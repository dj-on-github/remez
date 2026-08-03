/* Chebyshev I lowpass, order 6, fs = 1, 0.5 dB / 40 dB */
/* 16-bit fixed point, Q2.13: value = integer * 2^-13 */
/* cascade of 3 biquads, each y = b0 x + b1 x' + b2 x'' - a1 y' - a2 y'' */
#define IIR_SECTIONS 3
#define IIR_FRAC_BITS 13
static const long iir_sos_q[IIR_SECTIONS][6] = {
    {27, 54, 27, 8192, -9991, 3605},
    {8192, 16384, 8192, 8192, -6965, 5074},
    {8192, 16384, 8192, 8192, -4560, 7074},
};

static const double iir_sos[IIR_SECTIONS][6] = {
    { 0.0032958984375,  0.006591796875,  0.0032958984375,  1, -1.2196044921875,  0.4400634765625},
    { 1,  2,  1,  1, -0.8502197265625,  0.619384765625},
    { 1,  2,  1,  1, -0.556640625,  0.863525390625},
};

