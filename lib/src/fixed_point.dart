/// Fixed-point quantization of filter coefficients.
///
/// A filter designed in double precision has to be built out of finite-width
/// numbers. Each coefficient becomes a signed two's-complement integer of `B`
/// bits with an implied binary point `F` places from the right, so the value
/// actually used is
///
///     value = integer * 2^-F,   integer in [-2^(B-1), 2^(B-1) - 1]
///
/// which is the format usually written Q(B-1-F).F. Rounding to that lattice
/// perturbs the response: an FIR loses its equiripple property and its stopband
/// floor rises, and an IIR's poles move, which at worst pushes one outside the
/// unit circle.
///
/// The binary point is placed automatically by default, as far left as the
/// largest coefficient allows, since headroom that is not needed is resolution
/// given away.
///
/// This models *coefficient* quantization only. What the datapath does with the
/// numbers is in `datapath.dart`.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// Raised for a word length or binary point that cannot be used.
class FixedPointError implements Exception {
  FixedPointError(this.message);
  final String message;
  @override
  String toString() => 'FixedPointError: $message';
}

const int minBits = 2;

/// A double holds integers exactly up to 2^53.
const int maxBits = 53;

/// A set of coefficients rounded to a fixed-point format.
class Fixed {
  Fixed({
    required this.bits,
    required this.fracBits,
    required this.ints,
    required this.values,
    required this.saturated,
    required this.ideal,
  });

  final int bits;
  final int fracBits;

  /// The stored integers.
  final Int64List ints;

  /// What they represent: `ints * 2^-fracBits`.
  final Float64List values;

  /// How many had to be clipped to fit.
  final int saturated;

  /// The coefficients before rounding.
  final Float64List ideal;

  /// The gap between adjacent representable values.
  double get step => math.pow(2.0, -fracBits).toDouble();

  /// Bits left of the binary point, excluding the sign bit.
  int get intBits => bits - 1 - fracBits;

  String get qFormat => 'Q$intBits.$fracBits';

  int get minInt => -(1 << (bits - 1));
  int get maxInt => (1 << (bits - 1)) - 1;

  double get maxError {
    var worst = 0.0;
    for (var i = 0; i < ideal.length; i++) {
      final e = (values[i] - ideal[i]).abs();
      if (e > worst) worst = e;
    }
    return worst;
  }
}

int _checkBits(int bits) {
  if (bits < minBits || bits > maxBits) {
    throw FixedPointError(
        'word length must be $minBits..$maxBits bits, got $bits');
  }
  return bits;
}

/// Binary point placed as far left as the largest coefficient allows.
///
/// Every integer bit the coefficients do not need is a fractional bit given
/// away, so the scale is the largest power of two for which nothing saturates.
int autoFracBits(List<double> values, int bits) {
  _checkBits(bits);
  var peak = 0.0;
  for (final v in values) {
    if (v.abs() > peak) peak = v.abs();
  }
  if (peak == 0.0 || !peak.isFinite) return bits - 1;
  return (math.log(((1 << (bits - 1)) - 1) / peak) / math.ln2).floor();
}

/// Round [values] to a [bits]-wide signed fixed-point format.
///
/// [fracBits] places the binary point; null picks it with [autoFracBits].
/// Values that do not fit are clipped rather than allowed to wrap.
Fixed quantize(List<double> values, int bits, {int? fracBits}) {
  _checkBits(bits);
  final ideal = Float64List.fromList(values);
  final frac = fracBits ?? autoFracBits(values, bits);
  if (frac <= -1024 || frac >= 1024) {
    throw FixedPointError('fractional bits out of range: $frac');
  }

  final lo = -(1 << (bits - 1));
  final hi = (1 << (bits - 1)) - 1;
  final scale = math.pow(2.0, frac).toDouble();
  final ints = Int64List(ideal.length);
  final out = Float64List(ideal.length);
  var saturated = 0;
  for (var i = 0; i < ideal.length; i++) {
    final raw = (ideal[i] * scale).roundToDouble();
    var clipped = raw;
    if (raw < lo) {
      clipped = lo.toDouble();
    } else if (raw > hi) {
      clipped = hi.toDouble();
    }
    if (clipped != raw) saturated++;
    ints[i] = clipped.toInt();
    out[i] = ints[i] / scale;
  }
  return Fixed(
    bits: bits,
    fracBits: frac,
    ints: ints,
    values: out,
    saturated: saturated,
    ideal: ideal,
  );
}

/// The columns of a second-order section that are actually multipliers.
///
/// a0 is not one: the sections are normalised so it is 1 and nothing multiplies
/// by it, so it is neither quantized nor allowed to influence where the binary
/// point goes.
const List<int> sosLiveColumns = [0, 1, 2, 4, 5];

/// Quantize a biquad cascade, leaving each section's a0 at exactly one.
///
/// The five coefficients that are multipliers share one format across all
/// sections, which is what a cascade built from one multiplier block does.
Fixed quantizeSos(List<Float64List> sos, int bits, {int? fracBits}) {
  if (sos.isEmpty || sos.first.length != 6) {
    throw FixedPointError('expected sections of six coefficients');
  }
  final live = <double>[];
  for (final row in sos) {
    for (final c in sosLiveColumns) {
      live.add(row[c]);
    }
  }
  final frac = fracBits ?? autoFracBits(live, bits);
  final q = quantize(live, bits, fracBits: frac);

  final flatIdeal = Float64List(sos.length * 6);
  final values = Float64List(sos.length * 6);
  final ints = Int64List(sos.length * 6);
  final scale = math.pow(2.0, q.fracBits).toDouble();
  var k = 0;
  for (var s = 0; s < sos.length; s++) {
    for (var c = 0; c < 6; c++) {
      flatIdeal[s * 6 + c] = sos[s][c];
    }
    for (final c in sosLiveColumns) {
      values[s * 6 + c] = q.values[k];
      ints[s * 6 + c] = q.ints[k];
      k++;
    }
    values[s * 6 + 3] = 1.0;
    ints[s * 6 + 3] = scale.round();
  }
  return Fixed(
    bits: q.bits,
    fracBits: q.fracBits,
    ints: ints,
    values: values,
    saturated: q.saturated,
    ideal: flatIdeal,
  );
}

/// The quantized sections, back in `(nsections, 6)` shape.
List<Float64List> sosRows(Fixed fixed) {
  final rows = <Float64List>[];
  for (var s = 0; s * 6 < fixed.values.length; s++) {
    rows.add(Float64List.sublistView(fixed.values, s * 6, s * 6 + 6));
  }
  return rows;
}
