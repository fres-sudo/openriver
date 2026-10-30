import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openriver_ui/openriver_ui.dart';

import '../../app/app_context.dart';
import '../library/library_cubit.dart';

/// App information. Preferences are added here as they are introduced.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.app.localizations;
    final theme = context.app.theme;
    final spacing = theme.spacing;
    return RiverPage(
      header: RiverPageHeader(
        title: strings.settingsTitle,
        description: strings.settingsDescription,
      ),
      body: ShadCard(
        width: double.infinity,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(strings.aboutHeading, style: theme.textTheme.h4),
            ),
            SizedBox(height: spacing.md),
            BlocBuilder<LibraryCubit, LibraryState>(
              builder: (context, state) => switch (state) {
                LibraryReady(:final info) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.coreVersion(info.coreVersion),
                      style: theme.textTheme.p,
                    ),
                    Text(
                      strings.schemaVersion(info.schemaVersion),
                      style: theme.textTheme.p,
                    ),
                    SizedBox(height: spacing.md),
                  ],
                ),
                _ => const SizedBox.shrink(),
              },
            ),
            Text(strings.privacyNote, style: theme.textTheme.muted),
          ],
        ),
      ),
    );
  }
}
