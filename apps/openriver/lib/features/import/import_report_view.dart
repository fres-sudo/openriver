import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openriver_ui/openriver_ui.dart';

import '../../app/app_context.dart';
import '../library/library_cubit.dart';

/// Progress, failure, or the report of the latest import.
///
/// Never shows file paths or contents: only counts, hand IDs, line numbers,
/// and stable diagnostic codes.
class ImportReportView extends StatelessWidget {
  const ImportReportView({
    super.key,
    required this.onDone,
    required this.onChooseAnother,
  });

  final VoidCallback onDone;
  final VoidCallback onChooseAnother;

  @override
  Widget build(BuildContext context) {
    final strings = context.app.localizations;
    final theme = context.app.theme;
    final spacing = theme.spacing;

    return BlocBuilder<LibraryCubit, LibraryState>(
      builder: (context, state) {
        if (state is! LibraryReady) return const SizedBox.shrink();
        final LibraryReady(:importing, :progress, :report, :importError) =
            state;

        if (importing) {
          final known = progress != null && progress.total > 0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShadProgress(
                semanticsLabel: strings.importProgressLabel,
                value: known ? progress.processed / progress.total : null,
              ),
              SizedBox(height: spacing.md),
              Text(
                progress == null
                    ? strings.importProgressUnknown
                    : strings.importProgress(
                        progress.processed,
                        progress.total,
                      ),
                style: theme.textTheme.p,
              ),
              SizedBox(height: spacing.sm),
              Text(strings.importContinuesHint, style: theme.textTheme.muted),
              SizedBox(height: spacing.xl),
              RiverButton(
                label: strings.cancelImport,
                variant: RiverButtonVariant.outline,
                onPressed: context.read<LibraryCubit>().cancelImport,
              ),
            ],
          );
        }

        if (importError != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.importFailedTitle, style: theme.textTheme.large),
              SizedBox(height: spacing.md),
              ShadAlert.destructive(
                icon: const Icon(LucideIcons.triangleAlert),
                description: Semantics(
                  liveRegion: true,
                  child: Text(importError),
                ),
              ),
              SizedBox(height: spacing.xl),
              Wrap(
                spacing: spacing.sm,
                runSpacing: spacing.sm,
                children: [
                  RiverButton(
                    label: strings.chooseAnotherFile,
                    onPressed: onChooseAnother,
                  ),
                  RiverButton(
                    label: strings.done,
                    variant: RiverButtonVariant.outline,
                    onPressed: onDone,
                  ),
                ],
              ),
            ],
          );
        }

        if (report == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                strings.importSummary(
                  report.imported,
                  report.duplicates,
                  report.rejected,
                ),
                style: theme.textTheme.p,
              ),
            ),
            Text(
              strings.storedHands(report.storedHandCount),
              style: theme.textTheme.muted,
            ),
            if (report.diagnostics.isNotEmpty) ...[
              SizedBox(height: spacing.xl),
              Semantics(
                container: true,
                header: true,
                child: Text(
                  strings.rejectedHandsHeading,
                  style: theme.textTheme.large,
                ),
              ),
              SizedBox(height: spacing.sm),
              for (final diagnostic in report.diagnostics)
                Padding(
                  padding: EdgeInsets.only(bottom: spacing.xs),
                  child: Text(
                    strings.rejectedHand(
                      diagnostic.handId ?? strings.unknownHand,
                      diagnostic.startLine,
                      diagnostic.endLine,
                      diagnostic.code,
                    ),
                    style: theme.textTheme.muted,
                  ),
                ),
            ],
            SizedBox(height: spacing.xl),
            RiverButton(label: strings.done, onPressed: onDone),
          ],
        );
      },
    );
  }
}
