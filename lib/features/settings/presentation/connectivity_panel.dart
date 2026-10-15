part of 'settings_screen.dart';

class _DesktopConnectivityLayout extends StatelessWidget {
  const _DesktopConnectivityLayout({
    required this.settingsState,
    required this.state,
    required this.controller,
    required this.wide,
    required this.onCategorySelected,
  });
  final SettingsState settingsState;
  final ConnectivityState state;
  final ConnectivityController controller;
  final bool wide;
  final ValueChanged<SettingsCategory> onCategorySelected;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: wide ? 250 : 228,
        child: _CategoryRail(
          selected: settingsState.category,
          query: settingsState.searchQuery,
          onSelected: onCategorySelected,
        ),
      ),
      const SizedBox(width: AppSpacing.md),
      const Expanded(child: _ConnectivityResponsivePanel()),
    ],
  );
}

class _ConnectivityResponsivePanel extends StatelessWidget {
  const _ConnectivityResponsivePanel({
    this.state,
    this.controller,
    this.compact = false,
  });
  final ConnectivityState? state;
  final ConnectivityController? controller;
  final bool compact;

  @override
  Widget build(BuildContext context) => const KeyedSubtree(
    key: Key('connectivity-panel'),
    child: RobotConnectionPanel(),
  );
}
