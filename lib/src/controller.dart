/// The design state behind the UI: what has been asked for, and what came back.
library;

import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'fir_core.dart' as fir;
import 'fixed_point.dart' as fx;
import 'iir_core.dart' as iir;
import 'labels.dart';

enum Mode { fir, iir }

enum Arithmetic { floating, fixed }

/// How far the port has been checked against the Python implementation.
///
/// The IIR models were ported one at a time and each is compared against
/// reference designs from the original. Anything not yet matching is still
/// offered -- it designs something -- but it is labelled, because "looks
/// plausible" is not the same as "agrees with the implementation it replaces".
enum Verified { exact, unverified }

/// Which colour scheme the window uses.
///
/// `system` follows the desktop, which is what most people want; the two fixed
/// choices are for when the plots are going into a document that has already
/// decided.
enum Appearance { system, light, dark }

/// Which of the two right-hand panes is showing.
///
/// Named for the pane rather than the view because Flutter already has a
/// `View`, and importing both into `main.dart` is ambiguous.
enum Pane { plot, design }

class IirModel {
  const IirModel(this.approximation, this.response, this.verified);
  final String approximation;
  final String response;
  final Verified verified;
}

/// Which (approximation, response) pairs reproduce the Python design exactly.
///
/// All of them, now. The set is kept rather than deleted because it is what the
/// UI reads to decide whether to caveat a model, and because a future
/// approximation lands here unverified until its reference designs agree.
final Set<String> _verifiedPairs = {
  for (final a in ['butterworth', 'chebyshev1', 'chebyshev2', 'elliptic'])
    for (final r in ['lowpass', 'highpass', 'bandpass', 'bandstop']) '$a/$r',
};

Verified verificationOf(String approximation, String response) =>
    _verifiedPairs.contains('$approximation/$response')
        ? Verified.exact
        : Verified.unverified;

/// One row of the FIR band table, as text so it can be edited freely.
///
/// [spec] is the band's requirement in dB — peak-to-peak ripple for a passband,
/// attenuation for a stopband — and is only read when [DesignController.useSpec]
/// is set, in which case it replaces [weight].
class BandRow {
  BandRow(this.f1, this.f2, this.d1, this.d2, this.weight, this.spec,
      {this.invF = false});
  String f1;
  String f2;

  /// The desired amplitude at the start and the end of the band. The exchange
  /// ramps linearly between them, which is how a sloped target -- the skirt of
  /// a raised-cosine band, or a differentiator's 2*pi*f -- is asked for.
  String d1;
  String d2;
  String weight;
  String spec;

  /// Weight as w/f across the band rather than a constant.
  ///
  /// That equalises the *relative* error, which is what a differentiator wants:
  /// a fixed absolute error is negligible at the top of the band and hopeless
  /// at the bottom.
  bool invF;

  BandRow copy() => BandRow(f1, f2, d1, d2, weight, spec, invF: invF);
}

class DesignController extends ChangeNotifier {
  // --- what was asked for ---
  Mode mode = Mode.fir;
  double fs = 1.0;

  int numtaps = 41;
  fir.Symmetry symmetry = fir.Symmetry.symmetric;

  /// Dense-grid points per basis coefficient.
  ///
  /// The exchange only ever sees the response on this grid, so a thin one can
  /// step over a ripple peak and settle on a filter whose true deviation is
  /// worse than the delta it reports. Raising it costs time roughly linearly.
  int gridDensity = 16;

  /// The iteration cap, and what "did not converge" in the report means.
  int maxiter = 60;

  /// Which preset the band table was last loaded from, for the pulldown.
  String? preset = 'Lowpass';
  List<BandRow> rows = [
    BandRow('0', '0.2', '1', '1', '1', '0.5'),
    BandRow('0.25', '0.5', '0', '0', '10', '50'),
  ];

  /// Take the band weights from the Spec column rather than the Weight column.
  bool useSpec = false;

  /// The deviation each band's dB spec asks for, once [useSpec] is set.
  ///
  /// Null when the weights are being entered directly, which is what the plot
  /// and the report test to decide whether there is a spec to draw or check
  /// against.
  List<double>? specDev;

  String response = 'lowpass';
  String approximation = 'butterworth';
  bool autoOrder = true;
  int order = 6;
  List<String> wp = ['0.2', '0.4'];
  List<String> ws = ['0.3', '0.45'];
  String rp = '0.5';
  String rs = '40';

  Arithmetic arithmetic = Arithmetic.floating;
  int wordBits = 16;
  bool autoFrac = true;
  int fracBits = 15;
  int headroom = 2;

  // --- what the hardware export should build ---
  /// Coefficients baked into the RTL as constants, rather than driven in.
  bool fixedCoeffs = true;
  String structure = 'chain';
  bool folded = false;
  bool wantTestbench = true;

  bool logScale = true;
  Pane view = Pane.plot;
  Appearance appearance = Appearance.system;

  // --- what came back ---
  fir.RemezResult? firResult;
  fir.RemezResult? firEffective;
  iir.IIRResult? iirResult;
  iir.IIRResult? iirEffective;
  fx.Fixed? fixed;
  String? error;
  Duration? lastDesignTime;

  bool get isIir => mode == Mode.iir;
  bool get isFixed => arithmetic == Arithmetic.fixed;
  bool get hasResult => isIir ? iirEffective != null : firEffective != null;

  Verified get verification =>
      isIir ? verificationOf(approximation, response) : Verified.exact;

  /// How many band edges this response needs.
  int get edgeCount => (response == 'bandpass' || response == 'bandstop') ? 2 : 1;

  void update(void Function() change) {
    change();
    design();
  }

  /// Change the sample rate, carrying the band edges with it.
  ///
  /// Edges are entered in whatever units the rate is in, so changing 1.0 to
  /// 48000 means the same 0.2 is now 9600: the number changes and the filter
  /// does not.
  void setSampleRate(double value) {
    if (!(value > 0) || value == fs) return;
    final ratio = value / fs;
    fs = value;
    String scale(String text) {
      final v = double.tryParse(text);
      return v == null ? text : _trim(v * ratio);
    }

    for (final row in rows) {
      row.f1 = scale(row.f1);
      row.f2 = scale(row.f2);
    }
    for (var i = 0; i < wp.length; i++) {
      wp[i] = scale(wp[i]);
    }
    for (var i = 0; i < ws.length; i++) {
      ws[i] = scale(ws[i]);
    }
    design();
  }

  void design() {
    final watch = Stopwatch()..start();
    error = null;
    try {
      if (isIir) {
        _designIir();
      } else {
        _designFir();
      }
      _applyArithmetic();
    } on fir.RemezError catch (e) {
      error = e.message;
      firResult = firEffective = null;
    } on iir.IIRError catch (e) {
      error = e.message;
      iirResult = iirEffective = null;
    } on fx.FixedPointError catch (e) {
      error = e.message;
    } catch (e) {
      error = '$e';
    }
    watch.stop();
    lastDesignTime = watch.elapsed;
    notifyListeners();
  }

  void _designFir() {
    final f1 = Float64List(rows.length);
    final f2 = Float64List(rows.length);
    final d1 = Float64List(rows.length);
    final d2 = Float64List(rows.length);
    final weights = Float64List(rows.length);
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final values = [r.f1, r.f2, r.d1, r.d2, r.weight]
          .map(double.tryParse)
          .toList();
      if (values.any((v) => v == null)) {
        throw fir.RemezError('band ${i + 1}: every field must be a number');
      }
      f1[i] = values[0]!;
      f2[i] = values[1]!;
      d1[i] = values[2]!;
      d2[i] = values[3]!;
      weights[i] = values[4]!;
    }

    specDev = useSpec ? _weightsFromSpec(d1, d2, weights) : null;

    final bands = [
      for (var i = 0; i < rows.length; i++)
        fir.Band(f1[i], f2[i], d1[i], d2[i],
            w1: weights[i],
            w2: weights[i],
            weightKind: rows[i].invF
                ? fir.WeightKind.inverseF
                : fir.WeightKind.constant)
    ];
    firResult = fir.design(numtaps, bands,
        symmetry: symmetry,
        fs: fs,
        gridDensity: gridDensity,
        maxiter: maxiter);
    firEffective = firResult;
    iirResult = iirEffective = null;
  }

  /// Turn each band's dB spec into a deviation, and overwrite [weights].
  ///
  /// The exchange equalises W_i·delta_i across the bands, so a set of ripple
  /// limits delta_i is met exactly when the weights are inversely proportional
  /// to them. Only the ratios matter, so they are normalised to the loosest
  /// band, which keeps the numbers near one and leaves delta readable.
  ///
  /// What the dB figure means depends on the band: a stopband (desired zero) is
  /// asking for attenuation, a passband for peak-to-peak ripple about its gain.
  List<double> _weightsFromSpec(
      Float64List d1, Float64List d2, Float64List weights) {
    final devs = <double>[];
    for (var i = 0; i < rows.length; i++) {
      final spec = double.tryParse(rows[i].spec);
      if (spec == null) {
        throw fir.RemezError('band ${i + 1}: the dB spec must be a number');
      }
      if (spec <= 0) {
        throw fir.RemezError('band ${i + 1}: the dB spec must be positive');
      }
      final peak = math.max(d1[i].abs(), d2[i].abs());
      if (peak < 1e-12) {
        devs.add(math.pow(10.0, -spec / 20.0).toDouble());
      } else {
        final g = math.pow(10.0, spec / 20.0).toDouble();
        devs.add(peak * (g - 1.0) / (g + 1.0));
      }
    }
    final ref = devs.reduce(math.max);
    for (var i = 0; i < devs.length; i++) {
      weights[i] = ref / devs[i];
    }
    return devs;
  }

  void _designIir() {
    List<double> parse(List<String> values, String what) {
      final out = <double>[];
      for (var i = 0; i < edgeCount; i++) {
        final v = double.tryParse(values[i]);
        if (v == null) throw iir.IIRError('$what edge ${i + 1} is not a number');
        out.add(v);
      }
      return out;
    }

    final ripple = double.tryParse(rp);
    final atten = double.tryParse(rs);
    if (ripple == null || atten == null) {
      throw iir.IIRError('the ripple and attenuation must be numbers');
    }
    iirResult = iir.design(
      response,
      approximation,
      wp: parse(wp, 'passband'),
      ws: parse(ws, 'stopband'),
      rp: ripple,
      rs: atten,
      order: autoOrder ? null : order,
      fs: fs,
    );
    if (autoOrder) order = iirResult!.order;
    iirEffective = iirResult;
    firResult = firEffective = null;
  }

  void _applyArithmetic() {
    fixed = null;
    if (!isFixed) return;
    final frac = autoFrac ? null : fracBits;
    if (isIir && iirResult != null) {
      final q = fx.quantizeSos(iirResult!.sos, wordBits, fracBits: frac);
      fixed = q;
      if (autoFrac) fracBits = q.fracBits;
      iirEffective = iir.withSos(iirResult!, fx.sosRows(q));
    } else if (firResult != null) {
      final q = fx.quantize(firResult!.h, wordBits, fracBits: frac);
      fixed = q;
      if (autoFrac) fracBits = q.fracBits;
      firEffective = fir.withTaps(firResult!, q.values);
    }
  }

  /// Change the IIR response, bringing edges that make sense for it.
  ///
  /// A highpass needs its stopband below its passband and a bandpass needs four
  /// edges in order; carrying the previous response's numbers over would
  /// otherwise put an error on screen the moment the pulldown was touched.
  void setResponse(String value) {
    if (value == response) return;
    response = value;
    final u = fs;
    String at(double fraction) => _trim(fraction * u);
    switch (value) {
      case 'lowpass':
        wp = [at(0.2), at(0.4)];
        ws = [at(0.3), at(0.45)];
        break;
      case 'highpass':
        wp = [at(0.3), at(0.4)];
        ws = [at(0.2), at(0.45)];
        break;
      case 'bandpass':
        wp = [at(0.2), at(0.3)];
        ws = [at(0.12), at(0.38)];
        break;
      case 'bandstop':
        wp = [at(0.12), at(0.38)];
        ws = [at(0.2), at(0.3)];
        break;
    }
    design();
  }

  void addBand() {
    rows.add(BandRow(_trim(fs * 0.3), _trim(fs * 0.4), '0', '0', '1', '50'));
    design();
  }

  void removeBand(int index) {
    if (rows.length <= 1) return;
    rows.removeAt(index);
    design();
  }

  void loadPreset(String name) {
    preset = name;
    final unit = fs;
    // Only the frequencies scale with the sample rate: a desired amplitude and
    // a weight mean the same thing at any rate.
    List<BandRow> scaled(List<List<String>> spec) => [
          for (final s in spec)
            BandRow(_trim(double.parse(s[0]) * unit),
                _trim(double.parse(s[1]) * unit), s[2], s[3], s[4], s[5],
                invF: s.length > 6 && s[6] == '1/f')
        ];
    switch (name) {
      case 'Lowpass':
        numtaps = 41;
        symmetry = fir.Symmetry.symmetric;
        rows = scaled([
          ['0', '0.2', '1', '1', '1', '0.5'],
          ['0.25', '0.5', '0', '0', '10', '50'],
        ]);
        break;
      case 'Highpass':
        numtaps = 41;
        symmetry = fir.Symmetry.symmetric;
        rows = scaled([
          ['0', '0.2', '0', '0', '10', '50'],
          ['0.25', '0.5', '1', '1', '1', '0.5'],
        ]);
        break;
      case 'Bandpass':
        numtaps = 55;
        symmetry = fir.Symmetry.symmetric;
        rows = scaled([
          ['0', '0.12', '0', '0', '10', '50'],
          ['0.18', '0.32', '1', '1', '1', '0.5'],
          ['0.38', '0.5', '0', '0', '10', '50'],
        ]);
        break;
      case 'Bandstop':
        numtaps = 55;
        symmetry = fir.Symmetry.symmetric;
        rows = scaled([
          ['0', '0.14', '1', '1', '1', '0.5'],
          ['0.2', '0.3', '0', '0', '10', '50'],
          ['0.36', '0.5', '1', '1', '1', '0.5'],
        ]);
        break;
      case 'Multiband':
        numtaps = 75;
        symmetry = fir.Symmetry.symmetric;
        rows = scaled([
          ['0', '0.1', '1', '1', '1', '0.5'],
          ['0.15', '0.25', '0.4', '0.4', '1', '1'],
          ['0.3', '0.4', '0', '0', '8', '45'],
          ['0.45', '0.5', '1', '1', '1', '0.5'],
        ]);
        break;
      case 'Hilbert transformer':
        numtaps = 41;
        symmetry = fir.Symmetry.antisymmetric;
        rows = scaled([
          ['0.05', '0.45', '1', '1', '1', '40'],
        ]);
        break;
      // A differentiator's target is 2*pi*f, so the desired value ramps across
      // the band and the weight goes as 1/f.  The two amplitudes are the
      // six-figure strings the Python's table shows, not the full-precision
      // values, so that a differentiator designed in either tool has the same
      // taps rather than ones that differ in the seventh digit.
      case 'Differentiator':
        numtaps = 33;
        symmetry = fir.Symmetry.antisymmetric;
        rows = scaled([
          ['0.01', '0.45', '0.0628319', '2.82743', '1', '40', '1/f'],
        ]);
        break;
      // The middle band falls from 1 to 0 across its width: the point of
      // desired-at-start and desired-at-stop being separate fields.
      case 'Raised-cosine band':
        numtaps = 61;
        symmetry = fir.Symmetry.symmetric;
        rows = scaled([
          ['0', '0.15', '1', '1', '1', '0.5'],
          ['0.18', '0.28', '1', '0', '1', '1'],
          ['0.33', '0.5', '0', '0', '5', '45'],
        ]);
        break;
    }
    design();
  }

  static const List<String> presets = [
    'Lowpass',
    'Highpass',
    'Bandpass',
    'Bandstop',
    'Multiband',
    'Hilbert transformer',
    'Differentiator',
    'Raised-cosine band',
  ];

  // --- what the plots need -------------------------------------------------

  /// Magnitude in dB (or linear) over 0..fs/2, as built.
  ({Float64List f, Float64List y}) magnitude({int points = 1024}) {
    final f = Float64List(points);
    final y = Float64List(points);
    final nyq = fs / 2;
    for (var i = 0; i < points; i++) {
      f[i] = nyq * i / (points - 1);
    }
    if (isIir) {
      final res = iirEffective!;
      final h = res.responseAt(f.toList());
      for (var i = 0; i < points; i++) {
        y[i] = logScale ? _db(h[i].abs) : h[i].abs;
      }
    } else {
      final res = firEffective!;
      final w = Float64List(points);
      for (var i = 0; i < points; i++) {
        w[i] = 2 * math.pi * f[i] / fs;
      }
      final amp = fir.amplitudeResponse(res.h, w, res.symmetry);
      for (var i = 0; i < points; i++) {
        y[i] = logScale ? _db(amp[i].abs()) : amp[i];
      }
    }
    return (f: f, y: y);
  }

  /// The design before rounding, when the two differ.
  ({Float64List f, Float64List y})? idealMagnitude({int points = 1024}) {
    if (fixed == null) return null;
    final f = Float64List(points);
    final y = Float64List(points);
    final nyq = fs / 2;
    for (var i = 0; i < points; i++) {
      f[i] = nyq * i / (points - 1);
    }
    if (isIir) {
      final h = iirResult!.responseAt(f.toList());
      for (var i = 0; i < points; i++) {
        y[i] = logScale ? _db(h[i].abs) : h[i].abs;
      }
    } else {
      final res = firResult!;
      final w = Float64List(points);
      for (var i = 0; i < points; i++) {
        w[i] = 2 * math.pi * f[i] / fs;
      }
      final amp = fir.amplitudeResponse(res.h, w, res.symmetry);
      for (var i = 0; i < points; i++) {
        y[i] = logScale ? _db(amp[i].abs()) : amp[i];
      }
    }
    return (f: f, y: y);
  }

  /// How far down the magnitude plot has to reach, in dB.
  ///
  /// Not from delta: that is the *weighted* deviation, and once the weights
  /// come from dB specs it is essentially the passband's number, which would
  /// cut the stopband off the bottom of the plot.
  double magnitudeFloor() {
    if (isIir) {
      final res = iirEffective!;
      return math.max(math.min(-1.6 * res.rs - 20.0, -20.0), -220.0);
    }
    final res = firEffective!;
    final spec = specDev;
    var deepest = double.infinity;
    for (var i = 0; i < res.bands.length; i++) {
      final target = res.bands[i].target;
      final level = target + res.bandDeviation[i];
      if (level < deepest) deepest = level;
      // The requested spec line has to be visible too, or an 80 dB stopband is
      // judged against a line below the bottom of the plot.
      if (spec != null && target + spec[i] < deepest) deepest = target + spec[i];
    }
    final db = _db(deepest);
    return math.max(math.min(db - 15.0, -20.0), -220.0);
  }

  /// Kaiser's order estimate over the narrowest transition band.
  ///
  /// A missed spec is usually just too few taps, and this is the number to try
  /// next. Null when there is no transition to measure across.
  int? _tapsForSpec(fir.RemezResult res, List<double> spec) {
    if (res.bands.length < 2) return null;
    var width = double.infinity;
    var at = -1;
    for (var i = 0; i < res.bands.length - 1; i++) {
      final gap = res.bands[i + 1].f1 - res.bands[i].f2;
      if (gap > 0 && gap < width) {
        width = gap;
        at = i;
      }
    }
    if (at < 0) return null;
    final n = fir.kaiserOrderEstimate(spec[at], spec[at + 1], width, fs: res.fs);
    return n > 0 ? n : null;
  }

  /// One band sampled: the frequencies, the desired amplitude and the
  /// tolerance the exchange holds it to.
  ///
  /// Both the desired amplitude and the weight may vary across a band, so
  /// these are curves and not the straight lines between the edges that a
  /// two-point plot would draw -- in dB even a linear ramp is bent.
  ({Float64List f, Float64List desired, Float64List tolerance}) bandCurves(
      fir.RemezResult res, fir.Band band,
      {int points = 240}) {
    final f = Float64List(points);
    final desired = Float64List(points);
    final tolerance = Float64List(points);
    final span = band.f2 - band.f1;
    final delta = res.delta.abs();
    for (var i = 0; i < points; i++) {
      f[i] = band.f1 + (points == 1 ? 0.0 : i / (points - 1)) * span;
      final t = span <= 0 ? 0.0 : (f[i] - band.f1) / span;
      desired[i] = band.d1 + t * (band.d2 - band.d1);
      final w = band.weightKind == fir.WeightKind.inverseF
          ? band.w1 / math.max(f[i] / res.fs, 1e-9)
          : band.w1 + t * (band.w2 - band.w1);
      // The exchange equalises W*|D - A|, so a band sits within delta/W of
      // its target.
      tolerance[i] = delta / w;
    }
    return (f: f, desired: desired, tolerance: tolerance);
  }

  /// The bands whose target is not zero, which are the ones a ripple plot has
  /// anything to say about: 20*log10(A/D) is meaningless where D is zero.
  List<fir.Band> get liveBands => [
        for (final b in (firEffective ?? firResult)?.bands ?? const <fir.Band>[])
          if (b.target > 1e-12) b
      ];

  /// The impulse response, for the bottom panel.
  Float64List impulse({int max = 256}) {
    if (isIir) {
      final n = math.min(max, 200);
      return iir.sosImpulse(iirEffective!.sos, n);
    }
    return firEffective!.h;
  }

  // --- saving and reopening ------------------------------------------------

  /// The file format, shared with the Python tool.
  ///
  /// Same key names, same values, same version, so a design saved in either
  /// opens in the other. The parts this port has no equivalent for -- which
  /// panels were folded, which optional traces were showing -- are carried
  /// through untouched rather than dropped, so that a round trip through this
  /// program does not quietly strip settings the other one relies on.
  static const String formatName = 'remez-filter-design';

  /// Fields read from a file that this program has no control for.
  Map<String, dynamic> _passenger = const {};

  Map<String, dynamic> toJson() {
    final display = <String, dynamic>{
      ...(_passenger['display'] as Map<String, dynamic>? ?? const {}),
      'log_scale': logScale,
      'view': view == Pane.design ? 'Design view' : 'Plot view',
      // Not a key the Python writes; it ignores what it does not know, and
      // this program preserves what it does, so the two still interchange.
      'appearance': appearance.name,
    };
    return {
      'format': formatName,
      'version': 1,
      'mode': isIir ? 'IIR — bilinear transform' : 'FIR — Remez exchange',
      'fs': fs,
      'fir': {
        'numtaps': numtaps,
        'symmetry': symmetry.name,
        'grid_density': gridDensity,
        'maxiter': maxiter,
        'use_spec': useSpec,
        'bands': [
          for (final r in rows)
            [
              double.tryParse(r.f1) ?? 0.0,
              double.tryParse(r.f2) ?? 0.0,
              double.tryParse(r.d1) ?? 0.0,
              double.tryParse(r.d2) ?? 0.0,
              double.tryParse(r.weight) ?? 1.0,
              double.tryParse(r.spec) ?? 0.0,
              r.invF,
            ]
        ],
      },
      'iir': {
        // Written as the Python's pulldowns spell them, so its loader accepts
        // them; the reader here takes either.
        'response': responseLabels[response] ?? response,
        'approximation': approximationLabels[approximation] ?? approximation,
        'order': order,
        'auto_order': autoOrder,
        'wp': List<String>.from(wp),
        'ws': List<String>.from(ws),
        'rp': rp,
        'rs': rs,
      },
      'arithmetic': {
        ...(_passenger['arithmetic'] as Map<String, dynamic>? ?? const {}),
        'kind': isFixed ? 'fixed' : 'float',
        'word_bits': wordBits,
        'auto_frac': autoFrac,
        'frac_bits': fracBits,
        'headroom': headroom,
        'fixed_coeffs': fixedCoeffs,
        'structure': structure,
        'folded': folded,
        'testbench': wantTestbench,
      },
      'display': display,
    };
  }

  /// Restore what [toJson] wrote. Anything absent keeps its current value.
  void fromJson(Map<String, dynamic> state) {
    if (state['format'] != formatName) {
      throw const FormatException('not a filter design file');
    }
    _passenger = {
      'display': state['display'],
      'arithmetic': state['arithmetic'],
    };

    T? read<T>(Map<String, dynamic>? from, String key) {
      final v = from?[key];
      return v is T ? v : null;
    }

    final rate = (state['fs'] as num?)?.toDouble();
    // The file's edges are already in the file's units, so this is the rate
    // they are in, not a change to scale them by.
    if (rate != null && rate > 0) fs = rate;

    final firState = state['fir'] as Map<String, dynamic>?;
    numtaps = read<num>(firState, 'numtaps')?.toInt() ?? numtaps;
    gridDensity = read<num>(firState, 'grid_density')?.toInt() ?? gridDensity;
    maxiter = read<num>(firState, 'maxiter')?.toInt() ?? maxiter;
    useSpec = read<bool>(firState, 'use_spec') ?? useSpec;
    final sym = read<String>(firState, 'symmetry');
    if (sym == 'antisymmetric') {
      symmetry = fir.Symmetry.antisymmetric;
    } else if (sym == 'symmetric') {
      symmetry = fir.Symmetry.symmetric;
    }
    final bands = firState?['bands'];
    if (bands is List && bands.isNotEmpty) {
      rows = [
        for (final b in bands.cast<List<dynamic>>())
          BandRow(
            _trim((b[0] as num).toDouble()),
            _trim((b[1] as num).toDouble()),
            _trim((b[2] as num).toDouble()),
            _trim((b[3] as num).toDouble()),
            _trim((b[4] as num).toDouble()),
            b.length > 5 ? _trim((b[5] as num).toDouble()) : '50',
            invF: b.length > 6 && b[6] == true,
          )
      ];
      // Loaded bands are the file's, not a preset's.
      preset = null;
    }

    final iirState = state['iir'] as Map<String, dynamic>?;
    final r0 = read<String>(iirState, 'response');
    if (r0 != null) response = keyFor(responseLabels, r0, response);
    final a0 = read<String>(iirState, 'approximation');
    if (a0 != null) {
      approximation = keyFor(approximationLabels, a0, approximation);
    }
    order = read<num>(iirState, 'order')?.toInt() ?? order;
    autoOrder = read<bool>(iirState, 'auto_order') ?? autoOrder;
    for (final entry in [('wp', wp), ('ws', ws)]) {
      final values = iirState?[entry.$1];
      if (values is List) {
        for (var i = 0; i < values.length && i < entry.$2.length; i++) {
          entry.$2[i] = '${values[i]}';
        }
      }
    }
    rp = _asText(iirState?['rp']) ?? rp;
    rs = _asText(iirState?['rs']) ?? rs;

    final arith = state['arithmetic'] as Map<String, dynamic>?;
    arithmetic = read<String>(arith, 'kind') == 'fixed'
        ? Arithmetic.fixed
        : (arith?.containsKey('kind') ?? false)
            ? Arithmetic.floating
            : arithmetic;
    wordBits = read<num>(arith, 'word_bits')?.toInt() ?? wordBits;
    autoFrac = read<bool>(arith, 'auto_frac') ?? autoFrac;
    fracBits = read<num>(arith, 'frac_bits')?.toInt() ?? fracBits;
    headroom = read<num>(arith, 'headroom')?.toInt() ?? headroom;
    fixedCoeffs = read<bool>(arith, 'fixed_coeffs') ?? fixedCoeffs;
    structure = read<String>(arith, 'structure') ?? structure;
    folded = read<bool>(arith, 'folded') ?? folded;
    wantTestbench = read<bool>(arith, 'testbench') ?? wantTestbench;

    final display = state['display'] as Map<String, dynamic>?;
    logScale = read<bool>(display, 'log_scale') ?? logScale;
    view = read<String>(display, 'view') == 'Design view'
        ? Pane.design
        : Pane.plot;
    final look = read<String>(display, 'appearance');
    appearance = Appearance.values.firstWhere((a) => a.name == look,
        orElse: () => appearance);

    final mode0 = read<String>(state, 'mode');
    if (mode0 != null) {
      mode = mode0.startsWith('IIR') ? Mode.iir : Mode.fir;
    }
    design();
  }

  String report() {
    final b = StringBuffer();
    if (error != null) {
      b.writeln('Cannot design this filter:');
      b.writeln();
      b.writeln(error);
      return b.toString();
    }
    if (isIir) {
      final res = iirEffective!;
      b.writeln('$approximation $response');
      b.writeln('order            ${res.order}'
          '${res.autoOrder ? '  (smallest that meets the spec)' : ''}');
      b.writeln('digital degree   ${res.degree}   '
          '(${res.sos.length} second-order section'
          '${res.sos.length == 1 ? '' : 's'})');
      b.writeln('smallest order   ${res.orderEstimate}');
      b.writeln('max |pole|       ${res.maxPoleRadius.toStringAsFixed(6)}   '
          '${res.stable ? 'stable' : '*** UNSTABLE ***'}');
      b.writeln();
      b.writeln('spec check');
      b.writeln('  passband ripple  achieved '
          '${res.achievedRp.toStringAsFixed(4)} dB  required '
          '${res.rp} dB   ${res.achievedRp <= res.rp * 1.0001 + 1e-9 ? 'met' : 'MISSED'}');
      b.writeln('  stopband atten.  achieved '
          '${res.achievedRs.toStringAsFixed(4)} dB  required '
          '${res.rs} dB   ${res.achievedRs >= res.rs - 1e-4 ? 'met' : 'MISSED'}');
      if (verification == Verified.unverified) {
        b.writeln();
        b.writeln('NOTE: this combination is not yet checked against the');
        b.writeln('Python implementation.  It designs, but treat the numbers');
        b.writeln('as provisional.');
      }
      b.writeln();
      b.writeln('second-order sections   b0 b1 b2 / a0 a1 a2');
      for (var i = 0; i < res.sos.length; i++) {
        final s = res.sos[i];
        b.writeln('  [$i] b ${_col(s[0])} ${_col(s[1])} ${_col(s[2])}');
        b.writeln('      a ${_col(s[3])} ${_col(s[4])} ${_col(s[5])}');
      }
    } else {
      final res = firResult!;
      final eff = firEffective!;
      b.writeln('type ${res.ftype}  (${res.symmetry.name}, '
          '${res.numtaps.isOdd ? 'odd' : 'even'} length ${res.numtaps})');
      b.writeln('iterations       ${res.iterations}'
          '${res.converged ? '' : '   *** did not converge ***'}');
      b.writeln('weighted delta   ${res.delta.abs().toStringAsExponential(5)}');
      b.writeln();
      b.writeln('band          range            deviation      dB');
      for (var i = 0; i < res.bands.length; i++) {
        final band = res.bands[i];
        final dev = eff.bandDeviation[i];
        final target = band.target;
        final label = target < 1e-12
            ? '${_db(dev).toStringAsFixed(2)} atten'
            : '${(_db(1 + dev / target) - _db(1 - dev / target)).toStringAsFixed(2)} p-p';
        b.writeln('  ${(i + 1).toString().padRight(3)} '
            '${_trim(band.f1).padLeft(8)}-${_trim(band.f2).padRight(8)} '
            '${dev.toStringAsExponential(4).padLeft(12)}  $label');
      }
      final spec = specDev;
      if (spec != null) {
        b.writeln();
        b.writeln('spec check   (weights taken from the Spec column)');
        var met = true;
        for (var i = 0; i < spec.length; i++) {
          final dev = eff.bandDeviation[i];
          final ok = dev <= spec[i] * (1 + 1e-9);
          met &= ok;
          b.writeln('  band ${(i + 1).toString().padRight(2)} '
              'asked ${rows[i].spec.padLeft(7)} dB  '
              '= ${spec[i].toStringAsExponential(3)}   '
              'got ${dev.toStringAsExponential(3)}   ${ok ? 'met' : 'MISSED'}');
        }
        if (!met) {
          final need = _tapsForSpec(res, spec);
          b.writeln(need == null
              ? '  more taps would tighten every band'
              : '  try about $need taps to meet every spec');
        }
      }
    }
    if (fixed != null) {
      final q = fixed!;
      b.writeln();
      b.writeln('arithmetic       ${q.bits}-bit fixed point, ${q.qFormat}');
      b.writeln('  resolution     ${q.step.toStringAsExponential(4)}');
      b.writeln('  worst rounding ${q.maxError.toStringAsExponential(4)}');
      if (q.saturated > 0) {
        b.writeln('  *** ${q.saturated} coefficient(s) saturated ***');
      }
      b.writeln('  datapath       ${q.bits + headroom} bits '
          '(Q${q.intBits + headroom}.${q.fracBits})');
    }
    if (lastDesignTime != null) {
      b.writeln();
      b.writeln('designed in ${lastDesignTime!.inMicroseconds / 1000.0} ms');
    }
    if (!isIir && firEffective != null) {
      b.writeln();
      b.writeln('coefficients');
      final h = firEffective!.h;
      for (var i = 0; i < h.length; i++) {
        final index = 'h[$i]'.padRight(8);
        b.writeln('  $index = ${h[i].toStringAsFixed(12)}'
            '${fixed != null ? '   ${fixed!.ints[i]}' : ''}');
      }
    }
    return b.toString();
  }
}

String _col(double v) => v.toStringAsFixed(9).padLeft(14);

double _db(double x) => 20 * math.log(math.max(x.abs(), 1e-12)) / math.ln10;

/// A number as a field's worth of text: readable, and precise enough to scale
/// back when the sample rate changes again.
/// A JSON scalar as the text a field holds; the Python writes these as strings.
String? _asText(Object? v) {
  if (v == null) return null;
  if (v is String) return v;
  if (v is num) return _trim(v.toDouble());
  return null;
}

String _trim(double v) {
  if (v == v.roundToDouble() && v.abs() < 1e15) {
    return v.toStringAsFixed(0);
  }
  var s = v.toStringAsPrecision(10);
  if (s.contains('.') && !s.contains('e')) {
    s = s.replaceAll(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  }
  return s;
}
