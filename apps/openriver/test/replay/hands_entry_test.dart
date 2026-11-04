import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openriver/app/openriver_app.dart';
import 'package:openriver_api/openriver_api.dart';

import 'replay_wire_fixture.dart';

class _Core implements OpenRiverCore {
  _Core({this.count = 0});
  final int count;
  final cursors = <HandCursor?>[];
  @override
  void cancelImport() {}
  @override
  Future<LibraryInfo> initializeLibrary(String databasePath) async =>
      const LibraryInfo(coreVersion: '0.1.0', schemaVersion: 2);
  @override
  Future<int> storedHandCount(String databasePath) async => count;
  @override
  Future<StoredHandPage> listHands(
    String databasePath, {
    HandCursor? cursor,
  }) async {
    cursors.add(cursor);
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
    final core = _Core(count: 2);
    await tester.pumpWidget(
      OpenRiverApp(core: core, databasePath: () async => 'test.sqlite3'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hands').first);
    await tester.pumpAndSettle();
    expect(find.text('Example'), findsOneWidget);
    expect(find.textContaining(r'Blinds $0.01/$0.02'), findsOneWidget);
    await tester.tap(find.text('Load more hands'));
    await tester.pumpAndSettle();
    expect(find.text('Later'), findsOneWidget);
    expect(core.cursors.last?.id, 1);
    await tester.tap(find.text('Replay hand').first);
    await tester.pumpAndSettle();
    expect(find.text('Hand replay'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Seat 1, Ada')), findsOneWidget);
  });
}
