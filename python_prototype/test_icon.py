"""Checks for the icon and the file it is written to."""

import os

import pytest

Image = pytest.importorskip("PIL.Image")
import make_icon as mi  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ICO = os.path.join(HERE, "docs", "icon.ico")


def test_the_ico_is_in_the_repository():
    assert os.path.exists(ICO), "run python make_icon.py"


def test_the_ico_holds_every_size():
    with Image.open(ICO) as image:
        assert image.format == "ICO"
        assert sorted(image.info["sizes"]) == sorted((s, s) for s in mi.SIZES)
        # Every entry decodes, and to the size it claims.
        for size in mi.SIZES:
            image.size = (size, size)
            frame = image.convert("RGBA")
            assert frame.size == (size, size)


def test_the_png_companions_are_there():
    for size in (16, 32, 256):
        path = os.path.join(HERE, "docs", f"icon-{size}.png")
        with Image.open(path) as image:
            assert image.size == (size, size)


def test_drawing_is_reproducible():
    assert mi.draw(64).tobytes() == mi.draw(64).tobytes()


def test_building_writes_what_it_says_it_does(tmp_path):
    written = mi.build(str(tmp_path))
    for path in written:
        assert os.path.exists(path) and os.path.getsize(path) > 0
    assert any(p.endswith("icon.ico") for p in written)


@pytest.mark.parametrize("size", mi.SIZES)
def test_every_size_is_drawn_and_opaque_where_it_should_be(size):
    icon = mi.draw(size)
    assert icon.size == (size, size)
    assert icon.mode == "RGBA"
    # The middle of the tile is solid: a rounded corner is the only place
    # transparency belongs.
    middle = icon.getpixel((size // 2, size // 2))
    assert middle[3] == 255
    corner = icon.getpixel((0, 0))
    assert corner[3] < 128, "the corners should be rounded off"


def test_the_detail_thins_out_as_the_canvas_shrinks():
    """The point of drawing each size separately rather than resampling one."""
    small = mi.detail_for(16)
    large = mi.detail_for(256)
    assert small["lobes"] == 0 and large["lobes"] > 0
    assert small["ripple"] == 0.0 and large["ripple"] > 0.0
    # Below 24 pixels the stroke would be as thick as the shape it sits on.
    assert mi.detail_for(16)["curve"] == 0.0
    assert mi.detail_for(256)["curve"] > 0.0
    # And the relative margin grows with the canvas, so small sizes stay bold.
    assert small["margin"] < large["margin"]


def test_the_silhouette_is_a_lowpass_response():
    """Left side high and filled, right side low: the shape has to say lowpass."""
    size = 64
    icon = mi.draw(size)
    fill = mi.FILL[:3]

    def filled_height(x):
        column = [y for y in range(size)
                  if _close(icon.getpixel((x, y))[:3], fill, 60)]
        return len(column)

    passband = filled_height(int(size * 0.20))
    stopband = filled_height(int(size * 0.85))
    assert passband > 2 * stopband, (passband, stopband)


def _close(a, b, tol):
    return all(abs(p - q) <= tol for p, q in zip(a, b))


def test_the_window_takes_the_icon_without_complaining():
    tk = pytest.importorskip("tkinter")
    try:
        root = tk.Tk()
    except tk.TclError:
        pytest.skip("no display available")
    try:
        import remez as gui
        app = gui.RemezApp(root)
        root.update()
        # Loaded and, importantly, still referenced: Tk drops an image as soon
        # as nothing points at it, and the icon silently disappears.
        assert getattr(app, "_icon_images", [])
        assert [i.width() for i in app._icon_images] == [256, 32, 16]
    finally:
        root.destroy()
