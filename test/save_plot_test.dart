/// Saving the plot: that the pane really can be captured, at the right size,
/// and that it captures whichever view is showing.
///
/// The file dialog cannot be driven from a test, so this exercises the part
/// either side of it -- finding the boundary and encoding the image -- with the
/// same calls the button makes.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remez/main.dart';
import 'package:remez/src/controller.dart';

/// Capture the pane the way `_savePlot` does.
///
/// Inside `runAsync`: `toImage` and `toByteData` wait on the engine, and the
/// fake clock a widget test runs on never lets those futures complete -- the
/// test hangs rather than failing, which is a slow way to find out.
Future<T> real<T>(WidgetTester tester, Future<T> Function() body) async {
  final value = await tester.runAsync(body);
  return value as T;
}

Future<ui.Image> _capture(WidgetTester tester, {double scale = 2.0}) =>
    real(tester, () {
      final boundary =
          paneKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return boundary.toImage(pixelRatio: scale);
    });

Future<DesignController> _open(WidgetTester tester,
    {Size window = const Size(1200, 900)}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const RemezApp());
  await tester.pumpAndSettle();
  final state = tester.state<State<DesignerPage>>(find.byType(DesignerPage));
  // ignore: avoid_dynamic_calls
  return (state as dynamic).controller as DesignController;
}

/// The distinct colours in an image, as packed ARGB.
Future<Set<int>> _colours(WidgetTester tester, ui.Image image) async {
  final data = await real(tester, () => image.toByteData());
  final bytes = data!.buffer.asUint32List();
  return {for (final v in bytes) v};
}

/// The scroll view the plots sit in; the control column has one of its own.
final Finder _paneViewport = find.ancestor(
    of: find.byKey(paneKey), matching: find.byType(SingleChildScrollView));

void main() {
  testWidgets('the image is the plots, not the window they sit in',
      (tester) async {
    // A tall window leaves space below the last plot. The saved file should be
    // the plots and nothing else, so the capture is bounded by the content.
    await _open(tester, window: const Size(1200, 2000));
    final tall = tester.getSize(find.byKey(paneKey));
    final viewport = tester.getSize(_paneViewport);
    expect(tall.height, lessThan(viewport.height),
        reason: 'the content should be shorter than the viewport here');

    final image = await _capture(tester, scale: 1.0);
    addTearDown(image.dispose);
    expect(image.height, tall.height.round());

    // And the blank that was excluded is not a rounding error: this window is
    // half as tall again as the plots need, and none of that reaches the file.
    expect(viewport.height - image.height, greaterThan(400),
        reason: 'the window is ${viewport.height} tall and the image '
            '${image.height}; the dead space is not being trimmed');
  });

  testWidgets('a window too short to show them all still saves them all',
      (tester) async {
    // The other half of the same decision: the capture is the content, so a
    // plot scrolled out of view is still in the file.
    await _open(tester, window: const Size(1200, 400));
    final content = tester.getSize(find.byKey(paneKey));
    final viewport = tester.getSize(_paneViewport);
    expect(content.height, greaterThan(viewport.height));

    final image = await _capture(tester, scale: 1.0);
    addTearDown(image.dispose);
    expect(image.height, content.height.round());
  });

  testWidgets('the passband ripple plot is one of them', (tester) async {
    await _open(tester);
    expect(find.text('ripple against target, for bands with a non-zero target'),
        findsOneWidget);
    // And it says so rather than drawing an empty frame when there is nothing
    // to compare against.
    expect(find.text('W(f)·[D(f) − A(f)]   —   δ = 2.8766e-2'), findsOneWidget);
  });

  testWidgets('the pane captures to an image, oversampled', (tester) async {
    await _open(tester);
    final size = tester.getSize(find.byKey(paneKey));

    final image = await _capture(tester);
    addTearDown(image.dispose);
    // Twice the logical size in each direction, which is what makes a saved
    // plot sharp in a document rather than a screenshot of one.
    expect(image.width, (size.width * 2).round());
    expect(image.height, (size.height * 2).round());

    final png = await real(
        tester, () => image.toByteData(format: ui.ImageByteFormat.png));
    expect(png, isNotNull);
    final bytes = png!.buffer.asUint8List();
    expect(bytes.length, greaterThan(1000));
    // A real PNG, by its signature.
    expect(bytes.sublist(0, 8),
        Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
  });

  testWidgets('it captures whichever view is showing', (tester) async {
    final c = await _open(tester);

    final plot = await _capture(tester, scale: 1.0);
    addTearDown(plot.dispose);
    final plotColours = await _colours(tester, plot);

    c.update(() => c.view = Pane.design);
    await tester.pumpAndSettle();
    final design = await _capture(tester, scale: 1.0);
    addTearDown(design.dispose);
    final designColours = await _colours(tester, design);

    // Two different pictures, not the same one twice.
    expect(plotColours, isNot(designColours));
    // And both have something in them beyond the background.
    expect(plotColours.length, greaterThan(4));
    expect(designColours.length, greaterThan(4));
  });

  testWidgets('the image is opaque, background and all', (tester) async {
    // The pane paints no background of its own, so without the ColoredBox
    // inside the boundary the gaps between the traces come out transparent.
    await _open(tester);
    final image = await _capture(tester, scale: 1.0);
    addTearDown(image.dispose);
    final data = await real(tester, () => image.toByteData());
    final bytes = data!.buffer.asUint8List();
    var transparent = 0;
    for (var i = 3; i < bytes.length; i += 4) {
      if (bytes[i] != 255) transparent++;
    }
    expect(transparent, 0, reason: '$transparent pixels are not opaque');
  });

  testWidgets('a dark plot really is dark', (tester) async {
    final c = await _open(tester);
    c.update(() => c.appearance = Appearance.dark);
    await tester.pumpAndSettle();

    final image = await _capture(tester, scale: 1.0);
    addTearDown(image.dispose);
    final data = await real(tester, () => image.toByteData());
    final bytes = data!.buffer.asUint8List();
    // The corner is background, wherever the traces are.
    final r = bytes[0], g = bytes[1], b = bytes[2];
    expect(r + g + b, lessThan(200), reason: 'corner was ($r, $g, $b)');
  });

  testWidgets('the button is there and needs a filter', (tester) async {
    final c = await _open(tester);
    ButtonStyleButton button() => tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Save plot…'));
    expect(button().onPressed, isNotNull);

    c.update(() => c.numtaps = 2); // will not design
    await tester.pumpAndSettle();
    expect(c.error, isNotNull);
    expect(button().onPressed, isNull);
  });
}
