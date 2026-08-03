/// The controller: what the UI drives, without building any widgets.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:remez/src/controller.dart';
import 'package:remez/src/fir_core.dart' as fir;

void main() {
  test('it designs a lowpass on construction', () {
    final c = DesignController()..design();
    expect(c.error, isNull);
    expect(c.firResult, isNotNull);
    expect(c.firResult!.numtaps, 41);
    expect(c.firResult!.converged, isTrue);
  });

  test('every FIR preset designs', () {
    final c = DesignController();
    for (final p in DesignController.presets) {
      c.loadPreset(p);
      expect(c.error, isNull, reason: p);
      expect(c.firResult!.converged, isTrue, reason: p);
    }
  });

  test('the sample rate carries the band edges with it', () {
    final c = DesignController()..design();
    final before = c.firResult!.h.toList();
    c.setSampleRate(48000);
    expect(c.rows[0].f2, '9600');
    expect(c.rows[1].f1, '12000');
    for (var i = 0; i < before.length; i++) {
      expect(c.firResult!.h[i], closeTo(before[i], 1e-12));
    }
    c.setSampleRate(1);
    expect(c.rows[0].f2, '0.2');
  });

  test('a bad field is reported, not thrown', () {
    final c = DesignController()..design();
    c.update(() => c.rows[0].f2 = 'banana');
    expect(c.error, contains('must be a number'));
    c.update(() => c.rows[0].f2 = '0.2');
    expect(c.error, isNull);
  });

  test('fixed point rounds the taps and reports the format', () {
    final c = DesignController()..design();
    final ideal = c.firResult!.h.toList();
    c.update(() {
      c.arithmetic = Arithmetic.fixed;
      c.wordBits = 8;
    });
    expect(c.fixed, isNotNull);
    expect(c.firEffective!.h, isNot(equals(ideal)));
    expect(c.firEffective!.bandDeviation[1],
        greaterThan(c.firResult!.bandDeviation[1]));
    expect(c.report(), contains('fixed point'));
  });

  test('IIR mode designs the verified models', () {
    final c = DesignController();
    for (final pair in [
      ['butterworth', 'lowpass'],
      ['butterworth', 'highpass'],
      ['chebyshev1', 'lowpass'],
      ['chebyshev2', 'bandstop'],
    ]) {
      c.update(() => c.mode = Mode.iir);
      c.setResponse(pair[1]);
      c.update(() => c.approximation = pair[0]);
      expect(c.error, isNull, reason: '$pair');
      expect(c.iirResult!.stable, isTrue, reason: '$pair');
      expect(c.verification, Verified.exact, reason: '$pair');
    }
  });

  test('every model the UI offers designs and is verified', () {
    // The caveat these carried while the port was in progress is gone because
    // all sixteen now reproduce the Python; the test is here so that adding a
    // seventeenth without reference designs cannot slip through unlabelled.
    final c = DesignController();
    c.update(() => c.mode = Mode.iir);
    for (final approximation in [
      'butterworth',
      'chebyshev1',
      'chebyshev2',
      'elliptic'
    ]) {
      for (final response in ['lowpass', 'highpass', 'bandpass', 'bandstop']) {
        c.update(() => c.approximation = approximation);
        c.setResponse(response);
        final where = '$approximation $response';
        expect(c.error, isNull, reason: where);
        expect(c.verification, Verified.exact, reason: where);
        expect(c.report(), isNot(contains('not yet checked')), reason: where);
      }
    }
  });

  test('a model with no reference designs is labelled rather than hidden', () {
    expect(verificationOf('butterworth', 'lowpass'), Verified.exact);
    expect(verificationOf('bessel', 'lowpass'), Verified.unverified);
  });

  test('the magnitude floor keeps the stopband on the plot', () {
    final c = DesignController();
    c.update(() {
      c.rows[1].weight = '100';
      c.numtaps = 81;
    });
    final floor = c.magnitudeFloor();
    final stopband = 20 *
        math.log(c.firEffective!.bandDeviation[1].abs()) / math.ln10;
    expect(floor, lessThan(stopband));
    expect(floor, greaterThanOrEqualTo(-220.0));
  });

  test('the plots have something to draw', () {
    final c = DesignController()..design();
    final m = c.magnitude();
    expect(m.f.length, m.y.length);
    expect(m.f.first, 0);
    expect(m.f.last, closeTo(c.fs / 2, 1e-12));
    expect(c.impulse().length, c.firResult!.numtaps);
  });
  group('weights from the Spec column', () {
    // A 0.5 dB peak-to-peak passband is +-delta about a gain of 1 where
    // 20*log10((1+d)/(1-d)) = 0.5, and a 50 dB stopband is a deviation of
    // 10^(-50/20).  Those are the two numbers the whole feature turns on.
    test('a dB spec becomes the deviation it means', () {
      final c = DesignController()
        ..useSpec = true
        ..design();
      expect(c.error, isNull);
      final dev = c.specDev!;
      expect(dev, hasLength(2));

      final g = math.pow(10.0, 0.5 / 20.0);
      expect(dev[0], closeTo((g - 1) / (g + 1), 1e-15));
      expect(dev[1], closeTo(math.pow(10.0, -50 / 20.0), 1e-15));
    });

    test('the weights it derives are inverse to the deviations', () {
      final c = DesignController()
        ..useSpec = true
        ..design();
      final dev = c.specDev!;
      final bands = c.firResult!.bands;
      // Only the ratio is meaningful, and the loosest band is normalised to 1.
      expect(bands[0].w1 * dev[0], closeTo(bands[1].w1 * dev[1], 1e-12));
      expect(math.min(bands[0].w1, bands[1].w1), closeTo(1.0, 1e-12));
    });

    test('the exchange equalises the specs, not the raw deviations', () {
      final c = DesignController()
        ..numtaps = 61
        ..useSpec = true
        ..design();
      final dev = c.specDev!;
      final got = c.firEffective!.bandDeviation;
      // Each band should overshoot its own spec by the same factor, and with
      // enough taps that factor should be under one.
      final slack = [got[0] / dev[0], got[1] / dev[1]];
      expect(slack[0], closeTo(slack[1], 1e-6));
      expect(slack[0], lessThan(1.0));
      expect(c.report(), contains('met'));
    });

    test('the Weight column is what is used when the box is clear', () {
      final c = DesignController()..design();
      expect(c.specDev, isNull);
      expect(c.firResult!.bands[1].w1, 10.0);
      expect(c.report(), isNot(contains('Spec column')));
    });

    test('a missed spec is reported with the taps that would meet it', () {
      final c = DesignController()
        ..numtaps = 11 // far too few for 50 dB across a 0.05 transition
        ..useSpec = true
        ..design();
      final report = c.report();
      expect(report, contains('MISSED'));
      expect(report, contains(RegExp(r'try about \d+ taps')));
    });

    test('a nonsense spec is an error, not a crash', () {
      final c = DesignController()..useSpec = true;
      c.rows[1].spec = '0';
      c.design();
      expect(c.error, contains('must be positive'));
      c.rows[1].spec = 'wide';
      c.design();
      expect(c.error, contains('must be a number'));
    });

    test('the plot floor reaches the spec line even when it is missed', () {
      final c = DesignController()
        ..numtaps = 11
        ..useSpec = true
        ..design();
      // The 50 dB line has to be on screen to be judged against.
      expect(c.magnitudeFloor(), lessThan(-50.0));
    });

    // Numbers taken from the Python implementation, running the same
    // conversion on the same preset: this is the check that the feature was
    // ported rather than reinvented.
    test('it agrees with the Python, tap for tap', () {
      final c = DesignController()
        ..useSpec = true
        ..design();
      expect(c.specDev![0], closeTo(0.028774368331997317, 1e-15));
      expect(c.specDev![1], closeTo(0.0031622776601683794, 1e-15));
      expect(c.firResult!.bands[1].w1, closeTo(9.099254216173158, 1e-13));

      const h = [
        0.0038549486311417907,
        0.0019519594126185032,
        -0.006351292207808438,
        -0.011889463234153878,
        -0.003917759629844967,
      ];
      for (var i = 0; i < h.length; i++) {
        expect(c.firResult!.h[i], closeTo(h[i], 1e-12), reason: 'h[$i]');
      }
      expect(c.firEffective!.bandDeviation[0],
          closeTo(0.027186682786510707, 1e-12));
      expect(c.firEffective!.bandDeviation[1],
          closeTo(0.0029877924212941146, 1e-12));
    });
  });

  group('grid density and the iteration cap', () {
    // Both are passed straight to the core, so the check that matters is that
    // the UI's numbers arrive there: same knob, same taps as the Python.
    test('the grid density reaches the design, and agrees with the Python', () {
      final coarse = DesignController()
        ..gridDensity = 4
        ..design();
      const h4 = [
        0.0036258774091951296,
        0.0014172084165768979,
        -0.006953525189358693,
      ];
      for (var i = 0; i < h4.length; i++) {
        expect(coarse.firResult!.h[i], closeTo(h4[i], 1e-12), reason: 'h[$i]');
      }
      expect(coarse.firResult!.delta.abs(), closeTo(0.02847828401918276, 1e-12));

      final fine = DesignController()
        ..gridDensity = 64
        ..design();
      const h64 = [
        0.0035409794435074977,
        0.0012736812383777672,
        -0.007049638272563637,
      ];
      for (var i = 0; i < h64.length; i++) {
        expect(fine.firResult!.h[i], closeTo(h64[i], 1e-12), reason: 'h[$i]');
      }

      // The coarse grid does not look between its points, so it settles for a
      // smaller equiripple deviation than the finer grid can find. That gap is
      // what the knob is for.
      expect(coarse.firResult!.delta.abs(),
          lessThan(fine.firResult!.delta.abs()));
    });

    test('a grid too coarse to search is reported, not crashed', () {
      final c = DesignController()
        ..gridDensity = 0
        ..design();
      expect(c.error, contains('raise the grid density'));
      expect(c.firResult, isNull);
    });

    test('the iteration cap stops the exchange and says so', () {
      final c = DesignController()
        ..maxiter = 2
        ..design();
      expect(c.error, isNull);
      expect(c.firResult!.iterations, 2);
      expect(c.firResult!.converged, isFalse);
      expect(c.firResult!.h[0], closeTo(0.004354720639138332, 1e-12));
      expect(c.report(), contains('did not converge'));
    });

    test('the default cap is high enough for the presets to converge', () {
      final c = DesignController();
      for (final p in DesignController.presets) {
        c.loadPreset(p);
        expect(c.firResult!.converged, isTrue, reason: p);
        expect(c.firResult!.iterations, lessThan(c.maxiter), reason: p);
      }
    });

    test('the preset pulldown follows what was loaded', () {
      final c = DesignController();
      expect(c.preset, 'Lowpass');
      c.loadPreset('Bandpass');
      expect(c.preset, 'Bandpass');
      expect(c.numtaps, 55);
    });
  });

  group('sloped bands and 1/f weighting', () {
    test('the Differentiator preset matches the Python, tap for tap', () {
      final c = DesignController()..loadPreset('Differentiator');
      expect(c.error, isNull);
      expect(c.numtaps, 33);
      expect(c.firResult!.ftype, 3); // antisymmetric, odd length
      expect(c.firResult!.converged, isTrue);
      expect(c.firResult!.iterations, 6);
      expect(c.rows.single.invF, isTrue);

      const h = [
        -0.003074070705384069,
        0.006957920019359631,
        -0.009940295708047997,
        0.014854180976300896,
      ];
      for (var i = 0; i < h.length; i++) {
        expect(c.firResult!.h[i], closeTo(h[i], 1e-12), reason: 'h[$i]');
      }
      expect(c.firResult!.delta.abs(), closeTo(0.018733594631326393, 1e-12));
      expect(c.firEffective!.bandDeviation[0],
          closeTo(0.008430117584097285, 1e-12));
    });

    test('the Raised-cosine band preset matches the Python', () {
      final c = DesignController()..loadPreset('Raised-cosine band');
      expect(c.error, isNull);
      expect(c.numtaps, 61);
      expect(c.firResult!.ftype, 1);
      expect(c.firResult!.iterations, 9);
      // The middle band is the sloped one.
      expect(c.rows[1].d1, '1');
      expect(c.rows[1].d2, '0');

      const h = [
        0.00013235963187126446,
        0.0012021514735708625,
        0.0007641640877811631,
        -0.0010685226581337733,
      ];
      for (var i = 0; i < h.length; i++) {
        expect(c.firResult!.h[i], closeTo(h[i], 1e-12), reason: 'h[$i]');
      }
      expect(c.firResult!.delta.abs(), closeTo(0.0020822356420450265, 1e-12));
    });

    test('1/f weighting is what makes the differentiator work', () {
      // The whole point: a constant weight equalises the absolute error, which
      // near DC is far larger than the target itself.  Relative error is what
      // matters, and 1/f is how it is asked for.
      DesignController build({required bool invF}) {
        final c = DesignController()..loadPreset('Differentiator');
        c.update(() => c.rows.single.invF = invF);
        return c;
      }

      // Measured off the response rather than the weighted error, so the
      // comparison does not depend on how the weight was applied.
      double worstRelative(DesignController c) {
        c.logScale = false;
        final m = c.magnitude();
        var worst = 0.0;
        for (var i = 0; i < m.f.length; i++) {
          if (m.f[i] < 0.01 || m.f[i] > 0.45) continue;
          final rel = (m.y[i] - 2 * math.pi * m.f[i]).abs() /
              (2 * math.pi * m.f[i]);
          if (rel > worst) worst = rel;
        }
        return worst;
      }

      expect(worstRelative(build(invF: true)),
          lessThan(worstRelative(build(invF: false))));
    });

    test('the desired value ramps between the two ends of a band', () {
      final c = DesignController();
      c.rows = [
        BandRow('0', '0.2', '1', '0.5', '1', '0.5'),
        BandRow('0.3', '0.5', '0', '0', '1', '50'),
      ];
      c.design();
      expect(c.error, isNull);
      final band = c.firResult!.bands[0];
      expect(band.d1, 1.0);
      expect(band.d2, 0.5);

      // Halfway across the first band the response should be near 0.75.
      final m = c.magnitude();
      c.logScale = false;
      final linear = c.magnitude();
      var atMid = 0.0;
      for (var i = 0; i < linear.f.length; i++) {
        if (linear.f[i] >= 0.1) {
          atMid = linear.y[i];
          break;
        }
      }
      expect(atMid, closeTo(0.75, 0.02));
      expect(m.f.length, linear.f.length);
    });

    test('every preset still designs, including the new two', () {
      final c = DesignController();
      for (final p in DesignController.presets) {
        c.loadPreset(p);
        expect(c.error, isNull, reason: p);
        expect(c.firResult!.converged, isTrue, reason: p);
      }
      expect(DesignController.presets, hasLength(8));
    });
  });

  group('the ripple-against-target plot', () {
    // On the full-scale magnitude plot half a dB of passband ripple is a line
    // thickness, so this one draws 20*log10(A/D) per band instead. The numbers
    // come from the Python running the same computation.
    test('the band curves and the ripple agree with the Python', () {
      final c = DesignController()..design();
      final res = c.firResult!;
      expect(c.liveBands, hasLength(1),
          reason: 'only the passband has a target to compare against');

      final band = c.liveBands.single;
      final curves = c.bandCurves(res, band);
      expect(curves.f.first, band.f1);
      expect(curves.f.last, band.f2);
      expect(curves.f, hasLength(240));

      double db(double x) =>
          20 * math.log(math.max(x.abs(), 1e-12)) / math.ln10;

      final up = db(1 + curves.tolerance[0] / curves.desired[0]);
      final down = db(math.max(1 - curves.tolerance[0] / curves.desired[0], 1e-12));
      expect(up, closeTo(0.246334563942, 1e-9));
      expect(down, closeTo(-0.253525111909, 1e-9));

      final w = Float64List(curves.f.length);
      for (var i = 0; i < w.length; i++) {
        w[i] = 2 * math.pi * curves.f[i] / res.fs;
      }
      final amp = fir.amplitudeResponse(res.h, w, res.symmetry);
      expect(db(amp[0] / curves.desired[0]), closeTo(-0.253525111909, 1e-9));
      expect(db(amp[120] / curves.desired[120]), closeTo(0.068314391232, 1e-9));
    });

    test('the tolerance follows the weight across a band', () {
      // A band whose weight ramps has a tolerance that is a curve, not a
      // rectangle: the exchange holds W*|D-A| equal, so where W is larger the
      // band is held tighter.
      final c = DesignController();
      c.rows = [
        BandRow('0', '0.2', '1', '1', '1', '0.5'),
        BandRow('0.25', '0.5', '0', '0', '10', '50'),
      ];
      c.design();
      final res = c.firResult!;
      final wide = c.bandCurves(res, res.bands[0]);
      final tight = c.bandCurves(res, res.bands[1]);
      // Ten times the weight is a tenth of the tolerance.
      expect(wide.tolerance.first / tight.tolerance.first, closeTo(10.0, 1e-9));
      // And delta itself is the weighted figure both are derived from.
      expect(wide.tolerance.first * res.bands[0].w1,
          closeTo(res.delta.abs(), 1e-12));
    });

    test('a band that targets zero is left out of it', () {
      final c = DesignController()..design();
      // The stopband targets zero, and 20*log10(A/0) says nothing.
      expect(c.firResult!.bands, hasLength(2));
      expect(c.liveBands, hasLength(1));
      expect(c.liveBands.single.target, 1.0);
    });

    test('a sloped band is sampled as a curve, not two endpoints', () {
      final c = DesignController()..loadPreset('Raised-cosine band');
      final sloped = c.firResult!.bands[1];
      expect(sloped.d1, 1.0);
      expect(sloped.d2, 0.0);
      final curves = c.bandCurves(c.firResult!, sloped);
      // The desired value ramps between the ends, so the middle is halfway.
      expect(curves.desired.first, closeTo(1.0, 1e-12));
      expect(curves.desired.last, closeTo(0.0, 1e-12));
      expect(curves.desired[119], closeTo(0.5, 0.01));
    });
  });

}
