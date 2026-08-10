import 'package:flutter/material.dart';
import 'package:robot_control_app/core/theme/app_spacing.dart';
import 'package:robot_control_app/shared/widgets/empty_view.dart';
import 'package:robot_control_app/shared/widgets/section_title.dart';

class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({
    required this.title,
    required this.description,
    required this.icon,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(title),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: EmptyView(
                    title: '$title is ready for integration',
                    message: description,
                    icon: icon,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
