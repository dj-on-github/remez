/*
 * Compress the amplitude of raw 64 bit floating point PCM audio so that the
 * loudest sample sits at +-1.0.
 *
 *     f64compress [-c algorithm] [-o outfile] [-v] [infile]
 *
 * Input is headerless doubles in the machine's native byte order, the
 * format written by wavtof64.py, read from infile or from stdin when no
 * file is named. The same format is written to outfile when -o is given,
 * otherwise to stdout. Channels are irrelevant here: every sample is
 * treated alike, so an interleaved multi channel file keeps its balance.
 *
 * The peak is measured over the whole input before anything is written, so
 * a named file is read twice and a pipe is buffered in memory.
 *
 *   -c linear   Divide every sample by the peak. The whole waveform is
 *               scaled by one constant, so nothing is distorted, but a
 *               single loud crack drags the rest of the recording down.
 *               This is the default.
 *
 *   -c log      Leave quiet audio alone and bend the loud end down, using
 *               y = a.ln(1 + x/a) with a chosen so that the peak lands
 *               exactly on 1.0. The curve leaves the origin at a slope of
 *               1, so low level detail keeps its original level.
 *
 *   -c logNN    The same curve, but only above a knee, with everything
 *               below the knee passed through untouched. NN is the
 *               percentage of the full scale range that gets compressed,
 *               so -c log25 puts the knee at 0.75 and squeezes the top
 *               quarter of the range. The curve meets the straight line at
 *               the knee with the same slope, so there is no audible
 *               corner.
 *
 * The log curves only ever push levels down, so they need a peak above 1.0
 * to have anything to do. Quieter input is passed through unchanged; use
 * -c linear to bring such a recording up to full scale.
 *
 * Compile with:  cc -O2 -o f64compress f64compress.c -lm
 */

#include <errno.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Samples per read. */
#define IO_SAMPLES 4096

/* Where the bisection for the log curvature gives up. */
#define SOLVE_STEPS 200

typedef enum {
    MODE_LINEAR,
    MODE_LOG
} t_mode;

typedef struct {
    t_mode mode;
    double peak;        /* loudest sample in the input */
    double gain;        /* linear only: 1/peak */
    double knee;        /* log only: below this the audio is untouched */
    double curve;       /* log only: the a in a.ln(1 + x/a) */
    int    active;      /* zero when there is nothing to do */
} t_map;

/* Growable sample buffer, used when the input cannot be read twice. */
typedef struct {
    double *v;
    size_t  n, cap;
} t_buf;

static const char *progname = "f64compress";

/* ------------------------------------------------------------------ */
/* Little endian sample access, so the bytes mean the same on any host */
/* ------------------------------------------------------------------ */

static double get_double(const unsigned char *p)
{
    uint64_t u = (uint64_t)p[0]         | ((uint64_t)p[1] <<  8)
               | ((uint64_t)p[2] << 16) | ((uint64_t)p[3] << 24)
               | ((uint64_t)p[4] << 32) | ((uint64_t)p[5] << 40)
               | ((uint64_t)p[6] << 48) | ((uint64_t)p[7] << 56);
    double d;
    memcpy(&d, &u, 8);
    return d;
}

static void put_double(unsigned char *p, double d)
{
    uint64_t u;
    int i;

    memcpy(&u, &d, 8);
    for (i = 0; i < 8; i++)
        p[i] = (unsigned char)((u >> (8 * i)) & 0xFF);
}

static int buf_push(t_buf *b, double x)
{
    if (b->n == b->cap) {
        size_t cap = b->cap ? b->cap * 2 : 8192;
        double *v = (double *) realloc(b->v, cap * sizeof *v);
        if (!v)
            return -1;
        b->v = v;
        b->cap = cap;
    }
    b->v[b->n++] = x;
    return 0;
}

/* ------------------------------------------------------------------ */
/* The compression curves                                              */
/* ------------------------------------------------------------------ */

/* How far a.ln(1 + span/a) reaches. This is what has to equal the room
   left above the knee. */
static double curve_reach(double a, double span)
{
    if (a <= 0.0)
        return 0.0;
    return a * log(1.0 + span / a);
}

/* Finds the a that makes the curve land exactly on 1.0 at the peak.

   curve_reach rises monotonically from 0 towards span as a grows, so the
   root is bracketed and bisection is enough. A tiny a bends the top down
   hard, a huge a is indistinguishable from a straight line. */
static double solve_curve(double span, double room)
{
    double lo = 1e-12, hi = 1.0, mid;
    int i;

    /* Push hi out until the curve overshoots the room available */
    for (i = 0; i < 200 && curve_reach(hi, span) < room; i++)
        hi *= 2.0;

    for (i = 0; i < SOLVE_STEPS; i++) {
        mid = 0.5 * (lo + hi);
        if (curve_reach(mid, span) < room)
            lo = mid;
        else
            hi = mid;
    }
    return 0.5 * (lo + hi);
}

/* Works out the mapping from the peak that was measured. */
static void plan_map(t_map *map, t_mode mode, double knee, double peak)
{
    map->mode = mode;
    map->peak = peak;
    map->knee = knee;
    map->gain = 1.0;
    map->curve = 0.0;
    map->active = 0;

    if (!(peak > 0.0))
        return;                     /* digital silence, nothing to scale */

    if (mode == MODE_LINEAR) {
        map->gain = 1.0 / peak;
        map->active = 1;
        return;
    }

    /* The log curves only bend levels down, so they need headroom to work
       with: the peak has to be above 1.0, and above the knee. */
    if (peak <= 1.0 || peak <= knee)
        return;

    map->curve = solve_curve(peak - knee, 1.0 - knee);
    map->active = 1;
}

static double apply_map(const t_map *map, double x)
{
    double m, y;

    if (map->active == 0)
        return x;

    if (map->mode == MODE_LINEAR) {
        /* Dividing rather than multiplying by a stored reciprocal matters:
           x/peak is exactly 1.0 when x is the peak, where x*(1.0/peak) can
           land an ulp above it and clip whatever reads the result. */
        y = x / map->peak;
    }
    else {
        m = fabs(x);
        if (m <= map->knee)
            return x;
        y = map->knee + curve_reach(map->curve, m - map->knee);
        if (x < 0.0)
            y = -y;
    }

    /* The curve is solved by bisection, so hold it to the promise. */
    if (y > 1.0)
        y = 1.0;
    if (y < -1.0)
        y = -1.0;
    return y;
}

/* ------------------------------------------------------------------ */
/* Reading                                                             */
/* ------------------------------------------------------------------ */

/* Reads the input, tracking the loudest sample. When keep is non-zero the
   samples are kept in buf as well, for inputs that cannot be read twice.
   Returns 0, or -1 after reporting the problem. */
static int scan_input(FILE *in, int keep, t_buf *buf, double *peak,
                      unsigned long *count, unsigned long *nonfinite)
{
    unsigned char bytes[IO_SAMPLES * 8];
    size_t leftover = 0, got;

    *peak = 0.0;
    *count = 0;
    *nonfinite = 0;

    while ((got = fread(bytes + leftover, 1, sizeof bytes - leftover, in)) > 0) {
        size_t total = leftover + got;
        size_t n = total / 8;
        size_t i;

        for (i = 0; i < n; i++) {
            double x = get_double(bytes + i * 8);

            /* A NaN would poison the peak, and an infinity would make every
               other sample vanish, so neither is allowed to count. */
            if (!isfinite(x)) {
                x = 0.0;
                (*nonfinite)++;
            }
            if (fabs(x) > *peak)
                *peak = fabs(x);
            if (keep && buf_push(buf, x) != 0) {
                fprintf(stderr, "%s: out of memory\n", progname);
                return -1;
            }
            (*count)++;
        }

        leftover = total - n * 8;
        if (leftover)
            memmove(bytes, bytes + n * 8, leftover);
    }

    if (ferror(in)) {
        fprintf(stderr, "%s: read failed: %s\n", progname, strerror(errno));
        return -1;
    }
    if (leftover)
        fprintf(stderr, "%s: ignoring %lu trailing byte(s), not a whole sample\n",
                progname, (unsigned long)leftover);

    return 0;
}

/* Second pass over a file that can be read twice. */
static int map_stream(FILE *in, FILE *out, const t_map *map, double *outpeak)
{
    unsigned char inbytes[IO_SAMPLES * 8];
    unsigned char outbytes[IO_SAMPLES * 8];
    size_t leftover = 0, got;

    while ((got = fread(inbytes + leftover, 1, sizeof inbytes - leftover, in)) > 0) {
        size_t total = leftover + got;
        size_t n = total / 8;
        size_t i;

        for (i = 0; i < n; i++) {
            double x = get_double(inbytes + i * 8);
            double y;

            if (!isfinite(x))
                x = 0.0;
            y = apply_map(map, x);
            if (fabs(y) > *outpeak)
                *outpeak = fabs(y);
            put_double(outbytes + i * 8, y);
        }

        if (n && fwrite(outbytes, 8, n, out) != n) {
            fprintf(stderr, "%s: write failed: %s\n", progname, strerror(errno));
            return -1;
        }

        leftover = total - n * 8;
        if (leftover)
            memmove(inbytes, inbytes + n * 8, leftover);
    }

    if (ferror(in)) {
        fprintf(stderr, "%s: read failed: %s\n", progname, strerror(errno));
        return -1;
    }
    return 0;
}

/* ------------------------------------------------------------------ */
/* Driver                                                              */
/* ------------------------------------------------------------------ */

static void usage(FILE *out)
{
    fprintf(out, "usage: %s [-c algorithm] [-o outfile] [-v] [infile]\n", progname);
    fprintf(out, "  Scales raw 64 bit float PCM samples so the peak sits at +-1.0.\n");
    fprintf(out, "  -c linear   one constant factor, 1/peak (default)\n");
    fprintf(out, "  -c log      logarithmic, quiet audio kept, loud audio bent down\n");
    fprintf(out, "  -c logNN    linear below the knee, logarithmic above it, where\n");
    fprintf(out, "              NN is the percent of full scale to compress, so\n");
    fprintf(out, "              log25 leaves everything below 0.75 untouched\n");
    fprintf(out, "  -o file     write samples here (default: stdout)\n");
    fprintf(out, "  -v          report what was measured on stderr\n");
    fprintf(out, "  infile defaults to stdin, as does '-'.\n");
}

/* Reads a -c argument. Returns 0, or -1 if it makes no sense. */
static int parse_algorithm(const char *text, t_mode *mode, double *knee)
{
    char *end;
    double pct;

    if (strcmp(text, "linear") == 0) {
        *mode = MODE_LINEAR;
        *knee = 0.0;
        return 0;
    }
    if (strncmp(text, "log", 3) != 0)
        return -1;

    *mode = MODE_LOG;
    if (text[3] == '\0') {
        *knee = 0.0;                /* compress the whole range */
        return 0;
    }

    pct = strtod(text + 3, &end);
    if (*end || !(pct > 0.0) || !(pct <= 100.0))
        return -1;

    *knee = 1.0 - pct / 100.0;
    return 0;
}

int main(int argc, char **argv)
{
    const char *in_path = NULL, *out_path = NULL;
    const char *algorithm = "linear";
    FILE *in = stdin, *out = stdout;
    t_mode mode = MODE_LINEAR;
    double knee = 0.0, peak = 0.0, outpeak = 0.0;
    unsigned long count = 0, nonfinite = 0;
    t_buf buf = {NULL, 0, 0};
    t_map map;
    int verbose = 0, status = 0, seekable, i;

    if (argc > 0 && argv[0] && argv[0][0])
        progname = argv[0];

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-c") == 0) {
            if (++i == argc) {
                fprintf(stderr, "%s: -c needs an algorithm\n", progname);
                return 1;
            }
            algorithm = argv[i];
            if (parse_algorithm(algorithm, &mode, &knee) != 0) {
                fprintf(stderr, "%s: unknown algorithm: %s\n", progname, algorithm);
                usage(stderr);
                return 1;
            }
        } else if (strcmp(argv[i], "-o") == 0) {
            if (++i == argc) {
                fprintf(stderr, "%s: -o needs a filename\n", progname);
                return 1;
            }
            out_path = argv[i];
        } else if (strcmp(argv[i], "-v") == 0) {
            verbose = 1;
        } else if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            usage(stdout);
            return 0;
        } else if (strcmp(argv[i], "-") == 0) {
            in_path = NULL;
        } else if (argv[i][0] == '-' && argv[i][1]) {
            fprintf(stderr, "%s: unknown option: %s\n", progname, argv[i]);
            usage(stderr);
            return 1;
        } else if (in_path == NULL) {
            in_path = argv[i];
        } else {
            fprintf(stderr, "%s: only one input file may be given\n", progname);
            return 1;
        }
    }

    if (in_path) {
        in = fopen(in_path, "rb");
        if (!in) {
            fprintf(stderr, "%s: %s: %s\n", progname, in_path, strerror(errno));
            return 1;
        }
    }
    if (out_path) {
        out = fopen(out_path, "wb");
        if (!out) {
            fprintf(stderr, "%s: %s: %s\n", progname, out_path, strerror(errno));
            if (in != stdin)
                fclose(in);
            return 1;
        }
    }

    /* A file can be rewound and read again. A pipe has to be kept. */
    seekable = (fseek(in, 0L, SEEK_SET) == 0);

    if (scan_input(in, seekable ? 0 : 1, &buf, &peak, &count, &nonfinite) != 0) {
        status = 1;
        goto done;
    }

    if (count == 0) {
        fprintf(stderr, "%s: no samples on input\n", progname);
        status = 1;
        goto done;
    }

    plan_map(&map, mode, knee, peak);

    if (map.active == 0 && peak > 0.0)
        fprintf(stderr, "%s: peak is %.6f, already within +-1.0, "
                        "nothing for %s to compress\n", progname, peak, algorithm);
    if (!(peak > 0.0))
        fprintf(stderr, "%s: the input is silent, passing it through\n", progname);

    if (seekable) {
        if (fseek(in, 0L, SEEK_SET) != 0) {
            fprintf(stderr, "%s: could not rewind the input: %s\n",
                    progname, strerror(errno));
            status = 1;
            goto done;
        }
        if (map_stream(in, out, &map, &outpeak) != 0)
            status = 1;
    } else {
        unsigned char outbytes[IO_SAMPLES * 8];
        size_t done_n = 0;

        while (done_n < buf.n) {
            size_t n = buf.n - done_n;
            size_t j;

            if (n > IO_SAMPLES)
                n = IO_SAMPLES;
            for (j = 0; j < n; j++) {
                double y = apply_map(&map, buf.v[done_n + j]);
                if (fabs(y) > outpeak)
                    outpeak = fabs(y);
                put_double(outbytes + j * 8, y);
            }
            if (fwrite(outbytes, 8, n, out) != n) {
                fprintf(stderr, "%s: write failed: %s\n", progname, strerror(errno));
                status = 1;
                break;
            }
            done_n += n;
        }
    }

    if (verbose) {
        fprintf(stderr, "%s: %lu samples, input peak %.6f\n",
                progname, count, peak);
        fprintf(stderr, "%s: algorithm %s\n", progname, algorithm);
        if (map.active == 0)
            fprintf(stderr, "%s: passed through unchanged\n", progname);
        else if (map.mode == MODE_LINEAR)
            fprintf(stderr, "%s: gain %.6f (%.2f dB)\n",
                    progname, map.gain, 20.0 * log10(map.gain));
        else
            fprintf(stderr, "%s: knee %.4f, curvature a = %.6f, "
                            "gain above the knee falls to %.4f at the peak\n",
                    progname, map.knee, map.curve,
                    map.curve / (map.curve + peak - map.knee));
        fprintf(stderr, "%s: output peak %.6f\n", progname, outpeak);
        if (nonfinite)
            fprintf(stderr, "%s: %lu sample(s) were not finite and were silenced\n",
                    progname, nonfinite);
    }

done:
    free(buf.v);
    if (in != stdin)
        fclose(in);
    if (fflush(out) != 0 || (out != stdout && fclose(out) != 0)) {
        fprintf(stderr, "%s: %s: %s\n", progname,
                out_path ? out_path : "stdout", strerror(errno));
        status = 1;
    }
    return status;
}
