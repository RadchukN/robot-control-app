part of 'voice_studio_screen.dart';

class _ConnectionPanel extends ConsumerStatefulWidget {
  const _ConnectionPanel();

  @override
  ConsumerState<_ConnectionPanel> createState() => _ConnectionPanelState();
}

class _ConnectionPanelState extends ConsumerState<_ConnectionPanel> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(voiceEventLogProvider, (_, next) {
      if (!next.autoScroll) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    });
    final link = ref.watch(robotLinkProvider);
    final voice = ref.watch(realtimeVoiceProvider);
    final tts = ref.watch(ttsProvider);
    final log = ref.watch(voiceEventLogProvider);
    final logController = ref.read(voiceEventLogProvider.notifier);

    final rows = <(String, (String, _Tone))>[
      ('WebSocket', _webSocket(link.status)),
      ('Authentication', _authentication(link.status)),
      ('Telemetry', _telemetry(link)),
      (
        'Voice backend',
        voice.simulated
            ? ('Demo (mock backend)', _Tone.demo)
            : voice.backendAvailable
            ? ('Available', _Tone.connected)
            : ('Unavailable', _Tone.unavailable),
      ),
      (
        'Voice session',
        (
          _sessionLabel(voice.session),
          voice.simulated ? _Tone.demo : _sessionTone(voice.session),
        ),
      ),
      (
        'Microphone',
        (_deviceLabel(voice.microphone), _deviceTone(voice.microphone)),
      ),
      ('Speaker', (_deviceLabel(voice.speaker), _deviceTone(voice.speaker))),
    ];
    final lastError = voice.lastError ?? tts.lastError ?? link.message;

    return _Card(
      minHeight: 340,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardHeader(
            icon: Icons.sensors_rounded,
            title: 'Connection & Voice State',
          ),
          const SizedBox(height: 10),
          for (final (label, (value, tone)) in rows)
            _StateRow(label: label, value: value, tone: tone),
          _StateRow(
            label: 'Last error',
            value: lastError ?? 'None',
            tone: lastError == null ? _Tone.unknown : _Tone.disconnected,
            valueColor: lastError == null ? _muted : _red,
          ),
          const Divider(height: 16, color: _outline),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Event Log',
                  style: _text(13, height: 17 / 13, weight: FontWeight.w600),
                ),
              ),
              Text(
                'Auto-scroll',
                style: _text(11, height: 14 / 11, color: _muted),
              ),
              Transform.scale(
                scale: 0.75,
                child: Switch(
                  key: const Key('event-log-autoscroll'),
                  value: log.autoScroll,
                  activeTrackColor: _blue,
                  onChanged: logController.setAutoScroll,
                ),
              ),
              IconButton(
                tooltip: 'Clear event log',
                visualDensity: VisualDensity.compact,
                onPressed: log.entries.isEmpty ? null : logController.clear,
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              ),
            ],
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF6F7FC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: log.entries.isEmpty
                  ? Center(
                      child: Text(
                        'No events yet.',
                        style: _text(11, height: 14 / 11, color: _muted),
                      ),
                    )
                  : ListView.builder(
                      key: const Key('event-log'),
                      controller: _scroll,
                      padding: const EdgeInsets.all(8),
                      itemCount: log.entries.length,
                      itemBuilder: (context, index) =>
                          _LogRow(entry: log.entries[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

(String, _Tone) _webSocket(RobotLinkStatus status) => switch (status) {
  RobotLinkStatus.connected ||
  RobotLinkStatus.awaitingTelemetry ||
  RobotLinkStatus.degraded => ('Connected', _Tone.connected),
  RobotLinkStatus.connecting => ('Connecting', _Tone.connecting),
  RobotLinkStatus.reconnecting => ('Reconnecting', _Tone.connecting),
  RobotLinkStatus.disconnected || RobotLinkStatus.authenticationRequired => (
    'Disconnected',
    _Tone.disconnected,
  ),
};

(String, _Tone) _authentication(RobotLinkStatus status) => switch (status) {
  RobotLinkStatus.connected ||
  RobotLinkStatus.awaitingTelemetry ||
  RobotLinkStatus.degraded => ('Accepted', _Tone.connected),
  RobotLinkStatus.authenticationRequired => (
    'Token rejected or missing',
    _Tone.disconnected,
  ),
  RobotLinkStatus.connecting ||
  RobotLinkStatus.reconnecting => ('Connecting', _Tone.connecting),
  RobotLinkStatus.disconnected => ('Unknown', _Tone.unknown),
};

(String, _Tone) _telemetry(RobotLinkState link) {
  final at = link.lastTelemetryAt;
  final time = at == null ? '' : ' · ${clockTime(at)}';
  return switch (link.status) {
    RobotLinkStatus.connected => ('Fresh$time', _Tone.connected),
    RobotLinkStatus.degraded => ('Stale$time', _Tone.unavailable),
    RobotLinkStatus.awaitingTelemetry => ('Waiting', _Tone.connecting),
    _ => ('Unknown', _Tone.unknown),
  };
}

String _sessionLabel(VoiceSessionState state) =>
    state.name[0].toUpperCase() + state.name.substring(1);

_Tone _sessionTone(VoiceSessionState state) => switch (state) {
  VoiceSessionState.disconnected ||
  VoiceSessionState.error => _Tone.disconnected,
  VoiceSessionState.starting || VoiceSessionState.stopping => _Tone.connecting,
  VoiceSessionState.busy => _Tone.unavailable,
  VoiceSessionState.idle => _Tone.unknown,
  _ => _Tone.connected,
};

class _StateRow extends StatelessWidget {
  const _StateRow({
    required this.label,
    required this.value,
    required this.tone,
    this.valueColor,
  });

  final String label;
  final String value;
  final _Tone tone;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.5),
    child: Row(
      children: [
        _ToneDot(tone.color),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _text(12, height: 16 / 12, color: _body),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _text(
              12,
              height: 16 / 12,
              weight: FontWeight.w600,
              color: valueColor ?? tone.color,
            ),
          ),
        ),
      ],
    ),
  );
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});

  final VoiceLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.level) {
      VoiceLogLevel.info => _green,
      VoiceLogLevel.warning => _amber,
      VoiceLogLevel.error => _red,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _ToneDot(color),
          ),
          const SizedBox(width: 6),
          Text(
            clockTime(entry.time),
            style: _text(11, height: 15 / 11, color: _muted),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              entry.simulated ? '${entry.message} (demo)' : entry.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _text(11, height: 15 / 11, color: _body),
            ),
          ),
        ],
      ),
    );
  }
}
