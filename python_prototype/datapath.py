"""The fixed-point datapath: what the generated hardware actually computes.

One definition of the arithmetic, used by everything that needs to agree on it
-- the SystemVerilog and VHDL back-ends, the self-checking testbenches they
emit, and the measured noise floor the GUI plots.  If this file and the RTL ever
disagree, the tests fail.

Every value is a signed integer of ``width`` bits representing
``integer * 2**-frac``.  Two operations build every filter here:

    mul(c, x)   exact product, plus half an LSB, shifted right by frac,
                saturated into width bits
    add(a, b)   saturated into width bits

Neither wraps.  Saturating adds are not associative, so the order they are
performed in is part of the specification, not an implementation detail: a
linear accumulator chain and a balanced tree give different answers once
anything clips, and folding a symmetric filter rounds once per *pair* instead
of once per tap.  Each of those variants is modelled separately and exactly.

Structures
----------
``chain``  products summed in tap order, one adder per tap (lowest area, longest
           combinational path)
``tree``   products summed pairwise, ceil(log2 N) levels deep
``mac``    one multiplier reused over N cycles, accumulating in tap order --
           arithmetically the same as ``chain``

``folded`` uses the symmetry of a linear-phase response: the taps are equal in
pairs, so one pre-add and one multiply serve two taps.  Two consequences worth
knowing: the pre-adder is one bit wider than the datapath, because it sums two
samples that may each be at full scale; and a folded filter rounds once per pair
rather than once per tap, so it is not bit-identical to the unfolded one -- its
noise floor is about 3 dB lower.
"""

from __future__ import annotations

import numpy as np

__all__ = ["STRUCTURES", "DatapathError", "mul", "add", "simulate",
           "fir_terms", "term_count", "latency", "resources",
           "noise_response", "effective_response", "NOISE_LEVEL"]

STRUCTURES = ("chain", "tree", "mac")

# RMS of the noise used to measure a datapath, as a fraction of full scale.
# Loud enough for rounding to be visible, quiet enough that a filter with a
# little gain does not spend the measurement clipping.
NOISE_LEVEL = 0.25


class DatapathError(ValueError):
    """Raised for a datapath that cannot be built or modelled."""


# --------------------------------------------------------------------------
# the two operations
# --------------------------------------------------------------------------

def _sat(value, width: int):
    lo, hi = -(1 << (width - 1)), (1 << (width - 1)) - 1
    if isinstance(value, np.ndarray):
        return np.clip(value, lo, hi)
    return lo if value < lo else hi if value > hi else value


def mul(coef: int, sample, frac: int, width: int):
    """Exact product, rounded to nearest, saturated into the datapath."""
    product = coef * sample
    if frac > 0:
        product = (product + (1 << (frac - 1))) >> frac
    return _sat(product, width)


def add(a, b, width: int):
    """Saturating add."""
    return _sat(a + b, width)


# --------------------------------------------------------------------------
# how a folded FIR is put together
# --------------------------------------------------------------------------

def fir_terms(numtaps: int, symmetry: str, folded: bool):
    """The multiplies a FIR needs, as (coefficient index, taps to pre-add).

    Unfolded this is simply one multiply per tap.  Folded, a symmetric pair
    shares a multiply: ``(k, (k, N-1-k), +1)`` means "add those two taps and
    multiply once by h[k]".  An antisymmetric filter subtracts instead, and its
    centre tap -- which is exactly zero -- drops out altogether.
    """
    if not folded:
        return [(k, (k,), 1) for k in range(numtaps)]

    anti = symmetry == "antisymmetric"
    pairs = numtaps // 2
    terms = [(k, (k, numtaps - 1 - k), -1 if anti else 1) for k in range(pairs)]
    if numtaps % 2 == 1 and not anti:
        centre = numtaps // 2
        terms.append((centre, (centre,), 1))
    return terms


def term_count(numtaps: int, symmetry: str, folded: bool) -> int:
    return len(fir_terms(numtaps, symmetry, folded))


def latency(kind: str, numtaps: int, symmetry: str, structure: str,
            folded: bool, nsec: int = 1) -> int:
    """Clocks from a strobe on din_strb to the one on dout_strb."""
    if kind == "iir":
        return 1
    n = term_count(numtaps, symmetry, folded)
    if structure == "chain":
        return 1
    if structure == "tree":
        return 1 + _tree_levels(n)
    if structure == "mac":
        return n + 2
    raise DatapathError(f"unknown structure {structure!r}")


def _tree_levels(n: int) -> int:
    levels = 0
    while n > 1:
        n = (n + 1) // 2
        levels += 1
    return levels


def resources(kind: str, numtaps: int, symmetry: str, structure: str,
              folded: bool, nsec: int = 1) -> dict:
    """Multipliers, adders and delay elements the structure instantiates."""
    if kind == "iir":
        return {"multipliers": 5 * nsec, "adders": 4 * nsec,
                "delays": 2 * nsec, "pipeline": 0}
    n = term_count(numtaps, symmetry, folded)
    pre = n - (1 if (folded and numtaps % 2 and symmetry == "symmetric") else 0) \
        if folded else 0
    if structure == "mac":
        return {"multipliers": 1, "adders": 1 + (1 if folded else 0),
                "delays": numtaps, "pipeline": 0}
    adders = (n - 1) + pre
    return {"multipliers": n, "adders": adders, "delays": numtaps - 1,
            "pipeline": _tree_levels(n) if structure == "tree" else 0}


# --------------------------------------------------------------------------
# simulation
# --------------------------------------------------------------------------

def _reduce_chain(values, width):
    acc = values[0]
    for v in values[1:]:
        acc = add(acc, v, width)
    return acc


def _reduce_tree(values, width):
    level = list(values)
    while len(level) > 1:
        nxt = [add(level[i], level[i + 1], width)
               for i in range(0, len(level) - 1, 2)]
        if len(level) % 2:
            nxt.append(level[-1])          # an odd one out passes through
        level = nxt
    return level[0]


def _reduce(values, width, structure):
    if structure == "tree":
        return _reduce_tree(values, width)
    return _reduce_chain(values, width)     # chain and mac accumulate in order


def simulate(kind: str, coeffs, samples, frac: int, wcoef: int, headroom: int,
             *, structure: str = "chain", folded: bool = False,
             symmetry: str = "symmetric"):
    """Run integer samples through the modelled datapath, exactly.

    ``coeffs`` is the tap list for a FIR, or one (b0, b1, b2, a1, a2) per
    section for an IIR.  Vectorised over samples where the structure allows it,
    which is every FIR; an IIR has feedback and is stepped one sample at a time.
    """
    width = wcoef + headroom
    x = np.asarray(samples, dtype=object).ravel()

    if kind == "fir":
        return _simulate_fir([int(c) for c in coeffs], x, frac, wcoef, headroom,
                             structure, folded, symmetry)
    if kind != "iir":
        raise DatapathError(f"unknown filter kind {kind!r}")

    sections = [tuple(int(v) for v in s) for s in coeffs]
    state = [[0, 0] for _ in sections]
    out = []
    for sample in x:
        value = _sat(int(sample), width)
        for i, (b0, b1, b2, a1, a2) in enumerate(sections):
            s1, s2 = state[i]
            y = add(mul(b0, value, frac, width), s1, width)
            u1 = add(mul(b1, value, frac, width),
                     mul(_sat(-a1, wcoef), y, frac, width), width)
            s1_next = add(u1, s2, width)
            s2_next = add(mul(b2, value, frac, width),
                          mul(_sat(-a2, wcoef), y, frac, width), width)
            state[i] = [s1_next, s2_next]
            value = y
        out.append(int(value))
    return out


def _simulate_fir(taps, x, frac, wcoef, headroom, structure, folded, symmetry):
    width = wcoef + headroom
    n = len(taps)
    m = x.size
    # Numpy int64 is wide enough: a product needs width + wcoef bits, and both
    # are capped well below 63 by the coefficient word length.
    xs = np.clip(np.asarray([int(v) for v in x], dtype=np.int64),
                 -(1 << (width - 1)), (1 << (width - 1)) - 1)

    # line[k] is the input delayed by k samples, over the whole record.
    line = np.zeros((n, m), dtype=np.int64)
    for k in range(n):
        if k:
            line[k, k:] = xs[:-k]
        else:
            line[k] = xs

    products = []
    for cindex, taps_in, sign in fir_terms(n, symmetry, folded):
        if len(taps_in) == 1:
            operand = line[taps_in[0]]
        else:
            # The pre-adder is one bit wider than the datapath and does not
            # saturate: it sums two samples that may each be at full scale, and
            # clipping that sum would throw away signal rather than round it.
            a, b = taps_in
            operand = line[a] + sign * line[b]
        products.append(mul(taps[cindex], operand, frac, width))

    return [int(v) for v in _reduce(products, width, structure)]


# --------------------------------------------------------------------------
# measured noise floor
# --------------------------------------------------------------------------

def noise_response(kind, coeffs, exact, frac, wcoef, headroom, *,
                   structure="chain", folded=False, symmetry="symmetric",
                   length=None, seed=12345):
    """Measure the arithmetic noise the datapath adds, as a spectrum.

    White noise goes in, and the integer datapath's output is compared against
    the same filter computed exactly -- same coefficients, no rounding, no
    saturation.  The difference is purely what the arithmetic did, so its
    spectrum can be measured with no dynamic range problem: taking the output
    spectrum directly instead would measure the analysis window's sidelobes
    rather than the filter, since a passband sixty dB above a stopband leaks
    into it.

    ``exact`` is called with the float input and must return the float output of
    the ideal-arithmetic filter.

    Returns (frequency in cycles/sample, noise amplitude in dB relative to the
    input, RMS of that noise in LSB).  Add it in power to |H| to get what a
    bench measurement would show.
    """
    if frac < 0:
        raise DatapathError(
            "the binary point is inside the integer part, so this is not a "
            "datapath that can be measured; give the coefficients more bits")
    if length is None:
        length = 1 << 15 if kind == "fir" else 1 << 13
    segment = 512
    length = max(int(length), 8 * segment)

    rng = np.random.default_rng(seed)
    full = (1 << (wcoef + headroom - 1)) - 1
    xi = np.clip(np.round(rng.normal(0.0, NOISE_LEVEL * full, length)),
                 -full, full).astype(np.int64)

    got = np.asarray(simulate(kind, coeffs, xi, frac, wcoef, headroom,
                              structure=structure, folded=folded,
                              symmetry=symmetry), dtype=float)
    want = np.asarray(exact(xi.astype(float)), dtype=float)
    if want.shape != got.shape:
        raise DatapathError("the exact reference must return one sample per input")
    # A degenerate design -- one whose amplitude runs away in an unconstrained
    # transition band -- has no measurable noise floor, only overflow.
    if not (np.all(np.isfinite(want)) and np.all(np.isfinite(got))):
        raise DatapathError(
            "the filter's own response overflows, so there is no noise floor "
            "to measure; the design itself needs looking at first")

    skip = min(length // 4, 8 * segment)
    error = got[skip:] - want[skip:]
    f, pee = _welch(error, segment)
    _, pxx = _welch(xi.astype(float)[skip:], segment)
    with np.errstate(divide="ignore", invalid="ignore"):
        ratio = np.sqrt(pee / pxx)
    return (f, 20.0 * np.log10(np.maximum(ratio, 1e-30)),
            float(np.sqrt(np.mean(error ** 2))))


def effective_response(mag_db, noise_db):
    """What a measurement sees: the response with the noise added in power.

    The two are uncorrelated, so they add as powers rather than amplitudes,
    which is why a stopband thirty dB below the noise floor simply is not
    there to be measured.
    """
    return 10.0 * np.log10(10.0 ** (np.asarray(mag_db) / 10.0)
                           + 10.0 ** (np.asarray(noise_db) / 10.0))


def _welch(x, segment):
    """Averaged periodogram, Blackman-Harris window, half-overlapping."""
    n = np.arange(segment)
    # 4-term Blackman-Harris: -92 dB sidelobes, so a loud band cannot leak into
    # a quiet one at any dynamic range this tool can produce.
    window = (0.35875
              - 0.48829 * np.cos(2 * np.pi * n / segment)
              + 0.14128 * np.cos(4 * np.pi * n / segment)
              - 0.01168 * np.cos(6 * np.pi * n / segment))
    step = segment // 2
    acc = np.zeros(segment // 2 + 1)
    count = 0
    for start in range(0, len(x) - segment + 1, step):
        spectrum = np.fft.rfft(x[start:start + segment] * window)
        acc += np.abs(spectrum) ** 2
        count += 1
    if count:
        acc /= count
    return np.fft.rfftfreq(segment), acc
