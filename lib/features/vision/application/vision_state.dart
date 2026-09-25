import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum VisionConnectionStatus { connecting, connected, disconnected }

enum VisionStreamStatus { waiting, live, paused, unavailable }

enum VisionMode { rgb, depth, thermal, segmentation, aiOverlay, pointCloud }

enum VisionControl { zoom, exposure, focus, snapshot, record, fullscreen }

enum VisionPerceptionStatus { waiting, active, degraded, unavailable }

@immutable
class VisionCameraInfo {
  const VisionCameraInfo({
    required this.source,
    required this.name,
    this.resolution,
    this.framesPerSecond,
    this.latency,
  });

  final String source;
  final String name;
  final String? resolution;
  final double? framesPerSecond;
  final Duration? latency;
}

enum VisionObjectMovement {
  stationary,
  approaching,
  departing,
  lateral,
  unknown,
}

@immutable
class VisionDetection {
  const VisionDetection({
    required this.id,
    required this.label,
    required this.normalizedX,
    required this.normalizedY,
    required this.normalizedWidth,
    required this.normalizedHeight,
    this.confidence,
    this.distanceMeters,
    this.movement,
  });

  final String id;
  final String label;
  final double normalizedX;
  final double normalizedY;
  final double normalizedWidth;
  final double normalizedHeight;
  final double? confidence;
  final double? distanceMeters;
  final VisionObjectMovement? movement;
}

const _notProvided = Object();

@immutable
class VisionState {
  const VisionState({
    required this.connectionStatus,
    required this.streamStatus,
    required this.activeMode,
    required this.cameraInfo,
    required this.detections,
    required this.selectedObject,
    required this.perceptionStatus,
    required this.sceneAssessment,
    required this.perceptionModel,
    required this.inferenceLatency,
    required this.recording,
    required this.error,
  });

  const VisionState.initial()
    : connectionStatus = VisionConnectionStatus.connecting,
      streamStatus = VisionStreamStatus.waiting,
      activeMode = VisionMode.rgb,
      cameraInfo = null,
      detections = const [],
      selectedObject = null,
      perceptionStatus = VisionPerceptionStatus.waiting,
      sceneAssessment = null,
      perceptionModel = null,
      inferenceLatency = null,
      recording = false,
      error = null;

  final VisionConnectionStatus connectionStatus;
  final VisionStreamStatus streamStatus;
  final VisionMode activeMode;
  final VisionCameraInfo? cameraInfo;
  final List<VisionDetection> detections;
  final VisionDetection? selectedObject;
  final VisionPerceptionStatus perceptionStatus;
  final String? sceneAssessment;
  final String? perceptionModel;
  final Duration? inferenceLatency;
  final bool recording;
  final Object? error;

  VisionState copyWith({
    VisionConnectionStatus? connectionStatus,
    VisionStreamStatus? streamStatus,
    VisionMode? activeMode,
    Object? cameraInfo = _notProvided,
    List<VisionDetection>? detections,
    Object? selectedObject = _notProvided,
    VisionPerceptionStatus? perceptionStatus,
    Object? sceneAssessment = _notProvided,
    Object? perceptionModel = _notProvided,
    Object? inferenceLatency = _notProvided,
    bool? recording,
    Object? error = _notProvided,
  }) => VisionState(
    connectionStatus: connectionStatus ?? this.connectionStatus,
    streamStatus: streamStatus ?? this.streamStatus,
    activeMode: activeMode ?? this.activeMode,
    cameraInfo: identical(cameraInfo, _notProvided)
        ? this.cameraInfo
        : cameraInfo as VisionCameraInfo?,
    detections: detections ?? this.detections,
    selectedObject: identical(selectedObject, _notProvided)
        ? this.selectedObject
        : selectedObject as VisionDetection?,
    perceptionStatus: perceptionStatus ?? this.perceptionStatus,
    sceneAssessment: identical(sceneAssessment, _notProvided)
        ? this.sceneAssessment
        : sceneAssessment as String?,
    perceptionModel: identical(perceptionModel, _notProvided)
        ? this.perceptionModel
        : perceptionModel as String?,
    inferenceLatency: identical(inferenceLatency, _notProvided)
        ? this.inferenceLatency
        : inferenceLatency as Duration?,
    recording: recording ?? this.recording,
    error: identical(error, _notProvided) ? this.error : error,
  );
}

abstract interface class VisionGateway {
  Future<VisionState> reconnect();

  Future<VisionState> retry();

  Future<void> invokeControl(VisionControl control);
}

final visionGatewayProvider = Provider<VisionGateway?>(
  (ref) => null,
  name: 'VisionGatewayProvider',
);

final visionModeCapabilitiesProvider = Provider<Set<VisionMode>>(
  (ref) => const {VisionMode.rgb},
  name: 'VisionModeCapabilitiesProvider',
);

final visionControlCapabilitiesProvider = Provider<Set<VisionControl>>(
  (ref) => const {},
  name: 'VisionControlCapabilitiesProvider',
);

class VisionController extends Notifier<VisionState> {
  @override
  VisionState build() => const VisionState.initial();

  bool selectMode(VisionMode mode) {
    final supportedModes = ref.read(visionModeCapabilitiesProvider);
    if (!supportedModes.contains(mode)) {
      return false;
    }
    state = state.copyWith(activeMode: mode);
    return true;
  }

  void selectDetection(VisionDetection? detection) {
    state = state.copyWith(selectedObject: detection);
  }

  Future<void> reconnect() => _request((gateway) => gateway.reconnect());

  Future<void> retry() => _request((gateway) => gateway.retry());

  Future<bool> invokeControl(VisionControl control) async {
    final supportedControls = ref.read(visionControlCapabilitiesProvider);
    final gateway = ref.read(visionGatewayProvider);
    if (!supportedControls.contains(control) || gateway == null) return false;

    try {
      await gateway.invokeControl(control);
      return true;
    } on Object catch (error) {
      state = state.copyWith(error: error);
      return false;
    }
  }

  Future<void> _request(
    Future<VisionState> Function(VisionGateway gateway) request,
  ) async {
    state = state.copyWith(
      connectionStatus: VisionConnectionStatus.connecting,
      streamStatus: VisionStreamStatus.waiting,
      error: null,
    );

    final gateway = ref.read(visionGatewayProvider);
    if (gateway == null) {
      return;
    }

    try {
      state = await request(gateway);
    } on Object catch (error) {
      state = state.copyWith(
        connectionStatus: VisionConnectionStatus.disconnected,
        streamStatus: VisionStreamStatus.unavailable,
        perceptionStatus: VisionPerceptionStatus.unavailable,
        error: error,
      );
    }
  }
}

final visionControllerProvider =
    NotifierProvider<VisionController, VisionState>(
      VisionController.new,
      name: 'VisionControllerProvider',
    );
