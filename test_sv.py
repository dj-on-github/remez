"""Checks for the SystemVerilog output.

The generated RTL is linted, then compiled and run against the bit-exact model
in :mod:`sv_export`, so the two independent descriptions of the same datapath
have to agree sample for sample.  Everything needing a toolchain skips itself
when Verilator is not installed.
"""

import shutil
import subprocess

import numpy as np
import pytest

import fir_core as rz
import fixed_point as fp
import iir_core as ii
import sv_export as sv

VERILATOR = shutil.which("verilator")
needs_verilator = pytest.mark.skipif(VERILATOR is None,
                                     reason="verilator is not installed")

STIM = [4096, -4096, 2048, 0, 1024, -3000, 3000, 100, -100, 4095, -4096, 0,
        512, -512, 2000, 1500, -2500, 700]


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------

def fir_design(numtaps=15, bits=12):
    res = rz.design(numtaps, [rz.Band(0, .2, 1.), rz.Band(.3, .5, 0., w1=10.)])
    return res, fp.quantize(res.h, bits)


def iir_design(bits=16):
    res = ii.design("lowpass", "elliptic", wp=0.2, ws=0.3, rp=0.5, rs=40, fs=1.0)
    return res, fp.quantize_sos(res.sos, bits)


def pack(values, width):
    """Pack signed integers so that slice k sits at [k*width +: width]."""
    mask = (1 << width) - 1
    out = 0
    for k, v in enumerate(values):
        out |= (int(v) & mask) << (k * width)
    return out


def lint(tmp_path, source, name="dut.sv"):
    path = tmp_path / name
    path.write_text(source)
    done = subprocess.run([VERILATOR, "--lint-only", "-Wall", str(path)],
                          capture_output=True, text=True)
    return done, path


def run_rtl(tmp_path, source, top, stim, wcoef, headroom, coeffs=None):
    """Compile the design with a generated testbench and return its outputs.

    ``coeffs`` is the flat coefficient list when the design expects them on a
    port, and None when they are built in.
    """
    wdata = wcoef + headroom
    design = tmp_path / f"{top}.sv"
    design.write_text(source)

    stim_literal = ", ".join(str(int(v)) for v in stim)
    if coeffs is None:
        coeff_decl, coeff_port = [], ""
    else:
        nbits = len(coeffs) * wcoef
        coeff_decl = [f"    localparam logic signed [{nbits - 1}:0] COEFF = "
                      f"{nbits}'h{pack(coeffs, wcoef):x};"]
        coeff_port = "              .coeff(COEFF),\n"

    tb = "\n".join([
        "module tb;",
        f"    localparam int WDATA = {wdata};",
        f"    localparam int NS = {len(stim)};",
        f"    localparam longint STIM [0:NS-1] = '{{{stim_literal}}};",
        *coeff_decl,
        "",
        "    logic clk = 0, resetn = 0, din_strb = 0;",
        "    logic signed [WDATA-1:0] din = '0;",
        "    logic signed [WDATA-1:0] dout;",
        "    logic dout_strb;",
        "",
        f"    {top} dut (.clk(clk), .resetn(resetn), .din(din),",
        f"              .din_strb(din_strb),\n{coeff_port}"
        "              .dout(dout), .dout_strb(dout_strb));",
        "",
        "    always #5 clk = ~clk;",
        "",
        "    initial begin",
        "        repeat (3) @(posedge clk);",
        "        resetn = 1'b1;",
        "        @(posedge clk);",
        "        for (int i = 0; i < NS; i++) begin",
        "            din      = WDATA'(STIM[i]);",
        "            din_strb = 1'b1;",
        "            @(posedge clk);",
        "            din_strb = 1'b0;",
        # An idle gap between samples: the delay line must not advance.
        "            repeat (2) @(posedge clk);",
        "        end",
        "        repeat (4) @(posedge clk);",
        "        $finish;",
        "    end",
        "",
        "    always @(posedge clk)",
        "        if (resetn && dout_strb) $display(\"OUT %0d\", dout);",
        "endmodule",
        "",
    ])
    (tmp_path / "tb.sv").write_text(tb)

    build = subprocess.run(
        [VERILATOR, "--binary", "--timing", "-o", "sim", "--Mdir",
         str(tmp_path / "obj"), str(design), str(tmp_path / "tb.sv")],
        capture_output=True, text=True, cwd=tmp_path)
    assert build.returncode == 0, build.stdout + build.stderr

    run = subprocess.run([str(tmp_path / "obj" / "sim")],
                         capture_output=True, text=True, cwd=tmp_path)
    assert run.returncode == 0, run.stdout + run.stderr
    return [int(line.split()[1]) for line in run.stdout.splitlines()
            if line.startswith("OUT ")]


# --------------------------------------------------------------------------
# generation
# --------------------------------------------------------------------------

def test_the_source_holds_the_four_modules():
    res, q = fir_design()
    src = sv.fir_source(res, q, sv.SvOptions(name="lp", headroom=2))
    for module in ("module lp_mul", "module lp_add", "module lp_delay",
                   "module lp_sat", "module lp #("):
        assert module in src, module
    assert src.count("endmodule") == 5


def test_the_interface_is_the_one_asked_for():
    res, q = fir_design()
    src = sv.fir_source(res, q, sv.SvOptions(name="lp", headroom=4))
    for port in ("input  wire                     clk,",
                 "input  wire                     resetn,",
                 "input  wire signed [WDATA-1:0]  din,",
                 "input  wire                     din_strb,",
                 "output logic signed [WDATA-1:0] dout,",
                 "output logic                    dout_strb"):
        assert port in src, port
    assert "parameter int WDATA    = WCOEF + HEADROOM" in src
    assert "parameter int HEADROOM = 4," in src


def test_headroom_widens_the_datapath():
    res, q = fir_design(bits=12)
    for headroom in (0, 3, 8):
        src = sv.fir_source(res, q, sv.SvOptions(name="lp", headroom=headroom))
        assert f"parameter int HEADROOM = {headroom}," in src
        assert f"Datapath      {12 + headroom} bits" in src


def test_fixed_coefficients_are_parameters_and_have_no_port():
    res, q = fir_design()
    src = sv.fir_source(res, q, sv.SvOptions(name="lp", fixed_coeffs=True))
    assert "coeff," not in src                  # no such port
    assert ".coef('0)" in src                   # the port is tied off instead
    assert ".FIXED(1'b1)" in src
    assert ".COEF(COEF[k])" in src
    # every tap is present as a literal
    for value in q.ints:
        assert str(int(value)) in src


def test_runtime_coefficients_add_an_input_vector():
    res, q = fir_design()
    src = sv.fir_source(res, q, sv.SvOptions(name="lp", fixed_coeffs=False))
    assert "input  wire signed [NTAPS*WCOEF-1:0] coeff," in src
    assert ".FIXED(1'b0)" in src
    assert ".coef(coeff[k*WCOEF +: WCOEF])" in src
    assert "h[0]" in src and f"h[{len(q.ints) - 1}]" in src   # the slice map


def test_the_iir_source_wires_one_biquad_per_section():
    res, q = iir_design()
    src = sv.iir_source(res, q, sv.SvOptions(name="ell"))
    assert f"parameter int NSEC     = {len(res.sos)}," in src
    assert src.count("u_mul_pb0") == 1        # inside one generate block
    for u in ("u_mul_pb0", "u_mul_pb1", "u_mul_pb2", "u_mul_pa1", "u_mul_pa2",
              "u_add_y", "u_add_u1", "u_add_s1", "u_add_s2", "u_z1", "u_z2"):
        assert u in src, u
    # the feedback pair is negated in the multiplier, not by a subtractor
    assert ".NEG(1'b1)" in src
    assert "u_sub" not in src


def test_a_name_becomes_a_legal_identifier():
    assert sv.sanitise_name("Low pass 41!") == "low_pass_41"
    assert sv.sanitise_name("41taps").startswith("filt_")
    assert sv.sanitise_name("") == "filt"
    res, q = fir_design()
    src = sv.fir_source(res, q, sv.SvOptions(name="my filter.sv"))
    assert "module my_filter_sv #(" in src


def test_floating_point_cannot_be_turned_into_rtl():
    res, _ = fir_design()
    with pytest.raises(sv.SvError, match="Fixed point"):
        sv.fir_source(res, None, sv.SvOptions())


def test_saturated_coefficients_are_refused():
    res, _ = fir_design()
    bad = fp.quantize(res.h, 8, frac_bits=12)      # forces clipping
    assert bad.saturated
    with pytest.raises(sv.SvError, match="saturated"):
        sv.fir_source(res, bad, sv.SvOptions())


def test_absurd_headroom_is_refused():
    res, q = fir_design()
    with pytest.raises(sv.SvError, match="headroom"):
        sv.fir_source(res, q, sv.SvOptions(headroom=-1))


# --------------------------------------------------------------------------
# the model
# --------------------------------------------------------------------------

def test_the_model_tracks_the_floating_point_filter():
    """The integer datapath should do what the design says, to within rounding."""
    res, q = fir_design(numtaps=21, bits=16)
    headroom, frac = 4, q.frac_bits
    rng = np.random.default_rng(0)
    x = rng.uniform(-0.5, 0.5, 300)
    xi = [int(round(v * (1 << frac))) for v in x]

    got = np.array(sv.simulate("fir", q.ints, xi, frac, q.bits, headroom),
                   dtype=float) / (1 << frac)
    want = np.convolve(x, q.values)[:len(x)]
    assert np.max(np.abs(got - want)) < 20.0 / (1 << frac)


def test_the_model_saturates_instead_of_wrapping():
    res, q = fir_design(bits=12)
    # No headroom at all, and a full-scale input: the sum has to clip.
    hi = (1 << (q.bits - 1)) - 1
    out = sv.simulate("fir", q.ints, [hi] * 40, q.frac_bits, q.bits, 0)
    assert max(out) == hi                       # clipped, not wrapped negative
    assert min(out) >= -(1 << (q.bits - 1))


def test_headroom_is_what_stops_the_clipping():
    res, q = fir_design(bits=12)
    hi = (1 << (q.bits - 1)) - 1
    clipped = sv.simulate("fir", q.ints, [hi] * 40, q.frac_bits, q.bits, 0)
    roomy = sv.simulate("fir", q.ints, [hi] * 40, q.frac_bits, q.bits, 4)
    assert max(clipped) == hi
    assert max(roomy) > hi                      # the true sum, now representable


def test_the_iir_model_tracks_its_floating_point_filter():
    res, q = iir_design(bits=18)
    frac, headroom = q.frac_bits, 4
    rng = np.random.default_rng(1)
    x = rng.uniform(-0.25, 0.25, 400)
    xi = [int(round(v * (1 << frac))) for v in x]
    live = [0, 1, 2, 4, 5]
    sections = [[int(row[i]) for i in live] for row in q.ints]

    got = np.array(sv.simulate("iir", sections, xi, frac, q.bits, headroom),
                   dtype=float) / (1 << frac)
    want = ii.sos_filter(q.values, x)
    assert np.max(np.abs(got - want)) < 1e-3


# --------------------------------------------------------------------------
# lint
# --------------------------------------------------------------------------

@needs_verilator
@pytest.mark.parametrize("fixed_coeffs", [True, False])
@pytest.mark.parametrize("kind", ["fir", "iir"])
def test_the_rtl_lints_without_a_warning(tmp_path, kind, fixed_coeffs):
    if kind == "fir":
        res, q = fir_design()
        src = sv.fir_source(res, q, sv.SvOptions(name="dut", headroom=3,
                                                fixed_coeffs=fixed_coeffs))
    else:
        res, q = iir_design()
        src = sv.iir_source(res, q, sv.SvOptions(name="dut", headroom=3,
                                                fixed_coeffs=fixed_coeffs))
    done, _ = lint(tmp_path, src)
    assert done.returncode == 0, done.stdout + done.stderr


# --------------------------------------------------------------------------
# simulation
# --------------------------------------------------------------------------

@needs_verilator
def test_the_fir_rtl_matches_the_model_bit_for_bit(tmp_path):
    res, q = fir_design(numtaps=15, bits=12)
    headroom = 3
    src = sv.fir_source(res, q, sv.SvOptions(name="dut", headroom=headroom))
    got = run_rtl(tmp_path, src, "dut", STIM, q.bits, headroom)
    want = sv.simulate("fir", q.ints, STIM, q.frac_bits, q.bits, headroom)
    assert got == want
    assert len(got) == len(STIM)


@needs_verilator
def test_the_iir_rtl_matches_the_model_bit_for_bit(tmp_path):
    res, q = iir_design(bits=16)
    headroom = 4
    src = sv.iir_source(res, q, sv.SvOptions(name="dut", headroom=headroom))
    got = run_rtl(tmp_path, src, "dut", STIM, q.bits, headroom)
    live = [0, 1, 2, 4, 5]
    sections = [[int(row[i]) for i in live] for row in q.ints]
    want = sv.simulate("iir", sections, STIM, q.frac_bits, q.bits, headroom)
    assert got == want


@needs_verilator
def test_runtime_coefficients_give_the_same_answer_as_built_in_ones(tmp_path):
    res, q = fir_design(numtaps=15, bits=12)
    headroom = 3
    src = sv.fir_source(res, q, sv.SvOptions(name="dut", headroom=headroom,
                                             fixed_coeffs=False))
    got = run_rtl(tmp_path, src, "dut", STIM, q.bits, headroom,
                  coeffs=[int(v) for v in q.ints])
    want = sv.simulate("fir", q.ints, STIM, q.frac_bits, q.bits, headroom)
    assert got == want


@needs_verilator
def test_runtime_iir_coefficients_take_the_designed_signs(tmp_path):
    """a1 and a2 go in as designed; the RTL negates them, not the caller."""
    res, q = iir_design(bits=16)
    headroom = 4
    live = [0, 1, 2, 4, 5]
    sections = [[int(row[i]) for i in live] for row in q.ints]
    src = sv.iir_source(res, q, sv.SvOptions(name="dut", headroom=headroom,
                                             fixed_coeffs=False))
    got = run_rtl(tmp_path, src, "dut", STIM, q.bits, headroom,
                  coeffs=[v for section in sections for v in section])
    want = sv.simulate("iir", sections, STIM, q.frac_bits, q.bits, headroom)
    assert got == want


@needs_verilator
def test_the_rtl_is_an_impulse_response_away_from_the_design(tmp_path):
    """Push an impulse through the RTL and get the quantized taps back."""
    res, q = fir_design(numtaps=15, bits=14)
    headroom, frac = 3, q.frac_bits
    src = sv.fir_source(res, q, sv.SvOptions(name="dut", headroom=headroom))
    impulse = [1 << frac] + [0] * (len(q.ints) + 2)
    got = run_rtl(tmp_path, src, "dut", impulse, q.bits, headroom)
    # h[k] * 1.0, rounded through the datapath, is h[k] again.
    assert got[:len(q.ints)] == [int(v) for v in q.ints]
    assert all(v == 0 for v in got[len(q.ints):])
