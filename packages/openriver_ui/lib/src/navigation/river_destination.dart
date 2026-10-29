import 'package:flutter/widgets.dart';

/// A top-level place in the app, shown in the shell's navigation.
@immutable
final class RiverDestination {
  const RiverDestination({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.badgeCount,
  }) : assert(badgeCount == null || badgeCount >= 0);

  /// Visible and spoken name. Keep it short; it may wrap to two lines.
  final String label;

  final IconData icon;

  /// Icon while selected; defaults to [icon].
  final IconData? selectedIcon;

  /// A count of new items. Zero or null shows no badge.
  final int? badgeCount;
}

/// The app-wide primary action, such as importing a hand history.
///
/// The shell places it at the top of the sidebar or rail. With a bottom bar,
/// `RiverPageHeader` shows it among the page's actions.
@immutable
final class RiverShellAction {
  const RiverShellAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final IconData icon;

  /// Null disables the action.
  final VoidCallback? onPressed;

  /// Disables the action while the work it started is running.
  final bool busy;

  bool get enabled => onPressed != null && !busy;

  @override
  bool operator ==(Object other) =>
      other is RiverShellAction &&
      other.label == label &&
      other.icon == icon &&
      other.onPressed == onPressed &&
      other.busy == busy;

  @override
  int get hashCode => Object.hash(label, icon, onPressed, busy);
}
