"""Classical IIR filter design: analog prototypes and the bilinear transform.

This is the recursive counterpart to :mod:`remez_core`.  Where the Remez
exchange searches numerically for the best polynomial, the classical IIR
designs are closed form: a normalised analog lowpass prototype with a known
pole-zero pattern is transformed to the wanted band, then mapped to the unit
disc.  Four approximations are provided:

    approximation   passband        stopband        equiripple where
    --------------  --------------  --------------  ------------------
    Butterworth     maximally flat  maximally flat  nowhere
    Chebyshev I     equiripple      monotonic       passband
    Chebyshev II    monotonic       equiripple      stopband
    Elliptic        equiripple      equiripple      both

and each may be turned into a lowpass, highpass, bandpass or bandstop
response.  The elliptic case is the interesting one: it is the minimax
solution of the same approximation problem the Remez exchange solves, but over
rational rather than polynomial functions, and it is what gives the lowest
order for a given specification.  Its poles and zeros come from Jacobi
elliptic functions, evaluated here by the descending Landen transformation
following Orfanidis, *Lecture Notes on Elliptic Filter Design* (2006).

The design path is the standard one:

    prototype (analog lowpass, edge at 1 rad/s)
        -> frequency transformation (lp2lp / lp2hp / lp2bp / lp2bs)
        -> bilinear transform, with the band edges pre-warped
        -> second-order sections

Band edges are pre-warped by w = 2 fs tan(pi f / fs) before the analog design,
so that the digital filter has its edges at exactly the frequencies asked for;
the bilinear transform's frequency compression is undone at those points, at
the cost of bending everything in between.

Nothing here depends on scipy; only numpy is required.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np

__all__ = [
    "IIRError",
    "IIRResult",
    "RESPONSES",
    "APPROXIMATIONS",
    "design",
    "estimate_order",
    "butter_ap",
    "cheb1_ap",
    "cheb2_ap",
    "ellip_ap",
    "bilinear_zpk",
    "zpk_to_sos",
    "sos_freqz",
    "sos_filter",
    "sos_impulse",
    "group_delay",
    "ellipk",
]


class IIRError(RuntimeError):
    """Raised when a design request is inconsistent or cannot be met."""


RESPONSES = ("lowpass", "highpass", "bandpass", "bandstop")

APPROXIMATIONS = ("butterworth", "chebyshev1", "chebyshev2", "elliptic")

# Which edge each approximation places exactly.  Chebyshev II is defined by
# where its stopband begins; the others by where the passband ends.
_CRITICAL_EDGE = {
    "butterworth": "passband",
    "chebyshev1": "passband",
    "chebyshev2": "stopband",
    "elliptic": "passband",
}


# --------------------------------------------------------------------------
# Elliptic integrals and Jacobi elliptic functions
# --------------------------------------------------------------------------

def _ellipk_kc(kc: float) -> float:
    """Complete elliptic integral K of the modulus whose complement is ``kc``.

    Parameterising by the *complementary* modulus is what makes this usable at
    both ends: an elliptic filter needs K(k) and K(k') for the same k, and one
    of the two is always evaluated at a modulus indistinguishable from 1 in
    double precision if it is passed directly.  The arithmetic-geometric mean
    converges quadratically, so a dozen iterations are always enough.
    """
    a, b = 1.0, float(kc)
    if b <= 0.0:
        return np.inf
    for _ in range(60):
        if abs(a - b) <= 1e-16 * a:
            break
        a, b = 0.5 * (a + b), np.sqrt(a * b)
    return np.pi / (2.0 * a)


def ellipk(k: float) -> float:
    """Complete elliptic integral of the first kind, K(k), for 0 <= k < 1."""
    return _ellipk_kc(np.sqrt(max(0.0, 1.0 - k * k)))


def _landen(k: float, tol: float = 1e-15, maxiter: int = 60) -> list:
    """Descending Landen moduli k1, k2, ... -> 0 for the modulus ``k``.

    Each step halves the "elliptic-ness" of the problem by
    k_{n+1} = (k_n / (1 + sqrt(1 - k_n^2)))^2, and the sequence reaches
    round-off in a handful of iterations.  Jacobi's functions are then
    evaluated by starting from the trivial modulus-zero case, where they are
    just a sine or a cosine, and undoing the transformations one at a time.
    """
    v = []
    k = float(k)
    for _ in range(maxiter):
        if k <= tol:
            break
        k = (k / (1.0 + np.sqrt(1.0 - k * k))) ** 2
        v.append(k)
    return v


def _ascend(w, v):
    """Run the ascending Landen recursion over the moduli ``v`` (reversed)."""
    for kn in reversed(v):
        w = (1.0 + kn) * w / (1.0 + kn * w * w)
    return w


def _sne(u, k):
    """sn(u K(k), k) -- the argument is in units of the quarter period."""
    return _ascend(np.sin(np.pi * np.asarray(u, dtype=complex) / 2.0), _landen(k))


def _cde(u, k):
    """cd(u K(k), k) -- likewise normalised to the quarter period."""
    return _ascend(np.cos(np.pi * np.asarray(u, dtype=complex) / 2.0), _landen(k))


def _asne(w, k):
    """Inverse of :func:`_sne`: u with sn(u K(k), k) = w."""
    v = [float(k)] + _landen(k)
    w = np.asarray(w, dtype=complex)
    for n in range(len(v) - 1):
        w = w / (1.0 + np.sqrt(1.0 - w * w * v[n] ** 2)) * 2.0 / (1.0 + v[n + 1])
    return 2.0 / np.pi * np.arcsin(w)


def _nome(k: float) -> float:
    """Elliptic nome q(k) = exp(-pi K'/K), by the classical series.

    The series is in ell = (1 - sqrt(k')) / (2 (1 + sqrt(k'))), and the whole
    point of using it is that k is tiny, which is exactly when forming
    ``1 - sqrt(k')`` by subtraction throws away every digit it has.  The
    logarithmic form below keeps them.
    """
    t = 0.25 * np.log1p(-float(k) * float(k))          # log of k'^(1/2)
    ell = -0.5 * np.expm1(t) / (1.0 + np.exp(t))
    return ell + 2.0 * ell ** 5 + 15.0 * ell ** 9 + 150.0 * ell ** 13


def _ellipdeg_small(n: int, k1: float) -> float:
    """Solve the degree equation through the nome, for a tiny k1.

    The Landen route below loses digits when k1 is small enough that its
    complement is 1 to working precision.  Written in terms of the nome
    q = exp(-pi K'/K) the degree equation is just q = q1^(1/n), and the modulus
    comes back from the theta series, which is happy with a tiny q.
    """
    q = _nome(k1) ** (1.0 / n)
    m = np.arange(0, 8)
    num = np.sum(q ** (m * (m + 1)))                    # theta_2 / (2 q^(1/4))
    den = 1.0 + 2.0 * np.sum(q ** (m[1:] ** 2))         # theta_3
    return 4.0 * np.sqrt(q) * (num / den) ** 2


def _ellipdeg(n: int, k1: float) -> float:
    """Solve the degree equation n K'(k)/K(k) = K'(k1)/K(k1) for k.

    ``k1`` is the *discrimination factor* eps_p / eps_s fixed by the two ripple
    specifications, and ``k`` that comes back is the selectivity: an order-n
    elliptic filter with those ripples has its passband edge at 1 and its
    stopband edge at 1/k.
    """
    if k1 <= 0.0:
        raise IIRError("the stopband must be more demanding than the passband")
    if k1 >= 1.0:
        raise IIRError("stopband attenuation must exceed the passband ripple")
    if k1 < 1e-6:
        return _ellipdeg_small(n, k1)
    kc = np.sqrt(1.0 - k1 * k1)                    # complement of k1
    kp = kc ** n * np.prod(np.real(_sne((2 * np.arange(1, n // 2 + 1) - 1) / n, kc))) ** 4
    return np.sqrt(max(0.0, 1.0 - kp * kp))


# --------------------------------------------------------------------------
# Analog prototypes: normalised lowpass, band edge at 1 rad/s
# --------------------------------------------------------------------------

def butter_ap(n: int):
    """Butterworth prototype: n poles evenly spaced on the left unit semicircle."""
    _check_order(n)
    k = np.arange(1 - n, n, 2)
    p = -np.exp(1j * np.pi * k / (2.0 * n))
    return np.array([], dtype=complex), p, 1.0


def cheb1_ap(n: int, rp: float):
    """Chebyshev type I prototype: ``rp`` dB of equiripple in the passband."""
    _check_order(n)
    if rp <= 0:
        raise IIRError("the passband ripple must be positive")
    eps = np.sqrt(10.0 ** (0.1 * rp) - 1.0)
    mu = np.arcsinh(1.0 / eps) / n
    theta = np.pi * np.arange(1 - n, n, 2) / (2.0 * n)
    p = -np.sinh(mu + 1j * theta)
    k = float(np.real(np.prod(-p)))
    if n % 2 == 0:
        # Even orders start the ripple at 1/sqrt(1+eps^2) rather than at 1, so
        # that the band still spans exactly rp dB.
        k /= np.sqrt(1.0 + eps * eps)
    return np.array([], dtype=complex), p, k


def cheb2_ap(n: int, rs: float):
    """Chebyshev type II prototype: ``rs`` dB of equiripple stopband from 1 rad/s.

    This is the type I response reciprocated in frequency, which turns the
    passband ripple into stopband ripple and puts a zero on the imaginary axis
    at each former ripple peak.
    """
    _check_order(n)
    if rs <= 0:
        raise IIRError("the stopband attenuation must be positive")
    de = 1.0 / np.sqrt(10.0 ** (0.1 * rs) - 1.0)
    mu = np.arcsinh(1.0 / de) / n
    if n % 2:
        m = np.concatenate([np.arange(1 - n, 0, 2), np.arange(2, n, 2)])
    else:
        m = np.arange(1 - n, n, 2)
    z = -np.conjugate(1j / np.sin(m * np.pi / (2.0 * n)))
    pp = -np.exp(1j * np.pi * np.arange(1 - n, n, 2) / (2.0 * n))
    p = 1.0 / (np.sinh(mu) * pp.real + 1j * np.cosh(mu) * pp.imag)
    k = float(np.real(np.prod(-p) / np.prod(-z)))
    return z, p, k


def ellip_ap(n: int, rp: float, rs: float):
    """Elliptic (Cauer) prototype: equiripple in both bands.

    Given the order and the two ripple figures, the degree equation fixes the
    selectivity k, and with it the stopband edge at 1/k: an elliptic filter
    cannot be asked for all three of order, passband ripple and transition
    width, since any two determine the third.  The poles and zeros then follow
    from the Jacobi functions -- zeros at j/(k cd(u_i K, k)) on the imaginary
    axis, poles at j cd((u_i - j v0) K, k) -- with one extra real pole when the
    order is odd.
    """
    _check_order(n)
    if rp <= 0 or rs <= 0:
        raise IIRError("both ripple figures must be positive")
    if rs <= rp:
        raise IIRError("the stopband attenuation must exceed the passband ripple")
    if n == 1:
        # The degree equation is degenerate at n = 1; a single real pole placed
        # for the wanted ripple is the whole filter.
        eps = np.sqrt(10.0 ** (0.1 * rp) - 1.0)
        p = np.array([-1.0 / eps], dtype=complex)
        return np.array([], dtype=complex), p, float(1.0 / eps)

    eps_p = np.sqrt(10.0 ** (0.1 * rp) - 1.0)
    eps_s = np.sqrt(10.0 ** (0.1 * rs) - 1.0)
    k1 = eps_p / eps_s
    k = _ellipdeg(n, k1)

    ell = n // 2
    ui = (2.0 * np.arange(1, ell + 1) - 1.0) / n
    zeta = _cde(ui, k)
    za = 1j / (k * zeta)

    v0 = float(np.real(-1j * _asne(1j / eps_p, k1) / n))
    pa = 1j * _cde(ui - 1j * v0, k)

    z = np.concatenate([za, np.conjugate(za)])
    p = np.concatenate([pa, np.conjugate(pa)])
    if n % 2:
        p = np.append(p, complex(np.real(1j * _sne(1j * v0, k))))

    gain = float(np.real(np.prod(-p) / np.prod(-z)))
    if n % 2 == 0:
        gain /= np.sqrt(1.0 + eps_p * eps_p)
    return z, p, gain


def _check_order(n):
    if int(n) != n or n < 1:
        raise IIRError("the filter order must be a positive integer")
    if n > 40:
        raise IIRError("orders above 40 are numerically hopeless in double precision")


_PROTOTYPES = {
    "butterworth": lambda n, rp, rs: butter_ap(n),
    "chebyshev1": lambda n, rp, rs: cheb1_ap(n, rp),
    "chebyshev2": lambda n, rp, rs: cheb2_ap(n, rs),
    "elliptic": lambda n, rp, rs: ellip_ap(n, rp, rs),
}


# --------------------------------------------------------------------------
# Analog frequency transformations, in zero-pole-gain form
# --------------------------------------------------------------------------

def _relative_degree(z, p):
    d = len(p) - len(z)
    if d < 0:
        raise IIRError("improper prototype: more zeros than poles")
    return d


def lp2lp_zpk(z, p, k, wo):
    """Scale the prototype so its band edge lands at ``wo``."""
    d = _relative_degree(z, p)
    return z * wo, p * wo, k * wo ** d


def lp2hp_zpk(z, p, k, wo):
    """s -> wo/s: the lowpass turns inside out about ``wo``."""
    d = _relative_degree(z, p)
    zh = wo / z if len(z) else np.array([], dtype=complex)
    ph = wo / p
    zh = np.append(zh, np.zeros(d))        # the reflected poles at infinity
    kh = k * float(np.real(np.prod(-z) / np.prod(-p))) if len(z) \
        else k * float(np.real(1.0 / np.prod(-p)))
    return zh, ph, kh


def lp2bp_zpk(z, p, k, wo, bw):
    """s -> (s^2 + wo^2)/(bw s): each root splits into a pair about ``wo``."""
    d = _relative_degree(z, p)
    zl = z * bw / 2.0
    pl = p * bw / 2.0
    zb = np.concatenate([zl + np.sqrt(zl ** 2 - wo ** 2),
                         zl - np.sqrt(zl ** 2 - wo ** 2)]) if len(z) \
        else np.array([], dtype=complex)
    pb = np.concatenate([pl + np.sqrt(pl ** 2 - wo ** 2),
                         pl - np.sqrt(pl ** 2 - wo ** 2)])
    zb = np.append(zb, np.zeros(d))        # d zeros at DC
    return zb, pb, k * bw ** d


def lp2bs_zpk(z, p, k, wo, bw):
    """s -> (bw s)/(s^2 + wo^2): the highpass equivalent of :func:`lp2bp_zpk`."""
    d = _relative_degree(z, p)
    zh = (bw / 2.0) / z if len(z) else np.array([], dtype=complex)
    ph = (bw / 2.0) / p
    zb = np.concatenate([zh + np.sqrt(zh ** 2 - wo ** 2),
                         zh - np.sqrt(zh ** 2 - wo ** 2)]) if len(z) \
        else np.array([], dtype=complex)
    pb = np.concatenate([ph + np.sqrt(ph ** 2 - wo ** 2),
                         ph - np.sqrt(ph ** 2 - wo ** 2)])
    # The poles that went to infinity come back as zeros at +-j wo.
    zb = np.append(zb, np.full(d, +1j * wo))
    zb = np.append(zb, np.full(d, -1j * wo))
    kb = k * float(np.real(np.prod(-z) / np.prod(-p))) if len(z) \
        else k * float(np.real(1.0 / np.prod(-p)))
    return zb, pb, kb


def bilinear_zpk(z, p, k, fs):
    """Map the analog design onto the unit disc: s = 2 fs (1 - z^-1)/(1 + z^-1)."""
    d = _relative_degree(z, p)
    fs2 = 2.0 * fs
    zd = (fs2 + z) / (fs2 - z) if len(z) else np.array([], dtype=complex)
    pd = (fs2 + p) / (fs2 - p)
    zd = np.append(zd, -np.ones(d))        # infinity maps to Nyquist
    num = np.prod(fs2 - z) if len(z) else 1.0
    kd = k * float(np.real(num / np.prod(fs2 - p)))
    return zd, pd, kd


def prewarp(f, fs):
    """Analog frequency whose bilinear image is the digital frequency ``f``."""
    f = np.asarray(f, dtype=float)
    if np.any(f <= 0) or np.any(f >= fs / 2.0):
        raise IIRError(f"every band edge must lie strictly between 0 and fs/2 ({fs / 2:g})")
    return 2.0 * fs * np.tan(np.pi * f / fs)


# --------------------------------------------------------------------------
# Second-order sections
# --------------------------------------------------------------------------

def _pop_conjugate_pair(roots, first):
    """Take ``first`` out of ``roots`` together with its partner.

    A complex root leaves with its conjugate; a real one with the nearest other
    real root, so that every section comes out with real coefficients.  The
    counts always work: complex roots arrive in conjugate pairs, so whatever is
    left over is real and even in number.
    """
    if abs(first.imag) > 1e-12 * max(1.0, abs(first)):
        j = int(np.argmin(np.abs(np.array(roots) - np.conjugate(first))))
        return roots.pop(j)
    reals = [i for i, r in enumerate(roots) if abs(r.imag) <= 1e-12 * max(1.0, abs(r))]
    if not reals:
        raise IIRError("cannot pair the roots into real second-order sections")
    j = min(reals, key=lambda i: abs(roots[i] - first))
    return roots.pop(j)


def zpk_to_sos(z, p, k):
    """Group a digital zero-pole-gain description into second-order sections.

    Sections are formed by taking the pole pair furthest inside the unit circle
    first and giving it the nearest available zero pair, which keeps each
    section's gain as flat as the pattern allows.  The ordering that falls out
    -- the sharpest, closest-to-the-circle pole pair last -- is the usual one
    for cascade implementation, since it delays the biggest internal peak until
    after the earlier sections have already attenuated whatever it would ring
    on.
    """
    z = list(np.atleast_1d(np.asarray(z, dtype=complex)))
    p = list(np.atleast_1d(np.asarray(p, dtype=complex)))
    if len(z) > len(p):
        raise IIRError("improper filter: more zeros than poles")
    z += [0j] * (len(p) - len(z))
    if len(p) % 2:                      # an extra pole and zero at the origin
        z.append(0j)                    # cancel, and make the order even
        p.append(0j)
    if not p:
        return np.array([[k, 0.0, 0.0, 1.0, 0.0, 0.0]])

    sos = []
    while p:
        i = int(np.argmin(np.abs(np.array(p))))       # furthest inside the circle
        p1 = p.pop(i)
        p2 = _pop_conjugate_pair(p, p1)
        j = int(np.argmin(np.abs(np.array(z) - p1)))
        z1 = z.pop(j)
        z2 = _pop_conjugate_pair(z, z1)
        b = np.real(np.poly([z1, z2]))
        a = np.real(np.poly([p1, p2]))
        sos.append(np.concatenate([b, a]))

    out = np.array(sos)
    out[0, :3] *= k
    return out


def sos_freqz(sos, w):
    """Frequency response of a cascade at the digital frequencies ``w`` (rad/sample)."""
    zi = np.exp(-1j * np.asarray(w, dtype=float))
    h = np.ones_like(zi)
    for b0, b1, b2, a0, a1, a2 in np.atleast_2d(sos):
        h = h * (b0 + b1 * zi + b2 * zi * zi) / (a0 + a1 * zi + a2 * zi * zi)
    return h


def sos_filter(sos, x):
    """Run a signal through the cascade, transposed direct form II per section."""
    y = np.asarray(x, dtype=float).copy()
    for b0, b1, b2, a0, a1, a2 in np.atleast_2d(sos):
        b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
        out = np.empty_like(y)
        s1 = s2 = 0.0
        for i, v in enumerate(y):
            o = b0 * v + s1
            s1 = b1 * v - a1 * o + s2
            s2 = b2 * v - a2 * o
            out[i] = o
        y = out
    return y


def sos_impulse(sos, n):
    """First ``n`` samples of the impulse response."""
    x = np.zeros(int(n))
    x[0] = 1.0
    return sos_filter(sos, x)


def group_delay(sos, w):
    """Group delay in samples, by differentiating the unwrapped phase.

    The response is sampled a little either side of each requested point rather
    than differencing the plotted curve, so the answer does not depend on how
    finely the plot happens to be drawn.
    """
    w = np.asarray(w, dtype=float)
    h = 1e-5
    ph = np.unwrap(np.angle(sos_freqz(sos, np.clip(w + h, 0.0, np.pi))))
    pl = np.unwrap(np.angle(sos_freqz(sos, np.clip(w - h, 0.0, np.pi))))
    return -(ph - pl) / (2.0 * h)


# --------------------------------------------------------------------------
# Order estimation
# --------------------------------------------------------------------------

def _lowpass_ratio(response, wp, ws):
    """Normalised stopband edge of the equivalent analog lowpass problem.

    Every response type is designed by transforming a lowpass whose passband
    edge is 1 rad/s, so what governs the order is where the stopband lands
    after that same transformation.  For the two band responses the transform
    is geometrically symmetric about the band centre while the requested edges
    generally are not, so both stopband edges are mapped and the harder of the
    two -- the one closer to 1 -- decides.
    """
    if response == "lowpass":
        return ws[0] / wp[0]
    if response == "highpass":
        return wp[0] / ws[0]
    wo2 = wp[0] * wp[1]
    bw = wp[1] - wp[0]
    if response == "bandpass":
        return float(min(abs((w * w - wo2) / (w * bw)) for w in ws))
    return float(min(abs(w * bw / (w * w - wo2)) for w in ws))


def estimate_order(approximation, response, wp, ws, rp, rs):
    """Smallest order meeting the specification, in *analog* (pre-warped) units."""
    ratio = _lowpass_ratio(response, np.atleast_1d(wp), np.atleast_1d(ws))
    if ratio <= 1.0:
        raise IIRError("the stopband edges must lie outside the passband edges")
    gp = 10.0 ** (0.1 * rp) - 1.0
    gs = 10.0 ** (0.1 * rs) - 1.0
    if gs <= gp:
        raise IIRError("the stopband attenuation must exceed the passband ripple")

    if approximation == "butterworth":
        n = np.log10(gs / gp) / (2.0 * np.log10(ratio))
    elif approximation in ("chebyshev1", "chebyshev2"):
        n = np.arccosh(np.sqrt(gs / gp)) / np.arccosh(ratio)
    else:
        k = 1.0 / ratio                       # selectivity
        k1 = np.sqrt(gp / gs)                 # discrimination
        n = (ellipk(k) * _ellipk_kc(k1)) / (_ellipk_kc(k) * ellipk(k1))
    return max(1, int(np.ceil(n - 1e-12)))


# --------------------------------------------------------------------------
# Result
# --------------------------------------------------------------------------

@dataclass
class IIRResult:
    """Everything the design produced, for both use and display."""

    z: np.ndarray                  # digital zeros
    p: np.ndarray                  # digital poles
    k: float                       # digital overall gain
    sos: np.ndarray                # (nsections, 6): b0 b1 b2 a0 a1 a2
    order: int                     # prototype order
    degree: int                    # order of the digital filter itself
    response: str
    approximation: str
    fs: float
    wp: tuple                      # requested passband edge(s)
    ws: tuple                      # requested stopband edge(s)
    rp: float                      # requested passband ripple, dB
    rs: float                      # requested stopband attenuation, dB
    wn: tuple                      # critical frequencies actually placed
    order_estimate: int            # smallest order that meets the spec
    auto_order: bool
    achieved_rp: float             # peak-to-peak passband ripple, dB
    achieved_rs: float             # worst stopband attenuation, dB
    max_pole_radius: float
    stable: bool
    passband_ranges: list = field(default_factory=list)
    stopband_ranges: list = field(default_factory=list)

    def response_at(self, f):
        """Complex frequency response at physical frequencies ``f``."""
        return sos_freqz(self.sos, 2.0 * np.pi * np.asarray(f, dtype=float) / self.fs)

    @property
    def meets_spec(self) -> bool:
        return (self.achieved_rp <= self.rp * 1.0001 + 1e-9
                and self.achieved_rs >= self.rs - 1e-4)


# --------------------------------------------------------------------------
# Main entry point
# --------------------------------------------------------------------------

def _bands(response, wp, ws, fs):
    """Physical frequency ranges of the pass and stop regions, for spec checks."""
    nyq = fs / 2.0
    if response == "lowpass":
        return [(0.0, wp[0])], [(ws[0], nyq)]
    if response == "highpass":
        return [(wp[0], nyq)], [(0.0, ws[0])]
    if response == "bandpass":
        return [(wp[0], wp[1])], [(0.0, ws[0]), (ws[1], nyq)]
    return [(0.0, wp[0]), (wp[1], nyq)], [(ws[0], ws[1])]


def _check_edges(response, wp, ws, fs):
    """Validate the edge ordering for the requested response."""
    nyq = fs / 2.0
    need = 2 if response in ("bandpass", "bandstop") else 1
    if len(wp) != need or len(ws) != need:
        raise IIRError(f"a {response} needs {need} passband and {need} stopband edge"
                       f"{'s' if need > 1 else ''}")
    for name, edges in (("passband", wp), ("stopband", ws)):
        for w in edges:
            if not (0.0 < w < nyq):
                raise IIRError(f"{name} edge {w:g} must lie strictly between 0 and "
                               f"fs/2 ({nyq:g})")
    if response == "lowpass":
        if not wp[0] < ws[0]:
            raise IIRError("the stopband edge must be above the passband edge")
    elif response == "highpass":
        if not ws[0] < wp[0]:
            raise IIRError("the stopband edge must be below the passband edge")
    elif response == "bandpass":
        if not ws[0] < wp[0] < wp[1] < ws[1]:
            raise IIRError("a bandpass needs fs1 < fp1 < fp2 < fs2")
    else:
        if not wp[0] < ws[0] < ws[1] < wp[1]:
            raise IIRError("a bandstop needs fp1 < fs1 < fs2 < fp2")


def design(response: str,
           approximation: str,
           *,
           wp,
           ws,
           rp: float = 1.0,
           rs: float = 40.0,
           order=None,
           fs: float = 1.0,
           npoints: int = 4096) -> IIRResult:
    """Design a digital IIR filter from a band specification.

    Parameters
    ----------
    response : ``"lowpass"``, ``"highpass"``, ``"bandpass"`` or ``"bandstop"``.
    approximation : ``"butterworth"``, ``"chebyshev1"``, ``"chebyshev2"`` or
        ``"elliptic"``.
    wp, ws : passband and stopband edges in units of ``fs``; one each for a
        lowpass or highpass, two each (low, high) for a bandpass or bandstop.
    rp : peak-to-peak passband ripple in dB.
    rs : stopband attenuation in dB.
    order : prototype order, or ``None`` to use the smallest order that meets
        the specification.
    fs : sampling frequency.

    The filter is placed so that the edge each approximation defines exactly --
    the passband edge, except for Chebyshev II, which is defined by where its
    stopband begins -- falls on the requested frequency.  For Butterworth the
    natural frequency is pulled in from the passband edge so that the passband
    ripple is met exactly there rather than at the conventional -3 dB point.
    """
    if response not in RESPONSES:
        raise IIRError(f"unknown response {response!r}")
    if approximation not in APPROXIMATIONS:
        raise IIRError(f"unknown approximation {approximation!r}")
    if fs <= 0:
        raise IIRError("the sample rate must be positive")

    wp = tuple(float(v) for v in np.atleast_1d(wp))
    ws = tuple(float(v) for v in np.atleast_1d(ws))
    _check_edges(response, wp, ws, fs)
    if rp <= 0:
        raise IIRError("the passband ripple must be positive")
    if rs <= rp:
        raise IIRError("the stopband attenuation must exceed the passband ripple")

    awp = prewarp(np.array(wp), fs)
    aws = prewarp(np.array(ws), fs)
    estimate = estimate_order(approximation, response, awp, aws, rp, rs)
    auto = order is None
    n = estimate if auto else int(order)
    if n < 1:
        raise IIRError("the filter order must be at least 1")

    z, p, k = _PROTOTYPES[approximation](n, rp, rs)

    if approximation == "butterworth":
        # A Butterworth prototype has no ripple to pin an edge to, so it is
        # normalised at its -3 dB point.  Widening it until the response is
        # exactly rp dB down at 1 rad/s puts it on the same footing as the
        # other three, and the transformations below then place that edge on
        # the requested band edge whatever the response type.
        z, p, k = lp2lp_zpk(z, p, k, (10.0 ** (0.1 * rp) - 1.0) ** (-1.0 / (2.0 * n)))

    # Denormalise onto the edge this approximation actually pins down.
    edges = aws if _CRITICAL_EDGE[approximation] == "stopband" else awp

    if response == "lowpass":
        z, p, k = lp2lp_zpk(z, p, k, edges[0])
    elif response == "highpass":
        z, p, k = lp2hp_zpk(z, p, k, edges[0])
    else:
        wo = np.sqrt(edges[0] * edges[1])
        bw = edges[1] - edges[0]
        if response == "bandpass":
            z, p, k = lp2bp_zpk(z, p, k, wo, bw)
        else:
            z, p, k = lp2bs_zpk(z, p, k, wo, bw)

    z, p, k = bilinear_zpk(z, p, k, fs)
    sos = zpk_to_sos(z, p, k)

    # Achieved specification, measured on a dense grid of each region.
    pass_ranges, stop_ranges = _bands(response, wp, ws, fs)
    achieved_rp = _band_ripple(sos, pass_ranges, fs, npoints)
    achieved_rs = _band_attenuation(sos, stop_ranges, fs, npoints)

    radius = float(np.max(np.abs(p))) if len(p) else 0.0
    wn = tuple(float(v) for v in (fs / np.pi * np.arctan(edges / (2.0 * fs))))

    return IIRResult(
        z=np.asarray(z), p=np.asarray(p), k=float(k), sos=sos,
        order=n, degree=len(p),
        response=response, approximation=approximation, fs=fs,
        wp=wp, ws=ws, rp=rp, rs=rs, wn=wn,
        order_estimate=estimate, auto_order=auto,
        achieved_rp=achieved_rp, achieved_rs=achieved_rs,
        max_pole_radius=radius, stable=radius < 1.0,
        passband_ranges=pass_ranges, stopband_ranges=stop_ranges,
    )


def _region_grid(ranges, fs, npoints):
    """Dense frequency samples over a list of (f1, f2) regions."""
    total = sum(max(b - a, 0.0) for a, b in ranges) or 1.0
    out = []
    for a, b in ranges:
        if b <= a:
            continue
        m = max(16, int(npoints * (b - a) / total))
        out.append(np.linspace(a, b, m))
    return np.concatenate(out) if out else np.array([])


def _band_ripple(sos, ranges, fs, npoints):
    """Peak-to-peak variation in dB over the passband regions."""
    f = _region_grid(ranges, fs, npoints)
    if f.size == 0:
        return 0.0
    mag = np.abs(sos_freqz(sos, 2.0 * np.pi * f / fs))
    lo = float(np.min(mag))
    hi = float(np.max(mag))
    if lo <= 0.0:
        return np.inf
    return 20.0 * np.log10(hi / lo)


def _band_attenuation(sos, ranges, fs, npoints):
    """Worst attenuation in dB over the stopband regions, relative to unit gain."""
    f = _region_grid(ranges, fs, npoints)
    if f.size == 0:
        return np.inf
    mag = np.abs(sos_freqz(sos, 2.0 * np.pi * f / fs))
    peak = float(np.max(mag))
    if peak <= 0.0:
        return np.inf
    return -20.0 * np.log10(peak)
