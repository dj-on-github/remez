/// Least squares and the window method, against what each is supposed to buy.
///
/// There is no reference implementation to match here, so the tests are the
/// defining properties: least squares must beat the exchange on total squared
/// error and lose to it on the worst error -- that trade is the whole reason
/// it exists -- and a window must give the attenuation its textbook figure
/// says, whatever filter it is cutting.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:remez/src/controller.dart';
import 'package:remez/src/fir_core.dart';
import 'package:remez/src/fir_ls.dart';

List<Band> lowpass() => [
      Band(0.0, 0.2, 1.0, 1.0),
      Band(0.25, 0.5, 0.0, 0.0),
    ];

/// Peak and total squared error over the bands, measured off the response
/// rather than off whatever the designer reported about itself.
({double peak, double energy}) measure(RemezResult res) {
  var peak = 0.0;
  var energy = 0.0;
  const points = 2000;
  for (final band in res.bands) {
    final w = Float64List(points);
    for (var i = 0; i < points; i++) {
      w[i] = 2 *
          math.pi *
          (band.f1 + (band.f2 - band.f1) * i / (points - 1)) /
          res.fs;
    }
    final a = amplitudeResponse(res.h, w, res.symmetry);
    for (var i = 0; i < points; i++) {
      final e = (band.d1 - a[i]).abs();
      if (e > peak) peak = e;
      energy += e * e;
    }
  }
  return (peak: peak, energy: energy);
}

double dbOf(double x) => 20 * math.log(math.max(x, 1e-300)) / math.ln10;

void main() {
  group('least squares', () {
    test('it beats the exchange on energy and loses on the worst case', () {
      final remez = design(41, lowpass(), fs: 1.0);
      final ls = designLeastSquares(41, lowpass(), fs: 1.0);

      final a = measure(remez);
      final b = measure(ls);
      expect(b.energy, lessThan(a.energy),
          reason: 'least squares minimises exactly this');
      expect(b.peak, greaterThan(a.peak),
          reason: 'and the exchange minimises exactly that');
    });

    test('its stopband keeps falling away from the transition', () {
      final ls = designLeastSquares(61, lowpass(), fs: 1.0);
      double at(double f) {
        final w = Float64List.fromList([2 * math.pi * f]);
        return dbOf(amplitudeResponse(ls.h, w, ls.symmetry)[0].abs());
      }

      // Equiripple holds the whole stopband at one height. Least squares
      // spends its error near the transition and is quieter further out, so
      // the far half of the band should average below the near half.
      double mean(double from, double to) {
        var sum = 0.0;
        const n = 200;
        for (var i = 0; i < n; i++) {
          sum += at(from + (to - from) * i / (n - 1));
        }
        return sum / n;
      }

      expect(mean(0.36, 0.5), lessThan(mean(0.26, 0.36) - 6));
      expect(at(0.45), lessThan(at(0.27)));
    });

    test('it needs no iteration, and says so', () {
      final ls = designLeastSquares(41, lowpass(), fs: 1.0);
      expect(ls.iterations, 0);
      expect(ls.converged, isTrue);
      expect(ls.extremalF, isEmpty,
          reason: 'there is no alternation to mark');
    });

    test('the taps come out symmetric', () {
      final ls = designLeastSquares(41, lowpass(), fs: 1.0);
      for (var k = 0; k < 41; k++) {
        expect(ls.h[k], closeTo(ls.h[40 - k], 1e-15));
      }
    });

    test('an antisymmetric design comes out antisymmetric', () {
      final ls = designLeastSquares(
          41, <Band>[Band(0.05, 0.45, 1.0, 1.0)],
          symmetry: Symmetry.antisymmetric, fs: 1.0);
      for (var k = 0; k < 41; k++) {
        expect(ls.h[k], closeTo(-ls.h[40 - k], 1e-14));
      }
      expect(ls.h[20].abs(), lessThan(1e-15),
          reason: 'an odd-length antisymmetric filter has no centre tap');
      expect(ls.ftype, 3);
    });

    test('weights move the error where they are put', () {
      final even = designLeastSquares(41, lowpass(), fs: 1.0);
      final leaning = designLeastSquares(
          41,
          [
            Band(0.0, 0.2, 1.0, 1.0, w1: 1, w2: 1),
            Band(0.25, 0.5, 0.0, 0.0, w1: 20, w2: 20),
          ],
          fs: 1.0);
      expect(leaning.bandDeviation[1], lessThan(even.bandDeviation[1]));
      expect(leaning.bandDeviation[0], greaterThan(even.bandDeviation[0]));
    });

    test('every length and symmetry gives the right type', () {
      expect(designLeastSquares(41, lowpass()).ftype, 1);
      expect(designLeastSquares(40, lowpass()).ftype, 2);
      final anti = <Band>[Band(0.05, 0.45, 1.0, 1.0)];
      expect(
          designLeastSquares(41, anti, symmetry: Symmetry.antisymmetric).ftype,
          3);
      expect(
          designLeastSquares(40, anti, symmetry: Symmetry.antisymmetric).ftype,
          4);
    });
  });

  group('the window method', () {
    /// The stopband floor the design actually achieves, in dB.
    double floor(FirWindow w, {int numtaps = 161}) {
      final res = designWindowed(numtaps, lowpass(), window: w, fs: 1.0);
      return dbOf(res.bandDeviation[1]);
    }

    test('a taper beats no taper, and Blackman beats them all', () {
      // Not the textbook ordering, which is about each window's *first*
      // sidelobe and so lands in the transition band rather than in the
      // stopband anyone asked for. Measured over the band that was specified,
      // Hann's faster roll-off puts it ahead of Hamming's lower first lobe.
      expect(floor(FirWindow.rectangular), greaterThan(-40));
      for (final w in [FirWindow.hann, FirWindow.hamming, FirWindow.blackman]) {
        expect(floor(w), lessThan(floor(FirWindow.rectangular) - 20),
            reason: '${w.label} against no window at all');
      }
      expect(floor(FirWindow.blackman), lessThan(floor(FirWindow.hamming)));
      expect(floor(FirWindow.blackman), lessThan(floor(FirWindow.hann)));
    });

    test('each window bottoms out near its own sidelobe figure', () {
      for (final w in [FirWindow.hamming, FirWindow.blackman]) {
        expect(floor(w, numtaps: 321), lessThan(-w.attenuation + 4),
            reason: '${w.label} should reach its ${w.attenuation} dB');
        expect(floor(w, numtaps: 321), greaterThan(-w.attenuation - 30),
            reason: '${w.label} floor is set by the window, not the length');
      }
    });

    test('a window needs length before it delivers its figure', () {
      // Blackman's main lobe is the widest of them, so at 81 taps it does not
      // fit this transition and the filter falls a long way short.
      expect(floor(FirWindow.blackman, numtaps: 81), greaterThan(-50));
      expect(floor(FirWindow.blackman, numtaps: 161), lessThan(-70));
    });

    test('a bigger Kaiser beta buys a deeper stopband', () {
      double kaiser(double beta) => dbOf(designWindowed(161, lowpass(),
              window: FirWindow.kaiser, kaiserBeta: beta, fs: 1.0)
          .bandDeviation[1]);
      expect(kaiser(10.0), lessThan(kaiser(4.0) - 20));
    });

    test('it passes DC and stops Nyquist', () {
      final res = designWindowed(81, lowpass(), fs: 1.0);
      final w = Float64List.fromList([0.0, math.pi]);
      final a = amplitudeResponse(res.h, w, res.symmetry);
      expect(a[0], closeTo(1.0, 0.02));
      expect(a[1].abs(), lessThan(0.01));
    });

    test('the taps are exactly symmetric, so the phase is exactly linear', () {
      final res = designWindowed(41, lowpass(), fs: 1.0);
      for (var k = 0; k < 41; k++) {
        expect(res.h[k], res.h[40 - k]);
      }
    });

    test('the exchange still beats it, which is the point of the exchange', () {
      final remez = design(61, lowpass(), fs: 1.0);
      final win = designWindowed(61, lowpass(), fs: 1.0);
      expect(measure(remez).peak, lessThan(measure(win).peak));
    });
  });

  group('through the controller', () {
    test('the method can be switched and everything still works', () {
      for (final m in FirMethod.values) {
        final c = DesignController()
          ..method = m
          ..design();
        expect(c.error, isNull, reason: m.label);
        expect(c.firEffective!.h, hasLength(41));
        expect(c.report(), contains('method           ${m.label}'));
        // The plots and exports all read these.
        expect(c.magnitude().y.first, closeTo(0.0, 0.5));
        expect(c.zplane(), isNotNull);
        expect(c.phaseAndDelay(), isNotNull);
      }
    });

    test('only the exchange reports iterations', () {
      final remez = DesignController()..design();
      expect(remez.report(), contains('iterations'));
      final ls = DesignController()
        ..method = FirMethod.leastSquares
        ..design();
      expect(ls.report(), isNot(contains('iterations')));
    });

    test('the window is named in the report', () {
      final c = DesignController()
        ..method = FirMethod.window
        ..window = FirWindow.blackman
        ..design();
      expect(c.report(), contains('Blackman window'));
    });

    test('a Kaiser design names its beta', () {
      final c = DesignController()
        ..method = FirMethod.window
        ..window = FirWindow.kaiser
        ..kaiserBeta = '6.5'
        ..design();
      expect(c.report(), contains('beta 6.5'));
    });

    test('a bad beta is an error, not a crash', () {
      final c = DesignController()
        ..method = FirMethod.window
        ..window = FirWindow.kaiser
        ..kaiserBeta = 'wide'
        ..design();
      expect(c.error, contains('Kaiser beta'));
    });

    test('half band works with any method', () {
      for (final m in FirMethod.values) {
        final c = DesignController()
          ..method = m
          ..halfBand = true
          ..numtaps = 43
          ..design();
        expect(c.error, isNull, reason: m.label);
        // The identity is a property of the mirror-symmetric problem, so the
        // snapped taps should be near zero before snapping for the exchange
        // and least squares alike.
        expect(c.firEffective!.h[21], closeTo(0.5, 0.02), reason: m.label);
      }
    });

    test('the choice round trips through the design file', () {
      final a = DesignController()
        ..method = FirMethod.window
        ..window = FirWindow.kaiser
        ..kaiserBeta = '7.2'
        ..design();
      final b = DesignController()..fromJson(a.toJson());
      expect(b.method, FirMethod.window);
      expect(b.window, FirWindow.kaiser);
      expect(b.kaiserBeta, '7.2');
    });

    test('a file that predates the choice still opens on the exchange', () {
      final state = DesignController().toJson();
      (state['fir'] as Map<String, dynamic>).remove('method');
      final c = DesignController()..fromJson(state);
      expect(c.method, FirMethod.remez);
    });
  });
}
