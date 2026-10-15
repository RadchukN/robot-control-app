import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/core/theme/app_spacing.dart';
import 'package:robot_control_app/features/dashboard/application/dashboard_controller.dart';
import 'package:robot_control_app/features/dashboard/dashboard_failure.dart';
import 'package:robot_control_app/features/dashboard/presentation/dashboard_view.dart';
import 'package:robot_control_app/shared/widgets/loading_view.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-1, -1),
          end: Alignment(1, 1),
          colors: [Color(0xFFF7FAFF), Color(0xFFECF1FF), Color(0xFFFEFEFF)],
          stops: [0, .54, 1],
        ),
      ),
      child: dashboard.when(
        loading: () => const LoadingView(message: 'Loading robot status...'),
        error: (error, _) => _DashboardError(
          failure: DashboardFailure.from(error),
          onRefresh: controller.refresh,
        ),
        data: (data) =>
            DashboardView(data: data, onRefresh: controller.refresh),
      ),
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
