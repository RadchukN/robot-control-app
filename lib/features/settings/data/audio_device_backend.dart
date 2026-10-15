import 'dart:async';

import 'package:flutter/foundation.dart';

enum AudioDeviceDirection { input, output }

/// Display category reported by the backend (`kind`); never derived from id.
enum AudioDeviceKind { robot, system, usb, hdmi, other }

/// `connected` / `status` of a device. Robot audio is `unknown`: it can only
/// be checked by using it.
enum AudioAvailability { connected, disconnected, unknown }

@immutable
class AudioDevice {
  const AudioDevice({
    required this.id,
    required this.name,
    required this.direction,
    required this.kind,
    this.availability = AudioAvailability.connected,
    this.verified = true,
    this.limitations = const [],
    this.simulated = false,
  });

  /// Opaque, server-generated stable id (for example `robot:mic` or
  /// `usb:<vid>:<pid>[:<serial>][@<usb-port>]`). Never parsed or rewritten.
  final String id;

  /// The backend's `label`.
  final String name;
  final AudioDeviceDirection direction;
  final AudioDeviceKind kind;
  final AudioAvailability availability;

  /// False for devices not proven on this robot (`robot:mic`, …).
  final bool verified;

  /// Human-readable notes from the backend, shown under the device.
  final List<String> limitations;
  final bool simulated;

  /// Unplugged devices cannot be chosen; `unknown` (robot audio) can.
  bool get selectable => availability != AudioAvailability.disconnected;
}

/// A selection the backend confirmed as saved. Saved is not active: it takes
/// effect when the voice runtime next starts (`applies_on`).
@immutable
class AudioDeviceSettings {
  const AudioDeviceSettings({this.inputId, this.outputId});

  final String? inputId;
  final String? outputId;
}

/// `input`/`output.status` of the resolved selection.
enum AudioSelectionStatus { connected, disconnected, unknown, unresolved }

/// Where the resolved selection comes from.
enum AudioSelectionSource { settings, env, envFallback, unknown }

@immutable
class AudioSelection {
  const AudioSelection({
    this.deviceId,
    this.label,
    this.status = AudioSelectionStatus.unknown,
    this.source = AudioSelectionSource.settings,
  });

  final String? deviceId;
  final String? label;
  final AudioSelectionStatus status;
  final AudioSelectionSource source;
}

enum AudioSettingsFileStatus { ok, absent, invalid, unknown }

/// Who holds the robot's audio lock, as observed by the backend.
@immutable
class AudioSessionInfo {
  const AudioSessionInfo({
    this.active = false,
    this.owner,
    this.inputLost = false,
    this.inputDeviceId,
    this.outputDeviceId,
  });

  final bool active;

  /// e.g. `realtime_voice`, `tts`, `audio_test_input`; null when idle.
  final String? owner;

  /// `session.input_state == "lost"` during a realtime session.
  final bool inputLost;

  /// Devices the running session actually uses; the only source of "active".
  final String? inputDeviceId;
  final String? outputDeviceId;
}

/// Body of `audio_settings` / `audio_device_status`.
@immutable
class AudioDeviceStatus {
  const AudioDeviceStatus({
    this.input = const AudioSelection(),
    this.output = const AudioSelection(),
    this.settingsFile = AudioSettingsFileStatus.ok,
    this.session = const AudioSessionInfo(),
    this.voiceRuntimeRunning = false,
    this.testsEnabled = false,
    this.testRunning = false,
    this.devicesChanged = false,
  });

  final AudioSelection input;
  final AudioSelection output;
  final AudioSettingsFileStatus settingsFile;
  final AudioSessionInfo session;
  final bool voiceRuntimeRunning;
  final bool testsEnabled;
  final bool testRunning;

  /// Pushed when a device was plugged in or removed; re-request devices.
  final bool devicesChanged;

  AudioSelection selection(AudioDeviceDirection d) =>
      d == AudioDeviceDirection.input ? input : output;

  /// The device a running session uses, or null (idle or not reported).
  String? activeId(AudioDeviceDirection d) => !session.active
      ? null
      : d == AudioDeviceDirection.input
      ? session.inputDeviceId
      : session.outputDeviceId;
}

/// What the robot advertised (Flutter-side flags mapped from the contract).
@immutable
class AudioCapabilities {
  const AudioCapabilities({
    this.discovery = false,
    this.settings = false,
    this.inputTest = false,
    this.outputTest = false,
    this.cancellableTests = false,
    this.inputTestDefaultSec = 3,
  });

  static const none = AudioCapabilities();

  final bool discovery;
  final bool settings;

  /// Hardware tests are opt-in on the Jetson (`--audio-tests`).
  final bool inputTest;
  final bool outputTest;

  /// Whether a running test can actually be stopped on the robot.
  final bool cancellableTests;
  final int inputTestDefaultSec;

  bool testFor(AudioDeviceDirection direction) =>
      direction == AudioDeviceDirection.input ? inputTest : outputTest;
}

enum AudioTestOutcome { passed, failed, cancelled }

@immutable
class AudioTestResult {
  const AudioTestResult(
    this.outcome, {
    this.message,
    this.rms,
    this.peak,
    this.peakDbfs,
    this.clipping,
    this.signal,
    this.durationSec,
  });

  final AudioTestOutcome outcome;
  final String? message;

  /// Input measurements exactly as the backend reported them; never invented.
  final num? rms;
  final num? peak;
  final num? peakDbfs;
  final bool? clipping;

  /// `ok` or `silent`.
  final String? signal;
  final num? durationSec;
}

/// Pushed state changes (no request id).
sealed class AudioBackendEvent {
  const AudioBackendEvent();
}

/// A pushed `audio_device_status` or `audio_settings`.
class AudioStatusPushed extends AudioBackendEvent {
  const AudioStatusPushed(this.status);

  final AudioDeviceStatus status;
}

/// A pushed `audio_error`.
class AudioErrorPushed extends AudioBackendEvent {
  const AudioErrorPushed({
    required this.code,
    required this.fatal,
    this.owner,
    this.deviceId,
    this.direction,
    this.detail,
  });

  /// `input_device_lost`, `session_stopped_input_lost`,
  /// `selected_device_disconnected`, `settings_file_invalid`, …
  final String code;
  final bool fatal;
  final String? owner;
  final String? deviceId;
  final AudioDeviceDirection? direction;
  final String? detail;
}

/// Thrown for a failed request; [code] is the backend's `error` (or a
/// Flutter-side reason such as `timeout`, `unsupported`, `disconnected`).
class AudioDeviceException implements Exception {
  const AudioDeviceException(
    this.code,
    this.message, {
    this.owner,
    this.busy = false,
  });

  final String code;
  final String message;

  /// Audio lock holder for `busy` results.
  final String? owner;
  final bool busy;

  @override
  String toString() => message;
}

/// Audio device management on the robot. Implementations open no robot
/// connection of their own; the live adapter uses the dashboard's
/// authenticated WebSocket.
abstract interface class AudioDeviceBackend {
  bool get isSimulated;

  /// Why device management is unavailable, or null when usable.
  String? get unavailableReason;

  /// Pushed status, settings and error events.
  Stream<AudioBackendEvent> get events;

  Future<AudioCapabilities> getCapabilities();
  Future<List<AudioDevice>> getDevices();
  Future<AudioDeviceStatus> getStatus();

  /// Returns the selection the backend confirmed as saved.
  Future<AudioDeviceSettings> applySettings(AudioDeviceSettings desired);

  /// A bounded hardware test, sent only after the user confirmed it.
  Future<AudioTestResult> testInput(String deviceId, {int? durationSec});
  Future<AudioTestResult> testOutput(String deviceId);

  /// Stops a test where supported; see [AudioCapabilities.cancellableTests].
  void cancelTest(AudioDeviceDirection direction);
  void dispose();
}

/// No usable backend (robot disconnected, or audio unsupported): nothing is
/// ever sent and every request fails with [unavailableReason].
class UnavailableAudioDeviceBackend implements AudioDeviceBackend {
  const UnavailableAudioDeviceBackend([
    this.unavailableReason = 'Robot is not connected.',
  ]);

  @override
  final String unavailableReason;

  @override
  bool get isSimulated => false;

  @override
  Stream<AudioBackendEvent> get events => const Stream.empty();

  Future<Never> _unavailable() =>
      Future.error(AudioDeviceException('unavailable', unavailableReason));

  @override
  Future<AudioCapabilities> getCapabilities() => _unavailable();

  @override
  Future<List<AudioDevice>> getDevices() => _unavailable();

  @override
  Future<AudioDeviceStatus> getStatus() => _unavailable();

  @override
  Future<AudioDeviceSettings> applySettings(AudioDeviceSettings desired) =>
      _unavailable();

  @override
  Future<AudioTestResult> testInput(String deviceId, {int? durationSec}) =>
      _unavailable();

  @override
  Future<AudioTestResult> testOutput(String deviceId) => _unavailable();

  @override
  void cancelTest(AudioDeviceDirection direction) {}

  @override
  void dispose() {}
}

/// Demo Mode backend: simulated devices, no recording, no playback, no I/O.
class MockAudioDeviceBackend implements AudioDeviceBackend {
  MockAudioDeviceBackend({
    List<AudioDevice>? devices,
    this.latency,
    this.capabilities = demoCapabilities,
  }) : _devices = devices ?? demoDevices;

  static const demoCapabilities = AudioCapabilities(
    discovery: true,
    settings: true,
    inputTest: true,
    outputTest: true,
    cancellableTests: true,
  );

  final AudioCapabilities capabilities;

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
      kind: AudioDeviceKind.robot,
      simulated: true,
    ),
    AudioDevice(
      id: defaultId,
      name: 'Jetson system default microphone',
      direction: AudioDeviceDirection.input,
      kind: AudioDeviceKind.system,
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
      kind: AudioDeviceKind.robot,
      simulated: true,
    ),
    AudioDevice(
      id: defaultId,
      name: 'Jetson system default speaker',
      direction: AudioDeviceDirection.output,
      kind: AudioDeviceKind.system,
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
  final _events = StreamController<AudioBackendEvent>.broadcast();

  /// Simulates unplugging or plugging in devices.
  @visibleForTesting
  set devices(List<AudioDevice> value) => _devices = value;

  @override
  bool get isSimulated => true;

  @override
  String? get unavailableReason => null;

  @override
  Stream<AudioBackendEvent> get events => _events.stream;

  Future<T> _reply<T>(T Function() reply) => latency == null
      ? Future.microtask(reply)
      : Future.delayed(latency!, reply);

  AudioDevice? _find(String? id, AudioDeviceDirection direction) =>
      _devices.where((d) => d.id == id && d.direction == direction).firstOrNull;

  AudioSelection _selection(String? id, AudioDeviceDirection direction) {
    final device = _find(id, direction);
    return AudioSelection(
      deviceId: id,
      label: device?.name,
      status: device == null
          ? AudioSelectionStatus.disconnected
          : AudioSelectionStatus.connected,
    );
  }

  /// No demo voice session ever runs, so nothing is reported active.
  AudioDeviceStatus _status() => AudioDeviceStatus(
    input: _selection(_settings.inputId, AudioDeviceDirection.input),
    output: _selection(_settings.outputId, AudioDeviceDirection.output),
    testsEnabled: capabilities.inputTest || capabilities.outputTest,
    testRunning: _tests.isNotEmpty,
  );

  @override
  Future<List<AudioDevice>> getDevices() =>
      _reply(() => List.unmodifiable(_devices));

  @override
  Future<AudioCapabilities> getCapabilities() => _reply(() => capabilities);

  @override
  Future<AudioDeviceStatus> getStatus() => _reply(_status);

  @override
  Future<AudioDeviceSettings> applySettings(AudioDeviceSettings desired) =>
      _reply(() {
        for (final (id, direction) in [
          (desired.inputId, AudioDeviceDirection.input),
          (desired.outputId, AudioDeviceDirection.output),
        ]) {
          if (id != null && !(_find(id, direction)?.selectable ?? false)) {
            throw const AudioDeviceException(
              'device_unavailable',
              'The selected device is not connected.',
            );
          }
        }
        _settings = AudioDeviceSettings(
          inputId: desired.inputId ?? _settings.inputId,
          outputId: desired.outputId ?? _settings.outputId,
        );
        // Like the robot: push the new settings, then confirm.
        if (!_events.isClosed) _events.add(AudioStatusPushed(_status()));
        return _settings;
      });

  Future<AudioTestResult> _test(
    AudioDeviceDirection direction,
    String deviceId,
    Duration duration,
  ) {
    if (_tests.containsKey(direction)) {
      return Future.error(
        const AudioDeviceException(
          'audio_test_running',
          'A test is already running.',
          busy: true,
        ),
      );
    }
    if (!(_find(deviceId, direction)?.selectable ?? false)) {
      return Future.error(
        const AudioDeviceException(
          'device_unavailable',
          'The device is not connected.',
        ),
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
              ? 'Simulated input level. Nothing was recorded.'
              : 'Simulated tone. Nothing was played.',
        ),
      );
    });
    return completer.future;
  }

  @override
  Future<AudioTestResult> testInput(String deviceId, {int? durationSec}) =>
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
    _events.close();
  }
}
