/// The program's icon, drawn rather than stored.
///
/// The picture is the one thing this program makes that nothing else does: the
/// magnitude response of an equiripple lowpass filter. A flat passband, a steep
/// skirt, and a stopband of equal-height lobes -- the shape the Remez exchange
/// produces and the shape a filter designer recognises immediately.
///
/// An icon is not one drawing. At 256 pixels the passband ripple and the
/// stopband lobes are the point of it; at 16 the same detail is mud, and all
/// that survives is the silhouette -- shelf, cliff, floor. So each size is
/// drawn to suit itself, with the detail turned down as the canvas shrinks,
/// rather than drawn once and resampled.
///
/// A port of the Python tool's `make_icon.py`: the same palette, the same
/// proportions, the same thresholds. `tool/make_icons.dart` renders it into
/// every size the platforms ask for.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const Color iconBackground = Color(0xFF112038); // deep navy, so the curve can
const Color iconPanel = Color(0xFF192E4E); //      be bright; a lifted plot area
const Color iconFill = Color(0xFF269EF0); //       the area under the response
const Color iconCurve = Color(0xFFECF8FF); //      the response itself
const Color iconBaseline = Color(0xFF486896);

/// How much of the drawing survives at a given size.
///
/// Below about twenty pixels a lobe is one pixel of grey, so the stopband is
/// drawn flat and only the silhouette is left. The thresholds are where the
/// features stop being legible, not round numbers.
class IconDetail {
  const IconDetail({
    required this.lobes,
    required this.ripple,
    required this.curve,
    required this.corner,
    required this.margin,
    required this.panel,
  });

  /// How many stopband lobes to draw; zero for a flat floor.
  final int lobes;

  /// Passband ripple amplitude, in units of the plot height.
  final double ripple;

  /// Stroke width of the response, as a fraction of the canvas.
  final double curve;

  final double corner;
  final double margin;
  final bool panel;

  factory IconDetail.forSize(int size) {
    // Below 24 pixels the white stroke would be as thick as the shape it sits
    // on, so the silhouette carries the icon on its own.
    if (size <= 20) {
      return const IconDetail(
          lobes: 0,
          ripple: 0.0,
          curve: 0.0,
          corner: 0.16,
          margin: 0.055,
          panel: false);
    }
    if (size <= 24) {
      return const IconDetail(
          lobes: 2,
          ripple: 0.0,
          curve: 0.0,
          corner: 0.17,
          margin: 0.06,
          panel: false);
    }
    if (size <= 32) {
      return const IconDetail(
          lobes: 2,
          ripple: 0.0,
          curve: 0.045,
          corner: 0.18,
          margin: 0.075,
          panel: false);
    }
    if (size <= 64) {
      return const IconDetail(
          lobes: 3,
          ripple: 0.018,
          curve: 0.035,
          corner: 0.19,
          margin: 0.095,
          panel: true);
    }
    return const IconDetail(
        lobes: 3,
        ripple: 0.024,
        curve: 0.026,
        corner: 0.20,
        margin: 0.11,
        panel: true);
  }
}

/// The curve, in unit coordinates: x left to right, y up from the floor.
///
/// Not a real design run -- an icon needs the *idea* of an equiripple response,
/// with the transition where the eye wants it and lobes big enough to see. The
/// proportions are those of a real lowpass all the same: a passband about twice
/// the width of the transition, and a stopband floor near the bottom.
List<Offset> iconResponse(IconDetail detail, {int steps = 800}) {
  const passEdge = 0.44, stopEdge = 0.60;
  const passLevel = 0.88, floor = 0.17;
  const lobeHeight = 0.125;

  final points = <Offset>[];
  for (var i = 0; i <= steps; i++) {
    final x = i / steps;
    double y;
    if (x <= passEdge) {
      y = passLevel;
      if (detail.ripple != 0) {
        // Two cycles of passband ripple, faded out at the band edge so the
        // curve leaves the shelf smoothly.
        final phase = math.pi * 2.0 * 2.0 * (x / passEdge);
        y += detail.ripple * math.cos(phase);
      }
    } else if (x < stopEdge) {
      // A smooth skirt: a raised cosine reads as steeper than a straight line
      // of the same width.
      final t = (x - passEdge) / (stopEdge - passEdge);
      y = floor + (passLevel - floor) * 0.5 * (1.0 + math.cos(math.pi * t));
    } else {
      y = floor;
      if (detail.lobes > 0) {
        final t = (x - stopEdge) / (1.0 - stopEdge);
        // Equal-height lobes, which is the whole point of the algorithm.
        y += lobeHeight * (math.sin(math.pi * detail.lobes * t)).abs();
      }
    }
    points.add(Offset(x, y));
  }
  return points;
}

/// How much of a maskable icon is guaranteed to survive the platform's mask.
///
/// A maskable icon is cropped to whatever shape the launcher wants -- a circle,
/// a squircle, a rounded square -- so the drawing has to sit inside the circle
/// of 80% diameter that the specification promises, and the background has to
/// reach every corner.
const double _maskableSafe = 0.78;

/// Paint one icon at [size] logical pixels square.
///
/// With [maskable] the corners are square and the drawing is shrunk into the
/// safe circle: the launcher rounds it off itself, and an icon that has already
/// been rounded comes out with the corners cut twice and a gap of background
/// where the mask and the drawing disagree.
void paintIcon(Canvas canvas, int size, {bool maskable = false}) {
  final detail = IconDetail.forSize(size);
  final big = size.toDouble();

  final corner = maskable ? 0.0 : detail.corner * big;
  canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, big, big), Radius.circular(corner)),
      Paint()..color = iconBackground);

  if (maskable) {
    // Draw the rest at the safe size, centred.
    final inset = big * (1 - _maskableSafe) / 2;
    canvas.save();
    canvas.translate(inset, inset);
    canvas.scale(_maskableSafe);
  }

  // The plot area, inset from the rounded edge. The inset panel is only drawn
  // where it is big enough to read as one; at small sizes it just muddies two
  // dark tones together.
  final margin = detail.margin * big;
  final left = margin, right = big - margin;
  final top = margin * 1.15, bottom = big - margin * 1.15;
  final spanX = right - left, spanY = bottom - top;
  if (detail.panel) {
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(left, top, right, bottom),
            Radius.circular(corner * 0.35)),
        Paint()..color = iconPanel);
  }

  Offset place(Offset p) =>
      Offset(left + p.dx * spanX, bottom - p.dy * spanY);

  final curve = iconResponse(detail).map(place).toList();
  final floorY = place(Offset.zero).dy;

  // Fill under the curve, then lay the curve over the top of it.
  final area = Path()..moveTo(curve.first.dx, floorY);
  for (final p in curve) {
    area.lineTo(p.dx, p.dy);
  }
  area
    ..lineTo(curve.last.dx, floorY)
    ..close();
  canvas.drawPath(area, Paint()..color = iconFill);

  // The response, drawn over the fill. No highlight along the top: a second
  // line a hair below the first only reads as a curve out of focus.
  if (detail.curve != 0) {
    final stroke = Path()..moveTo(curve.first.dx, curve.first.dy);
    for (final p in curve.skip(1)) {
      stroke.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        stroke,
        Paint()
          ..color = iconCurve
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(detail.curve * big, 1.0)
          // Round joins, butt ends: PIL's `joint="curve"` rounds the corners
          // of the polyline but leaves the two ends square, and a round cap
          // here makes the curve overhang the plot area on the left.
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.butt);
  }

  // A baseline, so the shape sits on something rather than floating.
  canvas.drawLine(
      Offset(left, floorY),
      Offset(right, floorY),
      Paint()
        ..color = iconBaseline
        ..strokeWidth = math.max(0.014 * big, 0.5));

  if (maskable) canvas.restore();
}

/// Render the icon to an image of [size] square.
Future<ui.Image> renderIcon(int size, {bool maskable = false}) {
  final recorder = ui.PictureRecorder();
  paintIcon(Canvas(recorder), size, maskable: maskable);
  return recorder.endRecording().toImage(size, size);
}

/// The icon as PNG bytes at [size].
Future<Uint8List> iconPng(int size, {bool maskable = false}) async {
  final image = await renderIcon(size, maskable: maskable);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}
