/// The command line.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:remez/src/cli.dart';
import 'package:remez/src/labels.dart';

void main() {
  test('it calls itself remez', () {
    // The name it presents, which is not the name of the Dart package it is
    // built from.
    expect(programName, 'remez');
    expect(usage, startsWith('usage: remez '));
    expect(parseArgs(['--version']).message, startsWith('remez '));
    expect(parseArgs(['--wat']).message, startsWith('remez: '));
    expect(parseArgs(['a', 'b']).message, startsWith('remez: '));
    // And nowhere does the old name survive.
    expect(usage, isNot(contains('remez_flutter')));
  });

  test('nothing means open the designer', () {
    final r = parseArgs([]);
    expect(r.shouldExit, isFalse);
    expect(r.designPath, isNull);
  });

  test('a positional argument is the design to open', () {
    final r = parseArgs(['saved.json']);
    expect(r.shouldExit, isFalse);
    expect(r.designPath, 'saved.json');
  });

  test('help and version print and stop', () {
    for (final flag in ['-h', '--help']) {
      final r = parseArgs([flag]);
      expect(r.exitCode, 0, reason: flag);
      expect(r.isError, isFalse, reason: flag);
      expect(r.message, contains('usage:'), reason: flag);
      expect(r.message, contains('DESIGN.remz'), reason: flag);
    }
    final v = parseArgs(['--version']);
    expect(v.exitCode, 0);
    expect(v.message, contains(version));
  });

  test('an unknown option is an error, with the usage', () {
    final r = parseArgs(['--wat']);
    expect(r.exitCode, 2);
    expect(r.isError, isTrue);
    expect(r.message, contains('unrecognized arguments: --wat'));
    expect(r.message, contains('usage:'));
  });

  test('two design files is an error', () {
    final r = parseArgs(['a.json', 'b.json']);
    expect(r.exitCode, 2);
    expect(r.message, contains('only one design file'));
  });

  test('-- ends the options, so a file may start with a dash', () {
    final r = parseArgs(['--', '-odd-name.json']);
    expect(r.shouldExit, isFalse);
    expect(r.designPath, '-odd-name.json');
  });

  test('help wins wherever it appears', () {
    expect(parseArgs(['saved.json', '--help']).exitCode, 0);
  });
}
