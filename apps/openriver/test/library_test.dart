import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openriver/app/openriver_app.dart';
import 'package:openriver/features/library/library_cubit.dart';
import 'package:openriver_api/openriver_api.dart';

class FakeCore implements OpenRiverCore {
  FakeCore(this.open, {this.import});
  final Future<LibraryInfo> Function() open;
  final Future<HandImportReport> Function()? import;
  @override
  Future<LibraryInfo> initializeLibrary(String databasePath) => open();
  @override
  Future<int> storedHandCount(String databasePath) async => 0;
  @override
  Future<HandImportReport> importHandHistory(
    String databasePath,
    String filePath,
  ) async =>
      import?.call() ??
      const HandImportReport(
        parsed: 0,
        imported: 0,
        duplicates: 0,
        rejected: 0,
        storedHandCount: 0,
        diagnostics: [],
      );
}

const info = LibraryInfo(coreVersion: '0.1.0', schemaVersion: 2);

void main() {
  testWidgets('partial import shows counts and rejected hand reason', (
    tester,
  ) async {
    final core = FakeCore(
      () async => info,
      import: () async => const HandImportReport(
        parsed: 2,
        imported: 1,
        duplicates: 0,
        rejected: 1,
        storedHandCount: 1,
        diagnostics: [
          HandImportDiagnostic(
            handId: '1003',
            startLine: 17,
            endLine: 24,
            code: 'IncompleteHand',
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      OpenRiverApp(core: core, databasePath: () async => 'test.sqlite3'),
    );
    await tester.pumpAndSettle();
    await tester
        .element(find.text('Import hand history'))
        .read<LibraryCubit>()
        .importPath('synthetic.txt');
    await tester.pumpAndSettle();
    expect(find.text('1 stored hands'), findsOneWidget);
    expect(find.text('Imported 1, duplicates 0, rejected 1.'), findsOneWidget);
    expect(find.textContaining('IncompleteHand'), findsOneWidget);
  });

  testWidgets('unsupported input can retry without exposing its path', (
    tester,
  ) async {
    var attempts = 0;
    final core = FakeCore(
      () async => info,
      import: () async {
        if (++attempts == 1) {
          throw const CoreException(CoreFailure.unsupportedFormat);
        }
        return const HandImportReport(
          parsed: 1,
          imported: 1,
          duplicates: 0,
          rejected: 0,
          storedHandCount: 1,
          diagnostics: [],
        );
      },
    );
    await tester.pumpWidget(
      OpenRiverApp(core: core, databasePath: () async => 'test.sqlite3'),
    );
    await tester.pumpAndSettle();
    final cubit = tester
        .element(find.text('Import hand history'))
        .read<LibraryCubit>();
    await cubit.importPath('/private/player/history.txt');
    await tester.pumpAndSettle();
    expect(
      find.text('This hand-history format is not supported yet.'),
      findsOneWidget,
    );
    expect(find.textContaining('/private/player'), findsNothing);
    await cubit.importPath('/private/player/history.txt');
    await tester.pumpAndSettle();
    expect(find.text('1 stored hands'), findsOneWidget);
  });
  testWidgets('opening a library shows progress then ready', (tester) async {
    final completion = Completer<LibraryInfo>();
    await tester.pumpWidget(
      OpenRiverApp(
        core: FakeCore(() => completion.future),
        databasePath: () async => 'test.sqlite3',
      ),
    );
    expect(find.text('Opening your library…'), findsOneWidget);
    completion.complete(info);
    await tester.pumpAndSettle();
    expect(find.text('Your library is ready'), findsOneWidget);
  });

  testWidgets('failed startup can retry without displaying private details', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      OpenRiverApp(
        core: FakeCore(() async {
          if (++attempts == 1) {
            throw Exception('/private/player/library.sqlite3');
          }
          return info;
        }),
        databasePath: () async => 'test.sqlite3',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('/private/player'), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Your library is ready'), findsOneWidget);
  });

  for (final size in [
    const Size(375, 812),
    const Size(812, 375),
    const Size(1440, 900),
  ]) {
    testWidgets('library fits $size with enlarged text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        OpenRiverApp(
          core: FakeCore(() async => info),
          databasePath: () async => 'test.sqlite3',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Your library is ready'), findsOneWidget);
    });
  }

  test('startup finishes safely after the UI is disposed', () async {
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
}
