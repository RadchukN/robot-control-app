import 'package:flutter/material.dart';
import 'package:robot_control_app/core/theme/app_spacing.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({this.message = 'Loading…', super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(message),
          ],
        ),
      );
}
