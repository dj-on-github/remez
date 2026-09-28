/*
 * Compute the frequency spectrum of a sequence of 64 bit floats.
 *
 *     spectrumf64 [-h] [-o plot.png] [-n max_frequency] [-w [-s segment_length]] [infile]
 *
 * Input is headerless doubles in the machine's native byte order, the
 * format written by wavtof64.py and randomf64 -b, read from infile or from
 * stdin when no file is named. The samples are zero padded up to the next
 * power of two and transformed with a radix-2 FFT.
 *
 * Because the input is real, the upper half of the FFT is the complex
 * conjugate mirror of the lower half, so only bins 0 to N/2 are reported.
 * Bin N/2 is the Nyquist frequency, which is labelled max_frequency
 * (1.0 unless -n is given). To read the axis in Hz, pass half the sample
 * rate, e.g. -n 22050 for 44.1 kHz audio.
 *
 * With -o the magnitude spectrum, in dB, is drawn to a PNG file. Without
 * it, one line per bin is written to stdout: frequency, real, imaginary.
 *
 * With -w the spectrum is instead estimated by Welch's method: the input is
 * cut into segments of segment_length samples (default 1024, rounded up to a
 * power of two) overlapping by half, each is multiplied by a Hann window and
 * transformed, and the squared magnitudes are averaged. This trades
 * frequency resolution for a much smoother, lower variance estimate. The
 * result is power per bin divided by the window's energy, so white noise of
 * variance v comes out flat at v. Phase does not survive the averaging, so
 * the text output is two columns: frequency, power. Samples after the last
 * whole segment are not used.
 *
 * Compile with:  cc -O2 -o spectrumf64 spectrumf64.c -lz -lm
 */

#include <complex.h>
#include <errno.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <zlib.h>

/* Plot geometry, in pixels. */
#define IMG_W        1200
#define IMG_H        700
#define MARGIN_L     110
#define MARGIN_R     30
#define MARGIN_T     60
#define MARGIN_B     90
#define FONT_SCALE   2

/* Most dB shown below the peak. */
#define DB_RANGE     140.0

#define DEFAULT_SEGMENT 1024

static const char *prog;

static void usage(void) {
    fprintf(stderr,
        "Usage: %s [-h] [-o <filename.png>] [-n <max_frequency>] [-w [-s <segment_length>]] [infile]\n"
        "  -h                    Print this help and exit\n"
        "  -o <filename.png>     Draw the magnitude spectrum to a PNG file\n"
        "                        (without -o, print frequency, real, imaginary as text)\n"
        "  -n <max_frequency>    Frequency of the Nyquist bin, in Hz (default 1)\n"
        "  -w                    Average the power spectra of Hann windowed, half\n"
        "                        overlapping segments (Welch's method); the text\n"
        "                        output is then frequency, power\n"
        "  -s <segment_length>   Welch segment length in samples, rounded up to a\n"
        "                        power of two (default %d; requires -w)\n"
        "  infile                File of binary f64 samples (default stdin)\n",
        prog, DEFAULT_SEGMENT);
}

/* ---------------------------------------------------------------- input */

static double *read_samples(FILE *in, const char *name, size_t *count) {
    size_t cap = 1 << 16;
    size_t n = 0;
    size_t got;
    double *buf = malloc(cap * sizeof *buf);
    unsigned char partial[sizeof(double)];
    size_t leftover;

    if (buf == NULL) {
        fprintf(stderr, "%s: out of memory\n", prog);
        exit(1);
    }
    for (;;) {
        if (n == cap) {
            double *nb;
            cap *= 2;
            nb = realloc(buf, cap * sizeof *buf);
            if (nb == NULL) {
                fprintf(stderr, "%s: out of memory\n", prog);
                exit(1);
            }
            buf = nb;
        }
        got = fread(buf + n, sizeof *buf, cap - n, in);
        n += got;
        if (got == 0 || feof(in) || ferror(in)) break;
    }
    if (ferror(in)) {
        fprintf(stderr, "%s: error reading %s: %s\n", prog, name, strerror(errno));
        exit(1);
    }
    /* fread discards a trailing partial item; see whether there was one. */
    leftover = fread(partial, 1, sizeof partial, in);
    if (leftover != 0) {
        fprintf(stderr, "%s: warning: ignoring %zu trailing bytes in %s\n",
                prog, leftover, name);
    }
    *count = n;
    return buf;
}

/* ------------------------------------------------------------------ FFT */

/* In place iterative radix-2 FFT. n must be a power of two. */
static void fft(double complex *x, size_t n) {
    size_t i, j, k, len, half, step;
    double complex *tw;
    double complex t, u, v;

    if (n < 2) return;

    /* Bit reversal permutation. */
    for (i = 1, j = 0; i < n; i++) {
        size_t bit = n >> 1;
        for (; j & bit; bit >>= 1) j ^= bit;
        j ^= bit;
        if (i < j) {
            t = x[i];
            x[i] = x[j];
            x[j] = t;
        }
    }

    /* Twiddle factors, each computed directly for accuracy. */
    tw = malloc((n / 2) * sizeof *tw);
    if (tw == NULL) {
        fprintf(stderr, "%s: out of memory\n", prog);
        exit(1);
    }
    for (k = 0; k < n / 2; k++) {
        double a = -2.0 * M_PI * (double)k / (double)n;
        tw[k] = cos(a) + I * sin(a);
    }

    for (len = 2; len <= n; len <<= 1) {
        half = len / 2;
        step = n / len;
        for (i = 0; i < n; i += len) {
            for (k = 0; k < half; k++) {
                u = x[i + k];
                v = x[i + k + half] * tw[k * step];
                x[i + k] = u + v;
                x[i + k + half] = u - v;
            }
        }
    }
    free(tw);
}

/* Smallest power of two >= n, or 0 if that is too large to allocate. */
static size_t pow2_at_least(size_t n) {
    size_t p = 1;
    while (p < n) {
        if (p > SIZE_MAX / 2 / sizeof(double complex)) return 0;
        p <<= 1;
    }
    return p;
}

/* Welch's method. Returns fftsize / 2 + 1 bins of power, averaged over
   Hann windowed segments of seglen samples overlapping by half, and
   normalised by the window energy. */
static double *welch(const double *x, size_t n, size_t seglen,
                     size_t *fftsize_out, size_t *nsegs_out) {
    size_t fftsize, nbins, hop, nsegs, s, i, k;
    double *w, *power, wsum = 0.0;
    double complex *X;

    if (seglen > n) seglen = n;
    fftsize = pow2_at_least(seglen);
    nbins = fftsize > 1 ? fftsize / 2 + 1 : 1;
    hop = seglen / 2 > 0 ? seglen / 2 : 1;
    nsegs = (n - seglen) / hop + 1;

    w = malloc(seglen * sizeof *w);
    power = calloc(nbins, sizeof *power);
    X = malloc(fftsize * sizeof *X);
    if (w == NULL || power == NULL || X == NULL) {
        fprintf(stderr, "%s: out of memory\n", prog);
        exit(1);
    }

    /* Periodic Hann window. A single sample gets a window of 1. */
    for (i = 0; i < seglen; i++) {
        w[i] = seglen > 1 ? 0.5 - 0.5 * cos(2.0 * M_PI * (double)i / (double)seglen) : 1.0;
        wsum += w[i] * w[i];
    }

    for (s = 0; s < nsegs; s++) {
        const double *seg = x + s * hop;
        for (i = 0; i < seglen; i++) X[i] = seg[i] * w[i];
        for (; i < fftsize; i++) X[i] = 0.0;
        fft(X, fftsize);
        for (k = 0; k < nbins; k++) {
            double re = creal(X[k]), im = cimag(X[k]);
            power[k] += re * re + im * im;
        }
    }
    for (k = 0; k < nbins; k++) power[k] /= (double)nsegs * wsum;

    free(w);
    free(X);
    *fftsize_out = fftsize;
    *nsegs_out = nsegs;
    return power;
}

/* ---------------------------------------------------------------- image */

typedef struct {
    int w, h;
    unsigned char *px;      /* RGB, row major */
} image;

typedef struct { unsigned char r, g, b; } color;

static const color BLACK = {   0,   0,   0 };
static const color GRID  = { 220, 220, 220 };
static const color TRACE = {  20,  80, 200 };

static void set_px(image *im, int x, int y, color c) {
    unsigned char *p;
    if (x < 0 || y < 0 || x >= im->w || y >= im->h) return;
    p = im->px + 3 * ((size_t)y * im->w + x);
    p[0] = c.r;
    p[1] = c.g;
    p[2] = c.b;
}

static void vline(image *im, int x, int y0, int y1, color c) {
    int y;
    if (y0 > y1) { int t = y0; y0 = y1; y1 = t; }
    for (y = y0; y <= y1; y++) set_px(im, x, y, c);
}

static void hline(image *im, int x0, int x1, int y, color c) {
    int x;
    if (x0 > x1) { int t = x0; x0 = x1; x1 = t; }
    for (x = x0; x <= x1; x++) set_px(im, x, y, c);
}

static void line(image *im, int x0, int y0, int x1, int y1, color c) {
    int dx = abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
    int dy = -abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
    int err = dx + dy, e2;

    for (;;) {
        set_px(im, x0, y0, c);
        if (x0 == x1 && y0 == y1) break;
        e2 = 2 * err;
        if (e2 >= dy) { err += dy; x0 += sx; }
        if (e2 <= dx) { err += dx; y0 += sy; }
    }
}

/* Classic 5x8 font, ASCII 32 to 126. Each byte is one column, LSB at top. */
static const unsigned char font5x8[95][5] = {
    {0x00,0x00,0x00,0x00,0x00}, {0x00,0x00,0x5F,0x00,0x00}, {0x00,0x07,0x00,0x07,0x00},
    {0x14,0x7F,0x14,0x7F,0x14}, {0x24,0x2A,0x7F,0x2A,0x12}, {0x23,0x13,0x08,0x64,0x62},
    {0x36,0x49,0x56,0x20,0x50}, {0x00,0x08,0x07,0x03,0x00}, {0x00,0x1C,0x22,0x41,0x00},
    {0x00,0x41,0x22,0x1C,0x00}, {0x2A,0x1C,0x7F,0x1C,0x2A}, {0x08,0x08,0x3E,0x08,0x08},
    {0x00,0x80,0x70,0x30,0x00}, {0x08,0x08,0x08,0x08,0x08}, {0x00,0x00,0x60,0x60,0x00},
    {0x20,0x10,0x08,0x04,0x02}, {0x3E,0x51,0x49,0x45,0x3E}, {0x00,0x42,0x7F,0x40,0x00},
    {0x72,0x49,0x49,0x49,0x46}, {0x21,0x41,0x49,0x4D,0x33}, {0x18,0x14,0x12,0x7F,0x10},
    {0x27,0x45,0x45,0x45,0x39}, {0x3C,0x4A,0x49,0x49,0x31}, {0x41,0x21,0x11,0x09,0x07},
    {0x36,0x49,0x49,0x49,0x36}, {0x46,0x49,0x49,0x29,0x1E}, {0x00,0x00,0x14,0x00,0x00},
    {0x00,0x40,0x34,0x00,0x00}, {0x00,0x08,0x14,0x22,0x41}, {0x14,0x14,0x14,0x14,0x14},
    {0x00,0x41,0x22,0x14,0x08}, {0x02,0x01,0x59,0x09,0x06}, {0x3E,0x41,0x5D,0x59,0x4E},
    {0x7C,0x12,0x11,0x12,0x7C}, {0x7F,0x49,0x49,0x49,0x36}, {0x3E,0x41,0x41,0x41,0x22},
    {0x7F,0x41,0x41,0x41,0x3E}, {0x7F,0x49,0x49,0x49,0x41}, {0x7F,0x09,0x09,0x09,0x01},
    {0x3E,0x41,0x41,0x51,0x73}, {0x7F,0x08,0x08,0x08,0x7F}, {0x00,0x41,0x7F,0x41,0x00},
    {0x20,0x40,0x41,0x3F,0x01}, {0x7F,0x08,0x14,0x22,0x41}, {0x7F,0x40,0x40,0x40,0x40},
    {0x7F,0x02,0x1C,0x02,0x7F}, {0x7F,0x04,0x08,0x10,0x7F}, {0x3E,0x41,0x41,0x41,0x3E},
    {0x7F,0x09,0x09,0x09,0x06}, {0x3E,0x41,0x51,0x21,0x5E}, {0x7F,0x09,0x19,0x29,0x46},
    {0x26,0x49,0x49,0x49,0x32}, {0x03,0x01,0x7F,0x01,0x03}, {0x3F,0x40,0x40,0x40,0x3F},
    {0x1F,0x20,0x40,0x20,0x1F}, {0x3F,0x40,0x38,0x40,0x3F}, {0x63,0x14,0x08,0x14,0x63},
    {0x03,0x04,0x78,0x04,0x03}, {0x61,0x59,0x49,0x4D,0x43}, {0x00,0x7F,0x41,0x41,0x41},
    {0x02,0x04,0x08,0x10,0x20}, {0x00,0x41,0x41,0x41,0x7F}, {0x04,0x02,0x01,0x02,0x04},
    {0x40,0x40,0x40,0x40,0x40}, {0x00,0x03,0x07,0x08,0x00}, {0x20,0x54,0x54,0x78,0x40},
    {0x7F,0x28,0x44,0x44,0x38}, {0x38,0x44,0x44,0x44,0x28}, {0x38,0x44,0x44,0x28,0x7F},
    {0x38,0x54,0x54,0x54,0x18}, {0x00,0x08,0x7E,0x09,0x02}, {0x18,0xA4,0xA4,0x9C,0x78},
    {0x7F,0x08,0x04,0x04,0x78}, {0x00,0x44,0x7D,0x40,0x00}, {0x20,0x40,0x40,0x3D,0x00},
    {0x7F,0x10,0x28,0x44,0x00}, {0x00,0x41,0x7F,0x40,0x00}, {0x7C,0x04,0x78,0x04,0x78},
    {0x7C,0x08,0x04,0x04,0x78}, {0x38,0x44,0x44,0x44,0x38}, {0xFC,0x18,0x24,0x24,0x18},
    {0x18,0x24,0x24,0x18,0xFC}, {0x7C,0x08,0x04,0x04,0x08}, {0x48,0x54,0x54,0x54,0x24},
    {0x04,0x04,0x3F,0x44,0x24}, {0x3C,0x40,0x40,0x20,0x7C}, {0x1C,0x20,0x40,0x20,0x1C},
    {0x3C,0x40,0x30,0x40,0x3C}, {0x44,0x28,0x10,0x28,0x44}, {0x4C,0x90,0x90,0x90,0x7C},
    {0x44,0x64,0x54,0x4C,0x44}, {0x00,0x08,0x36,0x41,0x00}, {0x00,0x00,0x77,0x00,0x00},
    {0x00,0x41,0x36,0x08,0x00}, {0x02,0x01,0x02,0x04,0x02},
};

#define CHAR_W (6 * FONT_SCALE)     /* 5 columns plus 1 of spacing */
#define CHAR_H (8 * FONT_SCALE)

static int text_width(const char *s) {
    return (int)strlen(s) * CHAR_W - FONT_SCALE;
}

static void draw_char(image *im, int x, int y, char ch, color c, int vertical) {
    int col, row, sx, sy;
    unsigned char bits;

    if (ch < 32 || ch > 126) ch = '?';
    for (col = 0; col < 5; col++) {
        bits = font5x8[ch - 32][col];
        for (row = 0; row < 8; row++) {
            if (!(bits & (1 << row))) continue;
            for (sx = 0; sx < FONT_SCALE; sx++) {
                for (sy = 0; sy < FONT_SCALE; sy++) {
                    int px = col * FONT_SCALE + sx;
                    int py = row * FONT_SCALE + sy;
                    if (vertical)   /* rotated 90 degrees anticlockwise */
                        set_px(im, x + py, y - px, c);
                    else
                        set_px(im, x + px, y + py, c);
                }
            }
        }
    }
}

/* Draw s with its top left corner at (x, y), or reading bottom to top
   starting at (x, y) when vertical. */
static void draw_text(image *im, int x, int y, const char *s, color c, int vertical) {
    for (; *s; s++) {
        draw_char(im, x, y, *s, c, vertical);
        if (vertical) y -= CHAR_W; else x += CHAR_W;
    }
}

static void png_chunk(FILE *f, const char *type, const unsigned char *data, uint32_t len) {
    unsigned char hdr[8];
    unsigned char crcb[4];
    uLong crc;

    hdr[0] = len >> 24; hdr[1] = len >> 16; hdr[2] = len >> 8; hdr[3] = len;
    memcpy(hdr + 4, type, 4);
    crc = crc32(0L, (const Bytef *)type, 4);
    if (len) crc = crc32(crc, data, len);
    crcb[0] = crc >> 24; crcb[1] = crc >> 16; crcb[2] = crc >> 8; crcb[3] = crc;
    fwrite(hdr, 1, 8, f);
    if (len) fwrite(data, 1, len, f);
    fwrite(crcb, 1, 4, f);
}

static int write_png(const image *im, const char *filename) {
    static const unsigned char sig[8] = { 0x89, 'P', 'N', 'G', '\r', '\n', 0x1A, '\n' };
    unsigned char ihdr[13];
    size_t stride = 3 * (size_t)im->w;
    size_t rawlen = (stride + 1) * im->h;
    unsigned char *raw = malloc(rawlen);
    uLongf zlen = compressBound(rawlen);
    unsigned char *z = malloc(zlen);
    FILE *f;
    int y, ok;

    if (raw == NULL || z == NULL) {
        fprintf(stderr, "%s: out of memory\n", prog);
        exit(1);
    }
    for (y = 0; y < im->h; y++) {
        raw[y * (stride + 1)] = 0;      /* filter type: none */
        memcpy(raw + y * (stride + 1) + 1, im->px + y * stride, stride);
    }
    if (compress2(z, &zlen, raw, rawlen, Z_BEST_COMPRESSION) != Z_OK) {
        fprintf(stderr, "%s: compression failed\n", prog);
        exit(1);
    }

    f = fopen(filename, "wb");
    if (f == NULL) {
        fprintf(stderr, "%s: cannot open %s: %s\n", prog, filename, strerror(errno));
        free(raw);
        free(z);
        return 0;
    }
    ihdr[0] = im->w >> 24; ihdr[1] = im->w >> 16; ihdr[2] = im->w >> 8; ihdr[3] = im->w;
    ihdr[4] = im->h >> 24; ihdr[5] = im->h >> 16; ihdr[6] = im->h >> 8; ihdr[7] = im->h;
    ihdr[8] = 8;        /* bit depth */
    ihdr[9] = 2;        /* colour type: RGB */
    ihdr[10] = 0;       /* compression */
    ihdr[11] = 0;       /* filter */
    ihdr[12] = 0;       /* no interlace */

    fwrite(sig, 1, sizeof sig, f);
    png_chunk(f, "IHDR", ihdr, sizeof ihdr);
    png_chunk(f, "IDAT", z, (uint32_t)zlen);
    png_chunk(f, "IEND", NULL, 0);

    ok = !ferror(f);
    if (fclose(f) != 0) ok = 0;
    if (!ok) fprintf(stderr, "%s: error writing %s: %s\n", prog, filename, strerror(errno));
    free(raw);
    free(z);
    return ok;
}

/* ----------------------------------------------------------------- plot */

/* A tick spacing of 1, 2 or 5 times a power of ten giving about want ticks. */
static double nice_step(double range, int want) {
    double raw = range / want;
    double mag = pow(10.0, floor(log10(raw)));
    double r = raw / mag;
    if (r < 1.5) return mag;
    if (r < 3.5) return 2 * mag;
    if (r < 7.5) return 5 * mag;
    return 10 * mag;
}

/* Plot db[0 .. nbins-1], bin nbins-1 being at maxf. */
static void plot_spectrum(const double *db, size_t nbins, double maxf,
                          const char *name, const char *subtitle,
                          const char *ylabel, const char *filename) {
    image im;
    int pw = IMG_W - MARGIN_L - MARGIN_R;
    int ph = IMG_H - MARGIN_T - MARGIN_B;
    int x0 = MARGIN_L, y0 = MARGIN_T, x1 = MARGIN_L + pw - 1, y1 = MARGIN_T + ph - 1;
    double dbmax = -INFINITY, dbtop, dbbot, step, v;
    size_t k;
    int x, y, px, prev_y = -1;
    char label[64];

    double dbmin = INFINITY;

    for (k = 0; k < nbins; k++) {
        if (db[k] > dbmax) dbmax = db[k];
        if (isfinite(db[k]) && db[k] < dbmin) dbmin = db[k];
    }
    if (!isfinite(dbmax)) dbmax = dbmin = 0.0;      /* all zero input */
    /* Fit the axis to the data, but show no more than DB_RANGE. */
    dbtop = 10.0 * ceil(dbmax / 10.0 + 1e-9);
    dbbot = 10.0 * floor(dbmin / 10.0 - 1e-9);
    if (dbbot < dbtop - DB_RANGE) dbbot = dbtop - DB_RANGE;

    im.w = IMG_W;
    im.h = IMG_H;
    im.px = malloc(3 * (size_t)IMG_W * IMG_H);
    if (im.px == NULL) {
        fprintf(stderr, "%s: out of memory\n", prog);
        exit(1);
    }
    memset(im.px, 255, 3 * (size_t)IMG_W * IMG_H);

#define XPIX(f)  (x0 + (int)lround((f) / maxf * (pw - 1)))
#define YPIX(d)  (y0 + (int)lround((dbtop - (d)) / (dbtop - dbbot) * (ph - 1)))

    /* Frequency grid and labels. */
    step = nice_step(maxf, 10);
    for (v = 0; v <= maxf * (1 + 1e-9); v += step) {
        px = XPIX(v);
        vline(&im, px, y0, y1, GRID);
        vline(&im, px, y1, y1 + 6, BLACK);
        snprintf(label, sizeof label, "%g", fabs(v) < step * 1e-9 ? 0.0 : v);
        draw_text(&im, px - text_width(label) / 2, y1 + 12, label, BLACK, 0);
    }

    /* Level grid and labels. */
    step = nice_step(dbtop - dbbot, 8);
    for (v = dbtop; v >= dbbot - step * 1e-9; v -= step) {
        y = YPIX(v);
        hline(&im, x0, x1, y, GRID);
        hline(&im, x0 - 6, x0, y, BLACK);
        snprintf(label, sizeof label, "%g", fabs(v) < step * 1e-9 ? 0.0 : v);
        draw_text(&im, x0 - 10 - text_width(label), y - CHAR_H / 2, label, BLACK, 0);
    }

    /* The trace. With more bins than columns draw each column's min to max
       so no peak is lost; otherwise join the points with lines. */
    if (nbins > (size_t)pw) {
        for (x = 0; x < pw; x++) {
            size_t k0 = (size_t)((double)x / pw * nbins);
            size_t k1 = (size_t)((double)(x + 1) / pw * nbins);
            double lo = INFINITY, hi = -INFINITY;
            int ylo, yhi;
            if (k1 > nbins) k1 = nbins;
            if (k1 <= k0) k1 = k0 + 1;
            for (k = k0; k < k1; k++) {
                if (db[k] < lo) lo = db[k];
                if (db[k] > hi) hi = db[k];
            }
            if (lo < dbbot) lo = dbbot;
            if (hi < dbbot) hi = dbbot;
            ylo = YPIX(lo);
            yhi = YPIX(hi);
            if (prev_y >= 0) {
                if (prev_y < yhi) yhi = prev_y;
                if (prev_y > ylo) ylo = prev_y;
            }
            vline(&im, x0 + x, yhi, ylo, TRACE);
            prev_y = YPIX(db[k1 - 1] < dbbot ? dbbot : db[k1 - 1]);
        }
    } else {
        int prev_x = -1;
        for (k = 0; k < nbins; k++) {
            double f = nbins > 1 ? (double)k / (nbins - 1) * maxf : 0.0;
            px = XPIX(f);
            y = YPIX(db[k] < dbbot ? dbbot : db[k]);
            if (prev_x >= 0) line(&im, prev_x, prev_y, px, y, TRACE);
            else set_px(&im, px, y, TRACE);
            prev_x = px;
            prev_y = y;
        }
    }

    /* Frame, titles and axis labels. */
    hline(&im, x0, x1, y0, BLACK);
    hline(&im, x0, x1, y1, BLACK);
    vline(&im, x0, y0, y1, BLACK);
    vline(&im, x1, y0, y1, BLACK);

    {
        char title[512];
        const char *base = strrchr(name, '/');
        size_t maxch = (IMG_W - 20) / CHAR_W;
        snprintf(title, sizeof title, "Spectrum of %s", base ? base + 1 : name);
        if (strlen(title) > maxch && maxch > 3 && maxch < sizeof title)
            strcpy(title + maxch - 3, "...");
        draw_text(&im, (IMG_W - text_width(title)) / 2, 12, title, BLACK, 0);
        draw_text(&im, (IMG_W - text_width(subtitle)) / 2, 12 + CHAR_H + 6, subtitle, BLACK, 0);
    }
    draw_text(&im, x0 + (pw - text_width("Frequency (Hz)")) / 2, IMG_H - CHAR_H - 20,
              "Frequency (Hz)", BLACK, 0);
    draw_text(&im, 16, y0 + (ph + text_width(ylabel)) / 2, ylabel, BLACK, 1);

#undef XPIX
#undef YPIX

    if (!write_png(&im, filename)) exit(1);
    free(im.px);
}

/* ----------------------------------------------------------------- main */

int main(int argc, char *argv[]) {
    int opt;
    char *outname = NULL;
    const char *inname = "stdin";
    double maxf = 1.0;
    int use_welch = 0;
    int have_seglen = 0;
    size_t seglen = DEFAULT_SEGMENT;
    unsigned long long ull;
    char *end;
    FILE *in;
    double *samples;
    double *db;
    size_t nsamples, fftsize, nbins, k;
    double complex *X;
    char subtitle[128];

    prog = argv[0];
    while ((opt = getopt(argc, argv, "ho:n:ws:")) != -1) {
        switch (opt) {
        case 'h':
            usage();
            return 0;
        case 'o':
            outname = optarg;
            break;
        case 'n':
            errno = 0;
            maxf = strtod(optarg, &end);
            if (errno != 0 || end == optarg || *end != '\0' || !isfinite(maxf) || maxf <= 0) {
                fprintf(stderr, "%s: invalid max frequency for -n: %s\n", prog, optarg);
                return 1;
            }
            break;
        case 'w':
            use_welch = 1;
            break;
        case 's':
            errno = 0;
            ull = strtoull(optarg, &end, 10);
            if (optarg[0] == '-' || errno != 0 || end == optarg || *end != '\0' || ull == 0 ||
                ull > SIZE_MAX || pow2_at_least((size_t)ull) == 0) {
                fprintf(stderr, "%s: invalid segment length for -s: %s\n", prog, optarg);
                return 1;
            }
            seglen = pow2_at_least((size_t)ull);
            have_seglen = 1;
            break;
        default:
            usage();
            return 1;
        }
    }

    if (have_seglen && !use_welch) {
        fprintf(stderr, "%s: -s requires -w\n", prog);
        usage();
        return 1;
    }
    if (argc - optind > 1) {
        fprintf(stderr, "%s: only one input file may be given\n", prog);
        usage();
        return 1;
    }
    if (optind < argc && strcmp(argv[optind], "-") != 0) {
        inname = argv[optind];
        in = fopen(inname, "rb");
        if (in == NULL) {
            fprintf(stderr, "%s: cannot open %s: %s\n", prog, inname, strerror(errno));
            return 1;
        }
    } else {
        if (optind >= argc && isatty(STDIN_FILENO)) {
            fprintf(stderr, "%s: no input file given and stdin is a terminal\n", prog);
            usage();
            return 1;
        }
        in = stdin;
    }

    samples = read_samples(in, inname, &nsamples);
    if (in != stdin) fclose(in);
    if (nsamples == 0) {
        fprintf(stderr, "%s: no samples in %s\n", prog, inname);
        return 1;
    }

    if (use_welch) {
        size_t nsegs;
        double *power = welch(samples, nsamples, seglen, &fftsize, &nsegs);
        free(samples);
        nbins = fftsize > 1 ? fftsize / 2 + 1 : 1;

        if (outname != NULL) {
            db = malloc(nbins * sizeof *db);
            if (db == NULL) {
                fprintf(stderr, "%s: out of memory\n", prog);
                return 1;
            }
            for (k = 0; k < nbins; k++)
                db[k] = power[k] > 0 ? 10.0 * log10(power[k]) : -INFINITY;
            snprintf(subtitle, sizeof subtitle,
                     "%zu samples, Welch: %zu segments of %zu, Hann, 50%% overlap",
                     nsamples, nsegs, nsamples < seglen ? nsamples : seglen);
            plot_spectrum(db, nbins, maxf, inname, subtitle, "Power (dB)", outname);
            free(db);
        } else {
            for (k = 0; k < nbins; k++) {
                double f = nbins > 1 ? (double)k / (nbins - 1) * maxf : 0.0;
                if (printf("%.17g %.17g\n", f, power[k]) < 0) break;
            }
        }
        free(power);
    } else {
        /* Zero pad up to a power of two. */
        fftsize = pow2_at_least(nsamples);
        if (fftsize == 0) {
            fprintf(stderr, "%s: too many samples\n", prog);
            return 1;
        }
        X = calloc(fftsize, sizeof *X);
        if (X == NULL) {
            fprintf(stderr, "%s: out of memory\n", prog);
            return 1;
        }
        for (k = 0; k < nsamples; k++) X[k] = samples[k];
        free(samples);

        fft(X, fftsize);
        nbins = fftsize > 1 ? fftsize / 2 + 1 : 1;

        if (outname != NULL) {
            db = malloc(nbins * sizeof *db);
            if (db == NULL) {
                fprintf(stderr, "%s: out of memory\n", prog);
                return 1;
            }
            for (k = 0; k < nbins; k++) {
                double m = cabs(X[k]);
                db[k] = m > 0 ? 20.0 * log10(m) : -INFINITY;
            }
            snprintf(subtitle, sizeof subtitle, "%zu samples, FFT size %zu", nsamples, fftsize);
            plot_spectrum(db, nbins, maxf, inname, subtitle, "Magnitude (dB)", outname);
            free(db);
        } else {
            for (k = 0; k < nbins; k++) {
                double f = nbins > 1 ? (double)k / (nbins - 1) * maxf : 0.0;
                if (printf("%.17g %.17g %.17g\n", f, creal(X[k]), cimag(X[k])) < 0) break;
            }
        }
        free(X);
    }

    if (outname == NULL && (ferror(stdout) || fflush(stdout) != 0)) {
        fprintf(stderr, "%s: error writing output: %s\n", prog, strerror(errno));
        return 1;
    }
    return 0;
}
