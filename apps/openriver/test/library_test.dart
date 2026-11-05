import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openriver/app/app_context.dart';
import 'package:openriver/app/openriver_app.dart';
import 'package:openriver/features/library/library_cubit.dart';
import 'package:openriver/features/library/library_page.dart';
import 'package:openriver_api/openriver_api.dart';
import 'package:openriver_ui/openriver_ui.dart';

class FakeCore implements OpenRiverCore {
  FakeCore(
    this.open, {
    this.import,
    this.progress = const [],
    this.analytics,
    this.export,
  });
  final Future<LibraryInfo> Function() open;
  final Future<HandImportReport> Function()? import;
  final Future<PlayerAnalyticsReport> Function(PlayerAnalyticsQuery query)?
  analytics;
  final Future<LibraryExportResult> Function()? export;
  final List<ImportProgress> progress;
  var cancelRequests = 0;
  final importedPaths = <String>[];
  final exportedPaths = <String>[];
  @override
  void cancelImport() => cancelRequests++;
  @override
  Future<LibraryInfo> initializeLibrary(String databasePath) => open();
  @override
  Future<int> storedHandCount(String databasePath) async => 0;
  @override
  Future<StoredHandPage> listHands(
    String databasePath, {
    HandCursor? cursor,
  }) async => const StoredHandPage([], null);
  @override
  Future<HandSearchResult> searchHands(
    String databasePath,
    HandSearchQuery query,
  ) async => HandSearchResult(
    hands: const [],
    total: 0,
    page: query.page,
    pageSize: query.pageSize,
  );
  @override
  Future<String> handReplayJson(String databasePath, int handId) =>
      throw UnimplementedError();
  @override
  Future<HandImportReport> importHandHistory(
    String databasePath,
    String filePath, {
    void Function(ImportProgress progress)? onProgress,
  }) async {
    importedPaths.add(filePath);
    progress.forEach(onProgress ?? (_) {});
    return import?.call() ?? _report();
  }

  @override
  Future<PlayerAnalyticsReport> playerAnalytics(
    String databasePath,
    PlayerAnalyticsQuery query,
  ) async =>
      analytics?.call(query) ??
      const PlayerAnalyticsReport(
        players: [],
        totalPlayers: 0,
        selected: null,
        graphCurrency: null,
        graphCurrencyScale: 2,
        points: [],
      );

  @override
  Future<LibraryExportResult> exportLibrary(
    String databasePath,
    String destinationPath,
  ) async {
    exportedPaths.add(destinationPath);
    return export?.call() ?? const LibraryExportResult(handCount: 1);
  }
}

HandImportReport _report({
  int imported = 1,
  int rejected = 0,
  int stored = 1,
  List<HandImportDiagnostic> diagnostics = const [],
}) => HandImportReport(
  parsed: imported + rejected,
  imported: imported,
  duplicates: 0,
  rejected: rejected,
  storedHandCount: stored,
  diagnostics: diagnostics,
);

StatisticValue _stat(String key, String label, int successes, int eligible) =>
    StatisticValue(
      key: key,
      label: label,
      description: 'Definition of $label',
      successes: successes,
      eligible: eligible,
      rate: eligible == 0 ? null : successes / eligible,
      intervalLow: null,
      intervalHigh: null,
      minimumMeaningfulSample: 100,
    );

PlayerAnalyticsReport _analyticsReport() {
  final stats = [
    _stat('vpip', 'VPIP', 1, 4),
    _stat('pfr', 'PFR', 1, 4),
    _stat('three_bet', '3-bet', 0, 2),
    _stat('fold_to_three_bet', 'Fold to 3-bet', 0, 0),
    _stat('steal', 'Steal attempt', 1, 2),
    _stat('fold_bb_to_steal', 'Big blind fold to steal', 0, 1),
  ];
  const selected = PlayerStatistics(
    room: 'stars',
    name: 'Ada',
    hands: 12,
    handsCounted: 20,
    netBigBlinds: 3,
    bbPer100: 2.5,
    aggressionFactor: 1.5,
    aggressionFrequency: 0.4,
    results: [
      CurrencyResults(
        currency: 'USD',
        currencyScale: 2,
        net: 150,
        netAtShowdown: 100,
        netWithoutShowdown: 50,
      ),
    ],
    stats: [],
  );
  return PlayerAnalyticsReport(
    players: const [
      AnalyticsPlayer(room: 'stars', name: 'Ada', hands: 12),
      AnalyticsPlayer(room: 'stars', name: 'Bo', hands: 8),
    ],
    totalPlayers: 2,
    selected: PlayerStatistics(
      room: selected.room,
      name: selected.name,
      hands: selected.hands,
      handsCounted: selected.handsCounted,
      netBigBlinds: selected.netBigBlinds,
      bbPer100: selected.bbPer100,
      aggressionFactor: selected.aggressionFactor,
      aggressionFrequency: selected.aggressionFrequency,
      results: selected.results,
      stats: stats,
    ),
    graphCurrency: 'USD',
    graphCurrencyScale: 2,
    points: const [
      ResultPoint(
        sequence: 1,
        playedAt: '2026-10-23T12:01:00Z',
        externalHandId: '1001',
        net: 50,
        cumulativeNet: 50,
        cumulativeBigBlinds: 1,
      ),
      ResultPoint(
        sequence: 2,
        playedAt: '2026-10-24T12:01:00Z',
        externalHandId: '1002',
        net: 100,
        cumulativeNet: 150,
        cumulativeBigBlinds: 3,
      ),
    ],
  );
}

const info = LibraryInfo(coreVersion: '0.1.0', schemaVersion: 3);
const privatePath = '/private/player/history.txt';

Future<void> _pumpApp(
  WidgetTester tester,
  OpenRiverCore core, {
  Size size = const Size(1280, 800),
  Future<String?> Function()? choose,
  Future<String?> Function()? chooseExport,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    OpenRiverApp(
      core: core,
      databasePath: () async => 'test.sqlite3',
      chooseHandHistory: choose ?? () async => privatePath,
      chooseExportLocation:
          chooseExport ?? () async => '/private/player/backup.sqlite3',
    ),
  );
  await tester.pumpAndSettle();
}

/// The shell's primary action: the sidebar button on wide windows.
Finder get _shellImport => find.text('Import hand history').first;

void main() {
  group('startup', () {
    testWidgets('shows progress, then the ready library', (tester) async {
      final completion = Completer<LibraryInfo>();
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        OpenRiverApp(
          core: FakeCore(() => completion.future),
          databasePath: () async => 'test.sqlite3',
        ),
      );
      await tester.pump();
      expect(find.byType(ShadApp), findsOneWidget);
      expect(find.byType(RiverShell), findsOneWidget);
      expect(find.text('Opening your library…'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Import hand history').first),
        isSemantics(isEnabled: false),
        reason: 'import waits for the library',
      );

      completion.complete(info);
      await tester.pumpAndSettle();
      expect(find.text('Your library is ready'), findsOneWidget);
      expect(find.text('0 stored hands'), findsOneWidget);
    });

    testWidgets('failure can retry without displaying private details', (
      tester,
    ) async {
      var attempts = 0;
      await _pumpApp(
        tester,
        FakeCore(() async {
          if (++attempts == 1) {
            throw Exception('/private/player/library.sqlite3');
          }
          return info;
        }),
      );
      expect(find.textContaining('/private/player'), findsNothing);
      expect(find.text('Let’s try that again'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('Your library is ready'), findsOneWidget);
    });

    test('finishes safely after the UI is disposed', () async {
      final completion = Completer<LibraryInfo>();
      final cubit = LibraryCubit(
        core: FakeCore(() => completion.future),
        databasePath: () async => 'test.sqlite3',
      );
      final opening = cubit.open();
      await cubit.close();
      completion.complete(info);
      await expectLater(opening, completes);
    });

    test('incompatible schema has a specific recovery message', () async {
      final cubit = LibraryCubit(
        core: FakeCore(
          () async => throw const CoreException(CoreFailure.incompatibleSchema),
        ),
        databasePath: () async => 'test.sqlite3',
      );
      addTearDown(cubit.close);
      await cubit.open();
      expect(cubit.state, isA<LibraryFailed>());
      expect(
        (cubit.state as LibraryFailed).message,
        contains('different version'),
      );
    });

    testWidgets('system dark appearance uses the dark theme', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await _pumpApp(tester, FakeCore(() async => info));

      final context = tester.element(find.byType(LibraryPage));
      expect(context.app.theme.brightness, Brightness.dark);
      expect(context.app.theme.colors, RiverThemes.dark.colorScheme);
    });
  });

  group('import', () {
    testWidgets('partial import shows counts and the rejection reason', (
      tester,
    ) async {
      final core = FakeCore(
        () async => info,
        import: () async => _report(
          rejected: 1,
          diagnostics: const [
            HandImportDiagnostic(
              handId: '1003',
              startLine: 17,
              endLine: 24,
              code: 'IncompleteHand',
            ),
          ],
        ),
      );
      await _pumpApp(tester, core);

      await tester.tap(_shellImport);
      await tester.pumpAndSettle();
      expect(core.importedPaths, [privatePath]);
      expect(
        find.text('Imported 1, duplicates 0, rejected 1.'),
        findsOneWidget,
      );
      expect(
        find.text('Hand 1003, lines 17–24: IncompleteHand'),
        findsOneWidget,
      );
      expect(find.textContaining('/private/player'), findsNothing);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsNothing);
      expect(find.text('1 stored hand'), findsOneWidget);
      expect(
        find.text('Last import: imported 1, duplicates 0, rejected 1.'),
        findsOneWidget,
      );

      await tester.tap(find.text('View report'));
      await tester.pumpAndSettle();
      expect(
        find.text('Hand 1003, lines 17–24: IncompleteHand'),
        findsOneWidget,
      );
    });

    testWidgets('unsupported input can choose another file', (tester) async {
      var attempts = 0;
      var choices = 0;
      final core = FakeCore(
        () async => info,
        import: () async {
          if (++attempts == 1) {
            throw const CoreException(CoreFailure.unsupportedFormat);
          }
          return _report();
        },
      );
      await _pumpApp(
        tester,
        core,
        choose: () async {
          choices++;
          return privatePath;
        },
      );

      await tester.tap(_shellImport);
      await tester.pumpAndSettle();
      expect(
        find.text('This hand-history format is not supported yet.'),
        findsWidgets,
      );
      expect(find.textContaining('/private/player'), findsNothing);

      await tester.tap(find.text('Choose another file'));
      await tester.pumpAndSettle();
      expect(choices, 2);
      expect(
        find.text('Imported 1, duplicates 0, rejected 0.'),
        findsOneWidget,
      );
    });

    testWidgets('shows progress and a cancel that reports no change', (
      tester,
    ) async {
      final running = Completer<HandImportReport>();
      final core = FakeCore(
        () async => info,
        import: () => running.future,
        progress: const [ImportProgress(processed: 250, total: 1000)],
      );
      await _pumpApp(tester, core);

      await tester.tap(_shellImport);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // The overlay and the library page both show progress.
      expect(find.text('Importing hands… 250 of 1000'), findsNWidgets(2));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Import hand history').first),
        isSemantics(isEnabled: false),
        reason: 'one import at a time',
      );

      await tester.tap(find.text('Cancel import').last);
      expect(core.cancelRequests, 1);
      running.completeError(const CoreException(CoreFailure.cancelled));
      await tester.pumpAndSettle();
      expect(
        find.text('Import cancelled. Nothing from that file was added.'),
        findsWidgets,
      );
      expect(find.text('Cancel import'), findsNothing);
    });

    testWidgets('cancelling the chooser imports nothing', (tester) async {
      final core = FakeCore(() async => info);
      await _pumpApp(tester, core, choose: () async => null);

      await tester.tap(_shellImport);
      await tester.pumpAndSettle();
      expect(core.importedPaths, isEmpty);
      expect(find.text('Done'), findsNothing);
    });

    testWidgets('a failing chooser shows a message', (tester) async {
      await _pumpApp(
        tester,
        FakeCore(() async => info),
        choose: () async => throw Exception('no chooser'),
      );

      await tester.tap(_shellImport);
      await tester.pump();
      expect(
        find.text('The file chooser could not open. Please try again.'),
        findsOneWidget,
      );
      await tester.pumpAndSettle(const Duration(seconds: 10));
    });

    testWidgets('import is in the page header on phones', (tester) async {
      final core = FakeCore(() async => info);
      await _pumpApp(tester, core, size: const Size(390, 844));

      await tester.tap(find.text('Import hand history').first);
      await tester.pumpAndSettle();
      expect(core.importedPaths, [privatePath]);
    });
  });

  group('statistics and export', () {
    testWidgets('shows core stats, results, graph modes, and filters', (
      tester,
    ) async {
      final queries = <PlayerAnalyticsQuery>[];
      final core = FakeCore(
        () async => info,
        analytics: (query) async {
          queries.add(query);
          return _analyticsReport();
        },
      );
      await _pumpApp(tester, core, size: const Size(1440, 1000));

      await tester.tap(find.text('Statistics').first);
      await tester.pumpAndSettle();
      expect(find.text('Ada · stars'), findsWidgets);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('+2.50'), findsOneWidget);
      expect(find.text(r'$1.50'), findsWidgets);
      expect(find.text('25.0%'), findsWidgets);
      expect(find.text('1 / 4 opportunities'), findsWidgets);
      expect(find.text('—'), findsWidgets);
      expect(find.text(r'Final result: $1.50'), findsOneWidget);

      await tester.tap(find.text('Show big blinds'));
      await tester.pump();
      expect(find.text('Final result: +3.00 BB'), findsOneWidget);

      await tester.tap(find.text('Filters').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(ShadInput).first, 'usd');
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(queries.last.currency, 'USD');
    });

    testWidgets('exports a backup without exposing its path', (tester) async {
      final core = FakeCore(() async => info);
      await _pumpApp(tester, core);
      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export library backup'));
      await tester.pump();

      expect(core.exportedPaths, ['/private/player/backup.sqlite3']);
      expect(find.text('Backup exported with 1 hand.'), findsOneWidget);
      expect(find.textContaining('/private/player'), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 10));
    });
  });

  group('navigation', () {
    testWidgets('shows every destination', (tester) async {
      await _pumpApp(tester, FakeCore(() async => info));

      await tester.tap(find.text('Hands').first);
      await tester.pumpAndSettle();
      expect(find.text('Every hand you have imported.'), findsOneWidget);
      expect(find.text('No hands yet'), findsOneWidget);

      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();
      expect(find.text('Core version 0.1.0'), findsOneWidget);
      expect(find.text('Library schema 3'), findsOneWidget);
    });

    testWidgets('back returns to the library, then leaves the app', (
      tester,
    ) async {
      final platformCalls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          platformCalls.add(call.method);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _pumpApp(tester, FakeCore(() async => info));
      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Your library is ready'), findsOneWidget);
      expect(platformCalls, isNot(contains('SystemNavigator.pop')));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(platformCalls, contains('SystemNavigator.pop'));
    });

    testWidgets('unknown paths go to the library', (tester) async {
      await _pumpApp(tester, FakeCore(() async => info));
      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();

      GoRouter.of(tester.element(find.byType(RiverShell))).go('/missing');
      await tester.pumpAndSettle();
      expect(find.text('Your library is ready'), findsOneWidget);
    });

    testWidgets('reselecting scrolls to the top; switching keeps position', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      // Tall enough for the sidebar, short enough for the library to scroll.
      await _pumpApp(
        tester,
        FakeCore(() async => info),
        size: const Size(1800, 500),
      );
      final controller = PrimaryScrollController.of(
        tester.element(find.byType(LibraryPage)),
      );
      expect(controller.position.maxScrollExtent, greaterThan(100));
      controller.jumpTo(100);
      await tester.pump();

      await tester.tap(find.text('Hands').first);
      await tester.pumpAndSettle();
      // By icon: the page title is also "Library".
      await tester.tap(find.byIcon(LucideIcons.library));
      await tester.pumpAndSettle();
      expect(controller.offset, 100, reason: 'kept while away');

      await tester.tap(find.byIcon(LucideIcons.library));
      await tester.pumpAndSettle();
      expect(controller.offset, 0, reason: 'reselected');
    });
  });

  testWidgets('context.app.localizations reads app strings', (tester) async {
    await _pumpApp(tester, FakeCore(() async => info));
    final context = tester.element(find.byType(LibraryPage));

    expect(context.app.localizations.navHands, 'Hands');
    expect(context.app.localizations.storedHands(1), '1 stored hand');
    expect(context.app.localizations.storedHands(2), '2 stored hands');
  });

  for (final size in const [Size(375, 812), Size(812, 375), Size(1440, 900)]) {
    for (final destination in ['Library', 'Hands', 'Statistics', 'Settings']) {
      testWidgets('$destination fits $size with enlarged text', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _pumpApp(tester, FakeCore(() async => info), size: size);
        if (destination != 'Library') {
          await tester.tap(find.text(destination).first);
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      });
    }
  }
}
