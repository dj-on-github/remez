/// The report box, which scrolls independently of the column it sits in.
///
/// Two scroll views one inside the other is where a scrollbar with no
/// controller of its own goes wrong, and it goes wrong only on desktop: on
/// mobile a `ScrollView` adopts the `PrimaryScrollController` and the scrollbar
/// finds a position attached to it, so the same tree that asserts on macOS is
/// quiet under the default test platform. Both are checked here, and the
/// platform is set explicitly so that neither depends on which one the tests
/// happen to run as.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remez/main.dart';
import 'package:remez/src/controller.dart';

/// The report's own scroll position, and a report long enough to have one.
Future<ScrollPosition> reportPosition(WidgetTester tester) async {
  await tester.pumpWidget(const RemezApp());
  await tester.pumpAndSettle();

  final state = tester.state<State<DesignerPage>>(find.byType(DesignerPage));
  // ignore: avoid_dynamic_calls
  final c = (state as dynamic).controller as DesignController;
  // An IIR cascade lists every section, which overflows the box.
  c.update(() {
    c.mode = Mode.iir;
    c.approximation = 'elliptic';
    c.arithmetic = Arithmetic.fixed;
    c.wordBits = 16;
  });
  await tester.pumpAndSettle();

  await tester.scrollUntilVisible(find.text('Result'), 300,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();

  final report = find.byType(SelectableText).last;
  final inner = find
      .ancestor(of: report, matching: find.byType(Scrollable))
      .evaluate()
      .first as StatefulElement;
  return (inner.state as ScrollableState).position;
}

void main() {
  for (final platform in [TargetPlatform.macOS, TargetPlatform.android]) {
    testWidgets('scrolling the report on ${platform.name} does not throw',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      debugDefaultTargetPlatformOverride = platform;
      Object? thrown;
      try {
        final pos = await reportPosition(tester);
        expect(pos.maxScrollExtent, greaterThan(0.0),
            reason: 'the report must have something to scroll');
        // What the scrollbar reacts to is the notification, however the
        // scroll was started; a trackpad pan and a wheel arrive here too.
        pos.jumpTo(40);
        await tester.pump();
        pos.jumpTo(80);
        await tester.pumpAndSettle();
        expect(pos.pixels, 80.0);
        thrown = tester.takeException();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      expect(thrown, isNull,
          reason: 'the scrollbar and the scroll view must share a controller');
    });
  }

  testWidgets('the report carries exactly one scrollbar', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final pos = await reportPosition(tester);
      // Counted by what each scrollbar is attached to rather than by where it
      // sits in the tree: the column's own scrollbar is an ancestor of the
      // report as well, and is not the one under test.
      final mine = [
        for (final e in find.byType(Scrollbar).evaluate())
          if ((e.widget as Scrollbar).controller?.positions.contains(pos) ??
              false)
            e.widget as Scrollbar,
      ];
      // The desktop scroll behaviour would add a second one of its own.
      expect(mine, hasLength(1),
          reason: 'the report should carry exactly one scrollbar');
      // And no scrollbar anywhere may be left without a controller, which is
      // what sends it looking for the PrimaryScrollController.
      for (final e in find.byType(Scrollbar).evaluate()) {
        expect((e.widget as Scrollbar).controller, isNotNull,
            reason: 'a scrollbar with no controller falls back to the '
                'PrimaryScrollController, which nothing here attaches to');
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
