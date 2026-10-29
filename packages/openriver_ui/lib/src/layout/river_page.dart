import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../components/river_button.dart';
import '../foundation/tokens.dart';
import '../navigation/river_shell_scope.dart';
import 'river_layout.dart';
import 'window_class.dart';

/// Maximum width of a page's content.
enum RiverPageWidth {
  /// [RiverSizes.contentMaxWidth], for reading and forms.
  standard,

  /// [RiverSizes.wideContentMaxWidth], for lists and tables.
  wide,

  /// No maximum; the page uses the whole content region.
  full,
}

/// Title, description, and actions at the top of a page.
///
/// The title is a semantic header. Actions sit beside the title when the page
/// is wider than compact and wrap below it otherwise or when space runs out.
///
/// Inside a `RiverShell`:
///
/// - With a bottom bar, the shell's primary action is shown first among the
///   actions, unless [showShellAction] is false.
/// - After the selected destination changes, keyboard focus moves to the
///   title of the newly visible page, so screen readers announce it and Tab
///   continues from the top of the page.
class RiverPageHeader extends StatefulWidget {
  const RiverPageHeader({
    super.key,
    required this.title,
    this.description,
    this.actions = const [],
    this.showShellAction = true,
  });

  final String title;
  final String? description;

  /// Typically `RiverButton`s, in order of importance.
  final List<Widget> actions;

  /// Whether to show the shell's primary action when the shell has no other
  /// place for it.
  final bool showShellAction;

  @override
  State<RiverPageHeader> createState() => _RiverPageHeaderState();
}

class _RiverPageHeaderState extends State<RiverPageHeader> {
  final _titleFocus = FocusNode(debugLabel: 'RiverPageHeader title');

  /// The shell navigation this header has already responded to.
  int? _handledNavigation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final navigation = RiverShellScope.maybeOf(context)?.navigationCount;
    // Hidden branches of an indexed stack have tickers disabled.
    final visible = TickerMode.valuesOf(context).enabled;
    if (navigation == null || !visible) return;
    final first = _handledNavigation == null;
    if (navigation == _handledNavigation) return;
    _handledNavigation = navigation;
    // At launch (no navigation yet), leave focus alone.
    if (first && navigation == 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _titleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final spacing = RiverSpacing.instance;
    final compact =
        RiverLayout.of(context, RiverLayoutAspect.content) ==
        RiverWindowClass.compact;
    final shell = RiverShellScope.maybeOf(context);
    final shellAction =
        widget.showShellAction && shell?.form == RiverNavigationForm.bottomBar
        ? shell?.primaryAction
        : null;
    final actions = [
      if (shellAction != null)
        RiverButton(
          label: shellAction.label,
          icon: shellAction.icon,
          onPressed: shellAction.onPressed,
          busy: shellAction.busy,
        ),
      ...widget.actions,
    ];

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Focus(
          focusNode: _titleFocus,
          skipTraversal: true,
          child: Semantics(
            header: true,
            child: Text(
              widget.title,
              style: compact ? theme.textTheme.h3 : theme.textTheme.h2,
            ),
          ),
        ),
        if (widget.description != null) ...[
          SizedBox(height: spacing.sm),
          Text(widget.description!, style: theme.textTheme.muted),
        ],
      ],
    );

    if (actions.isEmpty) return heading;

    final actionWrap = Wrap(
      spacing: spacing.sm,
      runSpacing: spacing.sm,
      alignment: compact ? WrapAlignment.start : WrapAlignment.end,
      children: actions,
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          heading,
          SizedBox(height: spacing.lg),
          actionWrap,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: heading),
        SizedBox(width: spacing.xl),
        Flexible(child: actionWrap),
      ],
    );
  }
}

/// The scaffold for a screen's content.
///
/// A page fills its region with the theme background, applies safe areas,
/// outer padding chosen from the content class of its region, and a maximum
/// width. The header and body see the content class of the padded,
/// width-limited area they are laid out in.
///
/// A [scrollable] page scrolls the header and body together through the
/// primary scroll controller, so the shell can scroll it to the top. Pages
/// whose body scrolls itself, such as long lists, set [scrollable] to false;
/// their body then fills the remaining height.
class RiverPage extends StatelessWidget {
  const RiverPage({
    super.key,
    this.header,
    required this.body,
    this.width = RiverPageWidth.standard,
    this.scrollable = true,
  });

  final Widget? header;
  final Widget body;
  final RiverPageWidth width;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final spacing = RiverSpacing.instance;
    final sizes = RiverSizes.instance;
    final maxWidth = switch (width) {
      RiverPageWidth.standard => sizes.contentMaxWidth,
      RiverPageWidth.wide => sizes.wideContentMaxWidth,
      RiverPageWidth.full => double.infinity,
    };

    return ColoredBox(
      color: theme.colorScheme.background,
      child: SafeArea(
        child: RiverContentScope(
          child: Builder(
            builder: (context) {
              final compact =
                  RiverLayout.of(context, RiverLayoutAspect.content) ==
                  RiverWindowClass.compact;
              final padding = EdgeInsets.all(
                compact ? spacing.xl : spacing.xxxl,
              );
              final content = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
                children: [
                  if (header != null) ...[
                    header!,
                    SizedBox(height: spacing.xxl),
                  ],
                  if (scrollable) body else Expanded(child: body),
                ],
              );
              final constrained = Align(
                alignment: AlignmentDirectional.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: RiverContentScope(child: content),
                ),
              );
              if (!scrollable) {
                return Padding(padding: padding, child: constrained);
              }
              return SingleChildScrollView(
                primary: true,
                padding: padding,
                child: constrained,
              );
            },
          ),
        ),
      ),
    );
  }
}
