/// Renders every figure the tutorial uses, from the running program.
///
/// Run it with `--update-goldens` to write them:
///
///     flutter test test/make_docs_test.dart --update-goldens
///
/// Nothing here is hand-drawn. The panel figures are crops of the real control
/// column and the plot figures are the real magnitude plot, so a change to the
/// UI shows up in the documentation the next time this is run rather than
/// quietly making it wrong. Without the flag it checks the figures can still be
/// produced, which is what keeps that promise honest.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remez/main.dart';
import 'package:remez/src/controller.dart';
import 'package:remez/src/plots.dart';

const String _dir = 'docs/images';

/// Load real fonts, so the figures carry words rather than boxes.
///
/// `flutter test` substitutes a test font whose every glyph is a filled
/// rectangle -- deliberately, so that layout goldens do not depend on what is
/// installed. That is right for a layout golden and useless for documentation,
/// so this registers the Roboto that ships with the SDK under the family the
/// Material theme actually asks for, plus the icon font.
///
/// Returns false when the SDK fonts cannot be found, which the tests report
/// rather than quietly writing unreadable figures.
Future<bool> _loadRealFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return false;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return false;

  Future<bool> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    var any = false;
    for (final name in files) {
      final file = File('${dir.path}/$name');
      if (!file.existsSync()) continue;
      loader.addFont(
          Future.value(ByteData.view(file.readAsBytesSync().buffer)));
      any = true;
    }
    if (any) await loader.load();
    return any;
  }

  final text = await load('Roboto',
      ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
  return text && await _loadMonospace();
}

/// A real monospaced font for the Result panel.
///
/// The SDK ships no monospace, and the report is the one place where the
/// columns only line up because the font is fixed pitch -- substituting Roboto
/// would produce a figure that renders but misrepresents the panel. So a system
/// font is used, and its absence is a failure rather than a silent fallback.
Future<bool> _loadMonospace() async {
  const candidates = [
    '/System/Library/Fonts/SFNSMono.ttf',
    '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
    '/System/Library/Fonts/Supplemental/Courier New.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf',
    '/usr/share/fonts/TTF/DejaVuSansMono.ttf',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final loader = FontLoader('monospace')
      ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
    await loader.load();
    return true;
  }
  return false;
}

/// Oversampled, so the figures are readable when a browser scales them down.
const double _scale = 2.0;

Future<void> _write(String name, ui.Image image, WidgetTester tester) async {
  final data = await tester
      .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
  (Directory(_dir)..createSync(recursive: true));
  File('$_dir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
}

/// Capture a widget, by wrapping the nearest boundary and cropping to its rect.
///
/// Panels are not repaint boundaries of their own, so the whole window is
/// captured once and each panel cut out of it. Cropping in the same pass keeps
/// the figures pixel-aligned with what was on screen.
Future<ui.Image> _crop(WidgetTester tester, Finder of) async {
  final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary));
  final full = await tester.runAsync(() => boundary.toImage(pixelRatio: _scale));
  final rect = tester.getRect(of);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final src = Rect.fromLTWH(rect.left * _scale, rect.top * _scale,
      rect.width * _scale, rect.height * _scale);
  canvas.drawImageRect(full!, src,
      Rect.fromLTWH(0, 0, src.width, src.height), Paint());
  final out = await tester.runAsync(() => recorder
      .endRecording()
      .toImage(src.width.round(), src.height.round()));
  full.dispose();
  return out!;
}

Future<DesignController> _open(WidgetTester tester,
    {Size window = const Size(1500, 1800)}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const RemezApp());
  await tester.pumpAndSettle();
  final state = tester.state<State<DesignerPage>>(find.byType(DesignerPage));
  // ignore: avoid_dynamic_calls
  return (state as dynamic).controller as DesignController;
}

/// Pin the design time and force the rebuild that shows it.
///
/// The Result panel prints how long the design took, which differs on every
/// run and would rewrite that figure each time. Assigning the field is not
/// enough: it does not go through `update`, so nothing is notified and the
/// panel keeps painting the real duration.
Future<void> _pinTiming(WidgetTester tester, DesignController c) async {
  c.lastDesignTime = const Duration(microseconds: 12300);
  tester.element(find.byType(DesignerPage)).markNeedsBuild();
  await tester.pumpAndSettle();
}

/// The panel with this title, as a croppable rectangle.
Finder _panel(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(Card)).first;

void main() {
  final write = autoUpdateGoldenFiles;

  setUpAll(() async {
    expect(await _loadRealFonts(), isTrue,
        reason: 'a font was missing, so figures would be drawn in the test '
            'font and carry filled boxes instead of words');
  });

  testWidgets('the panels', (tester) async {
    final c = await _open(tester);
    await tester.pumpAndSettle();

    Future<void> shot(String name, String title) async {
      final image = await _crop(tester, _panel(title));
      expect(image.width, greaterThan(100), reason: name);
      if (write) await _write(name, image, tester);
      image.dispose();
    }

    await shot('panel-mode', 'Mode');
    await shot('panel-filter-fir', 'Filter');
    await shot('panel-bands-fir', 'Bands and constraints');
    await shot('panel-arithmetic', 'Arithmetic');
    await shot('panel-file', 'File');
    await shot('panel-display', 'Display');
    await _pinTiming(tester, c);
    expect(find.textContaining('designed in 12.3 ms'), findsWidgets,
        reason: 'the pinned duration is not what the report is showing');
    await shot('panel-result', 'Result');

    // The arithmetic panel only shows the word length and the hardware options
    // once it is in fixed point, and that is most of what there is to explain.
    c.update(() {
      c.arithmetic = Arithmetic.fixed;
      c.wordBits = 12;
    });
    await tester.pumpAndSettle();
    await shot('panel-arithmetic-fixed', 'Arithmetic');

    // And the IIR side replaces two panels entirely.
    c.update(() => c.mode = Mode.iir);
    c.setResponse('bandpass');
    await tester.pumpAndSettle();
    await shot('panel-filter-iir', 'Filter');
    await shot('panel-bands-iir', 'Bands and specification');
  });

  testWidgets('the annotated responses', (tester) async {
    // Each figure names the parameters where they act on the curve. These use
    // their own controllers rather than the app's: pumping a figure unmounts
    // the designer, which disposes the controller it was holding.
    tester.view.physicalSize = const Size(1100, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Future<void> figure(String name, Widget plot) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
            colorScheme:
                ColorScheme.fromSeed(seedColor: const Color(0xFF2196F3)),
            useMaterial3: true),
        home: Scaffold(
          body: RepaintBoundary(
            child: ColoredBox(
              color: const Color(0xFFFFFFFF),
              child: SizedBox(width: 900, height: 452, child: plot),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final image = await _crop(tester, find.byType(SizedBox).first);
      expect(image.width, 1800);
      if (write) await _write(name, image, tester);
      image.dispose();
    }

    /// A design at a real sample rate, so the figures carry Hz rather than
    /// fractions of one.
    DesignController design(String preset, int taps) {
      final c = DesignController();
      c.loadPreset(preset);
      c.update(() => c.numtaps = taps);
      c.setSampleRate(48000);
      return c;
    }

    await figure('response-lowpass', _annotated(design('Lowpass', 61),
        lowpass: true));
    await figure('response-highpass', _annotated(design('Highpass', 61),
        lowpass: false));
    await figure('response-bandpass', _annotatedBandpass(design('Bandpass', 81)));
  });
}

/// The magnitude plot with the FIR parameters named on it.
///
/// The names are the ones on the controls -- `F start`, `F stop`, `Ripple dB`,
/// `Atten. dB` -- put where each acts on the curve. The prose belongs in the
/// tutorial; a figure that tries to explain as well as label ends up doing
/// neither.
Widget _annotated(DesignController c, {required bool lowpass}) {
  final m = c.magnitude();
  final res = c.firEffective!;
  final pass = lowpass ? res.bands.first : res.bands.last;
  final stop = lowpass ? res.bands.last : res.bands.first;
  final passDev = res.bandDeviation[lowpass ? 0 : 1];
  final stopDb = 20 * db10(res.bandDeviation[lowpass ? 1 : 0]);
  final floor = c.magnitudeFloor();
  const ink = Color(0xFFB3261E);

  // Headroom above 0 dB for the band bars, so their labels stay in the frame.
  const top = 16.0;
  const bar = 11.0;

  return LinePlot(
    title: '',
    traces: [Trace(m.f, m.y, const Color(0xFF1F77B4))],
    xLabel: 'frequency (Hz)',
    yLabel: 'amplitude (dB)',
    xRange: (0, c.fs / 2),
    yRange: (floor, top),
    height: 420,
    spans: [
      Span(pass.f1, pass.f2, bar, 'passband', colour: ink, above: false),
      Span(stop.f1, stop.f2, bar, 'stopband', colour: ink, above: false),
      Span(lowpass ? pass.f2 : stop.f2, lowpass ? stop.f1 : pass.f1,
          floor * 0.5, 'transition', colour: ink),
    ],
    callouts: [
      // The band edge the passband row's F stop (or F start) sets.
      Callout(lowpass ? pass.f2 : pass.f1, 0,
          lowpass ? 'F stop  ${_short(pass.f2)}' : 'F start  ${_short(pass.f1)}',
          dx: lowpass ? -70 : 70, dy: -52, colour: ink),
      Callout(lowpass ? stop.f1 : stop.f2, stopDb,
          lowpass ? 'F start  ${_short(stop.f1)}' : 'F stop  ${_short(stop.f2)}',
          dx: lowpass ? -40 : 40, dy: -46, colour: ink),
      Callout(pass.f1 + (pass.f2 - pass.f1) * (lowpass ? 0.45 : 0.55),
          20 * db10(1 + passDev),
          'Ripple dB  (${_ripple(passDev)} p-p)',
          dy: 32, colour: ink),
      // Above the floor, not among the ripples, and clear of the edge callout.
      Callout(stop.f1 + (stop.f2 - stop.f1) * (lowpass ? 0.72 : 0.28), stopDb,
          'Atten. dB  (${(-stopDb).toStringAsFixed(1)})',
          dy: -30, colour: ink),
    ],
  );
}

/// The bandpass figure: three bands, two transitions, two edges named.
Widget _annotatedBandpass(DesignController c) {
  final m = c.magnitude();
  final res = c.firEffective!;
  final low = res.bands[0], pass = res.bands[1], high = res.bands[2];
  final stopDb = 20 * db10(res.bandDeviation[0]);
  final floor = c.magnitudeFloor();
  const ink = Color(0xFFB3261E);
  const top = 16.0;
  const bar = 11.0;

  return LinePlot(
    title: '',
    traces: [Trace(m.f, m.y, const Color(0xFF1F77B4))],
    xLabel: 'frequency (Hz)',
    yLabel: 'amplitude (dB)',
    xRange: (0, c.fs / 2),
    yRange: (floor, top),
    height: 420,
    spans: [
      Span(low.f1, low.f2, bar, 'stopband', colour: ink, above: false),
      Span(pass.f1, pass.f2, bar, 'passband', colour: ink, above: false),
      Span(high.f1, high.f2, bar, 'stopband', colour: ink, above: false),
      Span(low.f2, pass.f1, floor * 0.5, 'transition', colour: ink),
      Span(pass.f2, high.f1, floor * 0.5, 'transition', colour: ink),
    ],
    callouts: [
      Callout(pass.f1, 0, 'F start  ${_short(pass.f1)}',
          dx: -66, dy: -54, colour: ink),
      Callout(pass.f2, 0, 'F stop  ${_short(pass.f2)}',
          dx: 66, dy: -54, colour: ink),
      Callout((high.f1 + high.f2) / 2, stopDb,
          'Atten. dB  (${(-stopDb).toStringAsFixed(1)})',
          dy: -30, colour: ink),
    ],
  );
}

/// dB from a linear ratio, with a floor so an exact zero does not blow up.
double db10(double x) => x <= 0 ? -12 : math.log(x) / math.ln10;

String _short(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

String _ripple(double dev) =>
    (20 * db10(1 + dev) - 20 * db10(1 - dev)).toStringAsFixed(2);
