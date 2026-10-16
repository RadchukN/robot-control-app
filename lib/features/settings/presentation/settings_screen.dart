import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/core/theme/app_spacing.dart';
import 'package:robot_control_app/shared/layout/app_layout.dart';
import 'package:robot_control_app/core/theme/app_colors.dart';
import 'package:robot_control_app/core/theme/theme_provider.dart';
import 'package:robot_control_app/features/settings/application/audio_devices_controller.dart';
import 'package:robot_control_app/features/settings/application/connectivity_state.dart';
import 'package:robot_control_app/features/settings/application/settings_state.dart';
import 'package:robot_control_app/features/settings/data/audio_device_backend.dart';
import 'package:robot_control_app/features/dashboard/application/dashboard_controller.dart';
import 'package:robot_control_app/services/robot_connection.dart';
import 'package:robot_control_app/services/robot_authentication.dart';
import 'package:robot_control_app/shared/notifications/app_notification_service.dart';

part 'audio_devices_card.dart';
part 'connectivity_panel.dart';
part 'robot_connection_panel.dart';

const _background = Color(0xFFF1F5FF);
const _surface = Color(0xFFFFFFFF);
const _ink = Color(0xFF252A42);
const _body = Color(0xFF3F4661);
const _muted = Color(0xFF68708A);
const _outline = Color(0x8CD1D6E8);
const _purple = Color(0xFF752BE8);
const _selected = Color(0xFFE8DEFF);
const _control = Color(0xFFF2EDFF);
const _dot = Color(0xFFA6ADC4);
const _success = Color(0xFF0DA15C);
const _warning = Color(0xFF936900);
const _danger = Color(0xFFBA1A1A);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(settingsProvider.select((s) => s.syncStatus), (previous, next) {
      if (previous == null || previous == next) return;
      _notifySyncStatus(ref.read(appNotificationsProvider.notifier), next);
    });
    final state = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final connectivityState = ref.watch(connectivityProvider);
    final connectivityController = ref.read(connectivityProvider.notifier);
    final themeMode = ref.watch(themeProvider);

    return ColoredBox(
      key: const Key('settings-screen'),
      color: _background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return _PhoneSettings(
              state: state,
              connectivityState: connectivityState,
              connectivityController: connectivityController,
              onQueryChanged: controller.setSearchQuery,
              onCategorySelected: controller.selectCategory,
            );
          }
          if (constraints.maxWidth < 840) {
            return _TabletSettings(
              state: state,
              connectivityState: connectivityState,
              connectivityController: connectivityController,
              themeMode: themeMode,
              onQueryChanged: controller.setSearchQuery,
              onCategorySelected: controller.selectCategory,
              onThemeChanged: ref.read(themeProvider.notifier).setThemeMode,
              onRestoreRobotChanged: controller.toggleRestoreLastRobot,
              onOpenWorkspaceChanged: controller.toggleOpenLastWorkspace,
              onCollisionChanged: controller.toggleCollisionAvoidance,
              onProximityChanged: controller.toggleHumanProximityStop,
              onConfirmationChanged: controller.toggleCommandConfirmation,
            );
          }
          return _DesktopSettings(
            state: state,
            connectivityState: connectivityState,
            connectivityController: connectivityController,
            themeMode: themeMode,
            onCategorySelected: controller.selectCategory,
            onThemeChanged: ref.read(themeProvider.notifier).setThemeMode,
            onSearchChanged: controller.setSearchQuery,
            onSearchVisibilityChanged: controller.setSearchVisible,
            onRestoreRobotChanged: controller.toggleRestoreLastRobot,
            onOpenWorkspaceChanged: controller.toggleOpenLastWorkspace,
            onCollisionChanged: controller.toggleCollisionAvoidance,
            onProximityChanged: controller.toggleHumanProximityStop,
            onConfirmationChanged: controller.toggleCommandConfirmation,
          );
        },
      ),
    );
  }
}

class _DesktopSettings extends StatelessWidget {
  const _DesktopSettings({
    required this.state,
    required this.connectivityState,
    required this.connectivityController,
    required this.themeMode,
    required this.onCategorySelected,
    required this.onThemeChanged,
    required this.onSearchChanged,
    required this.onSearchVisibilityChanged,
    required this.onRestoreRobotChanged,
    required this.onOpenWorkspaceChanged,
    required this.onCollisionChanged,
    required this.onProximityChanged,
    required this.onConfirmationChanged,
  });

  final SettingsState state;
  final ConnectivityState connectivityState;
  final ConnectivityController connectivityController;
  final ThemeMode themeMode;
  final ValueChanged<SettingsCategory> onCategorySelected;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool> onSearchVisibilityChanged;
  final VoidCallback onRestoreRobotChanged;
  final VoidCallback onOpenWorkspaceChanged;
  final VoidCallback onCollisionChanged;
  final VoidCallback onProximityChanged;
  final VoidCallback onConfirmationChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showInspector = constraints.maxWidth >= 1540;
        final horizontalPadding = showInspector ? 30.0 : AppSpacing.lg;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            showInspector ? 22 : 18,
            horizontalPadding,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SettingsHeader(
                state: state,
                wide: showInspector,
                onSearchChanged: onSearchChanged,
                onSearchVisibilityChanged: onSearchVisibilityChanged,
              ),
              SizedBox(height: showInspector ? AppSpacing.md : 14),
              if (state.category == SettingsCategory.connectivity)
                _DesktopConnectivityLayout(
                  settingsState: state,
                  state: connectivityState,
                  controller: connectivityController,
                  wide: showInspector,
                  onCategorySelected: onCategorySelected,
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: showInspector ? 270 : 248,
                      child: _CategoryRail(
                        selected: state.category,
                        query: state.searchQuery,
                        onSelected: onCategorySelected,
                      ),
                    ),
                    SizedBox(width: showInspector ? 20 : 18),
                    Expanded(
                      child: _CategoryPanel(
                        state: state,
                        themeMode: themeMode,
                        onThemeChanged: onThemeChanged,
                        onRestoreRobotChanged: onRestoreRobotChanged,
                        onOpenWorkspaceChanged: onOpenWorkspaceChanged,
                        onCollisionChanged: onCollisionChanged,
                        onProximityChanged: onProximityChanged,
                        onConfirmationChanged: onConfirmationChanged,
                      ),
                    ),
                    if (showInspector) ...[
                      const SizedBox(width: 20),
                      const SizedBox(width: 360, child: _SafetyInspector()),
                    ],
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({
    required this.state,
    required this.wide,
    required this.onSearchChanged,
    required this.onSearchVisibilityChanged,
  });

  final SettingsState state;
  final bool wide;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool> onSearchVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (state.category) {
      SettingsCategory.connectivity =>
        'Configure Gustav’s network, pairing, and platform connectivity',
      SettingsCategory.safety when wide =>
        'Safety configuration for Gustav and shared operator policy',
      _ => 'Configure Gustav, platform behavior and operator preferences',
    };
    return SizedBox(
      height: wide ? 60 : 57,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: _text(
                    wide ? 30 : 28,
                    height: wide ? 41 / 30 : 38 / 28,
                    weight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text(12, height: 16 / 12, color: _muted),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: wide ? 8 : 12.5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusPill(status: state.syncStatus),
                const SizedBox(width: 10),
                if (state.searchVisible)
                  SizedBox(
                    width: 184,
                    height: 32,
                    child: _SearchField(
                      initialValue: state.searchQuery,
                      hint: 'Search settings',
                      autofocus: true,
                      onChanged: onSearchChanged,
                      onSubmitted: (_) => onSearchVisibilityChanged(false),
                    ),
                  )
                else
                  _HeaderButton(
                    label: 'Search settings',
                    onTap: () => onSearchVisibilityChanged(true),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final SettingsSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SettingsSyncStatus.saved => _success,
      SettingsSyncStatus.unsaved => _purple,
      SettingsSyncStatus.restartRequired => _purple,
      SettingsSyncStatus.warning => _warning,
      SettingsSyncStatus.danger => _danger,
      SettingsSyncStatus.offline => _muted,
      SettingsSyncStatus.noRobot => _muted,
    };
    final label = status == SettingsSyncStatus.saved
        ? 'All changes saved'
        : status.label;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _control,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Text(
        label,
        style: _text(
          12,
          height: 16 / 12,
          weight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _control,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        hoverColor: _selected,
        child: SizedBox(
          width: 114,
          height: 32,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_rounded, size: 14, color: _muted),
              const SizedBox(width: AppSpacing.xxs),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: _text(
                      11,
                      height: 15 / 11,
                      weight: FontWeight.w500,
                      color: _muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.selected,
    required this.query,
    required this.onSelected,
  });

  final SettingsCategory selected;
  final String query;
  final ValueChanged<SettingsCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final needle = query.trim().toLowerCase();
    final categories = SettingsCategory.values.where((category) {
      return needle.isEmpty ||
          category.label.toLowerCase().contains(needle) ||
          category.description.toLowerCase().contains(needle);
    }).toList();
    return _GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          for (var index = 0; index < categories.length; index++) ...[
            _CategoryRailItem(
              category: categories[index],
              selected: categories[index] == selected,
              onTap: categories[index].hasPanel
                  ? () => onSelected(categories[index])
                  : null,
            ),
            if (index != categories.length - 1)
              const SizedBox(height: AppSpacing.xxs),
          ],
        ],
      ),
    );
  }
}

class _CategoryRailItem extends StatelessWidget {
  const _CategoryRailItem({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final SettingsCategory category;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _selected : Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        hoverColor: _selected.withValues(alpha: 0.55),
        child: SizedBox(
          height: 30,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: AppSpacing.xs,
                  height: AppSpacing.xs,
                  decoration: BoxDecoration(
                    color: selected ? _purple : _dot,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  category.label,
                  style: _text(
                    12,
                    height: 16 / 12,
                    weight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? _purple : _body,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryPanel extends StatelessWidget {
  const _CategoryPanel({
    required this.state,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onRestoreRobotChanged,
    required this.onOpenWorkspaceChanged,
    required this.onCollisionChanged,
    required this.onProximityChanged,
    required this.onConfirmationChanged,
  });

  final SettingsState state;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final VoidCallback onRestoreRobotChanged;
  final VoidCallback onOpenWorkspaceChanged;
  final VoidCallback onCollisionChanged;
  final VoidCallback onProximityChanged;
  final VoidCallback onConfirmationChanged;

  @override
  Widget build(BuildContext context) {
    return switch (state.category) {
      SettingsCategory.safety => _SafetyPanel(
        state: state,
        onCollisionChanged: onCollisionChanged,
        onProximityChanged: onProximityChanged,
        onConfirmationChanged: onConfirmationChanged,
      ),
      SettingsCategory.appearance => _AppearancePanel(
        themeMode: themeMode,
        onThemeChanged: onThemeChanged,
      ),
      _ => _GeneralPanel(
        state: state,
        onRestoreRobotChanged: onRestoreRobotChanged,
        onOpenWorkspaceChanged: onOpenWorkspaceChanged,
      ),
    };
  }
}

class _GeneralPanel extends StatelessWidget {
  const _GeneralPanel({
    required this.state,
    required this.onRestoreRobotChanged,
    required this.onOpenWorkspaceChanged,
    this.tablet = false,
  });

  final SettingsState state;
  final VoidCallback onRestoreRobotChanged;
  final VoidCallback onOpenWorkspaceChanged;
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    if (tablet) {
      return _TabletGeneralPanel(
        state: state,
        onRestoreRobotChanged: onRestoreRobotChanged,
        onOpenWorkspaceChanged: onOpenWorkspaceChanged,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _OverviewCard(
          title: 'General',
          subtitle:
              'Core identity, regional preferences and startup behavior for G1 Gustav.',
          height: 82,
        ),
        const SizedBox(height: AppSpacing.sm),
        _DesktopSection(
          title: 'Robot identity',
          description: 'How Gustav appears and where operator sessions begin.',
          rows: [
            _SettingRowData(
              'Robot display name',
              'Current robot identity',
              value: state.robotDisplayName,
            ),
            _SettingRowData(
              'Default workspace',
              'First workspace after sign-in',
              value: state.defaultWorkspace,
            ),
            _SettingRowData(
              'Startup module',
              'Module restored after reconnect',
              value: state.startupModule,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _DesktopSection(
          title: 'Regional preferences',
          description: 'Formatting used throughout the operator interface.',
          rows: [
            _SettingRowData(
              'Time zone',
              'Used for missions, logs and scheduled automation',
              value: state.timeZone,
            ),
            _SettingRowData(
              'Units',
              'Preferred measurement system',
              value: state.units,
            ),
            _SettingRowData(
              'Language',
              'Interface and system messages',
              value: state.language,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _DesktopSection(
          title: 'Startup behavior',
          description: 'Choose what the platform restores between sessions.',
          rows: [
            _SettingRowData(
              'Restore last robot',
              'Reconnect to Gustav when authorized',
              switchValue: state.restoreLastRobot,
              onChanged: onRestoreRobotChanged,
            ),
            _SettingRowData(
              'Open at last workspace',
              'Preserve operator context between sessions',
              switchValue: state.openLastWorkspace,
              onChanged: onOpenWorkspaceChanged,
            ),
          ],
        ),
      ],
    );
  }
}

class _SafetyPanel extends StatelessWidget {
  const _SafetyPanel({
    required this.state,
    required this.onCollisionChanged,
    required this.onProximityChanged,
    required this.onConfirmationChanged,
    this.tablet = false,
  });

  final SettingsState state;
  final VoidCallback onCollisionChanged;
  final VoidCallback onProximityChanged;
  final VoidCallback onConfirmationChanged;
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final motionRows = [
      _SettingRowData(
        'Collision avoidance',
        'Prevent contact with detected obstacles',
        switchValue: state.collisionAvoidance,
        onChanged: onCollisionChanged,
      ),
      _SettingRowData(
        'Human proximity stop',
        tablet
            ? 'Stop inside the protected zone'
            : 'Stop when a person enters the protected zone',
        switchValue: state.humanProximityStop,
        onChanged: onProximityChanged,
      ),
      _SettingRowData(
        'Maximum robot speed',
        'Global speed ceiling',
        value: state.maximumRobotSpeed,
      ),
    ];
    final operatorRows = [
      const _SettingRowData(
        'Emergency stop',
        'Always visible and immediately actionable',
        value: 'Enabled',
        valueColor: _success,
      ),
      _SettingRowData(
        'Command confirmation',
        tablet
            ? 'Confirm high-impact actions'
            : 'Require confirmation for high-impact actions',
        switchValue: state.commandConfirmation,
        onChanged: onConfirmationChanged,
      ),
      _SettingRowData(
        'Control ownership',
        tablet
            ? 'One active operator at a time'
            : 'Only one active operator at a time',
        value: state.controlOwnership,
      ),
    ];
    if (tablet) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _OverviewCard(
            title: 'Safety',
            subtitle: 'Limits, stop behavior and operator authority.',
            height: 69,
            tablet: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          _TabletSection(title: 'Motion protection', rows: motionRows),
          const SizedBox(height: AppSpacing.sm),
          _TabletSection(title: 'Operator controls', rows: operatorRows),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _OverviewCard(
          title: 'Safety',
          subtitle:
              'Safety-critical limits require explicit authority and remain visible to operators.',
          height: 87,
          wide: true,
        ),
        const SizedBox(height: 14),
        _DesktopSection(
          title: 'Motion protection',
          description: 'Safeguards applied before motion reaches Gustav.',
          rowHeight: 61,
          rows: motionRows,
        ),
        const SizedBox(height: 14),
        _DesktopSection(
          title: 'Operator controls',
          description:
              'Authority and confirmation for safety-critical actions.',
          rowHeight: 61,
          rows: operatorRows,
        ),
      ],
    );
  }
}

class _AppearancePanel extends StatelessWidget {
  const _AppearancePanel({
    required this.themeMode,
    required this.onThemeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _OverviewCard(
          title: 'Appearance',
          subtitle: 'Theme, density and contrast preferences for this device.',
          height: 82,
        ),
        const SizedBox(height: AppSpacing.sm),
        _GlassCard(
          radius: 20,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Interface theme',
                style: _text(
                  16,
                  height: 22 / 16,
                  weight: FontWeight.w600,
                  color: _ink,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Use the system preference or select a fixed appearance.',
                style: _text(11, height: 15 / 11, color: _muted),
              ),
              const SizedBox(height: AppSpacing.md),
              SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('System')),
                  ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ],
                selected: {themeMode},
                onSelectionChanged: (value) => onThemeChanged(value.first),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.title,
    required this.subtitle,
    required this.height,
    this.tablet = false,
    this.wide = false,
  });

  final String title;
  final String subtitle;
  final double height;
  final bool tablet;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: _GlassCard(
        radius: tablet
            ? 18
            : wide
            ? 22
            : 20,
        padding: EdgeInsets.symmetric(
          horizontal: tablet
              ? 18
              : wide
              ? 22
              : 20,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: _text(
                tablet
                    ? 19
                    : wide
                    ? 23
                    : 22,
                height: tablet
                    ? 26 / 19
                    : wide
                    ? 31 / 23
                    : 30 / 22,
                weight: FontWeight.w600,
                color: _ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _text(11, height: 15 / 11, color: _muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopSection extends StatelessWidget {
  const _DesktopSection({
    required this.title,
    required this.description,
    required this.rows,
    this.rowHeight = 57,
  });

  final String title;
  final String description;
  final List<_SettingRowData> rows;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _text(
                    16,
                    height: 22 / 16,
                    weight: FontWeight.w600,
                    color: const Color(0xFF333B57),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: _text(11, height: 15 / 11, color: _muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          for (var index = 0; index < rows.length; index++) ...[
            _SettingRow(data: rows[index], height: rowHeight),
            if (index != rows.length - 1)
              const Divider(height: 1, thickness: 1, color: _outline),
          ],
        ],
      ),
    );
  }
}

class _SettingRowData {
  const _SettingRowData(
    this.title,
    this.subtitle, {
    this.value,
    this.valueColor,
    this.switchValue,
    this.onChanged,
  });

  final String title;
  final String subtitle;
  final String? value;
  final Color? valueColor;
  final bool? switchValue;
  final VoidCallback? onChanged;
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.data,
    required this.height,
    this.dense = false,
  });

  final _SettingRowData data;
  final double height;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: dense ? AppSpacing.md : 18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _text(
                      dense ? 12 : 13,
                      height: dense ? 16 / 12 : 18 / 13,
                      weight: FontWeight.w500,
                      color: _body,
                    ),
                  ),
                  Text(
                    data.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _text(
                      dense ? 10 : 11,
                      height: dense ? 14 / 10 : 15 / 11,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (data.switchValue case final value?)
              _SettingsSwitch(
                value: value,
                onTap: data.onChanged,
                compact: dense,
              )
            else
              _ValuePill(
                value: data.value ?? '',
                color: data.valueColor ?? _purple,
                compact: dense,
              ),
          ],
        ),
      ),
    );
  }
}

class _ValuePill extends StatelessWidget {
  const _ValuePill({
    required this.value,
    required this.color,
    required this.compact,
  });

  final String value;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 31 : 32,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _control,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Text(
        value,
        style: _text(
          compact ? 11 : 12,
          height: compact ? 15 / 11 : 16 / 12,
          weight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    required this.value,
    required this.onTap,
    required this.compact,
  });

  final bool value;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 42.0 : 44.0;
    final height = compact ? 24.0 : 26.0;
    final thumbSize = compact ? 18.0 : 20.0;
    return Semantics(
      toggled: value,
      button: true,
      child: MouseRegion(
        cursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: GestureDetector(
          key: ValueKey('settings-switch-${value ? 'on' : 'off'}'),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: width,
            height: height,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: value ? _purple : _dot,
              borderRadius: BorderRadius.circular(999),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 160),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: thumbSize,
                height: thumbSize,
                decoration: const BoxDecoration(
                  color: _surface,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SafetyInspector extends StatelessWidget {
  const _SafetyInspector();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _InspectorCard(
          title: 'Safety status',
          primary: 'Nominal · 8 safeguards active',
          secondary: 'Last validated 14:18 · Gustav online',
          primaryColor: _success,
        ),
        const SizedBox(height: AppSpacing.md),
        _GlassCard(
          radius: 20,
          color: const Color(0xFFFFF3F2),
          borderColor: const Color(0x66BA1A1A),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'High-risk settings',
                style: _text(
                  16,
                  height: 22 / 16,
                  weight: FontWeight.w600,
                  color: _danger,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Changes can alter physical safety behavior and require elevated authorization.',
                style: _text(11, height: 15 / 11, color: _muted),
              ),
              const SizedBox(height: AppSpacing.md),
              const _InspectorAction(
                title: 'Disable proximity stop',
                subtitle: 'Requires Safety Admin and robot idle',
                action: 'Locked',
              ),
              const Divider(height: 17, color: Color(0x40BA1A1A)),
              const _InspectorAction(
                title: 'Reset safety policy',
                subtitle: 'Restore approved platform defaults',
                action: 'Review',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const _InspectorCard(
          title: 'Recent safety changes',
          primary: '14:12 · Speed limit validated',
          secondary: 'Yesterday · Authority policy reviewed',
        ),
      ],
    );
  }
}

class _InspectorCard extends StatelessWidget {
  const _InspectorCard({
    required this.title,
    required this.primary,
    required this.secondary,
    this.primaryColor = _body,
  });

  final String title;
  final String primary;
  final String secondary;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: _text(
              15,
              height: 20 / 15,
              weight: FontWeight.w600,
              color: _ink,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            primary,
            style: _text(
              11,
              height: 15 / 11,
              weight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            secondary,
            style: _text(10, height: 14 / 10, color: _muted),
          ),
        ],
      ),
    );
  }
}

class _InspectorAction extends StatelessWidget {
  const _InspectorAction({
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final String title;
  final String subtitle;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: _text(
                  12,
                  height: 16 / 12,
                  weight: FontWeight.w500,
                  color: _body,
                ),
              ),
              Text(
                subtitle,
                style: _text(9, height: 12 / 9, color: _muted),
              ),
            ],
          ),
        ),
        _ValuePill(value: action, color: _danger, compact: true),
      ],
    );
  }
}

class _TabletSettings extends StatelessWidget {
  const _TabletSettings({
    required this.state,
    required this.connectivityState,
    required this.connectivityController,
    required this.themeMode,
    required this.onQueryChanged,
    required this.onCategorySelected,
    required this.onThemeChanged,
    required this.onRestoreRobotChanged,
    required this.onOpenWorkspaceChanged,
    required this.onCollisionChanged,
    required this.onProximityChanged,
    required this.onConfirmationChanged,
  });

  final SettingsState state;
  final ConnectivityState connectivityState;
  final ConnectivityController connectivityController;
  final ThemeMode themeMode;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<SettingsCategory> onCategorySelected;
  final ValueChanged<ThemeMode> onThemeChanged;
  final VoidCallback onRestoreRobotChanged;
  final VoidCallback onOpenWorkspaceChanged;
  final VoidCallback onCollisionChanged;
  final VoidCallback onProximityChanged;
  final VoidCallback onConfirmationChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: AppLayout.landscapeOf(context) ? null : 51,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settings',
                        style: _text(
                          25,
                          height: 34 / 25,
                          weight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                      Text(
                        state.category == SettingsCategory.connectivity
                            ? 'Network, pairing and platform connectivity'
                            : 'Configure Gustav and operator preferences',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _text(11, height: 15 / 11, color: _muted),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _StatusPill(status: state.syncStatus),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 38,
            child: _SearchField(
              initialValue: state.searchQuery,
              hint: 'Search settings',
              onChanged: onQueryChanged,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _TabletCategorySelector(
            category: state.category,
            onSelected: onCategorySelected,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (state.category == SettingsCategory.connectivity)
            _ConnectivityResponsivePanel(
              state: connectivityState,
              controller: connectivityController,
            )
          else if (state.category == SettingsCategory.safety)
            _SafetyPanel(
              state: state,
              tablet: true,
              onCollisionChanged: onCollisionChanged,
              onProximityChanged: onProximityChanged,
              onConfirmationChanged: onConfirmationChanged,
            )
          else if (state.category == SettingsCategory.appearance)
            _AppearancePanel(
              themeMode: themeMode,
              onThemeChanged: onThemeChanged,
            )
          else
            _GeneralPanel(
              state: state,
              tablet: true,
              onRestoreRobotChanged: onRestoreRobotChanged,
              onOpenWorkspaceChanged: onOpenWorkspaceChanged,
            ),
        ],
      ),
    );
  }
}

class _TabletCategorySelector extends StatelessWidget {
  const _TabletCategorySelector({
    required this.category,
    required this.onSelected,
  });

  final SettingsCategory category;
  final ValueChanged<SettingsCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      radius: AppSpacing.md,
      padding: EdgeInsets.zero,
      child: PopupMenuButton<SettingsCategory>(
        tooltip: 'Change category',
        onSelected: onSelected,
        itemBuilder: (context) => SettingsCategory.values
            .where((item) => item.hasPanel)
            .map((item) => PopupMenuItem(value: item, child: Text(item.label)))
            .toList(),
        child: SizedBox(
          height: AppLayout.landscapeOf(context) ? AppLayout.touchTarget : 38,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    category.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _text(
                      13,
                      height: 18 / 13,
                      weight: FontWeight.w600,
                      color: _purple,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    'Change category',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: _text(11, height: 15 / 11, color: _muted),
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: _muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabletGeneralPanel extends StatelessWidget {
  const _TabletGeneralPanel({
    required this.state,
    required this.onRestoreRobotChanged,
    required this.onOpenWorkspaceChanged,
  });

  final SettingsState state;
  final VoidCallback onRestoreRobotChanged;
  final VoidCallback onOpenWorkspaceChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _OverviewCard(
          title: 'General',
          subtitle: 'Identity, regional preferences and safe startup defaults.',
          height: 69,
          tablet: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        _TabletSection(
          title: 'Robot identity',
          rows: [
            _SettingRowData(
              'Robot display name',
              'Shown across workspaces',
              value: state.robotDisplayName,
            ),
            _SettingRowData(
              'Default workspace',
              'First screen after sign-in',
              value: state.defaultWorkspace,
            ),
            _SettingRowData(
              'Startup module',
              'Restore operator context',
              value: state.startupModule,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _TabletSection(
          title: 'Regional preferences',
          rows: [
            _SettingRowData(
              'Time zone',
              'Mission and log timestamps',
              value: state.timeZone,
            ),
            _SettingRowData(
              'Units',
              'Measurements and telemetry',
              value: state.units,
            ),
            _SettingRowData(
              'Language',
              'Interface language',
              value: state.language,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _TabletSection(
          title: 'Startup behavior',
          rows: [
            _SettingRowData(
              'Restore last robot',
              'Reconnect when authorized',
              switchValue: state.restoreLastRobot,
              onChanged: onRestoreRobotChanged,
            ),
            _SettingRowData(
              'Open last workspace',
              'Preserve operator context',
              switchValue: state.openLastWorkspace,
              onChanged: onOpenWorkspaceChanged,
            ),
          ],
        ),
      ],
    );
  }
}

class _TabletSection extends StatelessWidget {
  const _TabletSection({required this.title, required this.rows});

  final String title;
  final List<_SettingRowData> rows;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      radius: 18,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: _text(
                    15,
                    height: 20 / 15,
                    weight: FontWeight.w600,
                    color: const Color(0xFF333B57),
                  ),
                ),
              ),
            ),
          ),
          for (var index = 0; index < rows.length; index++) ...[
            _SettingRow(data: rows[index], height: 56, dense: true),
            if (index != rows.length - 1)
              const Divider(height: 1, thickness: 1, color: _outline),
          ],
        ],
      ),
    );
  }
}

class _PhoneSettings extends StatelessWidget {
  const _PhoneSettings({
    required this.state,
    required this.connectivityState,
    required this.connectivityController,
    required this.onQueryChanged,
    required this.onCategorySelected,
  });

  final SettingsState state;
  final ConnectivityState connectivityState;
  final ConnectivityController connectivityController;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<SettingsCategory> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final needle = state.searchQuery.trim().toLowerCase();
    final categories = SettingsCategory.values.where((category) {
      return needle.isEmpty ||
          category.label.toLowerCase().contains(needle) ||
          category.description.toLowerCase().contains(needle);
    }).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: AppLayout.landscapeOf(context) ? null : 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settings',
                        style: _text(
                          24,
                          height: 32 / 24,
                          weight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                      Text(
                        state.category == SettingsCategory.connectivity
                            ? 'Network, pairing and platform connectivity'
                            : 'Robot, platform and operator preferences',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _text(11, height: 15 / 11, color: _muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _StatusPill(status: state.syncStatus),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 38,
            child: _SearchField(
              initialValue: state.searchQuery,
              hint: 'Search settings',
              onChanged: onQueryChanged,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (state.category == SettingsCategory.connectivity) ...[
            _TabletCategorySelector(
              category: state.category,
              onSelected: onCategorySelected,
            ),
            const SizedBox(height: AppSpacing.sm),
            _ConnectivityResponsivePanel(
              state: connectivityState,
              controller: connectivityController,
              compact: true,
            ),
          ] else
            _GlassCard(
              radius: 20,
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Column(
                children: [
                  for (var index = 0; index < categories.length; index++) ...[
                    _PhoneCategoryItem(
                      category: categories[index],
                      selected: categories[index] == state.category,
                      onTap: categories[index].hasPanel
                          ? () => onCategorySelected(categories[index])
                          : null,
                    ),
                    if (index != categories.length - 1)
                      const SizedBox(height: AppSpacing.xxs),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PhoneCategoryItem extends StatelessWidget {
  const _PhoneCategoryItem({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final SettingsCategory category;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _selected : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        hoverColor: _selected.withValues(alpha: 0.55),
        child: ConstrainedBox(
          constraints: AppLayout.landscapeOf(context)
              ? const BoxConstraints(minHeight: 49)
              : const BoxConstraints.tightFor(height: 49),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 9,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.label,
                        style: _text(
                          13,
                          height: 18 / 13,
                          weight: selected ? FontWeight.w600 : FontWeight.w500,
                          color: selected ? _purple : _body,
                        ),
                      ),
                      Text(
                        category.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _text(9, height: 12 / 9, color: _muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '›',
                  style: _text(
                    19,
                    height: 26 / 19,
                    color: selected ? _purple : _muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.initialValue,
    required this.hint,
    required this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  final String initialValue;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      autofocus: autofocus,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      style: _text(12, height: 16 / 12, color: _body),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: _text(12, height: 16 / 12, color: _muted),
        prefixIcon: const Icon(Icons.search_rounded, size: 16, color: _muted),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 34,
          minHeight: 38,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        filled: true,
        fillColor: _surface.withValues(alpha: 0.86),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _purple, width: 1.5),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    super.key,
    required this.radius,
    required this.padding,
    required this.child,
    this.color,
    this.borderColor,
  });

  final double radius;
  final EdgeInsetsGeometry padding;
  final Widget child;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? _surface.withValues(alpha: 0.76),
        border: Border.all(color: borderColor ?? _outline),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x122E1F6B),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

TextStyle _text(
  double size, {
  required double height,
  required Color color,
  FontWeight weight = FontWeight.w400,
}) {
  return TextStyle(
    fontSize: size,
    height: height,
    fontWeight: weight,
    color: color,
  );
}

/// Mirrors the inline sync status as a transient notification.
void _notifySyncStatus(
  AppNotificationService notifications,
  SettingsSyncStatus status,
) {
  const key = 'settings-sync';
  switch (status) {
    case SettingsSyncStatus.saved:
      notifications.success(
        'Settings saved',
        description: 'Changes are synchronized.',
        key: key,
      );
    case SettingsSyncStatus.unsaved:
      notifications.unsaved(
        'Unsaved changes',
        description: 'Review or discard your edits.',
        key: key,
      );
    case SettingsSyncStatus.restartRequired:
      notifications.info(
        'Restart required',
        description: 'Apply after a safe restart.',
        key: key,
      );
    case SettingsSyncStatus.warning:
      notifications.warning(
        'Setting reduces protection',
        description: 'Review safety settings before robot motion.',
        key: key,
      );
    case SettingsSyncStatus.danger:
      notifications.error(
        'Elevated authority required',
        description: status.description,
        key: key,
      );
    case SettingsSyncStatus.offline:
    case SettingsSyncStatus.noRobot:
      notifications.info(
        status.label,
        description: status.description,
        key: key,
      );
  }
}
