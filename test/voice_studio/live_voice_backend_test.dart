import 'dart:async';

import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart' as test_api show testWidgets;
import 'package:robot_control_app/features/voice_studio/data/live_voice_backend.dart';
import 'package:robot_control_app/features/voice_studio/data/voice_backend.dart';
import 'package:robot_control_app/features/voice_studio/domain/voice_models.dart';

class FakeVoiceSocket implements VoiceFrameTransport {
  final incoming = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final sent = <Map<String, Object?>>[];
  bool failWrites = false;
  @override
  Stream<Map<String, dynamic>> get frames => incoming.stream;
  @override
  void send(Map<String, Object?> frame) {
    if (failWrites) throw StateError('private transport detail');
    sent.add(Map.of(frame));
  }

  Map<String, Object?> last(String type) =>
      sent.lastWhere((m) => m['type'] == type);
  void capabilities({bool enabled = true, bool reclaim = true}) =>
      incoming.add({
        'type': 'voice_capabilities',
        'protocol': 'medza.voice',
        'version': 1,
        'request_id': last('voice_get_capabilities')['request_id'],
        'enabled': enabled,
        'ownership': reclaim ? 'connection_with_resume_token' : 'unsupported',
        'requests': [
          'voice_get_capabilities',
          'voice_get_status',
          'voice_start',
          'voice_stop',
        ],
        'automatic_greeting': false,
      });
  void status(
    String state, {
    String? session = 'session-a',
    String? requestId,
    String? token,
    String? reason,
  }) => incoming.add({
    'type': 'voice_status',
    'protocol': 'medza.voice',
    'version': 1,
    'request_id': requestId,
    'state': state,
    'session_id': session,
    'reason': reason,
    'resume_token': ?token,
  });
  void snapshot(String state, {String? session = 'session-a'}) => status(
    state,
    session: session,
    requestId: last('voice_get_status')['request_id'] as String,
  );
  void ack({String state = 'starting', String token = 'private-one'}) => status(
    state,
    requestId: last('voice_start')['request_id'] as String,
    token: token,
  );
  void error(
    String code, {
    bool fatal = true,
    String? requestId,
    String session = 'session-a',
  }) => incoming.add({
    'type': 'voice_error',
    'code': code,
    'fatal': fatal,
    if (fatal) 'session_id': session,
    'request_id': ?requestId,
    'message': 'must-never-display-private-detail',
  });
  void transcript(
    String text, {
    bool finality = false,
    String item = 'item-1',
    String role = 'user',
    String? response,
    String session = 'session-a',
  }) => incoming.add({
    'type': 'voice_transcript',
    'session_id': session,
    'role': role,
    'item_id': item,
    'response_id': response,
    'text': text,
    'final': finality,
  });
}

void main() {
  late FakeVoiceSocket socket;
  late LiveVoiceBackend backend;
  late List<VoiceBackendEvent> events;
  void testWidgets(String name, Future<void> Function(WidgetTester) body) {
    test_api.testWidgets(name, (tester) async {
      socket = FakeVoiceSocket();
      backend = LiveVoiceBackend(
        socket,
        requestTimeout: const Duration(seconds: 2),
        readyTimeout: const Duration(seconds: 4),
      );
      events = [];
      backend.events.listen(events.add);
      backend.connectionChanged(true, 'ws://test-a');
      try {
        await body(tester);
      } finally {
        backend.dispose();
        await socket.incoming.close();
      }
    });
  }

  Future<void> idle(WidgetTester tester) async {
    socket.capabilities();
    socket.snapshot('idle', session: null);
    await tester.pump();
  }

  Future<void> owned(WidgetTester tester) async {
    await idle(tester);
    await backend.startConversation();
    socket.ack();
    socket.status('listening');
    await tester.pump();
  }

  VoiceControlEvent controls() => events.whereType<VoiceControlEvent>().last;
  List<Map<String, Object?>> starts() =>
      socket.sent.where((m) => m['type'] == 'voice_start').toList();

  testWidgets(
    'queries only; Start needs both enabled capabilities and idle status',
    (tester) async {
      expect(socket.sent.map((m) => m['type']), [
        'voice_get_capabilities',
        'voice_get_status',
      ]);
      await backend.startConversation();
      expect(starts(), isEmpty);
      socket.capabilities();
      await backend.startConversation();
      expect(starts(), isEmpty);
      socket.snapshot('idle', session: null);
      await backend.startConversation();
      expect(starts().single.keys, unorderedEquals(['type', 'request_id']));
      expect(
        starts().single['request_id'].toString().length,
        lessThanOrEqualTo(64),
      );
      socket.ack();
      await tester.pump();
      expect(
        events.whereType<VoiceSessionEvent>().last.state,
        VoiceSessionState.starting,
      );
      socket.status('listening');
      await tester.pump();
      expect(
        events.whereType<VoiceSessionEvent>().last.state,
        VoiceSessionState.listening,
      );
      expect(controls().idle, isFalse);
    },
  );

  testWidgets('disabled backend never starts', (tester) async {
    socket.capabilities(enabled: false);
    socket.snapshot('idle');
    await backend.startConversation();
    await tester.pump();
    expect(starts(), isEmpty);
    expect(controls().available, isFalse);
  });

  testWidgets(
    'adapter replacement rejects old correlated credentials on the same socket',
    (tester) async {
      await idle(tester);
      await backend.startConversation();
      final oldRequest = starts().last['request_id'] as String;
      backend.dispose();
      backend = LiveVoiceBackend(socket);
      backend.events.listen(events.add);
      backend.connectionChanged(true, 'ws://test-a');
      await idle(tester);
      await backend.startConversation();
      expect(starts().last['request_id'], isNot(oldRequest));
      socket.status('starting', requestId: oldRequest, token: 'obsolete-token');
      socket.ack(token: 'current-token');
      socket.status('listening');
      backend.connectionChanged(false, 'ws://test-a');
      backend.connectionChanged(true, 'ws://test-a');
      socket.capabilities();
      socket.snapshot('listening');
      expect(starts().last['resume_token'], 'current-token');
    },
  );

  testWidgets('an explicit Stop can resolve an already terminal failure', (
    tester,
  ) async {
    await owned(tester);
    socket.error('cleanup_failed');
    socket.status('idle', reason: 'cleanup_failed');
    await tester.pump();
    await backend.stopConversation();
    socket.status('idle', reason: 'stopped');
    await tester.pump();
    expect(
      events.whereType<VoiceSessionEvent>().last.state,
      VoiceSessionState.idle,
    );
    expect(controls().canStop, isFalse);
    expect(starts().length, 1);
  });

  testWidgets(
    'reclaim rejection stays visible while another owner is listening',
    (tester) async {
      await owned(tester);
      backend.connectionChanged(false, 'ws://test-a');
      backend.connectionChanged(true, 'ws://test-a');
      socket.capabilities();
      socket.snapshot('listening');
      socket.error(
        'session_owned',
        fatal: false,
        requestId: starts().last['request_id'] as String,
      );
      socket.snapshot('listening');
      await tester.pump();
      expect(events.whereType<VoiceErrorEvent>().last.code, 'session_owned');
      expect(
        events.whereType<VoiceSessionEvent>().last.state,
        VoiceSessionState.disconnected,
      );
      expect(controls().canStop, isTrue);
      expect(controls().idle, isFalse);
      expect(starts().length, 2);
    },
  );

  testWidgets(
    'same owner reconnect explicitly reclaims and rotates its private token',
    (tester) async {
      await owned(tester);
      backend.connectionChanged(false, 'ws://test-a');
      backend.connectionChanged(true, 'ws://test-a');
      expect(starts().length, 1);
      socket.snapshot(
        'listening',
      ); // Status alone is not reclaim authorization.
      expect(starts().length, 1);
      socket.capabilities();
      expect(starts().last, containsPair('session_id', 'session-a'));
      expect(starts().last, containsPair('resume_token', 'private-one'));
      socket.ack(state: 'listening', token: 'private-two');
      backend.connectionChanged(false, 'ws://test-a');
      backend.connectionChanged(true, 'ws://test-a');
      socket.capabilities();
      socket.snapshot('listening');
      expect(starts().last['resume_token'], 'private-two');
      await tester.pump();
      for (final event in events) {
        expect(event.toString(), isNot(contains('private-')));
      }
    },
  );

  for (final code in [
    'invalid_reclaim',
    'reclaim_expired',
    'session_unavailable',
    'session_owned',
  ]) {
    testWidgets(
      '$code drops credentials without starting a replacement session',
      (tester) async {
        await owned(tester);
        backend.connectionChanged(false, 'ws://test-a');
        backend.connectionChanged(true, 'ws://test-a');
        socket.capabilities();
        socket.snapshot('listening');
        socket.error(
          code,
          fatal: false,
          requestId: starts().last['request_id'] as String,
        );
        socket.snapshot('idle');
        await tester.pump();
        expect(starts().length, 2);
        backend.connectionChanged(false, 'ws://test-a');
        backend.connectionChanged(true, 'ws://test-a');
        socket.capabilities();
        socket.snapshot('idle');
        expect(starts().length, 2);
        await backend.startConversation();
        expect(starts().last.containsKey('resume_token'), isFalse);
      },
    );
  }

  testWidgets(
    'no token, changed session, unsupported ownership and changed endpoint never reclaim',
    (tester) async {
      await idle(tester);
      socket.status('listening');
      backend.connectionChanged(false, 'ws://test-a');
      backend.connectionChanged(true, 'ws://test-a');
      socket.capabilities();
      socket.snapshot('listening');
      expect(starts(), isEmpty);
      socket.status('idle');
      await backend.startConversation();
      socket.ack();
      backend.connectionChanged(false, 'ws://test-a');
      backend.connectionChanged(true, 'ws://test-a');
      socket.capabilities(reclaim: false);
      socket.snapshot('listening');
      expect(starts().length, 1);
      backend.connectionChanged(false, 'ws://test-a');
      backend.connectionChanged(true, 'ws://test-a');
      socket.capabilities();
      socket.snapshot('listening', session: 'replacement');
      expect(starts().length, 1);
      backend.connectionChanged(true, 'ws://other-backend');
      socket.capabilities();
      socket.snapshot('listening');
      expect(starts().length, 1);
    },
  );

  testWidgets(
    'partial deltas append and final replaces by the full stable tuple',
    (tester) async {
      await owned(tester);
      socket.transcript('Hel');
      socket.transcript('lo');
      socket.transcript('Hello!', finality: true);
      socket.transcript('late-partial');
      socket.transcript('Assistant', role: 'assistant', response: 'r1');
      socket.transcript('Other response', role: 'assistant', response: 'r2');
      socket.transcript('Stale', session: 'old');
      await tester.pump();
      final entries = events
          .whereType<VoiceTranscriptEvent>()
          .map((e) => e.entry)
          .toList();
      expect(entries.map((e) => e.text), [
        'Hel',
        'Hello',
        'Hello!',
        'Assistant',
        'Other response',
      ]);
      expect(entries.take(3).map((e) => e.id).toSet().length, 1);
      expect(entries.skip(3).map((e) => e.id).toSet().length, 2);
      expect(
        events.whereType<VoiceSessionEvent>().last.state,
        VoiceSessionState.listening,
      );
    },
  );

  testWidgets(
    'Stop cancels starting and ignores its late acknowledgement/token',
    (tester) async {
      await idle(tester);
      await backend.startConversation();
      final startId = starts().single['request_id'] as String;
      await backend.stopConversation();
      socket.status('starting', requestId: startId, token: 'too-late');
      socket.status('listening');
      await tester.pump();
      expect(
        events.whereType<VoiceSessionEvent>().last.state,
        VoiceSessionState.stopping,
      );
      socket.status('idle', reason: 'stopped');
      socket.status(
        'idle',
        requestId: socket.last('voice_stop')['request_id'] as String,
        reason: 'stopped',
      );
      await tester.pump();
      expect(controls().canStop, isFalse);
      backend.connectionChanged(false, 'ws://test-a');
      backend.connectionChanged(true, 'ws://test-a');
      socket.capabilities();
      socket.snapshot('idle');
      expect(starts().length, 1);
    },
  );

  testWidgets(
    'Stop while disconnected sends Stop after status, never reclaim',
    (tester) async {
      await owned(tester);
      backend.connectionChanged(false, 'ws://test-a');
      await backend.stopConversation();
      await tester.pump();
      expect(controls().canStop, isTrue);
      backend.connectionChanged(true, 'ws://test-a');
      socket.capabilities();
      socket.snapshot('listening');
      expect(
        socket.last('voice_stop').keys,
        unorderedEquals(['type', 'request_id']),
      );
      expect(starts().length, 1);
    },
  );

  testWidgets('late status query cannot cancel a newer Start', (tester) async {
    await idle(tester);
    backend.connectionChanged(false, 'ws://test-a');
    backend.connectionChanged(true, 'ws://test-a');
    socket.capabilities();
    socket.status('idle');
    final oldQuery = socket.last('voice_get_status')['request_id'] as String;
    await backend.startConversation();
    socket.status('idle', requestId: oldQuery);
    await tester.pump();
    expect(controls().idle, isFalse);
    expect(controls().canStop, isTrue);
  });

  for (final code in [
    'microphone_lost',
    'input_lost',
    'bluetooth_unavailable',
    'api_error',
    'child_exited',
    'cleanup_failed',
    'cleanup_timeout',
  ]) {
    testWidgets('$code remains visible after terminal idle; no restart', (
      tester,
    ) async {
      await owned(tester);
      socket.error(code);
      socket.status('idle', reason: code);
      await tester.pump();
      final error = events.whereType<VoiceErrorEvent>().last;
      expect(error.code, code);
      expect(error.message, isNot(contains('private-detail')));
      expect(controls().canStop, isFalse);
      expect(starts().length, 1);
      if (code == 'microphone_lost' || code == 'input_lost') {
        expect(
          events.whereType<VoiceDeviceEvent>().last.microphone,
          DeviceStatus.unavailable,
        );
      }
      if (code == 'bluetooth_unavailable') {
        expect(
          events.whereType<VoiceDeviceEvent>().last.speaker,
          DeviceStatus.unavailable,
        );
      }
    });
  }

  testWidgets('timeouts retain Stop and never auto-start or retry reclaim', (
    tester,
  ) async {
    await idle(tester);
    await backend.startConversation();
    await tester.pump(const Duration(seconds: 2));
    expect(events.whereType<VoiceErrorEvent>().last.code, 'request_timeout');
    expect(controls().canStop, isTrue);
    socket.snapshot('starting');
    await tester.pump(const Duration(seconds: 2));
    expect(events.whereType<VoiceErrorEvent>().last.code, 'readiness_timeout');
    expect(starts().length, 1);
  });

  testWidgets(
    'transport errors and malformed/foreign events do not leak or enable Start',
    (tester) async {
      socket.incoming.add({
        'type': 'voice_status',
        'protocol': 'medza.voice',
        'version': 2,
        'state': 'idle',
      });
      socket.incoming.add({'type': 'voice_capabilities', 'enabled': true});
      await backend.startConversation();
      expect(starts(), isEmpty);
      await idle(tester);
      socket.failWrites = true;
      await backend.startConversation();
      await tester.pump();
      expect(events.whereType<VoiceErrorEvent>().last.code, 'network_error');
      expect(controls().idle, isFalse);
      expect(controls().canStop, isTrue);
      socket.error('private-one', fatal: false, requestId: 'unknown');
      expect(
        events.whereType<VoiceErrorEvent>().last.message,
        isNot(contains('private')),
      );
    },
  );
}
