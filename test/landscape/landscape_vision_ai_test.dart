import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/core/routing/app_routes.dart';

import 'landscape_harness.dart';

Finder _button(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

void main() {
  setUpAll(loadRealFonts);

  testWidgets('Vision gives the camera the full height on phones', (
    tester,
  ) async {
    for (final size in landscapePhones) {
      setPhoneView(tester, size, padding: notchPadding);
      await layoutErrors(() => pumpApp(tester, route: AppRoutes.vision));
      final camera = tester.getRect(
        find.byKey(const Key('vision-camera-viewport')),
      );
      final usable = size.height - notchPadding.bottom;
      expect(camera.height, greaterThan(usable - 30), reason: '$size');
      expect(camera.bottom, lessThanOrEqualTo(usable), reason: '$size');
      // Secondary details live beside the camera, not below it.
      expect(find.byKey(const Key('vision-landscape-side')), findsOneWidget);
      expect(find.text('Waiting for camera events...'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('AI Workspace keeps input and confirmation reachable with '
      'the keyboard open', (tester) async {
    for (final size in landscapePhones) {
      for (final textScale in const [1.0, 1.3]) {
        final reason = '$size x$textScale';
        // A phone keyboard covers roughly half of a landscape screen.
        final keyboard = (size.height * 0.5).roundToDouble();
        setPhoneView(
          tester,
          size,
          padding: notchPadding,
          textScale: textScale,
          keyboard: keyboard,
        );
        final errors = await layoutErrors(() async {
          await pumpApp(tester, route: AppRoutes.aiWorkspace);
          await tester.showKeyboard(find.byKey(const Key('ai-composer-field')));
          await settle(tester);
        });
        expect(errors, isEmpty, reason: reason);
        final visibleBottom = size.height - keyboard;
        final field = tester.getRect(
          find.byKey(const Key('ai-composer-field')),
        );
        expect(field.bottom, lessThanOrEqualTo(visibleBottom), reason: reason);
        expectTappable(tester, _button('Send'), reason: reason);
        // The title row steps aside; the conversation still scrolls to the
        // confirmation buttons.
        expect(find.byKey(const Key('ai-landscape-top')), findsNothing);
        final confirm = _button('Confirm & execute');
        await tester.ensureVisible(confirm);
        await settle(tester);
        expect(confirm.hitTestable(), findsOneWidget, reason: reason);
        expect(
          tester.getRect(confirm).bottom,
          lessThanOrEqualTo(visibleBottom),
          reason: reason,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });

  testWidgets('AI Workspace shows title and context with the keyboard down', (
    tester,
  ) async {
    setPhoneView(tester, const Size(740, 360), padding: notchPadding);
    await layoutErrors(() => pumpApp(tester, route: AppRoutes.aiWorkspace));
    expect(find.byKey(const Key('ai-landscape-top')), findsOneWidget);
    expect(find.text('AI Workspace'), findsOneWidget);
    expect(find.text('Context live'), findsOneWidget);
  });

  testWidgets('desktop Vision and AI Workspace keep their layouts', (
    tester,
  ) async {
    setPhoneView(tester, const Size(1440, 960));
    await layoutErrors(() => pumpApp(tester, route: AppRoutes.vision));
    expect(find.byKey(const Key('vision-landscape-side')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await layoutErrors(() => pumpApp(tester, route: AppRoutes.aiWorkspace));
    expect(find.byKey(const Key('ai-landscape-top')), findsNothing);
  });
}
