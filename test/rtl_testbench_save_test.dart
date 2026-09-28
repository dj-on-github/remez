/// Saving the RTL and its testbench together.
///
/// The RTL export writes a pair of files, so it asks for a directory rather
/// than a file name. That is not a preference: a save panel on a sandboxed
/// desktop grants exactly the one file named in it, so the testbench -- whose
/// path was derived from the RTL's rather than chosen -- could not be written
/// at all, while the RTL beside it could. Choosing the folder grants both.
library;

import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remez/main.dart';
import 'package:remez/src/controller.dart';

/// A folder chooser that answers with a prepared path and counts the asking.
class FakeSelector extends FileSelectorPlatform {
  FakeSelector(this.answers);

  /// One path per call, in order; null answers as a cancelled dialog.
  final List<String?> answers;
  int asked = 0;

  @override
  Future<String?> getDirectoryPath({
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    asked++;
    return answers.removeAt(0);
  }

  @override
  Future<String?> getSavePath({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? suggestedName,
    String? confirmButtonText,
  }) async =>
      throw UnimplementedError('the RTL export asks for a folder');
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('remez_rtl'));
  tearDown(() => dir.deleteSync(recursive: true));

  /// Bring up the app in fixed point, where the RTL buttons are live.
  Future<DesignController> pumpFixed(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1500, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const RemezApp());
    await tester.pumpAndSettle();
    final state = tester.state<State<DesignerPage>>(find.byType(DesignerPage));
    // ignore: avoid_dynamic_calls
    final c = (state as dynamic).controller as DesignController;
    c.update(() {
      c.arithmetic = Arithmetic.fixed;
      c.moduleName = 'lp';
    });
    await tester.pumpAndSettle();
    return c;
  }

  /// Tap the button and let the handler run to the end.
  ///
  /// The writes are real file IO, which only makes progress on the real event
  /// loop, while the code waiting on them only resumes when the test pumps --
  /// so the two have to be alternated until the chain has run through.
  Future<void> tapGenerate(WidgetTester tester, {bool verilog = true}) async {
    await tester.tap(find.widgetWithText(
        OutlinedButton, verilog ? 'Generate SV…' : 'Generate VHDL…'));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('one folder, asked once, and both files land in it',
      (tester) async {
    final selector = FakeSelector([dir.path]);
    FileSelectorPlatform.instance = selector;

    await pumpFixed(tester);
    await tapGenerate(tester);

    expect(selector.asked, 1, reason: 'one dialog for the pair');
    expect(File('${dir.path}/lp.sv').readAsStringSync(), contains('module lp'));
    expect(File('${dir.path}/lp_tb.sv').readAsStringSync(),
        contains('lp_tb'),
        reason: 'the testbench is the file the sandbox used to refuse');
    expect(find.textContaining('lp.sv and lp_tb.sv'), findsOneWidget);
  });

  testWidgets('the files are named after the module, not the folder',
      (tester) async {
    FileSelectorPlatform.instance = FakeSelector([dir.path]);
    final c = await pumpFixed(tester);
    c.update(() => c.moduleName = 'Half Band 43!');
    await tester.pumpAndSettle();
    await tapGenerate(tester);

    // Sanitised the same way the module name inside the file is.
    expect(File('${dir.path}/half_band_43.sv').existsSync(), isTrue);
    expect(File('${dir.path}/half_band_43_tb.sv').existsSync(), isTrue);
    expect(File('${dir.path}/half_band_43.sv').readAsStringSync(),
        contains('module half_band_43'));
  });

  testWidgets('VHDL goes to the same folder with its own suffix',
      (tester) async {
    FileSelectorPlatform.instance = FakeSelector([dir.path]);
    await pumpFixed(tester);
    await tapGenerate(tester, verilog: false);

    expect(File('${dir.path}/lp.vhd').existsSync(), isTrue);
    expect(File('${dir.path}/lp_tb.vhd').existsSync(), isTrue);
  });

  testWidgets('no testbench wanted writes one file and still asks once',
      (tester) async {
    final selector = FakeSelector([dir.path]);
    FileSelectorPlatform.instance = selector;

    final c = await pumpFixed(tester);
    c.update(() => c.wantTestbench = false);
    await tester.pumpAndSettle();
    await tapGenerate(tester);

    expect(File('${dir.path}/lp.sv').existsSync(), isTrue);
    expect(File('${dir.path}/lp_tb.sv').existsSync(), isFalse);
    expect(selector.asked, 1);
  });

  testWidgets('cancelling the folder writes nothing', (tester) async {
    FileSelectorPlatform.instance = FakeSelector([null]);
    await pumpFixed(tester);
    await tapGenerate(tester);
    expect(dir.listSync(), isEmpty);
  });

  group('replacing what is already there', () {
    testWidgets('it asks first, and Cancel leaves the files alone',
        (tester) async {
      File('${dir.path}/lp.sv').writeAsStringSync('mine, not yours');
      FileSelectorPlatform.instance = FakeSelector([dir.path]);

      await pumpFixed(tester);
      await tapGenerate(tester);

      expect(find.text('Replace lp.sv?'), findsOneWidget,
          reason: 'a folder gives no warning of its own, unlike a save panel');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(File('${dir.path}/lp.sv').readAsStringSync(), 'mine, not yours');
      expect(File('${dir.path}/lp_tb.sv').existsSync(), isFalse,
          reason: 'cancelling has to stop the pair, not just the one named');
    });

    testWidgets('Replace goes ahead', (tester) async {
      File('${dir.path}/lp.sv').writeAsStringSync('mine, not yours');
      File('${dir.path}/lp_tb.sv').writeAsStringSync('nor this');
      FileSelectorPlatform.instance = FakeSelector([dir.path]);

      await pumpFixed(tester);
      await tapGenerate(tester);

      expect(find.text('Replace 2 files?'), findsOneWidget);
      await tester.tap(find.text('Replace'));
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(File('${dir.path}/lp.sv').readAsStringSync(),
          contains('module lp'));
      expect(File('${dir.path}/lp_tb.sv').readAsStringSync(), contains('lp_tb'));
    });

    testWidgets('nothing to replace means nothing to ask', (tester) async {
      FileSelectorPlatform.instance = FakeSelector([dir.path]);
      await pumpFixed(tester);
      await tapGenerate(tester);
      expect(find.textContaining('Replace'), findsNothing);
    });
  });

  testWidgets('a design that cannot make hardware says so before asking',
      (tester) async {
    final selector = FakeSelector([dir.path]);
    FileSelectorPlatform.instance = selector;

    final c = await pumpFixed(tester);
    // Folding a biquad cascade is not a thing, and the planner refuses it.
    c.update(() {
      c.mode = Mode.iir;
      c.folded = true;
    });
    await tester.pumpAndSettle();
    await tapGenerate(tester);

    expect(selector.asked, 0,
        reason: 'no point sending anyone to pick a folder for nothing');
    expect(dir.listSync(), isEmpty);
    expect(find.textContaining('fold'), findsWidgets);
  });

  testWidgets('the module name is saved with the design', (tester) async {
    final c = await pumpFixed(tester);
    c.update(() => c.moduleName = 'decim4');
    final reloaded = DesignController()..fromJson(c.toJson());
    expect(reloaded.moduleName, 'decim4');
  });
}
