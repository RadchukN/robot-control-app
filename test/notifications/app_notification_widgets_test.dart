import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/app.dart';
import 'package:robot_control_app/core/routing/app_router.dart';
import 'package:robot_control_app/core/routing/app_routes.dart';
import 'package:robot_control_app/features/dashboard/application/dashboard_controller.dart';
import 'package:robot_control_app/services/robot_connection.dart';
import 'package:robot_control_app/services/robot_service.dart';
import 'package:robot_control_app/shared/notifications/app_notification.dart';
import 'package:robot_control_app/shared/notifications/app_notification_card.dart';
import 'package:robot_control_app/shared/notifications/app_notification_host.dart';
import 'package:robot_control_app/shared/notifications/app_notification_service.dart';

import '../fixture_api_client.dart';
import '../voice_studio/voice_test_helpers.dart';

const _exit = Duration(milliseconds: 300);

Future<(ProviderContainer, AppNotificationService)> _pumpHost(
  WidgetTester tester, {
  Size size = const Size(1440, 900),
  ThemeData? theme,
  bool disableAnimations = false,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: disableAnimations),
        child: MaterialApp(
          theme: theme,
          builder: (context, child) => AppNotificationHost(child: child!),
          home: const Scaffold(body: Center(child: Text('Page'))),
        ),
      ),
    ),
  );
  return (container, container.read(appNotificationsProvider.notifier));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Finder get _cards => find.byType(AppNotificationCard);

void main() {
  group('AppNotificationCard', () {
    for (final brightness in Brightness.values) {
      testWidgets('renders every variant in ${brightness.name} theme', (
        tester,
      ) async {
        final (_, service) = await _pumpHost(
          tester,
          size: const Size(1440, 1400),
          theme: ThemeData(brightness: brightness),
        );
        for (final type in AppNotificationType.values) {
          service.show(
            type,
            'Title ${type.name}',
            description: 'About ${type.name}',
          );
          await tester.pump(_exit);
          await tester.pump(_exit);
          final card = find.widgetWithText(
            AppNotificationCard,
            'Title ${type.name}',
          );
          expect(card, findsOneWidget);
          expect(
            find.descendant(of: card, matching: find.text(type.badge)),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: card,
              matching: find.text('About ${type.name}'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: card,
              matching: find.byKey(const Key('app-notification-close')),
            ),
            type == AppNotificationType.critical
                ? findsNothing
                : findsOneWidget,
          );
          expect(
            find.descendant(
              of: card,
              matching: find.byKey(const Key('app-notification-acknowledge')),
            ),
            type == AppNotificationType.critical
                ? findsOneWidget
                : findsNothing,
          );
          expect(
            find.descendant(
              of: card,
              matching: find.byType(LinearProgressIndicator),
            ),
            type == AppNotificationType.progress
                ? findsOneWidget
                : findsNothing,
          );
          service.dismissAll();
          if (type == AppNotificationType.critical) {
            service.dismiss(
              tester.widget<AppNotificationCard>(card).notification.key,
            );
          }
          await tester.pump(_exit);
          await tester.pump(_exit);
        }
        expect(tester.takeException(), isNull);
        await _unmount(tester);
      });
    }

    test('tones are soft in light mode and use dark surfaces in dark mode', () {
      for (final type in AppNotificationType.values) {
        final light = AppNotificationTone.of(type, Brightness.light);
        final dark = AppNotificationTone.of(type, Brightness.dark);
        expect(light.surface.computeLuminance(), greaterThan(0.9));
        expect(dark.surface.computeLuminance(), lessThan(0.05));
        expect(light.border.a, lessThan(1), reason: 'thin, soft border');
        expect(light.badgeBackground.a, lessThan(0.2));
      }
    });

    testWidgets('long text is clamped without overflow on narrow screens', (
      tester,
    ) async {
      final (_, service) = await _pumpHost(tester, size: const Size(320, 640));
      service.error(
        'A very long notification title ' * 6,
        description: 'Supporting description that keeps going ' * 12,
        action: AppNotificationAction('View details with a long label', () {}),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final size = tester.getSize(_cards);
      expect(size.width, 320 - 24);
      expect(size.height, lessThan(320));
      await _unmount(tester);
    });
  });

  group('AppNotificationHost', () {
    testWidgets('desktop cards float top-right at a bounded width', (
      tester,
    ) async {
      final (_, service) = await _pumpHost(tester);
      service.success('Connected successfully');
      await tester.pumpAndSettle();
      final rect = tester.getRect(_cards);
      expect(rect.width, 400);
      expect(rect.right, 1440 - 20);
      expect(rect.top, greaterThanOrEqualTo(100));
      // The page underneath is not shifted.
      expect(tester.getCenter(find.text('Page')), const Offset(720, 450));
      await _unmount(tester);
    });

    testWidgets('compact cards span the width and respect SafeArea', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: 47),
              viewInsets: EdgeInsets.only(bottom: 300),
            ),
            child: MaterialApp(
              builder: (context, child) => AppNotificationHost(child: child!),
              home: const Scaffold(body: SizedBox()),
            ),
          ),
        ),
      );
      container
          .read(appNotificationsProvider.notifier)
          .info('Motion simulation');
      await tester.pumpAndSettle();
      final rect = tester.getRect(_cards);
      expect(rect.width, 390 - 24);
      expect(rect.top, greaterThanOrEqualTo(47 + 82));
      expect(rect.bottom, lessThan(844 - 300), reason: 'clear of keyboard');
      await _unmount(tester);
    });

    testWidgets('stacks three, queues the rest, and animates out', (
      tester,
    ) async {
      final (container, service) = await _pumpHost(tester);
      for (var i = 1; i <= 4; i++) {
        service.error('Error $i');
      }
      await tester.pumpAndSettle();
      expect(_cards, findsNWidgets(3));
      expect(find.text('Error 3'), findsOneWidget, reason: 'newest on top');
      expect(find.text('Error 4'), findsNothing, reason: 'queued when full');

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(AppNotificationCard, 'Error 3'),
          matching: find.byKey(const Key('app-notification-close')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 90));
      expect(find.text('Error 3'), findsOneWidget, reason: 'exit animation');
      await tester.pump(_exit);
      await tester.pumpAndSettle();
      expect(find.text('Error 3'), findsNothing);
      expect(find.text('Error 4'), findsOneWidget, reason: 'promoted');
      expect(_cards, findsNWidgets(3));
      expect(container.read(appNotificationsProvider).queued, isEmpty);
      await _unmount(tester);
    });

    testWidgets('auto-dismisses and pauses while hovered', (tester) async {
      final (_, service) = await _pumpHost(tester);
      service.success('Transcript copied');
      await tester.pumpAndSettle();

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(_cards));
      await tester.pump(const Duration(seconds: 10));
      expect(_cards, findsOneWidget, reason: 'paused under the pointer');

      await mouse.moveTo(Offset.zero);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(_cards, findsNothing);
      await _unmount(tester);
    });

    testWidgets('action runs its callback and dismisses the card', (
      tester,
    ) async {
      final (_, service) = await _pumpHost(tester);
      var retried = 0;
      service.error(
        'Connection failed',
        action: AppNotificationAction('Retry', () => retried++),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(retried, 1);
      expect(_cards, findsNothing);
      await _unmount(tester);
    });

    testWidgets('keyboard: F6 reaches actions, Enter activates, Esc closes', (
      tester,
    ) async {
      final (_, service) = await _pumpHost(tester);
      var opened = 0;
      service.warning(
        'Telemetry unavailable',
        action: AppNotificationAction('Settings', () => opened++),
      );
      await tester.pumpAndSettle();

      Future<bool> focusOn(Finder target) async {
        await tester.sendKeyEvent(LogicalKeyboardKey.f6);
        await tester.pump();
        for (var i = 0; i < 8; i++) {
          final current = FocusManager.instance.primaryFocus?.context;
          if (current != null &&
              find
                  .ancestor(of: find.byWidget(current.widget), matching: target)
                  .evaluate()
                  .isNotEmpty) {
            return true;
          }
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          final focused = FocusManager.instance.primaryFocus?.context;
          if (focused != null &&
              find
                  .ancestor(of: find.byWidget(focused.widget), matching: target)
                  .evaluate()
                  .isNotEmpty) {
            return true;
          }
        }
        return false;
      }

      expect(
        await focusOn(find.byKey(const Key('app-notification-action'))),
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(_cards, findsNothing);

      service.info('Motion simulation');
      await tester.pumpAndSettle();
      expect(
        await focusOn(find.byKey(const Key('app-notification-close'))),
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_cards, findsNothing);
      await _unmount(tester);
    });

    testWidgets('cards are announced as live regions with labeled controls', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final (_, service) = await _pumpHost(tester);
      service.success('Connected successfully', description: 'Link is up.');
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(_cards),
        isSemantics(
          isLiveRegion: true,
          label: 'Success. Connected successfully. Link is up.',
        ),
      );
      expect(find.byTooltip('Dismiss notification'), findsOneWidget);
      handle.dispose();
      await _unmount(tester);
    });

    testWidgets('critical safety stays until acknowledged', (tester) async {
      final (container, service) = await _pumpHost(tester);
      service.critical(
        'Robot motion state unknown',
        description: 'Motion commands are blocked until safety is verified.',
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 30));
      service.dismissAll();
      await tester.pumpAndSettle();
      expect(find.text('Robot motion state unknown'), findsOneWidget);
      expect(find.byKey(const Key('app-notification-close')), findsNothing);

      // Esc on a critical card acknowledges explicitly; it never times out.
      await tester.tap(find.byKey(const Key('app-notification-acknowledge')));
      await tester.pumpAndSettle();
      expect(_cards, findsNothing);
      expect(container.read(appNotificationsProvider).visible, isEmpty);
      await _unmount(tester);
    });

    testWidgets('reduced motion shows and hides cards without animation', (
      tester,
    ) async {
      final (_, service) = await _pumpHost(tester, disableAnimations: true);
      final key = service.info('Motion simulation');
      await tester.pump();
      expect(
        tester
            .widget<FadeTransition>(
              find
                  .ancestor(of: _cards, matching: find.byType(FadeTransition))
                  .first,
            )
            .opacity
            .value,
        1,
      );
      service.dismiss(key);
      await tester.pump();
      await tester.pump();
      expect(_cards, findsNothing);
      await _unmount(tester);
    });
  });

  group('app integration', () {
    Future<ProviderContainer> pumpApp(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [
          dashboardControllerProvider.overrideWith(
            () => RecordingDashboardController([]),
          ),
          robotServiceProvider.overrideWithValue(
            RobotService(FixtureApiClient()),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RobotControlApp(),
        ),
      );
      await tester.pumpAndSettle();
      tester.takeException(); // Pre-existing dashboard layout issues.
      return container;
    }

    testWidgets('one overlay survives navigation without leaking', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      final service = container.read(appNotificationsProvider.notifier);
      service.critical('Robot motion state unknown');
      for (final route in [
        AppRoutes.motion,
        AppRoutes.voiceStudio,
        AppRoutes.settings,
        AppRoutes.dashboard,
      ]) {
        container.read(appRouterProvider).go(route);
        await tester.pumpAndSettle();
        tester.takeException();
        expect(
          find.byKey(const Key('app-notification-overlay')),
          findsOneWidget,
        );
        expect(_cards, findsOneWidget, reason: route);
      }
      service.success('Saved');
      await tester.pumpAndSettle();
      expect(service.hasHost, isTrue);
      await _unmount(tester);
      expect(service.hasHost, isFalse, reason: 'host detached, timers gone');
    });

    testWidgets('robot link updates one card from Connecting to Connected', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      final link = container.read(robotLinkProvider.notifier);
      link.update(const RobotLinkState(RobotLinkStatus.connecting));
      await tester.pump(_exit);
      expect(find.text('Connecting to robot…'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsWidgets);

      link.update(const RobotLinkState(RobotLinkStatus.connected));
      await tester.pumpAndSettle();
      tester.takeException();
      expect(find.text('Connecting to robot…'), findsNothing);
      expect(find.text('Connected successfully'), findsOneWidget);
      expect(_cards, findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      tester.takeException();
      expect(_cards, findsNothing);
      await _unmount(tester);
    });

    testWidgets('Voice Studio uses the notification system, not SnackBars', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      container.read(appRouterProvider).go(AppRoutes.voiceStudio);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('tts-text')), 'Good morning');
      await tester.ensureVisible(find.byKey(const Key('tts-save-phrase')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tts-save-phrase')));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(AppNotificationCard, 'Phrase saved'),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
      await _unmount(tester);
    });
  });

  test('no default SnackBars remain in the app', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where(
          (file) => file.readAsStringSync().contains(
            RegExp(r'SnackBar\(|showSnackBar'),
          ),
        )
        .map((file) => file.path)
        .toList();
    expect(offenders, isEmpty);
  });
}
