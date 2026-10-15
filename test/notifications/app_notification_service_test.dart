import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/features/motion/application/motion_state.dart';
import 'package:robot_control_app/features/motion/presentation/motion_notifications.dart';
import 'package:robot_control_app/services/robot_connection.dart';
import 'package:robot_control_app/shared/notifications/app_notification.dart';
import 'package:robot_control_app/shared/notifications/app_notification_service.dart';
import 'package:robot_control_app/shared/notifications/robot_link_notifications.dart';

/// A container whose service behaves as if a host were on screen.
(ProviderContainer, AppNotificationService) _service({bool host = true}) {
  final container = ProviderContainer();
  final service = container.read(appNotificationsProvider.notifier);
  if (host) service.attachHost();
  return (container, service);
}

List<String> _titles(ProviderContainer c) =>
    c.read(appNotificationsProvider).visible.map((n) => n.title).toList();

void main() {
  group('types', () {
    test('typed helpers set badge, type and timeout', () {
      final (container, service) = _service(host: false);
      addTearDown(container.dispose);
      service
        ..success('s')
        ..info('i')
        ..warning('w');
      service
        ..error('e')
        ..unsaved('u')
        ..critical('c')
        ..progress('p', value: 0.4);
      final all = [
        ...container.read(appNotificationsProvider).visible,
        ...container.read(appNotificationsProvider).queued,
      ];
      AppNotification byTitle(String t) => all.firstWhere((n) => n.title == t);
      expect(byTitle('s').badgeLabel, 'Success');
      expect(byTitle('s').duration, const Duration(milliseconds: 3500));
      expect(byTitle('i').duration, const Duration(milliseconds: 4500));
      expect(byTitle('w').duration, const Duration(seconds: 7));
      expect(byTitle('e').duration, const Duration(seconds: 12));
      expect(byTitle('u').badgeLabel, 'Unsaved');
      expect(byTitle('c').duration, isNull);
      expect(byTitle('c').closable, isFalse);
      expect(byTitle('p').duration, isNull);
      expect(byTitle('p').progress, 0.4);
    });
  });

  group('timeouts', () {
    testWidgets('each type auto-dismisses after its own duration', (
      tester,
    ) async {
      final (container, service) = _service();
      addTearDown(container.dispose);
      for (final (type, duration) in [
        (AppNotificationType.success, const Duration(milliseconds: 3500)),
        (AppNotificationType.info, const Duration(milliseconds: 4500)),
        (AppNotificationType.warning, const Duration(seconds: 7)),
        (AppNotificationType.error, const Duration(seconds: 12)),
      ]) {
        service.show(type, type.name);
        await tester.pump(duration - const Duration(milliseconds: 50));
        expect(_titles(container), [type.name], reason: '${type.name} early');
        await tester.pump(const Duration(milliseconds: 60));
        expect(_titles(container), isEmpty, reason: '${type.name} late');
      }
    });

    testWidgets('critical and progress never time out', (tester) async {
      final (container, service) = _service();
      addTearDown(container.dispose);
      service
        ..critical('Robot motion state unknown')
        ..progress('Connecting…');
      await tester.pump(const Duration(hours: 1));
      expect(_titles(container), hasLength(2));
      service.dismissAll();
      expect(
        _titles(container),
        ['Robot motion state unknown'],
        reason: 'dismissAll never hides an unresolved safety condition',
      );
      service.dismiss(
        container.read(appNotificationsProvider).visible.single.key,
      );
      expect(_titles(container), isEmpty);
    });

    testWidgets('countdowns run only while a host is mounted', (tester) async {
      final (container, service) = _service(host: false);
      addTearDown(container.dispose);
      service.success('Saved');
      await tester.pump(const Duration(seconds: 10));
      expect(_titles(container), ['Saved'], reason: 'nothing on screen yet');

      service.attachHost();
      await tester.pump(const Duration(seconds: 4));
      expect(_titles(container), isEmpty);

      service.info('Later');
      service.detachHost();
      await tester.pump(const Duration(seconds: 10));
      expect(_titles(container), ['Later'], reason: 'detach cancels timers');
    });

    testWidgets('hold pauses and release restarts the countdown', (
      tester,
    ) async {
      final (container, service) = _service();
      addTearDown(container.dispose);
      final key = service.success('Copied');
      await tester.pump(const Duration(seconds: 3));
      service.hold(key);
      await tester.pump(const Duration(seconds: 10));
      expect(_titles(container), ['Copied']);
      service.release(key);
      await tester.pump(const Duration(seconds: 3));
      expect(_titles(container), ['Copied']);
      await tester.pump(const Duration(seconds: 1));
      expect(_titles(container), isEmpty);
    });
  });

  group('stacking', () {
    testWidgets('shows at most three and promotes the queue in order', (
      tester,
    ) async {
      final (container, service) = _service();
      addTearDown(container.dispose);
      for (var i = 1; i <= 5; i++) {
        service.error('E$i');
      }
      final state = container.read(appNotificationsProvider);
      expect(state.visible.map((n) => n.title), ['E3', 'E2', 'E1']);
      expect(state.queued.map((n) => n.title), ['E4', 'E5']);

      service.dismiss(state.visible.first.key);
      expect(_titles(container), ['E2', 'E1', 'E4']);
      expect(
        container.read(appNotificationsProvider).queued.map((n) => n.title),
        ['E5'],
      );
      service.dismissAll();
      expect(container.read(appNotificationsProvider).visible, isEmpty);
      expect(container.read(appNotificationsProvider).queued, isEmpty);
    });

    testWidgets('a critical notification always takes a visible slot', (
      tester,
    ) async {
      final (container, service) = _service();
      addTearDown(container.dispose);
      service
        ..error('A')
        ..error('B')
        ..error('C')
        ..critical('Safety');
      final state = container.read(appNotificationsProvider);
      expect(state.visible.first.title, 'Safety');
      expect(state.visible, hasLength(3));
      expect(state.queued.single.title, 'A', reason: 'oldest displaced');
      service.error('D');
      expect(_titles(container).first, 'Safety', reason: 'critical leads');
      service.detachHost();
    });

    testWidgets('repeated events are de-duplicated and refresh the timer', (
      tester,
    ) async {
      final (container, service) = _service();
      addTearDown(container.dispose);
      service.info('Telemetry', description: 'same');
      await tester.pump(const Duration(seconds: 4));
      service.info('Telemetry', description: 'same');
      final visible = container.read(appNotificationsProvider).visible;
      expect(visible, hasLength(1));
      expect(visible.single.repeatCount, 2);
      await tester.pump(const Duration(seconds: 4));
      expect(_titles(container), ['Telemetry'], reason: 'timer restarted');
      await tester.pump(const Duration(seconds: 1));
      expect(_titles(container), isEmpty);
    });

    testWidgets('a keyed notification updates in place', (tester) async {
      final (container, service) = _service();
      addTearDown(container.dispose);
      service
        ..info('Other')
        ..progress('Connecting to robot…', key: 'link');
      await tester.pump(const Duration(minutes: 1));
      expect(_titles(container), ['Connecting to robot…']);
      service.success('Connected successfully', key: 'link');
      final visible = container.read(appNotificationsProvider).visible;
      expect(visible.single.type, AppNotificationType.success);
      await tester.pump(const Duration(seconds: 4));
      expect(_titles(container), isEmpty);
    });
  });

  group('robot link policy', () {
    RobotLinkState link(RobotLinkStatus status, [String? message]) =>
        RobotLinkState(status, message: message);

    test('reports one outage while retries cycle, then success', () {
      final (container, service) = _service(host: false);
      addTearDown(container.dispose);
      final policy = RobotLinkNotificationPolicy();
      var settingsOpened = 0;
      RobotLinkState? previous;
      void apply(RobotLinkState next) {
        policy.apply(
          service,
          previous,
          next,
          openSettings: () => settingsOpened++,
        );
        previous = next;
      }

      apply(link(RobotLinkStatus.connecting));
      expect(
        container.read(appNotificationsProvider).visible.single.type,
        AppNotificationType.progress,
      );
      for (var i = 0; i < 3; i++) {
        apply(link(RobotLinkStatus.disconnected, 'Connection refused'));
        apply(link(RobotLinkStatus.reconnecting, 'Retrying in 2s'));
        apply(link(RobotLinkStatus.connecting));
      }
      var visible = container.read(appNotificationsProvider).visible;
      expect(visible, hasLength(1));
      expect(visible.single.title, 'Connection failed');
      expect(visible.single.repeatCount, 1, reason: 'reported once');
      visible.single.action!.onPressed();
      expect(settingsOpened, 1);

      apply(link(RobotLinkStatus.awaitingTelemetry));
      apply(link(RobotLinkStatus.connected));
      visible = container.read(appNotificationsProvider).visible;
      expect(visible.single.title, 'Connected successfully');

      apply(link(RobotLinkStatus.degraded, 'stale'));
      expect(
        container.read(appNotificationsProvider).visible.single.title,
        'Telemetry unavailable',
      );
      apply(link(RobotLinkStatus.authenticationRequired, 'Token rejected'));
      final auth = container.read(appNotificationsProvider).visible.single;
      expect(auth.type, AppNotificationType.error);
      expect(auth.duration, isNull, reason: 'auth error stays until fixed');
      expect(auth.action?.label, 'Settings');

      apply(link(RobotLinkStatus.disconnected));
      expect(container.read(appNotificationsProvider).visible, isEmpty);
    });
  });

  group('motion messages', () {
    MotionState motion(MotionPlaybackStatus status, String message) =>
        const MotionState.initial().copyWith(
          playbackStatus: status,
          commandMessage: message,
        );

    test('maps results to types and keeps safety critical', () {
      final (container, service) = _service(host: false);
      addTearDown(container.dispose);
      AppNotification last() =>
          container.read(appNotificationsProvider).visible.first;

      notifyMotionCommand(
        service,
        motion(MotionPlaybackStatus.simulated, 'Hello: $simulationOnlyLabel'),
      );
      expect(last().title, 'Motion simulation');
      expect(last().type, AppNotificationType.info);
      expect(last().description, contains('robot did not move'));

      notifyMotionCommand(
        service,
        motion(
          MotionPlaybackStatus.error,
          'Hello: A command is pending or its outcome is unknown. '
          'Stop remains available.',
        ),
      );
      final critical = container
          .read(appNotificationsProvider)
          .visible
          .firstWhere((n) => n.isCritical);
      expect(critical.title, 'Robot motion state unknown');

      // Even a "stopped" result never clears the safety card on its own.
      notifyMotionCommand(
        service,
        motion(MotionPlaybackStatus.stopped, 'Stop: Stopped'),
      );
      expect(
        container
            .read(appNotificationsProvider)
            .visible
            .where((n) => n.isCritical),
        hasLength(1),
      );

      final before = container.read(appNotificationsProvider);
      notifyMotionCommand(
        service,
        motion(
          MotionPlaybackStatus.idle,
          'Robot WebSocket connected. No motion was sent.',
        ),
      );
      expect(container.read(appNotificationsProvider), same(before));
    });
  });
}
