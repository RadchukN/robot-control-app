import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robot_control_app/core/routing/app_routes.dart';
import 'package:robot_control_app/features/settings/application/audio_devices_controller.dart';
import 'package:robot_control_app/features/settings/data/audio_device_backend.dart';
import 'package:robot_control_app/features/voice_studio/application/realtime_voice_controller.dart';
import 'package:robot_control_app/features/voice_studio/application/voice_studio_providers.dart';
import 'package:robot_control_app/features/voice_studio/domain/voice_models.dart';
import 'package:robot_control_app/services/robot_connection.dart';

import '../landscape/landscape_harness.dart';
import 'live_voice_backend_test.dart' show FakeVoiceSocket;

void main() {
  setUpAll(loadRealFonts);

  for (final size in const [Size(1440, 960), Size(640, 360), Size(844, 390)]) {
    testWidgets(
      'live controls preserve $size layout and Stop through reconnect/error',
      (tester) async {
        setPhoneView(tester, size);
        final socket = FakeVoiceSocket();
        addTearDown(socket.incoming.close);
        late ProviderContainer container;
        final errors = await layoutErrors(() async {
          container = await pumpApp(
            tester,
            route: AppRoutes.voiceStudio,
            overrides: [
              voiceFrameTransportProvider.overrideWithValue(socket),
              audioDeviceBackendProvider.overrideWith((ref) {
                final mock = MockAudioDeviceBackend();
                ref.onDispose(mock.dispose);
                return mock;
              }),
            ],
          );
          // Demo never touches the voice transport, even when link state changes.
          container
              .read(robotLinkProvider.notifier)
              .update(const RobotLinkState(RobotLinkStatus.connected));
          await settle(tester);
          expect(socket.sent, isEmpty);
          container.read(voiceDemoModeProvider.notifier).set(false);
          await settle(tester);
          expect(container.read(realtimeVoiceProvider).canStart, isFalse);
          socket.capabilities();
          await tester.pump();
          expect(container.read(realtimeVoiceProvider).canStart, isFalse);
          socket.snapshot('idle', session: null);
          await settle(tester);
          expect(container.read(realtimeVoiceProvider).canStart, isTrue);
          await tester.tap(find.byKey(const Key('voice-start')));
          await settle(tester);
          socket.ack();
          await tester.pump();
          expect(
            container.read(realtimeVoiceProvider).session,
            VoiceSessionState.starting,
          );
          expect(container.read(realtimeVoiceProvider).canStop, isTrue);
          socket.status('listening');
          await settle(tester);
          expect(
            container.read(realtimeVoiceProvider).session,
            VoiceSessionState.listening,
          );
          expect(find.textContaining('private-one'), findsNothing);
          // A live session cannot be hidden by switching to Demo Mode.
          expect(
            tester
                .widget<Switch>(find.byKey(const Key('voice-demo-toggle')))
                .onChanged,
            isNull,
          );
          expect(container.read(voiceDemoModeProvider), isFalse);
          final landscape = size.height < 480;
          if (landscape) {
            await tester.tap(find.byKey(const Key('voice-section-speech')));
            await settle(tester);
            expectTappable(
              tester,
              find.byKey(const Key('voice-landscape-stop-ai')),
            );
          }
          container
              .read(robotLinkProvider.notifier)
              .update(const RobotLinkState(RobotLinkStatus.reconnecting));
          await tester.pump();
          expect(container.read(realtimeVoiceProvider).canStart, isFalse);
          expect(container.read(realtimeVoiceProvider).canStop, isTrue);
          final stop = find.byKey(
            Key(landscape ? 'voice-landscape-stop-ai' : 'voice-stop'),
          );
          await tester.ensureVisible(stop);
          await tester.tap(stop);
          await tester.pump();
          // Stop is queued as intent, not sent on a disconnected transport.
          expect(socket.sent.where((m) => m['type'] == 'voice_stop'), isEmpty);
          container
              .read(robotLinkProvider.notifier)
              .update(const RobotLinkState(RobotLinkStatus.awaitingTelemetry));
          await tester.pump();
          socket.capabilities();
          socket.snapshot('listening');
          await tester.pump();
          expect(socket.sent.where((m) => m['type'] == 'voice_stop').length, 1);
          socket.error('bluetooth_unavailable');
          socket.status('idle', reason: 'bluetooth_unavailable');
          await tester.pump();
          expect(
            container.read(realtimeVoiceProvider).lastError,
            contains('Bluetooth'),
          );
          expect(
            container.read(realtimeVoiceProvider).speaker,
            DeviceStatus.unavailable,
          );
          expect(
            socket.sent.where((m) => m['type'] == 'voice_start').length,
            1,
          );
          await tester.pumpWidget(const SizedBox.shrink());
        });
        expect(errors, isEmpty, reason: errors.join('\n'));
      },
    );
  }
}
