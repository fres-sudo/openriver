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
  cancelled,
}

final class CoreException implements Exception {
  const CoreException(this.failure);
  final CoreFailure failure;
}

abstract interface class OpenRiverCore {
  Future<LibraryInfo> initializeLibrary(String databasePath);

  /// Reports how many hands have been processed so far while importing.
  /// Completes with [CoreFailure.cancelled] after [cancelImport] stops it.
  Future<HandImportReport> importHandHistory(
    String databasePath,
    String filePath, {
    void Function(ImportProgress progress)? onProgress,
  });

  /// Stops the running import. Nothing from the cancelled file is stored.
  void cancelImport();
  Future<int> storedHandCount(String databasePath);
}

final class ImportProgress {
  const ImportProgress({required this.processed, required this.total});
  final int processed;
  final int total;
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
        native.CoreError.cancelled => CoreFailure.cancelled,
      });
    }
  }

  @override
  void cancelImport() => native.cancelImport();

  @override
  Future<HandImportReport> importHandHistory(
    String databasePath,
    String filePath, {
    void Function(ImportProgress progress)? onProgress,
  }) async {
    try {
      await _ensureInitialized();
      native.ImportSummary? result;
      await for (final event in native.importHandHistory(
        databasePath: databasePath,
        filePath: filePath,
      )) {
        result = event.summary;
        if (result == null) {
          onProgress?.call(
            ImportProgress(processed: event.processed, total: event.total),
          );
        }
      }
      if (result == null) throw const CoreException(CoreFailure.unavailable);
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
        native.CoreError.cancelled => CoreFailure.cancelled,
      });
    }
  }

  @override
  Future<int> storedHandCount(String databasePath) async {
    await _ensureInitialized();
    return native.storedHandCount(databasePath: databasePath);
  }
}
