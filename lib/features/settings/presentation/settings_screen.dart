import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/core/config/app_config.dart';
import 'package:robot_control_app/core/theme/app_spacing.dart';
import 'package:robot_control_app/core/theme/theme_provider.dart';
import 'package:robot_control_app/shared/widgets/info_tile.dart';
import 'package:robot_control_app/shared/widgets/section_title.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const SectionTitle('Appearance'),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('System'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Dark'),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (selection) {
                ref.read(themeProvider.notifier).setThemeMode(selection.first);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionTitle('Environment'),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Column(
                children: [
                  InfoTile(title: 'API URL', value: config.apiUrl),
                  const Divider(height: 1),
                  InfoTile(title: 'App version', value: config.version),
                  const Divider(height: 1),
                  InfoTile(title: 'Debug mode', value: config.debugMode ? 'On' : 'Off'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
