import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/features/dashboard/application/dashboard_controller.dart';
import 'package:robot_control_app/features/settings/application/settings_state.dart';
import 'package:robot_control_app/features/settings/data/audio_device_backend.dart';
import 'package:robot_control_app/features/settings/data/live_audio_device_backend.dart';
import 'package:robot_control_app/features/voice_studio/application/realtime_voice_controller.dart'
    show isRobotLinkOpen;
import 'package:robot_control_app/features/voice_studio/application/voice_studio_providers.dart';
import 'package:robot_control_app/features/voice_studio/domain/voice_models.dart';
import 'package:robot_control_app/services/robot_connection.dart';
import 'package:robot_control_app/shared/notifications/app_notification.dart';
import 'package:robot_control_app/shared/notifications/app_notification_service.dart';

/// The dashboard's authenticated robot socket, narrowed to `audio_*` frames.
class DashboardAudioTransport implements AudioFrameTransport {
  DashboardAudioTransport(this._dashboard);

  final DashboardController _dashboard;

  @override
  Stream<Map<String, dynamic>> get frames => _dashboard.audioFrames;

  @override
  void send(Map<String, Object?> frame) => _dashboard.sendAudioFrame(frame);
}

final audioFrameTransportProvider = Provider<AudioFrameTransport>(
  (ref) =>
      DashboardAudioTransport(ref.read(dashboardControllerProvider.notifier)),
  name: 'AudioFrameTransportProvider',
);

/// Demo Mode → simulated devices; otherwise one live backend per robot
/// connection (a reconnect builds a new one and never replays requests).
final audioDeviceBackendProvider = Provider<AudioDeviceBackend>((ref) {
  final AudioDeviceBackend backend;
  if (ref.watch(voiceDemoModeProvider)) {
    backend = MockAudioDeviceBackend();
  } else if (ref.watch(
    robotLinkProvider.select((link) => isRobotLinkOpen(link.status)),
  )) {
    backend = LiveAudioDeviceBackend(ref.read(audioFrameTransportProvider));
  } else {
    backend = const UnavailableAudioDeviceBackend();
  }
  ref.onDispose(backend.dispose);
  return backend;
}, name: 'AudioDeviceBackendProvider');

enum AudioTestState { idle, running, passed, failed, cancelled }

const _unset = Object();

@immutable
class AudioDevicesState {
  const AudioDevicesState({
    required this.simulated,
    this.loading = false,
    this.applying = false,
    this.unavailableReason,
    this.error,
    this.devices = const [],
    this.capabilities = AudioCapabilities.none,
    this.status,
    this.desiredInputId,
    this.desiredOutputId,
    this.inputTest = AudioTestState.idle,
    this.outputTest = AudioTestState.idle,
    this.inputTestMessage,
    this.outputTestMessage,
  });

  final bool simulated;
  final bool loading;

  /// A selection is pending on the robot.
  final bool applying;
  final String? unavailableReason;
  final String? error;
  final List<AudioDevice> devices;
  final AudioCapabilities capabilities;

  /// Latest backend status (saved selection, session, settings file).
  final AudioDeviceStatus? status;

  /// Local preference the user picked; may not be saved on the robot yet.
  final String? desiredInputId;
  final String? desiredOutputId;

  final AudioTestState inputTest;
  final AudioTestState outputTest;
  final String? inputTestMessage;
  final String? outputTestMessage;

  bool get available => unavailableReason == null;

  /// The robot's audio lock is held (voice session, playback or test). The
  /// backend's lock is authoritative.
  bool get backendBusy =>
      (status?.session.active ?? false) || (status?.testRunning ?? false);

  List<AudioDevice> devicesFor(AudioDeviceDirection direction) =>
      devices.where((d) => d.direction == direction).toList(growable: false);

  AudioSelection? savedSelection(AudioDeviceDirection d) =>
      status?.selection(d);

  /// Backend-confirmed saved selection; applies at the next voice runtime.
  String? savedId(AudioDeviceDirection d) => savedSelection(d)?.deviceId;

  /// Device a running session uses, only as reported by the backend.
  String? activeId(AudioDeviceDirection d) => status?.activeId(d);

  String? desiredId(AudioDeviceDirection d) =>
      d == AudioDeviceDirection.input ? desiredInputId : desiredOutputId;

  /// The device shown in the dropdown: the local choice, else the saved one.
  String? selectedId(AudioDeviceDirection d) => desiredId(d) ?? savedId(d);

  AudioDevice? device(AudioDeviceDirection direction, String? id) =>
      devices.where((d) => d.direction == direction && d.id == id).firstOrNull;

  AudioTestState test(AudioDeviceDirection d) =>
      d == AudioDeviceDirection.input ? inputTest : outputTest;

  String? testMessage(AudioDeviceDirection d) =>
      d == AudioDeviceDirection.input ? inputTestMessage : outputTestMessage;

  AudioDevicesState copyWith({
    bool? loading,
    bool? applying,
    Object? error = _unset,
    List<AudioDevice>? devices,
    AudioCapabilities? capabilities,
    Object? status = _unset,
    Object? desiredInputId = _unset,
    Object? desiredOutputId = _unset,
    AudioTestState? inputTest,
    AudioTestState? outputTest,
    Object? inputTestMessage = _unset,
    Object? outputTestMessage = _unset,
  }) {
    T? pick<T>(Object? value, T? current) =>
        identical(value, _unset) ? current : value as T?;
    return AudioDevicesState(
      simulated: simulated,
      unavailableReason: unavailableReason,
      loading: loading ?? this.loading,
      applying: applying ?? this.applying,
      error: pick(error, this.error),
      devices: devices ?? this.devices,
      capabilities: capabilities ?? this.capabilities,
      status: pick(status, this.status),
      desiredInputId: pick(desiredInputId, this.desiredInputId),
      desiredOutputId: pick(desiredOutputId, this.desiredOutputId),
      inputTest: inputTest ?? this.inputTest,
      outputTest: outputTest ?? this.outputTest,
      inputTestMessage: pick(inputTestMessage, this.inputTestMessage),
      outputTestMessage: pick(outputTestMessage, this.outputTestMessage),
    );
  }
}

/// Robot microphone and speaker selection over `medza.audio` v1.
///
/// A confirmed selection is *saved* and applies when the voice runtime next
/// starts; it is shown active only when the backend reports the running
/// session uses it. Changes are refused while Flutter or the robot reports
/// the audio in use, and nothing is ever changed without a user action.
class AudioDevicesController extends Notifier<AudioDevicesState> {
  static const requestTimeout = Duration(seconds: 8);

  /// Input tests run ≤5 s plus a 5 s robot timeout; output tests on the
  /// robot speaker may take up to its 30 s DDS child timeout.
  static Duration testTimeout(AudioDeviceDirection d, {int durationSec = 5}) =>
      d == AudioDeviceDirection.input
      ? Duration(seconds: durationSec + 10)
      : const Duration(seconds: 45);

  late AudioDeviceBackend _backend;
  final _testGeneration = {
    for (final direction in AudioDeviceDirection.values) direction: 0,
  };

  @override
  AudioDevicesState build() {
    _backend = ref.watch(audioDeviceBackendProvider);
    final backend = _backend;
    final subscription = backend.events.listen(_onEvent);
    ref.onDispose(() {
      subscription.cancel();
      for (final direction in AudioDeviceDirection.values) {
        backend.cancelTest(direction);
      }
    });
    final settings = ref.read(settingsProvider);
    final reason = backend.unavailableReason;
    // (Re)connect: capabilities, then devices and status. Never a replay.
    if (reason == null) Future.microtask(() => refresh(announce: false));
    return AudioDevicesState(
      simulated: backend.isSimulated,
      unavailableReason: reason,
      loading: reason == null,
      desiredInputId: settings.audioInputDeviceId,
      desiredOutputId: settings.audioOutputDeviceId,
    );
  }

  AppNotificationService get _notify =>
      ref.read(appNotificationsProvider.notifier);

  bool _current(AudioDeviceBackend backend) =>
      ref.mounted && identical(backend, _backend);

  String _suffix() => state.simulated ? ' (simulated)' : '';

  String _nameOf(AudioDeviceDirection d, String? id) =>
      state.device(d, id)?.name ??
      (state.savedId(d) == id ? state.savedSelection(d)?.label : null) ??
      id ??
      'device';

  /// Capabilities, devices and backend-confirmed settings. Only a manual
  /// refresh announces itself, so background updates never spam.
  Future<void> refresh({bool announce = true}) async {
    if (!state.available) {
      if (announce) {
        _notify.warning(
          'Audio device unavailable',
          description: state.unavailableReason,
          key: 'audio-devices',
        );
      }
      return;
    }
    final backend = _backend;
    state = state.copyWith(loading: true, error: null);
    try {
      final capabilities = await backend.getCapabilities();
      if (!capabilities.discovery) {
        throw const AudioDeviceException(
          'unsupported',
          'The robot does not support audio device discovery.',
        );
      }
      final devices = await backend.getDevices().timeout(requestTimeout);
      final status = await backend.getStatus().timeout(requestTimeout);
      if (!_current(backend)) return;
      state = state.copyWith(
        loading: false,
        devices: devices,
        capabilities: capabilities,
        status: status,
      );
      if (announce) {
        _notify.success(
          'Audio devices refreshed',
          description:
              '${devices.length} device${devices.length == 1 ? '' : 's'} '
              'found${_suffix()}.',
          key: 'audio-devices',
        );
      }
    } on Object catch (error) {
      if (!_current(backend)) return;
      final message = _describe(error);
      state = state.copyWith(loading: false, error: message);
      if (announce) {
        _notify.error(
          'Audio devices not refreshed',
          description: message,
          key: 'audio-devices',
        );
      }
    }
  }

  Future<void> _refreshDevices(AudioDeviceBackend backend) async {
    try {
      final devices = await backend.getDevices().timeout(requestTimeout);
      if (_current(backend)) state = state.copyWith(devices: devices);
    } on Object {
      // The next push or manual refresh recovers; never retried in a loop.
    }
  }

  void _onEvent(AudioBackendEvent event) {
    if (!ref.mounted) return;
    switch (event) {
      case AudioStatusPushed(:final status):
        state = state.copyWith(status: status);
        if (status.devicesChanged) unawaited(_refreshDevices(_backend));
      case AudioErrorPushed(
        :final code,
        :final fatal,
        :final deviceId,
        :final direction,
      ):
        final label = direction == null
            ? deviceId
            : _nameOf(direction, deviceId);
        switch (code) {
          case 'selected_device_disconnected':
            _notify.warning(
              'Audio device disconnected',
              description:
                  '${label ?? 'The selected device'} was unplugged. The robot '
                  'does not switch to another device.',
              key: 'audio-device-disconnected-${direction?.name}',
            );
          case 'input_device_lost':
            _notify.warning(
              'Microphone lost',
              description:
                  'The voice session receives no microphone audio. It keeps '
                  'retrying.',
              key: 'audio-input-lost',
            );
          case 'session_stopped_input_lost':
            _notify.error(
              'Voice session stopped',
              description:
                  'The microphone stayed lost, so the robot stopped the '
                  'session. It does not restart on its own.',
              key: 'audio-input-lost',
            );
          case 'settings_file_invalid':
            _notify.error(
              'Audio configuration failure',
              description:
                  'The saved audio settings are invalid; the robot will use '
                  'its .env defaults. Select the devices again to re-save.',
              key: 'audio-settings-file',
            );
          default:
            if (fatal) {
              _notify.error(
                'Audio configuration failure',
                description: code,
                key: 'audio-error-$code',
              );
            }
        }
    }
  }

  /// Flutter's own voice/TTS session, or the robot's authoritative lock.
  bool _busy() {
    final owner = state.status?.session.owner;
    final busy =
        ref.read(audioSessionProvider) != AudioOwner.none || state.backendBusy;
    if (!busy) return false;
    _notify.warning(
      'Voice session is active',
      description: owner == null
          ? 'Stop the AI conversation or speech before changing audio devices.'
          : 'The robot audio is in use by $owner. Try again when it is free.',
      key: 'audio-devices',
    );
    return true;
  }

  Future<void> select(AudioDeviceDirection direction, String deviceId) async {
    if (!state.available || state.applying || state.loading) return;
    if (deviceId == state.selectedId(direction) &&
        deviceId == state.savedId(direction)) {
      return;
    }
    if (!state.capabilities.settings) {
      _notify.warning(
        'Audio device unavailable',
        description: 'The robot does not support saving audio devices.',
        key: 'audio-devices-${direction.name}',
      );
      return;
    }
    if (_busy()) return;
    final input = direction == AudioDeviceDirection.input;
    final settings = ref.read(settingsProvider.notifier);
    if (input) {
      settings.setAudioInputDevice(deviceId);
      state = state.copyWith(desiredInputId: deviceId, applying: true);
    } else {
      settings.setAudioOutputDevice(deviceId);
      state = state.copyWith(desiredOutputId: deviceId, applying: true);
    }
    final backend = _backend;
    try {
      // Only the changed direction; the other keeps its saved selection.
      await backend
          .applySettings(
            input
                ? AudioDeviceSettings(inputId: deviceId)
                : AudioDeviceSettings(outputId: deviceId),
          )
          .timeout(requestTimeout);
      if (!_current(backend)) return;
      // Saved, not active. The pushed audio_settings carries the new state.
      state = state.copyWith(applying: false);
      if (state.savedId(direction) != deviceId) {
        unawaited(_refreshStatus(backend));
      }
      final running = state.status?.voiceRuntimeRunning ?? false;
      _notify.success(
        input ? 'Microphone selected' : 'Speaker selected',
        description:
            '${_nameOf(direction, deviceId)}${_suffix()}. Settings applied: '
            'used when the voice runtime next starts'
            '${running ? '; the running runtime keeps its devices until it restarts' : ''}.',
        key: 'audio-devices-${direction.name}',
      );
    } on Object catch (error) {
      if (!_current(backend)) return;
      state = state.copyWith(applying: false);
      final busy = error is AudioDeviceException && error.busy;
      final code = error is AudioDeviceException ? error.code : 'error';
      _notify.show(
        busy || code == 'device_unavailable' || code == 'wrong_direction'
            ? AppNotificationType.warning
            : AppNotificationType.error,
        busy
            ? 'Robot audio is busy'
            : switch (code) {
                'device_unavailable' ||
                'invalid_device_id' ||
                'wrong_direction' => 'Audio device unavailable',
                'timeout' => 'Robot did not respond',
                'disconnected' => 'Robot is not connected',
                _ => 'Audio configuration failure',
              },
        description: _describe(error),
        key: 'audio-devices-${direction.name}',
      );
    }
  }

  Future<void> _refreshStatus(AudioDeviceBackend backend) async {
    try {
      final status = await backend.getStatus().timeout(requestTimeout);
      if (_current(backend)) state = state.copyWith(status: status);
    } on Object {
      // A later push or refresh recovers.
    }
  }

  /// Starts a test (the UI confirms first in live mode) or, while running,
  /// cancels it where supported, otherwise only stops waiting.
  Future<void> toggleTest(AudioDeviceDirection direction) async {
    final input = direction == AudioDeviceDirection.input;
    final label = input ? 'Microphone test' : 'Speaker test';
    if (state.test(direction) == AudioTestState.running) {
      if (state.capabilities.cancellableTests) {
        _backend.cancelTest(direction);
      } else {
        _testGeneration[direction] = _testGeneration[direction]! + 1;
        _setTest(
          direction,
          AudioTestState.cancelled,
          'Stopped waiting. The robot may still finish the test.',
        );
        _notify.info(
          '$label may still be running',
          description: 'Audio tests cannot be cancelled on the robot.',
          key: 'audio-test-${direction.name}',
        );
      }
      return;
    }
    if (!state.available || !state.capabilities.testFor(direction)) return;
    if (_busy()) return;
    final deviceId = state.selectedId(direction);
    final device = state.device(direction, deviceId);
    if (deviceId == null || device == null || !device.selectable) {
      _notify.warning(
        'Audio device unavailable',
        description: 'Select a connected device before testing.',
        key: 'audio-test-${direction.name}',
      );
      return;
    }
    final seconds = state.capabilities.inputTestDefaultSec;
    _setTest(direction, AudioTestState.running, 'Testing ${device.name}…');
    final backend = _backend;
    final generation = _testGeneration[direction]!;
    bool stale() =>
        !_current(backend) || generation != _testGeneration[direction];
    try {
      final result =
          await (input
                  ? backend.testInput(deviceId, durationSec: seconds)
                  : backend.testOutput(deviceId))
              .timeout(
                testTimeout(direction, durationSec: seconds),
                onTimeout: () => throw const AudioDeviceException(
                  'timeout',
                  'No result in time. The robot may still be running the '
                      'test.',
                ),
              );
      if (stale()) return;
      switch (result.outcome) {
        case AudioTestOutcome.passed:
          final message = result.message ?? _describeResult(direction, result);
          _setTest(direction, AudioTestState.passed, message);
          _notify.success(
            input ? 'Microphone test finished' : 'Speaker test finished',
            description: message,
            key: 'audio-test-${direction.name}',
          );
        case AudioTestOutcome.failed:
          _setTest(direction, AudioTestState.failed, result.message);
          _notify.error(
            '$label failed',
            description: result.message,
            key: 'audio-test-${direction.name}',
          );
        case AudioTestOutcome.cancelled:
          _setTest(direction, AudioTestState.cancelled, 'Test cancelled.');
          _notify.info('$label cancelled', key: 'audio-test-${direction.name}');
      }
    } on Object catch (error) {
      if (stale()) return;
      _setTest(direction, AudioTestState.failed, _describe(error));
      _notify.error(
        '$label failed',
        description: _describe(error),
        key: 'audio-test-${direction.name}',
      );
    }
  }

  /// Robot-measured values only; nothing is invented.
  static String _describeResult(AudioDeviceDirection d, AudioTestResult r) {
    if (d == AudioDeviceDirection.output) {
      return 'Test tone played'
          '${r.durationSec == null ? '' : ' (${r.durationSec} s)'}'
          ' at the robot\'s current volume.';
    }
    final parts = [
      if (r.signal != null) 'Signal ${r.signal}',
      if (r.rms != null) 'RMS ${r.rms}',
      if (r.peakDbfs != null) 'peak ${r.peakDbfs} dBFS',
      if (r.clipping == true) 'clipping',
    ];
    return parts.isEmpty ? 'Test finished.' : '${parts.join(' · ')}.';
  }

  void _setTest(AudioDeviceDirection d, AudioTestState test, String? message) =>
      state = d == AudioDeviceDirection.input
      ? state.copyWith(inputTest: test, inputTestMessage: message)
      : state.copyWith(outputTest: test, outputTestMessage: message);

  static String _describe(Object error) => switch (error) {
    AudioDeviceException(:final message) => message,
    TimeoutException() => 'The robot did not respond in time.',
    _ => '$error',
  };
}

final audioDevicesProvider =
    NotifierProvider<AudioDevicesController, AudioDevicesState>(
      AudioDevicesController.new,
      name: 'AudioDevicesProvider',
    );
