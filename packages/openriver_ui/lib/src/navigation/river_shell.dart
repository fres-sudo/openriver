import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../components/river_button.dart';
import '../foundation/tokens.dart';
import '../l10n/river_localizations.dart';
import '../layout/river_layout.dart';
import '../layout/window_class.dart';
import 'nav_item.dart';
import 'river_destination.dart';
import 'river_shell_scope.dart';

/// The app frame: top-level navigation around a body.
///
/// The navigation form follows the text-scale-adjusted window class:
///
/// | Class | Form |
/// | --- | --- |
/// | compact | bottom bar |
/// | medium | rail |
/// | expanded and wider | sidebar, which the user can collapse to a rail |
///
/// Wide but short windows, such as a phone in landscape, use the rail.
///
/// The shell does not know about routing. It reports selections through
/// [onDestinationSelected] and [onDestinationReselected]; the app changes
/// [selectedIndex] and [body] in response. [body] keeps its element, and so
/// its state, when the navigation form changes.
class RiverShell extends StatefulWidget {
  RiverShell({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.onDestinationReselected,
    this.primaryAction,
    this.brand,
    this.initiallyCollapsed = false,
    this.onCollapsedChanged,
  }) : assert(destinations.isNotEmpty, 'Provide at least one destination.'),
       assert(
         selectedIndex >= 0 && selectedIndex < destinations.length,
         'selectedIndex must refer to a destination.',
       );

  final List<RiverDestination> destinations;
  final int selectedIndex;

  /// Called with the index of a destination other than the selected one.
  final ValueChanged<int> onDestinationSelected;

  /// Called when the selected destination is chosen again. Apps typically
  /// return to the destination's root page, or scroll to the top if already
  /// there.
  final ValueChanged<int>? onDestinationReselected;

  final Widget body;
  final RiverShellAction? primaryAction;

  /// Shown at the top of the expanded sidebar, such as the app name.
  final Widget? brand;

  /// Whether the sidebar starts collapsed to a rail.
  final bool initiallyCollapsed;

  /// Called when the user collapses or expands the sidebar, for persistence.
  final ValueChanged<bool>? onCollapsedChanged;

  /// Most destinations a bottom bar can hold.
  static const maxBottomBarDestinations = 5;

  /// Destinations selectable with ⌘ or Ctrl and a digit.
  static const maxShortcutDestinations = 9;

  /// Wide windows shorter than this use the rail instead of the sidebar.
  static const minSidebarHeight = 480.0;

  /// Returns the navigation form for the given classes and window height.
  @visibleForTesting
  static RiverNavigationForm formFor({
    required RiverWindowClass navigationClass,
    required double height,
    required bool collapsed,
  }) {
    if (navigationClass == RiverWindowClass.compact) {
      return RiverNavigationForm.bottomBar;
    }
    if (navigationClass == RiverWindowClass.medium ||
        collapsed ||
        height < minSidebarHeight) {
      return RiverNavigationForm.rail;
    }
    return RiverNavigationForm.sidebar;
  }

  @override
  State<RiverShell> createState() => _RiverShellState();
}

class _RiverShellState extends State<RiverShell> {
  late bool _collapsed = widget.initiallyCollapsed;
  int _navigationCount = 0;
  ShortcutRegistryEntry? _shortcuts;
  int _registeredShortcutCount = 0;

  @override
  void initState() {
    super.initState();
    _scheduleShortcutRegistration();
  }

  @override
  void didUpdateWidget(RiverShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) _navigationCount++;
    if (_shortcutCount != _registeredShortcutCount) {
      _scheduleShortcutRegistration();
    }
  }

  @override
  void dispose() {
    _shortcuts?.dispose();
    super.dispose();
  }

  int get _shortcutCount =>
      math.min(widget.destinations.length, RiverShell.maxShortcutDestinations);

  /// Registers ⌘1–9 (macOS, iOS) or Ctrl+1–9 with the app's shortcut
  /// registry, so they work wherever focus is. Registration notifies the
  /// registrar, so it must happen outside the build phase.
  void _scheduleShortcutRegistration() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final registry = ShortcutRegistry.maybeOf(context);
      if (registry == null) return;
      _shortcuts?.dispose();
      final apple = switch (defaultTargetPlatform) {
        TargetPlatform.macOS || TargetPlatform.iOS => true,
        _ => false,
      };
      final count = _shortcutCount;
      _shortcuts = registry.addAll({
        for (var i = 0; i < count; i++)
          SingleActivator(_digits[i], meta: apple, control: !apple):
              VoidCallbackIntent(() => _select(i)),
      });
      _registeredShortcutCount = count;
    });
  }

  static const _digits = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  void _select(int index) {
    if (!mounted || index >= widget.destinations.length) return;
    if (index == widget.selectedIndex) {
      widget.onDestinationReselected?.call(index);
    } else {
      widget.onDestinationSelected(index);
    }
  }

  void _toggleCollapsed() {
    setState(() => _collapsed = !_collapsed);
    widget.onCollapsedChanged?.call(_collapsed);
  }

  @override
  Widget build(BuildContext context) {
    final navigationClass = RiverLayout.of(
      context,
      RiverLayoutAspect.navigation,
    );
    final form = RiverShell.formFor(
      navigationClass: navigationClass,
      height: MediaQuery.sizeOf(context).height,
      collapsed: _collapsed,
    );
    assert(
      form != RiverNavigationForm.bottomBar ||
          widget.destinations.length <= RiverShell.maxBottomBarDestinations,
      'A bottom bar holds at most ${RiverShell.maxBottomBarDestinations} '
      'destinations.',
    );
    final textDirection = Directionality.of(context);
    final ltr = textDirection == TextDirection.ltr;
    // The on-screen keyboard covers the bottom bar; hide it so the body keeps
    // the remaining height.
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final showNavigation =
        form != RiverNavigationForm.bottomBar || !keyboardVisible;
    // Collapsing only applies where the sidebar would otherwise show.
    final canToggle =
        navigationClass >= RiverWindowClass.expanded &&
        MediaQuery.sizeOf(context).height >= RiverShell.minSidebarHeight;

    final navigation = !showNavigation
        ? const SizedBox.shrink()
        : Semantics(
            container: true,
            explicitChildNodes: true,
            label: RiverLocalizations.of(context).navigationLabel,
            child: FocusTraversalGroup(
              child: switch (form) {
                RiverNavigationForm.bottomBar => _BottomBar(
                  destinations: widget.destinations,
                  selectedIndex: widget.selectedIndex,
                  onSelected: _select,
                ),
                RiverNavigationForm.rail => _Rail(
                  destinations: widget.destinations,
                  selectedIndex: widget.selectedIndex,
                  onSelected: _select,
                  primaryAction: widget.primaryAction,
                  onExpand: canToggle ? _toggleCollapsed : null,
                ),
                RiverNavigationForm.sidebar => _Sidebar(
                  destinations: widget.destinations,
                  selectedIndex: widget.selectedIndex,
                  onSelected: _select,
                  primaryAction: widget.primaryAction,
                  brand: widget.brand,
                  onCollapse: _toggleCollapsed,
                ),
              },
            ),
          );

    final side = form != RiverNavigationForm.bottomBar;
    final body = MediaQuery.removePadding(
      context: context,
      removeBottom: !side && showNavigation,
      removeLeft: side && ltr,
      removeRight: side && !ltr,
      child: FocusTraversalGroup(
        child: RiverShellScope(
          form: form,
          primaryAction: widget.primaryAction,
          navigationCount: _navigationCount,
          child: RiverContentScope(child: widget.body),
        ),
      ),
    );

    return ColoredBox(
      color: ShadTheme.of(context).colorScheme.background,
      child: CustomMultiChildLayout(
        delegate: _ShellLayoutDelegate(
          side: side,
          textDirection: textDirection,
        ),
        children: [
          // The body comes first and keeps its key, so changing the
          // navigation form never rebuilds it from scratch.
          LayoutId(
            id: _Slot.body,
            key: const ValueKey(_Slot.body),
            child: body,
          ),
          LayoutId(
            id: _Slot.navigation,
            key: const ValueKey(_Slot.navigation),
            child: navigation,
          ),
        ],
      ),
    );
  }
}

enum _Slot { body, navigation }

class _ShellLayoutDelegate extends MultiChildLayoutDelegate {
  _ShellLayoutDelegate({required this.side, required this.textDirection});

  final bool side;
  final TextDirection textDirection;

  @override
  void performLayout(Size size) {
    if (side) {
      final navigation = layoutChild(
        _Slot.navigation,
        BoxConstraints(
          minHeight: size.height,
          maxHeight: size.height,
          maxWidth: size.width,
        ),
      );
      final bodyWidth = math.max(0.0, size.width - navigation.width);
      layoutChild(
        _Slot.body,
        BoxConstraints.tightFor(width: bodyWidth, height: size.height),
      );
      final ltr = textDirection == TextDirection.ltr;
      positionChild(
        _Slot.navigation,
        Offset(ltr ? 0 : size.width - navigation.width, 0),
      );
      positionChild(_Slot.body, Offset(ltr ? navigation.width : 0, 0));
    } else {
      final navigation = layoutChild(
        _Slot.navigation,
        BoxConstraints(
          minWidth: size.width,
          maxWidth: size.width,
          maxHeight: size.height,
        ),
      );
      final bodyHeight = math.max(0.0, size.height - navigation.height);
      layoutChild(
        _Slot.body,
        BoxConstraints.tightFor(width: size.width, height: bodyHeight),
      );
      positionChild(_Slot.body, Offset.zero);
      positionChild(_Slot.navigation, Offset(0, bodyHeight));
    }
  }

  @override
  bool shouldRelayout(_ShellLayoutDelegate oldDelegate) =>
      side != oldDelegate.side || textDirection != oldDelegate.textDirection;
}

/// Border between the navigation and the body.
BorderSide _divider(BuildContext context) =>
    BorderSide(color: ShadTheme.of(context).colorScheme.border);

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<RiverDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final spacing = RiverSpacing.instance;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ShadTheme.of(context).colorScheme.background,
        border: Border(top: _divider(context)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.sm,
            vertical: spacing.xs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (index, destination) in destinations.indexed)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: spacing.xs),
                    child: _destinationItem(
                      destination,
                      selected: index == selectedIndex,
                      layout: NavItemLayout.stacked,
                      onPressed: () => onSelected(index),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

NavItem _destinationItem(
  RiverDestination destination, {
  required bool selected,
  required NavItemLayout layout,
  required VoidCallback onPressed,
}) => NavItem(
  icon: selected
      ? destination.selectedIcon ?? destination.icon
      : destination.icon,
  label: destination.label,
  selected: selected,
  badgeCount: destination.badgeCount,
  layout: layout,
  onPressed: onPressed,
);

/// A start-edge column with a scrolling middle and a fixed footer.
class _SideColumn extends StatelessWidget {
  const _SideColumn({
    required this.width,
    required this.header,
    required this.items,
    this.footer,
  });

  final double width;
  final List<Widget> header;
  final List<Widget> items;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final spacing = RiverSpacing.instance;
    final ltr = Directionality.of(context) == TextDirection.ltr;
    final divider = _divider(context);
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: ShadTheme.of(context).colorScheme.background,
        border: ltr ? Border(right: divider) : Border(left: divider),
      ),
      child: SafeArea(
        left: ltr,
        right: !ltr,
        child: Padding(
          padding: EdgeInsets.all(spacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...header,
                      for (final item in items)
                        Padding(
                          padding: EdgeInsets.only(bottom: spacing.xs),
                          child: item,
                        ),
                    ],
                  ),
                ),
              ),
              ?footer,
            ],
          ),
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.primaryAction,
    required this.onExpand,
  });

  final List<RiverDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final RiverShellAction? primaryAction;
  final VoidCallback? onExpand;

  /// Rail width at the default text size; it grows with the text scale.
  static const baseWidth = 80.0;

  @override
  Widget build(BuildContext context) {
    final spacing = RiverSpacing.instance;
    final scale = RiverWindowClass.effectiveTextScale(
      MediaQuery.textScalerOf(context),
    );
    final action = primaryAction;
    return _SideColumn(
      width: baseWidth * scale,
      header: [
        if (action != null) ...[
          NavItem(
            icon: action.icon,
            label: action.label,
            layout: NavItemLayout.iconOnly,
            isDestination: false,
            prominent: true,
            onPressed: action.enabled ? action.onPressed : null,
          ),
          SizedBox(height: spacing.lg),
        ],
      ],
      items: [
        for (final (index, destination) in destinations.indexed)
          _destinationItem(
            destination,
            selected: index == selectedIndex,
            layout: NavItemLayout.stacked,
            onPressed: () => onSelected(index),
          ),
      ],
      footer: onExpand == null
          ? null
          : NavItem(
              icon: LucideIcons.panelLeftOpen,
              mirrorIconInRtl: true,
              label: RiverLocalizations.of(context).expandSidebar,
              layout: NavItemLayout.iconOnly,
              isDestination: false,
              onPressed: onExpand,
            ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.primaryAction,
    required this.brand,
    required this.onCollapse,
  });

  final List<RiverDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final RiverShellAction? primaryAction;
  final Widget? brand;
  final VoidCallback onCollapse;

  static const baseWidth = 256.0;
  static const maxWidth = 360.0;

  @override
  Widget build(BuildContext context) {
    final spacing = RiverSpacing.instance;
    final scale = RiverWindowClass.effectiveTextScale(
      MediaQuery.textScalerOf(context),
    );
    final action = primaryAction;
    return _SideColumn(
      width: math.min(baseWidth * scale, maxWidth),
      header: [
        if (brand != null) ...[
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.md,
              vertical: spacing.md,
            ),
            child: DefaultTextStyle.merge(
              style: ShadTheme.of(context).textTheme.large.copyWith(
                color: ShadTheme.of(context).colorScheme.foreground,
              ),
              child: brand!,
            ),
          ),
          SizedBox(height: spacing.sm),
        ],
        if (action != null) ...[
          RiverButton(
            label: action.label,
            icon: action.icon,
            onPressed: action.onPressed,
            busy: action.busy,
            expand: true,
          ),
          SizedBox(height: spacing.lg),
        ],
      ],
      items: [
        for (final (index, destination) in destinations.indexed)
          _destinationItem(
            destination,
            selected: index == selectedIndex,
            layout: NavItemLayout.inline,
            onPressed: () => onSelected(index),
          ),
      ],
      footer: Align(
        alignment: AlignmentDirectional.centerStart,
        child: NavItem(
          icon: LucideIcons.panelLeftClose,
          mirrorIconInRtl: true,
          label: RiverLocalizations.of(context).collapseSidebar,
          layout: NavItemLayout.iconOnly,
          isDestination: false,
          onPressed: onCollapse,
        ),
      ),
    );
  }
}
