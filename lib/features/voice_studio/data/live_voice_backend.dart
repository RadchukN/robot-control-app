import 'dart:async';
import 'dart:convert';

import 'package:robot_control_app/features/dashboard/application/dashboard_controller.dart';
import 'package:robot_control_app/features/voice_studio/data/voice_backend.dart';
import 'package:robot_control_app/features/voice_studio/domain/voice_models.dart';

abstract interface class VoiceFrameTransport {
  Stream<Map<String, dynamic>> get frames;
  void send(Map<String, Object?> frame);
}

class DashboardVoiceTransport implements VoiceFrameTransport {
  DashboardVoiceTransport(this._dashboard);
  final DashboardController _dashboard;
  @override
  Stream<Map<String, dynamic>> get frames => _dashboard.voiceFrames;
  @override
  void send(Map<String, Object?> frame) => _dashboard.sendVoiceFrame(frame);
}

enum _Request { capabilities, status, start, reclaim, stop }

/// medza.voice v1 controller/adapter. Credentials live only in private memory.
/// A transport opening is never permission to start a new conversation.
class LiveVoiceBackend implements VoiceBackend {
  LiveVoiceBackend(
    this._transport, {
    DateTime Function()? now,
    this.requestTimeout = const Duration(seconds: 10),
    this.readyTimeout = const Duration(seconds: 30),
  }) : _now = now ?? DateTime.now {
    _subscription = _transport.frames.listen(_receive);
  }

  static int _nextAdapter = 0;

  final VoiceFrameTransport _transport;
  final int _adapterId = ++_nextAdapter;
  final DateTime Function() _now;
  final Duration requestTimeout;
  final Duration readyTimeout;
  final _events = StreamController<VoiceBackendEvent>.broadcast();
  late final StreamSubscription<Map<String, dynamic>> _subscription;
  final _requests = <String, (_Request, Timer, int)>{};
  final _transcripts = <String, TranscriptEntry>{};
  int _counter = 0;
  int _sequence = 0;
  int _operation = 0;
  bool _disposed = false;
  bool _linked = false;
  bool _enabled = false;
  bool _supportsReclaim = false;
  bool _capabilitiesKnown = false;
  bool _statusKnown = false;
  bool _idle = false;
  bool _active = false;
  bool _needsReclaim = false;
  bool _stopRequested = false;
  bool _failed = false;
  String? _endpoint;
  String? _session;
  String? _ownedSession;
  String? _resumeToken;
  String? _stopSession;
  Timer? _readyTimer;
  String? _unavailable = 'Checking voice availability.';

  @override
  bool get isSimulated => false;
  @override
  Stream<VoiceBackendEvent> get events => _events.stream;
  @override
  String? get unavailableReason => _unavailable;
  @override
  VoiceCapabilities? get capabilities => _capabilitiesKnown
      ? VoiceCapabilities(
          languages: const {},
          voices: const {},
          speeds: const [],
          realtimeConversation: _enabled,
        )
      : null;

  void _emit(VoiceBackendEvent event) {
    if (!_disposed) _events.add(event);
  }

  void _controls() => _emit(
    VoiceControlEvent(
      available: _linked && _capabilitiesKnown && _enabled,
      idle: _statusKnown && _idle && !_stopRequested,
      canStop: _active || _stopRequested,
      reason: _unavailable,
    ),
  );

  void connectionChanged(bool linked, String endpoint) {
    if (_disposed) return;
    final changed = _endpoint != null && endpoint != _endpoint;
    if (changed) {
      _forgetOwner();
      _session = null;
      _active = false;
      _stopRequested = false;
      _stopSession = null;
      _transcripts.clear();
    }
    _endpoint = endpoint;
    if (_linked == linked && !changed) return;
    _linked = linked;
    _cancelRequests();
    _capabilitiesKnown = false;
    _statusKnown = false;
    _enabled = false;
    _idle = false;
    _unavailable = linked
        ? 'Checking voice availability.'
        : 'Robot link is down.';
    if (!linked) {
      _needsReclaim = _resumeToken != null && !_stopRequested;
      _emit(const VoiceSessionEvent(VoiceSessionState.disconnected));
      _emit(
        const VoiceDeviceEvent(
          microphone: DeviceStatus.unavailable,
          speaker: DeviceStatus.unavailable,
        ),
      );
    } else {
      // Queries subscribe and observe; they never create/reclaim a session.
      _query();
    }
    _controls();
  }

  void _query() {
    _send(_Request.capabilities);
    _send(_Request.status);
  }

  String? _send(_Request request) {
    if (_disposed || !_linked) return null;
    final id = 'voice-$_adapterId-${++_counter}';
    final frame = <String, Object?>{
      'type': switch (request) {
        _Request.capabilities => 'voice_get_capabilities',
        _Request.status => 'voice_get_status',
        _Request.start || _Request.reclaim => 'voice_start',
        _Request.stop => 'voice_stop',
      },
      'request_id': id,
      if (request == _Request.reclaim) ...{
        'session_id': _ownedSession,
        'resume_token': _resumeToken,
      },
    };
    _requests[id] = (
      request,
      Timer(requestTimeout, () {
        final expired = _requests.remove(id);
        if (expired == null || expired.$3 != _operation) return;
        if (request == _Request.reclaim) _forgetOwner();
        _idle = false; // An unanswered command is not proof of terminal idle.
        _statusKnown = false;
        _controls();
        _error('request_timeout');
        if (request == _Request.start ||
            request == _Request.stop ||
            request == _Request.reclaim) {
          _send(_Request.status);
        }
      }),
      _operation,
    );
    try {
      _transport.send(frame);
    } on Object {
      _requests.remove(id)?.$2.cancel();
      _statusKnown = false;
      _idle = false;
      _error('network_error');
      _controls();
    }
    return id;
  }

  @override
  Future<void> startConversation() async {
    if (!_linked || !_enabled || !_statusKnown || !_idle || _stopRequested) {
      return;
    }
    _failed = false;
    _operation++;
    _session = null;
    _idle = false;
    _active = true;
    _emit(const VoiceSessionEvent(VoiceSessionState.starting));
    _controls();
    _send(_Request.start);
    _waitForReady();
  }

  void _waitForReady() {
    _readyTimer?.cancel();
    _readyTimer = Timer(readyTimeout, () {
      _idle = false;
      _statusKnown = false;
      _controls();
      _error('readiness_timeout');
      _send(_Request.status);
    });
  }

  @override
  Future<void> stopConversation() async {
    _failed = false; // An explicit Stop is a fresh operator action.
    _operation++;
    _stopRequested = true;
    _stopSession = _session;
    _needsReclaim = false;
    _forgetOwner();
    _readyTimer?.cancel();
    // Invalidate late Start/reclaim acknowledgements, including their tokens.
    for (final entry in _requests.entries.toList()) {
      if (entry.value.$1 == _Request.start ||
          entry.value.$1 == _Request.reclaim) {
        entry.value.$2.cancel();
        _requests.remove(entry.key);
      }
    }
    _emit(const VoiceSessionEvent(VoiceSessionState.stopping));
    _controls();
    if (_linked) _send(_Request.stop);
  }

  void _receive(Map<String, dynamic> frame) {
    if (_disposed || !_linked) return;
    final type = frame['type'];
    if (type == 'voice_status' || type == 'voice_capabilities') {
      if (frame['protocol'] != 'medza.voice' || frame['version'] != 1) return;
    }
    if (type == 'voice_capabilities' && frame['enabled'] is! bool) return;
    if (type == 'voice_status' &&
        (!const {
              'idle',
              'starting',
              'listening',
              'stopping',
            }.contains(frame['state']) ||
            (frame['session_id'] != null && frame['session_id'] is! String))) {
      return;
    }
    final id = frame['request_id'];
    final pending = id is String ? _requests[id] : null;
    if (pending != null && pending.$3 != _operation) {
      _requests.remove(id)?.$2.cancel();
      return;
    }
    final kind = pending?.$1;
    if ((type == 'voice_capabilities' && kind == _Request.capabilities) ||
        (type == 'voice_status' &&
            kind != null &&
            kind != _Request.capabilities) ||
        (type == 'voice_error' && kind != null)) {
      _requests.remove(id)?.$2.cancel();
    }
    switch (type) {
      case 'voice_capabilities':
        if (kind != _Request.capabilities || frame['enabled'] is! bool) return;
        _capabilitiesKnown = true;
        _enabled = frame['enabled'] == true;
        _supportsReclaim =
            frame['ownership'] == 'connection_with_resume_token' &&
            frame['requests'] is List &&
            (frame['requests'] as List).contains('voice_start');
        _unavailable = _enabled ? null : 'Voice is disabled on the backend.';
        _controls();
        _maybeResume();
      case 'voice_status':
        _status(frame, kind);
      case 'voice_transcript':
        _transcript(frame);
      case 'voice_error':
        final fatal = frame['fatal'] == true;
        if (fatal &&
            (frame['session_id'] is! String ||
                frame['session_id'] != _session)) {
          return;
        }
        if (!fatal && kind == null) return;
        // Observing a still-running shared session does not undo a rejected
        // command or restore ownership. Keep the error until operator action.
        _failed = true;
        if (kind == _Request.reclaim) {
          _forgetOwner();
          _send(_Request.status);
        }
        if (fatal) {
          _failed = true;
          _forgetOwner();
          _readyTimer?.cancel();
        }
        _idle = false;
        _statusKnown = false;
        final code = frame['code'];
        if (code == 'voice_disabled') {
          _enabled = false;
          _unavailable = _messages['voice_disabled'];
        }
        _error(code is String ? code : 'voice_failed');
        if (code == 'input_lost' || code == 'microphone_lost') {
          _emit(
            const VoiceDeviceEvent(
              microphone: DeviceStatus.unavailable,
              speaker: DeviceStatus.unknown,
            ),
          );
        } else if (code == 'bluetooth_unavailable' || code == 'output_error') {
          _emit(
            const VoiceDeviceEvent(
              microphone: DeviceStatus.unknown,
              speaker: DeviceStatus.unavailable,
            ),
          );
        }
        _controls();
        if (!fatal && kind != _Request.reclaim && kind != _Request.status) {
          _send(_Request.status);
        }
    }
  }

  void _status(Map<String, dynamic> frame, _Request? kind) {
    final value = frame['state'];
    if (!const {'idle', 'starting', 'listening', 'stopping'}.contains(value)) {
      return;
    }
    final session = frame['session_id'];
    if (session != null && session is! String) return;
    if (kind == null && _active && _session != null && session != _session) {
      return;
    }
    if (kind == null && _requests.values.any((p) => p.$1 == _Request.start)) {
      return;
    }
    // Correlated late command replies cannot supersede a newer command/session.
    if (frame['request_id'] != null && kind == null) return;
    if (kind == _Request.reclaim && session != _ownedSession) return;
    final token = frame['resume_token'];
    if (!_stopRequested &&
        (kind == _Request.start || kind == _Request.reclaim) &&
        session is String &&
        token is String &&
        token.isNotEmpty &&
        token.codeUnits.every((n) => n < 128)) {
      _ownedSession = session;
      _resumeToken = token;
      _needsReclaim = false;
    }
    _session = session as String?;
    _statusKnown = true;
    _idle = value == 'idle';
    _active = !_idle;
    if (_idle) {
      final reason = frame['reason'];
      _forgetOwner();
      _stopRequested = false;
      _stopSession = null;
      _readyTimer?.cancel();
      // Terminal pushes are authoritative, even before the Stop reply.
      for (final entry in _requests.entries.toList()) {
        if (entry.value.$1 != _Request.capabilities) {
          entry.value.$2.cancel();
          _requests.remove(entry.key);
        }
      }
      if (reason is String && reason != 'stopped') {
        _failed = true;
        _error(reason);
      }
      if (!_failed) _emit(const VoiceSessionEvent(VoiceSessionState.idle));
    } else if (!_stopRequested) {
      final next = switch (value) {
        'listening' => VoiceSessionState.listening,
        'stopping' => VoiceSessionState.stopping,
        _ => VoiceSessionState.starting,
      };
      if (value == 'listening' || value == 'stopping') _readyTimer?.cancel();
      if (!_failed && !(_needsReclaim && _ownedSession == session)) {
        _emit(VoiceSessionEvent(next));
      }
    }
    _controls();
    _maybeResume();
  }

  void _maybeResume() {
    if (!_linked || !_capabilitiesKnown || !_statusKnown || _idle) return;
    if (_stopRequested) {
      if (_stopSession == _session &&
          !_requests.values.any((p) => p.$1 == _Request.stop)) {
        _send(_Request.stop);
      } else if (_stopSession != _session) {
        // A queued Stop must not stop a replacement session on another owner.
        _stopRequested = false;
        _stopSession = null;
        _controls();
        _error('session_owned');
      }
      return;
    }
    if (_needsReclaim &&
        _supportsReclaim &&
        _enabled &&
        _ownedSession == _session &&
        _resumeToken != null) {
      _needsReclaim =
          false; // One explicit attempt per connection; no retry loop.
      _send(_Request.reclaim);
    } else if (_ownedSession != null && _ownedSession != _session) {
      _forgetOwner();
    }
  }

  void _transcript(Map<String, dynamic> frame) {
    if (frame['session_id'] != _session || _session == null) return;
    final role = frame['role'];
    final item = frame['item_id'];
    final response = frame['response_id'];
    final text = frame['text'];
    final finality = frame['final'];
    if ((role != 'user' && role != 'assistant') ||
        item is! String ||
        text is! String ||
        finality is! bool ||
        (response != null && response is! String)) {
      return;
    }
    final key = jsonEncode([_session, role, item, response]);
    final current = _transcripts[key];
    if (current?.isFinal == true && !finality) return;
    final entry = TranscriptEntry(
      id: current?.id ?? 'live-item-${++_counter}',
      role: role == 'user' ? TranscriptRole.user : TranscriptRole.robot,
      text: finality ? text : '${current?.text ?? ''}$text',
      isFinal: finality,
      timestamp: current?.timestamp ?? _now(),
      sequence: ++_sequence,
    );
    _transcripts[key] = entry;
    if (_transcripts.length > 200) {
      _transcripts.remove(_transcripts.keys.first);
    }
    _emit(VoiceTranscriptEvent(entry));
    // Transcript finality never changes playback/readiness/device state.
  }

  void _error(String code) {
    // Never display provider exception text, arbitrary wire fields or secrets.
    final safeCode = _messages.containsKey(code) ? code : 'voice_failed';
    _emit(VoiceErrorEvent(safeCode, _messages[safeCode]!));
  }

  void _forgetOwner() {
    _ownedSession = null;
    _resumeToken = null;
    _needsReclaim = false;
  }

  void _cancelRequests() {
    for (final request in _requests.values) {
      request.$2.cancel();
    }
    _requests.clear();
    _readyTimer?.cancel();
  }

  @override
  Future<void> speak(TtsRequest request) => Future.error(
    StateError('Live text-to-speech is not available in medza.voice v1.'),
  );
  @override
  Future<void> stopSpeaking(String requestId) async {}
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelRequests();
    _forgetOwner();
    _session = null;
    _transcripts.clear();
    _subscription.cancel();
    _events.close();
  }
}

const _messages = <String, String>{
  'invalid_request': 'The backend rejected the voice request.',
  'unknown_request': 'This backend does not support the voice request.',
  'voice_disabled': 'Voice is disabled on the backend.',
  'audio_session_active': 'Robot audio is already in use.',
  'selection_required': 'Save an input and output in Audio Devices first.',
  'usb_input_bluetooth_output_required':
      'Select a USB microphone and Bluetooth speaker in Audio Devices.',
  'device_unavailable': 'The selected microphone or speaker is unavailable.',
  'wrong_direction': 'The saved audio device has the wrong direction.',
  'invalid_device_id': 'The saved audio selection is invalid.',
  'venv_unavailable': 'The backend voice environment is unavailable.',
  'voice_start_failed': 'The backend could not launch voice.',
  'session_owned':
      'Another connection owns the session. Stop remains available.',
  'invalid_reclaim':
      'Session ownership could not be reclaimed. Stop and start explicitly.',
  'reclaim_expired':
      'The reconnect grace period expired. Start a new conversation explicitly.',
  'session_unavailable': 'The previous session no longer exists.',
  'session_stopping': 'The session is stopping.',
  'api_error': 'The voice provider reported an error.',
  'input_lost': 'Microphone capture failed or timed out.',
  'microphone_lost': 'The microphone was disconnected.',
  'bluetooth_unavailable': 'The Bluetooth speaker is unavailable.',
  'output_error': 'Speaker playback failed.',
  'network_error': 'The voice connection failed.',
  'voice_failed': 'The voice session failed.',
  'child_exited': 'The voice process ended unexpectedly.',
  'child_protocol_error': 'The backend received an invalid voice event.',
  'cleanup_failed': 'Voice cleanup failed. Check backend audio status.',
  'cleanup_timeout': 'Voice cleanup timed out; the backend forced termination.',
  'max_duration': 'The conversation reached its duration limit.',
  'idle_timeout': 'The conversation ended after inactivity.',
  'client_disconnected': 'The owner reconnect grace period expired.',
  'server_shutdown': 'The voice server shut down.',
  'request_timeout':
      'The voice request timed out. Status is being checked; Stop remains available.',
  'readiness_timeout':
      'Voice did not become ready in time. Stop remains available.',
};
