/// The design state behind the UI: what has been asked for, and what came back.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'complex.dart';
import 'datapath.dart' as dp;
import 'fir_core.dart' as fir;
import 'fir_ls.dart';
import 'fixed_point.dart' as fx;
import 'iir_core.dart' as iir;
import 'labels.dart';
import 'multirate.dart';
import 'response.dart';
import 'roots.dart';
import 'signals.dart';
import 'rtl_common.dart';

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

/// Which direction a polyphase rate change goes.
enum RateChange { decimate, interpolate }

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

  /// Which design method runs.
  ///
  /// The exchange is the default because minimax is what a specification
  /// usually means. The other two are here because it is not always: least
  /// squares when total error matters more than the worst of it, and the
  /// window method when a predictable answer with no iteration is worth more
  /// than an optimal one.
  FirMethod method = FirMethod.remez;
  FirWindow window = FirWindow.hamming;

  /// The Kaiser window's shape parameter, which sets its attenuation.
  String kaiserBeta = '8.6';

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

  /// Design a half-band filter: alternate taps exactly zero, for half the
  /// multiplies.
  ///
  /// Constrains rather than post-processes. The band table collapses to one
  /// edge -- the stopband is its mirror about the quarter-rate point -- the
  /// weights are equal, and the length is rounded to 4k+3, because those are
  /// the conditions under which the answer is a half-band filter at all.
  bool halfBand = false;

  /// The half-band passband edge, in sample-rate units.
  String halfBandEdge = '0.2';

  /// Rate change factor, for the polyphase decomposition. 1 is no rate change.
  int rateFactor = 1;

  /// Which way the rate change goes.
  ///
  /// It makes no difference to the filter -- the same taps, split the same way
  /// -- but it decides what the phases are wired to, and so what the exports
  /// have to say about them.
  RateChange rateChange = RateChange.decimate;

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

  /// Measure the noise the generated datapath's own arithmetic adds.
  ///
  /// Off by default because it is not free: it drives the exact integer
  /// datapath with a few thousand samples and takes a spectrum of the error
  /// against the same filter computed exactly, which is tens of milliseconds
  /// and has no business happening on every keystroke.
  bool measureNoise = false;

  /// Shade the spread of responses half an LSB of coefficient error covers.
  ///
  /// Also not free, and for the same reason: it is a few hundred filters
  /// evaluated rather than one.
  bool showSensitivity = false;

  // --- what the hardware export should build ---
  /// Coefficients baked into the RTL as constants, rather than driven in.
  bool fixedCoeffs = true;
  String structure = 'chain';
  bool folded = false;
  bool wantTestbench = true;

  bool logScale = true;
  Pane view = Pane.plot;
  Appearance appearance = Appearance.system;

  /// Which of the optional plots are drawn.
  ///
  /// Phase is off to start with because group delay is its derivative and says
  /// the same thing without the 2*pi steps; the other two are on because they
  /// are the plots that answer a question the magnitude cannot.
  /// Push a test signal through the filter and plot what comes out.
  bool showSignal = false;
  TestSignal testSignal = TestSignal.chirp;
  String signalFrequency = '0.05';
  int signalLength = 512;

  bool showPhase = false;
  bool showGroupDelay = true;
  bool showZPlane = true;

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
    if (_restoring) {
      change();
      design();
      return;
    }
    // Compared before and after the change rather than against the last
    // snapshot: a text field commits on every blur, so most of what arrives
    // here sets a value to what it already was, and recording that would make
    // undo appear to do nothing.
    //
    // Taken before `design()` runs, so what is compared is what was asked
    // for. The design's own consequences -- an auto-chosen order, a tap count
    // rounded to a half-band length -- are not changes anyone made.
    final before = toJson();
    change();
    if (!_sameState(before, toJson())) {
      _past.add(before);
      if (_past.length > _historyLimit) _past.removeAt(0);
      _future.clear();
    }
    design();
  }

  // --- undo, redo and pinning -----------------------------------------------

  /// Snapshots of the state before each change, newest last.
  ///
  /// Built on [toJson] rather than on a list of edits: the file format already
  /// captures everything the program can be asked for, so anything that
  /// survives a save survives an undo, and nothing has to be added here when a
  /// new control is added anywhere else.
  final List<Map<String, dynamic>> _past = [];
  final List<Map<String, dynamic>> _future = [];

  /// Set while a snapshot is being restored, so the restore does not record
  /// itself as another change to undo.
  bool _restoring = false;

  static const int _historyLimit = 100;

  bool get canUndo => _past.isNotEmpty;
  bool get canRedo => _future.isNotEmpty;

  void undo() {
    if (_past.isEmpty) return;
    _future.add(toJson());
    _restore(_past.removeLast());
  }

  void redo() {
    if (_future.isEmpty) return;
    _past.add(toJson());
    _restore(_future.removeLast());
  }

  void _restore(Map<String, dynamic> state) {
    _restoring = true;
    try {
      fromJson(state);
    } finally {
      _restoring = false;
    }
  }

  bool _sameState(Map<String, dynamic> a, Map<String, dynamic> b) =>
      json.encode(a) == json.encode(b);

  /// A design kept on the axes while another is edited against it.
  Map<String, dynamic>? _pinnedState;

  /// What the pinned design was, in a few words, for the legend.
  String? pinnedLabel;

  bool get hasPinned => _pinnedState != null;

  /// Keep the current design on the plot while the next one is edited.
  void pin() {
    _pinnedState = toJson();
    pinnedLabel = describe();
    _pinnedCurve = null;
    notifyListeners();
  }

  void unpin() {
    _pinnedState = null;
    pinnedLabel = null;
    _pinnedCurve = null;
    notifyListeners();
  }

  /// The pinned design's magnitude, on the current axes.
  ///
  /// Recomputed from the saved state rather than from a stored curve, so that
  /// changing the sample rate or switching to a linear axis moves the pinned
  /// trace with everything else instead of leaving it where it was drawn.
  ({Float64List f, Float64List y})? pinnedMagnitude({int points = 1024}) {
    if (_pinnedState == null) return null;
    if (_pinnedCurve != null) return _pinnedCurve;
    try {
      final scratch = DesignController()
        ..logScale = logScale
        ..fromJson(_pinnedState!);
      if (!scratch.hasResult) return null;
      scratch.logScale = logScale;
      return _pinnedCurve = scratch.magnitude(points: points);
    } catch (_) {
      // A pinned state that no longer designs is not worth an error on screen;
      // it simply stops being drawn.
      return null;
    }
  }

  ({Float64List f, Float64List y})? _pinnedCurve;

  /// The design in a few words, for a legend or a window title.
  String describe() {
    if (isIir) {
      return '${labelOf(approximation)} $response, order $order';
    }
    return 'FIR N=$numtaps, ${method.label}'
        '${halfBand ? ', half band' : ''}';
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
    _zplaneBuilt = _zplaneIdeal = null;
    _noise = null;
    noiseError = null;
    _sensitivity = null;
    _pinnedCurve = null;
    _signalRun = null;
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
    if (halfBand) {
      _designHalfBand();
      return;
    }
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
    firResult = _run(bands);
    firEffective = firResult;
    iirResult = iirEffective = null;
  }

  /// Hand the bands to whichever method is selected.
  fir.RemezResult _run(List<fir.Band> bands) {
    switch (method) {
      case FirMethod.remez:
        return fir.design(numtaps, bands,
            symmetry: symmetry,
            fs: fs,
            gridDensity: gridDensity,
            maxiter: maxiter);
      case FirMethod.leastSquares:
        return designLeastSquares(numtaps, bands,
            symmetry: symmetry, fs: fs, gridDensity: gridDensity);
      case FirMethod.window:
        final beta = double.tryParse(kaiserBeta);
        if (beta == null || beta < 0) {
          throw fir.RemezError('the Kaiser beta must be a number, and not '
              'negative');
        }
        return designWindowed(numtaps, bands,
            symmetry: symmetry,
            fs: fs,
            gridDensity: gridDensity,
            window: window,
            kaiserBeta: beta);
    }
  }

  /// Design the half-band case, where almost everything is fixed for you.
  ///
  /// The length is rounded up to the nearest 4k+3 rather than rejected: the
  /// Taps field is a number someone typed, and refusing three lengths out of
  /// every four would make it unusable. What it was rounded to is in the
  /// report.
  void _designHalfBand() {
    final fp = double.tryParse(halfBandEdge);
    if (fp == null) {
      throw fir.RemezError('the half-band edge must be a number');
    }
    numtaps = nearestHalfBandLength(numtaps);
    symmetry = fir.Symmetry.symmetric;
    specDev = null;
    final res = _run(halfBandBands(fp, fs: fs));
    // What the exchange leaves at 1e-16 is zero, and a tap stored as 1e-16
    // still costs a multiplier. Recorded first, because snapping destroys the
    // evidence of how close the design came.
    halfBandMiss = halfBandResidual(res.h);
    firResult = fir.withTaps(res, snapHalfBand(res.h));
    firEffective = firResult;
    iirResult = iirEffective = null;
  }

  /// How far the taps that should have vanished actually were from zero,
  /// relative to the centre tap, before they were snapped.
  double halfBandMiss = 0.0;

  /// The rate-change phases of the filter as built, or null when there is no
  /// rate change to decompose for.
  List<Float64List>? phases() {
    if (isIir || rateFactor < 2) return null;
    final res = firEffective;
    return res == null ? null : polyphase(res.h, rateFactor);
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

  /// The deepest stopband the design achieves, in dB, or null if it has none.
  ///
  /// What the arithmetic noise has to be compared against: a stopband below
  /// the noise floor is a number on a plot rather than a filter you can build.
  double? _deepestStopband() {
    if (isIir) return -iirEffective!.achievedRs;
    final res = firEffective;
    if (res == null) return null;
    var deepest = double.infinity;
    for (var i = 0; i < res.bands.length; i++) {
      if (res.bands[i].target > 1e-12) continue;
      final level = _db(res.bandDeviation[i]);
      if (level < deepest) deepest = level;
    }
    return deepest.isFinite ? deepest : null;
  }

  /// Whether [f] falls in a band the design is holding down.
  bool _inStopband(double f) {
    if (isIir) {
      for (final range in iirEffective!.stopbandRanges) {
        if (f >= range[0] && f <= range[1]) return true;
      }
      return false;
    }
    for (final band in firEffective?.bands ?? const <fir.Band>[]) {
      if (band.target > 1e-12) continue;
      if (f >= band.f1 && f <= band.f2) return true;
    }
    return false;
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

  /// How much of the response a half-LSB of coefficient error can move.
  ///
  /// Every coefficient is nudged independently by a uniform draw of up to half
  /// a step either way -- the most a differently-rounded implementation of the
  /// same design could be out by -- and the pointwise extremes of the
  /// resulting magnitude responses are the envelope.
  ///
  /// A design whose envelope is a thin line has margin. One whose envelope
  /// swallows the stopband is balanced on the exact values it was given, and
  /// will not survive being built. For an IIR it can be worse than that, which
  /// is what [unstable] counts: perturbations that put a pole on or outside
  /// the unit circle.
  ///
  /// The draws are seeded, so the shading does not shimmer from one rebuild to
  /// the next while nothing has changed.
  ({Float64List f, Float64List lo, Float64List hi, int unstable, int trials})?
      sensitivity({int points = 512, int trials = 128}) {
    if (!showSensitivity || fixed == null || !hasResult) return null;
    if (_sensitivity != null) return _sensitivity;

    final f = Float64List(points);
    final nyq = fs / 2;
    for (var i = 0; i < points; i++) {
      f[i] = nyq * i / (points - 1);
    }
    final w = Float64List(points);
    for (var i = 0; i < points; i++) {
      w[i] = 2 * math.pi * f[i] / fs;
    }

    final lo = Float64List(points)..fillRange(0, points, double.infinity);
    final hi = Float64List(points)
      ..fillRange(0, points, double.negativeInfinity);
    final rng = math.Random(20240804);
    final step = fixed!.step;
    var unstable = 0;

    for (var t = 0; t < trials; t++) {
      // The first draw is no perturbation at all. Zero error is a member of
      // the set being sampled, and including it explicitly is the only way a
      // finite number of draws is guaranteed to cover the design it is drawn
      // around: at a null, every jittered filter moves its zero off the exact
      // frequency the nominal one nulls at, and the envelope would sit above
      // the very curve it is supposed to bound.
      final amount = t == 0 ? 0.0 : step;
      Float64List magnitude;
      if (isIir) {
        final rows = <Float64List>[];
        for (final row in fx.sosRows(fixed!)) {
          final jittered = Float64List.fromList(row);
          // a0 is not a multiplier and is exactly one in the hardware, so it
          // has no rounding error to model.
          for (final c in fx.sosLiveColumns) {
            jittered[c] += (rng.nextDouble() - 0.5) * amount;
          }
          rows.add(jittered);
        }
        var radius = 0.0;
        for (final p in iir.sosToZpk(rows).p) {
          if (p.abs > radius) radius = p.abs;
        }
        if (radius >= 1.0) {
          unstable++;
          continue; // its response is unbounded; it would swamp the envelope
        }
        final h = iir.sosFreqz(rows, w);
        magnitude = Float64List(points);
        for (var i = 0; i < points; i++) {
          magnitude[i] = h[i].abs;
        }
      } else {
        final taps = Float64List.fromList(fixed!.values);
        for (var k = 0; k < taps.length; k++) {
          taps[k] += (rng.nextDouble() - 0.5) * amount;
        }
        final amp = fir.amplitudeResponse(taps, w, symmetry);
        magnitude = Float64List(points);
        for (var i = 0; i < points; i++) {
          magnitude[i] = amp[i].abs();
        }
      }
      for (var i = 0; i < points; i++) {
        final y = logScale ? _db(magnitude[i]) : magnitude[i];
        if (y < lo[i]) lo[i] = y;
        if (y > hi[i]) hi[i] = y;
      }
    }

    if (unstable == trials) {
      // Nothing to draw, but the count is the finding.
      return _sensitivity =
          (f: f, lo: Float64List(0), hi: Float64List(0),
              unstable: unstable, trials: trials);
    }
    return _sensitivity =
        (f: f, lo: lo, hi: hi, unstable: unstable, trials: trials);
  }

  ({Float64List f, Float64List lo, Float64List hi, int unstable, int trials})?
      _sensitivity;

  /// What the datapath's arithmetic adds to the output, measured.
  ///
  /// Null when the measurement is switched off, when the arithmetic is
  /// floating point and there is nothing to measure, or when the datapath
  /// cannot be built at all -- in which case [noiseError] says why, in the same
  /// words the export button would have used.
  ///
  /// A coefficient set can be rounded to a filter whose response is still
  /// exactly what was asked for and whose hardware still cannot reach it: the
  /// sums and products are rounded too, and that noise sits at some level of
  /// its own. Where the stopband is deeper than that level, the stopband is not
  /// what the filter will actually deliver.
  dp.NoiseFloor? noiseFloor() {
    if (!measureNoise || fixed == null || !hasResult) return null;
    if (_noise != null || noiseError != null) return _noise;
    try {
      // Structure and folding are FIR options: a cascade of biquads has no
      // adder tree to choose and nothing to fold, and `simulateIir` ignores
      // both, so passing them through would only trip the planner's check.
      final options = RtlOptions(
        headroom: headroom,
        fixedCoeffs: fixedCoeffs,
        structure: isIir ? 'chain' : structure,
        folded: !isIir && folded,
      );
      final plan = isIir
          ? planFor('iir', iirResult!, fixed!, options)
          : planFor('fir', firResult!, fixed!, options);
      final rows = isIir ? fx.sosRows(fixed!) : const <Float64List>[];
      final taps = fixed!.values;
      _noise = dp.noiseResponse(
        plan.simulate,
        (x) => isIir ? iir.sosFilter(rows, x) : _convolve(taps, x),
        fixed!.fracBits,
        fixed!.bits,
        headroom,
        // Four thousand samples put the median within a few tenths of a dB of
        // where sixteen thousand put it, at a quarter of the wait.
        length: 1 << 12,
      );
    } on RtlError catch (e) {
      noiseError = e.message;
    } on dp.DatapathError catch (e) {
      noiseError = e.message;
    }
    return _noise;
  }

  dp.NoiseFloor? _noise;

  /// Why there is no measurement, when there should have been one.
  String? noiseError;

  /// Phase in degrees and group delay in samples, over the same grid.
  ///
  /// Returned together because both come out of one pass over the response and
  /// the two plots share an x axis.
  ///
  /// The delay is masked wherever the response is essentially null: there it is
  /// a ratio of two quantities that have both gone to zero, and the noise that
  /// falls out of that would put spikes on a plot whose whole message, for a
  /// linear-phase filter, is that the line is flat.
  ({Float64List f, Float64List phase, Float64List delay})? phaseAndDelay(
      {int points = 1024, bool ideal = false}) {
    if (ideal && fixed == null) return null;
    final f = Float64List(points);
    final w = Float64List(points);
    final nyq = fs / 2;
    for (var i = 0; i < points; i++) {
      f[i] = nyq * i / (points - 1);
      w[i] = 2 * math.pi * f[i] / fs;
    }

    final List<Complex> h;
    final Float64List tau;
    if (isIir) {
      final res = ideal ? iirResult : iirEffective;
      if (res == null) return null;
      h = iir.sosFreqz(res.sos, w);
      tau = sosGroupDelay(res.sos, w);
    } else {
      final res = ideal ? firResult : firEffective;
      if (res == null) return null;
      h = firFreqz(res.h, w);
      tau = polyGroupDelay(res.h, w);
    }

    final raw = Float64List(points);
    var peak = 0.0;
    for (var i = 0; i < points; i++) {
      raw[i] = h[i].arg;
      final m = h[i].abs;
      if (m > peak) peak = m;
    }
    final floor = peak * 1e-7;

    final phase = unwrap(raw);
    for (var i = 0; i < points; i++) {
      phase[i] *= 180 / math.pi;
      if (h[i].abs < floor) tau[i] = double.nan;
    }
    return (f: f, phase: phase, delay: tau);
  }

  /// Push a test signal through the filter, in both arithmetics.
  ///
  /// The float path is the design as designed. The fixed path is the exact
  /// integer datapath the exports would generate, run on the same samples and
  /// scaled back to the input's units, so the two can be drawn on one axis and
  /// the gap between them read off directly.
  SignalRun? signalRun() {
    if (!showSignal || !hasResult) return null;
    if (_signalRun != null) return _signalRun;

    final frequency = double.tryParse(signalFrequency) ?? 0.05;
    final n = signalLength.clamp(16, 8192);
    final x = generate(testSignal, n, fs: fs, frequency: frequency);
    final y = isIir
        ? iir.sosFilter(iirEffective!.sos, x)
        : convolve(firEffective!.h, x);

    Float64List? quantized;
    var clipped = 0;
    final q = fixed;
    if (q != null && q.fracBits >= 0) {
      try {
        final plan = planFor(
          isIir ? 'iir' : 'fir',
          isIir ? iirResult! : firResult!,
          q,
          RtlOptions(
            headroom: headroom,
            fixedCoeffs: fixedCoeffs,
            structure: isIir ? 'chain' : structure,
            folded: !isIir && folded,
          ),
        );
        final scale = math.pow(2.0, q.fracBits).toDouble();
        final limit = (1 << (q.bits + headroom - 1)) - 1;
        final samples = [
          for (final v in x) (v * scale).round().clamp(-limit - 1, limit)
        ];
        final out = plan.simulate(samples);
        quantized = Float64List(out.length);
        for (var i = 0; i < out.length; i++) {
          quantized[i] = out[i] / scale;
          if (out[i] >= limit || out[i] <= -limit - 1) clipped++;
        }
      } catch (_) {
        // A datapath that cannot be built has nothing to run; the float trace
        // is still worth showing on its own.
        quantized = null;
      }
    }

    return _signalRun = SignalRun(
      input: x,
      output: y,
      fixedOutput: quantized,
      clipped: clipped,
    );
  }

  SignalRun? _signalRun;

  /// Where the transfer function goes to zero and to infinity.
  ///
  /// [ideal] asks for the design before its coefficients were rounded, and is
  /// null unless fixed point is on: with nothing to compare against, drawing
  /// the same points twice says nothing.
  ///
  /// An FIR's poles are the N-1 at the origin that its delay line puts there.
  /// They are returned rather than left implicit so the plot can count them.
  ({List<Complex> zeros, List<Complex> poles, bool converged})? zplane(
      {bool ideal = false}) {
    if (ideal && fixed == null) return null;
    final cached = ideal ? _zplaneIdeal : _zplaneBuilt;
    if (cached != null) return cached;

    ({List<Complex> zeros, List<Complex> poles, bool converged})? value;
    if (isIir) {
      // Already known: an IIR is designed from its poles and zeros, and
      // re-analysing the rounded sections recovers where they moved to.
      final res = ideal ? iirResult : iirEffective;
      if (res != null) value = (zeros: res.z, poles: res.p, converged: true);
    } else {
      final res = ideal ? firResult : firEffective;
      if (res != null) {
        final found = polynomialRoots(res.h.toList());
        value = (
          zeros: found.values,
          poles: List<Complex>.filled(res.h.length - 1, Complex.zero),
          converged: found.converged,
        );
      }
    }
    if (ideal) {
      _zplaneIdeal = value;
    } else {
      _zplaneBuilt = value;
    }
    return value;
  }

  /// Root finding is quadratic in the tap count and the plot asks on every
  /// rebuild, so the answer is held until the next design replaces it.
  ({List<Complex> zeros, List<Complex> poles, bool converged})? _zplaneBuilt;
  ({List<Complex> zeros, List<Complex> poles, bool converged})? _zplaneIdeal;

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
      // Not keys the Python writes; it ignores what it does not know, and this
      // program preserves what it does, so the two still interchange.
      'appearance': appearance.name,
      'phase': showPhase,
      'signal': showSignal,
      'signal_kind': testSignal.name,
      'signal_frequency': signalFrequency,
      'signal_length': signalLength,
      'group_delay': showGroupDelay,
      'zplane': showZPlane,
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
        'method': method.name,
        'window': window.name,
        'kaiser_beta': kaiserBeta,
        'half_band': halfBand,
        'half_band_edge': halfBandEdge,
        'rate_factor': rateFactor,
        'rate_change': rateChange.name,
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
        'measure_noise': measureNoise,
        'sensitivity': showSensitivity,
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
    final methodName = read<String>(firState, 'method');
    method = FirMethod.values
        .firstWhere((m) => m.name == methodName, orElse: () => method);
    final windowName = read<String>(firState, 'window');
    window = FirWindow.values
        .firstWhere((w) => w.name == windowName, orElse: () => window);
    kaiserBeta = _asText(firState?['kaiser_beta']) ?? kaiserBeta;
    halfBand = read<bool>(firState, 'half_band') ?? halfBand;
    halfBandEdge = _asText(firState?['half_band_edge']) ?? halfBandEdge;
    rateFactor = read<num>(firState, 'rate_factor')?.toInt() ?? rateFactor;
    final direction = read<String>(firState, 'rate_change');
    rateChange = RateChange.values
        .firstWhere((r) => r.name == direction, orElse: () => rateChange);
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
    measureNoise = read<bool>(arith, 'measure_noise') ?? measureNoise;
    showSensitivity = read<bool>(arith, 'sensitivity') ?? showSensitivity;

    final display = state['display'] as Map<String, dynamic>?;
    logScale = read<bool>(display, 'log_scale') ?? logScale;
    view = read<String>(display, 'view') == 'Design view'
        ? Pane.design
        : Pane.plot;
    final look = read<String>(display, 'appearance');
    appearance = Appearance.values.firstWhere((a) => a.name == look,
        orElse: () => appearance);
    showPhase = read<bool>(display, 'phase') ?? showPhase;
    showSignal = read<bool>(display, 'signal') ?? showSignal;
    final kind = read<String>(display, 'signal_kind');
    testSignal = TestSignal.values
        .firstWhere((s) => s.name == kind, orElse: () => testSignal);
    signalFrequency = _asText(display?['signal_frequency']) ?? signalFrequency;
    signalLength = read<num>(display, 'signal_length')?.toInt() ?? signalLength;
    showGroupDelay = read<bool>(display, 'group_delay') ?? showGroupDelay;
    showZPlane = read<bool>(display, 'zplane') ?? showZPlane;

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
      final dead = res.deadSection;
      if (dead != null) {
        // Both figures are measured from a response that is identically zero,
        // so they come back infinite -- and an infinite attenuation would
        // otherwise be reported as meeting the stopband spec.
        b.writeln('  *** section $dead has no numerator left ***');
        b.writeln('  its three b coefficients all rounded to zero'
            '${fixed != null ? ' in ${fixed!.qFormat}' : ''}, so the');
        b.writeln('  cascade passes nothing and neither figure below means');
        b.writeln('  anything.  Widen the word, or place the binary point by');
        b.writeln('  hand further to the right.');
        b.writeln('  passband ripple  not measurable   required '
            '${res.rp} dB   MISSED');
        b.writeln('  stopband atten.  not measurable   required '
            '${res.rs} dB   MISSED');
      } else {
        b.writeln('  passband ripple  achieved '
            '${res.achievedRp.toStringAsFixed(4)} dB  required '
            '${res.rp} dB   ${res.achievedRp <= res.rp * 1.0001 + 1e-9 ? 'met' : 'MISSED'}');
        b.writeln('  stopband atten.  achieved '
            '${res.achievedRs.toStringAsFixed(4)} dB  required '
            '${res.rs} dB   ${res.achievedRs >= res.rs - 1e-4 ? 'met' : 'MISSED'}');
      }
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
      b.writeln('method           ${method.label}'
          "${method == FirMethod.window ? ', ${window.label} window'
              '${window == FirWindow.kaiser ? ', beta $kaiserBeta' : ''}' : ''}");
      if (method == FirMethod.remez) {
        b.writeln('iterations       ${res.iterations}'
            '${res.converged ? '' : '   *** did not converge ***'}');
      }
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
      if (halfBand) {
        final census = tapCensus(eff.h, res.symmetry, folded);
        b.writeln();
        b.writeln('half band, folded about ${_trim(fs / 4)}');
        b.writeln('  length         ${res.numtaps}'
            '${numtaps == res.numtaps ? '' : '   (rounded to 4k+3)'}');
        b.writeln('  zero taps      ${census.taps - census.nonzero} of '
            '${census.taps}, so ${census.multipliers} multipl'
            '${census.multipliers == 1 ? 'y' : 'ies'}'
            '${folded ? ' folded' : ''} instead of ${census.taps}');
        b.writeln('  centre tap     ${eff.h[res.numtaps ~/ 2]}');
        // How far the identity was from holding before the snap: small means
        // the design converged, large means the length is not enough.
        b.writeln('  snapped by     '
            '${halfBandMiss.toStringAsExponential(2)} of the centre tap');
      }

      final phaseSet = phases();
      if (phaseSet != null) {
        final verb =
            rateChange == RateChange.decimate ? 'decimate' : 'interpolate';
        b.writeln();
        b.writeln('polyphase, $verb by $rateFactor');
        b.writeln('  ${phaseSet.length} phases of ${phaseSet.first.length} '
            'taps each');
        b.writeln('  ${(eff.h.length / rateFactor).ceil()} multiplies per '
            '${rateChange == RateChange.decimate ? 'input' : 'output'} sample '
            'instead of ${eff.h.length}');
        for (var p = 0; p < phaseSet.length; p++) {
          b.writeln('  e$p: ${phaseSet[p].map(_short).join('  ')}');
        }
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

      final spread = sensitivity();
      if (spread != null) {
        b.writeln();
        b.writeln('half an LSB of coefficient error, over '
            '${spread.trials} draws');
        if (spread.unstable > 0) {
          b.writeln('  *** ${spread.unstable} of ${spread.trials} came out '
              'unstable ***');
          b.writeln('  the design sits too close to the unit circle to '
              'survive being built');
        }
        if (spread.lo.isNotEmpty) {
          final stop = _deepestStopband();
          if (stop != null) {
            // The worst the stopband gets anywhere it is supposed to be a
            // stopband, over every draw.
            var worst = double.negativeInfinity;
            for (var i = 0; i < spread.f.length; i++) {
              if (!_inStopband(spread.f[i])) continue;
              final v = logScale ? spread.hi[i] : _db(spread.hi[i]);
              if (v > worst) worst = v;
            }
            if (worst.isFinite) {
              b.writeln('  stopband       ${stop.toStringAsFixed(2)} dB '
                  'as built, ${worst.toStringAsFixed(2)} dB at worst');
            }
          }
        }
      }

      final noise = noiseFloor();
      if (noiseError != null) {
        b.writeln();
        b.writeln('arithmetic noise cannot be measured:');
        b.writeln('  $noiseError');
      } else if (noise != null) {
        final worst = noise.worstDb;
        b.writeln();
        b.writeln('arithmetic noise  (measured through the datapath'
            '${isIir ? '' : ', $structure${folded ? ' folded' : ''}'})');
        b.writeln('  error rms      ${noise.rmsLsb.toStringAsFixed(3)} LSB');
        b.writeln('  noise floor    '
            '${noise.medianDb.toStringAsFixed(2)} dB median, '
            '${worst.toStringAsFixed(2)} dB worst');
        // The number that decides whether the stopband on the plot is real.
        final designed = _deepestStopband();
        if (designed != null) {
          final actual = dp.effectiveResponse(designed, noise.medianDb);
          b.writeln('  stopband       ${designed.toStringAsFixed(2)} dB '
              'designed, ${actual.toStringAsFixed(2)} dB with the noise'
              '${actual > designed + 0.5 ? '   *** the arithmetic is the '
                  'limit, not the filter ***' : ''}');
        }
      }
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

/// Direct convolution, for the exactly-computed reference the measurement
/// compares the integer datapath against.
Float64List _convolve(Float64List taps, Float64List x) {
  final out = Float64List(x.length);
  for (var i = 0; i < x.length; i++) {
    var acc = 0.0;
    final upper = math.min(taps.length - 1, i);
    for (var k = 0; k <= upper; k++) {
      acc += taps[k] * x[i - k];
    }
    out[i] = acc;
  }
  return out;
}

/// A coefficient at a width that lines a phase up in the report.
String _short(double v) => v.toStringAsFixed(9).padLeft(13);

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
