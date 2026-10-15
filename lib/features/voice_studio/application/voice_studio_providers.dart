import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/features/voice_studio/data/mock_voice_backend.dart';
import 'package:robot_control_app/features/voice_studio/data/voice_backend.dart';
import 'package:robot_control_app/features/voice_studio/domain/voice_models.dart';
import 'package:robot_control_app/services/robot_connection.dart';

final voiceClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
  name: 'VoiceClockProvider',
);

/// Demo Mode is on by default because the Jetson voice backend is not
/// finalized. It only affects voice and TTS; it never opens a connection.
class VoiceDemoMode extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool enabled) {
    if (state == enabled) return;
    state = enabled;
    ref
        .read(voiceEventLogProvider.notifier)
        .add(
          enabled
              ? 'Demo Mode on: voice and TTS are simulated.'
              : 'Demo Mode off: robot voice backend unavailable.',
          level: enabled ? VoiceLogLevel.info : VoiceLogLevel.warning,
        );
  }
}

final voiceDemoModeProvider = NotifierProvider<VoiceDemoMode, bool>(
  VoiceDemoMode.new,
  name: 'VoiceDemoModeProvider',
);

/// Switching mode disposes the previous backend, which ends any session.
final voiceBackendProvider = Provider<VoiceBackend>((ref) {
  final backend = ref.watch(voiceDemoModeProvider)
      ? MockVoiceBackend(now: ref.read(voiceClockProvider))
      : UnavailableVoiceBackend();
  ref.onDispose(backend.dispose);
  return backend;
}, name: 'VoiceBackendProvider');

/// Realtime voice and TTS share the robot speaker exclusively.
class AudioSessionCoordinator extends Notifier<AudioOwner> {
  @override
  AudioOwner build() {
    ref.watch(voiceBackendProvider);
    return AudioOwner.none;
  }

  bool acquire(AudioOwner owner) {
    if (state != AudioOwner.none && state != owner) return false;
    state = owner;
    return true;
  }

  void release(AudioOwner owner) {
    if (state == owner) state = AudioOwner.none;
  }
}

final audioSessionProvider =
    NotifierProvider<AudioSessionCoordinator, AudioOwner>(
      AudioSessionCoordinator.new,
      name: 'AudioSessionProvider',
    );

@immutable
class VoiceEventLogState {
  const VoiceEventLogState({this.entries = const [], this.autoScroll = true});

  final List<VoiceLogEntry> entries;
  final bool autoScroll;
}

class VoiceEventLog extends Notifier<VoiceEventLogState> {
  static const maxEntries = 100;

  @override
  VoiceEventLogState build() {
    ref.listen(robotLinkProvider.select((link) => link.status), (
      previous,
      next,
    ) {
      if (previous != next) {
        add(
          'WebSocket: ${next.name}',
          level: switch (next) {
            RobotLinkStatus.connected => VoiceLogLevel.info,
            RobotLinkStatus.authenticationRequired ||
            RobotLinkStatus.disconnected => VoiceLogLevel.error,
            _ => VoiceLogLevel.warning,
          },
        );
      }
    });
    return const VoiceEventLogState();
  }

  void add(
    String message, {
    VoiceLogLevel level = VoiceLogLevel.info,
    bool simulated = false,
  }) {
    final entries = [
      ...state.entries,
      VoiceLogEntry(
        ref.read(voiceClockProvider)(),
        message,
        level: level,
        simulated: simulated,
      ),
    ];
    state = VoiceEventLogState(
      entries: entries.length > maxEntries
          ? entries.sublist(entries.length - maxEntries)
          : entries,
      autoScroll: state.autoScroll,
    );
  }

  void setAutoScroll(bool value) =>
      state = VoiceEventLogState(entries: state.entries, autoScroll: value);

  void clear() => state = VoiceEventLogState(autoScroll: state.autoScroll);
}

final voiceEventLogProvider =
    NotifierProvider<VoiceEventLog, VoiceEventLogState>(
      VoiceEventLog.new,
      name: 'VoiceEventLogProvider',
    );
