import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'library_cubit.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

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
                                LibraryReady() => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    const Text(
                                      'This is the first OpenRiver development build. Hand importing and analysis are coming next.',
                                    ),
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
