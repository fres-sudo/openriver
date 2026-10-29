import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// The light and dark themes used by every OpenRiver screen.
abstract final class RiverThemes {
  static final light = ShadThemeData(
    colorScheme: const ShadGreenColorScheme.light(),
    brightness: Brightness.light,
  );

  static final dark = ShadThemeData(
    colorScheme: const ShadGreenColorScheme.dark(),
    brightness: Brightness.dark,
  );
}
