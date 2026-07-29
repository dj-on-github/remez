"""Checks for fir_core: alternation, symmetry, and agreement with scipy."""

import numpy as np
import pytest
from scipy import signal

import fir_core as rz


def amp(res, w):
    return rz.amplitude_response(res.h, w, res.symmetry)


def peak_weighted_deviation(h, bands, symmetry="symmetric"):
    """Peak of W(f)|D(f) - A(f)| over the bands, evaluated off the design grid."""
    worst = 0.0
    for b in bands:
        f = np.linspace(b.f1, b.f2, 4001)
        t = (f - b.f1) / (b.f2 - b.f1)
        d = b.d1 + t * (b.d2 - b.d1)
        w = b.w1 + t * (b.w2 - b.w1)
        worst = max(worst, float((w * np.abs(amp_h(h, f, symmetry) - d)).max()))
    return worst


def amp_h(h, f, symmetry):
    return rz.amplitude_response(h, 2 * np.pi * f, symmetry)


# The dense grid quantises where the extrema may sit, so an independent
# implementation lands on slightly different taps at a given density.  What
# must agree is the optimum itself: both converge to it as the grid refines.
def assert_matches_scipy(numtaps, bands, edges, desired, weight=None,
                         symmetry="symmetric", ftype=None):
    res = rz.design(numtaps, bands, symmetry=symmetry, grid_density=256)
    kw = {"type": "hilbert"} if symmetry == "antisymmetric" else {}
    ref = signal.remez(numtaps, edges, desired, weight=weight, fs=1.0,
                       grid_density=256, **kw)
    assert res.converged
    if ftype is not None:
        assert res.ftype == ftype
    assert np.allclose(res.h, ref, atol=1e-6)
    mine = peak_weighted_deviation(res.h, bands, symmetry)
    theirs = peak_weighted_deviation(ref, bands, symmetry)
    assert mine <= theirs * 1.001


def test_lowpass_type1_matches_scipy():
    assert_matches_scipy(31, [rz.Band(0.0, 0.2, 1.0), rz.Band(0.25, 0.5, 0.0)],
                         [0, 0.2, 0.25, 0.5], [1, 0], ftype=1)


def test_lowpass_type2_even_length():
    assert_matches_scipy(32, [rz.Band(0.0, 0.18, 1.0), rz.Band(0.26, 0.5, 0.0)],
                         [0, 0.18, 0.26, 0.5], [1, 0], ftype=2)


def test_bandpass_weighted():
    bands = [rz.Band(0, 0.1, 0.0, w1=2.0),
             rz.Band(0.15, 0.3, 1.0, w1=1.0),
             rz.Band(0.35, 0.5, 0.0, w1=4.0)]
    assert_matches_scipy(45, bands, [0, .1, .15, .3, .35, .5], [0, 1, 0],
                         weight=[2, 1, 4])


def test_hilbert_type3():
    assert_matches_scipy(31, [rz.Band(0.05, 0.45, 1.0)], [0.05, 0.45], [1],
                         symmetry="antisymmetric", ftype=3)


def test_coarse_grid_still_lands_near_the_optimum():
    bands = [rz.Band(0.0, 0.2, 1.0), rz.Band(0.25, 0.5, 0.0)]
    coarse = rz.design(31, bands, grid_density=16)
    fine = rz.design(31, bands, grid_density=256)
    assert np.allclose(coarse.h, fine.h, atol=1e-4)


def test_differentiator_type4():
    # Desired amplitude ramps with frequency; weight 1/f is the usual choice.
    b = rz.Band(0.0, 0.45, 0.0, 2 * np.pi * 0.45)
    res = rz.design(32, [b], symmetry="antisymmetric")
    assert res.ftype == 4
    w = 2 * np.pi * np.linspace(0.02, 0.45, 200)
    got = amp(res, w)
    assert np.max(np.abs(got - w)) < 0.05


def test_symmetry_of_taps():
    res = rz.design(30, [rz.Band(0, .2, 1.0), rz.Band(.3, .5, 0.0)])
    assert np.allclose(res.h, res.h[::-1], atol=1e-12)
    res = rz.design(31, [rz.Band(.05, .45, 1.0)], symmetry="antisymmetric")
    assert np.allclose(res.h, -res.h[::-1], atol=1e-12)
    assert abs(res.h[15]) < 1e-12


def test_alternation_and_equiripple():
    res = rz.design(41, [rz.Band(0, .2, 1.0), rz.Band(.28, .5, 0.0)])
    e = res.extremal_e
    assert len(e) == (41 + 1) // 2 + 1
    assert np.all(np.sign(e[:-1]) * np.sign(e[1:]) < 0)          # alternating
    assert np.allclose(np.abs(e), abs(res.delta), rtol=1e-6)      # equiripple
    assert np.abs(res.grid_e).max() <= abs(res.delta) * (1 + 1e-6)


def test_taps_reproduce_the_designed_amplitude():
    res = rz.design(37, [rz.Band(0, .15, 1.0), rz.Band(.22, .4, 0.3), rz.Band(.45, .5, 0.0)])
    w = 2 * np.pi * res.grid_f / res.fs
    assert np.max(np.abs(amp(res, w) - res.grid_a)) < 1e-9


def test_weighting_scales_the_ripples():
    res = rz.design(41, [rz.Band(0, .2, 1.0, w1=1.0), rz.Band(.3, .5, 0.0, w1=10.0)])
    dp, ds = res.band_deviation
    assert dp / ds == pytest.approx(10.0, rel=1e-3)


def test_sampling_frequency_units():
    a = rz.design(31, [rz.Band(0, 2000, 1.0), rz.Band(2500, 5000, 0.0)], fs=10000)
    b = rz.design(31, [rz.Band(0, .2, 1.0), rz.Band(.25, .5, 0.0)])
    assert np.allclose(a.h, b.h, atol=1e-9)


@pytest.mark.parametrize("bad,msg", [
    (dict(numtaps=2, bands=[rz.Band(0, .2, 1.0), rz.Band(.3, .5, 0.0)]), "at least 3"),
    (dict(numtaps=21, bands=[rz.Band(0, .6, 1.0)]), "f2 <= fs/2"),
    (dict(numtaps=21, bands=[rz.Band(.3, .5, 1.0), rz.Band(.1, .2, 0.0)]), "overlaps"),
    (dict(numtaps=21, bands=[rz.Band(0, .2, 1.0, w1=0.0)]), "strictly positive"),
])
def test_input_validation(bad, msg):
    with pytest.raises(rz.RemezError) as e:
        rz.design(**bad)
    assert msg in str(e.value)


def test_high_order_design_converges():
    # Uniform starting references collapse to a round-off deviation above ~100
    # coefficients; reference scaling is what keeps these designs working.
    bands = [rz.Band(0, 0.13, 0.0, w1=17.0), rz.Band(0.2, 0.28, 1.0),
             rz.Band(0.33, 0.5, 0.0, w1=1.1)]
    res = rz.design(190, bands)
    assert res.converged
    assert abs(res.delta) > 1e-9
    assert np.abs(res.grid_e).max() <= abs(res.delta) * (1 + 1e-6)


@pytest.mark.parametrize("numtaps", [101, 128, 175, 220])
def test_long_filters_stay_equiripple(numtaps):
    bands = [rz.Band(0, 0.2, 1.0), rz.Band(0.25, 0.5, 0.0, w1=10.0)]
    res = rz.design(numtaps, bands)
    assert res.converged
    e = res.extremal_e
    assert np.all(np.sign(e[:-1]) * np.sign(e[1:]) < 0)
    assert np.allclose(np.abs(e), abs(res.delta), rtol=1e-6)


def test_inverse_f_weighting_equalises_relative_error():
    # A differentiator wants constant *relative* error, not constant absolute.
    b = rz.Band(0.02, 0.45, 2 * np.pi * 0.02, 2 * np.pi * 0.45, w1=1.0,
                weight_kind="inv_f")
    res = rz.design(33, [b], symmetry="antisymmetric")
    f = np.linspace(0.05, 0.45, 2000)
    rel = np.abs(amp(res, 2 * np.pi * f) - 2 * np.pi * f) / (2 * np.pi * f)
    # Equal relative ripple at the bottom of the band and at the top.
    assert rel[:1000].max() == pytest.approx(rel[1000:].max(), rel=0.05)

    # Constant weighting instead lets the relative error at the low end run away.
    flat = rz.design(33, [rz.Band(0.02, 0.45, 2 * np.pi * 0.02, 2 * np.pi * 0.45)],
                     symmetry="antisymmetric")
    rel_flat = np.abs(amp(flat, 2 * np.pi * f) - 2 * np.pi * f) / (2 * np.pi * f)
    assert rel_flat[:1000].max() > 4 * rel_flat[1000:].max()
    assert rel.max() < rel_flat.max() / 4


@pytest.mark.parametrize("n", [5, 30, 60, 100])
def test_interpolation_is_accurate_far_outside_the_nodes(n):
    """The kernel the exchange runs on, checked against extended precision.

    Points outside the hull of the nodes are what a wide unconstrained
    transition band produces, and are where the usual barycentric formula
    quietly returns a finite wrong answer.
    """
    rng = np.random.default_rng(3)
    x = np.sort(np.cos(np.pi * rng.uniform(0, 1, n)))
    y = rng.normal(size=n)
    gamma = rz._bary_weights(x)
    xq = np.sort(rng.uniform(-1.3, 1.3, 40))          # 1.3 is well outside

    xl = x.astype(np.longdouble)
    ref = np.array([
        float(sum(np.prod([(np.longdouble(q) - xl[j]) / (xl[k] - xl[j])
                           for j in range(n) if j != k]) * np.longdouble(y[k])
                  for k in range(n)))
        for q in xq])

    got = rz._lagrange(xq, x, y, gamma)
    assert np.max(np.abs(got - ref) / np.abs(ref)) < 1e-12
    # And the nodes themselves come back exactly.
    assert np.array_equal(rz._lagrange(x, x, y, gamma), y)


def test_kaiser_estimate_is_in_the_right_ballpark():
    n = rz.kaiser_order_estimate(0.01, 0.001, 0.05)
    res = rz.design(n | 1, [rz.Band(0, .2, 1.0, w1=1.0), rz.Band(.25, .5, 0.0, w1=10.0)])
    assert res.band_deviation[0] < 0.02
