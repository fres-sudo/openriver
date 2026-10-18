import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openriver_api/openriver_api.dart';

sealed class LibraryState {
  const LibraryState();
}

final class LibraryLoading extends LibraryState {
  const LibraryLoading();
}

final class LibraryReady extends LibraryState {
  const LibraryReady(this.info);
  final LibraryInfo info;
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
      if (!isClosed) emit(LibraryReady(info));
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
}
