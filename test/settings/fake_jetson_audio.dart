import 'dart:async';

import 'package:robot_control_app/features/settings/data/live_audio_device_backend.dart';

/// In-memory stand-in for the Jetson `medza.audio` v1 server, answering the
/// way `docs/audio_devices.md` §1–§7 describes. No sockets, no audio.
class FakeJetsonAudio implements AudioFrameTransport {
  FakeJetsonAudio({
    this.supportsAudio = true,
    this.testsEnabled = false,
    this.autoCompleteTests = true,
  });

  static Map<String, Object?> device(
    String id,
    String direction,
    String kind,
    String label, {
    bool? connected = true,
    bool verified = true,
    List<String> limitations = const [],
  }) => {
    'id': id,
    'direction': direction,
    'kind': kind,
    'label': label,
    'connected': connected,
    'status': switch (connected) {
      true => 'connected',
      false => 'disconnected',
      null => 'unknown',
    },
    'verified': verified,
    'capabilities': direction == 'input'
        ? ['capture', 'test']
        : ['playback', 'test'],
    'limitations': limitations,
  };

  static const djiId = 'usb:2ca3:4011:XSP12345678B';

  /// Ignores every audio_* frame, like a backend without audio support.
  bool supportsAudio;
  bool testsEnabled;
  bool autoCompleteTests;
  bool connected = true;

  final sent = <Map<String, Object?>>[];
  final _frames = StreamController<Map<String, dynamic>>.broadcast(sync: true);

  List<Map<String, Object?>> inputs = [
    device(
      'robot:mic',
      'input',
      'robot',
      'Unitree G1 microphone',
      connected: null,
      verified: false,
    ),
    device(
      'system:default',
      'input',
      'system',
      'System default',
      verified: false,
    ),
    device(djiId, 'input', 'usb', 'DJI Wireless Mic Rx'),
  ];
  List<Map<String, Object?>> outputs = [
    device(
      'robot:speaker',
      'output',
      'robot',
      'Unitree G1 built-in speaker',
      connected: null,
    ),
  ];
  String? selectedInput = djiId;
  String? selectedOutput = 'robot:speaker';
  String? sessionOwner;
  String? sessionInputId;
  String? sessionOutputId;
  bool settingsFileInvalid = false;
  final _pendingTests = <String, Map<String, Object?>>{};

  List<String> get sentTypes => [for (final f in sent) f['type'] as String];

  @override
  Stream<Map<String, dynamic>> get frames => _frames.stream;

  /// Server → client frame.
  void push(Map<String, dynamic> frame) => _frames.add(frame);

  @override
  void send(Map<String, Object?> frame) {
    if (!connected) throw StateError('Robot is not connected.');
    sent.add(frame);
    if (supportsAudio) _respond(frame);
  }

  Map<String, Object?> _selection(String? id, List<Map<String, Object?>> list) {
    final match = list.where((d) => d['id'] == id).firstOrNull;
    return {
      'device_id': id,
      'label': match?['label'],
      'status': match == null ? 'disconnected' : match['status'],
      'source': settingsFileInvalid ? 'env_fallback' : 'settings',
    };
  }

  Map<String, dynamic> statusBody(
    String type, {
    String? requestId,
    bool devicesChanged = false,
  }) => {
    'type': type,
    'request_id': ?requestId,
    'input': _selection(selectedInput, inputs),
    'output': _selection(selectedOutput, outputs),
    'settings_file': {
      'status': settingsFileInvalid ? 'invalid' : 'ok',
      'error': settingsFileInvalid ? 'settings_file_invalid' : null,
      'fallback': settingsFileInvalid ? 'env' : null,
    },
    'session': {
      'active': sessionOwner != null,
      'owner': sessionOwner,
      'since': sessionOwner == null ? null : 1792070742.4,
      'input_state': sessionOwner == 'realtime_voice' ? 'ok' : null,
      'input_error': null,
      'input_device_id': sessionInputId,
      'output_device_id': sessionOutputId,
    },
    'voice_runtime_running': sessionOwner == 'realtime_voice',
    'applies_on': 'voice_runtime_start',
    'tests_enabled': testsEnabled,
    'test_running': _pendingTests.isNotEmpty,
    if (type == 'audio_device_status' && requestId == null)
      'devices_changed': devicesChanged,
  };

  Map<String, dynamic> _result(
    String action,
    String status,
    String? id, [
    Map<String, Object?> extra = const {},
  ]) => {
    'type': 'audio_result',
    'action': action,
    'status': status,
    'request_id': ?id,
    ...extra,
  };

  void _respond(Map<String, Object?> frame) {
    final id = frame['request_id'] as String?;
    switch (frame['type']) {
      case 'audio_get_capabilities':
        push({
          'type': 'audio_capabilities',
          'request_id': id,
          'protocol': 'medza.audio',
          'protocol_version': 1,
          'requests': [
            'audio_device_status',
            'audio_get_capabilities',
            'audio_get_devices',
            'audio_get_settings',
            'audio_set_settings',
            'audio_test_input',
            'audio_test_output',
          ],
          'pushed': ['audio_device_status', 'audio_settings', 'audio_error'],
          'tests_enabled': testsEnabled,
          'settings_apply_on': 'voice_runtime_start',
          'limits': {
            'request_id_max_length': 64,
            'input_test_default_sec': 3,
            'input_test_max_sec': 5,
            'output_test_tone_sec': 1.0,
            'status_poll_interval_sec': 2.0,
          },
        });
      case 'audio_get_devices':
        push({
          'type': 'audio_devices',
          'request_id': id,
          'inputs': inputs,
          'outputs': outputs,
          'selected': {'input': selectedInput, 'output': selectedOutput},
          'settings_file': {'status': 'ok', 'error': null, 'fallback': null},
          'tests_enabled': testsEnabled,
        });
      case 'audio_device_status':
        push(statusBody('audio_device_status', requestId: id));
      case 'audio_get_settings':
        push(statusBody('audio_settings', requestId: id));
      case 'audio_set_settings':
        if (sessionOwner != null) {
          push(
            _result('set_settings', 'busy', id, {
              'error': 'audio_session_active',
              'owner': sessionOwner,
            }),
          );
          return;
        }
        final input = frame['input_device_id'] as String?;
        final output = frame['output_device_id'] as String?;
        if ((input != null && !inputs.any((d) => d['id'] == input)) ||
            (output != null && !outputs.any((d) => d['id'] == output))) {
          push(
            _result('set_settings', 'rejected', id, {
              'error': 'device_unavailable',
            }),
          );
          return;
        }
        selectedInput = input ?? selectedInput;
        selectedOutput = output ?? selectedOutput;
        settingsFileInvalid = false;
        push(statusBody('audio_settings'));
        push(
          _result('set_settings', 'completed', id, {
            'input_device_id': selectedInput,
            'output_device_id': selectedOutput,
          }),
        );
      case 'audio_test_input' || 'audio_test_output':
        final action = (frame['type'] as String).substring('audio_'.length);
        if (!testsEnabled) {
          push(
            _result(action, 'rejected', id, {'error': 'audio_tests_disabled'}),
          );
          return;
        }
        if (frame['confirm'] != true) {
          push(
            _result(action, 'rejected', id, {'error': 'confirmation_required'}),
          );
          return;
        }
        if (sessionOwner != null) {
          push(
            _result(action, 'busy', id, {
              'error': 'audio_session_active',
              'owner': sessionOwner,
            }),
          );
          return;
        }
        push(
          _result(action, 'accepted', id, {'device_id': frame['device_id']}),
        );
        final done = action == 'test_input'
            ? _result(action, 'completed', id, {
                'device_id': frame['device_id'],
                'duration_sec': frame['duration_sec'],
                'rms': 2226,
                'peak': 24219,
                'peak_dbfs': -2.6,
                'clipping': false,
                'signal': 'ok',
              })
            : _result(action, 'completed', id, {
                'device_id': frame['device_id'],
                'duration_sec': 1.0,
              });
        if (autoCompleteTests) {
          push(done);
        } else {
          _pendingTests[id!] = done;
        }
      default:
        push(
          _result(
            (frame['type'] as String).substring('audio_'.length),
            'rejected',
            id,
            {'error': 'unknown_type'},
          ),
        );
    }
  }

  /// Delivers held-back final test results (out of order with other replies).
  void finishTests() {
    final results = [..._pendingTests.values];
    _pendingTests.clear();
    results.forEach(push);
  }
}
