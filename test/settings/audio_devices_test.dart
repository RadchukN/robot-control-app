import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/core/theme/app_theme.dart';
import 'package:robot_control_app/features/dashboard/application/dashboard_controller.dart';
import 'package:robot_control_app/features/settings/application/audio_devices_controller.dart';
import 'package:robot_control_app/features/settings/application/settings_state.dart';
import 'package:robot_control_app/features/settings/data/audio_device_backend.dart';
import 'package:robot_control_app/features/settings/data/live_audio_device_backend.dart';
import 'package:robot_control_app/features/settings/presentation/settings_screen.dart';
import 'package:robot_control_app/features/voice_studio/application/voice_studio_providers.dart';
import 'package:robot_control_app/features/voice_studio/domain/voice_models.dart';
import 'package:robot_control_app/services/robot_authentication.dart';
import 'package:robot_control_app/services/robot_connection.dart';
import 'package:robot_control_app/shared/notifications/app_notification_service.dart';

import '../robot_authentication_test.dart' show MemoryTokenStore;
import '../voice_studio/voice_test_helpers.dart';
import 'fake_jetson_audio.dart';

const _input = AudioDeviceDirection.input;
const _output = AudioDeviceDirection.output;
const _dji = FakeJetsonAudio.djiId;

List<String> _notes(ProviderContainer c) => [
  for (final n in c.read(appNotificationsProvider).visible) n.title,
  for (final n in c.read(appNotificationsProvider).queued) n.title,
];

/// Live mode over the fake Jetson: Demo Mode off, robot link open.
ProviderContainer _live(FakeJetsonAudio jetson, {List<String>? motionCalls}) {
  final c = ProviderContainer(
    overrides: [
      robotTokenStoreProvider.overrideWithValue(MemoryTokenStore()),
      dashboardControllerProvider.overrideWith(
        () => RecordingDashboardController(motionCalls ?? []),
      ),
      audioFrameTransportProvider.overrideWithValue(jetson),
    ],
  );
  c.read(voiceDemoModeProvider.notifier).set(false);
  c
      .read(robotLinkProvider.notifier)
      .update(const RobotLinkState(RobotLinkStatus.connected));
  return c;
}

Future<AudioDevicesState> _loaded(
  WidgetTester tester,
  ProviderContainer c,
) async {
  c.read(audioDevicesProvider);
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
  return c.read(audioDevicesProvider);
}

void main() {
  group('LiveAudioDeviceBackend', () {
    testWidgets('correlates replies by request id and ignores strangers', (
      tester,
    ) async {
      final jetson = FakeJetsonAudio(supportsAudio: false);
      final backend = LiveAudioDeviceBackend(jetson);
      addTearDown(backend.dispose);
      final devices = backend.getDevices();
      final id = jetson.sent.single['request_id']! as String;
      expect(jetson.sent.single, {
        'type': 'audio_get_devices',
        'request_id': id,
      });
      expect(id.length, inInclusiveRange(1, 64));

      var done = false;
      unawaited(devices.then((_) => done = true));
      jetson.push({
        'type': 'audio_devices',
        'request_id': 'other',
        'inputs': <Object>[],
        'outputs': <Object>[],
      });
      await tester.pump();
      expect(done, isFalse, reason: 'unrelated reply ignored');
      jetson.push({
        'type': 'audio_devices',
        'request_id': id,
        'inputs': [
          FakeJetsonAudio.device(_dji, 'input', 'usb', 'DJI Wireless Mic Rx'),
        ],
        'outputs': <Object>[],
      });
      expect((await devices).single.id, _dji);
    });

    testWidgets('a backend without audio support times out after 3 s', (
      tester,
    ) async {
      final backend = LiveAudioDeviceBackend(
        FakeJetsonAudio(supportsAudio: false),
      );
      addTearDown(backend.dispose);
      Object? error;
      unawaited(
        backend.getCapabilities().then(
          (_) {},
          onError: (Object e) => error = e,
        ),
      );
      await tester.pump(const Duration(milliseconds: 2900));
      expect(error, isNull);
      await tester.pump(const Duration(milliseconds: 200));
      expect((error! as AudioDeviceException).code, 'unsupported');
    });

    testWidgets('set_settings: push first, then the correlated result', (
      tester,
    ) async {
      final jetson = FakeJetsonAudio();
      final backend = LiveAudioDeviceBackend(jetson);
      addTearDown(backend.dispose);
      final events = <AudioBackendEvent>[];
      backend.events.listen(events.add);
      final saved = await backend.applySettings(
        const AudioDeviceSettings(outputId: 'robot:speaker'),
      );
      expect(
        jetson.sent.single.keys,
        unorderedEquals(['type', 'request_id', 'output_device_id']),
      );
      expect(saved.outputId, 'robot:speaker');
      expect(saved.inputId, _dji, reason: 'other direction kept');
      expect(events.single, isA<AudioStatusPushed>());
    });

    testWidgets('busy and rejected results become typed errors', (
      tester,
    ) async {
      final jetson = FakeJetsonAudio()..sessionOwner = 'realtime_voice';
      final backend = LiveAudioDeviceBackend(jetson);
      addTearDown(backend.dispose);
      await expectLater(
        backend.applySettings(const AudioDeviceSettings(inputId: _dji)),
        throwsA(
          isA<AudioDeviceException>()
              .having((e) => e.busy, 'busy', isTrue)
              .having((e) => e.owner, 'owner', 'realtime_voice'),
        ),
      );
      jetson.sessionOwner = null;
      await expectLater(
        backend.applySettings(const AudioDeviceSettings(inputId: 'usb:gone')),
        throwsA(
          isA<AudioDeviceException>().having(
            (e) => e.code,
            'code',
            'device_unavailable',
          ),
        ),
      );
    });

    testWidgets('a test waits past `accepted` and may finish out of order', (
      tester,
    ) async {
      final jetson = FakeJetsonAudio(
        testsEnabled: true,
        autoCompleteTests: false,
      );
      final backend = LiveAudioDeviceBackend(jetson);
      addTearDown(backend.dispose);
      AudioTestResult? result;
      unawaited(
        backend.testInput(_dji, durationSec: 3).then((r) => result = r),
      );
      expect(jetson.sent.single['confirm'], isTrue);
      expect(jetson.sent.single['duration_sec'], 3);
      await tester.pump();
      expect(result, isNull, reason: 'accepted is not the result');

      // A later request is answered before the test's final result.
      final devices = await backend.getDevices();
      expect(devices, isNotEmpty);
      expect(result, isNull);
      jetson.finishTests();
      await tester.pump();
      expect(result!.rms, 2226);
      expect(result!.peakDbfs, -2.6);
      expect(result!.signal, 'ok');
      expect(result!.clipping, isFalse);
    });

    testWidgets('pushes become events; disconnect fails pending requests', (
      tester,
    ) async {
      final jetson = FakeJetsonAudio(supportsAudio: false);
      final backend = LiveAudioDeviceBackend(jetson);
      final events = <AudioBackendEvent>[];
      backend.events.listen(events.add);
      jetson
        ..push({
          'type': 'audio_error',
          'code': 'input_device_lost',
          'fatal': false,
          'owner': 'realtime_voice',
        })
        ..push({'type': 'audio_new_future_push', 'x': 1})
        ..push(jetson.statusBody('audio_device_status', devicesChanged: true));
      await tester.pump();
      expect(events, hasLength(2), reason: 'unknown pushed types ignored');
      expect((events.last as AudioStatusPushed).status.devicesChanged, isTrue);

      final pending = backend.getStatus();
      backend.dispose();
      await expectLater(
        pending,
        throwsA(
          isA<AudioDeviceException>().having(
            (e) => e.code,
            'code',
            'disconnected',
          ),
        ),
      );
      jetson.connected = false;
      final after = LiveAudioDeviceBackend(jetson);
      addTearDown(after.dispose);
      await expectLater(
        after.getDevices(),
        throwsA(isA<AudioDeviceException>()),
      );
    });
  });

  group('AudioDevicesController (live)', () {
    testWidgets('negotiates, discovers and separates saved from active', (
      tester,
    ) async {
      final jetson = FakeJetsonAudio();
      final c = _live(jetson);
      addTearDown(c.dispose);
      final state = await _loaded(tester, c);
      expect(jetson.sentTypes, [
        'audio_get_capabilities',
        'audio_get_devices',
        'audio_device_status',
      ]);
      expect(state.simulated, isFalse);
      expect(state.devicesFor(_input).map((d) => d.name), [
        'Unitree G1 microphone',
        'System default',
        'DJI Wireless Mic Rx',
      ]);
      expect(state.devices.any((d) => d.simulated), isFalse);
      expect(state.savedId(_input), _dji);
      expect(state.savedId(_output), 'robot:speaker');
      expect(state.activeId(_input), isNull, reason: 'no running session');
      expect(
        state.capabilities.inputTest,
        isFalse,
        reason: 'tests_enabled false',
      );
      expect(_notes(c), isEmpty, reason: 'background discovery is silent');
    });

    testWidgets('unsupported backend leaves audio settings unavailable', (
      tester,
    ) async {
      final jetson = FakeJetsonAudio(supportsAudio: false);
      final c = _live(jetson);
      addTearDown(c.dispose);
      c.read(audioDevicesProvider);
      await tester.pump(const Duration(seconds: 4));
      final state = c.read(audioDevicesProvider);
      expect(state.error, contains('did not answer'));
      expect(state.devices, isEmpty);
      expect(jetson.sentTypes, ['audio_get_capabilities']);
      await c.read(audioDevicesProvider.notifier).select(_input, _dji);
      expect(jetson.sentTypes, [
        'audio_get_capabilities',
      ], reason: 'nothing else sent');
    });

    testWidgets('independent selection: pending, then saved, never active', (
      tester,
    ) async {
      final jetson = FakeJetsonAudio();
      final c = _live(jetson);
      addTearDown(c.dispose);
      await _loaded(tester, c);
      jetson.sent.clear();
      final controller = c.read(audioDevicesProvider.notifier);

      final pending = controller.select(_input, 'system:default');
      expect(c.read(audioDevicesProvider).applying, isTrue);
      await pending;
      var state = c.read(audioDevicesProvider);
      expect(jetson.sent.single, {
        'type': 'audio_set_settings',
        'request_id': jetson.sent.single['request_id'],
        'input_device_id': 'system:default',
      });
      expect(state.savedId(_input), 'system:default');
      expect(
        state.savedId(_output),
        'robot:speaker',
        reason: 'output untouched',
      );
      expect(state.activeId(_input), isNull);
      expect(c.read(settingsProvider).audioInputDeviceId, 'system:default');
      expect(c.read(settingsProvider).audioOutputDeviceId, isNull);
      expect(_notes(c), ['Microphone selected']);

      jetson.sent.clear();
      await controller.select(_output, 'robot:speaker');
      expect(jetson.sent, isEmpty, reason: 'already saved');

      // Active only when the robot reports a running session using it.
      jetson
        ..sessionOwner = 'realtime_voice'
        ..sessionInputId = 'system:default'
        ..sessionOutputId = 'robot:speaker';
      jetson.push(jetson.statusBody('audio_device_status'));
      await tester.pump();
      state = c.read(audioDevicesProvider);
      expect(state.activeId(_input), 'system:default');
      expect(state.backendBusy, isTrue);
    });

    testWidgets('robot busy lock blocks changes and tests without sending', (
      tester,
    ) async {
      final jetson = FakeJetsonAudio(testsEnabled: true)..sessionOwner = 'tts';
      final c = _live(jetson);
      addTearDown(c.dispose);
      await _loaded(tester, c);
      jetson.sent.clear();
      final controller = c.read(audioDevicesProvider.notifier);
      await controller.select(_input, 'system:default');
      await controller.toggleTest(_output);
      expect(jetson.sent, isEmpty);
      expect(c.read(audioDevicesProvider).savedId(_input), _dji);
      expect(_notes(c), ['Voice session is active']);
    });

    testWidgets('a busy reply from the robot is authoritative', (tester) async {
      final jetson = FakeJetsonAudio();
      final c = _live(jetson);
      addTearDown(c.dispose);
      await _loaded(tester, c);
      // The robot became busy before Flutter saw a status push.
      jetson.sessionOwner = 'realtime_voice';
      await c
          .read(audioDevicesProvider.notifier)
          .select(_input, 'system:default');
      final state = c.read(audioDevicesProvider);
      expect(state.savedId(_input), _dji);
      expect(
        state.desiredInputId,
        'system:default',
        reason: 'kept as local choice',
      );
      expect(_notes(c), ['Robot audio is busy']);
    });

    testWidgets('Flutter voice session also blocks changes', (tester) async {
      final jetson = FakeJetsonAudio();
      final c = _live(jetson);
      addTearDown(c.dispose);
      await _loaded(tester, c);
      jetson.sent.clear();
      c.read(audioSessionProvider.notifier).acquire(AudioOwner.realtime);
      await c
          .read(audioDevicesProvider.notifier)
          .select(_input, 'system:default');
      expect(jetson.sent, isEmpty);
    });

    testWidgets('unplugged selection stays visible and is never replaced', (
      tester,
    ) async {
      final jetson = FakeJetsonAudio();
      final c = _live(jetson);
      addTearDown(c.dispose);
      await _loaded(tester, c);
      jetson.sent.clear();
      jetson.inputs = jetson.inputs.where((d) => d['id'] != _dji).toList();
      jetson
        ..push({
          'type': 'audio_error',
          'code': 'selected_device_disconnected',
          'fatal': false,
          'direction': 'input',
          'device_id': _dji,
          'session_active': false,
        })
        ..push(jetson.statusBody('audio_device_status', devicesChanged: true));
      await tester.pump();
      await tester.pump();
      final state = c.read(audioDevicesProvider);
      expect(jetson.sentTypes, [
        'audio_get_devices',
      ], reason: 're-request devices');
      expect(state.device(_input, _dji), isNull);
      expect(state.savedId(_input), _dji, reason: 'never replaced');
      expect(
        state.savedSelection(_input)!.status,
        AudioSelectionStatus.disconnected,
      );
      expect(_notes(c), ['Audio device disconnected']);
    });

    testWidgets('reconnect refreshes and never replays a settings change', (
      tester,
    ) async {
      final jetson = FakeJetsonAudio();
      final c = _live(jetson);
      addTearDown(c.dispose);
      await _loaded(tester, c);
      await c
          .read(audioDevicesProvider.notifier)
          .select(_input, 'system:default');
      final link = c.read(robotLinkProvider.notifier);
      link.update(const RobotLinkState(RobotLinkStatus.reconnecting));
      expect(c.read(audioDevicesProvider).available, isFalse);
      jetson.sent.clear();
      link.update(const RobotLinkState(RobotLinkStatus.connected));
      final state = await _loaded(tester, c);
      expect(jetson.sentTypes, [
        'audio_get_capabilities',
        'audio_get_devices',
        'audio_device_status',
      ]);
      expect(state.savedId(_input), 'system:default', reason: 'from the robot');
    });

    testWidgets('settings file invalid is a configuration failure', (
      tester,
    ) async {
      final jetson = FakeJetsonAudio()..settingsFileInvalid = true;
      final c = _live(jetson);
      addTearDown(c.dispose);
      final state = await _loaded(tester, c);
      expect(state.status!.settingsFile, AudioSettingsFileStatus.invalid);
      expect(
        state.savedSelection(_input)!.source,
        AudioSelectionSource.envFallback,
      );
      jetson.push({
        'type': 'audio_error',
        'code': 'settings_file_invalid',
        'fatal': false,
        'fallback': 'env',
      });
      await tester.pump();
      expect(_notes(c), ['Audio configuration failure']);
    });

    testWidgets('tests: gated by tests_enabled, measured, not cancellable', (
      tester,
    ) async {
      final disabled = FakeJetsonAudio();
      final c1 = _live(disabled);
      addTearDown(c1.dispose);
      await _loaded(tester, c1);
      disabled.sent.clear();
      await c1.read(audioDevicesProvider.notifier).toggleTest(_input);
      expect(disabled.sent, isEmpty, reason: 'tests_enabled false');

      final jetson = FakeJetsonAudio(testsEnabled: true);
      final c = _live(jetson);
      addTearDown(c.dispose);
      await _loaded(tester, c);
      jetson.sent.clear();
      await c.read(audioDevicesProvider.notifier).toggleTest(_input);
      expect(jetson.sent.single, containsPair('confirm', true));
      expect(jetson.sent.single, containsPair('device_id', _dji));
      final state = c.read(audioDevicesProvider);
      expect(state.inputTest, AudioTestState.passed);
      expect(state.inputTestMessage, contains('RMS 2226'));
      expect(state.inputTestMessage, contains('-2.6 dBFS'));

      jetson
        ..autoCompleteTests = false
        ..sent.clear();
      final speaker = c.read(audioDevicesProvider.notifier).toggleTest(_output);
      expect(c.read(audioDevicesProvider).outputTest, AudioTestState.running);
      await c.read(audioDevicesProvider.notifier).toggleTest(_output);
      expect(c.read(audioDevicesProvider).outputTest, AudioTestState.cancelled);
      expect(
        c.read(audioDevicesProvider).outputTestMessage,
        contains('may still finish'),
      );
      expect(jetson.sentTypes, [
        'audio_test_output',
      ], reason: 'no cancel message exists');
      jetson.finishTests();
      await speaker;
      expect(
        c.read(audioDevicesProvider).outputTest,
        AudioTestState.cancelled,
        reason: 'late result does not overwrite',
      );
    });

    testWidgets('Demo Mode never sends audio frames', (tester) async {
      final jetson = FakeJetsonAudio();
      final motionCalls = <String>[];
      final c = ProviderContainer(
        overrides: [
          dashboardControllerProvider.overrideWith(
            () => RecordingDashboardController(motionCalls),
          ),
          audioFrameTransportProvider.overrideWithValue(jetson),
        ],
      );
      addTearDown(c.dispose);
      c
          .read(robotLinkProvider.notifier)
          .update(const RobotLinkState(RobotLinkStatus.connected));
      final state = await _loaded(tester, c);
      expect(state.simulated, isTrue);
      final controller = c.read(audioDevicesProvider.notifier);
      await controller.select(_input, MockAudioDeviceBackend.usbMicId);
      final test = controller.toggleTest(_output);
      await tester.pump(MockAudioDeviceBackend.outputTestDuration);
      await test;
      expect(jetson.sent, isEmpty);
      expect(motionCalls, isEmpty);
    });
  });

  group('Audio devices card (live)', () {
    Future<(ProviderContainer, FakeJetsonAudio)> mount(
      WidgetTester tester, {
      bool testsEnabled = false,
      Size size = const Size(1200, 1400),
    }) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final jetson = FakeJetsonAudio(testsEnabled: testsEnabled);
      final c = _live(jetson);
      addTearDown(c.dispose);
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
      return (c, jetson);
    }

    Finder key(String k) => find.byKey(Key(k));

    testWidgets('shows real devices and saved, not active, state', (
      tester,
    ) async {
      await mount(tester);
      expect(key('connection-two-columns'), findsOneWidget);
      expect(find.text('DJI Wireless Mic Rx'), findsOneWidget);
      expect(find.text('Unitree G1 built-in speaker'), findsOneWidget);
      expect(find.textContaining('(simulated)'), findsNothing);
      final status = tester.widget<Text>(key('audio-input-status')).data!;
      expect(status, contains('Saved on the robot'));
      expect(status, contains('next starts'));
      expect(status, isNot(contains('In use')));
      expect(
        tester.widget<ButtonStyleButton>(key('audio-input-test')).onPressed,
        isNull,
        reason: 'tests_enabled false',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('live tests ask for confirmation; Cancel sends nothing', (
      tester,
    ) async {
      final (_, jetson) = await mount(tester, testsEnabled: true);
      jetson.sent.clear();
      await tester.ensureVisible(key('audio-output-test'));
      await tester.tap(key('audio-output-test'));
      await tester.pumpAndSettle();
      expect(key('audio-test-confirm'), findsOneWidget);
      expect(find.textContaining('current volume'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(jetson.sent, isEmpty);

      await tester.tap(key('audio-output-test'));
      await tester.pumpAndSettle();
      await tester.tap(key('audio-test-confirm-start'));
      await tester.pumpAndSettle();
      expect(jetson.sentTypes, ['audio_test_output']);
      expect(jetson.sent.single['confirm'], isTrue);
    });

    testWidgets('robot busy lock disables controls with a notice', (
      tester,
    ) async {
      final (_, jetson) = await mount(tester, testsEnabled: true);
      jetson.sessionOwner = 'realtime_voice';
      jetson.push(jetson.statusBody('audio_device_status'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('in use by realtime_voice'), findsOneWidget);
      expect(
        tester.widget<ButtonStyleButton>(key('audio-input-test')).onPressed,
        isNull,
      );
    });

    testWidgets('stacks without overflow at phone width', (tester) async {
      await mount(tester, size: const Size(390, 2400));
      expect(key('audio-two-columns'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('Demo Mode card keeps simulated devices and behaviour', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final c = ProviderContainer(
      overrides: [
        robotTokenStoreProvider.overrideWithValue(MemoryTokenStore()),
        dashboardControllerProvider.overrideWith(
          () => RecordingDashboardController([]),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SingleChildScrollView(child: RobotConnectionPanel()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Unitree G1 microphone array (simulated)'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Demo Mode · simulated devices'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byKey(const Key('audio-input-test')));
    await tester.tap(find.byKey(const Key('audio-input-test')));
    await tester.pump();
    expect(find.byKey(const Key('audio-test-confirm')), findsNothing);
    expect(find.text('Cancel test'), findsOneWidget);
    await tester.tap(find.byKey(const Key('audio-input-test')));
    await tester.pump();
    expect(c.read(audioDevicesProvider).inputTest, AudioTestState.cancelled);
  });
}
