"""SystemVerilog generation for a designed filter.

The structure the design view draws -- multipliers, adders and unit delays --
written out as synthesisable RTL, plus a self-checking testbench for it.  The
arithmetic is defined once in :mod:`datapath`, the hardware is planned once in
:mod:`rtl_common`, and this file only renders it.

    <name>_mul     one coefficient multiply, rounded and saturated back to the
                   datapath format
    <name>_add     one datapath-width add or subtract, saturating
    <name>_sat     clamps a wide signed value into a narrow one
    <name>_delay   one register: the filter's unit delay, and the pipeline
                   register between adder-tree levels
    <name>         the filter
    <name>_tb      a testbench that checks it against known-good vectors

Numbers
-------
Coefficients are ``WCOEF`` bits with ``FRAC`` fractional bits, exactly as the
Arithmetic panel quantized them.  The datapath carries the same ``FRAC``
fractional bits and ``HEADROOM`` extra integer bits, so every signal is
``WDATA = WCOEF + HEADROOM`` bits and unity is ``1 << FRAC``.  Products are
exact, then rounded to nearest and saturated; adds saturate.

Timing
------
Synchronous, one sample per ``din_strb``, active-low synchronous reset.  The
result appears on ``dout`` with ``dout_strb`` high for one cycle, ``LATENCY``
clocks after the strobe: one clock for the chain, one per tree level plus one
for the tree, and one per term plus two for the MAC.  The MAC form needs strobes
at least ``LATENCY`` clocks apart and ignores any that arrive while it is busy.
"""

from __future__ import annotations

import numpy as np

from datapath import simulate                      # noqa: F401  (re-exported)
from rtl_common import (RtlError, RtlOptions, RtlPlan, plan_for,  # noqa: F401
                        sanitise_name)

__all__ = ["SvError", "SvOptions", "RtlOptions", "fir_source", "iir_source",
           "source_for", "testbench_for", "simulate", "sanitise_name",
           "plan_for"]

# The names this module went by before it grew a second back-end.
SvError = RtlError
SvOptions = RtlOptions


# --------------------------------------------------------------------------
# the reusable modules
# --------------------------------------------------------------------------

def _library(name: str, folded: bool = False) -> list:
    """The reusable modules.  The widening pre-adder is only for folding, and an
    unused module would be a second candidate top for the tools."""
    out = [
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
        "    parameter int     WIN   = WDATA,   // wider for a folded pre-add",
        "    parameter int     WCOEF = 12,",
        "    parameter int     FRAC  = 11,",
        "    parameter bit     FIXED = 1'b1,",
        "    parameter bit     NEG   = 1'b0,",
        "    parameter longint COEF  = 0",
        ") (",
        "    input  logic signed [WCOEF-1:0] coef,",
        "    input  logic signed [WIN-1:0]   din,",
        "    output logic signed [WDATA-1:0] dout",
        ");",
        "    localparam int WPROD = WIN + WCOEF;",
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
        "// that clips is bad, one that wraps is unrecognisable.  SUB subtracts,",
        "// which is what the pre-adders of a folded antisymmetric filter do.",
        "// ---------------------------------------------------------------------",
        f"module {name}_add #(",
        "    parameter int WDATA = 16,",
        "    parameter bit SUB   = 1'b0",
        ") (",
        "    input  logic signed [WDATA-1:0] a,",
        "    input  logic signed [WDATA-1:0] b,",
        "    output logic signed [WDATA-1:0] sum",
        ");",
        "    logic signed [WDATA:0] full;",
        "    always_comb full = SUB ? ($signed(a) - $signed(b))",
        "                           : ($signed(a) + $signed(b));",
        f"    {name}_sat #(.WIN(WDATA+1), .WOUT(WDATA)) u_sat (.din(full), .dout(sum));",
        "endmodule",
        "",
        "",
        *(_preadder(name) if folded else []),
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
        "// One register.  It advances only when enabled, which makes it both the",
        "// unit delay of the filter (enabled once per input sample) and the",
        "// pipeline register between adder-tree levels.",
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
    return out


def _preadder(name: str) -> list:
    return [
        "// ---------------------------------------------------------------------",
        "// A widening add for the pre-adders of a folded filter.  It sums two",
        "// samples that may each be at full scale, so the result is one bit wider",
        "// and nothing is clipped: saturating here would throw away signal rather",
        "// than round it.  SUB subtracts, as an antisymmetric filter needs.",
        "// ---------------------------------------------------------------------",
        f"module {name}_addw #(",
        "    parameter int WDATA = 16,",
        "    parameter bit SUB   = 1'b0",
        ") (",
        "    input  logic signed [WDATA-1:0] a,",
        "    input  logic signed [WDATA-1:0] b,",
        "    output logic signed [WDATA:0]   sum",
        ");",
        "    always_comb sum = SUB ? ($signed(a) - $signed(b))",
        "                          : ($signed(a) + $signed(b));",
        "endmodule",
        "",
        "",
    ]


def _preamble(plan: RtlPlan) -> list:
    int_bits = plan.wcoef - 1 - plan.frac
    lo, hi = plan.limits
    res = plan.resources
    out = ["// " + "=" * 69, f"// {plan.title}", "//"]
    out += [f"// {line}" for line in plan.detail]
    out += [
        "//",
        f"// Coefficients  {plan.wcoef} bits, Q{int_bits}.{plan.frac}"
        f"   (value = integer * 2^-{plan.frac})",
        f"// Datapath      {plan.wdata} bits = {plan.wcoef} + {plan.headroom} "
        f"headroom, Q{int_bits + plan.headroom}.{plan.frac}",
        f"//               unity is {1 << plan.frac}, "
        f"range [{lo / (1 << plan.frac):g}, {hi / (1 << plan.frac):g}]",
        "// Products are exact, then rounded to nearest and saturated; adds",
        "// saturate.  Headroom is what keeps the adders off their limits.",
        "//",
        f"// Costs         {res['multipliers']} multiplier"
        f"{'s' if res['multipliers'] != 1 else ''}, "
        f"{res['adders']} adder{'s' if res['adders'] != 1 else ''}, "
        f"{res['delays']} delay{'s' if res['delays'] != 1 else ''}"
        + (f", {res['pipeline']} pipeline levels" if res.get("pipeline") else ""),
        "//",
        "// clk / resetn        synchronous, active-low reset",
        "// din, din_strb       one sample per strobe",
        f"// dout, dout_strb     the result, {plan.latency} clock"
        f"{'s' if plan.latency != 1 else ''} after din_strb",
    ]
    if plan.structure == "mac":
        out += ["//                     strobes must be at least LATENCY clocks",
                "//                     apart; any arriving while busy are ignored"]
    out.append("//")
    if plan.fixed_coeffs:
        out += ["// Coefficients are elaboration-time parameters, so synthesis can",
                "// specialise each multiplier.  There is no coefficient port.",
                "//"]
    else:
        out += ["// Coefficients arrive on the packed 'coeff' port and may change",
                "// while the filter runs.  Slice k is coeff[k*WCOEF +: WCOEF]:",
                "//"]
        out += [f"//   [{i:3d}] {label}" for i, label in enumerate(plan.coeff_labels)]
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


def _needs_coeff_table(plan: RtlPlan) -> bool:
    """The MAC reads the table as data, so with a coefficient port it has none."""
    return plan.fixed_coeffs or plan.structure != "mac"


def _coeff_table(plan: RtlPlan, indent=4) -> list:
    if not _needs_coeff_table(plan):
        return []
    pad = " " * indent
    group = 5 if plan.kind == "iir" else 8
    what = ("Five stored integers per section, in the order b0 b1 b2 a1 a2."
            if plan.kind == "iir" else
            ("One per multiply: the coefficient a folded pair shares."
             if plan.folded else "The impulse response, as stored integers."))
    # A shared multiplier reads the table at the coefficient width, as data; the
    # other structures pass its entries as parameters, which want longint.
    declare = ("logic signed [WCOEF-1:0]" if plan.structure == "mac"
               else "longint")
    out = [pad + f"// {what}",
           pad + f"localparam {declare} COEF [0:NCOEF-1] = '{{"]
    for start in range(0, len(plan.coeffs), group):
        chunk = plan.coeffs[start:start + group]
        text = ", ".join(str(int(v)) for v in chunk)
        if start + group < len(plan.coeffs):
            text += ","
        out.append(pad + "    " + text)
    out.append(pad + "};")
    return out


def _params(plan: RtlPlan) -> list:
    out = ["    // These describe the filter that was generated: the coefficients",
           "    // below are stored in this format, so overriding them would leave",
           "    // the two disagreeing.  They live here, rather than in the body, so",
           "    // that the port declarations can use them.  LATENCY is here to be",
           "    // read by whatever instantiates this, and is not used inside every",
           "    // structure, hence the pragma.",
           "    /* verilator lint_off UNUSEDPARAM */"]
    if plan.kind == "iir":
        out.append(f"    parameter int NSEC     = {plan.nsec},")
    else:
        out.append(f"    parameter int NTAPS    = {plan.numtaps},")
        out.append(f"    parameter int NTERM    = {plan.nterms},")
    out += [f"    parameter int NCOEF    = {len(plan.coeffs)},",
            f"    parameter int WCOEF    = {plan.wcoef},",
            f"    parameter int FRAC     = {plan.frac},",
            f"    parameter int HEADROOM = {plan.headroom},",
            f"    parameter int LATENCY  = {plan.latency},",
            "    parameter int WDATA    = WCOEF + HEADROOM",
            "    /* verilator lint_on UNUSEDPARAM */"]
    return out


def _ports(plan: RtlPlan) -> list:
    out = ["    input  wire                     clk,",
           "    input  wire                     resetn,",
           "    input  wire signed [WDATA-1:0]  din,",
           "    input  wire                     din_strb,"]
    if not plan.fixed_coeffs:
        out.append("    input  wire signed [NCOEF*WCOEF-1:0] coeff,")
    out += ["    output logic signed [WDATA-1:0] dout,",
            "    output logic                    dout_strb"]
    return out


def _coef_port(plan: RtlPlan, index: str) -> str:
    return "'0" if plan.fixed_coeffs else f"coeff[({index})*WCOEF +: WCOEF]"


def _mul_inst(plan, name, label, index, din, dout, neg="1'b0", indent=12,
              win=None):
    pad = " " * indent
    width = ".WDATA(WDATA)" if win is None else f".WDATA(WDATA), .WIN({win})"
    return [
        pad + f"{name}_mul #(",
        pad + f"    {width}, .WCOEF(WCOEF), .FRAC(FRAC),",
        pad + f"    .FIXED(1'b{int(plan.fixed_coeffs)}), .NEG({neg}),",
        pad + f"    .COEF(COEF[{index}])",
        pad + f") {label} (",
        pad + f"    .coef({_coef_port(plan, index)}),",
        pad + f"    .din({din}), .dout({dout}));",
    ]


# --------------------------------------------------------------------------
# FIR
# --------------------------------------------------------------------------

def _fir_products(plan: RtlPlan, name: str) -> list:
    """The delay line, the pre-adders if folded, and the multipliers."""
    out = [
        "    // x[0] is this cycle's sample; x[k] is it delayed by k strobes.",
        "    wire signed [WDATA-1:0] x    [0:NTAPS-1];",
        "    wire signed [WTERM-1:0] term [0:NTERM-1];",
        "    wire signed [WDATA-1:0] prod [0:NTERM-1];",
        "",
        "    assign x[0] = din;",
        "",
        "    generate",
        "        for (genvar k = 1; k < NTAPS; k++) begin : g_delay",
        f"            {name}_delay #(.WDATA(WDATA)) u_z (",
        "                .clk(clk), .resetn(resetn), .en(din_strb),",
        "                .d(x[k-1]), .q(x[k]));",
        "        end",
        "",
    ]
    if plan.folded:
        sub = f"1'b{int(plan.subtracts)}"
        word = "subtract" if plan.subtracts else "add"
        out += [
            f"        // Folded: one pre-{word} per symmetric pair, so one",
            "        // multiplier serves two taps.",
            "        for (genvar k = 0; k < NPAIR; k++) begin : g_pre",
            f"            {name}_addw #(.WDATA(WDATA), .SUB({sub})) u_pre (",
            "                .a(x[k]), .b(x[NTAPS-1-k]), .sum(term[k]));",
            "        end",
        ]
        if plan.has_centre:
            out += ["",
                    "        // The unpaired centre tap goes straight in, sign",
                    "        // extended to the width the pre-adders produce.",
                    "        assign term[NTERM-1] = WTERM'($signed(x[NTAPS/2]));"]
        out.append("")
    else:
        out += ["        for (genvar k = 0; k < NTERM; k++) begin : g_term",
                "            assign term[k] = x[k];",
                "        end",
                ""]
    out += ["        for (genvar k = 0; k < NTERM; k++) begin : g_mul"]
    out += _mul_inst(plan, name, "u_mul", "k", "term[k]", "prod[k]",
                     win="WTERM")
    out += ["        end", "    endgenerate", ""]
    return out


def _fir_chain(name: str) -> list:
    return [
        "    // Sum the products along a chain of adders, in tap order.",
        "    wire signed [WDATA-1:0] acc [0:NTERM-1];",
        "    assign acc[0] = prod[0];",
        "",
        "    generate",
        "        for (genvar k = 1; k < NTERM; k++) begin : g_sum",
        f"            {name}_add #(.WDATA(WDATA)) u_add (",
        "                .a(acc[k-1]), .b(prod[k]), .sum(acc[k]));",
        "        end",
        "    endgenerate",
        "",
        "    always_ff @(posedge clk) begin",
        "        if (!resetn) begin",
        "            dout      <= '0;",
        "            dout_strb <= 1'b0;",
        "        end else begin",
        "            if (din_strb) dout <= acc[NTERM-1];",
        "            dout_strb <= din_strb;",
        "        end",
        "    end",
    ]


def _fir_tree(name: str) -> list:
    """Balanced adder tree with a register between levels."""
    return [
        "    // Balanced adder tree: LEVELS deep instead of NTERM long, with a",
        "    // register between levels so the clock is not held back by the whole",
        "    // summation.  vld[L] is high in the cycle where level L holds this",
        "    // sample's data, and is what enables the level after it.",
        "    localparam int LEVELS = LATENCY - 1;",
        "",
        "    function automatic int level_count(input int lvl);",
        "        int n;",
        "        n = NTERM;",
        "        for (int i = 0; i < lvl; i++) n = (n + 1) / 2;",
        "        return n;",
        "    endfunction",
        "",
        "    logic [LEVELS-1:0] vld;",
        "    always_ff @(posedge clk) begin",
        "        if (!resetn) vld <= '0;",
        "        else         vld <= {vld[LEVELS-2:0], din_strb};",
        "    end",
        "",
        "    wire signed [WDATA-1:0] node [0:LEVELS][0:NTERM-1];",
        "",
        "    generate",
        "        for (genvar k = 0; k < NTERM; k++) begin : g_leaf",
        "            assign node[0][k] = prod[k];",
        "        end",
        "",
        "        for (genvar L = 0; L < LEVELS; L++) begin : g_level",
        "            for (genvar i = 0; i < level_count(L+1); i++) begin : g_node",
        "                wire signed [WDATA-1:0] partial;",
        "                if (2*i + 1 < level_count(L)) begin : g_add",
        f"                    {name}_add #(.WDATA(WDATA)) u_add (",
        "                        .a(node[L][2*i]), .b(node[L][2*i+1]),",
        "                        .sum(partial));",
        "                end else begin : g_pass",
        "                    // An odd one out waits a level rather than being",
        "                    // added to something that is not there.",
        "                    assign partial = node[L][2*i];",
        "                end",
        f"                {name}_delay #(.WDATA(WDATA)) u_reg (",
        "                    .clk(clk), .resetn(resetn),",
        "                    .en(L == 0 ? din_strb : vld[L-1]),",
        "                    .d(partial), .q(node[L+1][i]));",
        "            end",
        "        end",
        "    endgenerate",
        "",
        "    always_ff @(posedge clk) begin",
        "        if (!resetn) begin",
        "            dout      <= '0;",
        "            dout_strb <= 1'b0;",
        "        end else begin",
        "            if (vld[LEVELS-1]) dout <= node[LEVELS][0];",
        "            dout_strb <= vld[LEVELS-1];",
        "        end",
        "    end",
    ]


def _fir_mac(plan: RtlPlan, name: str) -> list:
    """One multiplier walked over the terms, one per clock."""
    pre = plan.folded
    out = [
        "    // One multiplier, reused.  The delay line is a register file with a",
        "    // write pointer rather than a shift chain, so any tap can be fetched",
        "    // by index; the accumulator then walks the terms one per clock.",
        "    // AW addresses the delay line, KW counts the terms; folding makes",
        "    // those two different sizes.",
        "    localparam int AW = (NTAPS > 1) ? $clog2(NTAPS) : 1;",
        "    localparam int KW = (NTERM > 1) ? $clog2(NTERM) : 1;",
        "",
        "    logic signed [WDATA-1:0] mem [0:NTAPS-1];",
        "    logic [AW-1:0]           wp, rp;",
    ]
    if pre:
        out.append("    logic [AW-1:0]           rp2;")
    out += [
        "    logic [KW-1:0]           k;",
        "    logic                    busy;",
        "    logic signed [WDATA-1:0] acc;",
        "",
        "    wire signed [WDATA-1:0] sample = mem[rp];",
    ]
    if pre:
        sub = f"1'b{int(plan.subtracts)}"
        out += [
            "    wire signed [WDATA-1:0] mirror = mem[rp2];",
            "    wire signed [WTERM-1:0] paired;",
            f"    {name}_addw #(.WDATA(WDATA), .SUB({sub})) u_pre (",
            "        .a(sample), .b(mirror), .sum(paired));",
        ]
        if plan.has_centre:
            out += ["",
                    "    // The centre tap of an odd-length symmetric filter has",
                    "    // no partner, so on that term the pre-adder is bypassed.",
                    "    wire signed [WTERM-1:0] term_in ="
                    " (k == KW'(NTERM-1)) ? WTERM'($signed(sample)) : paired;"]
        else:
            out.append("    wire signed [WTERM-1:0] term_in = paired;")
    else:
        out.append("    wire signed [WTERM-1:0] term_in = sample;")

    # There is one multiplier for every tap, so its coefficient is selected
    # while the filter runs and cannot be an elaboration-time constant.  With
    # fixed coefficients the table becomes a ROM read by the term counter --
    # which still saves the coefficient port, but cannot specialise the
    # multiplier the way a tap-per-multiplier structure can.
    out += ["",
            "    // One multiplier serves every tap, so the coefficient is looked",
            "    // up per term rather than built into a multiplier.",
            "    wire signed [WCOEF-1:0] coef_sel = "
            + ("COEF[k];" if plan.fixed_coeffs
               else "coeff[k*WCOEF +: WCOEF];"),
            "",
            "    wire signed [WDATA-1:0] prod;",
            f"    {name}_mul #(",
            "        .WDATA(WDATA), .WIN(WTERM), .WCOEF(WCOEF), .FRAC(FRAC),",
            "        .FIXED(1'b0), .NEG(1'b0)",
            "    ) u_mul (",
            "        .coef(coef_sel),",
            "        .din(term_in), .dout(prod));"]
    out += [
        "",
        "    wire signed [WDATA-1:0] acc_next;",
        f"    {name}_add #(.WDATA(WDATA)) u_acc (",
        "        .a(acc), .b(prod), .sum(acc_next));",
        "",
        "    always_ff @(posedge clk) begin",
        "        if (!resetn) begin",
        "            // The delay line is cleared, as the shift-register",
        "            // structures clear theirs: without it the first NTAPS",
        "            // outputs would depend on whatever the memory held.",
        "            for (int i = 0; i < NTAPS; i++) mem[i] <= '0;",
        "            wp        <= '0;",
        "            rp        <= '0;",
    ]
    if pre:
        out.append("            rp2       <= '0;")
    out += [
        "            k         <= '0;",
        "            busy      <= 1'b0;",
        "            acc       <= '0;",
        "            dout      <= '0;",
        "            dout_strb <= 1'b0;",
        "        end else begin",
        "            dout_strb <= 1'b0;",
        "",
        "            // A strobe arriving mid-sum would corrupt it, so it is",
        "            // ignored: keep them LATENCY clocks apart.",
        "            if (din_strb && !busy) begin",
        "                mem[wp] <= din;",
        "                rp      <= wp;",
    ]
    if pre:
        out.append("                rp2     <= (wp == AW'(NTAPS-1)) ? '0 "
                   ": wp + AW'(1);")
    out += [
        "                wp      <= (wp == AW'(NTAPS-1)) ? '0 : wp + AW'(1);",
        "                k       <= '0;",
        "                acc     <= '0;",
        "                busy    <= 1'b1;",
        "            end else if (busy) begin",
        "                acc <= acc_next;",
        "                if (k == KW'(NTERM-1)) begin",
        "                    busy      <= 1'b0;",
        "                    dout      <= acc_next;",
        "                    dout_strb <= 1'b1;",
        "                end else begin",
        "                    k   <= k + KW'(1);",
        "                    rp  <= (rp == '0) ? AW'(NTAPS-1) : rp - AW'(1);",
    ]
    if pre:
        out.append("                    rp2 <= (rp2 == AW'(NTAPS-1)) ? '0 "
                   ": rp2 + AW'(1);")
    out += [
        "                end",
        "            end",
        "        end",
        "    end",
    ]
    return out


def fir_source(res, fixed, opts: RtlOptions) -> str:
    """RTL for a FIR in the requested structure."""
    return _render_fir(plan_for("fir", res, fixed, opts))


def _render_fir(plan: RtlPlan) -> str:
    name = plan.name
    lines = _preamble(plan) + _library(name, plan.folded)
    lines += [
        "// ---------------------------------------------------------------------",
        f"// {name}: the filter itself.",
        "// ---------------------------------------------------------------------",
        f"module {name} #(",
        *_params(plan),
        ") (",
        *_ports(plan),
        ");",
    ]
    # A folded pre-adder is one bit wider than the datapath, because it sums
    # two samples that may each be at full scale.
    lines.append(f"    localparam int WTERM = WDATA + {1 if plan.folded else 0};")
    if plan.folded and plan.structure != "mac":
        # The shared-multiplier form walks terms rather than instantiating a
        # pre-adder per pair, so it has no use for the count.
        lines.append(f"    localparam int NPAIR = {plan.npairs};")
    lines += _coeff_table(plan)
    lines.append("")

    if plan.structure == "mac":
        lines += _fir_mac(plan, name)
    else:
        lines += _fir_products(plan, name)
        lines += (_fir_tree(name) if plan.structure == "tree"
                  else _fir_chain(name))

    lines += ["endmodule", "",
              "/* verilator lint_on DECLFILENAME */",
              "`default_nettype wire", ""]
    return "\n".join(lines)


# --------------------------------------------------------------------------
# IIR
# --------------------------------------------------------------------------

def iir_source(res, fixed, opts: RtlOptions) -> str:
    """RTL for the biquad cascade, each section in transposed direct form II."""
    return _render_iir(plan_for("iir", res, fixed, opts))


def _render_iir(plan: RtlPlan) -> str:
    name = plan.name
    lines = _preamble(plan) + _library(name, plan.folded)
    lines += [
        "// ---------------------------------------------------------------------",
        f"// {name}: the filter itself.",
        "// ---------------------------------------------------------------------",
        f"module {name} #(",
        *_params(plan),
        ") (",
        *_ports(plan),
        ");",
    ]
    lines += _coeff_table(plan)
    lines += [
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
    for target, slot, neg in (("pb0", 0, "1'b0"), ("pb1", 1, "1'b0"),
                              ("pb2", 2, "1'b0"), ("pa1", 3, "1'b1"),
                              ("pa2", 4, "1'b1")):
        source = "x" if target.startswith("pb") else "y"
        lines += _mul_inst(plan, name, f"u_mul_{target}", f"s*5 + {slot}",
                           source, target, neg=neg)
        lines.append("")
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


def source_for(kind: str, res, fixed, opts: RtlOptions) -> str:
    if kind == "iir":
        return iir_source(res, fixed, opts)
    return fir_source(res, fixed, opts)


# --------------------------------------------------------------------------
# self-checking testbench
# --------------------------------------------------------------------------

def stimulus(plan: RtlPlan, samples=None, seed=20240):
    """Test samples: full scale both ways, so the saturating adders get used."""
    if samples is not None:
        return [int(v) for v in samples]
    lo, hi = plan.limits
    unity = 1 << plan.frac
    rng = np.random.default_rng(seed)
    edge = [unity, -unity, hi, lo, 0, hi, lo, unity // 2, -unity // 2, 0]
    return [int(v) for v in edge + rng.integers(lo // 2, hi // 2, 40).tolist()]


def testbench_for(kind: str, res, fixed, opts: RtlOptions, *, samples=None,
                  seed=20240) -> str:
    """A testbench that drives known stimulus and checks the known answers.

    The expected values come from the model in :mod:`datapath`, so running this
    proves the RTL agrees with the same description of the arithmetic that the
    plots and the reports are drawn from.  It reports on every mismatch and
    stops on the first.
    """
    plan = plan_for(kind, res, fixed, opts)
    stim = stimulus(plan, samples, seed)
    expect = plan.simulate(stim)
    name = plan.name
    gap = plan.latency + 2

    lines = [
        "// " + "=" * 69,
        f"// {name}_tb: self-checking testbench for {name}.",
        "//",
        f"// {len(stim)} samples, full scale among them so that the saturating",
        "// adders are exercised, with the expected output of every one as",
        "// computed by the generator's model of this datapath.  Prints PASS and",
        f"// finishes; stops on the first mismatch.  Latency {plan.latency}, so",
        f"// the strobes here are {gap} clocks apart.",
        "//",
        f"// $ verilator --binary --timing --top-module {name}_tb \\",
        "//       -o sim <design>.sv <this file> && ./sim",
        "// " + "=" * 69,
        "",
        "`default_nettype none",
        "",
        f"module {name}_tb;",
        f"    localparam int WCOEF = {plan.wcoef};",
        f"    localparam int HEADROOM = {plan.headroom};",
        "    localparam int WDATA = WCOEF + HEADROOM;",
        f"    localparam int NS = {len(stim)};",
        f"    localparam int GAP = {gap};",
        "",
        "    localparam longint STIM   [0:NS-1] = '{",
    ]
    lines += _wrap(stim)
    lines += ["    };", "    localparam longint EXPECT [0:NS-1] = '{"]
    lines += _wrap(expect)
    lines += ["    };", ""]

    if not plan.fixed_coeffs:
        nbits = len(plan.coeffs) * plan.wcoef
        mask = (1 << plan.wcoef) - 1
        packed = 0
        for i, value in enumerate(plan.coeffs):
            packed |= (int(value) & mask) << (i * plan.wcoef)
        lines += ["    // The same coefficients the fixed build would compile in.",
                  f"    localparam logic signed [{nbits - 1}:0] COEFF = "
                  f"{nbits}'h{packed:x};", ""]

    lines += [
        "    logic clk, resetn, din_strb;",
        "    logic signed [WDATA-1:0] din;",
        "    logic signed [WDATA-1:0] dout;",
        "    logic dout_strb;",
        "    int   seen;",
        "",
        f"    {name} dut (",
        "        .clk(clk), .resetn(resetn), .din(din), .din_strb(din_strb),",
        *([] if plan.fixed_coeffs else ["        .coeff(COEFF),"]),
        "        .dout(dout), .dout_strb(dout_strb));",
        "",
        "    always #5 clk = ~clk;",
        "",
        "    initial begin",
        "        clk      = 1'b0;",
        "        resetn   = 1'b0;",
        "        din_strb = 1'b0;",
        "        din      = '0;",
        "        seen     = 0;",
        "        repeat (3) @(posedge clk);",
        "        resetn = 1'b1;",
        "        @(posedge clk);",
        "        for (int i = 0; i < NS; i++) begin",
        "            din      = WDATA'(STIM[i]);",
        "            din_strb = 1'b1;",
        "            @(posedge clk);",
        "            din_strb = 1'b0;",
        "            repeat (GAP - 1) @(posedge clk);",
        "        end",
        "        repeat (GAP + 4) @(posedge clk);",
        "        if (seen != NS) begin",
        '            $display("FAIL: %0d outputs, expected %0d", seen, NS);',
        '            $fatal(1, "wrong number of outputs");',
        "        end",
        '        $display("PASS: %0d samples matched", seen);',
        "        $finish;",
        "    end",
        "",
        "    always @(posedge clk) begin",
        "        if (resetn && dout_strb) begin",
        "            if (dout !== WDATA'(EXPECT[seen])) begin",
        '                $display("FAIL at %0d: got %0d, expected %0d",',
        "                         seen, dout, EXPECT[seen]);",
        '                $fatal(1, "mismatch");',
        "            end",
        "            seen <= seen + 1;",
        "        end",
        "    end",
        "endmodule",
        "",
        "`default_nettype wire",
        "",
    ]
    return "\n".join(lines)


def _wrap(values, indent=8, group=8):
    pad = " " * indent
    out = []
    for start in range(0, len(values), group):
        chunk = values[start:start + group]
        text = ", ".join(str(int(v)) for v in chunk)
        if start + group < len(values):
            text += ","
        out.append(pad + text)
    return out
