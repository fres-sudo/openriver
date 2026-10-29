import 'package:flutter/widgets.dart';

/// Width classes used for responsive decisions.
///
/// The boundaries follow the Material 3 window size classes. A class describes
/// available width only; it says nothing about the device or operating system.
enum RiverWindowClass {
  /// Less than 600 logical pixels.
  compact(0),

  /// 600 to 839 logical pixels.
  medium(600),

  /// 840 to 1199 logical pixels.
  expanded(840),

  /// 1200 to 1599 logical pixels.
  large(1200),

  /// 1600 logical pixels or more.
  extraLarge(1600);

  const RiverWindowClass(this.minWidth);

  /// Smallest width, inclusive, that belongs to this class.
  final double minWidth;

  /// Returns the class for [width]. Negative, infinite, and NaN widths are
  /// treated as the nearest valid class.
  static RiverWindowClass fromWidth(double width) {
    if (width.isNaN) return compact;
    for (final windowClass in values.reversed) {
      if (width >= windowClass.minWidth) return windowClass;
    }
    return compact;
  }

  /// Returns the class used to choose navigation for a window of [width] at
  /// the given [textScaler].
  ///
  /// Larger text needs more room for labels, so the width is divided by the
  /// effective text scale, clamped to 1–2. At twice the text size, a 700-pixel
  /// window is treated as compact.
  static RiverWindowClass forNavigation(double width, TextScaler textScaler) =>
      fromWidth(width / effectiveTextScale(textScaler));

  /// The text scale factor applied to body-sized text, clamped to 1–2.
  static double effectiveTextScale(TextScaler textScaler) {
    const bodyFontSize = 14.0;
    final scale = textScaler.scale(bodyFontSize) / bodyFontSize;
    if (scale.isNaN) return 1;
    return scale.clamp(1.0, 2.0);
  }

  bool operator >=(RiverWindowClass other) => index >= other.index;
  bool operator >(RiverWindowClass other) => index > other.index;
  bool operator <=(RiverWindowClass other) => index <= other.index;
  bool operator <(RiverWindowClass other) => index < other.index;
}
