import 'package:flutter/foundation.dart';

/// Realtime conversation lifecycle, as reported by the voice backend.
enum VoiceSessionState {
  idle,
  starting,
  listening,
  thinking,
  speaking,
  stopping,
  error,
  disconnected,
  busy;

  bool get isActive =>
      const {starting, listening, thinking, speaking}.contains(this);
}

/// Audio device availability. Only [ready] means the backend confirmed it.
enum DeviceStatus { ready, unknown, unavailable, simulated }

enum TranscriptRole { user, robot }

enum TtsPhase { idle, requesting, speaking, stopping, error }

enum AudioOwner { none, realtime, tts }

enum AudioDirection { input, output }

@immutable
class VoiceLanguage {
  const VoiceLanguage(this.code, this.label);

  final String code;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is VoiceLanguage && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// Languages the UI can display; support is decided by [VoiceCapabilities].
const displayLanguages = [
  VoiceLanguage('cs-CZ', 'Czech'),
  VoiceLanguage('en-US', 'English'),
  VoiceLanguage('uk-UA', 'Ukrainian'),
  VoiceLanguage('de-DE', 'German'),
];

@immutable
class VoiceCapabilities {
  const VoiceCapabilities({
    required this.languages,
    required this.voices,
    required this.speeds,
    this.maxTextLength = 500,
    this.realtimeConversation = false,
    this.ttsHandover = false,
  });

  /// Language codes the backend can synthesize.
  final Set<String> languages;

  /// Voice ids per language code.
  final Map<String, List<String>> voices;
  final List<double> speeds;
  final int maxTextLength;
  final bool realtimeConversation;

  /// Whether TTS may take over the speaker from an active conversation.
  final bool ttsHandover;
}

@immutable
class TranscriptEntry {
  const TranscriptEntry({
    required this.id,
    required this.role,
    required this.text,
    required this.isFinal,
    required this.timestamp,
    required this.sequence,
    this.simulated = false,
  });

  final String id;
  final TranscriptRole role;
  final String text;
  final bool isFinal;
  final DateTime timestamp;
  final int sequence;
  final bool simulated;
}

@immutable
class TtsRequest {
  const TtsRequest({
    required this.requestId,
    required this.text,
    required this.language,
    required this.voice,
    required this.speed,
  });

  final String requestId;
  final String text;
  final String language;
  final String voice;
  final double speed;
}

@immutable
class SavedPhrase {
  const SavedPhrase(this.id, this.text);

  final String id;
  final String text;
}

enum VoiceLogLevel { info, warning, error }

@immutable
class VoiceLogEntry {
  const VoiceLogEntry(
    this.time,
    this.message, {
    this.level = VoiceLogLevel.info,
    this.simulated = false,
  });

  final DateTime time;
  final String message;
  final VoiceLogLevel level;
  final bool simulated;
}
