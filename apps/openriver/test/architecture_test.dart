import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// UI comes from `openriver_ui`, which wraps shadcn_ui and excludes Material
/// and Cupertino controls. See docs/flutter-design-system.md.
const _forbidden = [
  'package:flutter/material.dart',
  'package:flutter/cupertino.dart',
  'package:shadcn_ui/',
];

final _import = RegExp(r'''^\s*import\s+['"]([^'"]+)['"]''', multiLine: true);

void main() {
  test('app sources use the UI kit instead of other UI libraries', () {
    final violations = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      for (final match in _import.allMatches(file.readAsStringSync())) {
        final uri = match.group(1)!;
        if (_forbidden.any(uri.startsWith)) {
          violations.add('${file.path}: $uri');
        }
      }
    }
    expect(violations, isEmpty);
  });
}
