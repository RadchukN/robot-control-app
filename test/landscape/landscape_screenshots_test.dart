// Renders each route at the phone landscape sizes with real fonts, for
// visual review. Off by default; run with
//   LANDSCAPE_SHOTS=<output dir> flutter test test/landscape/landscape_screenshots_test.dart
// Robot traffic stays in the offline recorder, as in the other tests.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/core/routing/app_routes.dart';

import 'landscape_harness.dart';

final _out = Platform.environment['LANDSCAPE_SHOTS'];

const _routes = {
  'dashboard': AppRoutes.dashboard,
  'motion': AppRoutes.motion,
  'vision': AppRoutes.vision,
  'ai_workspace': AppRoutes.aiWorkspace,
  'voice_studio': AppRoutes.voiceStudio,
  'settings': AppRoutes.settings,
};

void main() {
  final shots = <(String, Size, String, double, double)>[
    for (final MapEntry(key: name, value: route) in _routes.entries)
      for (final size in const [Size(640, 360), Size(844, 390)])
        (name, size, route, 1.0, 0.0),
    (
      'ai_workspace_keyboard',
      const Size(844, 390),
      AppRoutes.aiWorkspace,
      1,
      180,
    ),
    ('settings_text13', const Size(740, 360), AppRoutes.settings, 1.3, 0),
    ('dashboard_desktop', const Size(1440, 960), AppRoutes.dashboard, 1, 0),
  ];

  testWidgets('landscape screenshots', skip: _out == null, (tester) async {
    await tester.runAsync(loadRealFonts);
    Directory(_out!).createSync(recursive: true);
    for (final (name, size, route, textScale, keyboard) in shots) {
      setPhoneView(
        tester,
        size,
        padding: size.height < 480 ? notchPadding : FakeViewPadding.zero,
        textScale: textScale,
        keyboard: keyboard,
      );
      await layoutErrors(() => pumpApp(tester, route: route));
      if (keyboard > 0) {
        final field = find.byType(TextField).last;
        await tester.showKeyboard(field);
        await settle(tester);
      }
      await tester.runAsync(() async {
        final element = find.byType(MaterialApp).evaluate().single;
        final ui.Image image = await captureImage(element);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          '$_out/${name}_${size.width.toInt()}x${size.height.toInt()}.png',
        );
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
