/// Phase and group delay: what the magnitude plot cannot show.
///
/// A magnitude response says how much of each frequency comes through, and
/// nothing at all about when. That second question is the whole difference
/// between the two families this program designs -- a linear-phase FIR delays
/// every frequency by the same (N-1)/2 samples, and an IIR does not, worst
/// around its band edges -- so it is worth a plot rather than a claim.
///
/// Group delay is computed from the derivative of the transfer function rather
/// than by differencing an unwrapped phase. Differencing needs the phase to be
/// unwrapped correctly first, which is exactly what fails near a zero on the
/// unit circle, where the phase steps by pi and no amount of unwrapping should
/// smooth it away.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'complex.dart';

/// The complex frequency response of `sum h[n] z^-n` at radian frequencies [w].
List<Complex> firFreqz(Float64List h, Float64List w) {
  return [
    for (final omega in w) _polySum(h, omega).value,
  ];
}

/// Group delay in samples of `sum c[n] z^-n`, at radian frequencies [w].
///
/// For `P(w) = sum c[n] e^-jwn` the phase derivative is `Im(P'/P)`, and one
/// factor of -j comes out of the differentiation, which leaves the delay as the
/// real part of a ratio the same loop can accumulate both halves of.
Float64List polyGroupDelay(List<double> c, Float64List w) {
  final out = Float64List(w.length);
  for (var i = 0; i < w.length; i++) {
    final s = _polySum(c, w[i]);
    out[i] = s.value.abs2 == 0.0
        ? double.nan
        : (s.weighted / s.value).re;
  }
  return out;
}

/// Group delay in samples of a cascade of second-order sections.
///
/// Sections multiply, so their phases add and so do their delays. Summing them
/// section by section also avoids convolving the cascade into one long
/// polynomial, which is what makes a high-order elliptic design lose its
/// coefficients to rounding.
Float64List sosGroupDelay(List<Float64List> sos, Float64List w) {
  final out = Float64List(w.length);
  for (final section in sos) {
    final b = [section[0], section[1], section[2]];
    final a = [section[3], section[4], section[5]];
    final numerator = polyGroupDelay(b, w);
    final denominator = polyGroupDelay(a, w);
    for (var i = 0; i < w.length; i++) {
      out[i] += numerator[i] - denominator[i];
    }
  }
  return out;
}

/// Remove the 2*pi steps an arctangent leaves behind.
///
/// Only those: a linear-phase filter's phase really does step by pi at every
/// zero on the unit circle, and flattening that would draw a filter that does
/// not exist.
Float64List unwrap(Float64List phase) {
  final out = Float64List(phase.length);
  var offset = 0.0;
  for (var i = 0; i < phase.length; i++) {
    if (i > 0) {
      final step = phase[i] - phase[i - 1];
      if (step > math.pi) {
        offset -= 2 * math.pi;
      } else if (step < -math.pi) {
        offset += 2 * math.pi;
      }
    }
    out[i] = phase[i] + offset;
  }
  return out;
}

/// `sum c[n] e^-jwn` and `sum n c[n] e^-jwn`, which the delay needs together.
({Complex value, Complex weighted}) _polySum(List<double> c, double w) {
  var value = Complex.zero;
  var weighted = Complex.zero;
  for (var n = 0; n < c.length; n++) {
    final term = Complex(math.cos(w * n), -math.sin(w * n)).scale(c[n]);
    value = value + term;
    weighted = weighted + term.scale(n.toDouble());
  }
  return (value: value, weighted: weighted);
}
