import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../foundation/tokens.dart';
import '../l10n/river_localizations.dart';

/// How a [NavItem] arranges its icon and label.
enum NavItemLayout {
  /// Icon above a short label: bottom bar and rail.
  stacked,

  /// Icon beside the label: sidebar.
  inline,

  /// Icon only, with a tooltip and spoken label.
  iconOnly,
}

/// One focusable entry in the shell's navigation.
///
/// Built from Flutter primitives because shadcn_ui 0.2.6 has no navigation
/// controls. Destinations announce a selected state within a mutually
/// exclusive group; other entries, such as the primary action or sidebar
/// toggle, are plain buttons.
class NavItem extends StatefulWidget {
  const NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.layout,
    this.selected = false,
    this.isDestination = true,
    this.badgeCount,
    this.prominent = false,
    this.mirrorIconInRtl = false,
  });

  final IconData icon;
  final String label;

  /// Null disables the item.
  final VoidCallback? onPressed;
  final NavItemLayout layout;
  final bool selected;

  /// Whether this item is one of a group of destinations.
  final bool isDestination;
  final int? badgeCount;

  /// Draws the item with the primary color, for the shell's primary action.
  final bool prominent;

  /// Flips the icon in right-to-left layouts, for icons that point to a side.
  final bool mirrorIconInRtl;

  @override
  State<NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<NavItem> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _activate() {
    if (_enabled) widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colors = theme.colorScheme;
    final sizes = RiverSizes.instance;
    final spacing = RiverSpacing.instance;
    final strings = RiverLocalizations.of(context);
    final badge = widget.badgeCount ?? 0;

    final Color background;
    final Color foreground;
    if (widget.prominent) {
      background = _hovered || _pressed
          ? Color.lerp(colors.primary, colors.background, 0.1)!
          : colors.primary;
      foreground = colors.primaryForeground;
    } else if (widget.selected) {
      (background, foreground) = (colors.secondary, colors.secondaryForeground);
    } else if (_hovered || _pressed) {
      (background, foreground) = (colors.accent, colors.accentForeground);
    } else {
      (background, foreground) = (
        const Color(0x00000000),
        colors.mutedForeground,
      );
    }
    final textStyle = theme.textTheme.small.copyWith(
      color: foreground,
      fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
    );

    Widget icon = Icon(widget.icon, size: sizes.icon, color: foreground);
    if (widget.mirrorIconInRtl &&
        Directionality.of(context) == TextDirection.rtl) {
      icon = Transform.flip(flipX: true, child: icon);
    }
    if (badge > 0 && widget.layout != NavItemLayout.inline) {
      icon = _BadgeAnchor(count: badge, child: icon);
    }

    final label = Text(
      widget.label,
      style: textStyle,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: widget.layout == NavItemLayout.stacked
          ? TextAlign.center
          : TextAlign.start,
    );

    final content = switch (widget.layout) {
      NavItemLayout.stacked => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          SizedBox(height: spacing.xs),
          label,
        ],
      ),
      NavItemLayout.inline => Row(
        children: [
          icon,
          SizedBox(width: spacing.md),
          Expanded(child: label),
          if (badge > 0) ...[SizedBox(width: spacing.sm), _Badge(count: badge)],
        ],
      ),
      NavItemLayout.iconOnly => icon,
    };

    Widget item = Container(
      constraints: BoxConstraints(
        minWidth: sizes.minTapTarget,
        minHeight: sizes.minTapTarget,
      ),
      padding: switch (widget.layout) {
        NavItemLayout.stacked => EdgeInsets.symmetric(
          horizontal: spacing.xs,
          vertical: spacing.sm,
        ),
        NavItemLayout.inline => EdgeInsets.symmetric(
          horizontal: spacing.md,
          vertical: spacing.sm,
        ),
        NavItemLayout.iconOnly => EdgeInsets.all(spacing.md),
      },
      decoration: BoxDecoration(
        color: background,
        borderRadius: theme.radius,
        border: Border.all(
          width: 2,
          color: _focused ? colors.ring : const Color(0x00000000),
        ),
      ),
      // Size factors keep the item as small as its content allows; a bare
      // alignment would stretch it to fill the bottom bar's height.
      child: Align(
        alignment: widget.layout == NavItemLayout.inline
            ? AlignmentDirectional.centerStart
            : Alignment.center,
        widthFactor: widget.layout == NavItemLayout.inline ? null : 1,
        heightFactor: 1,
        child: content,
      ),
    );

    item = Opacity(opacity: _enabled ? 1 : 0.5, child: item);

    final spokenLabel = badge > 0
        ? '${widget.label}, ${strings.badgeCount(badge)}'
        : widget.label;

    item = Semantics(
      container: true,
      button: true,
      enabled: _enabled,
      selected: widget.isDestination ? widget.selected : null,
      inMutuallyExclusiveGroup: widget.isDestination ? true : null,
      label: spokenLabel,
      onTap: _enabled ? _activate : null,
      // The detector's focus state joins this node; the visuals are hidden
      // because the label above already describes them.
      child: FocusableActionDetector(
        enabled: _enabled,
        mouseCursor: _enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTap: _enabled ? _activate : null,
          onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: ExcludeSemantics(child: item),
        ),
      ),
    );

    if (widget.layout == NavItemLayout.iconOnly) {
      item = ShadTooltip(builder: (_) => Text(widget.label), child: item);
    }
    return item;
  }
}

/// Places a small count badge over the top end of [child].
class _BadgeAnchor extends StatelessWidget {
  const _BadgeAnchor({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      child,
      PositionedDirectional(top: -6, end: -10, child: _Badge(count: count)),
    ],
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: theme.textTheme.small.copyWith(
          fontSize: 12,
          height: 1.3,
          color: theme.colorScheme.primaryForeground,
        ),
      ),
    );
  }
}
