/// Half-band filters and the polyphase decomposition.
///
/// The half-band tests are about the identity the design rests on: mirror
/// bands with equal weights give `A(w) + A(pi-w) = 1`, and that identity *is*
/// the statement that alternate taps vanish. So the check is that they come
/// out at machine zero before anything snaps them, not merely that they are
/// zero after.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:remez/src/coeff_export.dart';
import 'package:remez/src/controller.dart';
import 'package:remez/src/fir_core.dart' as fir;
import 'package:remez/src/multirate.dart';

void main() {
  group('lengths', () {
    test('a half-band length is 4k+3', () {
      expect(isHalfBandLength(11), isTrue);
      expect(isHalfBandLength(15), isTrue);
      expect(isHalfBandLength(13), isFalse);
      expect(isHalfBandLength(12), isFalse);
      expect(isHalfBandLength(3), isFalse, reason: 'too short to be useful');
    });

    test('anything else is rounded to one', () {
      for (var n = 8; n < 200; n++) {
        final rounded = nearestHalfBandLength(n);
        expect(isHalfBandLength(rounded), isTrue, reason: 'from $n');
        expect((rounded - n).abs(), lessThanOrEqualTo(2));
      }
      expect(nearestHalfBandLength(2), 7);
    });
  });

  group('the vanishing taps', () {
    test('they are the even distances from the centre', () {
      // N = 11, centre at 5: the taps at 1, 3, 7 and 9 vanish.
      expect(vanishingTaps(11), [1, 3, 7, 9]);
      expect(vanishingTaps(15), [1, 3, 5, 9, 11, 13]);
      expect(vanishingTaps(11), isNot(contains(5)),
          reason: 'the centre tap is the one that carries the half');
    });

    test('the exchange puts them at machine zero on its own', () {
      for (final n in [11, 19, 31, 43]) {
        final res = fir.design(n, halfBandBands(0.2), fs: 1.0);
        for (final k in vanishingTaps(n)) {
          expect(res.h[k].abs(), lessThan(1e-12),
              reason: 'N = $n, tap $k: snapping should be a rounding, not a '
                  'change of design');
        }
        expect(res.h[(n - 1) ~/ 2], closeTo(0.5, 1e-12));
      }
    });

    test('unequal weights break it, which is why they are not offered', () {
      final lopsided = fir.design(
          31,
          [
            fir.Band(0.0, 0.2, 1.0, 1.0, w1: 1, w2: 1),
            fir.Band(0.3, 0.5, 0.0, 0.0, w1: 10, w2: 10),
          ],
          fs: 1.0);
      var worst = 0.0;
      for (final k in vanishingTaps(31)) {
        if (lopsided.h[k].abs() > worst) worst = lopsided.h[k].abs();
      }
      expect(worst, greaterThan(1e-4),
          reason: 'the identity only holds when the two bands are weighted '
              'the same and folded about the quarter rate');
    });

    test('an edge at or past the quarter rate is refused', () {
      expect(() => halfBandBands(0.25), throwsA(isA<fir.RemezError>()));
      expect(() => halfBandBands(0.0), throwsA(isA<fir.RemezError>()));
      expect(() => halfBandBands(0.3), throwsA(isA<fir.RemezError>()));
    });
  });

  group('snapping', () {
    test('it zeroes exactly the taps that should vanish', () {
      // N = 11: centre at 5, so the odd taps either side of it go.
      final h = Float64List.fromList([
        0.1, 1e-17, -0.2, -3e-16, 0.3, 0.5, 0.3, 2e-16, -0.2, -1e-17, 0.1,
      ]);
      final out = snapHalfBand(h);
      for (final k in vanishingTaps(11)) {
        expect(out[k], 0.0);
      }
      expect(out[0], 0.1, reason: 'an even tap is left alone');
      expect(out[4], 0.3);
      expect(out[5], 0.5, reason: 'the centre keeps its half');
    });

    test('the residual says how far off the identity was', () {
      final h = Float64List.fromList([
        0.1, 0.05, -0.2, 0.0, 0.3, 0.5, 0.3, 0.0, -0.2, 0.0, 0.1,
      ]);
      expect(halfBandResidual(h), closeTo(0.05 / 0.5, 1e-12));
    });
  });

  group('the census', () {
    test('zero taps need no multiplier', () {
      final h = Float64List.fromList([0.1, 0.0, 0.5, 0.0, 0.1]);
      final c = tapCensus(h, fir.Symmetry.symmetric, false);
      expect(c.taps, 5);
      expect(c.nonzero, 3);
      expect(c.multipliers, 3);
    });

    test('folding halves what is left', () {
      final h = Float64List.fromList([0.1, 0.0, 0.3, 0.0, 0.5, 0.0, 0.3, 0.0, 0.1]);
      final c = tapCensus(h, fir.Symmetry.symmetric, true);
      // Two live pairs plus the centre.
      expect(c.multipliers, 3);
      expect(c.nonzero, 5);
    });
  });

  group('polyphase', () {
    test('the phases interleave back to the filter', () {
      final h = Float64List.fromList(
          [for (var i = 0; i < 13; i++) (i + 1) * 0.5]);
      for (final m in [2, 3, 4, 5]) {
        final phases = polyphase(h, m);
        expect(phases, hasLength(m));
        for (var k = 0; k < h.length; k++) {
          expect(phases[k % m][k ~/ m], h[k], reason: 'M = $m, tap $k');
        }
      }
    });

    test('the padding is zeros at the end', () {
      final h = Float64List.fromList([1.0, 2.0, 3.0, 4.0, 5.0]);
      final phases = polyphase(h, 2);
      expect(phases[0], [1.0, 3.0, 5.0]);
      expect(phases[1], [2.0, 4.0, 0.0]);
    });

    test('a factor of one is the filter itself', () {
      final h = Float64List.fromList([1.0, 2.0, 3.0]);
      expect(polyphase(h, 1).single, [1.0, 2.0, 3.0]);
    });

    test('a factor below one is refused', () {
      expect(() => polyphase(Float64List(4), 0), throwsA(isA<fir.RemezError>()));
    });
  });

  group('the controller', () {
    test('half band constrains the length and the taps', () {
      final c = DesignController()
        ..halfBand = true
        ..numtaps = 40
        ..design();
      expect(c.error, isNull);
      expect(c.numtaps, 39, reason: '40 rounds to the nearest 4k+3, which is 39');
      final h = c.firEffective!.h;
      for (final k in vanishingTaps(39)) {
        expect(h[k], 0.0, reason: 'tap $k is stored as exactly zero');
      }
      expect(h[19], closeTo(0.5, 1e-12), reason: 'the centre carries the half');
      expect(c.halfBandMiss, lessThan(1e-11));
    });

    test('the response really is a lowpass folded about the quarter rate', () {
      final c = DesignController()
        ..halfBand = true
        ..halfBandEdge = '0.2'
        ..numtaps = 43
        ..design();
      final m = c.magnitude(points: 512);
      // A(w) + A(pi - w) = 1: the amplitude at f and at 0.5-f sum to one.
      final linear = DesignController()
        ..halfBand = true
        ..halfBandEdge = '0.2'
        ..numtaps = 43
        ..logScale = false
        ..design();
      final a = linear.magnitude(points: 513);
      for (var i = 0; i < 513; i++) {
        final mirrored = a.y[512 - i];
        expect(a.y[i] + mirrored, closeTo(1.0, 1e-6),
            reason: 'the half-band identity, at ${a.f[i]}');
      }
      expect(m.y.first, closeTo(0.0, 0.1), reason: 'unity at DC, in dB');
    });

    test('a bad edge is an error, not a crash', () {
      final c = DesignController()
        ..halfBand = true
        ..halfBandEdge = '0.3'
        ..design();
      expect(c.error, isNotNull);
      expect(c.error, contains('quarter-rate'));
    });

    test('the report counts the multiplies saved', () {
      final c = DesignController()
        ..halfBand = true
        ..numtaps = 43
        ..design();
      final text = c.report();
      expect(text, contains('half band'));
      expect(text, contains('zero taps'));
      // Odd indices 1..41 is 21 taps, less the centre at 21 itself.
      expect(text, contains('20 of 43'));
    });
  });

  group('the rate change', () {
    test('there are no phases without a rate change', () {
      final c = DesignController()..design();
      expect(c.phases(), isNull);
      expect(c.report(), isNot(contains('polyphase')));
    });

    test('an IIR has no polyphase form here', () {
      final c = DesignController()
        ..mode = Mode.iir
        ..rateFactor = 4
        ..design();
      expect(c.phases(), isNull);
    });

    test('the phases are of the filter as built', () {
      final c = DesignController()
        ..rateFactor = 4
        ..design();
      final phases = c.phases()!;
      expect(phases, hasLength(4));
      final h = c.firEffective!.h;
      for (var k = 0; k < h.length; k++) {
        expect(phases[k % 4][k ~/ 4], h[k]);
      }
    });

    test('the report gives the multiply count per sample', () {
      final c = DesignController()
        ..rateFactor = 4
        ..numtaps = 41
        ..design();
      final text = c.report();
      expect(text, contains('polyphase, decimate by 4'));
      expect(text, contains('11 multiplies per input sample instead of 41'));
    });

    test('interpolating counts per output sample instead', () {
      final c = DesignController()
        ..rateFactor = 3
        ..rateChange = RateChange.interpolate
        ..design();
      expect(c.report(), contains('per output sample'));
    });

    test('the coefficient export carries the phases', () {
      final c = DesignController()
        ..rateFactor = 2
        ..design();
      final csv = firExport(c.firEffective!, 'x.csv', phases: c.phases());
      expect(csv.any((l) => l.startsWith('phase,k,h')), isTrue);
      final header = firExport(c.firEffective!, 'x.h', phases: c.phases());
      expect(header.any((l) => l.contains('#define FIR_PHASES 2')), isTrue);
      expect(header.any((l) => l.contains('fir_phases[FIR_PHASES]')), isTrue);
    });

    test('nothing extra is written when there is no rate change', () {
      final c = DesignController()..design();
      final csv = firExport(c.firEffective!, 'x.csv', phases: c.phases());
      expect(csv.any((l) => l.contains('phase')), isFalse);
    });
  });

  group('saving', () {
    test('the half-band and rate settings round trip', () {
      final a = DesignController()
        ..halfBand = true
        ..halfBandEdge = '0.18'
        ..rateFactor = 5
        ..rateChange = RateChange.interpolate
        ..design();
      final b = DesignController()..fromJson(a.toJson());
      expect(b.halfBand, isTrue);
      expect(b.halfBandEdge, '0.18');
      expect(b.rateFactor, 5);
      expect(b.rateChange, RateChange.interpolate);
      expect(b.error, isNull);
    });
  });

  group('what it is worth', () {
    test('a half band costs about half the multiplies of a plain design', () {
      final half = DesignController()
        ..halfBand = true
        ..numtaps = 43
        ..design();
      final plain = DesignController()
        ..numtaps = 43
        ..rows = [
          BandRow('0', '0.2', '1', '1', '1', '0.5'),
          BandRow('0.3', '0.5', '0', '0', '1', '50'),
        ]
        ..design();

      final a = tapCensus(half.firEffective!.h, fir.Symmetry.symmetric, false);
      final b = tapCensus(plain.firEffective!.h, fir.Symmetry.symmetric, false);
      expect(a.multipliers, lessThan(b.multipliers * 0.6));
      // And it is not a worse filter for it: same bands, comparable ripple.
      expect(half.firEffective!.delta.abs(),
          closeTo(plain.firEffective!.delta.abs(), 0.02));
      expect(math.max(a.multipliers, 1), 23,
          reason: '43 taps less the 20 that vanish');
    });
  });
}
