import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/features/dashboard/application/dashboard_controller.dart';
import 'package:robot_control_app/services/robot_authentication.dart';
import 'package:robot_control_app/services/robot_connection.dart';
import 'package:robot_control_app/services/web_socket_service.dart';
import 'package:robot_control_app/services/web_socket_transport_web.dart'
    as browser;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'robot_connection_test.dart' show MockRobot, waitUntil;

class MemoryTokenStore implements RobotTokenStore {
  final tokens = <Uri, String>{};
  Object? failure;
  Completer<String?>? pendingRead;
  @override
  Future<String?> read(Uri endpoint) async {
    if (failure != null) throw failure!;
    return pendingRead?.future ?? tokens[endpoint];
  }

  @override
  Future<void> write(Uri endpoint, String token) async {
    tokens[endpoint] = token;
  }

  @override
  Future<void> delete(Uri endpoint) async {
    tokens.remove(endpoint);
  }
}

class FailingSecureStorage extends FlutterSecureStorage {
  const FailingSecureStorage();
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw StateError('sensitive-token');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockRobot server;
  late MemoryTokenStore store;
  late ProviderContainer container;
  late DashboardController controller;
  late RobotEndpoint endpoint;
  final logs = <String>[];
  late DebugPrintCallback originalPrint;
  setUp(() {
    logs.clear();
    originalPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logs.add(message);
    };
  });
  tearDown(() => debugPrint = originalPrint);

  Future<void> start({
    String? token = 'sample-token',
    RobotNetworkMode mode = RobotNetworkMode.lanWifi,
    bool delayRead = false,
  }) async {
    server = MockRobot()..requiredToken = 'sample-token';
    if (mode == RobotNetworkMode.ethernet && token == null) {
      server.requiredToken = null;
    }
    await server.start();
    store = MemoryTokenStore();
    if (delayRead) store.pendingRead = Completer<String?>();
    endpoint = RobotEndpoint(
      ip: '127.0.0.1',
      port: server.server.port,
      mode: mode,
    );
    if (token != null) store.tokens[endpoint.uri] = token;
    container = ProviderContainer(
      overrides: [
        robotTokenStoreProvider.overrideWithValue(store),
        robotEndpointProvider.overrideWithValue(endpoint),
        robotConnectionTimingProvider.overrideWithValue(
          const RobotConnectionTiming(
            staleAfter: Duration(seconds: 2),
            reconnectAfter: Duration(seconds: 4),
            retryDelay: Duration(milliseconds: 50),
          ),
        ),
      ],
    );
    final subscription = container.listen(
      dashboardControllerProvider,
      (_, _) {},
    );
    controller = container.read(dashboardControllerProvider.notifier);
    addTearDown(() async {
      subscription.close();
      container.dispose();
      await server.close();
    });
  }

  RobotLinkStatus status() => container.read(robotLinkProvider).status;

  test(
    '101 authenticates through header; fresh telemetry still gates commands',
    () async {
      await start();
      await waitUntil(() => status() == RobotLinkStatus.awaitingTelemetry);
      expect(server.authorizations.single, 'Bearer sample-token');
      expect(server.requestUrls.single.query, isEmpty);
      expect(
        container.read(dashboardControllerProvider).value!.telemetryConnected,
        isFalse,
      );
      await expectLater(controller.sendMotion('wave_hand'), throwsStateError);
      server.telemetry();
      await waitUntil(() => status() == RobotLinkStatus.connected);
      expect(server.messages, isEmpty);
      expect(logs.join(), isNot(contains('sample-token')));
    },
  );

  test(
    '401 stops retries until credentials change, including explicit Connect and resume',
    () async {
      await start(token: 'invalid-token');
      await waitUntil(() => status() == RobotLinkStatus.authenticationRequired);
      expect(container.read(robotLinkProvider).message, contains('HTTP 401'));
      controller.connectRobot(endpoint);
      await container
          .read(robotCredentialsProvider.notifier)
          .save(endpoint, 'invalid-token');
      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 220));
      expect(server.attempts, 1);
      expect(status(), RobotLinkStatus.authenticationRequired);
      expect(logs.join(), isNot(contains('invalid-token')));
      expect(
        container.read(robotLinkProvider).message,
        isNot(contains('invalid-token')),
      );
      await container
          .read(robotCredentialsProvider.notifier)
          .save(endpoint, 'sample-token');
      await waitUntil(() => status() == RobotLinkStatus.awaitingTelemetry);
      server.telemetry();
      await waitUntil(() => status() == RobotLinkStatus.connected);
      expect(server.attempts, 2);
      expect(server.messages, isEmpty);
    },
  );

  test(
    'reconnect attaches token again; revoked token blocks retries',
    () async {
      await start();
      await waitUntil(() => status() == RobotLinkStatus.awaitingTelemetry);
      await server.sockets.last.close(
        WebSocketStatus.normalClosure,
        'sample-token',
      );
      await waitUntil(
        () =>
            server.sockets.length == 2 &&
            status() == RobotLinkStatus.awaitingTelemetry,
      );
      expect(server.authorizations, everyElement('Bearer sample-token'));
      server.requiredToken = 'rotated-token';
      await server.sockets.last.close();
      await waitUntil(() => status() == RobotLinkStatus.authenticationRequired);
      final attempts = server.attempts;
      await Future<void>.delayed(const Duration(milliseconds: 220));
      expect(server.attempts, attempts);
      expect(server.messages, isEmpty);
    },
  );

  test(
    'missing LAN token blocks networking, saving enables it, removing disables it',
    () async {
      await start(token: null);
      await waitUntil(() => status() == RobotLinkStatus.authenticationRequired);
      expect(server.attempts, 0);
      await container
          .read(robotCredentialsProvider.notifier)
          .save(endpoint, 'sample-token');
      await waitUntil(() => status() == RobotLinkStatus.awaitingTelemetry);
      await container
          .read(robotCredentialsProvider.notifier)
          .save(endpoint, null);
      await waitUntil(() => status() == RobotLinkStatus.authenticationRequired);
      expect(store.tokens, isEmpty);
      expect(server.attempts, 1);
      expect(server.messages, isEmpty);
    },
  );

  test('legacy Ethernet connects without credentials', () async {
    await start(token: null, mode: RobotNetworkMode.ethernet);
    await waitUntil(() => status() == RobotLinkStatus.awaitingTelemetry);
    expect(server.authorizations.single, isNull);
    server.telemetry();
    await waitUntil(() => status() == RobotLinkStatus.connected);
    expect(server.messages, isEmpty);
    expect(logs.join(), isNot(contains('sample-token')));
  });

  test('an endpoint switch cannot clear a rejected credential latch', () async {
    await start(token: 'invalid-token');
    await waitUntil(() => status() == RobotLinkStatus.authenticationRequired);
    final other = MockRobot();
    await other.start();
    addTearDown(other.close);
    controller.connectRobot(
      RobotEndpoint(ip: '127.0.0.1', port: other.server.port),
    );
    await waitUntil(
      () =>
          other.sockets.isNotEmpty &&
          status() == RobotLinkStatus.awaitingTelemetry,
    );
    controller.connectRobot(endpoint);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(status(), RobotLinkStatus.authenticationRequired);
    expect(server.attempts, 1);
  });

  test(
    'browser header authentication is refused and status is never parsed from text',
    () {
      expect(
        () => browser.connectSocket(Uri.parse('ws://127.0.0.1:8765/'), {
          'Authorization': 'Bearer sample-token',
        }),
        throwsUnsupportedError,
      );
      expect(
        browser.isUnauthorizedUpgrade(
          const WebSocketException('HTTP 401', 401),
        ),
        isFalse,
      );
      expect(
        WebSocketService.isUnauthorized(
          WebSocketChannelException('HTTP 401 sample-token'),
        ),
        isFalse,
      );
      expect(
        WebSocketService.isUnauthorized(
          const WebSocketException('sample-token', 403),
        ),
        isFalse,
      );
      expect(
        WebSocketService.isUnauthorized(
          WebSocketChannelException.from(
            const WebSocketException('sample-token', 401),
          ),
        ),
        isTrue,
      );
    },
  );

  test(
    'disconnect during credential loading prevents a late connection',
    () async {
      await start(delayRead: true);
      await waitUntil(() => status() == RobotLinkStatus.connecting);
      controller.disconnectRobot();
      store.pendingRead!.complete('sample-token');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(server.attempts, 0);
      expect(status(), RobotLinkStatus.disconnected);
    },
  );

  test(
    'tokens stay scoped to endpoints; errors and invalid tokens are safe',
    () async {
      final memory = MemoryTokenStore();
      final auth = BearerRobotAuthentication(memory);
      const selected = RobotEndpoint(ip: '10.0.0.1');
      memory.tokens[selected.uri] = 'sensitive-token';
      expect(await auth.upgradeHeaders(selected), {
        'Authorization': 'Bearer sensitive-token',
      });
      expect(
        await auth.upgradeHeaders(const RobotEndpoint(ip: '10.0.0.2')),
        isEmpty,
      );
      memory.failure = StateError('sensitive-token');
      final safeFailure = throwsA(
        isA<RobotCredentialException>().having(
          (error) => error.toString(),
          'message',
          isNot(contains('sensitive-token')),
        ),
      );
      await expectLater(auth.upgradeHeaders(selected), safeFailure);
      const native = OsRobotTokenStore(FailingSecureStorage());
      await expectLater(native.read(selected.uri), safeFailure);
      for (final token in [
        'bad token',
        'header\r\ninjection',
        '',
        'token\u0000',
      ]) {
        expect(isValidRobotToken(token), isFalse);
      }
    },
  );
}
