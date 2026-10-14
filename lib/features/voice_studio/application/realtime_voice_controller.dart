import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/features/voice_studio/application/voice_studio_providers.dart';
import 'package:robot_control_app/features/voice_studio/data/voice_backend.dart';
import 'package:robot_control_app/features/voice_studio/domain/transcript_buffer.dart';
import 'package:robot_control_app/features/voice_studio/domain/voice_models.dart';
import 'package:robot_control_app/services/robot_connection.dart';

const _unset = Object();

@immutable
class RealtimeVoiceState {
  const RealtimeVoiceState({
    required this.session,
    required this.microphone,
    required this.speaker,
    required this.waveform,
    required this.transcript,
    required this.simulated,
    required this.linkConnected,
    this.unavailableReason,
    this.lastError,
  });

  static const waveformSamples = 48;

  final VoiceSessionState session;
  final DeviceStatus microphone;
  final DeviceStatus speaker;

  /// Most recent audio levels, oldest first, each 0..1.
  final List<double> waveform;
  final List<TranscriptEntry> transcript;
  final bool simulated;
  final bool linkConnected;
  final String? unavailableReason;
  final String? lastError;

  bool get canStart =>
      !session.isActive &&
      session != VoiceSessionState.stopping &&
      (simulated || (linkConnected && unavailableReason == null));

  bool get canStop => session.isActive;

  String get transcriptText => TranscriptBuffer.format(transcript);

  RealtimeVoiceState copyWith({
    VoiceSessionState? session,
    DeviceStatus? microphone,
    DeviceStatus? speaker,
    List<double>? waveform,
    List<TranscriptEntry>? transcript,
    bool? linkConnected,
    Object? lastError = _unset,
  }) => RealtimeVoiceState(
    session: session ?? this.session,
    microphone: microphone ?? this.microphone,
    speaker: speaker ?? this.speaker,
    waveform: waveform ?? this.waveform,
    transcript: transcript ?? this.transcript,
    simulated: simulated,
    linkConnected: linkConnected ?? this.linkConnected,
    unavailableReason: unavailableReason,
    lastError: identical(lastError, _unset)
        ? this.lastError
        : lastError as String?,
  );
}

bool isRobotLinkOpen(RobotLinkStatus status) => const {
  RobotLinkStatus.connected,
  RobotLinkStatus.awaitingTelemetry,
  RobotLinkStatus.degraded,
}.contains(status);

/// Realtime conversation state. Independent of motion: nothing here can send
/// a motion command or trigger a gesture.
class RealtimeVoiceController extends Notifier<RealtimeVoiceState> {
  late VoiceBackend _backend;
  late TranscriptBuffer _transcript;

  @override
  RealtimeVoiceState build() {
    _backend = ref.watch(voiceBackendProvider);
    _transcript = TranscriptBuffer();
    final subscription = _backend.events.listen(_onEvent);
    ref.onDispose(subscription.cancel);
    ref.listen(
      robotLinkProvider.select((link) => isRobotLinkOpen(link.status)),
      (_, linked) => _onLink(linked),
    );
    final linked = isRobotLinkOpen(ref.read(robotLinkProvider).status);
    final simulated = _backend.isSimulated;
    return RealtimeVoiceState(
      session: simulated || linked
          ? VoiceSessionState.idle
          : VoiceSessionState.disconnected,
      microphone: _initialDevice(simulated, linked),
      speaker: _initialDevice(simulated, linked),
      waveform: List.filled(RealtimeVoiceState.waveformSamples, 0),
      transcript: const [],
      simulated: simulated,
      linkConnected: linked,
      unavailableReason: _backend.unavailableReason,
    );
  }

  static DeviceStatus _initialDevice(bool simulated, bool linked) => simulated
      ? DeviceStatus.simulated
      : linked
      ? DeviceStatus.unknown
      : DeviceStatus.unavailable;

  void _log(String message, {VoiceLogLevel level = VoiceLogLevel.info}) => ref
      .read(voiceEventLogProvider.notifier)
      .add(message, level: level, simulated: state.simulated);

  AudioSessionCoordinator get _audio => ref.read(audioSessionProvider.notifier);

  Future<void> start() async {
    if (!state.canStart) return;
    final backend = _backend;
    if (!_audio.acquire(AudioOwner.realtime)) {
      state = state.copyWith(
        session: VoiceSessionState.busy,
        lastError: 'Speaker is in use by text-to-speech. Stop speech first.',
      );
      _log('Conversation blocked: speaker busy', level: VoiceLogLevel.warning);
      return;
    }
    state = state.copyWith(
      session: VoiceSessionState.starting,
      lastError: null,
    );
    _log('Starting AI conversation');
    try {
      await backend.startConversation();
    } on Object catch (error) {
      if (!ref.mounted || !identical(backend, _backend)) return;
      _audio.release(AudioOwner.realtime);
      state = state.copyWith(
        session: VoiceSessionState.error,
        lastError: _message(error),
      );
      _log(
        'Conversation failed: ${_message(error)}',
        level: VoiceLogLevel.error,
      );
    }
  }

  Future<void> stop() async {
    if (!state.canStop) return;
    state = state.copyWith(session: VoiceSessionState.stopping);
    _log('Stopping AI conversation');
    await _backend.stopConversation();
  }

  void clearTranscript() {
    _transcript.clear();
    state = state.copyWith(transcript: const []);
    _log('Transcript cleared');
  }

  void _onLink(bool linked) {
    if (linked == state.linkConnected) return;
    if (state.simulated) {
      state = state.copyWith(linkConnected: linked);
      return;
    }
    if (!linked) {
      _audio.release(AudioOwner.realtime);
      state = state.copyWith(
        linkConnected: false,
        session: VoiceSessionState.disconnected,
        microphone: DeviceStatus.unavailable,
        speaker: DeviceStatus.unavailable,
        waveform: List.filled(RealtimeVoiceState.waveformSamples, 0),
      );
      _log('Voice disconnected with robot link', level: VoiceLogLevel.error);
      return;
    }
    // Reconnect never restarts a conversation by itself.
    state = state.copyWith(
      linkConnected: true,
      session: state.session == VoiceSessionState.disconnected
          ? VoiceSessionState.idle
          : state.session,
      microphone: DeviceStatus.unknown,
      speaker: DeviceStatus.unknown,
    );
  }

  void _onEvent(VoiceBackendEvent event) {
    if (!ref.mounted) return;
    switch (event) {
      case VoiceSessionEvent(state: final next, :final message):
        _onSession(next, message);
      case VoiceTranscriptEvent(:final entry):
        if (_transcript.apply(entry)) {
          state = state.copyWith(transcript: _transcript.entries);
        }
      case VoiceAudioLevelEvent(:final level):
        if (!state.session.isActive) return;
        final samples = [...state.waveform.skip(1), level.clamp(0.0, 1.0)];
        state = state.copyWith(waveform: samples);
      case VoiceDeviceEvent(:final microphone, :final speaker):
        state = state.copyWith(
          microphone: _device(microphone),
          speaker: _device(speaker),
        );
      case VoiceErrorEvent(:final code, :final message):
        _audio.release(AudioOwner.realtime);
        state = state.copyWith(
          session: VoiceSessionState.error,
          lastError: '$code: $message',
        );
        _log('Voice error $code: $message', level: VoiceLogLevel.error);
      case TtsStatusEvent():
        return;
    }
  }

  // A simulated backend can never report real hardware as ready.
  DeviceStatus _device(DeviceStatus status) =>
      state.simulated && status != DeviceStatus.unavailable
      ? DeviceStatus.simulated
      : status;

  void _onSession(VoiceSessionState next, String? message) {
    final current = state.session;
    if (current == next) return;
    // Late activity after Stop must not reopen the session.
    if (current == VoiceSessionState.stopping && next.isActive) return;
    if (current == VoiceSessionState.disconnected) return;
    final ended = const {
      VoiceSessionState.idle,
      VoiceSessionState.error,
      VoiceSessionState.disconnected,
    }.contains(next);
    if (ended) _audio.release(AudioOwner.realtime);
    state = state.copyWith(
      session: next,
      waveform: ended || next == VoiceSessionState.stopping
          ? List.filled(RealtimeVoiceState.waveformSamples, 0)
          : null,
      lastError: next == VoiceSessionState.error ? message : null,
    );
    _log(
      'Voice session: ${next.name}${message == null ? '' : ' — $message'}',
      level: next == VoiceSessionState.error
          ? VoiceLogLevel.error
          : VoiceLogLevel.info,
    );
  }
}

String _message(Object error) =>
    error is StateError ? error.message : error.toString();

final realtimeVoiceProvider =
    NotifierProvider<RealtimeVoiceController, RealtimeVoiceState>(
      RealtimeVoiceController.new,
      name: 'RealtimeVoiceProvider',
    );
