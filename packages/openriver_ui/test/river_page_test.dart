import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openriver_ui/openriver_ui.dart';

import 'support/harness.dart';

const _bodyKey = Key('body');
const _actionKey = Key('action');

RiverPageHeader _header({String? description = 'Everything you imported.'}) =>
    RiverPageHeader(
      title: 'Hands',
      description: description,
      actions: [
        RiverButton(key: _actionKey, label: 'Import', onPressed: () {}),
      ],
    );

/// Records the content class seen by the page body.
RiverWindowClass? _bodyClass;

Widget _body({double height = 200}) => Builder(
  key: _bodyKey,
  builder: (context) {
    _bodyClass = context.app.responsive.content;
    return SizedBox(height: height);
  },
);

void main() {
  setUp(() => _bodyClass = null);

  group('padding and width', () {
    for (final (size, padding) in [
      (const Size(390, 844), 24.0),
      (const Size(768, 1024), 48.0),
      (const Size(1280, 800), 48.0),
    ]) {
      testWidgets('uses $padding outer padding at ${size.width}', (
        tester,
      ) async {
        await pumpRiver(
          tester,
          RiverPage(body: _body()),
          surface: RiverTestSurface(size: size),
        );

        final rect = tester.getRect(find.byKey(_bodyKey));
        expect(rect.top, padding);
        expect(rect.width, math.min(960, size.width - padding * 2));
      });
    }

    for (final (width, maxWidth) in [
      (RiverPageWidth.standard, 960.0),
      (RiverPageWidth.wide, 1280.0),
      (RiverPageWidth.full, 1920.0 - 96),
    ]) {
      testWidgets('${width.name} limits content to $maxWidth', (tester) async {
        await pumpRiver(
          tester,
          RiverPage(width: width, body: _body()),
          surface: const RiverTestSurface(size: Size(1920, 1080)),
        );

        final rect = tester.getRect(find.byKey(_bodyKey));
        expect(rect.width, maxWidth);
        expect(rect.center.dx, 960, reason: 'content is centered');
      });
    }

    testWidgets('respects safe-area insets', (tester) async {
      await pumpRiver(
        tester,
        RiverPage(body: _body()),
        surface: const RiverTestSurface(
          size: Size(390, 844),
          padding: EdgeInsets.only(top: 47, bottom: 34),
        ),
      );

      expect(tester.getRect(find.byKey(_bodyKey)).top, 47 + 24);
    });

    testWidgets('publishes the class of the padded content area', (
      tester,
    ) async {
      // 1000 wide window, 48 padding each side: 904 is expanded.
      await pumpRiver(
        tester,
        RiverPage(width: RiverPageWidth.full, body: _body()),
        surface: const RiverTestSurface(size: Size(1000, 800)),
      );
      expect(_bodyClass, RiverWindowClass.expanded);

      // 640 wide window, 48 padding each side: 544 is compact.
      await pumpRiver(
        tester,
        RiverPage(body: _body()),
        surface: const RiverTestSurface(size: Size(640, 800)),
      );
      expect(_bodyClass, RiverWindowClass.compact);
    });
  });

  group('header', () {
    testWidgets('marks the title as a semantic header', (tester) async {
      await pumpRiver(tester, RiverPage(header: _header(), body: _body()));

      expect(
        tester.getSemantics(find.text('Hands')),
        isSemantics(label: 'Hands', isHeader: true),
      );
    });

    testWidgets('places actions beside the title on wide pages', (
      tester,
    ) async {
      await pumpRiver(tester, RiverPage(header: _header(), body: _body()));

      final title = tester.getRect(find.text('Hands'));
      final action = tester.getRect(find.byKey(_actionKey));
      expect(action.top, title.top);
      expect(action.left, greaterThan(title.right));
    });

    testWidgets('places actions beside the title in right-to-left', (
      tester,
    ) async {
      await pumpRiver(
        tester,
        RiverPage(header: _header(), body: _body()),
        surface: const RiverTestSurface(textDirection: TextDirection.rtl),
      );

      final title = tester.getRect(find.text('Hands'));
      final action = tester.getRect(find.byKey(_actionKey));
      expect(action.right, lessThan(title.left));
    });

    testWidgets('places actions below the title on compact pages', (
      tester,
    ) async {
      await pumpRiver(
        tester,
        RiverPage(header: _header(), body: _body()),
        surface: const RiverTestSurface(size: Size(390, 844)),
      );

      final description = tester.getRect(find.text('Everything you imported.'));
      final action = tester.getRect(find.byKey(_actionKey));
      expect(action.top, greaterThan(description.bottom));
    });
  });

  group('scrolling', () {
    testWidgets('scrollable pages use the primary scroll controller', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpRiver(
        tester,
        PrimaryScrollController(
          controller: controller,
          child: RiverPage(header: _header(), body: _body(height: 3000)),
        ),
        surface: const RiverTestSurface(size: Size(390, 844)),
      );

      expect(controller.hasClients, isTrue);
      controller.jumpTo(1000);
      await tester.pump();
      expect(tester.getRect(find.text('Hands')).top, lessThan(0));
    });

    testWidgets('fixed pages give the body the remaining height', (
      tester,
    ) async {
      late BoxConstraints bodyConstraints;
      await pumpRiver(
        tester,
        RiverPage(
          scrollable: false,
          header: _header(),
          body: LayoutBuilder(
            builder: (context, constraints) {
              bodyConstraints = constraints;
              return const SizedBox.expand();
            },
          ),
        ),
      );

      expect(bodyConstraints.hasBoundedHeight, isTrue);
      expect(bodyConstraints.maxHeight, lessThan(800 - 96));
      expect(bodyConstraints.maxHeight, greaterThan(400));
    });
  });

  testAcross(
    'lays out a header and body',
    () => RiverPage(
      header: RiverPageHeader(
        title: 'A long page title that needs to wrap on narrow screens',
        description:
            'A description long enough to wrap across several lines when the '
            'window is narrow or the text is large.',
        actions: [
          RiverButton(label: 'Import hand history', onPressed: () {}),
          RiverButton(
            label: 'Export',
            variant: RiverButtonVariant.outline,
            onPressed: () {},
          ),
        ],
      ),
      body: _body(height: 1200),
    ),
    verify: (tester, surface) async {
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    },
  );
}
