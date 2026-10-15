import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/app.dart';
import 'package:robot_control_app/core/routing/app_router.dart';
import 'package:robot_control_app/core/routing/app_routes.dart';
import 'package:robot_control_app/features/settings/application/connectivity_state.dart';
import 'package:robot_control_app/features/settings/application/settings_state.dart';
import 'package:robot_control_app/services/robot_service.dart';
import 'package:robot_control_app/features/dashboard/application/dashboard_controller.dart';
import 'package:robot_control_app/models/dashboard_data.dart';
import 'package:robot_control_app/services/robot_authentication.dart';
import 'robot_authentication_test.dart' show MemoryTokenStore;

import 'fixture_api_client.dart';

class _OfflineSettingsDashboard extends DashboardController {
  @override
  Future<DashboardData> build() async =>
      DashboardData(updatedAt: DateTime.now());
}

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
          dashboardControllerProvider.overrideWith(
            _OfflineSettingsDashboard.new,
          ),
          robotTokenStoreProvider.overrideWithValue(MemoryTokenStore()),
          robotServiceProvider.overrideWithValue(
            RobotService(FixtureApiClient()),
          ),
        ],
      );
      container
          .read(settingsProvider.notifier)
          .selectCategory(SettingsCategory.connectivity);
      container.read(appRouterProvider).go(AppRoutes.settings);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RobotControlApp(),
        ),
      );
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

  testWidgets('Connectivity menu opens the real robot connection controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [
        dashboardControllerProvider.overrideWith(_OfflineSettingsDashboard.new),
        robotTokenStoreProvider.overrideWithValue(MemoryTokenStore()),
        robotServiceProvider.overrideWithValue(
          RobotService(FixtureApiClient()),
        ),
      ],
    );
    container.read(appRouterProvider).go(AppRoutes.settings);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const RobotControlApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connectivity'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('connectivity-panel')), findsOneWidget);
    expect(find.byKey(const Key('robot-ip-field')), findsOneWidget);
    expect(find.byKey(const Key('robot-connect-button')), findsOneWidget);
    expect(find.byKey(const Key('connectivity-wifi-switch')), findsNothing);
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
