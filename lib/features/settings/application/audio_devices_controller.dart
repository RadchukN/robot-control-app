import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/features/settings/application/settings_state.dart';
import 'package:robot_control_app/features/settings/data/audio_device_backend.dart';
import 'package:robot_control_app/features/voice_studio/application/realtime_voice_controller.dart'
    show isRobotLinkOpen;
import 'package:robot_control_app/features/voice_studio/application/voice_studio_providers.dart';
import 'package:robot_control_app/features/voice_studio/domain/voice_models.dart';
import 'package:robot_control_app/services/robot_connection.dart';
import 'package:robot_control_app/shared/notifications/app_notification.dart';
import 'package:robot_control_app/shared/notifications/app_notification_service.dart';

/// Shares the app's existing Demo Mode: simulated devices in Demo Mode, the
/// unavailable live adapter otherwise. Neither sends anything to the robot.
final audioDeviceBackendProvider = Provider<AudioDeviceBackend>((ref) {
  final backend = ref.watch(voiceDemoModeProvider)
      ? MockAudioDeviceBackend()
      : const UnavailableAudioDeviceBackend();
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
    this.activeInputId,
    this.activeOutputId,
    this.desiredInputId,
    this.desiredOutputId,
    this.inputTest = AudioTestState.idle,
    this.outputTest = AudioTestState.idle,
    this.inputTestMessage,
    this.outputTestMessage,
  });

  final bool simulated;
  final bool loading;
  final bool applying;
  final String? unavailableReason;
  final String? error;
  final List<AudioDevice> devices;

  /// Confirmed by the backend.
  final String? activeInputId;
  final String? activeOutputId;

  /// Saved preference; may differ from what is active.
  final String? desiredInputId;
  final String? desiredOutputId;

  final AudioTestState inputTest;
  final AudioTestState outputTest;
  final String? inputTestMessage;
  final String? outputTestMessage;

  bool get available => unavailableReason == null;

  List<AudioDevice> devicesFor(AudioDeviceDirection direction) =>
      devices.where((d) => d.direction == direction).toList(growable: false);

  String? activeId(AudioDeviceDirection d) =>
      d == AudioDeviceDirection.input ? activeInputId : activeOutputId;

  String? desiredId(AudioDeviceDirection d) =>
      d == AudioDeviceDirection.input ? desiredInputId : desiredOutputId;

  /// The device shown in the dropdown: the saved choice, else the active one.
  String? selectedId(AudioDeviceDirection d) => desiredId(d) ?? activeId(d);

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
    Object? activeInputId = _unset,
    Object? activeOutputId = _unset,
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
      activeInputId: pick(activeInputId, this.activeInputId),
      activeOutputId: pick(activeOutputId, this.activeOutputId),
      desiredInputId: pick(desiredInputId, this.desiredInputId),
      desiredOutputId: pick(desiredOutputId, this.desiredOutputId),
      inputTest: inputTest ?? this.inputTest,
      outputTest: outputTest ?? this.outputTest,
      inputTestMessage: pick(inputTestMessage, this.inputTestMessage),
      outputTestMessage: pick(outputTestMessage, this.outputTestMessage),
    );
  }
}

/// Robot microphone and speaker selection. Changes are refused while a
/// realtime conversation or TTS owns the audio session, and a device is only
/// reported active once the backend confirms it.
class AudioDevicesController extends Notifier<AudioDevicesState> {
  static const requestTimeout = Duration(seconds: 8);
  static const testTimeout = Duration(seconds: 10);

  late AudioDeviceBackend _backend;

  @override
  AudioDevicesState build() {
    _backend = ref.watch(audioDeviceBackendProvider);
    final linked = ref.watch(
      robotLinkProvider.select((link) => isRobotLinkOpen(link.status)),
    );
    final backend = _backend;
    ref.onDispose(() {
      for (final direction in AudioDeviceDirection.values) {
        backend.cancelTest(direction);
      }
    });
    final settings = ref.read(settingsProvider);
    final reason =
        backend.unavailableReason ??
        (!backend.isSimulated && !linked ? 'Robot is not connected.' : null);
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

  /// Loads devices and the active configuration. Only a manual refresh
  /// announces itself, so background discovery never spams notifications.
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
      final devices = await backend.getDevices().timeout(requestTimeout);
      final settings = await backend.getSettings().timeout(requestTimeout);
      if (!_current(backend)) return;
      state = state.copyWith(
        loading: false,
        devices: devices,
        activeInputId: settings.inputId,
        activeOutputId: settings.outputId,
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

  bool _sessionBusy() {
    if (ref.read(audioSessionProvider) == AudioOwner.none) return false;
    _notify.warning(
      'Voice session is active',
      description:
          'Stop the AI conversation or speech before changing audio devices.',
      key: 'audio-devices',
    );
    return true;
  }

  Future<void> select(AudioDeviceDirection direction, String deviceId) async {
    if (!state.available || state.applying) return;
    if (deviceId == state.selectedId(direction) &&
        deviceId == state.activeId(direction)) {
      return;
    }
    if (_sessionBusy()) return;
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
      final confirmed = await backend
          .applySettings(
            input
                ? AudioDeviceSettings(inputId: deviceId)
                : AudioDeviceSettings(outputId: deviceId),
          )
          .timeout(requestTimeout);
      if (!_current(backend)) return;
      state = state.copyWith(
        applying: false,
        activeInputId: confirmed.inputId,
        activeOutputId: confirmed.outputId,
      );
      final name = state.device(direction, deviceId)?.name ?? deviceId;
      _notify.success(
        input ? 'Microphone selected' : 'Speaker settings applied',
        description: '$name${_suffix()}',
        key: 'audio-devices-${direction.name}',
      );
    } on Object catch (error) {
      if (!_current(backend)) return;
      state = state.copyWith(applying: false);
      final code = error is AudioDeviceException ? error.code : 'error';
      _notify.show(
        code == 'rejected' || code == 'error' || code == 'timeout'
            ? AppNotificationType.error
            : AppNotificationType.warning,
        switch (code) {
          'busy' => 'Voice session is active',
          'rejected' => 'Configuration rejected',
          'timeout' => 'Robot did not respond',
          _ => 'Audio device unavailable',
        },
        description: _describe(error),
        key: 'audio-devices-${direction.name}',
      );
    }
  }

  Future<void> toggleTest(AudioDeviceDirection direction) async {
    if (state.test(direction) == AudioTestState.running) {
      _backend.cancelTest(direction);
      return;
    }
    if (!state.available || _sessionBusy()) return;
    final deviceId = state.selectedId(direction);
    final device = state.device(direction, deviceId);
    final input = direction == AudioDeviceDirection.input;
    final label = input ? 'Microphone test' : 'Speaker test';
    if (deviceId == null || device == null || !device.connected) {
      _notify.warning(
        'Audio device unavailable',
        description: 'Select a connected device before testing.',
        key: 'audio-test-${direction.name}',
      );
      return;
    }
    _setTest(direction, AudioTestState.running, 'Testing ${device.name}…');
    final backend = _backend;
    try {
      final result =
          await (input
                  ? backend.testInput(deviceId)
                  : backend.testOutput(deviceId))
              .timeout(
                testTimeout,
                onTimeout: () {
                  backend.cancelTest(direction);
                  throw const AudioDeviceException(
                    'timeout',
                    'The test did not finish in time.',
                  );
                },
              );
      if (!_current(backend)) return;
      switch (result.outcome) {
        case AudioTestOutcome.passed:
          _setTest(direction, AudioTestState.passed, result.message);
          _notify.success(
            input ? 'Microphone test passed' : 'Speaker test finished',
            description: result.message,
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
      if (!_current(backend)) return;
      _setTest(direction, AudioTestState.failed, _describe(error));
      _notify.error(
        '$label failed',
        description: _describe(error),
        key: 'audio-test-${direction.name}',
      );
    }
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
