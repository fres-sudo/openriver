import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openriver_ui/openriver_ui.dart';

import 'library_cubit.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  Future<void> _chooseFile(BuildContext context) async {
    try {
      final file = await openFile();
      if (file != null && context.mounted) {
        await context.read<LibraryCubit>().importPath(file.path);
      }
    } catch (_) {
      if (context.mounted) {
        ShadToaster.of(context).show(
          const ShadToast.destructive(
            title: Text('The file chooser could not open. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ColoredBox(
      color: theme.colorScheme.background,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                RiverWindowClass.fromWidth(constraints.maxWidth) ==
                RiverWindowClass.compact;
            return SingleChildScrollView(
              padding: EdgeInsets.all(
                compact
                    ? context.app.theme.spacing.xl
                    : context.app.theme.spacing.xxxl,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: context.app.theme.sizes.contentMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('OpenRiver', style: theme.textTheme.h4),
                      const SizedBox(height: 32),
                      const ShadBadge.secondary(
                        text: Text('Local-first study'),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'A clearer view of your game.',
                        style: compact
                            ? theme.textTheme.h2
                            : theme.textTheme.h1,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your space to review hands, understand patterns, and study at your own pace.',
                        style: theme.textTheme.lead,
                      ),
                      const SizedBox(height: 32),
                      ShadCard(
                        width: double.infinity,
                        content: BlocBuilder<LibraryCubit, LibraryState>(
                          builder: (context, state) => switch (state) {
                            LibraryLoading() => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const ShadProgress(
                                  semanticsLabel: 'Opening your library',
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Opening your library…',
                                  style: theme.textTheme.p,
                                ),
                              ],
                            ),
                            LibraryFailed(:final message) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Let’s try that again',
                                  style: theme.textTheme.h3,
                                ),
                                const SizedBox(height: 12),
                                ShadAlert.destructive(
                                  icon: const Icon(LucideIcons.triangleAlert),
                                  description: Semantics(
                                    liveRegion: true,
                                    child: Text(message),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _LibraryActionButton(
                                  onPressed: () =>
                                      context.read<LibraryCubit>().open(),
                                  label: 'Try again',
                                ),
                              ],
                            ),
                            LibraryReady(
                              :final storedCount,
                              :final importing,
                              :final progress,
                              :final report,
                              :final importError,
                            ) =>
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    LucideIcons.circleCheck,
                                    color: theme.colorScheme.primary,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Your library is ready',
                                    style: theme.textTheme.h3,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Stored on this device. No account needed.',
                                    style: theme.textTheme.p,
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    '$storedCount stored hands',
                                    style: theme.textTheme.p,
                                  ),
                                  const SizedBox(height: 16),
                                  _LibraryActionButton(
                                    enabled: !importing,
                                    onPressed: () => _chooseFile(context),
                                    label: 'Import hand history',
                                  ),
                                  if (importing) ...[
                                    const SizedBox(height: 16),
                                    ShadProgress(
                                      semanticsLabel: 'Importing hands',
                                      value:
                                          progress == null ||
                                              progress.total == 0
                                          ? null
                                          : progress.processed / progress.total,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      progress == null
                                          ? 'Importing hands…'
                                          : 'Importing hands… ${progress.processed} of ${progress.total}',
                                      style: theme.textTheme.p,
                                    ),
                                    const SizedBox(height: 8),
                                    _LibraryActionButton(
                                      onPressed: () => context
                                          .read<LibraryCubit>()
                                          .cancelImport(),
                                      label: 'Cancel import',
                                    ),
                                  ],
                                  if (importError != null) ...[
                                    const SizedBox(height: 16),
                                    ShadAlert.destructive(
                                      icon: const Icon(
                                        LucideIcons.triangleAlert,
                                      ),
                                      description: Semantics(
                                        liveRegion: true,
                                        child: Text(importError),
                                      ),
                                    ),
                                  ],
                                  if (report != null) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      'Imported ${report.imported}, duplicates ${report.duplicates}, rejected ${report.rejected}.',
                                      style: theme.textTheme.p,
                                    ),
                                    for (final diagnostic in report.diagnostics)
                                      Text(
                                        'Hand ${diagnostic.handId ?? 'unknown'}, lines ${diagnostic.startLine}–${diagnostic.endLine}: ${diagnostic.code}',
                                        style: theme.textTheme.muted,
                                      ),
                                  ],
                                ],
                              ),
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Built for the time away from the table.',
                        style: theme.textTheme.h4,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Post-session review. Private by default. Yours to explore.',
                        style: theme.textTheme.muted,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LibraryActionButton extends StatelessWidget {
  const _LibraryActionButton({
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) => ShadButton(
        enabled: enabled,
        onPressed: onPressed,
        height: math.max(48, 48 + 96 * (textScale - 1)),
        text: SizedBox(
          width: math.min(190, math.max(0, constraints.maxWidth - 48)),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
