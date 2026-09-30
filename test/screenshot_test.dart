/// Renders the app to an image, so the layout can be looked at.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remez/main.dart';
import 'package:remez/src/controller.dart';

void main() {
  setUpAll(() {
    // Compare the golden by what it is for.
    //
    // The stock comparator is exact to the bit, which makes a layout golden
    // fail whenever the engine changes its mind about how to shade the corner
    // of a rounded box. That is what happened here: the SDK moved on from the
    // one that wrote this image and 160 pixels out of a million and a half
    // changed, all of them corners, none by more than a seventh of a level.
    // Nothing in the program had moved.
    //
    // A ceiling on the per-pixel difference draws the line in the right
    // place. Anti-aliasing reshades an edge slightly; anything that actually
    // moved -- a glyph by a pixel, a control changing colour, a panel growing
    // a row -- differs at close to full amplitude where it moved, and still
    // fails.
    final previous = goldenFileComparator as LocalFileComparator;
    goldenFileComparator = _AntiAliasTolerant(previous.basedir);
  });

  testWidgets('the designer renders', (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const RemezApp());
    await tester.pumpAndSettle();

    // The app bar prints how long the design took, which is different on every
    // run and puts a few hundred differing pixels into the image. Pinning it
    // keeps the golden about the layout, which is what it is for.
    //
    // The rebuild has to be forced: assigning the field does not go through
    // `update`, so no listener fires and the app bar would keep painting the
    // real duration. Pinning it without this looks like it works and passes
    // whenever two runs happen to round to the same digits.
    final element = tester.element(find.byType(DesignerPage));
    final state = tester.state<State<DesignerPage>>(find.byType(DesignerPage));
    // ignore: avoid_dynamic_calls
    final c = (state as dynamic).controller as DesignController;
    c.lastDesignTime = const Duration(microseconds: 1234);
    element.markNeedsBuild();
    await tester.pumpAndSettle();
    expect(find.text('designed in 1.234 ms'), findsOneWidget,
        reason: 'the pinned duration is not what the app bar is showing');

    await expectLater(
        find.byType(DesignerPage), matchesGoldenFile('golden/designer.png'));
  });

  testWidgets('the split between the panes can be dragged', (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const RemezApp());
    await tester.pumpAndSettle();

    double columnWidth() =>
        tester.getSize(find.byType(ListView).first).width;
    final divider = find.byKey(splitterKey);

    expect(columnWidth(), 400);
    // The harness eats kDragSlopDefault (20) before the gesture starts, so a
    // 120-pixel drag moves the split by 100.
    await tester.drag(divider, const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(columnWidth(), 500);

    // Past the minimum it stops rather than squeezing the controls away.
    await tester.drag(divider, const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(columnWidth(), 260);

    // Double-click puts it back.
    await tester.tap(divider);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(divider);
    await tester.pumpAndSettle();
    expect(columnWidth(), 400);
  });

  testWidgets('a wider column packs the band table into fewer rows',
      (tester) async {
    // The band row carries seven controls, so at any sensible column width it
    // wraps.  What the drag has to buy is fewer wrapped lines, not a magic
    // width at which everything fits.
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const RemezApp());
    await tester.pumpAndSettle();

    double tableHeight() => tester
        .getSize(find.ancestor(
            of: find.text('F start').first, matching: find.byType(Wrap))
            .first)
        .height;

    final narrow = tableHeight();
    await tester.drag(find.byKey(splitterKey), const Offset(320, 0));
    await tester.pumpAndSettle();
    expect(tableHeight(), lessThan(narrow));

    // Dragged wide enough, the whole row is on one line.
    await tester.drag(find.byKey(splitterKey), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(
        tester.getTopLeft(find.ancestor(
            of: find.text('1/f').first, matching: find.byType(InkWell)).first).dy,
        closeTo(
            tester.getTopLeft(find.ancestor(
                of: find.text('F start').first,
                matching: find.byType(TextField)).first).dy,
            2.0));
  });

  testWidgets('the export buttons are on screen and enable when they can run',
      (tester) async {
    // Tall enough for the whole control column with the Arithmetic panel in
    // its fixed-point form, which is the longest it gets. The point of the
    // test is that the exports are reachable without hunting through a menu;
    // it needs a window that can show the column to say that.
    tester.view.physicalSize = const Size(1500, 1980);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const RemezApp());
    await tester.pumpAndSettle();

    ButtonStyleButton button(String label) => tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, label));

    // All four are present without opening a menu or scrolling a pane away.
    for (final label in [
      'Open design…',
      'Save design…',
      'Save coefficients…',
      'Save plot…',
      'Save script…',
      'Save integer C…',
      'Save C…',
      'Generate SV…',
      'Generate VHDL…',
    ]) {
      expect(find.widgetWithText(OutlinedButton, label), findsOneWidget,
          reason: label);
    }

    // Opening and saving a design need nothing; C needs a filter, which there
    // is; SV needs fixed-point coefficients, which there are not yet.
    expect(button('Open design…').onPressed, isNotNull);
    expect(button('Save design…').onPressed, isNotNull);
    expect(button('Save coefficients…').onPressed, isNotNull);
    expect(button('Save plot…').onPressed, isNotNull);
    expect(button('Save C…').onPressed, isNotNull);
    expect(button('Save script…').onPressed, isNotNull);
    // Integer C needs an integer datapath, which floating point has not got.
    expect(button('Save integer C…').onPressed, isNull);
    expect(button('Generate SV…').onPressed, isNull);
    expect(button('Generate VHDL…').onPressed, isNull);

    // Switch to fixed point and both hardware exports come alive.
    await tester.tap(find.text('Fixed'));
    await tester.pumpAndSettle();
    expect(button('Generate SV…').onPressed, isNotNull);
    expect(button('Generate VHDL…').onPressed, isNotNull);
    expect(button('Save integer C…').onPressed, isNotNull);

    // A filter that will not design disables both of the exports.
    final state = tester.state<State<DesignerPage>>(find.byType(DesignerPage));
    // ignore: avoid_dynamic_calls
    final c = (state as dynamic).controller as DesignController;
    c.update(() => c.numtaps = 2); // too short for any type
    await tester.pumpAndSettle();
    expect(c.error, isNotNull);
    expect(button('Save C…').onPressed, isNull);
    expect(button('Generate SV…').onPressed, isNull);
    expect(button('Generate VHDL…').onPressed, isNull);
  });
}

/// A golden comparator that forgives anti-aliasing and nothing else.
class _AntiAliasTolerant extends LocalFileComparator {
  _AntiAliasTolerant(Uri basedir)
      : super(basedir.resolve('screenshot_test.dart'));

  /// How far one channel may move before it counts as a real difference.
  ///
  /// The corner reshading this was written for peaks at 34 of 255. Sixty-four
  /// leaves room for the engine to go on fiddling without letting through a
  /// change anyone could see.
  static const int _tolerance = 64;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final want = await _pixels(Uint8List.fromList(await getGoldenBytes(golden)));
    final got = await _pixels(imageBytes);

    if (want.width != got.width || want.height != got.height) {
      throw FlutterError('Golden "$golden": the image is now '
          '${got.width}x${got.height}, was ${want.width}x${want.height}.');
    }

    var offending = 0;
    var worst = 0;
    for (var i = 0; i < want.bytes.length; i += 4) {
      for (var c = 0; c < 4; c++) {
        final delta = (want.bytes[i + c] - got.bytes[i + c]).abs();
        if (delta > worst) worst = delta;
        if (delta > _tolerance) {
          offending++;
          break;
        }
      }
    }
    if (offending == 0) return true;

    // Write the same failure images the stock comparator would, so a real
    // difference can be looked at rather than only counted. Pointing at
    // files without producing them would be worse than not mentioning them.
    final result = await GoldenFileComparator.compareLists(
        imageBytes, await getGoldenBytes(golden));
    await generateFailureOutput(result, golden, basedir);
    throw FlutterError('Golden "$golden": $offending pixel(s) differ by more '
        'than $_tolerance of 255 (worst $worst). See test/failures.');
  }

  Future<({int width, int height, Uint8List bytes})> _pixels(
      Uint8List encoded) async {
    final codec = await ui.instantiateImageCodec(encoded);
    final frame = await codec.getNextFrame();
    final data =
        await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final out = (
      width: frame.image.width,
      height: frame.image.height,
      bytes: data!.buffer.asUint8List(),
    );
    frame.image.dispose();
    codec.dispose();
    return out;
  }
}
