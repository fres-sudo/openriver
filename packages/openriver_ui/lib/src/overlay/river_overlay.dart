import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../components/river_icon_button.dart';
import '../foundation/tokens.dart';
import '../l10n/river_localizations.dart';
import '../layout/river_layout.dart';
import '../layout/window_class.dart';

/// Shows [builder]'s content above the current screen: a bottom sheet in a
/// compact window, otherwise a centered dialog.
///
/// The form follows the window while the overlay is open. The overlay has a
/// titled, scrollable body and a close button; tapping the barrier, pressing
/// Escape, or the system back gesture also close it. It names its route for
/// screen readers, keeps focus inside, and skips its transition when the
/// platform asks for reduced motion.
///
/// Built on Flutter's `showGeneralDialog` rather than `showShadDialog`: the
/// shadcn_ui 0.2.6 close button is a 20-pixel target with no spoken label,
/// and its animations ignore reduced motion.
Future<T?> showRiverOverlay<T>({
  required BuildContext context,
  required String title,
  String? description,
  required WidgetBuilder builder,
}) {
  final strings = RiverLocalizations.of(context);
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: strings.close,
    barrierColor: const Color(0x99000000),
    transitionDuration: reduceMotion
        ? Duration.zero
        : RiverDurations.instance.normal,
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(opacity: curved, child: child);
    },
    pageBuilder: (context, _, _) =>
        _RiverOverlay(title: title, description: description, builder: builder),
  );
}

class _RiverOverlay extends StatelessWidget {
  const _RiverOverlay({
    required this.title,
    required this.description,
    required this.builder,
  });

  final String title;
  final String? description;
  final WidgetBuilder builder;

  static const dialogMaxWidth = 560.0;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final spacing = RiverSpacing.instance;
    final sheet =
        RiverLayout.of(context, RiverLayoutAspect.window) ==
        RiverWindowClass.compact;
    final size = MediaQuery.sizeOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final radius = theme.radius.topLeft;

    final panel = Container(
      constraints: BoxConstraints(
        maxWidth: sheet ? double.infinity : dialogMaxWidth,
        maxHeight: (size.height - keyboard) * (sheet ? 0.9 : 0.85),
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        border: Border.all(color: theme.colorScheme.border),
        borderRadius: sheet ? BorderRadius.vertical(top: radius) : theme.radius,
      ),
      child: SafeArea(
        top: false,
        left: sheet,
        right: sheet,
        bottom: sheet,
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            spacing.xl,
            spacing.md,
            spacing.sm,
            spacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Semantics(
                      container: true,
                      header: true,
                      child: Text(title, style: theme.textTheme.h4),
                    ),
                  ),
                  RiverIconButton(
                    icon: LucideIcons.x,
                    label: RiverLocalizations.of(context).close,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsetsDirectional.only(end: spacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (description != null) ...[
                        Text(description!, style: theme.textTheme.muted),
                        SizedBox(height: spacing.lg),
                      ] else
                        SizedBox(height: spacing.sm),
                      builder(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: Align(
          alignment: sheet ? Alignment.bottomCenter : Alignment.center,
          child: Padding(
            padding: sheet ? EdgeInsets.zero : EdgeInsets.all(spacing.xl),
            // Taps inside the panel must not reach the dismissing barrier.
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: () {},
              child: DefaultTextStyle(
                style: theme.textTheme.p.copyWith(
                  color: theme.colorScheme.foreground,
                ),
                child: panel,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
