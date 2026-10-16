part of 'motion_screen.dart';

/// Phones on their side: the catalog scrolls on the left while playback
/// status, progress, Play and Stop stay pinned on the right.
class _LandscapeMotionLayout extends StatelessWidget {
  const _LandscapeMotionLayout({
    required this.state,
    required this.controller,
    required this.width,
  });

  final MotionState state;
  final MotionController controller;
  final double width;

  @override
  Widget build(BuildContext context) {
    final dockWidth = width >= 700 ? 248.0 : 216.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const Key('motion-landscape-scroll'),
            padding: const EdgeInsets.fromLTRB(12, 12, 6, 16),
            child: _MotionPage(
              state: state,
              controller: controller,
              width: width - dockWidth,
            ),
          ),
        ),
        SizedBox(
          width: dockWidth,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 12, 12, 12),
            child: _LandscapePlaybackDock(state: state, controller: controller),
          ),
        ),
      ],
    );
  }
}

class _LandscapePlaybackDock extends StatelessWidget {
  const _LandscapePlaybackDock({required this.state, required this.controller});

  final MotionState state;
  final MotionController controller;

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedMotion;
    final status = state.playbackStatus;
    // A dry run and a command the robot is executing must never look alike.
    final (String, IconData, Color)? mode = switch (status) {
      MotionPlaybackStatus.simulated => (
        'Dry run · robot did not move',
        Icons.science_outlined,
        _amber,
      ),
      MotionPlaybackStatus.sending ||
      MotionPlaybackStatus.playing ||
      MotionPlaybackStatus.stopping => (
        'Physical motion on robot',
        Icons.precision_manufacturing_outlined,
        _red,
      ),
      _ => null,
    };
    return _MotionPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        key: const Key('motion-playback-dock'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SectionHeading(
                    icon: Icons.play_arrow_rounded,
                    title: 'Playback',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selected?.name ?? 'No motion selected',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _motionText(
                      12,
                      height: 16 / 12,
                      weight: FontWeight.w600,
                      color: selected == null ? _muted : _ink,
                    ),
                  ),
                  if (mode != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      key: Key(
                        status == MotionPlaybackStatus.simulated
                            ? 'motion-dry-run-badge'
                            : 'motion-physical-badge',
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: mode.$3.withValues(alpha: 0.1),
                        border: Border.all(
                          color: mode.$3.withValues(alpha: 0.35),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(mode.$2, size: 15, color: mode.$3),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              mode.$1,
                              style: _motionText(
                                10,
                                height: 13 / 10,
                                weight: FontWeight.w600,
                                color: mode.$3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _PlaybackProgress(state: state),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _GradientButton(
            key: const Key('motion-dock-play'),
            label: 'Play',
            icon: Icons.play_arrow_rounded,
            expanded: true,
            onTap: selected == null
                ? null
                : () => controller.playMotion(selected.id),
          ),
          const SizedBox(height: 8),
          _SoftButton(
            key: const Key('motion-dock-stop'),
            label: 'Stop',
            icon: Icons.stop_rounded,
            expanded: true,
            onTap: controller.stop,
          ),
        ],
      ),
    );
  }
}

class _MotionPage extends StatelessWidget {
  const _MotionPage({
    required this.state,
    required this.controller,
    required this.width,
  });

  final MotionState state;
  final MotionController controller;
  final double width;

  @override
  Widget build(BuildContext context) {
    final wide = width >= 1180;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MotionHeader(state: state, controller: controller),
        const SizedBox(height: 14),
        _QuickGestures(state: state, controller: controller),
        const SizedBox(height: 12),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final recordWidth = constraints.maxWidth >= 1050
                        ? 360.0
                        : 310.0;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _SavedMotions(
                                state: state,
                                controller: controller,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: recordWidth,
                              child: _RecordMotion(
                                state: state,
                                controller: controller,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _PlaybackControls(state: state, controller: controller),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 280,
                child: _MotionSidebar(state: state, controller: controller),
              ),
            ],
          )
        else ...[
          _SavedMotions(state: state, controller: controller),
          const SizedBox(height: 12),
          _RecordMotion(state: state, controller: controller),
          const SizedBox(height: 12),
          _PlaybackControls(state: state, controller: controller),
          const SizedBox(height: 12),
          _MotionSidebar(
            state: state,
            controller: controller,
            horizontal: width >= 700,
          ),
        ],
      ],
    );
  }
}

class _MotionHeader extends StatelessWidget {
  const _MotionHeader({required this.state, required this.controller});

  final MotionState state;
  final MotionController controller;

  @override
  Widget build(BuildContext context) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Motion',
          style: _motionText(
            30,
            height: 38 / 30,
            weight: FontWeight.w700,
            color: _ink,
          ),
        ),
        Text(
          'Record, play, and manage robot movement sequences for G1 Gustav.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _motionText(13, height: 17 / 13, color: _muted),
        ),
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _StatusChip(
          icon: state.serviceLoading ? Icons.sync_rounded : Icons.circle,
          label: state.serviceLoading
              ? 'Loading motion catalog'
              : state.serviceOnline
              ? 'Motion service online'
              : 'Motion catalog unavailable',
          color: state.serviceOnline ? _green : _purple,
        ),
        _StatusChip(
          icon: Icons.check_circle_rounded,
          label: state.hasUnsavedChanges
              ? 'Local changes'
              : 'All changes saved',
          color: state.hasUnsavedChanges ? _purple : _green,
        ),
        _SquareAction(
          tooltip: 'Refresh motions',
          icon: Icons.settings_outlined,
          onTap: controller.refresh,
        ),
        _GradientButton(
          label: 'Send to robot',
          icon: Icons.send_rounded,
          onTap: controller.sendSelectedToRobot,
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 820) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 10), actions],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: title),
            const SizedBox(width: 16),
            actions,
          ],
        );
      },
    );
  }
}

class _QuickGestures extends StatelessWidget {
  const _QuickGestures({required this.state, required this.controller});

  final MotionState state;
  final MotionController controller;

  @override
  Widget build(BuildContext context) {
    final touch = AppLayout.landscapeOf(context);
    return _MotionPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeading(
            icon: Icons.bolt_rounded,
            title: 'Quick gestures',
            subtitle: 'Common motions for quick access.',
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: touch ? 104 : 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.quickGestures.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final gesture = state.quickGestures[index];
                return _GestureCard(
                  gesture: gesture,
                  available:
                      gesture.id == 'hello' ||
                      state.savedMotions.any(
                        (motion) => motion.recordedFilename == gesture.id,
                      ),
                  onPlay: () => controller.playGesture(gesture),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GestureCard extends StatelessWidget {
  const _GestureCard({
    required this.gesture,
    required this.onPlay,
    required this.available,
  });

  final QuickGesture gesture;
  final VoidCallback onPlay;
  final bool available;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppLayout.landscapeOf(context) ? 124 : 104,
      padding: const EdgeInsets.fromLTRB(9, 8, 7, 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        border: Border.all(color: _outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gesture.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _motionText(
                    11,
                    height: 14 / 11,
                    weight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                const Spacer(),
                Text(
                  available
                      ? _duration(gesture.durationSeconds)
                      : 'Unavailable',
                  style: _motionText(10, height: 13 / 10, color: _muted),
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _GestureRobot(spriteIndex: gesture.spriteIndex),
              _CirclePlay(onTap: onPlay),
            ],
          ),
        ],
      ),
    );
  }
}

class _GestureRobot extends StatelessWidget {
  const _GestureRobot({required this.spriteIndex});

  static const _asset = 'assets/images/motion_gesture_robots.png';
  static const _spriteCount = 11;
  static const _cellWidth = 17.0;
  static const _spriteWidth = _cellWidth * _spriteCount;
  static const _spriteHeight = _spriteWidth / 3;

  final int spriteIndex;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 30,
    height: 38,
    child: Center(
      child: SizedBox(
        width: _cellWidth,
        height: 38,
        child: ClipRect(
          child: OverflowBox(
            minWidth: _spriteWidth,
            maxWidth: _spriteWidth,
            minHeight: _spriteHeight,
            maxHeight: _spriteHeight,
            alignment: Alignment(
              -1 + (2 * spriteIndex / (_spriteCount - 1)),
              0,
            ),
            child: Image.asset(
              _asset,
              width: _spriteWidth,
              height: _spriteHeight,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    ),
  );
}

class _SavedMotions extends StatefulWidget {
  const _SavedMotions({required this.state, required this.controller});

  final MotionState state;
  final MotionController controller;

  @override
  State<_SavedMotions> createState() => _SavedMotionsState();
}

class _SavedMotionsState extends State<_SavedMotions> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final controller = widget.controller;
    // On phones the page is the only scroll view (no trapped inner scroll)
    // and the pinned dock already shows playback progress.
    final touch = AppLayout.landscapeOf(context);
    return _MotionPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final heading = _SectionHeading(
                icon: Icons.folder_rounded,
                title: 'Saved motions (${state.savedMotions.length})',
              );
              final search = SizedBox(
                width: constraints.maxWidth < 620 ? 150 : 190,
                height: touch ? AppLayout.touchTarget : 36,
                child: TextField(
                  key: const Key('motion-search'),
                  onChanged: controller.setSearchQuery,
                  style: _motionText(11, height: 14 / 11, color: _body),
                  decoration: _inputDecoration(
                    'Search motions...',
                    icon: Icons.search_rounded,
                  ),
                ),
              );
              // Stacked on a narrow phone column, the search takes the
              // width the type filter leaves.
              final stacked = constraints.maxWidth < 600;
              final filters = Row(
                mainAxisSize: touch && stacked
                    ? MainAxisSize.max
                    : MainAxisSize.min,
                children: [
                  if (touch && stacked) Expanded(child: search) else search,
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 106,
                    child: _MotionDropdown<String>(
                      value: state.typeFilter,
                      items: state.types,
                      label: (value) => value,
                      onChanged: controller.setTypeFilter,
                    ),
                  ),
                ],
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [heading, const SizedBox(height: 10), filters],
                );
              }
              return Row(
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: 12),
                  filters,
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          if (!touch && state.playbackStatus != MotionPlaybackStatus.idle) ...[
            _PlaybackProgress(state: state),
            const SizedBox(height: 10),
          ],
          if (state.visibleMotions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Text(
                state.serviceLoading
                    ? 'Loading motion catalog…'
                    : state.error ??
                          (state.savedMotions.isEmpty
                              ? 'No recorded motions available.'
                              : 'No motions match this filter.'),
                textAlign: TextAlign.center,
                style: _motionText(12, height: 16 / 12, color: _muted),
              ),
            )
          else if (touch)
            _MotionCards(state: state, controller: controller)
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (MediaQuery.sizeOf(context).height * 0.45).clamp(
                  220.0,
                  420.0,
                ),
              ),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  primary: false,
                  padding: const EdgeInsets.only(right: 10),
                  child: LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth >= 690
                        ? _MotionTable(state: state, controller: controller)
                        : _MotionCards(state: state, controller: controller),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlaybackProgress extends StatelessWidget {
  const _PlaybackProgress({required this.state});

  final MotionState state;

  @override
  Widget build(BuildContext context) {
    final status = state.playbackStatus;
    final active =
        status == MotionPlaybackStatus.sending ||
        status == MotionPlaybackStatus.playing ||
        status == MotionPlaybackStatus.stopping;
    final label = switch (status) {
      MotionPlaybackStatus.idle => 'Ready',
      MotionPlaybackStatus.sending => 'Sending to robot…',
      MotionPlaybackStatus.playing => 'Playing on robot…',
      MotionPlaybackStatus.paused => 'Paused',
      MotionPlaybackStatus.stopping => 'Stopping…',
      MotionPlaybackStatus.finished => 'Completed',
      MotionPlaybackStatus.simulated => simulationOnlyLabel,
      MotionPlaybackStatus.stopped => 'Stopped',
      MotionPlaybackStatus.error => 'Error',
      MotionPlaybackStatus.busy => 'Robot busy',
      MotionPlaybackStatus.unavailable => 'Unavailable',
    };
    final color = switch (status) {
      MotionPlaybackStatus.finished => _green,
      MotionPlaybackStatus.error => _red,
      MotionPlaybackStatus.busy ||
      MotionPlaybackStatus.unavailable ||
      MotionPlaybackStatus.simulated => _amber,
      _ => _purple,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${state.currentMotionName ?? 'Motion'} · $label',
            style: _motionText(
              12,
              height: 16 / 12,
              weight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 9),
          LinearProgressIndicator(
            value: active
                ? null
                : (status == MotionPlaybackStatus.finished ? 1 : 0),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
            semanticsLabel: label,
          ),
        ],
      ),
    );
  }
}

class _MotionTable extends StatelessWidget {
  const _MotionTable({required this.state, required this.controller});

  final MotionState state;
  final MotionController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: const Color(0xFFF5F6FC),
          child: const Row(
            children: [
              SizedBox(width: 30),
              Expanded(flex: 4, child: _TableLabel('Name')),
              Expanded(flex: 2, child: _TableLabel('Type')),
              Expanded(flex: 2, child: _TableLabel('Duration')),
              Expanded(flex: 2, child: _TableLabel('Last used')),
              SizedBox(width: 190, child: _TableLabel('Actions')),
            ],
          ),
        ),
        for (final motion in state.visibleMotions)
          _MotionTableRow(
            motion: motion,
            selected: motion.id == state.selectedMotionId,
            controller: controller,
          ),
      ],
    );
  }
}

class _TableLabel extends StatelessWidget {
  const _TableLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: _motionText(10, height: 13 / 10, color: _muted),
  );
}

class _MotionTableRow extends StatelessWidget {
  const _MotionTableRow({
    required this.motion,
    required this.selected,
    required this.controller,
  });

  final SavedMotion motion;
  final bool selected;
  final MotionController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _purpleSoft.withValues(alpha: 0.5) : Colors.transparent,
      child: InkWell(
        onTap: () => controller.selectMotion(motion.id),
        child: Container(
          height: 43,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _outline)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 17,
                  tooltip: motion.favorite ? 'Remove favorite' : 'Favorite',
                  onPressed: () => controller.toggleFavorite(motion.id),
                  icon: Icon(
                    motion.favorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: motion.favorite ? _amber : _muted,
                  ),
                ),
              ),
              Expanded(flex: 4, child: _MotionName(motion.name)),
              Expanded(flex: 2, child: _TypeBadge(motion.type)),
              Expanded(
                flex: 2,
                child: Text(
                  _duration(motion.durationSeconds),
                  style: _motionText(10, height: 13 / 10, color: _body),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  motion.lastUsed,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _motionText(10, height: 13 / 10, color: _muted),
                ),
              ),
              SizedBox(
                width: 190,
                child: _MotionRowActions(
                  motion: motion,
                  controller: controller,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MotionCards extends StatelessWidget {
  const _MotionCards({required this.state, required this.controller});

  final MotionState state;
  final MotionController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final motion in state.visibleMotions)
          Material(
            color: motion.id == state.selectedMotionId
                ? _purpleSoft.withValues(alpha: 0.6)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => controller.selectMotion(motion.id),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints.tightFor(
                        width: AppLayout.landscapeOf(context)
                            ? AppLayout.touchTarget
                            : 28,
                        height: AppLayout.landscapeOf(context)
                            ? AppLayout.touchTarget
                            : 28,
                      ),
                      tooltip: motion.favorite
                          ? 'Remove from favorites'
                          : 'Add to favorites',
                      onPressed: () => controller.toggleFavorite(motion.id),
                      icon: Icon(
                        motion.favorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 17,
                        color: motion.favorite ? _amber : _muted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MotionName(motion.name),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 7,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _TypeBadge(motion.type),
                              Text(
                                _duration(motion.durationSeconds),
                                style: _motionText(
                                  9,
                                  height: 12 / 9,
                                  color: _muted,
                                ),
                              ),
                              Text(
                                motion.lastUsed,
                                style: _motionText(
                                  9,
                                  height: 12 / 9,
                                  color: _muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _MotionRowActions(
                      motion: motion,
                      controller: controller,
                      compact: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MotionRowActions extends StatelessWidget {
  const _MotionRowActions({
    required this.motion,
    required this.controller,
    this.compact = false,
  });

  final SavedMotion motion;
  final MotionController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        Icons.play_arrow_rounded,
        'Play',
        () => controller.playMotion(motion.id),
        false,
      ),
      (
        Icons.copy_rounded,
        'Duplicate',
        () => controller.duplicate(motion.id),
        false,
      ),
      (
        Icons.edit_outlined,
        'Rename',
        () => _showRenameDialog(context, motion, controller),
        false,
      ),
      (
        Icons.delete_outline_rounded,
        'Delete',
        () => _showDeleteDialog(context, motion, controller),
        true,
      ),
      (
        Icons.more_horiz_rounded,
        'More',
        () => _showMotionMessage(context, '${motion.name} selected'),
        false,
      ),
    ];
    final visible = compact ? [actions.first, actions.last] : actions;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (final action in visible)
          _TinyAction(
            icon: action.$1,
            tooltip: action.$2,
            onTap: action.$3,
            danger: action.$4,
          ),
      ],
    );
  }
}

class _MotionName extends StatelessWidget {
  const _MotionName(this.name);

  final String name;

  @override
  Widget build(BuildContext context) => Text(
    name,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: _motionText(
      11,
      height: 14 / 11,
      weight: FontWeight.w600,
      color: _ink,
    ),
  );
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge(this.type);

  final String type;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (type) {
      'Greeting' => (_green, _greenSoft),
      'Dance' => (_purple, _purpleSoft),
      'Reaction' => (_red, _redSoft),
      'Gesture' => (const Color(0xFF007AB8), const Color(0xFFE5F4FC)),
      _ => (_body, const Color(0xFFF0F2F8)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        type,
        maxLines: 1,
        style: _motionText(
          9,
          height: 11 / 9,
          weight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

class _RecordMotion extends StatefulWidget {
  const _RecordMotion({required this.state, required this.controller});

  final MotionState state;
  final MotionController controller;

  @override
  State<_RecordMotion> createState() => _RecordMotionState();
}

class _RecordMotionState extends State<_RecordMotion> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.state.motionName);
  }

  @override
  void didUpdateWidget(covariant _RecordMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.motionName != _nameController.text) {
      _nameController.value = TextEditingValue(
        text: widget.state.motionName,
        selection: TextSelection.collapsed(
          offset: widget.state.motionName.length,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final controller = widget.controller;
    final canSave =
        !state.recording &&
        state.motionName.trim().isNotEmpty &&
        state.recordedDuration > Duration.zero;
    return _MotionPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeading(
            icon: Icons.fiber_manual_record_rounded,
            title: 'Record new motion',
            iconColor: _red,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final name = _LabeledControl(
                label: 'Motion name',
                child: TextField(
                  key: const Key('motion-name-input'),
                  controller: _nameController,
                  enabled: !state.recording,
                  onChanged: controller.setMotionName,
                  style: _motionText(11, height: 14 / 11, color: _body),
                  decoration: _inputDecoration('e.g. my_motion.json'),
                ),
              );
              final category = _LabeledControl(
                label: 'Category / tag',
                child: _MotionDropdown<String>(
                  value: state.motionCategory,
                  items: const [
                    'Custom',
                    'Greeting',
                    'Dance',
                    'Reaction',
                    'Gesture',
                  ],
                  label: (value) => value,
                  onChanged: state.recording
                      ? null
                      : controller.setMotionCategory,
                ),
              );
              if (constraints.maxWidth < 420) {
                return Column(
                  children: [name, const SizedBox(height: 9), category],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: name),
                  const SizedBox(width: 10),
                  Expanded(child: category),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Container(
            height: 126,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FD),
              border: Border.all(color: _outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.circle,
                  size: 15,
                  color: state.recording ? _red : const Color(0xFFFF4263),
                ),
                const SizedBox(height: 10),
                Text(
                  state.recording ? 'Recording motion...' : 'Ready to record',
                  style: _motionText(11, height: 14 / 11, color: _muted),
                ),
                const SizedBox(height: 3),
                Text(
                  _recordingTime(state.recordedDuration),
                  key: const Key('motion-recording-timer'),
                  style: _motionText(
                    31,
                    height: 38 / 31,
                    weight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _GradientButton(
                  key: const Key('motion-start-recording'),
                  label: 'Start recording',
                  icon: Icons.mic_none_rounded,
                  onTap: state.recording ? null : controller.startRecording,
                  expanded: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SoftButton(
                  key: const Key('motion-stop-recording'),
                  label: 'Stop recording',
                  icon: Icons.stop_rounded,
                  onTap: state.recording ? controller.stopRecording : null,
                  expanded: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SoftButton(
            key: const Key('motion-save-recording'),
            label: 'Save motion',
            icon: Icons.save_outlined,
            onTap: canSave
                ? () {
                    final saved = controller.saveRecording();
                    _showMotionMessage(
                      context,
                      saved
                          ? 'Motion saved locally'
                          : 'Complete a recording first',
                      type: saved
                          ? AppNotificationType.success
                          : AppNotificationType.warning,
                    );
                  }
                : null,
            expanded: true,
          ),
        ],
      ),
    );
  }
}

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({required this.state, required this.controller});

  final MotionState state;
  final MotionController controller;

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedMotion;
    return _MotionPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeading(
            icon: Icons.play_arrow_rounded,
            title: 'Playback controls',
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final controls = <Widget>[
                SizedBox(
                  width: constraints.maxWidth < 600
                      ? constraints.maxWidth
                      : 330,
                  child: _LabeledControl(
                    label: 'Selected motion',
                    child: _MotionDropdown<String>(
                      value: selected?.id,
                      items: [
                        for (final motion in state.savedMotions) motion.id,
                      ],
                      label: (id) => state.savedMotions
                          .firstWhere((motion) => motion.id == id)
                          .name,
                      onChanged: controller.selectMotion,
                    ),
                  ),
                ),
                _PlaybackButton(
                  label: 'Play',
                  icon: Icons.play_arrow_rounded,
                  active: state.playbackStatus == MotionPlaybackStatus.playing,
                  onTap: selected == null
                      ? null
                      : () => controller.playMotion(selected.id),
                ),
                _PlaybackButton(
                  label: 'Pause',
                  icon: Icons.pause_rounded,
                  onTap: state.playbackStatus == MotionPlaybackStatus.playing
                      ? controller.pause
                      : null,
                ),
                _PlaybackButton(
                  label: 'Stop',
                  icon: Icons.stop_rounded,
                  onTap: controller.stop,
                ),
                SizedBox(
                  width: 92,
                  child: _LabeledControl(
                    label: 'Playback speed',
                    child: _MotionDropdown<double>(
                      value: state.playbackSpeed,
                      items: const [0.5, 0.75, 1, 1.25, 1.5, 2],
                      label: (value) => '${value}x',
                      onChanged: controller.setPlaybackSpeed,
                    ),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: _LabeledControl(
                    label: 'Loop',
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _MotionToggle(
                        value: state.loop,
                        onTap: controller.toggleLoop,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 78,
                  child: _LabeledControl(
                    label: 'Queue next',
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _MotionToggle(
                        value: state.queueNext,
                        onTap: controller.toggleQueueNext,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 136,
                  child: _LabeledControl(
                    label: 'Send to robot',
                    child: _GradientButton(
                      label: 'Send to robot',
                      icon: Icons.send_rounded,
                      onTap: selected == null
                          ? null
                          : controller.sendSelectedToRobot,
                    ),
                  ),
                ),
              ];
              return Wrap(
                spacing: 8,
                runSpacing: 9,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: controls,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PlaybackButton extends StatelessWidget {
  const _PlaybackButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 94,
    child: _LabeledControl(
      label: ' ',
      child: active
          ? _GradientButton(
              label: label,
              icon: icon,
              onTap: onTap,
              expanded: true,
            )
          : _SoftButton(label: label, icon: icon, onTap: onTap, expanded: true),
    ),
  );
}

class _MotionSidebar extends StatelessWidget {
  const _MotionSidebar({
    required this.state,
    required this.controller,
    this.horizontal = false,
  });

  final MotionState state;
  final MotionController controller;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _MotionStatusCard(state: state),
      _RecentActivityCard(items: state.recentActivity),
      const _SafetyNotesCard(),
      _ImportExportCard(state: state, controller: controller),
    ];
    if (!horizontal) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < cards.length; index++) ...[
            cards[index],
            if (index != cards.length - 1) const SizedBox(height: 10),
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 1100
            ? (constraints.maxWidth - 30) / 4
            : (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }
}

class _MotionStatusCard extends StatelessWidget {
  const _MotionStatusCard({required this.state});

  final MotionState state;

  @override
  Widget build(BuildContext context) {
    final current = state.currentMotionName == null
        ? state.playbackStatus.name
        : '${state.currentMotionName} · ${state.playbackStatus.name}';
    return _MotionPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SidebarHeading(
            icon: Icons.circle,
            iconColor: _green,
            title: 'Motion status',
          ),
          const SizedBox(height: 9),
          _SidebarRow(
            label: 'Service',
            value: state.robotConnected ? 'Online' : 'Offline',
            color: state.robotConnected ? _green : _purple,
          ),
          _SidebarRow(label: 'Current motion', value: current),
          _SidebarRow(
            label: 'Queue length',
            value: state.queueNext ? '1' : '0',
          ),
          const _SidebarRow(
            label: 'Robot posture',
            value: 'Safe',
            color: _green,
          ),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.items});

  final List<MotionActivity> items;

  @override
  Widget build(BuildContext context) {
    return _MotionPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SidebarHeading(
            icon: Icons.history_rounded,
            title: 'Recent activity',
            trailing: _MiniAction(
              label: 'View all',
              onTap: () =>
                  _showMotionMessage(context, 'All recent activity is shown'),
            ),
          ),
          const SizedBox(height: 7),
          for (final item in items)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _outline)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 15,
                    backgroundColor: _purpleSoft,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 17,
                      color: _purple,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _motionText(
                            10,
                            height: 13 / 10,
                            weight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                        Text(
                          _duration(item.durationSeconds),
                          style: _motionText(9, height: 12 / 9, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    item.when,
                    style: _motionText(9, height: 12 / 9, color: _muted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SafetyNotesCard extends StatelessWidget {
  const _SafetyNotesCard();

  @override
  Widget build(BuildContext context) {
    return _MotionPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SidebarHeading(
            icon: Icons.warning_amber_rounded,
            iconColor: _amber,
            title: 'Safety notes',
          ),
          const SizedBox(height: 7),
          Text(
            'Ensure clear space around the robot before playing complex motions.',
            style: _motionText(9, height: 13 / 9, color: _body),
          ),
          const SizedBox(height: 7),
          const _SafetyBullet(
            'Some motions may require operator confirmation.',
          ),
          const _SafetyBullet('Monitor footing and nearby people.'),
          const _SafetyBullet(
            'Stop immediately if the robot behaves unexpectedly.',
          ),
        ],
      ),
    );
  }
}

class _SafetyBullet extends StatelessWidget {
  const _SafetyBullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Icon(Icons.circle, size: 5, color: _amber),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: _motionText(9, height: 13 / 9, color: _muted),
          ),
        ),
      ],
    ),
  );
}

class _ImportExportCard extends StatelessWidget {
  const _ImportExportCard({required this.state, required this.controller});

  final MotionState state;
  final MotionController controller;

  @override
  Widget build(BuildContext context) {
    return _MotionPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SidebarHeading(
            icon: Icons.cloud_upload_outlined,
            title: 'Import / export',
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _SoftButton(
                label: 'Import motions (JSON)',
                onTap: () => _runMotionAction(
                  context,
                  controller.importMotions(),
                  success: 'Motions imported',
                  unavailable: 'Motion import is not connected yet',
                ),
              ),
              _SoftButton(
                label: 'Export selected',
                icon: Icons.ios_share_outlined,
                onTap: state.selectedMotion == null
                    ? null
                    : () => _runMotionAction(
                        context,
                        controller.exportSelected(),
                        success: 'Motion exported',
                        unavailable: 'Motion export is not connected yet',
                      ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          _SoftButton(
            label: 'Sync with robot',
            icon: Icons.sync_rounded,
            expanded: true,
            onTap: () => _showMotionMessage(
              context,
              'Robot motion sync is not connected yet',
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarHeading extends StatelessWidget {
  const _SidebarHeading({
    required this.icon,
    required this.title,
    this.iconColor = _purple,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 19, color: iconColor),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: _motionText(
            14,
            height: 18 / 14,
            weight: FontWeight.w600,
            color: _ink,
          ),
        ),
      ),
      ?trailing,
    ],
  );
}

class _SidebarRow extends StatelessWidget {
  const _SidebarRow({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 7),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: _outline)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: _motionText(10, height: 13 / 10, color: _body),
          ),
        ),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color == null
                  ? const Color(0xFFF2F4FA)
                  : color!.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _motionText(
                10,
                height: 12 / 10,
                weight: FontWeight.w600,
                color: color ?? _body,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _MotionPanel extends StatelessWidget {
  const _MotionPanel({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: _surface,
      border: Border.all(color: _outline),
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x102E2767),
          blurRadius: 22,
          offset: Offset(0, 7),
        ),
      ],
    ),
    child: Padding(padding: padding, child: child),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor = _purple,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 22, color: iconColor),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _motionText(
                16,
                height: 20 / 16,
                weight: FontWeight.w600,
                color: _ink,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _motionText(11, height: 14 / 11, color: _muted),
              ),
          ],
        ),
      ),
    ],
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: 11),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: _motionText(
            10,
            height: 13 / 10,
            weight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _SquareAction extends StatelessWidget {
  const _SquareAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.white.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          width: AppLayout.landscapeOf(context) ? AppLayout.touchTarget : 40,
          height: AppLayout.landscapeOf(context) ? AppLayout.touchTarget : 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: _outline),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 20, color: _body),
        ),
      ),
    ),
  );
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.expanded = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? 0.45 : 1,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          height: AppLayout.landscapeOf(context) ? AppLayout.touchTarget : 42,
          width: expanded ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8252F6), Color(0xFF6331EC)],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color(0x306F2CF4),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: Colors.white),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _motionText(
                    11,
                    height: 14 / 11,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SoftButton extends StatelessWidget {
  const _SoftButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? 0.42 : 1,
    child: Material(
      color: _purpleSoft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: AppLayout.landscapeOf(context) ? AppLayout.touchTarget : 42,
          width: expanded ? double.infinity : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: _purple),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _motionText(
                      10,
                      height: 13 / 10,
                      weight: FontWeight.w600,
                      color: _purple,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _CirclePlay extends StatelessWidget {
  const _CirclePlay({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: _purpleSoft,
    shape: const CircleBorder(),
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox.square(
        dimension: AppLayout.landscapeOf(context) ? 44 : 30,
        child: const Icon(Icons.play_arrow_rounded, size: 19, color: _purple),
      ),
    ),
  );
}

class _LabeledControl extends StatelessWidget {
  const _LabeledControl({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: _motionText(
          10,
          height: 13 / 10,
          weight: FontWeight.w500,
          color: _body,
        ),
      ),
      const SizedBox(height: 5),
      SizedBox(
        height: AppLayout.landscapeOf(context) ? AppLayout.touchTarget : 36,
        child: child,
      ),
    ],
  );
}

class _MotionDropdown<T> extends StatelessWidget {
  const _MotionDropdown({
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
  });

  final T? value;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: AppLayout.landscapeOf(context) ? AppLayout.touchTarget : 36,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.82),
      border: Border.all(color: _outline),
      borderRadius: BorderRadius.circular(9),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        borderRadius: BorderRadius.circular(12),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 17,
          color: _body,
        ),
        style: _motionText(10, height: 13 / 10, color: _body),
        items: [
          for (final item in items)
            DropdownMenuItem<T>(value: item, child: Text(label(item))),
        ],
        onChanged: onChanged == null
            ? null
            : (next) {
                if (next != null) onChanged!(next);
              },
      ),
    ),
  );
}

class _MotionToggle extends StatelessWidget {
  const _MotionToggle({required this.value, required this.onTap});

  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: value,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      // Same switch, with a finger-sized hit area on phones.
      child: Padding(
        padding: AppLayout.landscapeOf(context)
            ? const EdgeInsets.symmetric(horizontal: 5, vertical: 13)
            : EdgeInsets.zero,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 38,
          height: 22,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? _purple : const Color(0xFFCED4E4),
            borderRadius: BorderRadius.circular(999),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 160),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: SizedBox(width: 16, height: 16),
            ),
          ),
        ),
      ),
    ),
  );
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: _purpleSoft,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        child: Text(
          label,
          style: _motionText(
            9,
            height: 12 / 9,
            weight: FontWeight.w600,
            color: _purple,
          ),
        ),
      ),
    ),
  );
}

class _TinyAction extends StatelessWidget {
  const _TinyAction({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.danger = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool danger;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: IconButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: AppLayout.landscapeOf(context)
          ? const BoxConstraints.tightFor(
              width: AppLayout.touchTarget,
              height: AppLayout.touchTarget,
            )
          : const BoxConstraints.tightFor(width: 35, height: 31),
      style: IconButton.styleFrom(
        // The desktop row allocates 35 dp per action. Material's default
        // 48 dp tap padding otherwise overflows its 190 dp actions column.
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: danger ? _redSoft : const Color(0xFFF2F3FA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon, size: 16, color: danger ? _red : _purple),
    ),
  );
}

InputDecoration _inputDecoration(String hint, {IconData? icon}) =>
    InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: _motionText(10, height: 13 / 10, color: _muted),
      prefixIcon: icon == null ? null : Icon(icon, size: 16, color: _muted),
      prefixIconConstraints: const BoxConstraints(minWidth: 34),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.82),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: _outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: _outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: _purple, width: 1.4),
      ),
    );

TextStyle _motionText(
  double size, {
  required double height,
  required Color color,
  FontWeight weight = FontWeight.w400,
}) =>
    TextStyle(fontSize: size, height: height, fontWeight: weight, color: color);

String _duration(double seconds) =>
    seconds > 0 ? '${seconds.toStringAsFixed(1)} s' : '--';

String _recordingTime(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  final tenths = (duration.inMilliseconds.remainder(1000) ~/ 100).toString();
  return '$minutes:$seconds.$tenths';
}

Future<void> _runMotionAction(
  BuildContext context,
  Future<bool> action, {
  required String success,
  required String unavailable,
}) async {
  try {
    final result = await action;
    if (!context.mounted) return;
    _showMotionMessage(
      context,
      result ? success : unavailable,
      type: result ? AppNotificationType.success : AppNotificationType.info,
    );
  } on Object {
    if (!context.mounted) return;
    _showMotionMessage(
      context,
      'Motion action failed',
      type: AppNotificationType.error,
    );
  }
}

void _showMotionMessage(
  BuildContext context,
  String message, {
  AppNotificationType type = AppNotificationType.info,
}) => context.notifications.show(type, message);

Future<void> _showRenameDialog(
  BuildContext context,
  SavedMotion motion,
  MotionController controller,
) async {
  final textController = TextEditingController(text: motion.name);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Rename motion'),
      content: TextField(controller: textController, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, textController.text),
          child: const Text('Rename'),
        ),
      ],
    ),
  );
  textController.dispose();
  if (result != null) controller.rename(motion.id, result);
}

Future<void> _showDeleteDialog(
  BuildContext context,
  SavedMotion motion,
  MotionController controller,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete motion?'),
      content: Text('Remove ${motion.name} from the local list?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed ?? false) controller.delete(motion.id);
}
