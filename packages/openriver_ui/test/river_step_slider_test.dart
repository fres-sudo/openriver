import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openriver_ui/openriver_ui.dart';

import 'support/harness.dart';

/// Hosts a slider whose value follows its own callback.
class _Host extends StatefulWidget {
  const _Host({this.initial = 0, this.enabled = true});
  final int initial;
  final bool enabled;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late var value = widget.initial;
  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 220,
      child: RiverStepSlider(
        value: value,
        max: 10,
        label: 'Step',
        valueLabel: (v) => 'Step ${v + 1} of 11',
        onChanged: widget.enabled ? (v) => setState(() => value = v) : null,
      ),
    ),
  );
}

int _value(WidgetTester tester) =>
    tester.widget<RiverStepSlider>(find.byType(RiverStepSlider)).value;

void main() {
  testWidgets('taps and drags choose the nearest step', (tester) async {
    await pumpRiver(tester, const _Host());
    final rect = tester.getRect(find.byType(RiverStepSlider));
    expect(rect.height, 48);

    await tester.tapAt(rect.centerRight - const Offset(2, 0));
    await tester.pump();
    expect(_value(tester), 10);
    await tester.tapAt(rect.center);
    await tester.pump();
    expect(_value(tester), 5);
    await tester.dragFrom(rect.center, Offset(-rect.width, 0));
    await tester.pump();
    expect(_value(tester), 0);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  testWidgets('arrow keys, Home, and End move while focused', (tester) async {
    await pumpRiver(tester, const _Host(initial: 4));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_value(tester), 5);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_value(tester), 4);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(_value(tester), 10);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(_value(tester), 0);
  });

  testWidgets('right-to-left reverses direction', (tester) async {
    await pumpRiver(
      tester,
      const _Host(initial: 5),
      surface: const RiverTestSurface(textDirection: TextDirection.rtl),
    );
    final rect = tester.getRect(find.byType(RiverStepSlider));
    await tester.tapAt(rect.centerLeft + const Offset(2, 0));
    await tester.pump();
    expect(_value(tester), 10);
  });

  testWidgets('is a labeled slider with spoken values', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpRiver(tester, const _Host(initial: 3));
    final node = find.bySemanticsLabel('Step');
    expect(
      tester.getSemantics(node),
      isSemantics(
        isSlider: true,
        isEnabled: true,
        value: 'Step 4 of 11',
        increasedValue: 'Step 5 of 11',
        decreasedValue: 'Step 3 of 11',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );
    tester.semantics.performAction(
      find.semantics.byLabel('Step'),
      SemanticsAction.increase,
    );
    await tester.pump();
    expect(_value(tester), 4);
    handle.dispose();
  });

  testWidgets('ignores input without onChanged', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpRiver(tester, const _Host(initial: 2, enabled: false));
    await tester.tap(find.byType(RiverStepSlider));
    await tester.pump();
    expect(_value(tester), 2);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Step')),
      isSemantics(isSlider: true, isEnabled: false, hasEnabledState: true),
    );
    handle.dispose();
  });
}
