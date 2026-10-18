import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openriver/app/openriver_app.dart';
import 'package:openriver_api/openriver_api.dart';
import 'package:path/path.dart' as path;

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
    expect(reopened.schemaVersion, 1);
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
  });
}
