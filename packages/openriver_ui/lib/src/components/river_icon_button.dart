import 'package:flutter/widgets.dart';

import '../navigation/nav_item.dart';

/// An action shown only as an icon, such as closing an overlay.
///
/// [label] is spoken and shown as a tooltip. The target is at least 48 by 48
/// logical pixels, and Enter and Space activate it while focused.
class RiverIconButton extends StatelessWidget {
  const RiverIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.mirrorInRtl = false,
  });

  final IconData icon;
  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// Flips the icon in right-to-left layouts, for icons that point to a side.
  final bool mirrorInRtl;

  @override
  Widget build(BuildContext context) => NavItem(
    icon: icon,
    label: label,
    onPressed: onPressed,
    layout: NavItemLayout.iconOnly,
    isDestination: false,
    mirrorIconInRtl: mirrorInRtl,
  );
}
