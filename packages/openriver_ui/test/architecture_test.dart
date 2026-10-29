import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Packages the kit must never import; it receives app data as arguments.
const _forbidden = [
  'package:flutter/material.dart',
  'package:flutter/cupertino.dart',
  'package:openriver_api/',
  'package:openriver/',
  'package:flutter_bloc/',
  'package:go_router/',
];

final _import = RegExp(r'''^\s*import\s+['"]([^'"]+)['"]''', multiLine: true);

void main() {
  test('kit sources import only allowed packages', () {
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
