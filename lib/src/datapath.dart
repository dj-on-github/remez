/// The fixed-point datapath: what generated hardware actually computes.
///
/// One definition of the arithmetic, so that the RTL back-ends, the testbenches
/// they emit and the measured noise floor all agree on it.
///
/// Every value is a signed integer of `width` bits representing
/// `integer * 2^-frac`. Two operations build every filter:
///
///     mul(c, x)   exact product, plus half an LSB, shifted right by frac,
///                 saturated into width bits
///     add(a, b)   saturated into width bits
///
/// Neither wraps. Saturating adds are not associative, so the order they are
/// performed in is part of the specification: a linear accumulator chain and a
/// balanced tree give different answers once anything clips, and folding a
/// symmetric filter rounds once per *pair* instead of once per tap.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'fir_core.dart' show Symmetry;

/// Raised for a datapath that cannot be built or modelled.
class DatapathError implements Exception {
  DatapathError(this.message);
  final String message;
  @override
  String toString() => 'DatapathError: $message';
}

/// How the products are summed.
enum Structure {
  /// One adder per tap, in tap order: least area, longest combinational path.
  chain,

  /// Pairwise, ceil(log2 N) levels deep.
  tree,

  /// One multiplier reused over N cycles, accumulating in tap order --
  /// arithmetically the same as [chain].
  mac,
}

/// The structure a saved design or an export option names.
Structure structureFromName(String name) => switch (name) {
      'tree' => Structure.tree,
      'mac' => Structure.mac,
      _ => Structure.chain,
    };

extension StructureName on Structure {
  String get label => switch (this) {
        Structure.chain => 'chain',
        Structure.tree => 'tree',
        Structure.mac => 'mac',
      };
}

/// RMS of the noise used to measure a datapath, as a fraction of full scale.
const double noiseLevel = 0.25;

int _satInt(int value, int width) {
  final lo = -(1 << (width - 1));
  final hi = (1 << (width - 1)) - 1;
  return value < lo ? lo : (value > hi ? hi : value);
}

/// Exact product, rounded to nearest, saturated into the datapath.
int mul(int coef, int sample, int frac, int width) {
  var product = coef * sample;
  if (frac > 0) {
    product = (product + (1 << (frac - 1))) >> frac;
  }
  return _satInt(product, width);
}

/// Saturating add.
int add(int a, int b, int width) => _satInt(a + b, width);

/// One multiply of a FIR: which coefficient, which taps feed it, and the sign.
class FirTerm {
  const FirTerm(this.coefIndex, this.taps, this.sign);

  final int coefIndex;

  /// One tap, or the pair a folded multiply shares.
  final List<int> taps;

  /// +1 for a symmetric pre-add, -1 for the antisymmetric subtract.
  final int sign;
}

/// The multiplies a FIR needs.
///
/// Unfolded this is one per tap. Folded, a symmetric pair shares a multiply,
/// and an antisymmetric filter subtracts instead, its zero centre tap dropping
/// out altogether.
List<FirTerm> firTerms(int numtaps, Symmetry symmetry, bool folded) {
  if (!folded) {
    return [for (var k = 0; k < numtaps; k++) FirTerm(k, [k], 1)];
  }
  final anti = symmetry == Symmetry.antisymmetric;
  final pairs = numtaps ~/ 2;
  final terms = [
    for (var k = 0; k < pairs; k++)
      FirTerm(k, [k, numtaps - 1 - k], anti ? -1 : 1)
  ];
  if (numtaps.isOdd && !anti) {
    terms.add(FirTerm(numtaps ~/ 2, [numtaps ~/ 2], 1));
  }
  return terms;
}

int termCount(int numtaps, Symmetry symmetry, bool folded) =>
    firTerms(numtaps, symmetry, folded).length;

int treeLevels(int n) {
  var levels = 0;
  while (n > 1) {
    n = (n + 1) ~/ 2;
    levels++;
  }
  return levels;
}

/// Clocks from a strobe on din_strb to the one on dout_strb.
int latency(int numtaps, Symmetry symmetry, Structure structure, bool folded,
    {bool iir = false}) {
  if (iir) return 1;
  final n = termCount(numtaps, symmetry, folded);
  switch (structure) {
    case Structure.chain:
      return 1;
    case Structure.tree:
      return 1 + treeLevels(n);
    case Structure.mac:
      return n + 2;
  }
}

/// Multipliers, adders and delay elements the structure instantiates.
class Resources {
  const Resources(this.multipliers, this.adders, this.delays, this.pipeline);
  final int multipliers;
  final int adders;
  final int delays;
  final int pipeline;
}

Resources resources(int numtaps, Symmetry symmetry, Structure structure,
    bool folded, {int sections = 1, bool iir = false}) {
  if (iir) {
    return Resources(5 * sections, 4 * sections, 2 * sections, 0);
  }
  final n = termCount(numtaps, symmetry, folded);
  final centre = folded && numtaps.isOdd && symmetry == Symmetry.symmetric;
  final pre = folded ? n - (centre ? 1 : 0) : 0;
  if (structure == Structure.mac) {
    return Resources(1, 1 + (folded ? 1 : 0), numtaps, 0);
  }
  return Resources(n, (n - 1) + pre, numtaps - 1,
      structure == Structure.tree ? treeLevels(n) : 0);
}

// ---------------------------------------------------------------------------
// simulation
// ---------------------------------------------------------------------------

int _reduce(List<int> values, int width, Structure structure) {
  if (structure == Structure.tree) {
    var level = List<int>.from(values);
    while (level.length > 1) {
      final next = <int>[];
      for (var i = 0; i + 1 < level.length; i += 2) {
        next.add(add(level[i], level[i + 1], width));
      }
      if (level.length.isOdd) next.add(level.last); // an odd one out passes on
      level = next;
    }
    return level.first;
  }
  // chain and mac both accumulate in order
  var acc = values.first;
  for (var i = 1; i < values.length; i++) {
    acc = add(acc, values[i], width);
  }
  return acc;
}

/// Run integer samples through the modelled FIR datapath, exactly.
List<int> simulateFir(
  List<int> taps,
  List<int> samples,
  int frac,
  int wcoef,
  int headroom, {
  Structure structure = Structure.chain,
  bool folded = false,
  Symmetry symmetry = Symmetry.symmetric,
}) {
  final width = wcoef + headroom;
  final n = taps.length;
  final terms = firTerms(n, symmetry, folded);
  final line = List<int>.filled(n, 0);
  final out = <int>[];
  final products = List<int>.filled(terms.length, 0);

  for (final raw in samples) {
    for (var k = n - 1; k > 0; k--) {
      line[k] = line[k - 1];
    }
    line[0] = _satInt(raw, width);

    for (var t = 0; t < terms.length; t++) {
      final term = terms[t];
      int operand;
      if (term.taps.length == 1) {
        operand = line[term.taps[0]];
      } else {
        // The pre-adder is one bit wider than the datapath and does not
        // saturate: it sums two samples that may each be at full scale, and
        // clipping that sum would throw away signal rather than round it.
        operand = line[term.taps[0]] + term.sign * line[term.taps[1]];
      }
      products[t] = mul(taps[term.coefIndex], operand, frac, width);
    }
    out.add(_reduce(products, width, structure));
  }
  return out;
}

/// Run integer samples through a cascade of biquads, transposed direct form II.
///
/// Each section is `(b0, b1, b2, a1, a2)`; a0 is 1 and nothing multiplies by
/// it, and a1/a2 are given as designed and negated here.
List<int> simulateIir(
  List<List<int>> sections,
  List<int> samples,
  int frac,
  int wcoef,
  int headroom,
) {
  final width = wcoef + headroom;
  final state = [for (var _ in sections) [0, 0]];
  final out = <int>[];

  for (final raw in samples) {
    var value = _satInt(raw, width);
    for (var i = 0; i < sections.length; i++) {
      final s = sections[i];
      final b0 = s[0], b1 = s[1], b2 = s[2], a1 = s[3], a2 = s[4];
      final s1 = state[i][0], s2 = state[i][1];
      final y = add(mul(b0, value, frac, width), s1, width);
      final u1 = add(mul(b1, value, frac, width),
          mul(_satInt(-a1, wcoef), y, frac, width), width);
      final s1Next = add(u1, s2, width);
      final s2Next = add(mul(b2, value, frac, width),
          mul(_satInt(-a2, wcoef), y, frac, width), width);
      state[i][0] = s1Next;
      state[i][1] = s2Next;
      value = y;
    }
    out.add(value);
  }
  return out;
}

// ---------------------------------------------------------------------------
// measured noise floor
// ---------------------------------------------------------------------------

/// What a measurement of the datapath's arithmetic noise found.
class NoiseFloor {
  NoiseFloor(this.frequency, this.noiseDb, this.rmsLsb);

  /// Cycles per sample.
  final Float64List frequency;

  /// Noise amplitude in dB relative to the input.
  final Float64List noiseDb;

  /// RMS of the error at the output, in LSB.
  final double rmsLsb;

  double get medianDb {
    final sorted = Float64List.fromList(noiseDb)..sort();
    return sorted[sorted.length ~/ 2];
  }
}

/// Measure the arithmetic noise the datapath adds, as a spectrum.
///
/// White noise goes in, and the integer datapath's output is compared against
/// the same filter computed exactly. The difference is purely what the
/// arithmetic did, so its spectrum can be measured with no dynamic range
/// problem: taking the output spectrum directly would measure the analysis
/// window's sidelobes instead, since a passband sixty dB above a stopband leaks
/// into it.
///
/// [exact] is called with the float input and must return the float output of
/// the ideal-arithmetic filter.
NoiseFloor noiseResponse(
  List<int> Function(List<int> samples) run,
  Float64List Function(Float64List samples) exact,
  int frac,
  int wcoef,
  int headroom, {
  int? length,
  int seed = 12345,
}) {
  if (frac < 0) {
    throw DatapathError('the binary point is inside the integer part, so this '
        'is not a datapath that can be measured; give the coefficients more '
        'bits');
  }
  const segment = 512;
  final n = math.max(length ?? 1 << 14, 8 * segment);

  final rng = math.Random(seed);
  final full = (1 << (wcoef + headroom - 1)) - 1;
  final xi = List<int>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    // Box-Muller, so the drive is Gaussian rather than uniform.
    final u1 = math.max(rng.nextDouble(), 1e-12);
    final u2 = rng.nextDouble();
    final g = math.sqrt(-2.0 * math.log(u1)) * math.cos(2 * math.pi * u2);
    xi[i] = (g * noiseLevel * full).round().clamp(-full, full);
  }

  final got = run(xi);
  final xf = Float64List(n);
  for (var i = 0; i < n; i++) {
    xf[i] = xi[i].toDouble();
  }
  final want = exact(xf);
  if (want.length != got.length) {
    throw DatapathError('the exact reference must return one sample per input');
  }
  for (final v in want) {
    if (!v.isFinite) {
      throw DatapathError("the filter's own response overflows, so there is no "
          'noise floor to measure; the design itself needs looking at first');
    }
  }

  final skip = math.min(n ~/ 4, 8 * segment);
  final error = Float64List(n - skip);
  final drive = Float64List(n - skip);
  var sumSquares = 0.0;
  for (var i = skip; i < n; i++) {
    error[i - skip] = got[i].toDouble() - want[i];
    drive[i - skip] = xf[i];
    sumSquares += error[i - skip] * error[i - skip];
  }

  final pee = _welch(error, segment);
  final pxx = _welch(drive, segment);
  final freq = Float64List(pee.length);
  final db = Float64List(pee.length);
  for (var i = 0; i < pee.length; i++) {
    freq[i] = i / segment;
    final ratio = math.sqrt(pee[i] / pxx[i]);
    db[i] = 20.0 * math.log(math.max(ratio, 1e-30)) / math.ln10;
  }
  return NoiseFloor(freq, db, math.sqrt(sumSquares / error.length));
}

/// Averaged periodogram, Blackman-Harris window, half-overlapping.
///
/// The window's -92 dB sidelobes mean a loud band cannot leak into a quiet one
/// at any dynamic range this tool can produce.
Float64List _welch(Float64List x, int segment) {
  final window = Float64List(segment);
  for (var i = 0; i < segment; i++) {
    final t = 2 * math.pi * i / segment;
    window[i] = 0.35875 -
        0.48829 * math.cos(t) +
        0.14128 * math.cos(2 * t) -
        0.01168 * math.cos(3 * t);
  }
  final bins = segment ~/ 2 + 1;
  final acc = Float64List(bins);
  var count = 0;
  final step = segment ~/ 2;
  final piece = Float64List(segment);
  for (var start = 0; start + segment <= x.length; start += step) {
    for (var i = 0; i < segment; i++) {
      piece[i] = x[start + i] * window[i];
    }
    // A direct DFT of one 512-point segment; measuring is not the hot path.
    for (var k = 0; k < bins; k++) {
      var re = 0.0, im = 0.0;
      for (var i = 0; i < segment; i++) {
        final angle = -2 * math.pi * k * i / segment;
        re += piece[i] * math.cos(angle);
        im += piece[i] * math.sin(angle);
      }
      acc[k] += re * re + im * im;
    }
    count++;
  }
  if (count > 0) {
    for (var i = 0; i < bins; i++) {
      acc[i] /= count;
    }
  }
  return acc;
}

/// What a measurement sees: the response with the noise added in power.
///
/// The two are uncorrelated, so they add as powers rather than amplitudes,
/// which is why a stopband thirty dB below the floor is not there to be
/// measured.
double effectiveResponse(double magDb, double noiseDb) =>
    10.0 *
    math.log(math.pow(10.0, magDb / 10.0) + math.pow(10.0, noiseDb / 10.0)) /
    math.ln10;
