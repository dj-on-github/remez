/// The macOS menu bar.
///
/// A Mac application is expected to put its commands in the bar at the top of
/// the screen as well as wherever else they live, and a window that has none
/// looks like a port of something else -- which this is, but that is not a
/// reason to leave it looking like one. The buttons in the File panel stay
/// where they are: the menu is a second way to the same handlers, not a
/// replacement for them.
///
/// [PlatformMenuBar] draws nothing anywhere else, so this costs the other
/// platforms a widget that passes its child through.
///
/// The menus are built by a plain function rather than inside the page's
/// `build`, so that what is in them -- the order, the labels, which items are
/// live and what each one does -- can be read and tested without a menu bar,
/// a window, or a Mac.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'labels.dart';

/// What the menu bar needs to be able to do.
///
/// Every one of these is the same callback the corresponding button in the
/// window already uses, so the two cannot drift apart.
class MenuActions {
  const MenuActions({
    required this.settings,
    required this.open,
    required this.save,
    required this.exportC,
    required this.exportVerilog,
    required this.exportVhdl,
    required this.undo,
    required this.cut,
    required this.copy,
    required this.paste,
  });

  final VoidCallback settings;
  final VoidCallback open;

  /// Never null. A design file records the specification and not the result,
  /// so it can be saved while the filter will not build -- which is exactly
  /// when you want to keep it and come back to it.
  final VoidCallback save;

  /// Null when there is no filter to write out, which disables the item
  /// rather than letting it fail when it is chosen.
  final VoidCallback? exportC;

  /// Null without fixed-point coefficients, for the same reason the two
  /// buttons in the File panel are greyed out then.
  final VoidCallback? exportVerilog;
  final VoidCallback? exportVhdl;

  /// Null when there is nothing to undo.
  final VoidCallback? undo;

  final VoidCallback cut;
  final VoidCallback copy;
  final VoidCallback paste;
}

/// Whether this platform has a menu bar worth building.
///
/// Only macOS does. Asking anywhere else is not merely pointless: a
/// [PlatformProvidedMenuItem] throws when the platform has no such item, so
/// the About and Quit entries below cannot even be constructed on Linux, on
/// Windows, or in a widget test -- which reports itself as Android.
bool get hasPlatformMenuBar => defaultTargetPlatform == TargetPlatform.macOS;

/// The provided items this platform actually has, in the order given.
///
/// Empty off macOS, which is what keeps [designerMenus] safe to call anywhere
/// -- a test reads the menus without a Mac to read them on.
List<PlatformMenuItem> _provided(List<PlatformProvidedMenuItemType> types) => [
      for (final type in types)
        if (PlatformProvidedMenuItem.hasMenu(type))
          PlatformProvidedMenuItem(type: type),
    ];

/// The three menus, in the order they appear.
///
/// The first is the application menu. Its label is the one macOS ignores --
/// the bar shows the bundle name there whatever is passed -- but it is given
/// the program's name anyway so that reading this says what it will look like.
List<PlatformMenuItem> designerMenus(MenuActions on) => <PlatformMenuItem>[
      PlatformMenu(
        label: programName,
        menus: <PlatformMenuItem>[
          ..._provided(const [PlatformProvidedMenuItemType.about]),
          PlatformMenuItemGroup(members: <PlatformMenuItem>[
            PlatformMenuItem(
              label: 'Settings…',
              shortcut: const SingleActivator(LogicalKeyboardKey.comma,
                  meta: true),
              onSelected: on.settings,
            ),
          ]),
          PlatformMenuItemGroup(
            members: _provided(const [
              PlatformProvidedMenuItemType.hide,
              // Not "Show <name>", which was asked for and cannot exist: a
              // hidden application has no menu bar to be chosen from. This is
              // the item macOS provides for getting hidden applications back,
              // and the system labels it "Show All".
              PlatformProvidedMenuItemType.showAllApplications,
            ]),
          ),
          PlatformMenuItemGroup(
            members: _provided(const [PlatformProvidedMenuItemType.quit]),
          ),
        ],
      ),
      PlatformMenu(
        label: 'File',
        menus: <PlatformMenuItem>[
          PlatformMenuItemGroup(members: <PlatformMenuItem>[
            PlatformMenuItem(
              label: 'Open…',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyO, meta: true),
              onSelected: on.open,
            ),
            PlatformMenuItem(
              label: 'Save…',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyS, meta: true),
              onSelected: on.save,
            ),
          ]),
          PlatformMenuItemGroup(members: <PlatformMenuItem>[
            PlatformMenuItem(label: 'Export C…', onSelected: on.exportC),
            PlatformMenuItem(
                label: 'Export SystemVerilog…', onSelected: on.exportVerilog),
            PlatformMenuItem(label: 'Export VHDL…', onSelected: on.exportVhdl),
          ]),
        ],
      ),
      PlatformMenu(
        label: 'Edit',
        menus: <PlatformMenuItem>[
          PlatformMenuItemGroup(members: <PlatformMenuItem>[
            PlatformMenuItem(
              label: 'Undo',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyZ, meta: true),
              onSelected: on.undo,
            ),
          ]),
          PlatformMenuItemGroup(members: <PlatformMenuItem>[
            PlatformMenuItem(
              label: 'Cut',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyX, meta: true),
              onSelected: on.cut,
            ),
            PlatformMenuItem(
              label: 'Copy',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyC, meta: true),
              onSelected: on.copy,
            ),
            PlatformMenuItem(
              label: 'Paste',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyV, meta: true),
              onSelected: on.paste,
            ),
          ]),
        ],
      ),
    ];

/// The keys that undo and redo, for platforms where nothing else claims them.
///
/// On macOS the Edit menu owns Command-Z and Shift-Command-Z: a menu key
/// equivalent is taken by the menu before the window ever sees the event, so
/// binding them here as well would at best do nothing and at worst undo twice.
/// Rather than depend on which of those it is, the bindings are simply not
/// made where a menu has them. Everywhere else there is no menu bar, so this
/// is the only thing offering them.
Map<ShortcutActivator, VoidCallback> undoShortcuts(
    VoidCallback undo, VoidCallback redo) {
  if (hasPlatformMenuBar) return const {};
  return {
    const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): undo,
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true): undo,
    const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
        redo,
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
        redo,
  };
}
