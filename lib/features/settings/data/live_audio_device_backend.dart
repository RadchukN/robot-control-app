import 'dart:async';

import 'package:robot_control_app/features/settings/data/audio_device_backend.dart';
import 'package:robot_control_app/features/settings/data/medza_audio_protocol.dart';

/// The robot's existing authenticated WebSocket, narrowed to audio frames.
abstract interface class AudioFrameTransport {
  /// Incoming `audio_*` frames.
  Stream<Map<String, dynamic>> get frames;

  /// Sends one `audio_*` frame; throws when the robot is not connected.
  void send(Map<String, Object?> frame);
}

/// `medza.audio` v1 over [AudioFrameTransport]. One instance per robot
/// connection: a reconnect creates a new one, so nothing is ever replayed.
class LiveAudioDeviceBackend implements AudioDeviceBackend {
  LiveAudioDeviceBackend(this._transport) {
    _subscription = _transport.frames.listen(_onFrame);
  }

  final AudioFrameTransport _transport;
  late final StreamSubscription<Map<String, dynamic>> _subscription;
  final _events = StreamController<AudioBackendEvent>.broadcast();
  final _pending = <String, _Pending>{};
  int _nextId = 0;
  bool _disposed = false;

  @override
  bool get isSimulated => false;

  @override
  String? get unavailableReason => null;

  @override
  Stream<AudioBackendEvent> get events => _events.stream;

  /// Ids are short, unique per connection and within the 64-char limit.
  String _requestId() => 'fl-${++_nextId}';

  Future<Map<String, dynamic>> _request(
    Map<String, Object?> Function(String requestId) build, {
    required Set<String> replyTypes,
    String? action,
  }) {
    if (_disposed) {
      return Future.error(
        const AudioDeviceException('disconnected', 'Robot is not connected.'),
      );
    }
    final id = _requestId();
    final pending = _Pending(replyTypes, action);
    _pending[id] = pending;
    try {
      _transport.send(build(id));
    } on Object {
      _pending.remove(id);
      return Future.error(
        const AudioDeviceException('disconnected', 'Robot is not connected.'),
      );
    }
    return pending.completer.future.whenComplete(() => _pending.remove(id));
  }

  void _onFrame(Map<String, dynamic> frame) {
    final requestId = MedzaAudioProtocol.requestIdOf(frame);
    final pending = requestId == null ? null : _pending[requestId];
    if (pending != null) {
      _resolve(pending, frame);
      return;
    }
    if (requestId != null) return; // Stale reply (timed out or unknown).
    // Pushed messages never carry a request id.
    final status = MedzaAudioProtocol.decodeStatus(frame);
    if (status != null) {
      _emit(AudioStatusPushed(status));
      return;
    }
    final error = MedzaAudioProtocol.decodeError(frame);
    if (error != null) _emit(error);
    // Unknown pushed types are ignored (§2).
  }

  void _resolve(_Pending pending, Map<String, dynamic> frame) {
    final completer = pending.completer;
    if (completer.isCompleted) return;
    final result = MedzaAudioResult.decode(frame);
    if (result != null) {
      if (result.failed) {
        completer.completeError(
          AudioDeviceException(
            result.error ?? result.status,
            result.message,
            owner: result.owner,
            busy: result.status == 'busy',
          ),
        );
      } else if (result.status == 'completed' &&
          (pending.action == null || pending.action == result.action)) {
        completer.complete(frame);
      }
      // `accepted` only acknowledges a test; wait for the final result.
      return;
    }
    if (pending.replyTypes.contains(frame['type'])) {
      completer.complete(frame);
      return;
    }
    completer.completeError(
      const AudioDeviceException(
        'invalid_response',
        'The robot sent an unexpected audio response.',
      ),
    );
  }

  void _emit(AudioBackendEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  Never _invalid() => throw const AudioDeviceException(
    'invalid_response',
    'The robot sent an invalid audio response.',
  );

  @override
  Future<AudioCapabilities> getCapabilities() async {
    // Backends without audio support never answer (§2).
    final frame =
        await _request(
          MedzaAudioProtocol.getCapabilities,
          replyTypes: const {'audio_capabilities'},
        ).timeout(
          MedzaAudioProtocol.capabilityTimeout,
          onTimeout: () => throw const AudioDeviceException(
            'unsupported',
            'Audio settings are unavailable: the robot did not answer the '
                'audio capability request.',
          ),
        );
    return MedzaAudioProtocol.decodeCapabilities(frame) ??
        (throw const AudioDeviceException(
          'unsupported',
          'The robot uses an unsupported audio protocol version.',
        ));
  }

  @override
  Future<List<AudioDevice>> getDevices() async {
    final frame = await _request(
      MedzaAudioProtocol.getDevices,
      replyTypes: const {'audio_devices'},
    );
    return MedzaAudioProtocol.decodeDevices(frame) ?? _invalid();
  }

  @override
  Future<AudioDeviceStatus> getStatus() async {
    final frame = await _request(
      MedzaAudioProtocol.deviceStatus,
      replyTypes: const {'audio_device_status'},
    );
    return MedzaAudioProtocol.decodeStatus(frame) ?? _invalid();
  }

  @override
  Future<AudioDeviceSettings> applySettings(AudioDeviceSettings desired) async {
    // The robot pushes audio_settings first, then this completed result.
    final frame = await _request(
      (id) => MedzaAudioProtocol.setSettings(
        id,
        inputDeviceId: desired.inputId,
        outputDeviceId: desired.outputId,
      ),
      replyTypes: const {},
      action: 'set_settings',
    );
    String? string(Object? value) => value is String ? value : null;
    return AudioDeviceSettings(
      inputId: string(frame['input_device_id']),
      outputId: string(frame['output_device_id']),
    );
  }

  @override
  Future<AudioTestResult> testInput(String deviceId, {int? durationSec}) async {
    final frame = await _request(
      (id) => MedzaAudioProtocol.testInput(
        id,
        deviceId: deviceId,
        durationSec: durationSec ?? 3,
      ),
      replyTypes: const {},
      action: 'test_input',
    );
    final signal = frame['signal'];
    num? number(Object? value) => value is num ? value : null;
    return AudioTestResult(
      AudioTestOutcome.passed,
      rms: number(frame['rms']),
      peak: number(frame['peak']),
      peakDbfs: number(frame['peak_dbfs']),
      clipping: frame['clipping'] is bool ? frame['clipping'] as bool : null,
      signal: signal is String ? signal : null,
      durationSec: number(frame['duration_sec']),
    );
  }

  @override
  Future<AudioTestResult> testOutput(String deviceId) async {
    final frame = await _request(
      (id) => MedzaAudioProtocol.testOutput(id, deviceId: deviceId),
      replyTypes: const {},
      action: 'test_output',
    );
    final duration = frame['duration_sec'];
    return AudioTestResult(
      AudioTestOutcome.passed,
      durationSec: duration is num ? duration : null,
    );
  }

  /// §4: there is no cancel message; an accepted test runs to its end.
  @override
  void cancelTest(AudioDeviceDirection direction) {}

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_subscription.cancel());
    for (final pending in _pending.values) {
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(
          const AudioDeviceException('disconnected', 'Robot is not connected.'),
        );
      }
    }
    _pending.clear();
    _events.close();
  }
}

class _Pending {
  _Pending(this.replyTypes, this.action);

  final Set<String> replyTypes;

  /// Expected `audio_result.action` for requests answered by a result.
  final String? action;
  final completer = Completer<Map<String, dynamic>>();
}
