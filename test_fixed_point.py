"""Checks for coefficient quantization and the re-analysis it feeds."""

import numpy as np
import pytest

import fir_core as rz
import fixed_point as fp
import iir_core as ii


def lowpass(numtaps=41):
    return rz.design(numtaps, [rz.Band(0, .2, 1.), rz.Band(.25, .5, 0., w1=10.)])


def elliptic(rs=70):
    return ii.design("lowpass", "elliptic", wp=0.2, ws=0.26, rp=0.3, rs=rs, fs=1.0)


# ------------------------------------------------------------------ the format

def test_values_land_on_the_lattice():
    q = fp.quantize([0.1, -0.25, 0.4], 12)
    assert np.all(q.ints == np.round(np.asarray([0.1, -0.25, 0.4]) * 2 ** q.frac_bits))
    assert np.allclose(q.values, q.ints * q.step)
    assert q.step == 2.0 ** -q.frac_bits


def test_exactly_representable_values_are_untouched():
    exact = np.array([0.5, -0.25, 0.125, 0.0, -0.5])
    q = fp.quantize(exact, 16)
    assert np.array_equal(q.values, exact)
    assert q.max_error == 0.0


def test_rounding_error_is_at_most_half_a_step():
    rng = np.random.default_rng(0)
    for bits in (6, 8, 12, 16, 24):
        v = rng.uniform(-1, 1, 200)
        q = fp.quantize(v, bits)
        assert q.saturated == 0
        assert q.max_error <= q.step / 2 + 1e-18


@pytest.mark.parametrize("bits", [4, 8, 12, 16, 24, 32])
def test_nothing_saturates_under_the_automatic_binary_point(bits):
    rng = np.random.default_rng(1)
    for scale in (1e-3, 0.4, 1.0, 7.9, 1000.0):
        q = fp.quantize(rng.uniform(-scale, scale, 100), bits)
        assert q.saturated == 0
        lo, hi = q.limits
        assert np.all((q.ints >= lo) & (q.ints <= hi))


def test_the_automatic_point_gives_away_no_resolution():
    # One bit further left would have to saturate something, or the point was
    # not pushed as far as it could go.
    rng = np.random.default_rng(2)
    v = rng.uniform(-0.9, 0.9, 50)
    q = fp.quantize(v, 16)
    greedier = fp.quantize(v, 16, q.frac_bits + 1)
    assert greedier.saturated > 0


def test_more_bits_never_rounds_worse():
    v = np.random.default_rng(3).uniform(-1, 1, 100)
    errors = [fp.quantize(v, b).max_error for b in range(4, 25)]
    assert all(a >= b for a, b in zip(errors, errors[1:]))


def test_a_forced_binary_point_saturates_and_says_so():
    q = fp.quantize([0.4, 1.2, -1.5], 8, frac_bits=7)     # range is about +-1
    assert q.saturated == 2                               # both of the outliers
    lo, hi = q.limits
    assert q.ints[1] == hi and q.ints[2] == lo            # clipped, not wrapped
    assert q.values[1] == pytest.approx(hi / 128)
    assert q.values[0] == pytest.approx(51 / 128)         # the one that fits


def test_qformat_labels_the_split():
    q = fp.quantize([1.5], 16)                            # needs one integer bit
    assert q.int_bits + q.frac_bits + 1 == q.bits
    assert q.qformat == f"Q{q.int_bits}.{q.frac_bits}"


def test_zero_coefficients_do_not_divide_by_zero():
    q = fp.quantize(np.zeros(5), 16)
    assert np.all(q.values == 0)
    assert q.frac_bits == 15


@pytest.mark.parametrize("bits", [1, 0, -3, 54])
def test_impossible_word_lengths_are_refused(bits):
    with pytest.raises(fp.FixedPointError):
        fp.quantize([0.5], bits)


# --------------------------------------------------------------------- the FIR

def test_quantization_preserves_linear_phase():
    # Symmetric taps are equal to the last bit, so they round identically and
    # the symmetry -- and with it the exact linear phase -- survives.
    for numtaps, sym in ((41, "symmetric"), (40, "symmetric"),
                         (41, "antisymmetric"), (40, "antisymmetric")):
        res = rz.design(numtaps, [rz.Band(.05, .2, 1.), rz.Band(.25, .45, 0.)],
                        symmetry=sym)
        q = fp.quantize(res.h, 8)
        sign = 1 if sym == "symmetric" else -1
        assert np.array_equal(q.values, sign * q.values[::-1])


def test_the_stopband_floor_rises_as_bits_are_removed():
    res = lowpass()
    floors = []
    for bits in (8, 10, 12, 16, 24):
        q = fp.quantize(res.h, bits)
        floors.append(rz.with_taps(res, q.values).band_deviation[1])
    assert all(a > b for a, b in zip(floors, floors[1:]))       # monotonic
    assert floors[0] > 3 * res.band_deviation[1]                # 8 bits hurts
    assert floors[-1] == pytest.approx(res.band_deviation[1], rel=1e-3)


def test_enough_bits_reproduces_the_design_exactly():
    res = lowpass()
    q = fp.quantize(res.h, 53)
    eff = rz.with_taps(res, q.values)
    assert np.allclose(eff.h, res.h, rtol=0, atol=1e-15)
    assert eff.band_deviation == pytest.approx(res.band_deviation, rel=1e-9)


def test_with_taps_reanalyses_everything_it_reports():
    res = lowpass()
    eff = rz.with_taps(res, fp.quantize(res.h, 8).values)
    # The measured fields follow the new taps ...
    w = 2 * np.pi * res.grid_f / res.fs
    assert np.allclose(eff.grid_a, rz.amplitude_response(eff.h, w, res.symmetry))
    assert np.allclose(eff.grid_e, res.grid_w * (res.grid_d - eff.grid_a))
    assert not np.allclose(eff.grid_e, res.grid_e)
    # ... and the design history does not.
    assert eff.delta == res.delta
    assert eff.iterations == res.iterations
    assert np.array_equal(eff.extremal_f, res.extremal_f)


def test_rounding_destroys_the_equiripple_property():
    res = lowpass()
    eff = rz.with_taps(res, fp.quantize(res.h, 8).values)
    assert np.allclose(np.abs(res.extremal_e), abs(res.delta), rtol=1e-6)
    assert not np.allclose(np.abs(eff.extremal_e), abs(res.delta), rtol=1e-3)


def test_with_taps_checks_the_length():
    with pytest.raises(rz.RemezError):
        rz.with_taps(lowpass(), np.zeros(7))


# --------------------------------------------------------------------- the IIR

def test_a0_stays_exactly_one():
    res = elliptic()
    for bits in (6, 8, 12, 16):
        q = fp.quantize_sos(res.sos, bits)
        assert np.all(q.values[:, 3] == 1.0)


def test_a0_does_not_drag_the_binary_point():
    # a0 is not a multiplier, so it must not be the coefficient that decides
    # how many integer bits everything else has to carry.
    sos = np.array([[0.01, 0.02, 0.01, 1.0, -0.5, 0.25]])
    assert fp.quantize_sos(sos, 12).frac_bits > fp.quantize(sos, 12).frac_bits


def test_quantized_sections_still_describe_the_same_filter_shape():
    res = elliptic()
    q = fp.quantize_sos(res.sos, 20)
    eff = ii.with_sos(res, q.values)
    assert eff.stable
    assert eff.achieved_rp == pytest.approx(res.achieved_rp, rel=0.05)
    assert eff.achieved_rs == pytest.approx(res.achieved_rs, rel=0.05)


def test_a_short_word_can_cost_stability():
    # A narrow-band high-order elliptic has poles crowded against the unit
    # circle, and rounding their coefficients is what pushes one onto or past
    # it.  This is the failure that makes coefficient width a design decision
    # rather than an afterthought.
    old = np.seterr(all="ignore")            # an unstable filter divides by 0
    try:
        res = ii.design("lowpass", "elliptic", wp=0.02, ws=0.03, rp=0.1, rs=80,
                        fs=1.0)
        assert res.stable and res.max_pole_radius > 0.99
        effs = [ii.with_sos(res, fp.quantize_sos(res.sos, b).values)
                for b in (6, 8, 24)]
    finally:
        np.seterr(**old)
    assert not effs[0].stable and effs[0].max_pole_radius >= 1.0
    assert not effs[1].stable
    assert effs[2].stable
    assert effs[2].max_pole_radius == pytest.approx(res.max_pole_radius, rel=1e-6)


def test_sos_to_zpk_recovers_the_designed_roots():
    res = elliptic()
    z, p, _ = ii.sos_to_zpk(res.sos)
    assert len(p) == len(res.p) and len(z) == len(res.z)
    assert np.allclose(np.sort_complex(p), np.sort_complex(res.p), atol=1e-9)
    assert np.allclose(np.sort_complex(z), np.sort_complex(res.z), atol=1e-9)


def test_with_sos_leaves_the_specification_alone():
    res = elliptic()
    eff = ii.with_sos(res, fp.quantize_sos(res.sos, 8).values)
    assert (eff.rp, eff.rs, eff.wp, eff.ws) == (res.rp, res.rs, res.wp, res.ws)
    assert eff.order == res.order


def test_with_sos_checks_the_shape():
    with pytest.raises(ii.IIRError):
        ii.with_sos(elliptic(), np.zeros((2, 6)))


def test_quantize_sos_rejects_a_non_section_array():
    with pytest.raises(fp.FixedPointError):
        fp.quantize_sos(np.zeros((3, 5)), 16)
