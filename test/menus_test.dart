/// The macOS menu bar.
///
/// [designerMenus] is a plain function returning a list, which is the whole
/// reason it is one: what is in the menus -- the order, the labels, which
/// items are live and what each one does -- can be read here without a menu
/// bar, a window, or a Mac.
///
/// The items macOS provides for itself (About, Hide, Show All, Quit) cannot be
/// constructed off macOS at all, so the platform is overridden where they are
/// being counted.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remez/main.dart';
import 'package:remez/src/controller.dart';
import 'package:remez/src/labels.dart';
import 'package:remez/src/menus.dart';

/// Records which command the menu ran, so the wiring can be checked.
class Ran {
  final List<String> calls = [];
  VoidCallback note(String what) => () => calls.add(what);
}

MenuActions everything(Ran ran) => MenuActions(
      settings: ran.note('settings'),
      open: ran.note('open'),
      save: ran.note('save'),
      exportC: ran.note('exportC'),
      exportVerilog: ran.note('exportVerilog'),
      exportVhdl: ran.note('exportVhdl'),
      undo: ran.note('undo'),
      cut: ran.note('cut'),
      copy: ran.note('copy'),
      paste: ran.note('paste'),
    );

const MenuActions nothing = MenuActions(
  settings: _nop,
  open: _nop,
  save: _nop,
  exportC: null,
  exportVerilog: null,
  exportVhdl: null,
  undo: null,
  cut: _nop,
  copy: _nop,
  paste: _nop,
);

void _nop() {}

/// The labels of a menu's items, groups flattened, provided items skipped
/// because the system names those itself.
List<String> labelsOf(PlatformMenu menu) {
  final out = <String>[];
  void walk(Iterable<PlatformMenuItem> items) {
    for (final item in items) {
      if (item is PlatformMenuItemGroup) {
        walk(item.members);
      } else if (item is PlatformMenu) {
        out.add(item.label);
      } else if (item is PlatformProvidedMenuItem) {
        out.add('<provided:${item.type.name}>');
      } else {
        out.add(item.label);
      }
    }
  }

  walk(menu.menus);
  return out;
}

PlatformMenu menuNamed(List<PlatformMenuItem> menus, String label) =>
    menus.whereType<PlatformMenu>().firstWhere((m) => m.label == label);

PlatformMenuItem itemNamed(PlatformMenu menu, String label) {
  PlatformMenuItem? found;
  void walk(Iterable<PlatformMenuItem> items) {
    for (final item in items) {
      if (item is PlatformMenuItemGroup) {
        walk(item.members);
      } else if (item is! PlatformProvidedMenuItem && item.label == label) {
        found = item;
      }
    }
  }

  walk(menu.menus);
  return found ?? (throw StateError('no item "$label" in ${menu.label}'));
}

void main() {
  group('where there is a menu bar', () {
    test('only macOS has one', () {
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        expect(hasPlatformMenuBar, platform == TargetPlatform.macOS,
            reason: '$platform');
      }
      debugDefaultTargetPlatformOverride = null;
    });

    test('the menus can still be built off macOS, without the system items',
        () {
      // Not idle: a PlatformProvidedMenuItem throws where the platform has
      // none, so building these at all is the thing being checked.
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final menus = designerMenus(everything(Ran()));
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(labelsOf(menuNamed(menus, programName)), ['Settings…'],
          reason: 'About, Hide, Show All and Quit are all the system\'s');
      expect(labelsOf(menuNamed(menus, 'File')), hasLength(5),
          reason: 'the File menu is ours, so it is unaffected');
    });
  });

  group('on macOS', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.macOS);
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('three menus, named and in order', () {
      final menus = designerMenus(everything(Ran()));
      expect(menus.whereType<PlatformMenu>().map((m) => m.label).toList(),
          [programName, 'File', 'Edit']);
    });

    test('the application menu holds what was asked for', () {
      expect(labelsOf(menuNamed(designerMenus(everything(Ran())), programName)),
          [
            '<provided:about>',
            'Settings…',
            '<provided:hide>',
            '<provided:showAllApplications>',
            '<provided:quit>',
          ]);
    });

    test('the File menu holds what was asked for, in order', () {
      expect(labelsOf(menuNamed(designerMenus(everything(Ran())), 'File')), [
        'Open…',
        'Save…',
        'Export C…',
        'Export SystemVerilog…',
        'Export VHDL…',
      ]);
    });

    test('the Edit menu holds what was asked for, in order', () {
      expect(labelsOf(menuNamed(designerMenus(everything(Ran())), 'Edit')),
          ['Undo', 'Cut', 'Copy', 'Paste']);
    });

    test('the keys are the ones a Mac user will already be pressing', () {
      final menus = designerMenus(everything(Ran()));
      final expected = {
        (programName, 'Settings…'): LogicalKeyboardKey.comma,
        ('File', 'Open…'): LogicalKeyboardKey.keyO,
        ('File', 'Save…'): LogicalKeyboardKey.keyS,
        ('Edit', 'Undo'): LogicalKeyboardKey.keyZ,
        ('Edit', 'Cut'): LogicalKeyboardKey.keyX,
        ('Edit', 'Copy'): LogicalKeyboardKey.keyC,
        ('Edit', 'Paste'): LogicalKeyboardKey.keyV,
      };
      for (final entry in expected.entries) {
        final item = itemNamed(menuNamed(menus, entry.key.$1), entry.key.$2);
        final shortcut = item.shortcut! as SingleActivator;
        expect(shortcut.trigger, entry.value, reason: '${entry.key}');
        expect(shortcut.meta, isTrue,
            reason: '${entry.key} has to be the command key');
      }
      // The exports have none, so they cannot collide with anything.
      for (final label in ['Export C…', 'Export SystemVerilog…']) {
        expect(itemNamed(menuNamed(menus, 'File'), label).shortcut, isNull);
      }
    });

    test('each item runs its own command and no other', () {
      final ran = Ran();
      final menus = designerMenus(everything(ran));
      for (final entry in <(String, String, String)>[
        (programName, 'Settings…', 'settings'),
        ('File', 'Open…', 'open'),
        ('File', 'Save…', 'save'),
        ('File', 'Export C…', 'exportC'),
        ('File', 'Export SystemVerilog…', 'exportVerilog'),
        ('File', 'Export VHDL…', 'exportVhdl'),
        ('Edit', 'Undo', 'undo'),
        ('Edit', 'Cut', 'cut'),
        ('Edit', 'Copy', 'copy'),
        ('Edit', 'Paste', 'paste'),
      ]) {
        ran.calls.clear();
        itemNamed(menuNamed(menus, entry.$1), entry.$2).onSelected!();
        expect(ran.calls, [entry.$3]);
      }
    });

    test('an item with nothing to do is greyed out, not broken', () {
      final menus = designerMenus(nothing);
      for (final entry in <(String, String)>[
        ('File', 'Export C…'),
        ('File', 'Export SystemVerilog…'),
        ('File', 'Export VHDL…'),
        ('Edit', 'Undo'),
      ]) {
        expect(itemNamed(menuNamed(menus, entry.$1), entry.$2).onSelected,
            isNull,
            reason: '${entry.$1} > ${entry.$2}');
      }
      // Open, Save and Settings never depend on there being a filter: the
      // first two are about the design file, which records what was asked
      // for rather than what came back.
      for (final label in ['Open…', 'Save…']) {
        expect(itemNamed(menuNamed(menus, 'File'), label).onSelected,
            isNotNull,
            reason: label);
      }
    });
  });

  group('who owns Command-Z', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('the menu does, on macOS, and the window does not bind it as well',
        () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(undoShortcuts(_nop, _nop), isEmpty,
          reason: 'a menu key equivalent never reaches the window, so a '
              'second binding either does nothing or undoes twice');
      // And the menu really does claim it, so nothing has been dropped.
      expect(
          (itemNamed(menuNamed(designerMenus(nothing), 'Edit'), 'Undo').shortcut
                  as SingleActivator)
              .trigger,
          LogicalKeyboardKey.keyZ);
    });

    test('the window does, everywhere without a menu bar', () {
      for (final platform in [
        TargetPlatform.linux,
        TargetPlatform.windows,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        final bindings = undoShortcuts(_nop, _nop);
        expect(bindings, hasLength(4), reason: '$platform');
        expect(
            bindings.keys.whereType<SingleActivator>().every(
                (a) => a.trigger == LogicalKeyboardKey.keyZ),
            isTrue,
            reason: '$platform');
      }
    });
  });

  group('what the window hands the menu', () {
    testWidgets('every item is live exactly when its button is',
        (tester) async {
      tester.view.physicalSize = const Size(1500, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const RemezApp());
      await tester.pumpAndSettle();
      final state =
          tester.state<State<DesignerPage>>(find.byType(DesignerPage));
      // ignore: avoid_dynamic_calls
      final c = (state as dynamic).controller as DesignController;

      // ignore: avoid_dynamic_calls
      MenuActions actions() => (state as dynamic)
          .menuActions(tester.element(find.byType(DesignerPage)))
          as MenuActions;

      bool buttonLive(String label) =>
          tester
              .widget<OutlinedButton>(
                  find.widgetWithText(OutlinedButton, label))
              .onPressed !=
          null;

      /// The pairs that have to agree: a menu item and the button in the
      /// File panel that runs the same command.
      void expectAgreement(String where) {
        for (final pair in <(String, VoidCallback?)>[
          ('Open design…', actions().open),
          ('Save design…', actions().save),
          ('Save C…', actions().exportC),
          ('Generate SV…', actions().exportVerilog),
          ('Generate VHDL…', actions().exportVhdl),
        ]) {
          expect(pair.$2 != null, buttonLive(pair.$1),
              reason: '$where: "${pair.$1}" and its menu item disagree');
        }
      }

      expectAgreement('floating point');

      c.update(() => c.arithmetic = Arithmetic.fixed);
      await tester.pumpAndSettle();
      expectAgreement('fixed point');
      expect(actions().exportVerilog, isNotNull,
          reason: 'and the RTL really did come alive, so the check has bite');

      // A filter that will not design takes the lot away.
      c.update(() => c.numtaps = 2);
      await tester.pumpAndSettle();
      expect(c.error, isNotNull);
      expectAgreement('a design that will not build');
      expect(actions().exportC, isNull);
    });

    testWidgets('Undo follows the toolbar button', (tester) async {
      tester.view.physicalSize = const Size(1500, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const RemezApp());
      await tester.pumpAndSettle();
      final state =
          tester.state<State<DesignerPage>>(find.byType(DesignerPage));
      // ignore: avoid_dynamic_calls
      final c = (state as dynamic).controller as DesignController;
      // ignore: avoid_dynamic_calls
      MenuActions actions() => (state as dynamic)
          .menuActions(tester.element(find.byType(DesignerPage)))
          as MenuActions;

      bool undoButtonLive() =>
          tester
              .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo))
              .onPressed !=
          null;

      expect(actions().undo != null, undoButtonLive());
      c.update(() => c.numtaps = 61);
      await tester.pumpAndSettle();
      expect(actions().undo != null, undoButtonLive());
      expect(undoButtonLive(), isTrue);

      actions().undo!();
      await tester.pumpAndSettle();
      expect(c.numtaps, 41, reason: 'the menu item really undoes');
    });
  });
}
