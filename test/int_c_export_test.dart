/// The integer-only C, against the datapath model it claims to be.
///
/// The claim is strong -- "the same arithmetic as the RTL, down to the last
/// bit, including where it clips" -- so the test has to be strong too: compile
/// the generated file, run real samples through it, and require every output
/// to equal `simulateFir`/`simulateIir` exactly. Not close: equal. The whole
/// point of the file is that it is the reference model.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:remez/src/controller.dart';
import 'package:remez/src/datapath.dart';
import 'package:remez/src/fir_core.dart' as fir;
import 'package:remez/src/fixed_point.dart' as fx;
import 'package:remez/src/int_c_export.dart';

/// Compile and run the source over [input], or null if there is no compiler.
List<int>? runC(String source, List<int> input, Directory dir) {
  final src = File('${dir.path}/filter.c')..writeAsStringSync(source);
  final exe = '${dir.path}/filter';
  final built =
      Process.runSync('cc', ['-O2', '-Wall', '-o', exe, src.path]);
  if (built.exitCode != 0) {
    if (built.stderr.toString().contains('not found')) return null;
    fail('cc failed:\n${built.stderr}');
  }
  expect(built.stderr.toString(), isEmpty,
      reason: 'generated C should compile without warnings');

  final data = Int32List.fromList(input);
  final inFile = File('${dir.path}/in.i32')
    ..writeAsBytesSync(data.buffer.asUint8List());
  final outPath = '${dir.path}/out.i32';
  final ran = Process.runSync('/bin/sh',
      ['-c', '"$exe" < "${inFile.path}" > "$outPath"']);
  expect(ran.exitCode, 0, reason: 'filter exited: ${ran.stderr}');
  final bytes = File(outPath).readAsBytesSync();
  return Int32List.view(
      Uint8List.fromList(bytes).buffer, 0, bytes.length ~/ 4).toList();
}

/// Samples that reach full scale, so the saturation is exercised and not
/// merely present.
List<int> drive(int n, int width) {
  final rng = math.Random(97531);
  final full = (1 << (width - 1)) - 1;
  return [
    for (var i = 0; i < n; i++)
      i < 8 ? full : (rng.nextDouble() * 2 - 1).round() * full ~/ 1 +
          (rng.nextInt(2 * full) - full)
  ].map((v) => v.clamp(-full - 1, full)).toList();
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('remez_int_c'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('the FIR', () {
    for (final structure in ['chain', 'tree']) {
      for (final folded in [false, true]) {
        test('matches the model exactly: $structure'
            '${folded ? ' folded' : ''}', () {
          final c = DesignController()
            ..arithmetic = Arithmetic.fixed
            ..wordBits = 12
            ..numtaps = 21
            ..structure = structure
            ..folded = folded
            ..design();
          expect(c.error, isNull);

          final source = firIntCSource(c.firEffective!,
              fixed: c.fixed!,
              headroom: c.headroom,
              structure: structure,
              folded: folded);
          final samples = drive(400, c.fixed!.bits + c.headroom);
          final got = runC(source, samples, dir);
          if (got == null) {
            printOnFailure('no C compiler; skipped');
            return;
          }

          final want = simulateFir(
            c.fixed!.ints.toList(),
            samples,
            c.fixed!.fracBits,
            c.fixed!.bits,
            c.headroom,
            structure: structureFromName(structure),
            folded: folded,
            symmetry: c.symmetry,
          );
          expect(got, want, reason: 'every sample, not most of them');
        });
      }
    }

    test('an antisymmetric folded filter matches too', () {
      final c = DesignController()
        ..arithmetic = Arithmetic.fixed
        ..wordBits = 12
        ..folded = true
        ..design();
      c.loadPreset('Hilbert transformer');
      expect(c.error, isNull);

      final source = firIntCSource(c.firEffective!,
          fixed: c.fixed!, headroom: c.headroom, folded: true);
      final samples = drive(300, c.fixed!.bits + c.headroom);
      final got = runC(source, samples, dir);
      if (got == null) return;
      expect(
          got,
          simulateFir(c.fixed!.ints.toList(), samples, c.fixed!.fracBits,
              c.fixed!.bits, c.headroom,
              folded: true, symmetry: c.symmetry));
    });

    test('it saturates rather than wrapping', () {
      final c = DesignController()
        ..arithmetic = Arithmetic.fixed
        ..wordBits = 10
        ..numtaps = 15
        ..design();
      final width = c.fixed!.bits + c.headroom;
      final full = (1 << (width - 1)) - 1;
      // A long run at full scale drives the accumulator past the datapath.
      final samples = List<int>.filled(120, full);
      final got = runC(
          firIntCSource(c.firEffective!,
              fixed: c.fixed!, headroom: c.headroom),
          samples,
          dir);
      if (got == null) return;
      for (final v in got) {
        expect(v, greaterThanOrEqualTo(-full - 1));
        expect(v, lessThanOrEqualTo(full));
      }
      expect(got.any((v) => v > 0), isTrue,
          reason: 'a wrap would have flipped the sign');
    });
  });

  group('the IIR', () {
    test('the cascade matches the model exactly', () {
      final c = DesignController()
        ..mode = Mode.iir
        ..arithmetic = Arithmetic.fixed
        ..wordBits = 14
        ..design();
      expect(c.error, isNull);

      final source = iirIntCSource(c.iirEffective!,
          fixed: c.fixed!, headroom: c.headroom);
      final samples = drive(400, c.fixed!.bits + c.headroom);
      final got = runC(source, samples, dir);
      if (got == null) return;

      final sections = [
        for (var s = 0; s < c.iirEffective!.sos.length; s++)
          [
            for (final col in [0, 1, 2, 4, 5]) c.fixed!.ints[s * 6 + col]
          ]
      ];
      expect(
          got,
          simulateIir(sections, samples, c.fixed!.fracBits, c.fixed!.bits,
              c.headroom));
    });
  });

  group('what it refuses', () {
    test('a datapath wider than an int32', () {
      final c = DesignController()
        ..arithmetic = Arithmetic.fixed
        ..wordBits = 40
        ..headroom = 8
        ..design();
      expect(
          () => firIntCSource(c.firEffective!,
              fixed: c.fixed!, headroom: 8),
          throwsA(isA<IntCError>()));
    });

    test('coefficients that saturated when they were quantized', () {
      final fixed = fx.quantize([0.5, 4.0, 0.5], 8, fracBits: 7);
      expect(fixed.saturated, greaterThan(0));
      expect(
          () => firIntCSource(
              fir.design(3, [fir.Band(0.0, 0.2, 1.0, 1.0)]),
              fixed: fixed),
          throwsA(isA<IntCError>()));
    });
  });

  group('what it says', () {
    test('no floating point anywhere in the code', () {
      final c = DesignController()
        ..arithmetic = Arithmetic.fixed
        ..design();
      final source =
          firIntCSource(c.firEffective!, fixed: c.fixed!, headroom: c.headroom);
      // The comments are allowed to say "floating point"; the code is not
      // allowed to contain any, so they are stripped before looking.
      final code = source
          .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
          .replaceAll(RegExp(r'//[^\n]*'), '');
      for (final banned in ['double', 'float', 'math.h']) {
        expect(code, isNot(contains(banned)),
            reason: 'no $banned in generated code');
      }
      // And no floating-point literal either: every coefficient is written
      // as the integer it is stored as.
      expect(RegExp(r'\d\.\d').hasMatch(code), isFalse,
          reason: 'a decimal literal would mean a coefficient slipped '
              'through as a double');
    });

    test('it names the structure it was built for', () {
      final c = DesignController()
        ..arithmetic = Arithmetic.fixed
        ..structure = 'tree'
        ..folded = true
        ..design();
      final source = firIntCSource(c.firEffective!,
          fixed: c.fixed!,
          headroom: c.headroom,
          structure: 'tree',
          folded: true);
      expect(source, contains('structure: tree, folded'));
    });
  });
}
