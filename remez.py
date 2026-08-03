#!/usr/bin/env python3
"""Interactive digital filter designer: Remez-exchange FIR and classical IIR.

The mode selector at the top left chooses between the two design methods.  In
either mode the constraints and filter parameters are entered on the left and
the right hand side plots what came out.

FIR mode runs the Parks-McClellan exchange and plots the specification, the
amplitude response, the weighted error with its extremal frequencies, and the
impulse response.  IIR mode designs a Butterworth, Chebyshev or elliptic filter
by the bilinear transform and plots the magnitude, the passband detail, the
group delay and phase, the pole-zero pattern and the impulse and step
responses.

Run with:  python remez.py [DESIGN.json]; --help lists the options.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

import numpy as np
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg, NavigationToolbar2Tk
from matplotlib.figure import Figure

import datapath as dp
import fir_core as rz
import fixed_point as fp
import iir_core as ii
import rtl_common as rc
import sv_export as sv
import vhdl_export as vh

__version__ = "1.0"

MODE_FIR = "FIR — Remez exchange"
MODE_IIR = "IIR — bilinear transform"
MODES = [MODE_FIR, MODE_IIR]

ARITH_FLOAT = "float"
ARITH_FIXED = "fixed"

VIEW_PLOT = "Plot view"
VIEW_DESIGN = "Design view"
VIEWS = [VIEW_PLOT, VIEW_DESIGN]

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

# --------------------------------------------------------------------------
# IIR mode
# --------------------------------------------------------------------------

RESPONSE_LABELS = {"Lowpass": "lowpass", "Highpass": "highpass",
                   "Bandpass": "bandpass", "Bandstop": "bandstop"}
APPROX_LABELS = {"Butterworth": "butterworth", "Chebyshev I": "chebyshev1",
                 "Chebyshev II": "chebyshev2", "Elliptic": "elliptic"}
_RESPONSE_NAMES = {v: k for k, v in RESPONSE_LABELS.items()}
_APPROX_NAMES = {v: k for k, v in APPROX_LABELS.items()}

# (response, approximation, passband edges, stopband edges, rp dB, rs dB, order)
# Frequencies are fractions of fs; an order of None means "smallest that meets
# the specification".
IIR_PRESETS = {
    "Elliptic lowpass": ("lowpass", "elliptic", (0.20,), (0.25,), 0.5, 60.0, None),
    "Elliptic highpass": ("highpass", "elliptic", (0.25,), (0.20,), 0.5, 60.0, None),
    "Elliptic bandpass": ("bandpass", "elliptic", (0.18, 0.32), (0.12, 0.38),
                          0.5, 60.0, None),
    "Elliptic bandstop": ("bandstop", "elliptic", (0.14, 0.36), (0.20, 0.30),
                          0.5, 60.0, None),
    "Butterworth lowpass": ("lowpass", "butterworth", (0.20,), (0.32,), 1.0, 40.0, None),
    "Chebyshev I lowpass": ("lowpass", "chebyshev1", (0.20,), (0.28,), 0.5, 50.0, None),
    "Chebyshev II lowpass": ("lowpass", "chebyshev2", (0.20,), (0.28,), 0.5, 50.0, None),
    "Narrow notch": ("bandstop", "elliptic", (0.16, 0.24), (0.19, 0.21), 0.2, 50.0, None),
    "Steep anti-alias": ("lowpass", "elliptic", (0.22,), (0.25,), 0.1, 90.0, None),
}


def _number(value):
    """A field's worth of number: readable, and precise enough to scale back.

    %g at the default six figures turns 5925.925872 into 5925.93, and the
    original would not come back when the rate was set back.
    """
    return f"{value:.10g}"


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


class Panel(ttk.Frame):
    """A titled box whose contents can be folded away.

    Seven of these stacked up do not fit on a laptop screen.  The column they
    live in scrolls, and the button at the top right of each one folds its
    contents away, which is quicker than scrolling past something you are not
    using.

    Put contents in ``.body``, not in the panel itself.
    """

    SHOWN = "–"            # en dash: click to fold away
    HIDDEN = "+"

    def __init__(self, parent, title, row, collapsed=False, on_toggle=None):
        super().__init__(parent, padding=(6, 2, 6, 6))
        self.columnconfigure(0, weight=1)
        self.rowconfigure(2, weight=1)
        self._parent = parent
        self._row = row
        self._on_toggle = on_toggle
        self.title = title

        head = ttk.Frame(self)
        head.grid(row=0, column=0, sticky="ew")
        head.columnconfigure(0, weight=1)
        ttk.Label(head, text=title, font=("", 0, "bold")).grid(
            row=0, column=0, sticky="w")
        self.button = ttk.Button(head, width=2, command=self.toggle,
                                 style="Panel.TButton")
        self.button.grid(row=0, column=1, sticky="e")

        self._rule = ttk.Separator(self, orient="horizontal")
        self._rule.grid(row=1, column=0, sticky="ew", pady=(3, 5))

        self.body = ttk.Frame(self)
        self.body.grid(row=2, column=0, sticky="nsew")
        self.body.columnconfigure(0, weight=1)

        self.collapsed = False
        if collapsed:
            self.collapse()
        else:
            self._sync()

    def grid_into(self, **kw):
        """Grid the panel itself into the row it was told about."""
        kw.setdefault("column", 0)
        kw.setdefault("sticky", "new")
        self.grid(row=self._row, **kw)
        return self

    def _sync(self):
        self.button.configure(text=self.HIDDEN if self.collapsed else self.SHOWN)

    def collapse(self, collapsed=True):
        self.collapsed = bool(collapsed)
        if self.collapsed:
            self.body.grid_remove()
            self._rule.grid_remove()
        else:
            self._rule.grid()
            self.body.grid()
        self._sync()

    def toggle(self):
        self.collapse(not self.collapsed)
        if self._on_toggle is not None:
            self._on_toggle(self)


class RemezApp:
    def __init__(self, root):
        self.root = root
        root.title("Digital filter designer — Remez FIR and classical IIR")
        self._set_icon(root)
        root.geometry("1360x900")
        self.rows = []
        self.result = None
        self.iir_result = None
        self.spec_dev = None
        self.mode = tk.StringVar(value=MODE_FIR)
        self.view = tk.StringVar(value=VIEW_PLOT)

        # Arithmetic: the design is always carried out in double precision, and
        # the coefficients are rounded onto the chosen word length afterwards.
        # self.eff is what the filter actually is once that has happened, and is
        # what every plot, report and export works from.
        self.arith = tk.StringVar(value=ARITH_FLOAT)
        self.word_bits = tk.IntVar(value=16)
        self.auto_frac = tk.BooleanVar(value=True)
        self.frac_bits = tk.IntVar(value=15)
        self.headroom = tk.IntVar(value=2)
        self.fixed_coeffs = tk.BooleanVar(value=True)
        self.structure = tk.StringVar(value="chain")
        self.folded = tk.BooleanVar(value=False)
        self.show_noise = tk.BooleanVar(value=False)
        self.want_tb = tk.BooleanVar(value=True)
        self.last_rtl_written = []
        self.fixed = None
        self.eff = None
        self.min_bits = None            # smallest word length that meets the spec
        self._min_bits_key = None
        self._noise = None              # cached (freq, dB, rms) of the datapath

        # Every collapsible panel, by title, so their state can be saved and
        # restored with the rest of the design.
        self.panels = {}

        style = ttk.Style()
        style.configure("Panel.TButton", padding=(1, 0))

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

        self._sync_sample_rate()
        self.load_preset("Lowpass")
        self.design()

        # No multi-line field takes a plain Return, so it can mean "design".
        for key in ("<Return>", "<KP_Enter>", "<Control-Return>", "<F5>"):
            root.bind(key, lambda e: self.design())

    def _set_icon(self, root):
        """Give the window the program's icon, where the platform allows it.

        iconphoto is the portable one and is what Linux and Windows use for the
        window; iconbitmap takes the .ico and is what Windows wants for the
        taskbar.  A macOS Dock icon needs an application bundle rather than a
        running interpreter, so it will not change there.  None of this is worth
        failing to start over, so every step is allowed to decline.
        """
        folder = os.path.join(os.path.dirname(os.path.abspath(__file__)), "docs")
        images = []
        for size in (256, 32, 16):
            path = os.path.join(folder, f"icon-{size}.png")
            if os.path.exists(path):
                try:
                    images.append(tk.PhotoImage(file=path))
                except tk.TclError:
                    pass
        if images:
            # Tk drops an image the moment nothing refers to it.
            self._icon_images = images
            try:
                root.iconphoto(True, *images)
            except tk.TclError:
                pass
        ico = os.path.join(folder, "icon.ico")
        if os.path.exists(ico):
            try:
                root.iconbitmap(ico)
            except tk.TclError:
                pass                    # not a format this platform accepts

    def _place_sash(self):
        """Give the controls the width they asked for, the plot the rest.

        Called again on a mode switch, since the two panels do not ask for the
        same width, but only ever to widen: a sash the user has dragged out is
        theirs, and shuffling it on every switch would be maddening.
        """
        try:
            want = max(self.paned.winfo_children()[0].winfo_reqwidth(), 380)
            if self.paned.winfo_width() > want + 200 and self.paned.sashpos(0) < want:
                self.paned.sashpos(0, want)
        except (tk.TclError, IndexError):
            pass

    # ---------------------------------------------------------------- controls

    def _build_controls(self, outer):
        """A scrollable column: the mode selector, the two mode panels, and the
        shared panels below them, all stacked from the top.

        Nothing here stretches to fill the height.  Panels that grow with the
        window would have to take that space from somewhere, and what they took
        it from was the panels below them -- which is why the lower ones used to
        sit against the bottom of the pane.  Everything asks for the height it
        needs, the column scrolls if that does not fit, and the one widget with
        its own scrollbar (the report) is a fixed size.
        """
        outer.columnconfigure(0, weight=1)
        outer.rowconfigure(0, weight=1)

        canvas = tk.Canvas(outer, highlightthickness=0, borderwidth=0,
                           takefocus=0)
        canvas.grid(row=0, column=0, sticky="nsew")
        self.scroll = ttk.Scrollbar(outer, orient="vertical",
                                    command=canvas.yview)
        self.scroll.grid(row=0, column=1, sticky="ns")
        canvas.configure(yscrollcommand=self.scroll.set)
        self.canvas_controls = canvas

        # A right margin, so no panel's own scrollbar ends up flush against the
        # one that scrolls the whole column.
        parent = ttk.Frame(canvas, padding=(0, 0, 6, 0))
        window = canvas.create_window((0, 0), window=parent, anchor="nw")
        self.controls = parent

        def fit_contents(_event=None):
            # The canvas asks the paned window for the width the controls need;
            # its own children do not contribute to that on their own.
            need = parent.winfo_reqwidth()
            canvas.configure(scrollregion=canvas.bbox("all"), width=need)
            stretch(need)
            self._place_sash()

        def stretch(need):
            # Fill the canvas when there is room to spare, but never squeeze the
            # controls below the width they need: grid would answer by clipping
            # the right-hand end of the band table.
            canvas.itemconfigure(window,
                                 width=max(canvas.winfo_width(), need))

        def fill_width(event):
            stretch(parent.winfo_reqwidth())

        parent.bind("<Configure>", fit_contents)
        canvas.bind("<Configure>", fill_width)
        self._fit_controls = fit_contents

        # Scroll only while the pointer is over the column, so the wheel still
        # belongs to the plot when it is over the plot.
        canvas.bind("<Enter>", lambda e: canvas.bind_all("<MouseWheel>",
                                                         self._wheel))
        canvas.bind("<Leave>", lambda e: canvas.unbind_all("<MouseWheel>"))

        parent.columnconfigure(0, weight=1)

        sel = ttk.Frame(parent)
        sel.grid(row=0, column=0, sticky="ew", pady=(0, 6))
        sel.columnconfigure(1, weight=1)
        ttk.Label(sel, text="Mode").grid(row=0, column=0, sticky="w")
        combo = ttk.Combobox(sel, textvariable=self.mode, state="readonly",
                             values=MODES, width=24)
        combo.grid(row=0, column=1, sticky="ew", padx=(6, 0))
        combo.bind("<<ComboboxSelected>>", lambda e: self.switch_mode())

        self.fir_panel = ttk.Frame(parent)
        self.iir_panel = ttk.Frame(parent)
        for panel in (self.fir_panel, self.iir_panel):
            panel.grid(row=1, column=0, sticky="new")
            panel.columnconfigure(0, weight=1)
        self._build_fir_controls(self.fir_panel)
        self._build_iir_controls(self.iir_panel)
        self.iir_panel.grid_remove()

        self._build_arithmetic(parent)
        self._build_actions(parent)
        self._build_display(parent)
        self._build_report(parent)
        parent.after_idle(self._fit_controls)

    def _wheel(self, event):
        """One notch of the wheel, whichever platform's units it arrives in."""
        delta = event.delta
        if abs(delta) >= 120:                 # Windows and X11 report multiples
            delta //= 120
        try:
            self.canvas_controls.yview_scroll(-int(delta), "units")
        except tk.TclError:
            pass

    def _panel(self, parent, title, row, label=None, **grid):
        """Make a collapsible panel, register it under ``title``, and grid it.

        ``label`` overrides the heading, for the two panels whose headings would
        otherwise collide between the modes.
        """
        panel = Panel(parent, label or title, row,
                      on_toggle=self._panel_toggled)
        panel.grid_into(**grid)
        self.panels[title] = panel
        return panel

    def _panel_toggled(self, panel):
        """Folding changes how tall and how wide the column wants to be."""
        self._fit_controls()
        self._place_sash()

    def _build_arithmetic(self, parent):
        """Floating point, or a fixed-point word length to quantize onto."""
        box = self._panel(parent, "Arithmetic", 2, pady=(8, 0)).body
        box.columnconfigure(4, weight=1)

        ttk.Radiobutton(box, text="Floating point (double)", value=ARITH_FLOAT,
                        variable=self.arith, command=self._arith_changed
                        ).grid(row=0, column=0, columnspan=5, sticky="w")
        ttk.Radiobutton(box, text="Fixed point", value=ARITH_FIXED,
                        variable=self.arith, command=self._arith_changed
                        ).grid(row=1, column=0, sticky="w")

        self.fixed_widgets = []
        ttk.Label(box, text="word").grid(row=1, column=1, sticky="e", padx=(8, 2))
        w = ttk.Spinbox(box, from_=fp.MIN_BITS, to=fp.MAX_BITS, width=4,
                        textvariable=self.word_bits, command=self._arith_changed)
        w.grid(row=1, column=2, sticky="w")
        ttk.Label(box, text="bits").grid(row=1, column=3, sticky="w", padx=(2, 0))
        self.fixed_widgets.append(w)
        self.word_bits_widget = w

        c = ttk.Checkbutton(box, text="place the binary point automatically",
                            variable=self.auto_frac, command=self._arith_changed)
        c.grid(row=2, column=0, columnspan=5, sticky="w", pady=(2, 0))
        self.fixed_widgets.append(c)

        ttk.Label(box, text="fraction").grid(row=3, column=1, sticky="e", padx=(8, 2))
        f = ttk.Spinbox(box, from_=-64, to=64, width=4, textvariable=self.frac_bits,
                        command=self._arith_changed)
        f.grid(row=3, column=2, sticky="w")
        ttk.Label(box, text="bits").grid(row=3, column=3, sticky="w", padx=(2, 0))
        self.fixed_widgets.append(f)
        self.frac_spin = f

        # Headroom widens the datapath above the coefficient format, which is
        # what keeps a chain of saturating adds off its limits.  It changes the
        # hardware, not the coefficients, so it does not requantize anything.
        ttk.Label(box, text="headroom").grid(row=4, column=1, sticky="e", padx=(8, 2))
        hr = ttk.Spinbox(box, from_=0, to=32, width=4, textvariable=self.headroom,
                         command=self._arith_changed)
        hr.grid(row=4, column=2, sticky="w")
        ttk.Label(box, text="bits").grid(row=4, column=3, sticky="w", padx=(2, 0))
        self.fixed_widgets.append(hr)
        self.headroom_spin = hr

        c = ttk.Checkbutton(box, text="fixed coefficients (built into the RTL)",
                            variable=self.fixed_coeffs, command=self._arith_changed)
        c.grid(row=5, column=0, columnspan=5, sticky="w", pady=(2, 0))
        self.fixed_widgets.append(c)

        # The structure is what trades combinational depth against area: a
        # chain is smallest and slowest, a tree is deeper in registers but
        # shorter in logic, and a MAC is one multiplier at one term per clock.
        ttk.Label(box, text="structure").grid(row=6, column=0, sticky="w",
                                              pady=(4, 0))
        st = ttk.Combobox(box, textvariable=self.structure, state="readonly",
                          width=22, values=list(dp.STRUCTURES))
        st.grid(row=6, column=1, columnspan=4, sticky="ew", padx=2, pady=(4, 0))
        st.bind("<<ComboboxSelected>>", self._arith_changed)
        self.fixed_widgets.append(st)
        self.structure_combo = st

        c = ttk.Checkbutton(box, text="fold the symmetry (half the multipliers)",
                            variable=self.folded, command=self._arith_changed)
        c.grid(row=7, column=0, columnspan=5, sticky="w")
        self.fixed_widgets.append(c)
        self.fold_check = c

        c = ttk.Checkbutton(box, text="write a self-checking testbench beside it",
                            variable=self.want_tb)
        c.grid(row=8, column=0, columnspan=5, sticky="w")
        self.fixed_widgets.append(c)

        self.arith_status = tk.StringVar(value="")
        ttk.Label(box, textvariable=self.arith_status, foreground="#555",
                  justify="left").grid(row=9, column=0, columnspan=5, sticky="w",
                                       pady=(4, 0))
        self._sync_arith_widgets()

    def _sync_arith_widgets(self):
        """Grey out what does not apply: the word length, or the FIR structures."""
        fixed = self.is_fixed()
        for w in self.fixed_widgets:
            w.configure(state="normal" if fixed else "disabled")
        if fixed and self.auto_frac.get():
            self.frac_spin.configure(state="disabled")
        if self.is_iir():
            # A biquad cascade has nothing to fold and cannot be pipelined
            # through its own feedback.
            self.structure_combo.configure(state="disabled")
            self.fold_check.configure(state="disabled")

    def _build_actions(self, parent):
        # Two rows: one wide row of five buttons would set the width of the
        # whole control column, and the plot would pay for it.
        act = ttk.Frame(parent)
        act.grid(row=3, column=0, sticky="ew", pady=(8, 0))
        for column in range(3):
            act.columnconfigure(column, weight=1)
        buttons = [("Design  (Ctrl+Enter)", self.design, 0, 0, 2),
                   ("Save plot…", self.save_plot, 0, 2, 1),
                   ("Open design…", self.open_design, 1, 0, 1),
                   ("Save design…", self.save_design, 1, 1, 1),
                   ("Save coefficients…", self.save_coefficients, 1, 2, 1),
                   ("Save C…", self.save_c_source, 2, 0, 1),
                   ("Generate SV…", self.save_sv_source, 2, 1, 1),
                   ("Generate VHDL…", self.save_vhdl_source, 2, 2, 1)]
        for text, command, row, column, span in buttons:
            ttk.Button(act, text=text, command=command).grid(
                row=row, column=column, columnspan=span, sticky="ew",
                padx=(0, 3), pady=(0, 3))

    def _build_display(self, parent):
        opt = self._panel(parent, "Display", 4, pady=(8, 0)).body
        self.log_scale = tk.BooleanVar(value=True)
        self.show_spec = tk.BooleanVar(value=True)
        self.show_ext = tk.BooleanVar(value=True)
        for i, (text, var) in enumerate([
                ("Magnitude in dB", self.log_scale),
                ("Show constraints", self.show_spec),
                ("Show extremal frequencies", self.show_ext),
                ("Measure the fixed-point noise floor", self.show_noise)]):
            command = (self._noise_toggled if var is self.show_noise
                       else self.redraw)
            w = ttk.Checkbutton(opt, text=text, variable=var, command=command)
            w.grid(row=i, column=0, sticky="w")
            if var is self.show_ext:
                self.ext_check = w          # FIR only; greyed out in IIR mode
            if var is self.show_noise:
                self.noise_check = w

    def _build_report(self, parent):
        rbox = self._panel(parent, "Result", 5, pady=(8, 0)).body
        rbox.columnconfigure(0, weight=1)
        # A fixed height: the report scrolls itself, so it has no reason to grow
        # with the window, and growing is what pushed the panels apart.
        self.report = tk.Text(rbox, width=44, height=16, wrap="none",
                              font=("Menlo", 10), relief="flat")
        self.report.grid(row=0, column=0, sticky="nsew")
        self.report.configure(state="disabled")
        sb = ttk.Scrollbar(rbox, orient="vertical", command=self.report.yview)
        # Inset, so it reads as the report's own scrollbar rather than as part
        # of the one scrolling the whole column.
        sb.grid(row=0, column=1, sticky="ns", padx=(3, 4))
        self.report.configure(yscrollcommand=sb.set)
        self.report_scroll = sb

    def _build_fir_controls(self, parent):
        parent.columnconfigure(0, weight=1)

        # --- filter parameters -------------------------------------------
        box = self._panel(parent, "Filter", 0).body
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
        self._watch_sample_rate(
            ttk.Entry(box, textvariable=self.fs, width=10)
        ).grid(row=0, column=3, sticky="ew", padx=2)

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
        cbox = self._panel(parent, "Bands and constraints", 1,
                           pady=(8, 0)).body
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

    def _build_iir_controls(self, parent):
        parent.columnconfigure(0, weight=1)

        self.response = tk.StringVar(value="Lowpass")
        self.approximation = tk.StringVar(value="Elliptic")
        self.iir_order = tk.IntVar(value=6)
        self.auto_order = tk.BooleanVar(value=True)
        self.iir_preset = tk.StringVar(value="Elliptic lowpass")

        # --- filter parameters -------------------------------------------
        box = self._panel(parent, "Filter (IIR)", 0, label="Filter").body
        box.columnconfigure(1, weight=1)
        box.columnconfigure(3, weight=1)

        ttk.Label(box, text="Response").grid(row=0, column=0, sticky="w")
        resp = ttk.Combobox(box, textvariable=self.response, state="readonly",
                            width=14, values=list(RESPONSE_LABELS))
        resp.grid(row=0, column=1, columnspan=3, sticky="ew", padx=2)
        resp.bind("<<ComboboxSelected>>",
                  lambda e: (self._edge_fields_for_response(), self.design()))

        ttk.Label(box, text="Approximation").grid(row=1, column=0, sticky="w", pady=(4, 0))
        appr = ttk.Combobox(box, textvariable=self.approximation, state="readonly",
                            width=14, values=list(APPROX_LABELS))
        appr.grid(row=1, column=1, columnspan=3, sticky="ew", padx=2, pady=(4, 0))
        appr.bind("<<ComboboxSelected>>", lambda e: self.design())

        ttk.Label(box, text="Order (N)").grid(row=2, column=0, sticky="w", pady=(4, 0))
        self.order_spin = ttk.Spinbox(box, from_=1, to=40, textvariable=self.iir_order,
                                      width=8, command=self.design)
        self.order_spin.grid(row=2, column=1, sticky="ew", padx=(2, 8), pady=(4, 0))
        ttk.Checkbutton(box, text="smallest that meets the spec",
                        variable=self.auto_order, command=self._auto_order_toggled
                        ).grid(row=2, column=2, columnspan=2, sticky="w", pady=(4, 0))

        # The sample rate is shared with FIR mode: it is a property of the
        # signal, not of how the filter happens to be designed.
        ttk.Label(box, text="Sample rate").grid(row=3, column=0, sticky="w", pady=(4, 0))
        self._watch_sample_rate(ttk.Entry(box, textvariable=self.fs, width=10)).grid(
            row=3, column=1, sticky="ew", padx=(2, 8), pady=(4, 0))

        ttk.Label(box, text="Preset").grid(row=4, column=0, sticky="w", pady=(4, 0))
        pre = ttk.Combobox(box, textvariable=self.iir_preset, state="readonly",
                           width=14, values=list(IIR_PRESETS))
        pre.grid(row=4, column=1, columnspan=3, sticky="ew", padx=2, pady=(4, 0))
        pre.bind("<<ComboboxSelected>>",
                 lambda e: (self.load_iir_preset(self.iir_preset.get()), self.design()))

        # --- the specification --------------------------------------------
        sbox = self._panel(parent, "Bands and specification", 1,
                           pady=(8, 0)).body
        for c in (1, 2):
            sbox.columnconfigure(c, weight=1)

        ttk.Label(sbox, text="lower", anchor="center").grid(row=0, column=1, sticky="ew")
        self.edge_hi_label = ttk.Label(sbox, text="upper", anchor="center")
        self.edge_hi_label.grid(row=0, column=2, sticky="ew")

        self.iir_wp = [tk.StringVar(value="0.2"), tk.StringVar(value="0.4")]
        self.iir_ws = [tk.StringVar(value="0.25"), tk.StringVar(value="0.45")]
        self.edge_entries = {}
        for row, (text, vars_) in enumerate([("Passband edge", self.iir_wp),
                                             ("Stopband edge", self.iir_ws)], start=1):
            ttk.Label(sbox, text=text).grid(row=row, column=0, sticky="w", pady=1)
            widgets = []
            for col, var in enumerate(vars_):
                e = ttk.Entry(sbox, textvariable=var, width=9, justify="right")
                e.grid(row=row, column=col + 1, sticky="ew", padx=2, pady=1)
                e.bind("<Return>", lambda ev: self.design())
                widgets.append(e)
            self.edge_entries[text] = widgets

        self.iir_rp = tk.DoubleVar(value=0.5)
        self.iir_rs = tk.DoubleVar(value=60.0)
        for row, (text, var) in enumerate([("Passband ripple (dB p-p)", self.iir_rp),
                                           ("Stopband attenuation (dB)", self.iir_rs)],
                                          start=3):
            ttk.Label(sbox, text=text).grid(row=row, column=0, sticky="w", pady=(4, 0))
            e = ttk.Entry(sbox, textvariable=var, width=9, justify="right")
            e.grid(row=row, column=1, sticky="ew", padx=2, pady=(4, 0))
            e.bind("<Return>", lambda ev: self.design())

        ttk.Label(sbox, wraplength=300, foreground="#555",
                  text="Chebyshev II is placed on the stopband edge and the other "
                       "three on the passband edge; the opposite edge is where the "
                       "order is worked out from."
                  ).grid(row=5, column=0, columnspan=3, sticky="w", pady=(6, 0))

        self._edge_fields_for_response()
        self._auto_order_toggled(design=False)

    def _build_plot(self, parent):
        bar = ttk.Frame(parent, padding=(6, 4))
        bar.pack(fill="x")
        ttk.Label(bar, text="View").pack(side="left")
        combo = ttk.Combobox(bar, textvariable=self.view, state="readonly",
                             values=VIEWS, width=14)
        combo.pack(side="left", padx=(6, 0))
        combo.bind("<<ComboboxSelected>>", lambda e: self.switch_view())
        self.view_hint = ttk.Label(bar, foreground="#666", text="")
        self.view_hint.pack(side="left", padx=(10, 0))

        self.fig = Figure(figsize=(8, 8), layout="constrained")
        self.canvas = FigureCanvasTkAgg(self.fig, master=parent)
        self.canvas.get_tk_widget().pack(fill="both", expand=True)
        NavigationToolbar2Tk(self.canvas, parent).update()
        self._layout_axes()

    def _layout_axes(self):
        """Lay the figure out for the current mode and view.

        Nothing survives a switch: the two modes have nothing useful in common
        to plot -- an equiripple error curve means nothing for an IIR filter,
        and a pole-zero pattern means nothing for an FIR one -- and the design
        view is one bare set of axes rather than a stack of them.
        """
        self.fig.clear()
        self.view_hint.configure(
            text="the structure you would build, with its actual constants"
            if self.is_design() else "")
        if self.is_design():
            self.ax_design = self.fig.add_subplot(111)
            self.ax_design.set_axis_off()
        elif self.is_iir():
            gs = self.fig.add_gridspec(4, 2, height_ratios=[2.5, 1.2, 1.2, 1.5])
            self.ax_imag = self.fig.add_subplot(gs[0, :])
            self.ax_idetail = self.fig.add_subplot(gs[1, :])
            self.ax_delay = self.fig.add_subplot(gs[2, :])
            self.ax_phase = self.ax_delay.twinx()
            self.ax_pz = self.fig.add_subplot(gs[3, 0])
            self.ax_step = self.fig.add_subplot(gs[3, 1])
            self.ax_imp2 = self.ax_step.twinx()
        else:
            gs = self.fig.add_gridspec(4, 1, height_ratios=[2.6, 1.2, 1.3, 1.1])
            self.ax_mag = self.fig.add_subplot(gs[0])
            self.ax_detail = self.fig.add_subplot(gs[1])
            self.ax_err = self.fig.add_subplot(gs[2])
            self.ax_imp = self.fig.add_subplot(gs[3])

    # --------------------------------------------------------- mode and view

    def is_iir(self):
        return self.mode.get() == MODE_IIR

    def is_design(self):
        return self.view.get() == VIEW_DESIGN

    def switch_view(self):
        """Swap between the response plots and the structure diagram."""
        self._layout_axes()
        if (self.iir_result if self.is_iir() else self.result) is None:
            self.design()
        else:
            self.redraw()

    def switch_mode(self):
        """Show the panel and the axes belonging to the newly selected mode."""
        if self.is_iir():
            self.fir_panel.grid_remove()
            self.iir_panel.grid()
        else:
            self.iir_panel.grid_remove()
            self.fir_panel.grid()
        self.ext_check.configure(state="disabled" if self.is_iir() else "normal")
        self._layout_axes()
        self.design()
        self._place_sash()

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

    # -------------------------------------------------------------- IIR inputs

    def _edge_fields_for_response(self):
        """A lowpass or highpass has one edge of each kind; the band types two."""
        two = RESPONSE_LABELS[self.response.get()] in ("bandpass", "bandstop")
        for widgets in self.edge_entries.values():
            widgets[1].configure(state="normal" if two else "disabled")
        self.edge_hi_label.configure(foreground="" if two else "#999")

    def _auto_order_toggled(self, design=True):
        self.order_spin.configure(state="disabled" if self.auto_order.get() else "normal")
        if design:
            self.design()

    def load_iir_preset(self, name):
        response, approximation, wp, ws, rp, rs, order = IIR_PRESETS[name]
        fs = self.fs.get() or 1.0
        self.response.set(_RESPONSE_NAMES[response])
        self.approximation.set(_APPROX_NAMES[approximation])
        for var, edges in ((self.iir_wp, wp), (self.iir_ws, ws)):
            for i, f in enumerate(edges):
                var[i].set(f"{f * fs:g}")
        self.iir_rp.set(rp)
        self.iir_rs.set(rs)
        self.auto_order.set(order is None)
        if order is not None:
            self.iir_order.set(order)
        self._edge_fields_for_response()
        self._auto_order_toggled(design=False)

    def read_iir_spec(self):
        """The IIR specification as the core module wants it."""
        response = RESPONSE_LABELS[self.response.get()]
        n = 2 if response in ("bandpass", "bandstop") else 1
        try:
            wp = [float(v.get()) for v in self.iir_wp[:n]]
            ws = [float(v.get()) for v in self.iir_ws[:n]]
            rp = float(self.iir_rp.get())
            rs = float(self.iir_rs.get())
        except (ValueError, tk.TclError):
            raise ii.IIRError("every band edge and dB figure must be a number")
        return response, APPROX_LABELS[self.approximation.get()], wp, ws, rp, rs

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

    def _watch_sample_rate(self, entry):
        """Rescale the band edges when this entry's value is committed.

        Not on every keystroke: a variable trace would fire on the "4" of
        "48000" and rescale by four before the user had finished typing.
        Committing means Return or moving the focus away.
        """
        entry.bind("<Return>", self._sample_rate_changed, add="+")
        entry.bind("<KP_Enter>", self._sample_rate_changed, add="+")
        entry.bind("<FocusOut>", self._sample_rate_changed, add="+")
        return entry

    def _sync_sample_rate(self):
        """Take the current rate as the one the band edges are already in."""
        try:
            rate = float(self.fs.get())
        except (tk.TclError, ValueError):
            return
        if rate > 0:
            self.fs_baseline = rate

    def _sample_rate_changed(self, _event=None):
        """Move the band edges to the new units, keeping the same filter.

        Edges are entered in whatever units the sample rate is in, so changing
        1.0 to 48000 means the same 0.2 is now 9600 -- the number changes and
        the filter does not.  Only frequencies move: gains, weights and the dB
        specs mean the same thing at any rate.
        """
        # FocusOut arrives while a window is being torn down as well as when
        # the user clicks away, and redrawing into half-destroyed widgets is
        # not worth finding out the consequences of.
        try:
            if not self.root.winfo_exists():
                return
        except tk.TclError:
            return
        try:
            rate = float(self.fs.get())
        except (tk.TclError, ValueError):
            return                          # mid-edit, or not a number yet
        old = getattr(self, "fs_baseline", None)
        if not (rate > 0) or not old or rate == old:
            if rate > 0:
                self.fs_baseline = rate
            return

        ratio = rate / old
        self.fs_baseline = rate
        for var in self._frequency_fields():
            try:
                value = float(var.get())
            except ValueError:
                continue                    # leave anything unparsed alone
            var.set(_number(value * ratio))
        try:
            self.design()
        except tk.TclError:
            pass

    def _frequency_fields(self):
        """Every entry holding a frequency, in either mode.

        Both mode panels are kept up to date, not just the visible one: the
        rate is shared between them, and a stale edge in the other mode would
        be wrong the moment it was switched to.
        """
        fields = []
        for row in self.rows:
            fields += row.vars[:2]          # F start and F stop
        fields += list(self.iir_wp) + list(self.iir_ws)
        return fields

    def is_fixed(self):
        return self.arith.get() == ARITH_FIXED

    def _apply_arithmetic(self):
        """Quantize the current design onto the chosen word length.

        Leaves ``self.eff`` as the design itself in floating point mode, and as
        a re-analysed copy carrying the rounded coefficients in fixed point.
        """
        res = self.iir_result if self.is_iir() else self.result
        self.fixed = None
        self.eff = res
        self._sync_arith_widgets()
        if res is None:
            self.arith_status.set("")
            return
        if not self.is_fixed():
            self.arith_status.set("coefficients used exactly as designed")
            return

        try:
            bits = int(self.word_bits.get())
            frac = None if self.auto_frac.get() else int(self.frac_bits.get())
            if self.is_iir():
                self.fixed = fp.quantize_sos(res.sos, bits, frac)
                self.eff = ii.with_sos(res, self.fixed.values)
            else:
                self.fixed = fp.quantize(res.h, bits, frac)
                self.eff = rz.with_taps(res, self.fixed.values)
        except (fp.FixedPointError, rz.RemezError, ii.IIRError,
                ValueError, tk.TclError) as exc:
            self.fixed = None
            self.eff = res
            self.arith_status.set(f"not quantized: {exc}")
            return

        q = self.fixed
        if self.auto_frac.get():
            self.frac_bits.set(q.frac_bits)
        lo, hi = q.limits
        try:
            headroom = max(int(self.headroom.get()), 0)
        except tk.TclError:
            headroom = 0
        smallest = self._smallest_word_length()
        note = (f"{smallest} bits is the narrowest that meets the spec"
                if smallest else "no word length up to 32 bits meets the spec")
        try:
            plan = rc.plan_for("iir" if self.is_iir() else "fir",
                               self.eff, q, self.rtl_options())
            cost = (f"{plan.resources['multipliers']} mult, "
                    f"{plan.resources['adders']} add, "
                    f"latency {plan.latency}")
        except rc.RtlError as exc:
            cost = str(exc).split(";")[0][:48]
        self.arith_status.set(
            f"{q.qformat}   step {q.step:.3g}   "
            f"range [{lo * q.step:g}, {hi * q.step:g}]\n"
            f"largest coefficient error {q.max_error:.3g}\n"
            f"RTL datapath {q.bits + headroom} bits "
            f"(Q{q.int_bits + headroom}.{q.frac_bits}), coefficients "
            + ("built in" if self.fixed_coeffs.get() else "on a port") + "\n"
            + cost + "\n" + note
            + (f"\n***  {q.saturated} saturated  ***" if q.saturated else ""))

    def rtl_options(self, name="filt"):
        """The hardware options, as the back-ends want them."""
        return sv.RtlOptions(
            name=name,
            headroom=int(self.headroom.get()),
            fixed_coeffs=bool(self.fixed_coeffs.get()),
            structure="chain" if self.is_iir() else self.structure.get(),
            folded=False if self.is_iir() else bool(self.folded.get()))

    def _smallest_word_length(self):
        """The narrowest coefficient word that still meets the specification.

        Answers the question the word-length spinbox otherwise gets walked up and
        down to answer.  Against the dB specs when they are being used, and
        otherwise against the design's own deviation, allowing the quantized
        filter a quarter of a dB of slack on it.
        """
        res = self.iir_result if self.is_iir() else self.result
        if res is None:
            return None
        key = (id(res), self.is_iir(), tuple(self.spec_dev or ()),
               None if self.auto_frac.get() else int(self.frac_bits.get()))
        if key == self._min_bits_key:
            return self.min_bits

        frac = None if self.auto_frac.get() else int(self.frac_bits.get())
        if self.is_iir():
            def meets(bits):
                q = fp.quantize_sos(res.sos, bits, frac)
                if q.saturated:
                    return False
                eff = ii.with_sos(res, q.values)
                return bool(eff.stable and eff.meets_spec)
        else:
            slack = 10.0 ** (0.25 / 20.0)          # a quarter of a dB
            want = (list(self.spec_dev) if self.spec_dev is not None
                    else [d * slack for d in res.band_deviation])

            def meets(bits):
                q = fp.quantize(res.h, bits, frac)
                if q.saturated:
                    return False
                eff = rz.with_taps(res, q.values)
                return all(got <= limit * 1.0001
                           for got, limit in zip(eff.band_deviation, want))

        found = None
        for bits in range(fp.MIN_BITS, 33):
            try:
                if meets(bits):
                    found = bits
                    break
            except (fp.FixedPointError, rz.RemezError, ii.IIRError, ValueError):
                continue
        self._min_bits_key = key
        self.min_bits = found
        return found

    def _noise_floor(self):
        """Measure what the fixed-point datapath adds, cached per configuration."""
        if self.fixed is None or self.eff is None:
            return None
        q = self.fixed
        opts = self.rtl_options()
        key = (id(self.eff), q.bits, q.frac_bits, opts.headroom, opts.structure,
               opts.folded, self.is_iir())
        if self._noise is not None and self._noise[0] == key:
            return self._noise[1]

        try:
            if self.is_iir():
                live = [0, 1, 2, 4, 5]
                coeffs = [[int(row[i]) for i in live] for row in q.ints]
                sos = self.eff.sos

                def exact(x):
                    return ii.sos_filter(sos, x)
                measured = dp.noise_response(
                    "iir", coeffs, exact, q.frac_bits, q.bits, opts.headroom)
            else:
                taps = self.eff.h

                def exact(x):
                    return np.convolve(x, taps)[:len(x)]
                measured = dp.noise_response(
                    "fir", q.ints, exact, q.frac_bits, q.bits, opts.headroom,
                    structure=opts.structure, folded=opts.folded,
                    symmetry=self.eff.symmetry)
        except (dp.DatapathError, ValueError):
            return None
        self._noise = (key, measured)
        return measured

    def _arith_changed(self, *_):
        """An arithmetic control moved: requantize, but do not redesign."""
        self._apply_arithmetic()
        if self.eff is not None:
            self.redraw()
            self._report()

    def design(self, *_):
        if self.is_iir():
            return self.design_iir()
        return self.design_fir()

    def design_fir(self):
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
            self._apply_arithmetic()
            self._fail(str(exc))
            return
        self._apply_arithmetic()
        self.redraw()
        self._report()

    def design_iir(self):
        try:
            response, approximation, wp, ws, rp, rs = self.read_iir_spec()
            order = None if self.auto_order.get() else int(self.iir_order.get())
            self.iir_result = ii.design(
                response, approximation, wp=wp, ws=ws, rp=rp, rs=rs,
                order=order, fs=float(self.fs.get()),
            )
        except (ii.IIRError, ValueError, tk.TclError) as exc:
            self.iir_result = None
            self._apply_arithmetic()
            self._fail(str(exc))
            return
        if self.auto_order.get():
            self.iir_order.set(self.iir_result.order)
        self._apply_arithmetic()
        self.redraw()
        self._report()

    def _fail(self, message):
        self.report.configure(state="normal")
        self.report.delete("1.0", "end")
        self.report.insert("1.0", "Cannot design this filter:\n\n" + message)
        self.report.configure(state="disabled")
        for ax in self.fig.axes:
            ax.clear()
        first = self.fig.axes[0]
        first.text(0.5, 0.5, "no filter", ha="center", va="center",
                   transform=first.transAxes, color="0.6")
        self.canvas.draw_idle()

    # ----------------------------------------------------------------- drawing

    def redraw(self):
        if self.is_design():
            return self.redraw_design()
        if self.is_iir():
            return self.redraw_iir()
        return self.redraw_fir()

    def redraw_design(self):
        """The current filter drawn as adders, delays and multipliers."""
        res = self.iir_result if self.is_iir() else self.result
        if res is None:
            return
        if self.is_iir():
            draw_iir_structure(self.ax_design, res)
        else:
            draw_fir_structure(self.ax_design, res)
        self.canvas.draw_idle()

    def redraw_fir(self):
        res = self.result
        if res is None:
            return
        eff = self.eff if self.eff is not None else res
        quantized = self.fixed is not None
        nyq = res.fs / 2.0
        f = np.linspace(0.0, nyq, 4096)
        amp = rz.amplitude_response(eff.h, 2 * np.pi * f / res.fs, res.symmetry)
        log = self.log_scale.get()

        # ---- amplitude ---------------------------------------------------
        ax = self.ax_mag
        ax.clear()
        if quantized:
            # The design it was rounded from, to show what the word length cost.
            ideal = rz.amplitude_response(res.h, 2 * np.pi * f / res.fs, res.symmetry)
            ax.plot(f, db(ideal) if log else ideal, lw=0.9, color="0.6", ls="-",
                    label="ideal (double)", zorder=2)
        y = db(amp) if log else amp
        ax.plot(f, y, lw=1.2, color="#1f77b4", zorder=3,
                label=f"{self.fixed.bits}-bit coefficients" if quantized
                else "designed response")

        if quantized and self.show_noise.get() and log:
            self._draw_noise(ax, res)
        if self.show_spec.get():
            self._draw_constraints(ax, res, log)
        if self.show_ext.get():
            ea = rz.amplitude_response(eff.h, 2 * np.pi * res.extremal_f / res.fs,
                                       res.symmetry)
            ax.plot(res.extremal_f, db(ea) if log else ea, "o", ms=3.5,
                    color="#d62728", label="extremal frequencies", zorder=4)

        ax.set_xlim(0, nyq)
        if log:
            top = max(5.0, np.nanmax(y[np.isfinite(y)]) + 5)
            ax.set_ylim(self._magnitude_floor(res, eff), top)
            ax.set_ylabel("amplitude (dB)")
        else:
            ax.set_ylabel("amplitude")
        ax.set_xlabel(f"frequency ({'normalised' if res.fs == 1.0 else 'Hz'})")
        ax.grid(alpha=0.3)
        ax.legend(loc="upper right", fontsize=8, framealpha=0.9)
        ax.set_title(f"Type {res.ftype} {res.symmetry} FIR, N = {res.numtaps}"
                     f"   —   {res.iterations} iterations"
                     f"{'' if res.converged else '  (did not converge)'}"
                     + (f"   —   {self.fixed.qformat} coefficients" if quantized else ""))

        # ---- passband detail ----------------------------------------------
        self._draw_detail(self.ax_detail, res, f, amp)

        # ---- weighted error ----------------------------------------------
        ax = self.ax_err
        ax.clear()
        for sl in self._segment_slices(res):
            ax.plot(res.grid_f[sl], eff.grid_e[sl], lw=1.0, color="#2ca02c")
        d = abs(res.delta)
        ax.axhline(d, color="#888", ls="--", lw=0.9)
        ax.axhline(-d, color="#888", ls="--", lw=0.9)
        if self.show_ext.get():
            ax.plot(res.extremal_f, eff.extremal_e, "o", ms=3.5, color="#d62728")
        ax.set_xlim(0, nyq)
        # Rounding the taps breaks the equiripple property, and the error then
        # runs outside the +-delta the exchange achieved; keep both in frame.
        reach = max(d, float(np.abs(eff.grid_e).max())) if d or eff.grid_e.size else 1.0
        ax.set_ylim(-1.6 * reach, 1.6 * reach)
        ax.set_ylabel("weighted error")
        ax.set_xlabel("frequency")
        ax.grid(alpha=0.3)
        ax.set_title(f"W(f)·[D(f) − A(f)]   —   δ = {d:.4g}"
                     + (f", peak {np.abs(eff.grid_e).max():.4g} once rounded"
                        if quantized else ""), fontsize=9)

        # ---- impulse response --------------------------------------------
        ax = self.ax_imp
        ax.clear()
        n = np.arange(res.numtaps)
        ax.stem(n, eff.h, basefmt=" ", markerfmt="o", linefmt="-")
        for line in ax.get_lines():
            line.set_markersize(3)
            line.set_linewidth(0.9)
        if quantized:
            ax.plot(n, res.h, ".", ms=2.5, color="#d62728", zorder=5,
                    label="before rounding")
            ax.legend(loc="upper right", fontsize=7, framealpha=0.9)
        ax.set_xlim(-0.5, res.numtaps - 0.5)
        ax.set_xlabel("tap")
        ax.set_ylabel("h[n]")
        ax.grid(alpha=0.3)
        ax.set_title("impulse response", fontsize=9)

        self.canvas.draw_idle()

    @staticmethod
    def _segment_slices(res):
        """Index slices of the grid, one per band, so bands are not joined up."""
        band = res.grid_band
        breaks = np.nonzero(np.diff(band))[0]
        starts = np.r_[0, breaks + 1]
        stops = np.r_[breaks + 1, band.size]
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

    def _noise_toggled(self):
        """The measurement shows up in the report as well as on the plot."""
        self.redraw()
        if (self.result if not self.is_iir() else self.iir_result) is not None:
            self._report()

    def _magnitude_floor(self, res, eff):
        """How far down the magnitude plot has to reach, in dB.

        Not from delta.  That is the *weighted* deviation, and once the weights
        come from dB specs it is essentially the passband's number: ask for
        0.5 dB of ripple and 80 dB of attenuation and delta lands near -19 dB,
        which would cut the stopband off the bottom of the plot along with the
        spec line it is being judged against.

        What has to be visible is the level each band is actually held to: the
        top of its tolerance band, the deviation it achieved, and the spec it
        was asked for.  For a stopband those are the attenuation; for a
        passband they sit near its gain and never win the minimum.
        """
        levels = []
        for index, band in enumerate(res.bands):
            _, des, tol = self._band_curves(res, band)
            target = float(np.max(np.abs(des)))
            levels.append(float(np.max(des + tol)))
            levels.append(target + float(eff.band_deviation[index]))
            if self.spec_dev is not None:
                levels.append(target + float(self.spec_dev[index]))

        deepest = db(min(levels)) if levels else -60.0
        if self.show_noise.get():
            measured = self._noise_floor()
            if measured is not None:
                deepest = min(deepest, float(np.median(measured[1])))
        # Room below the deepest line, so the response is not clipped to it.
        return max(min(deepest - 15.0, -20.0), -220.0)

    def _draw_noise(self, ax, res):
        """The measured arithmetic noise, and the response once it is included.

        The coefficient-quantized curve is what exact arithmetic would give.
        Real hardware rounds every product, and that noise is uncorrelated with
        the signal, so it adds in power: a stopband below the floor is simply not
        there to be measured.  Both are drawn, since the gap between them is the
        thing worth seeing.
        """
        measured = self._noise_floor()
        if measured is None:
            return
        norm, noise_db, _ = measured
        f = norm * res.fs
        if self.is_iir():
            mag_db = db(np.abs(self.eff.response_at(f)))
        else:
            mag_db = db(rz.amplitude_response(self.eff.h, 2 * np.pi * norm,
                                              self.eff.symmetry))
        ax.plot(f, noise_db, lw=0.9, color="#9467bd", ls=":", zorder=4,
                label=f"arithmetic noise ({dp.NOISE_LEVEL:g} FS input)")
        ax.plot(f, dp.effective_response(mag_db, noise_db), lw=1.0,
                color="#8c564b", alpha=0.85, zorder=4,
                label="as measured, noise included")

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

    # ------------------------------------------------------------- IIR drawing

    def redraw_iir(self):
        ideal = self.iir_result
        if ideal is None:
            return
        # Everything below is the filter as it will actually be built; the
        # design it came from is drawn behind it when the two differ.
        res = self.eff if self.eff is not None else ideal
        quantized = self.fixed is not None
        nyq = res.fs / 2.0
        f = np.linspace(0.0, nyq, 4096)
        h = res.response_at(f)
        mag = np.abs(h)
        log = self.log_scale.get()

        # ---- magnitude -----------------------------------------------------
        ax = self.ax_imag
        ax.clear()
        if quantized:
            im = np.abs(ideal.response_at(f))
            ax.plot(f, db(im) if log else im, lw=0.9, color="0.6", zorder=2,
                    label="ideal (double)")
        ax.plot(f, db(mag) if log else mag, lw=1.2, color="#1f77b4", zorder=3,
                label=f"{self.fixed.bits}-bit coefficients" if quantized
                else "designed response")
        if quantized and self.show_noise.get() and log:
            self._draw_noise(ax, res)
        if self.show_spec.get():
            self._draw_iir_mask(ax, res, log)
        ax.set_xlim(0, nyq)
        if log:
            ax.set_ylim(max(-1.6 * res.rs - 20.0, -220.0), 5.0)
            ax.set_ylabel("magnitude (dB)")
        else:
            ax.set_ylim(-0.05, 1.15)
            ax.set_ylabel("magnitude")
        ax.set_xlabel(f"frequency ({'normalised' if res.fs == 1.0 else 'Hz'})")
        ax.grid(alpha=0.3)
        ax.legend(loc="upper right", fontsize=8, framealpha=0.9)
        ax.set_title(
            f"{_APPROX_NAMES[res.approximation]} {res.response}, order {res.order}"
            f"   —   {len(res.sos)} biquad{'s' if len(res.sos) != 1 else ''}"
            + (f"   —   {self.fixed.qformat} coefficients" if quantized else "")
            + ("" if res.stable else "   *** UNSTABLE ***"))

        # ---- passband detail ------------------------------------------------
        ax = self.ax_idetail
        ax.clear()
        seen = []
        for a, b in res.passband_ranges:
            bf = np.linspace(a, b, 800)
            m = db(np.abs(res.response_at(bf)))
            ax.plot(bf, m, lw=1.2, color="#1f77b4", zorder=3)
            seen.append(m[np.isfinite(m)])
        ax.axhline(0.0, color="#ff7f0e", lw=1.2, ls="--", zorder=2)
        ax.axhline(-res.rp, color="#ff7f0e", lw=1.2, ls="--", zorder=2,
                   label=f"−{res.rp:g} dB")
        # Zoom onto the passband: for a lowpass this is a fraction of the axis,
        # and a fraction of a dB of ripple is invisible spread over the rest.
        lo = min(a for a, _ in res.passband_ranges)
        hi = max(b for _, b in res.passband_ranges)
        pad = 0.02 * (hi - lo)
        ax.set_xlim(max(0.0, lo - pad), min(nyq, hi + pad))
        # The corridor the specification draws is the natural frame, but
        # rounding the coefficients shifts the gain as well as widening the
        # ripple, and a curve that has left the corridor still has to be shown.
        ylo, yhi = -1.8 * res.rp, 0.8 * res.rp
        seen = np.concatenate(seen) if any(s.size for s in seen) else np.array([])
        if seen.size:
            room = 0.2 * max(float(seen.max() - seen.min()), res.rp)
            ylo = min(ylo, float(seen.min()) - room)
            yhi = max(yhi, float(seen.max()) + room)
        ax.set_ylim(ylo, yhi)
        ax.set_ylabel("passband (dB)")
        ax.grid(alpha=0.3)
        ax.legend(loc="lower left", fontsize=8, framealpha=0.9)
        ax.set_title(f"passband ripple   —   {res.achieved_rp:.4g} dB p-p achieved",
                     fontsize=9)

        # ---- group delay and phase -------------------------------------------
        ax, axp = self.ax_delay, self.ax_phase
        ax.clear()
        axp.clear()
        w = np.linspace(1e-4, np.pi - 1e-4, 2048)
        gf = w * res.fs / (2.0 * np.pi)
        ax.plot(gf, ii.group_delay(res.sos, w), lw=1.1, color="#9467bd")
        axp.plot(gf, np.unwrap(np.angle(ii.sos_freqz(res.sos, w))) * 180.0 / np.pi,
                 lw=0.9, color="#8c564b", alpha=0.65)
        for a, b in res.passband_ranges:
            ax.axvspan(a, b, color="#ff7f0e", alpha=0.10, zorder=0)
        ax.set_xlim(0, nyq)
        ax.set_ylabel("group delay (samples)", color="#9467bd")
        axp.set_ylabel("phase (deg)", color="#8c564b")
        ax.grid(alpha=0.3)
        ax.set_title("group delay, shaded over the passband, with the unwrapped "
                     "phase behind it", fontsize=9)

        # ---- pole-zero pattern -----------------------------------------------
        ax = self.ax_pz
        ax.clear()
        t = np.linspace(0, 2 * np.pi, 361)
        ax.plot(np.cos(t), np.sin(t), color="0.7", lw=0.9)
        ax.axhline(0, color="0.85", lw=0.7)
        ax.axvline(0, color="0.85", lw=0.7)
        if quantized:
            # Rounding the coefficients moves the roots; how close the poles
            # come to the unit circle afterwards is what decides stability.
            if len(ideal.z):
                ax.plot(ideal.z.real, ideal.z.imag, "o", ms=6, mfc="none",
                        mew=0.9, color="0.65", zorder=2)
            ax.plot(ideal.p.real, ideal.p.imag, "x", ms=6, mew=0.9,
                    color="0.65", zorder=2, label="before rounding")
        if len(res.z):
            ax.plot(res.z.real, res.z.imag, "o", ms=6, mfc="none", mew=1.2,
                    color="#1f77b4", label="zeros", zorder=3)
        ax.plot(res.p.real, res.p.imag, "x", ms=6, mew=1.4, color="#d62728",
                label="poles", zorder=3)
        # A Butterworth's zeros all sit on top of each other at Nyquist, which
        # otherwise reads as a single zero.
        for roots, colour in ((res.z, "#1f77b4"), (res.p, "#d62728")):
            for root, count in self._multiplicities(roots):
                if count > 1:
                    ax.annotate(f"×{count}", (root.real, root.imag),
                                textcoords="offset points", xytext=(5, 4),
                                fontsize=7, color=colour)
        lim = max(1.15, float(np.max(np.abs(np.r_[res.z, res.p]))) * 1.1
                  if len(res.z) or len(res.p) else 1.15)
        ax.set_xlim(-lim, lim)
        ax.set_ylim(-lim, lim)
        ax.set_aspect("equal", adjustable="box")
        ax.grid(alpha=0.3)
        ax.legend(loc="upper right", fontsize=7, framealpha=0.9)
        ax.set_title("poles and zeros   —   max |p| = "
                     f"{res.max_pole_radius:.4f}"
                     + (f" (was {ideal.max_pole_radius:.4f})" if quantized else ""),
                     fontsize=9)

        # ---- impulse and step response ----------------------------------------
        ax, axi = self.ax_step, self.ax_imp2
        ax.clear()
        axi.clear()
        n = self._settling_length(res)
        imp = ii.sos_impulse(res.sos, n)
        step = np.cumsum(imp)
        k = np.arange(n)
        # A sharp filter's impulse response is a hundred times smaller than the
        # step it integrates to, so the two get their own scales.
        axi.plot(k, imp, lw=0.8, color="#2ca02c", alpha=0.8, label="impulse")
        ax.plot(k, step, lw=1.1, color="#1f77b4", label="step")
        ax.axhline(0.0, color="0.85", lw=0.7)
        ax.set_xlim(0, n - 1)
        ax.set_xlabel("sample")
        ax.set_ylabel("step", color="#1f77b4")
        axi.set_ylabel("impulse", color="#2ca02c")
        ax.set_zorder(axi.get_zorder() + 1)
        ax.patch.set_visible(False)
        ax.grid(alpha=0.3)
        ax.set_title("impulse and step response", fontsize=9)

        self.canvas.draw_idle()

    @staticmethod
    def _multiplicities(roots, tol=1e-9):
        """Group coincident roots into (root, count) pairs."""
        out = []
        for r in roots:
            for i, (seen, count) in enumerate(out):
                if abs(r - seen) <= tol:
                    out[i] = (seen, count + 1)
                    break
            else:
                out.append((r, 1))
        return out

    @staticmethod
    def _settling_length(res, cap=1024):
        """Enough samples for the slowest pole to decay by about 60 dB."""
        r = min(res.max_pole_radius, 1.0 - 1e-9)
        n = 60.0 / max(-20.0 * np.log10(r), 1e-6) if r > 0 else 32
        return int(np.clip(n, 48, cap))

    def _draw_iir_mask(self, ax, res, log):
        """The specification as the corridors the response has to stay inside."""
        rp_lo = 10.0 ** (-res.rp / 20.0)
        rs_hi = 10.0 ** (-res.rs / 20.0)
        first = True
        for a, b in res.passband_ranges:
            lo, hi = (db(rp_lo), 0.0) if log else (rp_lo, 1.0)
            ax.fill_between([a, b], lo, hi, color="#ff7f0e", alpha=0.18, zorder=1,
                            label="passband corridor" if first else None)
            first = False
        first = True
        for a, b in res.stopband_ranges:
            lo, hi = (-400.0, db(rs_hi)) if log else (0.0, rs_hi)
            ax.fill_between([a, b], lo, hi, color="#7f7f7f", alpha=0.18, zorder=1,
                            label="stopband limit" if first else None)
            first = False
        for edge in res.wp + res.ws:
            ax.axvline(edge, color="0.75", lw=0.7, zorder=0)

    # ------------------------------------------------------------------ report

    def _report(self):
        if self.is_iir():
            return self._report_iir()
        return self._report_fir()

    def _write_report(self, lines):
        self.report.configure(state="normal")
        self.report.delete("1.0", "end")
        self.report.insert("1.0", "\n".join(lines))
        self.report.configure(state="disabled")

    def _report_iir(self):
        ideal = self.iir_result
        res = self.eff if self.eff is not None else ideal
        out = []
        out.append(f"{_APPROX_NAMES[ideal.approximation]} {ideal.response}")
        out.append(f"order            {res.order}"
                   f"{'  (smallest that meets the spec)' if res.auto_order else ''}")
        out.append(f"digital degree   {res.degree}   "
                   f"({len(res.sos)} second-order section"
                   f"{'s' if len(res.sos) != 1 else ''})")
        out.append(f"smallest order   {res.order_estimate}")
        out.append(f"max |pole|       {res.max_pole_radius:.6f}   "
                   f"{'stable' if res.stable else '*** UNSTABLE ***'}"
                   + (f"   (was {ideal.max_pole_radius:.6f})"
                      if self.fixed is not None else ""))
        out += self._arithmetic_lines()
        if self.fixed is not None:
            out.append(f"  passband ripple  {ideal.achieved_rp:.4g}"
                       f" -> {res.achieved_rp:.4g} dB")
            out.append(f"  stopband atten.  {ideal.achieved_rs:.4g}"
                       f" -> {res.achieved_rs:.4g} dB")
            shift = self._passband_gain_shift(ideal, res)
            if np.isfinite(shift) and abs(shift) > 0.01:
                out.append(f"  passband gain    {shift:+.3g} dB"
                           "   (rescale a numerator to take it out)")
            if ideal.stable and not res.stable:
                out.append("  *** rounding pushed a pole outside the unit circle:")
                out.append("      widen the coefficients, or split into more")
                out.append("      sections so each pole pair is less sensitive ***")
        out.append("")

        out.append("spec check")
        rp_verdict = "met" if res.achieved_rp <= res.rp * 1.0001 + 1e-9 else "MISSED"
        rs_verdict = "met" if res.achieved_rs >= res.rs - 1e-4 else "MISSED"
        out.append(f"  passband ripple  achieved {res.achieved_rp:8.4g} dB  "
                   f"required {res.rp:8.4g} dB   {rp_verdict}")
        out.append(f"  stopband atten.  achieved {res.achieved_rs:8.4g} dB  "
                   f"required {res.rs:8.4g} dB   {rs_verdict}")
        if not res.meets_spec and not res.auto_order:
            out.append(f"  raise the order to {res.order_estimate} to meet both")
        elif not res.meets_spec:
            # Only reachable for a band response whose edges are not
            # geometrically symmetric about the band centre.
            out.append("  the band edges are not geometrically symmetric, so one")
            out.append("  transition is wider than asked for; nudge an edge or")
            out.append("  raise the order by one.")
        out.append("")

        edges = ", ".join(f"{v:g}" for v in res.wn)
        out.append(f"placed on        {edges}"
                   f"  ({'stopband' if res.approximation == 'chebyshev2' else 'passband'}"
                   f" edge)")
        out.append(f"sample rate      {res.fs:g}")
        out.append("")

        if self.fixed is not None:
            q = self.fixed
            out.append(f"second-order sections   b0 b1 b2 / a0 a1 a2"
                       f"   as integer × 2^-{q.frac_bits}")
            for i, (s, n) in enumerate(zip(res.sos, q.ints)):
                out.append(f"  [{i}] b {s[0]: .9f} {s[1]: .9f} {s[2]: .9f}")
                out.append(f"        {n[0]:>12d} {n[1]:>12d} {n[2]:>12d}")
                out.append(f"      a {s[3]: .9f} {s[4]: .9f} {s[5]: .9f}")
                out.append(f"        {'—':>12} {n[4]:>12d} {n[5]:>12d}")
        else:
            out.append("second-order sections   b0 b1 b2 / a0 a1 a2")
            for i, s in enumerate(res.sos):
                out.append(f"  [{i}] b {s[0]: .12f} {s[1]: .12f} {s[2]: .12f}")
                out.append(f"      a {s[3]: .12f} {s[4]: .12f} {s[5]: .12f}")
        out.append("")

        out.append("poles (radius, frequency)")
        for p in sorted(res.p, key=lambda q: (abs(np.angle(q)), -abs(q))):
            f = abs(np.angle(p)) * res.fs / (2.0 * np.pi)
            out.append(f"  {p.real: .9f} {p.imag:+.9f}j   "
                       f"|p| = {abs(p):.6f}   f = {f:.6g}")
        if len(res.z):
            out.append("")
            out.append("zeros")
            for z in sorted(res.z, key=lambda q: (abs(np.angle(q)), -abs(q))):
                f = abs(np.angle(z)) * res.fs / (2.0 * np.pi)
                out.append(f"  {z.real: .9f} {z.imag:+.9f}j   "
                           f"|z| = {abs(z):.6f}   f = {f:.6g}")

        self._write_report(out)

    def _report_fir(self):
        res = self.result
        eff = self.eff if self.eff is not None else res
        out = []
        out.append(f"type {res.ftype}  ({res.symmetry}, "
                   f"{'odd' if res.numtaps % 2 else 'even'} length {res.numtaps})")
        out.append(f"iterations       {res.iterations}"
                   f"{'' if res.converged else '   *** did not converge ***'}")
        out.append(f"weighted delta   {abs(res.delta):.6g}")
        out += self._arithmetic_lines()
        out.append("")
        if self.fixed is not None:
            out.append("as built, after rounding the taps:")
        out.append("band          range            deviation      dB")
        for i, (b, dev) in enumerate(zip(res.bands, eff.band_deviation)):
            target = max(abs(b.d1), abs(b.d2))
            if target < 1e-12:
                label = f"{db(dev):8.2f} atten"
            else:
                label = f"{db(1 + dev / target) - db(1 - dev / target):8.2f} p-p"
            out.append(f"  {i + 1:<3d} {b.f1:8.4g}–{b.f2:<8.4g} "
                       f"{dev:12.4g}  {label}")

        if self.fixed is not None:
            out.append("")
            out.append("cost of rounding, per band")
            for i, (ideal_dev, dev) in enumerate(zip(res.band_deviation,
                                                     eff.band_deviation)):
                grew = dev / ideal_dev if ideal_dev > 0 else float("inf")
                out.append(f"  band {i + 1}: {ideal_dev:.4g} -> {dev:.4g}"
                           f"   ({db(grew):+.2f} dB)")

        if self.spec_dev is not None:
            out.append("")
            out.append("spec check")
            for i, (dev, want) in enumerate(zip(eff.band_deviation, self.spec_dev)):
                verdict = "met" if dev <= want * 1.0001 else "MISSED"
                out.append(f"  band {i + 1}: achieved {dev:.4g}  "
                           f"required {want:.4g}   {verdict}")
            missed = [dv > wt * 1.0001
                      for dv, wt in zip(eff.band_deviation, self.spec_dev)]
            if any(missed):
                if self.fixed is not None and not any(
                        dv > wt * 1.0001 for dv, wt in zip(res.band_deviation,
                                                           self.spec_dev)):
                    out.append("  the design met the spec; the word length lost it,")
                    out.append("  so widen the coefficients rather than adding taps")
                else:
                    need = self._suggest_taps(res)
                    if need:
                        out.append(f"  try about {need} taps to meet every spec")

        if res.peak_amplitude > 10 * max(1.0, max(abs(b.d1) for b in res.bands)):
            out.append("")
            out.append(f"warning: |A| reaches {res.peak_amplitude:.3g} in the")
            out.append("unconstrained transition region.  Add a band there or")
            out.append("use fewer taps.")

        out.append("")
        if self.fixed is not None:
            q = self.fixed
            out.append(f"coefficients      integer × 2^-{q.frac_bits}")
            width = len(str(max(abs(int(v)) for v in q.ints))) + 1
            for i, (v, n) in enumerate(zip(eff.h, q.ints)):
                out.append(f"  h[{i:<4d}] = {v: .12f}   {n:>{width}d}")
        else:
            out.append("coefficients")
            for i, v in enumerate(res.h):
                out.append(f"  h[{i:<4d}] = {v: .12f}")

        self._write_report(out)

    @staticmethod
    def _passband_gain_shift(ideal, eff):
        """How far rounding moved the passband gain, in dB.

        Ripple is measured peak-to-peak and so says nothing about this: a
        cascade whose numerators all rounded slightly high keeps its shape and
        simply sits at the wrong level.
        """
        f = ii._region_grid(ideal.passband_ranges, ideal.fs, 512)
        if f.size == 0:
            return float("nan")
        a = np.abs(ideal.response_at(f)).max()
        b = np.abs(eff.response_at(f)).max()
        if not (a > 0 and np.isfinite(b) and b > 0):
            return float("nan")
        return 20.0 * np.log10(b / a)

    def _arithmetic_lines(self):
        """The word length block shared by both reports."""
        if self.fixed is None:
            return []
        q = self.fixed
        lo, hi = q.limits
        out = ["",
               f"arithmetic       {q.bits}-bit fixed point, {q.qformat}",
               f"  resolution     {q.step:.6g}"
               f"   range [{lo * q.step:g}, {hi * q.step:g}]",
               f"  worst rounding {q.max_error:.4g}"]
        if q.saturated:
            out.append(f"  *** {q.saturated} coefficient"
                       f"{'s' if q.saturated != 1 else ''} saturated: the binary "
                       "point is too far left ***")
        smallest = self._smallest_word_length()
        if smallest:
            verdict = ("which is what this is"
                       if smallest == q.bits else
                       ("so this is wider than it needs to be"
                        if smallest < q.bits else "so this is too narrow"))
            out.append(f"  narrowest that meets the spec: {smallest} bits, "
                       f"{verdict}")
        else:
            out.append("  no word length up to 32 bits meets the spec")

        measured = self._noise_floor() if self.show_noise.get() else None
        if measured is not None:
            _, noise_db, rms = measured
            out.append(f"  arithmetic noise {float(np.median(noise_db)):.1f} dB "
                       f"below a {dp.NOISE_LEVEL:g} full-scale input")
            out.append(f"  ({rms:.2f} LSB rms at the output, from rounding each")
            out.append("   product; tick the display option to plot it)")
        elif self.show_noise.get():
            out.append("  the datapath could not be measured (see the design")
            out.append("  warning above)")
        else:
            out.append("  the plots show coefficient quantization only; tick the")
            out.append("  display option to measure the datapath as well")
        return out

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
        # Always the coefficients as built: in fixed point that means the
        # rounded values, alongside the integers they are stored as.
        res = self.eff if self.eff is not None else (
            self.iir_result if self.is_iir() else self.result)
        if res is None:
            return
        path = filedialog.asksaveasfilename(
            title="Save coefficients",
            defaultextension=".csv",
            filetypes=[("CSV", "*.csv"), ("C header", "*.h"), ("Text", "*.txt")])
        if not path:
            return
        lines = (self._iir_export(res, path, self.fixed) if self.is_iir()
                 else self._fir_export(res, path, self.fixed))
        try:
            with open(path, "w") as fh:
                fh.write("\n".join(lines) + "\n")
        except OSError as exc:
            messagebox.showerror("Save failed", str(exc))

    @staticmethod
    def _format_note(fixed):
        """One line describing the word length, for an export header."""
        if fixed is None:
            return "double precision coefficients"
        return (f"{fixed.bits}-bit fixed point, {fixed.qformat}: "
                f"value = integer * 2^-{fixed.frac_bits}")

    @staticmethod
    def _iir_export(res, path, fixed=None):
        """Biquad sections, as CSV or as a C table ready to cascade."""
        head = (f"{_APPROX_NAMES[res.approximation]} {res.response}, "
                f"order {res.order}, fs = {res.fs:g}, "
                f"{res.rp:g} dB / {res.rs:g} dB")
        note = RemezApp._format_note(fixed)
        if path.endswith(".h"):
            lines = [f"/* {head} */",
                     f"/* {note} */",
                     f"/* cascade of {len(res.sos)} biquads, "
                     "each y = b0 x + b1 x' + b2 x'' - a1 y' - a2 y'' */",
                     f"#define IIR_SECTIONS {len(res.sos)}"]
            if fixed is not None:
                lines += [f"#define IIR_FRAC_BITS {fixed.frac_bits}",
                          "static const long iir_sos_q[IIR_SECTIONS][6] = {"]
                lines += ["    {" + ", ".join(f"{int(v):d}" for v in s) + "},"
                          for s in fixed.ints]
                lines += ["};", ""]
            lines += ["static const double iir_sos[IIR_SECTIONS][6] = {"]
            lines += ["    {" + ", ".join(f"{v: .17g}" for v in s) + "},"
                      for s in res.sos]
            lines += ["};", ""]
            return lines
        lines = [f"# {head}",
                 f"# {note}",
                 f"# max |pole| = {res.max_pole_radius:.10g}, "
                 f"achieved {res.achieved_rp:.4g} dB / {res.achieved_rs:.4g} dB",
                 "section,b0,b1,b2,a0,a1,a2"
                 + (",b0_q,b1_q,b2_q,a0_q,a1_q,a2_q" if fixed is not None else "")]
        for i, s in enumerate(res.sos):
            row = str(i) + "," + ",".join(f"{v:.17g}" for v in s)
            if fixed is not None:
                row += "," + ",".join(f"{int(v):d}" for v in fixed.ints[i])
            lines.append(row)
        return lines

    @staticmethod
    def _fir_export(res, path, fixed=None):
        """The impulse response, as CSV or as a C array."""
        note = RemezApp._format_note(fixed)
        if path.endswith(".h"):
            lines = [f"/* Parks-McClellan FIR, type {res.ftype}, "
                     f"N = {res.numtaps}, delta = {abs(res.delta):.6g} */",
                     f"/* {note} */",
                     f"#define FIR_TAPS {res.numtaps}"]
            if fixed is not None:
                lines += [f"#define FIR_FRAC_BITS {fixed.frac_bits}",
                          "static const long fir_coeffs_q[FIR_TAPS] = {"]
                lines += [f"    {int(v):d}," for v in fixed.ints]
                lines += ["};", ""]
            lines += ["static const double fir_coeffs[FIR_TAPS] = {"]
            lines += [f"    {v: .17g}," for v in res.h]
            lines += ["};", ""]
            return lines
        lines = [f"# Parks-McClellan FIR, type {res.ftype}, "
                 f"N = {res.numtaps}, fs = {res.fs:g}",
                 f"# {note}",
                 f"# weighted delta = {abs(res.delta):.10g}",
                 "n,h" + (",h_q" if fixed is not None else "")]
        for i, v in enumerate(res.h):
            row = f"{i},{v:.17g}"
            if fixed is not None:
                row += f",{int(fixed.ints[i]):d}"
            lines.append(row)
        return lines

    def save_vhdl_source(self):
        """Write the filter out as synthesisable VHDL."""
        self._save_rtl(vh, "Generate VHDL", ".vhd",
                       [("VHDL", "*.vhd"), ("VHDL", "*.vhdl"),
                        ("All files", "*")])

    def _save_rtl(self, backend, title, suffix, filetypes):
        """Shared by both back-ends: ask for a file, write the design and its
        testbench beside it."""
        res = self.eff if self.eff is not None else (
            self.iir_result if self.is_iir() else self.result)
        if res is None:
            return
        if self.fixed is None:
            messagebox.showerror(
                "Nothing to generate",
                "Hardware needs fixed-point coefficients.\n\n"
                "Choose Fixed point in the Arithmetic panel, pick a word "
                "length, and try again.")
            return
        path = filedialog.asksaveasfilename(title=title, defaultextension=suffix,
                                            filetypes=filetypes)
        if not path:
            return

        stem = os.path.splitext(os.path.basename(path))[0]
        kind = "iir" if self.is_iir() else "fir"
        opts = self.rtl_options(stem)
        try:
            design = backend.source_for(kind, res, self.fixed, opts)
            bench = (backend.testbench_for(kind, res, self.fixed, opts)
                     if self.want_tb.get() else None)
        except (sv.SvError, ValueError, tk.TclError) as exc:
            messagebox.showerror("Cannot generate RTL", str(exc))
            return

        written = [path]
        try:
            with open(path, "w") as fh:
                fh.write(design)
            if bench is not None:
                root, ext = os.path.splitext(path)
                tb_path = f"{root}_tb{ext}"
                with open(tb_path, "w") as fh:
                    fh.write(bench)
                written.append(tb_path)
        except OSError as exc:
            messagebox.showerror("Save failed", str(exc))
            return
        self.last_rtl_written = written

    def save_sv_source(self):
        """Write the filter out as synthesisable SystemVerilog."""
        self._save_rtl(sv, "Generate SystemVerilog", ".sv",
                       [("SystemVerilog", "*.sv"), ("Verilog", "*.v"),
                        ("All files", "*")])

    # ------------------------------------------------------------------- design

    def save_design(self):
        """Write the whole specification out as JSON, so it can be reopened."""
        path = filedialog.asksaveasfilename(
            title="Save design", defaultextension=".json",
            filetypes=[("JSON", "*.json"), ("All files", "*")])
        if not path:
            return
        try:
            with open(path, "w") as fh:
                json.dump(self.to_dict(), fh, indent=2, sort_keys=True)
                fh.write("\n")
        except (OSError, TypeError) as exc:
            messagebox.showerror("Save failed", str(exc))

    def open_design(self):
        """Read a design back and put every control where it was."""
        path = filedialog.askopenfilename(
            title="Open design",
            filetypes=[("JSON", "*.json"), ("All files", "*")])
        if not path:
            return
        try:
            state = read_design(path)
        except (OSError, ValueError) as exc:
            messagebox.showerror("Cannot open that file", str(exc))
            return
        try:
            self.from_dict(state)
        except (KeyError, TypeError, ValueError, tk.TclError) as exc:
            messagebox.showerror("Cannot load that design",
                                 f"{exc}\n\nThe file may be from another tool.")

    def to_dict(self):
        """Everything needed to rebuild this design, as plain data."""
        return {
            "format": "remez-filter-design",
            "version": 1,
            "mode": self.mode.get(),
            "fs": float(self.fs.get()),
            "fir": {
                "numtaps": int(self.numtaps.get()),
                "symmetry": self.symmetry.get(),
                "grid_density": int(self.grid_density.get()),
                "maxiter": int(self.maxiter.get()),
                "use_spec": bool(self.use_spec.get()),
                "bands": [row.read() for row in self.rows],
            },
            "iir": {
                "response": self.response.get(),
                "approximation": self.approximation.get(),
                "order": int(self.iir_order.get()),
                "auto_order": bool(self.auto_order.get()),
                "wp": [v.get() for v in self.iir_wp],
                "ws": [v.get() for v in self.iir_ws],
                "rp": self.iir_rp.get(),
                "rs": self.iir_rs.get(),
            },
            "arithmetic": {
                "kind": self.arith.get(),
                "word_bits": int(self.word_bits.get()),
                "auto_frac": bool(self.auto_frac.get()),
                "frac_bits": int(self.frac_bits.get()),
                "headroom": int(self.headroom.get()),
                "fixed_coeffs": bool(self.fixed_coeffs.get()),
                "structure": self.structure.get(),
                "folded": bool(self.folded.get()),
                "testbench": bool(self.want_tb.get()),
            },
            "display": {
                "log_scale": bool(self.log_scale.get()),
                "show_spec": bool(self.show_spec.get()),
                "show_ext": bool(self.show_ext.get()),
                "show_noise": bool(self.show_noise.get()),
                "view": self.view.get(),
                "folded_panels": sorted(t for t, p in self.panels.items()
                                       if p.collapsed),
            },
        }

    def from_dict(self, state):
        """Restore what :meth:`to_dict` wrote.  Anything absent keeps its value."""
        if state.get("format") != "remez-filter-design":
            raise ValueError("not a filter design file")

        self.fs.set(float(state.get("fs", self.fs.get())))
        # The file's edges are already in the file's units, so this is the rate
        # they are in -- not a change to scale from.
        self._sync_sample_rate()

        fir = state.get("fir", {})
        if "numtaps" in fir:
            self.numtaps.set(int(fir["numtaps"]))
        for key, var in (("symmetry", self.symmetry),
                         ("grid_density", self.grid_density),
                         ("maxiter", self.maxiter),
                         ("use_spec", self.use_spec)):
            if key in fir:
                var.set(fir[key])
        if fir.get("bands"):
            self.clear_rows()
            for values in fir["bands"]:
                self.add_row(tuple(values))

        iir = state.get("iir", {})
        for key, var in (("response", self.response),
                         ("approximation", self.approximation),
                         ("order", self.iir_order),
                         ("auto_order", self.auto_order),
                         ("rp", self.iir_rp), ("rs", self.iir_rs)):
            if key in iir:
                var.set(iir[key])
        for key, holder in (("wp", self.iir_wp), ("ws", self.iir_ws)):
            for var, value in zip(holder, iir.get(key, [])):
                var.set(value)

        arith = state.get("arithmetic", {})
        for key, var in (("kind", self.arith), ("word_bits", self.word_bits),
                         ("auto_frac", self.auto_frac),
                         ("frac_bits", self.frac_bits),
                         ("headroom", self.headroom),
                         ("fixed_coeffs", self.fixed_coeffs),
                         ("structure", self.structure), ("folded", self.folded),
                         ("testbench", self.want_tb)):
            if key in arith:
                var.set(arith[key])

        display = state.get("display", {})
        if "folded_panels" in display:
            wanted = set(display["folded_panels"])
            for title, panel in self.panels.items():
                panel.collapse(title in wanted)
        for key, var in (("log_scale", self.log_scale),
                         ("show_spec", self.show_spec),
                         ("show_ext", self.show_ext),
                         ("show_noise", self.show_noise),
                         ("view", self.view)):
            if key in display:
                var.set(display[key])

        if "mode" in state and state["mode"] in MODES:
            self.mode.set(state["mode"])
        # One rebuild at the end, rather than one per field.
        for row in self.rows:
            row.set_spec_state(self.use_spec.get())
        self._edge_fields_for_response()
        self._auto_order_toggled(design=False)
        self.switch_mode()
        self._layout_axes()
        self.switch_view()

    def save_c_source(self):
        # The generated filter runs in double precision, but it must run the
        # coefficients that were actually chosen, rounded ones included.
        res = self.eff if self.eff is not None else (
            self.iir_result if self.is_iir() else self.result)
        if res is None:
            return
        path = filedialog.asksaveasfilename(
            title="Save C source",
            defaultextension=".c",
            filetypes=[("C source", "*.c"), ("All files", "*")])
        if not path:
            return
        # The file's own name is what the program calls itself in its usage
        # and error messages, until argv[0] says otherwise.
        stem = rc.sanitise_name(os.path.splitext(os.path.basename(path))[0])
        source = (self._iir_c_source(res, self.fixed, stem) if self.is_iir()
                  else self._fir_c_source(res, self.fixed, stem))
        try:
            with open(path, "w") as fh:
                fh.write(source)
        except OSError as exc:
            messagebox.showerror("Save failed", str(exc))

    @staticmethod
    def _c_preamble(title, detail, structure):
        return "\n".join([
            "/*",
            f" * {title}",
            *[f" * {line}" for line in detail],
            " *",
            f" * {structure}",
            " * Generated by remez.py.",
            " *",
            " * As a library:",
            " *",
            " *     t_ctx ctx;",
            " *     if (init_filter(&ctx) != 0) ... out of memory ...",
            " *     for (...) y = process_sample(x, &ctx);",
            " *     free_filter(&ctx);",
            " *",
            " * As a program, which is what it builds as by default:",
            " *",
            " *     cc -O2 -o filter this.c",
            " *     ./filter [-o outfile] [infile]",
            " *",
            " * It reads and writes raw 64 bit float samples in native byte",
            " * order, stdin to stdout unless told otherwise.  Compile with",
            " * -DFILTER_NO_MAIN to leave main out and link it into something",
            " * else instead.",
            " */",
            "",
            "#include <stdlib.h>",
            "",
            "",
        ])

    @staticmethod
    def _c_main(name="filter"):
        """The stand-alone program wrapped round the filter.

        Raw 64 bit floats in native byte order, in and out: a filter is
        usually one stage of a pipeline, and text costs a conversion each way
        and every bit below the seventeenth digit.  Reads stdin and writes
        stdout unless given filenames, so it composes.
        """
        return "\n".join([
            "",
            "#ifndef FILTER_NO_MAIN",
            "#include <errno.h>",
            "#include <stdio.h>",
            "#include <string.h>",
            "",
            "#ifdef _WIN32",
            "#include <fcntl.h>",
            "#include <io.h>",
            "#else",
            "#include <unistd.h>",
            "#endif",
            "",
            "/* Samples carried per read; the buffer is doubles so it stays aligned. */",
            "#define IO_SAMPLES 4096",
            "",
            f'static const char *progname = "{name}";',
            "",
            "static void usage(FILE *out)",
            "{",
            '    fprintf(out, "usage: %s [-o outfile] [infile]\\n", progname);',
            '    fprintf(out, "  Filters raw 64 bit float PCM samples (native byte order).\\n");',
            '    fprintf(out, "  infile defaults to stdin, output defaults to stdout.\\n");',
            "}",
            "",
            "/* Filters in to out a block at a time.  Returns 0, or -1 after reporting",
            "   an I/O error.  A trailing fragment shorter than one sample is reported",
            "   and dropped. */",
            "static int filter_stream(FILE *in, FILE *out, t_ctx *ctx)",
            "{",
            "    double buf[IO_SAMPLES];",
            "    unsigned char *bytes = (unsigned char *) buf;",
            "    size_t leftover = 0;",
            "    size_t got;",
            "",
            "    while ((got = fread(bytes + leftover, 1, sizeof buf - leftover, in)) > 0) {",
            "        size_t total = leftover + got;",
            "        size_t count = total / sizeof(double);",
            "        size_t i;",
            "",
            "        for (i = 0; i < count; i++)",
            "            buf[i] = process_sample(buf[i], ctx);",
            "",
            "        if (count && fwrite(buf, sizeof(double), count, out) != count) {",
            '            fprintf(stderr, "%s: write failed: %s\\n", progname, strerror(errno));',
            "            return -1;",
            "        }",
            "",
            "        /* Carry any bytes that did not complete a sample into the next read. */",
            "        leftover = total - count * sizeof(double);",
            "        if (leftover)",
            "            memmove(bytes, bytes + count * sizeof(double), leftover);",
            "    }",
            "",
            "    if (ferror(in)) {",
            '        fprintf(stderr, "%s: read failed: %s\\n", progname, strerror(errno));',
            "        return -1;",
            "    }",
            "    if (leftover)",
            '        fprintf(stderr, "%s: ignoring %lu trailing byte(s), not a whole sample\\n",',
            "                progname, (unsigned long) leftover);",
            "",
            "    return 0;",
            "}",
            "",
            "int main(int argc, char **argv)",
            "{",
            "    const char *in_path = NULL;",
            "    const char *out_path = NULL;",
            "    FILE *in = stdin;",
            "    FILE *out = stdout;",
            "    t_ctx ctx;",
            "    int status = 0;",
            "    int i;",
            "",
            "    if (argc > 0 && argv[0] && argv[0][0])",
            "        progname = argv[0];",
            "",
            "    for (i = 1; i < argc; i++) {",
            '        if (strcmp(argv[i], "-o") == 0) {',
            "            if (++i == argc) {",
            '                fprintf(stderr, "%s: -o needs a filename\\n", progname);',
            "                return 1;",
            "            }",
            "            out_path = argv[i];",
            '        } else if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {',
            "            usage(stdout);",
            "            return 0;",
            '        } else if (strcmp(argv[i], "-") == 0) {',
            "            in_path = NULL;             /* explicit stdin */",
            "        } else if (argv[i][0] == '-' && argv[i][1]) {",
            '            fprintf(stderr, "%s: unknown option: %s\\n", progname, argv[i]);',
            "            usage(stderr);",
            "            return 1;",
            "        } else if (in_path == NULL) {",
            "            in_path = argv[i];",
            "        } else {",
            '            fprintf(stderr, "%s: only one input file may be given\\n", progname);',
            "            return 1;",
            "        }",
            "    }",
            "",
            "    if (in_path) {",
            '        in = fopen(in_path, "rb");',
            "        if (!in) {",
            '            fprintf(stderr, "%s: %s: %s\\n", progname, in_path, strerror(errno));',
            "            return 1;",
            "        }",
            "    }",
            "",
            "    if (out_path) {",
            '        out = fopen(out_path, "wb");',
            "        if (!out) {",
            '            fprintf(stderr, "%s: %s: %s\\n", progname, out_path, strerror(errno));',
            "            if (in != stdin)",
            "                fclose(in);",
            "            return 1;",
            "        }",
            "    }",
            "",
            "#ifdef _WIN32",
            "    if (in == stdin)",
            "        _setmode(_fileno(stdin), _O_BINARY);",
            "    if (out == stdout)",
            "        _setmode(_fileno(stdout), _O_BINARY);",
            "#else",
            "    /* Raw samples down a terminal are noise, and usually a forgotten -o. */",
            "    if (out == stdout && isatty(fileno(stdout))) {",
            '        fprintf(stderr, "%s: refusing to write binary samples to a terminal; "',
            '                        "use -o or redirect\\n", progname);',
            "        if (in != stdin)",
            "            fclose(in);",
            "        return 1;",
            "    }",
            "#endif",
            "",
            "    if (init_filter(&ctx) != 0) {",
            '        fprintf(stderr, "%s: init_filter: out of memory\\n", progname);',
            "        status = 1;",
            "    } else {",
            "        if (filter_stream(in, out, &ctx) != 0)",
            "            status = 1;",
            "        free_filter(&ctx);",
            "    }",
            "",
            "    if (in != stdin)",
            "        fclose(in);",
            "    if (fflush(out) != 0 || (out != stdout && fclose(out) != 0)) {",
            '        fprintf(stderr, "%s: %s: %s\\n", progname,',
            '                out_path ? out_path : "stdout", strerror(errno));',
            "        status = 1;",
            "    }",
            "",
            "    return status;",
            "}",
            "#endif",
            "",
        ])

    @staticmethod
    def _iir_c_source(res, fixed=None, name="filter"):
        """A self-contained C implementation of the biquad cascade.

        The inner loop is the same transposed direct form II that
        ``iir_core.sos_filter`` runs and that the design view draws, so the
        three agree sample for sample.  ``a0`` is divided out here rather than
        stored, since it is 1 for every section a bilinear design produces.
        """
        rows = []
        for s in res.sos:
            c = [s[0] / s[3], s[1] / s[3], s[2] / s[3], s[4] / s[3], s[5] / s[3]]
            rows.append("    { " + ", ".join(f"{v: .17g}" for v in c) + " },")

        return RemezApp._c_preamble(
            f"{_APPROX_NAMES[res.approximation]} {res.response} IIR filter, "
            f"order {res.order}",
            [f"sample rate {res.fs:g}, "
             f"passband edge{'s' if len(res.wp) > 1 else ''} "
             f"{', '.join(f'{v:g}' for v in res.wp)}, "
             f"stopband edge{'s' if len(res.ws) > 1 else ''} "
             f"{', '.join(f'{v:g}' for v in res.ws)}",
             f"{res.rp:g} dB passband ripple, {res.rs:g} dB stopband attenuation "
             f"(achieved {res.achieved_rp:.4g} dB / {res.achieved_rs:.4g} dB)",
             f"max |pole| = {res.max_pole_radius:.10g}",
             RemezApp._format_note(fixed)],
            f"Cascade of {len(res.sos)} biquads, each transposed direct form II.",
        ) + "\n".join([
            f"#define FILTER_SECTIONS {len(res.sos)}",
            "",
            "/* one row per section: b0, b1, b2, a1, a2   (a0 is 1) */",
            "static const double filter_sos[FILTER_SECTIONS][5] = {",
            *rows,
            "};",
            "",
            "typedef struct {",
            "    double *state;      /* two delay elements per section */",
            "    size_t  sections;",
            "} t_ctx;",
            "",
            "/* Allocates the filter state, zeroed.  Returns 0, or -1 if out of",
            "   memory, in which case ctx is left safe to pass to free_filter. */",
            "int init_filter(t_ctx *ctx)",
            "{",
            "    ctx->sections = FILTER_SECTIONS;",
            "    ctx->state = (double *) calloc(2 * FILTER_SECTIONS,",
            "                                   sizeof *ctx->state);",
            "    return ctx->state ? 0 : -1;",
            "}",
            "",
            "void free_filter(t_ctx *ctx)",
            "{",
            "    free(ctx->state);",
            "    ctx->state = NULL;",
            "    ctx->sections = 0;",
            "}",
            "",
            "/*  y     = b0*x + s0",
            "    s0'   = b1*x - a1*y + s1",
            "    s1'   = b2*x - a2*y            , section by section  */",
            "double process_sample(double sample, t_ctx *ctx)",
            "{",
            "    size_t i;",
            "",
            "    for (i = 0; i < ctx->sections; i++) {",
            "        const double *c = filter_sos[i];",
            "        double *s = ctx->state + 2 * i;",
            "        double out = c[0] * sample + s[0];",
            "",
            "        s[0] = c[1] * sample - c[3] * out + s[1];",
            "        s[1] = c[2] * sample - c[4] * out;",
            "        sample = out;",
            "    }",
            "    return sample;",
            "}",
        ]) + "\n" + RemezApp._c_main(name)

    @staticmethod
    def _fir_c_source(res, fixed=None, name="filter"):
        """A self-contained C implementation of the tapped delay line.

        The delay line is a circular buffer, so nothing is copied per sample;
        the loop walks it backwards from the newest sample, which is the order
        the taps are stored in.
        """
        taps = [f"    {v: .17g}," for v in res.h]
        band = ", ".join(f"{b.f1:g}–{b.f2:g}" for b in res.bands)

        return RemezApp._c_preamble(
            f"Parks-McClellan FIR filter, type {res.ftype} ({res.symmetry}), "
            f"N = {res.numtaps}",
            [f"sample rate {res.fs:g}, bands {band}",
             f"weighted delta = {abs(res.delta):.10g}",
             RemezApp._format_note(fixed)],
            "Direct form: a tapped delay line into one accumulator.",
        ) + "\n".join([
            f"#define FILTER_TAPS {res.numtaps}",
            "",
            "static const double filter_taps[FILTER_TAPS] = {",
            *taps,
            "};",
            "",
            "typedef struct {",
            "    double *state;      /* circular delay line, FILTER_TAPS long */",
            "    size_t  taps;",
            "    size_t  pos;        /* where the next sample goes */",
            "} t_ctx;",
            "",
            "/* Allocates the delay line, zeroed.  Returns 0, or -1 if out of",
            "   memory, in which case ctx is left safe to pass to free_filter. */",
            "int init_filter(t_ctx *ctx)",
            "{",
            "    ctx->taps = FILTER_TAPS;",
            "    ctx->pos = 0;",
            "    ctx->state = (double *) calloc(FILTER_TAPS, sizeof *ctx->state);",
            "    return ctx->state ? 0 : -1;",
            "}",
            "",
            "void free_filter(t_ctx *ctx)",
            "{",
            "    free(ctx->state);",
            "    ctx->state = NULL;",
            "    ctx->taps = ctx->pos = 0;",
            "}",
            "",
            "/*  y[n] = sum_i h[i] * x[n-i]  */",
            "double process_sample(double sample, t_ctx *ctx)",
            "{",
            "    double acc = 0.0;",
            "    size_t i, k;",
            "",
            "    ctx->state[ctx->pos] = sample;",
            "    k = ctx->pos;",
            "    for (i = 0; i < ctx->taps; i++) {",
            "        acc += filter_taps[i] * ctx->state[k];",
            "        k = k ? k - 1 : ctx->taps - 1;",
            "    }",
            "    ctx->pos = ctx->pos + 1 == ctx->taps ? 0 : ctx->pos + 1;",
            "    return acc;",
            "}",
        ]) + "\n" + RemezApp._c_main(name)

    def save_plot(self):
        if (self.iir_result if self.is_iir() else self.result) is None:
            return
        path = filedialog.asksaveasfilename(
            title="Save plot", defaultextension=".png",
            filetypes=[("PNG", "*.png"), ("PDF", "*.pdf"), ("SVG", "*.svg")])
        if path:
            try:
                self.fig.savefig(path, dpi=150)
            except (OSError, ValueError) as exc:
                messagebox.showerror("Save failed", str(exc))


# --------------------------------------------------------------------------
# Structure diagrams
#
# The design view draws the filter as the thing you would actually build: the
# adders, the unit delays and the multipliers, each labelled with the constant
# that goes into it.  Everything is laid out in axes coordinates running 0..1
# in both directions, and every symbol is drawn as a marker, a text box or an
# annotation arrow -- all of which are sized in points -- so nothing is
# distorted when the pane is resized to some other aspect ratio.
# --------------------------------------------------------------------------

_WIRE = "#555"
_GAIN_COLOUR = "#1f77b4"
_DEAD_COLOUR = "#c8c8c8"


def _line(ax, x1, y1, x2, y2, colour=_WIRE, lw=1.0):
    ax.plot([x1, x2], [y1, y2], color=colour, lw=lw, solid_capstyle="round",
            zorder=2)


def _arrow(ax, x1, y1, x2, y2, colour=_WIRE, lw=1.0, shrink_a=0.0, shrink_b=0.0):
    ax.annotate("", xy=(x2, y2), xytext=(x1, y1), zorder=2,
                arrowprops=dict(arrowstyle="-|>", color=colour, lw=lw,
                                shrinkA=shrink_a, shrinkB=shrink_b,
                                mutation_scale=9))


def _node(ax, x, y, colour=_WIRE):
    ax.plot([x], [y], marker="o", ms=3.0, color=colour, zorder=3)


def _adder(ax, x, y, size, colour=_WIRE):
    ax.plot([x], [y], marker="o", ms=size, mfc="white", mec=colour, mew=1.0,
            zorder=4)
    ax.text(x, y, "+", ha="center", va="center", fontsize=size * 0.75,
            color=colour, zorder=5)


def _delay(ax, x, y, fontsize, colour=_WIRE):
    ax.text(x, y, "z⁻¹", ha="center", va="center", fontsize=fontsize,
            color=colour, zorder=5,
            bbox=dict(boxstyle="square,pad=0.28", fc="white", ec=colour, lw=0.9))


_FACING = {"right": -90, "left": 90, "down": 180}


def _gain(ax, x, y, label, fontsize, facing="right", dy=7, colour=_GAIN_COLOUR):
    """A multiplier triangle pointing the way the signal flows, and its value."""
    ax.plot([x], [y], marker=(3, 0, _FACING[facing]), ms=9,
            mfc="white", mec=colour, mew=1.0, zorder=4)
    if label:
        ax.annotate(label, (x, y), textcoords="offset points", xytext=(0, dy),
                    ha="center", va="bottom" if dy > 0 else "top",
                    fontsize=fontsize, color=colour, zorder=5)


def _draw_biquad(ax, coeffs, box, in_label, out_label, title, fontsize):
    """One second-order section, as transposed direct form II.

    This is the structure ``iir_core.sos_filter`` actually runs and the one the
    exported coefficients are meant for: two state variables, the numerator
    taps feeding forward off the input and the denominator taps feeding back
    off the output, so that

        y[n]  = b0 x[n] + s1[n-1]
        s1[n] = b1 x[n] - a1 y[n] + s2[n-1]
        s2[n] = b2 x[n] - a2 y[n]

    A first-order section reaches here padded with zeros; those branches are
    drawn in grey rather than dropped, so that the picture and the six exported
    numbers stay in step.
    """
    b0, b1, b2, _, a1, a2 = coeffs / coeffs[3]
    x0, y0, w, h = box

    def X(u):
        return x0 + u * w

    def Y(v):
        return y0 + v * h

    in_x, add_x, out_x = 0.235, 0.575, 0.825
    fwd_x, fbk_x = 0.395, 0.705
    rows = (0.76, 0.45, 0.14)
    delays = (0.605, 0.295)
    add_size = max(5.0, fontsize * 1.15)

    ax.text(X(0.5), Y(0.99), title, ha="center", va="top", fontsize=fontsize,
            color="#333")

    # ---- the input bus, and the feed-forward branches off it
    ax.annotate(in_label, (X(0.0), Y(rows[0])), textcoords="offset points",
                xytext=(0, 0), ha="left", va="center", fontsize=fontsize)
    _arrow(ax, X(0.13), Y(rows[0]), X(in_x), Y(rows[0]))
    _line(ax, X(in_x), Y(rows[2]), X(in_x), Y(rows[0]))
    for v in rows[1:]:
        _node(ax, X(in_x), Y(v))
    for v, gain, name in zip(rows, (b0, b1, b2), ("b0", "b1", "b2")):
        dead = gain == 0.0
        colour = _DEAD_COLOUR if dead else _WIRE
        _arrow(ax, X(in_x), Y(v), X(add_x), Y(v), colour=colour, shrink_b=add_size / 2)
        _gain(ax, X(fwd_x), Y(v), f"{name} = {gain:+.6g}", fontsize,
              colour=_DEAD_COLOUR if dead else _GAIN_COLOUR)

    # ---- the accumulator chain, running upward through the two delays
    for v in rows:
        _adder(ax, X(add_x), Y(v), add_size)
    for v_from, v_to, v_delay in zip(rows[1:], rows[:-1], delays):
        _arrow(ax, X(add_x), Y(v_from), X(add_x), Y(v_to),
               shrink_a=add_size / 2, shrink_b=add_size / 2)
        _delay(ax, X(add_x), Y(v_delay), fontsize)

    # ---- the output bus, and the feedback branches off it
    _arrow(ax, X(add_x), Y(rows[0]), X(0.99), Y(rows[0]), shrink_a=add_size / 2)
    ax.annotate(out_label, (X(0.99), Y(rows[0])), textcoords="offset points",
                xytext=(0, 7), ha="right", va="bottom", fontsize=fontsize)
    _node(ax, X(out_x), Y(rows[0]))
    _line(ax, X(out_x), Y(rows[2]), X(out_x), Y(rows[0]))
    for v, gain, name in zip(rows[1:], (a1, a2), ("a1", "a2")):
        dead = gain == 0.0
        colour = _DEAD_COLOUR if dead else _WIRE
        _node(ax, X(out_x), Y(v))
        _arrow(ax, X(out_x), Y(v), X(add_x), Y(v), colour=colour,
               shrink_b=add_size / 2)
        _gain(ax, X(fbk_x), Y(v), f"−{name} = {-gain:+.6g}", fontsize, facing="left",
              dy=-7, colour=_DEAD_COLOUR if dead else _GAIN_COLOUR)


def _draw_cascade_strip(ax, n, y, fontsize):
    """The section running order, along the top of the design view."""
    xs = np.linspace(0.14, 0.86, n) if n > 1 else np.array([0.5])
    ax.annotate("x[n]", (0.02, y), ha="left", va="center", fontsize=fontsize)
    ax.annotate("y[n]", (0.98, y), ha="right", va="center", fontsize=fontsize)
    step = (xs[1] - xs[0]) if n > 1 else 0.3
    gap = min(0.025, 0.35 * step)          # clearance around each box
    _arrow(ax, 0.062, y, xs[0] - gap, y)
    _arrow(ax, xs[-1] + gap, y, 0.955, y)
    for i, x in enumerate(xs):
        ax.text(x, y, str(i), ha="center", va="center", fontsize=fontsize,
                zorder=5,
                bbox=dict(boxstyle="round,pad=0.34", fc="#eaf2fa", ec="#1f77b4",
                          lw=0.9))
        if i:
            _arrow(ax, xs[i - 1] + gap, y, x - gap, y)


def draw_iir_structure(ax, res):
    """The whole IIR filter: a cascade of biquads, with the real coefficients."""
    ax.clear()
    ax.set_axis_off()
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)

    sos = res.sos
    n = len(sos)
    cols = 1 if n <= 2 else 2 if n <= 8 else 3
    rows = int(np.ceil(n / cols))
    fontsize = float(np.clip(9.5 - 1.0 * rows, 4.5, 8.5))

    ax.text(0.5, 0.995,
            f"{_APPROX_NAMES[res.approximation]} {res.response}, order {res.order}"
            f"  —  {n} biquad{'s' if n != 1 else ''} in cascade, "
            "each transposed direct form II",
            ha="center", va="top", fontsize=9)
    _draw_cascade_strip(ax, n, 0.925, max(fontsize, 6.5))

    top = 0.885
    cw, ch = 1.0 / cols, top / rows
    for i, s in enumerate(sos):
        r, c = divmod(i, cols)
        box = (c * cw + 0.012, top - (r + 1) * ch + 0.02 * ch,
               cw - 0.024, ch * 0.94)
        poles = np.roots(s[3:])
        radius = float(np.max(np.abs(poles)))
        freq = float(np.max(np.abs(np.angle(poles)))) * res.fs / (2.0 * np.pi)
        _draw_biquad(
            ax, s, box,
            in_label="x[n]" if i == 0 else f"w{i}[n]",
            out_label="y[n]" if i == n - 1 else f"w{i + 1}[n]",
            title=f"section {i}   |p| = {radius:.4f}   f = {freq:.4g}",
            fontsize=fontsize)


def draw_fir_structure(ax, res, max_taps=13):
    """The FIR filter as a tapped delay line.

    A long filter cannot be drawn tap by tap and stay readable, so past
    ``max_taps`` the middle is replaced by a break and the caption says exactly
    which taps are missing from the picture.
    """
    ax.clear()
    ax.set_axis_off()
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)

    n = res.numtaps
    if n <= max_taps:
        cols, omitted = list(range(n)), None
    else:
        half = max_taps // 2
        # ``None`` marks the column that stands in for the taps left out.
        cols = list(range(half)) + [None] + list(range(n - half, n))
        omitted = (half, n - half - 1)

    fontsize = float(np.clip(90.0 / len(cols), 6.0, 9.0))
    xs = np.linspace(0.085, 0.93, len(cols))
    y_top, y_gain, y_sum = 0.87, 0.68, 0.12
    add_size = max(6.0, fontsize * 1.3)

    ax.text(0.5, 0.985,
            f"Type {res.ftype} {res.symmetry} FIR, N = {res.numtaps}"
            "  —  direct form: a tapped delay line into one accumulator",
            ha="center", va="top", fontsize=9)
    ax.annotate("x[n]", (0.005, y_top), ha="left", va="center", fontsize=fontsize)
    ax.annotate("y[n]", (0.995, y_sum), ha="right", va="center", fontsize=fontsize)
    _arrow(ax, 0.042, y_top, xs[0], y_top)

    for i, (x, k) in enumerate(zip(xs, cols)):
        if i:
            _arrow(ax, xs[i - 1], y_top, x, y_top)
            _arrow(ax, xs[i - 1], y_sum, x, y_sum,
                   shrink_a=add_size / 2 if i > 1 else 0.0,
                   shrink_b=add_size / 2 if k is not None else 0.0)
            if cols[i - 1] is not None and k is not None:
                _delay(ax, (xs[i - 1] + x) / 2, y_top, fontsize)
        if k is None:                       # the break standing in for the rest
            for y in (y_top, y_sum):
                ax.text(x, y, "⋯", ha="center", va="center", zorder=5,
                        fontsize=fontsize + 4, color=_WIRE,
                        bbox=dict(boxstyle="square,pad=0.2", fc="white", ec="none"))
            continue
        _node(ax, x, y_top)
        _arrow(ax, x, y_top, x, y_sum, shrink_b=add_size / 2 if i else 0.0)
        _gain(ax, x, y_gain, "", fontsize, facing="down")
        ax.annotate(f"h{k}", (x, y_gain), textcoords="offset points",
                    xytext=(-7, 0), ha="right", va="center", fontsize=fontsize,
                    color=_GAIN_COLOUR)
        ax.annotate(f"{res.h[k]:+.6g}", (x, 0.5 * (y_gain + y_sum)),
                    textcoords="offset points", xytext=(4, 0), rotation=90,
                    ha="center", va="center", fontsize=fontsize - 0.5,
                    color=_GAIN_COLOUR)
        if i:
            _adder(ax, x, y_sum, add_size)
    _arrow(ax, xs[-1], y_sum, 0.958, y_sum, shrink_a=add_size / 2)

    notes = []
    if omitted is not None:
        notes.append(f"taps {omitted[0]} … {omitted[1]} are not drawn")
    sign = "h[n] = h[N−1−n]" if res.symmetry == "symmetric" else "h[n] = −h[N−1−n]"
    notes.append(f"{sign}, so the folded form needs only {(n + 1) // 2} multipliers")
    ax.text(0.5, 0.035, ";   ".join(notes), ha="center", va="center",
            fontsize=8, color="#555")


def read_design(path):
    """The JSON of a saved design, or an exception saying why not."""
    with open(path) as fh:
        return json.load(fh)


def build_parser():
    """The command line.

    Kept separate from :func:`main` so it can be tested, and so that adding an
    option is a single call here rather than a change to the startup path.  A
    future batch mode -- design a filter and write the coefficients or the RTL
    without ever opening a window -- would go in as a subparser alongside this,
    with the GUI remaining what happens when no subcommand is given.
    """
    parser = argparse.ArgumentParser(
        prog="remez.py",
        description="Interactive digital filter designer: Remez-exchange FIR "
                    "and classical IIR.",
        epilog="With no arguments it opens the designer on a default lowpass.",
    )
    parser.add_argument(
        "design", nargs="?", metavar="DESIGN.json",
        help="a design saved by File > Save design, opened at startup")
    parser.add_argument(
        "--geometry", metavar="WxH",
        help="initial window size, as Tk writes it: 1280x800, or 1280x800+40+40")
    parser.add_argument(
        "--version", action="version", version=f"%(prog)s {__version__}")
    return parser


def main(argv=None):
    """Start the designer.  Returns the process exit status."""
    args = build_parser().parse_args(argv)

    # Read the design before building anything, so a bad path fails at once
    # rather than after a window has appeared.
    state = None
    if args.design:
        try:
            state = read_design(args.design)
        except (OSError, ValueError) as exc:
            print(f"remez.py: cannot open {args.design}: {exc}", file=sys.stderr)
            return 2

    root = tk.Tk()
    try:
        ttk.Style().theme_use("aqua")
    except tk.TclError:
        pass
    app = RemezApp(root)

    if args.geometry:
        try:
            root.geometry(args.geometry)
        except tk.TclError:
            print(f"remez.py: {args.geometry!r} is not a size Tk understands",
                  file=sys.stderr)
            return 2
    if state is not None:
        try:
            app.from_dict(state)
        except (KeyError, TypeError, ValueError, tk.TclError) as exc:
            print(f"remez.py: {args.design} is not a design this can load: "
                  f"{exc}", file=sys.stderr)
            return 2

    root.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
