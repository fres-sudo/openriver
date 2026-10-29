import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openriver_ui/openriver_ui.dart';

import 'support/harness.dart';

const _destinations = [
  RiverDestination(label: 'Library', icon: LucideIcons.library),
  RiverDestination(label: 'Hands', icon: LucideIcons.list, badgeCount: 3),
  RiverDestination(label: 'Settings', icon: LucideIcons.settings),
];

/// Calls made by the shell, recorded by [_ShellApp].
final _reselected = <int>[];
final _collapsedChanges = <bool>[];
var _actionPresses = 0;

/// A shell whose body behaves like go_router's indexed stack: every visited
/// branch stays mounted, and hidden branches have tickers disabled.
class _ShellApp extends StatefulWidget {
  const _ShellApp({
    this.destinations = _destinations,
    this.action = true,
    this.busy = false,
    this.initiallyCollapsed = false,
  });

  final List<RiverDestination> destinations;
  final bool action;
  final bool busy;
  final bool initiallyCollapsed;

  @override
  State<_ShellApp> createState() => _ShellAppState();
}

class _ShellAppState extends State<_ShellApp> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => RiverShell(
    destinations: widget.destinations,
    selectedIndex: _index,
    onDestinationSelected: (index) => setState(() => _index = index),
    onDestinationReselected: _reselected.add,
    initiallyCollapsed: widget.initiallyCollapsed,
    onCollapsedChanged: _collapsedChanges.add,
    brand: const Text('OpenRiver'),
    primaryAction: widget.action
        ? RiverShellAction(
            label: 'Import',
            icon: LucideIcons.upload,
            busy: widget.busy,
            onPressed: () => _actionPresses++,
          )
        : null,
    body: IndexedStack(
      index: _index,
      children: [
        for (final (index, destination) in widget.destinations.indexed)
          TickerMode(
            enabled: index == _index,
            child: _Page(key: ValueKey(index), title: destination.label),
          ),
      ],
    ),
  );
}

class _Page extends StatelessWidget {
  const _Page({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => RiverPage(
    header: RiverPageHeader(title: '$title page'),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Counter(key: ValueKey('counter $title')),
        const SizedBox(height: 1600),
      ],
    ),
  );
}

/// Stateful content used to detect a remounted body.
class _Counter extends StatefulWidget {
  const _Counter({super.key});

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) => RiverButton(
    label: 'Count $count',
    onPressed: () => setState(() => count++),
  );
}

RiverShellScope _scope(WidgetTester tester) => tester
    .element(find.byType(RiverPage).first)
    .dependOnInheritedWidgetOfExactType<RiverShellScope>()!;

RiverNavigationForm _form(WidgetTester tester) => _scope(tester).form;

/// The destination item with [label], by its semantics.
Finder _item(String label) => find.bySemanticsLabel(RegExp('^$label(,|\$)'));

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pump();
}

void main() {
  setUp(() {
    _reselected.clear();
    _collapsedChanges.clear();
    _actionPresses = 0;
  });

  group('form', () {
    test('follows the navigation class and height', () {
      RiverNavigationForm form(
        RiverWindowClass c, {
        double height = 800,
        bool collapsed = false,
      }) => RiverShell.formFor(
        navigationClass: c,
        height: height,
        collapsed: collapsed,
      );

      expect(form(RiverWindowClass.compact), RiverNavigationForm.bottomBar);
      expect(
        form(RiverWindowClass.compact, collapsed: true),
        RiverNavigationForm.bottomBar,
      );
      expect(form(RiverWindowClass.medium), RiverNavigationForm.rail);
      for (final c in [
        RiverWindowClass.expanded,
        RiverWindowClass.large,
        RiverWindowClass.extraLarge,
      ]) {
        expect(form(c), RiverNavigationForm.sidebar);
        expect(form(c, collapsed: true), RiverNavigationForm.rail);
        expect(form(c, height: 479), RiverNavigationForm.rail);
      }
    });

    for (final (surface, expected) in [
      (const RiverTestSurface(size: Size(390, 844)), 'bottomBar'),
      (const RiverTestSurface(size: Size(768, 1024)), 'rail'),
      (const RiverTestSurface(size: Size(1280, 800)), 'sidebar'),
      (const RiverTestSurface(size: Size(844, 390)), 'rail'),
      (
        const RiverTestSurface(size: Size(700, 1000), textScale: 2),
        'bottomBar',
      ),
      (const RiverTestSurface(size: Size(1300, 800), textScale: 2), 'rail'),
    ]) {
      testWidgets('is $expected at $surface', (tester) async {
        await pumpRiver(tester, const _ShellApp(), surface: surface);
        expect(_form(tester).name, expected);
      });
    }

    testWidgets('a bottom bar holds at most five destinations', (tester) async {
      await pumpRiver(
        tester,
        _ShellApp(
          destinations: [
            for (var i = 0; i < 6; i++)
              RiverDestination(label: '$i', icon: LucideIcons.list),
          ],
        ),
        surface: const RiverTestSurface(size: Size(390, 844)),
      );
      expect(tester.takeException(), isAssertionError);
    });

    test('rejects an out-of-range selection', () {
      expect(
        () => RiverShell(
          destinations: _destinations,
          selectedIndex: 3,
          onDestinationSelected: (_) {},
          body: const SizedBox(),
        ),
        throwsAssertionError,
      );
    });
  });

  group('layout', () {
    testWidgets('body keeps its state across every form', (tester) async {
      await pumpRiver(
        tester,
        const _ShellApp(),
        surface: const RiverTestSurface(size: Size(390, 844)),
      );
      await tester.tap(find.text('Count 0'));
      await tester.pump();
      final state = tester.state(find.byType(_Counter));

      for (final size in const [
        Size(768, 1024),
        Size(1280, 800),
        Size(844, 390),
        Size(390, 844),
      ]) {
        await _resize(tester, size);
        expect(find.text('Count 1'), findsOneWidget, reason: '$size');
        expect(tester.state(find.byType(_Counter)), same(state));
      }
    });

    testWidgets('body keeps its state when the sidebar collapses', (
      tester,
    ) async {
      await pumpRiver(tester, const _ShellApp());
      await tester.tap(find.text('Count 0'));
      await tester.pump();
      final state = tester.state(find.byType(_Counter));

      await tester.tap(find.bySemanticsLabel('Collapse sidebar'));
      await tester.pump();

      expect(_form(tester), RiverNavigationForm.rail);
      expect(tester.state(find.byType(_Counter)), same(state));
    });

    testWidgets('sidebar is on the start edge', (tester) async {
      for (final direction in TextDirection.values) {
        await pumpRiver(
          tester,
          const _ShellApp(),
          surface: RiverTestSurface(textDirection: direction),
        );
        final library = tester.getRect(_item('Library'));
        final page = tester.getRect(find.text('Library page'));
        if (direction == TextDirection.ltr) {
          expect(library.right, lessThan(page.left));
        } else {
          expect(library.left, greaterThan(page.right));
        }
      }
    });

    testWidgets('bottom bar is below the body', (tester) async {
      await pumpRiver(
        tester,
        const _ShellApp(),
        surface: const RiverTestSurface(size: Size(390, 844)),
      );

      final bar = tester.getRect(_item('Library'));
      expect(bar.bottom, lessThanOrEqualTo(844));
      expect(bar.top, greaterThan(844 - 120));
      final page = tester.getRect(find.byType(RiverPage).first);
      expect(page.bottom, lessThanOrEqualTo(bar.top));
    });

    testWidgets('bottom bar consumes the bottom inset', (tester) async {
      await pumpRiver(
        tester,
        const _ShellApp(),
        surface: const RiverTestSurface(
          size: Size(390, 844),
          padding: EdgeInsets.only(top: 47, bottom: 34),
        ),
      );

      final pageContext = tester.element(find.byType(RiverPage).first);
      expect(MediaQuery.paddingOf(pageContext).bottom, 0);
      expect(MediaQuery.paddingOf(pageContext).top, 47);
      expect(tester.getRect(_item('Library')).bottom, lessThanOrEqualTo(810));
    });

    testWidgets('rail consumes the start inset', (tester) async {
      await pumpRiver(
        tester,
        const _ShellApp(),
        surface: const RiverTestSurface(
          size: Size(844, 390),
          padding: EdgeInsets.only(left: 47, bottom: 21),
        ),
      );

      final pageContext = tester.element(find.byType(RiverPage).first);
      expect(MediaQuery.paddingOf(pageContext).left, 0);
      expect(MediaQuery.paddingOf(pageContext).bottom, 21);
      expect(tester.getRect(_item('Library')).left, greaterThanOrEqualTo(47));
    });

    testWidgets('hides the bottom bar while the keyboard is visible', (
      tester,
    ) async {
      await pumpRiver(
        tester,
        const _ShellApp(),
        surface: const RiverTestSurface(size: Size(390, 844)),
      );
      final state = tester.state(find.byType(_Counter));

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      expect(_item('Library'), findsNothing);
      expect(tester.state(find.byType(_Counter)), same(state));

      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();
      expect(_item('Library'), findsOneWidget);
    });

    testWidgets('rail grows with the text scale', (tester) async {
      Future<double> railWidth(double textScale) async {
        await pumpRiver(
          tester,
          const _ShellApp(),
          surface: RiverTestSurface(
            size: const Size(1500, 900),
            textScale: textScale,
          ),
        );
        expect(_form(tester), RiverNavigationForm.rail);
        return tester.getTopLeft(find.byType(RiverPage).first).dx;
      }

      // 1500 / 2 = 750, a medium navigation class.
      expect(await railWidth(2), 160);
    });

    testWidgets('page content sees the class of the body, not the window', (
      tester,
    ) async {
      // 850 wide window, minus a 256 sidebar, leaves a compact body.
      await pumpRiver(
        tester,
        const _ShellApp(),
        surface: const RiverTestSurface(size: Size(850, 800)),
      );
      final context = tester.element(find.byType(RiverPage).first);
      expect(context.app.responsive.window, RiverWindowClass.expanded);
      expect(context.app.responsive.content, RiverWindowClass.compact);
    });
  });

  group('selection', () {
    for (final size in const [
      Size(390, 844),
      Size(768, 1024),
      Size(1280, 800),
    ]) {
      testWidgets('tapping selects and reselects at $size', (tester) async {
        await pumpRiver(
          tester,
          const _ShellApp(),
          surface: RiverTestSurface(size: size),
        );

        await tester.tap(_item('Hands'));
        await tester.pump();
        expect(find.text('Hands page'), findsOneWidget);
        expect(_reselected, isEmpty);

        await tester.tap(_item('Hands'));
        await tester.pump();
        expect(_reselected, [1]);
      });
    }

    testWidgets('each destination keeps its own state', (tester) async {
      await pumpRiver(tester, const _ShellApp());
      await tester.tap(find.text('Count 0'));
      await tester.pump();

      await tester.tap(_item('Hands'));
      await tester.pump();
      expect(find.text('Count 0'), findsOneWidget);

      await tester.tap(_item('Library'));
      await tester.pump();
      expect(find.text('Count 1'), findsOneWidget);
    });

    testWidgets(
      'selects destinations with ⌘ or Ctrl and a digit',
      (tester) async {
        await pumpRiver(tester, const _ShellApp());
        await tester.pump();
        final apple =
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.iOS;
        final modifier = apple
            ? LogicalKeyboardKey.metaLeft
            : LogicalKeyboardKey.controlLeft;

        Future<void> chord(LogicalKeyboardKey key) async {
          await tester.sendKeyDownEvent(modifier);
          await tester.sendKeyEvent(key);
          await tester.sendKeyUpEvent(modifier);
          await tester.pump();
        }

        await chord(LogicalKeyboardKey.digit3);
        expect(find.text('Settings page'), findsOneWidget);
        await chord(LogicalKeyboardKey.digit3);
        expect(_reselected, [2]);
        await chord(LogicalKeyboardKey.digit1);
        expect(find.text('Library page'), findsOneWidget);
        // No fourth destination; nothing happens.
        await chord(LogicalKeyboardKey.digit4);
        expect(find.text('Library page'), findsOneWidget);
      },
      variant: TargetPlatformVariant.desktop(),
    );

    testWidgets('removes its shortcuts when disposed', (tester) async {
      await pumpRiver(tester, const _ShellApp());
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      // A second shell registering the same keys would assert if the first
      // had left its entry behind.
      await pumpRiver(tester, const _ShellApp());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('keyboard and focus', () {
    testWidgets('Enter activates a focused destination', (tester) async {
      await pumpRiver(tester, const _ShellApp());

      // Tab order: sidebar action, then destinations.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.text('Hands page'), findsOneWidget);
    });

    testWidgets('arrow keys move between rail destinations', (tester) async {
      await pumpRiver(
        tester,
        const _ShellApp(action: false),
        surface: const RiverTestSurface(size: Size(768, 1024)),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(find.text('Hands page'), findsOneWidget);
    });

    testWidgets('moves focus to the new page title after selection', (
      tester,
    ) async {
      await pumpRiver(tester, const _ShellApp());
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        isNot('RiverPageHeader title'),
        reason: 'launch does not move focus',
      );

      for (final label in ['Hands', 'Library']) {
        await tester.tap(_item(label));
        await tester.pump();
        await tester.pump();
        final focus = FocusManager.instance.primaryFocus!;
        expect(focus.debugLabel, 'RiverPageHeader title');
        expect(
          find.descendant(
            of: find.byWidget(focus.context!.widget),
            matching: find.text('$label page'),
          ),
          findsOneWidget,
        );
      }
    });
  });

  group('semantics', () {
    testWidgets('announces destinations as a selectable group', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRiver(tester, const _ShellApp());

      expect(
        tester.getSemantics(_item('Library')),
        matchesSemantics(
          label: 'Library',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      expect(
        tester.getSemantics(_item('Hands')),
        isSemantics(
          label: 'Hands, 3 new',
          hasSelectedState: true,
          isSelected: false,
        ),
      );
      expect(find.bySemanticsLabel('Main navigation'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('caps the visible badge count', (tester) async {
      await pumpRiver(
        tester,
        const _ShellApp(
          destinations: [
            RiverDestination(label: 'Library', icon: LucideIcons.library),
            RiverDestination(
              label: 'Hands',
              icon: LucideIcons.list,
              badgeCount: 120,
            ),
          ],
        ),
      );
      expect(find.text('99+'), findsOneWidget);
      expect(_item('Hands'), findsOneWidget);
    });
  });

  group('sidebar toggle', () {
    testWidgets('collapses to a rail and expands again', (tester) async {
      await pumpRiver(tester, const _ShellApp());

      await tester.tap(find.bySemanticsLabel('Collapse sidebar'));
      await tester.pump();
      expect(_form(tester), RiverNavigationForm.rail);

      await tester.tap(find.bySemanticsLabel('Expand sidebar'));
      await tester.pump();
      expect(_form(tester), RiverNavigationForm.sidebar);
      expect(_collapsedChanges, [true, false]);
    });

    testWidgets('can start collapsed', (tester) async {
      await pumpRiver(tester, const _ShellApp(initiallyCollapsed: true));
      expect(_form(tester), RiverNavigationForm.rail);
      expect(find.bySemanticsLabel('Expand sidebar'), findsOneWidget);
    });

    testWidgets('is absent where the sidebar cannot show', (tester) async {
      await pumpRiver(
        tester,
        const _ShellApp(),
        surface: const RiverTestSurface(size: Size(768, 1024)),
      );
      expect(find.bySemanticsLabel('Expand sidebar'), findsNothing);
    });
  });

  group('primary action', () {
    for (final (size, form) in const [
      (Size(1280, 800), RiverNavigationForm.sidebar),
      (Size(768, 1024), RiverNavigationForm.rail),
      (Size(390, 844), RiverNavigationForm.bottomBar),
    ]) {
      testWidgets('is reachable in the ${form.name}', (tester) async {
        await pumpRiver(
          tester,
          const _ShellApp(),
          surface: RiverTestSurface(size: size),
        );

        final action = find.bySemanticsLabel('Import');
        expect(action, findsOneWidget);
        await tester.tap(action);
        expect(_actionPresses, 1);
      });

      testWidgets('is disabled while busy in the ${form.name}', (tester) async {
        await pumpRiver(
          tester,
          const _ShellApp(busy: true),
          surface: RiverTestSurface(size: size),
        );

        await tester.tap(find.bySemanticsLabel('Import'), warnIfMissed: false);
        expect(_actionPresses, 0);
        expect(
          tester.getSemantics(find.bySemanticsLabel('Import')),
          isSemantics(isEnabled: false),
        );
      });
    }

    testWidgets('page headers can opt out of the shell action', (tester) async {
      await pumpRiver(
        tester,
        RiverShell(
          destinations: _destinations,
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          primaryAction: RiverShellAction(
            label: 'Import',
            icon: LucideIcons.upload,
            onPressed: () {},
          ),
          body: const RiverPage(
            header: RiverPageHeader(title: 'Library', showShellAction: false),
            body: SizedBox(),
          ),
        ),
        surface: const RiverTestSurface(size: Size(390, 844)),
      );
      expect(find.bySemanticsLabel('Import'), findsNothing);
    });
  });

  testAcross(
    'lays out the shell',
    () => const _ShellApp(),
    verify: (tester, surface) async {
      // Navigation never crowds out the body.
      final page = tester.getSize(find.byType(RiverPage).first);
      expect(page.width, greaterThanOrEqualTo(surface.size.width / 2));
      expect(page.height, greaterThanOrEqualTo(surface.size.height / 2));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    },
  );
}
