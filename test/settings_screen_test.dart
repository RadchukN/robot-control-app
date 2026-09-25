import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/app.dart';
import 'package:robot_control_app/core/routing/app_router.dart';
import 'package:robot_control_app/core/routing/app_routes.dart';
import 'package:robot_control_app/features/settings/application/connectivity_state.dart';
import 'package:robot_control_app/features/settings/application/settings_state.dart';
import 'package:robot_control_app/services/robot_service.dart';

import 'fixture_api_client.dart';

void main() {
  testWidgets('Settings route fits the Figma reference viewports', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in const [
      Size(390, 844),
      Size(768, 1024),
      Size(1440, 960),
      Size(1792, 920),
    ]) {
      await tester.binding.setSurfaceSize(size);
      final container = ProviderContainer(
        overrides: [
          robotServiceProvider.overrideWithValue(
            RobotService(FixtureApiClient()),
          ),
        ],
      );
      container
          .read(settingsProvider.notifier)
          .selectCategory(SettingsCategory.connectivity);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RobotControlApp(),
        ),
      );
      await tester.pumpAndSettle();
      container.read(appRouterProvider).go(AppRoutes.settings);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-screen')), findsOneWidget);
      expect(find.byKey(const Key('connectivity-panel')), findsOneWidget);
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Connectivity'), findsWidgets);
      expect(tester.takeException(), isNull, reason: 'Viewport: $size');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
    }
  });

  test('Settings controls update only the local draft', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(settingsProvider.notifier).toggleRestoreLastRobot();

    final state = container.read(settingsProvider);
    expect(state.restoreLastRobot, isFalse);
    expect(state.syncStatus, SettingsSyncStatus.unsaved);
    expect(container.read(settingsPersistenceProvider), isNull);
  });

  testWidgets('Connectivity menu opens the section and toggles Wi-Fi', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [
        robotServiceProvider.overrideWithValue(
          RobotService(FixtureApiClient()),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const RobotControlApp(),
      ),
    );
    await tester.pumpAndSettle();
    container.read(appRouterProvider).go(AppRoutes.settings);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connectivity'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('connectivity-panel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('connectivity-wifi-switch')));
    await tester.pump();
    expect(container.read(connectivityProvider).wifiEnabled, isFalse);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
  });

  test('Connectivity controls update only screen-local state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(connectivityProvider.notifier);

    controller.toggleWifi();
    controller.connectWifi('guest-network');
    controller.setDefaultInput('USB microphone');

    final state = container.read(connectivityProvider);
    expect(state.wifiEnabled, isFalse);
    expect(state.selectedWifiId, 'guest-network');
    expect(
      state.wifiNetworks
          .singleWhere((item) => item.id == 'guest-network')
          .status,
      ConnectivityItemStatus.connected,
    );
    expect(state.defaultInput, 'USB microphone');
    expect(container.read(connectivityGatewayProvider), isNull);
  });
}
