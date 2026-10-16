import 'dart:async';

import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/features/voice_studio/application/voice_studio_providers.dart';
import 'package:robot_control_app/features/voice_studio/data/voice_backend.dart';
import 'package:robot_control_app/features/voice_studio/data/live_voice_backend.dart';
import 'package:robot_control_app/features/voice_studio/domain/voice_models.dart';

const defaultTtsMaxLength = 500;

int ttsLength(String text) => text.characters.length;

/// Returns a user-facing reason the text cannot be spoken, or null.
String? validateTtsText(String text, {int maxLength = defaultTtsMaxLength}) {
  if (text.trim().isEmpty) return 'Enter text for the robot to say.';
  if (ttsLength(text) > maxLength) {
    return 'Text is limited to $maxLength characters.';
  }
  if (RegExp(
    r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]',
  ).hasMatch(text)) {
    return 'Text contains unsupported control characters.';
  }
  return null;
}

const _unset = Object();

@immutable
class TtsState {
  const TtsState({
    required this.draft,
    required this.phase,
    required this.simulated,
    this.capabilities,
    this.unavailableReason,
    this.language,
    this.voice,
    this.speed,
    this.activeRequestId,
    this.lastError,
    this.lastResult,
  });

  final String draft;
  final TtsPhase phase;
  final bool simulated;
  final VoiceCapabilities? capabilities;
  final String? unavailableReason;
  final String? language;
  final String? voice;
  final double? speed;
  final String? activeRequestId;
  final String? lastError;
  final String? lastResult;

  int get maxLength => capabilities?.maxTextLength ?? defaultTtsMaxLength;

  String? get validationError => validateTtsText(draft, maxLength: maxLength);

  bool supportsLanguage(String code) =>
      capabilities?.languages.contains(code) ?? false;

  List<String> get voices => capabilities?.voices[language] ?? const [];

  List<double> get speeds => capabilities?.speeds ?? const [];

  bool get isBusy => const {
    TtsPhase.requesting,
    TtsPhase.speaking,
    TtsPhase.stopping,
  }.contains(phase);

  bool get canSpeak =>
      !isBusy &&
      validationError == null &&
      language != null &&
      supportsLanguage(language!) &&
      voice != null &&
      speed != null;

  bool get canStop =>
      phase == TtsPhase.requesting || phase == TtsPhase.speaking;

  TtsState copyWith({
    String? draft,
    TtsPhase? phase,
    Object? language = _unset,
    Object? voice = _unset,
    Object? speed = _unset,
    Object? activeRequestId = _unset,
    Object? lastError = _unset,
    Object? lastResult = _unset,
  }) => TtsState(
    draft: draft ?? this.draft,
    phase: phase ?? this.phase,
    simulated: simulated,
    capabilities: capabilities,
    unavailableReason: unavailableReason,
    language: identical(language, _unset) ? this.language : language as String?,
    voice: identical(voice, _unset) ? this.voice : voice as String?,
    speed: identical(speed, _unset) ? this.speed : speed as double?,
    activeRequestId: identical(activeRequestId, _unset)
        ? this.activeRequestId
        : activeRequestId as String?,
    lastError: identical(lastError, _unset)
        ? this.lastError
        : lastError as String?,
    lastResult: identical(lastResult, _unset)
        ? this.lastResult
        : lastResult as String?,
  );
}

/// Text-to-speech requests. Synthesis and playback belong to the Jetson; this
/// controller only validates input, owns request correlation, and shares the
/// speaker with realtime voice through [AudioSessionCoordinator].
class TextToSpeechController extends Notifier<TtsState> {
  late VoiceBackend _backend;
  int _requestCounter = 0;

  @override
  TtsState build() {
    _backend = ref.watch(voiceBackendProvider);
    final subscription = _backend.events.listen(_onEvent);
    ref.onDispose(subscription.cancel);
    final capabilities = _backend.capabilities;
    final language = displayLanguages
        .map((language) => language.code)
        .where((code) => capabilities?.languages.contains(code) ?? false)
        .firstOrNull;
    final speeds = capabilities?.speeds ?? const <double>[];
    return TtsState(
      draft: stateOrNull?.draft ?? '',
      phase: TtsPhase.idle,
      simulated: _backend.isSimulated,
      capabilities: capabilities,
      unavailableReason: _backend is LiveVoiceBackend
          ? 'Live text-to-speech is not available in medza.voice v1.'
          : _backend.unavailableReason,
      language: language,
      voice: capabilities?.voices[language]?.firstOrNull,
      speed: speeds.contains(1.0) ? 1.0 : speeds.firstOrNull,
    );
  }

  void _log(String message, {VoiceLogLevel level = VoiceLogLevel.info}) => ref
      .read(voiceEventLogProvider.notifier)
      .add(message, level: level, simulated: state.simulated);

  AudioSessionCoordinator get _audio => ref.read(audioSessionProvider.notifier);

  void setDraft(String text) => state = state.copyWith(draft: text);

  void clearDraft() => state = state.copyWith(draft: '', lastError: null);

  void setLanguage(String code) {
    if (!state.supportsLanguage(code) || state.isBusy) return;
    state = state.copyWith(
      language: code,
      voice: state.capabilities?.voices[code]?.firstOrNull,
    );
  }

  void setVoice(String voice) {
    if (!state.voices.contains(voice) || state.isBusy) return;
    state = state.copyWith(voice: voice);
  }

  void setSpeed(double speed) {
    if (!state.speeds.contains(speed) || state.isBusy) return;
    state = state.copyWith(speed: speed);
  }

  Future<void> speak() async {
    if (state.isBusy) return;
    final invalid =
        state.validationError ??
        state.unavailableReason ??
        (state.canSpeak ? null : 'Selected language or voice is unsupported.');
    if (invalid != null) {
      state = state.copyWith(lastError: invalid);
      return;
    }
    // TTS never interrupts a realtime conversation; no handover is supported.
    if (!_audio.acquire(AudioOwner.tts)) {
      state = state.copyWith(
        phase: TtsPhase.error,
        lastError:
            'The AI conversation is using the speaker. Stop it before speaking.',
      );
      _log('Speak blocked: speaker busy', level: VoiceLogLevel.warning);
      return;
    }
    final backend = _backend;
    final request = TtsRequest(
      requestId: 'tts-${++_requestCounter}',
      text: state.draft.trim(),
      language: state.language!,
      voice: state.voice!,
      speed: state.speed!,
    );
    state = state.copyWith(
      phase: TtsPhase.requesting,
      activeRequestId: request.requestId,
      lastError: null,
      lastResult: null,
    );
    _log('TTS requested (${request.language}, ${request.speed}x)');
    try {
      await backend.speak(request);
    } on Object catch (error) {
      if (!ref.mounted ||
          !identical(backend, _backend) ||
          state.activeRequestId != request.requestId) {
        return;
      }
      _finish(
        TtsPhase.error,
        error: error is StateError ? error.message : '$error',
      );
    }
  }

  Future<void> stopSpeaking() async {
    if (!state.canStop) return;
    final requestId = state.activeRequestId!;
    state = state.copyWith(phase: TtsPhase.stopping);
    _log('Stop speaking requested');
    await _backend.stopSpeaking(requestId);
  }

  void _onEvent(VoiceBackendEvent event) {
    if (!ref.mounted || event is! TtsStatusEvent) return;
    // Only the request this controller issued may change its state.
    if (event.requestId != state.activeRequestId) return;
    switch (event.phase) {
      case TtsEventPhase.speaking:
        if (state.phase != TtsPhase.requesting) return;
        state = state.copyWith(phase: TtsPhase.speaking);
        _log(
          event.simulated
              ? 'TTS: simulated speech started (robot silent)'
              : 'TTS: speaking started',
        );
      case TtsEventPhase.completed:
        _finish(
          TtsPhase.idle,
          result: event.simulated
              ? 'Simulation complete — the robot did not speak.'
              : 'Speech completed.',
        );
      case TtsEventPhase.cancelled:
        _finish(TtsPhase.idle, result: 'Speech stopped.');
      case TtsEventPhase.failed:
        _finish(TtsPhase.error, error: event.message ?? 'Speech failed.');
    }
  }

  void _finish(TtsPhase phase, {String? result, String? error}) {
    _audio.release(AudioOwner.tts);
    state = state.copyWith(
      phase: phase,
      activeRequestId: null,
      lastResult: result,
      lastError: error,
    );
    _log(
      error == null ? 'TTS: $result' : 'TTS error: $error',
      level: error == null ? VoiceLogLevel.info : VoiceLogLevel.error,
    );
  }
}

final ttsProvider = NotifierProvider<TextToSpeechController, TtsState>(
  TextToSpeechController.new,
  name: 'TtsProvider',
);

/// Local, in-memory phrases. Not persisted and never sent anywhere.
class SavedPhrasesController extends Notifier<List<SavedPhrase>> {
  static const maxPhrases = 20;
  int _next = 0;

  @override
  List<SavedPhrase> build() => [
    for (final text in const [
      'Hello everyone',
      'Welcome to PilsLab',
      'I am Unitree G1',
      'Nice to meet you',
      'Follow me',
    ])
      SavedPhrase('phrase-${_next++}', text),
  ];

  String? _validate(String text, {String? exceptId}) {
    final invalid = validateTtsText(text);
    if (invalid != null) return invalid;
    final normalized = text.trim().toLowerCase();
    if (state.any(
      (phrase) =>
          phrase.id != exceptId && phrase.text.toLowerCase() == normalized,
    )) {
      return 'This phrase is already saved.';
    }
    return null;
  }

  /// Returns an error message, or null when saved.
  String? add(String text) {
    final invalid = _validate(text);
    if (invalid != null) return invalid;
    if (state.length >= maxPhrases) {
      return 'You can save up to $maxPhrases phrases.';
    }
    state = [...state, SavedPhrase('phrase-${_next++}', text.trim())];
    return null;
  }

  String? edit(String id, String text) {
    final invalid = _validate(text, exceptId: id);
    if (invalid != null) return invalid;
    state = [
      for (final phrase in state)
        phrase.id == id ? SavedPhrase(id, text.trim()) : phrase,
    ];
    return null;
  }

  void remove(String id) =>
      state = state.where((phrase) => phrase.id != id).toList(growable: false);
}

final savedPhrasesProvider =
    NotifierProvider<SavedPhrasesController, List<SavedPhrase>>(
      SavedPhrasesController.new,
      name: 'SavedPhrasesProvider',
    );
