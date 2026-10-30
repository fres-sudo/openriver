import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openriver_ui/openriver_ui.dart';

import '../../app/app_context.dart';
import '../library/library_cubit.dart';
import 'import_report_view.dart';

/// Asks the user for a hand-history file and returns its path, or null if
/// they cancel. Provided above the router so tests can replace it.
typedef HandHistoryChooser = Future<String?> Function();

/// Opens the platform file chooser.
Future<String?> chooseHandHistoryFile() async => (await openFile())?.path;

/// Importing from anywhere in the app: the shell action and empty states.
abstract final class ImportFlow {
  /// Chooses a file, starts importing it, and shows progress and the result
  /// in an overlay. Closing the overlay does not stop the import.
  static Future<void> start(BuildContext context) async {
    final cubit = context.read<LibraryCubit>();
    final strings = context.app.localizations;
    final String? path;
    try {
      path = await context.read<HandHistoryChooser>()();
    } catch (_) {
      if (context.mounted) {
        ShadToaster.of(
          context,
        ).show(ShadToast.destructive(title: Text(strings.fileChooserFailed)));
      }
      return;
    }
    if (path == null || !context.mounted) return;
    // Starting the import emits its importing state before the overlay's
    // first frame, so the overlay opens on progress.
    final importing = cubit.importPath(path);
    showReport(context);
    await importing;
  }

  /// Shows the running or most recent import in an overlay.
  static Future<void> showReport(BuildContext context) {
    final cubit = context.read<LibraryCubit>();
    return showRiverOverlay<void>(
      context: context,
      title: context.app.localizations.importTitle,
      builder: (overlayContext) => BlocProvider.value(
        value: cubit,
        child: ImportReportView(
          onDone: () => Navigator.of(overlayContext).maybePop(),
          onChooseAnother: () {
            Navigator.of(overlayContext).maybePop();
            start(context);
          },
        ),
      ),
    );
  }
}
