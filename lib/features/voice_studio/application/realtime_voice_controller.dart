import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/features/voice_studio/application/voice_studio_providers.dart';
import 'package:robot_control_app/features/voice_studio/data/voice_backend.dart';
import 'package:robot_control_app/features/voice_studio/data/live_voice_backend.dart';
import 'package:robot_control_app/features/settings/application/audio_devices_controller.dart';
import 'package:robot_control_app/features/settings/data/audio_device_backend.dart';
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
    this.backendAvailable = false,
    this.backendIdle = false,
    this.liveCanStop = false,
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
  final bool backendAvailable;
  final bool backendIdle;
  final bool liveCanStop;

  bool get canStart =>
      !session.isActive &&
      session != VoiceSessionState.stopping &&
      (simulated || (linkConnected && backendAvailable && backendIdle));

  bool get canStop => simulated
      ? session.isActive || session == VoiceSessionState.stopping
      : liveCanStop ||
            session.isActive ||
            session == VoiceSessionState.stopping ||
            (session == VoiceSessionState.error && linkConnected);

  String get transcriptText => TranscriptBuffer.format(transcript);

  RealtimeVoiceState copyWith({
    VoiceSessionState? session,
    DeviceStatus? microphone,
    DeviceStatus? speaker,
    List<double>? waveform,
    List<TranscriptEntry>? transcript,
    bool? linkConnected,
    Object? lastError = _unset,
    Object? unavailableReason = _unset,
    bool? backendAvailable,
    bool? backendIdle,
    bool? liveCanStop,
  }) => RealtimeVoiceState(
    session: session ?? this.session,
    microphone: microphone ?? this.microphone,
    speaker: speaker ?? this.speaker,
    waveform: waveform ?? this.waveform,
    transcript: transcript ?? this.transcript,
    simulated: simulated,
    linkConnected: linkConnected ?? this.linkConnected,
    unavailableReason: identical(unavailableReason, _unset)
        ? this.unavailableReason
        : unavailableReason as String?,
    backendAvailable: backendAvailable ?? this.backendAvailable,
    backendIdle: backendIdle ?? this.backendIdle,
    liveCanStop: liveCanStop ?? this.liveCanStop,
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
  bool _inputFailed = false;
  bool _outputFailed = false;

  @override
  RealtimeVoiceState build() {
    _backend = ref.watch(voiceBackendProvider);
    _transcript = TranscriptBuffer();
    _inputFailed = false;
    _outputFailed = false;
    final subscription = _backend.events.listen(_onEvent);
    ref.onDispose(subscription.cancel);
    ref.listen(
      robotLinkProvider.select((link) => isRobotLinkOpen(link.status)),
      (_, linked) => _onLink(linked),
    );
    final linked = isRobotLinkOpen(ref.read(robotLinkProvider).status);
    final simulated = _backend.isSimulated;
    if (_backend is LiveVoiceBackend) {
      ref.listen(audioDevicesProvider, (_, devices) => _onDevices(devices));
    }
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

  void _onDevices(AudioDevicesState devices) {
    if (!ref.mounted || !state.linkConnected) return;
    final status = devices.status;
    DeviceStatus selection(AudioSelection? selection) =>
        switch (selection?.status) {
          AudioSelectionStatus.connected => DeviceStatus.ready,
          AudioSelectionStatus.disconnected => DeviceStatus.unavailable,
          _ => DeviceStatus.unknown,
        };
    // A discovered sink must not erase an actual capture/playback failure.
    state = state.copyWith(
      microphone: _inputFailed || status?.session.inputLost == true
          ? DeviceStatus.unavailable
          : selection(status?.input),
      speaker: _outputFailed
          ? DeviceStatus.unavailable
          : selection(status?.output),
    );
  }

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
    _inputFailed = false;
    _outputFailed = false;
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
    try {
      await _backend.stopConversation();
    } on Object {
      if (!ref.mounted) return;
      state = state.copyWith(
        session: VoiceSessionState.error,
        lastError: 'Stop could not be confirmed. Try Stop after reconnecting.',
      );
    }
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
      if (!state.canStop) _audio.release(AudioOwner.realtime);
      state = state.copyWith(
        linkConnected: false,
        session: VoiceSessionState.disconnected,
        microphone: DeviceStatus.unavailable,
        speaker: DeviceStatus.unavailable,
        backendAvailable: false,
        backendIdle: false,
        waveform: List.filled(RealtimeVoiceState.waveformSamples, 0),
      );
      _log('Voice disconnected with robot link', level: VoiceLogLevel.error);
      return;
    }
    // Reconnect never restarts a conversation by itself.
    state = state.copyWith(
      linkConnected: true,
      // Keep reconnecting until an authoritative voice_status arrives.
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
          microphone: _inputFailed
              ? DeviceStatus.unavailable
              : _device(microphone),
          speaker: _outputFailed ? DeviceStatus.unavailable : _device(speaker),
        );
      case VoiceErrorEvent(:final code, :final message):
        if (code == 'input_lost' || code == 'microphone_lost') {
          _inputFailed = true;
        }
        if (code == 'bluetooth_unavailable' || code == 'output_error') {
          _outputFailed = true;
        }
        if (!state.liveCanStop) _audio.release(AudioOwner.realtime);
        state = state.copyWith(
          session: VoiceSessionState.error,
          lastError: '$code: $message',
        );
        _log('Voice error $code: $message', level: VoiceLogLevel.error);
      case TtsStatusEvent():
        return;
      case VoiceControlEvent(
        :final available,
        :final idle,
        :final canStop,
        :final reason,
      ):
        if (idle) _audio.release(AudioOwner.realtime);
        if (canStop) _audio.acquire(AudioOwner.realtime);
        state = state.copyWith(
          backendAvailable: available,
          backendIdle: idle,
          liveCanStop: canStop,
          unavailableReason: reason,
        );
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
    if (state.simulated && current == VoiceSessionState.disconnected) return;
    if (!state.simulated && !state.linkConnected) return;
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
    if (_backend is LiveVoiceBackend && next == VoiceSessionState.listening) {
      _onDevices(ref.read(audioDevicesProvider));
    }
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
