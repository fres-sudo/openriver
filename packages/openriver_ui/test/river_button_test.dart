import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openriver_ui/openriver_ui.dart';

import 'support/harness.dart';

Widget _centered(Widget child, {double width = 320}) => Center(
  child: SizedBox(width: width, child: child),
);

/// The tappable area inside ShadButton's focus-ring padding.
Size _hitArea(WidgetTester tester) => tester.getSize(
  find.descendant(
    of: find.byType(ShadButton),
    matching: find.byType(GestureDetector),
  ),
);

void main() {
  testWidgets('has at least the minimum tap target height', (tester) async {
    await pumpRiver(
      tester,
      _centered(RiverButton(label: 'Import', onPressed: () {})),
    );

    expect(_hitArea(tester).height, 48);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('grows and wraps long labels with large text', (tester) async {
    const label = 'Import a hand history file from this device';
    await pumpRiver(
      tester,
      _centered(RiverButton(label: label, onPressed: () {}), width: 200),
      surface: const RiverTestSurface(size: Size(320, 568), textScale: 2),
    );

    expect(tester.takeException(), isNull);
    final buttonHeight = _hitArea(tester).height;
    final textHeight = tester.getSize(find.text(label)).height;
    expect(buttonHeight, greaterThan(48));
    expect(buttonHeight, greaterThanOrEqualTo(textHeight));
    expect(
      tester.getSize(find.byType(ShadButton)).width,
      lessThanOrEqualTo(200),
    );
  });

  testWidgets('expand fills the available width', (tester) async {
    await pumpRiver(
      tester,
      _centered(RiverButton(label: 'Retry', onPressed: () {}, expand: true)),
    );

    expect(tester.getSize(find.byType(ShadButton)).width, 320);
    expect(_hitArea(tester).width, 312, reason: 'less the focus-ring space');
  });

  testWidgets('activates on tap', (tester) async {
    var presses = 0;
    await pumpRiver(
      tester,
      _centered(RiverButton(label: 'Import', onPressed: () => presses++)),
    );

    await tester.tap(find.text('Import'));
    expect(presses, 1);
  });

  for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
    testWidgets('activates with ${key.keyLabel} while focused', (tester) async {
      var presses = 0;
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await pumpRiver(
        tester,
        _centered(
          RiverButton(
            label: 'Import',
            onPressed: () => presses++,
            focusNode: focusNode,
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(key);
      expect(presses, 1);
    });
  }

  testWidgets('is reachable with Tab', (tester) async {
    var presses = 0;
    await pumpRiver(
      tester,
      _centered(RiverButton(label: 'Import', onPressed: () => presses++)),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(presses, 1);
  });

  for (final (name, busy, enabled) in [
    ('busy', true, true),
    ('without a callback', false, false),
  ]) {
    testWidgets('ignores taps and keys when $name', (tester) async {
      var presses = 0;
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await pumpRiver(
        tester,
        _centered(
          RiverButton(
            label: 'Import',
            busy: busy,
            focusNode: focusNode,
            onPressed: enabled ? () => presses++ : null,
          ),
        ),
      );

      await tester.tap(find.text('Import'), warnIfMissed: false);
      focusNode.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(presses, 0);
      expect(
        tester.getSemantics(find.byType(ShadButton)),
        matchesSemantics(
          label: 'Import',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
    });
  }

  testWidgets('speaks the label but not the icon', (tester) async {
    await pumpRiver(
      tester,
      _centered(
        RiverButton(
          label: 'Import',
          icon: LucideIcons.upload,
          onPressed: () {},
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(ShadButton)),
      isSemantics(label: 'Import', isButton: true, isEnabled: true),
    );
  });

  testAcross(
    'lays out every variant',
    () => Center(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final variant in RiverButtonVariant.values)
            RiverButton(
              label: 'Import hand history',
              icon: LucideIcons.upload,
              variant: variant,
              onPressed: () {},
            ),
        ],
      ),
    ),
    surfaces: matrixSurfaces.where((s) => s.textDirection == TextDirection.ltr),
  );
}
