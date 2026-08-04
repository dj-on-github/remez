/// Every field label is fully readable.
///
/// A `TextField`'s floating label is laid out inside the field's width and is
/// ellipsised when it does not fit, so "Passband 1" becomes "Passban…" and the
/// control stops saying what it is. Finding the text does not catch that --
/// `find.text` matches a clipped label perfectly well -- so this compares what
/// each label was *given* against what it would take unconstrained.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remez/main.dart';
import 'package:remez/src/controller.dart';

/// Text that was cut off rather than laid out in full.
///
/// `didExceedMaxLines` is the exact signal: it is set when the paragraph ran
/// past the lines it was allowed and had to be ellipsised. Comparing widths
/// instead would flag every button label that simply wraps onto a second line,
/// which is not the same thing at all -- and would miss the field labels, whose
/// paragraph is laid out full size and then scaled down by the decorator.
List<String> truncatedLabels(WidgetTester tester) {
  final bad = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final render = element.renderObject! as RenderParagraph;
    final text = render.text.toPlainText();
    if (text.trim().isEmpty) continue;
    if (render.didExceedMaxLines) {
      bad.add('$text (cut off in ${render.size.width.toStringAsFixed(1)}px)');
    }
  }
  return bad;
}

Future<DesignController> _open(WidgetTester tester, Size window) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const RemezApp());
  await tester.pumpAndSettle();
  final state = tester.state<State<DesignerPage>>(find.byType(DesignerPage));
  // ignore: avoid_dynamic_calls
  return (state as dynamic).controller as DesignController;
}

void main() {
  testWidgets('the IIR bandpass labels are readable', (tester) async {
    // The reported case: two passband and two stopband edges, so the labels
    // carry a number and are the longest the panel ever shows.
    final c = await _open(tester, const Size(1500, 1400));
    c.update(() => c.mode = Mode.iir);
    c.setResponse('bandpass');
    await tester.pumpAndSettle();

    for (final label in [
      'Passband 1',
      'Passband 2',
      'Stopband 1',
      'Stopband 2',
      'Ripple dB',
      'Atten. dB',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(truncatedLabels(tester), isEmpty);
  });

  testWidgets('and so are they for every other response', (tester) async {
    final c = await _open(tester, const Size(1500, 1400));
    c.update(() => c.mode = Mode.iir);
    for (final response in ['lowpass', 'highpass', 'bandpass', 'bandstop']) {
      c.setResponse(response);
      await tester.pumpAndSettle();
      expect(truncatedLabels(tester), isEmpty, reason: response);
    }
  });

  testWidgets('the FIR band table labels are readable too', (tester) async {
    await _open(tester, const Size(1500, 1400));
    expect(truncatedLabels(tester), isEmpty);
  });

  testWidgets('they stay readable when the split is dragged narrow',
      (tester) async {
    // The column can be dragged down to its minimum; a label that only fits at
    // the default width is still a label that cannot be read.
    await _open(tester, const Size(1500, 1400));
    await tester.drag(find.byKey(splitterKey), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(truncatedLabels(tester), isEmpty);
  });
}
