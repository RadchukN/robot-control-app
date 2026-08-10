import 'package:flutter/material.dart';
import 'package:robot_control_app/shared/widgets/feature_placeholder.dart';

class MotionScreen extends StatelessWidget {
  const MotionScreen({super.key});

  @override
  Widget build(BuildContext context) => const FeaturePlaceholder(
        title: 'Motion',
        description: 'Discovered motions will appear here in a future feature stage.',
        icon: Icons.directions_walk_rounded,
      );
}
