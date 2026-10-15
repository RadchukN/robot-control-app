import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot_control_app/core/theme/app_spacing.dart';
import 'package:robot_control_app/features/vision/application/vision_state.dart';

const _ink = Color(0xFF252A42);
const _panelInk = Color(0xFF333B57);
const _body = Color(0xFF3F4661);
const _muted = Color(0xFF68708A);
const _purple = Color(0xFF8526ED);
const _success = Color(0xFF1AA86B);
const _warning = Color(0xFFB26B14);
const _critical = Color(0xFFBA1A1A);
const _cameraBackground = Color(0xFFE8EDFA);
const _outline = Color(0xA6D1D6EB);

typedef VisionStreamBuilder =
    Widget Function(BuildContext context, VisionState state);

/// Override this from the approved media transport layer when live frames are
/// available. HTTP/API placeholders must not be used for high-bandwidth video.
final visionStreamBuilderProvider = Provider<VisionStreamBuilder?>(
  (ref) => null,
  name: 'VisionStreamBuilderProvider',
);

class VisionScreen extends ConsumerWidget {
  const VisionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(visionControllerProvider);
    final capabilities = ref.watch(visionModeCapabilitiesProvider);
    final controller = ref.read(visionControllerProvider.notifier);

    return DecoratedBox(
      key: const Key('vision-screen'),
      decoration: const BoxDecoration(
        color: Color(0xFFF6F9FF),
        gradient: LinearGradient(
          colors: [Color(0xFFF7FAFF), Color(0xFFF2F0FF)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = switch (constraints.maxWidth) {
            < 600 => _VisionLayout.compact,
            < 840 => _VisionLayout.medium,
            < 1500 => _VisionLayout.expanded,
            _ => _VisionLayout.wide,
          };
          final outerPadding = switch (layout) {
            _VisionLayout.compact => 16.0,
            _VisionLayout.medium => 24.0,
            _ => 0.0,
          };
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: outerPadding),
            child: _VisionWorkspace(
              state: state,
              capabilities: capabilities,
              layout: layout,
              onModeSelected: controller.selectMode,
              onDetectionSelected: controller.selectDetection,
              onReconnect: controller.reconnect,
              onRetry: controller.retry,
            ),
          );
        },
      ),
    );
  }
}

enum _VisionLayout { compact, medium, expanded, wide }

class _VisionWorkspace extends StatelessWidget {
  const _VisionWorkspace({
    required this.state,
    required this.capabilities,
    required this.layout,
    required this.onModeSelected,
    required this.onDetectionSelected,
    required this.onReconnect,
    required this.onRetry,
  });

  final VisionState state;
  final Set<VisionMode> capabilities;
  final _VisionLayout layout;
  final bool Function(VisionMode mode) onModeSelected;
  final ValueChanged<VisionDetection?> onDetectionSelected;
  final VoidCallback onReconnect;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final compact = layout == _VisionLayout.compact;
    final padding = compact ? 12.0 : 20.0;
    final gap = compact ? 10.0 : 12.0;
    return ClipRect(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _VisionHeader(state: state, compact: compact),
            SizedBox(height: gap),
            _CameraModeSelector(
              activeMode: state.activeMode,
              capabilities: capabilities,
              compact: compact,
              onSelected: onModeSelected,
            ),
            SizedBox(height: gap),
            if (compact)
              _CompactVisionBody(
                state: state,
                onDetectionSelected: onDetectionSelected,
                onReconnect: onReconnect,
                onRetry: onRetry,
              )
            else if (layout == _VisionLayout.medium)
              _MediumVisionBody(
                state: state,
                onDetectionSelected: onDetectionSelected,
                onReconnect: onReconnect,
                onRetry: onRetry,
              )
            else
              _ExpandedVisionBody(
                state: state,
                wide: layout == _VisionLayout.wide,
                onDetectionSelected: onDetectionSelected,
                onReconnect: onReconnect,
                onRetry: onRetry,
              ),
          ],
        ),
      ),
    );
  }
}

class _VisionHeader extends StatelessWidget {
  const _VisionHeader({required this.state, required this.compact});

  final VisionState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final badge = _headerBadge(state);
    return SizedBox(
      height: compact ? 45 : 51,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vision',
                  style: _visionText(
                    compact ? 20 : 24,
                    height: 1.4,
                    weight: FontWeight.w600,
                    color: compact ? _panelInk : _ink,
                  ),
                ),
                Text(
                  _headerSubtitle(state),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _visionText(11, height: 1.4, color: _muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _Pill(
            label: badge.label,
            foreground: badge.foreground,
            background: badge.background,
          ),
        ],
      ),
    );
  }
}

String _headerSubtitle(VisionState state) {
  if (state.recording) return 'Recording · Front Camera · Gustav';
  return switch (state.connectionStatus) {
    VisionConnectionStatus.connecting => 'Connecting · G1 camera · Gustav',
    VisionConnectionStatus.connected => switch (state.streamStatus) {
      VisionStreamStatus.live => 'Live perception · Front Camera · Gustav',
      VisionStreamStatus.waiting => 'Loading camera · Front Camera · Gustav',
      VisionStreamStatus.paused => 'Paused · Front Camera · Gustav',
      VisionStreamStatus.unavailable =>
        'Camera unavailable · Front Camera · Gustav',
    },
    VisionConnectionStatus.disconnected =>
      'Disconnected · Front Camera · Gustav',
  };
}

({String label, Color foreground, Color background}) _headerBadge(
  VisionState state,
) {
  if (state.error != null) {
    return (
      label: 'Camera error',
      foreground: _critical,
      background: const Color(0xFFFFE8E6),
    );
  }
  if (state.connectionStatus == VisionConnectionStatus.connecting) {
    return (
      label: 'Connecting',
      foreground: _purple,
      background: const Color(0xFFF0E6FF),
    );
  }
  if (state.connectionStatus == VisionConnectionStatus.disconnected) {
    return (
      label: 'Disconnected',
      foreground: _muted,
      background: const Color(0xFFE9ECF4),
    );
  }
  if (state.perceptionStatus == VisionPerceptionStatus.degraded) {
    return (
      label: 'Degraded',
      foreground: _warning,
      background: const Color(0xFFFFF2D6),
    );
  }
  return (
    label: state.perceptionStatus == VisionPerceptionStatus.active
        ? 'AI perception active'
        : 'Camera connected',
    foreground: _success,
    background: const Color(0xFFE0FFF0),
  );
}

class _CameraModeSelector extends StatelessWidget {
  const _CameraModeSelector({
    required this.activeMode,
    required this.capabilities,
    required this.compact,
    required this.onSelected,
  });

  final VisionMode activeMode;
  final Set<VisionMode> capabilities;
  final bool compact;
  final bool Function(VisionMode mode) onSelected;

  @override
  Widget build(BuildContext context) {
    final modes = compact
        ? const [VisionMode.rgb, VisionMode.depth, VisionMode.aiOverlay]
        : VisionMode.values;
    return Container(
      height: 48,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: modes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final mode = modes[index];
          final enabled = capabilities.contains(mode);
          return _ModeButton(
            mode: mode,
            compact: compact,
            selected: mode == activeMode,
            enabled: enabled,
            onTap: enabled ? () => onSelected(mode) : null,
          );
        },
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.mode,
    required this.compact,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final VisionMode mode;
  final bool compact;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: enabled
          ? _modeLabel(mode, compact)
          : 'Unavailable for this camera',
      child: Material(
        color: selected
            ? _purple.withValues(alpha: 0.9)
            : const Color(0xE6F7F7FF),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          hoverColor: selected ? Colors.white12 : const Color(0xFFEDE5FF),
          child: Container(
            constraints: const BoxConstraints(minWidth: 35),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            alignment: Alignment.center,
            child: Text(
              _modeLabel(mode, compact),
              style: _visionText(
                11,
                height: 1.4,
                weight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : enabled
                    ? _muted
                    : _muted.withValues(alpha: 0.42),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _modeLabel(VisionMode mode, bool compact) => switch (mode) {
  VisionMode.rgb => 'RGB',
  VisionMode.depth => 'Depth',
  VisionMode.thermal => 'Thermal',
  VisionMode.segmentation => 'Segmentation',
  VisionMode.aiOverlay => compact ? 'AI' : 'AI Overlay',
  VisionMode.pointCloud => 'Point Cloud',
};

class _ExpandedVisionBody extends StatelessWidget {
  const _ExpandedVisionBody({
    required this.state,
    required this.wide,
    required this.onDetectionSelected,
    required this.onReconnect,
    required this.onRetry,
  });

  final VisionState state;
  final bool wide;
  final ValueChanged<VisionDetection?> onDetectionSelected;
  final VoidCallback onReconnect;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cameraHeight = wide ? 650.0 : 545.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 46),
            child: _PerceptionColumn(
              state: state,
              cameraHeight: cameraHeight,
              timelineHeight: 82,
              compactControls: false,
              onDetectionSelected: onDetectionSelected,
              onReconnect: onReconnect,
              onRetry: onRetry,
            ),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: wide ? 348 : 308,
          height: wide ? 837 : 722,
          child: _VisionInspector(state: state),
        ),
      ],
    );
  }
}

class _MediumVisionBody extends StatelessWidget {
  const _MediumVisionBody({
    required this.state,
    required this.onDetectionSelected,
    required this.onReconnect,
    required this.onRetry,
  });

  final VisionState state;
  final ValueChanged<VisionDetection?> onDetectionSelected;
  final VoidCallback onReconnect;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 488,
          child: _CameraViewport(
            state: state,
            height: 470,
            compactControls: false,
            onDetectionSelected: onDetectionSelected,
            onReconnect: onReconnect,
            onRetry: onRetry,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 75,
          width: double.infinity,
          child: _SceneInsight(state: state),
        ),
        const SizedBox(height: 10),
        const SizedBox(width: 488, height: 82, child: _VisionTimeline()),
        const SizedBox(height: 10),
        SizedBox(
          width: 219,
          height: 71,
          child: _SelectionSummary(detection: state.selectedObject),
        ),
      ],
    );
  }
}

class _CompactVisionBody extends StatelessWidget {
  const _CompactVisionBody({
    required this.state,
    required this.onDetectionSelected,
    required this.onReconnect,
    required this.onRetry,
  });

  final VisionState state;
  final ValueChanged<VisionDetection?> onDetectionSelected;
  final VoidCallback onReconnect;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CameraViewport(
          state: state,
          height: 290,
          compactControls: true,
          onDetectionSelected: onDetectionSelected,
          onReconnect: onReconnect,
          onRetry: onRetry,
        ),
        const SizedBox(height: 10),
        SizedBox(height: 84, child: _SceneInsight(state: state, compact: true)),
        const SizedBox(height: 10),
        const SizedBox(height: 70, child: _VisionTimeline(compact: true)),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: _SelectionSummary(
            detection: state.selectedObject,
            compact: true,
          ),
        ),
      ],
    );
  }
}

class _PerceptionColumn extends StatelessWidget {
  const _PerceptionColumn({
    required this.state,
    required this.cameraHeight,
    required this.timelineHeight,
    required this.compactControls,
    required this.onDetectionSelected,
    required this.onReconnect,
    required this.onRetry,
  });

  final VisionState state;
  final double cameraHeight;
  final double timelineHeight;
  final bool compactControls;
  final ValueChanged<VisionDetection?> onDetectionSelected;
  final VoidCallback onReconnect;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CameraViewport(
          state: state,
          height: cameraHeight,
          compactControls: compactControls,
          onDetectionSelected: onDetectionSelected,
          onReconnect: onReconnect,
          onRetry: onRetry,
        ),
        const SizedBox(height: 10),
        SizedBox(height: 75, child: _SceneInsight(state: state)),
        const SizedBox(height: 10),
        SizedBox(height: timelineHeight, child: const _VisionTimeline()),
      ],
    );
  }
}

class _CameraViewport extends ConsumerWidget {
  const _CameraViewport({
    required this.state,
    required this.height,
    required this.compactControls,
    required this.onDetectionSelected,
    required this.onReconnect,
    required this.onRetry,
  });

  final VisionState state;
  final double height;
  final bool compactControls;
  final ValueChanged<VisionDetection?> onDetectionSelected;
  final VoidCallback onReconnect;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controlsEnabled = state.streamStatus == VisionStreamStatus.live;
    final controlCapabilities = ref.watch(visionControlCapabilitiesProvider);
    final streamBuilder = ref.watch(visionStreamBuilderProvider);
    return Container(
      key: const Key('vision-camera-viewport'),
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _cameraBackground,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF2F5FF), Color(0xFFDDE5F7)],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x29332E7A),
            blurRadius: 34,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (state.streamStatus == VisionStreamStatus.live &&
              streamBuilder != null)
            streamBuilder(context, state)
          else
            _CameraEmptyState(
              state: state,
              onReconnect: onReconnect,
              onRetry: onRetry,
            ),
          if (state.streamStatus == VisionStreamStatus.live &&
              state.detections.isNotEmpty)
            _DetectionLayer(
              detections: state.detections,
              selected: state.selectedObject,
              onSelected: onDetectionSelected,
            ),
          Positioned(
            left: 14,
            top: 14,
            child: _Pill(
              label: _viewportStatus(state),
              foreground: _viewportStatusColor(state),
              background: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _CameraControls(
                compact: compactControls,
                enabled: controlsEnabled,
                recording: state.recording,
                capabilities: controlCapabilities,
                onInvoked: ref
                    .read(visionControllerProvider.notifier)
                    .invokeControl,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _viewportStatus(VisionState state) {
  if (state.error != null ||
      state.streamStatus == VisionStreamStatus.unavailable) {
    return 'Camera unavailable';
  }
  return switch (state.connectionStatus) {
    VisionConnectionStatus.connecting => 'Connecting · Front Camera',
    VisionConnectionStatus.disconnected => 'Offline · Front Camera',
    VisionConnectionStatus.connected => switch (state.streamStatus) {
      VisionStreamStatus.live =>
        state.recording
            ? '● Recording · Front Camera'
            : '● Live · Front Camera',
      VisionStreamStatus.paused => 'Paused · Front Camera',
      VisionStreamStatus.waiting => 'Loading · Front Camera',
      VisionStreamStatus.unavailable => 'Camera unavailable',
    },
  };
}

Color _viewportStatusColor(VisionState state) {
  if (state.error != null ||
      state.streamStatus == VisionStreamStatus.unavailable) {
    return _critical;
  }
  if (state.connectionStatus == VisionConnectionStatus.disconnected) {
    return _muted;
  }
  if (state.streamStatus == VisionStreamStatus.live) return _success;
  return _purple;
}

class _CameraEmptyState extends StatelessWidget {
  const _CameraEmptyState({
    required this.state,
    required this.onReconnect,
    required this.onRetry,
  });

  final VisionState state;
  final VoidCallback onReconnect;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final copy = _cameraCopy(state);
    final action = state.error != null
        ? ('Retry', onRetry)
        : state.connectionStatus == VisionConnectionStatus.disconnected
        ? ('Reconnect', onReconnect)
        : null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 56, 24, 72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x17332E7A),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                state.error == null
                    ? Icons.videocam_outlined
                    : Icons.videocam_off_outlined,
                color: state.error == null ? _purple : _critical,
                size: 30,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              copy.title,
              textAlign: TextAlign.center,
              style: _visionText(
                16,
                height: 1.4,
                weight: FontWeight.w600,
                color: _panelInk,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              copy.subtitle,
              textAlign: TextAlign.center,
              style: _visionText(12, height: 1.4, color: _muted),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (action case (final label, final callback))
              _ActionPill(label: label, onTap: callback)
            else if (state.connectionStatus ==
                    VisionConnectionStatus.connecting ||
                state.streamStatus == VisionStreamStatus.waiting)
              const SizedBox(
                width: 116,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: _purple,
                  backgroundColor: Color(0x54FFFFFF),
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

({String title, String subtitle}) _cameraCopy(VisionState state) {
  if (state.error != null) {
    return (
      title: 'Camera feed unavailable',
      subtitle: 'Unable to load the G1 camera stream.',
    );
  }
  if (state.connectionStatus == VisionConnectionStatus.disconnected) {
    return (
      title: 'Camera disconnected',
      subtitle: 'Reconnect to continue live perception.',
    );
  }
  if (state.connectionStatus == VisionConnectionStatus.connecting) {
    return (title: 'Camera feed', subtitle: 'Connecting to G1 camera...');
  }
  return switch (state.streamStatus) {
    VisionStreamStatus.waiting => (
      title: 'Camera feed',
      subtitle: 'Loading camera stream...',
    ),
    VisionStreamStatus.paused => (
      title: 'Camera paused',
      subtitle: 'Waiting for the stream to resume.',
    ),
    VisionStreamStatus.unavailable => (
      title: 'Camera feed unavailable',
      subtitle: 'Waiting for G1 camera stream...',
    ),
    VisionStreamStatus.live => (
      title: 'Camera feed',
      subtitle: 'Waiting for live video frames...',
    ),
  };
}

class _DetectionLayer extends StatelessWidget {
  const _DetectionLayer({
    required this.detections,
    required this.selected,
    required this.onSelected,
  });

  final List<VisionDetection> detections;
  final VisionDetection? selected;
  final ValueChanged<VisionDetection?> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            for (final detection in detections)
              Positioned(
                left: detection.normalizedX.clamp(0, 1) * constraints.maxWidth,
                top: detection.normalizedY.clamp(0, 1) * constraints.maxHeight,
                width:
                    detection.normalizedWidth.clamp(0, 1) *
                    constraints.maxWidth,
                height:
                    detection.normalizedHeight.clamp(0, 1) *
                    constraints.maxHeight,
                child: _DetectionBox(
                  detection: detection,
                  selected: selected?.id == detection.id,
                  onTap: () => onSelected(detection),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DetectionBox extends StatelessWidget {
  const _DetectionBox({
    required this.detection,
    required this.selected,
    required this.onTap,
  });

  final VisionDetection detection;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _purple : _success;
    final confidence = detection.confidence == null
        ? ''
        : ' · ${(detection.confidence! * 100).round()}%';
    return Semantics(
      button: true,
      label: '${detection.label}$confidence',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.topLeft,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: selected ? 2 : 1.5),
          ),
          child: Transform.translate(
            offset: const Offset(-1, -23),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                '${detection.label}$confidence',
                maxLines: 1,
                style: _visionText(
                  9,
                  height: 1.3,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraControls extends StatelessWidget {
  const _CameraControls({
    required this.compact,
    required this.enabled,
    required this.recording,
    required this.capabilities,
    required this.onInvoked,
  });

  final bool compact;
  final bool enabled;
  final bool recording;
  final Set<VisionControl> capabilities;
  final Future<bool> Function(VisionControl control) onInvoked;

  @override
  Widget build(BuildContext context) {
    final controls = compact
        ? const [
            (VisionControl.zoom, 'Zoom'),
            (VisionControl.snapshot, 'Shot'),
            (VisionControl.fullscreen, 'Full'),
          ]
        : [
            const (VisionControl.zoom, 'Zoom'),
            const (VisionControl.exposure, 'Exposure'),
            const (VisionControl.focus, 'Focus'),
            const (VisionControl.snapshot, 'Snapshot'),
            (VisionControl.record, recording ? 'Stop' : 'Record'),
            const (VisionControl.fullscreen, 'Fullscreen'),
          ];
    return Container(
      height: 47,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: controls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final control = controls[index];
          final available = enabled && capabilities.contains(control.$1);
          return _ActionPill(
            label: control.$2,
            onTap: available ? () => onInvoked(control.$1) : null,
            compact: true,
          );
        },
      ),
    );
  }
}

class _SceneInsight extends StatelessWidget {
  const _SceneInsight({required this.state, this.compact = false});

  final VisionState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasAssessment = state.sceneAssessment?.trim().isNotEmpty ?? false;
    final title = hasAssessment
        ? state.sceneAssessment!
        : state.perceptionStatus == VisionPerceptionStatus.active
        ? 'Analyzing environment...'
        : 'Waiting for perception data...';
    final detail = state.detections.isEmpty
        ? 'Scene analysis will appear when perception data is available.'
        : '${state.detections.length} detected ${state.detections.length == 1 ? 'object' : 'objects'}';
    return _GlassPanel(
      padding: EdgeInsets.all(compact ? 12 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _visionText(
              compact ? 14 : 15,
              height: 1.4,
              weight: FontWeight.w600,
              color: hasAssessment ? _success : _purple,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            maxLines: compact ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: _visionText(11, height: 1.4, color: _muted),
          ),
        ],
      ),
    );
  }
}

class _VisionTimeline extends StatelessWidget {
  const _VisionTimeline({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, size: compact ? 16 : 18, color: _muted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Waiting for camera events...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _visionText(11, height: 1.4, color: _muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({required this.detection, this.compact = false});

  final VisionDetection? detection;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final title = detection == null
        ? 'No object selected'
        : '${compact ? 'Selected' : 'Selected ·'} ${detection!.label}';
    final details = detection == null ? null : _detectionSummary(detection!);
    return _GlassPanel(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 10 : 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: _visionText(
              compact ? 12 : 14,
              height: 1.4,
              weight: FontWeight.w600,
              color: _panelInk,
            ),
          ),
          if (details != null) ...[
            const SizedBox(height: 8),
            Text(details, style: _visionText(11, height: 1.4, color: _muted)),
          ],
        ],
      ),
    );
  }
}

String _detectionSummary(VisionDetection detection) {
  final values = <String>[];
  if (detection.confidence != null) {
    values.add('${(detection.confidence! * 100).round()}%');
  }
  if (detection.distanceMeters != null) {
    values.add('${detection.distanceMeters!.toStringAsFixed(1)} m');
  }
  if (detection.movement != null) {
    values.add(_movementLabel(detection.movement!));
  }
  return values.isEmpty ? 'Detection details unavailable' : values.join(' · ');
}

String _movementLabel(VisionObjectMovement movement) => switch (movement) {
  VisionObjectMovement.stationary => 'Stationary',
  VisionObjectMovement.approaching => 'Approaching',
  VisionObjectMovement.departing => 'Departing',
  VisionObjectMovement.lateral => 'Lateral',
  VisionObjectMovement.unknown => 'Unknown',
};

class _VisionInspector extends StatelessWidget {
  const _VisionInspector({required this.state});

  final VisionState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.98)),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A292E6B),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Scene inspector',
            style: _visionText(
              18,
              height: 1.4,
              weight: FontWeight.w600,
              color: _panelInk,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 143,
            child: _InspectorSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Pill(
                    label: state.sceneAssessment == null
                        ? 'Waiting'
                        : 'Perception data',
                    foreground: state.sceneAssessment == null
                        ? _purple
                        : _success,
                    background: state.sceneAssessment == null
                        ? const Color(0xE6F0E6FF)
                        : const Color(0xE6E0FFF0),
                    expanded: true,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Scene understanding',
                    style: _visionText(
                      13,
                      height: 1.4,
                      weight: FontWeight.w600,
                      color: _purple,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    state.sceneAssessment ?? 'No scene data yet',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: _visionText(12, height: 1.4, color: _muted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _InspectorSection(
            title: 'Camera',
            rows: [
              ('Source', state.cameraInfo?.source ?? 'Not connected'),
              ('Resolution', state.cameraInfo?.resolution ?? '—'),
              ('FPS', _fps(state.cameraInfo?.framesPerSecond)),
              ('Latency', _latency(state.cameraInfo?.latency)),
            ],
          ),
          const SizedBox(height: 10),
          _InspectorSection(
            title: 'AI Perception',
            rows: [
              ('Model', state.perceptionModel ?? '—'),
              ('Inference', _latency(state.inferenceLatency)),
              (
                'Tracking',
                state.perceptionStatus == VisionPerceptionStatus.active
                    ? 'Active'
                    : '—',
              ),
              (
                'Objects',
                state.detections.isEmpty ? '—' : '${state.detections.length}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 151,
            child: _SelectedObjectSection(detection: state.selectedObject),
          ),
        ],
      ),
    );
  }
}

String _fps(double? value) => value == null ? '—' : '${value.round()} fps';

String _latency(Duration? value) =>
    value == null ? '—' : '${value.inMilliseconds} ms';

class _InspectorSection extends StatelessWidget {
  const _InspectorSection({this.title, this.rows = const [], this.child});

  final String? title;
  final List<(String, String)> rows;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        border: Border.all(color: _outline),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1233296B),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child:
          child ??
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) ...[
                Text(
                  title!,
                  style: _visionText(
                    13,
                    height: 1.4,
                    weight: FontWeight.w600,
                    color: _panelInk,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              for (var index = 0; index < rows.length; index++) ...[
                _InspectorRow(label: rows[index].$1, value: rows[index].$2),
                if (index != rows.length - 1) const SizedBox(height: 6),
              ],
            ],
          ),
    );
  }
}

class _InspectorRow extends StatelessWidget {
  const _InspectorRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _visionText(12, height: 1.4, color: _muted),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: _visionText(
                12,
                height: 1.4,
                weight: FontWeight.w500,
                color: _body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedObjectSection extends StatelessWidget {
  const _SelectedObjectSection({required this.detection});

  final VisionDetection? detection;

  @override
  Widget build(BuildContext context) {
    if (detection == null) {
      return const _InspectorSection(
        title: 'Selected object',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected object',
              style: TextStyle(
                color: _panelInk,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'No object selected',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      );
    }
    return _InspectorSection(
      title: 'Selected object',
      rows: [
        ('Type', detection!.label),
        (
          'Distance',
          detection!.distanceMeters == null
              ? '—'
              : '${detection!.distanceMeters!.toStringAsFixed(1)} m',
        ),
        (
          'Confidence',
          detection!.confidence == null
              ? '—'
              : '${(detection!.confidence! * 100).round()}%',
        ),
        (
          'Movement',
          detection!.movement == null
              ? '—'
              : _movementLabel(detection!.movement!),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.foreground,
    required this.background,
    this.expanded = false,
  });

  final String label;
  final Color foreground;
  final Color background;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      height: 31,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      alignment: expanded ? Alignment.centerLeft : Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _visionText(
          11,
          height: 1.4,
          weight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
    return expanded
        ? SizedBox(width: double.infinity, child: content)
        : content;
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.46 : 1,
      child: Material(
        color: const Color(0xE6F7F5FF),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          hoverColor: const Color(0xFFE9DEFF),
          child: Container(
            height: compact ? 31 : 36,
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              style: _visionText(
                11,
                height: 1.4,
                weight: FontWeight.w600,
                color: _purple,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A383380),
            blurRadius: 14,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

TextStyle _visionText(
  double size, {
  required double height,
  required Color color,
  FontWeight weight = FontWeight.w400,
}) {
  return TextStyle(
    fontSize: size,
    height: height,
    color: color,
    fontWeight: weight,
    letterSpacing: 0,
  );
}
