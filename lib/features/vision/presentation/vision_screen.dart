import 'package:flutter/material.dart';
import 'package:robot_control_app/shared/widgets/feature_placeholder.dart';

class VisionScreen extends StatelessWidget {
  const VisionScreen({super.key});

  @override
  Widget build(BuildContext context) => const FeaturePlaceholder(
        title: 'Vision',
        description: 'Vision information will appear here in a future feature stage.',
        icon: Icons.visibility_outlined,
      );
}
