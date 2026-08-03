/// The plots, drawn straight onto a canvas.
///
/// A chart package would carry a lot of machinery for interaction and styling
/// this does not need, and these are simple line plots over a linear axis. The
/// painters below are a few hundred lines and redraw a thousand-point response
/// without allocating anything but the path.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// One curve on a plot.
class Trace {
  const Trace(this.x, this.y, this.colour,
      {this.width = 1.4, this.dashed = false});
  final Float64List x;
  final Float64List y;
  final Color colour;
  final double width;
  final bool dashed;
}

/// A shaded horizontal band, for a tolerance or a specification corridor.
class Corridor {
  const Corridor(this.x0, this.x1, this.lo, this.hi, this.colour);
  final double x0;
  final double x1;
  final double lo;
  final double hi;
  final Color colour;
}

/// Points drawn as dots, for the extremal frequencies.
class Markers {
  const Markers(this.x, this.y, this.colour, {this.radius = 2.4});
  final Float64List x;
  final Float64List y;
  final Color colour;
  final double radius;
}

class LinePlot extends StatelessWidget {
  const LinePlot({
    super.key,
    required this.title,
    required this.traces,
    required this.xLabel,
    required this.yLabel,
    this.corridors = const [],
    this.markers = const [],
    this.xRange,
    this.yRange,
    this.height = 220,
    this.empty,
  });

  final String title;
  final List<Trace> traces;
  final List<Corridor> corridors;
  final List<Markers> markers;
  final String xLabel;
  final String yLabel;
  final (double, double)? xRange;
  final (double, double)? yRange;
  final double height;

  /// Written across the middle when there is nothing to plot, in place of an
  /// empty frame that looks like a bug.
  final String? empty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelLarge),
          SizedBox(
            height: height,
            child: CustomPaint(
              size: Size.infinite,
              painter: _PlotPainter(
                traces: traces,
                corridors: corridors,
                markers: markers,
                xLabel: xLabel,
                yLabel: yLabel,
                xRange: xRange,
                yRange: yRange,
                empty: empty,
                foreground: theme.colorScheme.onSurface,
                grid: theme.colorScheme.onSurface.withValues(alpha: 0.14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlotPainter extends CustomPainter {
  _PlotPainter({
    required this.traces,
    required this.corridors,
    required this.markers,
    required this.xLabel,
    required this.yLabel,
    required this.xRange,
    required this.yRange,
    required this.empty,
    required this.foreground,
    required this.grid,
  });

  final List<Trace> traces;
  final List<Corridor> corridors;
  final List<Markers> markers;
  final String xLabel;
  final String yLabel;
  final (double, double)? xRange;
  final (double, double)? yRange;
  final String? empty;
  final Color foreground;
  final Color grid;

  static const double leftPad = 54;
  static const double rightPad = 10;
  static const double topPad = 8;
  static const double bottomPad = 30;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(leftPad, topPad, size.width - rightPad,
        size.height - bottomPad);
    if (plot.width <= 4 || plot.height <= 4) return;

    var (x0, x1) = xRange ?? _extent(traces.map((t) => t.x));
    var (y0, y1) = yRange ?? _extent(traces.map((t) => t.y));
    if (x1 <= x0) x1 = x0 + 1;
    if (y1 <= y0) y1 = y0 + 1;

    double sx(double v) => plot.left + (v - x0) / (x1 - x0) * plot.width;
    double sy(double v) => plot.bottom - (v - y0) / (y1 - y0) * plot.height;

    final axis = Paint()
      ..color = grid
      ..strokeWidth = 1;

    // Grid and tick labels.
    for (final t in _ticks(y0, y1)) {
      final y = sy(t);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), axis);
      _text(canvas, _tickLabel(t), Offset(plot.left - 6, y),
          align: TextAlign.right, anchorRight: true);
    }
    for (final t in _ticks(x0, x1)) {
      final x = sx(t);
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), axis);
      _text(canvas, _tickLabel(t), Offset(x, plot.bottom + 4),
          align: TextAlign.center, centre: true);
    }

    canvas.save();
    canvas.clipRect(plot);

    for (final c in corridors) {
      final rect = Rect.fromLTRB(sx(c.x0), sy(c.hi), sx(c.x1), sy(c.lo));
      canvas.drawRect(rect, Paint()..color = c.colour);
    }

    for (final trace in traces) {
      if (trace.x.isEmpty) continue;
      final paint = Paint()
        ..color = trace.colour
        ..strokeWidth = trace.width
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      var started = false;
      for (var i = 0; i < trace.x.length; i++) {
        final v = trace.y[i];
        if (!v.isFinite) {
          started = false;
          continue;
        }
        final p = Offset(sx(trace.x[i]), sy(v.clamp(y0 - 1e6, y1 + 1e6)));
        if (!started) {
          path.moveTo(p.dx, p.dy);
          started = true;
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(trace.dashed ? _dash(path) : path, paint);
    }

    for (final m in markers) {
      final paint = Paint()..color = m.colour;
      for (var i = 0; i < m.x.length; i++) {
        if (!m.y[i].isFinite) continue;
        canvas.drawCircle(Offset(sx(m.x[i]), sy(m.y[i])), m.radius, paint);
      }
    }
    canvas.restore();

    canvas.drawRect(plot, Paint()
      ..color = grid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);

    if (empty != null) {
      _text(canvas, empty!, plot.center,
          align: TextAlign.center, centre: true, muted: true);
    }

    _text(canvas, xLabel, Offset(plot.center.dx, size.height - 14),
        align: TextAlign.center, centre: true, muted: true);
    canvas.save();
    canvas.translate(12, plot.center.dy);
    canvas.rotate(-math.pi / 2);
    _text(canvas, yLabel, Offset.zero,
        align: TextAlign.center, centre: true, muted: true);
    canvas.restore();
  }

  Path _dash(Path source) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final next = math.min(distance + (draw ? 6.0 : 4.0), metric.length);
        if (draw) out.addPath(metric.extractPath(distance, next), Offset.zero);
        distance = next;
        draw = !draw;
      }
    }
    return out;
  }

  void _text(Canvas canvas, String value, Offset at,
      {TextAlign align = TextAlign.left,
      bool centre = false,
      bool anchorRight = false,
      bool muted = false}) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: muted ? foreground.withValues(alpha: 0.7) : foreground,
          fontSize: 10,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx;
    if (centre) dx -= painter.width / 2;
    if (anchorRight) dx -= painter.width;
    canvas.paint(painter, Offset(dx, at.dy - (anchorRight ? 6 : 0)));
  }

  (double, double) _extent(Iterable<Float64List> lists) {
    var lo = double.infinity, hi = double.negativeInfinity;
    for (final list in lists) {
      for (final v in list) {
        if (!v.isFinite) continue;
        if (v < lo) lo = v;
        if (v > hi) hi = v;
      }
    }
    if (!lo.isFinite) return (0, 1);
    return (lo, hi);
  }

  List<double> _ticks(double lo, double hi) {
    final span = hi - lo;
    if (span <= 0) return [lo];
    final raw = span / 5;
    final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor());
    final step = [1.0, 2.0, 2.5, 5.0, 10.0]
            .firstWhere((m) => m * magnitude >= raw, orElse: () => 10.0) *
        magnitude;
    final out = <double>[];
    var t = (lo / step).ceil() * step;
    while (t <= hi + step * 1e-9 && out.length < 20) {
      out.add(t);
      t += step;
    }
    return out;
  }

  String _tickLabel(double v) {
    if (v == 0) return '0';
    final a = v.abs();
    if (a >= 1e5 || a < 1e-3) return v.toStringAsExponential(0);
    if (a >= 100) return v.toStringAsFixed(0);
    if (a >= 1) return v.toStringAsFixed(a % 1 == 0 ? 0 : 1);
    return v.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '');
  }

  @override
  bool shouldRepaint(covariant _PlotPainter old) => true;
}

extension on Canvas {
  void paint(TextPainter painter, Offset at) => painter.paint(this, at);
}

/// The impulse response as a stem plot.
class StemPlot extends StatelessWidget {
  const StemPlot(
      {super.key, required this.values, required this.title, this.height = 150});

  final Float64List values;
  final String title;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelLarge),
          SizedBox(
            height: height,
            child: CustomPaint(
              size: Size.infinite,
              painter: _StemPainter(
                values,
                theme.colorScheme.primary,
                theme.colorScheme.onSurface.withValues(alpha: 0.14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StemPainter extends CustomPainter {
  _StemPainter(this.values, this.colour, this.grid);
  final Float64List values;
  final Color colour;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final plot = Rect.fromLTRB(54, 8, size.width - 10, size.height - 12);
    var lo = 0.0, hi = 0.0;
    for (final v in values) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    if (hi == lo) hi = lo + 1;
    final pad = (hi - lo) * 0.08;
    lo -= pad;
    hi += pad;

    double sx(int i) =>
        plot.left + (values.length == 1 ? 0.5 : i / (values.length - 1)) *
            plot.width;
    double sy(double v) => plot.bottom - (v - lo) / (hi - lo) * plot.height;

    final zero = sy(0);
    canvas.drawLine(Offset(plot.left, zero), Offset(plot.right, zero),
        Paint()..color = grid);
    canvas.drawRect(
        plot,
        Paint()
          ..color = grid
          ..style = PaintingStyle.stroke);

    final stem = Paint()
      ..color = colour
      ..strokeWidth = values.length > 200 ? 0.7 : 1.2;
    final dot = Paint()..color = colour;
    for (var i = 0; i < values.length; i++) {
      final x = sx(i);
      canvas.drawLine(Offset(x, zero), Offset(x, sy(values[i])), stem);
      if (values.length <= 128) {
        canvas.drawCircle(Offset(x, sy(values[i])), 1.8, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StemPainter old) => true;
}
