/// Spacing scale shared by every OpenRiver layout.
///
/// Spacing is in logical pixels and follows multiples of 8, with 4 and 12 for
/// tight component compositions.
final class RiverSpacing {
  const RiverSpacing._();

  static const instance = RiverSpacing._();

  final double xs = 4;
  final double sm = 8;
  final double md = 12;
  final double lg = 16;
  final double xl = 24;
  final double xxl = 32;
  final double xxxl = 48;
}

/// Fixed component and layout sizes.
final class RiverSizes {
  const RiverSizes._();

  static const instance = RiverSizes._();

  /// Minimum width and height of any interactive target.
  final double minTapTarget = 48;

  final double iconSmall = 16;
  final double icon = 20;
  final double iconLarge = 32;

  /// Default maximum width of page content.
  final double contentMaxWidth = 960;

  /// Maximum width of data-dense pages, such as tables and lists.
  final double wideContentMaxWidth = 1280;
}

/// Durations for transitions. Callers must skip animation when
/// `MediaQuery.disableAnimationsOf(context)` is true.
final class RiverDurations {
  const RiverDurations._();

  static const instance = RiverDurations._();

  final Duration fast = const Duration(milliseconds: 120);
  final Duration normal = const Duration(milliseconds: 200);
  final Duration slow = const Duration(milliseconds: 300);
}
