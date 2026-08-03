/// Number formatting that matches Python's, so the generated files match.
///
/// The exports are compared against the Python tool's output, and both write
/// their numbers with `%g`-family formats. Dart has no `%g`, and the difference
/// is not cosmetic: `%g` chooses between fixed and exponential notation on the
/// exponent, then strips trailing zeros, so `0.0001` and `0.00001` come out in
/// different notations and `1.5` is three characters rather than six.
///
/// Nor is `toStringAsExponential` a shortcut to the digits. It rounds halves
/// away from zero where C and Python round them to even, and the values this
/// tool writes out are the ones where that shows: a fixed-point coefficient is
/// a dyadic rational, whose decimal expansion terminates, so a tie is not the
/// vanishing possibility it is for an arbitrary double. 2^-15 at ten
/// significant digits is exactly such a tie, and the two rules disagree on it.
/// So the digits here come from the exact expansion of the double, rounded
/// half-to-even.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// Python's `format(v, '.{precision}g')`.
///
/// With [space], a non-negative number is prefixed with a space so that columns
/// of signed values line up -- Python's `' '` sign flag, which the coefficient
/// tables use.
String formatG(double v, {int precision = 6, bool space = false}) {
  if (v.isNaN) return 'nan';
  final pad = space ? ' ' : '';
  if (v.isInfinite) return v.isNegative ? '-inf' : '${pad}inf';
  final sign = v.isNegative ? '-' : pad;
  if (v == 0.0) return '${sign}0';

  final p = precision < 1 ? 1 : precision;
  final d = _round(_exact(v.abs()), p);
  final exponent = d.pointPos - 1; // what %e would show

  if (exponent < -4 || exponent >= p) {
    final mantissa = d.digits.length == 1
        ? d.digits
        : _strip('${d.digits[0]}.${d.digits.substring(1)}');
    final magnitude = exponent.abs().toString().padLeft(2, '0');
    return '$sign$mantissa${exponent < 0 ? 'e-' : 'e+'}$magnitude';
  }

  // Fixed notation: place the point, padding with zeros on whichever side.
  final String body;
  if (d.pointPos <= 0) {
    body = '0.${'0' * -d.pointPos}${d.digits}';
  } else if (d.pointPos >= d.digits.length) {
    body = d.digits + '0' * (d.pointPos - d.digits.length);
  } else {
    body = '${d.digits.substring(0, d.pointPos)}.'
        '${d.digits.substring(d.pointPos)}';
  }
  return '$sign${_strip(body)}';
}

/// Decimal digits with an implied point: the value is `0.<digits> * 10^pointPos`.
class _Decimal {
  const _Decimal(this.digits, this.pointPos);
  final String digits;
  final int pointPos;
}

/// The *exact* decimal expansion of a positive finite double.
///
/// Every double is a dyadic rational, so its decimal expansion terminates:
/// `m * 2^e` is `m * 5^-e * 10^e` when e is negative, and a plain integer when
/// it is not. BigInt does the rest exactly.
_Decimal _exact(double v) {
  final bytes = ByteData(8)..setFloat64(0, v);
  final hi = bytes.getUint32(0);
  final lo = bytes.getUint32(4);
  final rawExponent = (hi >> 20) & 0x7FF;
  final rawMantissa =
      (BigInt.from(hi & 0xFFFFF) << 32) | BigInt.from(lo);

  BigInt m;
  int e;
  if (rawExponent == 0) {
    m = rawMantissa; // subnormal
    e = -1074;
  } else {
    m = rawMantissa | (BigInt.one << 52);
    e = rawExponent - 1075;
  }

  if (e >= 0) {
    final digits = (m << e).toString();
    return _Decimal(digits, digits.length);
  }
  final digits = (m * BigInt.from(5).pow(-e)).toString();
  return _Decimal(digits, digits.length + e);
}

/// Round to [p] significant digits, halves to even, as C and Python do.
_Decimal _round(_Decimal d, int p) {
  if (d.digits.length <= p) return d;
  final keep = d.digits.substring(0, p);
  final next = d.digits.codeUnitAt(p) - 0x30;
  var roundUp = next > 5;
  if (next == 5) {
    // A tie only if nothing follows; otherwise it is above the half. The tail
    // can be hundreds of digits long, so it is scanned rather than parsed.
    final exactHalf = !_anyNonZero(d.digits, p + 1);
    roundUp = exactHalf
        ? (keep.codeUnitAt(p - 1) - 0x30).isOdd // to even
        : true;
  }
  if (!roundUp) return _Decimal(keep, d.pointPos);

  final carried = (BigInt.parse(keep) + BigInt.one).toString();
  // 999 -> 1000: one more digit, so the point moves out with it.
  return carried.length > p
      ? _Decimal(carried.substring(0, p), d.pointPos + 1)
      : _Decimal(carried, d.pointPos);
}

bool _anyNonZero(String digits, int from) {
  for (var i = from; i < digits.length; i++) {
    if (digits.codeUnitAt(i) != 0x30) return true;
  }
  return false;
}

String _strip(String text) {
  if (!text.contains('.')) return text;
  var out = text;
  while (out.endsWith('0')) {
    out = out.substring(0, out.length - 1);
  }
  if (out.endsWith('.')) out = out.substring(0, out.length - 1);
  return out;
}

/// Python's `format(v, '.{digits}f')`.
///
/// Dart's `toStringAsFixed` rounds halves away from zero; this rounds to even.
String formatF(double v, int digits) {
  if (v.isNaN) return 'nan';
  if (v.isInfinite) return v.isNegative ? '-inf' : 'inf';
  final sign = v.isNegative ? '-' : '';
  final a = v.abs();
  if (a == 0.0) return digits > 0 ? '${sign}0.${'0' * digits}' : '${sign}0';

  final d = _exact(a);
  // Rounding to `digits` after the point is rounding to this many significant.
  final significant = d.pointPos + digits;
  final String zero = digits > 0 ? '${sign}0.${'0' * digits}' : '${sign}0';

  // Below half of the last place it keeps: nothing survives.
  if (significant < 0) return zero;

  final _Decimal r;
  if (significant == 0) {
    // Right on the boundary, where the whole value is what decides. Above a
    // half it carries into the last place kept; exactly a half rounds to even,
    // and the digit it would carry into is 0.
    final lead = d.digits.codeUnitAt(0) - 0x30;
    final up = lead > 5 || (lead == 5 && _anyNonZero(d.digits, 1));
    if (!up) return zero;
    r = _Decimal('1', 1 - digits);
  } else {
    r = _round(d, math.min(significant, d.digits.length));
  }

  if (r.digits == '0') return zero;
  var body = r.digits;
  var point = r.pointPos;
  if (point <= 0) {
    body = '${'0' * -point}$body';
    point = 0;
  }
  final whole = point == 0 ? '0' : body.substring(0, point);
  var fraction = body.substring(point);
  fraction = fraction.length >= digits
      ? fraction.substring(0, digits)
      : fraction + '0' * (digits - fraction.length);
  return digits > 0 ? '$sign$whole.$fraction' : '$sign$whole';
}
