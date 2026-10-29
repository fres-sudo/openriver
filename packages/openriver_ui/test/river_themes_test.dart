import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openriver_ui/openriver_ui.dart';

/// WCAG 2 relative luminance.
double _luminance(Color color) {
  double channel(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double contrast(Color a, Color b) {
  final (light, dark) = (_luminance(a), _luminance(b));
  return (math.max(light, dark) + 0.05) / (math.min(light, dark) + 0.05);
}

void main() {
  for (final (name, theme) in [
    ('light', RiverThemes.light),
    ('dark', RiverThemes.dark),
  ]) {
    group('$name theme text contrast meets WCAG AA', () {
      final c = theme.colorScheme;
      final pairs = {
        'foreground on background': (c.foreground, c.background),
        'muted foreground on background': (c.mutedForeground, c.background),
        'muted foreground on muted': (c.mutedForeground, c.muted),
        'card foreground on card': (c.cardForeground, c.card),
        'popover foreground on popover': (c.popoverForeground, c.popover),
        'primary foreground on primary': (c.primaryForeground, c.primary),
        'secondary foreground on secondary': (
          c.secondaryForeground,
          c.secondary,
        ),
        'accent foreground on accent': (c.accentForeground, c.accent),
        'destructive foreground on destructive': (
          c.destructiveForeground,
          c.destructive,
        ),
      };
      for (final MapEntry(key: label, value: (text, surface))
          in pairs.entries) {
        test(label, () {
          expect(contrast(text, surface), greaterThanOrEqualTo(4.5));
        });
      }

      // Links, alerts, and icons draw these colors directly on the page.
      test('primary as text on background', () {
        expect(contrast(c.primary, c.background), greaterThanOrEqualTo(4.5));
      });

      test('destructive as text on background', () {
        expect(
          contrast(c.destructive, c.background),
          greaterThanOrEqualTo(4.5),
        );
      });
    });
  }

  test('themes keep their brightness', () {
    expect(RiverThemes.light.brightness, Brightness.light);
    expect(RiverThemes.dark.brightness, Brightness.dark);
  });
}
