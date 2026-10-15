import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/features/dashboard/application/dashboard_controller.dart';
import 'package:robot_control_app/services/robot_connection.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<void> waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 4));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for connection state');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class MockRobot {
  late HttpServer server;
  final sockets = <WebSocket>[];
  final messages = <String>[];
  bool rejectConnections = false;
  int attempts = 0;
  String? requiredToken;
  final authorizations = <String?>[];
  final requestUrls = <Uri>[];
  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      attempts++;
      authorizations.add(
        request.headers.value(HttpHeaders.authorizationHeader),
      );
      requestUrls.add(request.uri);
      if (requiredToken != null &&
          authorizations.last != 'Bearer $requiredToken') {
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
        return;
      }
      if (rejectConnections) {
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
        return;
      }
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((message) => messages.add(message as String));
    });
  }

  void telemetry() => sockets.last.add(
    jsonEncode({
      'battery': {'soc': 75},
    }),
  );

  Future<void> close() async {
    for (final socket in sockets) {
      await socket.close();
    }
    await server.close(force: true);
  }
}

class PendingAuthentication implements RobotAuthenticationAdapter {
  final ready = Completer<void>();
  @override
  Future<Map<String, String>> upgradeHeaders(RobotEndpoint endpoint) async =>
      const {};
  @override
  Future<void> authenticate(WebSocketChannel channel) => ready.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockRobot server;
  late ProviderContainer container;
  late DashboardController controller;
  late ProviderSubscription<dynamic> subscription;

  Future<void> start({RobotAuthenticationAdapter? auth}) async {
    server = MockRobot();
    await server.start();
    container = ProviderContainer(
      overrides: [
        robotEndpointProvider.overrideWithValue(
          RobotEndpoint(ip: '127.0.0.1', port: server.server.port),
        ),
        robotConnectionTimingProvider.overrideWithValue(
          const RobotConnectionTiming(
            staleAfter: Duration(milliseconds: 250),
            reconnectAfter: Duration(milliseconds: 700),
            retryDelay: Duration(milliseconds: 50),
          ),
        ),
        robotAuthenticationProvider.overrideWithValue(auth),
      ],
    );
    subscription = container.listen(dashboardControllerProvider, (_, _) {});
    controller = container.read(dashboardControllerProvider.notifier);
    await waitUntil(() => server.sockets.isNotEmpty);
    if (auth == null) {
      await waitUntil(
        () =>
            container.read(robotLinkProvider).status ==
            RobotLinkStatus.awaitingTelemetry,
      );
    }
  }

  Future<void> cleanup() async {
    subscription.close();
    container.dispose();
    await server.close();
  }

  test('validates endpoints and preserves legacy Ethernet default', () {
    final local = ProviderContainer();
    addTearDown(local.dispose);
    expect(
      local.read(robotEndpointProvider).uri.toString(),
      'ws://192.168.123.164:8765',
    );
    expect(
      const RobotEndpoint(
        ip: '10.2.3.4',
        port: 8765,
        mode: RobotNetworkMode.lanWifi,
      ).uri.host,
      '10.2.3.4',
    );
    for (final ip in [
      '8.8.8.8',
      '',
      '192.168.1.999',
      'example.com',
      '192.168.1.1/path',
    ]) {
      expect(() => RobotEndpoint(ip: ip).uri, throwsFormatException);
    }
    expect(
      () => const RobotEndpoint(ip: '10.0.0.1', port: 0).uri,
      throwsFormatException,
    );
  });

  test(
    'requires fresh telemetry, preserves protocol, never replays after reconnect',
    () async {
      await start();
      addTearDown(cleanup);
      await expectLater(controller.sendMotion('wave_hand'), throwsStateError);
      server.telemetry();
      await waitUntil(
        () =>
            container.read(robotLinkProvider).status ==
            RobotLinkStatus.connected,
      );
      final pending = controller.sendMotion('wave_hand');
      final failed = expectLater(pending, throwsStateError);
      await waitUntil(() => server.messages.isNotEmpty);
      expect(jsonDecode(server.messages.single), {
        'type': 'motion',
        'action': 'wave_hand',
      });
      await server.sockets.last.close();
      await failed;
      await waitUntil(
        () =>
            server.sockets.length == 2 &&
            container.read(robotLinkProvider).status ==
                RobotLinkStatus.awaitingTelemetry,
      );
      server.telemetry();
      await waitUntil(
        () =>
            container.read(robotLinkProvider).status ==
            RobotLinkStatus.connected,
      );
      expect(server.messages.length, 1);
      controller.disconnectRobot();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(server.sockets.length, 2);
      expect(
        container.read(robotLinkProvider).status,
        RobotLinkStatus.disconnected,
      );
    },
  );

  test(
    'malformed frames and command responses never refresh stale telemetry',
    () async {
      await start();
      addTearDown(cleanup);
      server.telemetry();
      await waitUntil(
        () =>
            container.read(robotLinkProvider).status ==
            RobotLinkStatus.connected,
      );
      final timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
        server.sockets.last.add('{invalid');
        server.sockets.last.add(jsonEncode({'battery': {}}));
        server.sockets.last.add(
          jsonEncode({'type': 'motion_result', 'status': 'completed'}),
        );
      });
      addTearDown(timer.cancel);
      await waitUntil(
        () =>
            container.read(robotLinkProvider).status ==
            RobotLinkStatus.degraded,
      );
      expect(
        container.read(dashboardControllerProvider).value!.telemetryConnected,
        isFalse,
      );
      await expectLater(controller.sendMotion('wave_hand'), throwsStateError);
      await waitUntil(() => server.sockets.length >= 2);
      expect(server.messages, isEmpty);
    },
  );

  test(
    'switches endpoint and does not reconnect after explicit disconnect on resume',
    () async {
      await start();
      addTearDown(cleanup);
      final second = MockRobot();
      await second.start();
      addTearDown(second.close);
      controller.connectRobot(
        RobotEndpoint(
          ip: '127.0.0.1',
          port: second.server.port,
          mode: RobotNetworkMode.lanWifi,
        ),
      );
      await waitUntil(
        () =>
            second.sockets.isNotEmpty &&
            container.read(robotLinkProvider).status ==
                RobotLinkStatus.awaitingTelemetry,
      );
      second.telemetry();
      await waitUntil(
        () =>
            container.read(robotLinkProvider).status ==
            RobotLinkStatus.connected,
      );
      expect(
        container.read(selectedRobotEndpointProvider).port,
        second.server.port,
      );
      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      controller.disconnectRobot();
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(second.sockets.length, 1);
      expect(second.messages, isEmpty);
    },
  );

  test(
    'authentication adapter must finish before telemetry enables commands',
    () async {
      final auth = PendingAuthentication();
      await start(auth: auth);
      addTearDown(cleanup);
      server.telemetry();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await expectLater(controller.sendMotion('wave_hand'), throwsStateError);
      auth.ready.complete();
      await waitUntil(
        () =>
            container.read(robotLinkProvider).status ==
            RobotLinkStatus.awaitingTelemetry,
      );
      server.telemetry();
      await waitUntil(
        () =>
            container.read(robotLinkProvider).status ==
            RobotLinkStatus.connected,
      );
      expect(server.messages, isEmpty);
    },
  );

  test(
    'handshake failure reports an error and retries without commands',
    () async {
      await start();
      addTearDown(cleanup);
      server.rejectConnections = true;
      await server.sockets.last.close();
      await waitUntil(
        () =>
            server.attempts >= 2 &&
            container.read(robotLinkProvider).status ==
                RobotLinkStatus.reconnecting,
      );
      expect(
        container.read(robotLinkProvider).message,
        contains('Connection lost:'),
      );
      await expectLater(controller.sendMotion('wave_hand'), throwsStateError);
      server.rejectConnections = false;
      await waitUntil(
        () =>
            server.sockets.length == 2 &&
            container.read(robotLinkProvider).status ==
                RobotLinkStatus.awaitingTelemetry,
      );
      expect(server.messages, isEmpty);
    },
  );

  test('app resume reconnects telemetry without replaying commands', () async {
    await start();
    addTearDown(cleanup);
    server.telemetry();
    await waitUntil(
      () =>
          container.read(robotLinkProvider).status == RobotLinkStatus.connected,
    );
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(
      container.read(robotLinkProvider).status,
      RobotLinkStatus.disconnected,
    );
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await waitUntil(
      () =>
          server.sockets.length == 2 &&
          container.read(robotLinkProvider).status ==
              RobotLinkStatus.awaitingTelemetry,
    );
    expect(server.messages, isEmpty);
  });

  test('audio frames share the authenticated socket without touching '
      'telemetry or motion', () async {
    await start();
    addTearDown(cleanup);
    server.telemetry();
    await waitUntil(
      () =>
          container.read(robotLinkProvider).status == RobotLinkStatus.connected,
    );
    final frames = <Map<String, dynamic>>[];
    final audio = controller.audioFrames.listen(frames.add);
    addTearDown(audio.cancel);

    controller.sendAudioFrame({
      'type': 'audio_get_capabilities',
      'request_id': 'c1',
    });
    expect(
      () =>
          controller.sendAudioFrame({'type': 'motion', 'action': 'wave_hand'}),
      throwsArgumentError,
    );
    await waitUntil(() => server.messages.isNotEmpty);
    expect(server.messages, [
      jsonEncode({'type': 'audio_get_capabilities', 'request_id': 'c1'}),
    ]);

    server.sockets.last
      ..add(
        jsonEncode({
          'type': 'audio_capabilities',
          'request_id': 'c1',
          'protocol': 'medza.audio',
          'protocol_version': 1,
        }),
      )
      ..add(
        jsonEncode({
          'type': 'audio_result',
          'action': 'set_settings',
          'status': 'busy',
          'error': 'audio_session_active',
        }),
      );
    await waitUntil(() => frames.length == 2);
    expect(frames.map((f) => f['type']), [
      'audio_capabilities',
      'audio_result',
    ]);
    expect(container.read(robotLinkProvider).status, RobotLinkStatus.connected);

    controller.disconnectRobot();
    expect(
      () => controller.sendAudioFrame({'type': 'audio_get_devices'}),
      throwsStateError,
    );
  });
}
