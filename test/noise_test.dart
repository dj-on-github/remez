/// The measured arithmetic noise, as the controller and the report present it.
///
/// The measurement itself is checked in `fixed_point_test.dart` against
/// `q*sqrt(N/12)` from the theory. What is checked here is that the right
/// datapath is being measured -- the one the export would generate, structure
/// and folding included -- and that the answer moves the way physics says it
/// should when the word length changes.
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:remez/src/controller.dart';

DesignController fixedAt(int bits, {void Function(DesignController)? also}) {
  final c = DesignController()
    ..arithmetic = Arithmetic.fixed
    ..wordBits = bits
    ..measureNoise = true;
  also?.call(c);
  return c..design();
}

void main() {
  group('when there is nothing to measure', () {
    test('floating point has no arithmetic noise of its own', () {
      final c = DesignController()
        ..measureNoise = true
        ..design();
      expect(c.noiseFloor(), isNull);
      expect(c.noiseError, isNull);
    });

    test('the measurement stays off until it is asked for', () {
      final c = DesignController()
        ..arithmetic = Arithmetic.fixed
        ..design();
      expect(c.noiseFloor(), isNull);
      expect(c.report(), isNot(contains('arithmetic noise')));
    });
  });

  group('the measurement', () {
    test('every extra bit of coefficient buys about 6 dB', () {
      final at12 = fixedAt(12).noiseFloor()!;
      final at18 = fixedAt(18).noiseFloor()!;
      final gain = at12.medianDb - at18.medianDb;
      expect(gain, closeTo(6.02 * 6, 4.0),
          reason: 'six more bits should be about 36 dB quieter');
    });

    test('the error is a couple of LSB either way', () {
      // Each of N products is rounded, so the sum of the errors is about
      // sqrt(N/12) LSB. For 41 taps that is 1.8.
      final measured = fixedAt(16).noiseFloor()!;
      expect(measured.rmsLsb, closeTo(math.sqrt(41 / 12), 1.0));
    });

    test('it covers the band from DC to Nyquist', () {
      final measured = fixedAt(16).noiseFloor()!;
      expect(measured.frequency.first, 0.0);
      expect(measured.frequency.last, closeTo(0.5, 1e-9));
      expect(measured.noiseDb.length, measured.frequency.length);
    });

    test('an IIR can be measured too', () {
      final c = fixedAt(16, also: (c) {
        c.mode = Mode.iir;
        c.approximation = 'butterworth';
      });
      final measured = c.noiseFloor();
      expect(c.noiseError, isNull);
      expect(measured, isNotNull);
      expect(measured!.rmsLsb, greaterThan(0.0));
    });

    test('the answer is cached until the next design', () {
      final c = fixedAt(16);
      expect(identical(c.noiseFloor(), c.noiseFloor()), isTrue);
      final before = c.noiseFloor();
      c.update(() => c.wordBits = 12);
      expect(identical(c.noiseFloor(), before), isFalse);
    });

    test('folding changes the datapath, so it changes the noise', () {
      // Folded, one multiply serves a symmetric pair, so there are half as
      // many roundings to accumulate.
      final plain = fixedAt(12).noiseFloor()!;
      final folded = fixedAt(12, also: (c) => c.folded = true).noiseFloor()!;
      expect(folded.rmsLsb, lessThan(plain.rmsLsb),
          reason: 'half the multiplies is half the rounding events');
    });
  });

  group('the report', () {
    test('it states the floor and what the stopband really is', () {
      final c = fixedAt(16);
      final text = c.report();
      expect(text, contains('arithmetic noise'));
      expect(text, contains('error rms'));
      expect(text, contains('noise floor'));
      expect(text, contains('dB designed'));
    });

    test('it names the arithmetic as the limit when it is', () {
      // A deep stopband asked for with too few bits to hold it: the filter
      // meets the spec on paper and the hardware cannot.
      final c = fixedAt(8, also: (c) {
        c.numtaps = 121;
        c.rows = [
          BandRow('0', '0.2', '1', '1', '1', '0.1'),
          BandRow('0.24', '0.5', '0', '0', '1000', '100'),
        ];
      });
      expect(c.noiseFloor(), isNotNull);
      expect(c.report(), contains('the arithmetic is the limit'));
    });

    test('it explains itself when the datapath cannot be built', () {
      // Two bits cannot hold the coefficients, so they saturate and the
      // planner refuses -- the same refusal the export button gives.
      final c = fixedAt(4, also: (c) => c.autoFrac = false);
      c.update(() => c.fracBits = 12);
      expect(c.noiseFloor(), isNull);
      expect(c.noiseError, isNotNull);
      expect(c.report(), contains('arithmetic noise cannot be measured'));
    });
  });

  group('the setting', () {
    test('it round trips through the design file', () {
      final a = DesignController()
        ..measureNoise = true
        ..design();
      expect(DesignController().fromJsonReturning(a.toJson()).measureNoise,
          isTrue);
    });
  });
}

extension on DesignController {
  DesignController fromJsonReturning(Map<String, dynamic> state) {
    fromJson(state);
    return this;
  }
}
