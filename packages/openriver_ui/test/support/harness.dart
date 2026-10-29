import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openriver_ui/openriver_ui.dart';

/// Window sizes every responsive widget must handle.
const matrixSizes = [
  Size(320, 568), // small phone
  Size(390, 844), // phone
  Size(844, 390), // phone, landscape
  Size(768, 1024), // tablet, portrait
  Size(1024, 768), // tablet, landscape
  Size(1280, 800), // laptop
  Size(1920, 1080), // desktop
];

const matrixTextScales = [1.0, 1.5, 2.0];

/// One combination of window, text, theme, and direction.
final class RiverTestSurface {
  const RiverTestSurface({
    this.size = const Size(1280, 800),
    this.textScale = 1,
    this.brightness = Brightness.light,
    this.textDirection = TextDirection.ltr,
    this.padding = EdgeInsets.zero,
  });

  final Size size;
  final double textScale;
  final Brightness brightness;
  final TextDirection textDirection;

  /// Simulated system insets, such as a notch or home indicator.
  final EdgeInsets padding;

  @override
  String toString() =>
      '${size.width.toInt()}×${size.height.toInt()} '
      '@${textScale}x ${brightness.name} ${textDirection.name}';
}

/// Every combination of [matrixSizes], [matrixTextScales], both themes, and
/// both text directions.
Iterable<RiverTestSurface> get matrixSurfaces sync* {
  for (final size in matrixSizes) {
    for (final textScale in matrixTextScales) {
      for (final brightness in Brightness.values) {
        for (final textDirection in TextDirection.values) {
          yield RiverTestSurface(
            size: size,
            textScale: textScale,
            brightness: brightness,
            textDirection: textDirection,
          );
        }
      }
    }
  }
}

/// Pumps [child] in a themed app configured as [surface].
Future<void> pumpRiver(
  WidgetTester tester,
  Widget child, {
  RiverTestSurface surface = const RiverTestSurface(),
}) async {
  tester.view.physicalSize = surface.size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(
    left: surface.padding.left,
    top: surface.padding.top,
    right: surface.padding.right,
    bottom: surface.padding.bottom,
  );
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ShadApp(
      theme: RiverThemes.light,
      darkTheme: RiverThemes.dark,
      themeMode: surface.brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      localizationsDelegates: const [RiverLocalizations.delegate],
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(surface.textScale)),
        child: Directionality(
          textDirection: surface.textDirection,
          child: RiverLayoutScope(child: app!),
        ),
      ),
      home: child,
    ),
  );
  // ShadApp starts zero-duration flutter_animate timers while mounting. Pump
  // a fixed duration rather than settling, so indeterminate progress
  // indicators do not time out.
  await tester.pump(const Duration(milliseconds: 500));
}

/// Declares one widget test per surface in [surfaces], defaulting to the full
/// matrix. Each test fails on any framework exception, including overflow.
void testAcross(
  String description,
  Widget Function() build, {
  Iterable<RiverTestSurface>? surfaces,
  Future<void> Function(WidgetTester tester, RiverTestSurface surface)? verify,
}) {
  for (final surface in surfaces ?? matrixSurfaces) {
    testWidgets('$description [$surface]', (tester) async {
      await pumpRiver(tester, build(), surface: surface);
      expect(tester.takeException(), isNull);
      await verify?.call(tester, surface);
    });
  }
}
