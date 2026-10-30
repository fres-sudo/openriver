import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openriver/app/openriver_app.dart';
import 'package:openriver/features/library/library_cubit.dart';
import 'package:openriver/features/library/library_page.dart';
import 'package:openriver_api/openriver_api.dart';
import 'package:path/path.dart' as path;

const syntheticHand =
    '''PokerStars Hand #2001: Hold'em No Limit (\$0.01/\$0.02 USD) - 2026/10/23 12:01:00 UTC
Table 'Example' 6-max Seat #1 is the button
Seat 1: Ada (\$1.00 in chips)
Seat 2: Bo (\$1.00 in chips)
Ada: posts small blind \$0.01
Bo: posts big blind \$0.02
*** HOLE CARDS ***
Ada: calls \$0.01
Bo: checks
*** FLOP *** [2c 7d 9h]
Ada: bets \$0.02
Bo: folds
Uncalled bet (\$0.02) returned to Ada
Ada collected \$0.04 from pot
*** SUMMARY ***
Total pot \$0.04 | Rake \$0.00
Seat 1: Ada collected \$0.04
''';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('packaged Rust core migrates SQLite and renders the library', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp('openriver_smoke_');
    addTearDown(() => directory.delete(recursive: true));
    final database = path.join(directory.path, 'library.sqlite3');
    final core = RustOpenRiverCore();

    // Real native calls: no fake core or database.
    final first = await core.initializeLibrary(database);
    final reopened = await core.initializeLibrary(database);
    expect(first.coreVersion, '0.1.0');
    expect(reopened.schemaVersion, 2);
    expect(await File(database).exists(), isTrue);
    await expectLater(
      core.initializeLibrary(
        path.join(directory.path, 'missing', 'library.sqlite3'),
      ),
      throwsA(
        isA<CoreException>().having(
          (e) => e.failure,
          'failure',
          CoreFailure.unavailable,
        ),
      ),
    );
    final history = File(path.join(directory.path, 'synthetic.txt'));
    await history.writeAsString(syntheticHand);
    final imported = await core.importHandHistory(database, history.path);
    expect(
      (imported.imported, imported.rejected, imported.storedHandCount),
      (1, 0, 1),
    );
    await core.initializeLibrary(database);
    expect(await core.storedHandCount(database), 1);
    final repeated = await core.importHandHistory(database, history.path);
    expect((repeated.imported, repeated.duplicates), (0, 1));

    await tester.pumpWidget(
      OpenRiverApp(core: core, databasePath: () async => database),
    );
    for (
      var i = 0;
      i < 100 && find.text('Your library is ready').evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Your library is ready'), findsOneWidget);
    final template = await history.readAsString();
    final batch = File(path.join(directory.path, 'synthetic-10k.txt'));
    await batch.writeAsString(
      List.generate(
        10000,
        (i) => template.replaceFirst('Hand #2001', 'Hand #${10000 + i}'),
      ).join('\n'),
    );
    final cubit = tester.element(find.byType(LibraryPage)).read<LibraryCubit>();
    final importing = cubit.importPath(batch.path);
    await tester.pump();
    expect(find.text('Importing hands…'), findsOneWidget);
    await importing;
    await tester.pump();
    expect(find.text('10001 stored hands'), findsOneWidget);
  });

  testWidgets('mixed native import reports rejection and persists valid hand', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp('openriver_mixed_');
    addTearDown(() => directory.delete(recursive: true));
    final database = path.join(directory.path, 'library.sqlite3');
    final history = File(path.join(directory.path, 'mixed.txt'));
    await history.writeAsString(
      '''${syntheticHand.replaceFirst('Hand #2001', 'Hand #3001')}
PokerStars Hand #3002: Hold'em No Limit (\$0.01/\$0.02 USD) - 2026/10/23 12:02:00 UTC
Table 'Example' 6-max Seat #1 is the button
Seat 1: Ada (\$1.00 in chips)
Seat 2: Bo (\$1.00 in chips)
Ada: posts small blind \$0.01
Bo: posts big blind \$0.02
*** HOLE CARDS ***
Ada: calls \$0.01
''',
    );
    final core = RustOpenRiverCore();
    await tester.pumpWidget(
      OpenRiverApp(core: core, databasePath: () async => database),
    );
    for (
      var i = 0;
      i < 100 && find.text('Your library is ready').evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final cubit = tester.element(find.byType(LibraryPage)).read<LibraryCubit>();
    await cubit.importPath(history.path);
    await tester.pump();
    expect(
      find.text('Last import: imported 1, duplicates 0, rejected 1.'),
      findsOneWidget,
    );
    expect(find.text('1 stored hand'), findsOneWidget);
    await tester.tap(find.text('View report'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Imported 1, duplicates 0, rejected 1.'), findsOneWidget);
    expect(find.textContaining('Hand 3002'), findsOneWidget);
    expect(find.textContaining('IncompleteHand'), findsOneWidget);

    await core.initializeLibrary(database);
    expect(await core.storedHandCount(database), 1);
    final repeated = await core.importHandHistory(database, history.path);
    expect(
      (repeated.imported, repeated.duplicates, repeated.rejected),
      (0, 1, 1),
    );
    expect(repeated.storedHandCount, 1);
  });
}
