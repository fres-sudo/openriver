import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openriver_api/openriver_api.dart';

sealed class LibraryState {
  const LibraryState();
}

final class LibraryLoading extends LibraryState {
  const LibraryLoading();
}

final class LibraryReady extends LibraryState {
  const LibraryReady(
    this.info, {
    required this.storedCount,
    this.importing = false,
    this.progress,
    this.report,
    this.importError,
  });
  final LibraryInfo info;
  final int storedCount;
  final bool importing;
  final ImportProgress? progress;
  final HandImportReport? report;
  final String? importError;
}

final class LibraryFailed extends LibraryState {
  const LibraryFailed(this.message);
  final String message;
}

class LibraryCubit extends Cubit<LibraryState> {
  LibraryCubit({required this.core, required this.databasePath})
    : super(const LibraryLoading());

  final OpenRiverCore core;
  final Future<String> Function() databasePath;
  bool _opening = false;

  Future<void> open() async {
    if (_opening || isClosed) return;
    _opening = true;
    emit(const LibraryLoading());
    try {
      final info = await core.initializeLibrary(await databasePath());
      final count = await core.storedHandCount(await databasePath());
      if (!isClosed) emit(LibraryReady(info, storedCount: count));
    } catch (error) {
      final message = switch (error) {
        CoreException(failure: CoreFailure.incompatibleSchema) =>
          'This library needs a different version of OpenRiver. Your data has been kept.',
        CoreException(failure: CoreFailure.migrationFailed) =>
          'Your library could not be updated. Restart OpenRiver and try again.',
        _ =>
          'Your local library could not be opened. Check available storage and try again.',
      };
      if (!isClosed) emit(LibraryFailed(message));
    } finally {
      _opening = false;
    }
  }

  /// Stops the running import. The cancelled file leaves no hands behind.
  void cancelImport() {
    final current = state;
    if (current is LibraryReady && current.importing) core.cancelImport();
  }

  Future<void> importPath(String filePath) async {
    final current = state;
    if (current is! LibraryReady || current.importing || isClosed) return;
    emit(
      LibraryReady(
        current.info,
        storedCount: current.storedCount,
        importing: true,
      ),
    );
    try {
      final report = await core.importHandHistory(
        await databasePath(),
        filePath,
        onProgress: (progress) {
          if (!isClosed) {
            emit(
              LibraryReady(
                current.info,
                storedCount: current.storedCount,
                importing: true,
                progress: progress,
              ),
            );
          }
        },
      );
      if (!isClosed) {
        emit(
          LibraryReady(
            current.info,
            storedCount: report.storedHandCount,
            report: report,
          ),
        );
      }
    } catch (error) {
      final message = switch (error) {
        CoreException(failure: CoreFailure.cancelled) =>
          'Import cancelled. Nothing from that file was added.',
        CoreException(failure: CoreFailure.unsupportedFormat) =>
          'This hand-history format is not supported yet.',
        CoreException(failure: CoreFailure.invalidSource) =>
          'This file is empty, too large, or is not valid text.',
        CoreException(failure: CoreFailure.fileUnavailable) =>
          'The selected file could not be read. Please choose it again.',
        _ => 'The import could not be completed. Please try again.',
      };
      if (!isClosed) {
        emit(
          LibraryReady(
            current.info,
            storedCount: current.storedCount,
            importError: message,
          ),
        );
      }
    }
  }
}
