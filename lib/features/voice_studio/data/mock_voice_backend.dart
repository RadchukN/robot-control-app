import 'dart:async';

import 'package:robot_control_app/features/voice_studio/data/voice_backend.dart';
import 'package:robot_control_app/features/voice_studio/domain/voice_models.dart';

/// Offline Demo Mode backend. It never opens a connection or touches the
/// robot; every event it emits is flagged as simulated, and its timing is
/// fixed so tests can drive it with fake time.
class MockVoiceBackend implements VoiceBackend {
  MockVoiceBackend({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const tick = Duration(milliseconds: 120);

  static const demoCapabilities = VoiceCapabilities(
    languages: {'cs-CZ', 'en-US', 'uk-UA', 'de-DE'},
    voices: {
      'cs-CZ': ['Demo voice A', 'Demo voice B'],
      'en-US': ['Demo voice A', 'Demo voice B'],
      'uk-UA': ['Demo voice A', 'Demo voice B'],
      'de-DE': ['Demo voice A', 'Demo voice B'],
    },
    speeds: [0.75, 1.0, 1.25, 1.5],
    realtimeConversation: true,
  );

  static const script = [
    (
      'Hello! Can you introduce yourself?',
      'Hello! This is a simulated G1 voice demo. Nothing is sent to the robot.',
    ),
    (
      'Can you wave your hand?',
      'This is a demo reply. Voice never triggers robot gestures automatically.',
    ),
  ];

  static const _levels = [0.22, 0.56, 0.84, 0.47, 0.95, 0.62, 0.31, 0.74];

  final DateTime Function() _now;
  final _events = StreamController<VoiceBackendEvent>.broadcast();
  final _timers = <Timer>[];
  Timer? _ambient;
  Timer? _ttsTimer;
  Timer? _ttsLevels;
  String? _ttsRequestId;
  int _conversationGeneration = 0;
  bool _conversationActive = false;
  int _sequence = 0;
  int _utterance = 0;
  int _levelIndex = 0;

  @override
  bool get isSimulated => true;

  @override
  VoiceCapabilities get capabilities => demoCapabilities;

  @override
  String? get unavailableReason => null;

  @override
  Stream<VoiceBackendEvent> get events => _events.stream;

  void _emit(VoiceBackendEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  double _nextLevel([double scale = 1]) =>
      _levels[_levelIndex++ % _levels.length] * scale;

  @override
  Future<void> startConversation() async {
    if (_conversationActive) {
      throw StateError('A simulated conversation is already active.');
    }
    if (_ttsRequestId != null) {
      throw StateError('Simulated speaker is busy with text-to-speech.');
    }
    _conversationActive = true;
    final generation = ++_conversationGeneration;
    _emit(const VoiceSessionEvent(VoiceSessionState.starting));
    final steps = <(Duration, void Function())>[
      (
        const Duration(milliseconds: 300),
        () {
          _emit(
            const VoiceDeviceEvent(
              microphone: DeviceStatus.simulated,
              speaker: DeviceStatus.simulated,
            ),
          );
          _emit(const VoiceSessionEvent(VoiceSessionState.listening));
        },
      ),
    ];
    for (final (question, answer) in script) {
      final userId = 'sim-user-${++_utterance}';
      // Stamped when first heard so turns stay in conversation order.
      DateTime? userStarted;
      final words = question.split(' ');
      for (var i = 1; i <= words.length; i++) {
        final text = words.take(i).join(' ');
        final last = i == words.length;
        steps.add((
          const Duration(milliseconds: 200),
          () {
            _emit(VoiceAudioLevelEvent(AudioDirection.input, _nextLevel()));
            _transcript(
              userId,
              TranscriptRole.user,
              text,
              last,
              userStarted ??= _now(),
            );
          },
        ));
      }
      final robotId = 'sim-robot-${++_utterance}';
      DateTime? robotStarted;
      steps
        ..add((
          const Duration(milliseconds: 150),
          () => _emit(const VoiceSessionEvent(VoiceSessionState.thinking)),
        ))
        ..add((
          const Duration(milliseconds: 500),
          () {
            _emit(const VoiceSessionEvent(VoiceSessionState.speaking));
            final half = answer.split(' ');
            _transcript(
              robotId,
              TranscriptRole.robot,
              half.take(half.length ~/ 2).join(' '),
              false,
              robotStarted ??= _now(),
            );
          },
        ));
      for (var i = 0; i < 8; i++) {
        steps.add((
          tick,
          () =>
              _emit(VoiceAudioLevelEvent(AudioDirection.output, _nextLevel())),
        ));
      }
      steps
        ..add((
          tick,
          () => _transcript(
            robotId,
            TranscriptRole.robot,
            answer,
            true,
            robotStarted ??= _now(),
          ),
        ))
        ..add((
          const Duration(milliseconds: 150),
          () => _emit(const VoiceSessionEvent(VoiceSessionState.listening)),
        ));
    }
    _runSteps(steps, generation, onDone: _startAmbient);
  }

  void _transcript(
    String id,
    TranscriptRole role,
    String text,
    bool isFinal,
    DateTime timestamp,
  ) => _emit(
    VoiceTranscriptEvent(
      TranscriptEntry(
        id: id,
        role: role,
        text: text,
        isFinal: isFinal,
        timestamp: timestamp,
        sequence: ++_sequence,
        simulated: true,
      ),
    ),
  );

  void _runSteps(
    List<(Duration, void Function())> steps,
    int generation, {
    void Function()? onDone,
  }) {
    var index = 0;
    void next() {
      if (generation != _conversationGeneration) return;
      if (index >= steps.length) {
        onDone?.call();
        return;
      }
      final (delay, action) = steps[index++];
      _timers.add(
        Timer(delay, () {
          if (generation != _conversationGeneration) return;
          action();
          next();
        }),
      );
    }

    next();
  }

  void _startAmbient() {
    _ambient?.cancel();
    _ambient = Timer.periodic(
      tick,
      (_) =>
          _emit(VoiceAudioLevelEvent(AudioDirection.input, _nextLevel(0.25))),
    );
  }

  void _cancelConversationTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _ambient?.cancel();
    _ambient = null;
  }

  @override
  Future<void> stopConversation() async {
    if (!_conversationActive) return;
    final generation = ++_conversationGeneration;
    _cancelConversationTimers();
    _emit(const VoiceSessionEvent(VoiceSessionState.stopping));
    _timers.add(
      Timer(const Duration(milliseconds: 150), () {
        if (generation != _conversationGeneration) return;
        _conversationActive = false;
        _emit(const VoiceSessionEvent(VoiceSessionState.idle));
      }),
    );
  }

  @override
  Future<void> speak(TtsRequest request) async {
    if (_conversationActive) {
      throw StateError('Simulated speaker is owned by the conversation.');
    }
    if (_ttsRequestId != null) {
      throw StateError('Simulated speech is already playing.');
    }
    if (!capabilities.languages.contains(request.language)) {
      throw StateError('Unsupported language ${request.language}.');
    }
    _ttsRequestId = request.requestId;
    final duration = Duration(
      milliseconds: (request.text.length * 55 / request.speed)
          .clamp(800, 8000)
          .round(),
    );
    _ttsTimer = Timer(const Duration(milliseconds: 150), () {
      _emit(
        TtsStatusEvent(
          request.requestId,
          TtsEventPhase.speaking,
          simulated: true,
        ),
      );
      _ttsLevels = Timer.periodic(
        tick,
        (_) =>
            _emit(VoiceAudioLevelEvent(AudioDirection.output, _nextLevel(0.8))),
      );
      _ttsTimer = Timer(duration, () {
        _ttsLevels?.cancel();
        _ttsRequestId = null;
        _emit(
          TtsStatusEvent(
            request.requestId,
            TtsEventPhase.completed,
            simulated: true,
          ),
        );
      });
    });
  }

  @override
  Future<void> stopSpeaking(String requestId) async {
    if (requestId != _ttsRequestId) return;
    _ttsTimer?.cancel();
    _ttsLevels?.cancel();
    _ttsTimer = Timer(const Duration(milliseconds: 100), () {
      _ttsRequestId = null;
      _emit(
        TtsStatusEvent(requestId, TtsEventPhase.cancelled, simulated: true),
      );
    });
  }

  @override
  void dispose() {
    _conversationGeneration++;
    _cancelConversationTimers();
    _ttsTimer?.cancel();
    _ttsLevels?.cancel();
    _events.close();
  }
}
