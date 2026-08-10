enum ConnectionStatus { disconnected, connecting, connected, failed }

class RobotConnectionState {
  const RobotConnectionState._({required this.status, this.message});

  const RobotConnectionState.connected()
      : this._(status: ConnectionStatus.connected);

  const RobotConnectionState.connecting()
      : this._(status: ConnectionStatus.connecting);

  const RobotConnectionState.disconnected()
      : this._(status: ConnectionStatus.disconnected);

  const RobotConnectionState.failed(String message)
      : this._(status: ConnectionStatus.failed, message: message);

  final ConnectionStatus status;
  final String? message;

  bool get isConnected => status == ConnectionStatus.connected;
}
