import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/features/voice_studio/application/tts_controller.dart';
import 'package:robot_control_app/features/voice_studio/data/voice_backend.dart';
import 'package:robot_control_app/features/voice_studio/data/voice_protocol.dart';
import 'package:robot_control_app/features/voice_studio/domain/transcript_buffer.dart';
import 'package:robot_control_app/features/voice_studio/domain/voice_models.dart';

TranscriptEntry _entry(
  String id,
  int sequence,
  String text, {
  bool isFinal = true,
  int second = 0,
  TranscriptRole role = TranscriptRole.user,
}) => TranscriptEntry(
  id: id,
  role: role,
  text: text,
  isFinal: isFinal,
  timestamp: DateTime(2026, 1, 1, 10, 0, second),
  sequence: sequence,
);

void main() {
  group('TranscriptBuffer', () {
    test('partial updates become final and keep position', () {
      final buffer = TranscriptBuffer()
        ..apply(_entry('u1', 1, 'Hel', isFinal: false))
        ..apply(_entry('r1', 2, 'Hi', second: 2, role: TranscriptRole.robot))
        ..apply(_entry('u1', 3, 'Hello there', second: 5));
      expect(buffer.entries.map((e) => e.text), ['Hello there', 'Hi']);
      expect(buffer.entries.first.isFinal, isTrue);
    });

    test('ignores duplicate and stale out-of-order updates', () {
      final buffer = TranscriptBuffer()..apply(_entry('u1', 5, 'final text'));
      expect(buffer.apply(_entry('u1', 5, 'final text')), isFalse);
      expect(buffer.apply(_entry('u1', 3, 'older partial')), isFalse);
      expect(
        buffer.apply(_entry('u1', 9, 'late partial', isFinal: false)),
        isFalse,
        reason: 'a final utterance is never downgraded',
      );
      expect(buffer.entries.single.text, 'final text');
    });

    test('late-arriving utterances are inserted by timestamp', () {
      final buffer = TranscriptBuffer()
        ..apply(_entry('a', 1, 'first', second: 1))
        ..apply(_entry('c', 2, 'third', second: 3))
        ..apply(_entry('b', 3, 'second', second: 2));
      expect(buffer.entries.map((e) => e.text), ['first', 'second', 'third']);
    });

    test('history is bounded', () {
      final buffer = TranscriptBuffer(maxEntries: 3);
      for (var i = 0; i < 5; i++) {
        buffer.apply(_entry('u$i', i + 1, 'm$i', second: i));
      }
      expect(buffer.entries.map((e) => e.text), ['m2', 'm3', 'm4']);
    });

    test('format labels roles, partials and simulation', () {
      final text = TranscriptBuffer.format([
        _entry('u', 1, 'Hi'),
        TranscriptEntry(
          id: 'r',
          role: TranscriptRole.robot,
          text: 'Hel',
          isFinal: false,
          timestamp: DateTime(2026, 1, 1, 10, 0, 1),
          sequence: 2,
          simulated: true,
        ),
      ]);
      expect(
        text,
        '[10:00:00] You: Hi\n[10:00:01] G1 (simulated) (partial): Hel',
      );
    });
  });

  group('validateTtsText', () {
    test('rejects empty, overlong and control characters', () {
      expect(validateTtsText('   '), isNotNull);
      expect(validateTtsText('a' * 500), isNull);
      expect(validateTtsText('a' * 501), contains('500'));
      expect(validateTtsText('bad\u0007bell'), contains('control'));
      expect(validateTtsText('Ahoj, jak se máš?\nДобрий день'), isNull);
      expect(validateTtsText('abc', maxLength: 2), isNotNull);
    });
  });

  group('VoiceProtocol v1', () {
    const request = TtsRequest(
      requestId: 'tts-1',
      text: 'Hello',
      language: 'en-US',
      voice: 'A',
      speed: 1.0,
    );

    test('encodes speak and stop with version and correlation id', () {
      expect(VoiceProtocol.speak(request), {
        'type': 'tts_speak',
        'v': 1,
        'request_id': 'tts-1',
        'text': 'Hello',
        'language': 'en-US',
        'voice': 'A',
        'speed': 1.0,
      });
      expect(VoiceProtocol.stop('tts-1'), {
        'type': 'tts_stop',
        'v': 1,
        'request_id': 'tts-1',
      });
    });

    test('decodes status, results and errors', () {
      final speaking = VoiceProtocol.decode({
        'type': 'tts_status',
        'v': 1,
        'request_id': 'tts-1',
        'state': 'speaking',
      });
      expect(speaking?.phase, TtsEventPhase.speaking);
      final simulated = VoiceProtocol.decode({
        'type': 'tts_result',
        'v': 1,
        'request_id': 'tts-1',
        'status': 'completed',
        'dry_run': true,
      });
      expect(simulated?.phase, TtsEventPhase.completed);
      expect(simulated?.simulated, isTrue);
      final error = VoiceProtocol.decode({
        'type': 'tts_error',
        'v': 1,
        'request_id': 'tts-1',
        'code': 'audio_busy',
        'message': 'Speaker owned by realtime session',
      });
      expect(error?.phase, TtsEventPhase.failed);
      expect(error?.message, contains('audio_busy'));
    });

    test('ignores other versions, missing ids and foreign frames', () {
      expect(
        VoiceProtocol.decode({
          'type': 'tts_result',
          'v': 2,
          'request_id': 'tts-1',
          'status': 'completed',
        }),
        isNull,
      );
      expect(
        VoiceProtocol.decode({
          'type': 'tts_result',
          'v': 1,
          'status': 'completed',
        }),
        isNull,
      );
      expect(
        VoiceProtocol.decode({'type': 'motion_result', 'status': 'dry_run'}),
        isNull,
      );
      expect(
        VoiceProtocol.decode({
          'type': 'tts_result',
          'v': 1,
          'request_id': 'tts-1',
          'status': 'mystery',
        }),
        isNull,
      );
    });
  });
}
