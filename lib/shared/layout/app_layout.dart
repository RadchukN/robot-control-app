import 'package:flutter/widgets.dart';

/// Window classes shared by the shell and the screens.
///
/// Phones on their side are wide but short, so height decides as well as
/// width: a 915x412 phone must never get the desktop header and sidebar.
abstract final class AppLayout {
  static const landscapeMaxHeight = 480.0;
  static const landscapeMinWidth = 560.0;

  /// Minimum touch target on the landscape phone layout.
  static const touchTarget = 48.0;

  static bool isLandscapeCompact(Size size) =>
      size.height < landscapeMaxHeight && size.width >= landscapeMinWidth;

  /// True when the whole window is a short landscape viewport.
  static bool landscapeOf(BuildContext context) =>
      isLandscapeCompact(MediaQuery.sizeOf(context));
}
