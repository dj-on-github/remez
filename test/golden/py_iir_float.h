/* Chebyshev I lowpass, order 6, fs = 1, 0.5 dB / 40 dB */
/* double precision coefficients */
/* cascade of 3 biquads, each y = b0 x + b1 x' + b2 x'' - a1 y' - a2 y'' */
#define IIR_SECTIONS 3
static const double iir_sos[IIR_SECTIONS][6] = {
    { 0.0032680951535364595,  0.0065361903070729191,  0.0032680951535364595,  1, -1.2196088097398083,  0.44002108382886329},
    { 1,  2,  1,  1, -0.85022082446685121,  0.61935960991249062},
    { 1,  2,  1,  1, -0.55659410455683711,  0.86346949342772883},
};

