/// The IIR core, checked against the Python implementation it replaces.
///
/// Every design is checked twice over. First as a *filter*: the same order and
/// degree, the same achieved ripple and attenuation, the same response at a
/// thousand frequencies, and the same second-order sections once the overall
/// gain is factored out and the sections are put in a canonical order. That is
/// the part that has to hold, and it is what catches a wrong pole, a mispaired
/// zero or a lost gain.
///
/// Then, separately, as a *cascade*: whether the sections also come out in the
/// same order. Three of them do not, and it is worth being precise about why.
/// A bandpass or bandstop produces pole pairs mirrored about the imaginary
/// axis, whose magnitudes are equal in exact arithmetic; `zpkToSos` orders
/// sections by that magnitude, so the order is settled by whichever way the
/// last bit falls after the frequency transformation and the bilinear map. Both
/// orders are the same filter. The Python's order is no more principled than
/// this port's -- it is numpy's rounding rather than Dart's -- so the list
/// below records the state of affairs rather than asserting an ideal. It is
/// pinned so that a change in it has to be noticed and explained.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:remez/src/iir_core.dart';

/// Designs whose sections come out in a different order from the Python's,
/// through the tie described above. The filters are identical.
const Set<String> orderingDiffers = {
  'cheby1 bs',
  'chebyshev2 bandpass',
  'ellip bp',
};

/// A cascade with the gain taken out of whichever section was holding it, and
/// the sections put in a canonical order, so that two cascades of the same
/// filter compare equal however `zpkToSos` happened to sequence them.
({double gain, List<List<double>> sections}) canonical(
    List<List<double>> sos) {
  var gain = 1.0;
  final out = <List<double>>[];
  for (final row in sos) {
    final r = List<double>.from(row);
    final lead = r[0] != 0.0 ? r[0] : (r[1] != 0.0 ? r[1] : r[2]);
    gain *= lead;
    for (var i = 0; i < 3; i++) {
      r[i] /= lead;
    }
    out.add(r);
  }
  out.sort(_compare);
  return (gain: gain, sections: out);
}

/// Order two sections by their coefficients, column by column.
///
/// On values rounded well short of the tolerance the sections are compared at,
/// so that two cascades of the same filter sort the same way despite the last
/// few bits differing. Signed zero is flattened: a b1 of -0.0 and one of +0.0
/// are the same coefficient, and sorting them apart is what this is here to
/// avoid.
int _compare(List<double> a, List<double> b) {
  for (var i = 0; i < 6; i++) {
    final x = _round(a[i]), y = _round(b[i]);
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

double _round(double v) {
  final r = (v * 1e7).roundToDouble() / 1e7;
  return r == 0.0 ? 0.0 : r;
}

void main() {
  final reference = json.decode(
      File('test/golden/reference.json').readAsStringSync()) as Map<String, dynamic>;
  final cases = (reference['iir'] as List<dynamic>).cast<Map<String, dynamic>>();

  IIRResult run(Map<String, dynamic> c) => design(
        c['response'] as String,
        c['approximation'] as String,
        wp: (c['wp'] as List<dynamic>).map((v) => (v as num).toDouble()).toList(),
        ws: (c['ws'] as List<dynamic>).map((v) => (v as num).toDouble()).toList(),
        rp: (c['rp'] as num).toDouble(),
        rs: (c['rs'] as num).toDouble(),
        order: c['order_arg'] as int?,
      );

  List<List<double>> wanted(Map<String, dynamic> c) => (c['sos'] as List<dynamic>)
      .map((r) => (r as List<dynamic>).map((v) => (v as num).toDouble()).toList())
      .toList();

  for (final c in cases) {
    final name = c['name'] as String;

    test('$name is the same filter as the Python design', () {
      final res = run(c);
      expect(res.order, c['order'], reason: 'order');
      expect(res.degree, c['degree'], reason: 'degree');
      expect(res.orderEstimate, c['order_estimate'], reason: 'estimate');
      expect(res.stable, c['stable']);
      expect(res.maxPoleRadius,
          closeTo((c['max_pole_radius'] as num).toDouble(), 1e-9));
      expect(res.achievedRp,
          closeTo((c['achieved_rp'] as num).toDouble(), 1e-6));
      expect(res.achievedRs,
          closeTo((c['achieved_rs'] as num).toDouble(), 1e-6));

      final want = wanted(c);
      expect(res.sos.length, want.length, reason: 'section count');

      // The same sections, gain and ordering set aside.
      final got = canonical(res.sos.map((r) => r.toList()).toList());
      final ref = canonical(want);
      expect(got.gain, closeTo(ref.gain, ref.gain.abs() * 1e-9),
          reason: 'overall gain');
      for (var s = 0; s < ref.sections.length; s++) {
        for (var col = 0; col < 6; col++) {
          expect(got.sections[s][col], closeTo(ref.sections[s][col], 1e-9),
              reason: 'canonical section $s column $col');
        }
      }

      // And the same response, which no reordering or regrouping can fake.
      final w = Float64List(1000);
      for (var i = 0; i < w.length; i++) {
        w[i] = math.pi * i / (w.length - 1);
      }
      final hGot = sosFreqz(res.sos, w);
      final hWant = sosFreqz([for (final r in want) Float64List.fromList(r)], w);
      for (var i = 0; i < w.length; i++) {
        expect(hGot[i].re, closeTo(hWant[i].re, 1e-9), reason: 'Re H at w[$i]');
        expect(hGot[i].im, closeTo(hWant[i].im, 1e-9), reason: 'Im H at w[$i]');
      }
    });
  }

  test('the cascades that also match the Python section for section', () {
    final differs = <String>{};
    for (final c in cases) {
      final got = run(c).sos;
      final want = wanted(c);
      var same = got.length == want.length;
      for (var s = 0; same && s < want.length; s++) {
        for (var col = 0; col < 6; col++) {
          if ((got[s][col] - want[s][col]).abs() > 1e-9) {
            same = false;
            break;
          }
        }
      }
      if (!same) differs.add(c['name'] as String);
    }
    expect(differs, orderingDiffers,
        reason: 'the set of designs whose section ORDER differs from the '
            'Python has changed; the filters are still checked as filters '
            'above, but work out why this moved before updating the list');
  });
}
