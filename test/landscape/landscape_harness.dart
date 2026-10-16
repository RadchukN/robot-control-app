import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/app.dart';
import 'package:robot_control_app/core/routing/app_router.dart';
import 'package:robot_control_app/features/dashboard/application/dashboard_controller.dart';
import 'package:robot_control_app/models/dashboard_data.dart';
import 'package:robot_control_app/services/robot_service.dart';

import '../fixture_api_client.dart';

/// Phone landscape viewports from the mobile brief.
const landscapePhones = <Size>[
  Size(640, 360),
  Size(740, 360),
  Size(844, 390),
  Size(915, 412),
];

/// A notch on the left edge and a gesture bar at the bottom.
const notchPadding = FakeViewPadding(left: 44, right: 0, top: 0, bottom: 21);

/// Offline dashboard. Never connects; records every physical command attempt
/// so layout tests can prove they sent nothing (or exactly what they meant).
class RecordingRobot extends DashboardController {
  RecordingRobot({this.connected = true, this.reply});

  final bool connected;

  /// The robot's answer to a motion command; null never answers, as if the
  /// command were still running.
  final Map<String, dynamic> Function(String action, String? motion)? reply;
  final motionCalls = <String>[];
  final sentAudioFrames = <Map<String, Object?>>[];

  @override
  Future<DashboardData> build() async =>
      DashboardData(updatedAt: DateTime(2026), telemetryConnected: connected);

  @override
  Future<List<String>> getMotionCatalog() async => [
    'fake_hello.json',
    'fake_bow.json',
  ];

  @override
  Future<Map<String, dynamic>> sendMotion(
    String action, {
    String? motion,
    void Function(Map<String, dynamic>)? onResult,
  }) {
    motionCalls.add(motion == null ? action : '$action:$motion');
    final answer = reply?.call(action, motion);
    if (answer == null) return Completer<Map<String, dynamic>>().future;
    onResult?.call(answer);
    return Future.value(answer);
  }

  @override
  void sendAudioFrame(Map<String, Object?> frame) => sentAudioFrames.add(frame);
}

/// Sets the window to [size] in logical pixels with the given insets and
/// text scale. Everything is reset when the test ends.
void setPhoneView(
  WidgetTester tester,
  Size size, {
  FakeViewPadding padding = FakeViewPadding.zero,
  double keyboard = 0,
  double textScale = 1,
}) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size
    ..padding = padding
    ..viewPadding = padding
    ..viewInsets = FakeViewPadding(bottom: keyboard);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

/// Mounts the whole app on [route] and returns the container.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  required String route,
  RecordingRobot? robot,
  List overrides = const [],
}) async {
  final container = ProviderContainer(
    overrides: [
      dashboardControllerProvider.overrideWith(() => robot ?? RecordingRobot()),
      robotServiceProvider.overrideWithValue(RobotService(FixtureApiClient())),
      ...overrides.cast(),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const RobotControlApp(),
    ),
  );
  await settle(tester);
  container.read(appRouterProvider).go(route);
  await settle(tester);
  return container;
}

/// Lets animations and microtasks run without waiting for screens that
/// animate forever (spinners, simulated voice levels) to go idle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Collects every layout error (overflows included) raised while [body]
/// runs, instead of stopping at the first one. Each entry is the message
/// plus the source location of the widget that caused it.
Future<List<String>> layoutErrors(Future<void> Function() body) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.toString();
    final source = RegExp(r'lib/[^\s:]+\.dart:\d+').firstMatch(text)?.group(0);
    final message = details.exceptionAsString().split('\n').first;
    errors.add('$message @ $source');
  };
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return errors;
}

/// Errors whose cause is in [file] (e.g. `app_navigation_shell.dart`).
Iterable<String> errorsIn(List<String> errors, String file) =>
    errors.where((e) => e.contains(file));

/// The widget is on screen and can receive a tap.
void expectTappable(WidgetTester tester, Finder finder, {String? reason}) {
  expect(finder, findsOneWidget, reason: reason);
  expect(finder.hitTestable(), findsOneWidget, reason: reason);
  final size = tester.getSize(finder);
  expect(
    size.width >= 48 && size.height >= 48,
    isTrue,
    reason: '${reason ?? ''} target is $size',
  );
}

/// Loads Roboto (also under the Inter and Roboto Mono names the screens use)
/// and Material Icons from the Flutter SDK, so text measures as on a phone
/// instead of with the test font, whose glyphs are all square.
Future<void> loadRealFonts() async {
  final sdk = File(Platform.resolvedExecutable).parent.parent.parent.parent;
  final fonts = Directory('${sdk.path}/artifacts/material_fonts');
  Future<ByteData> read(String name) async =>
      ByteData.sublistView(await File('${fonts.path}/$name').readAsBytes());
  for (final family in const ['Roboto', 'Inter', 'Roboto Mono']) {
    final loader = FontLoader(family);
    for (final face in const [
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
      'roboto-light.ttf',
    ]) {
      loader.addFont(read(face));
    }
    await loader.load();
  }
  await (FontLoader(
    'MaterialIcons',
  )..addFont(read('materialicons-regular.otf'))).load();
}
