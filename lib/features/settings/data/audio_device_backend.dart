import 'dart:async';

import 'package:flutter/foundation.dart';

enum AudioDeviceDirection { input, output }

/// Display category reported by the backend; never derived from the id.
enum AudioDeviceKind { robotBuiltIn, systemDefault, usb, other }

@immutable
class AudioDevice {
  const AudioDevice({
    required this.id,
    required this.name,
    required this.direction,
    required this.kind,
    this.connected = true,
    this.simulated = false,
  });

  /// Opaque, server-generated stable id (for example `robot:mic` or
  /// `usb:<vid>:<pid>:<port-path>`). Flutter never parses or rewrites it.
  final String id;
  final String name;
  final AudioDeviceDirection direction;
  final AudioDeviceKind kind;

  /// False when the backend still knows the device but it is unplugged.
  final bool connected;
  final bool simulated;
}

@immutable
class AudioDeviceSettings {
  const AudioDeviceSettings({this.inputId, this.outputId});

  final String? inputId;
  final String? outputId;
}

enum AudioTestOutcome { passed, failed, cancelled }

@immutable
class AudioTestResult {
  const AudioTestResult(this.outcome, {this.message, this.level});

  final AudioTestOutcome outcome;
  final String? message;

  /// Peak input level 0..1 for microphone tests, when measured.
  final double? level;
}

/// Thrown for a rejected request; [code] matches the backend's reason.
class AudioDeviceException implements Exception {
  const AudioDeviceException(this.code, this.message);

  /// e.g. `unavailable`, `rejected`, `busy`, `not_found`, `timeout`.
  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Audio device management on the robot. Implementations open no robot
/// connection of their own; a live adapter must use the dashboard's
/// authenticated WebSocket.
abstract interface class AudioDeviceBackend {
  bool get isSimulated;

  /// Why device management is unavailable, or null when usable.
  String? get unavailableReason;

  Future<List<AudioDevice>> getDevices();
  Future<AudioDeviceSettings> getSettings();

  /// Returns the settings the backend actually confirmed.
  Future<AudioDeviceSettings> applySettings(AudioDeviceSettings desired);

  /// A bounded test that completes on its own or via [cancelTest].
  Future<AudioTestResult> testInput(String deviceId);
  Future<AudioTestResult> testOutput(String deviceId);
  void cancelTest(AudioDeviceDirection direction);
  void dispose();
}

/// Live placeholder. Until the Jetson device API contract exists, nothing
/// is ever sent and every request fails with [unavailableReason].
class UnavailableAudioDeviceBackend implements AudioDeviceBackend {
  const UnavailableAudioDeviceBackend([
    this.unavailableReason =
        'Audio device management is not available on the robot yet.',
  ]);

  @override
  final String unavailableReason;

  @override
  bool get isSimulated => false;

  Future<Never> _unavailable() =>
      Future.error(AudioDeviceException('unavailable', unavailableReason));

  @override
  Future<List<AudioDevice>> getDevices() => _unavailable();

  @override
  Future<AudioDeviceSettings> getSettings() => _unavailable();

  @override
  Future<AudioDeviceSettings> applySettings(AudioDeviceSettings desired) =>
      _unavailable();

  @override
  Future<AudioTestResult> testInput(String deviceId) => _unavailable();

  @override
  Future<AudioTestResult> testOutput(String deviceId) => _unavailable();

  @override
  void cancelTest(AudioDeviceDirection direction) {}

  @override
  void dispose() {}
}

/// Demo Mode backend: simulated devices, no recording, no playback, no I/O.
class MockAudioDeviceBackend implements AudioDeviceBackend {
  MockAudioDeviceBackend({List<AudioDevice>? devices, this.latency})
    : _devices = devices ?? demoDevices;

  /// Optional simulated round trip; by default replies on a microtask so
  /// opening Settings never leaves timers running.
  final Duration? latency;
  static const inputTestDuration = Duration(seconds: 3);
  static const outputTestDuration = Duration(seconds: 2);

  // Sample ids shaped like the backend's, used only as opaque demo data.
  static const micId = 'robot:mic';
  static const speakerId = 'robot:speaker';
  static const defaultId = 'system:default';
  static const usbMicId = 'usb:0000:0001:demo-1';
  static const usbSpeakerId = 'usb:0000:0002:demo-2';

  static const demoDevices = [
    AudioDevice(
      id: micId,
      name: 'Unitree G1 microphone array',
      direction: AudioDeviceDirection.input,
      kind: AudioDeviceKind.robotBuiltIn,
      simulated: true,
    ),
    AudioDevice(
      id: defaultId,
      name: 'Jetson system default microphone',
      direction: AudioDeviceDirection.input,
      kind: AudioDeviceKind.systemDefault,
      simulated: true,
    ),
    AudioDevice(
      id: usbMicId,
      name: 'USB microphone',
      direction: AudioDeviceDirection.input,
      kind: AudioDeviceKind.usb,
      simulated: true,
    ),
    AudioDevice(
      id: speakerId,
      name: 'Unitree G1 built-in speaker',
      direction: AudioDeviceDirection.output,
      kind: AudioDeviceKind.robotBuiltIn,
      simulated: true,
    ),
    AudioDevice(
      id: defaultId,
      name: 'Jetson system default speaker',
      direction: AudioDeviceDirection.output,
      kind: AudioDeviceKind.systemDefault,
      simulated: true,
    ),
    AudioDevice(
      id: usbSpeakerId,
      name: 'USB speaker',
      direction: AudioDeviceDirection.output,
      kind: AudioDeviceKind.usb,
      simulated: true,
    ),
  ];

  List<AudioDevice> _devices;
  var _settings = const AudioDeviceSettings(
    inputId: micId,
    outputId: speakerId,
  );
  final _tests = <AudioDeviceDirection, Completer<AudioTestResult>>{};
  final _timers = <AudioDeviceDirection, Timer>{};

  /// Simulates unplugging or plugging in devices.
  @visibleForTesting
  set devices(List<AudioDevice> value) => _devices = value;

  @override
  bool get isSimulated => true;

  @override
  String? get unavailableReason => null;

  Future<T> _reply<T>(T Function() reply) => latency == null
      ? Future.microtask(reply)
      : Future.delayed(latency!, reply);

  @override
  Future<List<AudioDevice>> getDevices() =>
      _reply(() => List.unmodifiable(_devices));

  @override
  Future<AudioDeviceSettings> getSettings() => _reply(() => _settings);

  @override
  Future<AudioDeviceSettings> applySettings(AudioDeviceSettings desired) =>
      _reply(() {
        for (final (id, direction) in [
          (desired.inputId, AudioDeviceDirection.input),
          (desired.outputId, AudioDeviceDirection.output),
        ]) {
          if (id != null &&
              !_devices.any(
                (d) => d.id == id && d.direction == direction && d.connected,
              )) {
            throw const AudioDeviceException(
              'not_found',
              'The selected device is not connected.',
            );
          }
        }
        return _settings = AudioDeviceSettings(
          inputId: desired.inputId ?? _settings.inputId,
          outputId: desired.outputId ?? _settings.outputId,
        );
      });

  Future<AudioTestResult> _test(
    AudioDeviceDirection direction,
    String deviceId,
    Duration duration,
  ) {
    if (_tests.containsKey(direction)) {
      return Future.error(
        const AudioDeviceException('busy', 'A test is already running.'),
      );
    }
    if (!_devices.any(
      (d) => d.id == deviceId && d.direction == direction && d.connected,
    )) {
      return Future.error(
        const AudioDeviceException('not_found', 'The device is not connected.'),
      );
    }
    final completer = Completer<AudioTestResult>();
    _tests[direction] = completer;
    _timers[direction] = Timer(duration, () {
      _tests.remove(direction);
      _timers.remove(direction);
      completer.complete(
        AudioTestResult(
          AudioTestOutcome.passed,
          message: direction == AudioDeviceDirection.input
              ? 'Simulated input level detected. Nothing was recorded.'
              : 'Simulated tone finished. Nothing was played.',
          level: direction == AudioDeviceDirection.input ? 0.62 : null,
        ),
      );
    });
    return completer.future;
  }

  @override
  Future<AudioTestResult> testInput(String deviceId) =>
      _test(AudioDeviceDirection.input, deviceId, inputTestDuration);

  @override
  Future<AudioTestResult> testOutput(String deviceId) =>
      _test(AudioDeviceDirection.output, deviceId, outputTestDuration);

  @override
  void cancelTest(AudioDeviceDirection direction) {
    _timers.remove(direction)?.cancel();
    _tests
        .remove(direction)
        ?.complete(const AudioTestResult(AudioTestOutcome.cancelled));
  }

  @override
  void dispose() {
    for (final direction in AudioDeviceDirection.values) {
      cancelTest(direction);
    }
  }
}
