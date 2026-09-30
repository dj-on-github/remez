/// How far down the magnitude plot reaches, and the buttons that change it.
///
/// The automatic floor is worked out from what each band was asked to achieve.
/// That is the right guess for a design that holds its bands evenly and the
/// wrong one for a design that does not, which is the case these tests are
/// built around: a least-squares stopband keeps falling away from the
/// transition, so the interesting part is below anything the bands were
/// measured against and runs off the bottom of the frame.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remez/main.dart';
import 'package:remez/src/controller.dart';
import 'package:remez/src/fir_ls.dart';

/// The top of the stopband ripple beyond [from], in dB.
///
/// The peaks and not the nulls. Every FIR dives past 100 dB down between its
/// stopband zeros, so the lowest point a trace reaches says nothing about
/// whether the plot is framed usefully -- what has to be on screen is the
/// level the lobes come back up to, because that is the attenuation being
/// read off.
double lobesBeyond(DesignController c, double from) {
  var top = double.negativeInfinity;
  final m = c.magnitude(points: 4096);
  for (var i = 0; i < m.f.length; i++) {
    if (m.f[i] < from) continue;
    if (m.y[i].isFinite && m.y[i] > top) top = m.y[i];
  }
  return top;
}

void main() {
  group('the case that prompted this', () {
    test('least squares puts its far stopband below the automatic range', () {
      final c = DesignController()
        ..method = FirMethod.leastSquares
        ..design();
      expect(lobesBeyond(c, 0.4), lessThan(c.magnitudeFloor()),
          reason: 'the whole far stopband is off the bottom of the frame, '
              'which is the complaint this was built for');
    });

    test('pressing down brings it back, in a press or two', () {
      final c = DesignController()
        ..method = FirMethod.leastSquares
        ..design();
      final lobes = lobesBeyond(c, 0.4);
      var presses = 0;
      while (c.magnitudeFloor() > lobes && c.canLowerFloor && presses < 20) {
        c.lowerFloor();
        presses++;
      }
      expect(c.magnitudeFloor(), lessThanOrEqualTo(lobes));
      expect(presses, lessThan(4), reason: 'a couple of presses, not a hunt');
    });

    test('the exchange never needed it', () {
      final c = DesignController()..design();
      expect(lobesBeyond(c, 0.4), greaterThan(c.magnitudeFloor()),
          reason: 'an equiripple stopband holds one level and that level is '
              'inside the automatic range, which is why nobody noticed '
              'before');
    });
  });

  group('moving the floor', () {
    test('a press is one step, down and back up again', () {
      final c = DesignController()..design();
      final start = c.magnitudeFloor();
      c.lowerFloor();
      expect(c.magnitudeFloor(),
          closeTo(start - DesignController.floorStepDb, 1e-9));
      c.raiseFloor();
      expect(c.magnitudeFloor(), closeTo(start, 1e-9));
    });

    test('it stops rather than running away', () {
      final c = DesignController()..design();
      for (var i = 0; i < 40; i++) {
        c.lowerFloor();
      }
      expect(c.magnitudeFloor(), DesignController.deepestFloorDb);
      expect(c.canLowerFloor, isFalse);

      for (var i = 0; i < 40; i++) {
        c.raiseFloor();
      }
      expect(c.magnitudeFloor(), DesignController.shallowestFloorDb);
      expect(c.canRaiseFloor, isFalse);
    });

    test('a press always moves the frame, even back off a limit', () {
      // The adjustment is measured from where the floor is and not from what
      // has been stored, so the clamp cannot swallow presses and leave the
      // next one doing nothing.
      final c = DesignController()..design();
      for (var i = 0; i < 40; i++) {
        c.lowerFloor();
      }
      final atLimit = c.magnitudeFloor();
      c.raiseFloor();
      expect(c.magnitudeFloor(),
          closeTo(atLimit + DesignController.floorStepDb, 1e-9),
          reason: 'one press back up should move by exactly one step');
    });

    test('reset puts it back where the design chose', () {
      final c = DesignController()..design();
      final automatic = c.magnitudeFloor();
      c.lowerFloor();
      c.lowerFloor();
      expect(c.floorAdjustDb, isNot(0));
      c.resetFloor();
      expect(c.floorAdjustDb, 0);
      expect(c.magnitudeFloor(), automatic);
    });

    test('it notifies, so the plot redraws', () {
      final c = DesignController()..design();
      var told = 0;
      c.addListener(() => told++);
      c.lowerFloor();
      expect(told, 1);
      c.resetFloor();
      expect(told, 2);
      c.resetFloor();
      expect(told, 2, reason: 'nothing changed, so nothing to say');
    });

    test('it survives a change of design', () {
      final c = DesignController()..design();
      c.lowerFloor();
      final adjusted = c.floorAdjustDb;
      c.update(() => c.numtaps = 81);
      expect(c.floorAdjustDb, adjusted,
          reason: 'it was set on purpose; a redesign is not a reason to '
              'throw the view away');
    });

    test('it is saved with the design', () {
      final a = DesignController()..design();
      a.lowerFloor();
      final b = DesignController()..fromJson(a.toJson());
      expect(b.floorAdjustDb, a.floorAdjustDb);
      expect(b.magnitudeFloor(), a.magnitudeFloor());
    });

    test('an IIR moves the same way', () {
      final c = DesignController()
        ..mode = Mode.iir
        ..design();
      final start = c.magnitudeFloor();
      c.lowerFloor();
      expect(c.magnitudeFloor(),
          closeTo(start - DesignController.floorStepDb, 1e-9));
    });
  });

  group('the buttons', () {
    testWidgets('they are beside the plot, and they work', (tester) async {
      tester.view.physicalSize = const Size(1500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const RemezApp());
      await tester.pumpAndSettle();
      final state =
          tester.state<State<DesignerPage>>(find.byType(DesignerPage));
      // ignore: avoid_dynamic_calls
      final c = (state as dynamic).controller as DesignController;

      IconButton button(IconData icon) =>
          tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon));

      expect(find.textContaining('floor '), findsOneWidget);
      expect(button(Icons.settings_backup_restore).onPressed, isNull,
          reason: 'nothing to reset yet');

      final start = c.magnitudeFloor();
      await tester.tap(find.widgetWithIcon(IconButton, Icons.expand_more));
      await tester.pumpAndSettle();
      expect(c.magnitudeFloor(),
          closeTo(start - DesignController.floorStepDb, 1e-9));
      expect(find.text('floor ${c.magnitudeFloor().round()} dB'),
          findsOneWidget,
          reason: 'the readout has to follow, or it is worse than nothing');
      expect(button(Icons.settings_backup_restore).onPressed, isNotNull);

      await tester.tap(
          find.widgetWithIcon(IconButton, Icons.settings_backup_restore));
      await tester.pumpAndSettle();
      expect(c.magnitudeFloor(), start);
    });

    testWidgets('a linear axis has no floor to move', (tester) async {
      tester.view.physicalSize = const Size(1500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const RemezApp());
      await tester.pumpAndSettle();
      final state =
          tester.state<State<DesignerPage>>(find.byType(DesignerPage));
      // ignore: avoid_dynamic_calls
      final c = (state as dynamic).controller as DesignController;

      expect(find.widgetWithIcon(IconButton, Icons.expand_more),
          findsOneWidget);
      c.update(() => c.logScale = false);
      await tester.pumpAndSettle();
      expect(find.widgetWithIcon(IconButton, Icons.expand_more), findsNothing,
          reason: 'a linear plot is fitted to its trace');
      expect(find.textContaining('floor '), findsNothing);
    });

    testWidgets('they share the title line instead of taking one',
        (tester) async {
      tester.view.physicalSize = const Size(1500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const RemezApp());
      await tester.pumpAndSettle();

      // A default IconButton is forty-eight pixels tall, which would push the
      // title row -- and every plot under it -- down the pane.
      for (final icon in [
        Icons.expand_more,
        Icons.expand_less,
        Icons.settings_backup_restore,
      ]) {
        final size = tester.getSize(find.widgetWithIcon(IconButton, icon));
        expect(size.height, lessThanOrEqualTo(24.0), reason: '$icon');
        expect(size.height, greaterThanOrEqualTo(math.min(16.0, 24.0)),
            reason: '$icon still has to be clickable');
      }
    });
  });
}
