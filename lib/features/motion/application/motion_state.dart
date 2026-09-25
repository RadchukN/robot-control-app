import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/models/motion_info.dart';
import 'package:robot_control_app/services/robot_service.dart';

enum MotionPlaybackStatus { idle, playing, paused }

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
  });

  final String id;
  final String name;
  final String type;
  final double durationSeconds;
  final String lastUsed;
  final bool favorite;
  final String source;
  final bool enabled;

  SavedMotion copyWith({String? name, bool? favorite}) => SavedMotion(
    id: id,
    name: name ?? this.name,
    type: type,
    durationSeconds: durationSeconds,
    lastUsed: lastUsed,
    favorite: favorite ?? this.favorite,
    source: source,
    enabled: enabled,
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
  });

  const MotionState.initial()
    : serviceLoading = true,
      serviceOnline = false,
      usingLocalFallback = true,
      savedMotions = _fallbackMotions,
      quickGestures = _quickGestures,
      recentActivity = _initialActivity,
      searchQuery = '',
      typeFilter = 'All types',
      selectedMotionId = 'motion-file:assets:motions:fake_hello',
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
      error = null;

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

  @override
  MotionState build() {
    ref.onDispose(() => _recordingTimer?.cancel());
    Future<void>.microtask(_loadMotions);
    return const MotionState.initial();
  }

  Future<void> _loadMotions() async {
    try {
      final items = await ref.read(robotServiceProvider).motions();
      if (!ref.mounted) return;
      final motions = items
          .where(
            (item) =>
                item.category.toLowerCase() != 'modules' &&
                !item.name.toLowerCase().startsWith('medza.motion.'),
          )
          .map(_fromInfo)
          .toList(growable: false);
      state = state.copyWith(
        serviceLoading: false,
        serviceOnline: true,
        usingLocalFallback: motions.isEmpty,
        savedMotions: motions.isEmpty ? state.savedMotions : motions,
        selectedMotionId: motions.isEmpty
            ? state.selectedMotionId
            : motions.first.id,
        error: null,
      );
    } on Object {
      if (!ref.mounted) return;
      state = state.copyWith(
        serviceLoading: false,
        serviceOnline: false,
        usingLocalFallback: true,
        error: 'Motion service unavailable',
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(serviceLoading: true, error: null);
    await _loadMotions();
  }

  void setSearchQuery(String value) =>
      state = state.copyWith(searchQuery: value);

  void setTypeFilter(String value) => state = state.copyWith(typeFilter: value);

  void selectMotion(String id) => state = state.copyWith(selectedMotionId: id);

  void playMotion(String id) {
    final motion = state.savedMotions
        .where((item) => item.id == id)
        .firstOrNull;
    if (motion == null || !motion.enabled) return;
    state = state.copyWith(
      selectedMotionId: id,
      currentMotionName: motion.name,
      playbackStatus: MotionPlaybackStatus.playing,
      recentActivity: _activity(motion.name, motion.durationSeconds),
    );
  }

  void playGesture(QuickGesture gesture) {
    state = state.copyWith(
      currentMotionName: gesture.name,
      playbackStatus: MotionPlaybackStatus.playing,
      recentActivity: _activity(gesture.name, gesture.durationSeconds),
    );
  }

  void pause() {
    if (state.playbackStatus != MotionPlaybackStatus.playing) return;
    state = state.copyWith(playbackStatus: MotionPlaybackStatus.paused);
  }

  void stop() => state = state.copyWith(
    playbackStatus: MotionPlaybackStatus.idle,
    currentMotionName: null,
  );

  void setPlaybackSpeed(double value) =>
      state = state.copyWith(playbackSpeed: value);

  void toggleLoop() => state = state.copyWith(loop: !state.loop);

  void toggleQueueNext() => state = state.copyWith(queueNext: !state.queueNext);

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
    final gateway = ref.read(motionCommandGatewayProvider);
    final motion = state.selectedMotion;
    if (gateway == null || motion == null) return false;
    await gateway.sendMotion(motion);
    return true;
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

  SavedMotion _fromInfo(MotionInfo info) {
    final fallback = _fallbackMotions
        .where((item) => item.name == info.name)
        .firstOrNull;
    return SavedMotion(
      id: info.id,
      name: info.name,
      type: _motionType(info.name, info.category),
      durationSeconds: info.durationSeconds ?? fallback?.durationSeconds ?? 0,
      lastUsed: fallback?.lastUsed ?? 'Not yet',
      favorite: fallback?.favorite ?? false,
      source: info.source,
      enabled: info.enabled,
    );
  }
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
  QuickGesture('bye', 'Bye', 2.0, 1),
  QuickGesture('kiss', 'Kiss', 1.8, 2),
  QuickGesture('handshake', 'Handshake', 2.6, 3),
  QuickGesture('nod', 'Nod', 1.2, 4),
  QuickGesture('thumbs-up', 'Thumbs up', 1.6, 5),
  QuickGesture('celebrate', 'Celebrate', 4.0, 6),
  QuickGesture('bow', 'Bow', 2.4, 7),
  QuickGesture('clap', 'Clap', 2.2, 8),
  QuickGesture('point-left', 'Point left', 1.8, 9),
  QuickGesture('point-right', 'Point right', 1.8, 10),
];

const _fallbackMotions = [
  SavedMotion(
    id: 'motion-file:assets:motions:fake_hello',
    name: 'fake_hello.json',
    type: 'Greeting',
    durationSeconds: 16.25,
    lastUsed: '2 hours ago',
    favorite: true,
    source: 'assets/motions/fake_hello.json',
  ),
  SavedMotion(
    id: 'motion-file:assets:motions:macarena',
    name: 'macarena.json',
    type: 'Dance',
    durationSeconds: 36.85,
    lastUsed: '1 day ago',
    favorite: false,
    source: 'assets/motions/macarena.json',
  ),
  SavedMotion(
    id: 'motion-file:assets:motions:max_dance',
    name: 'max_dance.json',
    type: 'Dance',
    durationSeconds: 36.87,
    lastUsed: '3 hours ago',
    favorite: true,
    source: 'assets/motions/max_dance.json',
  ),
  SavedMotion(
    id: 'motion-file:assets:motions:trump_dance',
    name: 'trump_dance.json',
    type: 'Dance',
    durationSeconds: 40.48,
    lastUsed: '2 days ago',
    favorite: false,
    source: 'assets/motions/trump_dance.json',
  ),
  SavedMotion(
    id: 'motion-file:assets:motions:omg',
    name: 'omg.json',
    type: 'Reaction',
    durationSeconds: 10,
    lastUsed: '5 hours ago',
    favorite: false,
    source: 'assets/motions/omg.json',
  ),
  SavedMotion(
    id: 'motion-file:assets:motions:ziga',
    name: 'ziga.json',
    type: 'Gesture',
    durationSeconds: 11.08,
    lastUsed: '1 day ago',
    favorite: true,
    source: 'assets/motions/ziga.json',
  ),
  SavedMotion(
    id: 'motion-file:assets:motions:kiril',
    name: 'kiril.json',
    type: 'Custom',
    durationSeconds: 29.75,
    lastUsed: '3 days ago',
    favorite: false,
    source: 'assets/motions/kiril.json',
  ),
  SavedMotion(
    id: 'motion-file:assets:motions:67',
    name: '67.json',
    type: 'Custom',
    durationSeconds: 25.13,
    lastUsed: '1 week ago',
    favorite: false,
    source: 'assets/motions/67.json',
  ),
  SavedMotion(
    id: 'motion-file:assets:motions:fuck',
    name: 'fuck.json',
    type: 'Custom',
    durationSeconds: 28.23,
    lastUsed: 'Not yet',
    favorite: false,
    source: 'assets/motions/fuck.json',
  ),
];

const _initialActivity = [
  MotionActivity('fake_hello.json', 16.25, '2 hours ago'),
  MotionActivity('max_dance.json', 36.87, '3 hours ago'),
  MotionActivity('omg.json', 10, '5 hours ago'),
  MotionActivity('ziga.json', 11.08, '1 day ago'),
  MotionActivity('macarena.json', 36.85, '1 day ago'),
];
