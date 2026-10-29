import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../foundation/tokens.dart';

enum RiverButtonVariant { primary, secondary, outline, ghost, destructive }

/// A labeled action button.
///
/// Wraps `ShadButton` and adds what OpenRiver requires of every action:
///
/// - a height of at least [RiverSizes.minTapTarget] that grows with the text
///   scale, wrapping long labels rather than clipping them;
/// - activation with Enter and Space while focused;
/// - a disabled state while [busy] or when [onPressed] is null.
class RiverButton extends StatelessWidget {
  const RiverButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = RiverButtonVariant.primary,
    this.busy = false,
    this.expand = false,
    this.focusNode,
    this.autofocus = false,
  });

  final String label;

  /// Called on tap or keyboard activation. Null disables the button.
  final VoidCallback? onPressed;

  /// Optional leading icon. It is decorative; [label] is spoken.
  final IconData? icon;

  final RiverButtonVariant variant;

  /// Disables the button while an action started by it is running.
  final bool busy;

  /// Whether the button fills the available width.
  final bool expand;

  final FocusNode? focusNode;
  final bool autofocus;

  static const _iconGap = 8.0;

  bool get _enabled => onPressed != null && !busy;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final (shadVariant, buttonTheme) = switch (variant) {
      RiverButtonVariant.primary => (
        ShadButtonVariant.primary,
        theme.primaryButtonTheme,
      ),
      RiverButtonVariant.secondary => (
        ShadButtonVariant.secondary,
        theme.secondaryButtonTheme,
      ),
      RiverButtonVariant.outline => (
        ShadButtonVariant.outline,
        theme.outlineButtonTheme,
      ),
      RiverButtonVariant.ghost => (
        ShadButtonVariant.ghost,
        theme.ghostButtonTheme,
      ),
      RiverButtonVariant.destructive => (
        ShadButtonVariant.destructive,
        theme.destructiveButtonTheme,
      ),
    };
    final padding =
        buttonTheme.sizesTheme?.regular?.padding ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    // Space ShadButton adds around its label: the decorator's focus-ring
    // padding outside, and the variant's border inside.
    final ringSpace =
        (buttonTheme.decoration ?? theme.decoration).border?.padding ??
        EdgeInsets.zero;
    final border =
        buttonTheme.border?.dimensions.resolve(Directionality.of(context)) ??
        EdgeInsets.zero;
    final iconSize = RiverSizes.instance.iconSmall;

    return LayoutBuilder(
      builder: (context, constraints) {
        final iconExtent = icon == null ? 0.0 : iconSize + _iconGap;
        final textMaxWidth = math.max(
          0.0,
          constraints.maxWidth -
              ringSpace.horizontal -
              border.horizontal -
              padding.horizontal -
              iconExtent,
        );
        final textHeight = _measureText(context, theme, textMaxWidth);
        final height = math.max(
          RiverSizes.instance.minTapTarget,
          textHeight + padding.vertical + border.vertical,
        );

        final button = ShadButton.raw(
          variant: shadVariant,
          enabled: _enabled,
          onPressed: _enabled ? onPressed : null,
          focusNode: focusNode,
          autofocus: autofocus,
          height: height,
          width: expand && constraints.hasBoundedWidth
              ? constraints.maxWidth - ringSpace.horizontal
              : null,
          padding: padding,
          icon: icon == null
              ? null
              : Padding(
                  padding: const EdgeInsetsDirectional.only(end: _iconGap),
                  child: ExcludeSemantics(child: Icon(icon, size: iconSize)),
                ),
          text: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: textMaxWidth),
            child: Text(label, textAlign: TextAlign.center),
          ),
        );

        return Actions(
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                if (_enabled) onPressed!();
                return null;
              },
            ),
          },
          // One node carries the label, button role, state, and tap action.
          child: MergeSemantics(child: button),
        );
      },
    );
  }

  double _measureText(
    BuildContext context,
    ShadThemeData theme,
    double maxWidth,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: theme.textTheme.small),
      textAlign: TextAlign.center,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout(maxWidth: maxWidth);
    final height = painter.height;
    painter.dispose();
    return height;
  }
}
