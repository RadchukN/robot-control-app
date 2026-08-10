import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/core/api/connection_provider.dart';
import 'package:robot_control_app/core/config/app_config.dart';
import 'package:robot_control_app/core/theme/app_colors.dart';
import 'package:robot_control_app/core/theme/app_spacing.dart';
import 'package:robot_control_app/models/connection_state.dart';
import 'package:robot_control_app/shared/widgets/info_tile.dart';
import 'package:robot_control_app/shared/widgets/primary_button.dart';
import 'package:robot_control_app/shared/widgets/section_title.dart';
import 'package:robot_control_app/shared/widgets/status_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final connection = ref.watch(connectionProvider);
    final (label, color) = switch (connection.status) {
      ConnectionStatus.connected => ('Connected', AppColors.success),
      ConnectionStatus.connecting => ('Connecting', AppColors.warning),
      ConnectionStatus.failed => ('Unavailable', AppColors.error),
      ConnectionStatus.disconnected => ('Not connected', Theme.of(context).colorScheme.outline),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const SectionTitle('Overview'),
            const SizedBox(height: AppSpacing.md),
            StatusCard(
              title: 'Robot Control API',
              status: label,
              subtitle: connection.message,
              icon: Icons.smart_toy_outlined,
              color: color,
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionTitle('Application'),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Column(
                children: [
                  InfoTile(title: 'API URL', value: config.apiUrl, icon: Icons.link),
                  const Divider(height: 1),
                  InfoTile(
                    title: 'Version',
                    value: config.version,
                    icon: Icons.info_outline,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Check connection',
              icon: Icons.sync,
              onPressed: connection.status == ConnectionStatus.connecting
                  ? null
                  : () => ref.read(connectionProvider.notifier).check(),
            ),
          ],
        ),
      ),
    );
  }
}
