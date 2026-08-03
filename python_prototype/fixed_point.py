"""Fixed-point quantization of filter coefficients.

A filter designed in double precision has to be built out of finite-width
numbers.  Each coefficient becomes a signed two's-complement integer of ``B``
bits with an implied binary point ``F`` places from the right, so that the
value actually used by the hardware is

    value = integer * 2**-F,    integer in [-2**(B-1), 2**(B-1) - 1]

which is the format usually written Q(B-1-F).F.  Rounding every coefficient to
that lattice perturbs the frequency response: an FIR filter loses its
equiripple property and its stopband floor rises, and an IIR filter's poles
move, which at worst pushes one outside the unit circle and makes the filter
unstable.

The binary point is placed automatically by default, as far left as the largest
coefficient allows, since every bit of headroom that is not needed is a bit of
resolution given away.

What this models is *coefficient* quantization only.  The arithmetic in the
datapath -- rounding of products, the width of the accumulator, overflow
behaviour -- is a separate question and is not simulated here.

Nothing here is specific to FIR or IIR; :func:`quantize` takes any array of
coefficients, and :func:`quantize_sos` adds the one convention a biquad
cascade needs.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

__all__ = ["Fixed", "FixedPointError", "auto_frac_bits", "quantize", "quantize_sos"]

MIN_BITS = 2
MAX_BITS = 53          # a double holds integers exactly up to 2**53


class FixedPointError(ValueError):
    """Raised for a word length or binary point that cannot be used."""


@dataclass
class Fixed:
    """A set of coefficients rounded to a fixed-point format."""

    bits: int
    frac_bits: int
    ints: np.ndarray               # the stored integers
    values: np.ndarray             # what they represent, ints * 2**-frac_bits
    saturated: int                 # how many had to be clipped to fit
    ideal: np.ndarray              # the coefficients before rounding

    @property
    def step(self) -> float:
        """The resolution: the gap between adjacent representable values."""
        return 2.0 ** -self.frac_bits

    @property
    def int_bits(self) -> int:
        """Bits left of the binary point, excluding the sign bit."""
        return self.bits - 1 - self.frac_bits

    @property
    def qformat(self) -> str:
        return f"Q{self.int_bits}.{self.frac_bits}"

    @property
    def limits(self) -> tuple:
        return -(2 ** (self.bits - 1)), 2 ** (self.bits - 1) - 1

    @property
    def error(self) -> np.ndarray:
        return self.values - self.ideal

    @property
    def max_error(self) -> float:
        return float(np.max(np.abs(self.error))) if self.ideal.size else 0.0


def _check_bits(bits: int) -> int:
    bits = int(bits)
    if not MIN_BITS <= bits <= MAX_BITS:
        raise FixedPointError(f"word length must be {MIN_BITS}..{MAX_BITS} bits, got {bits}")
    return bits


def auto_frac_bits(values, bits: int) -> int:
    """Binary point placed as far left as the largest coefficient allows.

    Every integer bit that the coefficients do not need is a fractional bit
    given away, so the scale is chosen to be the largest power of two for which
    nothing saturates.
    """
    bits = _check_bits(bits)
    peak = float(np.max(np.abs(np.asarray(values, dtype=float)))) if np.size(values) else 0.0
    if peak == 0.0 or not np.isfinite(peak):
        return bits - 1
    return int(np.floor(np.log2((2 ** (bits - 1) - 1) / peak)))


def quantize(values, bits: int, frac_bits: int | None = None) -> Fixed:
    """Round ``values`` to a ``bits``-wide signed fixed-point format.

    ``frac_bits`` places the binary point; ``None`` picks it with
    :func:`auto_frac_bits`.  Values that do not fit are clipped rather than
    allowed to wrap, and the number clipped is reported.
    """
    bits = _check_bits(bits)
    ideal = np.asarray(values, dtype=float)
    if frac_bits is None:
        frac_bits = auto_frac_bits(ideal, bits)
    frac_bits = int(frac_bits)
    if not -1024 < frac_bits < 1024:
        raise FixedPointError(f"fractional bits out of range: {frac_bits}")

    lo, hi = -(2 ** (bits - 1)), 2 ** (bits - 1) - 1
    raw = np.round(ideal * 2.0 ** frac_bits)
    ints = np.clip(raw, lo, hi)
    saturated = int(np.count_nonzero(ints != raw))
    ints = ints.astype(np.int64)
    return Fixed(bits=bits, frac_bits=frac_bits, ints=ints,
                 values=ints * 2.0 ** -frac_bits, saturated=saturated,
                 ideal=ideal)


def quantize_sos(sos, bits: int, frac_bits: int | None = None) -> Fixed:
    """Quantize a biquad cascade, leaving each section's a0 at exactly one.

    a0 is not a multiplier in an implementation -- the sections are normalised
    so that it is one, and nothing multiplies by it -- so it is neither
    quantized nor allowed to influence where the binary point goes.  The five
    coefficients that *are* multipliers share one format across all sections,
    which is what a cascade built from one multiplier block does.
    """
    sos = np.asarray(sos, dtype=float)
    if sos.ndim != 2 or sos.shape[1] != 6:
        raise FixedPointError("expected an (nsections, 6) array of sections")
    live = np.r_[0, 1, 2, 4, 5]                     # every column but a0

    if frac_bits is None:
        frac_bits = auto_frac_bits(sos[:, live], bits)
    q = quantize(sos[:, live], bits, frac_bits)

    values = np.array(sos)
    values[:, live] = q.values
    values[:, 3] = 1.0
    ints = np.zeros(sos.shape, dtype=np.int64)
    ints[:, live] = q.ints
    ints[:, 3] = int(round(2.0 ** q.frac_bits))     # what a0 would store
    return Fixed(bits=q.bits, frac_bits=q.frac_bits, ints=ints, values=values,
                 saturated=q.saturated, ideal=sos)
