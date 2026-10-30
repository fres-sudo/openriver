import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openriver/app/openriver_app.dart';
import 'package:openriver_api/openriver_api.dart';

class _Core implements OpenRiverCore {
  @override
  void cancelImport() {}
  @override
  Future<LibraryInfo> initializeLibrary(String databasePath) async =>
      const LibraryInfo(coreVersion: '0.1.0', schemaVersion: 2);
  @override
  Future<int> storedHandCount(String databasePath) async => 0;
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
}
