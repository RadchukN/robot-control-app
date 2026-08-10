import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/app.dart';
import 'package:robot_control_app/core/config/app_config.dart';
import 'package:robot_control_app/core/theme/theme_provider.dart';

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

  testWidgets('bottom navigation switches between feature screens', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RobotControlApp()));
    await tester.pumpAndSettle();

    expect(find.text('Overview'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.byIcon(Icons.directions_walk_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Motion is ready for integration'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.graphic_eq_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Audio is ready for integration'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Vision is ready for integration'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
  });
}
