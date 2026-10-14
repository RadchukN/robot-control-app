import 'package:robot_control_app/features/voice_studio/data/voice_backend.dart';
import 'package:robot_control_app/features/voice_studio/domain/voice_models.dart';

/// Provisional v1 TTS message codec for the Jetson backend.
///
/// The Jetson does not implement these messages yet; nothing in the app sends
/// them. They are kept here so a live adapter can be adapted in one place.
/// See docs/motion-voice-ui.md.
abstract final class VoiceProtocol {
  static const version = 1;

  static Map<String, Object?> speak(TtsRequest request) => {
    'type': 'tts_speak',
    'v': version,
    'request_id': request.requestId,
    'text': request.text,
    'language': request.language,
    'voice': request.voice,
    'speed': request.speed,
  };

  static Map<String, Object?> stop(String requestId) => {
    'type': 'tts_stop',
    'v': version,
    'request_id': requestId,
  };

  /// Decodes a backend frame. Returns null for frames this codec does not own,
  /// other protocol versions, or malformed payloads.
  static TtsStatusEvent? decode(Map<String, dynamic> message) {
    final type = message['type'];
    if (type is! String || !type.startsWith('tts_')) return null;
    if (message['v'] != version) return null;
    final requestId = message['request_id'];
    if (requestId is! String || requestId.isEmpty) return null;
    final simulated = message['dry_run'] == true;
    final text = message['message'];
    final detail = text is String ? text : null;
    return switch (type) {
      'tts_status' when message['state'] == 'speaking' => TtsStatusEvent(
        requestId,
        TtsEventPhase.speaking,
        message: detail,
        simulated: simulated,
      ),
      'tts_result' => switch (message['status']) {
        'completed' => TtsStatusEvent(
          requestId,
          TtsEventPhase.completed,
          message: detail,
          simulated: simulated,
        ),
        'cancelled' => TtsStatusEvent(
          requestId,
          TtsEventPhase.cancelled,
          message: detail,
          simulated: simulated,
        ),
        _ => null,
      },
      'tts_error' => TtsStatusEvent(
        requestId,
        TtsEventPhase.failed,
        message: '${message['code'] ?? 'error'}: ${detail ?? 'TTS failed'}',
        simulated: simulated,
      ),
      _ => null,
    };
  }
}
