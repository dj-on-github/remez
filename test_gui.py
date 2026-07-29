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
import fir_core as rz  # noqa: E402
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
        # -ffp-contract=off keeps the compiler from fusing a multiply and an
        # add into one FMA, which rounds once instead of twice and would put
        # the C a few bits away from the same arithmetic done in numpy.
        [cc, "-std=c99", "-Wall", "-Wextra", "-pedantic", "-O2",
         "-ffp-contract=off", "-DFILTER_MAIN", "-o", str(exe), str(src), "-lm"],
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


# ------------------------------------------------------- fixed point arithmetic


def go_fixed(app, bits=None, frac=None):
    """Switch to fixed point, optionally forcing the format."""
    app.arith.set(gui.ARITH_FIXED)
    if bits is not None:
        app.word_bits.set(bits)
    if frac is not None:
        app.auto_frac.set(False)
        app.frac_bits.set(frac)
    app._arith_changed()
    return app.fixed


def test_floating_point_is_the_default_and_quantizes_nothing(app):
    assert app.arith.get() == gui.ARITH_FLOAT
    assert app.fixed is None
    assert app.eff is app.result
    assert str(app.word_bits_widget["state"]) == "disabled"


def test_fixed_point_rounds_the_taps_and_says_so(app):
    q = go_fixed(app, 8)
    assert q is not None and q.bits == 8
    assert app.eff is not app.result
    assert np.array_equal(app.eff.h, q.values)
    assert np.array_equal(q.values, q.ints * 2.0 ** -q.frac_bits)
    assert not np.allclose(app.eff.h, app.result.h)
    assert q.qformat in app.arith_status.get()
    assert q.qformat in report_text(app)


def test_the_word_length_controls_wake_up_with_fixed_point(app):
    assert str(app.word_bits_widget["state"]) == "disabled"
    go_fixed(app, 12)
    assert str(app.word_bits_widget["state"]) == "normal"
    app.arith.set(gui.ARITH_FLOAT)
    app._arith_changed()
    assert str(app.word_bits_widget["state"]) == "disabled"
    assert app.fixed is None


def test_the_binary_point_spinbox_follows_the_automatic_choice(app):
    q = go_fixed(app, 16)
    assert app.auto_frac.get()
    assert app.frac_bits.get() == q.frac_bits
    assert str(app.frac_spin["state"]) == "disabled"
    # Taking it over by hand is honoured.
    forced = go_fixed(app, 16, frac=q.frac_bits - 3)
    assert forced.frac_bits == q.frac_bits - 3
    assert str(app.frac_spin["state"]) == "normal"


def test_narrower_words_cost_stopband_attenuation(app):
    ideal = app.result.band_deviation[1]
    floors = []
    for bits in (8, 12, 16):
        go_fixed(app, bits)
        floors.append(app.eff.band_deviation[1])
    assert floors[0] > floors[1] > floors[2] >= ideal * 0.999
    assert floors[0] > 2 * ideal


def test_the_report_shows_what_rounding_cost(app):
    go_fixed(app, 8)
    text = report_text(app)
    assert "cost of rounding, per band" in text
    assert "as built, after rounding the taps" in text
    assert "datapath rounding is not modelled" in text
    # The coefficient listing gains the integers actually stored.
    assert str(int(app.fixed.ints[0])) in text


def test_a_forced_binary_point_that_saturates_is_flagged(app):
    q = go_fixed(app, 8, frac=12)         # far too far left for these taps
    assert q.saturated > 0
    assert "saturated" in app.arith_status.get()
    assert "saturated" in report_text(app)


def test_quantization_survives_a_redesign(app):
    go_fixed(app, 10)
    app.numtaps.set(51)
    app.design()                          # a fresh design, still fixed point
    assert app.fixed is not None
    assert app.result.numtaps == 51
    assert app.eff.h.size == 51
    assert np.array_equal(app.eff.h, app.fixed.values)


def test_switching_arithmetic_does_not_redesign(app):
    before = app.result
    go_fixed(app, 12)
    assert app.result is before           # the same design object, re-rounded
    app.arith.set(gui.ARITH_FLOAT)
    app._arith_changed()
    assert app.result is before
    assert app.eff is before


def test_the_plot_shows_the_ideal_response_alongside(app):
    app.redraw()
    labels = [ln.get_label() for ln in app.ax_mag.get_lines()]
    assert not any("ideal" in str(x) for x in labels)
    go_fixed(app, 8)
    labels = [ln.get_label() for ln in app.ax_mag.get_lines()]
    assert any("ideal" in str(x) for x in labels)
    assert any("8-bit" in str(x) for x in labels)


def test_a_bad_word_length_is_reported_not_raised(app):
    app.arith.set(gui.ARITH_FIXED)
    app.word_bits.set(1)                  # below the minimum
    app._arith_changed()
    assert app.fixed is None
    assert app.eff is app.result          # falls back to the design itself
    assert "not quantized" in app.arith_status.get()


def test_fixed_point_applies_to_the_iir_sections_too(iir):
    q = go_fixed(iir, 10)
    assert q.ints.shape == iir.iir_result.sos.shape
    assert np.all(q.values[:, 3] == 1.0)              # a0 left alone
    assert np.array_equal(iir.eff.sos, q.values)
    assert not np.allclose(iir.eff.sos, iir.iir_result.sos)
    text = report_text(iir)
    assert q.qformat in text
    assert "passband ripple" in text


def test_rounding_moves_the_iir_poles(iir):
    before = iir.iir_result.max_pole_radius
    go_fixed(iir, 8)
    assert iir.eff.max_pole_radius != before
    assert f"was {before:.6f}" in report_text(iir)
    labels = [ln.get_label() for ln in iir.ax_pz.get_lines()]
    assert any("before rounding" in str(x) for x in labels)


def test_an_unstable_quantized_iir_is_called_out(iir):
    # Narrow band, high order, poles hard against the unit circle.
    iir.response.set("Lowpass")
    iir.iir_wp[0].set("0.02")
    iir.iir_ws[0].set("0.03")
    iir.iir_rp.set("0.1")
    iir.iir_rs.set("80")
    iir.design()
    assert iir.iir_result.stable
    go_fixed(iir, 8)
    assert not iir.eff.stable
    text = report_text(iir)
    assert "UNSTABLE" in text
    assert "outside the unit circle" in text


def test_exports_carry_the_integers_and_the_format(app, tmp_path, monkeypatch):
    go_fixed(app, 12)
    csv = tmp_path / "q.csv"
    header = tmp_path / "q.h"
    source = tmp_path / "q.c"
    for path in (csv, header, source):
        monkeypatch.setattr(gui.filedialog, "asksaveasfilename",
                            lambda p=path, **kw: str(p))
        app.save_c_source() if path.suffix == ".c" else app.save_coefficients()

    text = csv.read_text()
    assert f"Q{app.fixed.int_bits}.{app.fixed.frac_bits}" in text
    rows = [r for r in text.splitlines() if not r.startswith(("#", "n,"))]
    assert [int(r.split(",")[2]) for r in rows] == [int(v) for v in app.fixed.ints]
    # The exported doubles are the rounded ones, not the design's.
    assert np.allclose([float(r.split(",")[1]) for r in rows], app.eff.h, atol=0)

    head = header.read_text()
    assert f"#define FIR_FRAC_BITS {app.fixed.frac_bits}" in head
    assert "fir_coeffs_q" in head

    c = source.read_text()
    assert "fixed point" in c
    assert f"{app.eff.h[0]: .17g}" in c


def test_the_generated_c_runs_the_rounded_taps(app, tmp_path, monkeypatch):
    go_fixed(app, 8)
    source = save_c(app, tmp_path / "q.c", monkeypatch)
    x = np.random.default_rng(5).standard_normal(200)
    got = build_and_run(tmp_path, source, x)
    assert np.allclose(got, np.convolve(x, app.eff.h)[:len(x)], atol=1e-12)
    # and that is measurably not the unrounded design
    assert not np.allclose(got, np.convolve(x, app.result.h)[:len(x)], atol=1e-9)


def test_the_passband_panel_keeps_a_shifted_curve_in_frame(iir):
    iir.load_iir_preset("Elliptic lowpass")
    iir.design()
    go_fixed(iir, 10)
    lo, hi = iir.ax_idetail.get_ylim()
    curves = [ln.get_ydata() for ln in iir.ax_idetail.get_lines()
              if len(ln.get_ydata()) > 2]
    assert curves, "the passband response was not drawn"
    shown = np.concatenate(curves)
    shown = shown[np.isfinite(shown)]
    assert shown.min() >= lo and shown.max() <= hi
    assert hi > 0.8 * iir.eff.rp                 # the spec lines stay visible too


def test_a_gain_shift_from_rounding_is_reported(iir):
    iir.load_iir_preset("Elliptic lowpass")
    iir.design()
    go_fixed(iir, 10)
    shift = gui.RemezApp._passband_gain_shift(iir.iir_result, iir.eff)
    assert abs(shift) > 0.1                      # this one moves about a dB
    assert "passband gain" in report_text(iir)
    assert f"{shift:+.3g} dB" in report_text(iir)


def test_no_gain_shift_is_claimed_in_floating_point(iir):
    assert gui.RemezApp._passband_gain_shift(iir.iir_result,
                                             iir.iir_result) == pytest.approx(0.0)
    assert "passband gain" not in report_text(iir)


# --------------------------------------------------- SystemVerilog generation


def generate_sv(app, path, monkeypatch):
    monkeypatch.setattr(gui.filedialog, "asksaveasfilename",
                        lambda **kw: str(path))
    app.save_sv_source()
    return path.read_text() if path.exists() else ""


def test_the_generate_sv_button_is_on_the_action_row(app):
    labels = []
    for child in app.root.winfo_children():
        for frame in child.winfo_children():
            for w in frame.winfo_children():
                for b in w.winfo_children():
                    if b.winfo_class() == "TButton":
                        labels.append(b.cget("text"))
    assert any("Generate SV" in str(t) for t in labels), labels


def test_headroom_and_fixed_coefficients_default_sensibly(app):
    assert app.headroom.get() == 2
    assert app.fixed_coeffs.get() is True
    assert str(app.headroom_spin["state"]) == "disabled"      # float mode
    go_fixed(app, 12)
    assert str(app.headroom_spin["state"]) == "normal"


def test_the_status_line_reports_the_rtl_datapath(app):
    go_fixed(app, 12)
    app.headroom.set(5)
    app._arith_changed()
    text = app.arith_status.get()
    assert "RTL datapath 17 bits" in text
    assert "built in" in text
    app.fixed_coeffs.set(False)
    app._arith_changed()
    assert "on a port" in app.arith_status.get()


def test_generating_in_floating_point_is_refused_with_a_dialog(app, monkeypatch,
                                                              tmp_path):
    shown = []
    monkeypatch.setattr(gui.messagebox, "showerror",
                        lambda title, msg: shown.append((title, msg)))
    monkeypatch.setattr(gui.filedialog, "asksaveasfilename",
                        lambda **kw: str(tmp_path / "no.sv"))
    app.save_sv_source()
    assert shown and "Fixed point" in shown[0][1]
    assert not (tmp_path / "no.sv").exists()


def test_the_generated_fir_names_its_modules_after_the_file(app, tmp_path,
                                                            monkeypatch):
    go_fixed(app, 12)
    src = generate_sv(app, tmp_path / "my_lowpass.sv", monkeypatch)
    assert "module my_lowpass #(" in src
    assert "module my_lowpass_mul" in src
    assert f"parameter int NTAPS    = {app.result.numtaps}," in src
    assert f"parameter int WCOEF    = {app.fixed.bits}," in src
    assert f"parameter int FRAC     = {app.fixed.frac_bits}," in src
    assert f"parameter int HEADROOM = {app.headroom.get()}," in src


def test_the_headroom_setting_reaches_the_rtl(app, tmp_path, monkeypatch):
    go_fixed(app, 10)
    app.headroom.set(6)
    app._arith_changed()
    src = generate_sv(app, tmp_path / "h6.sv", monkeypatch)
    assert "parameter int HEADROOM = 6," in src
    assert "Datapath      16 bits = 10 + 6 headroom" in src


def test_the_checkbox_switches_the_coefficient_port(app, tmp_path, monkeypatch):
    go_fixed(app, 12)
    built_in = generate_sv(app, tmp_path / "a.sv", monkeypatch)
    assert "coeff," not in built_in
    assert ".FIXED(1'b1)" in built_in

    app.fixed_coeffs.set(False)
    app._arith_changed()
    ported = generate_sv(app, tmp_path / "b.sv", monkeypatch)
    assert "input  wire signed [NTAPS*WCOEF-1:0] coeff," in ported
    assert ".FIXED(1'b0)" in ported


def test_the_generated_iir_is_a_biquad_cascade(iir, tmp_path, monkeypatch):
    go_fixed(iir, 16)
    src = generate_sv(iir, tmp_path / "ell.sv", monkeypatch)
    assert f"parameter int NSEC     = {len(iir.eff.sos)}," in src
    assert "u_mul_pa1" in src and ".NEG(1'b1)" in src
    assert "u_z1" in src and "u_z2" in src
    # the sections that went in are the quantized ones, not the design's
    for value in iir.fixed.ints[0][[0, 1, 2, 4, 5]]:
        assert str(int(value)) in src


def test_a_saturating_word_length_is_refused_with_a_dialog(app, tmp_path,
                                                           monkeypatch):
    shown = []
    monkeypatch.setattr(gui.messagebox, "showerror",
                        lambda title, msg: shown.append((title, msg)))
    go_fixed(app, 8, frac=12)                    # forces coefficient clipping
    assert app.fixed.saturated
    generate_sv(app, tmp_path / "bad.sv", monkeypatch)
    assert shown and "saturated" in shown[0][1]


@pytest.mark.skipif(shutil.which("verilator") is None,
                    reason="verilator is not installed")
def test_the_generated_rtl_lints_and_runs_the_designed_filter(app, tmp_path,
                                                              monkeypatch):
    """End to end: design, quantize, generate, simulate, compare."""
    import sv_export as sv

    app.numtaps.set(15)
    app.design()
    go_fixed(app, 12)
    app.headroom.set(3)
    app._arith_changed()
    src = generate_sv(app, tmp_path / "dut.sv", monkeypatch)

    lint = subprocess.run([shutil.which("verilator"), "--lint-only", "-Wall",
                           str(tmp_path / "dut.sv")],
                          capture_output=True, text=True)
    assert lint.returncode == 0, lint.stdout + lint.stderr

    import test_sv
    stim = [4096, -4096, 2048, 0, 1024, -3000, 3000, 100, -100]
    got = test_sv.run_rtl(tmp_path, src, "dut", stim, app.fixed.bits, 3)
    want = sv.simulate("fir", app.fixed.ints, stim, app.fixed.frac_bits,
                       app.fixed.bits, 3)
    assert got == want

    # And the integers really are the filter: an impulse returns the taps.
    frac = app.fixed.frac_bits
    impulse = [1 << frac] + [0] * app.result.numtaps
    taps = test_sv.run_rtl(tmp_path, src, "dut", impulse, app.fixed.bits, 3)
    assert taps[:app.result.numtaps] == [int(v) for v in app.fixed.ints]
