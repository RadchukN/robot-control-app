import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/app.dart';
import 'package:robot_control_app/core/config/app_config.dart';
import 'package:robot_control_app/core/theme/theme_provider.dart';
import 'package:robot_control_app/services/robot_service.dart';

import 'fixture_api_client.dart';

void main() {
  test('default configuration points to the local API', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final config = container.read(appConfigProvider);

    expect(config.apiUrl, 'http://127.0.0.1:8000');
    expect(config.applicationName, 'Robot Control');
    expect(config.version, '0.1.0');
  });

  test('theme provider supports system, light, and dark modes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeProvider), ThemeMode.system);

    container.read(themeProvider.notifier).setThemeMode(ThemeMode.light);
    expect(container.read(themeProvider), ThemeMode.light);

    container.read(themeProvider.notifier).setThemeMode(ThemeMode.dark);
    expect(container.read(themeProvider), ThemeMode.dark);
  });

  testWidgets('compact shell navigation opens the control destination', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          robotServiceProvider.overrideWithValue(
            RobotService(FixtureApiClient()),
          ),
        ],
        child: const RobotControlApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Robot overview'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.sports_esports_outlined),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Motion is ready for integration'), findsOneWidget);
  });

  testWidgets('Dashboard fits all Figma reference viewports', (tester) async {
    for (final size in const [
      Size(390, 844),
      Size(768, 1024),
      Size(1440, 960),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            robotServiceProvider.overrideWithValue(
              RobotService(FixtureApiClient()),
            ),
          ],
          child: const RobotControlApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Robot overview'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Viewport: $size');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('AI Workspace fits all Figma reference viewports', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in const [
      Size(390, 844),
      Size(768, 1024),
      Size(1440, 960),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            robotServiceProvider.overrideWithValue(
              RobotService(FixtureApiClient()),
            ),
          ],
          child: const RobotControlApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.auto_awesome_outlined).first);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ai-workspace-screen')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Viewport: $size');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
