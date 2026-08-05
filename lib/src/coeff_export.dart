/// The coefficients on their own, as a table.
///
/// Two formats, chosen by the file's extension: a `.h` gets C arrays ready to
/// paste into a build, anything else gets CSV with a commented header. In fixed
/// point both carry the stored integers alongside the rounded values they
/// stand for, since one is what the hardware holds and the other is what it
/// means.
///
/// Always the coefficients *as built*: in fixed point that is the rounded
/// filter, not the one that was asked for.
library;

import 'fir_core.dart' as fir;
import 'fixed_point.dart' as fx;
import 'dart:typed_data';

import 'format.dart';
import 'iir_core.dart' as iir;
import 'labels.dart';

/// One line describing the word length, for an export header.
String formatNote(fx.Fixed? fixed) => fixed == null
    ? 'double precision coefficients'
    : '${fixed.bits}-bit fixed point, ${fixed.qFormat}: '
        'value = integer * 2^-${fixed.fracBits}';

/// True when [path] asks for the C header rather than CSV.
bool wantsHeader(String path) => path.endsWith('.h');

/// The impulse response, as CSV or as a C array.
/// [phases] is the polyphase decomposition, when the filter is part of a rate
/// change. It is written alongside the taps rather than instead of them: the
/// phases are the same numbers regrouped, and which form is wanted depends on
/// whether the reader is checking the design or building the hardware.
List<String> firExport(fir.RemezResult res, String path,
    {fx.Fixed? fixed, List<Float64List>? phases}) {
  final note = formatNote(fixed);
  if (wantsHeader(path)) {
    final lines = <String>[
      '/* Parks-McClellan FIR, type ${res.ftype}, '
          'N = ${res.numtaps}, delta = ${formatG(res.delta.abs())} */',
      '/* $note */',
      '#define FIR_TAPS ${res.numtaps}',
    ];
    if (fixed != null) {
      lines.addAll([
        '#define FIR_FRAC_BITS ${fixed.fracBits}',
        'static const long fir_coeffs_q[FIR_TAPS] = {',
        for (final v in fixed.ints) '    $v,',
        '};',
        '',
      ]);
    }
    lines.addAll([
      'static const double fir_coeffs[FIR_TAPS] = {',
      for (final v in res.h) '    ${formatG(v, precision: 17, space: true)},',
      '};',
      '',
    ]);
    if (phases != null && phases.isNotEmpty) {
      lines.addAll([
        '/* Polyphase: phase p is taps p, p+M, p+2M, ...  Feeding each phase',
        '   every Mth sample and summing computes only the outputs a',
        '   decimator keeps, for 1/M of the multiplies. */',
        '#define FIR_PHASES ${phases.length}',
        '#define FIR_PHASE_TAPS ${phases.first.length}',
        'static const double fir_phases[FIR_PHASES][FIR_PHASE_TAPS] = {',
        for (final phase in phases)
          '    {${phase.map((v) => formatG(v, precision: 17)).join(', ')}},',
        '};',
        '',
      ]);
    }
    return lines;
  }

  final lines = <String>[
    '# Parks-McClellan FIR, type ${res.ftype}, '
        'N = ${res.numtaps}, fs = ${formatG(res.fs)}',
    '# $note',
    '# weighted delta = ${formatG(res.delta.abs(), precision: 10)}',
    'n,h${fixed != null ? ',h_q' : ''}',
  ];
  for (var i = 0; i < res.h.length; i++) {
    var row = '$i,${formatG(res.h[i], precision: 17)}';
    if (fixed != null) row += ',${fixed.ints[i]}';
    lines.add(row);
  }
  if (phases != null && phases.isNotEmpty) {
    lines.addAll([
      '',
      '# polyphase: phase p is taps p, p+${phases.length}, '
          'p+${2 * phases.length}, ...',
      'phase,k,h',
    ]);
    for (var p = 0; p < phases.length; p++) {
      for (var k = 0; k < phases[p].length; k++) {
        lines.add('$p,$k,${formatG(phases[p][k], precision: 17)}');
      }
    }
  }
  return lines;
}

/// Biquad sections, as CSV or as a C table ready to cascade.
List<String> iirExport(iir.IIRResult res, String path, {fx.Fixed? fixed}) {
  final head = '${labelOf(res.approximation)} ${res.response}, '
      'order ${res.order}, fs = ${formatG(res.fs)}, '
      '${formatG(res.rp)} dB / ${formatG(res.rs)} dB';
  final note = formatNote(fixed);

  if (wantsHeader(path)) {
    final lines = <String>[
      '/* $head */',
      '/* $note */',
      '/* cascade of ${res.sos.length} biquads, '
          "each y = b0 x + b1 x' + b2 x'' - a1 y' - a2 y'' */",
      '#define IIR_SECTIONS ${res.sos.length}',
    ];
    if (fixed != null) {
      lines.addAll([
        '#define IIR_FRAC_BITS ${fixed.fracBits}',
        'static const long iir_sos_q[IIR_SECTIONS][6] = {',
        for (var s = 0; s < res.sos.length; s++)
          '    {${_sectionInts(fixed, s).join(', ')}},',
        '};',
        '',
      ]);
    }
    lines.addAll([
      'static const double iir_sos[IIR_SECTIONS][6] = {',
      for (final s in res.sos)
        '    {${s.map((v) => formatG(v, precision: 17, space: true)).join(', ')}},',
      '};',
      '',
    ]);
    return lines;
  }

  final lines = <String>[
    '# $head',
    '# $note',
    '# max |pole| = ${formatG(res.maxPoleRadius, precision: 10)}, '
        'achieved ${formatG(res.achievedRp, precision: 4)} dB / '
        '${formatG(res.achievedRs, precision: 4)} dB',
    'section,b0,b1,b2,a0,a1,a2'
        '${fixed != null ? ',b0_q,b1_q,b2_q,a0_q,a1_q,a2_q' : ''}',
  ];
  for (var i = 0; i < res.sos.length; i++) {
    var row =
        '$i,${res.sos[i].map((v) => formatG(v, precision: 17)).join(',')}';
    if (fixed != null) row += ',${_sectionInts(fixed, i).join(',')}';
    lines.add(row);
  }
  return lines;
}

/// The six stored integers of section [s].
///
/// The quantizer keeps them flat, six per section with a0 among them, because
/// that is the shape the tables here and the RTL's five-column form are both
/// cut from.
List<int> _sectionInts(fx.Fixed fixed, int s) =>
    [for (var c = 0; c < 6; c++) fixed.ints[s * 6 + c]];
