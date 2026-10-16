import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:robot_control_app/core/navigation/navigation_visibility.dart';
import 'package:robot_control_app/core/routing/app_router.dart';
import 'package:robot_control_app/core/routing/app_routes.dart';
import 'package:robot_control_app/features/audio/presentation/audio_screen.dart';
import 'package:robot_control_app/features/settings/application/settings_state.dart';

import '../landscape/landscape_harness.dart';

const _hidden = [
  'Audio',
  'Controller',
  'Manipulation',
  'Automation',
  'Files',
  'Logs',
];

const _shown = [
  'Dashboard',
  'AI Workspace',
  'Motion',
  'AI Voice Studio',
  'Vision',
  'Settings',
];

void main() {
  test('the six unfinished destinations are hidden, the rest are not', () {
    expect(NavigationVisibility.hidden, {
      NavFeature.audio,
      NavFeature.controller,
      NavFeature.manipulation,
      NavFeature.automation,
      NavFeature.files,
      NavFeature.logs,
    });
    for (final feature in const [
      NavFeature.dashboard,
      NavFeature.aiWorkspace,
      NavFeature.motion,
      NavFeature.voiceStudio,
      NavFeature.vision,
      NavFeature.settings,
    ]) {
      expect(
        NavigationVisibility.isVisible(feature),
        isTrue,
        reason: '$feature',
      );
    }
    expect(NavigationVisibility.isRouteVisible(AppRoutes.audio), isFalse);
    expect(NavigationVisibility.isRouteVisible(AppRoutes.voiceStudio), isTrue);
    expect(NavigationVisibility.isRouteVisible(AppRoutes.settings), isTrue);
  });

  testWidgets('desktop sidebar hides the unfinished entries', (tester) async {
    for (final size in const [Size(1440, 960), Size(1024, 768)]) {
      setPhoneView(tester, size);
      // Not on Settings: its own Audio/Controller/Automation categories are
      // settings sections, not navigation, and stay.
      await layoutErrors(() => pumpApp(tester, route: AppRoutes.dashboard));
      for (final label in _shown) {
        expect(find.text(label), findsWidgets, reason: '$size $label');
      }
      for (final label in _hidden) {
        expect(find.text(label), findsNothing, reason: '$size $label');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('landscape rail hides Audio and keeps the working pages', (
    tester,
  ) async {
    setPhoneView(tester, const Size(844, 390));
    await layoutErrors(() => pumpApp(tester, route: AppRoutes.dashboard));
    expect(find.byKey(const Key('landscape-nav-2')), findsNothing);
    for (final branch in const [0, 5, 1, 6, 3, 4]) {
      expect(find.byKey(Key('landscape-nav-$branch')), findsOneWidget);
    }
  });

  testWidgets('portrait More sheet hides Audio', (tester) async {
    setPhoneView(tester, const Size(390, 844));
    await layoutErrors(() async {
      await pumpApp(tester, route: AppRoutes.dashboard);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.more_horiz),
        ),
      );
      await settle(tester);
    });
    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    for (final label in const ['AI Voice Studio', 'Vision', 'Settings']) {
      expect(
        find.descendant(of: sheet, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: sheet, matching: find.text('Audio')),
      findsNothing,
    );
  });

  testWidgets('global search does not offer the hidden Audio page', (
    tester,
  ) async {
    setPhoneView(tester, const Size(1440, 960));
    await layoutErrors(() async {
      await pumpApp(tester, route: AppRoutes.dashboard);
      await tester.tap(find.byKey(const Key('global-search-field')));
      await tester.enterText(
        find.byKey(const Key('global-search-field')),
        'audio',
      );
      await settle(tester);
    });
    expect(find.text('Audio'), findsNothing);
    // Audio settings are still found, under Connectivity.
    expect(find.text('Connectivity'), findsWidgets);
  });

  testWidgets('a stale or direct link to Audio lands on the Dashboard', (
    tester,
  ) async {
    setPhoneView(tester, const Size(1440, 960));
    late final GoRouter router;
    await layoutErrors(() async {
      final container = await pumpApp(tester, route: AppRoutes.audio);
      router = container.read(appRouterProvider);
    });
    expect(router.state.uri.path, AppRoutes.dashboard);
    expect(find.byType(AudioScreen), findsNothing);
  });

  testWidgets('Audio Devices and AI Voice Studio keep working', (tester) async {
    setPhoneView(tester, const Size(1440, 960));
    await layoutErrors(() async {
      final container = await pumpApp(tester, route: AppRoutes.settings);
      container
          .read(settingsProvider.notifier)
          .selectCategory(SettingsCategory.connectivity);
      await settle(tester);
    });
    expect(find.byKey(const Key('audio-devices-card')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await layoutErrors(() => pumpApp(tester, route: AppRoutes.voiceStudio));
    expect(find.byKey(const Key('voice-studio-screen')), findsOneWidget);
  });
}
