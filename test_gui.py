"""GUI-level checks.

These drive the real Tk widgets (a window is created but never entered into
mainloop), so they exercise the whole path from the entry fields through the
design to the rendered figure.
"""

import os
import shutil
import subprocess

import numpy as np
import pytest

tk = pytest.importorskip("tkinter")
import iir_core as ii  # noqa: E402
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


@pytest.fixture
def iir(app):
    app.mode.set(gui.MODE_IIR)
    app.switch_mode()
    return app


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


# ------------------------------------------------------------------ IIR mode


def test_the_mode_selector_swaps_panels_and_axes(app):
    assert not app.is_iir()
    assert app.fir_panel.winfo_ismapped() or app.fir_panel.grid_info()
    assert app.iir_panel.grid_info() == {}
    fir_axes = list(app.fig.axes)

    app.mode.set(gui.MODE_IIR)
    app.switch_mode()
    assert app.is_iir()
    assert app.fir_panel.grid_info() == {}
    assert app.iir_panel.grid_info() != {}
    assert app.iir_result is not None, report_text(app)
    assert not any(ax in fir_axes for ax in app.fig.axes)
    assert str(app.ext_check["state"]) == "disabled"

    app.mode.set(gui.MODE_FIR)
    app.switch_mode()
    assert app.result is not None, report_text(app)
    assert str(app.ext_check["state"]) == "normal"


@pytest.mark.parametrize("name", list(gui.IIR_PRESETS))
def test_every_iir_preset_designs(iir, name):
    iir.load_iir_preset(name)
    iir.design()
    res = iir.iir_result
    assert res is not None, report_text(iir)
    assert res.stable and res.meets_spec
    assert np.all(np.isfinite(res.sos))
    assert "MISSED" not in report_text(iir)


def test_automatic_order_fills_in_the_spinbox(iir):
    iir.load_iir_preset("Elliptic lowpass")
    iir.design()
    assert iir.auto_order.get()
    assert str(iir.order_spin["state"]) == "disabled"
    assert iir.iir_order.get() == iir.iir_result.order == iir.iir_result.order_estimate


def test_a_manual_order_is_used_and_reported(iir):
    iir.load_iir_preset("Elliptic lowpass")
    iir.design()
    n = iir.iir_result.order
    iir.auto_order.set(False)
    iir._auto_order_toggled()
    assert str(iir.order_spin["state"]) == "normal"
    iir.iir_order.set(n - 2)
    iir.design()
    assert iir.iir_result.order == n - 2
    assert not iir.iir_result.meets_spec
    text = report_text(iir)
    assert "MISSED" in text
    assert f"raise the order to {n}" in text


def test_editing_an_edge_changes_the_iir_filter(iir):
    before = iir.iir_result.sos.copy()
    iir.iir_wp[0].set("0.1")
    iir.design()
    assert iir.iir_result.sos.shape != before.shape or \
        not np.allclose(iir.iir_result.sos, before)
    assert iir.iir_result.wp == (0.1,)


def test_band_responses_enable_the_upper_edge_fields(iir):
    lo, hi = iir.edge_entries["Passband edge"]
    assert str(hi["state"]) == "disabled"
    iir.response.set("Bandpass")
    iir._edge_fields_for_response()
    assert str(hi["state"]) == "normal"
    assert str(lo["state"]) == "normal"
    iir.response.set("Highpass")
    iir._edge_fields_for_response()
    assert str(hi["state"]) == "disabled"


def test_approximations_all_design_from_the_same_spec(iir):
    iir.load_iir_preset("Elliptic lowpass")
    orders = {}
    for name in gui.APPROX_LABELS:
        iir.approximation.set(name)
        iir.design()
        assert iir.iir_result is not None, (name, report_text(iir))
        orders[name] = iir.iir_result.order
    # the whole point of the elliptic design is that it needs the fewest poles
    assert orders["Elliptic"] < orders["Chebyshev I"] < orders["Butterworth"]


def test_iir_sample_rate_in_hz(iir):
    iir.fs.set(48000.0)
    iir.load_iir_preset("Elliptic lowpass")
    iir.design()
    assert iir.iir_result is not None, report_text(iir)
    assert iir.iir_result.wp == (0.2 * 48000,)
    normalised = ii.design("lowpass", "elliptic", wp=(0.2,), ws=(0.25,),
                           rp=0.5, rs=60.0)
    assert np.allclose(iir.iir_result.sos, normalised.sos)


def test_bad_iir_input_is_reported_not_raised(iir):
    iir.iir_wp[0].set("banana")
    iir.design()
    assert iir.iir_result is None
    assert "Cannot design" in report_text(iir)
    iir.iir_wp[0].set("0.2")               # and it recovers
    iir.design()
    assert iir.iir_result is not None


def test_overlapping_iir_edges_are_reported(iir):
    iir.iir_ws[0].set("0.1")               # stopband edge below the passband edge
    iir.design()
    assert iir.iir_result is None
    assert "stopband edge must be above" in report_text(iir)


def test_iir_plot_switches_between_db_and_linear(iir):
    iir.log_scale.set(True)
    iir.redraw()
    assert "dB" in iir.ax_imag.get_ylabel()
    iir.log_scale.set(False)
    iir.redraw()
    assert iir.ax_imag.get_ylabel() == "magnitude"


def test_iir_pole_zero_panel_is_drawn(iir):
    iir.load_iir_preset("Butterworth lowpass")
    iir.design()
    assert iir.ax_pz.get_aspect() == 1.0
    assert f"{iir.iir_result.max_pole_radius:.4f}" in iir.ax_pz.get_title()
    # all the zeros of a Butterworth sit on top of each other at Nyquist
    counts = gui.RemezApp._multiplicities(iir.iir_result.z)
    assert len(counts) == 1 and counts[0][1] == iir.iir_result.degree


def test_iir_exports(iir, tmp_path, monkeypatch):
    csv = tmp_path / "sos.csv"
    header = tmp_path / "sos.h"
    png = tmp_path / "iir.png"

    def choose(path):
        monkeypatch.setattr(gui.filedialog, "asksaveasfilename",
                            lambda **kw: str(path))

    choose(csv)
    iir.save_coefficients()
    choose(header)
    iir.save_coefficients()
    choose(png)
    iir.save_plot()

    res = iir.iir_result
    rows = [r for r in csv.read_text().strip().splitlines()
            if not r.startswith(("#", "section,"))]
    assert len(rows) == len(res.sos)
    values = np.array([[float(v) for v in r.split(",")[1:]] for r in rows])
    assert np.allclose(values, res.sos, atol=1e-15)

    text = header.read_text()
    assert f"#define IIR_SECTIONS {len(res.sos)}" in text
    assert text.count("},") == len(res.sos)

    assert png.exists() and os.path.getsize(png) > 5000


# --------------------------------------------------------------- design view


def diagram_text(app):
    return [t.get_text() for t in app.ax_design.texts]


def test_the_view_selector_swaps_between_plots_and_the_diagram(iir):
    assert not iir.is_design()
    assert len(iir.fig.axes) > 1

    iir.view.set(gui.VIEW_DESIGN)
    iir.switch_view()
    assert iir.is_design()
    assert len(iir.fig.axes) == 1
    assert not iir.ax_design.axison
    assert "structure" in iir.view_hint["text"]

    iir.view.set(gui.VIEW_PLOT)
    iir.switch_view()
    assert not iir.is_design()
    assert "dB" in iir.ax_imag.get_ylabel()
    assert iir.view_hint["text"] == ""


def test_the_iir_diagram_has_one_biquad_per_section(iir):
    iir.load_iir_preset("Elliptic bandpass")
    iir.design()
    res = iir.iir_result
    iir.view.set(gui.VIEW_DESIGN)
    iir.switch_view()

    text = diagram_text(iir)
    # two unit delays and three adders per transposed direct form II section
    assert text.count("z⁻¹") == 2 * len(res.sos)
    assert text.count("+") == 3 * len(res.sos)
    for i in range(len(res.sos)):
        assert any(t.startswith(f"section {i} ") for t in text)
    # the sections are chained input to output
    assert "x[n]" in text and "y[n]" in text
    for i in range(1, len(res.sos)):
        assert text.count(f"w{i}[n]") == 2      # output of one, input of the next


def test_the_iir_diagram_shows_the_real_coefficients(iir):
    iir.load_iir_preset("Elliptic lowpass")
    iir.design()
    s = iir.iir_result.sos[0]
    iir.view.set(gui.VIEW_DESIGN)
    iir.switch_view()
    text = diagram_text(iir)
    assert f"b0 = {s[0]:+.6g}" in text
    assert f"−a1 = {-s[4]:+.6g}" in text
    # a first-order section arrives padded, and says so rather than hiding it
    assert s[2] == 0.0 and "b2 = +0" in text


def test_the_diagram_follows_the_mode(iir):
    iir.view.set(gui.VIEW_DESIGN)
    iir.switch_view()
    assert any("biquad" in t for t in diagram_text(iir))
    iir.mode.set(gui.MODE_FIR)
    iir.switch_mode()
    assert iir.is_design()
    assert any("direct form" in t for t in diagram_text(iir))


def test_the_fir_diagram_draws_every_tap_when_it_can(app):
    app.numtaps.set(11)
    app.design()
    app.view.set(gui.VIEW_DESIGN)
    app.switch_view()
    text = diagram_text(app)
    assert text.count("z⁻¹") == 10
    assert [f"h{k}" for k in range(11)] == [t for t in text if t[:1] == "h" and
                                            t[1:].isdigit()]
    assert f"{app.result.h[0]:+.6g}" in text
    assert any("folded form needs only 6" in t for t in text)


def test_a_long_fir_says_which_taps_it_left_out(app):
    app.numtaps.set(41)
    app.design()
    app.view.set(gui.VIEW_DESIGN)
    app.switch_view()
    text = diagram_text(app)
    assert text.count("⋯") == 2               # one break on each rail
    assert "h6" not in text and "h34" not in text
    assert any("taps 6 … 34 are not drawn" in t for t in text)


def test_the_diagram_can_be_saved(iir, tmp_path, monkeypatch):
    iir.view.set(gui.VIEW_DESIGN)
    iir.switch_view()
    out = tmp_path / "structure.pdf"
    monkeypatch.setattr(gui.filedialog, "asksaveasfilename", lambda **kw: str(out))
    iir.save_plot()
    assert out.exists() and os.path.getsize(out) > 2000


def test_a_failed_design_does_not_break_the_design_view(iir):
    iir.view.set(gui.VIEW_DESIGN)
    iir.switch_view()
    iir.iir_wp[0].set("banana")
    iir.design()
    assert iir.iir_result is None
    assert "Cannot design" in report_text(iir)
    iir.iir_wp[0].set("0.2")
    iir.design()
    assert iir.iir_result is not None
    assert any("biquad" in t for t in diagram_text(iir))


# ------------------------------------------------------------- C source export


def buttons(widget):
    """Every button text under ``widget``, however deeply nested."""
    out = []
    for child in widget.winfo_children():
        if isinstance(child, gui.ttk.Button):
            out.append(child["text"])
        out.extend(buttons(child))
    return out


def save_c(app, path, monkeypatch):
    monkeypatch.setattr(gui.filedialog, "asksaveasfilename", lambda **kw: str(path))
    app.save_c_source()
    return path.read_text()


def build_and_run(tmp_path, source, samples):
    """Compile the generated filter and push samples through it."""
    cc = shutil.which("cc") or shutil.which("gcc")
    if cc is None:
        pytest.skip("no C compiler available")
    src = tmp_path / "filter.c"
    exe = tmp_path / "filter"
    src.write_text(source)
    build = subprocess.run(
        [cc, "-std=c99", "-Wall", "-Wextra", "-pedantic", "-O2",
         "-DFILTER_MAIN", "-o", str(exe), str(src), "-lm"],
        capture_output=True, text=True)
    assert build.returncode == 0, build.stderr
    assert build.stderr == "", build.stderr        # and without a single warning
    run = subprocess.run([str(exe)], text=True, capture_output=True,
                         input="\n".join(f"{v:.17g}" for v in samples))
    assert run.returncode == 0, run.stderr
    return np.array([float(v) for v in run.stdout.split()])


def test_the_save_c_button_is_on_the_action_row(app):
    assert "Save C…" in buttons(app.root)


def test_save_c_declares_the_requested_interface(iir, tmp_path, monkeypatch):
    text = save_c(iir, tmp_path / "iir.c", monkeypatch)
    assert "typedef struct {" in text and "} t_ctx;" in text
    assert "int init_filter(t_ctx *ctx)" in text
    assert "double process_sample(double sample, t_ctx *ctx)" in text
    assert "void free_filter(t_ctx *ctx)" in text
    assert "calloc(" in text                       # it allocates its own state
    assert f"#define FILTER_SECTIONS {len(iir.iir_result.sos)}" in text


def test_save_c_in_fir_mode_writes_the_taps(app, tmp_path, monkeypatch):
    text = save_c(app, tmp_path / "fir.c", monkeypatch)
    assert f"#define FILTER_TAPS {app.result.numtaps}" in text
    assert "double process_sample(double sample, t_ctx *ctx)" in text
    assert f"{app.result.h[0]: .17g}," in text


def test_save_c_does_nothing_if_the_dialog_is_cancelled(iir, tmp_path, monkeypatch):
    target = tmp_path / "nothing.c"
    monkeypatch.setattr(gui.filedialog, "asksaveasfilename", lambda **kw: "")
    iir.save_c_source()
    assert not target.exists()


def test_the_generated_iir_c_filters_exactly_as_the_designer_does(
        iir, tmp_path, monkeypatch):
    iir.load_iir_preset("Elliptic bandpass")
    iir.design()
    source = save_c(iir, tmp_path / "iir.c", monkeypatch)
    x = np.random.default_rng(3).standard_normal(300)
    got = build_and_run(tmp_path, source, x)
    assert len(got) == len(x)
    # the same transposed direct form II in the same order: bit for bit
    assert np.array_equal(got, ii.sos_filter(iir.iir_result.sos, x))


def test_the_generated_fir_c_filters_as_designed(app, tmp_path, monkeypatch):
    source = save_c(app, tmp_path / "fir.c", monkeypatch)
    x = np.random.default_rng(4).standard_normal(300)
    got = build_and_run(tmp_path, source, x)
    assert np.allclose(got, np.convolve(x, app.result.h)[:len(x)], atol=1e-12)


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
