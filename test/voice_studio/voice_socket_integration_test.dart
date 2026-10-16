import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/features/dashboard/application/dashboard_controller.dart';
import 'package:robot_control_app/features/settings/application/audio_devices_controller.dart';
import 'package:robot_control_app/features/settings/data/audio_device_backend.dart';
import 'package:robot_control_app/features/voice_studio/application/realtime_voice_controller.dart';
import 'package:robot_control_app/features/voice_studio/application/voice_studio_providers.dart';
import 'package:robot_control_app/features/voice_studio/domain/voice_models.dart';
import 'package:robot_control_app/services/robot_authentication.dart';
import 'package:robot_control_app/services/robot_connection.dart';

import '../robot_authentication_test.dart' show MemoryTokenStore;
import '../robot_connection_test.dart' show MockRobot, waitUntil;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'authenticated shared socket: observe, Start, reclaim, rotate, Stop; no secrets in logs',
    () async {
      final server = MockRobot()..requiredToken = 'test-bearer';
      await server.start();
      final endpoint = RobotEndpoint(
        ip: '127.0.0.1',
        port: server.server.port,
        mode: RobotNetworkMode.lanWifi,
      );
      final store = MemoryTokenStore()..tokens[endpoint.uri] = 'test-bearer';
      final logs = <String>[];
      final originalPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) logs.add(message);
      };
      final container = ProviderContainer(
        overrides: [
          robotEndpointProvider.overrideWithValue(endpoint),
          robotTokenStoreProvider.overrideWithValue(store),
          audioDeviceBackendProvider.overrideWith((ref) {
            final backend = MockAudioDeviceBackend();
            ref.onDispose(backend.dispose);
            return backend;
          }),
          robotConnectionTimingProvider.overrideWithValue(
            const RobotConnectionTiming(
              staleAfter: Duration(minutes: 1),
              reconnectAfter: Duration(minutes: 2),
              retryDelay: Duration(milliseconds: 20),
            ),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await server.close();
        debugPrint = originalPrint;
      });
      container.read(voiceDemoModeProvider.notifier).set(false);
      container.listen(realtimeVoiceProvider, (_, _) {});
      final controller = container.read(realtimeVoiceProvider.notifier);
      List<Map<String, dynamic>> frames(String type) => server.messages
          .map((m) => jsonDecode(m) as Map<String, dynamic>)
          .where((m) => m['type'] == type)
          .toList();
      void send(Map<String, Object?> frame) =>
          server.sockets.last.add(jsonEncode(frame));
      void capabilities() => send({
        'type': 'voice_capabilities',
        'protocol': 'medza.voice',
        'version': 1,
        'request_id': frames('voice_get_capabilities').last['request_id'],
        'enabled': true,
        'ownership': 'connection_with_resume_token',
        'requests': [
          'voice_get_capabilities',
          'voice_get_status',
          'voice_start',
          'voice_stop',
        ],
        'automatic_greeting': false,
      });
      void status(String value, {String? requestId, String? token}) => send({
        'type': 'voice_status',
        'protocol': 'medza.voice',
        'version': 1,
        'state': value,
        'session_id': 'private-session',
        'request_id': requestId,
        'reason': null,
        'resume_token': ?token,
      });

      await waitUntil(() => frames('voice_get_status').isNotEmpty);
      expect(server.authorizations, ['Bearer test-bearer']);
      expect(frames('voice_start'), isEmpty);
      capabilities();
      status(
        'idle',
        requestId: frames('voice_get_status').last['request_id'] as String,
      );
      await waitUntil(() => container.read(realtimeVoiceProvider).canStart);
      await controller.start();
      await waitUntil(() => frames('voice_start').length == 1);
      expect(
        frames('voice_start').single.keys,
        unorderedEquals(['type', 'request_id']),
      );
      status(
        'starting',
        requestId: frames('voice_start').last['request_id'] as String,
        token: 'resume-original',
      );
      await waitUntil(() => container.read(realtimeVoiceProvider).liveCanStop);
      expect(
        container.read(realtimeVoiceProvider).session,
        VoiceSessionState.starting,
      );
      status('listening');
      await waitUntil(
        () =>
            container.read(realtimeVoiceProvider).session ==
            VoiceSessionState.listening,
      );
      final telemetryBefore = container
          .read(dashboardControllerProvider)
          .value
          ?.telemetry;
      expect(
        telemetryBefore,
        isNull,
        reason: 'Voice replies are not telemetry freshness',
      );

      await server.sockets.last.close();
      await waitUntil(
        () =>
            server.sockets.length == 2 &&
            frames('voice_get_status').length == 2,
      );
      expect(server.authorizations, [
        'Bearer test-bearer',
        'Bearer test-bearer',
      ]);
      expect(frames('voice_start').length, 1);
      capabilities();
      status(
        'listening',
        requestId: frames('voice_get_status').last['request_id'] as String,
      );
      await waitUntil(() => frames('voice_start').length == 2);
      expect(frames('voice_start').last['session_id'], 'private-session');
      expect(frames('voice_start').last['resume_token'], 'resume-original');
      status(
        'listening',
        requestId: frames('voice_start').last['request_id'] as String,
        token: 'resume-rotated',
      );
      await waitUntil(
        () =>
            container.read(realtimeVoiceProvider).session ==
            VoiceSessionState.listening,
      );
      await server.sockets.last.close();
      await waitUntil(() => frames('voice_get_status').length == 3);
      capabilities();
      status(
        'listening',
        requestId: frames('voice_get_status').last['request_id'] as String,
      );
      await waitUntil(() => frames('voice_start').length == 3);
      expect(frames('voice_start').last['resume_token'], 'resume-rotated');
      status(
        'listening',
        requestId: frames('voice_start').last['request_id'] as String,
        token: 'resume-third',
      );
      await waitUntil(
        () =>
            container.read(realtimeVoiceProvider).session ==
            VoiceSessionState.listening,
      );
      await controller.stop();
      await waitUntil(() => frames('voice_stop').isNotEmpty);
      status('idle'); // unsolicited terminal push may precede the Stop response
      status(
        'idle',
        requestId: frames('voice_stop').last['request_id'] as String,
      );
      await waitUntil(() => !container.read(realtimeVoiceProvider).canStop);
      expect(frames('voice_start').length, 3);
      expect(store.tokens, {
        endpoint.uri: 'test-bearer',
      }, reason: 'No resume credentials are persisted');
      final visibleLog = container
          .read(voiceEventLogProvider)
          .entries
          .map((e) => e.message)
          .join('\n');
      for (final secret in [
        'test-bearer',
        'resume-original',
        'resume-rotated',
        'resume-third',
        'private-session',
      ]) {
        expect(logs.join('\n'), isNot(contains(secret)));
        expect(visibleLog, isNot(contains(secret)));
        expect(
          container.read(realtimeVoiceProvider).transcriptText,
          isNot(contains(secret)),
        );
      }
      expect(frames('motion'), isEmpty);
    },
  );
}
