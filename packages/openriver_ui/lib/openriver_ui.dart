/// OpenRiver UI kit.
///
/// Feature code imports this library instead of `shadcn_ui`, which it
/// re-exports.
library;

// `ShadApp.themeMode` uses Material's enum; it is the only Material export.
export 'package:flutter/material.dart' show ThemeMode;
export 'package:shadcn_ui/shadcn_ui.dart';

export 'src/context.dart';
export 'src/foundation/tokens.dart';
export 'src/l10n/river_localizations.dart';
export 'src/layout/river_layout.dart';
export 'src/layout/window_class.dart';
export 'src/theme/river_themes.dart';
