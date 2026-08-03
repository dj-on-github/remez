/// The design view: the elision rule, and that it draws whatever it is given.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remez/src/controller.dart';
import 'package:remez/src/design_view.dart';

void main() {
  group('which taps get a column', () {
    test('a short filter is drawn whole', () {
      for (final n in [3, 7, maxDrawnTaps]) {
        final (cols, omitted) = firColumns(n);
        expect(omitted, isNull, reason: '$n');
        expect(cols, [for (var i = 0; i < n; i++) i], reason: '$n');
      }
    });

    test('a long one keeps both ends and says what it dropped', () {
      final (cols, omitted) = firColumns(41);
      // Six taps each side of a single break.
      expect(cols.length, maxDrawnTaps);
      expect(cols.where((c) => c == null).length, 1);
      expect(cols.take(6), [0, 1, 2, 3, 4, 5]);
      expect(cols.skip(7), [35, 36, 37, 38, 39, 40]);
      // And the caption names exactly the taps that are not on screen.
      expect(omitted, (6, 34));
      final drawn = cols.whereType<int>().toSet();
      for (var i = omitted!.$1; i <= omitted.$2; i++) {
        expect(drawn.contains(i), isFalse, reason: 'tap $i');
      }
      expect(drawn.length + (omitted.$2 - omitted.$1 + 1), 41);
    });

    test('one more than fits is the first to be broken', () {
      expect(firColumns(maxDrawnTaps).$2, isNull);
      expect(firColumns(maxDrawnTaps + 1).$2, isNotNull);
    });
  });

  group('it draws', () {
    Future<void> draws(WidgetTester tester, DesignController c) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 600,
            child: DesignView(fir: c.firEffective, iir: c.iirEffective),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    testWidgets('every FIR preset', (tester) async {
      final c = DesignController();
      for (final p in DesignController.presets) {
        c.loadPreset(p);
        await draws(tester, c);
      }
    });

    testWidgets('every IIR model, including the odd orders', (tester) async {
      final c = DesignController();
      c.update(() => c.mode = Mode.iir);
      for (final a in ['butterworth', 'chebyshev1', 'chebyshev2', 'elliptic']) {
        for (final r in ['lowpass', 'highpass', 'bandpass', 'bandstop']) {
          c.update(() => c.approximation = a);
          c.setResponse(r);
          await draws(tester, c);
        }
      }
    });

    testWidgets('a first-order section, whose padding is drawn grey',
        (tester) async {
      final c = DesignController();
      c.update(() {
        c.mode = Mode.iir;
        c.approximation = 'butterworth';
        c.autoOrder = false;
        c.order = 1;
      });
      expect(c.iirEffective!.sos, hasLength(1));
      await draws(tester, c);
    });

    testWidgets('the rounded coefficients when the arithmetic is fixed',
        (tester) async {
      final c = DesignController();
      c.update(() {
        c.arithmetic = Arithmetic.fixed;
        c.wordBits = 8;
      });
      await draws(tester, c);
    });
  });
}
