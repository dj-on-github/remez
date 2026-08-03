/// Quantization and the datapath, checked against the Python implementation.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:remez/src/datapath.dart';
import 'package:remez/src/fir_core.dart';
import 'package:remez/src/fixed_point.dart';
import 'package:remez/src/iir_core.dart' as iir;

Map<String, dynamic> loadReference() =>
    json.decode(File('test/golden/reference.json').readAsStringSync())
        as Map<String, dynamic>;

RemezResult referenceLowpass() => design(41, [
      Band.flat(0, 0.2, 1.0),
      Band.flat(0.25, 0.5, 0.0, weight: 10.0),
    ]);

void main() {
  final reference = loadReference();

  group('quantization against the Python implementation', () {
    for (final entry in reference['fixed'] as List<dynamic>) {
      final c = entry as Map<String, dynamic>;
      test('${c['kind']} at ${c['bits']} bits matches', () {
        if (c['kind'] == 'taps') {
          final q = quantize(referenceLowpass().h, c['bits'] as int);
          expect(q.fracBits, c['frac_bits']);
          expect(q.saturated, c['saturated']);
          final want = (c['ints'] as List<dynamic>).cast<int>();
          expect(q.ints.toList(), want);
          expect(q.maxError, closeTo((c['max_error'] as num).toDouble(), 1e-15));
        } else {
          final res = iir.design('lowpass', 'elliptic',
              wp: [0.2], ws: [0.3], rp: 0.5, rs: 40);
          final q = quantizeSos(res.sos, c['bits'] as int);
          expect(q.fracBits, c['frac_bits']);
          final want = (c['ints'] as List<dynamic>)
              .map((r) => (r as List<dynamic>).cast<int>())
              .toList();
          for (var s = 0; s < want.length; s++) {
            for (var col = 0; col < 6; col++) {
              expect(q.ints[s * 6 + col], want[s][col],
                  reason: 'section $s column $col');
            }
          }
        }
      });
    }
  });

  group('the format', () {
    test('values land on the lattice', () {
      final q = quantize([0.1, -0.25, 0.4], 12);
      for (var i = 0; i < q.ints.length; i++) {
        expect(q.values[i], closeTo(q.ints[i] * q.step, 1e-18));
      }
    });

    test('exactly representable values are untouched', () {
      final exact = [0.5, -0.25, 0.125, 0.0, -0.5];
      final q = quantize(exact, 16);
      for (var i = 0; i < exact.length; i++) {
        expect(q.values[i], exact[i]);
      }
      expect(q.maxError, 0.0);
    });

    test('rounding error is at most half a step', () {
      final rng = math.Random(7);
      for (final bits in [6, 8, 12, 16, 24]) {
        final v = List<double>.generate(200, (_) => rng.nextDouble() * 2 - 1);
        final q = quantize(v, bits);
        expect(q.saturated, 0);
        expect(q.maxError, lessThanOrEqualTo(q.step / 2 + 1e-18));
      }
    });

    test('the automatic point gives away no resolution', () {
      final rng = math.Random(2);
      final v = List<double>.generate(50, (_) => rng.nextDouble() * 1.8 - 0.9);
      final q = quantize(v, 16);
      final greedier = quantize(v, 16, fracBits: q.fracBits + 1);
      expect(greedier.saturated, greaterThan(0));
    });

    test('a forced binary point saturates and says so', () {
      final q = quantize([0.4, 1.2, -1.5], 8, fracBits: 7);
      expect(q.saturated, 2);
      expect(q.ints[1], q.maxInt);
      expect(q.ints[2], q.minInt);
    });

    test('impossible word lengths are refused', () {
      for (final bits in [1, 0, -3, 54]) {
        expect(() => quantize([0.5], bits), throwsA(isA<FixedPointError>()));
      }
    });

    test('a0 stays exactly one and does not drag the point', () {
      final res = iir.design('lowpass', 'elliptic',
          wp: [0.2], ws: [0.3], rp: 0.5, rs: 40);
      for (final bits in [8, 12, 16]) {
        final q = quantizeSos(res.sos, bits);
        for (var s = 0; s * 6 < q.values.length; s++) {
          expect(q.values[s * 6 + 3], 1.0);
        }
      }
      final tiny = [Float64List.fromList([0.01, 0.02, 0.01, 1.0, -0.5, 0.25])];
      expect(quantizeSos(tiny, 12).fracBits,
          greaterThan(quantize(tiny.first.toList(), 12).fracBits));
    });
  });

  group('quantization and the design', () {
    test('linear phase survives it', () {
      for (final spec in [
        [41, Symmetry.symmetric],
        [40, Symmetry.symmetric],
        [41, Symmetry.antisymmetric],
        [40, Symmetry.antisymmetric],
      ]) {
        final res = design(
            spec[0] as int,
            [Band.flat(0.05, 0.2, 1.0), Band.flat(0.25, 0.45, 0.0)],
            symmetry: spec[1] as Symmetry);
        final q = quantize(res.h, 8);
        final sign = spec[1] == Symmetry.symmetric ? 1 : -1;
        for (var i = 0; i < q.values.length; i++) {
          expect(q.values[i], sign * q.values[q.values.length - 1 - i]);
        }
      }
    });

    test('the stopband floor rises as bits are removed', () {
      final res = referenceLowpass();
      final floors = <double>[];
      for (final bits in [8, 10, 12, 16, 24]) {
        floors.add(withTaps(res, quantize(res.h, bits).values).bandDeviation[1]);
      }
      for (var i = 0; i < floors.length - 1; i++) {
        expect(floors[i], greaterThan(floors[i + 1]));
      }
      expect(floors.first, greaterThan(3 * res.bandDeviation[1]));
      expect(floors.last, closeTo(res.bandDeviation[1], res.bandDeviation[1] * 1e-3));
    });
  });

  group('the datapath against the Python implementation', () {
    for (final entry in reference['datapath'] as List<dynamic>) {
      final c = entry as Map<String, dynamic>;
      final label = c['kind'] == 'fir'
          ? 'fir ${c['structure']} ${c['folded'] == true ? 'folded' : 'flat'}'
          : 'iir cascade';
      test('$label matches', () {
        final stim = (c['stim'] as List<dynamic>).cast<int>();
        final want = (c['expect'] as List<dynamic>).cast<int>();
        late List<int> got;
        if (c['kind'] == 'fir') {
          got = simulateFir(
            (c['taps'] as List<dynamic>).cast<int>(),
            stim,
            c['frac_bits'] as int,
            c['bits'] as int,
            c['headroom'] as int,
            structure: Structure.values
                .firstWhere((s) => s.label == c['structure']),
            folded: c['folded'] as bool,
          );
        } else {
          got = simulateIir(
            (c['sections'] as List<dynamic>)
                .map((r) => (r as List<dynamic>).cast<int>())
                .toList(),
            stim,
            c['frac_bits'] as int,
            c['bits'] as int,
            c['headroom'] as int,
          );
        }
        expect(got, want);
      });
    }
  });

  group('the arithmetic', () {
    test('multiply rounds to nearest', () {
      expect(mul(3, 3, 1, 8), 5);
      expect(mul(-3, 3, 1, 8), -4);
    });

    test('everything saturates rather than wrapping', () {
      expect(add(100, 100, 8), 127);
      expect(add(-100, -100, 8), -128);
      expect(mul(127, 127, 0, 8), 127);
    });

    test('the chain and the tree agree until something clips', () {
      final res = referenceLowpass();
      final q = quantize(res.h, 12);
      final taps = q.ints.toList();
      final small = List<int>.filled(30, 1 << (q.fracBits - 3));
      expect(
          simulateFir(taps, small, q.fracBits, q.bits, 4,
              structure: Structure.chain),
          simulateFir(taps, small, q.fracBits, q.bits, 4,
              structure: Structure.tree));

      final full = List<int>.filled(30, (1 << (q.bits - 1)) - 1);
      expect(
          simulateFir(taps, full, q.fracBits, q.bits, 0,
              structure: Structure.chain),
          isNot(simulateFir(taps, full, q.fracBits, q.bits, 0,
              structure: Structure.tree)));
    });

    test('folding halves the multiplies', () {
      expect(termCount(41, Symmetry.symmetric, true), 21);
      expect(termCount(40, Symmetry.symmetric, true), 20);
      expect(termCount(41, Symmetry.antisymmetric, true), 20);
      expect(termCount(41, Symmetry.symmetric, false), 41);
    });

    test('the folded pre-adder does not clip a full-scale pair', () {
      final res = referenceLowpass();
      final q = quantize(res.h, 12);
      const headroom = 4;
      final hi = (1 << (q.bits + headroom - 1)) - 1;
      final x = <int>[];
      for (var i = 0; i < 30; i++) {
        x.addAll([hi, -hi]);
      }
      final got = simulateFir(q.ints.toList(), x, q.fracBits, q.bits, headroom,
          folded: true);
      // Against the exact convolution of the same taps.
      for (var i = 5; i < x.length; i++) {
        var want = 0.0;
        for (var k = 0; k < q.values.length && k <= i; k++) {
          want += q.values[k] * x[i - k];
        }
        expect((got[i] - want).abs(), lessThan(8.0));
      }
    });

    test('the mac accumulates in the same order as the chain', () {
      final res = referenceLowpass();
      final q = quantize(res.h, 12);
      final rng = math.Random(0);
      final x = List<int>.generate(40, (_) => rng.nextInt(4000) - 2000);
      expect(
          simulateFir(q.ints.toList(), x, q.fracBits, q.bits, 3,
              structure: Structure.mac),
          simulateFir(q.ints.toList(), x, q.fracBits, q.bits, 3,
              structure: Structure.chain));
    });

    test('latency and cost follow the structure', () {
      expect(latency(41, Symmetry.symmetric, Structure.chain, false), 1);
      expect(latency(41, Symmetry.symmetric, Structure.mac, false), 43);
      expect(latency(41, Symmetry.symmetric, Structure.mac, true), 23);
      expect(resources(41, Symmetry.symmetric, Structure.mac, false).multipliers,
          1);
      expect(
          resources(41, Symmetry.symmetric, Structure.chain, true).multipliers,
          21);
      expect(resources(256, Symmetry.symmetric, Structure.tree, false).pipeline,
          8);
    });
  });

  group('the measured noise floor', () {
    test('matches q*sqrt(N/12) from the theory', () {
      final res = referenceLowpass();
      const headroom = 4;
      for (final bits in [10, 14, 18]) {
        final q = quantize(res.h, bits);
        final taps = q.ints.toList();
        final measured = noiseResponse(
          (x) => simulateFir(taps, x, q.fracBits, q.bits, headroom),
          (x) {
            final out = Float64List(x.length);
            for (var i = 0; i < x.length; i++) {
              var acc = 0.0;
              for (var k = 0; k < q.values.length && k <= i; k++) {
                acc += q.values[k] * x[i - k];
              }
              out[i] = acc;
            }
            return out;
          },
          q.fracBits,
          q.bits,
          headroom,
          length: 1 << 13,
        );
        expect(measured.rmsLsb,
            closeTo(math.sqrt(res.numtaps / 12.0), math.sqrt(res.numtaps / 12.0) * 0.3));

        final full = (1 << (q.bits + headroom - 1)) - 1;
        final predicted = 20 *
            math.log(math.sqrt(res.numtaps / 12.0) / (noiseLevel * full)) /
            math.ln10;
        expect(measured.medianDb, closeTo(predicted, 2.0));
      }
    });

    test('noise adds to the response in power', () {
      expect(effectiveResponse(-100.0, -60.0), closeTo(-60.0, 0.01));
      expect(effectiveResponse(-60.0, -60.0), closeTo(-56.99, 0.01));
      expect(effectiveResponse(0.0, -80.0), closeTo(0.0, 0.01));
    });
  });
}
