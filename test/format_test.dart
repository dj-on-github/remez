/// `formatG` against Python's `%g`, on every value the exports might hit.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:remez/src/format.dart';

void main() {
  final cases = json.decode(
      File('test/golden/format_cases.json').readAsStringSync()) as List<dynamic>;

  test('it matches Python for every precision the exports use', () {
    var checked = 0;
    for (final row in cases.cast<List<dynamic>>()) {
      final v = (row[0] as num).toDouble();
      expect(formatG(v, precision: 17), row[1], reason: 'g17 of $v');
      expect(formatG(v), row[2], reason: 'g6 of $v');
      expect(formatG(v, precision: 4), row[3], reason: 'g4 of $v');
      expect(formatG(v, precision: 10), row[4], reason: 'g10 of $v');
      expect(formatG(v, precision: 17, space: true), row[5], reason: 'g17sp of $v');
      expect(formatG(v, precision: 3), row[6], reason: 'g3 of $v');
      expect(formatF(v, 4), row[7], reason: 'f4 of $v');
      expect(formatF(v, 6), row[8], reason: 'f6 of $v');
      expect(formatF(v, 9), row[9], reason: 'f9 of $v');
      checked++;
    }
    expect(checked, greaterThan(500));
  });

  test('the awkward ones by hand', () {
    // The notation switch, either side of it.
    expect(formatG(1e-4), '0.0001');
    expect(formatG(1e-5), '1e-05');
    expect(formatG(123456.0), '123456');
    expect(formatG(1234567.0), '1.23457e+06');
    // Trailing zeros go, and the point with them.
    expect(formatG(1.5), '1.5');
    expect(formatG(2.0), '2');
    expect(formatG(0.0), '0');
    expect(formatG(-0.0), '-0');
    // The space flag pads only the non-negative.
    expect(formatG(1.0, space: true), ' 1');
    expect(formatG(-1.0, space: true), '-1');
  });
}
