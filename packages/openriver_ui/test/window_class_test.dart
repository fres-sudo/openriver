import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openriver_ui/openriver_ui.dart';

void main() {
  group('RiverWindowClass.fromWidth', () {
    final cases = <double, RiverWindowClass>{
      0.0: RiverWindowClass.compact,
      320.0: RiverWindowClass.compact,
      599.9: RiverWindowClass.compact,
      600.0: RiverWindowClass.medium,
      839.9: RiverWindowClass.medium,
      840.0: RiverWindowClass.expanded,
      1199.9: RiverWindowClass.expanded,
      1200.0: RiverWindowClass.large,
      1599.9: RiverWindowClass.large,
      1600.0: RiverWindowClass.extraLarge,
      3840.0: RiverWindowClass.extraLarge,
    };
    for (final MapEntry(key: width, value: expected) in cases.entries) {
      test('$width is ${expected.name}', () {
        expect(RiverWindowClass.fromWidth(width), expected);
      });
    }

    test('treats invalid widths as the nearest class', () {
      expect(RiverWindowClass.fromWidth(-1), RiverWindowClass.compact);
      expect(RiverWindowClass.fromWidth(double.nan), RiverWindowClass.compact);
      expect(
        RiverWindowClass.fromWidth(double.infinity),
        RiverWindowClass.extraLarge,
      );
    });

    test('class minimum widths are ascending', () {
      final widths = RiverWindowClass.values.map((c) => c.minWidth).toList();
      expect(widths, orderedEquals([...widths]..sort()));
    });
  });

  group('effective text scale', () {
    test('clamps to 1–2', () {
      expect(RiverWindowClass.effectiveTextScale(TextScaler.noScaling), 1);
      expect(
        RiverWindowClass.effectiveTextScale(const TextScaler.linear(0.8)),
        1,
      );
      expect(
        RiverWindowClass.effectiveTextScale(const TextScaler.linear(1.5)),
        1.5,
      );
      expect(
        RiverWindowClass.effectiveTextScale(const TextScaler.linear(2)),
        2,
      );
      expect(
        RiverWindowClass.effectiveTextScale(const TextScaler.linear(3)),
        2,
      );
    });

    test('navigation class narrows with larger text', () {
      expect(
        RiverWindowClass.forNavigation(700, TextScaler.noScaling),
        RiverWindowClass.medium,
      );
      expect(
        RiverWindowClass.forNavigation(700, const TextScaler.linear(2)),
        RiverWindowClass.compact,
      );
      expect(
        RiverWindowClass.forNavigation(1300, const TextScaler.linear(1.5)),
        RiverWindowClass.expanded,
      );
      expect(
        RiverWindowClass.forNavigation(1300, const TextScaler.linear(3)),
        RiverWindowClass.medium,
      );
    });
  });

  test('comparison operators follow width order', () {
    expect(RiverWindowClass.expanded >= RiverWindowClass.medium, isTrue);
    expect(RiverWindowClass.expanded >= RiverWindowClass.expanded, isTrue);
    expect(RiverWindowClass.expanded > RiverWindowClass.expanded, isFalse);
    expect(RiverWindowClass.compact < RiverWindowClass.medium, isTrue);
    expect(RiverWindowClass.large <= RiverWindowClass.medium, isFalse);
  });
}
