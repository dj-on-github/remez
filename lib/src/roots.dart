/// Polynomial root finding, for the zeros of an FIR transfer function.
///
/// An IIR design already knows its poles and zeros -- they are what it was
/// built from -- but an FIR is only a list of taps, and its zeros are the roots
/// of `h[0] z^(N-1) + h[1] z^(N-2) + ... + h[N-1]`. Those are worth seeing: a
/// linear-phase filter puts them on the unit circle across each stopband and in
/// reciprocal quadruples elsewhere, and rounding the taps moves them.
///
/// The method is Aberth-Ehrlich, which is Newton's method with the pull of the
/// roots already found divided out, so the iterates repel each other instead of
/// collapsing onto the same root. It converges cubically and, unlike
/// Durand-Kerner, copes with the clustered roots a long filter has.
library;

import 'dart:math' as math;

import 'complex.dart';

/// The roots of a polynomial, and whether the iteration settled.
///
/// [converged] false does not mean the values are useless -- they are usually
/// close -- but a plot drawn from them should say so rather than imply the
/// zeros are where it shows.
class Roots {
  const Roots(this.values, this.converged);
  final List<Complex> values;
  final bool converged;
}

/// The roots of `c[0] z^n + c[1] z^(n-1) + ... + c[n]`.
///
/// Exactly-zero coefficients are taken at face value: leading ones lower the
/// degree, trailing ones are roots at the origin. Both arise by construction --
/// a half-band filter's alternate taps and an antisymmetric filter's middle tap
/// are zero exactly, not nearly -- so they are handled here rather than left to
/// an iteration that would return a huge or a tiny root instead.
Roots polynomialRoots(List<double> coefficients, {int maxiter = 500}) {
  var c = List<double>.from(coefficients);
  var lead = 0;
  while (lead < c.length && c[lead] == 0.0) {
    lead++;
  }
  c = c.sublist(lead);
  var atOrigin = 0;
  while (c.length > 1 && c.last == 0.0) {
    c.removeLast();
    atOrigin++;
  }
  final origin = List<Complex>.filled(atOrigin, Complex.zero);

  final n = c.length - 1;
  if (n < 1) return Roots(origin, true);
  if (n == 1) return Roots([...origin, Complex(-c[1] / c[0])], true);
  if (n == 2) {
    return Roots([...origin, ...quadraticRoots(c[0], c[1], c[2])], true);
  }

  // Monic: the iteration only ever forms ratios, but scaling first keeps the
  // Horner sums from drifting in magnitude across a long filter.
  final a = [for (final v in c) v / c[0]];
  final d = [for (var i = 0; i < n; i++) a[i] * (n - i)];

  // The geometric mean of the root magnitudes, which is where to start looking.
  // For a symmetric FIR the first and last taps are equal, so this is exactly
  // 1 and the initial ring lands on the unit circle where most of the roots
  // actually are.
  var radius = math.pow(a[n].abs(), 1.0 / n).toDouble();
  if (!radius.isFinite || radius <= 0) radius = 1.0;

  // Spread over a ring, with the radius dithered and the angles offset by a
  // fraction of a turn. Starting on an exactly regular polygon lets the
  // symmetry of a symmetric filter survive every iteration, and the points
  // never separate.
  final z = <Complex>[
    for (var i = 0; i < n; i++)
      Complex(
        radius * (1 + 0.15 * ((i % 3) - 1)) *
            math.cos(2 * math.pi * i / n + 0.4),
        radius * (1 + 0.15 * ((i % 3) - 1)) *
            math.sin(2 * math.pi * i / n + 0.4),
      )
  ];

  final tolerance = 1e-14 * math.max(radius, 1.0);
  var converged = false;
  for (var it = 0; it < maxiter && !converged; it++) {
    var moved = 0.0;
    for (var i = 0; i < n; i++) {
      final p = _horner(a, z[i]);
      final dp = _horner(d, z[i]);
      if (dp.abs == 0.0 || !p.isFinite || !dp.isFinite) continue;
      final newton = p / dp;
      // The Aberth correction: subtract the slope the other roots contribute,
      // so this iterate is not drawn towards one that is already claimed.
      var pull = Complex.zero;
      for (var j = 0; j < n; j++) {
        if (j == i) continue;
        final gap = z[i] - z[j];
        if (gap.abs2 == 0.0) continue;
        pull = pull + Complex.one / gap;
      }
      final denominator = Complex.one - newton * pull;
      if (denominator.abs == 0.0) continue;
      final step = newton / denominator;
      if (!step.isFinite) continue;
      z[i] = z[i] - step;
      if (step.abs > moved) moved = step.abs;
    }
    converged = moved < tolerance;
  }

  return Roots([...origin, ...z], converged);
}

Complex _horner(List<double> a, Complex z) {
  var acc = Complex(a[0]);
  for (var i = 1; i < a.length; i++) {
    acc = acc * z + Complex(a[i]);
  }
  return acc;
}
