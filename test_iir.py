"""Checks on the classical IIR designs in ``iir_core``.

scipy is used as the reference for the analog prototypes, the frequency
transformations, the bilinear map and the order estimates; it is not used by
the program itself.  The elliptic prototype is the one worth cross-checking
carefully, since scipy reaches the same poles by root-finding on the degree
equation where this module evaluates the Jacobi functions directly.
"""

import numpy as np
import pytest

import iir_core as ii

signal = pytest.importorskip("scipy.signal")

FS = 1000.0

CASES = [
    ("lowpass", (200.0,), (260.0,)),
    ("highpass", (260.0,), (200.0,)),
    ("bandpass", (180.0, 320.0), (120.0, 380.0)),
    ("bandstop", (140.0, 360.0), (200.0, 300.0)),
]

SCIPY_NAME = {"butterworth": "butter", "chebyshev1": "cheby1",
              "chebyshev2": "cheby2", "elliptic": "ellip"}


def same_roots(a, b, rtol=1e-9):
    a, b = np.atleast_1d(a), np.atleast_1d(b)
    if a.size != b.size:
        return False
    return np.allclose(np.sort_complex(np.round(a, 12)),
                       np.sort_complex(np.round(b, 12)), rtol=rtol, atol=1e-12)


# ---------------------------------------------------------------- prototypes

@pytest.mark.parametrize("n", [1, 2, 3, 5, 8, 12])
def test_butterworth_prototype(n):
    z, p, k = ii.butter_ap(n)
    zz, pp, kk = signal.buttap(n)
    assert same_roots(z, zz) and same_roots(p, pp) and np.isclose(k, kk)
    # every pole on the unit semicircle, and none of them in the right half
    assert np.allclose(np.abs(p), 1.0)
    assert np.all(p.real < 1e-15)


@pytest.mark.parametrize("n", [1, 2, 3, 5, 8, 12])
@pytest.mark.parametrize("rp", [0.1, 0.5, 1.0, 3.0])
def test_chebyshev1_prototype(n, rp):
    z, p, k = ii.cheb1_ap(n, rp)
    zz, pp, kk = signal.cheb1ap(n, rp)
    assert same_roots(z, zz) and same_roots(p, pp) and np.isclose(k, kk)


@pytest.mark.parametrize("n", [1, 2, 3, 5, 8, 12])
@pytest.mark.parametrize("rs", [20.0, 40.0, 80.0])
def test_chebyshev2_prototype(n, rs):
    z, p, k = ii.cheb2_ap(n, rs)
    zz, pp, kk = signal.cheb2ap(n, rs)
    assert same_roots(z, zz) and same_roots(p, pp) and np.isclose(k, kk)


@pytest.mark.parametrize("n", [1, 2, 3, 4, 5, 8, 12])
@pytest.mark.parametrize("rp,rs", [(0.1, 40.0), (0.5, 60.0), (1.0, 80.0),
                                   (0.01, 100.0), (3.0, 20.0)])
def test_elliptic_prototype(n, rp, rs):
    """The Landen route to the Jacobi functions against scipy's root-finding."""
    z, p, k = ii.ellip_ap(n, rp, rs)
    zz, pp, kk = signal.ellipap(n, rp, rs)
    assert same_roots(z, zz, rtol=1e-8)
    assert same_roots(p, pp, rtol=1e-8)
    assert np.isclose(k, kk, rtol=1e-8)


@pytest.mark.parametrize("n", [3, 4, 7, 10])
def test_elliptic_is_equiripple_in_both_bands(n):
    """The defining property: n+1 touches of each limit, at both ends."""
    rp, rs = 0.5, 60.0
    z, p, k = ii.ellip_ap(n, rp, rs)

    def mag(w):
        s = 1j * w
        num = np.prod(s[:, None] - z[None, :], axis=1) if len(z) else 1.0
        return np.abs(k * num / np.prod(s[:, None] - p[None, :], axis=1))

    w = np.linspace(1e-6, 1.0, 20001)
    m = mag(w)
    assert np.isclose(m.max(), 1.0, rtol=1e-6)
    assert np.isclose(m.min(), 10 ** (-rp / 20.0), rtol=1e-6)

    # The stopband starts at 1/k, where k solves the degree equation.
    eps_p = np.sqrt(10 ** (0.1 * rp) - 1.0)
    eps_s = np.sqrt(10 ** (0.1 * rs) - 1.0)
    ws = 1.0 / ii._ellipdeg(n, eps_p / eps_s)
    assert ws > 1.0
    m = mag(np.linspace(ws, 40.0 * ws, 40001))
    assert m.max() <= 10 ** (-rs / 20.0) * (1 + 1e-6)


def test_elliptic_rejects_an_impossible_pair():
    with pytest.raises(ii.IIRError):
        ii.ellip_ap(5, 3.0, 1.0)


@pytest.mark.parametrize("k", [0.0, 0.1, 0.5, 0.9, 0.999, 1 - 1e-9])
def test_complete_elliptic_integral(k):
    from scipy import special
    assert np.isclose(ii.ellipk(k), special.ellipk(k * k), rtol=1e-12)


# ----------------------------------------------------- transformations, maps

@pytest.mark.parametrize("wo", [0.3, 1.0, 7.7])
def test_frequency_transformations(wo):
    z, p, k = ii.ellip_ap(5, 0.5, 60.0)
    bw = 0.4 * wo
    for mine, theirs in [
        (ii.lp2lp_zpk(z, p, k, wo), signal.lp2lp_zpk(z, p, k, wo)),
        (ii.lp2hp_zpk(z, p, k, wo), signal.lp2hp_zpk(z, p, k, wo)),
        (ii.lp2bp_zpk(z, p, k, wo, bw), signal.lp2bp_zpk(z, p, k, wo, bw)),
        (ii.lp2bs_zpk(z, p, k, wo, bw), signal.lp2bs_zpk(z, p, k, wo, bw)),
        (ii.bilinear_zpk(z, p, k, 3.0), signal.bilinear_zpk(z, p, k, 3.0)),
    ]:
        assert same_roots(mine[0], theirs[0])
        assert same_roots(mine[1], theirs[1])
        assert np.isclose(mine[2], theirs[2])


def test_transformations_of_an_all_pole_prototype():
    """The zero-free prototypes take a different branch of the gain formula."""
    z, p, k = ii.butter_ap(6)
    for mine, theirs in [
        (ii.lp2hp_zpk(z, p, k, 2.0), signal.lp2hp_zpk(z, p, k, 2.0)),
        (ii.lp2bp_zpk(z, p, k, 2.0, 0.5), signal.lp2bp_zpk(z, p, k, 2.0, 0.5)),
        (ii.lp2bs_zpk(z, p, k, 2.0, 0.5), signal.lp2bs_zpk(z, p, k, 2.0, 0.5)),
    ]:
        assert same_roots(mine[0], theirs[0])
        assert same_roots(mine[1], theirs[1])
        assert np.isclose(mine[2], theirs[2])


def test_prewarping_puts_the_edge_back_where_it_was():
    f = np.array([10.0, 200.0, 480.0])
    w = ii.prewarp(f, FS)
    assert np.allclose(FS / np.pi * np.arctan(w / (2.0 * FS)), f)
    with pytest.raises(ii.IIRError):
        ii.prewarp(np.array([FS / 2]), FS)


# ------------------------------------------------------------------ cascades

def test_sos_reproduces_the_zero_pole_gain_response():
    r = ii.design("bandpass", "elliptic", wp=(180.0, 320.0), ws=(120.0, 380.0),
                  rp=0.5, rs=60.0, fs=FS)
    f = np.linspace(1e-6, FS / 2 - 1e-6, 997)
    w = 2 * np.pi * f / FS
    _, ref = signal.freqz_zpk(r.z, r.p, r.k, worN=w)
    assert np.allclose(r.response_at(f), ref, rtol=1e-7, atol=1e-9)


def test_sections_have_real_coefficients_and_are_ordered_outward():
    r = ii.design("lowpass", "elliptic", wp=(200.0,), ws=(260.0,),
                  rp=0.5, rs=80.0, fs=FS)
    assert r.sos.shape[1] == 6
    assert np.all(np.isreal(r.sos))
    # the pole pair closest to the unit circle comes last
    radii = [max(abs(v) for v in np.roots(s[3:])) for s in r.sos]
    assert radii == sorted(radii)


def test_filtering_matches_scipy_sosfilt():
    r = ii.design("highpass", "chebyshev1", wp=(260.0,), ws=(200.0,),
                  rp=0.5, rs=50.0, fs=FS)
    rng = np.random.default_rng(0)
    x = rng.standard_normal(400)
    assert np.allclose(ii.sos_filter(r.sos, x), signal.sosfilt(r.sos, x), atol=1e-11)
    assert np.allclose(ii.sos_impulse(r.sos, 200)[:5],
                       signal.sosfilt(r.sos, np.r_[1.0, np.zeros(199)])[:5])


def test_group_delay_matches_scipy():
    r = ii.design("lowpass", "elliptic", wp=(200.0,), ws=(260.0,),
                  rp=0.5, rs=60.0, fs=FS)
    w = np.linspace(0.02, 3.0, 400)
    _, ref = signal.group_delay(signal.sos2tf(r.sos), w=w)
    assert np.allclose(ii.group_delay(r.sos, w), ref, atol=1e-4)


# ------------------------------------------------------------------- designs

@pytest.mark.parametrize("approximation", list(SCIPY_NAME))
@pytest.mark.parametrize("response,wp,ws", CASES)
def test_order_estimate_agrees_with_scipy(approximation, response, wp, ws):
    fn = {"butterworth": signal.buttord, "chebyshev1": signal.cheb1ord,
          "chebyshev2": signal.cheb2ord, "elliptic": signal.ellipord}[approximation]
    wp_ = wp[0] if len(wp) == 1 else list(wp)
    ws_ = ws[0] if len(ws) == 1 else list(ws)
    want, _ = fn(wp_, ws_, 0.5, 60.0, fs=FS)
    r = ii.design(response, approximation, wp=wp, ws=ws, rp=0.5, rs=60.0, fs=FS)
    assert r.order == want
    assert r.auto_order


@pytest.mark.parametrize("approximation", list(SCIPY_NAME))
@pytest.mark.parametrize("response,wp,ws", CASES)
@pytest.mark.parametrize("rp,rs", [(0.1, 40.0), (0.5, 60.0), (3.0, 80.0)])
def test_automatic_order_meets_the_specification(approximation, response, wp, ws,
                                                 rp, rs):
    r = ii.design(response, approximation, wp=wp, ws=ws, rp=rp, rs=rs, fs=FS)
    assert r.stable
    assert r.meets_spec, (r.achieved_rp, rp, r.achieved_rs, rs)
    # and one order lower would not have done
    if r.order > 1:
        lower = ii.design(response, approximation, wp=wp, ws=ws, rp=rp, rs=rs,
                          order=r.order - 1, fs=FS)
        assert not lower.meets_spec


@pytest.mark.parametrize("approximation", list(SCIPY_NAME))
@pytest.mark.parametrize("response,wp,ws", CASES)
def test_the_defining_edge_lands_exactly(approximation, response, wp, ws):
    """Each approximation places one edge exactly; check it is where it says."""
    rp, rs = 0.5, 60.0
    r = ii.design(response, approximation, wp=wp, ws=ws, rp=rp, rs=rs, fs=FS)
    if approximation == "chebyshev2":
        edges, want = ws, 10 ** (-rs / 20.0)
    else:
        edges, want = wp, 10 ** (-rp / 20.0)
    assert np.allclose(np.abs(r.response_at(np.array(edges))), want, rtol=1e-9)
    assert r.wn == pytest.approx(edges)


@pytest.mark.parametrize("approximation", list(SCIPY_NAME))
@pytest.mark.parametrize("response,wp,ws", CASES)
def test_designs_match_scipy_iirfilter(approximation, response, wp, ws):
    """Same critical frequencies in, same filter out.

    Butterworth is left out: scipy normalises it at its -3 dB point where this
    module normalises it at the passband edge, so the two do not take the same
    argument.  :func:`test_the_defining_edge_lands_exactly` covers it instead.
    """
    if approximation == "butterworth":
        pytest.skip("different normalisation convention")
    for n in (3, 4, 7):
        r = ii.design(response, approximation, wp=wp, ws=ws, rp=0.5, rs=60.0,
                      order=n, fs=FS)
        crit = r.wn[0] if len(r.wn) == 1 else list(r.wn)
        z, p, k = signal.iirfilter(n, crit, rp=0.5, rs=60.0, btype=response,
                                   ftype=SCIPY_NAME[approximation],
                                   output="zpk", fs=FS)
        assert same_roots(r.z, z, rtol=1e-8)
        assert same_roots(r.p, p, rtol=1e-8)
        assert np.isclose(r.k, k, rtol=1e-8)


def test_higher_order_than_needed_is_better_not_worse():
    base = ii.design("lowpass", "elliptic", wp=(200.0,), ws=(260.0,),
                     rp=0.5, rs=60.0, fs=FS)
    more = ii.design("lowpass", "elliptic", wp=(200.0,), ws=(260.0,),
                     rp=0.5, rs=60.0, order=base.order + 3, fs=FS)
    assert more.achieved_rs > base.achieved_rs
    assert more.achieved_rp == pytest.approx(0.5, rel=1e-6)


def test_scaling_the_sample_rate_scales_the_design():
    a = ii.design("lowpass", "elliptic", wp=(0.2,), ws=(0.25,), rp=0.5, rs=60.0)
    b = ii.design("lowpass", "elliptic", wp=(9600.0,), ws=(12000.0,),
                  rp=0.5, rs=60.0, fs=48000.0)
    assert np.allclose(a.sos, b.sos)


# ---------------------------------------------------------------- validation

@pytest.mark.parametrize("kwargs,message", [
    (dict(response="banana", wp=(0.2,), ws=(0.3,)), "unknown response"),
    (dict(approximation="banana", wp=(0.2,), ws=(0.3,)), "unknown approximation"),
    (dict(wp=(0.3,), ws=(0.2,)), "stopband edge must be above"),
    (dict(wp=(0.2,), ws=(0.6,)), "between 0 and"),
    (dict(wp=(0.2,), ws=(0.3,), rp=-1.0), "ripple must be positive"),
    (dict(wp=(0.2,), ws=(0.3,), rp=60.0, rs=1.0), "must exceed"),
    (dict(wp=(0.2,), ws=(0.3,), order=0), "at least 1"),
    (dict(response="bandpass", wp=(0.2,), ws=(0.3,)), "needs 2 passband"),
    (dict(response="bandpass", wp=(0.1, 0.2), ws=(0.15, 0.3)), "fs1 < fp1"),
    (dict(response="bandstop", wp=(0.1, 0.4), ws=(0.05, 0.3)), "fp1 < fs1"),
])
def test_bad_requests_are_rejected(kwargs, message):
    kwargs.setdefault("response", "lowpass")
    kwargs.setdefault("approximation", "elliptic")
    with pytest.raises(ii.IIRError, match=message):
        ii.design(**kwargs)


def test_absurd_orders_are_refused():
    with pytest.raises(ii.IIRError, match="hopeless"):
        ii.design("lowpass", "butterworth", wp=(0.2,), ws=(0.3,), order=100)
