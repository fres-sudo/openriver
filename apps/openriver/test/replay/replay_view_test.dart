import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openriver_ui/openriver_ui.dart';
import 'package:openriver/features/replay/table_pieces.dart';
import 'package:openriver/features/replay/action_log.dart';
import 'package:openriver/features/replay/replay_controls.dart';
import 'package:openriver/features/replay/replay_fixtures.dart';
import 'package:openriver/features/replay/replay_models.dart';

import 'replay_harness.dart';

Finder _seat(int seat) => find.byKey(ValueKey('seat-$seat'));

/// Whether the seat draws its hole cards face up.
List<bool> _faceUp(WidgetTester tester, int seat) => tester
    .widgetList<PlayingCardWidget>(
      find.descendant(
        of: _seat(seat),
        matching: find.byType(PlayingCardWidget),
      ),
    )
    .map((card) => card.faceUp && card.card != null)
    .toList();

String _announcement(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('replay-announcement')))
    .data!;

/// A control in [ReplayControls] by its spoken label.
Finder _control(String label) => find.descendant(
  of: find.byType(ReplayControls),
  matching: find.bySemanticsLabel(label),
);

Future<void> _tapLabel(WidgetTester tester, String label) async {
  final target = _control(label).first;
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
}

bool _enabled(WidgetTester tester, String label) => tester
    .getSemantics(_control(label).first)
    .getSemanticsData()
    .flagsCollection
    .isEnabled
    .toBoolOrNull()!;

void main() {
  testWidgets('stepping and jumping update the table', (tester) async {
    final cubit = await pumpReplay(tester, ReplayFixtures.sidePotAllIn);
    expect(_announcement(tester), r'3 players seated, blinds $0.01/$0.02');
    expect(_enabled(tester, 'Previous step'), isFalse);

    await _tapLabel(tester, 'Next step');
    await _tapLabel(tester, 'Next step');
    await _tapLabel(tester, 'Next step');
    expect(cubit.state.index, 3);
    expect(_announcement(tester), r'Cy raises to $3.00, all-in');
    expect(
      find.descendant(of: _seat(3), matching: find.text(r'Raise to $3.00')),
      findsOneWidget,
    );
    expect(find.text(r'$3.00'), findsOneWidget, reason: "Cy's bet");

    await _tapLabel(tester, 'Previous step');
    expect(cubit.state.index, 2);

    await _tapLabel(tester, 'Last step');
    expect(cubit.state.index, 12);
    expect(_announcement(tester), r'Bo wins $2.00 from the side pot 1');
    expect(find.text(r'Won $3.00'), findsOneWidget);
    expect(find.text(r'Won $2.00'), findsOneWidget);
    expect(_enabled(tester, 'Next step'), isFalse);

    await _tapLabel(tester, 'First step');
    expect(cubit.state.index, 0);

    await _tapLabel(tester, 'Turn');
    expect(cubit.state.index, 8);
    expect(cubit.state.step.board, hasLength(4));
  });

  testWidgets('seats describe themselves to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    final cubit = await pumpReplay(tester, ReplayFixtures.sidePotAllIn);
    cubit.jumpTo(6);
    await tester.pump();
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'^Seat 3, Cy, button, stack \$1\.00, bet \$2\.00, '
          r'Raise to \$3\.00, holding queen of spades, queen of hearts$',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Seat 1, Ada, small blind, .*all-in')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Seat 4, empty'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('replay-announcement'))),
      isSemantics(isLiveRegion: true, label: r'Cy takes back $1.00 uncalled'),
    );
    handle.dispose();
  });

  testWidgets('the next seat to act is highlighted and announced', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final cubit = await pumpReplay(tester, ReplayFixtures.sixMaxRiver);
    cubit.jumpTo(2);
    await tester.pump();
    expect(cubit.state.step.nextToAct, 1);
    expect(find.bySemanticsLabel(RegExp(r'^Seat 1, Uma, .*to act')), findsOne);
    expect(
      find.bySemanticsLabel(RegExp(r'^Seat 2, Hero, .*to act')),
      findsNothing,
    );
    handle.dispose();
  });

  testWidgets('street buttons are disabled for streets never reached', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpReplay(tester, ReplayFixtures.nineHandedWalk);
    expect(_enabled(tester, 'Preflop'), isTrue);
    for (final street in ['Flop', 'Turn', 'River', 'Showdown']) {
      expect(_enabled(tester, street), isFalse, reason: street);
    }

    await pumpReplay(tester, ReplayFixtures.headsUp);
    expect(_enabled(tester, 'Flop'), isTrue);
    for (final street in ['Turn', 'River', 'Showdown']) {
      expect(_enabled(tester, street), isFalse, reason: street);
    }

    await pumpReplay(tester, ReplayFixtures.sidePotAllIn);
    for (final street in ['Preflop', 'Flop', 'Turn', 'River', 'Showdown']) {
      expect(_enabled(tester, street), isTrue, reason: street);
    }
    expect(
      tester.getSemantics(_control('Preflop')),
      isSemantics(isButton: true, isSelected: true, isEnabled: true),
    );
    expect(
      tester.getSemantics(_control('1×')),
      isSemantics(isSelected: true, isInMutuallyExclusiveGroup: true),
    );
    handle.dispose();
  });

  testWidgets('keyboard shortcuts step, jump, and play', (tester) async {
    final cubit = await pumpReplay(tester, ReplayFixtures.sixMaxRiver);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(cubit.state.index, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(cubit.state.index, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(cubit.state.atEnd, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(cubit.state.index, 0);

    final streets = {
      LogicalKeyboardKey.digit2: Street.flop,
      LogicalKeyboardKey.digit3: Street.turn,
      LogicalKeyboardKey.digit4: Street.river,
      LogicalKeyboardKey.digit5: Street.showdown,
      LogicalKeyboardKey.digit1: Street.preflop,
    };
    for (final MapEntry(key: key, value: street) in streets.entries) {
      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(
        cubit.state.index,
        cubit.state.firstStepOf(street),
        reason: '$street',
      );
    }

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(cubit.state.playing, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(cubit.state.index, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(cubit.state.playing, isFalse);
  });

  testWidgets('Space activates a focused control instead of playing', (
    tester,
  ) async {
    final cubit = await pumpReplay(tester, ReplayFixtures.sixMaxRiver);
    await _tapLabel(tester, 'Amounts in big blinds');
    expect(cubit.state.amountsInBigBlinds, isTrue);
    // Move focus to the switch itself, then press Space.
    Focus.of(
      tester.element(
        find
            .descendant(
              of: find.byType(ShadSwitch).first,
              matching: find.byType(Container),
            )
            .first,
      ),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(cubit.state.amountsInBigBlinds, isFalse);
    expect(cubit.state.playing, isFalse);
  });

  testWidgets('playback follows the speed and stops at the last step', (
    tester,
  ) async {
    final cubit = await pumpReplay(tester, ReplayFixtures.headsUp);
    await _tapLabel(tester, '2×');
    expect(cubit.state.speed, 2);
    await _tapLabel(tester, 'Play');
    expect(cubit.state.playing, isTrue);
    expect(find.bySemanticsLabel('Pause'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(cubit.state.index, 1);
    await tester.pump(const Duration(seconds: 10));
    expect(cubit.state.atEnd, isTrue);
    expect(cubit.state.playing, isFalse);
    expect(find.bySemanticsLabel('Play'), findsOneWidget);

    // Playing again from the end starts over.
    await _tapLabel(tester, 'Play');
    expect(cubit.state.index, 0);
    await _tapLabel(tester, 'Pause');
    expect(cubit.state.playing, isFalse);
  });

  testWidgets("hiding opponents' cards reveals them at showdown", (
    tester,
  ) async {
    final cubit = await pumpReplay(tester, ReplayFixtures.sixMaxRiver);
    expect(cubit.state.focusSeat, 2, reason: 'first seat with known cards');
    expect(_faceUp(tester, 6), [true, true]);

    await _tapLabel(tester, 'Hide opponents’ cards until showdown');
    expect(_faceUp(tester, 2), [true, true], reason: 'the focus seat');
    expect(_faceUp(tester, 6), [false, false]);
    expect(_faceUp(tester, 1), [false, false], reason: 'unreported');

    cubit.jumpTo(cubit.state.firstStepOf(Street.river)!);
    await tester.pump();
    expect(_faceUp(tester, 6), [false, false]);

    await _tapLabel(tester, 'Showdown');
    expect(_faceUp(tester, 6), [true, true]);
    await _tapLabel(tester, 'Last step');
    expect(_faceUp(tester, 6), [true, true], reason: 'awards follow showdown');
  });

  testWidgets('the action log highlights and jumps to steps', (tester) async {
    final handle = tester.ensureSemantics();
    final cubit = await pumpReplay(tester, ReplayFixtures.sixMaxRiver);
    await tester.tap(
      find.descendant(
        of: find.byType(ActionLog),
        matching: find.text(r'Hero raises to $3.00'),
      ),
    );
    await tester.pump();
    expect(cubit.state.index, 4);
    expect(
      tester.getSemantics(
        find.descendant(
          of: find.byType(ActionLog),
          matching: find.bySemanticsLabel(r'Hero raises to $3.00'),
        ),
      ),
      isSemantics(isSelected: true, isButton: true),
    );
    expect(find.text('Flop'), findsWidgets, reason: 'street heading');

    // The current row scrolls into view as the replay advances.
    cubit.last();
    await tester.pumpAndSettle();
    final row = find.descendant(
      of: find.byType(ActionLog),
      matching: find.text(r'Bianca wins $70.50 from the main pot'),
    );
    expect(row, findsOneWidget);
    final log = tester.getRect(find.byType(Scrollable).last);
    expect(log.contains(tester.getCenter(row)), isTrue);
    handle.dispose();
  });

  testWidgets('amounts switch to big blinds', (tester) async {
    final cubit = await pumpReplay(tester, ReplayFixtures.sidePotAllIn);
    cubit.jumpTo(3);
    await _tapLabel(tester, 'Amounts in big blinds');
    expect(_announcement(tester), 'Cy raises to 150 BB, all-in');
    expect(find.text('Raise to 150 BB'), findsOneWidget);
    expect(find.text('Cy raises to 150 BB, all-in'), findsWidgets);
  });

  testWidgets('compact windows open the action log as a sheet', (tester) async {
    final cubit = await pumpReplay(
      tester,
      ReplayFixtures.sidePotAllIn,
      size: const Size(360, 800),
    );
    expect(find.text(r'Ada posts small blind $0.01'), findsNothing);
    await _tapLabel(tester, 'Show actions');
    await tester.pumpAndSettle();
    await tester.tap(find.text(r'Ada posts small blind $0.01'));
    await tester.pumpAndSettle();
    expect(cubit.state.index, 1);
    expect(
      find.text(r'Bo posts big blind $0.02'),
      findsNothing,
      reason: 'the sheet closes after choosing a step',
    );
  });

  testWidgets('meets tap-target and contrast guidelines', (tester) async {
    for (final brightness in Brightness.values) {
      final cubit = await pumpReplay(
        tester,
        ReplayFixtures.sixMaxRiver,
        brightness: brightness,
      );
      cubit.jumpTo(12);
      await tester.pump();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }
  });
}
