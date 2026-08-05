/// Undo, redo, and pinning a design to compare against.
///
/// All three are built on the same snapshots the design file uses, so the
/// property worth testing is that they really are: anything that survives a
/// save should survive an undo, without the history having to be told about it
/// when a new control is added.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:remez/src/controller.dart';
import 'package:remez/src/fir_ls.dart';

void main() {
  group('undo', () {
    test('nothing to undo at the start', () {
      final c = DesignController()..design();
      expect(c.canUndo, isFalse);
      expect(c.canRedo, isFalse);
      c.undo(); // must not throw or corrupt anything
      expect(c.numtaps, 41);
    });

    test('it puts back what a change replaced', () {
      final c = DesignController()..design();
      c.update(() => c.numtaps = 61);
      expect(c.numtaps, 61);
      expect(c.canUndo, isTrue);

      c.undo();
      expect(c.numtaps, 41);
      expect(c.firEffective!.h, hasLength(41),
          reason: 'undo has to redesign, not just move a number back');
    });

    test('it goes back as many steps as were taken', () {
      final c = DesignController()..design();
      for (final n in [51, 61, 71]) {
        c.update(() => c.numtaps = n);
      }
      expect(c.numtaps, 71);
      c.undo();
      expect(c.numtaps, 61);
      c.undo();
      expect(c.numtaps, 51);
      c.undo();
      expect(c.numtaps, 41);
      expect(c.canUndo, isFalse);
    });

    test('a change that changed nothing is not a step', () {
      final c = DesignController()..design();
      c.update(() => c.numtaps = 61);
      // Committing the same field again, as a text field does on every blur.
      c.update(() => c.numtaps = 61);
      c.update(() => c.numtaps = 61);
      c.undo();
      expect(c.numtaps, 41, reason: 'one undo, because there was one change');
    });

    test('it reaches everything the file format reaches', () {
      final c = DesignController()..design();
      c.update(() {
        c.mode = Mode.iir;
        c.approximation = 'elliptic';
        c.arithmetic = Arithmetic.fixed;
        c.wordBits = 10;
        c.showPhase = true;
        c.method = FirMethod.window;
        c.halfBand = true;
        c.rateFactor = 3;
      });
      c.undo();
      expect(c.mode, Mode.fir);
      expect(c.approximation, 'butterworth');
      expect(c.arithmetic, Arithmetic.floating);
      expect(c.wordBits, 16);
      expect(c.showPhase, isFalse);
      expect(c.method, FirMethod.remez);
      expect(c.halfBand, isFalse);
      expect(c.rateFactor, 1);
    });

    test('the history does not grow without bound', () {
      final c = DesignController()..design();
      for (var i = 0; i < 250; i++) {
        c.update(() => c.numtaps = 21 + 2 * i);
      }
      var steps = 0;
      while (c.canUndo && steps < 500) {
        c.undo();
        steps++;
      }
      expect(steps, lessThanOrEqualTo(100));
    });
  });

  group('redo', () {
    test('it puts back what undo took away', () {
      final c = DesignController()..design();
      c.update(() => c.numtaps = 61);
      c.undo();
      expect(c.canRedo, isTrue);
      c.redo();
      expect(c.numtaps, 61);
      expect(c.canRedo, isFalse);
    });

    test('a new change after an undo abandons the redo', () {
      final c = DesignController()..design();
      c.update(() => c.numtaps = 61);
      c.undo();
      expect(c.canRedo, isTrue);
      c.update(() => c.numtaps = 31);
      expect(c.canRedo, isFalse,
          reason: 'there is no branch to redo onto any more');
      c.undo();
      expect(c.numtaps, 41);
    });

    test('undoing a redo is not itself recorded twice', () {
      final c = DesignController()..design();
      c.update(() => c.numtaps = 61);
      c.undo();
      c.redo();
      c.undo();
      expect(c.numtaps, 41);
      expect(c.canUndo, isFalse);
    });
  });

  group('pinning', () {
    test('nothing is pinned to begin with', () {
      final c = DesignController()..design();
      expect(c.hasPinned, isFalse);
      expect(c.pinnedMagnitude(), isNull);
      expect(c.pinnedLabel, isNull);
    });

    test('a pinned design stays put while the live one changes', () {
      final c = DesignController()..design();
      c.pin();
      final was = c.pinnedMagnitude()!;

      c.update(() => c.numtaps = 101);
      final still = c.pinnedMagnitude()!;
      for (var i = 0; i < was.y.length; i++) {
        expect(still.y[i], was.y[i], reason: 'the pin should not move');
      }
      // And it really is a different filter now.
      final live = c.magnitude();
      var different = 0;
      for (var i = 0; i < live.y.length; i++) {
        if ((live.y[i] - still.y[i]).abs() > 1.0) different++;
      }
      expect(different, greaterThan(50));
    });

    test('the label says what was pinned', () {
      final c = DesignController()..design();
      c.pin();
      expect(c.pinnedLabel, contains('N=41'));
      expect(c.pinnedLabel, contains('Remez'));

      final iir = DesignController()
        ..mode = Mode.iir
        ..approximation = 'elliptic'
        ..design();
      iir.pin();
      expect(iir.pinnedLabel, contains('Elliptic'));
      expect(iir.pinnedLabel, contains('order'));
    });

    test('it follows the axis it is drawn on', () {
      final c = DesignController()..design();
      c.pin();
      final inDb = c.pinnedMagnitude()!;
      c.update(() => c.logScale = false);
      final linear = c.pinnedMagnitude()!;
      // Unity give or take the passband ripple, rather than the 0 dB the
      // same point reads as on a log axis.
      expect(linear.y.first, closeTo(1.0, 0.05),
          reason: 'unity gain, not 0 dB');
      expect(inDb.y.first, closeTo(0.0, 0.5));
    });

    test('unpinning takes it off', () {
      final c = DesignController()..design();
      c.pin();
      expect(c.hasPinned, isTrue);
      c.unpin();
      expect(c.hasPinned, isFalse);
      expect(c.pinnedMagnitude(), isNull);
    });

    test('an IIR can be pinned and an FIR compared against it', () {
      final c = DesignController()
        ..mode = Mode.iir
        ..design();
      c.pin();
      c.update(() => c.mode = Mode.fir);
      expect(c.pinnedMagnitude(), isNotNull);
      expect(c.magnitude(), isNotNull);
    });

    test('pinning is not itself an undo step', () {
      final c = DesignController()..design();
      c.pin();
      expect(c.canUndo, isFalse,
          reason: 'pinning changes what is drawn, not what was designed');
    });
  });
}
