import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// The light and dark themes used by every OpenRiver screen.
///
/// Both start from `ShadGreenColorScheme`. Colors whose text contrast falls
/// below WCAG AA (4.5:1 for body text) are replaced; tests check the ratios.
abstract final class RiverThemes {
  static final light = ShadThemeData(
    colorScheme: const ShadGreenColorScheme.light(
      // Stock green-600 on rose-50 is 3.0:1. Green-700 on white is 5.0:1.
      primary: Color(0xff15803d),
      primaryForeground: Color(0xffffffff),
      ring: Color(0xff15803d),
      // Stock zinc-500 on the muted surface is 4.4:1. Zinc-600 is 7.0:1.
      mutedForeground: Color(0xff52525b),
      // Stock red-500 on near-white is 3.6:1. Red-700 on white is 6.5:1.
      destructive: Color(0xffb91c1c),
      destructiveForeground: Color(0xffffffff),
    ),
    brightness: Brightness.light,
  );

  static final dark = ShadThemeData(
    colorScheme: const ShadGreenColorScheme.dark(
      // Alerts draw destructive as text. Stock red-900 on the background is
      // 2.0:1; red-400 is 7.1:1, and red-950 text on it is 5.8:1.
      destructive: Color(0xfff87171),
      destructiveForeground: Color(0xff450a0a),
    ),
    brightness: Brightness.dark,
  );
}
