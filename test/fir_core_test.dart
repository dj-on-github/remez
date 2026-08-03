/// The FIR core, checked against the Python implementation it replaces.
///
/// `test/golden/reference.json` holds designs produced by `fir_core.py`. The
/// port has to reproduce them: same taps, same deviation, same extremal
/// frequencies. Anything else is a difference in the algorithm, not in the
/// language.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:remez/src/fir_core.dart';

Map<String, dynamic> loadReference() {
  final file = File('test/golden/reference.json');
  return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
}

Band bandFrom(List<dynamic> v, {String? weightKind}) => Band(
      (v[0] as num).toDouble(),
      (v[1] as num).toDouble(),
      (v[2] as num).toDouble(),
      (v[3] as num).toDouble(),
      w1: (v[4] as num).toDouble(),
      w2: (v[5] as num).toDouble(),
      weightKind:
          weightKind == 'inv_f' ? WeightKind.inverseF : WeightKind.constant,
    );

void main() {
  final reference = loadReference();

  group('against the Python implementation', () {
    for (final entry in reference['fir'] as List<dynamic>) {
      final c = entry as Map<String, dynamic>;
      test('${c['name']} matches', () {
        final bands = (c['bands'] as List<dynamic>)
            .map((b) => bandFrom(b as List<dynamic>,
                weightKind: c['weight_kind'] as String?))
            .toList();
        final res = design(
          c['numtaps'] as int,
          bands,
          symmetry: c['symmetry'] == 'antisymmetric'
              ? Symmetry.antisymmetric
              : Symmetry.symmetric,
        );

        expect(res.ftype, c['ftype']);
        expect(res.converged, c['converged']);

        final wantH = (c['h'] as List<dynamic>).cast<num>();
        expect(res.h.length, wantH.length);
        for (var i = 0; i < wantH.length; i++) {
          expect(res.h[i], closeTo(wantH[i].toDouble(), 1e-9),
              reason: 'tap $i of ${c['name']}');
        }

        expect(res.delta.abs(),
            closeTo((c['delta'] as num).toDouble().abs(), 1e-9));

        final wantDev = (c['band_deviation'] as List<dynamic>).cast<num>();
        for (var i = 0; i < wantDev.length; i++) {
          expect(res.bandDeviation[i],
              closeTo(wantDev[i].toDouble(), 1e-9 + 1e-6 * wantDev[i].abs()));
        }

        final wantExt = (c['extremal_f'] as List<dynamic>).cast<num>();
        expect(res.extremalF.length, wantExt.length);
        for (var i = 0; i < wantExt.length; i++) {
          expect(res.extremalF[i], closeTo(wantExt[i].toDouble(), 1e-12));
        }
      });
    }
  });

  group('the properties the exchange guarantees', () {
    test('the error alternates and is equiripple', () {
      final res = design(41, [
        Band.flat(0, 0.2, 1.0),
        Band.flat(0.25, 0.5, 0.0, weight: 10.0),
      ]);
      expect(res.extremalE.length, (41 + 1) ~/ 2 + 1);
      for (var i = 0; i < res.extremalE.length - 1; i++) {
        expect(res.extremalE[i] * res.extremalE[i + 1], lessThan(0),
            reason: 'signs must alternate at $i');
      }
      for (final e in res.extremalE) {
        expect(e.abs(), closeTo(res.delta.abs(), 1e-6 * res.delta.abs()));
      }
      for (final e in res.gridE) {
        expect(e.abs(), lessThanOrEqualTo(res.delta.abs() * (1 + 1e-6)));
      }
    });

    test('the taps come out symmetric', () {
      final sym = design(30, [
        Band.flat(0, 0.2, 1.0),
        Band.flat(0.3, 0.5, 0.0),
      ]);
      for (var i = 0; i < sym.numtaps; i++) {
        expect(sym.h[i], closeTo(sym.h[sym.numtaps - 1 - i], 1e-15));
      }

      final anti = design([Band.flat(0.05, 0.45, 1.0)].isEmpty ? 0 : 31,
          [Band.flat(0.05, 0.45, 1.0)],
          symmetry: Symmetry.antisymmetric);
      for (var i = 0; i < anti.numtaps; i++) {
        expect(anti.h[i], closeTo(-anti.h[anti.numtaps - 1 - i], 1e-15));
      }
      expect(anti.h[15].abs(), lessThan(1e-15));
    });

    test('the taps reproduce the amplitude that was designed', () {
      final res = design(37, [
        Band.flat(0, 0.15, 1.0),
        Band.flat(0.22, 0.4, 0.3),
        Band.flat(0.45, 0.5, 0.0),
      ]);
      final w = Float64List(res.gridF.length);
      for (var i = 0; i < w.length; i++) {
        w[i] = 2 * math.pi * res.gridF[i] / res.fs;
      }
      final amp = amplitudeResponse(res.h, w, res.symmetry);
      for (var i = 0; i < amp.length; i++) {
        expect(amp[i], closeTo(res.gridA[i], 1e-9));
      }
    });

    test('weighting scales the ripples', () {
      final res = design(41, [
        Band.flat(0, 0.2, 1.0),
        Band.flat(0.3, 0.5, 0.0, weight: 10.0),
      ]);
      expect(res.bandDeviation[0] / res.bandDeviation[1],
          closeTo(10.0, 10.0 * 1e-3));
    });

    test('the sample rate is only a change of units', () {
      final hz = design(31, [
        Band.flat(0, 2000, 1.0),
        Band.flat(2500, 5000, 0.0),
      ], fs: 10000);
      final normalised = design(31, [
        Band.flat(0, 0.2, 1.0),
        Band.flat(0.25, 0.5, 0.0),
      ]);
      for (var i = 0; i < hz.numtaps; i++) {
        expect(hz.h[i], closeTo(normalised.h[i], 1e-12));
      }
    });

    test('long filters stay equiripple', () {
      for (final numtaps in [101, 128, 175, 220]) {
        final res = design(numtaps, [
          Band.flat(0, 0.2, 1.0),
          Band.flat(0.25, 0.5, 0.0, weight: 10.0),
        ]);
        expect(res.converged, isTrue, reason: '$numtaps taps');
        for (var i = 0; i < res.extremalE.length - 1; i++) {
          expect(res.extremalE[i] * res.extremalE[i + 1], lessThan(0));
        }
        for (final e in res.extremalE) {
          expect(e.abs(), closeTo(res.delta.abs(), 1e-6 * res.delta.abs()));
        }
      }
    });

    test('inverse-f weighting equalises the relative error', () {
      final res = design(
          33,
          [
            Band(0.02, 0.45, 2 * math.pi * 0.02, 2 * math.pi * 0.45,
                weightKind: WeightKind.inverseF)
          ],
          symmetry: Symmetry.antisymmetric);
      final f = Float64List(2000);
      for (var i = 0; i < f.length; i++) {
        f[i] = 2 * math.pi * (0.05 + (0.45 - 0.05) * i / (f.length - 1));
      }
      final amp = amplitudeResponse(res.h, f, Symmetry.antisymmetric);
      var lo = 0.0, hi = 0.0;
      for (var i = 0; i < f.length; i++) {
        final rel = (amp[i] - f[i]).abs() / f[i];
        if (i < f.length ~/ 2) {
          lo = math.max(lo, rel);
        } else {
          hi = math.max(hi, rel);
        }
      }
      expect(hi / lo, closeTo(1.0, 0.05));
    });
  });

  group('input validation', () {
    test('too few taps', () {
      expect(() => design(2, [Band.flat(0, 0.2, 1.0)]),
          throwsA(isA<RemezError>()));
    });
    test('a band past Nyquist', () {
      expect(() => design(21, [Band.flat(0, 0.6, 1.0)]),
          throwsA(isA<RemezError>()));
    });
    test('overlapping bands', () {
      expect(
          () => design(21, [
                Band.flat(0.3, 0.5, 1.0),
                Band.flat(0.1, 0.2, 0.0),
              ]),
          throwsA(isA<RemezError>()));
    });
    test('a weight of zero', () {
      expect(() => design(21, [Band.flat(0, 0.2, 1.0, weight: 0.0)]),
          throwsA(isA<RemezError>()));
    });
  });

  group('withTaps', () {
    test('re-analyses everything it reports', () {
      final res = design(41, [
        Band.flat(0, 0.2, 1.0),
        Band.flat(0.25, 0.5, 0.0, weight: 10.0),
      ]);
      final rounded = Float64List.fromList(
          res.h.map((v) => (v * 256).roundToDouble() / 256).toList());
      final eff = withTaps(res, rounded);

      expect(eff.delta, res.delta); // the design's own history is kept
      expect(eff.iterations, res.iterations);
      for (var i = 0; i < eff.gridA.length; i++) {
        expect(eff.gridE[i],
            closeTo(res.gridW[i] * (res.gridD[i] - eff.gridA[i]), 1e-12));
      }
      expect(eff.bandDeviation[1], greaterThan(res.bandDeviation[1]));
    });

    test('the same taps change nothing', () {
      final res = design(31, [
        Band.flat(0, 0.2, 1.0),
        Band.flat(0.25, 0.5, 0.0),
      ]);
      final again = withTaps(res, res.h);
      for (var i = 0; i < res.bandDeviation.length; i++) {
        expect(again.bandDeviation[i], closeTo(res.bandDeviation[i], 1e-12));
      }
    });
  });

  test("Kaiser's estimate is in the right ballpark", () {
    final n = kaiserOrderEstimate(0.01, 0.001, 0.05);
    final res = design(n | 1, [
      Band.flat(0, 0.2, 1.0),
      Band.flat(0.25, 0.5, 0.0, weight: 10.0),
    ]);
    expect(res.bandDeviation[0], lessThan(0.02));
  });
  test('running the iteration cap out reports the cap, not one past it', () {
    // Python's `for it in range(1, maxiter + 1)` leaves `it` at maxiter when
    // the loop runs to the end; a C-style for leaves it one higher. Every
    // converging design breaks out early and agrees either way, so this is the
    // only shape of design that can tell the two apart.
    final bands = [
      Band.flat(0, 0.2, 1.0),
      Band.flat(0.25, 0.5, 0.0, weight: 10),
    ];
    for (final cap in [1, 2, 3]) {
      final res = design(41, bands, maxiter: cap);
      expect(res.converged, isFalse, reason: 'maxiter $cap');
      expect(res.iterations, cap, reason: 'maxiter $cap');
    }
    // Python: design(41, bands, maxiter=2).h[:2]
    final res = design(41, bands, maxiter: 2);
    expect(res.h[0], closeTo(0.004354720639138332, 1e-12));
    expect(res.h[1], closeTo(0.008190272470050513, 1e-12));

    // With room to finish it converges well inside the cap.
    final done = design(41, bands, maxiter: 40);
    expect(done.converged, isTrue);
    expect(done.iterations, lessThan(40));
  });

}
