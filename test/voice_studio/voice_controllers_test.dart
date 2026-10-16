import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/features/dashboard/application/dashboard_controller.dart';
import 'package:robot_control_app/features/motion/application/motion_state.dart';
import 'package:robot_control_app/features/voice_studio/application/realtime_voice_controller.dart';
import 'package:robot_control_app/features/voice_studio/application/tts_controller.dart';
import 'package:robot_control_app/features/voice_studio/application/voice_studio_providers.dart';
import 'package:robot_control_app/features/voice_studio/data/voice_backend.dart';
import 'package:robot_control_app/features/voice_studio/domain/voice_models.dart';
import 'package:robot_control_app/services/robot_connection.dart';

import 'voice_test_helpers.dart';

ProviderContainer _container({
  VoiceBackend? backend,
  List<String>? motionCalls,
}) {
  var tick = 0;
  return ProviderContainer(
    overrides: [
      dashboardControllerProvider.overrideWith(
        () => RecordingDashboardController(motionCalls ?? []),
      ),
      voiceClockProvider.overrideWithValue(
        () => DateTime(2026, 1, 1, 10).add(Duration(seconds: tick++)),
      ),
      if (backend != null) voiceBackendProvider.overrideWithValue(backend),
    ],
  );
}

void _link(ProviderContainer container, RobotLinkStatus status) =>
    container.read(robotLinkProvider.notifier).update(RobotLinkState(status));

void main() {
  group('Realtime voice (Demo Mode)', () {
    testWidgets('walks the conversation states and builds a transcript', (
      tester,
    ) async {
      final container = _container();
      addTearDown(container.dispose);
      final states = <VoiceSessionState>[];
      container.listen(
        realtimeVoiceProvider.select((state) => state.session),
        (_, next) => states.add(next),
      );
      final controller = container.read(realtimeVoiceProvider.notifier);
      RealtimeVoiceState read() => container.read(realtimeVoiceProvider);

      expect(read().simulated, isTrue);
      expect(read().canStart, isTrue);
      expect(read().canStop, isFalse);

      await controller.start();
      expect(read().session, VoiceSessionState.starting);
      expect(container.read(audioSessionProvider), AudioOwner.realtime);
      expect(read().canStart, isFalse);

      await tester.pump(const Duration(milliseconds: 300));
      expect(read().session, VoiceSessionState.listening);
      // Demo devices are never presented as confirmed hardware.
      expect(read().microphone, DeviceStatus.simulated);
      expect(read().speaker, DeviceStatus.simulated);

      await tester.pump(const Duration(seconds: 12));
      expect(
        states,
        containsAllInOrder([
          VoiceSessionState.starting,
          VoiceSessionState.listening,
          VoiceSessionState.thinking,
          VoiceSessionState.speaking,
          VoiceSessionState.listening,
        ]),
      );
      final transcript = read().transcript;
      expect(transcript.map((entry) => entry.role), [
        TranscriptRole.user,
        TranscriptRole.robot,
        TranscriptRole.user,
        TranscriptRole.robot,
      ]);
      expect(transcript.every((entry) => entry.isFinal), isTrue);
      expect(transcript.every((entry) => entry.simulated), isTrue);
      expect(read().waveform.any((level) => level > 0), isTrue);

      await controller.stop();
      expect(read().session, VoiceSessionState.stopping);
      await tester.pump(const Duration(milliseconds: 200));
      expect(read().session, VoiceSessionState.idle);
      expect(read().waveform.every((level) => level == 0), isTrue);
      expect(container.read(audioSessionProvider), AudioOwner.none);

      controller.clearTranscript();
      expect(read().transcript, isEmpty);
    });

    testWidgets('switching Demo Mode off ends the simulated session', (
      tester,
    ) async {
      final container = _container();
      addTearDown(container.dispose);
      await container.read(realtimeVoiceProvider.notifier).start();
      await tester.pump(const Duration(milliseconds: 300));

      container.read(voiceDemoModeProvider.notifier).set(false);
      final state = container.read(realtimeVoiceProvider);
      expect(state.simulated, isFalse);
      expect(state.session.isActive, isFalse);
      expect(state.transcript, isEmpty);
      expect(container.read(audioSessionProvider), AudioOwner.none);
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('Audio session conflicts', () {
    testWidgets('TTS blocks a conversation until speech stops', (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      final tts = container.read(ttsProvider.notifier);
      final voice = container.read(realtimeVoiceProvider.notifier);

      tts.setDraft('Hello everyone');
      await tts.speak();
      await tester.pump(const Duration(milliseconds: 150));
      expect(container.read(ttsProvider).phase, TtsPhase.speaking);

      await voice.start();
      expect(
        container.read(realtimeVoiceProvider).session,
        VoiceSessionState.busy,
      );
      expect(
        container.read(realtimeVoiceProvider).lastError,
        contains('text-to-speech'),
      );
      expect(container.read(audioSessionProvider), AudioOwner.tts);

      await tts.stopSpeaking();
      expect(container.read(ttsProvider).phase, TtsPhase.stopping);
      await tester.pump(const Duration(milliseconds: 100));
      expect(container.read(ttsProvider).phase, TtsPhase.idle);
      expect(container.read(ttsProvider).lastResult, 'Speech stopped.');
      expect(container.read(audioSessionProvider), AudioOwner.none);

      await voice.start();
      expect(
        container.read(realtimeVoiceProvider).session,
        VoiceSessionState.starting,
      );
      await voice.stop();
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('a conversation blocks TTS without handover', (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      final voice = container.read(realtimeVoiceProvider.notifier);
      final tts = container.read(ttsProvider.notifier);
      await voice.start();
      await tester.pump(const Duration(milliseconds: 300));

      tts.setDraft('Hello');
      await tts.speak();
      final state = container.read(ttsProvider);
      expect(state.phase, TtsPhase.error);
      expect(state.lastError, contains('conversation'));
      expect(state.activeRequestId, isNull);
      expect(container.read(audioSessionProvider), AudioOwner.realtime);
      expect(
        container.read(realtimeVoiceProvider).session,
        VoiceSessionState.listening,
      );

      await voice.stop();
      await tester.pump(const Duration(milliseconds: 200));
    });
  });

  group('Text-to-speech', () {
    testWidgets('demo speech completes as a simulation', (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      final tts = container.read(ttsProvider.notifier);
      expect(container.read(ttsProvider).language, 'cs-CZ');
      tts
        ..setLanguage('en-US')
        ..setSpeed(1.25)
        ..setDraft('Hi');
      await tts.speak();
      expect(container.read(ttsProvider).phase, TtsPhase.requesting);
      await tester.pump(const Duration(milliseconds: 150));
      expect(container.read(ttsProvider).phase, TtsPhase.speaking);
      await tester.pump(const Duration(seconds: 1));
      final state = container.read(ttsProvider);
      expect(state.phase, TtsPhase.idle);
      expect(state.lastResult, contains('did not speak'));
      expect(container.read(audioSessionProvider), AudioOwner.none);
    });

    testWidgets('invalid text never reaches the backend', (tester) async {
      final backend = ScriptedVoiceBackend();
      final container = _container(backend: backend);
      addTearDown(container.dispose);
      final tts = container.read(ttsProvider.notifier);

      tts.setDraft('   ');
      await tts.speak();
      expect(container.read(ttsProvider).lastError, isNotNull);
      tts.setDraft('x' * 501);
      await tts.speak();
      expect(container.read(ttsProvider).lastError, contains('500'));
      tts.setLanguage('de-DE');
      expect(
        container.read(ttsProvider).language,
        'cs-CZ',
        reason: 'unsupported languages cannot be selected',
      );
      expect(backend.calls, isEmpty);
      expect(container.read(audioSessionProvider), AudioOwner.none);
    });

    testWidgets('only the correlated request changes TTS state', (
      tester,
    ) async {
      final backend = ScriptedVoiceBackend();
      final container = _container(backend: backend);
      addTearDown(container.dispose);
      final tts = container.read(ttsProvider.notifier)..setDraft('Ahoj');
      await tts.speak();
      final id = backend.requests.single.requestId;
      expect(backend.requests.single.language, 'cs-CZ');
      expect(backend.requests.single.voice, 'Live B');

      backend.emit(const TtsStatusEvent('other', TtsEventPhase.completed));
      expect(container.read(ttsProvider).phase, TtsPhase.requesting);
      backend.emit(TtsStatusEvent(id, TtsEventPhase.speaking));
      expect(container.read(ttsProvider).phase, TtsPhase.speaking);

      await tts.stopSpeaking();
      expect(backend.calls.last, 'stopSpeaking:$id');
      backend.emit(TtsStatusEvent(id, TtsEventPhase.cancelled));
      expect(container.read(ttsProvider).phase, TtsPhase.idle);
      expect(container.read(audioSessionProvider), AudioOwner.none);

      await tts.speak();
      final second = backend.requests.last.requestId;
      expect(second, isNot(id));
      backend.emit(TtsStatusEvent(id, TtsEventPhase.failed, message: 'late'));
      expect(container.read(ttsProvider).phase, TtsPhase.requesting);
      backend.emit(
        TtsStatusEvent(second, TtsEventPhase.failed, message: 'audio_busy'),
      );
      expect(container.read(ttsProvider).phase, TtsPhase.error);
      expect(container.read(ttsProvider).lastError, 'audio_busy');
      expect(container.read(audioSessionProvider), AudioOwner.none);
    });
  });

  group('Saved phrases', () {
    test('add, edit, delete, dedupe and bound', () {
      final container = _container();
      addTearDown(container.dispose);
      final phrases = container.read(savedPhrasesProvider.notifier);
      List<String> texts() =>
          container.read(savedPhrasesProvider).map((p) => p.text).toList();

      expect(texts(), contains('Welcome to PilsLab'));
      expect(phrases.add('  Good morning  '), isNull);
      expect(texts().last, 'Good morning');
      expect(phrases.add('good MORNING'), contains('already'));
      expect(phrases.add(''), isNotNull);

      final id = container.read(savedPhrasesProvider).last.id;
      expect(phrases.edit(id, 'Good evening'), isNull);
      expect(texts().last, 'Good evening');
      expect(phrases.edit(id, 'Follow me'), contains('already'));
      phrases.remove(id);
      expect(texts(), isNot(contains('Good evening')));

      for (var i = 0; texts().length < SavedPhrasesController.maxPhrases; i++) {
        expect(phrases.add('Phrase $i'), isNull);
      }
      expect(phrases.add('One too many'), contains('up to'));
    });
  });

  group('Live mode and disconnects', () {
    testWidgets(
      'Demo Mode off waits for authoritative backend status before enabling Start',
      (tester) async {
        final motionCalls = <String>[];
        final container = _container(motionCalls: motionCalls);
        addTearDown(container.dispose);
        container.read(voiceDemoModeProvider.notifier).set(false);

        var state = container.read(realtimeVoiceProvider);
        expect(state.simulated, isFalse);
        expect(state.session, VoiceSessionState.disconnected);
        expect(state.microphone, DeviceStatus.unavailable);
        expect(state.canStart, isFalse);

        _link(container, RobotLinkStatus.connected);
        state = container.read(realtimeVoiceProvider);
        expect(state.session, VoiceSessionState.disconnected);
        expect(state.microphone, DeviceStatus.unknown);
        expect(state.canStart, isFalse, reason: 'voice backend not supported');

        final tts = container.read(ttsProvider.notifier)..setDraft('Hello');
        expect(container.read(ttsProvider).capabilities, isNull);
        await tts.speak();
        expect(container.read(ttsProvider).lastError, isNotEmpty);
        expect(motionCalls, isEmpty);
      },
    );

    testWidgets(
      'disconnect retains uncertain audio ownership and reconnect never restarts',
      (tester) async {
        final backend = ScriptedVoiceBackend();
        final container = _container(backend: backend);
        addTearDown(container.dispose);
        final voice = container.read(realtimeVoiceProvider.notifier);
        RealtimeVoiceState read() => container.read(realtimeVoiceProvider);

        expect(read().session, VoiceSessionState.disconnected);
        _link(container, RobotLinkStatus.connected);
        backend.emit(const VoiceSessionEvent(VoiceSessionState.idle));
        backend.emit(
          const VoiceControlEvent(available: true, idle: true, canStop: false),
        );
        expect(read().canStart, isTrue);
        await voice.start();
        backend
          ..emit(const VoiceSessionEvent(VoiceSessionState.listening))
          ..emit(
            const VoiceDeviceEvent(
              microphone: DeviceStatus.ready,
              speaker: DeviceStatus.ready,
            ),
          );
        expect(read().session, VoiceSessionState.listening);
        expect(read().microphone, DeviceStatus.ready);

        _link(container, RobotLinkStatus.disconnected);
        expect(read().session, VoiceSessionState.disconnected);
        expect(read().microphone, DeviceStatus.unavailable);
        expect(container.read(audioSessionProvider), AudioOwner.realtime);
        backend.emit(const VoiceSessionEvent(VoiceSessionState.speaking));
        expect(read().session, VoiceSessionState.disconnected);

        _link(container, RobotLinkStatus.connected);
        expect(read().session, VoiceSessionState.disconnected);
        backend.emit(const VoiceSessionEvent(VoiceSessionState.idle));
        expect(read().session, VoiceSessionState.idle);
        expect(backend.calls, ['start'], reason: 'no automatic replay');
      },
    );

    testWidgets('late activity after Stop cannot reopen the session', (
      tester,
    ) async {
      final backend = ScriptedVoiceBackend();
      final container = _container(backend: backend);
      addTearDown(container.dispose);
      _link(container, RobotLinkStatus.connected);
      final voice = container.read(realtimeVoiceProvider.notifier);
      backend.emit(
        const VoiceControlEvent(available: true, idle: true, canStop: false),
      );
      await voice.start();
      backend.emit(const VoiceSessionEvent(VoiceSessionState.listening));
      await voice.stop();
      backend.emit(const VoiceSessionEvent(VoiceSessionState.speaking));
      expect(
        container.read(realtimeVoiceProvider).session,
        VoiceSessionState.stopping,
      );
      backend.emit(const VoiceSessionEvent(VoiceSessionState.idle));
      expect(
        container.read(realtimeVoiceProvider).session,
        VoiceSessionState.idle,
      );
      expect(container.read(audioSessionProvider), AudioOwner.none);
    });

    testWidgets('a simulated backend cannot report real ready hardware', (
      tester,
    ) async {
      final backend = ScriptedVoiceBackend(isSimulated: true);
      final container = _container(backend: backend);
      addTearDown(container.dispose);
      container.read(realtimeVoiceProvider);
      backend.emit(
        const VoiceDeviceEvent(
          microphone: DeviceStatus.ready,
          speaker: DeviceStatus.ready,
        ),
      );
      final state = container.read(realtimeVoiceProvider);
      expect(state.microphone, DeviceStatus.simulated);
      expect(state.speaker, DeviceStatus.simulated);
    });
  });

  testWidgets('voice and TTS never send motion commands', (tester) async {
    final motionCalls = <String>[];
    final container = _container(motionCalls: motionCalls);
    addTearDown(container.dispose);
    container.read(motionProvider);
    await tester.pump();
    final before = container.read(motionProvider).playbackStatus;

    final voice = container.read(realtimeVoiceProvider.notifier);
    await voice.start();
    // The demo script includes "Can you wave your hand?".
    await tester.pump(const Duration(seconds: 12));
    await voice.stop();
    await tester.pump(const Duration(milliseconds: 200));
    final tts = container.read(ttsProvider.notifier)..setDraft('Wave hand');
    await tts.speak();
    await tester.pump(const Duration(seconds: 2));

    expect(motionCalls, isEmpty);
    expect(container.read(motionProvider).playbackStatus, before);
  });
}
