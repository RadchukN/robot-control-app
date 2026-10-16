import 'dart:async';

import 'package:robot_control_app/features/voice_studio/domain/voice_models.dart';

sealed class VoiceBackendEvent {
  const VoiceBackendEvent();
}

class VoiceSessionEvent extends VoiceBackendEvent {
  const VoiceSessionEvent(this.state, {this.message});

  final VoiceSessionState state;
  final String? message;
}

class VoiceTranscriptEvent extends VoiceBackendEvent {
  const VoiceTranscriptEvent(this.entry);

  final TranscriptEntry entry;
}

class VoiceAudioLevelEvent extends VoiceBackendEvent {
  const VoiceAudioLevelEvent(this.direction, this.level);

  final AudioDirection direction;

  /// Normalized 0..1.
  final double level;
}

class VoiceDeviceEvent extends VoiceBackendEvent {
  const VoiceDeviceEvent({required this.microphone, required this.speaker});

  final DeviceStatus microphone;
  final DeviceStatus speaker;
}

/// Public controls only: session credentials never enter provider/UI state.
class VoiceControlEvent extends VoiceBackendEvent {
  const VoiceControlEvent({
    required this.available,
    required this.idle,
    required this.canStop,
    this.reason,
  });
  final bool available;
  final bool idle;
  final bool canStop;
  final String? reason;
}

enum TtsEventPhase { speaking, completed, cancelled, failed }

class TtsStatusEvent extends VoiceBackendEvent {
  const TtsStatusEvent(
    this.requestId,
    this.phase, {
    this.message,
    this.simulated = false,
  });

  final String requestId;
  final TtsEventPhase phase;
  final String? message;

  /// True when nothing was played on the robot speaker.
  final bool simulated;
}

class VoiceErrorEvent extends VoiceBackendEvent {
  const VoiceErrorEvent(this.code, this.message);

  final String code;
  final String message;
}

/// Voice and TTS transport. Implementations own no robot connection of their
/// own; a live adapter must ride on the dashboard's authenticated WebSocket.
abstract interface class VoiceBackend {
  bool get isSimulated;

  /// Null until the backend has reported what it supports.
  VoiceCapabilities? get capabilities;

  /// Why commands cannot be sent, or null when the backend is usable.
  String? get unavailableReason;

  Stream<VoiceBackendEvent> get events;

  Future<void> startConversation();
  Future<void> stopConversation();
  Future<void> speak(TtsRequest request);
  Future<void> stopSpeaking(String requestId);
  void dispose();
}

/// Live placeholder: the Jetson voice protocol is not finalized, so nothing is
/// ever sent and every command fails with [unavailableReason].
class UnavailableVoiceBackend implements VoiceBackend {
  UnavailableVoiceBackend([
    this.unavailableReason =
        'The robot voice backend is not available yet. Nothing was sent.',
  ]);

  final _events = StreamController<VoiceBackendEvent>.broadcast();

  @override
  final String unavailableReason;

  @override
  bool get isSimulated => false;

  @override
  VoiceCapabilities? get capabilities => null;

  @override
  Stream<VoiceBackendEvent> get events => _events.stream;

  Future<Never> _unavailable() => Future.error(StateError(unavailableReason));

  @override
  Future<void> startConversation() => _unavailable();

  @override
  Future<void> stopConversation() async {}

  @override
  Future<void> speak(TtsRequest request) => _unavailable();

  @override
  Future<void> stopSpeaking(String requestId) async {}

  @override
  void dispose() => _events.close();
}
