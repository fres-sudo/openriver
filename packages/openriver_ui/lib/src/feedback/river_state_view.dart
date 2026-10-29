import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../components/river_button.dart';
import '../foundation/tokens.dart';

/// Loading, empty, and error content for a region whose data is not ready.
///
/// Show each state in the same region as the content it replaces, so screen
/// readers follow the change. Error messages are live regions.
sealed class RiverStateView extends StatelessWidget {
  const RiverStateView({super.key});

  /// A progress indicator with a visible and spoken [label].
  const factory RiverStateView.loading({Key? key, required String label}) =
      _LoadingView;

  /// Nothing to show yet, with an optional next step.
  const factory RiverStateView.empty({
    Key? key,
    required String title,
    String? description,
    IconData? icon,
    Widget? action,
  }) = _EmptyView;

  /// A failure, with a retry action when [onRetry] is provided.
  ///
  /// [message] must be safe to show: no raw errors, file paths, or file
  /// contents.
  const factory RiverStateView.error({
    Key? key,
    required String title,
    required String message,
    String? retryLabel,
    VoidCallback? onRetry,
  }) = _ErrorView;
}

class _LoadingView extends RiverStateView {
  const _LoadingView({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShadProgress(semanticsLabel: label),
        SizedBox(height: RiverSpacing.instance.lg),
        ExcludeSemantics(child: Text(label, style: theme.textTheme.p)),
      ],
    );
  }
}

class _EmptyView extends RiverStateView {
  const _EmptyView({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.action,
  });

  final String title;
  final String? description;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final spacing = RiverSpacing.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: RiverSizes.instance.iconLarge,
            color: theme.colorScheme.mutedForeground,
          ),
          SizedBox(height: spacing.lg),
        ],
        Text(title, style: theme.textTheme.h4, textAlign: TextAlign.center),
        if (description != null) ...[
          SizedBox(height: spacing.sm),
          Text(
            description!,
            style: theme.textTheme.muted,
            textAlign: TextAlign.center,
          ),
        ],
        if (action != null) ...[SizedBox(height: spacing.xl), action!],
      ],
    );
  }
}

class _ErrorView extends RiverStateView {
  const _ErrorView({
    super.key,
    required this.title,
    required this.message,
    this.retryLabel,
    this.onRetry,
  }) : assert(
         (retryLabel == null) == (onRetry == null),
         'Provide retryLabel and onRetry together.',
       );

  final String title;
  final String message;
  final String? retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final spacing = RiverSpacing.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: theme.textTheme.h3),
        SizedBox(height: spacing.md),
        ShadAlert.destructive(
          icon: const Icon(LucideIcons.triangleAlert),
          description: Semantics(liveRegion: true, child: Text(message)),
        ),
        if (onRetry != null) ...[
          SizedBox(height: spacing.xl),
          RiverButton(label: retryLabel!, onPressed: onRetry),
        ],
      ],
    );
  }
}
