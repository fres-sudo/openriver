import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openriver_ui/openriver_ui.dart';

import '../../app/app_context.dart';
import '../import/import_flow.dart';
import '../library/library_cubit.dart';

/// Imported hands. The searchable list is a later milestone; for now the page
/// reports how many hands are stored.
class HandsPage extends StatelessWidget {
  const HandsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.app.localizations;
    return RiverPage(
      width: RiverPageWidth.wide,
      header: RiverPageHeader(
        title: strings.handsTitle,
        description: strings.handsDescription,
      ),
      body: BlocBuilder<LibraryCubit, LibraryState>(
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
          LibraryReady(storedCount: 0, importing: false) =>
            RiverStateView.empty(
              icon: LucideIcons.inbox,
              title: strings.libraryEmptyTitle,
              description: strings.libraryEmptyDescription,
              action: RiverButton(
                label: strings.importAction,
                icon: LucideIcons.upload,
                onPressed: () => ImportFlow.start(context),
              ),
            ),
          LibraryReady(:final storedCount) => RiverStateView.empty(
            icon: LucideIcons.list,
            title: strings.handsComingTitle,
            description: strings.handsComingDescription(storedCount),
          ),
        },
      ),
    );
  }
}
