import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/features/dashboard/application/dashboard_controller.dart';
import 'package:robot_control_app/services/web_socket_service.dart';

enum MotionPlaybackStatus {
  idle,
  sending,
  playing,
  paused,
  stopping,
  finished,
  // Backend dry run: the command was simulated and the robot did not move.
  simulated,
  stopped,
  error,
  busy,
  unavailable,
}

@immutable
class SavedMotion {
  const SavedMotion({
    required this.id,
    required this.name,
    required this.type,
    required this.durationSeconds,
    required this.lastUsed,
    required this.favorite,
    required this.source,
    this.enabled = true,
    this.backendFilename,
  });

  final String id;
  final String name;
  final String type;
  final double durationSeconds;
  final String lastUsed;
  final bool favorite;
  final String source;
  final bool enabled;
  // Immutable catalog identity, separate from the editable display name.
  final String? backendFilename;

  String? get recordedFilename {
    final filename =
        backendFilename ??
        (id.startsWith('motion-file:assets:motions:') &&
                source.startsWith('assets/motions/')
            ? source.substring('assets/motions/'.length)
            : null);
    return enabled &&
            filename != null &&
            MotionCommandSession.isRecordingFilename(filename)
        ? filename
        : null;
  }

  SavedMotion copyWith({String? name, bool? favorite}) => SavedMotion(
    id: id,
    name: name ?? this.name,
    type: type,
    durationSeconds: durationSeconds,
    lastUsed: lastUsed,
    favorite: favorite ?? this.favorite,
    source: source,
    enabled: enabled,
    backendFilename: backendFilename,
  );
}

@immutable
class QuickGesture {
  const QuickGesture(
    this.id,
    this.name,
    this.durationSeconds,
    this.spriteIndex,
  );

  final String id;
  final String name;
  final double durationSeconds;
  final int spriteIndex;
}

@immutable
class MotionActivity {
  const MotionActivity(this.title, this.durationSeconds, this.when);

  final String title;
  final double durationSeconds;
  final String when;
}

const _unset = Object();

const simulationOnlyLabel = 'Simulation only — robot did not move';

@immutable
class MotionState {
  const MotionState({
    required this.serviceLoading,
    required this.serviceOnline,
    required this.usingLocalFallback,
    required this.savedMotions,
    required this.quickGestures,
    required this.recentActivity,
    required this.searchQuery,
    required this.typeFilter,
    required this.selectedMotionId,
    required this.currentMotionName,
    required this.playbackStatus,
    required this.playbackSpeed,
    required this.loop,
    required this.queueNext,
    required this.motionName,
    required this.motionCategory,
    required this.recording,
    required this.recordedDuration,
    required this.hasUnsavedChanges,
    required this.error,
    this.commandMessage,
    this.robotConnected = false,
  });

  const MotionState.initial()
    : serviceLoading = true,
      serviceOnline = false,
      usingLocalFallback = false,
      savedMotions = const [],
      quickGestures = _quickGestures,
      recentActivity = const [],
      searchQuery = '',
      typeFilter = 'All types',
      selectedMotionId = null,
      currentMotionName = null,
      playbackStatus = MotionPlaybackStatus.idle,
      playbackSpeed = 1,
      loop = false,
      queueNext = false,
      motionName = '',
      motionCategory = 'Custom',
      recording = false,
      recordedDuration = Duration.zero,
      hasUnsavedChanges = false,
      error = null,
      commandMessage = null,
      robotConnected = false;

  final String? commandMessage;
  final bool robotConnected;

  final bool serviceLoading;
  final bool serviceOnline;
  final bool usingLocalFallback;
  final List<SavedMotion> savedMotions;
  final List<QuickGesture> quickGestures;
  final List<MotionActivity> recentActivity;
  final String searchQuery;
  final String typeFilter;
  final String? selectedMotionId;
  final String? currentMotionName;
  final MotionPlaybackStatus playbackStatus;
  final double playbackSpeed;
  final bool loop;
  final bool queueNext;
  final String motionName;
  final String motionCategory;
  final bool recording;
  final Duration recordedDuration;
  final bool hasUnsavedChanges;
  final String? error;

  SavedMotion? get selectedMotion {
    for (final motion in savedMotions) {
      if (motion.id == selectedMotionId) return motion;
    }
    return null;
  }

  List<String> get types => [
    'All types',
    ...{for (final motion in savedMotions) motion.type},
  ];

  List<SavedMotion> get visibleMotions {
    final query = searchQuery.trim().toLowerCase();
    return savedMotions
        .where(
          (motion) =>
              (typeFilter == 'All types' || motion.type == typeFilter) &&
              (query.isEmpty ||
                  motion.name.toLowerCase().contains(query) ||
                  motion.type.toLowerCase().contains(query)),
        )
        .toList(growable: false);
  }

  MotionState copyWith({
    bool? serviceLoading,
    bool? serviceOnline,
    bool? usingLocalFallback,
    List<SavedMotion>? savedMotions,
    List<MotionActivity>? recentActivity,
    String? searchQuery,
    String? typeFilter,
    Object? selectedMotionId = _unset,
    Object? currentMotionName = _unset,
    MotionPlaybackStatus? playbackStatus,
    double? playbackSpeed,
    bool? loop,
    bool? queueNext,
    String? motionName,
    String? motionCategory,
    bool? recording,
    Duration? recordedDuration,
    bool? hasUnsavedChanges,
    Object? error = _unset,
    Object? commandMessage = _unset,
    bool? robotConnected,
  }) => MotionState(
    serviceLoading: serviceLoading ?? this.serviceLoading,
    serviceOnline: serviceOnline ?? this.serviceOnline,
    usingLocalFallback: usingLocalFallback ?? this.usingLocalFallback,
    savedMotions: savedMotions ?? this.savedMotions,
    quickGestures: quickGestures,
    recentActivity: recentActivity ?? this.recentActivity,
    searchQuery: searchQuery ?? this.searchQuery,
    typeFilter: typeFilter ?? this.typeFilter,
    selectedMotionId: identical(selectedMotionId, _unset)
        ? this.selectedMotionId
        : selectedMotionId as String?,
    currentMotionName: identical(currentMotionName, _unset)
        ? this.currentMotionName
        : currentMotionName as String?,
    playbackStatus: playbackStatus ?? this.playbackStatus,
    playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    loop: loop ?? this.loop,
    queueNext: queueNext ?? this.queueNext,
    motionName: motionName ?? this.motionName,
    motionCategory: motionCategory ?? this.motionCategory,
    recording: recording ?? this.recording,
    recordedDuration: recordedDuration ?? this.recordedDuration,
    hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
    error: identical(error, _unset) ? this.error : error as String?,
    commandMessage: identical(commandMessage, _unset)
        ? this.commandMessage
        : commandMessage as String?,
    robotConnected: robotConnected ?? this.robotConnected,
  );
}

abstract interface class MotionCommandGateway {
  Future<void> sendMotion(SavedMotion motion);
  Future<List<SavedMotion>> importMotions();
  Future<void> exportMotion(SavedMotion motion);
}

final motionCommandGatewayProvider = Provider<MotionCommandGateway?>(
  (ref) => null,
);

class MotionController extends Notifier<MotionState> {
  Timer? _recordingTimer;
  DateTime? _recordingStarted;
  int _commandGeneration = 0;
  bool _commandPending = false;
  String? _pendingAction;
  bool _catalogRequested = false;
  bool _catalogLoading = false;
  int _catalogGeneration = 0;

  @override
  MotionState build() {
    ref.listen(dashboardControllerProvider, (_, next) {
      final connected =
          !next.hasError &&
          !next.isLoading &&
          next.value?.telemetryConnected == true;
      if (connected != state.robotConnected) {
        if (!connected) {
          _catalogGeneration++;
          _catalogRequested = false;
          _catalogLoading = false;
        }
        state = state.copyWith(
          robotConnected: connected,
          serviceLoading: connected,
          serviceOnline: false,
          savedMotions: const [],
          selectedMotionId: null,
          typeFilter: 'All types',
          error: connected
              ? null
              : 'WebSocket disconnected. Catalog unavailable.',
          commandMessage: connected
              ? 'Robot WebSocket connected. No motion was sent.'
              : 'Robot WebSocket disconnected. Motion outcome may be unknown.',
        );
        if (connected) unawaited(_loadMotions());
      }
    });
    ref.onDispose(() => _recordingTimer?.cancel());
    Future<void>.microtask(_loadMotions);
    final dashboard = ref.read(dashboardControllerProvider);
    return const MotionState.initial().copyWith(
      robotConnected:
          !dashboard.hasError &&
          !dashboard.isLoading &&
          dashboard.value?.telemetryConnected == true,
    );
  }

  Future<void> _loadMotions() async {
    if (!ref.mounted || _catalogLoading || _catalogRequested) return;
    if (!state.robotConnected) {
      state = state.copyWith(
        serviceLoading: false,
        serviceOnline: false,
        error: 'WebSocket disconnected. Waiting for connection.',
      );
      return;
    }
    _catalogRequested = true;
    _catalogLoading = true;
    final generation = ++_catalogGeneration;
    state = state.copyWith(serviceLoading: true, error: null);
    try {
      final filenames = await ref
          .read(dashboardControllerProvider.notifier)
          .getMotionCatalog();
      if (!ref.mounted || generation != _catalogGeneration) return;
      final motions = filenames
          .map(
            (filename) => SavedMotion(
              id: 'recorded:$filename',
              name: filename,
              type: _motionType(filename, 'Recorded'),
              durationSeconds: 0,
              lastUsed: '--',
              favorite: false,
              source: 'robot',
              backendFilename: filename,
            ),
          )
          .toList(growable: false);
      state = state.copyWith(
        serviceLoading: false,
        serviceOnline: true,
        usingLocalFallback: false,
        savedMotions: motions,
        selectedMotionId:
            motions.any((motion) => motion.id == state.selectedMotionId)
            ? state.selectedMotionId
            : motions.firstOrNull?.id,
        typeFilter: 'All types',
        error: null,
      );
    } on Object catch (error) {
      if (!ref.mounted || generation != _catalogGeneration) return;
      state = state.copyWith(
        serviceLoading: false,
        serviceOnline: false,
        usingLocalFallback: false,
        savedMotions: const [],
        selectedMotionId: null,
        typeFilter: 'All types',
        error: 'Motion catalog unavailable: $error',
      );
    } finally {
      if (generation == _catalogGeneration) _catalogLoading = false;
    }
  }

  Future<void> refresh() async {
    if (_catalogLoading) return;
    _catalogRequested = false;
    await _loadMotions();
  }

  void setSearchQuery(String value) =>
      state = state.copyWith(searchQuery: value);

  void setTypeFilter(String value) => state = state.copyWith(typeFilter: value);

  void selectMotion(String id) => state = state.copyWith(selectedMotionId: id);

  Future<bool> playMotion(String id) async {
    final motion = state.savedMotions
        .where((item) => item.id == id)
        .firstOrNull;
    if (motion == null || !motion.enabled) {
      _unavailable('This motion');
      return false;
    }
    state = state.copyWith(selectedMotionId: id);
    final filename = motion.recordedFilename;
    if (filename == null) {
      _unavailable(motion.name);
      return false;
    }
    return sendRecordedMotion(filename);
  }

  Future<bool> sendRecordedMotion(String filename) async {
    final motion = state.savedMotions
        .where((item) => item.recordedFilename == filename)
        .firstOrNull;
    if (motion == null) {
      _unavailable('Recorded motion');
      return false;
    }
    return _send(
      'play_recorded_motion',
      filename,
      motion.durationSeconds,
      filename: filename,
    );
  }

  Future<bool> playGesture(QuickGesture gesture) async {
    if (gesture.id == 'hello') {
      return _send('wave_hand', gesture.name, gesture.durationSeconds);
    }
    return sendRecordedMotion(gesture.id);
  }

  void pause() {
    _unavailable('Pause');
  }

  Future<bool> stop() => _send('stop_motion', 'Stop', 0);

  void _unavailable(String label) {
    state = state.copyWith(commandMessage: null);
    state = state.copyWith(
      playbackStatus: _commandPending
          ? state.playbackStatus
          : MotionPlaybackStatus.unavailable,
      commandMessage:
          '$label is not connected to the robot yet. No command sent.',
    );
  }

  Future<bool> _send(
    String action,
    String name,
    double duration, {
    String? filename,
  }) async {
    debugPrint(
      '[MOTION DEBUG] controller send attempt action=$action motion=$filename '
      'pending=$_commandPending pendingAction=$_pendingAction generation=$_commandGeneration',
    );
    if (_commandPending &&
        (action != 'stop_motion' || _pendingAction == 'stop_motion')) {
      debugPrint('[MOTION DEBUG] controller send blocked: local pending guard');
      state = state.copyWith(
        commandMessage: 'A command is pending. Stop remains available.',
      );
      return false;
    }
    final generation = ++_commandGeneration;
    _commandPending = true;
    _pendingAction = action;
    state = state.copyWith(
      commandMessage: 'Sending $name to robot…',
      error: null,
      playbackStatus: action == 'stop_motion'
          ? MotionPlaybackStatus.stopping
          : MotionPlaybackStatus.sending,
      currentMotionName: action == 'stop_motion'
          ? state.currentMotionName
          : name,
    );
    try {
      void processResult(Map<String, dynamic> result) {
        if (!ref.mounted || generation != _commandGeneration) {
          debugPrint(
            '[MOTION DEBUG] controller response ignored: '
            'mounted=${ref.mounted} responseGeneration=$generation '
            'currentGeneration=$_commandGeneration',
          );
          return;
        }
        final status = result['status'];
        if (const [
          'completed',
          'failed',
          'stopped',
          'unsupported_motion',
          'busy',
          'dry_run',
        ].contains(status)) {
          // Release the local command gate before notifying UI listeners.
          _commandPending = false;
          _pendingAction = null;
        }
        final playbackStatus = switch (status) {
          'accepted' =>
            action == 'stop_motion'
                ? MotionPlaybackStatus.stopping
                : MotionPlaybackStatus.playing,
          'completed' =>
            action == 'stop_motion'
                ? MotionPlaybackStatus.stopped
                : MotionPlaybackStatus.finished,
          'stopped' => MotionPlaybackStatus.stopped,
          'dry_run' => MotionPlaybackStatus.simulated,
          'busy' => MotionPlaybackStatus.busy,
          'unsupported_motion' => MotionPlaybackStatus.unavailable,
          _ => MotionPlaybackStatus.error,
        };
        final description = switch (playbackStatus) {
          MotionPlaybackStatus.playing => 'Playing on robot',
          MotionPlaybackStatus.stopping => 'Stop accepted; waiting for robot',
          MotionPlaybackStatus.finished => 'Finished',
          MotionPlaybackStatus.stopped => 'Stopped',
          MotionPlaybackStatus.simulated => simulationOnlyLabel,
          MotionPlaybackStatus.busy => 'Robot busy; command rejected',
          MotionPlaybackStatus.unavailable => 'Recording unavailable on robot',
          _ => 'Robot command failed',
        };
        final detail = result['error'] ?? result['message'];
        final message =
            '$name: $description${detail == null ? '' : ' — $detail'}';
        state = state.copyWith(
          playbackStatus: playbackStatus,
          error: const ['failed', 'busy', 'unsupported_motion'].contains(status)
              ? message
              : null,
          commandMessage: message,
          recentActivity: _activity('$name: $description', duration),
        );
      }

      void onResult(Map<String, dynamic> result) {
        debugPrint(
          '[MOTION DEBUG] controller before response '
          'action=${result['action']} motion=${result['motion']} status=${result['status']} '
          'expectedAction=$action expectedMotion=$filename '
          'pending=$_commandPending pendingAction=$_pendingAction generation=$_commandGeneration',
        );
        try {
          processResult(result);
        } finally {
          debugPrint(
            '[MOTION DEBUG] controller after response '
            'pending=$_commandPending pendingAction=$_pendingAction generation=$_commandGeneration',
          );
        }
      }

      final dashboard = ref.read(dashboardControllerProvider.notifier);
      final result = await (filename == null
          ? dashboard.sendMotion(action, onResult: onResult)
          : dashboard.sendRecordedMotion(filename, onResult: onResult));
      if (!ref.mounted || generation != _commandGeneration) return false;
      return const ['completed', 'stopped'].contains(result['status']);
    } on Object catch (error) {
      if (!ref.mounted || generation != _commandGeneration) return false;
      state = state.copyWith(
        playbackStatus: MotionPlaybackStatus.error,
        error: '$error',
        commandMessage: '$name: $error',
      );
      return false;
    } finally {
      if (generation == _commandGeneration) {
        _commandPending = false;
        _pendingAction = null;
      }
      debugPrint(
        '[MOTION DEBUG] controller send finally action=$action motion=$filename '
        'pending=$_commandPending pendingAction=$_pendingAction '
        'sendGeneration=$generation currentGeneration=$_commandGeneration',
      );
    }
  }

  void setPlaybackSpeed(double value) => _unavailable('Playback speed');

  void toggleLoop() => _unavailable('Loop');

  void toggleQueueNext() => _unavailable('Queue next');

  void toggleFavorite(String id) {
    state = state.copyWith(
      savedMotions: [
        for (final motion in state.savedMotions)
          motion.id == id
              ? motion.copyWith(favorite: !motion.favorite)
              : motion,
      ],
      hasUnsavedChanges: true,
    );
  }

  void duplicate(String id) {
    final source = state.savedMotions
        .where((item) => item.id == id)
        .firstOrNull;
    if (source == null) return;
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final base = source.name.endsWith('.json')
        ? source.name.substring(0, source.name.length - 5)
        : source.name;
    final copy = SavedMotion(
      id: 'local:$suffix',
      name: '${base}_copy.json',
      type: source.type,
      durationSeconds: source.durationSeconds,
      lastUsed: 'Not yet',
      favorite: false,
      source: 'local',
    );
    state = state.copyWith(
      savedMotions: [...state.savedMotions, copy],
      selectedMotionId: copy.id,
      hasUnsavedChanges: true,
    );
  }

  void rename(String id, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final name = trimmed.endsWith('.json') ? trimmed : '$trimmed.json';
    state = state.copyWith(
      savedMotions: [
        for (final motion in state.savedMotions)
          motion.id == id ? motion.copyWith(name: name) : motion,
      ],
      hasUnsavedChanges: true,
    );
  }

  void delete(String id) {
    final remaining = state.savedMotions
        .where((motion) => motion.id != id)
        .toList(growable: false);
    state = state.copyWith(
      savedMotions: remaining,
      selectedMotionId: state.selectedMotionId == id
          ? remaining.firstOrNull?.id
          : state.selectedMotionId,
      hasUnsavedChanges: true,
    );
  }

  void setMotionName(String value) => state = state.copyWith(motionName: value);

  void setMotionCategory(String value) =>
      state = state.copyWith(motionCategory: value);

  void startRecording() {
    if (state.recording) return;
    _recordingStarted = DateTime.now();
    state = state.copyWith(recording: true, recordedDuration: Duration.zero);
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final started = _recordingStarted;
      if (started == null || !ref.mounted) return;
      state = state.copyWith(
        recordedDuration: DateTime.now().difference(started),
      );
    });
  }

  void stopRecording() {
    if (!state.recording) return;
    final started = _recordingStarted;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    state = state.copyWith(
      recording: false,
      recordedDuration: started == null
          ? state.recordedDuration
          : DateTime.now().difference(started),
    );
  }

  bool saveRecording() {
    if (state.recording ||
        state.motionName.trim().isEmpty ||
        state.recordedDuration == Duration.zero) {
      return false;
    }
    final rawName = state.motionName.trim();
    final name = rawName.endsWith('.json') ? rawName : '$rawName.json';
    final motion = SavedMotion(
      id: 'local:${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      type: state.motionCategory,
      durationSeconds: state.recordedDuration.inMilliseconds / 1000,
      lastUsed: 'Not yet',
      favorite: false,
      source: 'local',
    );
    state = state.copyWith(
      savedMotions: [...state.savedMotions, motion],
      selectedMotionId: motion.id,
      motionName: '',
      recordedDuration: Duration.zero,
      hasUnsavedChanges: false,
      recentActivity: _activity(name, motion.durationSeconds),
    );
    return true;
  }

  Future<bool> sendSelectedToRobot() async {
    final motion = state.selectedMotion;
    if (motion == null) {
      _unavailable('Selected motion');
      return false;
    }
    return playMotion(motion.id);
  }

  Future<bool> importMotions() async {
    final gateway = ref.read(motionCommandGatewayProvider);
    if (gateway == null) return false;
    final imported = await gateway.importMotions();
    state = state.copyWith(savedMotions: [...state.savedMotions, ...imported]);
    return true;
  }

  Future<bool> exportSelected() async {
    final gateway = ref.read(motionCommandGatewayProvider);
    final motion = state.selectedMotion;
    if (gateway == null || motion == null) return false;
    await gateway.exportMotion(motion);
    return true;
  }

  List<MotionActivity> _activity(String title, double duration) => [
    MotionActivity(title, duration, 'Just now'),
    ...state.recentActivity.take(4),
  ];
}

final motionProvider = NotifierProvider<MotionController, MotionState>(
  MotionController.new,
  name: 'MotionProvider',
);

String _motionType(String name, String fallback) {
  final normalized = name.toLowerCase();
  if (normalized.contains('hello')) return 'Greeting';
  if (normalized.contains('dance') || normalized.contains('macarena')) {
    return 'Dance';
  }
  if (normalized.contains('omg')) return 'Reaction';
  if (normalized.contains('ziga')) return 'Gesture';
  return fallback == 'motion-files' ? 'Custom' : fallback;
}

const _quickGestures = [
  QuickGesture('hello', 'Hello', 2.1, 0),
  QuickGesture('hello_hand.json', 'Hand Hello', 0, 1),
  QuickGesture('fake_hello.json', 'Wave', 0, 2),
  QuickGesture('gudbay.json', 'Goodbye', 0, 3),
  QuickGesture('gudbay_solider.json', 'Soldier Goodbye', 0, 4),
  QuickGesture('love.json', 'Love', 0, 5),
  QuickGesture('what.json', 'What?', 0, 6),
  QuickGesture('67.json', '67', 0, 7),
  QuickGesture('kuku.json', 'Peekaboo', 0, 8),
  QuickGesture('heart.json', 'Heart', 0, 9),
];
