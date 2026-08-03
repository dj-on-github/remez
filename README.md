# remez — a digital filter designer

Parks–McClellan FIR design and classical IIR design, with the plots, the
fixed-point arithmetic and the exports.

Originally a port of the Python tool of the same name, which is now in the
`python_prototype` subdirectory; this is the version that ships. Everything here was
checked against that implementation -- see below -- so the two agree on the
filters they design and on the files they generate.

```bash
flutter run -d macos      # or windows, linux, chrome
flutter test
```

It builds and presents itself as **remez** -- the app bundle, the window title,
the usage text, the header of every file it generates, the Dart package, and
the bundle identifier `com.deadhat.remez` on every platform that has one.

From a terminal it takes a design file, and answers `--help` and `--version`
without opening a window:

```bash
remez mydesign.json
```

## How this is checked

`test/golden/reference.json` holds designs produced by the **Python**
implementation. Every module here is tested against it, so "ported" means
"reproduces the original's numbers", not "looks plausible". That is what caught
the one real difference so far: `zpkToSos` was pairing the poles furthest
*outside* the unit circle first where the original takes the ones furthest in,
which put the sections in the wrong order and gave the odd-order leftover pole
two zeros instead of one.

The reference designs come from the Python implementation, which now lives
alongside this one in `remez_python`. Regenerate them from there if the original
ever changes.

It also caught an off-by-one in the iteration count: a C-style `for` leaves the
counter one past the cap where Python's `range(1, maxiter + 1)` leaves it at the
cap. It only shows on a design that runs the cap out, so every converging design
agreed regardless -- which is why it took exposing the cap in the UI to find.

### Section order

`zpkToSos` orders the cascade by pole magnitude. A bandpass or bandstop produces
pole pairs mirrored about the imaginary axis whose magnitudes are *equal* in
exact arithmetic, so which goes first is settled by the last bit after the
frequency transformation and the bilinear map. Three of the twenty-four
reference designs come out in a different section order from the Python for that
reason. They are the same filter: the tests check the response, the gain, and
the sections themselves with the ordering set aside, and pin the list of three
so it cannot drift unnoticed.

A tolerance that would have made the choice deterministic was tried and dropped.
It agrees with the reference in *fewer* cases, because the reference is at the
mercy of numpy's rounding rather than of any rule. For the same reason
`Complex./` deliberately matches numpy's `nc_quot` -- reciprocal-and-multiply
rather than the more accurate two divisions -- which is worth four exact
matches. Neither is a property of the filter; both are noted where they are
done so nobody "fixes" them.

## What is ported

| module | state |
| --- | --- |
| `fir_core.dart` | **complete.** All four linear-phase types, multiband, weights, inverse-f weighting, reference scaling for long filters. Matches the Python to 1e-9 per tap on every reference design |
| `fixed_point.dart` | **complete** for taps; the SOS path waits on the elliptic model below |
| `datapath.dart` | **complete.** chain / tree / MAC, folding, saturating arithmetic, the measured noise floor |
| `iir_core.dart` | **partial** — see the table below |
| `controller.dart`, `plots.dart`, `main.dart` | the app: FIR and IIR design, magnitude, weighted error and impulse plots, the arithmetic panel, the report, all eight presets, the grid density and iteration cap, and the dB Spec column that derives the band weights |
| `design_view.dart` | **complete.** The filter as built: the biquad cascade in transposed direct form II, the FIR as a tapped delay line with the middle elided past thirteen taps |
| `c_export.dart` | **complete.** Library and program in one file, raw f64 stdin to stdout |
| `coeff_export.dart` | **complete.** The coefficients alone, as CSV or a C header |
| `rtl_common.dart` | **complete.** Plans the hardware once, for both back-ends to render |
| `sv_export.dart`, `vhdl_export.dart` | **complete.** SystemVerilog and VHDL-93 for chain, tree and MAC, folded or not, constant or runtime coefficients, each with a self-checking testbench |
| `cli.dart` | **complete.** A design file to open, `--version`, `--help` |
| `format.dart` | Python's `%g` and `%f`, which Dart has no equivalent for |
| `icon.dart` | **complete.** The app icon, drawn rather than stored, with the detail turned down as the canvas shrinks |

### IIR models

All sixteen combinations -- Butterworth, Chebyshev I, Chebyshev II and elliptic,
each as lowpass, highpass, bandpass and bandstop -- reproduce the Python across
the 24 reference designs.

Getting there took four fixes worth naming, none of which the plots would have
shown you:

- `lp2bp`/`lp2bs` split each root into a pair, and were interleaving the two
  halves per root where the original concatenates them as blocks. Same set of
  roots, different order -- and `zpkToSos` pairs by position, so it built a
  different, stable, wrong cascade.
- The three circular prototypes used `theta = pi(2i+1)/2n + pi/2`. That is the
  same semicircle but not the same *arithmetic*: the angles no longer come in
  exactly negated pairs, so the poles were not a conjugate-symmetric set and an
  odd order's real pole carried an imaginary part of 1e-16.
- Chebyshev II emitted its zeros in a different order from the original.
- The elliptic prototype was not a port at all: a different route through the
  degree equation, a Landen sequence fixed at five steps rather than run to
  tolerance, a different formula for the odd-order pole, and a `re > 0`
  reflection papering over a sign error. It is now a faithful port, and fixing
  it also fixed both failing fixed-point SOS cases.

## The icon

Ported from `make_icon.py` rather than copied out of it: the same palette, the
same proportions, the same thresholds, redrawn with `Canvas` so it regenerates
at any size. It is the magnitude response of an equiripple lowpass -- shelf,
cliff, floor -- and it is drawn differently at each size, because at 16 pixels
the ripple and the lobes are mud and only the silhouette survives.

    flutter test test/make_icons_test.dart --update-goldens

writes every asset the platforms ask for: the macOS asset catalogue, the
Windows `.ico` (packed by hand -- PNG-encoded entries, which Vista onwards
reads), the web favicon and manifest icons, the Android launcher densities and
the iOS icon set. Without the flag it only checks the drawing, and one of those
checks compares it against the Python's own PNGs at 16, 32 and 256: not pixel
for pixel, since PIL and Skia antialias differently, but by mean channel
distance, which edge softening barely moves and a changed colour or a shifted
curve moves a great deal. It currently sits at 0.43 out of 255.

The web maskable variants are the one thing that is not a copy. A maskable icon
is cropped to whatever shape the launcher wants, so those are drawn full bleed
with square corners and the picture inside the safe circle; rounding them off
first would have them cut twice.

## Appearance

Auto, Light or Dark, in the Display panel; Auto follows the desktop. The plots
were already drawn in theme colours, but the design view was not -- its symbols
are *filled* so the wire behind them does not show through, and that fill has to
be the dark background rather than white. `DesignPalette` holds the six colours
that decision needs, and lifts the wire and gain colours too, since #555 on
near-black is invisible.

The choice is saved in the design file under a key the Python does not write.
Its loader ignores what it does not recognise, and this one preserves what it
does, so the two still interchange.

## The exports

The buttons are in a **File** panel in the control column, above Display,
where the Python tool puts the same six.

A note for anyone porting this elsewhere: Flutter's macOS template turns the App
Sandbox on and grants nothing else, and a sandboxed app may not show an open or
save panel without `com.apple.security.files.user-selected.read-write`. AppKit
does not raise an error when it is missing -- it simply never presents the
panel, so the plugin's future never completes and the button appears to do
nothing at all. `test/entitlements_test.dart` asserts both configurations carry
it.

**Coefficients** (`Save coefficients…`). CSV or a C header, chosen by the
extension you give the file, with the stored integers alongside the rounded
values when the arithmetic is fixed point. All eight combinations -- FIR and
IIR, floating and fixed, both formats -- are compared against the Python's.

**The plot** (`Save plot…`). Whichever view is showing, captured from the pane
rather than redrawn, so the file is what is on screen: the plots or the design
diagram, in whichever theme. Oversampled 2x, because a screenshot at screen
resolution looks soft in a document -- the same reason the Python asks
matplotlib for 150 dpi against a default of 100.

The capture is bounded by the *content*, not by the window. The plots have a
natural height of their own, so a tall window leaves blank below them and a
short one would cut the last one off; putting the repaint boundary inside the
scroll view rather than around it means the file is the plots either way.

**C** (`Save C…`). One self-contained file that is both a library
(`init_filter` / `process_sample` / `free_filter`) and a program filtering raw
64-bit floats from stdin to stdout. The test compiles it with `cc` and runs
several hundred samples through it, comparing against the Dart model: they agree
bit for bit, which is the only way to know the coefficients came out in the
order the loop reads them.

**SystemVerilog** (`Generate SV…`) and **VHDL-93** (`Generate VHDL…`), each with
its testbench beside it. Both buttons are disabled until the arithmetic is fixed
point, since there is no hardware to describe otherwise; the tooltip says so.
Chain, balanced adder tree or one reused multiplier; folded or not; coefficients
compiled in as parameters or driven on a port. Fifteen combinations in each
language are checked the same way: the SystemVerilog is lint-clean under
`verilator -Wall`, builds and runs; the VHDL analyses, elaborates and runs under
`ghdl --std=93`. The testbench carries the expected output of every sample from
`datapath.dart`, so a pass means the RTL and the plots agree exactly -- and that
the two languages describe one filter, since they are checked against the same
vectors. The generated text is also compared against the Python's own output
character for character, testbench vectors included, which means the two
datapath models produce identical integers. The one line that differs is the
provenance: this writes `Generated by remez.` where the Python writes
`Generated by remez.py.`, and the comparison normalises that.

The two back-ends share `rtl_common.dart`, which decides *what* the hardware is
-- the coefficient table, the term list of a folded filter, the resource counts,
the latency, the stimulus -- so each renderer only has to spell it. VHDL-93
carries coefficients as `integer` generics, so that path refuses a word longer
than 31 bits and says to use the SystemVerilog instead; nothing else differs.

**Designs** save as `.remz` and load as either that or `.json`. The contents are
unchanged -- the Python tool's own format -- so a design made in either program
opens in the other; only the name and the desktop association are new. macOS
declares the type as `com.deadhat.remez.design` conforming to `public.json`, so
the Finder identifies it, hands a double-clicked one to this app, and anything
that reads JSON still can. Checked in both directions against a file the
Python wrote and by loading a Dart-written file back into the Python GUI.
Settings this port has no control for -- which panels were folded, which optional
traces were showing -- are carried through a round trip rather than dropped.

## Performance

The design itself, against the numpy implementation on the same machine:

| taps | Python | Dart |
| --- | --- | --- |
| 41 | 1.80 ms | 0.81 ms |
| 101 | 8.35 ms | 4.83 ms |
| 201 | 30.4 ms | 19.2 ms |
| 401 | 69.7 ms | 45.7 ms |

`dart run tool/bench.dart` reruns it. The hot loop is the barycentric
evaluation in `_lagrange`, which still does a `log` and an `exp` per node --
there is more to get here.
