import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:robot_control_app/services/web_socket_transport_web.dart'
    if (dart.library.io) 'package:robot_control_app/services/web_socket_transport_io.dart'
    as transport;

class WebSocketService {
  const WebSocketService();

  static final Uri telemetryUri = Uri.parse('ws://192.168.123.164:8765');

  WebSocketChannel connect(Uri uri, {Map<String, String> headers = const {}}) {
    debugPrint('[WS] connecting');
    return transport.connectSocket(uri, headers);
  }

  static bool isUnauthorized(Object error) =>
      transport.isUnauthorizedUpgrade(error);

  WebSocketChannel connectTelemetry() => connect(telemetryUri);
}

final webSocketServiceProvider = Provider<WebSocketService>(
  (ref) => const WebSocketService(),
  name: 'WebSocketServiceProvider',
);

/// Commands use the dashboard-owned channel; this class never connects or retries.
class MotionCommandSession {
  Set<String> supportedRecordings = {};

  static bool isRecordingFilename(String name) =>
      RegExp(r'^[A-Za-z0-9_-]+\.json$').hasMatch(name);

  void setMotionCatalog(Iterable<String> filenames) {
    supportedRecordings = Set.unmodifiable(
      filenames.where(isRecordingFilename),
    );
  }

  static const supportedActions = {
    'wave_hand',
    'greeting_pose',
    'play_recorded_motion',
    'stop_motion',
  };

  Completer<Map<String, dynamic>>? _pending;
  String? _action;
  String? _motion;
  String? _interruptedAction;
  String? _interruptedMotion;
  void Function(Map<String, dynamic>)? _onResult;
  bool _accepted = false;
  Timer? _timer;
  // Set only after a command was written to the socket, so it always means a
  // possibly live motion has an unknown outcome. Only a verified live Stop
  // clears it; disconnects and simulated results never do.
  bool _uncertain = false;
  bool _requireAction = false;

  // Temporary diagnostics: no command state is changed here.
  void _debugState(String event) {
    debugPrint(
      '[MOTION DEBUG] session=${identityHashCode(this)} $event '
      'pending=${_pending != null} completed=${_pending?.isCompleted} '
      'action=$_action motion=$_motion accepted=$_accepted '
      'uncertain=$_uncertain requireAction=$_requireAction '
      'interruptedAction=$_interruptedAction interruptedMotion=$_interruptedMotion',
    );
  }

  Future<Map<String, dynamic>> send(
    String action,
    void Function(String) write, {
    String? motion,
    void Function(Map<String, dynamic>)? onResult,
  }) {
    _debugState('send attempt action=$action motion=$motion');
    if (!supportedActions.contains(action)) {
      debugPrint('[MOTION DEBUG] send blocked: unsupported action=$action');
      return Future.error(
        StateError('$action is not connected to the robot yet'),
      );
    }
    if (action == 'play_recorded_motion' &&
        !supportedRecordings.contains(motion)) {
      debugPrint(
        '[MOTION DEBUG] send blocked: motion=$motion absent from catalog',
      );
      return Future.error(
        StateError('Unsupported recorded motion. Command not sent.'),
      );
    }
    if (action != 'stop_motion' && (_pending != null || _uncertain)) {
      _debugState('send blocked: pending or uncertain');
      return Future.error(
        StateError(
          'A command is pending or its outcome is unknown. Stop remains available.',
        ),
      );
    }
    if (_pending != null) {
      if (_action == 'stop_motion') {
        _debugState('send blocked: Stop already pending');
        return Future.error(
          StateError('Stop is already pending. No duplicate sent.'),
        );
      }
      _interruptedAction = _action;
      _interruptedMotion = _motion;
      _uncertain = true;
      _requireAction = true;
      _fail('Previous command superseded by Stop; its outcome is unknown.');
    }
    final pending = Completer<Map<String, dynamic>>();
    _pending = pending;
    _action = action;
    _motion = motion;
    _onResult = onResult;
    _accepted = false;
    _startTimeout(const Duration(seconds: 45));
    try {
      final payload = jsonEncode({
        'type': 'motion',
        'action': action,
        if (action == 'play_recorded_motion') 'motion': motion,
      });
      debugPrint('[MOTION DEBUG] outgoing motion: $payload');
      write(payload);
      _debugState('socket write returned');
    } on Object catch (error) {
      debugPrint('[MOTION DEBUG] socket write threw: $error');
      _uncertain = true;
      _requireAction = true;
      _fail('Could not send command; robot outcome unknown.');
    }
    return pending.future;
  }

  void handleResult(Map<String, dynamic> result) {
    debugPrint('[MOTION DEBUG] incoming result: ${jsonEncode(result)}');
    _debugState(
      'before response action=${result['action']} motion=${result['motion']}',
    );
    try {
      _processResult(result);
    } on Object catch (error) {
      debugPrint('[MOTION DEBUG] response processing threw: $error');
      rethrow;
    } finally {
      _debugState(
        'after response action=${result['action']} motion=${result['motion']}',
      );
    }
  }

  void _processResult(Map<String, dynamic> result) {
    if (_pending == null) {
      debugPrint('[MOTION DEBUG] response ignored: no pending command');
      return;
    }
    final action = result['action'];
    final motion = result['motion'];
    final interruptedStopped =
        _action == 'stop_motion' &&
        result['status'] == 'stopped' &&
        (action == null || action == _interruptedAction) &&
        (motion == null || motion == _interruptedMotion);
    if (!interruptedStopped) {
      if (action != null && action != _action) {
        debugPrint(
          '[MOTION DEBUG] response ignored: action mismatch '
          'received=$action expected=$_action',
        );
        return;
      }
      if (motion != null &&
          motion != _motion &&
          !(_action == 'stop_motion' &&
              action == 'stop_motion' &&
              motion == _interruptedMotion)) {
        debugPrint(
          '[MOTION DEBUG] response ignored: motion mismatch '
          'received=$motion expected=$_motion',
        );
        return;
      }
    }
    // A simulation result clears pending state, so it must name the exact command.
    if (result['status'] == 'dry_run' &&
        (action != _action ||
            (_action == 'play_recorded_motion' && motion != _motion))) {
      debugPrint(
        '[MOTION DEBUG] response ignored: uncorrelated dry_run '
        'received=$action/$motion expected=$_action/$_motion',
      );
      return;
    }
    // After interruption/timeout, an untagged reply could belong to an old command.
    if (_requireAction && action == null && !interruptedStopped) {
      debugPrint(
        '[MOTION DEBUG] response ignored: action required but missing',
      );
      return;
    }
    debugPrint(
      '[MOTION DEBUG] correlation matched interruptedStopped=$interruptedStopped',
    );
    var status = result['status'];
    if (status == null &&
        _action != 'play_recorded_motion' &&
        (result['success'] == true || result['ok'] == true)) {
      status = _action == 'stop_motion' ? 'stopped' : 'completed';
    }
    if (!const ['busy', 'unsupported_motion'].contains(status) &&
        (result['type'] == 'error' ||
            result['success'] == false ||
            result['ok'] == false ||
            (result['error'] != null && result['error'] != false) ||
            const ['error', 'rejected', 'unsupported'].contains(status))) {
      status = 'failed';
    }
    if (status == 'accepted') {
      if (!_accepted) {
        _accepted = true;
        _startTimeout(const Duration(minutes: 5));
        _onResult?.call({...result, 'status': status});
      } else {
        debugPrint('[MOTION DEBUG] response ignored: duplicate accepted');
      }
      return;
    }
    // Dry run is a confirmed simulation, never physical motion completion.
    final confirmedDryRun = status == 'dry_run' && result['dry_run'] == true;
    if (!confirmedDryRun &&
        !const [
          'completed',
          'stopped',
          'failed',
          'busy',
          'unsupported_motion',
        ].contains(status)) {
      debugPrint(
        '[MOTION DEBUG] response rejected: unrecognized status=$status',
      );
      _uncertain = true;
      _requireAction = true;
      _fail(
        'Unrecognized backend result; robot outcome unknown: ${result['message'] ?? result}',
      );
      return;
    }
    final update = {...result, 'status': status};
    debugPrint(
      '[MOTION DEBUG] terminal response status=$status; completing pending future',
    );
    final pending = _pending!;
    final notify = _onResult;
    _timer?.cancel();
    _pending = null;
    _action = null;
    _motion = null;
    _onResult = null;
    // A failed or simulated Stop is not proof the robot is safe.
    if (const ['stopped', 'completed'].contains(status) &&
        result['dry_run'] != true) {
      _uncertain = false;
      _requireAction = false;
      _interruptedAction = null;
      _interruptedMotion = null;
    }
    // Release the awaiting controller even if a UI result listener throws.
    pending.complete(update);
    notify?.call(update);
  }

  void _startTimeout(Duration duration) {
    _timer?.cancel();
    _timer = Timer(duration, () {
      _markPendingOutcomeUnknown();
      _fail('Command timed out; robot outcome unknown. No retry was sent.');
    });
  }

  void _markPendingOutcomeUnknown() {
    if (_pending == null) return;
    if (_action != 'stop_motion') {
      _interruptedAction = _action;
      _interruptedMotion = _motion;
    }
    _uncertain = true;
    _requireAction = true;
  }

  void disconnect() {
    // A command already on the wire may have reached a live robot.
    _markPendingOutcomeUnknown();
    _fail('WebSocket disconnected; any sent command has an unknown outcome.');
  }

  void _fail(String message) {
    _debugState('failure before: $message');
    _timer?.cancel();
    final pending = _pending;
    _pending = null;
    _action = null;
    _motion = null;
    _onResult = null;
    pending?.completeError(StateError(message));
    _debugState('failure after');
  }
}
