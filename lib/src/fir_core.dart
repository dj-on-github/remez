/// Parks-McClellan / Remez exchange for linear-phase FIR filter design.
///
/// A port of the Python `fir_core.py`, and it has to agree with it: the tests
/// check this against reference values taken from that implementation.
///
/// The four linear-phase types are supported by writing the zero-phase
/// amplitude as `A(w) = Q(w) * P(cos w)`:
///
///     type  taps   symmetry        Q(w)        basis size r
///     ----  -----  --------------  ----------  ---------------
///       I   odd    symmetric       1           (N + 1) ~/ 2
///      II   even   symmetric       cos(w/2)    N ~/ 2
///     III   odd    antisymmetric   sin(w)      (N - 1) ~/ 2
///      IV   even   antisymmetric   sin(w/2)    N ~/ 2
///
/// Dividing the desired response by Q and multiplying the weight by Q turns
/// every case into the same type-I problem, which is what the exchange solves.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'fft.dart';

/// Raised when a design request is inconsistent or the exchange fails.
class RemezError implements Exception {
  RemezError(this.message);
  final String message;
  @override
  String toString() => 'RemezError: $message';
}

/// How a band's error weight varies across it.
enum WeightKind {
  /// Ramps linearly from [Band.w1] to [Band.w2].
  constant,

  /// `w1 / f`, which equalises *relative* error -- what a differentiator wants.
  inverseF,
}

/// One approximation band.
///
/// Frequencies are in the same units as the sample rate. The desired amplitude
/// and the weight may each ramp across the band, which covers a flat band, a
/// differentiator, and any piecewise-linear specification.
class Band {
  Band(this.f1, this.f2, this.d1, double? d2,
      {double w1 = 1.0, double? w2, this.weightKind = WeightKind.constant})
      : d2 = d2 ?? d1,
        w1 = w1,
        w2 = w2 ?? w1;

  /// A band with one desired value and one weight across it.
  Band.flat(this.f1, this.f2, double desired,
      {double weight = 1.0, this.weightKind = WeightKind.constant})
      : d1 = desired,
        d2 = desired,
        w1 = weight,
        w2 = weight;

  final double f1;
  final double f2;
  final double d1;
  final double d2;
  final double w1;
  final double w2;
  final WeightKind weightKind;

  Band scaled(double by) => Band(f1 * by, f2 * by, d1, d2,
      w1: w1, w2: w2, weightKind: weightKind);

  /// The larger of the two desired values, which is the band's nominal level.
  double get target => math.max(d1.abs(), d2.abs());
}

/// Symmetry of the impulse response.
enum Symmetry { symmetric, antisymmetric }

/// Everything the exchange produced, for both use and display.
class RemezResult {
  RemezResult({
    required this.h,
    required this.numtaps,
    required this.ftype,
    required this.symmetry,
    required this.delta,
    required this.gridF,
    required this.gridD,
    required this.gridW,
    required this.gridA,
    required this.gridE,
    required this.gridBand,
    required this.extremalF,
    required this.extremalE,
    required this.iterations,
    required this.converged,
    required this.bandDeviation,
    required this.peakAmplitude,
    required this.fs,
    required this.bands,
  });

  /// Impulse response, length [numtaps].
  final Float64List h;
  final int numtaps;

  /// 1..4.
  final int ftype;
  final Symmetry symmetry;

  /// Signed minimax weighted deviation.
  final double delta;

  /// The dense grid, in physical frequency units, and what was measured on it.
  final Float64List gridF;
  final Float64List gridD;
  final Float64List gridW;
  final Float64List gridA;
  final Float64List gridE;

  /// Which band each grid point belongs to.
  final Int32List gridBand;

  final Float64List extremalF;
  final Float64List extremalE;
  final int iterations;
  final bool converged;

  /// Per-band peak `|D - A|`.
  final List<double> bandDeviation;

  /// Peak `|A|` over 0..fs/2, transition bands included.
  final double peakAmplitude;
  final double fs;
  final List<Band> bands;

  double get ripple => delta.abs();
}

/// Zero-phase amplitude `A(w)` of a linear-phase FIR from its taps.
Float64List amplitudeResponse(
    Float64List h, Float64List w, Symmetry symmetry) {
  final n = h.length;
  final centre = (n - 1) / 2.0;
  final out = Float64List(w.length);
  final sym = symmetry == Symmetry.symmetric;
  for (var i = 0; i < w.length; i++) {
    var total = 0.0;
    final wi = w[i];
    for (var k = 0; k < n; k++) {
      final angle = wi * (centre - k);
      total += h[k] * (sym ? math.cos(angle) : math.sin(angle));
    }
    out[i] = total;
  }
  return out;
}

/// Kaiser's estimate of the taps needed for a lowpass-like two-band design.
int kaiserOrderEstimate(double deltaP, double deltaS, double transition,
    {double fs = 1.0}) {
  if (transition <= 0 || deltaP <= 0 || deltaS <= 0) return 0;
  final df = transition / fs;
  final n = (-20.0 * _log10(math.sqrt(deltaP * deltaS)) - 13.0) / (14.6 * df) +
      1.0;
  return n.ceil();
}

double _log10(double x) => math.log(x) / math.ln10;

// ---------------------------------------------------------------------------
// type bookkeeping
// ---------------------------------------------------------------------------

class _Type {
  const _Type(this.ftype, this.r);
  final int ftype;
  final int r;
}

_Type _classify(int numtaps, Symmetry symmetry) {
  final odd = numtaps.isOdd;
  if (symmetry == Symmetry.symmetric) {
    return odd ? _Type(1, (numtaps + 1) ~/ 2) : _Type(2, numtaps ~/ 2);
  }
  return odd ? _Type(3, (numtaps - 1) ~/ 2) : _Type(4, numtaps ~/ 2);
}

double _qFactor(int ftype, double w) {
  switch (ftype) {
    case 1:
      return 1.0;
    case 2:
      return math.cos(w / 2.0);
    case 3:
      return math.sin(w);
    default:
      return math.sin(w / 2.0);
  }
}

// ---------------------------------------------------------------------------
// the dense grid
// ---------------------------------------------------------------------------

class _Grid {
  _Grid(this.f, this.band);
  final Float64List f;
  final Int32List band;
}

/// Dense grid of normalised frequencies (cycles/sample, 0..0.5).
///
/// The step comes from the *total* bandwidth rather than the full Nyquist
/// range, so a design whose bands cover only a sliver of the axis still gets
/// `gridDensity * r` points to search instead of a handful.
_Grid _buildGrid(List<Band> bands, int r, int gridDensity, int ftype) {
  final guard = 0.5 / (gridDensity * r);
  // Q(0) == 0 for types 3 and 4; Q(0.5) == 0 for types 2 and 3.
  final loGuard = (ftype == 3 || ftype == 4) ? guard : 0.0;
  final hiGuard = (ftype == 2 || ftype == 3) ? 0.5 - guard : 0.5;

  final spans = <List<double>>[];
  for (var i = 0; i < bands.length; i++) {
    final f1 = math.max(bands[i].f1, loGuard);
    final f2 = math.min(bands[i].f2, hiGuard);
    if (f2 <= f1) {
      throw RemezError('band ${i + 1} is empty after guarding against Q(w)=0; '
          'move the edges away from 0 or Nyquist');
    }
    spans.add([f1, f2]);
  }

  var total = 0.0;
  for (final s in spans) {
    total += s[1] - s[0];
  }
  final delf = total / (gridDensity * r);

  final f = <double>[];
  final band = <int>[];
  for (var i = 0; i < spans.length; i++) {
    final lo = spans[i][0], hi = spans[i][1];
    final npts = math.max(((hi - lo) / delf).ceil() + 1, 3);
    for (var k = 0; k < npts; k++) {
      f.add(lo + (hi - lo) * k / (npts - 1));
      band.add(i);
    }
  }
  return _Grid(Float64List.fromList(f), Int32List.fromList(band));
}

class _Desired {
  _Desired(this.d, this.w);
  final Float64List d;
  final Float64List w;
}

_Desired _interpBand(List<Band> bands, _Grid grid) {
  final d = Float64List(grid.f.length);
  final w = Float64List(grid.f.length);
  for (var index = 0; index < bands.length; index++) {
    final b = bands[index];
    final span = b.f2 - b.f1;
    // The lowest positive grid frequency in this band, for the 1/f guard.
    var smallest = double.infinity;
    for (var i = 0; i < grid.f.length; i++) {
      if (grid.band[i] == index && grid.f[i] > 0 && grid.f[i] < smallest) {
        smallest = grid.f[i];
      }
    }
    if (!smallest.isFinite) smallest = 1e-6;
    for (var i = 0; i < grid.f.length; i++) {
      if (grid.band[i] != index) continue;
      final t = span <= 0 ? 0.0 : (grid.f[i] - b.f1) / span;
      d[i] = b.d1 + t * (b.d2 - b.d1);
      if (b.weightKind == WeightKind.inverseF) {
        w[i] = b.w1 / math.max(grid.f[i], math.max(smallest, 1e-9));
      } else {
        w[i] = b.w1 + t * (b.w2 - b.w1);
      }
    }
  }
  for (final v in w) {
    if (v <= 0) throw RemezError('all band weights must be strictly positive');
  }
  return _Desired(d, w);
}

// ---------------------------------------------------------------------------
// barycentric machinery
// ---------------------------------------------------------------------------

class _BaryLogs {
  _BaryLogs(this.signs, this.logs);
  final Float64List signs;
  final Float64List logs;
}

/// `(signs, logs)` with `prod_{i != k} (x_k - x_i) = signs_k * exp(logs_k)`.
_BaryLogs _baryLogs(Float64List x) {
  final n = x.length;
  final signs = Float64List(n);
  final logs = Float64List(n);
  for (var k = 0; k < n; k++) {
    var sign = 1.0;
    var total = 0.0;
    for (var i = 0; i < n; i++) {
      if (i == k) continue;
      final diff = x[k] - x[i];
      if (diff < 0) sign = -sign;
      total += math.log(diff.abs());
    }
    signs[k] = sign;
    logs[k] = total;
  }
  return _BaryLogs(signs, logs);
}

/// Weights proportional to `1 / prod_{i != k} (x_k - x_i)`.
///
/// The products span hundreds of orders of magnitude for a long filter, so they
/// are formed in the log domain and rescaled by their geometric mean. Every
/// formula that consumes them is a ratio, so a common factor is free to choose
/// and keeping it near unity is what stops the exponentials overflowing.
Float64List _baryWeights(Float64List x) {
  final l = _baryLogs(x);
  var mean = 0.0;
  for (final v in l.logs) {
    mean += v;
  }
  mean /= l.logs.length;
  final out = Float64List(x.length);
  for (var k = 0; k < x.length; k++) {
    out[k] = l.signs[k] * math.exp(-(l.logs[k] - mean));
  }
  return out;
}

/// Evaluate the interpolant through `(x, y)` in the first barycentric form.
///
///     p(x) = prod_j (x - x_j) * sum_k w_k y_k / (x - x_k)
///
/// The more familiar second form -- the ratio of two such sums -- is cheaper,
/// but its denominator is `1/prod(x - x_j)`, which for a long filter cancels
/// away to nothing outside the hull of the nodes and then returns a finite,
/// entirely wrong number. That is exactly what a wide unconstrained transition
/// band asks for. This form is backward stable everywhere, and the products are
/// carried in the log domain so a degree-100 polynomial cannot overflow.
///
/// Note it is not a ratio in the weights, so the geometric mean that
/// [_baryWeights] divides out has to be put back.
Float64List _lagrange(
    Float64List xq, Float64List x, Float64List y, Float64List gamma) {
  final n = x.length;
  final logs = _baryLogs(x).logs;
  var mean = 0.0;
  for (final v in logs) {
    mean += v;
  }
  mean /= logs.length;

  final logGamma = Float64List(n);
  final signGamma = Float64List(n);
  for (var k = 0; k < n; k++) {
    logGamma[k] = math.log(gamma[k].abs());
    signGamma[k] = gamma[k] < 0 ? -1.0 : 1.0;
  }

  final out = Float64List(xq.length);
  final expo = Float64List(n);
  final sgn = Float64List(n);
  for (var i = 0; i < xq.length; i++) {
    var exact = -1;
    var logL = 0.0;
    var signL = 1.0;
    for (var k = 0; k < n; k++) {
      final diff = xq[i] - x[k];
      final adiff = diff.abs();
      if (adiff < 1e-13) {
        exact = k;
        sgn[k] = 1.0;
        expo[k] = 0.0;
        continue;
      }
      sgn[k] = diff < 0 ? -1.0 : 1.0;
      if (diff < 0) signL = -signL;
      final la = math.log(adiff);
      logL += la;
      expo[k] = -la;
    }
    if (exact >= 0) {
      out[i] = y[exact];
      continue;
    }
    var hi = double.negativeInfinity;
    for (var k = 0; k < n; k++) {
      expo[k] += logL + logGamma[k] - mean;
      if (expo[k] > hi) hi = expo[k];
    }
    var total = 0.0;
    for (var k = 0; k < n; k++) {
      total += signL * signGamma[k] * sgn[k] * y[k] * math.exp(expo[k] - hi);
    }
    out[i] = total * math.exp(hi);
  }
  return out;
}

class _Reference {
  _Reference(this.delta, this.err);
  final double delta;
  final Float64List err;
}

/// Solve the interpolation problem on a reference set.
///
/// By construction the error equals `(-1)^k * delta` at the reference points --
/// Oppenheim & Schafer eq. 7.132.
_Reference _referenceError(Int32List ext, Float64List x, Float64List dq,
    Float64List wq, Float64List sign) {
  final n = ext.length;
  final xext = Float64List(n);
  for (var i = 0; i < n; i++) {
    xext[i] = x[ext[i]];
  }
  final gamma = _baryWeights(xext);

  var num = 0.0, den = 0.0;
  for (var i = 0; i < n; i++) {
    num += gamma[i] * dq[ext[i]];
    den += gamma[i] * sign[i] / wq[ext[i]];
  }
  if (den.abs() < 1e-300) {
    throw RemezError('exchange broke down (singular denominator)');
  }
  final delta = num / den;

  final yext = Float64List(n);
  for (var i = 0; i < n; i++) {
    yext[i] = dq[ext[i]] - sign[i] * delta / wq[ext[i]];
  }
  final p = _lagrange(x, xext, yext, gamma);
  final err = Float64List(x.length);
  for (var i = 0; i < x.length; i++) {
    err[i] = wq[i] * (dq[i] - p[i]);
  }
  return _Reference(delta, err);
}

// ---------------------------------------------------------------------------
// extremal selection
// ---------------------------------------------------------------------------

/// Locate the alternating extrema of the weighted error.
///
/// A candidate is a local maximum of the *signed* error where it is positive,
/// or a local minimum where it is negative. Testing the signed error rather
/// than its magnitude matters: a small dip of the opposite sign at a band edge
/// is a genuine alternation even though `|err|` is larger just next to it.
/// Runs of equal sign are then collapsed to their largest member so the
/// survivors strictly alternate, and the set is trimmed to [nreq] by discarding
/// the smallest deviations in a way that preserves the alternation.
Int32List _findExtrema(Float64List e, int nreq) {
  final n = e.length;
  final cand = <int>[];
  for (var i = 0; i < n; i++) {
    final prev = i == 0 ? null : e[i - 1];
    final next = i == n - 1 ? null : e[i + 1];
    final isMax = e[i] > 0 &&
        (prev == null || e[i] >= prev) &&
        (next == null || e[i] > next);
    final isMin = e[i] < 0 &&
        (prev == null || e[i] <= prev) &&
        (next == null || e[i] < next);
    if (isMax || isMin) cand.add(i);
  }
  if (cand.isEmpty) {
    throw RemezError('no extrema found; the error curve is degenerate');
  }

  final merged = <int>[cand.first];
  for (final i in cand.skip(1)) {
    final same = (e[i] > 0) == (e[merged.last] > 0);
    if (same) {
      if (e[i].abs() > e[merged.last].abs()) merged[merged.length - 1] = i;
    } else {
      merged.add(i);
    }
  }

  if (merged.length < nreq) {
    throw RemezError('only ${merged.length} alternations found where $nreq are '
        'needed; try a denser grid or a different filter length');
  }

  while (merged.length > nreq) {
    final excess = merged.length - nreq;
    if (excess.isOdd) {
      if (e[merged.first].abs() < e[merged.last].abs()) {
        merged.removeAt(0);
      } else {
        merged.removeLast();
      }
    } else {
      var best = 0;
      var bestValue = double.infinity;
      for (var j = 0; j < merged.length - 1; j++) {
        final pair = math.max(e[merged[j]].abs(), e[merged[j + 1]].abs());
        if (pair < bestValue) {
          bestValue = pair;
          best = j;
        }
      }
      merged.removeRange(best, best + 2);
    }
  }
  return Int32List.fromList(merged);
}

// ---------------------------------------------------------------------------
// the exchange
// ---------------------------------------------------------------------------

class _Problem {
  _Problem(this.f, this.band, this.x, this.dq, this.wq, this.floor, this.tol);
  final Float64List f;
  final Int32List band;
  final Float64List x;
  final Float64List dq;
  final Float64List wq;
  final double floor;
  final double tol;
}

Float64List _alternating(int n) {
  final s = Float64List(n);
  for (var i = 0; i < n; i++) {
    s[i] = i.isEven ? 1.0 : -1.0;
  }
  return s;
}

class _Exchange {
  _Exchange(this.ext, this.converged, this.iterations);
  final Int32List ext;
  final bool converged;
  final int iterations;
}

_Exchange _runExchange(_Problem prob, int r, Int32List ext, int maxiter) {
  final sign = _alternating(r + 1);
  var converged = false;
  var it = 0;
  for (it = 1; it <= maxiter; it++) {
    final ref = _referenceError(ext, prob.x, prob.dq, prob.wq, sign);
    var maxErr = 0.0;
    for (final v in ref.err) {
      if (v.abs() > maxErr) maxErr = v.abs();
    }
    if (maxErr <= prob.floor) {
      converged = true;
      break;
    }
    Int32List next;
    try {
      next = _findExtrema(ref.err, r + 1);
    } on RemezError {
      // Degenerate iterate: keep the best reference we have and stop.
      break;
    }
    var peak = 0.0;
    for (final i in next) {
      if (ref.err[i].abs() > peak) peak = ref.err[i].abs();
    }
    if (peak - ref.delta.abs() <= prob.tol * ref.delta.abs() + prob.floor) {
      ext = next;
      converged = true;
      break;
    }
    var same = next.length == ext.length;
    if (same) {
      for (var i = 0; i < next.length; i++) {
        if (next[i] != ext[i]) {
          same = false;
          break;
        }
      }
    }
    if (same) {
      converged = true;
      break;
    }
    ext = next;
  }
  // Running the cap out leaves `it` one past it, where Python's `for it in
  // range(1, maxiter + 1)` leaves it at the cap. Only visible when the cap is
  // actually hit, which is why every converging design agreed anyway.
  return _Exchange(ext, converged, math.min(it, maxiter));
}

/// Evenly spread reference points, with a warp to escape symmetric traps.
///
/// A perfectly uniform reference is degenerate for symmetric problems -- a
/// Hilbert transformer gives delta = 0, and the error then has only n-1
/// alternations instead of n -- so the spacing is warped until it is usable.
Int32List _uniformReference(_Problem prob, int n) {
  for (var attempt = 0; attempt < 6; attempt++) {
    final power = 1.0 + 0.13 * attempt;
    final seen = <int>{};
    final guess = <int>[];
    for (var i = 0; i < n; i++) {
      final t = math.pow(i / (n - 1), power).toDouble();
      final index = (t * (prob.f.length - 1)).round();
      if (seen.add(index)) guess.add(index);
    }
    if (guess.length < n) {
      throw RemezError(
          'grid is too coarse for this filter length; raise the grid density');
    }
    try {
      final ext = Int32List.fromList(guess);
      final ref =
          _referenceError(ext, prob.x, prob.dq, prob.wq, _alternating(n));
      _findExtrema(ref.err, n);
      return ext;
    } on RemezError {
      continue;
    }
  }
  throw RemezError('could not find a starting reference with enough '
      'alternations; try a different filter length or a denser grid');
}

/// Round positions to strictly increasing grid indices inside `[lo, hi]`.
Int32List _distinctIndices(List<double> pos, int lo, int hi) {
  final idx = Int32List(pos.length);
  for (var i = 0; i < pos.length; i++) {
    idx[i] = pos[i].round().clamp(lo, hi);
  }
  for (var k = 1; k < idx.length; k++) {
    if (idx[k] <= idx[k - 1]) idx[k] = idx[k - 1] + 1;
  }
  if (idx[idx.length - 1] > hi) {
    final over = idx[idx.length - 1] - hi;
    for (var k = 0; k < idx.length; k++) {
      idx[k] -= over;
    }
    for (var k = idx.length - 2; k >= 0; k--) {
      if (idx[k] >= idx[k + 1]) idx[k] = idx[k + 1] - 1;
    }
  }
  if (idx[0] < lo) {
    throw RemezError(
        'grid is too coarse for this filter length; raise the grid density');
  }
  return idx;
}

/// Stretch a solved reference of one size into a starting reference of another.
///
/// The extrema of an optimal filter cluster near the band edges in a way that
/// barely changes with the filter length, so the solution of a half-size
/// problem is a far better starting point than an even spread.
Int32List _scaleReference(_Problem prob, Int32List ext, int n) {
  var nb = 0;
  for (final b in prob.band) {
    if (b + 1 > nb) nb = b + 1;
  }
  final lo = List<int>.filled(nb, -1);
  final hi = List<int>.filled(nb, -1);
  for (var i = 0; i < prob.band.length; i++) {
    final b = prob.band[i];
    if (lo[b] < 0) lo[b] = i;
    hi[b] = i;
  }
  final room = List<int>.generate(nb, (i) => hi[i] - lo[i] + 1);

  final groups = List.generate(nb, (_) => <int>[]);
  for (final i in ext) {
    groups[prob.band[i]].add(i);
  }
  final counts = List<double>.generate(
      nb, (i) => math.max(groups[i].length, 1).toDouble());
  var totalCount = 0.0;
  for (final c in counts) {
    totalCount += c;
  }

  final quota = List<int>.generate(nb, (i) {
    final want = (n * counts[i] / totalCount).round();
    return math.min(math.max(2, want), room[i]);
  });

  int sum() => quota.fold(0, (a, b) => a + b);
  while (sum() > n) {
    var k = -1, best = -1;
    for (var i = 0; i < nb; i++) {
      if (quota[i] > 2 && quota[i] > best) {
        best = quota[i];
        k = i;
      }
    }
    if (k < 0) break;
    quota[k] -= 1;
  }
  while (sum() < n) {
    var k = -1, best = 0;
    for (var i = 0; i < nb; i++) {
      final slack = room[i] - quota[i];
      if (slack > best) {
        best = slack;
        k = i;
      }
    }
    if (k < 0) {
      throw RemezError(
          'grid is too coarse for this filter length; raise the grid density');
    }
    quota[k] += 1;
  }

  final out = <int>[];
  for (var i = 0; i < nb; i++) {
    final m = quota[i];
    final g = groups[i];
    final pos = <double>[];
    if (g.length >= 2) {
      for (var j = 0; j < m; j++) {
        final t = (g.length - 1) * j / (m - 1);
        final base = t.floor().clamp(0, g.length - 2);
        final frac = t - base;
        pos.add(g[base] + (g[base + 1] - g[base]) * frac);
      }
    } else {
      for (var j = 0; j < m; j++) {
        pos.add(lo[i] + (hi[i] - lo[i]) * j / (m - 1));
      }
    }
    out.addAll(_distinctIndices(pos, lo[i], hi[i]));
  }
  return Int32List.fromList(out);
}

/// A reference to start from, by scaling up from smaller problems.
///
/// Below `base` coefficients an even spread is fine. Above it the uniform
/// reference is so far from optimal that the first deviation underflows to
/// round-off and the exchange has no signal to follow, so the problem is solved
/// at half the size first and its answer scaled up.
Int32List _startingReference(_Problem prob, int r, {int base = 24}) {
  if (r <= base) return _uniformReference(prob, r + 1);
  final small = math.max(base, r ~/ 2);
  var ext = _startingReference(prob, small, base: base);
  ext = _runExchange(prob, small, ext, 30).ext;
  return _scaleReference(prob, ext, r + 1);
}

// ---------------------------------------------------------------------------
// amplitude -> impulse response
// ---------------------------------------------------------------------------

/// Cosine-series coefficients of P: `P(cos w) = sum_k alpha_k cos(k w)`.
///
/// P has degree r-1, so sampling it at equispaced points around the unit circle
/// and taking a DFT recovers the coefficients exactly. The DFT is orthogonal,
/// which keeps this well conditioned even when P swings over many orders of
/// magnitude across a wide transition band.
Float64List _chebCoeffs(
    int r, Float64List xext, Float64List yext, Float64List gamma) {
  var m = 1;
  while (m < 2 * r) {
    m <<= 1;
  }
  final w = Float64List(m);
  final xs = Float64List(m);
  for (var j = 0; j < m; j++) {
    w[j] = 2.0 * math.pi * j / m;
    xs[j] = math.cos(w[j]);
  }
  final g = _lagrange(xs, xext, yext, gamma);
  final spectrum = realFft(g);
  final alpha = Float64List(r);
  alpha[0] = spectrum.re[0] / m;
  for (var k = 1; k < r; k++) {
    alpha[k] = 2.0 * spectrum.re[k] / m;
  }
  return alpha;
}

/// Turn the coefficients of P into the impulse response.
///
/// `A(w) = Q(w) P(cos w)` is expanded onto the natural basis of each type using
/// the product-to-sum identities, and the taps follow since the n-th basis
/// coefficient is twice the corresponding tap.
Float64List _amplitudeToTaps(int numtaps, int ftype, Float64List alpha) {
  final h = Float64List(numtaps);
  final b = alpha;

  if (ftype == 1) {
    final half = (numtaps - 1) ~/ 2;
    h[half] = b[0];
    for (var k = 1; k <= half; k++) {
      h[half - k] = b[k] / 2.0;
      h[half + k] = b[k] / 2.0;
    }
    return h;
  }

  late int m;
  late Float64List c;
  if (ftype == 2) {
    // cos(w/2) cos(kw) = [cos((k+1/2)w) + cos((k-1/2)w)] / 2
    m = numtaps ~/ 2;
    final bb = Float64List(b.length + 1)..setRange(0, b.length, b);
    c = Float64List(m + 1);
    c[1] = bb[0] + bb[1] / 2.0;
    for (var n = 2; n <= m; n++) {
      c[n] = (bb[n - 1] + bb[n]) / 2.0;
    }
  } else if (ftype == 3) {
    // sin(w) cos(kw) = [sin((k+1)w) - sin((k-1)w)] / 2
    m = (numtaps - 1) ~/ 2;
    final bb = Float64List(b.length + 2)..setRange(0, b.length, b);
    c = Float64List(m + 1);
    c[1] = bb[0] - bb[2] / 2.0;
    for (var n = 2; n <= m; n++) {
      c[n] = (bb[n - 1] - bb[n + 1]) / 2.0;
    }
  } else {
    // sin(w/2) cos(kw) = [sin((k+1/2)w) - sin((k-1/2)w)] / 2
    m = numtaps ~/ 2;
    final bb = Float64List(b.length + 1)..setRange(0, b.length, b);
    c = Float64List(m + 1);
    c[1] = bb[0] - bb[1] / 2.0;
    for (var n = 2; n <= m; n++) {
      c[n] = (bb[n - 1] - bb[n]) / 2.0;
    }
  }

  for (var n = 1; n <= m; n++) {
    h[m - n] = c[n] / 2.0;
  }
  if (ftype == 2) {
    for (var n = 1; n <= m; n++) {
      h[m - 1 + n] = h[m - n];
    }
  } else if (ftype == 3) {
    for (var n = 1; n <= m; n++) {
      h[m + n] = -h[m - n];
    }
    h[m] = 0.0; // the centre tap of a type III filter
  } else {
    for (var n = 1; n <= m; n++) {
      h[m - 1 + n] = -h[m - n];
    }
  }
  return h;
}

// ---------------------------------------------------------------------------
// the entry point
// ---------------------------------------------------------------------------

/// Design a linear-phase FIR filter by the Remez exchange algorithm.
RemezResult design(
  int numtaps,
  List<Band> bands, {
  Symmetry symmetry = Symmetry.symmetric,
  double fs = 1.0,
  int gridDensity = 16,
  int maxiter = 40,
  double tol = 1e-8,
}) {
  if (numtaps < 3) throw RemezError('numtaps must be at least 3');
  if (bands.isEmpty) throw RemezError('at least one band is required');

  final type = _classify(numtaps, symmetry);
  if (type.r < 2) {
    throw RemezError(
        'filter length $numtaps is too short for a type ${type.ftype} filter');
  }

  final nyq = fs / 2.0;
  final norm = <Band>[];
  var prev = double.negativeInfinity;
  for (var i = 0; i < bands.length; i++) {
    final b = bands[i];
    if (!(b.f1 >= 0.0 && b.f1 < b.f2 && b.f2 <= nyq)) {
      throw RemezError('band ${i + 1}: need 0 <= f1 < f2 <= fs/2 '
          '(${_short(nyq)}), got ${_short(b.f1)}..${_short(b.f2)}');
    }
    if (b.f1 < prev - 1e-12) {
      throw RemezError('band ${i + 1} overlaps the previous band');
    }
    prev = b.f2;
    norm.add(b.scaled(1.0 / fs));
  }

  final grid = _buildGrid(norm, type.r, gridDensity, type.ftype);
  final want = _interpBand(norm, grid);

  final n = grid.f.length;
  final x = Float64List(n);
  final dq = Float64List(n);
  final wq = Float64List(n);
  final q = Float64List(n);
  for (var i = 0; i < n; i++) {
    final omega = 2.0 * math.pi * grid.f[i];
    x[i] = math.cos(omega);
    q[i] = _qFactor(type.ftype, omega);
    dq[i] = want.d[i] / q[i];
    wq[i] = want.w[i] * q[i];
  }
  if (n < type.r + 1) {
    throw RemezError(
        'grid is too coarse for this filter length; raise the grid density');
  }

  // The stopping test is relative, which says nothing once delta has shrunk to
  // the size of the round-off in the grid values, so it gets an absolute floor.
  var scale = 1.0;
  for (var i = 0; i < n; i++) {
    final v = (wq[i] * dq[i]).abs();
    if (v > scale) scale = v;
  }
  final prob = _Problem(grid.f, grid.band, x, dq, wq, 1e-12 * scale, tol);

  var ext = _startingReference(prob, type.r);
  final run = _runExchange(prob, type.r, ext, maxiter);
  ext = run.ext;

  final sign = _alternating(type.r + 1);
  final xext = Float64List(ext.length);
  for (var i = 0; i < ext.length; i++) {
    xext[i] = x[ext[i]];
  }
  final gamma = _baryWeights(xext);
  var num = 0.0, den = 0.0;
  for (var i = 0; i < ext.length; i++) {
    num += gamma[i] * dq[ext[i]];
    den += gamma[i] * sign[i] / wq[ext[i]];
  }
  final delta = num / den;
  final yext = Float64List(ext.length);
  for (var i = 0; i < ext.length; i++) {
    yext[i] = dq[ext[i]] - sign[i] * delta / wq[ext[i]];
  }

  final p = _lagrange(x, xext, yext, gamma);
  final amp = Float64List(n);
  final err = Float64List(n);
  for (var i = 0; i < n; i++) {
    amp[i] = q[i] * p[i];
    err[i] = want.w[i] * (want.d[i] - amp[i]);
  }

  final h = _amplitudeToTaps(
      numtaps, type.ftype, _chebCoeffs(type.r, xext, yext, gamma));
  for (final v in h) {
    if (!v.isFinite) {
      throw RemezError('the design is numerically degenerate: the amplitude in '
          'the unconstrained transition region overflows.  Use fewer taps, or '
          'constrain more of the frequency axis.');
    }
  }

  // A polynomial pinned down only over narrow bands can do anything at all in
  // between; a huge peak there means the taps are meaningless in practice.
  final wFull = Float64List(math.max(8 * numtaps, 512));
  for (var i = 0; i < wFull.length; i++) {
    wFull[i] = math.pi * i / (wFull.length - 1);
  }
  var peak = 0.0;
  for (final v in amplitudeResponse(h, wFull, symmetry)) {
    if (v.abs() > peak) peak = v.abs();
  }

  final dev = List<double>.filled(norm.length, 0.0);
  for (var i = 0; i < n; i++) {
    final d = (want.d[i] - amp[i]).abs();
    if (d > dev[grid.band[i]]) dev[grid.band[i]] = d;
  }

  final gridFPhysical = Float64List(n);
  for (var i = 0; i < n; i++) {
    gridFPhysical[i] = grid.f[i] * fs;
  }
  final extF = Float64List(ext.length);
  final extE = Float64List(ext.length);
  for (var i = 0; i < ext.length; i++) {
    extF[i] = grid.f[ext[i]] * fs;
    extE[i] = err[ext[i]];
  }

  return RemezResult(
    h: h,
    numtaps: numtaps,
    ftype: type.ftype,
    symmetry: symmetry,
    delta: delta,
    gridF: gridFPhysical,
    gridD: want.d,
    gridW: want.w,
    gridA: amp,
    gridE: err,
    gridBand: grid.band,
    extremalF: extF,
    extremalE: extE,
    iterations: run.iterations,
    converged: run.converged,
    bandDeviation: dev,
    peakAmplitude: peak,
    fs: fs,
    bands: bands,
  );
}

/// Re-analyse a design as if it had been built with the taps [h].
///
/// Everything measured is recomputed; the fields that describe the *design*
/// rather than the filter (delta, the extremal frequencies, the iteration
/// count) are carried over, since rounding the taps afterwards does not change
/// what the exchange achieved.
RemezResult withTaps(RemezResult res, Float64List h) {
  if (h.length != res.h.length) {
    throw RemezError('expected ${res.h.length} taps, got ${h.length}');
  }
  final n = res.gridF.length;
  final w = Float64List(n);
  for (var i = 0; i < n; i++) {
    w[i] = 2.0 * math.pi * res.gridF[i] / res.fs;
  }
  final amp = amplitudeResponse(h, w, res.symmetry);
  final err = Float64List(n);
  for (var i = 0; i < n; i++) {
    err[i] = res.gridW[i] * (res.gridD[i] - amp[i]);
  }

  final dev = List<double>.filled(res.bands.length, 0.0);
  for (var i = 0; i < n; i++) {
    final d = (res.gridD[i] - amp[i]).abs();
    if (d > dev[res.gridBand[i]]) dev[res.gridBand[i]] = d;
  }

  final wFull = Float64List(math.max(8 * res.numtaps, 512));
  for (var i = 0; i < wFull.length; i++) {
    wFull[i] = math.pi * i / (wFull.length - 1);
  }
  var peak = 0.0;
  for (final v in amplitudeResponse(h, wFull, res.symmetry)) {
    if (v.abs() > peak) peak = v.abs();
  }

  final extW = Float64List(res.extremalF.length);
  for (var i = 0; i < extW.length; i++) {
    extW[i] = 2.0 * math.pi * res.extremalF[i] / res.fs;
  }
  final extAmp = amplitudeResponse(h, extW, res.symmetry);
  final extE = Float64List(extW.length);
  for (var i = 0; i < extW.length; i++) {
    // The nearest grid point carries the desired value and the weight.
    var best = 0;
    var bestDistance = double.infinity;
    for (var j = 0; j < n; j++) {
      final d = (res.gridF[j] - res.extremalF[i]).abs();
      if (d < bestDistance) {
        bestDistance = d;
        best = j;
      }
    }
    extE[i] = res.gridW[best] * (res.gridD[best] - extAmp[i]);
  }

  return RemezResult(
    h: h,
    numtaps: res.numtaps,
    ftype: res.ftype,
    symmetry: res.symmetry,
    delta: res.delta,
    gridF: res.gridF,
    gridD: res.gridD,
    gridW: res.gridW,
    gridA: amp,
    gridE: err,
    gridBand: res.gridBand,
    extremalF: res.extremalF,
    extremalE: extE,
    iterations: res.iterations,
    converged: res.converged,
    bandDeviation: dev,
    peakAmplitude: peak,
    fs: res.fs,
    bands: res.bands,
  );
}

String _short(double v) {
  if (v == v.roundToDouble() && v.abs() < 1e15) {
    return v.toStringAsFixed(0);
  }
  return v.toString();
}
