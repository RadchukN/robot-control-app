import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/features/settings/data/audio_device_backend.dart';
import 'package:robot_control_app/features/settings/data/medza_audio_protocol.dart';

// Payloads below are the examples from the Jetson docs/audio_devices.md.
const _dji = 'usb:2ca3:4011:XSP12345678B';

void main() {
  group('requests carry only the fields the contract allows', () {
    test('discovery and status requests', () {
      expect(MedzaAudioProtocol.getCapabilities('c1'), {
        'type': 'audio_get_capabilities',
        'request_id': 'c1',
      });
      expect(MedzaAudioProtocol.getDevices('r1'), {
        'type': 'audio_get_devices',
        'request_id': 'r1',
      });
      expect(MedzaAudioProtocol.getSettings('g1'), {
        'type': 'audio_get_settings',
        'request_id': 'g1',
      });
      expect(MedzaAudioProtocol.deviceStatus('d1'), {
        'type': 'audio_device_status',
        'request_id': 'd1',
      });
    });

    test('audio_set_settings sends ids verbatim, one or both directions', () {
      expect(
        MedzaAudioProtocol.setSettings(
          's1',
          inputDeviceId: _dji,
          outputDeviceId: 'robot:speaker',
        ),
        {
          'type': 'audio_set_settings',
          'request_id': 's1',
          'input_device_id': _dji,
          'output_device_id': 'robot:speaker',
        },
      );
      expect(
        MedzaAudioProtocol.setSettings('s2', outputDeviceId: 'robot:speaker'),
        {
          'type': 'audio_set_settings',
          'request_id': 's2',
          'output_device_id': 'robot:speaker',
        },
      );
      expect(() => MedzaAudioProtocol.setSettings('s3'), throwsArgumentError);
    });

    test('tests always confirm and bound the duration', () {
      expect(
        MedzaAudioProtocol.testInput('t1', deviceId: _dji, durationSec: 3),
        {
          'type': 'audio_test_input',
          'request_id': 't1',
          'confirm': true,
          'device_id': _dji,
          'duration_sec': 3,
        },
      );
      expect(MedzaAudioProtocol.testOutput('t2', deviceId: 'robot:speaker'), {
        'type': 'audio_test_output',
        'request_id': 't2',
        'confirm': true,
        'device_id': 'robot:speaker',
      });
      for (final bad in [0, 6]) {
        expect(
          () => MedzaAudioProtocol.testInput(
            't',
            deviceId: _dji,
            durationSec: bad,
          ),
          throwsRangeError,
        );
      }
    });
  });

  group('responses', () {
    final capabilities = {
      'type': 'audio_capabilities',
      'request_id': 'c1',
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
      'tests_enabled': false,
      'settings_apply_on': 'voice_runtime_start',
      'limits': {
        'request_id_max_length': 64,
        'input_test_default_sec': 3,
        'input_test_max_sec': 5,
        'output_test_tone_sec': 1.0,
        'status_poll_interval_sec': 2.0,
      },
    };

    test('capabilities: tests stay off unless tests_enabled', () {
      final caps = MedzaAudioProtocol.decodeCapabilities(capabilities)!;
      expect(caps.discovery, isTrue);
      expect(caps.settings, isTrue);
      expect(caps.inputTest, isFalse);
      expect(caps.outputTest, isFalse);
      expect(caps.cancellableTests, isFalse, reason: 'no cancel message');
      expect(caps.inputTestDefaultSec, 3);
      final enabled = MedzaAudioProtocol.decodeCapabilities({
        ...capabilities,
        'tests_enabled': true,
        'future_field': {'ignored': true},
      })!;
      expect(enabled.inputTest, isTrue);
      expect(enabled.outputTest, isTrue);
    });

    test('capabilities: other protocols or versions are unsupported', () {
      expect(
        MedzaAudioProtocol.decodeCapabilities({
          ...capabilities,
          'protocol': 'x',
        }),
        isNull,
      );
      expect(
        MedzaAudioProtocol.decodeCapabilities({
          ...capabilities,
          'protocol_version': 2,
        }),
        isNull,
      );
      expect(
        MedzaAudioProtocol.decodeCapabilities({
          ...capabilities,
          'requests': null,
        }),
        isNull,
      );
    });

    test('devices keep ids, labels, status, verification and limitations', () {
      final devices = MedzaAudioProtocol.decodeDevices({
        'type': 'audio_devices',
        'request_id': 'r1',
        'inputs': [
          {
            'id': 'robot:mic',
            'direction': 'input',
            'kind': 'robot',
            'label': 'Unitree G1 microphone',
            'connected': null,
            'status': 'unknown',
            'verified': false,
            'capabilities': ['capture', 'test'],
            'limitations': ['Only checked by using it.'],
          },
          {
            'id': _dji,
            'direction': 'input',
            'kind': 'usb',
            'label': 'DJI Wireless Mic Rx',
            'connected': true,
            'status': 'connected',
            'verified': true,
            'capabilities': ['capture', 'test'],
            'limitations': [],
            'usb': {'vendor_id': '2ca3', 'product_id': '4011'},
            'native_format': {
              'format': 'S24_3LE',
              'channels': 2,
              'rates': [48000],
            },
          },
          {'id': 'bad', 'direction': 'output', 'label': 'wrong list'},
          {'direction': 'input', 'label': 'no id'},
        ],
        'outputs': [
          {
            'id': 'hdmi:0',
            'direction': 'output',
            'kind': 'hdmi',
            'label': 'HDMI',
            'connected': false,
            'verified': false,
          },
        ],
        'selected': {'input': _dji, 'output': 'robot:speaker'},
        'settings_file': {'status': 'ok', 'error': null, 'fallback': null},
        'tests_enabled': false,
      })!;
      expect(devices.map((d) => d.id), ['robot:mic', _dji, 'hdmi:0']);
      final mic = devices.first;
      expect(mic.availability, AudioAvailability.unknown);
      expect(mic.selectable, isTrue, reason: 'robot audio can only be used');
      expect(mic.verified, isFalse);
      expect(mic.limitations, ['Only checked by using it.']);
      expect(devices[1].kind, AudioDeviceKind.usb);
      expect(devices[1].name, 'DJI Wireless Mic Rx');
      expect(devices.last.availability, AudioAvailability.disconnected);
      expect(devices.last.selectable, isFalse);
    });

    test('status separates saved, source, file state and active session', () {
      final status = MedzaAudioProtocol.decodeStatus({
        'type': 'audio_settings',
        'request_id': 'g1',
        'input': {
          'device_id': _dji,
          'label': 'DJI Wireless Mic Rx',
          'status': 'connected',
          'source': 'settings',
        },
        'output': {
          'device_id': 'robot:speaker',
          'label': 'Unitree G1 built-in speaker',
          'status': 'unknown',
          'source': 'settings',
        },
        'settings_file': {'status': 'ok', 'error': null, 'fallback': null},
        'session': {
          'active': true,
          'owner': 'realtime_voice',
          'since': 1792070742.4,
          'input_state': 'ok',
          'input_error': null,
          'input_device_id': _dji,
          'output_device_id': 'robot:speaker',
        },
        'voice_runtime_running': true,
        'applies_on': 'voice_runtime_start',
        'tests_enabled': false,
        'test_running': false,
      })!;
      expect(status.input.deviceId, _dji);
      expect(status.input.source, AudioSelectionSource.settings);
      expect(status.output.status, AudioSelectionStatus.unknown);
      expect(status.session.owner, 'realtime_voice');
      expect(status.activeId(AudioDeviceDirection.input), _dji);
      expect(status.voiceRuntimeRunning, isTrue);

      final invalid = MedzaAudioProtocol.decodeStatus({
        'type': 'audio_device_status',
        'input': {
          'device_id': 'robot:mic',
          'status': 'unknown',
          'source': 'env_fallback',
        },
        'output': {
          'device_id': null,
          'status': 'unresolved',
          'source': 'env_fallback',
        },
        'settings_file': {
          'status': 'invalid',
          'error': 'settings_file_invalid',
          'fallback': 'env',
        },
        'session': {'active': false, 'owner': null},
        'devices_changed': true,
      })!;
      expect(invalid.settingsFile, AudioSettingsFileStatus.invalid);
      expect(invalid.input.source, AudioSelectionSource.envFallback);
      expect(invalid.output.status, AudioSelectionStatus.unresolved);
      expect(
        invalid.activeId(AudioDeviceDirection.input),
        isNull,
        reason: 'idle',
      );
      expect(invalid.devicesChanged, isTrue);
      expect(
        MedzaAudioProtocol.decodeStatus({'type': 'audio_settings'}),
        isNull,
      );
    });

    test('results and pushed errors', () {
      final busy = MedzaAudioResult.decode({
        'type': 'audio_result',
        'action': 'set_settings',
        'status': 'busy',
        'request_id': 's1',
        'error': 'audio_session_active',
        'owner': 'realtime_voice',
      })!;
      expect(busy.failed, isTrue);
      expect(busy.requestId, 's1');
      expect(busy.message, contains('realtime_voice'));
      expect(
        MedzaAudioResult.decode({
          'type': 'audio_result',
          'action': 'x',
          'status': 'weird',
        }),
        isNull,
      );
      final error = MedzaAudioProtocol.decodeError({
        'type': 'audio_error',
        'code': 'selected_device_disconnected',
        'fatal': false,
        'direction': 'input',
        'device_id': _dji,
        'session_active': false,
      })!;
      expect(error.code, 'selected_device_disconnected');
      expect(error.direction, AudioDeviceDirection.input);
      expect(error.deviceId, _dji);
    });
  });
}
