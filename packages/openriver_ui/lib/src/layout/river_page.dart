import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../foundation/tokens.dart';
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
class RiverPageHeader extends StatelessWidget {
  const RiverPageHeader({
    super.key,
    required this.title,
    this.description,
    this.actions = const [],
  });

  final String title;
  final String? description;

  /// Typically `RiverButton`s, in order of importance.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final spacing = RiverSpacing.instance;
    final compact =
        RiverLayout.of(context, RiverLayoutAspect.content) ==
        RiverWindowClass.compact;

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: compact ? theme.textTheme.h3 : theme.textTheme.h2,
          ),
        ),
        if (description != null) ...[
          SizedBox(height: spacing.sm),
          Text(description!, style: theme.textTheme.muted),
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
