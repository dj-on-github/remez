#!/usr/bin/env python3
"""Draw the program's icon and write it out as .ico (and .png).

The picture is the one thing this program makes that nothing else does: the
magnitude response of an equiripple lowpass filter.  A flat passband, a steep
skirt, and a stopband of equal-height lobes -- the shape the Remez exchange
produces and the shape a filter designer recognises immediately.

An icon is not one drawing.  At 256 pixels the passband ripple and the stopband
lobes are the point of it; at 16 the same detail is mud, and all that survives is
the silhouette -- shelf, cliff, floor.  So each size is drawn to suit itself,
with the detail turned down as the canvas shrinks, rather than drawn once and
resampled.  Everything is drawn at eight times the final size and reduced, which
is what makes the curve smooth without any per-pixel work.

    python make_icon.py            writes docs/icon.ico, the PNGs, and a preview
"""

from __future__ import annotations

import os

from PIL import Image, ImageDraw

# The sizes Windows asks for, plus the ones everything else uses.
SIZES = (16, 20, 24, 32, 48, 64, 128, 256)
SUPERSAMPLE = 8

BACKGROUND = (17, 32, 56, 255)        # deep navy, so the curve can be bright
PANEL = (25, 46, 78, 255)             # a slightly lifted plot area, large sizes
FILL = (38, 158, 240, 255)            # the area under the response
CURVE = (236, 248, 255, 255)          # the response itself, near white
BASELINE = (72, 104, 150, 255)


def detail_for(size: int) -> dict:
    """How much of the drawing survives at this size.

    Below about twenty pixels a lobe is one pixel of grey, so the stopband is
    drawn flat and only the silhouette is left.  The thresholds are where the
    features stop being legible, not round numbers.
    """
    # Below 24 pixels the white stroke would be as thick as the shape it sits
    # on, so the silhouette carries the icon on its own.
    if size <= 20:
        return dict(lobes=0, ripple=0.0, curve=0.0, corner=0.16, margin=0.055,
                    panel=False)
    if size <= 24:
        return dict(lobes=2, ripple=0.0, curve=0.0, corner=0.17, margin=0.06,
                    panel=False)
    if size <= 32:
        return dict(lobes=2, ripple=0.0, curve=0.045, corner=0.18, margin=0.075,
                    panel=False)
    if size <= 64:
        return dict(lobes=3, ripple=0.018, curve=0.035, corner=0.19,
                    margin=0.095, panel=True)
    return dict(lobes=3, ripple=0.024, curve=0.026, corner=0.20, margin=0.11,
                panel=True)


def response(detail: dict, steps: int = 800):
    """The curve, in unit coordinates: x left to right, y up from the floor.

    Not a real design run -- an icon needs the *idea* of an equiripple response,
    with the transition where the eye wants it and lobes big enough to see.  The
    proportions are those of a real lowpass all the same: a passband about twice
    the width of the transition, and a stopband floor near the bottom.
    """
    import math

    pass_edge, stop_edge = 0.44, 0.60
    pass_level, floor = 0.88, 0.17
    lobe_height = 0.125

    points = []
    for i in range(steps + 1):
        x = i / steps
        if x <= pass_edge:
            y = pass_level
            if detail["ripple"]:
                # Two cycles of passband ripple, faded out at the band edge so
                # the curve leaves the shelf smoothly.
                phase = math.pi * 2.0 * 2.0 * (x / pass_edge)
                y += detail["ripple"] * math.cos(phase)
        elif x < stop_edge:
            # A smooth skirt: a raised cosine reads as steeper than a straight
            # line of the same width.
            t = (x - pass_edge) / (stop_edge - pass_edge)
            y = floor + (pass_level - floor) * 0.5 * (1.0 + math.cos(math.pi * t))
        else:
            y = floor
            if detail["lobes"]:
                t = (x - stop_edge) / (1.0 - stop_edge)
                # Equal-height lobes, which is the whole point of the algorithm.
                y += lobe_height * abs(math.sin(math.pi * detail["lobes"] * t))
        points.append((x, y))
    return points


def draw(size: int) -> Image.Image:
    """One icon, drawn large and reduced."""
    detail = detail_for(size)
    big = size * SUPERSAMPLE
    image = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    pen = ImageDraw.Draw(image)

    corner = detail["corner"] * big
    pen.rounded_rectangle((0, 0, big - 1, big - 1), radius=corner, fill=BACKGROUND)

    # The plot area, inset from the rounded edge.  The inset panel is only
    # drawn where it is big enough to read as one; at small sizes it just
    # muddies two dark tones together.
    margin = detail["margin"] * big
    left, right = margin, big - margin
    top, bottom = margin * 1.15, big - margin * 1.15
    span_x, span_y = right - left, bottom - top
    if detail["panel"]:
        pen.rounded_rectangle((left, top, right, bottom),
                              radius=corner * 0.35, fill=PANEL)

    def place(x, y):
        return left + x * span_x, bottom - y * span_y

    curve = [place(x, y) for x, y in response(detail)]
    floor_y = place(0.0, 0.0)[1]

    # Fill under the curve, then lay the curve over the top of it.
    pen.polygon([(curve[0][0], floor_y)] + curve + [(curve[-1][0], floor_y)],
                fill=FILL)

    # The response, drawn over the fill.  No highlight along the top: a second
    # line a hair below the first only reads as a curve out of focus.
    if detail["curve"]:
        width = max(detail["curve"] * big, SUPERSAMPLE)
        pen.line(curve, fill=CURVE, width=int(width), joint="curve")

    # A baseline, so the shape sits on something rather than floating.
    pen.line([(left, floor_y), (right, floor_y)], fill=BASELINE,
             width=max(int(0.014 * big), SUPERSAMPLE // 2))

    return image.resize((size, size), Image.LANCZOS)


def build(folder="docs"):
    os.makedirs(folder, exist_ok=True)
    images = [draw(size) for size in SIZES]

    ico = os.path.join(folder, "icon.ico")
    # Pillow writes one entry per size into the one file.
    images[-1].save(ico, format="ICO",
                    sizes=[(s, s) for s in SIZES],
                    append_images=images[:-1])

    written = [ico]
    for size, image in zip(SIZES, images):
        if size in (16, 32, 256):
            path = os.path.join(folder, f"icon-{size}.png")
            image.save(path)
            written.append(path)

    # A sheet showing every size as it will actually appear, plus the small ones
    # magnified so the silhouette can be judged.
    pad = 10
    strip = sum(s + pad for s in SIZES) + pad
    sheet = Image.new("RGBA", (max(strip, 560), 256 + 96 + pad * 3),
                      (245, 247, 250, 255))
    x = pad
    for size, image in zip(SIZES, images):
        sheet.paste(image, (x, pad + (256 - size)), image)
        x += size + pad
    x = pad
    for size in (16, 24, 32):
        blown = draw(size).resize((96, 96), Image.NEAREST)
        sheet.paste(blown, (x, 256 + pad * 2), blown)
        x += 96 + pad
    preview = os.path.join(folder, "icon-preview.png")
    sheet.save(preview)
    written.append(preview)
    return written


if __name__ == "__main__":
    for path in build():
        print(path)
