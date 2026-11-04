import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openriver/app/openriver_app.dart';
import 'package:openriver_api/openriver_api.dart';
import 'package:openriver_ui/openriver_ui.dart';

import 'replay_wire_fixture.dart';

class _Core implements OpenRiverCore {
  _Core({this.count = 0});
  final int count;
  final queries = <HandSearchQuery>[];
  @override
  void cancelImport() {}
  @override
  Future<LibraryInfo> initializeLibrary(String databasePath) async =>
      const LibraryInfo(coreVersion: '0.1.0', schemaVersion: 3);
  @override
  Future<int> storedHandCount(String databasePath) async => count;
  @override
  Future<StoredHandPage> listHands(
    String databasePath, {
    HandCursor? cursor,
  }) async {
    if (count == 0) return const StoredHandPage([], null);
    return cursor == null
        ? const StoredHandPage([
            StoredHand(
              id: 1,
              playedAt: '2026-10-23T12:01:00Z',
              room: 'Synthetic',
              externalHandId: '1001',
              tableName: 'Example',
              currency: 'USD',
              currencyScale: 2,
              smallBlind: 1,
              bigBlind: 2,
              playerCount: 2,
            ),
          ], HandCursor('2026-10-23T12:01:00Z', 1))
        : const StoredHandPage([
            StoredHand(
              id: 2,
              playedAt: '2026-10-22T12:01:00Z',
              room: 'Synthetic',
              externalHandId: '1002',
              tableName: 'Later',
              currency: 'USD',
              currencyScale: 2,
              smallBlind: 1,
              bigBlind: 2,
              playerCount: 2,
            ),
          ], null);
  }

  @override
  Future<HandSearchResult> searchHands(
    String databasePath,
    HandSearchQuery query,
  ) async {
    queries.add(query);
    final all = [
      for (var i = 0; i < count; i++)
        StoredHand(
          id: i + 1,
          playedAt: '2026-10-23T12:01:00Z',
          room: 'Synthetic',
          externalHandId: '${1001 + i}',
          tableName: i == 0 ? 'Example' : 'Later $i',
          currency: 'USD',
          currencyScale: 2,
          smallBlind: 1,
          bigBlind: 2,
          playerCount: 2,
          totalPot: 4,
        ),
    ];
    final matches = query.search.isEmpty
        ? all
        : all
              .where(
                (hand) => hand.tableName.toLowerCase().contains(
                  query.search.toLowerCase(),
                ),
              )
              .toList();
    return HandSearchResult(
      hands: matches
          .skip(query.page * query.pageSize)
          .take(query.pageSize)
          .toList(),
      total: matches.length,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<String> handReplayJson(String databasePath, int handId) async =>
      replayJson;
  @override
  Future<HandImportReport> importHandHistory(
    String databasePath,
    String filePath, {
    void Function(ImportProgress progress)? onProgress,
  }) => throw UnimplementedError();
}

void main() {
  testWidgets('debug builds open a sample replay from Hands', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      OpenRiverApp(core: _Core(), databasePath: () async => 'test.sqlite3'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hands').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open sample replay'));
    await tester.pumpAndSettle();
    expect(find.text('Hand replay'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Seat 2, Hero')), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Close replay'));
    await tester.pumpAndSettle();
    expect(find.text('Hand replay'), findsNothing);
    expect(find.text('Open sample replay'), findsOneWidget);
  });

  testWidgets('stored hands page and open their replay', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final core = _Core(count: 25);
    await tester.pumpWidget(
      OpenRiverApp(core: core, databasePath: () async => 'test.sqlite3'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hands').first);
    await tester.pumpAndSettle();
    expect(find.text('Example'), findsOneWidget);
    expect(find.text('Page 1 of 2'), findsOneWidget);
    await tester.ensureVisible(find.bySemanticsLabel('Next page'));
    await tester.tap(find.bySemanticsLabel('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('Later 20'), findsOneWidget);
    expect(core.queries.last.page, 1);
    await tester.ensureVisible(find.bySemanticsLabel('Previous page'));
    await tester.tap(find.bySemanticsLabel('Previous page'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Replay hand: 1001')));
    await tester.pumpAndSettle();
    expect(find.text('Hand replay'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Seat 1, Ada')), findsOneWidget);
  });

  testWidgets(
    'search, sort, and combined filters reach the full-library query',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final core = _Core(count: 25);
      await tester.pumpWidget(
        OpenRiverApp(core: core, databasePath: () async => 'test.sqlite3'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hands').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(ShadInput).first, 'Later 20');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(core.queries.last.search, 'Later 20');
      expect(find.text('Later 20'), findsNWidgets(2));
      expect(find.text('Example'), findsNothing);

      await tester.tap(find.text('Hand ID'));
      await tester.pumpAndSettle();
      expect(core.queries.last.sort, HandSortColumn.handId);
      expect(core.queries.last.page, 0);

      await tester.tap(find.text('Filters').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(ShadInput).at(1), 'Synthetic');
      await tester.enterText(find.byType(ShadInput).at(2), 'usd');
      await tester.enterText(find.byType(ShadInput).at(3), '2026-10-01');
      await tester.enterText(find.byType(ShadInput).at(4), '2026-10-31');
      await tester.enterText(find.byType(ShadInput).at(5), '2');
      await tester.enterText(find.byType(ShadInput).at(6), '6');
      await tester.ensureVisible(find.text('Apply filters'));
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      final query = core.queries.last;
      expect(query.room, 'Synthetic');
      expect(query.currency, 'USD');
      expect(query.dateFrom, '2026-10-01');
      expect(query.dateTo, '2026-10-31');
      expect(query.minPlayers, 2);
      expect(query.maxPlayers, 6);
    },
  );

  testWidgets('columns and page selection are controllable', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      OpenRiverApp(
        core: _Core(count: 2),
        databasePath: () async => 'test.sqlite3',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hands').first);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Select all visible hands'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 selected'), findsOneWidget);
    await tester.tap(find.text('Columns').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Table').last);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Close').last);
    await tester.pumpAndSettle();
    expect(find.text('Table'), findsNothing);
    await tester.enterText(find.byType(ShadInput).first, 'missing hand');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('No matching hands'), findsOneWidget);
    await tester.tap(find.textContaining('2 selected'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 selected'), findsNothing);
  });

  testWidgets('compact hands layout fits enlarged text', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      OpenRiverApp(
        core: _Core(count: 2),
        databasePath: () async => 'test.sqlite3',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hands').first);
    await tester.pumpAndSettle();
    expect(find.text('Example'), findsOneWidget);
    await tester.ensureVisible(find.bySemanticsLabel('Select hand 1001'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Select hand 1001'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
