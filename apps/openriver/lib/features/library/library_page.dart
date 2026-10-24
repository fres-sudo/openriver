import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_selector/file_selector.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The file chooser could not open. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('OpenRiver')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.all(constraints.maxWidth < 600 ? 24 : 48),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Chip(
                        avatar: Icon(Icons.lock_outline, size: 18),
                        label: Text('Local-first study'),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'A clearer view of your game.',
                        style: theme.textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your space to review hands, understand patterns, and study at your own pace.',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 32),
                      Card.outlined(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: SizedBox(
                            width: double.infinity,
                            child: BlocBuilder<LibraryCubit, LibraryState>(
                              builder: (context, state) => switch (state) {
                                LibraryLoading() => const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    LinearProgressIndicator(
                                      semanticsLabel: 'Opening your library',
                                    ),
                                    SizedBox(height: 16),
                                    Text('Opening your library…'),
                                  ],
                                ),
                                LibraryFailed(:final message) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Let’s try that again',
                                      style: theme.textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 12),
                                    Semantics(
                                      liveRegion: true,
                                      child: Text(message),
                                    ),
                                    const SizedBox(height: 24),
                                    FilledButton.icon(
                                      onPressed: () =>
                                          context.read<LibraryCubit>().open(),
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Try again'),
                                    ),
                                  ],
                                ),
                                LibraryReady(
                                  :final storedCount,
                                  :final importing,
                                  :final report,
                                  :final importError,
                                ) =>
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        color: theme.colorScheme.primary,
                                        size: 32,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Your library is ready',
                                        style: theme.textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Stored on this device. No account needed.',
                                      ),
                                      const SizedBox(height: 24),
                                      Text('$storedCount stored hands'),
                                      const SizedBox(height: 16),
                                      FilledButton.icon(
                                        onPressed: importing
                                            ? null
                                            : () => _chooseFile(context),
                                        icon: const Icon(Icons.upload_file),
                                        label: const Text(
                                          'Import hand history',
                                        ),
                                      ),
                                      if (importing) ...[
                                        const SizedBox(height: 16),
                                        const LinearProgressIndicator(
                                          semanticsLabel: 'Importing hands',
                                        ),
                                        const Text('Importing hands…'),
                                      ],
                                      if (importError != null) ...[
                                        const SizedBox(height: 16),
                                        Text(importError),
                                      ],
                                      if (report != null) ...[
                                        const SizedBox(height: 16),
                                        Text(
                                          'Imported ${report.imported}, duplicates ${report.duplicates}, rejected ${report.rejected}.',
                                        ),
                                        for (final diagnostic
                                            in report.diagnostics)
                                          Text(
                                            'Hand ${diagnostic.handId ?? 'unknown'}, lines ${diagnostic.startLine}–${diagnostic.endLine}: ${diagnostic.code}',
                                          ),
                                      ],
                                    ],
                                  ),
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Built for the time away from the table.',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Post-session review. Private by default. Yours to explore.',
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
