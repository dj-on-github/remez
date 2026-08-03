/// The macOS entitlements the file dialogs need.
///
/// Flutter's macOS template turns the App Sandbox on and grants nothing else.
/// A sandboxed app may not show an open or save panel without
/// `com.apple.security.files.user-selected.read-write`: AppKit does not raise
/// an error, it simply never presents the panel, and the plugin's future never
/// completes. The symptom is a button that appears to do nothing at all, which
/// is a slow thing to diagnose from the Dart side -- nothing throws, nothing
/// logs, and every widget test passes.
///
/// So it is asserted here, on the plist itself, in both configurations.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The keys set to `<true/>` in an entitlements plist.
Set<String> entitlements(String path) {
  final text = File(path).readAsStringSync();
  final keys = <String>{};
  final pattern = RegExp(r'<key>([^<]+)</key>\s*<(true|false)/>');
  for (final m in pattern.allMatches(text)) {
    if (m[2] == 'true') keys.add(m[1]!);
  }
  return keys;
}

void main() {
  const configurations = [
    'macos/Runner/DebugProfile.entitlements',
    'macos/Runner/Release.entitlements',
  ];

  for (final path in configurations) {
    final name = path.split('/').last;

    test('$name lets the file dialogs open', () {
      final granted = entitlements(path);
      expect(granted, contains('com.apple.security.files.user-selected.read-write'),
          reason: 'without this the Open/Save panels never appear, and '
              'nothing reports why');
    });

    test('$name keeps the sandbox on', () {
      // The entitlement above is the narrow one that makes the panels work;
      // it is not a reason to switch the sandbox off, and if the sandbox ever
      // does go, this test should be the place that argues about it.
      expect(entitlements(path), contains('com.apple.security.app-sandbox'));
    });
  }
}
