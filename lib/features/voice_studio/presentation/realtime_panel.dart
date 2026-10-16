part of 'voice_studio_screen.dart';

class _RealtimePanel extends ConsumerWidget {
  const _RealtimePanel({required this.fill});

  final bool fill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(realtimeVoiceProvider);
    final controller = ref.read(realtimeVoiceProvider.notifier);
    final header = _CardHeader(
      icon: Icons.mic_none_rounded,
      title: 'Realtime Speaking',
      subtitle: 'Have a natural conversation with Unitree G1 using AI.',
      large: true,
      trailing: [
        if (state.simulated) ...[const SizedBox(width: 8), const _DemoBadge()],
      ],
    );
    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SessionTile(state: state),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _PrimaryButton(
                key: const Key('voice-start'),
                label: 'Start AI Conversation',
                icon: Icons.chat_bubble_outline_rounded,
                onTap: state.canStart ? controller.start : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _SoftButton(
                key: const Key('voice-stop'),
                label: 'Stop AI',
                icon: Icons.stop_circle_rounded,
                color: _red,
                background: _redSoft,
                height: 48,
                onTap: state.canStop ? controller.stop : null,
              ),
            ),
          ],
        ),
      ],
    );
    final devices = Row(
      children: [
        Expanded(
          child: _DeviceIndicator(
            key: const Key('voice-mic'),
            label: 'Mic',
            icon: Icons.mic_rounded,
            status: state.microphone,
          ),
        ),
        Expanded(
          child: _DeviceIndicator(
            key: const Key('voice-speaker'),
            label: 'Speaker',
            icon: Icons.volume_up_rounded,
            status: state.speaker,
          ),
        ),
      ],
    );
    final waveform = _Waveform(
      levels: state.waveform,
      active: state.session.isActive,
    );
    final simulatedNote = state.simulated
        ? Text(
            'Simulation only · No real robot audio output',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _text(11, height: 14 / 11, color: _muted),
          )
        : null;

    return _Card(
      fill: fill,
      minHeight: 250,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.maxWidth >= 620;
          final body = side
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: controls),
                    Container(
                      width: 1,
                      height: 110,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      color: _outline,
                    ),
                    SizedBox(width: 200, child: devices),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [controls, const SizedBox(height: 14), devices],
                );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              if (simulatedNote != null) ...[
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: simulatedNote,
                ),
              ],
              const SizedBox(height: 12),
              body,
              const SizedBox(height: 12),
              if (fill)
                Expanded(child: waveform)
              else
                SizedBox(height: 64, child: waveform),
            ],
          );
        },
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.state});

  final RealtimeVoiceState state;

  @override
  Widget build(BuildContext context) {
    final session = state.session;
    final (label, detail, color) = switch (session) {
      VoiceSessionState.idle => (
        state.simulated || state.backendIdle ? 'Idle' : 'Checking',
        state.canStart
            ? 'Ready to start conversation'
            : state.unavailableReason ?? 'Voice backend unavailable',
        _purple,
      ),
      VoiceSessionState.starting => (
        'Starting',
        'Opening the voice session…',
        _blue,
      ),
      VoiceSessionState.listening => ('Listening', 'Speak now…', _green),
      VoiceSessionState.thinking => ('Thinking', 'Preparing a reply…', _blue),
      VoiceSessionState.speaking => (
        'Speaking',
        state.simulated
            ? 'Simulated reply · the robot is silent'
            : 'G1 is speaking',
        _purple,
      ),
      VoiceSessionState.stopping => ('Stopping', 'Ending the session…', _amber),
      VoiceSessionState.error => (
        'Error',
        state.lastError ?? 'Voice session failed',
        _red,
      ),
      VoiceSessionState.disconnected => (
        state.linkConnected ? 'Reconnecting' : 'Disconnected',
        state.linkConnected
            ? 'Checking the previous session and ownership…'
            : 'Robot link is down. Voice is unavailable.',
        _red,
      ),
      VoiceSessionState.busy => (
        'Busy',
        state.lastError ?? 'Speaker is in use',
        _amber,
      ),
    };
    return Container(
      key: const Key('voice-session-tile'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.settings_input_antenna_rounded, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: _text(17, height: 22 / 17, weight: FontWeight.w700),
                ),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _text(12, height: 16 / 12, color: _body),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

_Tone _deviceTone(DeviceStatus status) => switch (status) {
  DeviceStatus.ready => _Tone.connected,
  DeviceStatus.unknown => _Tone.unknown,
  DeviceStatus.unavailable => _Tone.unavailable,
  DeviceStatus.simulated => _Tone.demo,
};

String _deviceLabel(DeviceStatus status) => switch (status) {
  DeviceStatus.ready => 'Ready',
  DeviceStatus.unknown => 'Unknown',
  DeviceStatus.unavailable => 'Unavailable',
  DeviceStatus.simulated => 'Demo',
};

class _DeviceIndicator extends StatelessWidget {
  const _DeviceIndicator({
    super.key,
    required this.label,
    required this.icon,
    required this.status,
  });

  final String label;
  final IconData icon;
  final DeviceStatus status;

  @override
  Widget build(BuildContext context) {
    final tone = _deviceTone(status);
    return Semantics(
      label: '$label ${_deviceLabel(status)}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: tone.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: tone.color.withValues(alpha: 0.18),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Icon(icon, color: tone.color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _text(13, height: 17 / 13, weight: FontWeight.w600),
          ),
          Text(
            _deviceLabel(status),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _text(
              12,
              height: 16 / 12,
              weight: FontWeight.w600,
              color: tone.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.levels, required this.active});

  final List<double> levels;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('voice-waveform'),
    decoration: BoxDecoration(
      color: _blueSoft.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(14),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: CustomPaint(
        painter: _WaveformPainter(levels, active),
        size: Size.infinite,
      ),
    ),
  );
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter(this.levels, this.active);

  final List<double> levels;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty || size.isEmpty) return;
    final slot = size.width / (levels.length + 8);
    final barWidth = (slot * 0.45).clamp(2.0, 5.0);
    final start = slot * 4;
    final mid = size.height / 2;
    final maxHeight = size.height - 16;
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF4F7BFF), Color(0xFF8B5CF6), Color(0xFF4F7BFF)],
      ).createShader(Offset.zero & size)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;
    for (var i = 0; i < levels.length; i++) {
      // Taper the edges like the reference waveform.
      final edge = 1 - ((i - levels.length / 2).abs() / (levels.length / 2));
      final level = active ? levels[i] * (0.35 + 0.65 * edge) : 0.0;
      final height = (4 + level * maxHeight).clamp(4.0, maxHeight);
      final x = start + slot * i + slot / 2;
      paint.color = Colors.white.withValues(alpha: active ? 1 : 0.4);
      canvas.drawLine(
        Offset(x, mid - height / 2),
        Offset(x, mid + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.active != active || !identical(old.levels, levels);
}
