#!/usr/bin/env python3
"""Interactive Parks-McClellan (Remez exchange) FIR filter designer.

Constraints and filter parameters are entered on the left; the right hand side
plots the specification, the resulting amplitude response, the weighted error
with its extremal frequencies, and the impulse response.

Run with:  python remez_gui.py
"""

from __future__ import annotations

import tkinter as tk
from tkinter import filedialog, messagebox, ttk

import numpy as np
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg, NavigationToolbar2Tk
from matplotlib.figure import Figure

import remez_core as rz

# --------------------------------------------------------------------------
# Presets: (symmetry, taps, [(f1, f2, d1, d2, weight, spec_dB, inv_f)])
# Frequencies are fractions of fs and are scaled when a preset is loaded.
# --------------------------------------------------------------------------

PRESETS = {
    "Lowpass": ("symmetric", 41, [
        (0.00, 0.20, 1.0, 1.0, 1.0, 0.5, False),
        (0.25, 0.50, 0.0, 0.0, 10.0, 50.0, False),
    ]),
    "Highpass": ("symmetric", 41, [
        (0.00, 0.20, 0.0, 0.0, 10.0, 50.0, False),
        (0.25, 0.50, 1.0, 1.0, 1.0, 0.5, False),
    ]),
    "Bandpass": ("symmetric", 55, [
        (0.00, 0.12, 0.0, 0.0, 10.0, 50.0, False),
        (0.18, 0.32, 1.0, 1.0, 1.0, 0.5, False),
        (0.38, 0.50, 0.0, 0.0, 10.0, 50.0, False),
    ]),
    "Bandstop": ("symmetric", 55, [
        (0.00, 0.14, 1.0, 1.0, 1.0, 0.5, False),
        (0.20, 0.30, 0.0, 0.0, 10.0, 50.0, False),
        (0.36, 0.50, 1.0, 1.0, 1.0, 0.5, False),
    ]),
    "Multiband": ("symmetric", 75, [
        (0.00, 0.10, 1.0, 1.0, 1.0, 0.5, False),
        (0.15, 0.25, 0.4, 0.4, 1.0, 1.0, False),
        (0.30, 0.40, 0.0, 0.0, 8.0, 45.0, False),
        (0.45, 0.50, 1.0, 1.0, 1.0, 0.5, False),
    ]),
    "Hilbert transformer": ("antisymmetric", 41, [
        (0.05, 0.45, 1.0, 1.0, 1.0, 40.0, False),
    ]),
    "Differentiator": ("antisymmetric", 33, [
        (0.01, 0.45, 2 * np.pi * 0.01, 2 * np.pi * 0.45, 1.0, 40.0, True),
    ]),
    "Raised-cosine band": ("symmetric", 61, [
        (0.00, 0.15, 1.0, 1.0, 1.0, 0.5, False),
        (0.18, 0.28, 1.0, 0.0, 1.0, 1.0, False),
        (0.33, 0.50, 0.0, 0.0, 5.0, 45.0, False),
    ]),
}

COLUMNS = ["F start", "F stop", "Desired\nat start", "Desired\nat stop",
           "Weight", "Spec\n(dB)", "1/f"]
COL_WIDTH = [7, 7, 7, 7, 6, 6, 2]


def db(x, floor=1e-12):
    return 20.0 * np.log10(np.maximum(np.abs(x), floor))


class BandRow:
    """One row of the constraint table."""

    def __init__(self, table, index, values, on_change):
        self.table = table
        self.vars = [tk.StringVar(value=f"{v:g}") for v in values[:6]]
        self.inv_f = tk.BooleanVar(value=bool(values[6]))
        self.widgets = []
        for col, (var, width) in enumerate(zip(self.vars, COL_WIDTH)):
            e = ttk.Entry(table, textvariable=var, width=width, justify="right")
            e.grid(row=index + 1, column=col, padx=1, pady=1, sticky="ew")
            e.bind("<Return>", on_change)
            self.widgets.append(e)
        c = ttk.Checkbutton(table, variable=self.inv_f)
        c.grid(row=index + 1, column=6, padx=1)
        self.widgets.append(c)
        self.remove = ttk.Button(table, text="✕", width=2)
        self.remove.grid(row=index + 1, column=7, padx=(3, 0))
        self.widgets.append(self.remove)

    def regrid(self, index):
        for col, w in enumerate(self.widgets):
            w.grid_configure(row=index + 1, column=col)

    def destroy(self):
        for w in self.widgets:
            w.destroy()

    def read(self):
        return [float(v.get()) for v in self.vars] + [self.inv_f.get()]

    def set_spec_state(self, use_spec):
        self.widgets[4].configure(state="disabled" if use_spec else "normal")
        self.widgets[5].configure(state="normal" if use_spec else "disabled")


class RemezApp:
    def __init__(self, root):
        self.root = root
        root.title("Remez exchange FIR filter designer")
        root.geometry("1360x860")
        self.rows = []
        self.result = None
        self.spec_dev = None

        paned = ttk.PanedWindow(root, orient="horizontal")
        paned.pack(fill="both", expand=True)

        # Populate the panes before adding them: a ttk.PanedWindow sizes each
        # pane from its requested size at add time, and an empty frame asks for
        # one pixel.
        left = ttk.Frame(paned, padding=6)
        right = ttk.Frame(paned)
        self._build_controls(left)
        self._build_plot(right)
        paned.add(left, weight=0)
        paned.add(right, weight=1)
        self.paned = paned
        root.after_idle(self._place_sash)

        self.load_preset("Lowpass")
        self.design()

        # No multi-line field takes a plain Return, so it can mean "design".
        for key in ("<Return>", "<KP_Enter>", "<Control-Return>", "<F5>"):
            root.bind(key, lambda e: self.design())

    def _place_sash(self):
        """Give the controls the width they asked for, the plot the rest."""
        try:
            want = max(self.paned.winfo_children()[0].winfo_reqwidth(), 380)
            if self.paned.winfo_width() > want + 200:
                self.paned.sashpos(0, want)
        except (tk.TclError, IndexError):
            pass

    # ---------------------------------------------------------------- controls

    def _build_controls(self, parent):
        parent.columnconfigure(0, weight=1)

        # --- filter parameters -------------------------------------------
        box = ttk.LabelFrame(parent, text="Filter", padding=6)
        box.grid(row=0, column=0, sticky="ew")
        for c in (1, 3):
            box.columnconfigure(c, weight=1)

        self.numtaps = tk.IntVar(value=41)
        self.symmetry = tk.StringVar(value="symmetric")
        self.fs = tk.DoubleVar(value=1.0)
        self.grid_density = tk.IntVar(value=16)
        self.maxiter = tk.IntVar(value=60)

        ttk.Label(box, text="Taps (N)").grid(row=0, column=0, sticky="w")
        ttk.Spinbox(box, from_=3, to=2001, textvariable=self.numtaps, width=8,
                    command=self.design).grid(row=0, column=1, sticky="ew", padx=(2, 8))

        ttk.Label(box, text="Sample rate").grid(row=0, column=2, sticky="w")
        ttk.Entry(box, textvariable=self.fs, width=10).grid(row=0, column=3, sticky="ew", padx=2)

        ttk.Label(box, text="Symmetry").grid(row=1, column=0, sticky="w", pady=(4, 0))
        sym = ttk.Combobox(box, textvariable=self.symmetry, width=15, state="readonly",
                           values=["symmetric", "antisymmetric"])
        sym.grid(row=1, column=1, columnspan=3, sticky="ew", padx=2, pady=(4, 0))
        sym.bind("<<ComboboxSelected>>", lambda e: self.design())

        ttk.Label(box, text="Grid density").grid(row=2, column=0, sticky="w", pady=(4, 0))
        ttk.Spinbox(box, from_=4, to=256, textvariable=self.grid_density, width=8,
                    command=self.design).grid(row=2, column=1, sticky="ew", padx=(2, 8), pady=(4, 0))
        ttk.Label(box, text="Max iters").grid(row=2, column=2, sticky="w", pady=(4, 0))
        ttk.Spinbox(box, from_=1, to=500, textvariable=self.maxiter, width=8,
                    command=self.design).grid(row=2, column=3, sticky="ew", padx=2, pady=(4, 0))

        ttk.Label(box, text="Preset").grid(row=3, column=0, sticky="w", pady=(4, 0))
        self.preset = tk.StringVar(value="Lowpass")
        pre = ttk.Combobox(box, textvariable=self.preset, width=15, state="readonly",
                           values=list(PRESETS))
        pre.grid(row=3, column=1, columnspan=3, sticky="ew", padx=2, pady=(4, 0))
        pre.bind("<<ComboboxSelected>>",
                 lambda e: (self.load_preset(self.preset.get()), self.design()))

        # --- constraint table --------------------------------------------
        cbox = ttk.LabelFrame(parent, text="Bands and constraints", padding=6)
        cbox.grid(row=1, column=0, sticky="nsew", pady=(8, 0))
        parent.rowconfigure(1, weight=1)
        cbox.columnconfigure(0, weight=1)

        self.table = ttk.Frame(cbox)
        self.table.grid(row=0, column=0, sticky="ew")
        for col, (name, width) in enumerate(zip(COLUMNS, COL_WIDTH)):
            ttk.Label(self.table, text=name, width=width, anchor="center",
                      justify="center").grid(row=0, column=col, padx=1)

        btns = ttk.Frame(cbox)
        btns.grid(row=1, column=0, sticky="ew", pady=(6, 0))
        ttk.Button(btns, text="Add band", command=self.add_row).pack(side="left")
        ttk.Button(btns, text="Sort by frequency",
                   command=self.sort_rows).pack(side="left", padx=4)

        self.use_spec = tk.BooleanVar(value=False)
        ttk.Checkbutton(cbox, variable=self.use_spec, command=self._spec_toggled,
                        text="Weights from the Spec column:\n"
                             "passband ripple dB p-p / stopband atten. dB"
                        ).grid(row=2, column=0, sticky="w", pady=(6, 0))

        # --- actions -------------------------------------------------------
        act = ttk.Frame(parent)
        act.grid(row=2, column=0, sticky="ew", pady=(8, 0))
        ttk.Button(act, text="Design  (Ctrl+Enter)", command=self.design).pack(side="left")
        ttk.Button(act, text="Save coefficients…",
                   command=self.save_coefficients).pack(side="left", padx=4)
        ttk.Button(act, text="Save plot…", command=self.save_plot).pack(side="left")

        # --- display options -------------------------------------------------
        opt = ttk.LabelFrame(parent, text="Display", padding=6)
        opt.grid(row=3, column=0, sticky="ew", pady=(8, 0))
        self.log_scale = tk.BooleanVar(value=True)
        self.show_spec = tk.BooleanVar(value=True)
        self.show_ext = tk.BooleanVar(value=True)
        for i, (text, var) in enumerate([
                ("Magnitude in dB", self.log_scale),
                ("Show constraints", self.show_spec),
                ("Show extremal frequencies", self.show_ext)]):
            ttk.Checkbutton(opt, text=text, variable=var,
                            command=self.redraw).grid(row=i, column=0, sticky="w")

        # --- results ---------------------------------------------------------
        rbox = ttk.LabelFrame(parent, text="Result", padding=6)
        rbox.grid(row=4, column=0, sticky="nsew", pady=(8, 0))
        rbox.columnconfigure(0, weight=1)
        rbox.rowconfigure(0, weight=1)
        self.report = tk.Text(rbox, width=44, height=14, wrap="none",
                              font=("Menlo", 10), relief="flat")
        self.report.grid(row=0, column=0, sticky="nsew")
        self.report.configure(state="disabled")
        sb = ttk.Scrollbar(rbox, orient="vertical", command=self.report.yview)
        sb.grid(row=0, column=1, sticky="ns")
        self.report.configure(yscrollcommand=sb.set)

    def _build_plot(self, parent):
        self.fig = Figure(figsize=(8, 8), layout="constrained")
        gs = self.fig.add_gridspec(4, 1, height_ratios=[2.6, 1.2, 1.3, 1.1])
        self.ax_mag = self.fig.add_subplot(gs[0])
        self.ax_detail = self.fig.add_subplot(gs[1])
        self.ax_err = self.fig.add_subplot(gs[2])
        self.ax_imp = self.fig.add_subplot(gs[3])

        self.canvas = FigureCanvasTkAgg(self.fig, master=parent)
        self.canvas.get_tk_widget().pack(fill="both", expand=True)
        NavigationToolbar2Tk(self.canvas, parent).update()

    # ------------------------------------------------------------------- table

    def add_row(self, values=(0.0, 0.5, 1.0, 1.0, 1.0, 1.0, False)):
        row = BandRow(self.table, len(self.rows), list(values), lambda e: self.design())
        row.remove.configure(command=lambda r=row: self.remove_row(r))
        row.set_spec_state(self.use_spec.get())
        self.rows.append(row)
        return row

    def remove_row(self, row):
        if len(self.rows) <= 1:
            return
        self.rows.remove(row)
        row.destroy()
        for i, r in enumerate(self.rows):
            r.regrid(i)
        self.design()

    def clear_rows(self):
        for r in self.rows:
            r.destroy()
        self.rows = []

    def sort_rows(self):
        try:
            values = [r.read() for r in self.rows]
        except ValueError:
            return self._fail("Every field must be a number.")
        values.sort(key=lambda v: v[0])
        self.clear_rows()
        for v in values:
            self.add_row(v)
        self.design()

    def load_preset(self, name):
        symmetry, numtaps, bands = PRESETS[name]
        self.symmetry.set(symmetry)
        self.numtaps.set(numtaps)
        fs = self.fs.get() or 1.0
        self.clear_rows()
        for f1, f2, d1, d2, w, spec, inv in bands:
            self.add_row((f1 * fs, f2 * fs, d1, d2, w, spec, inv))

    def _spec_toggled(self):
        for r in self.rows:
            r.set_spec_state(self.use_spec.get())
        self.design()

    # ------------------------------------------------------------------ design

    def read_bands(self):
        """Build the band list, converting spec limits to weights if asked."""
        raw = []
        for i, row in enumerate(self.rows):
            try:
                f1, f2, d1, d2, w, spec, inv = row.read()
            except ValueError:
                raise rz.RemezError(f"band {i + 1}: every field must be a number")
            raw.append((f1, f2, d1, d2, w, spec, inv))

        weights = [r[4] for r in raw]
        self.spec_dev = None
        if self.use_spec.get():
            # A ripple spec of delta_i in band i is met when the weights are
            # inversely proportional to the deltas, since the exchange
            # equalises W_i * delta_i across all bands.
            devs = []
            for i, (f1, f2, d1, d2, w, spec, inv) in enumerate(raw):
                if spec <= 0:
                    raise rz.RemezError(f"band {i + 1}: the dB spec must be positive")
                peak = max(abs(d1), abs(d2))
                if peak < 1e-12:                       # stopband: attenuation
                    devs.append(10.0 ** (-spec / 20.0))
                else:                                   # passband: peak ripple
                    g = 10.0 ** (spec / 20.0)
                    devs.append(peak * (g - 1.0) / (g + 1.0))
            ref = max(devs)
            weights = [ref / d for d in devs]
            self.spec_dev = devs

        bands = []
        for (f1, f2, d1, d2, _w, _spec, inv), w in zip(raw, weights):
            bands.append(rz.Band(f1, f2, d1, d2, w1=w, w2=w,
                                 weight_kind="inv_f" if inv else "const"))
        return bands

    def design(self, *_):
        try:
            bands = self.read_bands()
            self.result = rz.design(
                int(self.numtaps.get()), bands,
                symmetry=self.symmetry.get(),
                fs=float(self.fs.get()),
                grid_density=int(self.grid_density.get()),
                maxiter=int(self.maxiter.get()),
            )
        except (rz.RemezError, ValueError, tk.TclError) as exc:
            self.result = None
            self._fail(str(exc))
            return
        self.redraw()
        self._report()

    def _fail(self, message):
        self.report.configure(state="normal")
        self.report.delete("1.0", "end")
        self.report.insert("1.0", "Cannot design this filter:\n\n" + message)
        self.report.configure(state="disabled")
        for ax in (self.ax_mag, self.ax_detail, self.ax_err, self.ax_imp):
            ax.clear()
        self.ax_mag.text(0.5, 0.5, "no filter", ha="center", va="center",
                         transform=self.ax_mag.transAxes, color="0.6")
        self.canvas.draw_idle()

    # ----------------------------------------------------------------- drawing

    def redraw(self):
        res = self.result
        if res is None:
            return
        nyq = res.fs / 2.0
        f = np.linspace(0.0, nyq, 4096)
        amp = rz.amplitude_response(res.h, 2 * np.pi * f / res.fs, res.symmetry)
        log = self.log_scale.get()

        # ---- amplitude ---------------------------------------------------
        ax = self.ax_mag
        ax.clear()
        y = db(amp) if log else amp
        ax.plot(f, y, lw=1.2, color="#1f77b4", label="designed response", zorder=3)

        if self.show_spec.get():
            self._draw_constraints(ax, res, log)
        if self.show_ext.get():
            ea = rz.amplitude_response(res.h, 2 * np.pi * res.extremal_f / res.fs,
                                       res.symmetry)
            ax.plot(res.extremal_f, db(ea) if log else ea, "o", ms=3.5,
                    color="#d62728", label="extremal frequencies", zorder=4)

        ax.set_xlim(0, nyq)
        if log:
            floor = min(-20.0, 20 * np.log10(max(abs(res.delta), 1e-12)) - 25)
            top = max(5.0, np.nanmax(y[np.isfinite(y)]) + 5)
            ax.set_ylim(max(floor, -220), top)
            ax.set_ylabel("amplitude (dB)")
        else:
            ax.set_ylabel("amplitude")
        ax.set_xlabel(f"frequency ({'normalised' if res.fs == 1.0 else 'Hz'})")
        ax.grid(alpha=0.3)
        ax.legend(loc="upper right", fontsize=8, framealpha=0.9)
        ax.set_title(f"Type {res.ftype} {res.symmetry} FIR, N = {res.numtaps}"
                     f"   —   {res.iterations} iterations"
                     f"{'' if res.converged else '  (did not converge)'}")

        # ---- passband detail ----------------------------------------------
        self._draw_detail(self.ax_detail, res, f, amp)

        # ---- weighted error ----------------------------------------------
        ax = self.ax_err
        ax.clear()
        for sl in self._segment_slices(res):
            ax.plot(res.grid_f[sl], res.grid_e[sl], lw=1.0, color="#2ca02c")
        d = abs(res.delta)
        ax.axhline(d, color="#888", ls="--", lw=0.9)
        ax.axhline(-d, color="#888", ls="--", lw=0.9)
        if self.show_ext.get():
            ax.plot(res.extremal_f, res.extremal_e, "o", ms=3.5, color="#d62728")
        ax.set_xlim(0, nyq)
        ax.set_ylim(-1.6 * d if d else -1, 1.6 * d if d else 1)
        ax.set_ylabel("weighted error")
        ax.set_xlabel("frequency")
        ax.grid(alpha=0.3)
        ax.set_title(f"W(f)·[D(f) − A(f)]   —   "
                     f"δ = {d:.4g}", fontsize=9)

        # ---- impulse response --------------------------------------------
        ax = self.ax_imp
        ax.clear()
        n = np.arange(res.numtaps)
        ax.stem(n, res.h, basefmt=" ", markerfmt="o", linefmt="-")
        for line in ax.get_lines():
            line.set_markersize(3)
            line.set_linewidth(0.9)
        ax.set_xlim(-0.5, res.numtaps - 0.5)
        ax.set_xlabel("tap")
        ax.set_ylabel("h[n]")
        ax.grid(alpha=0.3)
        ax.set_title("impulse response", fontsize=9)

        self.canvas.draw_idle()

    @staticmethod
    def _segment_slices(res):
        """Index slices of the grid, one per band, so bands are not joined up."""
        f = res.grid_f
        breaks = np.nonzero(np.diff(f) > 3 * np.median(np.diff(f)))[0]
        starts = np.r_[0, breaks + 1]
        stops = np.r_[breaks + 1, f.size]
        return [slice(a, b) for a, b in zip(starts, stops)]

    @staticmethod
    def _band_curves(res, band, npts=240):
        """Sample one band: (f, desired, achieved tolerance).

        Both the desired amplitude and the weight may vary across a band, so
        these are curves and not the straight lines between the edges that a
        two-point plot would draw -- in dB even a linear ramp is bent.
        """
        f = np.linspace(band.f1, band.f2, npts)
        span = band.f2 - band.f1
        t = np.zeros_like(f) if span <= 0 else (f - band.f1) / span
        des = band.d1 + t * (band.d2 - band.d1)
        if band.weight_kind == "inv_f":
            w = band.w1 / np.maximum(f / res.fs, 1e-9)
        else:
            w = band.w1 + t * (band.w2 - band.w1)
        # The exchange equalises W*|D - A|, so a band sits within delta/W of
        # its target.
        return f, des, abs(res.delta) / w

    def _draw_constraints(self, ax, res, log):
        """Desired response plus the achieved and requested tolerance bands."""
        first = True
        for i, b in enumerate(res.bands):
            f, des, tol = self._band_curves(res, b)
            hi, lo = des + tol, np.maximum(des - tol, 0.0)
            if log:
                dline, hi, lo = db(des), db(hi), db(lo)
            else:
                dline = des

            ax.plot(f, dline, color="#ff7f0e", lw=1.6, ls="--", zorder=2,
                    label="desired" if first else None)
            ax.fill_between(f, lo, hi, color="#ff7f0e", alpha=0.18, zorder=1,
                            label="achieved tolerance" if first else None)

            if self.spec_dev is not None:
                s = self.spec_dev[i]
                shi = des + s
                slo = np.maximum(des - s, 0.0)
                if log:
                    shi, slo = db(shi), db(slo)
                ax.plot(f, shi, color="#7f7f7f", lw=1.0, ls=":", zorder=2,
                        label="requested spec" if first else None)
                if np.all(np.isfinite(slo)) and np.any(slo > (-1e3 if log else 0)):
                    ax.plot(f, slo, color="#7f7f7f", lw=1.0, ls=":", zorder=2)
            first = False
            for edge in (b.f1, b.f2):
                ax.axvline(edge, color="0.75", lw=0.7, zorder=0)

    def _draw_detail(self, ax, res, f, amp):
        """Gain error against the target, for the bands where that has meaning.

        On the full-scale plot above, a half-dB of passband ripple is a line
        thickness.  Here each band with a non-zero target is drawn as
        20 log10(A/D), which puts the ripple of every such band -- whatever its
        gain, flat or sloped -- on one readable scale.
        """
        ax.clear()
        live = [b for b in res.bands if max(abs(b.d1), abs(b.d2)) > 1e-12]
        reach = 0.0
        for b in live:
            bf, des, tol = self._band_curves(res, b)
            a = np.interp(bf, f, amp)
            with np.errstate(divide="ignore", invalid="ignore"):
                ax.plot(bf, db(a / des), lw=1.2, color="#1f77b4", zorder=3)
                up = db(1.0 + tol / des)
                dn = db(np.maximum(1.0 - tol / des, 1e-12))
            ax.fill_between(bf, dn, up, color="#ff7f0e", alpha=0.18, zorder=1)
            ax.plot(bf, up, color="#ff7f0e", lw=1.0, ls="--", zorder=2)
            ax.plot(bf, dn, color="#ff7f0e", lw=1.0, ls="--", zorder=2)
            good = np.isfinite(up) & np.isfinite(dn)
            if good.any():
                reach = max(reach, float(np.max(np.abs(np.r_[up[good], dn[good]]))))
            for edge in (b.f1, b.f2):
                ax.axvline(edge, color="0.75", lw=0.7, zorder=0)

        ax.axhline(0.0, color="#ff7f0e", lw=1.4, ls="--", zorder=2)
        if reach > 0:
            ax.set_ylim(-1.6 * reach, 1.6 * reach)
        ax.set_xlim(0, res.fs / 2.0)
        ax.set_ylabel("gain error (dB)")
        ax.grid(alpha=0.3)
        ax.set_title("ripple against target, for bands with a non-zero target",
                     fontsize=9)
        if not live:
            ax.text(0.5, 0.5, "every band targets zero", ha="center", va="center",
                    transform=ax.transAxes, color="0.6", fontsize=9)

    # ------------------------------------------------------------------ report

    def _report(self):
        res = self.result
        out = []
        out.append(f"type {res.ftype}  ({res.symmetry}, "
                   f"{'odd' if res.numtaps % 2 else 'even'} length {res.numtaps})")
        out.append(f"iterations       {res.iterations}"
                   f"{'' if res.converged else '   *** did not converge ***'}")
        out.append(f"weighted delta   {abs(res.delta):.6g}")
        out.append("")
        out.append("band          range            deviation      dB")
        for i, (b, dev) in enumerate(zip(res.bands, res.band_deviation)):
            target = max(abs(b.d1), abs(b.d2))
            if target < 1e-12:
                label = f"{db(dev):8.2f} atten"
            else:
                label = f"{db(1 + dev / target) - db(1 - dev / target):8.2f} p-p"
            out.append(f"  {i + 1:<3d} {b.f1:8.4g}–{b.f2:<8.4g} "
                       f"{dev:12.4g}  {label}")

        if self.spec_dev is not None:
            out.append("")
            out.append("spec check")
            for i, (dev, want) in enumerate(zip(res.band_deviation, self.spec_dev)):
                verdict = "met" if dev <= want * 1.0001 else "MISSED"
                out.append(f"  band {i + 1}: achieved {dev:.4g}  "
                           f"required {want:.4g}   {verdict}")
            if any(dv > wt * 1.0001 for dv, wt in zip(res.band_deviation, self.spec_dev)):
                need = self._suggest_taps(res)
                if need:
                    out.append(f"  try about {need} taps to meet every spec")

        if res.peak_amplitude > 10 * max(1.0, max(abs(b.d1) for b in res.bands)):
            out.append("")
            out.append(f"warning: |A| reaches {res.peak_amplitude:.3g} in the")
            out.append("unconstrained transition region.  Add a band there or")
            out.append("use fewer taps.")

        out.append("")
        out.append("coefficients")
        for i, v in enumerate(res.h):
            out.append(f"  h[{i:<4d}] = {v: .12f}")

        self.report.configure(state="normal")
        self.report.delete("1.0", "end")
        self.report.insert("1.0", "\n".join(out))
        self.report.configure(state="disabled")

    def _suggest_taps(self, res):
        """Kaiser's order estimate over the narrowest transition band."""
        if self.spec_dev is None or len(res.bands) < 2:
            return None
        gaps = [(res.bands[i + 1].f1 - res.bands[i].f2, i)
                for i in range(len(res.bands) - 1)]
        gaps = [g for g in gaps if g[0] > 0]
        if not gaps:
            return None
        width, i = min(gaps)
        n = rz.kaiser_order_estimate(self.spec_dev[i], self.spec_dev[i + 1],
                                     width, res.fs)
        return n if n > 0 else None

    # ------------------------------------------------------------------ export

    def save_coefficients(self):
        if self.result is None:
            return
        path = filedialog.asksaveasfilename(
            title="Save coefficients",
            defaultextension=".csv",
            filetypes=[("CSV", "*.csv"), ("C header", "*.h"), ("Text", "*.txt")])
        if not path:
            return
        res = self.result
        try:
            if path.endswith(".h"):
                lines = [f"/* Parks-McClellan FIR, type {res.ftype}, "
                         f"N = {res.numtaps}, delta = {abs(res.delta):.6g} */",
                         f"#define FIR_TAPS {res.numtaps}",
                         "static const double fir_coeffs[FIR_TAPS] = {"]
                lines += [f"    {v: .17g}," for v in res.h]
                lines += ["};", ""]
            else:
                lines = [f"# Parks-McClellan FIR, type {res.ftype}, "
                         f"N = {res.numtaps}, fs = {res.fs:g}",
                         f"# weighted delta = {abs(res.delta):.10g}",
                         "n,h"]
                lines += [f"{i},{v:.17g}" for i, v in enumerate(res.h)]
            with open(path, "w") as fh:
                fh.write("\n".join(lines) + "\n")
        except OSError as exc:
            messagebox.showerror("Save failed", str(exc))

    def save_plot(self):
        if self.result is None:
            return
        path = filedialog.asksaveasfilename(
            title="Save plot", defaultextension=".png",
            filetypes=[("PNG", "*.png"), ("PDF", "*.pdf"), ("SVG", "*.svg")])
        if path:
            try:
                self.fig.savefig(path, dpi=150)
            except (OSError, ValueError) as exc:
                messagebox.showerror("Save failed", str(exc))


def main():
    root = tk.Tk()
    try:
        ttk.Style().theme_use("aqua")
    except tk.TclError:
        pass
    RemezApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
