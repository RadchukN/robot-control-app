import 'package:flutter/material.dart';
import 'package:robot_control_app/shared/widgets/feature_placeholder.dart';

class AudioScreen extends StatelessWidget {
  const AudioScreen({super.key});

  @override
  Widget build(BuildContext context) => const FeaturePlaceholder(
        title: 'Audio',
        description: 'Audio capabilities will appear here without changing app navigation.',
        icon: Icons.graphic_eq_rounded,
      );
}
