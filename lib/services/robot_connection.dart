import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/services/web_socket_service.dart';
import 'package:robot_control_app/services/robot_authentication.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum RobotNetworkMode { ethernet, lanWifi }

enum RobotLinkStatus {
  disconnected,
  connecting,
  awaitingTelemetry,
  connected,
  degraded,
  reconnecting,
  authenticationRequired,
}

class RobotEndpoint {
  const RobotEndpoint({
    required this.ip,
    this.port = 8765,
    this.mode = RobotNetworkMode.ethernet,
  });

  final String ip;
  final int port;
  final RobotNetworkMode mode;

  Uri get uri {
    final parts = ip.trim().split('.');
    final bytes = parts.map(int.tryParse).toList();
    if (bytes.length != 4 ||
        bytes.any((n) => n == null || n < 0 || n > 255) ||
        parts.any((part) => !RegExp(r'^\d{1,3}$').hasMatch(part))) {
      throw const FormatException('Enter a private IPv4 robot address.');
    }
    final a = bytes[0]!;
    final b = bytes[1]!;
    if (!(a == 10 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168) ||
        a == 127 ||
        (a == 169 && b == 254))) {
      throw const FormatException(
        'Public internet addresses are not supported.',
      );
    }
    if (port < 1 || port > 65535) {
      throw const FormatException('Port must be between 1 and 65535.');
    }
    return Uri(scheme: 'ws', host: bytes.join('.'), port: port);
  }
}

class RobotLinkState {
  const RobotLinkState(this.status, {this.message, this.lastTelemetryAt});
  final RobotLinkStatus status;
  final String? message;
  final DateTime? lastTelemetryAt;
}

class RobotLinkNotifier extends Notifier<RobotLinkState> {
  @override
  RobotLinkState build() => const RobotLinkState(RobotLinkStatus.disconnected);
  void update(RobotLinkState next) => state = next;
}

final robotLinkProvider = NotifierProvider<RobotLinkNotifier, RobotLinkState>(
  RobotLinkNotifier.new,
  name: 'RobotLinkProvider',
);

final robotEndpointProvider = Provider<RobotEndpoint>(
  (ref) => RobotEndpoint(ip: WebSocketService.telemetryUri.host),
  name: 'RobotEndpointProvider',
);

class RobotConnectionTiming {
  const RobotConnectionTiming({
    this.staleAfter = const Duration(seconds: 5),
    this.reconnectAfter = const Duration(seconds: 15),
    this.retryDelay = const Duration(seconds: 2),
    this.handshakeTimeout = const Duration(seconds: 10),
  });
  final Duration staleAfter;
  final Duration reconnectAfter;
  final Duration retryDelay;
  final Duration handshakeTimeout;
}

final robotConnectionTimingProvider = Provider(
  (ref) => const RobotConnectionTiming(),
  name: 'RobotConnectionTimingProvider',
);

/// Authentication happens during HTTP upgrade; no JSON authentication messages.
abstract interface class RobotAuthenticationAdapter {
  Future<Map<String, String>> upgradeHeaders(RobotEndpoint endpoint);
  Future<void> authenticate(WebSocketChannel channel);
}

class SelectedRobotEndpoint extends Notifier<RobotEndpoint> {
  @override
  RobotEndpoint build() => ref.read(robotEndpointProvider);
  void select(RobotEndpoint endpoint) => state = endpoint;
}

final selectedRobotEndpointProvider =
    NotifierProvider<SelectedRobotEndpoint, RobotEndpoint>(
      SelectedRobotEndpoint.new,
      name: 'SelectedRobotEndpointProvider',
    );

final robotAuthenticationProvider = Provider<RobotAuthenticationAdapter?>(
  (ref) => BearerRobotAuthentication(ref.read(robotTokenStoreProvider)),
  name: 'RobotAuthenticationProvider',
);
