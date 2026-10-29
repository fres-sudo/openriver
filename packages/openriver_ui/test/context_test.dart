import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openriver_ui/openriver_ui.dart';

/// Pumps [builder] inside a themed app of [size] and returns its context.
Future<BuildContext> _pumpApp(
  WidgetTester tester, {
  Size size = const Size(1280, 800),
  ThemeMode themeMode = ThemeMode.light,
  Iterable<LocalizationsDelegate<dynamic>>? delegates,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  late BuildContext captured;
  await tester.pumpWidget(
    ShadApp(
      theme: RiverThemes.light,
      darkTheme: RiverThemes.dark,
      themeMode: themeMode,
      localizationsDelegates: delegates,
      builder: (context, child) => RiverLayoutScope(child: child!),
      home: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  // ShadApp starts flutter_animate timers while mounting.
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  group('context.app.theme', () {
    for (final (mode, expected) in [
      (ThemeMode.light, RiverThemes.light),
      (ThemeMode.dark, RiverThemes.dark),
    ]) {
      testWidgets('matches the Shad theme in ${mode.name} mode', (
        tester,
      ) async {
        final context = await _pumpApp(tester, themeMode: mode);
        final theme = context.app.theme;

        expect(theme.colors, ShadTheme.of(context).colorScheme);
        expect(theme.colors.primary, expected.colorScheme.primary);
        expect(theme.textTheme, ShadTheme.of(context).textTheme);
        expect(theme.brightness, expected.brightness);
        expect(theme.radius, ShadTheme.of(context).radius);
        expect(theme.data, ShadTheme.of(context));
      });
    }

    testWidgets('exposes design tokens', (tester) async {
      final theme = (await _pumpApp(tester)).app.theme;

      expect(theme.spacing.xl, 24);
      expect(theme.spacing.xxxl, 48);
      expect(theme.sizes.minTapTarget, 48);
      expect(theme.sizes.contentMaxWidth, 960);
      expect(theme.durations.normal, const Duration(milliseconds: 200));
    });
  });

  group('context.app.responsive', () {
    const cases = [
      (Size(320, 568), RiverWindowClass.compact, true, false, false),
      (Size(844, 390), RiverWindowClass.expanded, false, false, true),
      (Size(768, 1024), RiverWindowClass.medium, false, true, false),
      (Size(1280, 800), RiverWindowClass.large, false, false, true),
      (Size(1920, 1080), RiverWindowClass.extraLarge, false, false, true),
    ];
    for (final (size, windowClass, mobile, tablet, desktop) in cases) {
      testWidgets('${size.width}×${size.height} is ${windowClass.name}', (
        tester,
      ) async {
        final responsive = (await _pumpApp(tester, size: size)).app.responsive;

        expect(responsive.window, windowClass);
        expect(responsive.content, windowClass);
        expect(responsive.isMobile, mobile);
        expect(responsive.isTablet, tablet);
        expect(responsive.isDesktop, desktop);
      });
    }

    testWidgets('a getter registers a rebuild dependency', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final seen = <bool>[];

      await tester.pumpWidget(
        ShadApp(
          builder: (context, child) => RiverLayoutScope(child: child!),
          home: Builder(
            builder: (context) {
              seen.add(context.app.responsive.isMobile);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpAndSettle();

      expect(seen, [true, false]);
    });
  });

  testWidgets(
    'context.app.input reports touch platforms',
    (tester) async {
      final context = await _pumpApp(tester);
      final touch = switch (defaultTargetPlatform) {
        TargetPlatform.android ||
        TargetPlatform.iOS ||
        TargetPlatform.fuchsia => true,
        _ => false,
      };

      expect(context.app.input.isTouch, touch);
      expect(context.app.input.hasHover, !touch);
    },
    variant: TargetPlatformVariant.all(),
  );

  group('context.app.riverLocalizations', () {
    testWidgets('falls back to English without a delegate', (tester) async {
      final context = await _pumpApp(tester);

      expect(context.app.riverLocalizations, isA<RiverLocalizationsEn>());
      expect(context.app.riverLocalizations.badgeCount(1), '1 new');
      expect(context.app.riverLocalizations.badgeCount(3), '3 new');
    });

    testWidgets('uses a registered override', (tester) async {
      final context = await _pumpApp(
        tester,
        delegates: const [_GermanDelegate(), RiverLocalizations.delegate],
      );

      expect(context.app.riverLocalizations.close, 'Schließen');
    });
  });

  test('app extensions can reach the build context', () {
    final element = _FakeContext();
    expect(element.app.buildContext, same(element));
  });
}

class _FakeContext extends Fake implements BuildContext {}

class _GermanStrings extends RiverLocalizationsEn {
  const _GermanStrings();

  @override
  String get close => 'Schließen';
}

class _GermanDelegate extends LocalizationsDelegate<RiverLocalizations> {
  const _GermanDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<RiverLocalizations> load(Locale locale) =>
      SynchronousFuture(const _GermanStrings());

  @override
  bool shouldReload(_GermanDelegate old) => false;
}
