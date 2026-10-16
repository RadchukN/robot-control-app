import 'package:robot_control_app/core/routing/app_routes.dart';

/// Every destination the app navigation can offer.
enum NavFeature {
  dashboard,
  aiWorkspace,
  motion,
  voiceStudio,
  vision,
  audio,
  controller,
  manipulation,
  automation,
  files,
  logs,
  settings,
}

/// Which destinations the sidebar, rails, menus and search show.
///
/// Unfinished destinations stay defined, with their screens and routes, and
/// are only hidden here. Remove a feature from [hidden] to bring it back.
abstract final class NavigationVisibility {
  /// Not ready for operators yet.
  ///
  /// [NavFeature.audio] is the placeholder Audio page only. Audio Devices in
  /// Settings > Connectivity and AI Voice Studio are separate and stay.
  static const hidden = <NavFeature>{
    NavFeature.audio,
    NavFeature.controller,
    NavFeature.manipulation,
    NavFeature.automation,
    NavFeature.files,
    NavFeature.logs,
  };

  /// Routes owned by a destination that can be hidden.
  static const _routes = <String, NavFeature>{
    AppRoutes.audio: NavFeature.audio,
  };

  static bool isVisible(NavFeature feature) => !hidden.contains(feature);

  /// False for the route of a hidden destination; such routes redirect to
  /// the Dashboard, so stale links and restored state cannot open them.
  static bool isRouteVisible(String route) {
    final feature = _routes[route];
    return feature == null || isVisible(feature);
  }
}
