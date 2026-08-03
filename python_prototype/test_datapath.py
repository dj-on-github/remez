"""Checks for the fixed-point datapath model and the noise it measures."""

import numpy as np
import pytest

import datapath as dp
import fir_core as rz
import fixed_point as fp
import iir_core as ii


def lowpass(numtaps=41, bits=12):
    res = rz.design(numtaps, [rz.Band(0, .2, 1.), rz.Band(.25, .5, 0., w1=10.)])
    return res, fp.quantize(res.h, bits)


# ------------------------------------------------------------------ arithmetic

def test_multiply_rounds_to_nearest():
    # 3 * 1.5 in Q0.1 is 4.5 LSB, which rounds up, not toward zero.
    assert dp.mul(3, 3, 1, 8) == 5
    assert dp.mul(-3, 3, 1, 8) == -4          # -4.5 rounds up as well
    assert dp.mul(1 << 4, 1 << 4, 4, 16) == 1 << 4


def test_operations_saturate_rather_than_wrap():
    assert dp.add(100, 100, 8) == 127
    assert dp.add(-100, -100, 8) == -128
    assert dp.mul(127, 127, 0, 8) == 127      # 16129 clipped, not wrapped


def test_the_chain_and_the_tree_agree_until_something_clips():
    res, q = lowpass()
    small = [1 << (q.frac_bits - 3)] * 30
    chain = dp.simulate("fir", q.ints, small, q.frac_bits, q.bits, 4,
                        structure="chain")
    tree = dp.simulate("fir", q.ints, small, q.frac_bits, q.bits, 4,
                       structure="tree")
    assert chain == tree

    # With no headroom a full-scale run clips, and then the order matters,
    # because a saturating add is not associative.
    full = [(1 << (q.bits - 1)) - 1] * 30
    chain = dp.simulate("fir", q.ints, full, q.frac_bits, q.bits, 0,
                        structure="chain")
    tree = dp.simulate("fir", q.ints, full, q.frac_bits, q.bits, 0,
                       structure="tree")
    assert chain != tree


def test_the_mac_accumulates_in_the_same_order_as_the_chain():
    res, q = lowpass()
    x = list(np.random.default_rng(0).integers(-2000, 2000, 40))
    assert (dp.simulate("fir", q.ints, x, q.frac_bits, q.bits, 3, structure="mac")
            == dp.simulate("fir", q.ints, x, q.frac_bits, q.bits, 3,
                           structure="chain"))


# --------------------------------------------------------------------- folding

@pytest.mark.parametrize("numtaps,symmetry,expect", [
    (41, "symmetric", 21),          # 20 pairs plus the centre tap
    (40, "symmetric", 20),
    (41, "antisymmetric", 20),      # the centre tap is zero and drops out
    (40, "antisymmetric", 20),
])
def test_folding_halves_the_multiplies(numtaps, symmetry, expect):
    assert dp.term_count(numtaps, symmetry, True) == expect
    assert dp.term_count(numtaps, symmetry, False) == numtaps


def test_folding_is_slightly_more_accurate_not_merely_cheaper():
    # One rounding per pair instead of two, so the two are not bit-identical
    # and the folded one is the better of them.
    res, q = lowpass(numtaps=41, bits=10)
    frac, bits, headroom = q.frac_bits, q.bits, 4
    rng = np.random.default_rng(1)
    x = rng.uniform(-0.4, 0.4, 4000)
    xi = [int(round(v * (1 << frac))) for v in x]
    exact = np.convolve(x, q.values)[:len(x)]

    errs = {}
    for folded in (False, True):
        got = np.asarray(dp.simulate("fir", q.ints, xi, frac, bits, headroom,
                                     folded=folded), dtype=float) / (1 << frac)
        errs[folded] = float(np.sqrt(np.mean((got - exact) ** 2)))
    assert errs[True] < errs[False]


def test_folding_needs_the_symmetry_to_be_there():
    terms = dp.fir_terms(5, "antisymmetric", True)
    assert [t[1] for t in terms] == [(0, 4), (1, 3)]
    assert all(sign == -1 for _, _, sign in terms)


# ------------------------------------------------------------- latency and cost

@pytest.mark.parametrize("structure,folded,latency", [
    ("chain", False, 1),
    ("tree", False, 1 + 5),          # ceil(log2 41) = 6 levels
    ("mac", False, 41 + 2),
    ("mac", True, 21 + 2),
])
def test_latency_matches_the_structure(structure, folded, latency):
    got = dp.latency("fir", 41, "symmetric", structure, folded)
    assert got == dp.latency("fir", 41, "symmetric", structure, folded)
    assert got > 0
    if structure != "tree":
        assert got == latency


def test_the_mac_costs_one_multiplier_whatever_the_length():
    for numtaps in (15, 41, 201):
        assert dp.resources("fir", numtaps, "symmetric", "mac",
                            False)["multipliers"] == 1
    assert dp.resources("fir", 41, "symmetric", "chain",
                        False)["multipliers"] == 41
    assert dp.resources("fir", 41, "symmetric", "chain",
                        True)["multipliers"] == 21


def test_the_tree_is_logarithmically_deep():
    assert dp.resources("fir", 256, "symmetric", "tree", False)["pipeline"] == 8
    assert dp.resources("fir", 256, "symmetric", "chain", False)["pipeline"] == 0


# ----------------------------------------------------------------- noise floor

def test_the_measured_noise_matches_the_theory():
    """Rounding each of N products gives q*sqrt(N/12) at the output.

    The measurement is of the error signal, not of the output spectrum: taking
    the latter would measure the analysis window's sidelobes, since a passband
    sixty dB above a stopband leaks into it.
    """
    res, _ = lowpass()
    headroom = 4
    for bits in (10, 14, 18, 22):
        q = fp.quantize(res.h, bits)
        taps = q.values

        def exact(x, h=taps):
            return np.convolve(x, h)[:len(x)]

        f, noise_db, rms = dp.noise_response("fir", q.ints, exact, q.frac_bits,
                                             q.bits, headroom)
        # rms is in LSB, and one LSB is 2**-frac.
        assert rms == pytest.approx(np.sqrt(res.numtaps / 12.0), rel=0.25)

        full = (1 << (q.bits + headroom - 1)) - 1
        predicted = 20 * np.log10(np.sqrt(res.numtaps / 12.0)
                                  / (dp.NOISE_LEVEL * full))
        assert float(np.median(noise_db)) == pytest.approx(predicted, abs=1.5)


def test_more_bits_lowers_the_floor_six_dB_at_a_time():
    res, _ = lowpass()

    def floor(bits):
        q = fp.quantize(res.h, bits)
        return float(np.median(dp.noise_response(
            "fir", q.ints, lambda x, h=q.values: np.convolve(x, h)[:len(x)],
            q.frac_bits, q.bits, 4)[1]))

    a, b = floor(12), floor(16)
    assert a - b == pytest.approx(24.0, abs=3.0)      # four bits, 6 dB each


def test_folding_lowers_the_noise_floor_by_three_dB():
    # Half as many roundings, so the noise power halves.  This only holds
    # because the pre-adder is a bit wider than the datapath and does not clip
    # the sum of two large samples.
    res, q = lowpass(bits=12)

    def floor(folded):
        return float(np.median(dp.noise_response(
            "fir", q.ints, lambda x: np.convolve(x, q.values)[:len(x)],
            q.frac_bits, q.bits, 4, folded=folded)[1]))

    assert floor(True) - floor(False) == pytest.approx(-3.0, abs=1.0)


def test_the_folded_pre_adder_does_not_clip_a_full_scale_pair():
    # Two samples at full scale sum to twice full scale before the multiply.
    # Saturating that would lose signal, so the pre-add is one bit wider; the
    # test is that a loud input is still filtered accurately.
    res, q = lowpass(bits=12)
    frac, bits, headroom = q.frac_bits, q.bits, 4
    hi = (1 << (bits + headroom - 1)) - 1
    x = [hi, -hi] * 30
    got = np.asarray(dp.simulate("fir", q.ints, x, frac, bits, headroom,
                                 folded=True), dtype=float)
    want = np.convolve(np.asarray(x, dtype=float), q.values)[:len(x)]
    # Within a few LSB of the exact filter, not off by a factor.
    assert np.max(np.abs(got - want)) < 8.0


def test_the_effective_response_adds_noise_in_power():
    # A stopband well below the floor is simply not there to be measured.
    assert dp.effective_response(-100.0, -60.0) == pytest.approx(-60.0, abs=0.01)
    assert dp.effective_response(-60.0, -60.0) == pytest.approx(-56.99, abs=0.01)
    assert dp.effective_response(0.0, -80.0) == pytest.approx(0.0, abs=0.01)


def test_the_iir_datapath_can_be_measured_too():
    res = ii.design("lowpass", "elliptic", wp=0.2, ws=0.3, rp=0.5, rs=40, fs=1.0)
    q = fp.quantize_sos(res.sos, 18)
    live = [0, 1, 2, 4, 5]
    sections = [[int(row[i]) for i in live] for row in q.ints]
    f, noise_db, rms = dp.noise_response(
        "iir", sections, lambda x: ii.sos_filter(q.values, x),
        q.frac_bits, q.bits, 4, length=1 << 12)
    assert f.size > 100
    assert np.all(np.isfinite(noise_db))
    assert 0.0 < rms < 1000.0


def test_an_unknown_structure_is_refused():
    with pytest.raises(dp.DatapathError):
        dp.latency("fir", 21, "symmetric", "magic", False)
