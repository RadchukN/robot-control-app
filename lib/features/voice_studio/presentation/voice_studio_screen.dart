import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:robot_control_app/core/routing/app_routes.dart';
import 'package:robot_control_app/core/theme/app_spacing.dart';
import 'package:robot_control_app/features/motion/application/motion_state.dart';
import 'package:robot_control_app/features/voice_studio/application/realtime_voice_controller.dart';
import 'package:robot_control_app/features/voice_studio/application/tts_controller.dart';
import 'package:robot_control_app/features/voice_studio/application/voice_studio_providers.dart';
import 'package:robot_control_app/features/voice_studio/domain/transcript_buffer.dart';
import 'package:robot_control_app/features/voice_studio/domain/voice_models.dart';
import 'package:robot_control_app/services/robot_connection.dart';

part 'voice_studio_style.dart';
part 'realtime_panel.dart';
part 'transcript_panel.dart';
part 'tts_panel.dart';
part 'quick_motions_panel.dart';
part 'connection_panel.dart';

class VoiceStudioScreen extends ConsumerWidget {
  const VoiceStudioScreen({super.key});

  static const wideBreakpoint = 1100.0;
  static const mediumBreakpoint = 720.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) => DecoratedBox(
    key: const Key('voice-studio-screen'),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_backgroundTop, _backgroundBottom],
      ),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            compact ? 12 : 16,
            compact ? 14 : 18,
            compact ? 12 : 16,
            AppSpacing.lg,
          ),
          child: _VoiceStudioLayout(
            width: constraints.maxWidth - (compact ? 24 : 32),
          ),
        );
      },
    ),
  );
}

class _VoiceStudioLayout extends StatelessWidget {
  const _VoiceStudioLayout({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox.square(dimension: 12);
    if (width >= VoiceStudioScreen.wideBreakpoint) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StudioHeader(),
          gap,
          SizedBox(
            height: 292,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 61, child: _RealtimePanel(fill: true)),
                gap,
                Expanded(flex: 39, child: _TranscriptPanel()),
              ],
            ),
          ),
          gap,
          SizedBox(
            height: 384,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 46, child: _TtsPanel(fill: true)),
                gap,
                Expanded(flex: 27, child: _QuickMotionsPanel()),
                gap,
                Expanded(flex: 27, child: _ConnectionPanel()),
              ],
            ),
          ),
        ],
      );
    }
    if (width >= VoiceStudioScreen.mediumBreakpoint) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StudioHeader(),
          gap,
          _RealtimePanel(fill: false),
          gap,
          SizedBox(height: 320, child: _TranscriptPanel()),
          gap,
          _TtsPanel(fill: false),
          gap,
          SizedBox(
            height: 420,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _QuickMotionsPanel()),
                gap,
                Expanded(child: _ConnectionPanel()),
              ],
            ),
          ),
        ],
      );
    }
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StudioHeader(),
        gap,
        _RealtimePanel(fill: false),
        gap,
        SizedBox(height: 340, child: _TranscriptPanel()),
        gap,
        _TtsPanel(fill: false),
        gap,
        SizedBox(height: 380, child: _QuickMotionsPanel()),
        gap,
        SizedBox(height: 460, child: _ConnectionPanel()),
      ],
    );
  }
}

class _StudioHeader extends ConsumerWidget {
  const _StudioHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(voiceDemoModeProvider);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Voice Studio',
          style: _text(28, height: 36 / 28, weight: FontWeight.w700),
        ),
        Text(
          'Realtime conversation, text-to-speech and quick motions for G1.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _text(13, height: 17 / 13, color: _muted),
        ),
      ],
    );
    final toggle = Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _outline),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            demo ? Icons.science_outlined : Icons.cloud_off_outlined,
            size: 16,
            color: demo ? _amberText : _muted,
          ),
          const SizedBox(width: 6),
          Text(
            'Demo Mode',
            style: _text(12, height: 16 / 12, weight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          Switch(
            key: const Key('voice-demo-toggle'),
            value: demo,
            activeTrackColor: _purple,
            onChanged: ref.read(voiceDemoModeProvider.notifier).set,
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 640
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 10), toggle],
            )
          : Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 16),
                toggle,
              ],
            ),
    );
  }
}
