"""SystemVerilog generation for a designed filter.

The structure the design view draws -- multipliers, adders and unit delays --
written out as synthesisable RTL.  What comes out is one file holding four
modules: a multiplier, an adder, a delay element, and a top level that wires
them into the topology of the filter currently on screen.

    <name>_mul     one coefficient multiply, rounded and saturated back to the
                   datapath format
    <name>_add     one datapath-width add, saturating
    <name>_delay   one unit delay, advanced when din_strb is seen
    <name>         the filter

Numbers
-------
The coefficients are ``WCOEF`` bits with ``FRAC`` fractional bits, exactly as
the Arithmetic panel quantized them.  The datapath carries the same ``FRAC``
fractional bits and ``HEADROOM`` extra integer bits, so ``din``, ``dout`` and
every internal signal are ``WDATA = WCOEF + HEADROOM`` bits wide, with unity
represented by ``1 << FRAC``.

Each multiply is exact in ``WDATA + WCOEF`` bits and is then rounded (add half
an LSB, shift right by ``FRAC``) and saturated back to ``WDATA``.  Each add is
saturating.  Headroom is what keeps the adds off their limits: a direct-form
FIR sums N products, and without integer bits above the coefficient format that
sum clips.

Timing
------
Synchronous, one sample per ``din_strb``, active-low synchronous reset.  A
strobe on ``din_strb`` with a sample on ``din`` shifts the delay line and
registers the result, which appears on ``dout`` with ``dout_strb`` high for one
cycle -- so the latency from ``din_strb`` to ``dout_strb`` is one clock.

Coefficients
------------
With ``fixed_coeffs`` the values are elaboration-time parameters, which lets
synthesis specialise every multiplier -- often into a handful of shifts and
adds -- and there is no coefficient port.  Without it the top level takes a
packed ``coeff`` input and the values can be changed while it runs, at the cost
of real multipliers.

:func:`simulate` is a bit-exact model of the generated datapath, in Python.  It
exists so the RTL can be checked against something other than itself, and it is
what the tests compare a Verilator run against.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

import numpy as np

__all__ = ["SvError", "SvOptions", "fir_source", "iir_source", "source_for",
           "simulate", "sanitise_name"]


class SvError(ValueError):
    """Raised when a design cannot be written out as RTL."""


@dataclass
class SvOptions:
    """What the Arithmetic panel and the file dialog decided."""

    name: str = "filt"
    headroom: int = 2
    fixed_coeffs: bool = True


def sanitise_name(text: str) -> str:
    """Turn a file stem into a legal SystemVerilog identifier."""
    name = re.sub(r"\W", "_", str(text).strip())
    name = re.sub(r"_+", "_", name).strip("_")
    if not name or not re.match(r"[A-Za-z_]", name[0]):
        name = ("filt_" + name).rstrip("_")
    return name.lower()


# --------------------------------------------------------------------------
# Fixed-point arithmetic, shared by the generator and the reference model
# --------------------------------------------------------------------------

def _limits(width: int):
    return -(1 << (width - 1)), (1 << (width - 1)) - 1


def _sat(value: int, width: int) -> int:
    lo, hi = _limits(width)
    return lo if value < lo else hi if value > hi else value


def _mul(coef: int, sample: int, frac: int, width: int) -> int:
    """One coefficient multiply: exact, rounded to frac bits, saturated."""
    product = coef * sample
    if frac > 0:
        product += 1 << (frac - 1)
        product >>= frac                    # floor, matching >>> on a signed value
    return _sat(product, width)


def _neg(coef: int, width: int) -> int:
    """Saturating negate, for the feedback coefficients of a biquad."""
    return _sat(-coef, width)


def simulate(kind: str, coeffs, samples, frac: int, wcoef: int, headroom: int):
    """Bit-exact model of the generated RTL, in integers.

    ``kind`` is "fir" or "iir"; ``coeffs`` is the tap list, or a list of
    (b0, b1, b2, a1, a2) per section.  ``samples`` are datapath integers, and
    so is the result.  Every rounding and saturation happens in the same place
    and the same order as the RTL does it.
    """
    width = wcoef + headroom
    x = [int(v) for v in np.asarray(samples).ravel()]

    if kind == "fir":
        taps = [int(c) for c in coeffs]
        state = [0] * max(len(taps) - 1, 0)          # x[1..N-1]
        out = []
        for sample in x:
            line = [_sat(int(sample), width)] + state
            acc = _mul(taps[0], line[0], frac, width)
            for k in range(1, len(taps)):
                acc = _sat(acc + _mul(taps[k], line[k], frac, width), width)
            out.append(acc)
            state = line[:-1] if state else []
        return out

    if kind != "iir":
        raise SvError(f"unknown filter kind {kind!r}")

    sections = [tuple(int(v) for v in s) for s in coeffs]
    state = [[0, 0] for _ in sections]
    out = []
    for sample in x:
        value = _sat(int(sample), width)
        for i, (b0, b1, b2, a1, a2) in enumerate(sections):
            s1, s2 = state[i]
            y = _sat(_mul(b0, value, frac, width) + s1, width)
            u1 = _sat(_mul(b1, value, frac, width)
                      + _mul(_neg(a1, wcoef), y, frac, width), width)
            s1_next = _sat(u1 + s2, width)
            s2_next = _sat(_mul(b2, value, frac, width)
                           + _mul(_neg(a2, wcoef), y, frac, width), width)
            state[i] = [s1_next, s2_next]
            value = y
        out.append(value)
    return out


# --------------------------------------------------------------------------
# The reusable modules
# --------------------------------------------------------------------------

def _library(name: str) -> list:
    """The multiplier, adder and delay element, once each."""
    return [
        "// ---------------------------------------------------------------------",
        "// One coefficient multiply.",
        "//",
        "// The product is formed exactly in WDATA+WCOEF bits, which leaves it",
        "// with 2*FRAC fractional bits; half an LSB is added and it is shifted",
        "// back down to FRAC, then saturated into the datapath width.  With",
        "// FIXED set the coefficient is a parameter, so synthesis can fold the",
        "// multiply down to shifts and adds; otherwise it comes from the port.",
        "// NEG negates the coefficient, which is how the feedback taps of a",
        "// biquad are subtracted without a separate subtractor.",
        "// ---------------------------------------------------------------------",
        f"module {name}_mul #(",
        "    parameter int     WDATA = 16,",
        "    parameter int     WCOEF = 12,",
        "    parameter int     FRAC  = 11,",
        "    parameter bit     FIXED = 1'b1,",
        "    parameter bit     NEG   = 1'b0,",
        "    parameter longint COEF  = 0",
        ") (",
        "    input  logic signed [WCOEF-1:0] coef,",
        "    input  logic signed [WDATA-1:0] din,",
        "    output logic signed [WDATA-1:0] dout",
        ");",
        "    localparam int WPROD = WDATA + WCOEF;",
        "    localparam longint CMAX =  (64'sd1 <<< (WCOEF-1)) - 1;",
        "    localparam longint CMIN = -(64'sd1 <<< (WCOEF-1));",
        "    // Saturating negate at elaboration, for the fixed case.",
        "    localparam longint CFIX = NEG ? ((-COEF > CMAX) ? CMAX :",
        "                                    (-COEF < CMIN) ? CMIN : -COEF) : COEF;",
        "",
        "    logic signed [WCOEF-1:0] c;",
        "    always_comb begin",
        "        if (FIXED)      c = WCOEF'(CFIX);",
        "        else if (NEG)   c = (coef == WCOEF'(CMIN)) ? WCOEF'(CMAX) : -coef;",
        "        else            c = coef;",
        "    end",
        "",
        "    logic signed [WPROD-1:0] prod, rounded;",
        "    always_comb begin",
        "        prod    = $signed(din) * $signed(c);",
        "        rounded = (FRAC > 0) ? ((prod + (WPROD'(1) <<< (FRAC-1))) >>> FRAC)",
        "                             : prod;",
        "    end",
        "",
        f"    {name}_sat #(.WIN(WPROD), .WOUT(WDATA)) u_sat (.din(rounded), .dout(dout));",
        "endmodule",
        "",
        "",
        "// ---------------------------------------------------------------------",
        "// One datapath-width add, saturating rather than wrapping: a filter",
        "// that clips is bad, one that wraps is unrecognisable.",
        "// ---------------------------------------------------------------------",
        f"module {name}_add #(",
        "    parameter int WDATA = 16",
        ") (",
        "    input  logic signed [WDATA-1:0] a,",
        "    input  logic signed [WDATA-1:0] b,",
        "    output logic signed [WDATA-1:0] sum",
        ");",
        "    logic signed [WDATA:0] full;",
        "    always_comb full = $signed(a) + $signed(b);",
        f"    {name}_sat #(.WIN(WDATA+1), .WOUT(WDATA)) u_sat (.din(full), .dout(sum));",
        "endmodule",
        "",
        "",
        "// ---------------------------------------------------------------------",
        "// Clamp a wide signed value into a narrow one.",
        "// ---------------------------------------------------------------------",
        f"module {name}_sat #(",
        "    parameter int WIN  = 32,",
        "    parameter int WOUT = 16",
        ") (",
        "    input  logic signed [WIN-1:0]  din,",
        "    output logic signed [WOUT-1:0] dout",
        ");",
        "    localparam logic signed [WIN-1:0] HI =  (WIN'(1) <<< (WOUT-1)) - 1;",
        "    localparam logic signed [WIN-1:0] LO = -(WIN'(1) <<< (WOUT-1));",
        "    always_comb begin",
        "        if      ($signed(din) > HI) dout = WOUT'(HI);",
        "        else if ($signed(din) < LO) dout = WOUT'(LO);",
        "        else                        dout = din[WOUT-1:0];",
        "    end",
        "endmodule",
        "",
        "",
        "// ---------------------------------------------------------------------",
        "// One unit delay.  It advances only on a strobe, so the delay line",
        "// moves one place per input sample however slowly they arrive.",
        "// ---------------------------------------------------------------------",
        f"module {name}_delay #(",
        "    parameter int WDATA = 16",
        ") (",
        "    input  logic                    clk,",
        "    input  logic                    resetn,",
        "    input  logic                    en,",
        "    input  logic signed [WDATA-1:0] d,",
        "    output logic signed [WDATA-1:0] q",
        ");",
        "    always_ff @(posedge clk) begin",
        "        if (!resetn) q <= '0;",
        "        else if (en) q <= d;",
        "    end",
        "endmodule",
        "",
        "",
    ]


def _preamble(title: str, detail: list, wcoef: int, frac: int, headroom: int,
              fixed_coeffs: bool, coeff_map: list) -> list:
    wdata = wcoef + headroom
    int_bits = wcoef - 1 - frac
    out = ["// " + "=" * 69,
           f"// {title}",
           "//"]
    out += [f"// {line}" for line in detail]
    out += [
        "//",
        f"// Coefficients  {wcoef} bits, Q{int_bits}.{frac}"
        f"   (value = integer * 2^-{frac})",
        f"// Datapath      {wdata} bits = {wcoef} + {headroom} headroom, "
        f"Q{int_bits + headroom}.{frac}",
        f"//               unity is {1 << frac}, "
        f"range [{-(1 << (wdata - 1)) / (1 << frac):g}, "
        f"{((1 << (wdata - 1)) - 1) / (1 << frac):g}]",
        "// Products are exact, then rounded to nearest and saturated; adds",
        "// saturate.  Headroom is what keeps the adder chain off its limits.",
        "//",
        "// clk / resetn        synchronous, active-low reset",
        "// din, din_strb       one sample per strobe",
        "// dout, dout_strb     the result, one clock after din_strb",
        "//",
    ]
    if fixed_coeffs:
        out += ["// Coefficients are elaboration-time parameters, so synthesis can",
                "// specialise each multiplier.  There is no coefficient port.",
                "//"]
    else:
        out += ["// Coefficients arrive on the packed 'coeff' port and may change while",
                "// the filter runs.  Slice k occupies coeff[k*WCOEF +: WCOEF]:",
                "//"]
        out += [f"//   [{i:3d}] {label}" for i, label in enumerate(coeff_map)]
        out.append("//")
    out += [
        "// Generated by remez_gui.py.  Lint it with, for example:",
        # A comment whose first word is the tool name is read as a pragma.
        "//     $ verilator --lint-only -Wall <this file>",
        "// " + "=" * 69,
        "",
        "`default_nettype none",
        "",
        "// Everything the filter needs is in this one file, so the checker's",
        "// one-module-per-file rule does not apply to it.",
        "/* verilator lint_off DECLFILENAME */",
        "",
        "",
    ]
    return out


# --------------------------------------------------------------------------
# FIR
# --------------------------------------------------------------------------

def fir_source(res, fixed, opts: SvOptions) -> str:
    """RTL for the tapped delay line, one multiplier and adder per tap."""
    name = sanitise_name(opts.name)
    headroom, wcoef, frac = _check(opts, fixed)
    taps = [int(v) for v in fixed.ints]
    n = len(taps)
    if n < 2:
        raise SvError("a filter needs at least two taps to be worth building")

    band = ", ".join(f"{b.f1:g}-{b.f2:g}" for b in res.bands)
    lines = _preamble(
        f"{name}: Parks-McClellan FIR, type {res.ftype} ({res.symmetry}), "
        f"N = {n}",
        [f"sample rate {res.fs:g}, bands {band}",
         f"weighted delta = {abs(res.delta):.6g} as designed",
         "Direct form: a tapped delay line, one multiply per tap, summed",
         "along a chain of adders in tap order."],
        wcoef, frac, headroom, opts.fixed_coeffs,
        [f"h[{k}]" for k in range(n)])
    lines += _library(name)

    ports = ["    input  wire                     clk,",
             "    input  wire                     resetn,",
             "    input  wire signed [WDATA-1:0]  din,",
             "    input  wire                     din_strb,"]
    if not opts.fixed_coeffs:
        ports.append("    input  wire signed [NTAPS*WCOEF-1:0] coeff,")
    ports += ["    output logic signed [WDATA-1:0] dout,",
              "    output logic                    dout_strb"]

    lines += [
        "// ---------------------------------------------------------------------",
        f"// {name}: the filter itself.",
        "// ---------------------------------------------------------------------",
        f"module {name} #(",
        "    // These describe the filter that was generated: the coefficients",
        "    // below are stored in this format, so overriding them would leave",
        "    // the two disagreeing.  They live here, rather than in the body, so",
        "    // that the port declarations can use them.",
        f"    parameter int NTAPS    = {n},",
        f"    parameter int WCOEF    = {wcoef},",
        f"    parameter int FRAC     = {frac},",
        f"    parameter int HEADROOM = {headroom},",
        "    parameter int WDATA    = WCOEF + HEADROOM",
        ") (",
        *ports,
        ");",
        "    // The impulse response, as stored integers.",
        "    localparam longint COEF [0:NTAPS-1] = '{",
    ]
    lines += _wrap_values(taps, indent=8)
    lines += [
        "    };",
        "",
        "    // x[0] is this cycle's sample; x[k] is it delayed by k strobes.",
        "    wire signed [WDATA-1:0] x    [0:NTAPS-1];",
        "    wire signed [WDATA-1:0] prod [0:NTAPS-1];",
        "    wire signed [WDATA-1:0] acc  [0:NTAPS-1];",
        "",
        "    assign x[0] = din;",
        "",
        "    generate",
        "        for (genvar k = 0; k < NTAPS; k++) begin : g_tap",
        "            if (k > 0) begin : g_delay",
        f"                {name}_delay #(.WDATA(WDATA)) u_z (",
        "                    .clk(clk), .resetn(resetn), .en(din_strb),",
        "                    .d(x[k-1]), .q(x[k]));",
        "            end",
        "",
        f"            {name}_mul #(",
        "                .WDATA(WDATA), .WCOEF(WCOEF), .FRAC(FRAC),",
        f"                .FIXED(1'b{int(opts.fixed_coeffs)}), .COEF(COEF[k])",
        "            ) u_mul (",
        "                .coef(" + ("'0" if opts.fixed_coeffs
                                    else "coeff[k*WCOEF +: WCOEF]") + "),",
        "                .din(x[k]), .dout(prod[k]));",
        "",
        "            if (k == 0) begin : g_first",
        "                assign acc[0] = prod[0];",
        "            end else begin : g_sum",
        f"                {name}_add #(.WDATA(WDATA)) u_add (",
        "                    .a(acc[k-1]), .b(prod[k]), .sum(acc[k]));",
        "            end",
        "        end",
        "    endgenerate",
        "",
        "    always_ff @(posedge clk) begin",
        "        if (!resetn) begin",
        "            dout      <= '0;",
        "            dout_strb <= 1'b0;",
        "        end else begin",
        "            if (din_strb) dout <= acc[NTAPS-1];",
        "            dout_strb <= din_strb;",
        "        end",
        "    end",
        "endmodule",
        "",
        "/* verilator lint_on DECLFILENAME */",
        "`default_nettype wire",
        "",
    ]
    return "\n".join(lines)


# --------------------------------------------------------------------------
# IIR
# --------------------------------------------------------------------------

def iir_source(res, fixed, opts: SvOptions) -> str:
    """RTL for the biquad cascade, each section in transposed direct form II."""
    name = sanitise_name(opts.name)
    headroom, wcoef, frac = _check(opts, fixed)
    live = [0, 1, 2, 4, 5]                       # b0 b1 b2 a1 a2; a0 is 1
    sections = [[int(row[i]) for i in live] for row in fixed.ints]
    nsec = len(sections)
    if nsec < 1:
        raise SvError("no sections to build")

    labels = []
    for s in range(nsec):
        labels += [f"section {s} b0", f"section {s} b1", f"section {s} b2",
                   f"section {s} a1", f"section {s} a2"]

    lines = _preamble(
        f"{name}: {res.approximation} {res.response} IIR, order {res.order}",
        [f"sample rate {res.fs:g}, "
         f"{res.rp:g} dB passband ripple, {res.rs:g} dB stopband attenuation",
         f"max |pole| = {res.max_pole_radius:.6f}"
         f"{'' if res.stable else '   *** UNSTABLE ***'}",
         f"Cascade of {nsec} biquad{'s' if nsec != 1 else ''}, each transposed",
         "direct form II:",
         "    y  = b0*x + s1",
         "    s1 = b1*x - a1*y + s2",
         "    s2 = b2*x - a2*y",
         "a0 is 1 for every section, so nothing multiplies by it; a1 and a2 are",
         "given as designed and negated inside the multiplier."],
        wcoef, frac, headroom, opts.fixed_coeffs, labels)
    lines += _library(name)

    ports = ["    input  wire                     clk,",
             "    input  wire                     resetn,",
             "    input  wire signed [WDATA-1:0]  din,",
             "    input  wire                     din_strb,"]
    if not opts.fixed_coeffs:
        ports.append("    input  wire signed [NSEC*5*WCOEF-1:0] coeff,")
    ports += ["    output logic signed [WDATA-1:0] dout,",
              "    output logic                    dout_strb"]

    flat = [v for section in sections for v in section]
    lines += [
        "// ---------------------------------------------------------------------",
        f"// {name}: the filter itself.",
        "// ---------------------------------------------------------------------",
        f"module {name} #(",
        "    // These describe the filter that was generated: the coefficients",
        "    // below are stored in this format, so overriding them would leave",
        "    // the two disagreeing.  They live here, rather than in the body, so",
        "    // that the port declarations can use them.",
        f"    parameter int NSEC     = {nsec},",
        f"    parameter int WCOEF    = {wcoef},",
        f"    parameter int FRAC     = {frac},",
        f"    parameter int HEADROOM = {headroom},",
        "    parameter int WDATA    = WCOEF + HEADROOM",
        ") (",
        *ports,
        ");",
        "    // Five stored integers per section, in the order b0 b1 b2 a1 a2.",
        "    localparam longint COEF [0:NSEC*5-1] = '{",
    ]
    lines += _wrap_values(flat, indent=8, group=5)
    lines += [
        "    };",
        "",
        "    // chain[0] is the input; chain[s+1] is the output of section s.",
        "    wire signed [WDATA-1:0] chain [0:NSEC];",
        "    assign chain[0] = din;",
        "",
        "    generate",
        "        for (genvar s = 0; s < NSEC; s++) begin : g_sec",
        "            wire signed [WDATA-1:0] x = chain[s];",
        "            wire signed [WDATA-1:0] y;",
        "            wire signed [WDATA-1:0] s1, s2;          // delay outputs",
        "            wire signed [WDATA-1:0] pb0, pb1, pb2, pa1, pa2;",
        "            wire signed [WDATA-1:0] u1, s1_next, s2_next;",
        "",
        "            // The five multipliers.  a1 and a2 get NEG, which turns",
        "            // their adds into the subtractions the recursion wants.",
    ]
    slots = [("pb0", "0", "1'b0"), ("pb1", "1", "1'b0"), ("pb2", "2", "1'b0"),
             ("pa1", "3", "1'b1"), ("pa2", "4", "1'b1")]
    for target, slot, neg in slots:
        source = "x" if target.startswith("pb") else "y"
        lines += [
            f"            {name}_mul #(",
            "                .WDATA(WDATA), .WCOEF(WCOEF), .FRAC(FRAC),",
            f"                .FIXED(1'b{int(opts.fixed_coeffs)}), .NEG({neg}),",
            f"                .COEF(COEF[s*5 + {slot}])",
            f"            ) u_mul_{target} (",
            "                .coef(" + ("'0" if opts.fixed_coeffs else
                                        f"coeff[(s*5 + {slot})*WCOEF +: WCOEF]")
            + "),",
            f"                .din({source}), .dout({target}));",
            "",
        ]
    lines += [
        "            // y = b0*x + s1",
        f"            {name}_add #(.WDATA(WDATA)) u_add_y (",
        "                .a(pb0), .b(s1), .sum(y));",
        "",
        "            // s1 <- b1*x - a1*y + s2",
        f"            {name}_add #(.WDATA(WDATA)) u_add_u1 (",
        "                .a(pb1), .b(pa1), .sum(u1));",
        f"            {name}_add #(.WDATA(WDATA)) u_add_s1 (",
        "                .a(u1), .b(s2), .sum(s1_next));",
        "",
        "            // s2 <- b2*x - a2*y",
        f"            {name}_add #(.WDATA(WDATA)) u_add_s2 (",
        "                .a(pb2), .b(pa2), .sum(s2_next));",
        "",
        f"            {name}_delay #(.WDATA(WDATA)) u_z1 (",
        "                .clk(clk), .resetn(resetn), .en(din_strb),",
        "                .d(s1_next), .q(s1));",
        f"            {name}_delay #(.WDATA(WDATA)) u_z2 (",
        "                .clk(clk), .resetn(resetn), .en(din_strb),",
        "                .d(s2_next), .q(s2));",
        "",
        "            assign chain[s+1] = y;",
        "        end",
        "    endgenerate",
        "",
        "    always_ff @(posedge clk) begin",
        "        if (!resetn) begin",
        "            dout      <= '0;",
        "            dout_strb <= 1'b0;",
        "        end else begin",
        "            if (din_strb) dout <= chain[NSEC];",
        "            dout_strb <= din_strb;",
        "        end",
        "    end",
        "endmodule",
        "",
        "/* verilator lint_on DECLFILENAME */",
        "`default_nettype wire",
        "",
    ]
    return "\n".join(lines)


def source_for(kind: str, res, fixed, opts: SvOptions) -> str:
    if kind == "iir":
        return iir_source(res, fixed, opts)
    return fir_source(res, fixed, opts)


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------

def _check(opts: SvOptions, fixed):
    """Validate the format, and return (headroom, wcoef, frac)."""
    if fixed is None:
        raise SvError(
            "RTL needs fixed-point coefficients: choose Fixed point in the "
            "Arithmetic panel first")
    headroom = int(opts.headroom)
    if not 0 <= headroom <= 64:
        raise SvError(f"headroom must be 0..64 bits, got {headroom}")
    if fixed.frac_bits < 0:
        raise SvError(
            f"the binary point is {-fixed.frac_bits} places into the integer "
            "part, which no shift can undo; give the coefficients more bits")
    if fixed.saturated:
        raise SvError(
            f"{fixed.saturated} coefficient(s) saturated when quantized, so "
            "the RTL would not be the filter that was designed; move the "
            "binary point right")
    return headroom, fixed.bits, fixed.frac_bits


def _wrap_values(values, indent=8, group=8):
    """Lay integers out a few per line, comma separated, for a '{...} literal."""
    pad = " " * indent
    out = []
    for start in range(0, len(values), group):
        chunk = values[start:start + group]
        text = ", ".join(f"{v}" for v in chunk)
        if start + group < len(values):
            text += ","
        out.append(pad + text)
    return out
