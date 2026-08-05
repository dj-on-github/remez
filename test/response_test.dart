/// Phase and group delay, checked against what they are defined to be.
///
/// Group delay here is computed from the derivative of the transfer function,
/// not by differencing a phase. So the test that matters is that it agrees with
/// a phase difference wherever differencing is well behaved, and that the cases
/// with an exact answer -- a pure delay, a linear-phase FIR -- come out exact.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:remez/src/controller.dart';
import 'package:remez/src/fir_core.dart' as fir;
import 'package:remez/src/iir_core.dart' as iir;
import 'package:remez/src/response.dart';

Float64List grid(int n, {double from = 0.0, double to = math.pi}) {
  final w = Float64List(n);
  for (var i = 0; i < n; i++) {
    w[i] = from + (to - from) * i / (n - 1);
  }
  return w;
}

void main() {
  group('group delay', () {
    test('a pure delay of k samples has group delay k', () {
      for (final k in [0, 1, 5, 17]) {
        final h = List<double>.filled(k + 1, 0.0)..[k] = 1.0;
        final tau = polyGroupDelay(h, grid(9));
        for (final v in tau) {
          expect(v, closeTo(k.toDouble(), 1e-12));
        }
      }
    });

    test('a symmetric FIR delays every frequency by (N-1)/2', () {
      final c = DesignController()..design();
      final h = c.firEffective!.h;
      final tau = polyGroupDelay(h, grid(257));
      final expected = (h.length - 1) / 2;
      final response = firFreqz(h, grid(257));
      var peak = 0.0;
      for (final v in response) {
        if (v.abs > peak) peak = v.abs;
      }
      var checked = 0;
      for (var i = 0; i < tau.length; i++) {
        // The formula is 0/0 at a zero on the unit circle, which is what the
        // controller masks; away from those it should be exact.
        if (response[i].abs < peak * 1e-6) continue;
        expect(tau[i], closeTo(expected, 1e-6),
            reason: 'linear phase is the whole point of the symmetry');
        checked++;
      }
      expect(checked, greaterThan(200));
    });

    test('an antisymmetric FIR is linear phase too', () {
      final c = DesignController()
        ..loadPreset('Hilbert transformer');
      final h = c.firEffective!.h;
      final w = grid(129, from: 0.4, to: 2.6);
      final tau = polyGroupDelay(h, w);
      for (final v in tau) {
        expect(v, closeTo((h.length - 1) / 2, 1e-6));
      }
    });

    test('sections add: a cascade is the sum of its parts', () {
      final c = DesignController()
        ..mode = Mode.iir
        ..approximation = 'elliptic'
        ..design();
      final sos = c.iirEffective!.sos;
      expect(sos.length, greaterThan(1));
      final w = grid(64, from: 0.05, to: 1.2);
      final whole = sosGroupDelay(sos, w);
      final summed = Float64List(w.length);
      for (final section in sos) {
        final one = sosGroupDelay([section], w);
        for (var i = 0; i < w.length; i++) {
          summed[i] += one[i];
        }
      }
      for (var i = 0; i < w.length; i++) {
        expect(whole[i], closeTo(summed[i], 1e-9));
      }
    });

    test('it agrees with differencing the phase of an IIR', () {
      final c = DesignController()
        ..mode = Mode.iir
        ..approximation = 'chebyshev1'
        ..design();
      final sos = c.iirEffective!.sos;
      const step = 1e-6;
      for (final w in [0.2, 0.5, 0.9, 1.4, 2.2]) {
        final tau = sosGroupDelay(sos, Float64List.fromList([w]))[0];
        final around = iir.sosFreqz(
            sos, Float64List.fromList([w - step, w + step]));
        // Safe to difference directly: two points a microradian apart cannot
        // have wrapped between them.
        final slope = (around[1].arg - around[0].arg) / (2 * step);
        expect(tau, closeTo(-slope, 1e-4),
            reason: 'group delay is minus the slope of the phase at $w');
      }
    });

    test('an IIR delays its band edge more than its band centre', () {
      final c = DesignController()
        ..mode = Mode.iir
        ..approximation = 'elliptic'
        ..design();
      final sos = c.iirEffective!.sos;
      // wp is 0.2 of the sample rate, so the edge is at 0.4*pi radians.
      final tau = sosGroupDelay(
          sos, Float64List.fromList([0.05 * math.pi, 0.4 * math.pi]));
      expect(tau[1], greaterThan(tau[0]),
          reason: 'the classic reason to reach for an FIR instead');
    });
  });

  group('firFreqz', () {
    test('its magnitude is the amplitude response', () {
      final c = DesignController()..design();
      final res = c.firEffective!;
      final w = grid(201);
      final complex = firFreqz(res.h, w);
      final amplitude = fir.amplitudeResponse(res.h, w, res.symmetry);
      for (var i = 0; i < w.length; i++) {
        expect(complex[i].abs, closeTo(amplitude[i].abs(), 1e-9));
      }
    });
  });

  group('unwrap', () {
    test('it removes a 2*pi step and leaves a pi one alone', () {
      final wrapped = Float64List.fromList(
          [0.0, 1.0, 2.0, 3.0, -3.0, -2.0]); // steps over +pi at index 4
      final out = unwrap(wrapped);
      expect(out[3], closeTo(3.0, 1e-12));
      expect(out[4], closeTo(2 * math.pi - 3.0, 1e-12));
      expect(out[5], closeTo(2 * math.pi - 2.0, 1e-12));
    });

    test('a step of exactly pi is a real discontinuity, not a wrap', () {
      final out = unwrap(Float64List.fromList([0.0, math.pi, 0.0]));
      expect(out[1], closeTo(math.pi, 1e-12));
      expect(out[2], closeTo(0.0, 1e-12));
    });
  });

  group('controller.phaseAndDelay', () {
    test('an FIR comes back flat, with the nulls left out', () {
      final c = DesignController()..design();
      final r = c.phaseAndDelay(points: 512)!;
      expect(r.f.first, 0.0);
      expect(r.f.last, closeTo(c.fs / 2, 1e-12));

      final expected = (c.numtaps - 1) / 2;
      var drawn = 0, masked = 0;
      for (final v in r.delay) {
        if (v.isNaN) {
          masked++;
        } else {
          expect(v, closeTo(expected, 1e-5));
          drawn++;
        }
      }
      expect(drawn, greaterThan(400));
      expect(masked, lessThan(20),
          reason: 'only the exact nulls should drop out');
    });

    test('phase is in degrees and starts near zero', () {
      final c = DesignController()..design();
      final r = c.phaseAndDelay(points: 512)!;
      expect(r.phase.first.abs(), lessThan(1e-9));
      // 41 taps of delay over the whole band is a long way down in degrees.
      expect(r.phase.last, lessThan(-1000));
    });

    test('there is nothing to compare against in floating point', () {
      final c = DesignController()..design();
      expect(c.phaseAndDelay(ideal: true), isNull);
    });

    test('fixed point offers the design as well as the build', () {
      final c = DesignController()
        ..arithmetic = Arithmetic.fixed
        ..wordBits = 8
        ..design();
      expect(c.phaseAndDelay(ideal: true), isNotNull);
      // Rounding a symmetric filter rounds equal taps equally, so it stays
      // symmetric and stays exactly linear phase.
      for (final v in c.phaseAndDelay()!.delay) {
        if (v.isNaN) continue;
        expect(v, closeTo((c.numtaps - 1) / 2, 1e-5));
      }
    });

    test('an IIR is not flat', () {
      final c = DesignController()
        ..mode = Mode.iir
        ..approximation = 'elliptic'
        ..design();
      final delay = c.phaseAndDelay(points: 512)!.delay;
      final values = delay.where((v) => !v.isNaN).toList();
      final lo = values.reduce(math.min);
      final hi = values.reduce(math.max);
      expect(hi - lo, greaterThan(1.0),
          reason: 'a recursive filter does not delay every frequency alike');
    });
  });

  group('the toggles survive a save and reload', () {
    test('they round trip through the design file', () {
      final a = DesignController()
        ..showPhase = true
        ..showGroupDelay = false
        ..showZPlane = false
        ..design();
      final b = DesignController()..fromJson(a.toJson());
      expect(b.showPhase, isTrue);
      expect(b.showGroupDelay, isFalse);
      expect(b.showZPlane, isFalse);
    });

    test('a file that predates them keeps the defaults', () {
      final state = DesignController().toJson();
      (state['display'] as Map<String, dynamic>)
        ..remove('phase')
        ..remove('group_delay')
        ..remove('zplane');
      final c = DesignController()..fromJson(state);
      expect(c.showPhase, isFalse);
      expect(c.showGroupDelay, isTrue);
      expect(c.showZPlane, isTrue);
    });
  });
}
