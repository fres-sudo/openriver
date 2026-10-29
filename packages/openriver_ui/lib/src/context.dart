import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'foundation/tokens.dart';
import 'l10n/river_localizations.dart';
import 'layout/river_layout.dart';
import 'layout/window_class.dart';

/// Entry point for shared UI state: `context.app.theme.colors`,
/// `context.app.responsive.isMobile`, and so on.
extension RiverContextAccess on BuildContext {
  RiverAppContext get app => RiverAppContext(this);
}

/// Shared UI state reachable from a [BuildContext].
///
/// Every getter performs its lookup when called and registers the matching
/// dependency, so a widget rebuilds when what it read changes. Do not keep
/// results across builds or async gaps.
///
/// Apps add their own members, such as generated localizations, with an
/// extension on this type that reads [buildContext].
extension type const RiverAppContext(BuildContext buildContext) {
  RiverThemeAccess get theme => RiverThemeAccess(buildContext);

  RiverResponsiveAccess get responsive => RiverResponsiveAccess(buildContext);

  RiverInputAccess get input => const RiverInputAccess();

  RiverLocalizations get riverLocalizations =>
      RiverLocalizations.of(buildContext);
}

/// Theme values from the nearest `ShadTheme`, plus fixed design tokens.
extension type const RiverThemeAccess(BuildContext _context) {
  /// The full Shad theme, for component themes not surfaced here.
  ShadThemeData get data => ShadTheme.of(_context);

  ShadColorScheme get colors => data.colorScheme;

  ShadTextTheme get textTheme => data.textTheme;

  Brightness get brightness => data.brightness;

  BorderRadius get radius => data.radius;

  RiverSpacing get spacing => RiverSpacing.instance;

  RiverSizes get sizes => RiverSizes.instance;

  RiverDurations get durations => RiverDurations.instance;
}

/// Responsive classes from the nearest [RiverLayout].
///
/// [isMobile], [isTablet], and [isDesktop] describe the window's width class,
/// not the device: a narrow desktop window is mobile. Use [content] for layout
/// inside a page and [RiverInputAccess.isTouch] for touch-specific behavior.
extension type const RiverResponsiveAccess(BuildContext _context) {
  RiverWindowClass get window =>
      RiverLayout.of(_context, RiverLayoutAspect.window);

  /// Window class adjusted for text scale; chooses the shell's navigation.
  RiverWindowClass get navigation =>
      RiverLayout.of(_context, RiverLayoutAspect.navigation);

  /// Width class of the region this widget is laid out in.
  RiverWindowClass get content =>
      RiverLayout.of(_context, RiverLayoutAspect.content);

  bool get isMobile => window == RiverWindowClass.compact;

  bool get isTablet => window == RiverWindowClass.medium;

  bool get isDesktop => window >= RiverWindowClass.expanded;
}

/// Primary input modality of the current platform.
extension type const RiverInputAccess._(Object? _) {
  const RiverInputAccess() : this._(null);

  /// Whether the platform's primary input is touch (Android, iOS, Fuchsia).
  bool get isTouch => switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.fuchsia => true,
    TargetPlatform.linux ||
    TargetPlatform.macOS ||
    TargetPlatform.windows => false,
  };

  /// Whether hover affordances, such as tooltips on hover, are expected.
  bool get hasHover => !isTouch;
}
