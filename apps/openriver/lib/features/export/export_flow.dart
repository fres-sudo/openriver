import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openriver_api/openriver_api.dart';
import 'package:openriver_ui/openriver_ui.dart';

import '../../app/app_context.dart';
import '../library/library_cubit.dart';

final class ExportLocationChooser {
  const ExportLocationChooser(this.choose);

  final Future<String?> Function() choose;
}

Future<String?> chooseExportLocation() async =>
    (await getSaveLocation(suggestedName: 'openriver-backup.sqlite3'))?.path;

abstract final class ExportFlow {
  static Future<void> start(BuildContext context) async {
    final strings = context.app.localizations;
    final library = context.read<LibraryCubit>();
    if (library.state is! LibraryReady) return;
    final String? destination;
    try {
      destination = await context.read<ExportLocationChooser>().choose();
    } catch (_) {
      if (context.mounted) {
        ShadToaster.of(
          context,
        ).show(ShadToast.destructive(title: Text(strings.exportChooserFailed)));
      }
      return;
    }
    if (destination == null || !context.mounted) return;
    try {
      final result = await library.core.exportLibrary(
        await library.databasePath(),
        destination,
      );
      if (context.mounted) {
        ShadToaster.of(
          context,
        ).show(ShadToast(title: Text(strings.exportSuccess(result.handCount))));
      }
    } catch (error) {
      final message = switch (error) {
        CoreException(failure: CoreFailure.exportDestinationExists) =>
          strings.exportDestinationExists,
        CoreException(failure: CoreFailure.invalidExportPath) =>
          strings.exportInvalidPath,
        _ => strings.exportFailed,
      };
      if (context.mounted) {
        ShadToaster.of(
          context,
        ).show(ShadToast.destructive(title: Text(message)));
      }
    }
  }
}
