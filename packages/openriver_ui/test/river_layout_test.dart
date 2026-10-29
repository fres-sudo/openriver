import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openriver_ui/openriver_ui.dart';

/// Builds per aspect, and the last class each probe read.
final _builds = <RiverLayoutAspect, int>{};
final _seen = <RiverLayoutAspect, RiverWindowClass>{};

class _Probe extends StatelessWidget {
  const _Probe(this.aspect);

  final RiverLayoutAspect aspect;

  @override
  Widget build(BuildContext context) {
    _builds.update(aspect, (count) => count + 1, ifAbsent: () => 1);
    _seen[aspect] = RiverLayout.of(context, aspect);
    return const SizedBox.shrink();
  }
}

const _probes = Column(
  children: [
    _Probe(RiverLayoutAspect.window),
    _Probe(RiverLayoutAspect.navigation),
    _Probe(RiverLayoutAspect.content),
  ],
);

Widget _window(
  double width, {
  TextScaler textScaler = TextScaler.noScaling,
  required Widget child,
}) => MediaQuery(
  data: MediaQueryData(size: Size(width, 800), textScaler: textScaler),
  child: Directionality(textDirection: TextDirection.ltr, child: child),
);

void main() {
  setUp(() {
    _builds.clear();
    _seen.clear();
  });

  testWidgets('scope publishes classes from the window', (tester) async {
    await tester.pumpWidget(
      _window(
        700,
        textScaler: const TextScaler.linear(2),
        child: const RiverLayoutScope(child: _probes),
      ),
    );

    expect(_seen, {
      RiverLayoutAspect.window: RiverWindowClass.medium,
      RiverLayoutAspect.navigation: RiverWindowClass.compact,
      RiverLayoutAspect.content: RiverWindowClass.medium,
    });
  });

  testWidgets('resizing within a class rebuilds no dependents', (tester) async {
    await tester.pumpWidget(
      _window(900, child: const RiverLayoutScope(child: _probes)),
    );
    final initial = Map.of(_builds);

    for (final width in [950.0, 1000.0, 1199.0, 841.0]) {
      await tester.pumpWidget(
        _window(width, child: const RiverLayoutScope(child: _probes)),
      );
    }

    expect(_builds, initial);
  });

  testWidgets('only dependents of a changed aspect rebuild', (tester) async {
    await tester.pumpWidget(
      _window(1300, child: const RiverLayoutScope(child: _probes)),
    );
    final initial = Map.of(_builds);

    // Larger text changes the navigation class only.
    await tester.pumpWidget(
      _window(
        1300,
        textScaler: const TextScaler.linear(1.5),
        child: const RiverLayoutScope(child: _probes),
      ),
    );

    expect(_seen[RiverLayoutAspect.navigation], RiverWindowClass.expanded);
    expect(
      _builds[RiverLayoutAspect.navigation],
      initial[RiverLayoutAspect.navigation]! + 1,
    );
    expect(
      _builds[RiverLayoutAspect.window],
      initial[RiverLayoutAspect.window],
    );
    expect(
      _builds[RiverLayoutAspect.content],
      initial[RiverLayoutAspect.content],
    );
  });

  testWidgets('content scope uses its own width', (tester) async {
    await tester.pumpWidget(
      _window(
        1300,
        child: const RiverLayoutScope(
          child: Row(
            children: [
              SizedBox(width: 760),
              Expanded(child: RiverContentScope(child: _probes)),
            ],
          ),
        ),
      ),
    );

    expect(_seen[RiverLayoutAspect.window], RiverWindowClass.large);
    expect(_seen[RiverLayoutAspect.content], RiverWindowClass.compact);
  });

  testWidgets('content scope passes window changes through', (tester) async {
    Widget tree(TextScaler textScaler) => _window(
      1300,
      textScaler: textScaler,
      child: const RiverLayoutScope(
        child: SizedBox(width: 700, child: RiverContentScope(child: _probes)),
      ),
    );

    await tester.pumpWidget(tree(TextScaler.noScaling));
    expect(_seen[RiverLayoutAspect.navigation], RiverWindowClass.large);

    await tester.pumpWidget(tree(const TextScaler.linear(2)));
    expect(_seen[RiverLayoutAspect.navigation], RiverWindowClass.medium);
    expect(_seen[RiverLayoutAspect.content], RiverWindowClass.medium);
  });

  testWidgets('unbounded content inherits the enclosing class', (tester) async {
    await tester.pumpWidget(
      _window(
        900,
        child: const RiverLayoutScope(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              height: 100,
              child: RiverContentScope(
                child: SizedBox(width: 10, child: _probes),
              ),
            ),
          ),
        ),
      ),
    );

    expect(_seen[RiverLayoutAspect.content], RiverWindowClass.expanded);
  });

  testWidgets('falls back to MediaQuery without a scope', (tester) async {
    await tester.pumpWidget(_window(390, child: _probes));

    expect(_seen.values, everyElement(RiverWindowClass.compact));
  });
}
