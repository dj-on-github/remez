/// Renders the icon into every asset each platform asks for.
///
/// A test rather than a script because drawing needs a Flutter engine, and
/// `flutter test` is the only way to get one without launching the app. Run it
/// with `--update-goldens` to rewrite the files:
///
///     flutter test test/make_icons_test.dart --update-goldens
///
/// Without that flag it only checks the icon still draws as it should, so the
/// generator cannot rot between rebuilds.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:remez/src/icon.dart';

/// A PNG's pixels, as straight RGBA bytes.
Future<Uint8List> decodeRgba(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData();
  frame.image.dispose();
  return data!.buffer.asUint8List();
}

/// Where each platform wants its icon, and at what size.
const Map<String, int> _files = {
  // macOS: one set in the asset catalogue.
  'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png': 16,
  'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png': 32,
  'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png': 64,
  'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png': 128,
  'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png': 256,
  'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png': 512,
  'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png': 1024,

  // Web: the favicon and the manifest's icons.
  'web/favicon.png': 32,
  'web/icons/Icon-192.png': 192,
  'web/icons/Icon-512.png': 512,

  // Android launcher, one per density.
  'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
  'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
  'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
  'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
  'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,

  // iOS, whose names carry the point size and the scale.
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png': 20,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png': 40,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png': 60,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png': 29,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png': 58,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png': 87,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png': 40,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png': 80,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png': 120,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png': 120,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png': 180,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png': 76,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png': 152,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png': 167,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png':
      1024,
};

/// The maskable variants, which the launcher crops to its own shape.
const Map<String, int> _maskable = {
  'web/icons/Icon-maskable-192.png': 192,
  'web/icons/Icon-maskable-512.png': 512,
};

/// The sizes that go inside the Windows `.ico`.
///
/// The ones Windows asks for: an explorer list, a taskbar, a large tile.
const List<int> _icoSizes = [16, 24, 32, 48, 64, 128, 256];

/// Pack PNGs into an ICO container.
///
/// The format is a six-byte header, one sixteen-byte directory entry per image,
/// then the images. Each entry here holds a whole PNG rather than a bare
/// bitmap, which every Windows since Vista reads and which keeps the alpha
/// channel without the AND-mask business the old format needs. A dimension of
/// 256 is written as 0, since the field is one byte.
Uint8List buildIco(List<(int, Uint8List)> images) {
  final header = ByteData(6)
    ..setUint16(0, 0, Endian.little) // reserved
    ..setUint16(2, 1, Endian.little) // 1 = icon
    ..setUint16(4, images.length, Endian.little);

  var offset = 6 + 16 * images.length;
  final directory = BytesBuilder();
  for (final (size, png) in images) {
    final entry = ByteData(16)
      ..setUint8(0, size >= 256 ? 0 : size)
      ..setUint8(1, size >= 256 ? 0 : size)
      ..setUint8(2, 0) // colours in the palette: none, it is true colour
      ..setUint8(3, 0) // reserved
      ..setUint16(4, 1, Endian.little) // colour planes
      ..setUint16(6, 32, Endian.little) // bits per pixel
      ..setUint32(8, png.length, Endian.little)
      ..setUint32(12, offset, Endian.little);
    directory.add(entry.buffer.asUint8List());
    offset += png.length;
  }

  final out = BytesBuilder()
    ..add(header.buffer.asUint8List())
    ..add(directory.toBytes());
  for (final (_, png) in images) {
    out.add(png);
  }
  return out.toBytes();
}

void main() {
  test('the icon draws at every size it has to', () async {
    // The detail thresholds are the whole design, so this walks across them.
    for (final size in [16, 20, 24, 32, 48, 64, 128, 256, 1024]) {
      final png = await iconPng(size);
      expect(png.sublist(0, 8),
          [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
          reason: '$size is not a PNG');
      expect(png.length, greaterThan(100), reason: '$size is suspiciously small');
    }
  });

  test('the detail drops away as the canvas shrinks', () {
    // What makes it an icon rather than a thumbnail: at 16 pixels only the
    // silhouette is left, and the ripple and the stroke arrive as there is room
    // for them.
    expect(IconDetail.forSize(16).lobes, 0);
    expect(IconDetail.forSize(16).curve, 0.0);
    expect(IconDetail.forSize(24).lobes, 2);
    expect(IconDetail.forSize(24).curve, 0.0);
    expect(IconDetail.forSize(32).curve, greaterThan(0));
    expect(IconDetail.forSize(32).ripple, 0.0);
    expect(IconDetail.forSize(64).ripple, greaterThan(0));
    expect(IconDetail.forSize(64).panel, isTrue);
    expect(IconDetail.forSize(16).panel, isFalse);
  });

  test('the response is the shape a filter designer would recognise', () {
    final curve = iconResponse(IconDetail.forSize(256));
    double at(double x) =>
        curve.firstWhere((p) => p.dx >= x, orElse: () => curve.last).dy;

    // A flat-ish passband, a cliff, and a floor with lobes on it.
    expect(at(0.1), closeTo(0.88, 0.03));
    expect(at(0.4), closeTo(0.88, 0.03));
    expect(at(0.52), closeTo((0.88 + 0.17) / 2, 0.06)); // mid-skirt
    expect(at(0.62), lessThan(0.32));
    // The lobes are equal height, which is the point of the algorithm.
    final stop = curve.where((p) => p.dx >= 0.60);
    final peaks = <double>[];
    var previous = 0.0, rising = true;
    for (final p in stop) {
      if (rising && p.dy < previous) {
        peaks.add(previous);
        rising = false;
      } else if (!rising && p.dy > previous) {
        rising = true;
      }
      previous = p.dy;
    }
    expect(peaks, hasLength(3));
    for (final peak in peaks) {
      expect(peak, closeTo(0.17 + 0.125, 0.002));
    }
  });

  testWidgets('it is the same picture the Python draws', (tester) async {
    // Not pixel-identical: PIL and Skia antialias differently, and the Python
    // supersamples eight times and reduces where this strokes the path
    // directly. What has to hold is that it is the *same drawing* -- the same
    // palette in the same places -- so the two are compared by how far apart
    // their pixels are on average, which edge softening barely moves and a
    // changed colour or a shifted curve moves a great deal.
    for (final size in [16, 32, 256]) {
      final want = await tester.runAsync(() async =>
          decodeRgba(File('test/golden/py_icon_$size.png').readAsBytesSync()));
      final got = await tester.runAsync(() async {
        final image = await renderIcon(size);
        final data = await image.toByteData();
        image.dispose();
        return data!.buffer.asUint8List();
      });
      expect(got!.length, want!.length, reason: 'size $size');
      var total = 0;
      for (var i = 0; i < want.length; i++) {
        total += (got[i] - want[i]).abs();
      }
      final mean = total / want.length;
      expect(mean, lessThan(4.0),
          reason: 'at $size the mean channel difference is $mean');
    }
  });

  testWidgets('a maskable icon reaches the corners and keeps clear of them',
      (tester) async {
    final bytes = await tester.runAsync(() async {
      final image = await renderIcon(192, maskable: true);
      final data = await image.toByteData();
      image.dispose();
      return data!.buffer.asUint8List();
    });
    int at(int x, int y) {
      final i = (y * 192 + x) * 4;
      return (bytes![i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2];
    }

    // Full bleed: the very corner is background, not transparent and not a
    // rounded-off nothing.
    expect(bytes![3], 255, reason: 'the corner is transparent');
    expect(at(0, 0), iconBackground.toARGB32() & 0xFFFFFF);
    expect(at(191, 191), iconBackground.toARGB32() & 0xFFFFFF);
    // And the drawing is inside the safe circle: at 11% in from the left, on
    // the centre line, there is still background rather than the plot.
    expect(at(8, 96), iconBackground.toARGB32() & 0xFFFFFF);
    // While the middle is not.
    expect(at(96, 96), isNot(iconBackground.toARGB32() & 0xFFFFFF));
  });

  testWidgets('write the icons', (tester) async {
    // Only writes when asked; a plain run leaves the tree alone.
    if (!autoUpdateGoldenFiles) {
      markTestSkipped('run with --update-goldens to rewrite the icons');
      return;
    }
    await tester.runAsync(() async {
      for (final entry in _files.entries) {
        final png = await iconPng(entry.value);
        final file = File(entry.key)..createSync(recursive: true);
        file.writeAsBytesSync(png);
      }
      for (final entry in _maskable.entries) {
        final png = await iconPng(entry.value, maskable: true);
        (File(entry.key)..createSync(recursive: true)).writeAsBytesSync(png);
      }
      final layers = <(int, Uint8List)>[];
      for (final size in _icoSizes) {
        layers.add((size, await iconPng(size)));
      }
      File('windows/runner/resources/app_icon.ico')
          .writeAsBytesSync(buildIco(layers));
    });
    expect(File('macos/Runner/Assets.xcassets/AppIcon.appiconset/'
            'app_icon_1024.png')
        .lengthSync(), greaterThan(1000));
  });
}
