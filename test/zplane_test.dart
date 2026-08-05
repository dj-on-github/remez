/// The root finder behind the pole-zero plot, and what the controller hands it.
///
/// There is no Python reference for this one -- the original has no z-plane
/// plot -- so the checks are against properties the answer has to have:
/// polynomials whose roots are known, and the much stronger test of multiplying
/// the roots back out and recovering the taps that were factored.
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:remez/src/complex.dart';
import 'package:remez/src/controller.dart';
import 'package:remez/src/roots.dart';

/// The monic polynomial with these roots, as coefficients in descending powers.
List<Complex> expand(List<Complex> roots) {
  var poly = <Complex>[Complex.one];
  for (final r in roots) {
    final next = List<Complex>.filled(poly.length + 1, Complex.zero);
    for (var i = 0; i < poly.length; i++) {
      next[i] = next[i] + poly[i];
      next[i + 1] = next[i + 1] - poly[i] * r;
    }
    poly = next;
  }
  return poly;
}

/// The roots, sorted so two answers to the same polynomial line up.
List<Complex> sorted(List<Complex> values) {
  final out = [...values];
  out.sort((a, b) {
    final c = a.re.compareTo(b.re);
    return c != 0 ? c : a.im.compareTo(b.im);
  });
  return out;
}

void main() {
  group('polynomialRoots', () {
    test('finds the roots of a cubic with integer roots', () {
      // (z-1)(z-2)(z-3) = z^3 - 6z^2 + 11z - 6
      final found = polynomialRoots([1, -6, 11, -6]);
      expect(found.converged, isTrue);
      final re = sorted(found.values).map((v) => v.re).toList();
      expect(re[0], closeTo(1.0, 1e-10));
      expect(re[1], closeTo(2.0, 1e-10));
      expect(re[2], closeTo(3.0, 1e-10));
      for (final v in found.values) {
        expect(v.im.abs(), lessThan(1e-10));
      }
    });

    test('finds the nth roots of unity', () {
      const n = 12;
      final found = polynomialRoots([1, ...List.filled(n - 1, 0.0), -1]);
      expect(found.converged, isTrue);
      expect(found.values, hasLength(n));
      for (final v in found.values) {
        expect(v.abs, closeTo(1.0, 1e-12));
      }
      // Every one of them, not the same one twelve times.
      final angles = found.values.map((v) => v.arg).toList()..sort();
      for (var i = 1; i < angles.length; i++) {
        expect(angles[i] - angles[i - 1], closeTo(2 * math.pi / n, 1e-9));
      }
    });

    test('takes trailing zeros as roots at the origin', () {
      // z^3 - z^2 = z^2 (z - 1)
      final found = polynomialRoots([1, -1, 0, 0]);
      expect(found.converged, isTrue);
      expect(found.values, hasLength(3));
      expect(found.values.where((v) => v.abs < 1e-15), hasLength(2));
      expect(found.values.where((v) => (v.re - 1).abs() < 1e-12), hasLength(1));
    });

    test('takes leading zeros as a lower degree', () {
      final found = polynomialRoots([0, 0, 1, -3, 2]);
      expect(found.values, hasLength(2));
      final re = sorted(found.values).map((v) => v.re).toList();
      expect(re[0], closeTo(1.0, 1e-12));
      expect(re[1], closeTo(2.0, 1e-12));
    });

    test('a repeated root is found the right number of times', () {
      // (z - 0.5)^4, which is the case Durand-Kerner handles worst.
      final found = polynomialRoots([1, -2, 1.5, -0.5, 0.0625]);
      expect(found.values, hasLength(4));
      for (final v in found.values) {
        // A root of multiplicity m is only ever resolved to about the m'th
        // root of the machine epsilon, so this is as close as it can get.
        expect((v - const Complex(0.5)).abs, lessThan(1e-3));
      }
    });

    test('an empty or constant polynomial has no roots', () {
      expect(polynomialRoots([]).values, isEmpty);
      expect(polynomialRoots([3.0]).values, isEmpty);
      expect(polynomialRoots([0.0]).values, isEmpty);
    });
  });

  group('a real filter', () {
    test('the zeros multiply back out to the taps', () {
      final c = DesignController()..design();
      final h = c.firEffective!.h;
      final found = polynomialRoots(h.toList());
      expect(found.converged, isTrue,
          reason: 'a 41-tap lowpass should be well within reach');
      expect(found.values, hasLength(h.length - 1));

      final poly = expand(found.values);
      final scale = h[0];
      for (var i = 0; i < h.length; i++) {
        expect(poly[i].im * scale, closeTo(0.0, 1e-9),
            reason: 'real taps have conjugate-symmetric roots');
        expect(poly[i].re * scale, closeTo(h[i], 1e-9),
            reason: 'coefficient $i of the reconstructed polynomial');
      }
    });

    test('a symmetric FIR has its zeros in reciprocal pairs', () {
      final c = DesignController()..design();
      final found = polynomialRoots(c.firEffective!.h.toList());
      for (final v in found.values) {
        if ((v.abs - 1.0).abs() < 1e-6) continue; // its own reciprocal
        final reciprocal = Complex.one / v;
        final partner = found.values
            .any((other) => (other - reciprocal).abs < 1e-4);
        expect(partner, isTrue,
            reason: 'linear phase pairs $v with 1/$v');
      }
    });

    test('the stopband zeros sit on the unit circle', () {
      final c = DesignController()..design();
      final found = polynomialRoots(c.firEffective!.h.toList());
      final onCircle =
          found.values.where((v) => (v.abs - 1.0).abs() < 1e-6).length;
      // A 41-tap lowpass spends most of its zeros nulling the stopband, and
      // each of those is a point where the response is exactly zero: on the
      // circle, not near it.
      expect(onCircle, greaterThan(found.values.length ~/ 2));
    });
  });

  group('controller.zplane', () {
    test('an FIR reports its delay-line poles at the origin', () {
      final c = DesignController()..design();
      final z = c.zplane()!;
      expect(z.poles, hasLength(c.numtaps - 1));
      for (final p in z.poles) {
        expect(p.abs, 0.0);
      }
      expect(z.zeros, hasLength(c.numtaps - 1));
    });

    test('there is no ideal set to compare against in floating point', () {
      final c = DesignController()..design();
      expect(c.zplane(ideal: true), isNull);
    });

    test('an IIR hands over the poles it was designed from', () {
      final c = DesignController()
        ..mode = Mode.iir
        ..design();
      final z = c.zplane()!;
      expect(z.poles, hasLength(c.iirEffective!.degree));
      expect(c.iirEffective!.stable, isTrue);
      for (final p in z.poles) {
        expect(p.abs, lessThan(1.0));
      }
    });

    test('rounding the coefficients moves the poles', () {
      final c = DesignController()
        ..mode = Mode.iir
        ..approximation = 'elliptic'
        ..arithmetic = Arithmetic.fixed
        ..wordBits = 10
        ..design();
      final built = c.zplane()!;
      final ideal = c.zplane(ideal: true)!;
      expect(ideal.poles, hasLength(built.poles.length));

      var moved = 0.0;
      for (var i = 0; i < built.poles.length; i++) {
        final d = (built.poles[i] - ideal.poles[i]).abs;
        if (d > moved) moved = d;
      }
      expect(moved, greaterThan(0.0),
          reason: '10-bit coefficients cannot land on the design exactly');
    });

    test('the answer is cached until the next design', () {
      final c = DesignController()..design();
      expect(identical(c.zplane(), c.zplane()), isTrue);
      final before = c.zplane();
      c.update(() => c.numtaps = 31);
      expect(identical(c.zplane(), before), isFalse);
      expect(c.zplane()!.zeros, hasLength(30));
    });
  });
}
