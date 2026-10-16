import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:robot_control_app/core/navigation/navigation_visibility.dart';
import 'package:robot_control_app/core/routing/app_routes.dart';
import 'package:robot_control_app/core/theme/app_colors.dart';
import 'package:robot_control_app/features/motion/application/motion_state.dart';
import 'package:robot_control_app/features/motion/presentation/motion_notifications.dart';
import 'package:robot_control_app/services/robot_connection.dart';
import 'package:robot_control_app/shared/layout/app_layout.dart';
import 'package:robot_control_app/shared/notifications/app_notification_service.dart';

Future<void> _openGlobalSearch(BuildContext context) async {
  final route = await showSearch<String>(
    context: context,
    delegate: _PlatformSearchDelegate(),
  );
  if (route != null && route.isNotEmpty && context.mounted) {
    context.go(route);
  }
}

class AppNavigationShell extends StatelessWidget {
  const AppNavigationShell({required this.navigationShell, super.key});

  static const _compactBreakpoint = 600.0;
  static const _expandedBreakpoint = 840.0;

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  Future<void> _showMore(BuildContext context) async {
    final index = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _MoreDestinations(),
    );
    if (context.mounted && index != null) {
      _goBranch(index);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      if (AppLayout.isLandscapeCompact(constraints.biggest)) {
        return _LandscapeShell(
          navigationShell: navigationShell,
          onSelect: _goBranch,
        );
      }
      if (width < _compactBreakpoint) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              const _AppHeader(layout: _ShellLayout.compact),
              Expanded(child: navigationShell),
            ],
          ),
          bottomNavigationBar: _CompactNavigation(
            currentIndex: navigationShell.currentIndex,
            onSelect: (index) {
              switch (index) {
                case 0:
                  _goBranch(0);
                case 1:
                  _goBranch(5);
                case 2:
                  _goBranch(1);
                case 3:
                  _showMore(context);
              }
            },
          ),
        );
      }

      final expanded = width >= _expandedBreakpoint;
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            _AppHeader(
              layout: expanded ? _ShellLayout.expanded : _ShellLayout.medium,
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (expanded)
                    _DesktopSidebar(
                      currentIndex: navigationShell.currentIndex,
                      onSelect: _goBranch,
                    )
                  else
                    _MediumRail(
                      currentIndex: navigationShell.currentIndex,
                      onSelect: _goBranch,
                    ),
                  Expanded(child: navigationShell),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

enum _ShellLayout { compact, medium, expanded }

/// Phones on their side: no header, a slim icon rail with every routed
/// destination, the live robot link and a Stop that is always reachable.
class _LandscapeShell extends StatelessWidget {
  const _LandscapeShell({
    required this.navigationShell,
    required this.onSelect,
  });

  final StatefulNavigationShell navigationShell;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('landscape-shell'),
    // Fills the system-bar strips around the safe content area in the
    // pages' own lavender-white.
    backgroundColor: const Color(0xFFF7F8FF),
    body: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LandscapeRail(
          currentIndex: navigationShell.currentIndex,
          onSelect: onSelect,
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeLeft: true,
            child: SafeArea(
              left: false,
              child: Semantics(container: true, child: navigationShell),
            ),
          ),
        ),
      ],
    ),
  );
}

const _landscapeDestinations = <_DesktopDestination>[
  _DesktopDestination(
    'Dashboard',
    Icons.dashboard_outlined,
    NavFeature.dashboard,
    0,
  ),
  _DesktopDestination(
    'AI Workspace',
    Icons.auto_awesome_outlined,
    NavFeature.aiWorkspace,
    5,
  ),
  _DesktopDestination('Motion', Icons.trending_up, NavFeature.motion, 1),
  _DesktopDestination(
    'AI Voice Studio',
    Icons.record_voice_over_outlined,
    NavFeature.voiceStudio,
    6,
  ),
  _DesktopDestination(
    'Vision',
    Icons.visibility_outlined,
    NavFeature.vision,
    3,
  ),
  _DesktopDestination('Audio', Icons.graphic_eq_outlined, NavFeature.audio, 2),
  _DesktopDestination(
    'Settings',
    Icons.settings_outlined,
    NavFeature.settings,
    4,
  ),
];

class _LandscapeRail extends StatelessWidget {
  const _LandscapeRail({required this.currentIndex, required this.onSelect});

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Container(
      key: const Key('landscape-rail'),
      width: 72 + padding.left,
      padding: EdgeInsets.only(
        left: padding.left,
        top: padding.top + 8,
        bottom: padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFDFBFF), Color(0xFFF6F5FF), Color(0xFFECF0FF)],
          stops: [0, .58, 1],
        ),
        border: Border(right: BorderSide(color: Color(0x1F9485D1))),
      ),
      child: FocusTraversalGroup(
        child: Column(
          children: [
            _RailRobotStatus(onTap: () => onSelect(4)),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('landscape-rail-scroll'),
                child: Column(
                  children: [
                    for (final destination in _landscapeDestinations.where(
                      _DesktopDestination.isShown,
                    )) ...[
                      _RailDestinationTile(
                        destination: destination,
                        selected: destination.branch == currentIndex,
                        onTap: () => onSelect(destination.branch!),
                      ),
                      const SizedBox(height: 4),
                    ],
                    _RailIconButton(
                      key: const Key('landscape-rail-search'),
                      icon: Icons.search_rounded,
                      label: 'Search platform',
                      onTap: () => _openGlobalSearch(context),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            const _RailStopButton(),
          ],
        ),
      ),
    );
  }
}

class _RailDestinationTile extends StatelessWidget {
  const _RailDestinationTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _DesktopDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: destination.label,
    // The tile's own semantics replace the InkWell's, so the tap action is
    // declared here for screen readers.
    child: Semantics(
      key: Key('landscape-nav-${destination.branch}'),
      label: destination.label,
      selected: selected,
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          width: 56,
          height: AppLayout.touchTarget,
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xA8DED1FF), Color(0x6BD1E3FF)],
                  )
                : null,
            borderRadius: BorderRadius.circular(16),
            border: selected
                ? Border.all(color: const Color(0x298C61F5))
                : null,
          ),
          child: Icon(
            destination.icon,
            size: 22,
            color: selected ? const Color(0xFF3D149E) : const Color(0xFF4B5370),
          ),
        ),
      ),
    ),
  );
}

class _RailIconButton extends StatelessWidget {
  const _RailIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: AppLayout.touchTarget,
    child: IconButton(
      tooltip: label,
      onPressed: onTap,
      icon: Icon(icon, color: const Color(0xFF4B5370)),
    ),
  );
}

/// The live robot link, read from the connection. Opens Settings, where the
/// connection is managed.
class _RailRobotStatus extends ConsumerWidget {
  const _RailRobotStatus({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(robotLinkProvider.select((link) => link.status));
    final (label, color) = switch (status) {
      RobotLinkStatus.connected => ('Connected', const Color(0xFF1AAF68)),
      RobotLinkStatus.awaitingTelemetry => (
        'Waiting for telemetry',
        const Color(0xFFF5A400),
      ),
      RobotLinkStatus.degraded => ('Degraded', const Color(0xFFF5A400)),
      RobotLinkStatus.connecting => ('Connecting', const Color(0xFFF5A400)),
      RobotLinkStatus.reconnecting => ('Reconnecting', const Color(0xFFF5A400)),
      RobotLinkStatus.authenticationRequired => (
        'Authentication required',
        AppColors.error,
      ),
      RobotLinkStatus.disconnected => ('Disconnected', const Color(0xFF8A90A6)),
    };
    return Tooltip(
      message: 'G1 Gustav · $label',
      child: Semantics(
        key: const Key('landscape-robot-status'),
        label: 'Robot G1 Gustav, $label. Open connection settings.',
        button: true,
        onTap: onTap,
        excludeSemantics: true,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const _RobotAvatar(),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    key: ValueKey('landscape-link-${status.name}'),
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
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
}

/// Uses the same [MotionController.stop] as the Motion screen, so every
/// safety check in the motion command session still applies.
class _RailStopButton extends ConsumerWidget {
  const _RailStopButton();

  Future<void> _stop(BuildContext context, WidgetRef ref) async {
    void notify() => notifyMotionCommand(
      ref.read(appNotificationsProvider.notifier),
      ref.read(motionProvider),
    );
    // Report "Stopping…" at once, then the robot's answer. Keyed
    // notifications update in place, so the Motion screen's own listener
    // never shows a duplicate.
    final result = ref.read(motionProvider.notifier).stop();
    notify();
    await result;
    if (context.mounted) notify();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Tooltip(
    message: 'Stop robot motion',
    child: Semantics(
      key: const Key('landscape-stop'),
      label: 'Stop robot motion',
      button: true,
      onTap: () => _stop(context, ref),
      excludeSemantics: true,
      child: Material(
        color: const Color(0xFFFFEBEF),
        shape: const CircleBorder(side: BorderSide(color: Color(0x52ED3155))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _stop(context, ref),
          child: const SizedBox.square(
            dimension: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.stop_rounded, color: Color(0xFFED3155), size: 24),
                // Fixed size inside the 56 dp disc; the semantics label
                // carries the name at any text scale.
                Text(
                  'Stop',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    color: Color(0xFFED3155),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
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

class _AppHeader extends StatelessWidget {
  const _AppHeader({required this.layout});

  final _ShellLayout layout;

  @override
  Widget build(BuildContext context) {
    final compact = layout == _ShellLayout.compact;
    final medium = layout == _ShellLayout.medium;
    final height = compact ? 72.0 : (medium ? 80.0 : 88.0);
    final padding = compact ? 16.0 : (medium ? 24.0 : 8.0);
    final logoSize = compact
        ? const Size(80, 40)
        : (medium ? const Size(120, 50) : const Size(173, 72));

    return Container(
      height: height,
      padding: EdgeInsets.only(left: padding, right: compact ? 10 : 24),
      decoration: const BoxDecoration(
        color: Color(0xE8FBFCFF),
        border: Border(bottom: BorderSide(color: Color(0xB8FFFFFF))),
        boxShadow: [
          BoxShadow(
            color: Color(0x1433407A),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox.fromSize(
            size: logoSize,
            child: Image.asset(
              'assets/images/product_logo.png',
              fit: BoxFit.contain,
            ),
          ),
          if (compact) ...[
            const Spacer(),
            const _HeaderIcon(
              icon: Icons.smart_toy_outlined,
              tooltip: 'G1 Gustav · Ready',
            ),
          ] else ...[
            SizedBox(width: medium ? 12 : 20),
            _RobotSelector(medium: medium),
            const SizedBox(width: 12),
            if (!medium) ...[
              const Expanded(child: _GlobalSearch()),
              const SizedBox(width: 12),
            ] else
              const Spacer(),
          ],
          const _NotificationButton(),
          SizedBox(width: compact ? 2 : 8),
          const _UserAvatar(),
          SizedBox(width: compact ? 2 : 8),
          _HeaderIcon(
            icon: compact || medium ? Icons.search_rounded : Icons.more_horiz,
            tooltip: compact || medium ? 'Search platform' : 'More actions',
            onPressed: compact || medium
                ? () => _openGlobalSearch(context)
                : null,
          ),
        ],
      ),
    );
  }
}

class _RobotSelector extends StatelessWidget {
  const _RobotSelector({required this.medium});

  final bool medium;

  @override
  Widget build(BuildContext context) => Container(
    width: medium ? 360 : 348,
    height: medium ? 64 : 56,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: const Color(0x80FFFFFF),
      border: Border.all(color: const Color(0xB8FFFFFF)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Row(
      children: [
        _RobotAvatar(),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'G1 Gustav',
                maxLines: 1,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              Text(
                'Unitree G1 · Ready',
                maxLines: 1,
                style: TextStyle(fontSize: 12, color: Color(0xFF49454F)),
              ),
            ],
          ),
        ),
        _ReadyChip(),
        SizedBox(width: 4),
        Icon(Icons.expand_more, size: 20),
      ],
    ),
  );
}

class _RobotAvatar extends StatelessWidget {
  const _RobotAvatar();

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFF0E0FF), Color(0xFFBFE5FF)],
      ),
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xD6FFFFFF)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x24774BBA),
          blurRadius: 7,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: const Icon(
      Icons.smart_toy_outlined,
      size: 20,
      color: AppColors.primary,
    ),
  );
}

class _ReadyChip extends StatelessWidget {
  const _ReadyChip();

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: const Color(0xD9DDF8E8),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0x382DB46E)),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatusDot(color: Color(0xFF1AAF68)),
        SizedBox(width: 8),
        Text(
          'Ready',
          style: TextStyle(
            color: Color(0xFF167A46),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

class _GlobalSearch extends StatefulWidget {
  const _GlobalSearch();

  @override
  State<_GlobalSearch> createState() => _GlobalSearchState();
}

class _GlobalSearchState extends State<_GlobalSearch> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  final _portalController = OverlayPortalController();
  var _filter = _SearchFilter.all;
  var _open = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _show() {
    if (_open) return;
    setState(() => _open = true);
    _portalController.show();
  }

  void _hide() {
    if (!_open) return;
    _portalController.hide();
    _focusNode.unfocus();
    setState(() => _open = false);
  }

  void _select(_SearchDestination item) {
    _hide();
    context.go(item.route);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final panelHeight = (MediaQuery.sizeOf(context).height - 106)
          .clamp(280.0, 640.0)
          .toDouble();
      return OverlayPortal(
        controller: _portalController,
        overlayChildBuilder: (context) => Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hide,
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 6),
              child: SizedBox(
                width: constraints.maxWidth,
                child: _SearchDropdownPanel(
                  query: _controller.text,
                  filter: _filter,
                  maxHeight: panelHeight,
                  onFilterChanged: (filter) => setState(() => _filter = filter),
                  onSelected: _select,
                ),
              ),
            ),
          ],
        ),
        child: CompositedTransformTarget(
          link: _layerLink,
          child: AnimatedContainer(
            key: const Key('global-search-trigger'),
            duration: const Duration(milliseconds: 160),
            height: 48,
            padding: const EdgeInsets.only(left: 14, right: 4),
            decoration: BoxDecoration(
              color: const Color(0xE8FFFFFF),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: _open
                    ? const Color(0xFF8B5CF6)
                    : const Color(0x66AEB7D1),
                width: _open ? 1.5 : 1,
              ),
              boxShadow: _open
                  ? const [
                      BoxShadow(
                        color: Color(0x267C3AED),
                        blurRadius: 13,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 22,
                  color: Color(0xFF48506D),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const Key('global-search-field'),
                    controller: _controller,
                    focusNode: _focusNode,
                    onTap: _show,
                    onChanged: (_) {
                      _show();
                      setState(() {});
                    },
                    onSubmitted: (_) {
                      final matches = _matchingDestinations(
                        _controller.text,
                        _filter,
                      );
                      if (matches.isNotEmpty) _select(matches.first);
                    },
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF28324C),
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: 'Search pages, actions, files, and logs…',
                      hintStyle: TextStyle(
                        color: Color(0xFF78819E),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                if (_controller.text.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear search',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _controller.clear();
                      setState(() {});
                      _focusNode.requestFocus();
                    },
                    icon: const Icon(Icons.close_rounded, size: 20),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: _SearchShortcut('Ctrl K'),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 48,
    height: 52,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Center(child: Icon(Icons.notifications_none, size: 24)),
        Positioned(
          right: 0,
          top: 4,
          child: SizedBox(
            width: 20,
            height: 20,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '1',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar();

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFBFA3FF), Color(0xFF91B8FF), Color(0xFF4DC7FF)],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xD1FFFFFF)),
    ),
    child: const Icon(Icons.person_outline, color: Color(0xFF5E35B1)),
  );
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 48,
    height: 52,
    child: IconButton(
      icon: Icon(icon),
      onPressed: onPressed ?? () {},
      tooltip: tooltip,
    ),
  );
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({required this.currentIndex, required this.onSelect});

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final destinations = <_DesktopDestination>[
      const _DesktopDestination(
        'Dashboard',
        Icons.dashboard_outlined,
        NavFeature.dashboard,
        0,
      ),
      const _DesktopDestination(
        'AI Workspace',
        Icons.auto_awesome_outlined,
        NavFeature.aiWorkspace,
        5,
      ),
      const _DesktopDestination(
        'Motion',
        Icons.trending_up,
        NavFeature.motion,
        1,
      ),
      const _DesktopDestination(
        'AI Voice Studio',
        Icons.record_voice_over_outlined,
        NavFeature.voiceStudio,
        6,
      ),
      const _DesktopDestination(
        'Vision',
        Icons.visibility_outlined,
        NavFeature.vision,
        3,
      ),
      const _DesktopDestination(
        'Audio',
        Icons.graphic_eq_outlined,
        NavFeature.audio,
        2,
      ),
      const _DesktopDestination(
        'Controller',
        Icons.sports_esports_outlined,
        NavFeature.controller,
      ),
      const _DesktopDestination(
        'Manipulation',
        Icons.precision_manufacturing_outlined,
        NavFeature.manipulation,
      ),
      const _DesktopDestination(
        'Automation',
        Icons.account_tree_outlined,
        NavFeature.automation,
      ),
      const _DesktopDestination(
        'Files',
        Icons.folder_outlined,
        NavFeature.files,
      ),
      const _DesktopDestination(
        'Logs',
        Icons.article_outlined,
        NavFeature.logs,
      ),
      const _DesktopDestination(
        'Settings',
        Icons.settings_outlined,
        NavFeature.settings,
        4,
      ),
    ].where(_DesktopDestination.isShown);

    return Container(
      width: 200,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFDFBFF), Color(0xFFF6F5FF), Color(0xFFECF0FF)],
          stops: [0, .58, 1],
        ),
        border: Border(right: BorderSide(color: Color(0x1F9485D1))),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
              child: Column(
                children: [
                  for (final destination in destinations) ...[
                    _DesktopDestinationTile(
                      destination: destination,
                      selected: destination.branch == currentIndex,
                      onTap: destination.branch == null
                          ? null
                          : () => onSelect(destination.branch!),
                    ),
                    const SizedBox(height: 5),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(
            height: 292,
            child: OverflowBox(
              minWidth: 238,
              maxWidth: 238,
              alignment: Alignment.bottomCenter,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/images/robot_sidebar_bust.png',
                  width: 238,
                  height: 292,
                  alignment: Alignment.bottomCenter,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopDestination {
  const _DesktopDestination(this.label, this.icon, this.feature, [this.branch]);

  static bool isShown(_DesktopDestination destination) =>
      NavigationVisibility.isVisible(destination.feature);

  final NavFeature feature;

  final String label;
  final IconData icon;
  final int? branch;
}

class _DesktopDestinationTile extends StatelessWidget {
  const _DesktopDestinationTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _DesktopDestination destination;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: onTap != null,
    child: InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: Ink(
        height: 42,
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xA8DED1FF), Color(0x6BD1E3FF)],
                )
              : null,
          borderRadius: BorderRadius.circular(13),
          border: selected ? Border.all(color: const Color(0x298C61F5)) : null,
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x216338D6),
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            const SizedBox(width: 13),
            Icon(
              destination.icon,
              size: 18,
              color: selected
                  ? const Color(0xFF3D149E)
                  : const Color(0xE0333B57),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                destination.label,
                maxLines: 1,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF3D149E)
                      : const Color(0xE0333B57),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MediumRail extends StatelessWidget {
  const _MediumRail({required this.currentIndex, required this.onSelect});

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final destinations = <_DesktopDestination>[
      const _DesktopDestination(
        'Dashboard',
        Icons.dashboard_outlined,
        NavFeature.dashboard,
        0,
      ),
      const _DesktopDestination(
        'AI Agent',
        Icons.auto_awesome_outlined,
        NavFeature.aiWorkspace,
        5,
      ),
      const _DesktopDestination(
        'Control',
        Icons.sports_esports_outlined,
        NavFeature.motion,
        1,
      ),
      const _DesktopDestination(
        'Voice',
        Icons.record_voice_over_outlined,
        NavFeature.voiceStudio,
        6,
      ),
      const _DesktopDestination(
        'Perception',
        Icons.visibility_outlined,
        NavFeature.vision,
        3,
      ),
      const _DesktopDestination(
        'Settings',
        Icons.settings_outlined,
        NavFeature.settings,
        4,
      ),
    ].where(_DesktopDestination.isShown);
    return Container(
      width: 96,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      decoration: const BoxDecoration(
        color: Color(0xD9F8F8FF),
        border: Border(right: BorderSide(color: Color(0x1F9485D1))),
      ),
      child: Column(
        children: [
          for (final destination in destinations) ...[
            _MediumDestinationTile(
              destination: destination,
              selected: destination.branch == currentIndex,
              onTap: destination.branch == null
                  ? null
                  : () => onSelect(destination.branch!),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _MediumDestinationTile extends StatelessWidget {
  const _MediumDestinationTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _DesktopDestination destination;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,
    child: Ink(
      width: 72,
      height: 56,
      decoration: BoxDecoration(
        gradient: selected
            ? const LinearGradient(
                colors: [Color(0xA8DED1FF), Color(0x6BD1E3FF)],
              )
            : null,
        borderRadius: BorderRadius.circular(16),
        border: selected ? Border.all(color: const Color(0x298C61F5)) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            destination.icon,
            size: 20,
            color: selected ? const Color(0xFF3D149E) : const Color(0xFF4B5370),
          ),
          const SizedBox(height: 3),
          Text(
            destination.label,
            maxLines: 1,
            style: TextStyle(
              color: selected
                  ? const Color(0xFF3D149E)
                  : const Color(0xFF4B5370),
              fontSize: 10,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CompactNavigation extends StatelessWidget {
  const _CompactNavigation({
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = switch (currentIndex) {
      0 => 0,
      1 => 2,
      5 => 1,
      _ => 3,
    };
    return NavigationBar(
      height: 80,
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelect,
      backgroundColor: const Color(0xF2F8F8FF),
      indicatorColor: const Color(0x99DED1FF),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard_rounded),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.auto_awesome_outlined),
          label: 'AI Agent',
        ),
        NavigationDestination(
          icon: Icon(Icons.sports_esports_outlined),
          label: 'Control',
        ),
        NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Overflow'),
      ],
    );
  }
}

class _MoreDestinations extends StatelessWidget {
  const _MoreDestinations();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.record_voice_over_outlined),
            title: const Text('AI Voice Studio'),
            onTap: () => Navigator.pop(context, 6),
          ),
          ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: const Text('Vision'),
            onTap: () => Navigator.pop(context, 3),
          ),
          if (NavigationVisibility.isVisible(NavFeature.audio))
            ListTile(
              leading: const Icon(Icons.graphic_eq_outlined),
              title: const Text('Audio'),
              onTap: () => Navigator.pop(context, 2),
            ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () => Navigator.pop(context, 4),
          ),
        ],
      ),
    ),
  );
}

enum _SearchKind { page, action, file, log, mission }

enum _SearchFilter { all, pages, actions, files, logs }

List<_SearchDestination> _matchingDestinations(
  String query,
  _SearchFilter filter,
) {
  final terms = query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty)
      .toList(growable: false);
  final matches = _visibleSearchDestinations
      .where((item) {
        final matchesText =
            terms.isEmpty || terms.every(item.searchable.contains);
        final matchesFilter = switch (filter) {
          _SearchFilter.all => true,
          _SearchFilter.pages => item.kind == _SearchKind.page,
          _SearchFilter.actions => item.kind == _SearchKind.action,
          _SearchFilter.files =>
            item.kind == _SearchKind.file || item.kind == _SearchKind.mission,
          _SearchFilter.logs => item.kind == _SearchKind.log,
        };
        return matchesText && matchesFilter;
      })
      .toList(growable: false);
  if (terms.isNotEmpty) {
    final normalized = terms.join(' ');
    matches.sort((left, right) {
      int score(_SearchDestination item) {
        final title = item.title.toLowerCase();
        if (title == normalized) return 0;
        if (title.startsWith(normalized)) return 1;
        if (title.contains(normalized)) return 2;
        return 3;
      }

      return score(left).compareTo(score(right));
    });
  }
  return matches;
}

class _SearchDropdownPanel extends StatelessWidget {
  const _SearchDropdownPanel({
    required this.query,
    required this.filter,
    required this.maxHeight,
    required this.onFilterChanged,
    required this.onSelected,
  });

  final String query;
  final _SearchFilter filter;
  final double maxHeight;
  final ValueChanged<_SearchFilter> onFilterChanged;
  final ValueChanged<_SearchDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final matches = _matchingDestinations(query, filter);
    final pages = matches
        .where((item) => item.kind == _SearchKind.page)
        .toList();
    final actions = matches
        .where((item) => item.kind == _SearchKind.action)
        .toList();
    final resources = matches
        .where(
          (item) =>
              item.kind == _SearchKind.file ||
              item.kind == _SearchKind.log ||
              item.kind == _SearchKind.mission,
        )
        .toList();

    return Material(
      color: const Color(0xFFFDFDFF),
      elevation: 18,
      shadowColor: const Color(0x403A2D7A),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFDDE1EF)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SearchFilterBar(selected: filter, onChanged: onFilterChanged),
            const Divider(height: 1, color: Color(0xFFE7E9F2)),
            Flexible(
              child: matches.isEmpty
                  ? const _EmptySearchResults()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                      children: [
                        if (filter == _SearchFilter.all &&
                            query.trim().isNotEmpty)
                          _SearchResultSection(
                            title: 'Top results',
                            items: matches.take(3).toList(growable: false),
                            highlightedFirst: true,
                            onSelected: onSelected,
                          ),
                        if (pages.isNotEmpty)
                          _SearchResultSection(
                            title: filter == _SearchFilter.all
                                ? 'Pages'
                                : 'Page results',
                            items: pages,
                            onSelected: onSelected,
                          ),
                        if (actions.isNotEmpty)
                          _SearchResultSection(
                            title: 'Quick actions',
                            items: actions,
                            onSelected: onSelected,
                          ),
                        if (resources.isNotEmpty)
                          _SearchResultSection(
                            title: 'Files / Logs / Missions',
                            items: resources,
                            onSelected: onSelected,
                          ),
                      ],
                    ),
            ),
            if (query.trim().isNotEmpty)
              _SearchFooter(query: query, count: matches.length),
          ],
        ),
      ),
    );
  }
}

class _SearchFilterBar extends StatelessWidget {
  const _SearchFilterBar({required this.selected, required this.onChanged});

  final _SearchFilter selected;
  final ValueChanged<_SearchFilter> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 58,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      children: [
        for (final filter in _SearchFilter.values) ...[
          _SearchFilterChip(
            label: switch (filter) {
              _SearchFilter.all => 'All',
              _SearchFilter.pages => 'Pages',
              _SearchFilter.actions => 'Actions',
              _SearchFilter.files => 'Files',
              _SearchFilter.logs => 'Logs',
            },
            selected: filter == selected,
            onTap: () => onChanged(filter),
          ),
          if (filter != _SearchFilter.values.last) const SizedBox(width: 9),
        ],
      ],
    ),
  );
}

class _SearchFilterChip extends StatelessWidget {
  const _SearchFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFF6D22E8) : const Color(0xFFF2F2FA),
    borderRadius: BorderRadius.circular(999),
    child: InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF4B536E),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

class _SearchResultSection extends StatelessWidget {
  const _SearchResultSection({
    required this.title,
    required this.items,
    required this.onSelected,
    this.highlightedFirst = false,
  });

  final String title;
  final List<_SearchDestination> items;
  final ValueChanged<_SearchDestination> onSelected;
  final bool highlightedFirst;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 2, 0, 7),
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF313A59),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      for (var index = 0; index < items.length; index++)
        _SearchResultTile(
          item: items[index],
          shortcut: index + 1,
          highlighted: highlightedFirst && index == 0,
          onTap: () => onSelected(items[index]),
        ),
      const Divider(height: 18, color: Color(0xFFE7E9F2)),
    ],
  );
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.item,
    required this.shortcut,
    required this.highlighted,
    required this.onTap,
  });

  final _SearchDestination item;
  final int shortcut;
  final bool highlighted;
  final VoidCallback onTap;

  Color get _accent => switch (item.kind) {
    _SearchKind.page => const Color(0xFF6F2CF4),
    _SearchKind.action =>
      item.title == 'Emergency stop'
          ? const Color(0xFFE52B3F)
          : const Color(0xFF13A764),
    _SearchKind.file => const Color(0xFF7A2CF4),
    _SearchKind.log => const Color(0xFF3478F6),
    _SearchKind.mission => const Color(0xFF2684F5),
  };

  @override
  Widget build(BuildContext context) => Material(
    color: highlighted ? const Color(0xFFF2ECFF) : Colors.transparent,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.09),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: _accent, size: 21),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: highlighted
                          ? const Color(0xFF6520DE)
                          : const Color(0xFF26304F),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.section,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF68718E),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _SearchShortcut('⌘ $shortcut'),
            const SizedBox(width: 8),
          ],
        ),
      ),
    ),
  );
}

class _SearchShortcut extends StatelessWidget {
  const _SearchShortcut(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F7FC),
      border: Border.all(color: const Color(0xFFDDE1EF)),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      label,
      style: const TextStyle(color: Color(0xFF59627E), fontSize: 11),
    ),
  );
}

class _EmptySearchResults extends StatelessWidget {
  const _EmptySearchResults();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.search_off_rounded, size: 42, color: Color(0xFF7C849D)),
        SizedBox(height: 10),
        Text('No matching results'),
      ],
    ),
  );
}

class _SearchFooter extends StatelessWidget {
  const _SearchFooter({required this.query, required this.count});

  final String query;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xFFE7E9F2))),
    ),
    child: Row(
      children: [
        const Icon(Icons.search_rounded, size: 18, color: Color(0xFF68718E)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'See all $count results for “$query”',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF465172), fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _SearchDestination {
  const _SearchDestination({
    required this.title,
    required this.section,
    required this.route,
    required this.icon,
    required this.keywords,
    this.kind = _SearchKind.page,
  });

  final String title;
  final String section;
  final String route;
  final IconData icon;
  final String keywords;
  final _SearchKind kind;

  String get searchable => '$title $section $keywords'.toLowerCase();
}

/// Search entries whose destination is not hidden.
Iterable<_SearchDestination> get _visibleSearchDestinations =>
    _allSearchDestinations.where(
      (item) => NavigationVisibility.isRouteVisible(item.route),
    );

const _allSearchDestinations = <_SearchDestination>[
  _SearchDestination(
    title: 'Dashboard',
    section: 'Robot overview and live metrics',
    route: AppRoutes.dashboard,
    icon: Icons.dashboard_outlined,
    keywords:
        'home status robot battery cpu temperature network latency signal mission activity головна огляд робот батарея температура затримка місія',
  ),
  _SearchDestination(
    title: 'AI Workspace',
    section: 'Ask, inspect context, and execute',
    route: AppRoutes.aiWorkspace,
    icon: Icons.auto_awesome_outlined,
    keywords:
        'ai agent assistant context inspector command action intelligence штучний інтелект помічник команда',
  ),
  _SearchDestination(
    title: 'Motion',
    section: 'Gestures, recording, and playback',
    route: AppRoutes.motion,
    icon: Icons.motion_photos_auto_outlined,
    keywords:
        'movement saved motions record play pause loop queue hello bye kiss handshake nod thumbs up celebrate bow clap point рух жести запис відтворення',
  ),
  _SearchDestination(
    title: 'AI Voice Studio',
    section: 'Realtime speaking, text-to-speech, and quick motions',
    route: AppRoutes.voiceStudio,
    icon: Icons.record_voice_over_outlined,
    keywords:
        'voice ai conversation realtime speak speech tts text to speech transcript phrases microphone speaker голос розмова мовлення',
  ),
  _SearchDestination(
    title: 'Audio',
    section: 'Microphone, speaker, and voice',
    route: AppRoutes.audio,
    icon: Icons.graphic_eq_outlined,
    keywords:
        'sound volume input output speech microphone speaker звук гучність мікрофон динамік голос',
  ),
  _SearchDestination(
    title: 'Vision',
    section: 'Camera and perception',
    route: AppRoutes.vision,
    icon: Icons.visibility_outlined,
    keywords:
        'camera stream detection objects sensors perception зір камера розпізнавання об’єкти сенсори',
  ),
  _SearchDestination(
    title: 'Settings',
    section: 'Application and robot configuration',
    route: AppRoutes.settings,
    icon: Icons.settings_outlined,
    keywords:
        'preferences configuration connectivity wifi bluetooth platform api ports peripherals safety notifications appearance налаштування підключення вайфай блютуз порти безпека',
  ),
  _SearchDestination(
    title: 'Connectivity',
    section: 'Settings · Wi-Fi, Bluetooth, platform, and ports',
    route: AppRoutes.settings,
    icon: Icons.wifi_rounded,
    keywords:
        'network api usb controller dock camera auxiliary expansion audio input output мережа підключення порти',
  ),
  _SearchDestination(
    title: 'Quick gestures',
    section: 'Motion · Play common robot gestures',
    route: AppRoutes.motion,
    icon: Icons.bolt_rounded,
    keywords:
        'hello bye kiss handshake nod thumbs celebrate bow clap point жести',
    kind: _SearchKind.action,
  ),
  _SearchDestination(
    title: 'Start recording',
    section: 'Motion · Record a new motion sequence',
    route: AppRoutes.motion,
    icon: Icons.fiber_manual_record_rounded,
    keywords:
        'start record recording new motion timer category tag save почати запис рух зберегти',
    kind: _SearchKind.action,
  ),
  _SearchDestination(
    title: 'Playback controls',
    section: 'Motion · Play, pause, speed, loop, and queue',
    route: AppRoutes.motion,
    icon: Icons.play_circle_outline_rounded,
    keywords:
        'play pause stop speed loop queue robot відтворення швидкість черга',
    kind: _SearchKind.action,
  ),
  _SearchDestination(
    title: 'Open Motion',
    section: 'Configure and control robot motion',
    route: AppRoutes.motion,
    icon: Icons.trending_up_rounded,
    keywords: 'motion movement gait behavior open control рух керування',
    kind: _SearchKind.action,
  ),
  _SearchDestination(
    title: 'Start scan',
    section: 'Begin a new environment scan',
    route: AppRoutes.vision,
    icon: Icons.play_circle_outline_rounded,
    keywords: 'vision camera scan environment start сканування камера',
    kind: _SearchKind.action,
  ),
  _SearchDestination(
    title: 'Emergency stop',
    section: 'Immediately stop all robot motion',
    route: AppRoutes.dashboard,
    icon: Icons.stop_circle_outlined,
    keywords: 'stop safety motion robot emergency аварійна зупинка безпека',
    kind: _SearchKind.action,
  ),
  _SearchDestination(
    title: 'fake_hello.json',
    section: 'File · Saved motion',
    route: AppRoutes.motion,
    icon: Icons.insert_drive_file_outlined,
    keywords: 'file json motion hello saved файл рух',
    kind: _SearchKind.file,
  ),
  _SearchDestination(
    title: 'macarena.json',
    section: 'File · Saved motion',
    route: AppRoutes.motion,
    icon: Icons.insert_drive_file_outlined,
    keywords: 'file json motion dance saved файл танець',
    kind: _SearchKind.file,
  ),
  _SearchDestination(
    title: '67.json',
    section: 'File · Saved motion',
    route: AppRoutes.motion,
    icon: Icons.insert_drive_file_outlined,
    keywords: '67 file json motion custom saved файл рух',
    kind: _SearchKind.file,
  ),
  _SearchDestination(
    title: 'fuck.json',
    section: 'File · Saved motion',
    route: AppRoutes.motion,
    icon: Icons.insert_drive_file_outlined,
    keywords: 'file json motion custom saved файл рух',
    kind: _SearchKind.file,
  ),
  _SearchDestination(
    title: 'kiril.json',
    section: 'File · Saved motion',
    route: AppRoutes.motion,
    icon: Icons.insert_drive_file_outlined,
    keywords: 'file json motion custom saved файл рух',
    kind: _SearchKind.file,
  ),
  _SearchDestination(
    title: 'max_dance.json',
    section: 'File · Saved motion',
    route: AppRoutes.motion,
    icon: Icons.insert_drive_file_outlined,
    keywords: 'file json motion dance saved файл танець',
    kind: _SearchKind.file,
  ),
  _SearchDestination(
    title: 'omg.json',
    section: 'File · Saved motion',
    route: AppRoutes.motion,
    icon: Icons.insert_drive_file_outlined,
    keywords: 'file json motion reaction saved файл рух',
    kind: _SearchKind.file,
  ),
  _SearchDestination(
    title: 'trump_dance.json',
    section: 'File · Saved motion',
    route: AppRoutes.motion,
    icon: Icons.insert_drive_file_outlined,
    keywords: 'file json motion dance saved файл танець',
    kind: _SearchKind.file,
  ),
  _SearchDestination(
    title: 'ziga.json',
    section: 'File · Saved motion',
    route: AppRoutes.motion,
    icon: Icons.insert_drive_file_outlined,
    keywords: 'file json motion gesture saved файл жест',
    kind: _SearchKind.file,
  ),
  _SearchDestination(
    title: 'Vision calibration verified',
    section: 'Log · Vision system',
    route: AppRoutes.vision,
    icon: Icons.visibility_outlined,
    keywords: 'log calibration camera verified журнал калібрування камера',
    kind: _SearchKind.log,
  ),
  _SearchDestination(
    title: 'Warehouse aisle inspection',
    section: 'Mission · Scanning aisle B',
    route: AppRoutes.dashboard,
    icon: Icons.calendar_month_outlined,
    keywords:
        'mission warehouse inspection scanning motion місія склад перевірка',
    kind: _SearchKind.mission,
  ),
];

class _PlatformSearchDelegate extends SearchDelegate<String> {
  _PlatformSearchDelegate()
    : super(searchFieldLabel: 'Search pages, settings, and motions');

  List<_SearchDestination> get _matches {
    final terms = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty);
    if (terms.isEmpty) {
      return _visibleSearchDestinations.take(6).toList(growable: false);
    }
    return _visibleSearchDestinations
        .where((item) => terms.every(item.searchable.contains))
        .toList(growable: false);
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF5F4FF),
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: const Color(0xFFFDFDFF),
        foregroundColor: const Color(0xFF28324C),
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        tooltip: 'Clear search',
        onPressed: () => query = '',
        icon: const Icon(Icons.close_rounded),
      ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    tooltip: 'Close search',
    onPressed: () => close(context, ''),
    icon: const Icon(Icons.arrow_back_rounded),
  );

  @override
  Widget buildResults(BuildContext context) => _buildMatches(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildMatches(context);

  Widget _buildMatches(BuildContext context) {
    final matches = _matches;
    if (matches.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 44, color: Color(0xFF79809A)),
            SizedBox(height: 12),
            Text('No matching pages or settings'),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: matches.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = matches[index];
        return Material(
          color: const Color(0xD9FFFFFF),
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            key: ValueKey('global-search-result-${item.title}'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            leading: Icon(item.icon, color: AppColors.primary),
            title: Text(item.title),
            subtitle: Text(
              item.section,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () => close(context, item.route),
          ),
        );
      },
    );
  }
}
