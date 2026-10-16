import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/models/dashboard_data.dart';
import 'package:robot_control_app/services/web_socket_service.dart';
import 'package:robot_control_app/services/robot_connection.dart';
import 'package:robot_control_app/services/robot_authentication.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const dashboardTelemetryReconnectDelay = Duration(seconds: 2);

class DashboardController extends AsyncNotifier<DashboardData>
    with WidgetsBindingObserver {
  final Completer<DashboardData> _initialTelemetry = Completer<DashboardData>();
  Timer? _telemetryReconnectTimer;
  StreamSubscription<dynamic>? _telemetrySubscription;
  WebSocketChannel? _telemetryChannel;
  bool _telemetryConnected = false;
  bool _authenticated = false;
  bool _disposed = false;
  final _motionCommands = MotionCommandSession();
  final _audioFrames = StreamController<Map<String, dynamic>>.broadcast();
  final _voiceFrames = StreamController<Map<String, dynamic>>.broadcast();
  final _telemetryHistory = <DashboardTelemetry>[];
  final _historySampleClock = Stopwatch();
  Completer<List<String>>? _catalogRequest;
  late RobotEndpoint _endpoint;
  late RobotConnectionTiming _timing;
  bool _connectionRequested = true;
  bool _suspended = false;
  int _retryAttempt = 0;
  Timer? _freshnessTimer;
  final _telemetryClock = Stopwatch();
  DateTime? _lastTelemetryAt;
  bool _opening = false;
  int _connectionGeneration = 0;
  final _authenticationBlocks = <Uri, String>{};
  bool get _authenticationBlocked =>
      _authenticationBlocks.containsKey(_endpoint.uri);

  void _status(RobotLinkStatus status, [String? message]) {
    if (!_disposed) {
      ref
          .read(robotLinkProvider.notifier)
          .update(
            RobotLinkState(
              status,
              message: message,
              lastTelemetryAt: _lastTelemetryAt,
            ),
          );
    }
  }

  void connectRobot(RobotEndpoint endpoint) {
    endpoint.uri; // Validate before replacing a working connection.
    _closeConnection();
    _endpoint = endpoint;
    ref.read(selectedRobotEndpointProvider.notifier).select(endpoint);
    _retryAttempt = 0;
    _connectionRequested = true;
    _connectTelemetry();
  }

  void disconnectRobot() {
    _connectionRequested = false;
    _closeConnection();
    _status(RobotLinkStatus.disconnected);
  }

  void _closeConnection() {
    _connectionGeneration++;
    _opening = false;
    _telemetryReconnectTimer?.cancel();
    _telemetryReconnectTimer = null;
    _freshnessTimer?.cancel();
    _telemetryClock.stop();
    _lastTelemetryAt = null;
    final channel = _telemetryChannel;
    _telemetryChannel = null;
    final subscription = _telemetrySubscription;
    _telemetrySubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    if (channel != null) unawaited(channel.sink.close());
    _setTelemetryOffline();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _suspended = false;
      _connectTelemetry();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _suspended = true;
      _closeConnection();
      _status(
        RobotLinkStatus.disconnected,
        'App suspended; commands were not replayed.',
      );
    }
  }

  Future<List<String>> getMotionCatalog() async {
    final channel = _telemetryChannel;
    if (_disposed ||
        !_telemetryConnected ||
        channel == null ||
        _telemetryClock.elapsed >= _timing.staleAfter) {
      throw StateError('WebSocket disconnected. Catalog unavailable.');
    }
    final existing = _catalogRequest;
    if (existing != null) {
      return existing.future.timeout(const Duration(seconds: 10));
    }
    final request = Completer<List<String>>();
    _catalogRequest = request;
    try {
      channel.sink.add(jsonEncode({'type': 'get_motion_catalog'}));
      return await request.future.timeout(const Duration(seconds: 10));
    } finally {
      if (identical(_catalogRequest, request)) _catalogRequest = null;
    }
  }

  void _handleMotionCatalog(Map<String, dynamic> message) {
    final request = _catalogRequest;
    if (request == null || request.isCompleted) return;
    final motions = message['motions'];
    if (motions is! List ||
        motions.any(
          (name) =>
              name is! String ||
              !MotionCommandSession.isRecordingFilename(name),
        )) {
      request.completeError(FormatException('Invalid motion catalog response'));
      return;
    }
    final filenames = motions.cast<String>().toSet().toList(growable: false);
    _motionCommands.setMotionCatalog(filenames);
    request.complete(filenames);
  }

  void _disconnectCatalog() {
    final request = _catalogRequest;
    _catalogRequest = null;
    if (request != null && !request.isCompleted) {
      request.completeError(
        StateError('WebSocket disconnected. Catalog unavailable.'),
      );
    }
  }

  /// Incoming `medza.audio` frames from the robot socket.
  Stream<Map<String, dynamic>> get audioFrames => _audioFrames.stream;

  /// Private voice responses are routed without logging their payloads.
  Stream<Map<String, dynamic>> get voiceFrames => _voiceFrames.stream;

  void sendVoiceFrame(Map<String, Object?> frame) {
    if (!const {
      'voice_get_capabilities',
      'voice_get_status',
      'voice_start',
      'voice_stop',
    }.contains(frame['type'])) {
      throw ArgumentError('Unsupported voice request');
    }
    final channel = _telemetryChannel;
    if (_disposed || !_authenticated || channel == null) {
      throw StateError('Robot is not connected.');
    }
    channel.sink.add(jsonEncode(frame));
  }

  /// Sends one `audio_*` frame on the existing authenticated socket.
  void sendAudioFrame(Map<String, Object?> frame) {
    final type = frame['type'];
    if (type is! String || !type.startsWith('audio_')) {
      throw ArgumentError.value(type, 'type', 'Only audio_* frames');
    }
    final channel = _telemetryChannel;
    if (_disposed || !_authenticated || channel == null) {
      throw StateError('Robot is not connected.');
    }
    channel.sink.add(jsonEncode(frame));
  }

  Future<Map<String, dynamic>> sendRecordedMotion(
    String filename, {
    void Function(Map<String, dynamic>)? onResult,
  }) =>
      sendMotion('play_recorded_motion', motion: filename, onResult: onResult);

  Future<Map<String, dynamic>> sendMotion(
    String action, {
    String? motion,
    void Function(Map<String, dynamic>)? onResult,
  }) {
    final channel = _telemetryChannel;
    if (_disposed ||
        !_telemetryConnected ||
        channel == null ||
        _telemetryClock.elapsed >= _timing.staleAfter) {
      debugPrint(
        '[MOTION DEBUG] send blocked: disconnected '
        'action=$action motion=$motion disposed=$_disposed '
        'connected=$_telemetryConnected channelPresent=${channel != null}',
      );
      return Future.error(
        StateError('WebSocket disconnected. Command not sent.'),
      );
    }
    return _motionCommands.send(
      action,
      channel.sink.add,
      motion: motion,
      onResult: onResult,
    );
  }

  @override
  Future<DashboardData> build() async {
    _endpoint = ref.read(selectedRobotEndpointProvider);
    _timing = ref.read(robotConnectionTimingProvider);
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(_dispose);
    ref.listen(robotCredentialsProvider, (_, change) {
      if (change == null) return;
      _authenticationBlocks.remove(change.endpoint);
      if (change.endpoint != _endpoint.uri) return;
      _retryAttempt = 0;
      _closeConnection();
      if (_connectionRequested) unawaited(_connectTelemetry());
    });
    scheduleMicrotask(_connectTelemetry);
    return _initialTelemetry.future;
  }

  Future<void> _connectTelemetry() async {
    if (_disposed ||
        !_connectionRequested ||
        _suspended ||
        _telemetryChannel != null ||
        _opening) {
      return;
    }
    if (_authenticationBlocked) {
      _status(
        RobotLinkStatus.authenticationRequired,
        _authenticationBlocks[_endpoint.uri],
      );
      return;
    }
    _opening = true;
    final generation = _connectionGeneration;
    _telemetryReconnectTimer?.cancel();
    _telemetryReconnectTimer = null;
    try {
      _status(RobotLinkStatus.connecting);
      final headers =
          await ref
              .read(robotAuthenticationProvider)
              ?.upgradeHeaders(_endpoint)
              .timeout(_timing.handshakeTimeout) ??
          const <String, String>{};
      if (_disposed || generation != _connectionGeneration) return;
      final channel = ref
          .read(webSocketServiceProvider)
          .connect(_endpoint.uri, headers: headers);
      _telemetryChannel = channel;
      _telemetrySubscription = channel.stream.listen(
        (message) => _handleTelemetry(channel, message),
        onError: (Object error) =>
            _handleTelemetryDisconnect(channel, error: error),
        onDone: () => _handleTelemetryDisconnect(channel),
        cancelOnError: true,
      );
      unawaited(_waitForConnection(channel));
    } on Object catch (error) {
      if (_disposed || generation != _connectionGeneration) return;
      _setTelemetryOffline();
      _handleConnectionFailure(error);
    } finally {
      if (generation == _connectionGeneration) _opening = false;
    }
  }

  void _handleConnectionFailure(Object? error) {
    if (error != null && WebSocketService.isUnauthorized(error)) {
      const message =
          'Authentication rejected (HTTP 401). Change the saved token to reconnect.';
      _authenticationBlocks[_endpoint.uri] = message;
      _telemetryReconnectTimer?.cancel();
      _telemetryReconnectTimer = null;
      _status(RobotLinkStatus.authenticationRequired, message);
      return;
    }
    if (error is RobotCredentialException) {
      final message = error.toString();
      if (error.reason != RobotCredentialFailure.storage) {
        _authenticationBlocks[_endpoint.uri] = message;
      }
      _status(
        _authenticationBlocked
            ? RobotLinkStatus.authenticationRequired
            : RobotLinkStatus.disconnected,
        message,
      );
      return;
    }
    // Exception text, HTTP bodies and remote close reasons can contain credentials.
    debugPrint('[WS] connection lost');
    _status(
      RobotLinkStatus.disconnected,
      error == null
          ? 'Socket closed.'
          : 'Connection lost: WebSocket unavailable.',
    );
    _scheduleTelemetryReconnect();
  }

  Future<void> _waitForConnection(WebSocketChannel channel) async {
    try {
      await channel.ready.timeout(_timing.handshakeTimeout);
      if (_disposed || !identical(channel, _telemetryChannel)) return;
      await ref
          .read(robotAuthenticationProvider)
          ?.authenticate(channel)
          .timeout(_timing.handshakeTimeout);
      if (_disposed || !identical(channel, _telemetryChannel)) return;
      _authenticated = true;
      _status(
        RobotLinkStatus.awaitingTelemetry,
        'Socket open; waiting for fresh telemetry.',
      );
      _telemetryClock
        ..reset()
        ..start();
      _freshnessTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!identical(channel, _telemetryChannel)) return;
        if (_telemetryClock.elapsed >= _timing.reconnectAfter) {
          _handleTelemetryDisconnect(
            channel,
            error: StateError('Telemetry timed out.'),
          );
        } else if (_telemetryClock.elapsed >= _timing.staleAfter) {
          if (_telemetryConnected) {
            _telemetryConnected = false;
            final current = state.value;
            if (current != null) {
              state = AsyncData(current.copyWith(telemetryConnected: false));
            }
            _disconnectCatalog();
            _motionCommands.disconnect();
          }
          _status(
            RobotLinkStatus.degraded,
            'Telemetry stale; motion commands disabled.',
          );
        }
      });
      debugPrint('[WS] connected');
      // Socket readiness does not depend on receiving the first telemetry frame.
      final next = (state.value ?? DashboardData(updatedAt: DateTime.now()))
          .copyWith(
            telemetryConnected: _telemetryConnected,
            telemetryHistory: List.unmodifiable(_telemetryHistory),
          );
      if (_initialTelemetry.isCompleted) {
        state = AsyncData(next);
      } else {
        _initialTelemetry.complete(next);
      }
    } on Object catch (error) {
      _handleTelemetryDisconnect(channel, error: error);
    }
  }

  void _handleTelemetry(WebSocketChannel channel, dynamic message) {
    if (!identical(channel, _telemetryChannel) || message is! String) {
      return;
    }
    try {
      final decoded = jsonDecode(message);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      // medza.audio frames are additive: never motion results or telemetry.
      final type = decoded['type'];
      if (type is String && type.startsWith('voice_')) {
        if (_authenticated && !_voiceFrames.isClosed) _voiceFrames.add(decoded);
        return;
      }
      if (type is String && type.startsWith('audio_')) {
        if (!_audioFrames.isClosed) _audioFrames.add(decoded);
        return;
      }
      if (decoded['type'] == 'motion_catalog') {
        _handleMotionCatalog(decoded);
        return;
      }
      if (decoded['type'] == 'error' &&
          (decoded['request'] == 'get_motion_catalog' ||
              decoded['action'] == 'get_motion_catalog')) {
        final request = _catalogRequest;
        if (request != null && !request.isCompleted) {
          request.completeError(
            StateError(
              '${decoded['message'] ?? decoded['error'] ?? 'Catalog request failed'}',
            ),
          );
        }
        return;
      }
      if (decoded['type'] == 'motion_result' || decoded['type'] == 'error') {
        _motionCommands.handleResult(decoded);
        return;
      }
      if (!_authenticated) return;
      // Only existing telemetry envelopes count as freshness, never command replies.
      if (!(decoded['battery'] is Map ||
          decoded['imu'] is Map ||
          decoded['motors'] is Map ||
          decoded['motors'] is List ||
          decoded['network'] is Map)) {
        return;
      }
      final telemetry = DashboardTelemetry.fromJson(decoded);
      if (telemetry.batterySoc == null &&
          telemetry.batterySoh == null &&
          telemetry.imuTemperature == null &&
          telemetry.maxBmsTemperature == null &&
          telemetry.maxMotorTemperature == null &&
          telemetry.activeMotorCount == null &&
          telemetry.networkType == null &&
          telemetry.networkInterface == null &&
          telemetry.networkSignalPercent == null) {
        return;
      }
      _lastTelemetryAt = DateTime.now();
      _telemetryClock
        ..reset()
        ..start();
      _telemetryConnected = true;
      _retryAttempt = 0;
      _status(RobotLinkStatus.connected);
      if (decoded.containsKey('battery') ||
          decoded.containsKey('imu') ||
          decoded.containsKey('motors')) {
        if (_telemetryHistory.isEmpty ||
            _historySampleClock.elapsed >= const Duration(seconds: 5)) {
          _telemetryHistory.add(telemetry);
          if (_telemetryHistory.length > 61) _telemetryHistory.removeAt(0);
          _historySampleClock
            ..reset()
            ..start();
        }
      }
      final now = DateTime.now();
      final next = (state.value ?? DashboardData(updatedAt: now)).copyWith(
        telemetry: telemetry,
        telemetryConnected: _telemetryConnected,
        updatedAt: now,
        telemetryHistory: List.unmodifiable(_telemetryHistory),
      );
      if (_initialTelemetry.isCompleted) {
        state = AsyncData(next);
      } else {
        _initialTelemetry.complete(next);
      }
    } on Object {
      // Ignore malformed frames and keep listening for the next snapshot.
      debugPrint('[WS] could not process incoming message');
    }
  }

  void _handleTelemetryDisconnect(WebSocketChannel channel, {Object? error}) {
    if (!identical(channel, _telemetryChannel)) {
      return;
    }
    debugPrint('[WS] disconnected');
    _telemetryChannel = null;
    _freshnessTimer?.cancel();
    final subscription = _telemetrySubscription;
    if (subscription != null) unawaited(subscription.cancel());
    _telemetrySubscription = null;
    unawaited(channel.sink.close());
    _setTelemetryOffline();
    _handleConnectionFailure(error);
  }

  void _setTelemetryOffline() {
    _telemetryHistory.clear();
    _historySampleClock
      ..stop()
      ..reset();
    _disconnectCatalog();
    _motionCommands.disconnect();
    _telemetryConnected = false;
    _authenticated = false;
    if (_disposed) {
      return;
    }
    final error = StateError(
      'Unitree telemetry WebSocket is offline or unreachable.',
    );
    final stackTrace = StackTrace.current;
    if (_initialTelemetry.isCompleted) {
      state = AsyncError(error, stackTrace);
    } else {
      _initialTelemetry.completeError(error, stackTrace);
    }
  }

  void _scheduleTelemetryReconnect() {
    if (_disposed ||
        !_connectionRequested ||
        _authenticationBlocked ||
        _suspended ||
        _telemetryReconnectTimer != null) {
      return;
    }
    final multiplier = 1 << (_retryAttempt.clamp(0, 4));
    _retryAttempt++;
    final delay = _timing.retryDelay * multiplier;
    _status(
      RobotLinkStatus.reconnecting,
      '${ref.read(robotLinkProvider).message ?? 'Connection unavailable.'} Retrying in ${delay.inSeconds}s. Commands are never replayed.',
    );
    _telemetryReconnectTimer = Timer(delay, () {
      _telemetryReconnectTimer = null;
      _connectTelemetry();
    });
  }

  void _dispose() {
    _audioFrames.close();
    _voiceFrames.close();
    _connectionGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    _freshnessTimer?.cancel();
    _disconnectCatalog();
    _motionCommands.disconnect();
    _disposed = true;
    _telemetryReconnectTimer?.cancel();
    final subscription = _telemetrySubscription;
    _telemetrySubscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    final channel = _telemetryChannel;
    _telemetryChannel = null;
    if (channel != null) {
      debugPrint('[WS] disconnected (disposed)');
      unawaited(channel.sink.close());
    }
  }

  Future<void> refresh({bool showLoading = true}) async {
    if (!_connectionRequested || _suspended) return;
    if (_telemetryConnected) {
      return;
    }
    if (showLoading) {
      state = const AsyncLoading();
    }
    _closeConnection();
    await _connectTelemetry();
  }
}

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardData>(
      DashboardController.new,
      name: 'DashboardControllerProvider',
      // This controller owns backoff; disable provider-level retries.
      retry: (_, _) => null,
    );
