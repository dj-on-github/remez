/// Classical IIR filter design: analog prototypes and the bilinear transform.
///
/// The recursive counterpart to `fir_core.dart`, and a port of the Python
/// `iir_core.py`, which it is checked against. Where the Remez exchange
/// searches numerically for the best polynomial, these are closed form: a
/// normalised analog lowpass prototype with a known pole-zero pattern is
/// transformed to the wanted band, then mapped to the unit disc.
///
///     approximation   passband        stopband        equiripple where
///     --------------  --------------  --------------  ------------------
///     Butterworth     maximally flat  maximally flat  nowhere
///     Chebyshev I     equiripple      monotonic       passband
///     Chebyshev II    monotonic       equiripple      stopband
///     Elliptic        equiripple      equiripple      both
///
/// The elliptic case is the interesting one: it is the minimax solution of the
/// same approximation problem the Remez exchange solves, but over rational
/// rather than polynomial functions, and it gives the lowest order for a given
/// specification. Its poles and zeros come from Jacobi elliptic functions,
/// evaluated here by the descending Landen transformation following Orfanidis,
/// *Lecture Notes on Elliptic Filter Design* (2006).
///
/// Band edges are pre-warped by `w = 2 fs tan(pi f / fs)` before the analog
/// design, so the digital filter has its edges at exactly the frequencies asked
/// for.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'complex.dart';

/// Raised when an IIR request is inconsistent.
class IIRError implements Exception {
  IIRError(this.message);
  final String message;
  @override
  String toString() => 'IIRError: $message';
}

const List<String> responses = ['lowpass', 'highpass', 'bandpass', 'bandstop'];
const List<String> approximations = [
  'butterworth',
  'chebyshev1',
  'chebyshev2',
  'elliptic'
];

/// Zeros, poles and gain of an analog prototype or a digital filter.
class Zpk {
  Zpk(this.z, this.p, this.k);
  final List<Complex> z;
  final List<Complex> p;
  final double k;
}

/// Everything the design produced, for both use and display.
class IIRResult {
  IIRResult({
    required this.z,
    required this.p,
    required this.k,
    required this.sos,
    required this.order,
    required this.degree,
    required this.response,
    required this.approximation,
    required this.fs,
    required this.wp,
    required this.ws,
    required this.rp,
    required this.rs,
    required this.wn,
    required this.orderEstimate,
    required this.autoOrder,
    required this.achievedRp,
    required this.achievedRs,
    required this.maxPoleRadius,
    required this.stable,
    required this.passbandRanges,
    required this.stopbandRanges,
  });

  final List<Complex> z;
  final List<Complex> p;
  final double k;

  /// `(nsections, 6)`: b0 b1 b2 a0 a1 a2.
  final List<Float64List> sos;

  /// Prototype order.
  final int order;

  /// Order of the digital filter itself.
  final int degree;
  final String response;
  final String approximation;
  final double fs;

  /// Requested band edges.
  final List<double> wp;
  final List<double> ws;

  /// Requested passband ripple and stopband attenuation, dB.
  final double rp;
  final double rs;

  /// Critical frequencies actually placed.
  final List<double> wn;
  final int orderEstimate;
  final bool autoOrder;

  /// Peak-to-peak passband ripple, dB, and worst stopband attenuation, dB.
  final double achievedRp;
  final double achievedRs;

  final double maxPoleRadius;
  final bool stable;
  final List<List<double>> passbandRanges;
  final List<List<double>> stopbandRanges;

  /// The index of the first section with nothing left of it, or null.
  ///
  /// A numerator whose three coefficients have all rounded to zero kills the
  /// whole cascade: the response is identically zero, and every figure measured
  /// from it comes back infinite. Reported rather than measured, because the
  /// measurement is exactly what stops meaning anything.
  int? get deadSection {
    for (var s = 0; s < sos.length; s++) {
      for (final v in sos[s]) {
        if (!v.isFinite) return s;
      }
      if (sos[s][0] == 0.0 && sos[s][1] == 0.0 && sos[s][2] == 0.0) return s;
    }
    return null;
  }

  /// True when the cascade has no response left to measure.
  bool get degenerate => deadSection != null;

  bool get meetsSpec =>
      !degenerate &&
      achievedRp <= rp * 1.0001 + 1e-9 &&
      achievedRs >= rs - 1e-4;

  /// Complex frequency response at physical frequencies [f].
  List<Complex> responseAt(List<double> f) {
    final w = Float64List(f.length);
    for (var i = 0; i < f.length; i++) {
      w[i] = 2.0 * math.pi * f[i] / fs;
    }
    return sosFreqz(sos, w);
  }
}

// ---------------------------------------------------------------------------
// analog prototypes
// ---------------------------------------------------------------------------

void _checkOrder(int n) {
  if (n < 1) throw IIRError('the order must be at least 1, got $n');
  if (n > 60) throw IIRError('order $n is beyond what this will design');
}

/// Butterworth: poles evenly spaced on the left half of the unit circle.
/// The angles the three circular prototypes share: pi*k/(2n) for k running
/// -(n-1), -(n-3) ... n-1.
///
/// Written this way, and not as (2i+1)/(2n) + 1/2, so that the angles come in
/// exactly negated pairs. cos and sin of exactly negated arguments are exact
/// mirrors, so the poles come out an exactly conjugate-symmetric set and an
/// odd order's real pole has an imaginary part of exactly zero rather than
/// 1e-16. Both forms describe the same semicircle; only this one survives the
/// arithmetic that follows, where the pairing in `zpkToSos` turns on the last
/// bit of a magnitude.
List<double> _protoAngles(int n) => [
      for (var i = 0; i < n; i++) math.pi * (1 - n + 2 * i) / (2.0 * n)
    ];

Zpk butterAp(int n) {
  _checkOrder(n);
  // -exp(j*theta): n poles evenly spaced on the left unit semicircle.
  final p = [
    for (final theta in _protoAngles(n))
      Complex(-math.cos(theta), -math.sin(theta))
  ];
  return Zpk(const [], p, 1.0);
}

/// Chebyshev type I: equiripple in the passband, poles on an ellipse.
Zpk cheb1Ap(int n, double rp) {
  _checkOrder(n);
  if (rp <= 0) throw IIRError('the passband ripple must be positive');
  final eps = math.sqrt(math.pow(10.0, 0.1 * rp) - 1.0);
  final mu = _asinh(1.0 / eps) / n;
  // -sinh(mu + j*theta), expanded: the poles sit on an ellipse.
  final p = [
    for (final theta in _protoAngles(n))
      Complex(-_sinh(mu) * math.cos(theta), -_cosh(mu) * math.sin(theta))
  ];
  var k = _productOfNegated(p);
  if (n.isEven) {
    // Even orders start the ripple at 1/sqrt(1+eps^2) rather than at 1, so
    // that the band still spans exactly rp dB.
    k /= math.sqrt(1.0 + eps * eps);
  }
  return Zpk(const [], p, k);
}

/// `real(prod(-roots))`, the gain a prototype needs to reach unity at DC.
double _productOfNegated(List<Complex> roots) {
  var out = const Complex(1.0);
  for (final v in roots) {
    out = out * -v;
  }
  return out.re;
}

/// Chebyshev type II: equiripple in the stopband, with zeros on the axis.
Zpk cheb2Ap(int n, double rs) {
  _checkOrder(n);
  if (rs <= 0) throw IIRError('the stopband attenuation must be positive');
  final de = 1.0 / math.sqrt(math.pow(10.0, 0.1 * rs) - 1.0);
  final mu = _asinh(1.0 / de) / n;

  // The ripple peaks of the type I response, reciprocated: an odd order skips
  // the middle one, whose zero is at infinity.  The index list is built in the
  // Python's order (the negative half, then the positive half) because
  // `zpkToSos` pairs zeros with poles by position.
  final m = <int>[];
  if (n.isOdd) {
    for (var v = 1 - n; v < 0; v += 2) {
      m.add(v);
    }
    for (var v = 2; v < n; v += 2) {
      m.add(v);
    }
  } else {
    for (var v = 1 - n; v < n; v += 2) {
      m.add(v);
    }
  }
  final z = [
    for (final v in m) Complex(0.0, 1.0 / math.sin(v * math.pi / (2.0 * n)))
  ];

  final p = [
    for (final theta in _protoAngles(n))
      Complex.one /
          Complex(_sinh(mu) * -math.cos(theta), _cosh(mu) * -math.sin(theta))
  ];

  return Zpk(z, p, _productOfNegated(p) / _productOfNegated(z));
}

/// Elliptic (Cauer) prototype: equiripple in both bands.
///
/// Given the order and the two ripple figures, the degree equation fixes the
/// selectivity k, and with it the stopband edge at 1/k: an elliptic filter
/// cannot be asked for all three of order, passband ripple and transition
/// width, since any two determine the third. The poles and zeros then follow
/// from the Jacobi functions -- zeros at j/(k cd(u_i K, k)) on the imaginary
/// axis, poles at j cd((u_i - j v0) K, k) -- with one extra real pole when the
/// order is odd.
Zpk ellipAp(int n, double rp, double rs) {
  _checkOrder(n);
  if (rp <= 0 || rs <= 0) {
    throw IIRError('both ripple figures must be positive');
  }
  if (rs <= rp) {
    throw IIRError('the stopband attenuation must exceed the passband ripple');
  }
  if (n == 1) {
    // The degree equation is degenerate at n = 1; a single real pole placed
    // for the wanted ripple is the whole filter.
    final eps = math.sqrt(math.pow(10.0, 0.1 * rp) - 1.0);
    return Zpk(const [], [Complex(-1.0 / eps)], 1.0 / eps);
  }

  final epsP = math.sqrt(math.pow(10.0, 0.1 * rp) - 1.0);
  final epsS = math.sqrt(math.pow(10.0, 0.1 * rs) - 1.0);
  final k1 = epsP / epsS;
  final k = _ellipdeg(n, k1);

  final half = n ~/ 2;
  final ui = [for (var i = 1; i <= half; i++) (2.0 * i - 1.0) / n];

  final za = [
    for (final u in ui)
      const Complex(0.0, 1.0) / (Complex(k) * _cdeC(Complex(u), k))
  ];
  final v0 = (const Complex(0.0, -1.0) *
              _asne(Complex(0.0, 1.0 / epsP), k1) /
              Complex(n.toDouble()))
          .re;
  final pa = [
    for (final u in ui) const Complex(0.0, 1.0) * _cdeC(Complex(u, -v0), k)
  ];

  // The conjugates go in as a block, not alternating with the roots they
  // mirror: `zpkToSos` pairs zeros with poles by position.
  final z = [...za, for (final v in za) v.conjugate];
  final p = [...pa, for (final v in pa) v.conjugate];
  if (n.isOdd) {
    // The odd order's unpaired pole is real; it comes out of sn rather than cd.
    p.add(Complex((const Complex(0.0, 1.0) * _sneC(Complex(0.0, v0), k)).re));
  }

  var gain = (_productOfNegatedC(p) / _productOfNegatedC(z)).re;
  if (n.isEven) gain /= math.sqrt(1.0 + epsP * epsP);
  return Zpk(z, p, gain);
}

Complex _productOfNegatedC(List<Complex> roots) {
  var out = const Complex(1.0);
  for (final v in roots) {
    out = out * -v;
  }
  return out;
}

// --- elliptic integrals and Jacobi functions -------------------------------

double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;
double _cosh(double x) => (math.exp(x) + math.exp(-x)) / 2;
double _asinh(double x) => math.log(x + math.sqrt(x * x + 1));

/// `log(1 + x)`, accurate when x is small enough that `1 + x` loses it.
///
/// dart:math has no log1p. Kahan's formulation: the error in forming `u = 1+x`
/// is corrected by the ratio `x / (u - 1)`, which is exactly the factor the
/// logarithm of the rounded `u` is out by.
double _log1p(double x) {
  final u = 1.0 + x;
  if (u == 1.0) return x;
  return math.log(u) * x / (u - 1.0);
}

/// `exp(x) - 1`, likewise, and by the same trick in reverse.
double _expm1(double x) {
  final u = math.exp(x);
  if (u == 1.0) return x;
  if (u - 1.0 == -1.0) return -1.0;
  return (u - 1.0) * x / math.log(u);
}

/// Complete elliptic integral K of the modulus whose complement is [kc].
///
/// Parameterising by the *complementary* modulus is what makes this usable at
/// both ends: an elliptic filter needs K(k) and K(k') for the same k, and one
/// of the two is always evaluated at a modulus indistinguishable from 1 in
/// double precision if it is passed directly. The arithmetic-geometric mean
/// converges quadratically, so a dozen iterations are always enough.
double _ellipkKc(double kc) {
  if (kc <= 0.0) return double.infinity;
  var a = 1.0, b = kc;
  for (var i = 0; i < 60; i++) {
    if ((a - b).abs() <= 1e-16 * a) break;
    final an = 0.5 * (a + b);
    b = math.sqrt(a * b);
    a = an;
  }
  return math.pi / (2.0 * a);
}

/// Complete elliptic integral of the first kind in the parameter `m = k^2`.
double _ellipk(double m) => _ellipkKc(math.sqrt(math.max(0.0, 1.0 - m)));

/// Descending Landen moduli k1, k2, ... -> 0 for the modulus [k].
///
/// Each step halves the "elliptic-ness" of the problem, and the sequence
/// reaches round-off in a handful of iterations. Jacobi's functions are then
/// evaluated by starting from the trivial modulus-zero case, where they are
/// just a sine or a cosine, and undoing the transformations one at a time.
///
/// The count is not fixed: it runs until the modulus is below [tol], which for
/// a nearly-degenerate k is more steps than a fixed five and for a gentle one
/// is fewer.
List<double> _landen(double k, {double tol = 1e-15, int maxiter = 60}) {
  final out = <double>[];
  for (var i = 0; i < maxiter; i++) {
    if (k <= tol) break;
    final t = k / (1.0 + math.sqrt(1.0 - k * k));
    k = t * t;
    out.add(k);
  }
  return out;
}

/// Run the ascending Landen recursion over the moduli [v], reversed.
Complex _ascend(Complex w, List<double> v) {
  for (var i = v.length - 1; i >= 0; i--) {
    final kn = Complex(v[i]);
    w = (Complex.one + kn) * w / (Complex.one + kn * w * w);
  }
  return w;
}

/// `sn(u K(k), k)` -- the argument is in units of the quarter period.
Complex _sneC(Complex u, double k) =>
    _ascend(_csin(u * const Complex(math.pi / 2)), _landen(k));

/// `cd(u K(k), k)` -- likewise normalised to the quarter period.
Complex _cdeC(Complex u, double k) =>
    _ascend(_ccos(u * const Complex(math.pi / 2)), _landen(k));

/// Inverse of [_sneC]: u with `sn(u K(k), k) = w`.
Complex _asne(Complex w, double k) {
  final v = <double>[k, ..._landen(k)];
  for (var i = 0; i < v.length - 1; i++) {
    final root = (Complex.one - w * w * Complex(v[i] * v[i])).sqrt;
    w = w /
        (Complex.one + root) *
        const Complex(2.0) /
        Complex(1.0 + v[i + 1]);
  }
  return _casin(w) * const Complex(2.0 / math.pi);
}

/// Elliptic nome `q(k) = exp(-pi K'/K)`, by the classical series.
///
/// The series is in `ell = (1 - sqrt(k')) / (2 (1 + sqrt(k')))`, and the whole
/// point of using it is that k is tiny, which is exactly when forming
/// `1 - sqrt(k')` by subtraction throws away every digit it has. The
/// logarithmic form below keeps them.
double _nome(double k) {
  final t = 0.25 * _log1p(-k * k); // log of k'^(1/2)
  final ell = -0.5 * _expm1(t) / (1.0 + math.exp(t));
  return ell +
      2.0 * math.pow(ell, 5) +
      15.0 * math.pow(ell, 9) +
      150.0 * math.pow(ell, 13);
}

/// Solve the degree equation through the nome, for a tiny [k1].
///
/// The Landen route below loses digits when k1 is small enough that its
/// complement is 1 to working precision. Written in terms of the nome the
/// degree equation is just `q = q1^(1/n)`, and the modulus comes back from the
/// theta series, which is happy with a tiny q.
double _ellipdegSmall(int n, double k1) {
  final q = math.pow(_nome(k1), 1.0 / n).toDouble();
  var num = 0.0;
  for (var m = 0; m < 8; m++) {
    num += math.pow(q, m * (m + 1));
  }
  var den = 0.0;
  for (var m = 1; m < 8; m++) {
    den += math.pow(q, m * m);
  }
  final ratio = num / (1.0 + 2.0 * den);
  return 4.0 * math.sqrt(q) * ratio * ratio;
}

/// Solve the degree equation `n K'(k)/K(k) = K'(k1)/K(k1)` for k.
///
/// [k1] is the *discrimination factor* eps_p / eps_s fixed by the two ripple
/// specifications, and the k that comes back is the selectivity: an order-n
/// elliptic filter with those ripples has its passband edge at 1 and its
/// stopband edge at 1/k.
double _ellipdeg(int n, double k1) {
  if (k1 <= 0.0) {
    throw IIRError('the stopband must be more demanding than the passband');
  }
  if (k1 >= 1.0) {
    throw IIRError('stopband attenuation must exceed the passband ripple');
  }
  if (k1 < 1e-6) return _ellipdegSmall(n, k1);
  final kc = math.sqrt(1.0 - k1 * k1); // complement of k1
  var product = 1.0;
  for (var i = 1; i <= n ~/ 2; i++) {
    product *= _sneC(Complex((2.0 * i - 1.0) / n), kc).re;
  }
  final kp = math.pow(kc, n) * math.pow(product, 4);
  return math.sqrt(math.max(0.0, 1.0 - kp * kp));
}

Complex _csin(Complex z) =>
    Complex(math.sin(z.re) * _cosh(z.im), math.cos(z.re) * _sinh(z.im));

Complex _ccos(Complex z) =>
    Complex(math.cos(z.re) * _cosh(z.im), -math.sin(z.re) * _sinh(z.im));

/// `asin(z) = -i ln(iz + sqrt(1 - z^2))`.
Complex _casin(Complex z) {
  final inner = const Complex(0.0, 1.0) * z + (Complex.one - z * z).sqrt;
  return const Complex(0.0, -1.0) *
      Complex(math.log(inner.abs), inner.arg);
}

// ---------------------------------------------------------------------------
// frequency transformations
// ---------------------------------------------------------------------------

int _relativeDegree(List<Complex> z, List<Complex> p) {
  final degree = p.length - z.length;
  if (degree < 0) {
    throw IIRError('a filter cannot have more zeros than poles');
  }
  return degree;
}

/// `real(prod(-z) / prod(-p))`, the gain correction the s -> wo/s family needs.
///
/// The real part of the complex product, not a product of magnitudes: the two
/// agree for every prototype here, but only because the roots happen to come in
/// conjugate pairs or lie on the negative real axis, and that is not something
/// this function should be relying on.
double _gainRatio(List<Complex> z, List<Complex> p) {
  var num = const Complex(1.0), den = const Complex(1.0);
  for (final v in z) {
    num = num * -v;
  }
  for (final v in p) {
    den = den * -v;
  }
  return (num / den).re;
}

Zpk lp2lp(Zpk f, double wo) {
  final degree = _relativeDegree(f.z, f.p);
  final z = [for (final v in f.z) v.scale(wo)];
  final p = [for (final v in f.p) v.scale(wo)];
  return Zpk(z, p, f.k * math.pow(wo, degree).toDouble());
}

Zpk lp2hp(Zpk f, double wo) {
  final degree = _relativeDegree(f.z, f.p);
  final z = [for (final v in f.z) Complex(wo) / v];
  final p = [for (final v in f.p) Complex(wo) / v];
  for (var i = 0; i < degree; i++) {
    z.add(Complex.zero);
  }
  return Zpk(z, p, f.k * _gainRatio(f.z, f.p));
}

/// Split every root into a pair about `wo`.
///
/// The two halves go in as blocks -- every `+sqrt` root, then every `-sqrt`
/// root -- and not interleaved per root.  Both orders hold the same set, but
/// `zpkToSos` pairs by position, so interleaving them shuffles which pole meets
/// which zero and comes out as a different (still stable, still wrong) cascade.
List<Complex> _splitAbout(List<Complex> roots, double wo) {
  final out = <Complex>[];
  for (final v in roots) {
    out.add(v + (v * v - Complex(wo * wo)).sqrt);
  }
  for (final v in roots) {
    out.add(v - (v * v - Complex(wo * wo)).sqrt);
  }
  return out;
}

Zpk lp2bp(Zpk f, double wo, double bw) {
  final degree = _relativeDegree(f.z, f.p);
  final z = _splitAbout([for (final v in f.z) v.scale(bw / 2)], wo);
  final p = _splitAbout([for (final v in f.p) v.scale(bw / 2)], wo);
  for (var i = 0; i < degree; i++) {
    z.add(Complex.zero); // the poles that went to infinity, back at DC
  }
  return Zpk(z, p, f.k * math.pow(bw, degree).toDouble());
}

Zpk lp2bs(Zpk f, double wo, double bw) {
  final degree = _relativeDegree(f.z, f.p);
  final z = _splitAbout([for (final v in f.z) Complex(bw / 2) / v], wo);
  final p = _splitAbout([for (final v in f.p) Complex(bw / 2) / v], wo);
  // The poles that went to infinity come back as zeros at +-j wo, again as
  // blocks rather than alternating.
  for (var i = 0; i < degree; i++) {
    z.add(Complex(0.0, wo));
  }
  for (var i = 0; i < degree; i++) {
    z.add(Complex(0.0, -wo));
  }
  return Zpk(z, p, f.k * _gainRatio(f.z, f.p));
}

/// Bilinear transform, mapping the left half-plane to the unit disc.
Zpk bilinear(Zpk f, double fs) {
  final degree = _relativeDegree(f.z, f.p);
  final fs2 = 2.0 * fs;
  final z = [
    for (final v in f.z) (Complex(fs2) + v) / (Complex(fs2) - v)
  ];
  final p = [
    for (final v in f.p) (Complex(fs2) + v) / (Complex(fs2) - v)
  ];
  for (var i = 0; i < degree; i++) {
    z.add(const Complex(-1.0));
  }
  var num = Complex.one, den = Complex.one;
  for (final v in f.z) {
    num = num * (Complex(fs2) - v);
  }
  for (final v in f.p) {
    den = den * (Complex(fs2) - v);
  }
  return Zpk(z, p, f.k * (num / den).re);
}

/// Pre-warp a digital edge to the analog frequency the bilinear map needs.
double prewarp(double f, double fs) => 2.0 * fs * math.tan(math.pi * f / fs);

// ---------------------------------------------------------------------------
// second-order sections
// ---------------------------------------------------------------------------

/// Take [first] out of [roots] together with its partner.
///
/// A complex root leaves with its conjugate; a real one with the nearest other
/// real root, so every section comes out with real coefficients. The counts
/// always work: complex roots arrive in conjugate pairs, so whatever is left
/// over is real and even in number.
Complex _popConjugatePair(List<Complex> roots, Complex first) {
  final tolerance = 1e-12 * math.max(1.0, first.abs);
  if (first.im.abs() > tolerance) {
    var best = 0;
    var bestDistance = double.infinity;
    final want = first.conjugate;
    for (var i = 0; i < roots.length; i++) {
      final d = (roots[i] - want).abs;
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return roots.removeAt(best);
  }
  var best = -1;
  var bestDistance = double.infinity;
  for (var i = 0; i < roots.length; i++) {
    if (roots[i].im.abs() > 1e-12 * math.max(1.0, roots[i].abs)) continue;
    final d = (roots[i] - first).abs;
    if (d < bestDistance) {
      bestDistance = d;
      best = i;
    }
  }
  if (best < 0) {
    throw IIRError('cannot pair the roots into real second-order sections');
  }
  return roots.removeAt(best);
}

/// The index of the smallest value; the first of them, on a tie.
///
/// Worth knowing what this decides. A bandpass or bandstop puts its pole pairs
/// in mirrored sets whose magnitudes are equal in exact arithmetic and differ
/// in the last bit or two once they have been through the frequency
/// transformation and the bilinear map. Which of a tied pair is taken first
/// therefore rests on rounding, and it sets the order of the cascade: the same
/// filter, with its sections in a different sequence.
///
/// Both orders are the same filter and both are legitimate. A tolerance here,
/// to make the choice a property of the design rather than of the arithmetic,
/// was tried and rejected -- it agrees with the reference implementation in
/// fewer cases than plain rounding does, because the reference is itself at the
/// mercy of numpy's. See `iir_core_test.dart`, which checks the cascades as
/// filters and records separately which of them also match section for section.
int _argMin(List<double> values) {
  var best = 0;
  var smallest = double.infinity;
  for (var i = 0; i < values.length; i++) {
    if (values[i] < smallest) {
      smallest = values[i];
      best = i;
    }
  }
  return best;
}

/// Group a digital zero-pole-gain description into second-order sections.
///
/// Sections are formed by taking the pole pair furthest *inside* the unit
/// circle first and giving it the nearest available zero pair, which keeps each
/// section's gain as flat as the pattern allows. The ordering that falls out --
/// the sharpest, closest-to-the-circle pole pair last -- is the usual one for a
/// cascade, since it delays the biggest internal peak until the earlier
/// sections have already attenuated whatever it would ring on.
///
/// The overall gain is spread evenly over the sections rather than pushed into
/// the first one. Both give the same filter in exact arithmetic, but the gain
/// of a sharp narrow-band design is small enough to matter: an order-10
/// bandpass a sixteenth of the sample rate wide has k around 1e-10, and a
/// single section carrying all of it has a numerator six orders of magnitude
/// below the least significant bit of any sensible fixed-point format. It
/// quantizes to zero and takes the whole cascade with it. An even share is the
/// n-th root of that, which is representable, and it also keeps the signal off
/// the noise floor through the earlier sections instead of attenuating it to
/// nothing at the input and amplifying the quantization noise back up.
List<Float64List> zpkToSos(List<Complex> zIn, List<Complex> pIn, double k) {
  final z = List<Complex>.from(zIn);
  final p = List<Complex>.from(pIn);
  if (z.length > p.length) {
    throw IIRError('improper filter: more zeros than poles');
  }
  while (z.length < p.length) {
    z.add(Complex.zero);
  }
  if (p.length.isOdd) {
    // An extra pole and zero at the origin, which cancel and make the count
    // even.  Without this the leftover real pole would be given two zeros and
    // the section would be second order where it should be first.
    z.add(Complex.zero);
    p.add(Complex.zero);
  }
  if (p.isEmpty) {
    return [Float64List.fromList([k, 0.0, 0.0, 1.0, 0.0, 0.0])];
  }

  final sections = <Float64List>[];
  while (p.isNotEmpty) {
    final i = _argMin([for (final v in p) v.abs]);
    final p1 = p.removeAt(i);
    final p2 = _popConjugatePair(p, p1);

    final nearest = _argMin([for (final v in z) (v - p1).abs]);
    final z1 = z.removeAt(nearest);
    final z2 = _popConjugatePair(z, z1);

    final b = _fromRoots(z1, z2);
    final a = _fromRoots(p1, p2);
    sections.add(Float64List.fromList([b[0], b[1], b[2], a[0], a[1], a[2]]));
  }

  _spreadGain(sections, k);
  return sections;
}

/// Multiply the section numerators by [k], scaled so no node between two
/// sections has a peak gain above one.
///
/// Where the gain goes decides two different things, and both of them bite.
/// Put it all in the first section, as the textbook zpk-to-cascade does, and a
/// sharp narrow-band design whose k is 1e-10 has a numerator that quantizes to
/// zero and kills the cascade. Share it out evenly instead and the numerators
/// are representable, but nothing is looking at where the resonances are: a
/// section whose poles sit at 0.99 has a peak gain of its own, and with the
/// gain no longer taken out at the input the node behind it overflows. What
/// comes out then is not rounding error but clipping, which no amount of extra
/// word length or headroom will improve.
///
/// So each section takes the share that brings the running cascade's peak back
/// to one, measured on a fixed grid of [npoints] frequencies, and the last
/// takes whatever is left -- which puts the output at the filter's own gain,
/// and makes the sections multiply back to exactly [k] however the shares
/// rounded. The grid is dense enough to resolve a resonance a few thousandths
/// of a radian wide; missing a peak by a fraction of a dB only means a node
/// scaled slightly high, not a wrong filter.
void _spreadGain(List<Float64List> sections, double k, {int npoints = 4096}) {
  final n = sections.length;
  if (n == 1 || k == 0.0) {
    for (var i = 0; i < 3; i++) {
      sections[0][i] *= k;
    }
    return;
  }

  final w = Float64List(npoints);
  for (var i = 0; i < npoints; i++) {
    w[i] = math.pi * i / (npoints - 1);
  }

  final running = List<Complex>.filled(npoints, Complex.one);
  var rest = k;
  for (var s = 0; s < n - 1; s++) {
    final h = sosFreqz([sections[s]], w);
    var peak = 0.0;
    for (var i = 0; i < npoints; i++) {
      running[i] = running[i] * h[i];
      final m = running[i].abs;
      if (m > peak) peak = m;
    }
    // A section cannot have an all-zero numerator here -- they come out of
    // `_fromRoots` monic -- but a peak of zero would still not be a scale.
    final g = peak > 0 && peak.isFinite ? 1.0 / peak : 1.0;
    for (var i = 0; i < 3; i++) {
      sections[s][i] *= g;
    }
    for (var i = 0; i < npoints; i++) {
      running[i] = running[i].scale(g);
    }
    rest /= g;
  }
  for (var i = 0; i < 3; i++) {
    sections[n - 1][i] *= rest;
  }
}

List<double> _fromRoots(Complex r1, Complex r2) {
  // (z - r1)(z - r2) = z^2 - (r1+r2) z + r1 r2, real when they are conjugates.
  final sum = r1 + r2;
  final product = r1 * r2;
  return [1.0, -sum.re, product.re];
}

/// Frequency response of a cascade at digital frequencies [w] (rad/sample).
///
/// A pole sitting exactly on the unit circle -- which quantizing a sharp
/// filter's coefficients can produce -- makes the denominator vanish there. The
/// gain really is infinite, so the division is allowed to say so.
List<Complex> sosFreqz(List<Float64List> sos, Float64List w) {
  final out = List<Complex>.filled(w.length, Complex.one);
  for (var i = 0; i < w.length; i++) {
    final zi = Complex(math.cos(-w[i]), math.sin(-w[i]));
    var h = Complex.one;
    for (final s in sos) {
      final num = Complex(s[0]) + Complex(s[1]) * zi + Complex(s[2]) * zi * zi;
      final den = Complex(s[3]) + Complex(s[4]) * zi + Complex(s[5]) * zi * zi;
      h = h * num / den;
    }
    out[i] = h;
  }
  return out;
}

/// Run a signal through the cascade, transposed direct form II per section.
Float64List sosFilter(List<Float64List> sos, Float64List x) {
  var y = Float64List.fromList(x);
  for (final s in sos) {
    final b0 = s[0] / s[3], b1 = s[1] / s[3], b2 = s[2] / s[3];
    final a1 = s[4] / s[3], a2 = s[5] / s[3];
    var s1 = 0.0, s2 = 0.0;
    final out = Float64List(y.length);
    for (var i = 0; i < y.length; i++) {
      final v = y[i];
      final o = b0 * v + s1;
      s1 = b1 * v - a1 * o + s2;
      s2 = b2 * v - a2 * o;
      out[i] = o;
    }
    y = out;
  }
  return y;
}

/// The impulse response, [n] samples of it.
Float64List sosImpulse(List<Float64List> sos, int n) {
  final x = Float64List(n);
  if (n > 0) x[0] = 1.0;
  return sosFilter(sos, x);
}

// Group delay lives in `response.dart`, computed from the derivative of the
// transfer function rather than by differencing a phase, and covering an FIR
// as well as a cascade.

/// Zeros, poles and gain of a cascade.
///
/// Roots at the origin are dropped: a section with b2 = 0 is a first-order
/// numerator padded out, and that z = 0 root is an artefact of the storage.
Zpk sosToZpk(List<Float64List> sos) {
  final z = <Complex>[];
  final p = <Complex>[];
  var k = 1.0;
  for (final s in sos) {
    k *= s[0] / s[3];
    for (final trio in [
      [s[0], s[1], s[2]],
      [s[3], s[4], s[5]]
    ]) {
      if (trio[0] == 0.0) continue;
      final roots = quadraticRoots(trio[0], trio[1], trio[2]);
      for (final r in roots) {
        if (r.abs > 1e-14) {
          (identical(trio[0], s[0]) ? z : p).add(r);
        }
      }
    }
  }
  // The loop above cannot tell the two trios apart by identity; redo cleanly.
  z.clear();
  p.clear();
  k = 1.0;
  for (final s in sos) {
    k *= s[0] / s[3];
    if (s[0] != 0.0) {
      for (final r in quadraticRoots(s[0], s[1], s[2])) {
        if (r.abs > 1e-14) z.add(r);
      }
    }
    if (s[3] != 0.0) {
      for (final r in quadraticRoots(s[3], s[4], s[5])) {
        if (r.abs > 1e-14) p.add(r);
      }
    }
  }
  return Zpk(z, p, k);
}

// ---------------------------------------------------------------------------
// order estimation
// ---------------------------------------------------------------------------

/// Normalised stopband edge of the equivalent analog lowpass problem.
///
/// Every response type is designed by transforming a lowpass whose passband
/// edge is 1 rad/s, so what governs the order is where the stopband lands after
/// that same transformation. For the two band responses the transform is
/// geometrically symmetric about the band centre while the requested edges
/// generally are not, so both stopband edges are mapped and the harder of the
/// two -- the one closer to 1 -- decides.
double _lowpassRatio(String response, List<double> wp, List<double> ws) {
  if (response == 'lowpass') return ws[0] / wp[0];
  if (response == 'highpass') return wp[0] / ws[0];
  final wo2 = wp[0] * wp[1];
  final bw = wp[1] - wp[0];
  var smallest = double.infinity;
  for (final w in ws) {
    final v = response == 'bandpass'
        ? ((w * w - wo2) / (w * bw)).abs()
        : ((w * bw) / (w * w - wo2)).abs();
    if (v < smallest) smallest = v;
  }
  return smallest;
}

/// The smallest prototype order that meets the specification.
int estimateOrder(String approximation, String response, List<double> wp,
    List<double> ws, double rp, double rs,
    {double fs = 1.0}) {
  final warpedP = [for (final f in wp) prewarp(f, fs)];
  final warpedS = [for (final f in ws) prewarp(f, fs)];
  final ratio = _lowpassRatio(response, warpedP, warpedS);
  if (!(ratio > 1.0)) {
    throw IIRError('the stopband edge must be further out than the passband '
        'edge; check the order of the frequencies');
  }
  final gpass = math.pow(10.0, 0.1 * rp) - 1.0;
  final gstop = math.pow(10.0, 0.1 * rs) - 1.0;

  double n;
  switch (approximation) {
    case 'butterworth':
      n = math.log(gstop / gpass) / (2 * math.log(ratio));
      break;
    case 'chebyshev1':
    case 'chebyshev2':
      n = _acosh(math.sqrt(gstop / gpass)) / _acosh(ratio);
      break;
    default:
      final k = 1.0 / ratio;
      final k1 = math.sqrt(gpass / gstop);
      final capk = _ellipk(k * k);
      final capkp = _ellipk(1 - k * k);
      final capk1 = _ellipk(k1 * k1);
      final capk1p = _ellipk(1 - k1 * k1);
      n = (capk1p * capk) / (capk1 * capkp);
      break;
  }
  return math.max(1, n.ceil());
}

double _acosh(double x) => math.log(x + math.sqrt(x * x - 1));

// ---------------------------------------------------------------------------
// the entry point
// ---------------------------------------------------------------------------

class _Bands {
  _Bands(this.pass, this.stop);
  final List<List<double>> pass;
  final List<List<double>> stop;
}

_Bands _bands(String response, List<double> wp, List<double> ws, double fs) {
  final nyq = fs / 2;
  switch (response) {
    case 'lowpass':
      return _Bands([
        [0.0, wp[0]]
      ], [
        [ws[0], nyq]
      ]);
    case 'highpass':
      return _Bands([
        [wp[0], nyq]
      ], [
        [0.0, ws[0]]
      ]);
    case 'bandpass':
      return _Bands([
        [wp[0], wp[1]]
      ], [
        [0.0, ws[0]],
        [ws[1], nyq]
      ]);
    default:
      return _Bands([
        [0.0, wp[0]],
        [wp[1], nyq]
      ], [
        [ws[0], ws[1]]
      ]);
  }
}

void _checkEdges(String response, List<double> wp, List<double> ws, double fs) {
  final nyq = fs / 2;
  for (final group in [wp, ws]) {
    for (final f in group) {
      if (!(f > 0 && f < nyq)) {
        throw IIRError('every edge must lie strictly between 0 and fs/2 '
            '($nyq); got $f');
      }
    }
  }
  final wantPairs = response == 'bandpass' || response == 'bandstop';
  if (wantPairs && (wp.length < 2 || ws.length < 2)) {
    throw IIRError('a $response needs two passband and two stopband edges');
  }
  switch (response) {
    case 'lowpass':
      if (!(wp[0] < ws[0])) {
        throw IIRError('a lowpass needs the passband edge below the stopband');
      }
      break;
    case 'highpass':
      if (!(ws[0] < wp[0])) {
        throw IIRError('a highpass needs the stopband edge below the passband');
      }
      break;
    case 'bandpass':
      if (!(ws[0] < wp[0] && wp[0] < wp[1] && wp[1] < ws[1])) {
        throw IIRError('a bandpass needs fs1 < fp1 < fp2 < fs2');
      }
      break;
    default:
      if (!(wp[0] < ws[0] && ws[0] < ws[1] && ws[1] < wp[1])) {
        throw IIRError('a bandstop needs fp1 < fs1 < fs2 < fp2');
      }
  }
}

Float64List _regionGrid(List<List<double>> ranges, int npoints) {
  var total = 0.0;
  for (final r in ranges) {
    total += math.max(r[1] - r[0], 0.0);
  }
  if (total <= 0) return Float64List(0);
  final out = <double>[];
  for (final r in ranges) {
    if (r[1] <= r[0]) continue;
    final m = math.max(16, (npoints * (r[1] - r[0]) / total).toInt());
    for (var i = 0; i < m; i++) {
      out.add(r[0] + (r[1] - r[0]) * i / (m - 1));
    }
  }
  return Float64List.fromList(out);
}

double _bandRipple(
    List<Float64List> sos, List<List<double>> ranges, double fs, int npoints) {
  final f = _regionGrid(ranges, npoints);
  if (f.isEmpty) return 0.0;
  final w = Float64List(f.length);
  for (var i = 0; i < f.length; i++) {
    w[i] = 2 * math.pi * f[i] / fs;
  }
  var lo = double.infinity, hi = 0.0;
  for (final h in sosFreqz(sos, w)) {
    final m = h.abs;
    if (m < lo) lo = m;
    if (m > hi) hi = m;
  }
  if (lo <= 0) return double.infinity;
  return 20 * math.log(hi / lo) / math.ln10;
}

double _bandAttenuation(
    List<Float64List> sos, List<List<double>> ranges, double fs, int npoints) {
  final f = _regionGrid(ranges, npoints);
  if (f.isEmpty) return double.infinity;
  final w = Float64List(f.length);
  for (var i = 0; i < f.length; i++) {
    w[i] = 2 * math.pi * f[i] / fs;
  }
  var peak = 0.0;
  for (final h in sosFreqz(sos, w)) {
    if (h.abs > peak) peak = h.abs;
  }
  if (peak <= 0) return double.infinity;
  return -20 * math.log(peak) / math.ln10;
}

/// Design a classical IIR filter.
///
/// [order] null asks for the smallest order that meets the specification.
IIRResult design(
  String response,
  String approximation, {
  required List<double> wp,
  required List<double> ws,
  required double rp,
  required double rs,
  int? order,
  double fs = 1.0,
  int npoints = 4096,
}) {
  if (!responses.contains(response)) {
    throw IIRError('unknown response $response');
  }
  if (!approximations.contains(approximation)) {
    throw IIRError('unknown approximation $approximation');
  }
  if (rp <= 0) throw IIRError('the passband ripple must be positive');
  if (rs <= rp) {
    throw IIRError('the stopband attenuation must exceed the passband ripple');
  }
  _checkEdges(response, wp, ws, fs);

  final estimate = estimateOrder(approximation, response, wp, ws, rp, rs,
      fs: fs);
  final auto = order == null;
  final n = order ?? estimate;
  _checkOrder(n);

  // Pre-warp the edge the approximation actually pins down.
  final edgeIsStop = approximation == 'chebyshev2';
  final edges = <double>[
    for (final f in (edgeIsStop ? ws : wp)) prewarp(f, fs)
  ];

  Zpk proto;
  switch (approximation) {
    case 'butterworth':
      proto = butterAp(n);
      // No ripple pins an edge, so widen from -3 dB until the response is
      // exactly rp dB down at the passband edge.
      final scale = math.pow(math.pow(10.0, rp / 10.0) - 1.0, -1.0 / (2 * n))
          .toDouble();
      proto = Zpk(proto.z, [for (final v in proto.p) v.scale(scale)],
          proto.k * math.pow(scale, proto.p.length - proto.z.length).toDouble());
      break;
    case 'chebyshev1':
      proto = cheb1Ap(n, rp);
      break;
    case 'chebyshev2':
      proto = cheb2Ap(n, rs);
      break;
    default:
      proto = ellipAp(n, rp, rs);
  }

  Zpk analog;
  if (response == 'lowpass') {
    analog = lp2lp(proto, edges[0]);
  } else if (response == 'highpass') {
    analog = lp2hp(proto, edges[0]);
  } else {
    final wo = math.sqrt(edges[0] * edges[1]);
    final bw = edges[1] - edges[0];
    analog = response == 'bandpass'
        ? lp2bp(proto, wo, bw)
        : lp2bs(proto, wo, bw);
  }

  final digital = bilinear(analog, fs);
  final sos = zpkToSos(digital.z, digital.p, digital.k);

  final bands = _bands(response, wp, ws, fs);
  final achievedRp = _bandRipple(sos, bands.pass, fs, npoints);
  final achievedRs = _bandAttenuation(sos, bands.stop, fs, npoints);

  var radius = 0.0;
  for (final v in digital.p) {
    if (v.abs > radius) radius = v.abs;
  }
  final wn = [for (final e in edges) fs / math.pi * math.atan(e / (2 * fs))];

  return IIRResult(
    z: digital.z,
    p: digital.p,
    k: digital.k,
    sos: sos,
    order: n,
    degree: digital.p.length,
    response: response,
    approximation: approximation,
    fs: fs,
    wp: wp,
    ws: ws,
    rp: rp,
    rs: rs,
    wn: wn,
    orderEstimate: estimate,
    autoOrder: auto,
    achievedRp: achievedRp,
    achievedRs: achievedRs,
    maxPoleRadius: radius,
    stable: radius < 1.0,
    passbandRanges: bands.pass,
    stopbandRanges: bands.stop,
  );
}

/// Re-analyse a design as if it had been built from the sections [sos].
IIRResult withSos(IIRResult res, List<Float64List> sos, {int npoints = 4096}) {
  if (sos.length != res.sos.length) {
    throw IIRError('expected ${res.sos.length} sections, got ${sos.length}');
  }
  final zpk = sosToZpk(sos);
  var radius = 0.0;
  for (final v in zpk.p) {
    if (v.abs > radius) radius = v.abs;
  }
  return IIRResult(
    z: zpk.z,
    p: zpk.p,
    k: zpk.k,
    sos: sos,
    order: res.order,
    degree: res.degree,
    response: res.response,
    approximation: res.approximation,
    fs: res.fs,
    wp: res.wp,
    ws: res.ws,
    rp: res.rp,
    rs: res.rs,
    wn: res.wn,
    orderEstimate: res.orderEstimate,
    autoOrder: res.autoOrder,
    achievedRp: _bandRipple(sos, res.passbandRanges, res.fs, npoints),
    achievedRs: _bandAttenuation(sos, res.stopbandRanges, res.fs, npoints),
    maxPoleRadius: radius,
    stable: radius < 1.0,
    passbandRanges: res.passbandRanges,
    stopbandRanges: res.stopbandRanges,
  );
}
