import 'package:robot_control_app/features/settings/data/audio_device_backend.dart';

/// Provisional v1 codec, deliberately isolated: no app code imports it and
/// nothing is sent. The message names are NOT a confirmed Jetson contract;
/// replace this file once the real API exists. Device ids pass through
/// unchanged. See docs/audio-devices.md.
abstract final class AudioDeviceProtocol {
  static const version = 1;

  static Map<String, Object?> request(
    String type,
    String requestId, [
    Map<String, Object?> fields = const {},
  ]) => {'type': type, 'v': version, 'request_id': requestId, ...fields};

  static Map<String, Object?> getDevices(String requestId) =>
      request('audio_get_devices', requestId);

  static Map<String, Object?> getSettings(String requestId) =>
      request('audio_get_settings', requestId);

  static Map<String, Object?> setSettings(
    String requestId,
    AudioDeviceSettings settings,
  ) => request('audio_set_settings', requestId, {
    'input_id': ?settings.inputId,
    'output_id': ?settings.outputId,
  });

  static Map<String, Object?> testInput(String requestId, String deviceId) =>
      request('audio_test_input', requestId, {
        'device_id': deviceId,
        'max_duration_ms': 5000,
      });

  static Map<String, Object?> testOutput(String requestId, String deviceId) =>
      request('audio_test_output', requestId, {
        'device_id': deviceId,
        'max_duration_ms': 3000,
      });

  /// Parses an `audio_devices` reply; malformed entries are skipped.
  static List<AudioDevice>? decodeDevices(Map<String, dynamic> message) {
    if (message['type'] != 'audio_devices' || message['v'] != version) {
      return null;
    }
    final devices = message['devices'];
    if (devices is! List) return null;
    return [
      for (final raw in devices)
        if (raw is Map &&
            raw['id'] is String &&
            raw['name'] is String &&
            (raw['direction'] == 'input' || raw['direction'] == 'output'))
          AudioDevice(
            id: raw['id'] as String,
            name: raw['name'] as String,
            direction: raw['direction'] == 'input'
                ? AudioDeviceDirection.input
                : AudioDeviceDirection.output,
            kind: switch (raw['kind']) {
              'robot' => AudioDeviceKind.robotBuiltIn,
              'default' => AudioDeviceKind.systemDefault,
              'usb' => AudioDeviceKind.usb,
              _ => AudioDeviceKind.other,
            },
            connected: raw['connected'] != false,
            simulated: message['dry_run'] == true,
          ),
    ];
  }
}
