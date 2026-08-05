/// The shortcut wrapper around the whole window, and the undo it drives.
///
/// Worth a test of its own because the wrapper takes focus: if it took it away
/// from the text fields, every control in the program would stop accepting
/// input and every other test -- which sets fields on the controller directly
/// -- would still pass.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remez/main.dart';
import 'package:remez/src/controller.dart';

void main() {
  testWidgets('typing still works and undo enables', (tester) async {
    tester.view.physicalSize = const Size(1500, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const RemezApp());
    await tester.pumpAndSettle();
    final state = tester.state<State<DesignerPage>>(find.byType(DesignerPage));
    // ignore: avoid_dynamic_calls
    final c = (state as dynamic).controller as DesignController;

    IconButton icon(IconData d) =>
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, d));

    expect(icon(Icons.undo).onPressed, isNull, reason: 'nothing to undo yet');

    // Type into the Taps field and commit it, as a person would.
    final taps = find.widgetWithText(TextField, '41');
    expect(taps, findsOneWidget);
    await tester.tap(taps);
    await tester.pumpAndSettle();
    await tester.enterText(taps, '61');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(c.numtaps, 61, reason: 'the field must still reach the controller');
    expect(icon(Icons.undo).onPressed, isNotNull);
    expect(icon(Icons.redo).onPressed, isNull);

    icon(Icons.undo).onPressed!();
    await tester.pumpAndSettle();
    expect(c.numtaps, 41);
    expect(icon(Icons.redo).onPressed, isNotNull);
  });
}
