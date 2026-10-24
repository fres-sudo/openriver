/// The app-facing API. Poker rules and SQLite access belong to the Rust core.
library;

import 'src/rust/api/library.dart' as native;
import 'src/rust/frb_generated.dart';

final class LibraryInfo {
  const LibraryInfo({required this.coreVersion, required this.schemaVersion});

  final String coreVersion;
  final int schemaVersion;
}

enum CoreFailure {
  unavailable,
  migrationFailed,
  incompatibleSchema,
  fileUnavailable,
  invalidSource,
  unsupportedFormat,
}

final class CoreException implements Exception {
  const CoreException(this.failure);
  final CoreFailure failure;
}

abstract interface class OpenRiverCore {
  Future<LibraryInfo> initializeLibrary(String databasePath);
  Future<HandImportReport> importHandHistory(
    String databasePath,
    String filePath,
  );
  Future<int> storedHandCount(String databasePath);
}

final class HandImportDiagnostic {
  const HandImportDiagnostic({
    required this.handId,
    required this.startLine,
    required this.endLine,
    required this.code,
  });
  final String? handId;
  final int startLine;
  final int endLine;
  final String code;
}

final class HandImportReport {
  const HandImportReport({
    required this.parsed,
    required this.imported,
    required this.duplicates,
    required this.rejected,
    required this.storedHandCount,
    required this.diagnostics,
  });
  final int parsed;
  final int imported;
  final int duplicates;
  final int rejected;
  final int storedHandCount;
  final List<HandImportDiagnostic> diagnostics;
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
      if (status.schemaVersion != 2) {
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
        native.CoreError.fileUnavailable => CoreFailure.fileUnavailable,
        native.CoreError.invalidSource => CoreFailure.invalidSource,
        native.CoreError.unsupportedFormat => CoreFailure.unsupportedFormat,
      });
    }
  }

  @override
  Future<HandImportReport> importHandHistory(
    String databasePath,
    String filePath,
  ) async {
    try {
      await _ensureInitialized();
      final result = await native.importHandHistory(
        databasePath: databasePath,
        filePath: filePath,
      );
      return HandImportReport(
        parsed: result.parsed,
        imported: result.imported,
        duplicates: result.duplicates,
        rejected: result.rejected,
        storedHandCount: result.storedHandCount,
        diagnostics: result.diagnostics
            .map(
              (d) => HandImportDiagnostic(
                handId: d.sourceHandId,
                startLine: d.startLine,
                endLine: d.endLine,
                code: d.code,
              ),
            )
            .toList(),
      );
    } on native.CoreError catch (error) {
      throw CoreException(switch (error) {
        native.CoreError.databaseUnavailable => CoreFailure.unavailable,
        native.CoreError.migrationFailed => CoreFailure.migrationFailed,
        native.CoreError.incompatibleSchema => CoreFailure.incompatibleSchema,
        native.CoreError.fileUnavailable => CoreFailure.fileUnavailable,
        native.CoreError.invalidSource => CoreFailure.invalidSource,
        native.CoreError.unsupportedFormat => CoreFailure.unsupportedFormat,
      });
    }
  }

  @override
  Future<int> storedHandCount(String databasePath) async {
    await _ensureInitialized();
    return native.storedHandCount(databasePath: databasePath);
  }
}
