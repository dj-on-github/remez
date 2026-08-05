/// Test signals, and what the filter does to them.
///
/// The response plots say what the filter does to a sine wave of every
/// frequency, one at a time and forever. That is the complete answer and it is
/// not always the legible one. A chirp swept through the passband and out the
/// other side shows the transition as a fade you can point at; a step shows the
/// overshoot and the ringing that linear phase buys with pre-echo; an impulse
/// is the taps themselves.
///
/// Where this earns its place is fixed point. The same signal goes through the
/// design in double precision and through the exact integer datapath, and the
/// difference between the two outputs is the quantization damage -- not
/// estimated from a noise model, but the actual samples, on the actual signal,
/// with the saturation and the rounding that will really happen.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// What to push through the filter.
enum TestSignal { impulse, step, chirp, tone, noise, square }

extension TestSignalName on TestSignal {
  String get label => switch (this) {
        TestSignal.impulse => 'impulse',
        TestSignal.step => 'step',
        TestSignal.chirp => 'chirp',
        TestSignal.tone => 'tone',
        TestSignal.noise => 'noise',
        TestSignal.square => 'square',
      };

  /// One line on what this one is for.
  String get purpose => switch (this) {
        TestSignal.impulse => 'the taps themselves',
        TestSignal.step => 'overshoot, ringing and pre-echo',
        TestSignal.chirp => 'the whole band swept, so the shape is visible',
        TestSignal.tone => 'one frequency, for gain and delay',
        TestSignal.noise => 'everything at once, for the noise floor',
        TestSignal.square => 'harmonics, and what happens to the ones removed',
      };
}

/// Generate [n] samples of [signal], at amplitude [level] of full scale.
///
/// Frequencies are in the sample rate's own units, so a chirp over a 48 kHz
/// design really does sweep 0 to 24 kHz.
Float64List generate(
  TestSignal signal,
  int n, {
  double fs = 1.0,
  double level = 0.7,
  double frequency = 0.05,
  int seed = 6413,
}) {
  final x = Float64List(n);
  final rng = math.Random(seed);
  switch (signal) {
    case TestSignal.impulse:
      if (n > 0) x[0] = level;
      break;
    case TestSignal.step:
      // A few samples of nothing first, so the edge is not at the very start
      // where the delay line is still filling and the plot has no baseline.
      for (var i = n ~/ 8; i < n; i++) {
        x[i] = level;
      }
      break;
    case TestSignal.chirp:
      // A linear sweep from DC to Nyquist. Instantaneous frequency is the
      // derivative of the phase, so a frequency rising linearly to 0.5 over
      // the run means a phase that goes as i squared.
      final span = math.max(n - 1, 1);
      for (var i = 0; i < n; i++) {
        x[i] = level * math.sin(2 * math.pi * 0.5 * i * i / (2 * span));
      }
      break;
    case TestSignal.tone:
      for (var i = 0; i < n; i++) {
        x[i] = level * math.sin(2 * math.pi * frequency / fs * i);
      }
      break;
    case TestSignal.noise:
      for (var i = 0; i < n; i++) {
        x[i] = level * (2 * rng.nextDouble() - 1);
      }
      break;
    case TestSignal.square:
      final period = math.max(2.0, fs / math.max(frequency, 1e-9));
      for (var i = 0; i < n; i++) {
        x[i] = (i % period) < period / 2 ? level : -level;
      }
      break;
  }
  return x;
}

/// Direct convolution: `y[n] = sum h[k] x[n-k]`, trimmed to the input length.
Float64List convolve(Float64List h, Float64List x) {
  final out = Float64List(x.length);
  for (var i = 0; i < x.length; i++) {
    var acc = 0.0;
    final upper = math.min(h.length - 1, i);
    for (var k = 0; k <= upper; k++) {
      acc += h[k] * x[i - k];
    }
    out[i] = acc;
  }
  return out;
}

/// What a run through the filter produced.
class SignalRun {
  const SignalRun({
    required this.input,
    required this.output,
    required this.fixedOutput,
    required this.clipped,
  });

  final Float64List input;

  /// The design computed exactly, in double precision.
  final Float64List output;

  /// The same signal through the integer datapath, scaled back to the input's
  /// units so the two can be drawn on one axis. Null in floating point.
  final Float64List? fixedOutput;

  /// How many samples the integer datapath had to clip.
  ///
  /// Worth its own number: clipping is not noise that averages out, it is the
  /// filter ceasing to be linear, and one clipped sample in a run is a
  /// headroom problem rather than a rounding one.
  final int clipped;

  bool get hasFixed => fixedOutput != null;

  /// Peak and RMS of the difference the integer arithmetic made.
  ({double peak, double rms})? get error {
    final q = fixedOutput;
    if (q == null) return null;
    var peak = 0.0;
    var sum = 0.0;
    for (var i = 0; i < output.length; i++) {
      final e = (q[i] - output[i]).abs();
      if (e > peak) peak = e;
      sum += e * e;
    }
    return (peak: peak, rms: math.sqrt(sum / math.max(output.length, 1)));
  }
}
