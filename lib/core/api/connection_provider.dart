import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/models/connection_state.dart';
import 'package:robot_control_app/services/robot_service.dart';

class ConnectionNotifier extends Notifier<RobotConnectionState> {
  @override
  RobotConnectionState build() => const RobotConnectionState.disconnected();

  Future<void> check() async {
    state = const RobotConnectionState.connecting();
    try {
      await ref.read(robotServiceProvider).health();
      state = const RobotConnectionState.connected();
    } on Object catch (error) {
      state = RobotConnectionState.failed(error.toString());
    }
  }

  void disconnect() => state = const RobotConnectionState.disconnected();
}

final connectionProvider = NotifierProvider<ConnectionNotifier, RobotConnectionState>(
  ConnectionNotifier.new,
  name: 'ConnectionProvider',
);
