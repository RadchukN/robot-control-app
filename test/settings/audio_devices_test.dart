import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/core/theme/app_theme.dart';
import 'package:robot_control_app/features/dashboard/application/dashboard_controller.dart';
import 'package:robot_control_app/features/settings/application/audio_devices_controller.dart';
import 'package:robot_control_app/features/settings/application/settings_state.dart';
import 'package:robot_control_app/features/settings/data/audio_device_backend.dart';
import 'package:robot_control_app/features/settings/data/audio_device_protocol.dart';
import 'package:robot_control_app/features/settings/presentation/settings_screen.dart';
import 'package:robot_control_app/features/voice_studio/application/voice_studio_providers.dart';
import 'package:robot_control_app/features/voice_studio/domain/voice_models.dart';
import 'package:robot_control_app/services/robot_authentication.dart';
import 'package:robot_control_app/services/robot_connection.dart';
import 'package:robot_control_app/shared/notifications/app_notification_service.dart';

import '../robot_authentication_test.dart' show MemoryTokenStore;
import '../voice_studio/voice_test_helpers.dart';

const _input = AudioDeviceDirection.input;
const _output = AudioDeviceDirection.output;
const _usbMic = MockAudioDeviceBackend.usbMicId;
const _mic = MockAudioDeviceBackend.micId;
const _speaker = MockAudioDeviceBackend.speakerId;
const _default = MockAudioDeviceBackend.defaultId;

/// Never answers, to exercise request timeouts.
class _SilentBackend extends MockAudioDeviceBackend {
  @override
  Future<List<AudioDevice>> getDevices() =>
      Completer<List<AudioDevice>>().future;
}

ProviderContainer _container({
  AudioDeviceBackend? backend,
  List<String>? motionCalls,
}) => ProviderContainer(
  overrides: [
    robotTokenStoreProvider.overrideWithValue(MemoryTokenStore()),
    dashboardControllerProvider.overrideWith(
      () => RecordingDashboardController(motionCalls ?? []),
    ),
    if (backend != null) audioDeviceBackendProvider.overrideWithValue(backend),
  ],
);

List<String> _notes(ProviderContainer c) => [
  for (final n in c.read(appNotificationsProvider).visible) n.title,
  for (final n in c.read(appNotificationsProvider).queued) n.title,
];

Future<AudioDevicesState> _loaded(
  WidgetTester tester,
  ProviderContainer c,
) async {
  c.read(audioDevicesProvider);
  await tester.pump();
  await tester.pump();
  return c.read(audioDevicesProvider);
}

void main() {
  group('AudioDevicesController', () {
    testWidgets('Demo Mode discovers clearly simulated devices', (
      tester,
    ) async {
      final c = _container();
      addTearDown(c.dispose);
      final state = await _loaded(tester, c);
      expect(state.simulated, isTrue);
      expect(state.available, isTrue);
      expect(state.devicesFor(_input), hasLength(3));
      expect(state.devicesFor(_output), hasLength(3));
      expect(state.devices.every((d) => d.simulated), isTrue);
      expect(
        state.devices.map((d) => d.name),
        isNot(contains(contains('RØDE'))),
        reason: 'no hardcoded vendor device',
      );
      expect(state.activeInputId, _mic);
      expect(_notes(c), isEmpty, reason: 'background discovery is silent');

      await c.read(audioDevicesProvider.notifier).refresh();
      expect(_notes(c), ['Audio devices refreshed']);
    });

    testWidgets('microphone and speaker are selected independently', (
      tester,
    ) async {
      final motionCalls = <String>[];
      final c = _container(motionCalls: motionCalls);
      addTearDown(c.dispose);
      await _loaded(tester, c);
      final controller = c.read(audioDevicesProvider.notifier);

      await controller.select(_input, _usbMic);
      var state = c.read(audioDevicesProvider);
      expect(state.activeInputId, _usbMic);
      expect(state.activeOutputId, _speaker);
      expect(c.read(settingsProvider).audioInputDeviceId, _usbMic);
      expect(c.read(settingsProvider).audioOutputDeviceId, isNull);

      await controller.select(_output, _default);
      state = c.read(audioDevicesProvider);
      expect(state.activeInputId, _usbMic, reason: 'input unchanged');
      expect(state.activeOutputId, _default);
      expect(c.read(settingsProvider).audioOutputDeviceId, _default);
      expect(
        _notes(c),
        containsAll(['Microphone selected', 'Speaker settings applied']),
      );
      expect(motionCalls, isEmpty, reason: 'no robot traffic from Demo Mode');
    });

    testWidgets('an unplugged device is refused and stays inactive', (
      tester,
    ) async {
      final backend = MockAudioDeviceBackend(
        devices: [
          ...MockAudioDeviceBackend.demoDevices.where((d) => d.id != _usbMic),
          const AudioDevice(
            id: _usbMic,
            name: 'USB microphone',
            direction: _input,
            kind: AudioDeviceKind.usb,
            connected: false,
            simulated: true,
          ),
        ],
      );
      final c = _container(backend: backend);
      addTearDown(c.dispose);
      await _loaded(tester, c);
      await c.read(audioDevicesProvider.notifier).select(_input, _usbMic);
      final state = c.read(audioDevicesProvider);
      expect(state.desiredInputId, _usbMic, reason: 'preference kept');
      expect(state.activeInputId, _mic, reason: 'not applied');
      expect(_notes(c), ['Audio device unavailable']);
    });

    testWidgets('changes and tests are refused during a voice session', (
      tester,
    ) async {
      final c = _container();
      addTearDown(c.dispose);
      await _loaded(tester, c);
      c.read(audioSessionProvider.notifier).acquire(AudioOwner.realtime);
      final controller = c.read(audioDevicesProvider.notifier);
      await controller.select(_output, _default);
      await controller.toggleTest(_input);
      final state = c.read(audioDevicesProvider);
      expect(state.activeOutputId, _speaker);
      expect(state.desiredOutputId, isNull);
      expect(state.inputTest, AudioTestState.idle);
      expect(_notes(c), ['Voice session is active']);
    });

    testWidgets('tests are bounded, explicit and cancellable', (tester) async {
      final c = _container();
      addTearDown(c.dispose);
      await _loaded(tester, c);
      final controller = c.read(audioDevicesProvider.notifier);

      final mic = controller.toggleTest(_input);
      expect(c.read(audioDevicesProvider).inputTest, AudioTestState.running);
      await tester.pump(MockAudioDeviceBackend.inputTestDuration);
      await mic;
      expect(c.read(audioDevicesProvider).inputTest, AudioTestState.passed);
      expect(_notes(c), contains('Microphone test passed'));

      final speaker = controller.toggleTest(_output);
      expect(c.read(audioDevicesProvider).outputTest, AudioTestState.running);
      await controller.toggleTest(_output);
      await speaker;
      expect(c.read(audioDevicesProvider).outputTest, AudioTestState.cancelled);
      expect(_notes(c), contains('Speaker test cancelled'));
    });

    testWidgets('a silent backend times out instead of loading forever', (
      tester,
    ) async {
      final c = _container(backend: _SilentBackend());
      addTearDown(c.dispose);
      c.read(audioDevicesProvider);
      await tester.pump();
      expect(c.read(audioDevicesProvider).loading, isTrue);
      await tester.pump(AudioDevicesController.requestTimeout);
      final state = c.read(audioDevicesProvider);
      expect(state.loading, isFalse);
      expect(state.error, contains('did not respond'));
    });

    testWidgets('live mode is unavailable and never claims devices', (
      tester,
    ) async {
      final c = _container();
      addTearDown(c.dispose);
      c.read(voiceDemoModeProvider.notifier).set(false);
      final state = await _loaded(tester, c);
      expect(state.simulated, isFalse);
      expect(state.available, isFalse);
      expect(state.unavailableReason, contains('not available'));
      expect(state.devices, isEmpty);
      expect(state.activeInputId, isNull);
      final controller = c.read(audioDevicesProvider.notifier);
      await controller.select(_input, _mic);
      expect(c.read(settingsProvider).audioInputDeviceId, isNull);
      await controller.refresh();
      expect(_notes(c), contains('Audio device unavailable'));
    });
  });

  group('AudioDeviceProtocol (provisional)', () {
    test('passes backend ids through unchanged', () {
      const usb = 'usb:0x0d8c:0x0014:1-2.3';
      expect(
        AudioDeviceProtocol.setSettings(
          'r1',
          const AudioDeviceSettings(inputId: usb, outputId: 'robot:speaker'),
        ),
        {
          'type': 'audio_set_settings',
          'v': 1,
          'request_id': 'r1',
          'input_id': usb,
          'output_id': 'robot:speaker',
        },
      );
      expect(AudioDeviceProtocol.testInput('r2', usb)['device_id'], usb);
      expect(
        AudioDeviceProtocol.testOutput('r3', 'system:default')['device_id'],
        'system:default',
      );
    });

    test('decodes devices, skipping malformed entries and other versions', () {
      final devices = AudioDeviceProtocol.decodeDevices({
        'type': 'audio_devices',
        'v': 1,
        'devices': [
          {
            'id': 'robot:mic',
            'name': 'G1 mic',
            'direction': 'input',
            'kind': 'robot',
          },
          {
            'id': 'usb:0x19f7:0x0003:1-2.1',
            'name': 'RØDE NT-USB',
            'direction': 'input',
            'kind': 'usb',
            'connected': false,
          },
          {'id': 3, 'name': 'bad', 'direction': 'input'},
          {'id': 'x', 'name': 'no direction'},
        ],
      })!;
      expect(devices.map((d) => d.name), ['G1 mic', 'RØDE NT-USB']);
      expect(devices.map((d) => d.id), [
        'robot:mic',
        'usb:0x19f7:0x0003:1-2.1',
      ], reason: 'ids are preserved verbatim');
      expect(devices.last.connected, isFalse);
      expect(devices.last.kind, AudioDeviceKind.usb);
      expect(
        AudioDeviceProtocol.decodeDevices({'type': 'audio_devices', 'v': 2}),
        isNull,
      );
    });
  });

  group('Audio devices card', () {
    Future<ProviderContainer> mount(
      WidgetTester tester, {
      Size size = const Size(1200, 1400),
      bool demo = true,
    }) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final c = ProviderContainer(
        overrides: [
          robotTokenStoreProvider.overrideWithValue(MemoryTokenStore()),
          robotEndpointProvider.overrideWithValue(
            const RobotEndpoint(ip: '192.168.123.164'),
          ),
          dashboardControllerProvider.overrideWith(
            () => RecordingDashboardController([]),
          ),
        ],
      );
      addTearDown(c.dispose);
      if (!demo) c.read(voiceDemoModeProvider.notifier).set(false);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: RobotConnectionPanel(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return c;
    }

    Finder key(String k) => find.byKey(Key(k));

    testWidgets('renders under the existing connection cards', (tester) async {
      await mount(tester);
      for (final existing in [
        'robot-connection-card',
        'robot-connect-button',
        'connection-two-columns',
      ]) {
        expect(key(existing), findsOneWidget, reason: existing);
      }
      expect(key('audio-devices-card'), findsOneWidget);
      expect(
        tester.getTopLeft(key('audio-devices-card')).dy,
        greaterThan(tester.getBottomLeft(key('connection-two-columns')).dy),
      );
      expect(find.text('Audio devices'), findsOneWidget);
      expect(find.text('Microphone (Input)'), findsOneWidget);
      expect(find.text('Speaker (Output)'), findsOneWidget);
      expect(find.text('Test microphone'), findsOneWidget);
      expect(find.text('Test speaker'), findsOneWidget);
      expect(find.text('Refresh devices'), findsOneWidget);
      expect(key('audio-two-columns'), findsOneWidget);
      expect(
        find.text('Unitree G1 microphone array (simulated)'),
        findsOneWidget,
      );
      expect(
        find.text('Unitree G1 built-in speaker (simulated)'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('selecting a microphone in the UI leaves the speaker alone', (
      tester,
    ) async {
      final c = await mount(tester);
      await tester.ensureVisible(key('audio-input-select'));
      await tester.tap(key('audio-input-select'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('USB microphone (simulated)').last);
      await tester.pumpAndSettle();
      final state = c.read(audioDevicesProvider);
      expect(state.activeInputId, _usbMic);
      expect(state.activeOutputId, _speaker);
      expect(find.text('USB microphone (simulated)'), findsOneWidget);
      expect(
        find.text('Unitree G1 built-in speaker (simulated)'),
        findsOneWidget,
      );
    });

    testWidgets('test button runs only on click and can be cancelled', (
      tester,
    ) async {
      final c = await mount(tester);
      expect(c.read(audioDevicesProvider).outputTest, AudioTestState.idle);
      await tester.ensureVisible(key('audio-output-test'));
      await tester.tap(key('audio-output-test'));
      await tester.pump();
      expect(find.text('Cancel test'), findsOneWidget);
      await tester.tap(key('audio-output-test'));
      await tester.pump();
      expect(find.text('Test speaker'), findsOneWidget);
      expect(c.read(audioDevicesProvider).outputTest, AudioTestState.cancelled);
    });

    testWidgets('live mode shows an unavailable state with controls disabled', (
      tester,
    ) async {
      await mount(tester, demo: false);
      expect(key('audio-notice'), findsOneWidget);
      expect(find.textContaining('not available on the robot'), findsWidgets);
      expect(find.text('Unavailable'), findsNWidgets(2));
      for (final button in [
        'audio-input-test',
        'audio-output-test',
        'audio-refresh',
      ]) {
        final widget = tester.widget<ButtonStyleButton>(key(button));
        expect(widget.onPressed, isNull, reason: button);
      }
    });

    for (final size in const [
      Size(320, 900),
      Size(390, 844),
      Size(700, 1100),
    ]) {
      testWidgets('stacks without overflow at ${size.width.toInt()} px', (
        tester,
      ) async {
        await mount(tester, size: size);
        expect(key('audio-devices-card'), findsOneWidget);
        expect(key('audio-two-columns'), findsNothing);
        final mic = tester.getTopLeft(find.text('Microphone (Input)'));
        final speaker = tester.getTopLeft(find.text('Speaker (Output)'));
        expect(speaker.dy, greaterThan(mic.dy));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
