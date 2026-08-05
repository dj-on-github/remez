/// The pole-zero plot, drawn on the complex z plane.
///
/// The one picture that says whether a recursive filter is stable: every pole
/// inside the unit circle or it is not. It earns its place next to the response
/// plots in fixed point, where the design's poles and the poles the rounded
/// coefficients actually give are drawn together -- a pole that rounding has
/// pushed onto or over the circle is then something you see rather than
/// something you infer from a magnitude plot behaving oddly.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'complex.dart';

/// One filter's singularities: where the response goes to zero, and where it
/// goes to infinity.
class ZSet {
  const ZSet({
    required this.zeros,
    required this.poles,
    required this.colour,
    this.label,
    this.muted = false,
  });

  final List<Complex> zeros;
  final List<Complex> poles;
  final Color colour;

  /// Named in the key, when there is more than one set to tell apart.
  final String? label;

  /// Drawn thinner and smaller: the reference set, under the one that matters.
  final bool muted;
}

class ZPlanePlot extends StatelessWidget {
  const ZPlanePlot({
    super.key,
    required this.title,
    required this.sets,
    this.height = 300,
    this.note,
  });

  final String title;
  final List<ZSet> sets;
  final double height;

  /// A line under the title: what the plot cannot show, or a warning about it.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelLarge),
          if (note != null)
            Text(note!,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
          SizedBox(
            height: height,
            child: CustomPaint(
              size: Size.infinite,
              painter: _ZPainter(
                sets: sets,
                fontFamily: theme.textTheme.bodySmall?.fontFamily,
                foreground: theme.colorScheme.onSurface,
                grid: theme.colorScheme.onSurface.withValues(alpha: 0.14),
                circle: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                unstable: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZPainter extends CustomPainter {
  _ZPainter({
    required this.sets,
    required this.fontFamily,
    required this.foreground,
    required this.grid,
    required this.circle,
    required this.unstable,
  });

  final List<ZSet> sets;
  final String? fontFamily;
  final Color foreground;
  final Color grid;
  final Color circle;
  final Color unstable;

  @override
  void paint(Canvas canvas, Size size) {
    // Square, and centred in whatever it is given: the z plane is isotropic and
    // a stretched unit circle is an ellipse, which reads as a design decision
    // rather than as an axis scaling.
    const margin = 26.0;
    final side = math.min(size.width, size.height) - 2 * margin;
    if (side <= 8) return;
    final plot = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: side,
        height: side);

    // Always enough room for the unit circle, and enough for the roots when
    // they run wider. Beyond a few radii the interesting part would be a dot in
    // the middle, so the view stops and says how many are outside it.
    var extent = 1.18;
    for (final set in sets) {
      for (final v in [...set.zeros, ...set.poles]) {
        if (!v.isFinite) continue;
        final r = math.max(v.re.abs(), v.im.abs()) * 1.12;
        if (r > extent && r <= 4.0) extent = r;
      }
    }

    double sx(double re) => plot.center.dx + re / extent * (side / 2);
    double sy(double im) => plot.center.dy - im / extent * (side / 2);

    final axis = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(plot.left, sy(0)), Offset(plot.right, sy(0)), axis);
    canvas.drawLine(
        Offset(sx(0), plot.top), Offset(sx(0), plot.bottom), axis);

    canvas.drawCircle(
        Offset(sx(0), sy(0)),
        side / 2 / extent,
        Paint()
          ..color = circle
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);

    canvas.drawRect(
        plot,
        Paint()
          ..color = grid
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);

    // Ticks at the unit points rather than labels: the numbers would land on
    // the circle, which is exactly where a filter puts most of its zeros.
    for (final t in [-1.0, 1.0]) {
      canvas.drawLine(
          Offset(sx(t), sy(0) - 3), Offset(sx(t), sy(0) + 3), axis);
      canvas.drawLine(
          Offset(sx(0) - 3, sy(t)), Offset(sx(0) + 3, sy(t)), axis);
    }
    _text(canvas, 'Re(z)', Offset(plot.right - 4, plot.bottom + 6),
        anchorRight: true, muted: true);
    canvas.save();
    canvas.translate(plot.left - 14, plot.top + 4);
    canvas.rotate(-math.pi / 2);
    _text(canvas, 'Im(z)', Offset.zero, anchorRight: true, muted: true);
    canvas.restore();

    canvas.save();
    canvas.clipRect(plot.inflate(1));

    var offView = 0;
    for (final set in sets) {
      final scale = set.muted ? 0.8 : 1.0;
      final stroke = set.muted ? 1.1 : 1.6;
      for (final entry in [(set.zeros, true), (set.poles, false)]) {
        for (final cluster in _cluster(entry.$1, extent)) {
          final v = cluster.at;
          if (!v.isFinite ||
              v.re.abs() > extent * 1.02 ||
              v.im.abs() > extent * 1.02) {
            offView += cluster.count;
            continue;
          }
          // A pole outside the circle is the failure this plot exists to show,
          // so it is coloured as one whatever set it came from.
          final ink = !entry.$2 && v.abs >= 1.0 ? unstable : set.colour;
          final at = Offset(sx(v.re), sy(v.im));
          if (entry.$2) {
            _zero(canvas, at, 4.6 * scale, ink, stroke);
          } else {
            _pole(canvas, at, 4.4 * scale, ink, stroke);
          }
          if (cluster.count > 1) {
            _text(canvas, '×${cluster.count}',
                at + Offset(6 * scale, -12), colour: ink);
          }
        }
      }
    }
    canvas.restore();

    // What the shapes mean, drawn rather than written: the characters for a
    // ring and a cross are not in every font, and a key that renders as two
    // empty boxes is worse than none.
    var y = plot.top + 10;
    _zero(canvas, Offset(plot.left + 10, y), 4.0, foreground, 1.4);
    _text(canvas, 'zero', Offset(plot.left + 18, y - 6), muted: true);
    _pole(canvas, Offset(plot.left + 50, y), 4.0, foreground, 1.4);
    _text(canvas, 'pole', Offset(plot.left + 58, y - 6), muted: true);
    y += 16;

    // Which colour is which design, when there are two to tell apart.
    for (final set in sets) {
      if (sets.length < 2 || set.label == null) continue;
      canvas.drawLine(
          Offset(plot.left + 6, y),
          Offset(plot.left + 22, y),
          Paint()
            ..color = set.colour
            ..strokeWidth = set.muted ? 1.4 : 2.6);
      _text(canvas, set.label!, Offset(plot.left + 27, y - 6),
          colour: set.colour);
      y += 15;
    }

    if (offView > 0) {
      _text(canvas, '$offView off scale',
          Offset(plot.right - 6, plot.bottom - 14),
          anchorRight: true, muted: true);
    }
  }

  /// An open circle: a zero of the transfer function.
  void _zero(Canvas canvas, Offset at, double r, Color ink, double stroke) {
    canvas.drawCircle(
        at,
        r,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);
  }

  /// A cross: a pole.
  void _pole(Canvas canvas, Offset at, double r, Color ink, double stroke) {
    final paint = Paint()
      ..color = ink
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(at + Offset(-r, -r), at + Offset(r, r), paint);
    canvas.drawLine(at + Offset(-r, r), at + Offset(r, -r), paint);
  }

  /// Group coincident points so a repeated root is annotated rather than drawn
  /// as several markers in the same place looking like one.
  List<({Complex at, int count})> _cluster(List<Complex> values, double extent) {
    final tolerance = extent * 0.012;
    final out = <({Complex at, int count})>[];
    final counts = <int>[];
    for (final v in values) {
      var found = false;
      for (var i = 0; i < out.length; i++) {
        if ((out[i].at - v).abs <= tolerance) {
          counts[i]++;
          out[i] = (at: out[i].at, count: counts[i]);
          found = true;
          break;
        }
      }
      if (!found) {
        out.add((at: v, count: 1));
        counts.add(1);
      }
    }
    return out;
  }

  void _text(Canvas canvas, String value, Offset at,
      {bool centre = false,
      bool anchorRight = false,
      bool muted = false,
      Color? colour}) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: colour ??
              (muted ? foreground.withValues(alpha: 0.7) : foreground),
          fontSize: 10,
          fontFamily: fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx;
    if (centre) dx -= painter.width / 2;
    if (anchorRight) dx -= painter.width;
    painter.paint(canvas, Offset(dx, at.dy));
  }

  @override
  bool shouldRepaint(covariant _ZPainter old) => true;
}
