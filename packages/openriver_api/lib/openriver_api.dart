/// The app-facing API. Poker rules and SQLite access belong to the Rust core.
library;

import 'src/rust/api/library.dart' as native;
import 'src/rust/frb_generated.dart';

final class LibraryInfo {
  const LibraryInfo({required this.coreVersion, required this.schemaVersion});

  final String coreVersion;
  final int schemaVersion;
}

enum CoreFailure { unavailable, migrationFailed, incompatibleSchema }

final class CoreException implements Exception {
  const CoreException(this.failure);
  final CoreFailure failure;
}

abstract interface class OpenRiverCore {
  Future<LibraryInfo> initializeLibrary(String databasePath);
}

final class RustOpenRiverCore implements OpenRiverCore {
  // Multiple adapters share a single native runtime. Failed initialization can retry.
  static Future<void>? _initialization;

  static Future<void> _ensureInitialized() async {
    try {
      await (_initialization ??= RustLib.init());
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  @override
  Future<LibraryInfo> initializeLibrary(String databasePath) async {
    try {
      await _ensureInitialized();
      final status = await native.initializeLibrary(databasePath: databasePath);
      if (status.schemaVersion != 1) {
        throw const CoreException(CoreFailure.incompatibleSchema);
      }
      return LibraryInfo(
        coreVersion: status.coreVersion,
        schemaVersion: status.schemaVersion,
      );
    } on native.CoreError catch (error) {
      throw CoreException(switch (error) {
        native.CoreError.databaseUnavailable => CoreFailure.unavailable,
        native.CoreError.migrationFailed => CoreFailure.migrationFailed,
        native.CoreError.incompatibleSchema => CoreFailure.incompatibleSchema,
      });
    }
  }
}
