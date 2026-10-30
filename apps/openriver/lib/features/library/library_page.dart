import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openriver_ui/openriver_ui.dart';

import '../../app/app_context.dart';
import '../import/import_flow.dart';
import 'library_cubit.dart';

/// The library's status: opening, failed, or ready with stored hands and the
/// latest import.
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.app.localizations;
    return RiverPage(
      header: RiverPageHeader(
        title: strings.libraryTitle,
        description: strings.libraryDescription,
      ),
      body: ShadCard(
        width: double.infinity,
        content: BlocBuilder<LibraryCubit, LibraryState>(
          builder: (context, state) => switch (state) {
            LibraryLoading() => RiverStateView.loading(
              label: strings.libraryOpening,
            ),
            LibraryFailed(:final message) => RiverStateView.error(
              title: strings.libraryOpenFailedTitle,
              message: message,
              retryLabel: strings.retry,
              onRetry: context.read<LibraryCubit>().open,
            ),
            LibraryReady() => _ReadyContent(state: state),
          },
        ),
      ),
    );
  }
}

class _ReadyContent extends StatelessWidget {
  const _ReadyContent({required this.state});

  final LibraryReady state;

  @override
  Widget build(BuildContext context) {
    final strings = context.app.localizations;
    final theme = context.app.theme;
    final spacing = theme.spacing;
    final LibraryReady(:storedCount, :importing, :progress, :report) = state;
    final importError = state.importError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          LucideIcons.circleCheck,
          color: theme.colors.primary,
          size: theme.sizes.iconLarge,
        ),
        SizedBox(height: spacing.lg),
        Text(strings.libraryReady, style: theme.textTheme.h3),
        SizedBox(height: spacing.sm),
        Text(strings.storedHands(storedCount), style: theme.textTheme.p),
        if (storedCount == 0 && !importing) ...[
          SizedBox(height: spacing.lg),
          Text(strings.libraryEmptyDescription, style: theme.textTheme.muted),
          SizedBox(height: spacing.xl),
          RiverButton(
            label: strings.importAction,
            icon: LucideIcons.upload,
            onPressed: () => ImportFlow.start(context),
          ),
        ],
        if (importing) ...[
          SizedBox(height: spacing.xl),
          ShadProgress(
            semanticsLabel: strings.importProgressLabel,
            value: progress == null || progress.total == 0
                ? null
                : progress.processed / progress.total,
          ),
          SizedBox(height: spacing.sm),
          Text(
            progress == null
                ? strings.importProgressUnknown
                : strings.importProgress(progress.processed, progress.total),
            style: theme.textTheme.p,
          ),
          SizedBox(height: spacing.md),
          RiverButton(
            label: strings.cancelImport,
            variant: RiverButtonVariant.outline,
            onPressed: context.read<LibraryCubit>().cancelImport,
          ),
        ],
        if (importError != null) ...[
          SizedBox(height: spacing.xl),
          ShadAlert.destructive(
            icon: const Icon(LucideIcons.triangleAlert),
            description: Semantics(liveRegion: true, child: Text(importError)),
          ),
        ],
        if (report != null) ...[
          SizedBox(height: spacing.xl),
          Text(
            strings.lastImport(
              report.imported,
              report.duplicates,
              report.rejected,
            ),
            style: theme.textTheme.p,
          ),
          SizedBox(height: spacing.md),
          RiverButton(
            label: strings.viewImportReport,
            variant: RiverButtonVariant.outline,
            onPressed: () => ImportFlow.showReport(context),
          ),
        ],
      ],
    );
  }
}
