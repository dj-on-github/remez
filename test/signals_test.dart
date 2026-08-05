/// Test signals and what the filter does to them.
///
/// The point of the feature is that the fixed-point trace is the *actual*
/// datapath and not a model of it, so that is what the tests check: the same
/// integers the RTL would compute, and a clipped-sample count that reacts to
/// headroom rather than to rounding.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:remez/src/controller.dart';
import 'package:remez/src/datapath.dart';
import 'package:remez/src/signals.dart';

void main() {
  group('generating', () {
    test('an impulse is one sample and then nothing', () {
      final x = generate(TestSignal.impulse, 64, level: 0.7);
      expect(x[0], 0.7);
      expect(x.skip(1).every((v) => v == 0.0), isTrue);
    });

    test('a step starts at zero so there is a baseline to see', () {
      final x = generate(TestSignal.step, 80, level: 0.5);
      expect(x[0], 0.0);
      expect(x.last, 0.5);
      // Exactly one edge, not several.
      var edges = 0;
      for (var i = 1; i < x.length; i++) {
        if (x[i] != x[i - 1]) edges++;
      }
      expect(edges, 1);
    });

    test('a chirp really does sweep from DC to Nyquist', () {
      final x = generate(TestSignal.chirp, 2000, level: 1.0);
      // Count sign changes in the first and last tenth: frequency rising
      // linearly means the last stretch should alternate far more often.
      int crossings(int from, int to) {
        var n = 0;
        for (var i = from + 1; i < to; i++) {
          if ((x[i] < 0) != (x[i - 1] < 0)) n++;
        }
        return n;
      }

      expect(crossings(0, 200), lessThan(12));
      expect(crossings(1800, 2000), greaterThan(150),
          reason: 'near Nyquist it should cross almost every sample');
    });

    test('a tone is at the frequency asked for', () {
      final x = generate(TestSignal.tone, 1000, fs: 1.0, frequency: 0.05);
      var crossings = 0;
      for (var i = 1; i < x.length; i++) {
        if ((x[i] < 0) != (x[i - 1] < 0)) crossings++;
      }
      // Two crossings per cycle, 0.05 cycles per sample, 1000 samples.
      expect(crossings, closeTo(100, 3));
    });

    test('a tone follows the sample rate', () {
      final a = generate(TestSignal.tone, 500, fs: 1.0, frequency: 0.1);
      final b = generate(TestSignal.tone, 500, fs: 48000, frequency: 4800);
      for (var i = 0; i < 500; i++) {
        expect(b[i], closeTo(a[i], 1e-12));
      }
    });

    test('noise is bounded and not all one sign', () {
      final x = generate(TestSignal.noise, 500, level: 0.8);
      expect(x.every((v) => v.abs() <= 0.8), isTrue);
      expect(x.where((v) => v > 0).length, greaterThan(150));
      expect(x.where((v) => v < 0).length, greaterThan(150));
    });

    test('noise is the same noise every time', () {
      expect(generate(TestSignal.noise, 50),
          generate(TestSignal.noise, 50),
          reason: 'a trace that shimmers on every rebuild is unreadable');
    });

    test('a square wave only takes two values', () {
      final x = generate(TestSignal.square, 200, fs: 1.0, frequency: 0.05);
      expect(x.toSet().length, 2);
    });
  });

  group('convolve', () {
    test('an impulse response is the taps', () {
      final h = Float64List.fromList([0.5, -0.25, 0.125]);
      final x = Float64List(8)..[0] = 1.0;
      final y = convolve(h, x);
      expect(y[0], 0.5);
      expect(y[1], -0.25);
      expect(y[2], 0.125);
      expect(y.skip(3).every((v) => v == 0.0), isTrue);
    });

    test('it returns one sample per sample in', () {
      expect(convolve(Float64List(41), Float64List(100)), hasLength(100));
    });
  });

  group('through the controller', () {
    test('nothing runs until it is asked for', () {
      final c = DesignController()..design();
      expect(c.signalRun(), isNull);
    });

    test('the float output is the filter applied to the input', () {
      final c = DesignController()
        ..showSignal = true
        ..testSignal = TestSignal.chirp
        ..signalLength = 300
        ..design();
      final run = c.signalRun()!;
      expect(run.input, hasLength(300));
      expect(run.output, hasLength(300));
      expect(run.fixedOutput, isNull, reason: 'floating point has no datapath');

      final want = convolve(c.firEffective!.h, run.input);
      for (var i = 0; i < want.length; i++) {
        expect(run.output[i], closeTo(want[i], 1e-12));
      }
    });

    test('an impulse comes out as the taps', () {
      final c = DesignController()
        ..showSignal = true
        ..testSignal = TestSignal.impulse
        ..signalLength = 128
        ..design();
      final run = c.signalRun()!;
      final h = c.firEffective!.h;
      for (var i = 0; i < h.length; i++) {
        expect(run.output[i], closeTo(h[i] * run.input[0], 1e-12));
      }
    });

    test('the fixed trace is the datapath, integer for integer', () {
      final c = DesignController()
        ..showSignal = true
        ..testSignal = TestSignal.noise
        ..signalLength = 256
        ..arithmetic = Arithmetic.fixed
        ..wordBits = 12
        ..design();
      final run = c.signalRun()!;
      expect(run.hasFixed, isTrue);

      final q = c.fixed!;
      final scale = math.pow(2.0, q.fracBits).toDouble();
      final limit = (1 << (q.bits + c.headroom - 1)) - 1;
      final samples = [
        for (final v in run.input) (v * scale).round().clamp(-limit - 1, limit)
      ];
      final want = simulateFir(
          q.ints.toList(), samples, q.fracBits, q.bits, c.headroom,
          symmetry: c.symmetry);
      for (var i = 0; i < want.length; i++) {
        expect(run.fixedOutput![i], want[i] / scale,
            reason: 'sample $i must be the datapath value exactly');
      }
    });

    test('the structure the export would use is the one that runs', () {
      Float64List through(String structure) => (DesignController()
            ..showSignal = true
            ..testSignal = TestSignal.step
            ..signalLength = 200
            ..arithmetic = Arithmetic.fixed
            ..wordBits = 10
            ..headroom = 0
            ..structure = structure
            ..design())
          .signalRun()!
          .fixedOutput!;

      // Saturating adds are only non-associative once something saturates,
      // so this is driven with no headroom at all: with room to spare the two
      // structures agree exactly, which is itself the correct answer.
      final a = through('chain');
      final b = through('tree');
      var differ = 0;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) differ++;
      }
      expect(differ, greaterThan(0),
          reason: 'the plot should follow the structure that was chosen');
    });

    test('the error summary is the gap between the two paths', () {
      final c = DesignController()
        ..showSignal = true
        ..arithmetic = Arithmetic.fixed
        ..wordBits = 10
        ..design();
      final run = c.signalRun()!;
      final error = run.error!;
      expect(error.rms, greaterThan(0));
      expect(error.peak, greaterThanOrEqualTo(error.rms));
      // Ten-bit coefficients cannot be more than a few LSB out.
      expect(error.peak, lessThan(0.1));
    });

    test('more bits means less difference', () {
      double gap(int bits) {
        final c = DesignController()
          ..showSignal = true
          ..testSignal = TestSignal.noise
          ..arithmetic = Arithmetic.fixed
          ..wordBits = bits
          ..design();
        return c.signalRun()!.error!.rms;
      }

      expect(gap(16), lessThan(gap(10)));
      expect(gap(10), lessThan(gap(8)));
    });

    test('clipping is counted, and headroom is what fixes it', () {
      DesignController at(int headroom) => DesignController()
        ..showSignal = true
        ..testSignal = TestSignal.step
        ..signalLength = 256
        ..arithmetic = Arithmetic.fixed
        ..wordBits = 12
        ..headroom = headroom
        ..design();
      // With no headroom a step at 0.7 of full scale drives the accumulator
      // past what the datapath can hold.
      expect(at(0).signalRun()!.clipped, greaterThan(0));
      expect(at(4).signalRun()!.clipped, 0);
    });

    test('an IIR runs through its cascade', () {
      final c = DesignController()
        ..mode = Mode.iir
        ..showSignal = true
        ..testSignal = TestSignal.step
        ..arithmetic = Arithmetic.fixed
        ..wordBits = 14
        ..design();
      final run = c.signalRun()!;
      expect(run.hasFixed, isTrue);
      // A lowpass settles to its DC gain, which is one.
      expect(run.output.last, closeTo(run.input.last, 0.02));
    });

    test('the answer is cached until the next design', () {
      final c = DesignController()
        ..showSignal = true
        ..design();
      expect(identical(c.signalRun(), c.signalRun()), isTrue);
      final before = c.signalRun();
      c.update(() => c.testSignal = TestSignal.step);
      expect(identical(c.signalRun(), before), isFalse);
    });

    test('the settings round trip through the design file', () {
      final a = DesignController()
        ..showSignal = true
        ..testSignal = TestSignal.square
        ..signalFrequency = '0.02'
        ..signalLength = 1024
        ..design();
      final b = DesignController()..fromJson(a.toJson());
      expect(b.showSignal, isTrue);
      expect(b.testSignal, TestSignal.square);
      expect(b.signalFrequency, '0.02');
      expect(b.signalLength, 1024);
    });
  });
}
