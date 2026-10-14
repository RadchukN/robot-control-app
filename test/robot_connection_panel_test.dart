import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/core/theme/app_theme.dart';
import 'package:robot_control_app/features/dashboard/application/dashboard_controller.dart';
import 'package:robot_control_app/features/settings/presentation/settings_screen.dart';
import 'package:robot_control_app/models/dashboard_data.dart';
import 'package:robot_control_app/services/robot_authentication.dart';
import 'package:robot_control_app/services/robot_connection.dart';

import 'robot_authentication_test.dart' show MemoryTokenStore;

class _UiConnectionController extends DashboardController {
  RobotEndpoint? requestedEndpoint;
  int connectCalls = 0;
  int disconnectCalls = 0;
  @override
  Future<DashboardData> build() async =>
      DashboardData(updatedAt: DateTime.now());
  void telemetry(bool fresh) => state = AsyncData(
    DashboardData(updatedAt: DateTime.now(), telemetryConnected: fresh),
  );
  @override
  void connectRobot(RobotEndpoint endpoint) {
    connectCalls++;
    requestedEndpoint = endpoint;
    ref
        .read(robotLinkProvider.notifier)
        .update(const RobotLinkState(RobotLinkStatus.connecting));
  }

  @override
  void disconnectRobot() {
    disconnectCalls++;
    telemetry(false);
    ref
        .read(robotLinkProvider.notifier)
        .update(const RobotLinkState(RobotLinkStatus.disconnected));
  }
}

void main() {
  const previewPath = String.fromEnvironment('CONNECTIVITY_PREVIEW_PATH');
  const endpoint = RobotEndpoint(
    ip: '10.20.30.40',
    port: 9000,
    mode: RobotNetworkMode.lanWifi,
  );
  late ProviderContainer container;
  late MemoryTokenStore store;
  final previewKey = GlobalKey();

  setUp(() {
    store = MemoryTokenStore();
    container = ProviderContainer(
      overrides: [
        robotTokenStoreProvider.overrideWithValue(store),
        robotEndpointProvider.overrideWithValue(endpoint),
        dashboardControllerProvider.overrideWith(_UiConnectionController.new),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(1200, 1000),
    double scale = 1,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                backgroundColor: const Color(0xFFF1F5FF),
                body: RepaintBoundary(
                  key: previewKey,
                  child: const ColoredBox(
                    color: Color(0xFFF1F5FF),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(24),
                      child: RobotConnectionPanel(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  _UiConnectionController controller() =>
      container.read(dashboardControllerProvider.notifier)
          as _UiConnectionController;
  Finder field(String key) => find.byKey(Key(key));

  testWidgets('cards fit mobile, tablet, desktop and 200 percent text', (
    tester,
  ) async {
    for (final size in const [
      Size(320, 844),
      Size(390, 844),
      Size(768, 1024),
      Size(1200, 960),
      Size(1672, 941),
    ]) {
      await mount(tester, size: size);
      for (final key in [
        'robot-connection-card',
        'bearer-token-card',
        'connection-status-card',
        'connection-actions-card',
      ]) {
        final rect = tester.getRect(field(key));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
      }
      expect(
        field('connection-two-columns'),
        size.width - 48 >= 760 ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull, reason: '$size');
      await tester.pumpWidget(const SizedBox.shrink());
    }
    await mount(tester, size: const Size(390, 844), scale: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('draft fields preserve endpoint and validate before Connect', (
    tester,
  ) async {
    await mount(tester);
    expect(
      tester.widget<TextFormField>(field('robot-ip-field')).controller!.text,
      endpoint.ip,
    );
    expect(
      tester.widget<TextFormField>(field('robot-port-field')).controller!.text,
      '9000',
    );
    await tester.enterText(field('robot-ip-field'), '8.8.8.8');
    await tester.enterText(field('robot-port-field'), '0');
    await tester.ensureVisible(field('robot-connect-button'));
    await tester.tap(field('robot-connect-button'));
    await tester.pump();
    expect(
      find.text('Public internet addresses are not supported.'),
      findsOneWidget,
    );
    expect(find.text('Enter a port from 1 to 65535.'), findsOneWidget);
    expect(controller().connectCalls, 0);
    expect(container.read(selectedRobotEndpointProvider).uri, endpoint.uri);
    await tester.enterText(field('robot-ip-field'), '10.20.30.99');
    await tester.enterText(field('robot-port-field'), '8765');
    await tester.tap(field('robot-connect-button'));
    await tester.pump();
    expect(
      controller().requestedEndpoint!.uri.toString(),
      'ws://10.20.30.99:8765',
    );
    expect(controller().connectCalls, 1);
    expect(
      tester.widget<FilledButton>(field('robot-connect-button')).onPressed,
      isNull,
    );
  });

  testWidgets(
    'saved token metadata, visibility, save and removal use existing secure store',
    (tester) async {
      store.tokens[endpoint.uri] = 'saved-fixture-token';
      await mount(tester);
      expect(
        find.text('Token saved securely for this endpoint.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(field('robot-token-field'))
            .controller!
            .text,
        isEmpty,
      );
      await tester.enterText(
        field('robot-token-field'),
        'replacement-fixture-token',
      );
      await tester.tap(find.byTooltip('Show token'));
      await tester.pump();
      final editable = find.descendant(
        of: field('robot-token-field'),
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(editable).obscureText, isFalse);
      await tester.tap(find.text('Save token'));
      await tester.pumpAndSettle();
      expect(store.tokens[endpoint.uri], 'replacement-fixture-token');
      expect(
        tester
            .widget<TextFormField>(field('robot-token-field'))
            .controller!
            .text,
        isEmpty,
      );
      expect(tester.widget<EditableText>(editable).obscureText, isTrue);
      await tester.tap(find.text('Remove saved token'));
      await tester.pumpAndSettle();
      expect(store.tokens, isEmpty);
      expect(find.text('Saved token removed.'), findsOneWidget);
    },
  );

  testWidgets(
    'healthy status disables duplicate Connect and exposes full timestamp',
    (tester) async {
      await mount(tester);
      final now = DateTime.now();
      controller().telemetry(true);
      container
          .read(robotLinkProvider.notifier)
          .update(
            RobotLinkState(RobotLinkStatus.connected, lastTelemetryAt: now),
          );
      await tester.pump();
      expect(
        find.text('Robot is connected and telemetry is current.'),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(field('robot-connect-button')).onPressed,
        isNull,
      );
      expect(find.byTooltip(now.toLocal().toIso8601String()), findsOneWidget);
      expect(
        tester.widget<Text>(field('last-telemetry-time')).data,
        matches(RegExp(r'^\d{2}:\d{2}:\d{2}$')),
      );
      await tester.ensureVisible(field('robot-disconnect-button'));
      await tester.tap(field('robot-disconnect-button'));
      await tester.pump();
      expect(controller().disconnectCalls, 1);
      expect(
        find.text('Robot is connected and telemetry is current.'),
        findsNothing,
      );
    },
  );

  testWidgets('stale telemetry and authentication errors never appear healthy', (
    tester,
  ) async {
    await mount(tester);
    controller().telemetry(false);
    container
        .read(robotLinkProvider.notifier)
        .update(
          RobotLinkState(
            RobotLinkStatus.connected,
            lastTelemetryAt: DateTime.now(),
          ),
        );
    await tester.pump();
    expect(tester.widget<Text>(field('robot-status-title')).data, 'Degraded');
    controller().telemetry(true);
    container
        .read(robotLinkProvider.notifier)
        .update(
          RobotLinkState(
            RobotLinkStatus.connected,
            lastTelemetryAt: DateTime.now().subtract(
              const Duration(minutes: 1),
            ),
          ),
        );
    await tester.pump();
    expect(tester.widget<Text>(field('robot-status-title')).data, 'Degraded');
    container
        .read(robotLinkProvider.notifier)
        .update(
          const RobotLinkState(
            RobotLinkStatus.authenticationRequired,
            message:
                'Authentication rejected (HTTP 401). Change the saved token to reconnect.',
          ),
        );
    await tester.pump();
    expect(
      tester.widget<Text>(field('robot-status-title')).data,
      'Authentication required',
    );
    expect(
      find.text('Robot is connected and telemetry is current.'),
      findsNothing,
    );
  });

  testWidgets('network profile changes preserve drafts without connecting', (
    tester,
  ) async {
    await mount(tester);
    await tester.enterText(field('robot-ip-field'), '10.20.30.41');
    await tester.tap(field('robot-network-profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ethernet').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(field('robot-ip-field')).controller!.text,
      endpoint.ip,
    );
    await tester.tap(field('robot-network-profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('LAN / Wi-Fi').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.widget<TextFormField>(field('robot-ip-field')).controller!.text,
      '10.20.30.41',
    );
    expect(container.read(selectedRobotEndpointProvider).uri, endpoint.uri);
    expect(controller().connectCalls, 0);
  });

  testWidgets('reference viewport preview', (tester) async {
    await tester.runAsync(() async {
      if (Platform.isWindows) {
        final font = await File(
          '${Platform.environment['WINDIR']}/Fonts/segoeui.ttf',
        ).readAsBytes();
        for (final family in ['Roboto', 'Segoe UI']) {
          final loader = FontLoader(family)
            ..addFont(Future.value(ByteData.sublistView(font)));
          await loader.load();
        }
      }
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
    const previewEndpoint = RobotEndpoint(
      ip: '192.168.188.50',
      mode: RobotNetworkMode.lanWifi,
    );
    container
        .read(selectedRobotEndpointProvider.notifier)
        .select(previewEndpoint);
    store.tokens[previewEndpoint.uri] = 'preview-fixture-token';
    await mount(tester, size: const Size(1672, 941));
    controller().telemetry(true);
    container
        .read(robotLinkProvider.notifier)
        .update(
          RobotLinkState(
            RobotLinkStatus.connected,
            lastTelemetryAt: DateTime.now(),
          ),
        );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary =
          previewKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(previewPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }, skip: previewPath.isEmpty);
}
