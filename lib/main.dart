/// Digital filter designer: Remez-exchange FIR and classical IIR.
///
/// A Flutter port of the Python tool of the same name. The controls are on the
/// left, in panels that fold away; the right hand side plots what came out.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'src/c_export.dart';
import 'src/cli.dart';
import 'src/coeff_export.dart';
import 'src/labels.dart';
import 'src/controller.dart';
import 'src/design_view.dart';
import 'src/fir_core.dart' as fir;
import 'src/iir_core.dart' as iir;
import 'src/plots.dart';
import 'src/rtl_common.dart';
import 'src/sv_export.dart' as sv;
import 'src/vhdl_export.dart' as vhdl;

void main(List<String> args) {
  final cli = parseArgs(args);
  if (cli.shouldExit) {
    (cli.isError ? stderr : stdout).writeln(cli.message);
    exit(cli.exitCode!);
  }

  // Read the design before building anything, so a bad path fails at once
  // rather than after a window has appeared.
  Map<String, dynamic>? startup;
  if (cli.designPath != null) {
    try {
      startup = json.decode(File(cli.designPath!).readAsStringSync())
          as Map<String, dynamic>;
    } catch (e) {
      stderr.writeln('$programName: cannot open ${cli.designPath}: $e');
      exit(2);
    }
  }
  runApp(RemezApp(startup: startup));
}

class RemezApp extends StatefulWidget {
  const RemezApp({super.key, this.startup});

  /// A design to open at startup, from the command line.
  final Map<String, dynamic>? startup;

  @override
  State<RemezApp> createState() => _RemezAppState();
}

class _RemezAppState extends State<RemezApp> {
  /// Which appearance the designer has asked for.
  ///
  /// Held above [MaterialApp] rather than inside the page, because the theme
  /// has to be in scope of everything the page builds.
  ThemeMode mode = ThemeMode.system;

  static ThemeData _theme(Brightness brightness) => ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2196F3), brightness: brightness),
        useMaterial3: true,
        visualDensity: VisualDensity.compact,
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital filter designer',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: mode,
      home: DesignerPage(
        startup: widget.startup,
        onAppearance: (a) => setState(() => mode = switch (a) {
              Appearance.light => ThemeMode.light,
              Appearance.dark => ThemeMode.dark,
              Appearance.system => ThemeMode.system,
            }),
      ),
    );
  }
}

class DesignerPage extends StatefulWidget {
  const DesignerPage({super.key, this.startup, this.onAppearance});

  /// A design to open at startup, from the command line.
  final Map<String, dynamic>? startup;

  /// Told when the appearance changes, including when a design file sets it.
  final ValueChanged<Appearance>? onAppearance;

  @override
  State<DesignerPage> createState() => _DesignerPageState();
}

/// How the desktop hands this program a document it was asked to open.
const MethodChannel documentChannel = MethodChannel('com.deadhat.remez/documents');

class _DesignerPageState extends State<DesignerPage> {
  final controller = DesignController();
  double columnWidth = _defaultColumn;
  Appearance _appearance = Appearance.system;

  /// Open a design the desktop handed over, by path.
  ///
  /// Separate from the File panel's button because there is no dialog involved
  /// and no messenger yet on a cold launch: the window may not have been built
  /// when the path arrives.
  Future<void> _openPath(String path) async {
    try {
      final text = await File(path).readAsString();
      controller.fromJson(json.decode(text) as Map<String, dynamic>);
    } catch (e) {
      stderr.writeln('$programName: cannot open $path: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Cannot open $path: $e')));
    }
  }

  void _listenForDocuments() {
    documentChannel.setMethodCallHandler((call) async {
      if (call.method == 'open' && call.arguments is String) {
        await _openPath(call.arguments as String);
      }
      return null;
    });
    // A document double-clicked on a cold launch reaches the delegate before
    // this handler exists, so it is waiting to be collected.
    documentChannel.invokeMethod<String>('takePending').then((path) {
      if (path != null && path.isNotEmpty) _openPath(path);
    }).catchError((_) {
      // No such channel on a platform that has no document association.
    });
  }

  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      setState(() {});
      // A loaded design can carry an appearance, so this is not only the
      // control in the Display panel talking.
      if (controller.appearance != _appearance) {
        _appearance = controller.appearance;
        widget.onAppearance?.call(_appearance);
      }
    });
    var opened = false;
    if (widget.startup != null) {
      try {
        controller.fromJson(widget.startup!);
        opened = true;
      } catch (e) {
        stderr.writeln('$programName: that design could not be loaded: $e');
      }
    }
    if (!opened) controller.design();
    // Always, even when a design came in on the command line: the Finder can
    // hand this window another one at any time.
    _listenForDocuments();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital filter designer'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                controller.lastDesignTime == null
                    ? ''
                    : 'designed in '
                        '${controller.lastDesignTime!.inMicroseconds / 1000} ms',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, box) {
        // Clamped here rather than on drag, so that narrowing the window cannot
        // leave the column wider than the window and the plots at zero.
        final maxColumn = math.max(_minColumn, box.maxWidth - _minPlots);
        final width = columnWidth.clamp(_minColumn, maxColumn);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: width, child: _Controls(controller: controller)),
            _Splitter(
              key: splitterKey,
              onDrag: (dx) => setState(() => columnWidth = (width + dx)
                  .clamp(_minColumn, maxColumn)),
              onReset: () => setState(() => columnWidth = _defaultColumn),
            ),
            Expanded(child: _RightPane(controller: controller)),
          ],
        );
      }),
    );
  }
}

/// Identifies the plot pane, so it can be captured to an image.
final GlobalKey paneKey = GlobalKey();

const double _defaultColumn = 400;
const double _minColumn = 260;
const double _minPlots = 320;

/// How much a saved plot is oversampled against the screen.
const double _plotScale = 2.0;

/// Identifies the splitter for tests, which cannot reach a private type.
const Key splitterKey = ValueKey('splitter');

/// The draggable split between the controls and the plots.
///
/// The grab area is wider than the line it draws: a three-pixel divider is
/// possible to hit but not pleasant to. Double-click puts it back.
class _Splitter extends StatelessWidget {
  const _Splitter(
      {super.key, required this.onDrag, required this.onReset});
  final ValueChanged<double> onDrag;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
        onDoubleTap: onReset,
        child: Tooltip(
          message: 'Drag to resize, double-click to reset',
          waitDuration: const Duration(milliseconds: 700),
          child: SizedBox(
            width: 9,
            child: Center(
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// the control column
// ---------------------------------------------------------------------------

class _Controls extends StatelessWidget {
  const _Controls({required this.controller});
  final DesignController controller;

  /// Report the outcome of a save or an open.
  ///
  /// The messenger is looked up before the file dialog, not after: the dialog
  /// is an await, and a context is not guaranteed to still be mounted on the
  /// other side of one. Holding the messenger itself sidesteps the question.
  void _say(ScaffoldMessengerState messenger, String message,
      {bool error = false}) {
    messenger.showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? const Color(0xFFFFDAD6) : null,
    ));
  }

  Future<void> _openDesign(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    const type = XTypeGroup(label: 'design', extensions: designExtensions);
    final file = await openFile(acceptedTypeGroups: const [type]);
    if (file == null) return;
    try {
      controller.fromJson(
          json.decode(await file.readAsString()) as Map<String, dynamic>);
      _say(messenger, 'Opened ${file.name}');
    } catch (e) {
      _say(messenger, 'Cannot open that file: $e', error: true);
    }
  }

  Future<void> _saveDesign(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    const type = XTypeGroup(label: 'design', extensions: [designExtension]);
    final file = await getSaveLocation(
        acceptedTypeGroups: const [type],
        suggestedName: 'design.$designExtension');
    if (file == null) return;
    await _write(messenger, file.path,
        '${const JsonEncoder.withIndent('  ').convert(controller.toJson())}\n');
  }

  Future<void> _saveC(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    const type = XTypeGroup(label: 'C source', extensions: ['c']);
    final file = await getSaveLocation(
        acceptedTypeGroups: const [type], suggestedName: 'filter.c');
    if (file == null) return;
    // The file's own name is what the program calls itself in its usage and
    // error messages, until argv[0] says otherwise.
    final stem = sanitiseName(
        file.path.split(Platform.pathSeparator).last.replaceAll('.c', ''));
    // Whatever was actually built: in fixed point that is the rounded filter.
    final source = controller.isIir
        ? iirCSource(controller.iirEffective!,
            fixed: controller.fixed, name: stem)
        : firCSource(controller.firEffective!,
            fixed: controller.fixed, name: stem);
    await _write(messenger, file.path, source);
  }

  /// The RTL, and its testbench beside it when one was asked for.
  ///
  /// One routine for both languages: the hardware is decided by `planFor`, and
  /// the back-ends only render it, so the only thing that differs here is which
  /// pair of functions is called and what the file is called.
  Future<void> _saveRtl(BuildContext context, {required bool verilog}) async {
    final messenger = ScaffoldMessenger.of(context);
    final suffix = verilog ? 'sv' : 'vhd';
    final type = XTypeGroup(
        label: verilog ? 'SystemVerilog' : 'VHDL', extensions: [suffix]);
    final file = await getSaveLocation(
        acceptedTypeGroups: [type], suggestedName: 'filter.$suffix');
    if (file == null) return;
    final path = file.path;
    final stem = path.split(Platform.pathSeparator).last;
    final dot = '.$suffix';
    final opts = RtlOptions(
      name: stem.endsWith(dot)
          ? stem.substring(0, stem.length - dot.length)
          : stem,
      headroom: controller.headroom,
      fixedCoeffs: controller.fixedCoeffs,
      structure: controller.structure,
      folded: controller.folded,
    );
    try {
      final kind = controller.isIir ? 'iir' : 'fir';
      final design =
          controller.isIir ? controller.iirResult! : controller.firResult!;
      final plan = planFor(kind, design, controller.fixed, opts);
      final source = verilog
          ? (kind == 'iir' ? sv.renderIir(plan) : sv.renderFir(plan))
          : (kind == 'iir' ? vhdl.renderIir(plan) : vhdl.renderFir(plan));
      await File(path).writeAsString(source);
      if (!controller.wantTestbench) {
        _say(messenger, 'Wrote $path');
        return;
      }
      final tbPath = path.endsWith(dot)
          ? '${path.substring(0, path.length - dot.length)}_tb$dot'
          : '${path}_tb$dot';
      await File(tbPath).writeAsString(verilog
          ? sv.testbenchForPlan(plan)
          : vhdl.testbenchForPlan(plan));
      _say(messenger,
          'Wrote $path and ${tbPath.split(Platform.pathSeparator).last}');
    } on RtlError catch (e) {
      _say(messenger, e.message, error: true);
    } catch (e) {
      _say(messenger, 'Save failed: $e', error: true);
    }
  }

  /// Why the two RTL buttons are, or are not, available.
  String _rtlHint(DesignController c) => c.isFixed
      ? 'RTL and a testbench for the structure chosen in the Arithmetic panel'
      : 'Hardware needs fixed-point coefficients: choose Fixed in the '
          'Arithmetic panel';

  /// The coefficients on their own, as CSV or a C header.
  Future<void> _saveCoefficients(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    const types = [
      XTypeGroup(label: 'CSV', extensions: ['csv']),
      XTypeGroup(label: 'C header', extensions: ['h']),
      XTypeGroup(label: 'Text', extensions: ['txt']),
    ];
    final file = await getSaveLocation(
        acceptedTypeGroups: types, suggestedName: 'coefficients.csv');
    if (file == null) return;
    // Always the coefficients as built: in fixed point that means the rounded
    // values, alongside the integers they are stored as.
    final lines = controller.isIir
        ? iirExport(controller.iirEffective!, file.path, fixed: controller.fixed)
        : firExport(controller.firEffective!, file.path, fixed: controller.fixed);
    await _write(messenger, file.path, '${lines.join('\n')}\n');
  }

  /// Whichever view is showing, as a PNG.
  ///
  /// Captured from the pane rather than redrawn, so what lands in the file is
  /// what is on screen: the plots or the design diagram, in whichever theme.
  /// [_plotScale] oversamples it, because a screenshot at logical resolution
  /// looks soft in a document -- the Python asks matplotlib for 150 dpi against
  /// a default of 100 for the same reason.
  Future<void> _savePlot(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final boundary =
        paneKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      _say(messenger, 'There is nothing on screen to save', error: true);
      return;
    }
    const type = XTypeGroup(label: 'PNG', extensions: ['png']);
    final file = await getSaveLocation(
        acceptedTypeGroups: const [type], suggestedName: 'plot.png');
    if (file == null) return;
    try {
      final image = await boundary.toImage(pixelRatio: _plotScale);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('the image could not be encoded');
      await File(file.path).writeAsBytes(data.buffer.asUint8List());
      _say(messenger, 'Wrote ${file.path}');
    } catch (e) {
      _say(messenger, 'Save failed: $e', error: true);
    }
  }

  Future<void> _write(
      ScaffoldMessengerState messenger, String path, String text) async {
    try {
      await File(path).writeAsString(text);
      _say(messenger, 'Wrote $path');
    } catch (e) {
      _say(messenger, 'Save failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        _Panel(
          title: 'Mode',
          child: SegmentedButton<Mode>(
            segments: const [
              ButtonSegment(value: Mode.fir, label: Text('FIR')),
              ButtonSegment(value: Mode.iir, label: Text('IIR')),
            ],
            selected: {c.mode},
            onSelectionChanged: (s) => c.update(() => c.mode = s.first),
          ),
        ),
        if (c.isIir) _IirPanel(controller: c) else _FirPanel(controller: c),
        _ArithmeticPanel(controller: c),
        _Panel(
          title: 'File',
          child: Column(
            children: [
              // Two rows of two rather than a Wrap: one wide row would set the
              // width of the whole control column, and a Wrap reflows them into
              // a stack four buttons tall as soon as the split is narrowed.
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openDesign(context),
                    child: const Text('Open design…'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _saveDesign(context),
                    child: const Text('Save design…'),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        c.hasResult ? () => _saveCoefficients(context) : null,
                    child: const Text('Save coefficients…'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: c.hasResult ? () => _savePlot(context) : null,
                    child: const Text('Save plot…'),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: c.hasResult ? () => _saveC(context) : null,
                    child: const Text('Save C…'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Tooltip(
                    message: _rtlHint(c),
                    child: OutlinedButton(
                      onPressed: c.hasResult && c.isFixed
                          ? () => _saveRtl(context, verilog: true)
                          : null,
                      child: const Text('Generate SV…'),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: Tooltip(
                    message: _rtlHint(c),
                    child: OutlinedButton(
                      onPressed: c.hasResult && c.isFixed
                          ? () => _saveRtl(context, verilog: false)
                          : null,
                      child: const Text('Generate VHDL…'),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Expanded(child: SizedBox()),
              ]),
            ],
          ),
        ),
        _Panel(
          title: 'Display',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<Pane>(
                segments: const [
                  ButtonSegment(
                      value: Pane.plot,
                      label: Text('Plot view'),
                      icon: Icon(Icons.show_chart, size: 16)),
                  ButtonSegment(
                      value: Pane.design,
                      label: Text('Design view'),
                      icon: Icon(Icons.account_tree_outlined, size: 16)),
                ],
                selected: {c.view},
                onSelectionChanged: (v) =>
                    c.update(() => c.view = v.first),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Magnitude in dB'),
                value: c.logScale,
                onChanged: (v) => c.update(() => c.logScale = v),
              ),
              const SizedBox(height: 4),
              SegmentedButton<Appearance>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: Appearance.system,
                      label: Text('Auto'),
                      icon: Icon(Icons.brightness_auto_outlined, size: 15)),
                  ButtonSegment(
                      value: Appearance.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_outlined, size: 15)),
                  ButtonSegment(
                      value: Appearance.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined, size: 15)),
                ],
                selected: {c.appearance},
                onSelectionChanged: (v) =>
                    c.update(() => c.appearance = v.first),
              ),
            ],
          ),
        ),
        _Panel(
          title: 'Result',
          child: SizedBox(
            height: 260,
            child: Scrollbar(
              child: SingleChildScrollView(
                child: SelectableText(
                  c.report(),
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 11, height: 1.35),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Whichever of the two views is showing, or the reason there is neither.
class _RightPane extends StatelessWidget {
  const _RightPane({required this.controller});
  final DesignController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c.error != null || !c.hasResult) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            c.error ?? 'no filter',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final surface = Theme.of(context).colorScheme.surface;
    if (c.view == Pane.design) {
      // The design view draws what was built, so in fixed point it is the
      // rounded coefficients that appear against the multipliers. It is drawn
      // to fill whatever box it is given, so the boundary is the pane.
      return RepaintBoundary(
        key: paneKey,
        child: ColoredBox(
          color: surface,
          child: DesignView(fir: c.firEffective, iir: c.iirEffective),
        ),
      );
    }
    // The plots have a natural height of their own. Putting the boundary
    // around the content rather than around the viewport is what makes a saved
    // plot the plots and nothing else: on a tall window the viewport leaves
    // blank below them, and on a short one it would cut the last one off.
    return SingleChildScrollView(
      child: RepaintBoundary(
        key: paneKey,
        child: ColoredBox(color: surface, child: _Plots(controller: c)),
      ),
    );
  }
}

class _Panel extends StatefulWidget {
  const _Panel({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  State<_Panel> createState() => _PanelState();
}

class _PanelState extends State<_Panel> {
  bool collapsed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                if (widget.trailing != null) widget.trailing!,
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  icon: Icon(collapsed ? Icons.add : Icons.remove),
                  tooltip: collapsed ? 'Show' : 'Hide',
                  onPressed: () => setState(() => collapsed = !collapsed),
                ),
              ],
            ),
            if (!collapsed) ...[
              const Divider(height: 8),
              widget.child,
            ],
          ],
        ),
      ),
    );
  }
}

class _Field extends StatefulWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.onSubmitted,
    this.width = 90,
    this.enabled = true,
  });
  final String label;
  final String value;
  final ValueChanged<String> onSubmitted;
  final double width;

  /// A greyed-out field still shows its value, which is the point: the Weight
  /// and Spec columns swap places and you can see what the other one holds.
  final bool enabled;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late final TextEditingController text =
      TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_Field old) {
    super.didUpdateWidget(old);
    if (widget.value != text.text) text.text = widget.value;
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: Focus(
        onFocusChange: (has) {
          if (!has) widget.onSubmitted(text.text);
        },
        child: TextField(
          controller: text,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: widget.label,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          style: const TextStyle(fontSize: 13),
          onSubmitted: widget.onSubmitted,
        ),
      ),
    );
  }
}

/// A checkbox sized and framed like a [_Field], so it sits in the same Wrap.
class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.tooltip,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final box = InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 40,
        padding: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 32,
            child: Checkbox(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              value: value,
              onChanged: (v) => onChanged(v ?? false),
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 13)),
        ]),
      ),
    );
    return tooltip == null
        ? box
        : Tooltip(message: tooltip!, waitDuration: const Duration(milliseconds: 600), child: box);
  }
}

class _FirPanel extends StatelessWidget {
  const _FirPanel({required this.controller});
  final DesignController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Column(
      children: [
        _Panel(
          title: 'Filter',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                _Field(
                  label: 'Taps',
                  value: '${c.numtaps}',
                  width: 80,
                  onSubmitted: (v) {
                    final n = int.tryParse(v);
                    if (n != null) c.update(() => c.numtaps = n);
                  },
                ),
                _Field(
                  label: 'Sample rate',
                  value: _short(c.fs),
                  width: 120,
                  onSubmitted: (v) {
                    final f = double.tryParse(v);
                    if (f != null) c.setSampleRate(f);
                  },
                ),
                _Field(
                  label: 'Grid density',
                  value: '${c.gridDensity}',
                  width: 104,
                  onSubmitted: (v) {
                    final n = int.tryParse(v);
                    if (n != null) c.update(() => c.gridDensity = n);
                  },
                ),
                _Field(
                  label: 'Max iters',
                  value: '${c.maxiter}',
                  width: 92,
                  onSubmitted: (v) {
                    final n = int.tryParse(v);
                    if (n != null) c.update(() => c.maxiter = n);
                  },
                ),
              ]),
              const SizedBox(height: 8),
              DropdownButtonFormField<fir.Symmetry>(
                initialValue: c.symmetry,
                isDense: true,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Symmetry',
                    isDense: true,
                    border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(
                      value: fir.Symmetry.symmetric, child: Text('symmetric')),
                  DropdownMenuItem(
                      value: fir.Symmetry.antisymmetric,
                      child: Text('antisymmetric')),
                ],
                onChanged: (v) =>
                    v == null ? null : c.update(() => c.symmetry = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: c.preset,
                isDense: true,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Preset',
                    isDense: true,
                    border: OutlineInputBorder()),
                items: [
                  for (final p in DesignController.presets)
                    DropdownMenuItem(value: p, child: Text(p))
                ],
                onChanged: (v) => v == null ? null : c.loadPreset(v),
              ),
            ],
          ),
        ),
        _Panel(
          title: 'Bands and constraints',
          trailing: IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add band',
            onPressed: c.addBand,
          ),
          child: Column(
            children: [
              for (var i = 0; i < c.rows.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Expanded(
                      child: Wrap(spacing: 4, runSpacing: 4, children: [
                        _Field(
                            label: 'F start',
                            value: c.rows[i].f1,
                            width: 70,
                            onSubmitted: (v) =>
                                c.update(() => c.rows[i].f1 = v)),
                        _Field(
                            label: 'F stop',
                            value: c.rows[i].f2,
                            width: 70,
                            onSubmitted: (v) =>
                                c.update(() => c.rows[i].f2 = v)),
                        _Field(
                            label: 'D at start',
                            value: c.rows[i].d1,
                            width: 82,
                            onSubmitted: (v) =>
                                c.update(() => c.rows[i].d1 = v)),
                        _Field(
                            label: 'D at stop',
                            value: c.rows[i].d2,
                            width: 82,
                            onSubmitted: (v) =>
                                c.update(() => c.rows[i].d2 = v)),
                        _Field(
                            label: 'Weight',
                            value: c.rows[i].weight,
                            width: 64,
                            enabled: !c.useSpec,
                            onSubmitted: (v) =>
                                c.update(() => c.rows[i].weight = v)),
                        _Field(
                            label: 'Spec (dB)',
                            value: c.rows[i].spec,
                            width: 72,
                            enabled: c.useSpec,
                            onSubmitted: (v) =>
                                c.update(() => c.rows[i].spec = v)),
                        _Toggle(
                            label: '1/f',
                            tooltip: 'Weight as w/f across the band, which '
                                'equalises the relative error',
                            value: c.rows[i].invF,
                            onChanged: (v) =>
                                c.update(() => c.rows[i].invF = v)),
                      ]),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      icon: const Icon(Icons.close),
                      tooltip: 'Remove band',
                      onPressed: () => c.removeBand(i),
                    ),
                  ]),
                ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: c.useSpec,
                onChanged: (v) => c.update(() => c.useSpec = v ?? false),
                title: const Text('Weights from the Spec column'),
                subtitle: const Text(
                    'passband ripple dB p-p / stopband atten. dB',
                    style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IirPanel extends StatelessWidget {
  const _IirPanel({required this.controller});
  final DesignController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final verified = c.verification == Verified.exact;
    return Column(
      children: [
        _Panel(
          title: 'Filter',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: c.response,
                isDense: true,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Response',
                    isDense: true,
                    border: OutlineInputBorder()),
                items: [
                  for (final r in iir.responses)
                    DropdownMenuItem(value: r, child: Text(r))
                ],
                onChanged: (v) => v == null ? null : c.setResponse(v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: c.approximation,
                isDense: true,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Approximation',
                    isDense: true,
                    border: OutlineInputBorder()),
                items: [
                  for (final a in iir.approximations)
                    DropdownMenuItem(
                      value: a,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(a),
                        if (verificationOf(a, c.response) != Verified.exact)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.science_outlined, size: 14),
                          ),
                      ]),
                    )
                ],
                onChanged: (v) =>
                    v == null ? null : c.update(() => c.approximation = v),
              ),
              if (!verified)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Not yet checked against the Python implementation: it '
                    'designs, but treat the numbers as provisional.',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Smallest order'),
                    value: c.autoOrder,
                    onChanged: (v) => c.update(() => c.autoOrder = v ?? true),
                  ),
                ),
                _Field(
                  label: 'Order',
                  value: '${c.order}',
                  width: 76,
                  onSubmitted: (v) {
                    final n = int.tryParse(v);
                    if (n != null) {
                      c.update(() {
                        c.order = n;
                        c.autoOrder = false;
                      });
                    }
                  },
                ),
              ]),
              _Field(
                label: 'Sample rate',
                value: _short(c.fs),
                width: 130,
                onSubmitted: (v) {
                  final f = double.tryParse(v);
                  if (f != null) c.setSampleRate(f);
                },
              ),
            ],
          ),
        ),
        _Panel(
          title: 'Bands and specification',
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (var i = 0; i < c.edgeCount; i++)
              _Field(
                label: 'Passband ${c.edgeCount > 1 ? i + 1 : ''}'.trim(),
                value: c.wp[i],
                width: 96,
                onSubmitted: (v) => c.update(() => c.wp[i] = v),
              ),
            for (var i = 0; i < c.edgeCount; i++)
              _Field(
                label: 'Stopband ${c.edgeCount > 1 ? i + 1 : ''}'.trim(),
                value: c.ws[i],
                width: 96,
                onSubmitted: (v) => c.update(() => c.ws[i] = v),
              ),
            _Field(
              label: 'Ripple dB',
              value: c.rp,
              width: 96,
              onSubmitted: (v) => c.update(() => c.rp = v),
            ),
            _Field(
              label: 'Atten. dB',
              value: c.rs,
              width: 96,
              onSubmitted: (v) => c.update(() => c.rs = v),
            ),
          ]),
        ),
      ],
    );
  }
}

class _ArithmeticPanel extends StatelessWidget {
  const _ArithmeticPanel({required this.controller});
  final DesignController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return _Panel(
      title: 'Arithmetic',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<Arithmetic>(
            segments: const [
              ButtonSegment(value: Arithmetic.floating, label: Text('Floating')),
              ButtonSegment(value: Arithmetic.fixed, label: Text('Fixed')),
            ],
            selected: {c.arithmetic},
            onSelectionChanged: (s) => c.update(() => c.arithmetic = s.first),
          ),
          if (c.isFixed) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _Field(
                label: 'Word bits',
                value: '${c.wordBits}',
                width: 92,
                onSubmitted: (v) {
                  final n = int.tryParse(v);
                  if (n != null) c.update(() => c.wordBits = n);
                },
              ),
              _Field(
                label: 'Headroom',
                value: '${c.headroom}',
                width: 92,
                onSubmitted: (v) {
                  final n = int.tryParse(v);
                  if (n != null) c.update(() => c.headroom = n);
                },
              ),
            ]),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Place the binary point automatically'),
              value: c.autoFrac,
              onChanged: (v) => c.update(() => c.autoFrac = v ?? true),
            ),
            if (c.fixed != null)
              Text(
                '${c.fixed!.qFormat}   step '
                '${c.fixed!.step.toStringAsExponential(3)}'
                '${c.fixed!.saturated > 0 ? '   *** ${c.fixed!.saturated} saturated ***' : ''}',
                style: const TextStyle(fontSize: 11),
              ),
            const Divider(height: 16),
            Text('Hardware', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: c.structure,
              isDense: true,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Structure',
                  isDense: true,
                  border: OutlineInputBorder()),
              items: [
                for (final s in structures)
                  DropdownMenuItem(value: s, child: Text(s))
              ],
              onChanged: (v) => v == null ? null : c.update(() => c.structure = v),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Fold the symmetric taps'),
              subtitle: const Text('one multiplier per pair',
                  style: TextStyle(fontSize: 11)),
              value: c.folded,
              onChanged: (v) => c.update(() => c.folded = v ?? false),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Coefficients as constants'),
              subtitle: const Text('otherwise a runtime port',
                  style: TextStyle(fontSize: 11)),
              value: c.fixedCoeffs,
              onChanged: (v) => c.update(() => c.fixedCoeffs = v ?? true),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Write a testbench too'),
              value: c.wantTestbench,
              onChanged: (v) => c.update(() => c.wantTestbench = v ?? true),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// the plots
// ---------------------------------------------------------------------------

class _Plots extends StatelessWidget {
  const _Plots({required this.controller});
  final DesignController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c.error != null || !c.hasResult) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            c.error ?? 'no filter',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final magnitude = c.magnitude();
    final ideal = c.idealMagnitude();
    final traces = <Trace>[
      if (ideal != null)
        Trace(ideal.f, ideal.y, scheme.onSurface.withValues(alpha: 0.35),
            width: 1.0),
      Trace(magnitude.f, magnitude.y, scheme.primary),
    ];

    final corridors = <Corridor>[];
    final markers = <Markers>[];
    if (!c.isIir) {
      final res = c.firResult!;
      final eff = c.firEffective!;
      for (var i = 0; i < res.bands.length; i++) {
        final band = res.bands[i];
        final dev = eff.bandDeviation[i];
        final lo = c.logScale
            ? _dbOf(math.max(band.target - dev, 0))
            : band.target - dev;
        final hi = c.logScale ? _dbOf(band.target + dev) : band.target + dev;
        corridors.add(Corridor(
            band.f1, band.f2, lo, hi, scheme.tertiary.withValues(alpha: 0.20)));

        // What was asked for, against what the corridor above shows was got.
        final spec = c.specDev;
        if (spec != null) {
          final edges = Float64List.fromList([band.f1, band.f2]);
          final grey = scheme.onSurface.withValues(alpha: 0.55);
          for (final level in [band.target + spec[i], band.target - spec[i]]) {
            if (level <= 0 && c.logScale) continue;
            final y = c.logScale ? _dbOf(level) : level;
            traces.add(Trace(edges, Float64List.fromList([y, y]), grey,
                width: 1.0, dashed: true));
          }
        }
      }
      final w = Float64List(res.extremalF.length);
      for (var i = 0; i < w.length; i++) {
        w[i] = 2 * math.pi * res.extremalF[i] / res.fs;
      }
      final amp = fir.amplitudeResponse(eff.h, w, res.symmetry);
      final y = Float64List(amp.length);
      for (var i = 0; i < amp.length; i++) {
        y[i] = c.logScale ? _dbOf(amp[i].abs()) : amp[i];
      }
      markers.add(Markers(res.extremalF, y, scheme.error));
    }

    final floor = c.magnitudeFloor();
    var top = 5.0;
    for (final v in magnitude.y) {
      if (v.isFinite && v + 5 > top) top = v + 5;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinePlot(
          title: c.isIir
              ? '${c.approximation} ${c.response}, order '
                  '${c.iirEffective!.order}   —   '
                  '${c.iirEffective!.sos.length} biquad(s)'
                  '${c.iirEffective!.stable ? '' : '   *** UNSTABLE ***'}'
              : 'Type ${c.firResult!.ftype} ${c.firResult!.symmetry.name} FIR, '
                  'N = ${c.firResult!.numtaps}   —   '
                  '${c.firResult!.iterations} iterations',
          traces: traces,
          corridors: corridors,
          markers: markers,
          xLabel: 'frequency${c.fs == 1.0 ? ' (normalised)' : ' (Hz)'}',
          yLabel: c.logScale ? 'amplitude (dB)' : 'amplitude',
          xRange: (0, c.fs / 2),
          yRange: c.logScale ? (floor, top) : null,
          height: 300,
        ),
        if (!c.isIir) _DetailPlot(controller: c),
        if (!c.isIir) _ErrorPlot(controller: c),
        StemPlot(
          values: c.impulse(),
          title: c.isIir ? 'impulse response' : 'impulse response (the taps)',
        ),
      ],
    );
  }
}

/// Gain error against the target, for the bands where that has meaning.
///
/// On the full-scale plot above, half a dB of passband ripple is a line
/// thickness. Here each band with a non-zero target is drawn as 20*log10(A/D),
/// which puts the ripple of every such band -- whatever its gain, flat or
/// sloped -- on one readable scale.
class _DetailPlot extends StatelessWidget {
  const _DetailPlot({required this.controller});
  final DesignController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final res = c.firResult!;
    final eff = c.firEffective!;
    final scheme = Theme.of(context).colorScheme;
    final tolerance = scheme.tertiary;

    final traces = <Trace>[];
    final corridors = <Corridor>[];
    var reach = 0.0;

    for (final band in c.liveBands) {
      final curves = c.bandCurves(res, band);
      final w = Float64List(curves.f.length);
      for (var i = 0; i < w.length; i++) {
        w[i] = 2 * math.pi * curves.f[i] / res.fs;
      }
      final amp = fir.amplitudeResponse(eff.h, w, res.symmetry);

      final ratio = Float64List(w.length);
      final up = Float64List(w.length);
      final down = Float64List(w.length);
      for (var i = 0; i < w.length; i++) {
        final d = curves.desired[i];
        ratio[i] = _dbOf(amp[i] / d);
        up[i] = _dbOf(1.0 + curves.tolerance[i] / d);
        down[i] = _dbOf(math.max(1.0 - curves.tolerance[i] / d, 1e-12));
        if (up[i].isFinite && up[i].abs() > reach) reach = up[i].abs();
        if (down[i].isFinite && down[i].abs() > reach) reach = down[i].abs();
      }
      traces.add(Trace(curves.f, ratio, scheme.primary, width: 1.2));
      traces.add(Trace(curves.f, up, tolerance, width: 1.0, dashed: true));
      traces.add(Trace(curves.f, down, tolerance, width: 1.0, dashed: true));
      // The tolerance is a curve, not a rectangle, so it is not a Corridor;
      // the two dashed lines above carry it.
    }

    // The target itself, at 0 dB by construction.
    final limits = Float64List.fromList([0, c.fs / 2]);
    traces.add(Trace(limits, Float64List.fromList([0, 0]), tolerance,
        width: 1.4, dashed: true));

    return LinePlot(
      title: 'ripple against target, for bands with a non-zero target',
      traces: traces,
      corridors: corridors,
      xLabel: 'frequency',
      yLabel: 'gain error (dB)',
      xRange: (0, c.fs / 2),
      yRange: reach > 0 ? (-1.6 * reach, 1.6 * reach) : null,
      height: 150,
      empty: c.liveBands.isEmpty ? 'every band targets zero' : null,
    );
  }
}

class _ErrorPlot extends StatelessWidget {
  const _ErrorPlot({required this.controller});
  final DesignController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final res = c.firResult!;
    final eff = c.firEffective!;
    final scheme = Theme.of(context).colorScheme;

    // One trace per band, so the transition gaps are not joined up.
    final traces = <Trace>[];
    var start = 0;
    for (var i = 1; i <= res.gridBand.length; i++) {
      if (i == res.gridBand.length || res.gridBand[i] != res.gridBand[start]) {
        traces.add(Trace(
          Float64List.sublistView(res.gridF, start, i),
          Float64List.sublistView(eff.gridE, start, i),
          scheme.secondary,
          width: 1.1,
        ));
        start = i;
      }
    }

    var reach = res.delta.abs();
    for (final v in eff.gridE) {
      if (v.abs() > reach) reach = v.abs();
    }
    final delta = res.delta.abs();
    final limits = Float64List.fromList([0, c.fs / 2]);
    traces.add(Trace(limits, Float64List.fromList([delta, delta]),
        scheme.onSurface.withValues(alpha: 0.45),
        width: 1.0, dashed: true));
    traces.add(Trace(limits, Float64List.fromList([-delta, -delta]),
        scheme.onSurface.withValues(alpha: 0.45),
        width: 1.0, dashed: true));

    return LinePlot(
      title: 'W(f)·[D(f) − A(f)]   —   δ = ${delta.toStringAsExponential(4)}',
      traces: traces,
      xLabel: 'frequency',
      yLabel: 'weighted error',
      xRange: (0, c.fs / 2),
      yRange: (-1.6 * reach, 1.6 * reach),
      height: 180,
    );
  }
}

double _dbOf(double x) => 20 * math.log(math.max(x.abs(), 1e-12)) / math.ln10;

String _short(double v) =>
    v == v.roundToDouble() && v.abs() < 1e15 ? v.toStringAsFixed(0) : '$v';
