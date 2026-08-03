/// The coefficient tables, against the ones the Python writes.
///
/// Eight files: FIR and IIR, floating and fixed, CSV and C header. The values
/// are the whole point of the export, so they are compared as numbers to the
/// precision the two designs agree to, and everything else -- the header lines,
/// the column names, the punctuation, the `#define`s -- character for
/// character.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:remez/src/coeff_export.dart';
import 'package:remez/src/controller.dart';

final RegExp _number = RegExp(r'-?\d+\.?\d*(?:[eE][-+]?\d+)?');

void expectSameFile(List<String> got, String wantPath) {
  final want = File('test/golden/$wantPath').readAsStringSync().split('\n');
  // The Python writes a trailing newline, so the split leaves an empty last.
  if (want.isNotEmpty && want.last.isEmpty) want.removeLast();
  expect(got.length, want.length, reason: 'line count of $wantPath');
  for (var i = 0; i < want.length; i++) {
    if (got[i] == want[i]) continue;
    expect(got[i].replaceAll(_number, 'N'), want[i].replaceAll(_number, 'N'),
        reason: '$wantPath line ${i + 1}');
    final xs = _number.allMatches(got[i]).map((m) => double.parse(m[0]!)).toList();
    final ys = _number.allMatches(want[i]).map((m) => double.parse(m[0]!)).toList();
    for (var k = 0; k < ys.length; k++) {
      expect(xs[k], closeTo(ys[k], math.max(ys[k].abs() * 1e-9, 1e-12)),
          reason: '$wantPath line ${i + 1}, number ${k + 1}');
    }
  }
}

DesignController _fir({int bits = 0}) {
  final c = DesignController();
  c.update(() {
    c.numtaps = 15;
    if (bits > 0) {
      c.arithmetic = Arithmetic.fixed;
      c.wordBits = bits;
    }
  });
  return c;
}

DesignController _iir({int bits = 0}) {
  final c = DesignController();
  c.update(() {
    c.mode = Mode.iir;
    c.approximation = 'chebyshev1';
    c.wp = ['0.2', '0.4'];
    c.ws = ['0.3', '0.45'];
    c.rp = '0.5';
    c.rs = '40';
    if (bits > 0) {
      c.arithmetic = Arithmetic.fixed;
      c.wordBits = bits;
    }
  });
  return c;
}

void main() {
  group('the FIR table', () {
    test('CSV, floating point', () {
      final c = _fir();
      expectSameFile(firExport(c.firEffective!, 'x.csv'), 'py_fir_float.csv');
    });

    test('C header, floating point', () {
      final c = _fir();
      expectSameFile(firExport(c.firEffective!, 'x.h'), 'py_fir_float.h');
    });

    test('CSV, fixed point, with the stored integers alongside', () {
      final c = _fir(bits: 12);
      final got = firExport(c.firEffective!, 'x.csv', fixed: c.fixed);
      expectSameFile(got, 'py_fir_fixed.csv');
      expect(got[3], 'n,h,h_q');
    });

    test('C header, fixed point', () {
      final c = _fir(bits: 12);
      final got = firExport(c.firEffective!, 'x.h', fixed: c.fixed);
      expectSameFile(got, 'py_fir_fixed.h');
      expect(got.join('\n'), contains('#define FIR_FRAC_BITS'));
      expect(got.join('\n'), contains('static const long fir_coeffs_q'));
    });
  });

  group('the IIR table', () {
    test('CSV, floating point', () {
      final c = _iir();
      expectSameFile(iirExport(c.iirEffective!, 'x.csv'), 'py_iir_float.csv');
    });

    test('C header, floating point', () {
      final c = _iir();
      expectSameFile(iirExport(c.iirEffective!, 'x.h'), 'py_iir_float.h');
    });

    test('CSV, fixed point', () {
      final c = _iir(bits: 16);
      expectSameFile(
          iirExport(c.iirEffective!, 'x.csv', fixed: c.fixed), 'py_iir_fixed.csv');
    });

    test('C header, fixed point', () {
      final c = _iir(bits: 16);
      expectSameFile(
          iirExport(c.iirEffective!, 'x.h', fixed: c.fixed), 'py_iir_fixed.h');
    });
  });

  test('the format follows the extension, not the mode', () {
    expect(wantsHeader('taps.h'), isTrue);
    expect(wantsHeader('taps.csv'), isFalse);
    expect(wantsHeader('taps.txt'), isFalse);
    // Anything that is not a .h gets the CSV, as the Python does.
    final c = _fir();
    expect(firExport(c.firEffective!, 'taps.txt').first, startsWith('#'));
    expect(firExport(c.firEffective!, 'taps.h').first, startsWith('/*'));
  });

  test('what is written is the filter that was built, not the ideal one', () {
    final c = _fir(bits: 8);
    final rows = firExport(c.firEffective!, 'x.csv', fixed: c.fixed);
    // Column h is the rounded value, h_q the integer it is stored as, and the
    // two agree through the scale factor.
    final scale = math.pow(2, c.fixed!.fracBits);
    for (var i = 0; i < c.firEffective!.h.length; i++) {
      final parts = rows[4 + i].split(',');
      expect(int.parse(parts[0]), i);
      expect(double.parse(parts[1]) * scale, closeTo(int.parse(parts[2]), 1e-9));
    }
    // And they are not the unrounded taps.
    expect(c.firEffective!.h[0], isNot(c.firResult!.h[0]));
  });
}
