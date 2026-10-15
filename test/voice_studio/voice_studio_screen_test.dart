import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/app.dart';
import 'package:robot_control_app/core/routing/app_router.dart';
import 'package:robot_control_app/core/routing/app_routes.dart';
import 'package:robot_control_app/features/dashboard/application/dashboard_controller.dart';
import 'package:robot_control_app/features/voice_studio/application/realtime_voice_controller.dart';
import 'package:robot_control_app/features/voice_studio/application/tts_controller.dart';
import 'package:robot_control_app/features/voice_studio/application/voice_studio_providers.dart';
import 'package:robot_control_app/features/voice_studio/domain/voice_models.dart';
import 'package:robot_control_app/features/voice_studio/presentation/voice_studio_screen.dart';
import 'package:robot_control_app/services/robot_service.dart';

import '../fixture_api_client.dart';
import 'voice_test_helpers.dart';

const _sections = [
  'Realtime Speaking',
  'Conversation Transcript',
  'Speak Custom Text',
  'Quick Motions',
  'Connection & Voice State',
];

ProviderContainer _container(List<String> motionCalls) => ProviderContainer(
  overrides: [
    dashboardControllerProvider.overrideWith(
      () => RecordingDashboardController(motionCalls),
    ),
    robotServiceProvider.overrideWithValue(RobotService(FixtureApiClient())),
  ],
);

Future<ProviderContainer> _pumpStudio(
  WidgetTester tester, {
  Size size = const Size(1440, 960),
  List<String>? motionCalls,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = _container(motionCalls ?? []);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: VoiceStudioScreen())),
    ),
  );
  await tester.pump();
  await tester.pump();
  return container;
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  testWidgets('all five sections fit every viewport without overflow', (
    tester,
  ) async {
    for (final size in const [
      Size(360, 780),
      Size(390, 844),
      Size(768, 1024),
      Size(1024, 768),
      Size(1280, 800),
      Size(1440, 960),
      Size(1792, 920),
    ]) {
      final container = await _pumpStudio(tester, size: size);
      for (final section in _sections) {
        expect(find.text(section), findsOneWidget, reason: '$section @ $size');
      }
      // Fill the transcript and waveform, then re-check layout.
      await container.read(realtimeVoiceProvider.notifier).start();
      await tester.pump(const Duration(seconds: 12));
      expect(tester.takeException(), isNull, reason: 'Viewport: $size');
      await container.read(realtimeVoiceProvider.notifier).stop();
      await tester.pump(const Duration(milliseconds: 200));
      await _unmount(tester);
      container.dispose();
    }
  });

  testWidgets('demo conversation is labeled and controllable', (tester) async {
    final container = await _pumpStudio(tester);
    expect(find.byKey(const Key('voice-demo-badge')), findsWidgets);
    final sessionTile = find.byKey(const Key('voice-session-tile'));
    expect(
      find.descendant(of: sessionTile, matching: find.text('Idle')),
      findsOneWidget,
    );
    expect(
      find.text('No messages yet. Start an AI conversation.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('voice-start')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(
      find.descendant(of: sessionTile, matching: find.text('Listening')),
      findsOneWidget,
    );
    // Simulated devices read "Demo", never "Ready".
    expect(
      find.descendant(
        of: find.byKey(const Key('voice-mic')),
        matching: find.text('Demo'),
      ),
      findsOneWidget,
    );
    expect(find.text('Ready'), findsNothing);

    await tester.pump(const Duration(seconds: 12));
    expect(find.text('Hello! Can you introduce yourself?'), findsOneWidget);
    expect(find.text('simulated'), findsWidgets);

    await tester.tap(find.byKey(const Key('voice-stop')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(
      container.read(realtimeVoiceProvider).session,
      VoiceSessionState.idle,
    );

    await tester.tap(find.byKey(const Key('transcript-clear')));
    await tester.pump();
    expect(container.read(realtimeVoiceProvider).transcript, isEmpty);
    await _unmount(tester);
  });

  testWidgets('custom text counts, speaks in simulation and can stop', (
    tester,
  ) async {
    final container = await _pumpStudio(tester);
    await tester.enterText(find.byKey(const Key('tts-text')), 'Hello');
    await tester.pump();
    expect(find.text('5/500'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tts-speak')));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('tts-status'))).data,
      contains('robot is not speaking'),
    );
    expect(find.byKey(const Key('tts-stop')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tts-stop')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(container.read(ttsProvider).phase, TtsPhase.idle);
    expect(find.byKey(const Key('tts-speak')), findsOneWidget);
    expect(container.read(audioSessionProvider), AudioOwner.none);
    await _unmount(tester);
  });

  testWidgets('saved phrases load, save and delete locally', (tester) async {
    final container = await _pumpStudio(tester);
    await tester.tap(find.text('Welcome to PilsLab'));
    await tester.pump();
    expect(find.text('18/500'), findsOneWidget);
    expect(container.read(ttsProvider).draft, 'Welcome to PilsLab');

    await tester.enterText(find.byKey(const Key('tts-text')), 'Good morning');
    await tester.tap(find.byKey(const Key('tts-save-phrase')));
    await tester.pump();
    expect(
      container.read(savedPhrasesProvider).map((phrase) => phrase.text),
      contains('Good morning'),
    );

    final first = container.read(savedPhrasesProvider).first;
    await tester.tap(find.byKey(Key('phrase-menu-${first.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(
      container.read(savedPhrasesProvider).map((phrase) => phrase.id),
      isNot(contains(first.id)),
    );
    await _unmount(tester);
  });

  testWidgets('Demo Mode disables motion starts but keeps Stop', (
    tester,
  ) async {
    final motionCalls = <String>[];
    final container = await _pumpStudio(tester, motionCalls: motionCalls);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('quick-note')), findsOneWidget);
    expect(find.text('67.json'), findsOneWidget);

    await tester.tap(find.byKey(const Key('quick-wave')));
    await tester.tap(find.byTooltip('Play 67.json'));
    await tester.pump();
    expect(motionCalls, isEmpty);

    await tester.tap(find.byKey(const Key('quick-stop')));
    await tester.pump();
    expect(motionCalls, ['stop_motion']);

    container.read(voiceDemoModeProvider.notifier).set(false);
    await tester.pump();
    expect(find.byKey(const Key('quick-note')), findsNothing);
    await _unmount(tester);
  });

  testWidgets('outside Demo Mode Quick Motions use the motion controller', (
    tester,
  ) async {
    final motionCalls = <String>[];
    final container = await _pumpStudio(tester, motionCalls: motionCalls);
    container.read(voiceDemoModeProvider.notifier).set(false);
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const Key('quick-wave')));
    await tester.pump();
    expect(motionCalls, ['wave_hand']);
    // Live voice is unavailable, so Start stays disabled.
    expect(container.read(realtimeVoiceProvider).canStart, isFalse);
    await _unmount(tester);
  });

  testWidgets('AI Voice Studio is a separate navigation page from Motion', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = _container([]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const RobotControlApp(),
      ),
    );
    await tester.pumpAndSettle();
    // The dashboard's own layout is covered elsewhere.
    tester.takeException();

    expect(find.text('AI Voice Studio'), findsOneWidget);
    await tester.tap(find.text('AI Voice Studio'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('voice-studio-screen')), findsOneWidget);
    expect(find.byKey(const Key('motion-screen')), findsNothing);

    await tester.tap(find.text('Motion').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('motion-screen')), findsOneWidget);
    expect(find.text('Quick gestures'), findsOneWidget);
    expect(find.text('Record new motion'), findsWidgets);

    container.read(appRouterProvider).go(AppRoutes.voiceStudio);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('voice-studio-screen')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });
}
