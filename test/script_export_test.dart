/// The NumPy and MATLAB exports.
///
/// The MATLAB one can only be checked by reading it -- there is no Octave in
/// this project's toolchain -- so the tests are about shape and content. The
/// Python one can be run, and is: if NumPy is on the machine, the generated
/// module is imported and its output compared against this program's own, so
/// "the coefficients came across correctly" is measured and not assumed.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:remez/src/controller.dart';
import 'package:remez/src/script_export.dart';

/// Run a snippet with the generated module importable, or null without Python.
String? runPython(String module, String snippet, Directory dir) {
  File('${dir.path}/generated.py').writeAsStringSync(module);
  File('${dir.path}/check.py').writeAsStringSync(snippet);
  for (final python in ['python3', 'python']) {
    final probe = Process.runSync(python, ['-c', 'import numpy']);
    if (probe.exitCode != 0) continue;
    final ran = Process.runSync(python, ['check.py'],
        workingDirectory: dir.path);
    if (ran.exitCode != 0) fail('$python failed:\n${ran.stderr}');
    return ran.stdout.toString();
  }
  return null;
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('remez_script'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('choosing a language', () {
    test('by the extension, and nothing else', () {
      expect(scriptLanguageFor('/tmp/filter.py'), 'python');
      expect(scriptLanguageFor('/tmp/Filter.PY'), 'python');
      expect(scriptLanguageFor('/tmp/filter.m'), 'matlab');
      expect(scriptLanguageFor('/tmp/filter.c'), isNull);
      expect(scriptLanguageFor('/tmp/filter'), isNull);
    });
  });

  group('Python', () {
    test('an FIR module filters the same samples the same way', () {
      final c = DesignController()..design();
      final module = firScript(c.firEffective!, 'python', name: 'run');

      final x = Float64List.fromList(
          [for (var i = 0; i < 200; i++) math.sin(i * 0.31) + 0.4 * math.cos(i)]);
      final snippet = '''
import numpy as np
from generated import run, TAPS
x = np.array([${x.join(', ')}])
y = run(x)
print(TAPS.size)
print(' '.join('%.17g' % v for v in y))
''';
      final out = runPython(module, snippet, dir);
      if (out == null) {
        printOnFailure('no python3 with numpy; skipped');
        return;
      }
      final lines = out.trim().split('\n');
      expect(int.parse(lines[0]), c.numtaps);

      final got = lines[1].split(' ').map(double.parse).toList();
      expect(got, hasLength(x.length));
      // The same convolution this program would compute, to the last bit that
      // a different summation order leaves alone.
      final h = c.firEffective!.h;
      for (var i = 0; i < x.length; i++) {
        var want = 0.0;
        for (var k = 0; k < h.length && k <= i; k++) {
          want += h[k] * x[i - k];
        }
        expect(got[i], closeTo(want, 1e-12), reason: 'sample $i');
      }
    });

    test('the fixed-point integers are exactly the stored ones', () {
      final c = DesignController()
        ..arithmetic = Arithmetic.fixed
        ..wordBits = 12
        ..design();
      final module = firScript(c.firEffective!, 'python', fixed: c.fixed);
      final out = runPython(module, '''
import numpy as np
from generated import TAPS, TAPS_Q, FRAC_BITS
print(' '.join(str(int(v)) for v in TAPS_Q))
print(int(np.max(np.abs(TAPS - TAPS_Q / 2.0**FRAC_BITS)) == 0))
''', dir);
      if (out == null) return;
      final lines = out.trim().split('\n');
      expect(lines[0].split(' ').map(int.parse).toList(),
          c.fixed!.ints.toList());
      expect(lines[1], '1', reason: 'TAPS should be TAPS_Q / 2**FRAC_BITS');
    });

    test('an IIR module carries the sections in scipy order', () {
      final c = DesignController()
        ..mode = Mode.iir
        ..design();
      final module = iirScript(c.iirEffective!, 'python');
      expect(module, contains('from scipy.signal import sosfilt'));
      expect(module, contains('SOS = np.array(['));
      // Six numbers per row, b0 b1 b2 a0 a1 a2, which is what scipy wants.
      final rows = RegExp(r'^    \[(.*)\],$', multiLine: true)
          .allMatches(module)
          .map((m) => m.group(1)!.split(', ').length)
          .toList();
      expect(rows, hasLength(c.iirEffective!.sos.length));
      expect(rows.every((n) => n == 6), isTrue);
    });

    test('the function is named after the file', () {
      final c = DesignController()..design();
      expect(firScript(c.firEffective!, 'python', name: 'lowpass_9k6'),
          contains('def lowpass_9k6(x):'));
    });
  });

  group('MATLAB', () {
    test('an FIR is a function that calls filter', () {
      final c = DesignController()..design();
      final m = firScript(c.firEffective!, 'matlab', name: 'lp');
      expect(m, startsWith('function y = lp(x)'));
      expect(m, contains('y = filter(h, 1, x);'));
      expect(m.trimRight(), endsWith('end'));
      // One row per tap, in a continued matrix literal.
      expect('; ...\n'.allMatches(m).length, greaterThanOrEqualTo(c.numtaps));
    });

    test('an IIR stays as sections', () {
      final c = DesignController()
        ..mode = Mode.iir
        ..design();
      final m = iirScript(c.iirEffective!, 'matlab');
      expect(m, contains('sos = [ ...'));
      expect(m, contains('y = sosfilt(sos, x);'));
      expect(m, isNot(contains('y = filter(b, a, x)')),
          reason: 'flattening the cascade is what loses the stability');
    });

    test('fixed point brings its integers along', () {
      final c = DesignController()
        ..arithmetic = Arithmetic.fixed
        ..wordBits = 10
        ..design();
      final m = firScript(c.firEffective!, 'matlab', fixed: c.fixed);
      expect(m, contains('fracBits = ${c.fixed!.fracBits};'));
      expect(m, contains('hq = [${c.fixed!.ints.join('; ')}]'));
    });
  });

  group('both languages', () {
    test('every mode and arithmetic produces something', () {
      for (final language in ['python', 'matlab']) {
        for (final iir in [false, true]) {
          for (final fixedPoint in [false, true]) {
            final c = DesignController()
              ..mode = iir ? Mode.iir : Mode.fir
              ..arithmetic =
                  fixedPoint ? Arithmetic.fixed : Arithmetic.floating
              ..design();
            final text = iir
                ? iirScript(c.iirEffective!, language, fixed: c.fixed)
                : firScript(c.firEffective!, language, fixed: c.fixed);
            expect(text, isNotEmpty);
            expect(text, contains('remez'));
            expect(text.contains('fracBits') || text.contains('FRAC_BITS'),
                fixedPoint,
                reason: '$language, iir=$iir, fixed=$fixedPoint');
          }
        }
      }
    });
  });
}
