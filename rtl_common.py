"""What the RTL back-ends agree on, before either of them writes any text.

The SystemVerilog and VHDL outputs describe the same hardware, so everything
that decides *what* that hardware is -- the options, the coefficient tables, the
term list of a folded filter, the resource counts, the latency and the vectors a
testbench checks against -- lives here, and each back-end only has to render it.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

import numpy as np

import datapath as dp

__all__ = ["RtlError", "RtlOptions", "RtlPlan", "plan_for", "sanitise_name",
           "STRUCTURE_LABELS"]

STRUCTURE_LABELS = {
    "chain": "accumulator chain (one adder per tap, shortest area, longest path)",
    "tree": "balanced adder tree, registered between levels",
    "mac": "one multiplier reused over the taps, one term per clock",
}


class RtlError(ValueError):
    """Raised when a design cannot be written out as hardware."""


@dataclass
class RtlOptions:
    """Everything the panel and the file dialog decided about the hardware."""

    name: str = "filt"
    headroom: int = 2
    fixed_coeffs: bool = True
    structure: str = "chain"
    folded: bool = False


@dataclass
class RtlPlan:
    """The hardware to build, in a form either back-end can render."""

    kind: str                       # "fir" | "iir"
    name: str
    wcoef: int
    frac: int
    headroom: int
    wdata: int
    fixed_coeffs: bool
    structure: str
    folded: bool
    coeffs: list                    # flat integer table the RTL stores
    coeff_labels: list              # what each slice of the runtime port holds
    numtaps: int = 0
    symmetry: str = "symmetric"
    nsec: int = 0
    terms: list = field(default_factory=list)     # folded/unfolded multiply list
    levels: int = 0                 # adder-tree depth
    latency: int = 1                # clocks from din_strb to dout_strb
    resources: dict = field(default_factory=dict)
    title: str = ""
    detail: list = field(default_factory=list)

    @property
    def nterms(self) -> int:
        return len(self.terms)

    @property
    def npairs(self) -> int:
        return sum(1 for _, taps, _ in self.terms if len(taps) == 2)

    @property
    def subtracts(self) -> bool:
        """True when the folded pre-adders subtract, as an antisymmetric one does."""
        return any(sign < 0 for _, _, sign in self.terms)

    @property
    def has_centre(self) -> bool:
        return self.folded and any(len(taps) == 1 for _, taps, _ in self.terms)

    def simulate(self, samples):
        """Run samples through the datapath this plan describes."""
        if self.kind == "iir":
            sections = [self.coeffs[i:i + 5] for i in range(0, len(self.coeffs), 5)]
            return dp.simulate("iir", sections, samples, self.frac, self.wcoef,
                               self.headroom)
        return dp.simulate("fir", self.taps, samples, self.frac, self.wcoef,
                           self.headroom, structure=self.structure,
                           folded=self.folded, symmetry=self.symmetry)

    @property
    def taps(self):
        """The full tap list, for the model.  Folding stores only half of it."""
        return self._taps

    @property
    def limits(self):
        return -(1 << (self.wdata - 1)), (1 << (self.wdata - 1)) - 1


def sanitise_name(text: str) -> str:
    """Turn a file stem into an identifier both languages accept."""
    name = re.sub(r"\W", "_", str(text).strip())
    name = re.sub(r"_+", "_", name).strip("_")
    if not name or not re.match(r"[A-Za-z]", name[0]):
        name = ("filt_" + name).rstrip("_")
    return name.lower()


def plan_for(kind: str, res, fixed, opts: RtlOptions) -> RtlPlan:
    """Validate the request and work out the hardware it implies."""
    if fixed is None:
        raise RtlError(
            "hardware needs fixed-point coefficients: choose Fixed point in "
            "the Arithmetic panel first")
    headroom = int(opts.headroom)
    if not 0 <= headroom <= 64:
        raise RtlError(f"headroom must be 0..64 bits, got {headroom}")
    if fixed.frac_bits < 0:
        raise RtlError(
            f"the binary point is {-fixed.frac_bits} places into the integer "
            "part, which no shift can undo; give the coefficients more bits")
    if fixed.saturated:
        raise RtlError(
            f"{fixed.saturated} coefficient(s) saturated when quantized, so the "
            "hardware would not be the filter that was designed; move the "
            "binary point right")
    if opts.structure not in dp.STRUCTURES:
        raise RtlError(f"unknown structure {opts.structure!r}")

    name = sanitise_name(opts.name)
    common = dict(name=name, wcoef=fixed.bits, frac=fixed.frac_bits,
                  headroom=headroom, wdata=fixed.bits + headroom,
                  fixed_coeffs=bool(opts.fixed_coeffs))

    if kind == "iir":
        if opts.folded or opts.structure != "chain":
            raise RtlError(
                "an IIR is a cascade of biquads: there is nothing to fold, and "
                "its feedback cannot be pipelined without changing the filter. "
                "Use the chain structure with folding off.")
        live = [0, 1, 2, 4, 5]
        sections = [[int(row[i]) for i in live] for row in fixed.ints]
        labels = []
        for s in range(len(sections)):
            labels += [f"section {s} b0", f"section {s} b1", f"section {s} b2",
                       f"section {s} a1", f"section {s} a2"]
        plan = RtlPlan(
            kind="iir", nsec=len(sections),
            coeffs=[v for section in sections for v in section],
            coeff_labels=labels, structure="chain", folded=False,
            latency=1,
            resources=dp.resources("iir", 0, "symmetric", "chain", False,
                                   nsec=len(sections)),
            title=f"{name}: {res.approximation} {res.response} IIR, "
                  f"order {res.order}",
            detail=[f"sample rate {res.fs:g}, {res.rp:g} dB passband ripple, "
                    f"{res.rs:g} dB stopband attenuation",
                    f"max |pole| = {res.max_pole_radius:.6f}"
                    f"{'' if res.stable else '   *** UNSTABLE ***'}",
                    f"Cascade of {len(sections)} biquad"
                    f"{'s' if len(sections) != 1 else ''}, each transposed "
                    "direct form II:",
                    "    y  = b0*x + s1",
                    "    s1 = b1*x - a1*y + s2",
                    "    s2 = b2*x - a2*y",
                    "a0 is 1 for every section, so nothing multiplies by it; a1",
                    "and a2 are given as designed and negated in the multiplier."],
            **common)
        plan._taps = []
        return plan

    taps = [int(v) for v in fixed.ints]
    if len(taps) < 2:
        raise RtlError("a filter needs at least two taps to be worth building")
    if opts.folded and not _symmetric(taps, res.symmetry):
        raise RtlError(
            "folding needs the taps to be symmetric, and these are not; "
            "the design must be linear phase")

    terms = dp.fir_terms(len(taps), res.symmetry, bool(opts.folded))
    band = ", ".join(f"{b.f1:g}-{b.f2:g}" for b in res.bands)
    stored = [taps[cindex] for cindex, _, _ in terms]
    labels = []
    for cindex, group, sign in terms:
        if len(group) == 1:
            labels.append(f"h[{cindex}]" + (" (centre tap)" if opts.folded else ""))
        else:
            op = "-" if sign < 0 else "+"
            labels.append(f"h[{cindex}]   for x[{group[0]}] {op} x[{group[1]}]")

    detail = [f"sample rate {res.fs:g}, bands {band}",
              f"weighted delta = {abs(res.delta):.6g} as designed",
              f"Structure: {STRUCTURE_LABELS[opts.structure]}."]
    if opts.folded:
        detail += [
            "Folded: the response is linear phase, so the taps are equal in",
            f"pairs and one pre-{'subtract' if terms[0][2] < 0 else 'add'} plus "
            f"one multiply serves two of them,",
            f"which is {len(taps)} multipliers down to {len(terms)}.  Note that a "
            "folded",
            "filter rounds once per pair rather than once per tap, so it is not",
            "bit-identical to the unfolded one -- it is very slightly better."]

    plan = RtlPlan(
        kind="fir", numtaps=len(taps), symmetry=res.symmetry,
        coeffs=stored, coeff_labels=labels,
        structure=opts.structure, folded=bool(opts.folded), terms=terms,
        levels=_tree_levels(len(terms)),
        latency=dp.latency("fir", len(taps), res.symmetry, opts.structure,
                           bool(opts.folded)),
        resources=dp.resources("fir", len(taps), res.symmetry, opts.structure,
                               bool(opts.folded)),
        title=f"{name}: Parks-McClellan FIR, type {res.ftype} "
              f"({res.symmetry}), N = {len(taps)}",
        detail=detail, **common)
    plan._taps = taps
    return plan


def _symmetric(taps, symmetry) -> bool:
    a = np.asarray(taps, dtype=np.int64)
    return bool(np.array_equal(a, (-a if symmetry == "antisymmetric" else a)[::-1]))


def _tree_levels(n: int) -> int:
    levels = 0
    while n > 1:
        n = (n + 1) // 2
        levels += 1
    return levels
