"""Checks for the VHDL output.

The VHDL and the SystemVerilog describe the same hardware, so most of what can
be checked without a simulator is that they agree: same coefficients, same
counts, same latency, same interface, same expected vectors.  A VHDL simulator
is not assumed to be present -- see the note in the README about what this does
and does not prove.
"""

import re
import shutil
import subprocess

import pytest

import datapath as dp
import fir_core as rz
import fixed_point as fp
import iir_core as ii
import rtl_common as rc
import sv_export as sv
import vhdl_export as vh

def _working_ghdl():
    """ghdl on PATH is not enough, so probe it before trusting it.

    A macOS build that is still quarantined hangs rather than running, and the
    first call after Gatekeeper has been talked round fails once before
    settling.  Both would otherwise skip every VHDL test in this file, and a
    skipped test reads like a passing one -- so probe twice before giving up.
    """
    path = shutil.which("ghdl")
    if path is None:
        return None
    for _ in range(2):
        try:
            done = subprocess.run([path, "--version"], capture_output=True,
                                  text=True, timeout=15)
        except (OSError, subprocess.TimeoutExpired):
            continue
        if done.returncode == 0 and done.stdout.strip():
            return path
    return None


GHDL = _working_ghdl()
needs_ghdl = pytest.mark.skipif(
    GHDL is None, reason="no working ghdl (not installed, or it will not start)")

STRUCTURES = list(dp.STRUCTURES)


def fir_design(numtaps=15, bits=12):
    res = rz.design(numtaps, [rz.Band(0, .2, 1.), rz.Band(.3, .5, 0., w1=10.)])
    return res, fp.quantize(res.h, bits)


def iir_design(bits=16):
    res = ii.design("lowpass", "elliptic", wp=0.2, ws=0.3, rp=0.5, rs=40, fs=1.0)
    return res, fp.quantize_sos(res.sos, bits)


def opts(**kw):
    kw.setdefault("name", "dut")
    kw.setdefault("headroom", 3)
    return vh.RtlOptions(**kw)


# --------------------------------------------------------------------- entities

def test_the_file_holds_every_entity():
    res, q = fir_design()
    src = vh.source_for("fir", res, q, opts(folded=True))
    for entity in ("dut_sat", "dut_mul", "dut_add", "dut_addw", "dut_delay",
                   "dut"):
        assert f"entity {entity} is" in src, entity
    assert src.count("end architecture rtl;") == 6


def test_the_interface_is_the_one_asked_for():
    res, q = fir_design()
    src = vh.source_for("fir", res, q, opts(headroom=4))
    for port in ("clk       : in  std_logic;",
                 "resetn    : in  std_logic;",
                 "din       : in  signed(WDATA-1 downto 0);",
                 "din_strb  : in  std_logic;",
                 "dout      : out signed(WDATA-1 downto 0);",
                 "dout_strb : out std_logic);"):
        assert port in src, port
    assert "HEADROOM : natural  := 4;" in src
    assert "WDATA    : positive := 16);" in src        # 12 + 4


def test_it_is_vhdl_93_and_uses_numeric_std():
    res, q = fir_design()
    src = vh.source_for("fir", res, q, opts(structure="tree", folded=True))
    # A context clause applies only to the design unit after it, so every
    # entity and architecture pair needs its own.
    assert src.count("use ieee.numeric_std.all;") >= 6
    # None of the constructs that would need a standard later than 93:
    # if/generate has no else or elsif branch before 2008, and a conditional
    # expression in a declaration is 2019.
    assert "else generate" not in src
    assert "elsif generate" not in src
    assert "case generate" not in src
    assert not re.search(r"constant\s+\w+\s*:[^;]*\bwhen\b", src)
    assert "?" not in src


@pytest.mark.parametrize("structure", STRUCTURES)
@pytest.mark.parametrize("folded", [False, True])
def test_every_structure_generates(structure, folded):
    res, q = fir_design()
    src = vh.source_for("fir", res, q,
                        opts(structure=structure, folded=folded))
    assert "architecture rtl of dut is" in src
    if structure == "tree":
        assert "function level_count" in src
        assert "function level_offset" in src
    if structure == "mac":
        assert "sequencer : process (clk)" in src
        assert "signal mem" in src
    if folded:
        assert "WTERM : positive := WDATA + 1" in src
        assert "dut_addw" in src


def test_a_wide_word_is_refused_with_a_reason():
    res, _ = fir_design()
    with pytest.raises(vh.VhdlError, match="integer generics"):
        vh.source_for("fir", res, fp.quantize(res.h, 32), opts())


def test_floating_point_is_refused():
    res, _ = fir_design()
    with pytest.raises(vh.VhdlError, match="Fixed point"):
        vh.source_for("fir", res, None, opts())


# --------------------------------------------- agreement with the SystemVerilog

@pytest.mark.parametrize("structure", STRUCTURES)
@pytest.mark.parametrize("folded", [False, True])
def test_both_languages_describe_the_same_hardware(structure, folded):
    res, q = fir_design()
    o = opts(structure=structure, folded=folded)
    plan = rc.plan_for("fir", res, q, o)
    a = vh.source_for("fir", res, q, o)
    b = sv.source_for("fir", res, q, o)

    for text in (a, b):
        assert str(plan.latency) in text
        assert str(plan.nterms) in text
        for value in plan.coeffs:
            assert str(int(value)) in text

    # The same resource counts, quoted in both headers.
    costs = f"{plan.resources['multipliers']} multiplier"
    assert costs in a and costs in b


def test_both_testbenches_expect_the_same_numbers():
    res, q = fir_design()
    for structure in STRUCTURES:
        for folded in (False, True):
            o = opts(structure=structure, folded=folded)
            a = vh.testbench_for("fir", res, q, o)
            b = sv.testbench_for("fir", res, q, o)
            assert _numbers(a, "EXPECT") == _numbers(b, "EXPECT")
            assert _numbers(a, "STIM") == _numbers(b, "STIM")


def _numbers(text, label):
    """The integers of the STIM or EXPECT table, in either language."""
    body = text.split(label, 1)[1]
    body = body.split(":=", 1)[1] if ":=" in body.split("\n", 1)[0] else body
    # Everything up to the line that closes the aggregate.
    rows = []
    for line in body.splitlines()[1:]:
        if line.strip() in (");", "};"):
            break
        rows.append(line)
    return [int(v) for v in re.findall(r"-?\d+", "\n".join(rows))]


def test_the_expected_vectors_come_from_the_shared_model():
    res, q = fir_design()
    o = opts(structure="tree", folded=True)
    plan = rc.plan_for("fir", res, q, o)
    stim = sv.stimulus(plan)
    want = plan.simulate(stim)
    tb = vh.testbench_for("fir", res, q, o, samples=stim)
    for value in want[:5]:
        assert str(int(value)) in tb


def test_the_iir_cascade_is_there_too():
    res, q = iir_design()
    src = vh.source_for("iir", res, q, opts())
    assert "g_sec : for s in 0 to NSEC-1 generate" in src
    assert src.count("u_mul_p") == 5           # five multipliers per section
    assert "NEG => true" in src                # a1 and a2 negated in the mul
    assert "u_z1" in src and "u_z2" in src


def test_the_iir_refuses_a_structure_that_does_not_apply():
    res, q = iir_design()
    with pytest.raises(vh.VhdlError, match="cascade of biquads"):
        vh.source_for("iir", res, q, opts(structure="tree"))
    with pytest.raises(vh.VhdlError, match="cascade of biquads"):
        vh.source_for("iir", res, q, opts(folded=True))


# ------------------------------------------------- if a VHDL toolchain is there

@needs_ghdl
@pytest.mark.parametrize("structure", STRUCTURES)
@pytest.mark.parametrize("folded", [False, True])
def test_the_vhdl_analyses(tmp_path, structure, folded):
    """Only runs where ghdl is installed and able to start."""
    res, q = fir_design()
    o = opts(structure=structure, folded=folded)
    design = tmp_path / "dut.vhd"
    bench = tmp_path / "dut_tb.vhd"
    design.write_text(vh.source_for("fir", res, q, o))
    bench.write_text(vh.testbench_for("fir", res, q, o))
    done = subprocess.run([GHDL, "-a", "--std=93", "--workdir=" + str(tmp_path),
                           str(design), str(bench)],
                          capture_output=True, text=True, timeout=120)
    assert done.returncode == 0, done.stdout + done.stderr


def _ghdl_run(tmp_path, design_text, bench_text, top):
    design = tmp_path / "dut.vhd"
    bench = tmp_path / "dut_tb.vhd"
    design.write_text(design_text)
    bench.write_text(bench_text)
    work = "--workdir=" + str(tmp_path)
    for args in ([GHDL, "-a", "--std=93", work, str(design), str(bench)],
                 [GHDL, "-e", "--std=93", work, top]):
        done = subprocess.run(args, capture_output=True, text=True,
                              cwd=tmp_path, timeout=180)
        assert done.returncode == 0, done.stdout + done.stderr
    run = subprocess.run([GHDL, "-r", "--std=93", work, top],
                         capture_output=True, text=True, cwd=tmp_path,
                         timeout=180)
    assert run.returncode == 0, run.stdout + run.stderr
    return run.stdout + run.stderr


@needs_ghdl
@pytest.mark.parametrize("folded", [False, True])
@pytest.mark.parametrize("structure", STRUCTURES)
def test_every_vhdl_structure_runs_and_agrees_with_the_model(tmp_path, structure,
                                                             folded):
    """Simulated, not merely analysed: the testbench carries the expected output
    of every sample from the shared model, so a PASS means the VHDL and the
    model agree exactly."""
    res, q = fir_design()
    o = opts(structure=structure, folded=folded)
    out = _ghdl_run(tmp_path, vh.source_for("fir", res, q, o),
                    vh.testbench_for("fir", res, q, o), "dut_tb")
    assert "PASS" in out, out


@needs_ghdl
@pytest.mark.parametrize("fixed_coeffs", [True, False])
def test_the_vhdl_iir_runs_and_agrees_with_the_model(tmp_path, fixed_coeffs):
    res, q = iir_design()
    o = opts(fixed_coeffs=fixed_coeffs)
    out = _ghdl_run(tmp_path, vh.source_for("iir", res, q, o),
                    vh.testbench_for("iir", res, q, o), "dut_tb")
    assert "PASS" in out, out


@needs_ghdl
def test_runtime_vhdl_coefficients_give_the_same_answer(tmp_path):
    res, q = fir_design()
    o = opts(fixed_coeffs=False, folded=True)
    out = _ghdl_run(tmp_path, vh.source_for("fir", res, q, o),
                    vh.testbench_for("fir", res, q, o), "dut_tb")
    assert "PASS" in out, out


@needs_ghdl
def test_the_vhdl_runs_and_agrees_with_the_model(tmp_path):
    res, q = fir_design()
    o = opts()
    design = tmp_path / "dut.vhd"
    bench = tmp_path / "dut_tb.vhd"
    design.write_text(vh.source_for("fir", res, q, o))
    bench.write_text(vh.testbench_for("fir", res, q, o))
    work = "--workdir=" + str(tmp_path)
    for args in ([GHDL, "-a", "--std=93", work, str(design), str(bench)],
                 [GHDL, "-e", "--std=93", work, "dut_tb"]):
        done = subprocess.run(args, capture_output=True, text=True,
                              cwd=tmp_path, timeout=180)
        assert done.returncode == 0, done.stdout + done.stderr
    run = subprocess.run([GHDL, "-r", "--std=93", work, "dut_tb"],
                         capture_output=True, text=True, cwd=tmp_path,
                         timeout=180)
    assert run.returncode == 0, run.stdout + run.stderr
    assert "PASS" in run.stdout + run.stderr
