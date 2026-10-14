import 'dart:async';

import 'package:robot_control_app/features/dashboard/application/dashboard_controller.dart';
import 'package:robot_control_app/features/voice_studio/data/voice_backend.dart';
import 'package:robot_control_app/features/voice_studio/domain/voice_models.dart';
import 'package:robot_control_app/models/dashboard_data.dart';

/// Deterministic backend whose events are pushed by the test.
class ScriptedVoiceBackend implements VoiceBackend {
  ScriptedVoiceBackend({
    this.isSimulated = false,
    this.capabilities = const VoiceCapabilities(
      languages: {'en-US', 'cs-CZ'},
      voices: {
        'en-US': ['Live A'],
        'cs-CZ': ['Live B'],
      },
      speeds: [1.0, 1.25],
    ),
    this.unavailableReason,
  });

  final _events = StreamController<VoiceBackendEvent>.broadcast(sync: true);
  final calls = <String>[];
  final requests = <TtsRequest>[];

  @override
  final bool isSimulated;

  @override
  final VoiceCapabilities? capabilities;

  @override
  final String? unavailableReason;

  @override
  Stream<VoiceBackendEvent> get events => _events.stream;

  void emit(VoiceBackendEvent event) => _events.add(event);

  @override
  Future<void> startConversation() async => calls.add('start');

  @override
  Future<void> stopConversation() async => calls.add('stop');

  @override
  Future<void> speak(TtsRequest request) async {
    calls.add('speak');
    requests.add(request);
  }

  @override
  Future<void> stopSpeaking(String requestId) async =>
      calls.add('stopSpeaking:$requestId');

  @override
  void dispose() => _events.close();
}

/// Offline dashboard: never connects, records every motion command attempt.
class RecordingDashboardController extends DashboardController {
  RecordingDashboardController(this.motionCalls);

  final List<String> motionCalls;

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
  }) {
    motionCalls.add(motion == null ? action : '$action:$motion');
    return Completer<Map<String, dynamic>>().future;
  }
}
