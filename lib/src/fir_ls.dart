/// Two FIR designs that are not the Remez exchange.
///
/// The exchange minimises the *worst* weighted error, which is the right thing
/// to ask for when a specification is a limit that must not be exceeded. It is
/// not the only thing worth asking for.
///
/// **Least squares** minimises the total squared error instead. It gives up on
/// the worst case -- the error is largest at the band edges and falls away from
/// them -- and buys a stopband that keeps getting deeper the further from the
/// transition you look, rather than one flat wall of equal lobes. Where the
/// interference is broadband, or the filter feeds something that integrates,
/// total energy is the number that matters and equiripple is spending taps to
/// hold up a corner nobody is standing on.
///
/// **The window method** does not optimise anything. It takes the exact impulse
/// response of the ideal brick wall, which is infinitely long, cuts it to
/// length, and tapers the cut with a window so the truncation does not ring.
/// It is the oldest method and the least clever, and it has two things going
/// for it: there is no iteration to fail to converge, and the stopband depth
/// is a property of the window rather than of the design -- a Blackman window
/// bottoms out around 74 dB and no amount of extra length improves on that.
/// The catch is the other direction: the filter only *reaches* the window's
/// figure once it is long enough for the window's main lobe to fit inside the
/// transition. Ask for a narrow transition with a Blackman window and a short
/// filter and you get neither the transition nor the 74 dB.
///
/// Both are parameterised by the free half of the taps rather than by the
/// cosine coefficients of the amplitude response. Symmetry then takes care of
/// the four linear-phase types on its own: a filter forced to be antisymmetric
/// and even-length simply cannot have a non-zero response at DC, and nothing
/// here has to know that.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'fir_core.dart';

/// Which method designed a filter.
enum FirMethod { remez, leastSquares, window }

/// The taper the window method cuts the ideal response with.
///
/// Each trades main-lobe width -- how wide a transition it needs -- against
/// sidelobe height, which is what the stopband floor ends up being.
enum FirWindow { rectangular, hann, hamming, blackman, kaiser }

extension FirWindowName on FirWindow {
  String get label => switch (this) {
        FirWindow.rectangular => 'rectangular',
        FirWindow.hann => 'Hann',
        FirWindow.hamming => 'Hamming',
        FirWindow.blackman => 'Blackman',
        FirWindow.kaiser => 'Kaiser',
      };

  /// The window's own peak sidelobe, in dB, which is the floor the stopband
  /// approaches once the filter is long enough for the main lobe to fit the
  /// transition. A shorter filter than that does worse, sometimes much worse.
  double get attenuation => switch (this) {
        FirWindow.rectangular => 21,
        FirWindow.hann => 44,
        FirWindow.hamming => 53,
        FirWindow.blackman => 74,
        FirWindow.kaiser => 0, // set by beta, not by the window
      };
}

extension FirMethodName on FirMethod {
  String get label => switch (this) {
        FirMethod.remez => 'Remez exchange',
        FirMethod.leastSquares => 'least squares',
        FirMethod.window => 'window',
      };
}

/// Design by weighted least squares.
///
/// Minimises `sum W(f)^2 (D(f) - A(f))^2` over the bands, which is a linear
/// problem in the taps and so has one solution reached in one step -- there is
/// no exchange and nothing to converge.
RemezResult designLeastSquares(
  int numtaps,
  List<Band> bands, {
  Symmetry symmetry = Symmetry.symmetric,
  double fs = 1.0,
  int gridDensity = 16,
}) {
  final grid = _Grid.over(bands, numtaps, fs, gridDensity);
  final free = _freeTaps(numtaps, symmetry);
  final basis = _basis(grid.w, numtaps, symmetry, free);

  // Normal equations: (B' W^2 B) c = B' W^2 d. Symmetric and positive
  // definite as long as the grid has more points than free taps, which the
  // density guarantees by a wide margin.
  final a = List.generate(free, (_) => Float64List(free));
  final rhs = Float64List(free);
  for (var i = 0; i < grid.w.length; i++) {
    final weight = grid.weight[i] * grid.weight[i];
    for (var j = 0; j < free; j++) {
      final bij = basis[i][j] * weight;
      rhs[j] += bij * grid.desired[i];
      for (var k = j; k < free; k++) {
        a[j][k] += bij * basis[i][k];
      }
    }
  }
  for (var j = 0; j < free; j++) {
    for (var k = 0; k < j; k++) {
      a[j][k] = a[k][j];
    }
  }

  final c = _solve(a, rhs);
  return _finish(_expand(c, numtaps, symmetry), numtaps, symmetry, bands, fs,
      grid, FirMethod.leastSquares);
}

/// Design by truncating the ideal impulse response and tapering the cut.
///
/// The ideal response steps at the midpoint of each transition, which is the
/// classical construction and the reason each window delivers the attenuation
/// its textbook figure promises.
RemezResult designWindowed(
  int numtaps,
  List<Band> bands, {
  Symmetry symmetry = Symmetry.symmetric,
  double fs = 1.0,
  int gridDensity = 16,
  FirWindow window = FirWindow.hamming,
  double kaiserBeta = 8.6,
  int integrationPoints = 4096,
}) {
  final centre = (numtaps - 1) / 2.0;
  final sym = symmetry == Symmetry.symmetric;
  final h = Float64List(numtaps);

  // h[n] = (1/pi) * integral of D(w) cos(w(centre - n)) dw, over 0..pi, and
  // the sine of the same for an antisymmetric filter. Simpson's rule over a
  // fine grid: D is piecewise linear, so the only thing to resolve is the
  // cosine, and a few thousand points does that to well past the precision
  // the taps are stored at.
  final n = integrationPoints.isEven ? integrationPoints : integrationPoints + 1;
  final step = math.pi / n;
  for (var k = 0; k < numtaps; k++) {
    final lag = centre - k;
    var total = 0.0;
    for (var i = 0; i <= n; i++) {
      final w = i * step;
      final d = _desiredAt(w * fs / (2 * math.pi), bands);
      final kernel = sym ? math.cos(w * lag) : math.sin(w * lag);
      final weight = (i == 0 || i == n) ? 1.0 : (i.isOdd ? 4.0 : 2.0);
      total += weight * d * kernel;
    }
    h[k] = total * step / 3.0 / math.pi;
  }

  final taper = _window(numtaps, window, kaiserBeta);
  for (var k = 0; k < numtaps; k++) {
    h[k] *= taper[k];
  }
  // Truncation and tapering both break the exact symmetry very slightly.
  // Restoring it is not cosmetic: it is what makes the phase exactly linear.
  for (var k = 0; k < numtaps ~/ 2; k++) {
    final mean = (h[k] + (sym ? 1 : -1) * h[numtaps - 1 - k]) / 2;
    h[k] = mean;
    h[numtaps - 1 - k] = sym ? mean : -mean;
  }
  if (numtaps.isOdd && !sym) h[numtaps ~/ 2] = 0.0;

  final grid = _Grid.over(bands, numtaps, fs, gridDensity);
  return _finish(h, numtaps, symmetry, bands, fs, grid, FirMethod.window);
}

// ---------------------------------------------------------------------------

/// How many taps are free once the symmetry has had its say.
int _freeTaps(int numtaps, Symmetry symmetry) =>
    symmetry == Symmetry.symmetric
        ? (numtaps + 1) ~/ 2
        : numtaps ~/ 2; // an antisymmetric odd-length centre tap is zero

/// `A(w) = sum_j c[j] * basis[j](w)`, where `c` is the free half of the taps.
List<Float64List> _basis(
    Float64List w, int numtaps, Symmetry symmetry, int free) {
  final centre = (numtaps - 1) / 2.0;
  final sym = symmetry == Symmetry.symmetric;
  return [
    for (var i = 0; i < w.length; i++)
      Float64List(free)
        ..setRange(0, free, [
          for (var j = 0; j < free; j++)
            // Tap j and its partner N-1-j contribute equally: cosine is even
            // and the antisymmetric sine picks up two sign changes. The odd
            // centre tap of a symmetric filter has no partner.
            (numtaps.isOdd && sym && j == numtaps ~/ 2)
                ? 1.0
                : 2.0 *
                    (sym
                        ? math.cos(w[i] * (centre - j))
                        : math.sin(w[i] * (centre - j)))
        ])
  ];
}

Float64List _expand(Float64List c, int numtaps, Symmetry symmetry) {
  final h = Float64List(numtaps);
  final sym = symmetry == Symmetry.symmetric;
  for (var j = 0; j < c.length; j++) {
    h[j] = c[j];
    h[numtaps - 1 - j] = sym ? c[j] : -c[j];
  }
  if (numtaps.isOdd && sym) h[numtaps ~/ 2] = c[numtaps ~/ 2];
  return h;
}

/// The desired amplitude at physical frequency [f].
///
/// Sloped inside a band, as the band asks; a step at the middle of each
/// transition, where nothing was asked for at all.
double _desiredAt(double f, List<Band> bands) {
  if (f <= bands.first.f1) return bands.first.d1;
  for (var i = 0; i < bands.length; i++) {
    final b = bands[i];
    if (f > b.f2) continue;
    if (f >= b.f1) {
      final span = b.f2 - b.f1;
      final t = span <= 0 ? 0.0 : (f - b.f1) / span;
      return b.d1 + t * (b.d2 - b.d1);
    }
    // In a transition, where nothing was specified. The ideal response steps
    // at the midpoint: that is the brick wall the window method is defined as
    // truncating, and it is what makes the answer predictable -- ramping
    // across the gap instead would pre-smooth the target and give a much
    // deeper stopband than the window's own figure, for reasons that have
    // nothing to do with the window.
    final prev = bands[i - 1];
    return f < (prev.f2 + b.f1) / 2 ? prev.d2 : b.d1;
  }
  return bands.last.d2;
}

Float64List _window(int n, FirWindow kind, double beta) {
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    final t = n == 1 ? 0.0 : 2 * math.pi * i / (n - 1);
    out[i] = switch (kind) {
      FirWindow.rectangular => 1.0,
      FirWindow.hann => 0.5 - 0.5 * math.cos(t),
      FirWindow.hamming => 0.54 - 0.46 * math.cos(t),
      FirWindow.blackman =>
        0.42 - 0.5 * math.cos(t) + 0.08 * math.cos(2 * t),
      FirWindow.kaiser => _besselI0(
              beta * math.sqrt(1 - math.pow(2 * i / (n - 1) - 1, 2).clamp(0, 1))) /
          _besselI0(beta),
    };
  }
  return out;
}

/// Modified Bessel function of the first kind, order zero, by its series.
///
/// It converges quickly for the arguments a Kaiser window uses -- beta is
/// rarely above 20 -- and the terms are all positive, so there is nothing to
/// cancel.
double _besselI0(double x) {
  var term = 1.0;
  var sum = 1.0;
  for (var k = 1; k < 60; k++) {
    term *= (x / (2 * k)) * (x / (2 * k));
    sum += term;
    if (term < sum * 1e-17) break;
  }
  return sum;
}

/// Gaussian elimination with partial pivoting.
///
/// The normal equations are symmetric and positive definite, so Cholesky would
/// do; pivoting is used anyway because a badly conditioned design -- a very
/// long filter over a very narrow band -- is exactly when a user finds out,
/// and failing loudly beats returning a filter built from a divided zero.
Float64List _solve(List<Float64List> a, Float64List b) {
  final n = b.length;
  final x = Float64List.fromList(b);
  for (var col = 0; col < n; col++) {
    var pivot = col;
    for (var row = col + 1; row < n; row++) {
      if (a[row][col].abs() > a[pivot][col].abs()) pivot = row;
    }
    if (a[pivot][col].abs() < 1e-300) {
      throw RemezError('this least-squares design is singular: the taps are '
          'not determined by the bands given');
    }
    if (pivot != col) {
      final t = a[pivot];
      a[pivot] = a[col];
      a[col] = t;
      final tv = x[pivot];
      x[pivot] = x[col];
      x[col] = tv;
    }
    for (var row = col + 1; row < n; row++) {
      final factor = a[row][col] / a[col][col];
      if (factor == 0.0) continue;
      for (var k = col; k < n; k++) {
        a[row][k] -= factor * a[col][k];
      }
      x[row] -= factor * x[col];
    }
  }
  for (var row = n - 1; row >= 0; row--) {
    var sum = x[row];
    for (var k = row + 1; k < n; k++) {
      sum -= a[row][k] * x[k];
    }
    x[row] = sum / a[row][row];
  }
  return x;
}

/// The dense grid these methods measure themselves on.
class _Grid {
  _Grid(this.f, this.w, this.desired, this.weight, this.band);

  final Float64List f;
  final Float64List w;
  final Float64List desired;
  final Float64List weight;
  final Int32List band;

  /// Points spread over the bands in proportion to their width.
  factory _Grid.over(
      List<Band> bands, int numtaps, double fs, int gridDensity) {
    if (bands.isEmpty) throw RemezError('a design needs at least one band');
    final total = bands.fold<double>(0, (sum, b) => sum + (b.f2 - b.f1));
    if (!(total > 0)) throw RemezError('the bands have no width between them');
    final wanted = math.max(gridDensity * numtaps, 4 * numtaps);

    final f = <double>[];
    final desired = <double>[];
    final weight = <double>[];
    final band = <int>[];
    for (var i = 0; i < bands.length; i++) {
      final b = bands[i];
      final span = b.f2 - b.f1;
      final count = math.max(2, (wanted * span / total).round());
      for (var k = 0; k < count; k++) {
        final t = count == 1 ? 0.0 : k / (count - 1);
        final at = b.f1 + t * span;
        f.add(at);
        desired.add(b.d1 + t * (b.d2 - b.d1));
        weight.add(b.weightKind == WeightKind.inverseF
            ? b.w1 / math.max(at / fs, 1e-9)
            : b.w1 + t * (b.w2 - b.w1));
        band.add(i);
      }
    }
    final w = Float64List(f.length);
    for (var i = 0; i < f.length; i++) {
      w[i] = 2 * math.pi * f[i] / fs;
    }
    return _Grid(Float64List.fromList(f), w, Float64List.fromList(desired),
        Float64List.fromList(weight), Int32List.fromList(band));
  }
}

/// Package the taps as a [RemezResult], so everything downstream -- the plots,
/// the report, every exporter -- works without knowing which method ran.
///
/// The fields the exchange fills in and these methods have no analogue for are
/// filled honestly rather than plausibly: no iterations, no extremal
/// frequencies. `delta` is the achieved peak weighted error, which for the
/// exchange is what it converged to and here is simply what came out.
RemezResult _finish(Float64List h, int numtaps, Symmetry symmetry,
    List<Band> bands, double fs, _Grid grid, FirMethod method) {
  final amplitude = amplitudeResponse(h, grid.w, symmetry);
  final error = Float64List(grid.w.length);
  final deviation = List<double>.filled(bands.length, 0.0);
  var peakWeighted = 0.0;
  for (var i = 0; i < grid.w.length; i++) {
    final raw = grid.desired[i] - amplitude[i];
    error[i] = grid.weight[i] * raw;
    if (error[i].abs() > peakWeighted) peakWeighted = error[i].abs();
    if (raw.abs() > deviation[grid.band[i]]) {
      deviation[grid.band[i]] = raw.abs();
    }
  }

  // Over the whole axis, transitions included: a windowed or least-squares
  // design can overshoot in a transition band, and the plot has to fit it.
  final dense = Float64List(2048);
  for (var i = 0; i < dense.length; i++) {
    dense[i] = math.pi * i / (dense.length - 1);
  }
  var peak = 0.0;
  for (final v in amplitudeResponse(h, dense, symmetry)) {
    if (v.abs() > peak) peak = v.abs();
  }

  return RemezResult(
    h: h,
    numtaps: numtaps,
    ftype: symmetry == Symmetry.symmetric
        ? (numtaps.isOdd ? 1 : 2)
        : (numtaps.isOdd ? 3 : 4),
    symmetry: symmetry,
    delta: peakWeighted,
    gridF: grid.f,
    gridD: grid.desired,
    gridW: grid.weight,
    gridA: amplitude,
    gridE: error,
    gridBand: grid.band,
    // No alternation to mark: neither method has extremal frequencies, and
    // drawing the peaks of an error that was never equalised would suggest
    // an optimality that is not being claimed.
    extremalF: Float64List(0),
    extremalE: Float64List(0),
    iterations: 0,
    converged: true,
    bandDeviation: deviation,
    peakAmplitude: peak,
    fs: fs,
    bands: bands,
  );
}
