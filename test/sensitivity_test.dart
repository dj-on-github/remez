/// The coefficient sensitivity envelope.
///
/// The claim it makes is "half an LSB of error either way covers this much
/// response", so the tests are about that: the envelope must contain the
/// design it was drawn around, must shrink as the word length grows, and must
/// notice when a perturbed IIR falls off the unit circle.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:remez/src/controller.dart';

DesignController sensitive(int bits, {void Function(DesignController)? also}) {
  final c = DesignController()
    ..arithmetic = Arithmetic.fixed
    ..wordBits = bits
    ..showSensitivity = true;
  also?.call(c);
  return c..design();
}

void main() {
  group('when there is nothing to shade', () {
    test('floating point has no LSB to be half of', () {
      final c = DesignController()
        ..showSensitivity = true
        ..design();
      expect(c.sensitivity(), isNull);
    });

    test('it stays off until it is asked for', () {
      final c = DesignController()
        ..arithmetic = Arithmetic.fixed
        ..design();
      expect(c.sensitivity(), isNull);
      expect(c.report(), isNot(contains('half an LSB')));
    });
  });

  group('the envelope', () {
    test('it contains the response it was drawn around', () {
      final c = sensitive(12);
      final spread = c.sensitivity(points: 256)!;
      final built = c.magnitude(points: 256);
      for (var i = 0; i < spread.f.length; i++) {
        expect(spread.f[i], closeTo(built.f[i], 1e-12));
        // Not a tautology: the nominal design is one particular rounding, and
        // the draws are others, so it should land inside their spread.
        expect(built.y[i], greaterThanOrEqualTo(spread.lo[i] - 1e-6));
        expect(built.y[i], lessThanOrEqualTo(spread.hi[i] + 1e-6));
      }
    });

    test('more bits make it narrower', () {
      double width(int bits) {
        final c = sensitive(bits);
        final s = c.sensitivity(points: 256)!;
        // Measured in the passband, where dB and linear both behave.
        var worst = 0.0;
        for (var i = 0; i < s.f.length; i++) {
          if (s.f[i] > 0.15) break;
          final w = s.hi[i] - s.lo[i];
          if (w > worst) worst = w;
        }
        return worst;
      }

      expect(width(18), lessThan(width(12)));
      expect(width(12), lessThan(width(8)));
    });

    test('it is the same every time nothing has changed', () {
      final c = sensitive(12);
      final a = c.sensitivity(points: 128)!;
      expect(identical(c.sensitivity(points: 128), a), isTrue,
          reason: 'cached, so the shading does not shimmer on every rebuild');
      final again = sensitive(12).sensitivity(points: 128)!;
      for (var i = 0; i < a.lo.length; i++) {
        expect(again.lo[i], a.lo[i], reason: 'the draws are seeded');
      }
    });

    test('a fresh design gets a fresh envelope', () {
      final c = sensitive(12);
      final before = c.sensitivity();
      c.update(() => c.wordBits = 16);
      expect(identical(c.sensitivity(), before), isFalse);
    });
  });

  group('an IIR', () {
    test('a comfortable word length stays stable in every draw', () {
      final c = sensitive(20, also: (c) {
        c.mode = Mode.iir;
        c.approximation = 'butterworth';
      });
      expect(c.sensitivity()!.unstable, 0);
    });

    test('a tight one does not, and the report says so', () {
      // An elliptic design puts its poles closest to the circle, and this one
      // -- 90 dB across a transition one twentieth of an octave wide -- puts
      // them at a radius of 0.998. Eight bits cannot describe that accurately
      // enough to keep every draw inside.
      final c = sensitive(8, also: (c) {
        c.mode = Mode.iir;
        c.approximation = 'elliptic';
        c.rs = '90';
        c.ws = ['0.205', '0.45'];
      });
      final spread = c.sensitivity()!;
      expect(spread.unstable, greaterThan(0));
      expect(c.report(), contains('came out unstable'));
      expect(c.report(), contains('too close to the unit circle'));
    });
  });

  group('the report', () {
    test('it names the worst the stopband gets', () {
      final c = sensitive(10);
      final text = c.report();
      expect(text, contains('half an LSB of coefficient error'));
      expect(text, contains('as built'));
      expect(text, contains('at worst'));
    });
  });

  group('the setting', () {
    test('it round trips through the design file', () {
      final a = DesignController()
        ..showSensitivity = true
        ..design();
      final b = DesignController()..fromJson(a.toJson());
      expect(b.showSensitivity, isTrue);
    });
  });
}
