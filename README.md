# Remez exchange FIR filter designer

A from-scratch implementation of the Parks–McClellan / Remez exchange algorithm
for optimal (equiripple) linear-phase FIR filters, with a Tk GUI: constraints and
filter parameters on the left, the specification and the resulting filter curve
plotted on the right.

The plot panel, here on the multiband preset:

![the plot panel on a four-band design](docs/example-plot.png)

## Running it

```bash
python3 -m venv --system-site-packages .venv && .venv/bin/pip install -r requirements.txt
```

```bash
.venv/bin/python remez_gui.py
```

Requires numpy and matplotlib; the algorithm itself (`remez_core.py`) needs only
numpy. scipy is used by the tests to cross-check designs, not by the program.

## Using the GUI

**Filter** sets the length, the symmetry, and the sample rate. Band edges are
entered in whatever units the sample rate is in — leave it at 1.0 for normalised
frequency (0 … 0.5 cycles/sample), or set it to 48000 to type edges in Hz. The
preset menu fills the table with a lowpass, highpass, bandpass, bandstop,
multiband, Hilbert transformer, differentiator, or a sloped band.

**Bands and constraints** is one row per approximation band:

| column | meaning |
| --- | --- |
| F start, F stop | band edges; bands must not overlap, and the gaps between them are the transition regions, left unconstrained |
| Desired at start / at stop | target amplitude, ramping linearly across the band — set them equal for a flat band, or unequal for a differentiator or a sloped response |
| Weight | relative importance; the algorithm equalises `weight × error`, so a band with ten times the weight ends up with a tenth of the ripple |
| Spec (dB) | used instead of Weight when the checkbox below is ticked |
| 1/f | weight the band by 1/f, which equalises *relative* error — the usual choice for a differentiator |

Tick **Derive weights from the spec column** to work in decibels instead of bare
weights: give each passband its peak-to-peak ripple in dB and each stopband its
attenuation in dB, and the weights that ask for that ratio of ripples are
computed for you. The report then says whether each spec was actually met, and
if not, roughly how many taps it would take (Kaiser's estimate).

Press **Design**, Return or F5 after editing. Coefficients export as CSV or as a
C header; the plot exports as PNG, PDF or SVG.

The four panels show:

1. the amplitude response against the desired response and the achieved
   tolerance envelope, with the extremal frequencies marked;
2. the ripple of each non-zero-target band relative to its target, where a
   fraction of a dB is actually visible;
3. the weighted error `W(f)·[D(f) − A(f)]`, which is flat-topped at `±δ` between
   the alternating extrema — this is the algorithm's own view of the problem;
4. the impulse response.

## The algorithm

`remez_core.py` implements the exchange directly rather than wrapping
`scipy.signal.remez`. All four linear-phase types are supported by writing the
zero-phase amplitude as `A(w) = Q(w)·P(cos w)` and folding `Q` into the desired
response and the weight, which reduces every case to the same type-I problem:

| type | taps | symmetry | Q(w) | typical use |
| --- | --- | --- | --- | --- |
| I | odd | symmetric | 1 | any |
| II | even | symmetric | cos(w/2) | zero at Nyquist, so no highpass |
| III | odd | antisymmetric | sin(w) | Hilbert transformer |
| IV | even | antisymmetric | sin(w/2) | differentiator |

Each iteration solves for the deviation `δ` on the current reference set,
interpolates `P` through the resulting values in barycentric form, and moves the
reference to the alternating extrema of the new error curve.

A few details matter for robustness, and each is exercised by a test:

- **Extrema are found on the signed error**, not on `|error|`. A small dip of the
  opposite sign at a band edge is a genuine alternation even when `|error|` is
  larger right next to it, and missing those makes the search come up short.
- **Reference scaling.** An evenly spread starting reference is fine for short
  filters but collapses above roughly 100 coefficients: the first deviation
  underflows to round-off and the exchange has no signal to follow. Instead the
  problem is solved at half the size first and its reference scaled up,
  recursively. Across 500 randomised realistic designs this converges on all of
  them, where `scipy.signal.remez` raises "failure to converge" on 91.
- **The interpolation uses the first barycentric form**, in the log domain. The
  familiar second form — the ratio of two sums — has a denominator of
  `1/prod(x - x_j)`, which cancels to nothing outside the hull of the nodes and
  then returns a finite, completely wrong number, which is exactly what a wide
  unconstrained transition band asks for. The first form stays accurate to
  about `1e-14` at degree 100, verified against extended precision.
- **Taps come from the Chebyshev coefficients of `P`**, recovered with a DFT.
  Fitting the sampled amplitude instead is ill-conditioned exactly when a wide
  unconstrained transition band lets the polynomial run away.

## Tests

```bash
.venv/bin/python -m pytest -q
```

`test_remez.py` checks the algorithm — agreement with `scipy.signal.remez` on a
fine grid, the alternation and equiripple properties, tap symmetry, the four
types, weighting, and input validation. `test_gui.py` drives the real Tk widgets
from the entry fields through to the rendered figure.
