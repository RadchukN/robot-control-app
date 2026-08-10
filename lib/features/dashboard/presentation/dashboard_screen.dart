import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/core/theme/app_colors.dart';
import 'package:robot_control_app/core/theme/app_spacing.dart';
import 'package:robot_control_app/features/dashboard/application/dashboard_controller.dart';
import 'package:robot_control_app/features/dashboard/dashboard_failure.dart';
import 'package:robot_control_app/models/dashboard_data.dart';
import 'package:robot_control_app/models/service_info.dart';
import 'package:robot_control_app/shared/widgets/info_tile.dart';
import 'package:robot_control_app/shared/widgets/loading_view.dart';
import 'package:robot_control_app/shared/widgets/section_title.dart';
import 'package:robot_control_app/shared/widgets/status_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: dashboard.isLoading ? null : controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: dashboard.when(
          loading: () => const LoadingView(message: 'Loading robot status...'),
          error: (error, _) => _DashboardError(
            failure: DashboardFailure.from(error),
            onRefresh: controller.refresh,
          ),
          data: (data) =>
              _DashboardContent(data: data, onRefresh: controller.refresh),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.data, required this.onRefresh});

  final DashboardData data;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final runtimeColor = data.runtime.running
        ? AppColors.success
        : Theme.of(context).colorScheme.outline;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const SectionTitle('System status'),
          const SizedBox(height: AppSpacing.md),
          StatusCard(
            title: 'Robot Control API',
            status: data.health.isHealthy ? 'Online' : data.health.status,
            subtitle: data.health.service,
            icon: Icons.cloud_done_outlined,
            color: data.health.isHealthy ? AppColors.success : AppColors.error,
          ),
          const SizedBox(height: AppSpacing.sm),
          StatusCard(
            title: 'Robot Runtime',
            status: data.runtime.status,
            subtitle: data.runtime.pid == null
                ? null
                : 'PID ${data.runtime.pid}',
            icon: Icons.smart_toy_outlined,
            color: runtimeColor,
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionTitle('Runtime project'),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                InfoTile(
                  title: 'Project',
                  value: data.project.name,
                  icon: Icons.inventory_2_outlined,
                ),
                const Divider(height: 1),
                InfoTile(
                  title: 'Version',
                  value: data.project.version,
                  icon: Icons.sell_outlined,
                ),
                const Divider(height: 1),
                InfoTile(
                  title: 'Python',
                  value: data.project.pythonVersion ?? 'Unknown',
                  icon: Icons.code,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionTitle('Capabilities'),
          const SizedBox(height: AppSpacing.sm),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.65,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _MetricCard(
                label: 'Motion',
                value: data.motionSummary.total,
                icon: Icons.directions_walk_outlined,
              ),
              _MetricCard(
                label: 'Audio',
                value: data.audioCount,
                icon: Icons.graphic_eq_outlined,
              ),
              _MetricCard(
                label: 'Vision',
                value: data.visionCount,
                icon: Icons.visibility_outlined,
              ),
              _MetricCard(
                label: 'Controller',
                value: data.controllerCount,
                icon: Icons.sports_esports_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionTitle('Services'),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                for (var index = 0; index < data.services.length; index++) ...[
                  _ServiceTile(service: data.services[index]),
                  if (index < data.services.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Updated ${TimeOfDay.fromDateTime(data.updatedAt).format(context)}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service});

  final ServiceInfo service;

  @override
  Widget build(BuildContext context) {
    final color = service.health.healthy
        ? AppColors.success
        : AppColors.warning;
    return ListTile(
      leading: Icon(
        service.health.healthy
            ? Icons.check_circle_outline
            : Icons.warning_amber,
        color: color,
      ),
      title: Text(service.service),
      subtitle: Text(service.status.status),
      trailing: Text('${service.capabilityCount}'),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.failure, required this.onRefresh});

  final DashboardFailure failure;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final (title, icon) = switch (failure.kind) {
      DashboardFailureKind.offline => ('API offline', Icons.cloud_off_outlined),
      DashboardFailureKind.timeout => (
        'Request timed out',
        Icons.timer_off_outlined,
      ),
      DashboardFailureKind.http => ('API error', Icons.http_outlined),
      DashboardFailureKind.invalidResponse => (
        'Invalid API response',
        Icons.data_object_outlined,
      ),
      DashboardFailureKind.unknown => (
        'Unable to load dashboard',
        Icons.error_outline,
      ),
    };
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(failure.message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ),
        ],
      ),
    );
  }
}
