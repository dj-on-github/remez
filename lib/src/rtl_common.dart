/// What the RTL back-ends agree on, before either of them writes any text.
///
/// The SystemVerilog output describes hardware, and so would a VHDL one, so
/// everything that decides *what* that hardware is -- the options, the
/// coefficient tables, the term list of a folded filter, the resource counts,
/// the latency and the vectors a testbench checks against -- lives here, and
/// each back-end only has to render it.
library;

import 'datapath.dart' as dp;
import 'fir_core.dart' as fir;
import 'fixed_point.dart' as fx;
import 'format.dart';
import 'labels.dart';
import 'iir_core.dart' as iir;

const Map<String, String> structureLabels = {
  'chain': 'accumulator chain (one adder per tap, shortest area, longest path)',
  'tree': 'balanced adder tree, registered between levels',
  'mac': 'one multiplier reused over the taps, one term per clock',
};

const List<String> structures = ['chain', 'tree', 'mac'];

/// Raised when a design cannot be written out as hardware.
class RtlError implements Exception {
  const RtlError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Everything the panel and the file dialog decided about the hardware.
class RtlOptions {
  const RtlOptions({
    this.name = 'filt',
    this.headroom = 2,
    this.fixedCoeffs = true,
    this.structure = 'chain',
    this.folded = false,
  });

  final String name;
  final int headroom;
  final bool fixedCoeffs;
  final String structure;
  final bool folded;
}

/// The hardware to build, in a form either back-end can render.
class RtlPlan {
  RtlPlan({
    required this.kind,
    required this.name,
    required this.wcoef,
    required this.frac,
    required this.headroom,
    required this.wdata,
    required this.fixedCoeffs,
    required this.structure,
    required this.folded,
    required this.coeffs,
    required this.coeffLabels,
    required this.latency,
    required this.resources,
    required this.title,
    required this.detail,
    this.numtaps = 0,
    this.symmetry = fir.Symmetry.symmetric,
    this.nsec = 0,
    this.terms = const [],
    this.levels = 0,
    this.taps = const [],
  });

  final String kind; // "fir" | "iir"
  final String name;
  final int wcoef;
  final int frac;
  final int headroom;
  final int wdata;
  final bool fixedCoeffs;
  final String structure;
  final bool folded;

  /// The flat integer table the RTL stores.
  final List<int> coeffs;

  /// What each slice of the runtime port holds.
  final List<String> coeffLabels;

  final int numtaps;
  final fir.Symmetry symmetry;
  final int nsec;

  /// The folded or unfolded multiply list.
  final List<dp.FirTerm> terms;

  /// Adder-tree depth.
  final int levels;

  /// Clocks from din_strb to dout_strb.
  final int latency;
  final dp.Resources resources;
  final String title;
  final List<String> detail;

  /// The full tap list, for the model. Folding stores only half of it in
  /// [coeffs], but the simulation still needs every one.
  final List<int> taps;

  int get nterms => terms.length;
  int get npairs => terms.where((t) => t.taps.length == 2).length;

  /// True when the folded pre-adders subtract, as an antisymmetric one does.
  bool get subtracts => terms.any((t) => t.sign < 0);

  bool get hasCentre => folded && terms.any((t) => t.taps.length == 1);

  (int, int) get limits =>
      (-(1 << (wdata - 1)), (1 << (wdata - 1)) - 1);

  /// Run samples through the datapath this plan describes.
  List<int> simulate(List<int> samples) {
    if (kind == 'iir') {
      final sections = [
        for (var i = 0; i < coeffs.length; i += 5) coeffs.sublist(i, i + 5)
      ];
      return dp.simulateIir(sections, samples, frac, wcoef, headroom);
    }
    return dp.simulateFir(taps, samples, frac, wcoef, headroom,
        structure: dp.structureFromName(structure),
        folded: folded,
        symmetry: symmetry);
  }
}

/// Validate the request and work out the hardware it implies.
RtlPlan planFor(String kind, Object res, fx.Fixed? fixed, RtlOptions opts) {
  if (fixed == null) {
    throw const RtlError(
        'hardware needs fixed-point coefficients: choose Fixed point in '
        'the Arithmetic panel first');
  }
  final headroom = opts.headroom;
  if (headroom < 0 || headroom > 64) {
    throw RtlError('headroom must be 0..64 bits, got $headroom');
  }
  if (fixed.fracBits < 0) {
    throw RtlError(
        'the binary point is ${-fixed.fracBits} places into the integer '
        'part, which no shift can undo; give the coefficients more bits');
  }
  if (fixed.saturated > 0) {
    throw RtlError(
        '${fixed.saturated} coefficient(s) saturated when quantized, so the '
        'hardware would not be the filter that was designed; move the '
        'binary point right');
  }
  if (!structures.contains(opts.structure)) {
    throw RtlError("unknown structure '${opts.structure}'");
  }

  final name = sanitiseName(opts.name);

  if (kind == 'iir') {
    final r = res as iir.IIRResult;
    if (opts.folded || opts.structure != 'chain') {
      throw const RtlError(
          'an IIR is a cascade of biquads: there is nothing to fold, and '
          'its feedback cannot be pipelined without changing the filter. '
          'Use the chain structure with folding off.');
    }
    // The quantizer stores six per section with a0 among them; the hardware
    // never multiplies by a0, so only the five live columns are handed over.
    final nsec = fixed.ints.length ~/ 6;
    final sections = [
      for (var s = 0; s < nsec; s++)
        [for (final c in fx.sosLiveColumns) fixed.ints[s * 6 + c]]
    ];
    final labels = <String>[];
    for (var s = 0; s < sections.length; s++) {
      labels.addAll([
        'section $s b0',
        'section $s b1',
        'section $s b2',
        'section $s a1',
        'section $s a2',
      ]);
    }
    final plural = sections.length != 1 ? 's' : '';
    return RtlPlan(
      kind: 'iir',
      name: name,
      wcoef: fixed.bits,
      frac: fixed.fracBits,
      headroom: headroom,
      wdata: fixed.bits + headroom,
      fixedCoeffs: opts.fixedCoeffs,
      nsec: sections.length,
      coeffs: [for (final s in sections) ...s],
      coeffLabels: labels,
      structure: 'chain',
      folded: false,
      latency: 1,
      resources: dp.resources(0, fir.Symmetry.symmetric, dp.Structure.chain,
          false, sections: sections.length, iir: true),
      title: '$name: ${r.approximation} ${r.response} IIR, order ${r.order}',
      detail: [
        'sample rate ${formatG(r.fs)}, ${formatG(r.rp)} dB passband ripple, '
            '${formatG(r.rs)} dB stopband attenuation',
        'max |pole| = ${formatF(r.maxPoleRadius, 6)}'
            '${r.stable ? '' : '   *** UNSTABLE ***'}',
        'Cascade of ${sections.length} biquad$plural, each transposed '
            'direct form II:',
        '    y  = b0*x + s1',
        '    s1 = b1*x - a1*y + s2',
        '    s2 = b2*x - a2*y',
        'a0 is 1 for every section, so nothing multiplies by it; a1',
        'and a2 are given as designed and negated in the multiplier.',
      ],
    );
  }

  final r = res as fir.RemezResult;
  final taps = fixed.ints.toList();
  if (taps.length < 2) {
    throw const RtlError('a filter needs at least two taps to be worth building');
  }
  if (opts.folded && !_symmetric(taps, r.symmetry)) {
    throw const RtlError(
        'folding needs the taps to be symmetric, and these are not; '
        'the design must be linear phase');
  }

  final terms = dp.firTerms(taps.length, r.symmetry, opts.folded);
  final band =
      r.bands.map((b) => '${formatG(b.f1)}-${formatG(b.f2)}').join(', ');
  final stored = [for (final t in terms) taps[t.coefIndex]];
  final labels = <String>[];
  for (final t in terms) {
    if (t.taps.length == 1) {
      labels.add('h[${t.coefIndex}]${opts.folded ? ' (centre tap)' : ''}');
    } else {
      final op = t.sign < 0 ? '-' : '+';
      labels.add('h[${t.coefIndex}]   for x[${t.taps[0]}] $op x[${t.taps[1]}]');
    }
  }

  final detail = [
    'sample rate ${formatG(r.fs)}, bands $band',
    'weighted delta = ${formatG(r.delta.abs())} as designed',
    'Structure: ${structureLabels[opts.structure]}.',
  ];
  if (opts.folded) {
    detail.addAll([
      'Folded: the response is linear phase, so the taps are equal in',
      'pairs and one pre-${terms.first.sign < 0 ? 'subtract' : 'add'} plus '
          'one multiply serves two of them,',
      'which is ${taps.length} multipliers down to ${terms.length}.  Note '
          'that a folded',
      'filter rounds once per pair rather than once per tap, so it is not',
      'bit-identical to the unfolded one -- it is very slightly better.',
    ]);
  }

  return RtlPlan(
    kind: 'fir',
    name: name,
    wcoef: fixed.bits,
    frac: fixed.fracBits,
    headroom: headroom,
    wdata: fixed.bits + headroom,
    fixedCoeffs: opts.fixedCoeffs,
    numtaps: taps.length,
    symmetry: r.symmetry,
    coeffs: stored,
    coeffLabels: labels,
    structure: opts.structure,
    folded: opts.folded,
    terms: terms,
    levels: dp.treeLevels(terms.length),
    latency: dp.latency(taps.length, r.symmetry,
        dp.structureFromName(opts.structure), opts.folded),
    resources: dp.resources(taps.length, r.symmetry,
        dp.structureFromName(opts.structure), opts.folded),
    title: '$name: Parks-McClellan FIR, type ${r.ftype} '
        '(${r.symmetry.name}), N = ${taps.length}',
    detail: detail,
    taps: taps,
  );
}

bool _symmetric(List<int> taps, fir.Symmetry symmetry) {
  final anti = symmetry == fir.Symmetry.antisymmetric;
  for (var i = 0; i < taps.length; i++) {
    final mirror = taps[taps.length - 1 - i];
    if (taps[i] != (anti ? -mirror : mirror)) return false;
  }
  return true;
}
