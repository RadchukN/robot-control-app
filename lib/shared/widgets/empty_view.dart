import 'package:flutter/material.dart';
import 'package:robot_control_app/core/theme/app_spacing.dart';

class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    super.key,
  });

  final String title;
  final String? message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    // Centered when it fits; scrolls on short screens instead of clipping.
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
        ),
        child: Center(child: _content(context)),
      ),
    ),
  );

  Widget _content(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: AppSpacing.md),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (message != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(message!, textAlign: TextAlign.center),
        ],
      ],
    ),
  );
}
