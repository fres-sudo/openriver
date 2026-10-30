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
  FakeCore(this.open, {this.import, this.progress = const []});
  final Future<LibraryInfo> Function() open;
  final Future<HandImportReport> Function()? import;
  final List<ImportProgress> progress;
  var cancelRequests = 0;
  final importedPaths = <String>[];
  @override
  void cancelImport() => cancelRequests++;
  @override
  Future<LibraryInfo> initializeLibrary(String databasePath) => open();
  @override
  Future<int> storedHandCount(String databasePath) async => 0;
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

const info = LibraryInfo(coreVersion: '0.1.0', schemaVersion: 2);
const privatePath = '/private/player/history.txt';

Future<void> _pumpApp(
  WidgetTester tester,
  OpenRiverCore core, {
  Size size = const Size(1280, 800),
  Future<String?> Function()? choose,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    OpenRiverApp(
      core: core,
      databasePath: () async => 'test.sqlite3',
      chooseHandHistory: choose ?? () async => privatePath,
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
      expect(find.text('Library schema 2'), findsOneWidget);
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
    for (final destination in ['Library', 'Hands', 'Settings']) {
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
