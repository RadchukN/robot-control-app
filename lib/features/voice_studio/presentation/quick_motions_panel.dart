part of 'voice_studio_screen.dart';

/// Thin view over the existing [MotionController]. All command sending,
/// correlation, dry_run handling and the unknown-outcome lock stay there.
class _QuickMotionsPanel extends ConsumerWidget {
  const _QuickMotionsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = ref.watch(motionProvider);
    final controller = ref.read(motionProvider.notifier);
    final demo = ref.watch(voiceDemoModeProvider);
    final busy = const {
      MotionPlaybackStatus.sending,
      MotionPlaybackStatus.playing,
      MotionPlaybackStatus.stopping,
    }.contains(motion.playbackStatus);
    // Demo Mode never starts robot motion; Stop is a safety action and stays.
    final canSend = !demo && motion.robotConnected && !busy;
    final hello = motion.quickGestures
        .where((gesture) => gesture.id == 'hello')
        .firstOrNull;
    final recorded = motion.savedMotions
        .where((item) => item.recordedFilename != null)
        .toList(growable: false);
    final note = demo
        ? 'Demo Mode: motion buttons are disabled. Stop stays available and '
              'sends a real Stop.'
        : !motion.robotConnected
        ? 'Robot not connected. Motion commands unavailable.'
        : null;

    return _Card(
      minHeight: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardHeader(
            icon: Icons.sports_esports_outlined,
            title: 'Quick Motions',
            subtitle: 'Send simple motion commands to the robot.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SoftButton(
                  key: const Key('quick-wave'),
                  label: 'Wave Hand',
                  icon: Icons.waving_hand_outlined,
                  color: _blue,
                  background: _blueSoft,
                  height: 42,
                  onTap: canSend && hello != null
                      ? () => controller.playGesture(hello)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SoftButton(
                  key: const Key('quick-stop'),
                  label: 'Stop',
                  icon: Icons.stop_rounded,
                  color: _red,
                  background: _redSoft,
                  height: 42,
                  onTap: motion.robotConnected ? controller.stop : null,
                ),
              ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(
              note,
              key: const Key('quick-note'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _text(11, height: 14 / 11, color: _amberText),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recorded Motions',
                  style: _text(13, height: 17 / 13, weight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Refresh motion catalog',
                visualDensity: VisualDensity.compact,
                onPressed: motion.serviceLoading ? null : controller.refresh,
                icon: const Icon(Icons.refresh_rounded, size: 18),
              ),
              TextButton.icon(
                onPressed: () => context.go(AppRoutes.motion),
                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                label: const Text('Manage'),
              ),
            ],
          ),
          Expanded(
            child: recorded.isEmpty
                ? Center(
                    child: Text(
                      motion.serviceLoading
                          ? 'Loading motion catalog…'
                          : motion.error ??
                                'No recorded motions in the catalog.',
                      textAlign: TextAlign.center,
                      style: _text(12, height: 16 / 12, color: _muted),
                    ),
                  )
                : ListView.separated(
                    key: const Key('quick-recorded'),
                    itemCount: recorded.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = recorded[index];
                      return _RecordedMotionRow(
                        name: item.name,
                        type: item.type,
                        onPlay: canSend
                            ? () => controller.sendRecordedMotion(
                                item.recordedFilename!,
                              )
                            : null,
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          _MotionStatusBar(state: motion),
        ],
      ),
    );
  }
}

class _RecordedMotionRow extends StatelessWidget {
  const _RecordedMotionRow({
    required this.name,
    required this.type,
    required this.onPlay,
  });

  final String name;
  final String type;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF6F7FC),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(Icons.description_outlined, size: 18, color: _muted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _text(12, height: 16 / 12, weight: FontWeight.w600),
              ),
              Text(
                type,
                maxLines: 1,
                style: _text(10, height: 13 / 10, color: _muted),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Play $name',
          visualDensity: VisualDensity.compact,
          onPressed: onPlay,
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
        ),
      ],
    ),
  );
}

class _MotionStatusBar extends StatelessWidget {
  const _MotionStatusBar({required this.state});

  final MotionState state;

  @override
  Widget build(BuildContext context) {
    final status = state.playbackStatus;
    final label = switch (status) {
      MotionPlaybackStatus.idle => 'Ready',
      MotionPlaybackStatus.sending => 'Sending to robot…',
      MotionPlaybackStatus.playing => 'Playing on robot…',
      MotionPlaybackStatus.paused => 'Paused',
      MotionPlaybackStatus.stopping => 'Stopping…',
      MotionPlaybackStatus.finished => 'Completed',
      MotionPlaybackStatus.simulated => simulationOnlyLabel,
      MotionPlaybackStatus.stopped => 'Stopped',
      MotionPlaybackStatus.error => 'Error',
      MotionPlaybackStatus.busy => 'Robot busy',
      MotionPlaybackStatus.unavailable => 'Unavailable',
    };
    final color = switch (status) {
      MotionPlaybackStatus.finished => _green,
      MotionPlaybackStatus.error => _red,
      MotionPlaybackStatus.busy ||
      MotionPlaybackStatus.unavailable ||
      MotionPlaybackStatus.simulated => _amberText,
      _ => _purple,
    };
    return Container(
      key: const Key('quick-status'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${state.currentMotionName ?? 'Motion'} · $label',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _text(
          12,
          height: 16 / 12,
          weight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
