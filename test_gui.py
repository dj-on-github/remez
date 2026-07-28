"""GUI-level checks.

These drive the real Tk widgets (a window is created but never entered into
mainloop), so they exercise the whole path from the entry fields through the
design to the rendered figure.
"""

import os

import numpy as np
import pytest

tk = pytest.importorskip("tkinter")
import remez_core as rz  # noqa: E402
import remez_gui as gui  # noqa: E402


@pytest.fixture
def app():
    try:
        root = tk.Tk()
    except tk.TclError:
        pytest.skip("no display available")
    root.withdraw()
    a = gui.RemezApp(root)
    yield a
    root.destroy()


def report_text(app):
    return app.report.get("1.0", "end")


@pytest.mark.parametrize("name", list(gui.PRESETS))
def test_every_preset_designs(app, name):
    app.load_preset(name)
    app.design()
    assert app.result is not None, report_text(app)
    assert app.result.converged
    assert np.all(np.isfinite(app.result.h))
    assert "did not converge" not in report_text(app)


def test_default_lowpass_is_equiripple(app):
    res = app.result
    e = res.extremal_e
    assert np.all(np.sign(e[:-1]) * np.sign(e[1:]) < 0)
    assert np.allclose(np.abs(e), abs(res.delta), rtol=1e-6)


def test_editing_a_field_changes_the_filter(app):
    before = app.result.h.copy()
    app.rows[0].vars[1].set("0.1")        # narrow the passband
    app.design()
    assert not np.allclose(before, app.result.h)


def test_taps_field_drives_the_length(app):
    app.numtaps.set(64)
    app.design()
    assert app.result.numtaps == 64
    assert app.result.ftype == 2           # even length, symmetric


def test_sample_rate_in_hz(app):
    app.fs.set(48000.0)
    app.load_preset("Lowpass")
    app.design()
    assert app.result is not None, report_text(app)
    assert app.result.bands[0].f2 == pytest.approx(0.2 * 48000)
    normalised = rz.design(app.result.numtaps,
                           [rz.Band(0, .2, 1., w1=1.), rz.Band(.25, .5, 0., w1=10.)])
    assert np.allclose(app.result.h, normalised.h, atol=1e-9)


def test_add_and_remove_bands(app):
    n = len(app.rows)
    app.add_row((0.3, 0.4, 0.0, 0.0, 1.0, 40.0, False))
    assert len(app.rows) == n + 1
    app.remove_row(app.rows[-1])
    assert len(app.rows) == n
    # The last band cannot be removed, so a design is always possible.
    while len(app.rows) > 1:
        app.remove_row(app.rows[-1])
    app.remove_row(app.rows[0])
    assert len(app.rows) == 1


def test_spec_mode_sets_weights_and_checks_them(app):
    app.load_preset("Lowpass")
    app.use_spec.set(True)
    app._spec_toggled()
    assert app.result is not None, report_text(app)
    # 0.5 dB passband ripple against 50 dB stopband attenuation.
    dp, ds = app.spec_dev
    assert dp == pytest.approx((10 ** 0.025 - 1) / (10 ** 0.025 + 1), rel=1e-9)
    assert ds == pytest.approx(10 ** -2.5, rel=1e-9)
    assert app.result.bands[1].w1 / app.result.bands[0].w1 == pytest.approx(dp / ds)
    assert "spec check" in report_text(app)


def test_spec_mode_reports_a_miss_and_suggests_taps(app):
    app.load_preset("Lowpass")
    app.numtaps.set(11)                    # far too short for 50 dB
    app.use_spec.set(True)
    app._spec_toggled()
    text = report_text(app)
    assert "MISSED" in text
    assert "try about" in text


def test_bad_input_is_reported_not_raised(app):
    app.rows[0].vars[0].set("banana")
    app.design()
    assert app.result is None
    assert "Cannot design" in report_text(app)
    app.rows[0].vars[0].set("0")           # and it recovers
    app.design()
    assert app.result is not None


def test_overlapping_bands_are_reported(app):
    app.rows[1].vars[0].set("0.1")         # stopband now starts inside passband
    app.design()
    assert app.result is None
    assert "overlaps" in report_text(app)


def test_differentiator_uses_inverse_f_weighting(app):
    app.load_preset("Differentiator")
    app.design()
    assert app.result is not None, report_text(app)
    assert app.result.bands[0].weight_kind == "inv_f"
    assert app.result.symmetry == "antisymmetric"
    f = np.linspace(0.05, 0.44, 500)
    a = rz.amplitude_response(app.result.h, 2 * np.pi * f, "antisymmetric")
    assert np.max(np.abs(a - 2 * np.pi * f) / (2 * np.pi * f)) < 0.02


def test_plot_switches_between_db_and_linear(app):
    app.log_scale.set(True)
    app.redraw()
    assert "dB" in app.ax_mag.get_ylabel()
    app.log_scale.set(False)
    app.redraw()
    assert app.ax_mag.get_ylabel() == "amplitude"


def test_error_curve_is_not_joined_across_transition_bands(app):
    slices = gui.RemezApp._segment_slices(app.result)
    assert len(slices) == len(app.result.bands)


def test_exports(app, tmp_path, monkeypatch):
    csv = tmp_path / "coeffs.csv"
    header = tmp_path / "coeffs.h"
    png = tmp_path / "plot.png"

    def choose(path):
        monkeypatch.setattr(gui.filedialog, "asksaveasfilename",
                            lambda **kw: str(path))

    choose(csv)
    app.save_coefficients()
    choose(header)
    app.save_coefficients()
    choose(png)
    app.save_plot()

    rows = csv.read_text().strip().splitlines()
    assert rows[-1].startswith(str(app.result.numtaps - 1) + ",")
    values = [float(r.split(",")[1]) for r in rows if not r.startswith(("#", "n,"))]
    assert np.allclose(values, app.result.h, atol=1e-15)

    text = header.read_text()
    assert f"#define FIR_TAPS {app.result.numtaps}" in text
    assert text.count(",") >= app.result.numtaps

    assert png.exists() and png.stat().st_size > 0
    assert os.path.getsize(png) > 5000
