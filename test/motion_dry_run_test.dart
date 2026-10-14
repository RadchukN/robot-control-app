import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/features/dashboard/application/dashboard_controller.dart';
import 'package:robot_control_app/features/motion/application/motion_state.dart';
import 'package:robot_control_app/models/dashboard_data.dart';
import 'package:robot_control_app/services/robot_service.dart';
import 'package:robot_control_app/services/web_socket_service.dart';

import 'fixture_api_client.dart';

// Mirrors the Jetson dry-run backend; nothing here talks to a robot.
Map<String, dynamic> _dryRun(String action, {String? motion}) => {
  'type': 'motion_result',
  'status': 'dry_run',
  'action': action,
  'motion': ?motion,
  'backend_command': 'arm_task_high_wave',
  'g1_command': 'SET_ARM_TASK HighWave (26)',
  'robot_ip': '192.168.123.161',
  'connection_state': 'not_connected_dry_run',
  'dry_run': true,
};

class _DryRunDashboardController extends DashboardController {
  _DryRunDashboardController(this.session, this.writes);

  final MotionCommandSession session;
  final List<String> writes;

  @override
  Future<DashboardData> build() async =>
      DashboardData(updatedAt: DateTime(2026), telemetryConnected: true);

  @override
  Future<List<String>> getMotionCatalog() async => ['67.json'];

  @override
  Future<Map<String, dynamic>> sendMotion(
    String action, {
    String? motion,
    void Function(Map<String, dynamic>)? onResult,
  }) => session.send(action, writes.add, motion: motion, onResult: onResult);
}

void main() {
  group('MotionCommandSession dry_run', () {
    late MotionCommandSession session;
    late List<String> writes;

    setUp(() {
      session = MotionCommandSession()..setMotionCatalog(['67.json']);
      writes = [];
    });

    test('wave_hand dry_run completes and allows the next command', () async {
      final updates = <Map<String, dynamic>>[];
      final wave = session.send('wave_hand', writes.add, onResult: updates.add);
      expect(jsonDecode(writes.single), {
        'type': 'motion',
        'action': 'wave_hand',
      });

      session.handleResult(_dryRun('wave_hand'));

      final result = await wave;
      expect(result['status'], 'dry_run');
      expect(updates.single['status'], 'dry_run');

      final next = session.send('wave_hand', writes.add);
      expect(writes, hasLength(2));
      session.handleResult(_dryRun('wave_hand'));
      expect((await next)['status'], 'dry_run');
    });

    test('play_recorded_motion 67.json dry_run completes', () async {
      final play = session.send(
        'play_recorded_motion',
        writes.add,
        motion: '67.json',
      );
      expect(jsonDecode(writes.single), {
        'type': 'motion',
        'action': 'play_recorded_motion',
        'motion': '67.json',
      });

      session.handleResult(_dryRun('play_recorded_motion', motion: '67.json'));

      expect((await play)['status'], 'dry_run');
    });

    test('sequential dry runs across wave_hand and 67.json', () async {
      for (var i = 0; i < 3; i++) {
        final wave = session.send('wave_hand', writes.add);
        session.handleResult(_dryRun('wave_hand'));
        expect((await wave)['status'], 'dry_run');

        final play = session.send(
          'play_recorded_motion',
          writes.add,
          motion: '67.json',
        );
        session.handleResult(
          _dryRun('play_recorded_motion', motion: '67.json'),
        );
        expect((await play)['status'], 'dry_run');
      }
      expect(writes, hasLength(6));
    });

    test('uncorrelated dry_run responses do not clear pending', () async {
      var settled = false;
      final play = session.send(
        'play_recorded_motion',
        writes.add,
        motion: '67.json',
      );
      unawaited(play.whenComplete(() => settled = true));

      // Wrong action, missing action, wrong motion, missing motion.
      session.handleResult(_dryRun('wave_hand'));
      session.handleResult(_dryRun('play_recorded_motion')..remove('action'));
      session.handleResult(
        _dryRun('play_recorded_motion', motion: 'other.json'),
      );
      session.handleResult(_dryRun('play_recorded_motion'));
      await pumpEventQueue();
      expect(settled, isFalse);

      // Still pending: a new non-stop command is refused.
      await expectLater(
        session.send('wave_hand', writes.add),
        throwsA(isA<StateError>()),
      );
      expect(writes, hasLength(1));

      session.handleResult(_dryRun('play_recorded_motion', motion: '67.json'));
      expect((await play)['status'], 'dry_run');
    });

    test('dry_run status without dry_run flag stays uncertain', () async {
      final wave = session.send('wave_hand', writes.add);
      session.handleResult(_dryRun('wave_hand')..remove('dry_run'));
      await expectLater(wave, throwsA(isA<StateError>()));
      await expectLater(
        session.send('wave_hand', writes.add),
        throwsA(isA<StateError>()),
      );
    });

    test('unknown status still marks outcome uncertain', () async {
      final wave = session.send('wave_hand', writes.add);
      session.handleResult({
        'type': 'motion_result',
        'status': 'mystery',
        'action': 'wave_hand',
      });
      await expectLater(wave, throwsA(isA<StateError>()));
      await expectLater(
        session.send('wave_hand', writes.add),
        throwsA(isA<StateError>()),
      );
      expect(writes, hasLength(1));
    });

    test('disconnect still fails a pending command', () async {
      final wave = session.send('wave_hand', writes.add);
      session.disconnect();
      await expectLater(wave, throwsA(isA<StateError>()));
      session.handleResult(_dryRun('wave_hand'));
    });

    test(
      'dry_run Stop after a live-command disconnect keeps the outcome unknown',
      () async {
        // A command on the wire when the socket drops may have reached a live robot.
        final wave = session.send('wave_hand', writes.add);
        session.disconnect();
        await expectLater(wave, throwsA(isA<StateError>()));
        await expectLater(
          session.send('wave_hand', writes.add),
          throwsA(isA<StateError>()),
        );

        final simulatedStop = session.send('stop_motion', writes.add);
        session.handleResult(_dryRun('stop_motion'));
        expect((await simulatedStop)['status'], 'dry_run');
        await expectLater(
          session.send('wave_hand', writes.add),
          throwsA(isA<StateError>()),
          reason: 'a simulated Stop is not proof of physical safety',
        );

        final failedStop = session.send('stop_motion', writes.add);
        session.handleResult({
          'type': 'motion_result',
          'status': 'failed',
          'action': 'stop_motion',
        });
        expect((await failedStop)['status'], 'failed');
        await expectLater(
          session.send('wave_hand', writes.add),
          throwsA(isA<StateError>()),
        );

        // Only a verified live Stop clears the uncertainty.
        final liveStop = session.send('stop_motion', writes.add);
        session.handleResult({
          'type': 'motion_result',
          'status': 'stopped',
          'action': 'stop_motion',
        });
        expect((await liveStop)['status'], 'stopped');
        final next = session.send('wave_hand', writes.add);
        session.handleResult(_dryRun('wave_hand'));
        expect((await next)['status'], 'dry_run');
        expect(writes.map((w) => jsonDecode(w)['action']), [
          'wave_hand',
          'stop_motion',
          'stop_motion',
          'stop_motion',
          'wave_hand',
        ]);
      },
    );

    test('stopped result flagged dry_run does not clear uncertainty', () async {
      final wave = session.send('wave_hand', writes.add);
      session.disconnect();
      await expectLater(wave, throwsA(isA<StateError>()));

      final stop = session.send('stop_motion', writes.add);
      session.handleResult({..._dryRun('stop_motion'), 'status': 'stopped'});
      expect((await stop)['status'], 'stopped');
      await expectLater(
        session.send('wave_hand', writes.add),
        throwsA(isA<StateError>()),
      );
    });

    test('pure dry-run sequence including Stop stays unblocked', () async {
      for (final (action, motion) in [
        ('wave_hand', null),
        ('stop_motion', null),
        ('play_recorded_motion', '67.json'),
        ('stop_motion', null),
        ('wave_hand', null),
      ]) {
        final command = session.send(action, writes.add, motion: motion);
        session.handleResult(_dryRun(action, motion: motion));
        expect((await command)['status'], 'dry_run');
      }
      expect(writes, hasLength(5));
    });
  });

  group('MotionController dry_run', () {
    late MotionCommandSession session;
    late List<String> writes;
    late ProviderContainer container;

    setUp(() async {
      session = MotionCommandSession()..setMotionCatalog(['67.json']);
      writes = [];
      container = ProviderContainer(
        overrides: [
          dashboardControllerProvider.overrideWith(
            () => _DryRunDashboardController(session, writes),
          ),
          robotServiceProvider.overrideWithValue(
            RobotService(FixtureApiClient()),
          ),
        ],
      );
      container.read(motionProvider);
      await container.read(dashboardControllerProvider.future);
      await pumpEventQueue();
    });

    tearDown(() => container.dispose());

    test('shows simulation only and accepts sequential commands', () async {
      final controller = container.read(motionProvider.notifier);
      const hello = QuickGesture('hello', 'Hello', 2.1, 0);

      for (var i = 0; i < 2; i++) {
        final wave = controller.playGesture(hello);
        await pumpEventQueue();
        session.handleResult(_dryRun('wave_hand'));
        expect(await wave, isFalse, reason: 'robot did not move');
        var state = container.read(motionProvider);
        expect(state.playbackStatus, MotionPlaybackStatus.simulated);
        expect(state.commandMessage, contains(simulationOnlyLabel));
        expect(state.error, isNull);

        final play = controller.sendRecordedMotion('67.json');
        await pumpEventQueue();
        session.handleResult(
          _dryRun('play_recorded_motion', motion: '67.json'),
        );
        expect(await play, isFalse);
        state = container.read(motionProvider);
        expect(state.playbackStatus, MotionPlaybackStatus.simulated);
        expect(state.commandMessage, '67.json: $simulationOnlyLabel');
        expect(state.error, isNull);
      }
      expect(writes.map(jsonDecode), [
        for (var i = 0; i < 2; i++) ...[
          {'type': 'motion', 'action': 'wave_hand'},
          {
            'type': 'motion',
            'action': 'play_recorded_motion',
            'motion': '67.json',
          },
        ],
      ]);
    });
  });
}
