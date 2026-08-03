/// Just enough complex arithmetic for the IIR designs.
///
/// Dart has no complex type and the designs need only a handful of operations,
/// so this is a small immutable value type rather than a dependency.
library;

import 'dart:math' as math;

class Complex {
  const Complex(this.re, [this.im = 0.0]);

  static const Complex zero = Complex(0.0, 0.0);
  static const Complex one = Complex(1.0, 0.0);
  static const Complex i = Complex(0.0, 1.0);

  final double re;
  final double im;

  Complex operator +(Complex o) => Complex(re + o.re, im + o.im);
  Complex operator -(Complex o) => Complex(re - o.re, im - o.im);
  Complex operator -() => Complex(-re, -im);

  Complex operator *(Complex o) =>
      Complex(re * o.re - im * o.im, re * o.im + im * o.re);

  Complex operator /(Complex o) {
    // Smith's method: divide through by the larger part so neither the
    // numerator nor the denominator overflows on the way.
    //
    // The reciprocal is taken once and multiplied in, rather than dividing by
    // `d` twice.  That is a rounding worse -- and it is deliberate: it is what
    // numpy's `nc_quot` does, and a filter's second-order sections are ordered
    // by comparing pole magnitudes that are equal in exact arithmetic, so the
    // order is decided by the last bit.  Dividing twice is the more accurate
    // form and puts this port's cascades in a different order from the
    // implementation it is checked against.  Do not "fix" this without
    // regenerating the reference designs.
    if (o.re.abs() >= o.im.abs()) {
      final r = o.im / o.re;
      final scale = 1.0 / (o.re + o.im * r);
      return Complex((re + im * r) * scale, (im - re * r) * scale);
    }
    final r = o.re / o.im;
    final scale = 1.0 / (o.im + o.re * r);
    return Complex((re * r + im) * scale, (im * r - re) * scale);
  }

  Complex scale(double k) => Complex(re * k, im * k);

  double get abs => _hypot(re, im);
  double get abs2 => re * re + im * im;
  double get arg => math.atan2(im, re);

  Complex get conjugate => Complex(re, -im);

  Complex get sqrt {
    if (re == 0.0 && im == 0.0) return zero;
    final m = math.sqrt((abs + re.abs()) / 2.0);
    if (re >= 0) {
      return Complex(m, im / (2 * m));
    }
    final n = im < 0 ? -m : m;
    return Complex(im.abs() / (2 * m), n);
  }

  Complex get exp {
    final e = math.exp(re);
    return Complex(e * math.cos(im), e * math.sin(im));
  }

  bool get isFinite => re.isFinite && im.isFinite;

  @override
  String toString() => '${re.toStringAsFixed(9)}'
      '${im < 0 ? '-' : '+'}${im.abs().toStringAsFixed(9)}j';
}

double _hypot(double a, double b) {
  a = a.abs();
  b = b.abs();
  if (a == 0) return b;
  if (b == 0) return a;
  if (a < b) {
    final t = a;
    a = b;
    b = t;
  }
  final r = b / a;
  return a * math.sqrt(1 + r * r);
}

/// The two roots of `a z^2 + b z + c`, complex when the discriminant is.
List<Complex> quadraticRoots(double a, double b, double c) {
  if (a == 0.0) {
    if (b == 0.0) return const [];
    return [Complex(-c / b)];
  }
  final disc = b * b - 4 * a * c;
  if (disc >= 0) {
    final root = math.sqrt(disc);
    // The numerically stable pairing: form the large root first.
    final q = -0.5 * (b + (b < 0 ? -root : root));
    if (q == 0.0) return [const Complex(0.0), const Complex(0.0)];
    return [Complex(q / a), Complex(c / q)];
  }
  final root = math.sqrt(-disc);
  return [
    Complex(-b / (2 * a), root / (2 * a)),
    Complex(-b / (2 * a), -root / (2 * a)),
  ];
}
