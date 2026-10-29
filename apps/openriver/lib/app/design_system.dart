import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Shared visual foundation for every OpenRiver screen.
abstract final class OpenRiverDesignSystem {
  static final lightTheme = ShadThemeData(
    colorScheme: const ShadGreenColorScheme.light(),
    brightness: Brightness.light,
  );

  static final darkTheme = ShadThemeData(
    colorScheme: const ShadGreenColorScheme.dark(),
    brightness: Brightness.dark,
  );

  static const double compactBreakpoint = 600;
  static const double contentMaxWidth = 960;
  static const double compactPagePadding = 24;
  static const double widePagePadding = 48;
}
