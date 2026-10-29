import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openriver_ui/openriver_ui.dart';

import 'support/harness.dart';

Widget _region(Widget child) => Align(
  alignment: Alignment.topCenter,
  child: Padding(padding: const EdgeInsets.all(24), child: child),
);

void main() {
  testWidgets('loading shows and speaks its label once', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpRiver(
      tester,
      _region(const RiverStateView.loading(label: 'Opening your library')),
    );

    expect(find.text('Opening your library'), findsOneWidget);
    expect(find.bySemanticsLabel('Opening your library'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('error announces its message and retries', (tester) async {
    var retries = 0;
    await pumpRiver(
      tester,
      _region(
        RiverStateView.error(
          title: 'Let’s try that again',
          message: 'Your library could not be opened.',
          retryLabel: 'Try again',
          onRetry: () => retries++,
        ),
      ),
    );

    expect(
      tester.getSemantics(find.text('Your library could not be opened.')),
      isSemantics(isLiveRegion: true),
    );
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  testWidgets('error without retry shows no action', (tester) async {
    await pumpRiver(
      tester,
      _region(
        const RiverStateView.error(title: 'Failed', message: 'Not available.'),
      ),
    );

    expect(find.byType(RiverButton), findsNothing);
  });

  test('error requires a retry label with a retry callback', () {
    expect(
      () => RiverStateView.error(title: 't', message: 'm', onRetry: () {}),
      throwsAssertionError,
    );
  });

  testWidgets('empty shows its action', (tester) async {
    var presses = 0;
    await pumpRiver(
      tester,
      _region(
        RiverStateView.empty(
          icon: LucideIcons.inbox,
          title: 'No hands yet',
          description: 'Import a hand history to get started.',
          action: RiverButton(label: 'Import', onPressed: () => presses++),
        ),
      ),
    );

    await tester.tap(find.text('Import'));
    expect(presses, 1);
  });

  testAcross(
    'lays out every state',
    () => RiverPage(
      body: Column(
        children: [
          const RiverStateView.loading(label: 'Importing hands…'),
          RiverStateView.empty(
            icon: LucideIcons.inbox,
            title: 'No hands yet',
            description: 'Import a hand history to get started.',
            action: RiverButton(label: 'Import', onPressed: () {}),
          ),
          RiverStateView.error(
            title: 'Let’s try that again',
            message: 'Your library could not be opened. Please try again.',
            retryLabel: 'Try again',
            onRetry: () {},
          ),
        ],
      ),
    ),
    surfaces: matrixSurfaces.where((s) => s.textDirection == TextDirection.ltr),
    verify: (tester, surface) async {
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    },
  );
}
