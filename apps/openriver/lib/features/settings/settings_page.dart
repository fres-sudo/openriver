import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openriver_ui/openriver_ui.dart';

import '../../app/app_context.dart';
import '../export/export_flow.dart';
import '../library/library_cubit.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    await ExportFlow.start(context);
    if (mounted) setState(() => _exporting = false);
  }

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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShadCard(
            width: double.infinity,
            title: Text(strings.exportHeading),
            description: Text(strings.exportDescription),
            content: BlocBuilder<LibraryCubit, LibraryState>(
              builder: (context, state) => RiverButton(
                label: strings.exportAction,
                icon: LucideIcons.download,
                busy: _exporting,
                onPressed: state is LibraryReady && !_exporting
                    ? _export
                    : null,
              ),
            ),
          ),
          SizedBox(height: spacing.xl),
          ShadCard(
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
        ],
      ),
    );
  }
}
