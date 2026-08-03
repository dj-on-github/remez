/// The saved-design format, which is shared with the Python tool.
///
/// The point of the format is that a design saved in either program opens in
/// the other, so the test that matters is against a file the *Python* wrote,
/// not one this program wrote and read back.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:remez/src/controller.dart';
import 'package:remez/src/fir_core.dart' as fir;
import 'package:remez/src/labels.dart';

Map<String, dynamic> _pythonFile() => json.decode(
        File('test/golden/py_design.json').readAsStringSync())
    as Map<String, dynamic>;

void main() {
  test('a design the Python saved opens here', () {
    final c = DesignController()..fromJson(_pythonFile());
    expect(c.error, isNull);

    expect(c.fs, 48000.0);
    expect(c.numtaps, 63);
    expect(c.gridDensity, 24);
    expect(c.maxiter, 77);
    expect(c.useSpec, isTrue);
    expect(c.rows, hasLength(2));
    expect(c.rows[0].f2, '9600');
    expect(c.rows[1].f1, '12000');
    expect(c.rows[1].spec, '55');

    expect(c.arithmetic, Arithmetic.fixed);
    expect(c.wordBits, 14);
    expect(c.headroom, 3);
    expect(c.structure, 'tree');
    expect(c.folded, isTrue);
    expect(c.wantTestbench, isFalse);

    expect(c.rp, '0.25');
    expect(c.rs, '66');
    expect(c.approximation, 'elliptic');

    // And it actually designed the filter the file describes.
    expect(c.firResult!.numtaps, 63);
    expect(c.specDev, hasLength(2));
    expect(c.fixed!.bits, 14);
  });

  test('what this program writes is the same shape', () {
    // Every key the Python wrote, this writes too -- otherwise a design saved
    // here would lose settings when opened there.
    final want = _pythonFile();
    final got = (DesignController()..fromJson(want)).toJson();
    for (final section in ['fir', 'iir', 'arithmetic', 'display']) {
      final a = (got[section] as Map).keys.toSet();
      final b = (want[section] as Map).keys.toSet();
      expect(a.containsAll(b), isTrue,
          reason: '$section is missing ${b.difference(a)}');
    }
    expect(got['format'], want['format']);
    expect(got['version'], want['version']);
    expect(got['mode'], want['mode']);
  });

  test('settings this program has no control for survive a round trip', () {
    // show_ext, show_noise, show_spec and the folded panel list belong to the
    // Tk UI. Reading and rewriting a file must not drop them.
    final want = _pythonFile();
    final got = (DesignController()..fromJson(want)).toJson();
    final display = got['display'] as Map<String, dynamic>;
    for (final key in ['show_ext', 'show_noise', 'show_spec', 'folded_panels']) {
      expect(display.containsKey(key), isTrue, reason: key);
      expect(display[key], (want['display'] as Map)[key], reason: key);
    }
  });

  test('a design survives its own round trip', () {
    final a = DesignController();
    a.update(() {
      a.mode = Mode.iir;
      a.approximation = 'chebyshev2';
      a.wordBits = 10;
      a.arithmetic = Arithmetic.fixed;
      a.folded = true;
      a.structure = 'mac';
      a.view = Pane.design;
      a.logScale = false;
    });
    a.setResponse('bandstop');
    a.loadPreset('Differentiator');
    a.update(() => a.mode = Mode.fir);

    final b = DesignController()
      ..fromJson(json.decode(json.encode(a.toJson())) as Map<String, dynamic>);

    expect(b.mode, a.mode);
    expect(b.numtaps, a.numtaps);
    expect(b.symmetry, fir.Symmetry.antisymmetric);
    expect(b.rows.single.invF, isTrue);
    expect(b.rows.single.d1, a.rows.single.d1);
    expect(b.structure, 'mac');
    expect(b.folded, isTrue);
    expect(b.view, Pane.design);
    expect(b.logScale, isFalse);
    expect(b.approximation, 'chebyshev2');
    expect(b.response, 'bandstop');
    // The filter itself, not just the fields.
    for (var i = 0; i < a.firResult!.h.length; i++) {
      expect(b.firResult!.h[i], a.firResult!.h[i], reason: 'h[$i]');
    }
  });

  test('a file that is not a design is refused', () {
    expect(() => DesignController().fromJson({'format': 'something else'}),
        throwsA(isA<FormatException>()));
    expect(() => DesignController().fromJson({}),
        throwsA(isA<FormatException>()));
  });

  test('the file is called .remz and is still JSON inside', () {
    // The extension is the only thing that changed: the contents are the same
    // format the Python tool reads and writes, which is what keeps a design
    // portable between the two.
    expect(designExtension, 'remz');
    expect(designExtensions, contains('remz'));
    expect(designExtensions, contains('json'),
        reason: 'designs saved before this, and every one the Python writes, '
            'are named .json');

    final text = json.encode((DesignController()..design()).toJson());
    final back = json.decode(text) as Map<String, dynamic>;
    expect(back['format'], DesignController.formatName);
    expect(() => DesignController().fromJson(back), returnsNormally);
  });

  test('a design missing sections keeps what it had', () {
    final c = DesignController();
    final taps = c.numtaps;
    c.fromJson({'format': DesignController.formatName, 'version': 1});
    expect(c.numtaps, taps);
    expect(c.error, isNull);
  });
}
