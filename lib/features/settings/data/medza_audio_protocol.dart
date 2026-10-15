import 'package:robot_control_app/features/settings/data/audio_device_backend.dart';

/// Codec for the Jetson `medza.audio` v1 WebSocket protocol
/// (`docs/audio_devices.md` §1–§7 on the robot). Requests carry only the
/// fields the contract allows for their type, plus `request_id`; decoders
/// ignore unknown fields and return null for malformed frames.
abstract final class MedzaAudioProtocol {
  static const protocol = 'medza.audio';
  static const version = 1;

  /// No `audio_capabilities` within this time means audio is unsupported.
  static const capabilityTimeout = Duration(seconds: 3);

  static const maxRequestIdLength = 64;

  // ---- requests -----------------------------------------------------------

  static Map<String, Object?> getCapabilities(String requestId) => {
    'type': 'audio_get_capabilities',
    'request_id': requestId,
  };

  static Map<String, Object?> getDevices(String requestId) => {
    'type': 'audio_get_devices',
    'request_id': requestId,
  };

  static Map<String, Object?> getSettings(String requestId) => {
    'type': 'audio_get_settings',
    'request_id': requestId,
  };

  static Map<String, Object?> deviceStatus(String requestId) => {
    'type': 'audio_device_status',
    'request_id': requestId,
  };

  /// At least one id is required; an omitted direction keeps its saved
  /// selection on the robot.
  static Map<String, Object?> setSettings(
    String requestId, {
    String? inputDeviceId,
    String? outputDeviceId,
  }) {
    if (inputDeviceId == null && outputDeviceId == null) {
      throw ArgumentError('audio_set_settings needs at least one device id');
    }
    return {
      'type': 'audio_set_settings',
      'request_id': requestId,
      'input_device_id': ?inputDeviceId,
      'output_device_id': ?outputDeviceId,
    };
  }

  /// [durationSec] must be an integer from 1 to 5. `confirm` is always the
  /// JSON boolean `true`: build this only after the user confirmed.
  static Map<String, Object?> testInput(
    String requestId, {
    required String deviceId,
    required int durationSec,
  }) {
    if (durationSec < 1 || durationSec > 5) {
      throw RangeError.range(durationSec, 1, 5, 'durationSec');
    }
    return {
      'type': 'audio_test_input',
      'request_id': requestId,
      'confirm': true,
      'device_id': deviceId,
      'duration_sec': durationSec,
    };
  }

  static Map<String, Object?> testOutput(
    String requestId, {
    required String deviceId,
  }) => {
    'type': 'audio_test_output',
    'request_id': requestId,
    'confirm': true,
    'device_id': deviceId,
  };

  // ---- responses ----------------------------------------------------------

  static String? requestIdOf(Map<String, dynamic> frame) {
    final id = frame['request_id'];
    return id is String ? id : null;
  }

  /// Null unless this is a `medza.audio` v1 `audio_capabilities`.
  static AudioCapabilities? decodeCapabilities(Map<String, dynamic> frame) {
    if (frame['type'] != 'audio_capabilities' ||
        frame['protocol'] != protocol ||
        frame['protocol_version'] != version) {
      return null;
    }
    final requests = frame['requests'];
    if (requests is! List) return null;
    final names = requests.whereType<String>().toSet();
    final testsEnabled = frame['tests_enabled'] == true;
    final limits = frame['limits'];
    final defaultSec = limits is Map ? limits['input_test_default_sec'] : null;
    return AudioCapabilities(
      discovery: names.contains('audio_get_devices'),
      settings: names.contains('audio_set_settings'),
      inputTest: testsEnabled && names.contains('audio_test_input'),
      outputTest: testsEnabled && names.contains('audio_test_output'),
      // §4: there is no cancel message.
      cancellableTests: false,
      inputTestDefaultSec:
          defaultSec is int && defaultSec >= 1 && defaultSec <= 5
          ? defaultSec
          : 3,
    );
  }

  static AudioDevice? decodeDevice(
    Object? raw,
    AudioDeviceDirection direction,
  ) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final label = raw['label'];
    if (id is! String || id.isEmpty || label is! String) return null;
    if (raw['direction'] != direction.name) return null;
    final limitations = raw['limitations'];
    return AudioDevice(
      id: id,
      name: label,
      direction: direction,
      kind: switch (raw['kind']) {
        'robot' => AudioDeviceKind.robot,
        'system' => AudioDeviceKind.system,
        'usb' => AudioDeviceKind.usb,
        'hdmi' => AudioDeviceKind.hdmi,
        _ => AudioDeviceKind.other,
      },
      availability: switch (raw['connected']) {
        true => AudioAvailability.connected,
        false => AudioAvailability.disconnected,
        _ => AudioAvailability.unknown,
      },
      verified: raw['verified'] != false,
      limitations: limitations is List
          ? limitations.whereType<String>().toList(growable: false)
          : const [],
    );
  }

  /// Inputs then outputs from `audio_devices`; malformed entries skipped.
  static List<AudioDevice>? decodeDevices(Map<String, dynamic> frame) {
    if (frame['type'] != 'audio_devices') return null;
    final inputs = frame['inputs'];
    final outputs = frame['outputs'];
    if (inputs is! List || outputs is! List) return null;
    return [
      for (final raw in inputs) ?decodeDevice(raw, AudioDeviceDirection.input),
      for (final raw in outputs)
        ?decodeDevice(raw, AudioDeviceDirection.output),
    ];
  }

  static AudioSelection _selection(Object? raw) {
    if (raw is! Map) return const AudioSelection();
    final id = raw['device_id'];
    final label = raw['label'];
    return AudioSelection(
      deviceId: id is String ? id : null,
      label: label is String ? label : null,
      status: switch (raw['status']) {
        'connected' => AudioSelectionStatus.connected,
        'disconnected' => AudioSelectionStatus.disconnected,
        'unresolved' => AudioSelectionStatus.unresolved,
        _ => AudioSelectionStatus.unknown,
      },
      source: switch (raw['source']) {
        'settings' => AudioSelectionSource.settings,
        'env' => AudioSelectionSource.env,
        'env_fallback' => AudioSelectionSource.envFallback,
        _ => AudioSelectionSource.unknown,
      },
    );
  }

  /// Body of `audio_settings` or `audio_device_status`.
  static AudioDeviceStatus? decodeStatus(Map<String, dynamic> frame) {
    final type = frame['type'];
    if (type != 'audio_settings' && type != 'audio_device_status') {
      return null;
    }
    if (frame['input'] is! Map || frame['output'] is! Map) return null;
    final file = frame['settings_file'];
    final session = frame['session'];
    String? string(Object? value) => value is String ? value : null;
    return AudioDeviceStatus(
      input: _selection(frame['input']),
      output: _selection(frame['output']),
      settingsFile: switch (file is Map ? file['status'] : null) {
        'ok' => AudioSettingsFileStatus.ok,
        'absent' => AudioSettingsFileStatus.absent,
        'invalid' => AudioSettingsFileStatus.invalid,
        _ => AudioSettingsFileStatus.unknown,
      },
      session: session is Map
          ? AudioSessionInfo(
              active: session['active'] == true,
              owner: string(session['owner']),
              inputLost: session['input_state'] == 'lost',
              inputDeviceId: string(session['input_device_id']),
              outputDeviceId: string(session['output_device_id']),
            )
          : const AudioSessionInfo(),
      voiceRuntimeRunning: frame['voice_runtime_running'] == true,
      testsEnabled: frame['tests_enabled'] == true,
      testRunning: frame['test_running'] == true,
      devicesChanged: frame['devices_changed'] == true,
    );
  }

  static AudioErrorPushed? decodeError(Map<String, dynamic> frame) {
    if (frame['type'] != 'audio_error') return null;
    final code = frame['code'];
    if (code is! String) return null;
    String? string(Object? value) => value is String ? value : null;
    return AudioErrorPushed(
      code: code,
      fatal: frame['fatal'] == true,
      owner: string(frame['owner']),
      deviceId: string(frame['device_id']),
      direction: switch (frame['direction']) {
        'input' => AudioDeviceDirection.input,
        'output' => AudioDeviceDirection.output,
        _ => null,
      },
      detail: string(frame['detail']),
    );
  }
}

/// A parsed `audio_result`.
class MedzaAudioResult {
  const MedzaAudioResult({
    required this.action,
    required this.status,
    required this.raw,
    this.requestId,
    this.error,
    this.owner,
  });

  /// `set_settings`, `test_input`, `test_output`, or a request type without
  /// its `audio_` prefix for validation errors.
  final String action;

  /// `accepted`, `completed`, `rejected` or `busy`.
  final String status;
  final String? requestId;
  final String? error;
  final String? owner;
  final Map<String, dynamic> raw;

  static MedzaAudioResult? decode(Map<String, dynamic> frame) {
    if (frame['type'] != 'audio_result') return null;
    final action = frame['action'];
    final status = frame['status'];
    if (action is! String || status is! String) return null;
    if (!const {'accepted', 'completed', 'rejected', 'busy'}.contains(status)) {
      return null;
    }
    final error = frame['error'];
    final owner = frame['owner'];
    return MedzaAudioResult(
      action: action,
      status: status,
      requestId: MedzaAudioProtocol.requestIdOf(frame),
      error: error is String ? error : null,
      owner: owner is String ? owner : null,
      raw: frame,
    );
  }

  bool get failed => status == 'rejected' || status == 'busy';

  /// Human-readable text for the `error` codes in §5.
  String get message => switch (error) {
    'audio_session_active' =>
      'The robot audio is in use${owner == null ? '' : ' by $owner'}.',
    'audio_test_running' => 'Another audio test is running on the robot.',
    'device_unavailable' => 'The device is not connected to the robot now.',
    'invalid_device_id' => 'The robot did not recognise this device.',
    'wrong_direction' => 'This device cannot be used in that direction.',
    'settings_write_failed' => 'The robot could not save the audio settings.',
    'audio_tests_disabled' => 'Audio tests are disabled on the robot.',
    'confirmation_required' => 'The robot requires confirmation for tests.',
    'invalid_duration' => 'The test duration was rejected.',
    'device_busy' => 'Another process is using this audio device.',
    'no_audio_received' => 'No audio was received from the microphone.',
    'test_timeout' => 'The audio test timed out on the robot.',
    'test_failed' => 'The audio test failed on the robot.',
    'invalid_request' ||
    'invalid_request_id' ||
    'unknown_type' => 'The robot rejected the request ($error).',
    null => 'The robot rejected the request.',
    _ => 'The robot rejected the request ($error).',
  };
}
