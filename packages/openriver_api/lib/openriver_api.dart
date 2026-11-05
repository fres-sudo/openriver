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
  exportDestinationExists,
  invalidExportPath,
  exportFailed,
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
  Future<StoredHandPage> listHands(String databasePath, {HandCursor? cursor});
  Future<HandSearchResult> searchHands(
    String databasePath,
    HandSearchQuery query,
  );
  Future<String> handReplayJson(String databasePath, int handId);
  Future<PlayerAnalyticsReport> playerAnalytics(
    String databasePath,
    PlayerAnalyticsQuery query,
  );
  Future<LibraryExportResult> exportLibrary(
    String databasePath,
    String destinationPath,
  );
}

enum HandSortColumn { playedAt, handId, table, room, blinds, players, pot }

final class HandSearchQuery {
  const HandSearchQuery({
    this.search = '',
    this.room = '',
    this.currency = '',
    this.dateFrom,
    this.dateTo,
    this.minPlayers,
    this.maxPlayers,
    this.sort = HandSortColumn.playedAt,
    this.descending = true,
    this.page = 0,
    this.pageSize = 20,
  });

  final String search;
  final String room;
  final String currency;
  final String? dateFrom;
  final String? dateTo;
  final int? minPlayers;
  final int? maxPlayers;
  final HandSortColumn sort;
  final bool descending;
  final int page;
  final int pageSize;
}

final class HandSearchResult {
  const HandSearchResult({
    required this.hands,
    required this.total,
    required this.page,
    required this.pageSize,
  });
  final List<StoredHand> hands;
  final int total;
  final int page;
  final int pageSize;
}

final class HandCursor {
  const HandCursor(this.playedAt, this.id);
  final String playedAt;
  final int id;
}

final class StoredHand {
  const StoredHand({
    required this.id,
    required this.playedAt,
    required this.room,
    required this.externalHandId,
    required this.tableName,
    required this.currency,
    required this.currencyScale,
    required this.smallBlind,
    required this.bigBlind,
    required this.playerCount,
    this.totalPot = 0,
  });
  final int id;
  final String playedAt;
  final String room;
  final String externalHandId;
  final String tableName;
  final String currency;
  final int currencyScale;
  final int smallBlind;
  final int bigBlind;
  final int playerCount;
  final int totalPot;
}

final class StoredHandPage {
  const StoredHandPage(this.hands, this.nextCursor);
  final List<StoredHand> hands;
  final HandCursor? nextCursor;
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

final class PlayerAnalyticsQuery {
  const PlayerAnalyticsQuery({
    this.room = '',
    this.player = '',
    this.currency = '',
    this.dateFrom,
    this.dateTo,
    this.minBigBlind,
    this.maxBigBlind,
  });

  final String room;
  final String player;
  final String currency;
  final String? dateFrom;
  final String? dateTo;
  final int? minBigBlind;
  final int? maxBigBlind;
}

final class AnalyticsPlayer {
  const AnalyticsPlayer({
    required this.room,
    required this.name,
    required this.hands,
  });
  final String room;
  final String name;
  final int hands;
}

final class CurrencyResults {
  const CurrencyResults({
    required this.currency,
    required this.currencyScale,
    required this.net,
    required this.netAtShowdown,
    required this.netWithoutShowdown,
  });
  final String currency;
  final int currencyScale;
  final int net;
  final int netAtShowdown;
  final int netWithoutShowdown;
}

final class StatisticValue {
  const StatisticValue({
    required this.key,
    required this.label,
    required this.description,
    required this.successes,
    required this.eligible,
    required this.rate,
    required this.intervalLow,
    required this.intervalHigh,
    required this.minimumMeaningfulSample,
  });
  final String key;
  final String label;
  final String description;
  final int successes;
  final int eligible;
  final double? rate;
  final double? intervalLow;
  final double? intervalHigh;
  final int minimumMeaningfulSample;
}

final class PlayerStatistics {
  const PlayerStatistics({
    required this.room,
    required this.name,
    required this.hands,
    required this.handsCounted,
    required this.netBigBlinds,
    required this.bbPer100,
    required this.aggressionFactor,
    required this.aggressionFrequency,
    required this.results,
    required this.stats,
  });
  final String room;
  final String name;
  final int hands;
  final int handsCounted;
  final double netBigBlinds;
  final double? bbPer100;
  final double? aggressionFactor;
  final double? aggressionFrequency;
  final List<CurrencyResults> results;
  final List<StatisticValue> stats;
}

final class ResultPoint {
  const ResultPoint({
    required this.sequence,
    required this.playedAt,
    required this.externalHandId,
    required this.net,
    required this.cumulativeNet,
    required this.cumulativeBigBlinds,
  });
  final int sequence;
  final String playedAt;
  final String externalHandId;
  final int net;
  final int cumulativeNet;
  final double cumulativeBigBlinds;
}

final class PlayerAnalyticsReport {
  const PlayerAnalyticsReport({
    required this.players,
    required this.totalPlayers,
    required this.selected,
    required this.graphCurrency,
    required this.graphCurrencyScale,
    required this.points,
  });
  final List<AnalyticsPlayer> players;
  final int totalPlayers;
  final PlayerStatistics? selected;
  final String? graphCurrency;
  final int graphCurrencyScale;
  final List<ResultPoint> points;
}

final class LibraryExportResult {
  const LibraryExportResult({required this.handCount});
  final int handCount;
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
      if (status.schemaVersion != 3) {
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
        native.CoreError.exportDestinationExists =>
          CoreFailure.exportDestinationExists,
        native.CoreError.invalidExportPath => CoreFailure.invalidExportPath,
        native.CoreError.exportFailed => CoreFailure.exportFailed,
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
        native.CoreError.exportDestinationExists =>
          CoreFailure.exportDestinationExists,
        native.CoreError.invalidExportPath => CoreFailure.invalidExportPath,
        native.CoreError.exportFailed => CoreFailure.exportFailed,
      });
    }
  }

  @override
  Future<int> storedHandCount(String databasePath) async {
    await _ensureInitialized();
    return native.storedHandCount(databasePath: databasePath);
  }

  @override
  Future<StoredHandPage> listHands(
    String databasePath, {
    HandCursor? cursor,
  }) async {
    await _ensureInitialized();
    final page = await native.listHands(
      databasePath: databasePath,
      cursorPlayedAt: cursor?.playedAt,
      cursorId: cursor?.id,
    );
    return StoredHandPage(
      [
        for (final hand in page.hands)
          StoredHand(
            id: hand.id,
            playedAt: hand.playedAt,
            room: hand.room,
            externalHandId: hand.externalHandId,
            tableName: hand.tableName,
            currency: hand.currency,
            currencyScale: hand.currencyScale,
            smallBlind: hand.smallBlind,
            bigBlind: hand.bigBlind,
            playerCount: hand.playerCount,
            totalPot: hand.totalPot,
          ),
      ],
      page.nextPlayedAt == null || page.nextId == null
          ? null
          : HandCursor(page.nextPlayedAt!, page.nextId!),
    );
  }

  @override
  Future<HandSearchResult> searchHands(
    String databasePath,
    HandSearchQuery query,
  ) async {
    await _ensureInitialized();
    final result = await native.searchHands(
      databasePath: databasePath,
      request: native.HandQueryRequest(
        search: query.search,
        room: query.room,
        currency: query.currency,
        dateFrom: query.dateFrom,
        dateTo: query.dateTo,
        minPlayers: query.minPlayers,
        maxPlayers: query.maxPlayers,
        sort: switch (query.sort) {
          HandSortColumn.playedAt => native.HandSortColumn.playedAt,
          HandSortColumn.handId => native.HandSortColumn.handId,
          HandSortColumn.table => native.HandSortColumn.table,
          HandSortColumn.room => native.HandSortColumn.room,
          HandSortColumn.blinds => native.HandSortColumn.blinds,
          HandSortColumn.players => native.HandSortColumn.players,
          HandSortColumn.pot => native.HandSortColumn.pot,
        },
        descending: query.descending,
        page: query.page,
        pageSize: query.pageSize,
      ),
    );
    return HandSearchResult(
      hands: [
        for (final hand in result.hands)
          StoredHand(
            id: hand.id,
            playedAt: hand.playedAt,
            room: hand.room,
            externalHandId: hand.externalHandId,
            tableName: hand.tableName,
            currency: hand.currency,
            currencyScale: hand.currencyScale,
            smallBlind: hand.smallBlind,
            bigBlind: hand.bigBlind,
            playerCount: hand.playerCount,
            totalPot: hand.totalPot,
          ),
      ],
      total: result.total,
      page: result.page,
      pageSize: result.pageSize,
    );
  }

  @override
  Future<String> handReplayJson(String databasePath, int handId) async {
    await _ensureInitialized();
    return native.handReplay(databasePath: databasePath, handId: handId);
  }

  @override
  Future<PlayerAnalyticsReport> playerAnalytics(
    String databasePath,
    PlayerAnalyticsQuery query,
  ) async {
    try {
      await _ensureInitialized();
      final report = await native.playerAnalytics(
        databasePath: databasePath,
        request: native.PlayerAnalyticsRequest(
          room: query.room,
          player: query.player,
          currency: query.currency,
          dateFrom: query.dateFrom,
          dateTo: query.dateTo,
          minBigBlind: query.minBigBlind,
          maxBigBlind: query.maxBigBlind,
        ),
      );
      return PlayerAnalyticsReport(
        players: [
          for (final player in report.players)
            AnalyticsPlayer(
              room: player.room,
              name: player.name,
              hands: player.hands.toInt(),
            ),
        ],
        totalPlayers: report.totalPlayers,
        selected: switch (report.selected) {
          null => null,
          final selected => PlayerStatistics(
            room: selected.room,
            name: selected.name,
            hands: selected.hands.toInt(),
            handsCounted: selected.handsCounted.toInt(),
            netBigBlinds: selected.netBigBlinds,
            bbPer100: selected.bbPer100,
            aggressionFactor: selected.aggressionFactor,
            aggressionFrequency: selected.aggressionFrequency,
            results: [
              for (final result in selected.results)
                CurrencyResults(
                  currency: result.currency,
                  currencyScale: result.currencyScale,
                  net: result.net,
                  netAtShowdown: result.netAtShowdown,
                  netWithoutShowdown: result.netWithoutShowdown,
                ),
            ],
            stats: [
              for (final stat in selected.stats)
                StatisticValue(
                  key: stat.key,
                  label: stat.label,
                  description: stat.description,
                  successes: stat.successes.toInt(),
                  eligible: stat.eligible.toInt(),
                  rate: stat.rate,
                  intervalLow: stat.intervalLow,
                  intervalHigh: stat.intervalHigh,
                  minimumMeaningfulSample: stat.minimumMeaningfulSample,
                ),
            ],
          ),
        },
        graphCurrency: report.graphCurrency,
        graphCurrencyScale: report.graphCurrencyScale,
        points: [
          for (final point in report.points)
            ResultPoint(
              sequence: point.sequence,
              playedAt: point.playedAt,
              externalHandId: point.externalHandId,
              net: point.net,
              cumulativeNet: point.cumulativeNet,
              cumulativeBigBlinds: point.cumulativeBigBlinds,
            ),
        ],
      );
    } on native.CoreError catch (error) {
      throw CoreException(_coreFailure(error));
    }
  }

  @override
  Future<LibraryExportResult> exportLibrary(
    String databasePath,
    String destinationPath,
  ) async {
    try {
      await _ensureInitialized();
      final result = await native.exportLibrary(
        databasePath: databasePath,
        destinationPath: destinationPath,
      );
      return LibraryExportResult(handCount: result.handCount);
    } on native.CoreError catch (error) {
      throw CoreException(_coreFailure(error));
    }
  }
}

CoreFailure _coreFailure(native.CoreError error) => switch (error) {
  native.CoreError.databaseUnavailable => CoreFailure.unavailable,
  native.CoreError.migrationFailed => CoreFailure.migrationFailed,
  native.CoreError.incompatibleSchema => CoreFailure.incompatibleSchema,
  native.CoreError.fileUnavailable => CoreFailure.fileUnavailable,
  native.CoreError.invalidSource => CoreFailure.invalidSource,
  native.CoreError.unsupportedFormat => CoreFailure.unsupportedFormat,
  native.CoreError.cancelled => CoreFailure.cancelled,
  native.CoreError.exportDestinationExists =>
    CoreFailure.exportDestinationExists,
  native.CoreError.invalidExportPath => CoreFailure.invalidExportPath,
  native.CoreError.exportFailed => CoreFailure.exportFailed,
};
