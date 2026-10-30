import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openriver_ui/openriver_ui.dart';

import 'support/harness.dart';

const _openKey = Key('open');

/// A page with a button that opens an overlay with [content].
Widget _opener({Widget content = const Text('Overlay body')}) => Builder(
  builder: (context) => Center(
    child: RiverButton(
      key: _openKey,
      label: 'Open',
      onPressed: () => showRiverOverlay<void>(
        context: context,
        title: 'Import report',
        description: 'What happened to each hand.',
        builder: (_) => content,
      ),
    ),
  ),
);

/// Opens the overlay and lets its transition finish. The first frame starts
/// the transition; without the second pump the panel is still transparent,
/// and semantics and contrast checks would see nothing.
Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(_openKey));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('is a bottom sheet in a compact window', (tester) async {
    await pumpRiver(
      tester,
      _opener(),
      surface: const RiverTestSurface(size: Size(390, 844)),
    );
    await _open(tester);

    final title = tester.getRect(find.text('Import report'));
    final body = tester.getRect(find.text('Overlay body'));
    expect(body.bottom, greaterThan(844 / 2), reason: 'anchored at bottom');
    expect(title.left, 25, reason: '1-pixel border plus 24 padding');
  });

  testWidgets('is a centered dialog otherwise', (tester) async {
    await pumpRiver(tester, _opener());
    await _open(tester);

    final title = tester.getRect(find.text('Import report'));
    expect(title.left, greaterThan((1280 - 560) / 2));
    expect(title.top, greaterThan(100));
  });

  testWidgets('switches form when the window crosses compact', (tester) async {
    await pumpRiver(tester, _opener());
    await _open(tester);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();

    expect(tester.getRect(find.text('Import report')).left, 25);
  });

  testWidgets('names its route and marks the title as a header', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpRiver(tester, _opener());
    await _open(tester);

    expect(
      tester.getSemantics(find.text('Import report')),
      isSemantics(isHeader: true),
    );
    expect(
      find.semantics.byPredicate(
        (node) =>
            node.label == 'Import report' &&
            node.flagsCollection.scopesRoute &&
            node.flagsCollection.namesRoute,
      ),
      findsOne,
    );
    handle.dispose();
  });

  for (final (name, close) in <(String, Future<void> Function(WidgetTester))>[
    ('the close button', (t) => t.tap(find.byIcon(LucideIcons.x))),
    ('Escape', (t) => t.sendKeyEvent(LogicalKeyboardKey.escape)),
    ('the barrier', (t) => t.tapAt(const Offset(10, 10))),
    ('system back', (t) => t.binding.handlePopRoute()),
  ]) {
    testWidgets('closes with $name', (tester) async {
      await pumpRiver(tester, _opener());
      await _open(tester);
      expect(find.text('Overlay body'), findsOneWidget);

      await close(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Overlay body'), findsNothing);
    });
  }

  testWidgets('taps inside the panel do not close it', (tester) async {
    await pumpRiver(tester, _opener());
    await _open(tester);

    await tester.tap(find.text('What happened to each hand.'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Overlay body'), findsOneWidget);
  });

  testWidgets('keeps keyboard focus inside', (tester) async {
    await pumpRiver(tester, _opener());
    await _open(tester);

    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus!.context!;
      expect(
        find.descendant(
          of: find.byKey(_openKey),
          matching: find.byWidget(focused.widget),
        ),
        findsNothing,
      );
    }
  });

  testWidgets('skips its transition with reduced motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpRiver(tester, _opener());

    await tester.tap(find.byKey(_openKey));
    await tester.pump();
    await tester.pump();
    final opacity = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.text('Import report'),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(opacity.opacity.value, 1);
  });

  testWidgets('scrolls long content within the window', (tester) async {
    await pumpRiver(
      tester,
      _opener(content: const SizedBox(height: 3000, child: Text('Tall'))),
      surface: const RiverTestSurface(size: Size(390, 844)),
    );
    await _open(tester);

    expect(tester.takeException(), isNull);
    final title = tester.getRect(find.text('Import report'));
    expect(title.top, greaterThanOrEqualTo(844 * 0.1 - 1));
  });

  testWidgets('stays above the on-screen keyboard', (tester) async {
    await pumpRiver(
      tester,
      _opener(),
      surface: const RiverTestSurface(size: Size(390, 844)),
    );
    await _open(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();

    expect(
      tester.getRect(find.text('Overlay body')).bottom,
      lessThanOrEqualTo(844 - 300),
    );
  });

  testAcross(
    'lays out the overlay',
    () => _opener(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Imported 1, duplicates 0, rejected 1.'),
          const SizedBox(height: 16),
          RiverButton(label: 'Choose another file', onPressed: () {}),
        ],
      ),
    ),
    verify: (tester, surface) async {
      await _open(tester);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    },
  );
}
