"""Parks-McClellan / Remez exchange algorithm for linear-phase FIR filter design.

This is a from-scratch implementation of the Remez exchange (second algorithm of
Remez) specialised to the Chebyshev approximation problem that arises in
linear-phase FIR design, as described in Parks & McClellan (1972) and
Oppenheim & Schafer, *Discrete-Time Signal Processing*, section 7.7.

The four linear-phase FIR types are supported:

    type  taps   symmetry        Q(w)        basis size r
    ----  -----  --------------  ----------  ---------------
      I   odd    symmetric       1           (N + 1) // 2
     II   even   symmetric       cos(w/2)    N // 2
    III   odd    antisymmetric   sin(w)      (N - 1) // 2
     IV   even   antisymmetric   sin(w/2)    N // 2

In every case the zero-phase amplitude response is written as

    A(w) = Q(w) * P(cos w)

with P a polynomial of degree r-1.  Dividing the desired response by Q and
multiplying the weight by Q turns all four cases into the same type-I problem,
which is what the exchange loop below actually solves.

Nothing here depends on scipy; only numpy is required.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np

__all__ = [
    "Band",
    "RemezResult",
    "RemezError",
    "design",
    "amplitude_response",
    "kaiser_order_estimate",
]


class RemezError(RuntimeError):
    """Raised when a design request is inconsistent or the exchange fails."""


@dataclass
class Band:
    """One approximation band.

    Frequencies are in the same units as ``fs``.  The desired amplitude and the
    error weight may each ramp linearly across the band, which covers the
    constant-gain case (``d1 == d2``) as well as differentiators and arbitrary
    piecewise-linear specifications.
    """

    f1: float
    f2: float
    d1: float
    d2: float = None  # type: ignore[assignment]
    w1: float = 1.0
    w2: float = None  # type: ignore[assignment]
    name: str = ""
    weight_kind: str = "const"     # "const" ramps w1->w2; "inv_f" gives w1/f

    def __post_init__(self) -> None:
        if self.d2 is None:
            self.d2 = self.d1
        if self.w2 is None:
            self.w2 = self.w1
        if self.weight_kind not in ("const", "inv_f"):
            raise RemezError(f"unknown weight_kind {self.weight_kind!r}")


@dataclass
class RemezResult:
    """Everything the exchange produced, for both use and display."""

    h: np.ndarray                  # impulse response, length numtaps
    numtaps: int
    ftype: int                     # 1..4
    symmetry: str                  # "symmetric" | "antisymmetric"
    delta: float                   # signed minimax weighted deviation
    grid_f: np.ndarray             # dense grid, physical frequency units
    grid_d: np.ndarray             # desired amplitude on the grid
    grid_w: np.ndarray             # weight on the grid
    grid_a: np.ndarray             # achieved amplitude on the grid
    grid_e: np.ndarray             # weighted error W*(D - A) on the grid
    extremal_f: np.ndarray         # extremal frequencies, physical units
    extremal_e: np.ndarray         # weighted error at the extrema
    iterations: int
    converged: bool
    band_deviation: list           # per-band peak |D - A|
    peak_amplitude: float          # peak |A| over 0..fs/2, transition bands included
    fs: float
    bands: list = field(default_factory=list)

    @property
    def ripple(self) -> float:
        """Peak weighted deviation |delta|."""
        return abs(self.delta)


# --------------------------------------------------------------------------
# Type bookkeeping
# --------------------------------------------------------------------------

def _classify(numtaps: int, symmetry: str):
    """Return (ftype, r) for the given length and symmetry."""
    odd = numtaps % 2 == 1
    if symmetry == "symmetric":
        if odd:
            return 1, (numtaps + 1) // 2
        return 2, numtaps // 2
    elif symmetry == "antisymmetric":
        if odd:
            return 3, (numtaps - 1) // 2
        return 4, numtaps // 2
    raise RemezError(f"unknown symmetry {symmetry!r}")


def _q_factor(ftype: int, w: np.ndarray) -> np.ndarray:
    """The fixed multiplier Q(w) for each linear-phase type."""
    if ftype == 1:
        return np.ones_like(w)
    if ftype == 2:
        return np.cos(w / 2.0)
    if ftype == 3:
        return np.sin(w)
    return np.sin(w / 2.0)


# --------------------------------------------------------------------------
# Dense frequency grid
# --------------------------------------------------------------------------

def _build_grid(bands, r, grid_density, ftype):
    """Dense grid of normalised frequencies (cycles/sample, 0..0.5).

    Each band gets a number of points proportional to its width, with the band
    edges included exactly.  The step is derived from the *total* bandwidth
    rather than from the full Nyquist range, so that a design whose bands cover
    only a sliver of the axis still gets ``grid_density * r`` points to search
    instead of a handful.  For types where Q(w) vanishes at 0 and/or 0.5 the
    grid is nudged inward so that D/Q stays finite.
    """
    guard = 0.5 / (grid_density * r)
    # Q(0) == 0 for types 3 and 4; Q(0.5) == 0 for types 2 and 3.
    lo_guard = guard if ftype in (3, 4) else 0.0
    hi_guard = 0.5 - guard if ftype in (2, 3) else 0.5

    spans = []
    for idx, b in enumerate(bands):
        f1 = max(b.f1, lo_guard)
        f2 = min(b.f2, hi_guard)
        if f2 <= f1:
            raise RemezError(
                f"band {idx + 1} is empty after guarding against Q(w)=0; "
                "move the edges away from 0 or Nyquist"
            )
        spans.append((f1, f2))

    total = sum(f2 - f1 for f1, f2 in spans)
    delf = total / (grid_density * r)

    grid, seg = [], []
    for idx, (f1, f2) in enumerate(spans):
        npts = max(int(np.ceil((f2 - f1) / delf)) + 1, 3)
        grid.append(np.linspace(f1, f2, npts))
        seg.append(np.full(npts, idx))
    return np.concatenate(grid), np.concatenate(seg)


def _interp_band(bands, seg, f):
    """Desired amplitude and weight on the grid, ramping across each band."""
    d = np.empty_like(f)
    w = np.empty_like(f)
    for idx, b in enumerate(bands):
        m = seg == idx
        span = b.f2 - b.f1
        t = np.zeros(m.sum()) if span <= 0 else (f[m] - b.f1) / span
        d[m] = b.d1 + t * (b.d2 - b.d1)
        if b.weight_kind == "inv_f":
            # Equalises the *relative* error, which is what a differentiator
            # wants.  Guard DC, where a band may legitimately begin.
            fm = f[m]
            w[m] = b.w1 / np.maximum(fm, max(fm[fm > 0].min() if np.any(fm > 0) else 1e-6, 1e-9))
        else:
            w[m] = b.w1 + t * (b.w2 - b.w1)
    if np.any(w <= 0):
        raise RemezError("all band weights must be strictly positive")
    return d, w


# --------------------------------------------------------------------------
# Barycentric machinery
# --------------------------------------------------------------------------

def _bary_logs(x: np.ndarray):
    """(signs, logs) with prod_{i != k} (x_k - x_i) = signs_k * exp(logs_k)."""
    diff = x[:, None] - x[None, :]
    np.fill_diagonal(diff, 1.0)                # the excluded term, contributing 0
    return np.sign(diff).prod(axis=1), np.log(np.abs(diff)).sum(axis=1)


def _bary_weights(x: np.ndarray) -> np.ndarray:
    """gamma_k proportional to 1 / prod_{i != k} (x_k - x_i).

    The products span hundreds of orders of magnitude for a long filter, so the
    weights are formed in the log domain and then rescaled by their geometric
    mean: gamma = w * exp(mean(logs)).  Every formula that consumes them -- the
    deviation, the second barycentric form -- is a ratio in gamma, so a common
    factor is free to choose and keeping it near unity is what stops the
    exponentials from overflowing.  The first barycentric form is *not* a ratio
    in gamma, so it has to put that factor back; see _lagrange_first_form.
    """
    signs, logs = _bary_logs(x)
    return signs * np.exp(-(logs - logs.mean()))


def _lagrange(xq: np.ndarray, x: np.ndarray, y: np.ndarray, gamma: np.ndarray) -> np.ndarray:
    """Evaluate the interpolant through (x, y) in the first barycentric form.

        p(x) = prod_j (x - x_j) * sum_k w_k y_k / (x - x_k)

    The more familiar second form -- the ratio of two such sums -- is cheaper
    and is what the textbook derivation of the exchange uses, but its
    denominator is 1/prod(x - x_j), which for a long filter cancels away to
    nothing outside the hull of the nodes.  It then returns a finite, entirely
    wrong number for exactly the case a wide unconstrained transition band
    produces.  The first form is backward stable everywhere, and is used here
    throughout; the products are carried in the log domain so that a degree-100
    polynomial cannot overflow on the way.

    Note this form is not a ratio in the weights, so the geometric mean that
    _bary_weights divides out of gamma has to be put back.
    """
    diff = xq[:, None] - x[None, :]
    exact = np.abs(diff) < 1e-13
    adiff = np.abs(diff)
    adiff[exact] = 1.0
    sgn = np.sign(diff)
    sgn[exact] = 1.0

    log_adiff = np.log(adiff)
    log_l = log_adiff.sum(axis=1, keepdims=True)          # log |prod (x - x_j)|
    sign_l = sgn.prod(axis=1, keepdims=True)
    _, logs = _bary_logs(x)                               # gamma = w * exp(mean)
    expo = log_l + np.log(np.abs(gamma))[None, :] - logs.mean() - log_adiff
    hi = expo.max(axis=1, keepdims=True)
    terms = sign_l * np.sign(gamma)[None, :] * sgn * y[None, :] * np.exp(expo - hi)
    with np.errstate(over="ignore"):
        out = terms.sum(axis=1) * np.exp(hi[:, 0])

    # Nodes hit exactly take their tabulated value.
    rows, cols = np.nonzero(exact)
    out[rows] = y[cols]
    return out


def _reference_error(ext, x, dq, wq, sign):
    """Solve the interpolation problem on a reference set.

    Returns the minimax deviation implied by the reference and the weighted
    error of the resulting approximation over the whole grid.  By construction
    the error equals ``(-1)^k * delta`` at the reference points themselves --
    Oppenheim & Schafer eq. 7.132.
    """
    xext = x[ext]
    gamma = _bary_weights(xext)
    den = float(gamma @ (sign / wq[ext]))
    if abs(den) < 1e-300:
        raise RemezError("exchange broke down (singular denominator)")
    delta = float(gamma @ dq[ext]) / den
    yext = dq[ext] - sign * delta / wq[ext]
    return delta, wq * (dq - _lagrange(x, xext, yext, gamma))


# --------------------------------------------------------------------------
# Extremal selection
# --------------------------------------------------------------------------

def _find_extrema(err: np.ndarray, seg: np.ndarray, nreq: int) -> np.ndarray:
    """Locate the alternating extrema of the weighted error.

    A candidate is a local maximum of the *signed* error where the error is
    positive, or a local minimum where it is negative.  Testing the signed
    error rather than its magnitude matters: a small dip of the opposite sign
    at a band edge is a genuine alternation even though |err| is larger just
    next to it.  Runs of equal sign are then collapsed to their largest member
    so the survivors strictly alternate, and the set is trimmed to ``nreq``
    points by discarding the smallest deviations in a way that preserves the
    alternation.  The dense grid is treated as one contiguous sequence; a band
    gap is simply a jump in the error.
    """
    e = err
    ninf, pinf = -np.inf, np.inf
    prev_pos = np.r_[ninf, e[:-1]]
    next_pos = np.r_[e[1:], ninf]
    prev_neg = np.r_[pinf, e[:-1]]
    next_neg = np.r_[e[1:], pinf]

    is_max = (e > 0) & (e >= prev_pos) & (e > next_pos)
    is_min = (e < 0) & (e <= prev_neg) & (e < next_neg)
    cand = np.nonzero(is_max | is_min)[0].tolist()
    if not cand:
        raise RemezError("no extrema found; the error curve is degenerate")

    # Collapse consecutive same-sign candidates.
    merged = [cand[0]]
    for i in cand[1:]:
        if np.sign(err[i]) == np.sign(err[merged[-1]]):
            if np.abs(err[i]) > np.abs(err[merged[-1]]):
                merged[-1] = i
        else:
            merged.append(i)

    if len(merged) < nreq:
        raise RemezError(
            f"only {len(merged)} alternations found where {nreq} are needed; "
            "try a denser grid or a different filter length"
        )

    # Trim down to nreq, keeping the alternation intact.
    while len(merged) > nreq:
        excess = len(merged) - nreq
        if excess % 2 == 1:
            if np.abs(err[merged[0]]) < np.abs(err[merged[-1]]):
                merged.pop(0)
            else:
                merged.pop()
        else:
            mags = np.abs(err[merged])
            pair = int(np.argmin(np.maximum(mags[:-1], mags[1:])))
            del merged[pair:pair + 2]
    return np.array(merged, dtype=int)


# --------------------------------------------------------------------------
# The exchange itself
# --------------------------------------------------------------------------

@dataclass
class _Problem:
    """The equivalent type-I problem, tabulated on the dense grid."""

    f: np.ndarray
    seg: np.ndarray
    x: np.ndarray
    dq: np.ndarray
    wq: np.ndarray
    floor: float
    tol: float


def _alternating(n: int) -> np.ndarray:
    s = np.empty(n)
    s[0::2] = 1.0
    s[1::2] = -1.0
    return s


def _exchange(prob: _Problem, r: int, ext: np.ndarray, maxiter: int):
    """Run the exchange from a starting reference; returns (ext, converged, iterations)."""
    sign = _alternating(r + 1)
    converged = False
    it = 0
    for it in range(1, maxiter + 1):
        delta, err = _reference_error(ext, prob.x, prob.dq, prob.wq, sign)
        if np.abs(err).max() <= prob.floor:
            converged = True
            break
        try:
            new_ext = _find_extrema(err, prob.seg, r + 1)
        except RemezError:
            # Degenerate iterate: keep the best reference we have and stop.
            break
        peak = float(np.abs(err[new_ext]).max())
        if peak - abs(delta) <= prob.tol * abs(delta) + prob.floor:
            ext = new_ext
            converged = True
            break
        if np.array_equal(new_ext, ext):
            converged = True
            break
        ext = new_ext
    return ext, converged, it


def _uniform_reference(prob: _Problem, n: int) -> np.ndarray:
    """Evenly spread reference points, with a warp to escape symmetric traps.

    A perfectly uniform reference is degenerate for symmetric problems -- a
    Hilbert transformer gives delta = 0, and the error then has only n-1
    alternations instead of n -- so the spacing is warped until the reference
    is usable.
    """
    for attempt in range(6):
        t = np.linspace(0.0, 1.0, n) ** (1.0 + 0.13 * attempt)
        guess = np.unique((t * (prob.f.size - 1)).round().astype(int))
        if guess.size < n:
            raise RemezError("grid is too coarse for this filter length; raise the grid density")
        try:
            _, err = _reference_error(guess, prob.x, prob.dq, prob.wq, _alternating(n))
            _find_extrema(err, prob.seg, n)
        except RemezError:
            continue
        return guess
    raise RemezError(
        "could not find a starting reference with enough alternations; "
        "try a different filter length or a denser grid"
    )


def _scale_reference(prob: _Problem, ext: np.ndarray, n: int) -> np.ndarray:
    """Stretch a solved reference of one size into a starting reference of another.

    The extrema of an optimal filter cluster near the band edges in a way that
    barely changes with the filter length, so the solution of a half-size
    problem is a far better starting point than an even spread.  Each band
    keeps its share of the points and its internal shape; only the count grows.
    """
    nb = int(prob.seg.max()) + 1
    lo = np.array([np.nonzero(prob.seg == i)[0][0] for i in range(nb)])
    hi = np.array([np.nonzero(prob.seg == i)[0][-1] for i in range(nb)])
    room = hi - lo + 1

    groups = [ext[prob.seg[ext] == i] for i in range(nb)]
    counts = np.array([max(g.size, 1) for g in groups], dtype=float)

    quota = np.maximum(2, np.round(n * counts / counts.sum()).astype(int))
    quota = np.minimum(quota, room)
    # Settle the total on exactly n, moving points to wherever there is room.
    while quota.sum() > n:
        k = int(np.argmax(np.where(quota > 2, quota, -1)))
        if quota[k] <= 2:
            break
        quota[k] -= 1
    while quota.sum() < n:
        slack = room - quota
        if slack.max() <= 0:
            raise RemezError("grid is too coarse for this filter length; raise the grid density")
        quota[int(np.argmax(slack))] += 1

    out = []
    for i in range(nb):
        m = int(quota[i])
        g = groups[i]
        if g.size >= 2:
            pos = np.interp(np.linspace(0, g.size - 1, m), np.arange(g.size), g.astype(float))
        else:
            pos = np.linspace(lo[i], hi[i], m)
        out.append(_distinct_indices(pos, lo[i], hi[i]))
    return np.concatenate(out)


def _distinct_indices(pos: np.ndarray, lo: int, hi: int) -> np.ndarray:
    """Round positions to strictly increasing grid indices inside [lo, hi]."""
    idx = np.clip(np.round(pos).astype(int), lo, hi)
    for k in range(1, idx.size):                       # push collisions right
        if idx[k] <= idx[k - 1]:
            idx[k] = idx[k - 1] + 1
    if idx[-1] > hi:                                   # then back off the top
        idx -= idx[-1] - hi
        for k in range(idx.size - 2, -1, -1):
            if idx[k] >= idx[k + 1]:
                idx[k] = idx[k + 1] - 1
    if idx[0] < lo:
        raise RemezError("grid is too coarse for this filter length; raise the grid density")
    return idx


def _starting_reference(prob: _Problem, r: int, base: int = 24) -> np.ndarray:
    """Reference to start the exchange from, by scaling up from smaller problems.

    Below ``base`` coefficients an even spread is fine.  Above it, the uniform
    reference is so far from optimal that the first deviation underflows to
    round-off and the exchange has no signal to follow, so the problem is
    solved at half the size first and its answer scaled up.
    """
    if r <= base:
        return _uniform_reference(prob, r + 1)
    small = max(base, r // 2)
    ext = _starting_reference(prob, small, base)
    ext, _, _ = _exchange(prob, small, ext, maxiter=30)
    return _scale_reference(prob, ext, r + 1)


# --------------------------------------------------------------------------
# Amplitude -> impulse response
# --------------------------------------------------------------------------

def _cheb_coeffs(r, xext, yext, gamma) -> np.ndarray:
    """Cosine-series coefficients of P: P(cos w) = sum_k alpha_k cos(k w).

    P has degree r-1, so sampling it at 2r equispaced points around the unit
    circle and taking a DFT recovers the coefficients exactly.  The DFT is an
    orthogonal transform, which keeps this well conditioned even when P swings
    over many orders of magnitude across a wide transition band.
    """
    m = 2 * r
    w = 2.0 * np.pi * np.arange(m) / m
    g = _lagrange(np.cos(w), xext, yext, gamma)
    spec = np.fft.rfft(g)
    alpha = np.empty(r)
    alpha[0] = spec[0].real / m
    alpha[1:] = 2.0 * spec[1:r].real / m
    return alpha


def _amplitude_to_taps(numtaps, ftype, alpha) -> np.ndarray:
    """Turn the coefficients of P into the impulse response.

    A(w) = Q(w) P(cos w) is expanded onto the natural basis of each linear
    phase type -- cos(kw), cos((k-1/2)w), sin(kw), sin((k-1/2)w) -- using the
    product-to-sum identities, and the taps follow directly since the n-th
    basis coefficient equals twice the corresponding tap.
    """
    h = np.zeros(numtaps)
    b = alpha

    if ftype == 1:
        # A = sum_k alpha_k cos(k w); h[L] = alpha_0, h[L +- k] = alpha_k / 2.
        half = (numtaps - 1) // 2
        h[half] = b[0]
        k = np.arange(1, half + 1)
        h[half - k] = h[half + k] = b[k] / 2.0
        return h

    if ftype == 2:
        # cos(w/2) cos(kw) = [cos((k+1/2)w) + cos((k-1/2)w)] / 2
        m = numtaps // 2
        bb = np.r_[b, 0.0]
        c = np.empty(m + 1)
        c[1] = bb[0] + bb[1] / 2.0
        n = np.arange(2, m + 1)
        c[n] = (bb[n - 1] + bb[n]) / 2.0
    elif ftype == 3:
        # sin(w) cos(kw) = [sin((k+1)w) - sin((k-1)w)] / 2
        m = (numtaps - 1) // 2
        bb = np.r_[b, 0.0, 0.0]
        c = np.empty(m + 1)
        c[1] = bb[0] - bb[2] / 2.0
        n = np.arange(2, m + 1)
        c[n] = (bb[n - 1] - bb[n + 1]) / 2.0
    else:
        # sin(w/2) cos(kw) = [sin((k+1/2)w) - sin((k-1/2)w)] / 2
        m = numtaps // 2
        bb = np.r_[b, 0.0]
        c = np.empty(m + 1)
        c[1] = bb[0] - bb[1] / 2.0
        n = np.arange(2, m + 1)
        c[n] = (bb[n - 1] - bb[n]) / 2.0

    n = np.arange(1, m + 1)
    h[m - n] = c[n] / 2.0
    if ftype == 2:
        h[m - 1 + n] = h[m - n]
    elif ftype == 3:
        h[m + n] = -h[m - n]
        h[m] = 0.0                      # centre tap of a type III filter
    else:
        h[m - 1 + n] = -h[m - n]
    return h


def amplitude_response(h: np.ndarray, w: np.ndarray, symmetry: str = "symmetric") -> np.ndarray:
    """Zero-phase amplitude A(w) of a linear-phase FIR from its taps."""
    n = h.size
    centre = (n - 1) / 2.0
    k = centre - np.arange(n)
    if symmetry == "symmetric":
        return h @ np.cos(np.outer(k, w))
    return h @ np.sin(np.outer(k, w))


# --------------------------------------------------------------------------
# Main entry point
# --------------------------------------------------------------------------

def design(numtaps: int,
           bands,
           *,
           symmetry: str = "symmetric",
           fs: float = 1.0,
           grid_density: int = 16,
           maxiter: int = 40,
           tol: float = 1e-8) -> RemezResult:
    """Design a linear-phase FIR filter by the Remez exchange algorithm.

    Parameters
    ----------
    numtaps : filter length N.
    bands : sequence of :class:`Band`, with frequencies in units of ``fs``.
    symmetry : ``"symmetric"`` (types I/II) or ``"antisymmetric"`` (III/IV).
    fs : sampling frequency; band edges must lie in ``[0, fs/2]``.
    grid_density : dense-grid points per basis coefficient.
    maxiter : maximum number of exchange iterations.
    tol : relative stopping tolerance on (max|E| - |delta|) / |delta|.
    """
    if numtaps < 3:
        raise RemezError("numtaps must be at least 3")
    bands = list(bands)
    if not bands:
        raise RemezError("at least one band is required")

    ftype, r = _classify(numtaps, symmetry)
    if r < 2:
        raise RemezError(f"filter length {numtaps} is too short for a type {ftype} filter")

    # Validate and normalise band edges to cycles/sample.
    nyq = fs / 2.0
    norm = []
    prev = -np.inf
    for i, b in enumerate(bands):
        if not (0.0 <= b.f1 < b.f2 <= nyq):
            raise RemezError(
                f"band {i + 1}: need 0 <= f1 < f2 <= fs/2 ({nyq:g}), got {b.f1:g}..{b.f2:g}"
            )
        if b.f1 < prev - 1e-12:
            raise RemezError(f"band {i + 1} overlaps the previous band")
        prev = b.f2
        norm.append(Band(b.f1 / fs, b.f2 / fs, b.d1, b.d2,
                         b.w1, b.w2, b.name, b.weight_kind))

    f, seg = _build_grid(norm, r, grid_density, ftype)
    d, w_wt = _interp_band(norm, seg, f)

    omega = 2.0 * np.pi * f
    x = np.cos(omega)
    q = _q_factor(ftype, omega)
    dq = d / q                # desired for the equivalent type-I problem
    wq = w_wt * q             # weight for the equivalent type-I problem

    if f.size < r + 1:
        raise RemezError("grid is too coarse for this filter length; raise the grid density")

    # An over-parameterised specification (say one band and plenty of taps) can
    # be met exactly, and the stopping test -- being relative -- says nothing
    # once delta has shrunk to the size of the round-off in the grid values, so
    # it gets an absolute floor as well.
    floor = 1e-12 * max(1.0, float(np.abs(wq * dq).max()))
    prob = _Problem(f, seg, x, dq, wq, floor, tol)

    ext = _starting_reference(prob, r)
    ext, converged, it = _exchange(prob, r, ext, maxiter)

    # Final quantities on the converged extremal set.
    sign = _alternating(r + 1)
    xext = x[ext]
    gamma = _bary_weights(xext)
    delta = float(gamma @ dq[ext]) / float(gamma @ (sign / wq[ext]))
    yext = dq[ext] - sign * delta / wq[ext]

    p = _lagrange(x, xext, yext, gamma)
    amp = q * p
    err = w_wt * (d - amp)

    h = _amplitude_to_taps(numtaps, ftype, _cheb_coeffs(r, xext, yext, gamma))
    if not np.all(np.isfinite(h)):
        raise RemezError(
            "the design is numerically degenerate: the amplitude in the "
            "unconstrained transition region overflows.  Use fewer taps, or "
            "constrain more of the frequency axis."
        )

    # A polynomial pinned down only over narrow bands can do anything at all in
    # between; a huge peak there means the taps are meaningless in practice.
    w_full = np.linspace(0.0, np.pi, max(8 * numtaps, 512))
    peak_amp = float(np.abs(amplitude_response(h, w_full, symmetry)).max())

    dev = []
    for idx in range(len(norm)):
        m = seg == idx
        dev.append(float(np.abs(d[m] - amp[m]).max()) if m.any() else 0.0)

    return RemezResult(
        h=h,
        numtaps=numtaps,
        ftype=ftype,
        symmetry=symmetry,
        delta=delta,
        grid_f=f * fs,
        grid_d=d,
        grid_w=w_wt,
        grid_a=amp,
        grid_e=err,
        extremal_f=f[ext] * fs,
        extremal_e=err[ext],
        iterations=it,
        converged=converged,
        band_deviation=dev,
        peak_amplitude=peak_amp,
        fs=fs,
        bands=bands,
    )


def kaiser_order_estimate(delta_p: float, delta_s: float, transition: float, fs: float = 1.0) -> int:
    """Kaiser's estimate of the taps needed for a lowpass-like two-band design."""
    if transition <= 0 or delta_p <= 0 or delta_s <= 0:
        return 0
    df = transition / fs
    n = (-20.0 * np.log10(np.sqrt(delta_p * delta_s)) - 13.0) / (14.6 * df) + 1.0
    return int(np.ceil(n))
