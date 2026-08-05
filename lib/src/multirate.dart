/// Half-band filters and polyphase decomposition.
///
/// Two ways of not doing arithmetic you do not have to do.
///
/// A **half-band** lowpass has every other tap at exactly zero, so half its
/// multiplies disappear. That is not a trick played on an ordinary design: it
/// falls out of the minimax problem itself. Ask the Remez exchange for a filter
/// that is 1 up to `fp` and 0 from `fs/2 - fp`, with the two bands weighted
/// equally, and the answer satisfies `A(w) + A(pi - w) = 1` identically -- if it
/// did not, averaging it with its own mirror would give an equally good filter,
/// and the minimax solution is unique. Written out in taps, that identity says
/// the centre tap is 1/2 and every tap an even number of places from it is
/// zero. So the design is the ordinary one; only the length is constrained.
///
/// A **polyphase** decomposition is what makes a rate change cost what it
/// should. Decimating by M throws away M-1 of every M outputs, so computing
/// them is wasted; splitting the filter into M sub-filters, each fed by every
/// Mth input sample, computes only the outputs that survive. Interpolating by L
/// is the mirror image: L-1 of every L inputs are zero, and each phase produces
/// one output from the samples that are not. Either way the multiplies per
/// input sample fall by the rate factor, and no arithmetic changes -- the
/// output is the same to the last bit.
library;

import 'dart:typed_data';

import 'fir_core.dart';

/// Whether [n] can be the length of a half-band filter.
///
/// It needs a centre tap, so it is odd; and the taps that vanish do so in pairs
/// either side of the centre, which leaves `(n-1)/2` odd. Both together are
/// `n = 4k + 3`.
bool isHalfBandLength(int n) => n >= 7 && n % 4 == 3;

/// The nearest length a half-band filter can have, never shorter than 7.
int nearestHalfBandLength(int n) {
  if (n <= 7) return 7;
  final k = ((n - 3) / 4).round();
  return 4 * k + 3;
}

/// The two bands whose minimax solution is a half-band filter.
///
/// [fp] is the passband edge; the stopband starts at its mirror about a quarter
/// of the sample rate. The weights are equal because that is the condition, not
/// a default -- weighting one band harder than the other gives a perfectly good
/// filter that is not a half-band one, and whose alternate taps are not zero.
List<Band> halfBandBands(double fp, {double fs = 1.0}) {
  final quarter = fs / 4;
  if (!(fp > 0) || fp >= quarter) {
    throw RemezError('a half-band passband edge must be between 0 and '
        '${_short(quarter)}, the quarter-rate point it is folded about');
  }
  return [
    Band(0.0, fp, 1.0, 1.0),
    Band(fs / 2 - fp, fs / 2, 0.0, 0.0),
  ];
}

/// Which taps of a length-[n] half-band filter are zero.
///
/// Every tap an even number of places from the centre, the centre itself
/// excepted -- it is the one that carries the half.
List<int> vanishingTaps(int n) {
  final m = (n - 1) ~/ 2;
  return [
    for (var k = 0; k < n; k++)
      if (k != m && (k - m).isEven) k
  ];
}

/// Set the taps that are mathematically zero to exactly zero.
///
/// The exchange leaves them at 1e-16 or so -- occasionally 1e-6, when the
/// design is asking for more than its length can give and has not converged
/// far. Snapping them is not an approximation in the other direction: zero is
/// the value the half-band identity gives them, and a tap that is stored as
/// 1e-16 still costs a multiplier.
Float64List snapHalfBand(Float64List h) {
  final out = Float64List.fromList(h);
  for (final k in vanishingTaps(h.length)) {
    out[k] = 0.0;
  }
  return out;
}

/// The largest tap that had to be snapped, as a fraction of the centre tap.
///
/// A number worth reporting rather than hiding: it says how far the design was
/// from the identity it is supposed to satisfy exactly, and so whether the
/// length is really enough for what was asked.
double halfBandResidual(Float64List h) {
  final m = (h.length - 1) ~/ 2;
  final centre = h[m].abs();
  var worst = 0.0;
  for (final k in vanishingTaps(h.length)) {
    if (h[k].abs() > worst) worst = h[k].abs();
  }
  return centre > 0 ? worst / centre : worst;
}

/// The [factor] polyphase components of [h].
///
/// Phase `p` is `h[p], h[p + factor], h[p + 2*factor], ...`, which is the
/// sub-filter that sees every [factor]th sample starting at `p`. Sub-filters
/// are padded to a common length so a hardware or software implementation can
/// treat them as one rectangular array; the padding is at the end, where a
/// zero tap costs nothing.
List<Float64List> polyphase(Float64List h, int factor) {
  if (factor < 1) {
    throw RemezError('a rate factor must be at least 1, got $factor');
  }
  final each = (h.length + factor - 1) ~/ factor;
  return [
    for (var p = 0; p < factor; p++)
      Float64List(each)
        ..setRange(
            0,
            ((h.length - p + factor - 1) ~/ factor).clamp(0, each),
            [for (var k = p; k < h.length; k += factor) h[k]])
  ];
}

/// How many multiplies a tap set actually needs.
///
/// Zero taps need none, and a linear-phase filter's symmetric pairs share one,
/// so the count is what the hardware or the inner loop really costs -- not the
/// length, which is what people quote.
({int taps, int nonzero, int multipliers}) tapCensus(
    Float64List h, Symmetry symmetry, bool folded) {
  var nonzero = 0;
  for (final v in h) {
    if (v != 0.0) nonzero++;
  }
  if (!folded) return (taps: h.length, nonzero: nonzero, multipliers: nonzero);

  // Folded, a pair either side of the centre shares a multiply, and the pair
  // only needs one if either of its two taps is non-zero.
  final n = h.length;
  var multipliers = 0;
  for (var k = 0; k < n ~/ 2; k++) {
    if (h[k] != 0.0 || h[n - 1 - k] != 0.0) multipliers++;
  }
  if (n.isOdd && symmetry == Symmetry.symmetric && h[n ~/ 2] != 0.0) {
    multipliers++;
  }
  return (taps: n, nonzero: nonzero, multipliers: multipliers);
}

String _short(double v) {
  final s = v.toStringAsPrecision(6);
  return s.contains('.')
      ? s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
      : s;
}
