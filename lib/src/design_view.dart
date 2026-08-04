/// The filter drawn as the thing you would actually build.
///
/// Adders, unit delays and multipliers, each labelled with the constant that
/// goes into it. Everything is laid out in a 0..1 box in both directions and
/// then mapped onto whatever size the pane is, so the picture does not distort
/// when the split is dragged; the symbols themselves are sized in pixels, so
/// they stay legible while the wiring stretches.
///
/// The structures drawn are the ones the exports emit and the models run: the
/// IIR as a cascade of transposed direct form II biquads, the FIR as a tapped
/// delay line into one accumulator. If the picture and the coefficients ever
/// disagree, the picture is wrong.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'fir_core.dart' as fc;
import 'format.dart';
import 'labels.dart';
import 'iir_core.dart' as ic;

/// The colours the diagram is drawn in.
///
/// Held rather than hard-coded because the symbols punch holes in the sheet --
/// an adder, a delay box and a multiplier are all drawn filled, so that the
/// wire behind them does not show through -- and on a dark theme that fill has
/// to be the dark background, not white. The wire and gain colours are lifted
/// for the same reason: #555 on near-black is invisible.
class DesignPalette {
  const DesignPalette({
    required this.wire,
    required this.gain,
    required this.dead,
    required this.fill,
    required this.text,
    required this.boxFill,
    required this.boxLine,
  });

  /// What the light theme has always used, and matplotlib's before it.
  factory DesignPalette.light(Color text) => DesignPalette(
        wire: const Color(0xFF555555),
        gain: const Color(0xFF1F77B4),
        dead: const Color(0xFFC8C8C8),
        fill: const Color(0xFFFFFFFF),
        text: text,
        boxFill: const Color(0xFFEAF2FA),
        boxLine: const Color(0xFF1F77B4),
      );

  factory DesignPalette.dark(Color text, Color surface) => DesignPalette(
        wire: const Color(0xFFB0B0B0),
        gain: const Color(0xFF69B3E7),
        dead: const Color(0xFF5A5A5A),
        fill: surface,
        text: text,
        boxFill: const Color(0xFF17384F),
        boxLine: const Color(0xFF69B3E7),
      );

  factory DesignPalette.of(ThemeData theme) =>
      theme.brightness == Brightness.dark
          ? DesignPalette.dark(
              theme.colorScheme.onSurface, theme.colorScheme.surface)
          : DesignPalette.light(theme.colorScheme.onSurface);

  final Color wire;
  final Color gain;

  /// For a branch whose coefficient is exactly zero: drawn, but faded.
  final Color dead;

  /// What a symbol is filled with, to hide the wire it sits on.
  final Color fill;
  final Color text;
  final Color boxFill;
  final Color boxLine;
}

/// How many taps are drawn before the middle is replaced by a break.
const int maxDrawnTaps = 13;

class DesignView extends StatelessWidget {
  const DesignView({super.key, this.fir, this.iir});

  final fc.RemezResult? fir;
  final ic.IIRResult? iir;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: CustomPaint(
        size: Size.infinite,
        painter: _DesignPainter(
            fir: fir,
            iir: iir,
            palette: DesignPalette.of(Theme.of(context)),
            fontFamily: Theme.of(context).textTheme.bodySmall?.fontFamily),
      ),
    );
  }
}

class _DesignPainter extends CustomPainter {
  _DesignPainter(
      {required this.fir,
      required this.iir,
      required this.palette,
      required this.fontFamily});

  final fc.RemezResult? fir;
  final ic.IIRResult? iir;
  final DesignPalette palette;

  /// Named explicitly; a painter inherits no text style of its own.
  final String? fontFamily;

  @override
  void paint(Canvas canvas, Size size) {
    final c = _Sheet(canvas, size, palette, fontFamily);
    if (iir != null) {
      _drawIir(c, iir!);
    } else if (fir != null) {
      _drawFir(c, fir!);
    }
  }

  @override
  bool shouldRepaint(covariant _DesignPainter old) =>
      old.fir != fir ||
      old.iir != iir ||
      old.palette != palette ||
      old.fontFamily != fontFamily;
}

/// A rectangle of the unit sheet, with y running *up* from [y0].
///
/// Not a [Rect]: Flutter's has `bottom` as the larger y, because its space runs
/// down the screen. This one is in the sheet's coordinates, where a biquad's
/// rows are quoted as fractions from its own bottom edge.
class _Box {
  const _Box(this.x0, this.y0, this.w, this.h);
  final double x0;
  final double y0;
  final double w;
  final double h;

  double x(double u) => x0 + u * w;
  double y(double v) => y0 + v * h;
}

/// The drawing surface: a unit box mapped onto the canvas, plus the symbols.
class _Sheet {
  _Sheet(this.canvas, this.size, this.palette, this.fontFamily);
  final Canvas canvas;
  final Size size;
  final DesignPalette palette;
  final String? fontFamily;

  Offset at(double u, double v) => Offset(u * size.width, (1 - v) * size.height);

  void line(double x1, double y1, double x2, double y2,
      {Color? colour, double width = 1.0}) {
    canvas.drawLine(
        at(x1, y1),
        at(x2, y2),
        Paint()
          ..color = colour ?? palette.wire
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round);
  }

  /// A line with a head at the far end, pulled back by [shrinkB] pixels so it
  /// stops at the edge of whatever it points into rather than inside it.
  void arrow(double x1, double y1, double x2, double y2,
      {Color? colour,
      double width = 1.0,
      double shrinkA = 0,
      double shrinkB = 0}) {
    var a = at(x1, y1);
    var b = at(x2, y2);
    final d = b - a;
    final len = d.distance;
    if (len < 0.001) return;
    final unit = d / len;
    a += unit * shrinkA;
    b -= unit * shrinkB;
    if ((b - a).distance < 0.5) return;
    final ink = colour ?? palette.wire;
    final paint = Paint()
      ..color = ink
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(a, b, paint);
    const head = 4.5;
    final back = b - unit * head;
    final side = Offset(-unit.dy, unit.dx) * (head * 0.45);
    canvas.drawPath(
        Path()
          ..moveTo(b.dx, b.dy)
          ..lineTo(back.dx + side.dx, back.dy + side.dy)
          ..lineTo(back.dx - side.dx, back.dy - side.dy)
          ..close(),
        Paint()..color = ink);
  }

  void node(double x, double y, {Color? colour}) =>
      canvas.drawCircle(at(x, y), 1.8, Paint()..color = colour ?? palette.wire);

  /// A summing junction: a circle with a plus in it.
  ///
  /// The plus is two strokes rather than a glyph. At five pixels across, a `+`
  /// laid out as text carries enough leading to fill the circle solid.
  void adder(double x, double y, double radius, {Color? colour}) {
    final p = at(x, y);
    canvas.drawCircle(p, radius, Paint()..color = palette.fill);
    final stroke = Paint()
      ..color = colour ?? palette.wire
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(p, radius, stroke);
    final arm = radius * 0.55;
    canvas.drawLine(p - Offset(arm, 0), p + Offset(arm, 0), stroke);
    canvas.drawLine(p - Offset(0, arm), p + Offset(0, arm), stroke);
  }

  void delay(double x, double y, double fontSize) {
    final p = at(x, y);
    final painter = _layout('z⁻¹', fontSize, palette.wire);
    final box = Rect.fromCenter(
        center: p, width: painter.width + 9, height: painter.height + 5);
    final rr = RRect.fromRectAndRadius(box, const Radius.circular(1.5));
    canvas.drawRRect(rr, Paint()..color = palette.fill);
    canvas.drawRRect(
        rr,
        Paint()
          ..color = palette.wire
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9);
    painter.paint(canvas, p - Offset(painter.width / 2, painter.height / 2));
  }

  /// A multiplier triangle pointing the way the signal flows.
  void gain(double x, double y, String label, double fontSize,
      {String facing = 'right', double dy = 7, Color? colour}) {
    final p = at(x, y);
    final ink = colour ?? palette.gain;
    const r = 5.0;
    final angle = switch (facing) {
      'left' => math.pi,
      'down' => math.pi / 2,
      _ => 0.0,
    };
    Offset corner(double a) =>
        p + Offset(math.cos(angle + a) * r, math.sin(angle + a) * r);
    final path = Path()..moveTo(corner(0).dx, corner(0).dy);
    path.lineTo(corner(2.4).dx, corner(2.4).dy);
    path.lineTo(corner(-2.4).dx, corner(-2.4).dy);
    path.close();
    canvas.drawPath(path, Paint()..color = palette.fill);
    canvas.drawPath(
        path,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0);
    if (label.isEmpty) return;
    final painter = _layout(label, fontSize, ink);
    canvas.drawRect(
        Rect.fromLTWH(p.dx - painter.width / 2, p.dy - dy - painter.height / 2,
            painter.width, painter.height),
        Paint()..color = const Color(0x00000000));
    painter.paint(
        canvas,
        Offset(p.dx - painter.width / 2,
            p.dy - dy - (dy > 0 ? painter.height : 0)));
  }

  void label(double x, double y, String value, double fontSize,
      {bool centre = false,
      bool right = false,
      bool middle = true,
      Color? colour,
      double dx = 0,
      double dy = 0,
      double rotate = 0}) {
    _text(at(x, y) + Offset(dx, dy), value, fontSize, colour ?? palette.text,
        centre: centre, right: right, middle: middle, rotate: rotate);
  }

  void _text(Offset p, String value, double fontSize, Color colour,
      {bool centre = false,
      bool right = false,
      bool middle = false,
      double rotate = 0}) {
    final painter = _layout(value, fontSize, colour);
    var dx = 0.0;
    if (centre) dx = -painter.width / 2;
    if (right) dx = -painter.width;
    final dy = middle ? -painter.height / 2 : 0.0;
    if (rotate == 0) {
      painter.paint(canvas, p + Offset(dx, dy));
      return;
    }
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(rotate);
    painter.paint(canvas, Offset(dx, dy));
    canvas.restore();
  }

  TextPainter _layout(String value, double fontSize, Color colour) =>
      TextPainter(
        text: TextSpan(
            text: value,
            style: TextStyle(
                color: colour, fontSize: fontSize, fontFamily: fontFamily)),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
}

// ---------------------------------------------------------------------------
// the IIR: a cascade of biquads
// ---------------------------------------------------------------------------

/// One second-order section, as transposed direct form II.
///
/// This is the structure `sosFilter` actually runs and the one the exported
/// coefficients are meant for: two state variables, the numerator taps feeding
/// forward off the input and the denominator taps feeding back off the output,
/// so that
///
///     y[n]  = b0 x[n] + s1[n-1]
///     s1[n] = b1 x[n] - a1 y[n] + s2[n-1]
///     s2[n] = b2 x[n] - a2 y[n]
///
/// A first-order section reaches here padded with zeros; those branches are
/// drawn in grey rather than dropped, so that the picture and the six exported
/// numbers stay in step.
void _drawBiquad(_Sheet c, List<double> row, _Box box, String inLabel,
    String outLabel, String title, double fontSize) {
  final b0 = row[0] / row[3];
  final b1 = row[1] / row[3];
  final b2 = row[2] / row[3];
  final a1 = row[4] / row[3];
  final a2 = row[5] / row[3];

  double x(double u) => box.x(u);
  double y(double v) => box.y(v);

  const inX = 0.235, addX = 0.575, outX = 0.825;
  const fwdX = 0.395, fbkX = 0.705;
  const rows = [0.76, 0.45, 0.14];
  const delays = [0.605, 0.295];
  final addSize = math.max(4.0, fontSize * 0.75);

  c.label(x(0.5), y(0.99), title, fontSize, centre: true);

  // The input bus, and the feed-forward branches off it.
  c.label(x(0.0), y(rows[0]), inLabel, fontSize);
  c.arrow(x(0.13), y(rows[0]), x(inX), y(rows[0]));
  c.line(x(inX), y(rows[2]), x(inX), y(rows[0]));
  for (final v in rows.skip(1)) {
    c.node(x(inX), y(v));
  }
  const forwardNames = ['b0', 'b1', 'b2'];
  final forward = [b0, b1, b2];
  for (var i = 0; i < 3; i++) {
    final dead = forward[i] == 0.0;
    final colour = dead ? c.palette.dead : c.palette.wire;
    c.arrow(x(inX), y(rows[i]), x(addX), y(rows[i]),
        colour: colour, shrinkB: addSize);
    c.gain(x(fwdX), y(rows[i]),
        '${forwardNames[i]} = ${_signed(forward[i])}', fontSize,
        colour: dead ? c.palette.dead : c.palette.gain);
  }

  // The accumulator chain, running upward through the two delays.
  for (final v in rows) {
    c.adder(x(addX), y(v), addSize);
  }
  for (var i = 0; i < 2; i++) {
    c.arrow(x(addX), y(rows[i + 1]), x(addX), y(rows[i]),
        shrinkA: addSize, shrinkB: addSize);
    c.delay(x(addX), y(delays[i]), fontSize);
  }

  // The output bus, and the feedback branches off it.
  c.arrow(x(addX), y(rows[0]), x(0.99), y(rows[0]), shrinkA: addSize);
  c.label(x(0.99), y(rows[0]), outLabel, fontSize, right: true, dy: -8);
  c.node(x(outX), y(rows[0]));
  c.line(x(outX), y(rows[2]), x(outX), y(rows[0]));
  const backNames = ['a1', 'a2'];
  final back = [a1, a2];
  for (var i = 0; i < 2; i++) {
    final dead = back[i] == 0.0;
    final colour = dead ? c.palette.dead : c.palette.wire;
    c.node(x(outX), y(rows[i + 1]));
    c.arrow(x(outX), y(rows[i + 1]), x(addX), y(rows[i + 1]),
        colour: colour, shrinkB: addSize);
    c.gain(x(fbkX), y(rows[i + 1]),
        '−${backNames[i]} = ${_signed(-back[i])}', fontSize,
        facing: 'left', dy: -7, colour: dead ? c.palette.dead : c.palette.gain);
  }
}

/// The section running order, along the top of the design view.
void _drawCascadeStrip(_Sheet c, int n, double y, double fontSize) {
  final xs = n > 1
      ? [for (var i = 0; i < n; i++) 0.14 + (0.86 - 0.14) * i / (n - 1)]
      : [0.5];
  c.label(0.02, y, 'x[n]', fontSize);
  c.label(0.98, y, 'y[n]', fontSize, right: true);
  final step = n > 1 ? xs[1] - xs[0] : 0.3;
  final gap = math.min(0.025, 0.35 * step); // clearance around each box
  c.arrow(0.062, y, xs[0] - gap, y);
  c.arrow(xs[n - 1] + gap, y, 0.955, y);
  for (var i = 0; i < n; i++) {
    final p = c.at(xs[i], y);
    final painter = c._layout('\$i', fontSize, c.palette.boxLine);
    final box = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: p, width: painter.width + 12, height: painter.height + 6),
        const Radius.circular(4));
    c.canvas.drawRRect(box, Paint()..color = c.palette.boxFill);
    c.canvas.drawRRect(
        box,
        Paint()
          ..color = c.palette.boxLine
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9);
    painter.paint(
        c.canvas, p - Offset(painter.width / 2, painter.height / 2));
    if (i > 0) c.arrow(xs[i - 1] + gap, y, xs[i] - gap, y);
  }
}

void _drawIir(_Sheet c, ic.IIRResult res) {
  final sos = res.sos;
  final n = sos.length;
  final cols = n <= 2 ? 1 : (n <= 8 ? 2 : 3);
  final rows = (n / cols).ceil();
  final fontSize = (9.5 - 1.0 * rows).clamp(4.5, 8.5).toDouble();

  c.label(
      0.5,
      0.995,
      '${labelOf(res.approximation)} ${res.response}, order ${res.order}'
      '  —  $n biquad${n != 1 ? 's' : ''} in cascade, '
      'each transposed direct form II',
      9,
      centre: true);
  _drawCascadeStrip(c, n, 0.925, math.max(fontSize, 6.5));

  const top = 0.885;
  final cw = 1.0 / cols;
  final ch = top / rows;
  for (var i = 0; i < n; i++) {
    final r = i ~/ cols;
    final col = i % cols;
    final box = _Box(col * cw + 0.012, top - (r + 1) * ch + 0.02 * ch,
        cw - 0.024, ch * 0.94);
    final poles = _polesOf(sos[i]);
    final radius = poles.map((p) => p.$1).reduce(math.max);
    final freq = poles.map((p) => p.$2).reduce(math.max) *
        res.fs /
        (2.0 * math.pi);
    _drawBiquad(
      c,
      sos[i].toList(),
      box,
      i == 0 ? 'x[n]' : 'w$i[n]',
      i == n - 1 ? 'y[n]' : 'w${i + 1}[n]',
      'section $i   |p| = ${formatF(radius, 4)}   '
          'f = ${formatG(freq, precision: 4)}',
      fontSize,
    );
  }
}

/// The radius and angle of each pole of one section.
List<(double, double)> _polesOf(List<double> row) {
  final a = row[3], b = row[4], cc = row[5];
  if (a == 0) return [(0.0, 0.0)];
  final disc = b * b - 4 * a * cc;
  if (disc >= 0) {
    final root = math.sqrt(disc);
    final p1 = (-b + root) / (2 * a);
    final p2 = (-b - root) / (2 * a);
    return [
      (p1.abs(), p1 < 0 ? math.pi : 0.0),
      (p2.abs(), p2 < 0 ? math.pi : 0.0),
    ];
  }
  final re = -b / (2 * a);
  final im = math.sqrt(-disc) / (2 * a);
  final r = math.sqrt(re * re + im * im);
  final angle = math.atan2(im.abs(), re);
  return [(r, angle), (r, angle)];
}

// ---------------------------------------------------------------------------
// the FIR: a tapped delay line
// ---------------------------------------------------------------------------

/// Which taps get a column, and which are covered by the break.
///
/// A null entry is the column standing in for the taps left out; the second
/// value is the inclusive range those are, for the caption, or null when the
/// whole filter fits.
(List<int?>, (int, int)?) firColumns(int n) {
  if (n <= maxDrawnTaps) return ([for (var i = 0; i < n; i++) i], null);
  final half = maxDrawnTaps ~/ 2;
  return (
    [
      for (var i = 0; i < half; i++) i,
      null,
      for (var i = n - half; i < n; i++) i,
    ],
    (half, n - half - 1)
  );
}

/// The FIR filter as a tapped delay line.
///
/// A long filter cannot be drawn tap by tap and stay readable, so past
/// [maxDrawnTaps] the middle is replaced by a break and the caption says
/// exactly which taps are missing from the picture.
void _drawFir(_Sheet c, fc.RemezResult res) {
  final n = res.numtaps;
  final (cols, omitted) = firColumns(n);

  final fontSize = (90.0 / cols.length).clamp(6.0, 9.0).toDouble();
  final xs = [
    for (var i = 0; i < cols.length; i++)
      0.085 + (0.93 - 0.085) * (cols.length == 1 ? 0.5 : i / (cols.length - 1))
  ];
  const yTop = 0.87, yGain = 0.68, ySum = 0.12;
  final addSize = math.max(4.0, fontSize * 0.8);

  c.label(
      0.5,
      0.985,
      'Type ${res.ftype} ${res.symmetry.name} FIR, N = ${res.numtaps}'
      '  —  direct form: a tapped delay line into one accumulator',
      9,
      centre: true);
  c.label(0.005, yTop, 'x[n]', fontSize);
  c.label(0.995, ySum, 'y[n]', fontSize, right: true);
  c.arrow(0.042, yTop, xs[0], yTop);

  for (var i = 0; i < cols.length; i++) {
    final x = xs[i];
    final k = cols[i];
    if (i > 0) {
      c.arrow(xs[i - 1], yTop, x, yTop);
      c.arrow(xs[i - 1], ySum, x, ySum,
          shrinkA: i > 1 ? addSize : 0.0, shrinkB: k != null ? addSize : 0.0);
      if (cols[i - 1] != null && k != null) {
        c.delay((xs[i - 1] + x) / 2, yTop, fontSize);
      }
    }
    if (k == null) {
      // The break standing in for the rest.
      for (final y in [yTop, ySum]) {
        final p = c.at(x, y);
        c.canvas.drawRect(Rect.fromCenter(center: p, width: 16, height: 12),
            Paint()..color = c.palette.fill);
        c.label(x, y, '⋯', fontSize + 4, centre: true, colour: c.palette.wire);
      }
      continue;
    }
    c.node(x, yTop);
    c.arrow(x, yTop, x, ySum, shrinkB: i > 0 ? addSize : 0.0);
    c.gain(x, yGain, '', fontSize, facing: 'down');
    c.label(x, yGain, 'h$k', fontSize,
        right: true, dx: -8, colour: c.palette.gain);
    c.label(x, 0.5 * (yGain + ySum), _signed(res.h[k]), fontSize - 0.5,
        centre: true, dx: 4, colour: c.palette.gain, rotate: -math.pi / 2);
    if (i > 0) c.adder(x, ySum, addSize);
  }
  c.arrow(xs[xs.length - 1], ySum, 0.958, ySum, shrinkA: addSize);

  final notes = <String>[];
  if (omitted != null) {
    notes.add('taps ${omitted.$1} … ${omitted.$2} are not drawn');
  }
  final sign = res.symmetry == fc.Symmetry.symmetric
      ? 'h[n] = h[N−1−n]'
      : 'h[n] = −h[N−1−n]';
  notes.add('$sign, so the folded form needs only '
      '${(n + 1) ~/ 2} multipliers');
  c.label(0.5, 0.035, notes.join(';   '), 8,
      centre: true, colour: c.palette.wire);
}

/// Python's `%+.6g`: a sign always, six significant digits.
String _signed(double v) {
  final body = formatG(v, precision: 6);
  return body.startsWith('-') ? body : '+$body';
}
