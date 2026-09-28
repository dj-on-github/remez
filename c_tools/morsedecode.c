/*
 * Morse code decoder for raw 64 bit floating point PCM audio.
 *
 *     morsedecode [-s rate] [-f tone] [-o outfile] [-v] [infile]
 *
 * Input is headerless doubles in the machine's native byte order, the
 * format written by wavtof64.py, read from infile or from stdin when no
 * file is named. Decoded text goes to outfile when -o is given, otherwise
 * to stdout.
 *
 * By default the decoder does not care what the tone frequency is: it
 * measures short term energy, so anything keyed on and off will do. That
 * also means it hears everything else in the audio, so where other signals
 * or noise share the band, -f names the tone to listen to and the rest is
 * rejected. Nothing about the sending speed or the timing ratios is assumed
 * either, so Farnsworth spacing and hand keying with an unusual weight
 * still decode. The stages are
 *
 *   1. block RMS in dB, or with -f the magnitude of a windowed DFT at that
 *      tone, a few milliseconds per block, floored 60 dB below the peak so
 *      digital silence cannot stretch the scale
 *   2. Otsu's method over the resulting histogram to place the key up /
 *      key down threshold, with hysteresis sized from the distance to each
 *      class mean so the release level cannot fall into the noise
 *   3. run length encoding into mark and space runs, then a despeckle pass
 *      that absorbs runs far shorter than the typical one
 *   4. the mark lengths are sorted and cut at their largest ratio jump to
 *      separate dits from dahs, and the space lengths likewise into symbol,
 *      character and word gaps; every threshold comes from the audio
 *   5. table lookup of each dit/dah pattern
 *
 * Compile with:  cc -O2 -o morsedecode morsedecode.c -lm
 */

#include <errno.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif

/* Envelope block length in seconds. Short enough to resolve a dit at any
   sane speed, long enough to average over a cycle of a low tone. */
#define BLOCK_SECONDS 0.004

/* Samples per read. */
#define IO_SAMPLES 4096

/* Bins in the histogram Otsu's method runs over. */
#define HIST_BINS 256

/* Blocks in the tone tuned detector's window. Four blocks at the default
   block length is 16 ms, so the passband is about 60 Hz wide, as selective
   as a narrow CW filter but settling in a fraction of a dit. */
#define WINDOW_BLOCKS 4

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

/* How far below the peak the envelope is floored, in dB. */
#define ENV_FLOOR_DB 60.0

/* An envelope flatter than this is not keying. */
#define MIN_SPAN_DB 6.0

/* Two run lengths this far apart are taken to be different symbols. */
#define GROUP_RATIO 1.6

/* Runs shorter than the median run over this are treated as glitches. */
#define SPECKLE_FRACTION 4.0

/* Longest dit/dah pattern we will try to look up. */
#define MAX_SYMBOLS 8

static const char *progname = "morsedecode";

/* ------------------------------------------------------------------ */
/* Morse table                                                         */
/* ------------------------------------------------------------------ */

static const struct {
    const char *code;
    const char *text;
} morse_table[] = {
    {".-",      "A"},  {"-...",    "B"},  {"-.-.",    "C"},  {"-..",     "D"},
    {".",       "E"},  {"..-.",    "F"},  {"--.",     "G"},  {"....",    "H"},
    {"..",      "I"},  {".---",    "J"},  {"-.-",     "K"},  {".-..",    "L"},
    {"--",      "M"},  {"-.",      "N"},  {"---",     "O"},  {".--.",    "P"},
    {"--.-",    "Q"},  {".-.",     "R"},  {"...",     "S"},  {"-",       "T"},
    {"..-",     "U"},  {"...-",    "V"},  {".--",     "W"},  {"-..-",    "X"},
    {"-.--",    "Y"},  {"--..",    "Z"},

    {"-----",   "0"},  {".----",   "1"},  {"..---",   "2"},  {"...--",   "3"},
    {"....-",   "4"},  {".....",   "5"},  {"-....",   "6"},  {"--...",   "7"},
    {"---..",   "8"},  {"----.",   "9"},

    {".-.-.-",  "."},  {"--..--",  ","},  {"..--..",  "?"},  {".----.",  "'"},
    {"-.-.--",  "!"},  {"-..-.",   "/"},  {"-.--.",   "("},  {"-.--.-",  ")"},
    {".-...",   "&"},  {"---...",  ":"},  {"-.-.-.",  ";"},  {"-...-",   "="},
    {".-.-.",   "+"},  {"-....-",  "-"},  {"..--.-",  "_"},  {".-..-.",  "\""},
    {"...-..-", "$"},  {".--.-.",  "@"},

    /* Prosigns that are not also punctuation. */
    {"-.-.-",    "<KA>"},  {"...-.-",  "<SK>"},  {"...-.",  "<SN>"},
    {"........", "<HH>"}
};

#define MORSE_TABLE_LEN ((int) (sizeof morse_table / sizeof morse_table[0]))

static const char *lookup_morse(const char *code)
{
    int i;
    for (i = 0; i < MORSE_TABLE_LEN; i++)
        if (strcmp(morse_table[i].code, code) == 0)
            return morse_table[i].text;
    return NULL;
}

/* ------------------------------------------------------------------ */
/* Growable arrays                                                     */
/* ------------------------------------------------------------------ */

typedef struct {
    float  *v;
    size_t  n, cap;
} t_env;

typedef struct {
    int    on;      /* 1 = key down (mark), 0 = key up (space) */
    size_t len;     /* length in envelope blocks */
} t_run;

typedef struct {
    t_run  *v;
    size_t  n, cap;
} t_runs;

/* Every timing threshold the decoder needs, in envelope blocks. */
typedef struct {
    double dit;         /* one dit, for reporting the speed */
    double mark_thr;    /* at or above this a mark is a dah */
    double char_thr;    /* at or above this a space ends a character */
    double word_thr;    /* at or above this a space ends a word */
} t_timing;

static int env_push(t_env *e, float x)
{
    if (e->n == e->cap) {
        size_t cap = e->cap ? e->cap * 2 : 4096;
        float *v = (float *) realloc(e->v, cap * sizeof *v);
        if (!v)
            return -1;
        e->v = v;
        e->cap = cap;
    }
    e->v[e->n++] = x;
    return 0;
}

static int runs_push(t_runs *r, int on, size_t len)
{
    if (r->n == r->cap) {
        size_t cap = r->cap ? r->cap * 2 : 256;
        t_run *v = (t_run *) realloc(r->v, cap * sizeof *v);
        if (!v)
            return -1;
        r->v = v;
        r->cap = cap;
    }
    r->v[r->n].on = on;
    r->v[r->n].len = len;
    r->n++;
    return 0;
}

/* ------------------------------------------------------------------ */
/* Stage 1: audio to a dB envelope                                     */
/* ------------------------------------------------------------------ */

/* Two ways to measure how hard the key is down over one block.

   Broadband: the RMS of the block. It does not care what the tone is, but
   it hears everything else in the audio too.

   Tone tuned: the magnitude of a windowed DFT at one frequency, taken over
   a window WINDOW_BLOCKS blocks long and hopped one block at a time. That
   rejects noise and other signals outside its passband, which is about
   rate/window samples wide, while still moving a block at a time. */
typedef struct {
    size_t  block_len;
    size_t  filled;
    double  acc;            /* broadband: running sum of squares */

    int     tone;           /* non-zero when tone tuned */
    double *hist;           /* ring of the last win_len samples */
    double *wcos, *wsin;    /* windowed twiddle factors */
    size_t  win_len, pos;
    double  win_sum;
} t_detect;

static void detect_free(t_detect *d)
{
    free(d->hist);
    free(d->wcos);
    free(d->wsin);
    d->hist = d->wcos = d->wsin = NULL;
}

/* tone_hz of 0 selects the broadband detector. Returns 0, or -1 out of
   memory. */
static int detect_init(t_detect *d, size_t block_len, double tone_hz, long rate)
{
    size_t j;

    memset(d, 0, sizeof *d);
    d->block_len = block_len;
    if (tone_hz <= 0.0)
        return 0;

    d->tone = 1;
    d->win_len = block_len * WINDOW_BLOCKS;
    d->hist = (double *) calloc(d->win_len, sizeof *d->hist);
    d->wcos = (double *) malloc(d->win_len * sizeof *d->wcos);
    d->wsin = (double *) malloc(d->win_len * sizeof *d->wsin);
    if (!d->hist || !d->wcos || !d->wsin) {
        detect_free(d);
        return -1;
    }

    for (j = 0; j < d->win_len; j++) {
        /* Hann window, so a neighbouring signal a few tens of Hz away does
           not leak in through the skirts. */
        double w = 0.5 - 0.5 * cos(2.0 * M_PI * j / (double) d->win_len);
        double phase = 2.0 * M_PI * tone_hz * (double) j / (double) rate;
        d->wcos[j] = w * cos(phase);
        d->wsin[j] = w * sin(phase);
        d->win_sum += w;
    }
    if (d->win_sum <= 0.0)
        d->win_sum = 1.0;
    return 0;
}

/* Measures the block that has just finished. */
static double detect_level(const t_detect *d, size_t filled)
{
    double re = 0.0, im = 0.0;
    size_t j, k;

    if (!d->tone)
        return 10.0 * log10(d->acc / (double) filled + 1e-30);

    /* Walk the ring oldest first so the window lines up with the samples. */
    k = d->pos;
    for (j = 0; j < d->win_len; j++) {
        double x = d->hist[k];
        re += x * d->wcos[j];
        im -= x * d->wsin[j];
        k = (k + 1 == d->win_len) ? 0 : k + 1;
    }
    return 20.0 * log10(sqrt(re * re + im * im) / d->win_sum + 1e-30);
}

/* Feeds one sample in. Returns 1 when a block has completed and *db holds
   its level. */
static int detect_sample(t_detect *d, double x, double *db)
{
    /* One NaN would poison every statistic downstream, so a sample that is
       not a finite number counts as silence. */
    if (!isfinite(x))
        x = 0.0;

    if (d->tone) {
        d->hist[d->pos] = x;
        d->pos = (d->pos + 1 == d->win_len) ? 0 : d->pos + 1;
    } else {
        d->acc += x * x;
    }

    if (++d->filled < d->block_len)
        return 0;

    *db = detect_level(d, d->filled);
    d->filled = 0;
    d->acc = 0.0;
    return 1;
}

/* Reads doubles from in, appending one dB value per block. Returns 0, or -1
   after reporting the problem. */
static int build_envelope(FILE *in, t_detect *det, t_env *env)
{
    double buf[IO_SAMPLES];
    unsigned char *bytes = (unsigned char *) buf;
    size_t leftover = 0, got;

    while ((got = fread(bytes + leftover, 1, sizeof buf - leftover, in)) > 0) {
        size_t total = leftover + got;
        size_t count = total / sizeof(double);
        size_t i;

        for (i = 0; i < count; i++) {
            double db;
            if (detect_sample(det, buf[i], &db) && env_push(env, (float) db) != 0) {
                fprintf(stderr, "%s: out of memory\n", progname);
                return -1;
            }
        }

        leftover = total - count * sizeof(double);
        if (leftover)
            memmove(bytes, bytes + count * sizeof(double), leftover);
    }

    if (ferror(in)) {
        fprintf(stderr, "%s: read failed: %s\n", progname, strerror(errno));
        return -1;
    }
    if (leftover)
        fprintf(stderr, "%s: ignoring %lu trailing byte(s), not a whole sample\n",
                progname, (unsigned long) leftover);

    /* Keep a final part block only if it is at least half full, so a ragged
       end does not invent a short mark. */
    if (det->filled > 0 && det->filled * 2 >= det->block_len &&
        env_push(env, (float) detect_level(det, det->filled)) != 0) {
        fprintf(stderr, "%s: out of memory\n", progname);
        return -1;
    }

    return 0;
}

/* ------------------------------------------------------------------ */
/* Stage 2: key up / key down threshold                                */
/* ------------------------------------------------------------------ */

/* Otsu's method: the threshold that minimises the variance within the two
   classes it splits the histogram into. Returns the threshold in dB, and
   through mu_lo and mu_hi the mean of each class. */
static double otsu_threshold(const t_env *env, double lo, double hi,
                             double *mu_lo, double *mu_hi)
{
    long hist[HIST_BINS];
    double width, total_sum = 0.0, sum_b = 0.0, best_var = -1.0;
    double best_thr = (lo + hi) / 2.0, best_lo = lo, best_hi = hi;
    long n = 0, weight_b = 0;
    size_t i;
    int b;

    memset(hist, 0, sizeof hist);
    width = (hi > lo) ? (hi - lo) / HIST_BINS : 1.0;

    for (i = 0; i < env->n; i++) {
        int bin = (int) ((env->v[i] - lo) / width);
        if (bin < 0)
            bin = 0;
        if (bin > HIST_BINS - 1)
            bin = HIST_BINS - 1;
        hist[bin]++;
    }

    for (b = 0; b < HIST_BINS; b++) {
        total_sum += (double) b * hist[b];
        n += hist[b];
    }
    if (n == 0) {
        *mu_lo = lo;
        *mu_hi = hi;
        return best_thr;
    }

    for (b = 0; b < HIST_BINS; b++) {
        double mean_b, mean_f, var;
        long weight_f;

        weight_b += hist[b];
        if (weight_b == 0)
            continue;
        weight_f = n - weight_b;
        if (weight_f == 0)
            break;

        sum_b += (double) b * hist[b];
        mean_b = sum_b / weight_b;
        mean_f = (total_sum - sum_b) / weight_f;
        var = (double) weight_b * weight_f * (mean_b - mean_f) * (mean_b - mean_f);

        if (var > best_var) {
            best_var = var;
            best_thr = lo + (b + 0.5) * width;
            best_lo = lo + (mean_b + 0.5) * width;
            best_hi = lo + (mean_f + 0.5) * width;
        }
    }

    *mu_lo = best_lo;
    *mu_hi = best_hi;
    return best_thr;
}

/* Schmitt trigger over the envelope, producing mark and space runs. */
static int envelope_to_runs(const t_env *env, double thr, double hyst, t_runs *runs)
{
    double up = thr + hyst, down = thr - hyst;
    int state = env->n && env->v[0] > thr;
    size_t len = 0, i;

    for (i = 0; i < env->n; i++) {
        int next = state;

        if (state) {
            if (env->v[i] < down)
                next = 0;
        } else {
            if (env->v[i] > up)
                next = 1;
        }

        if (next != state) {
            if (runs_push(runs, state, len) != 0)
                return -1;
            state = next;
            len = 0;
        }
        len++;
    }

    if (len && runs_push(runs, state, len) != 0)
        return -1;
    return 0;
}

/* ------------------------------------------------------------------ */
/* Stage 3: despeckle                                                  */
/* ------------------------------------------------------------------ */

static int cmp_double(const void *a, const void *b)
{
    double x = *(const double *) a, y = *(const double *) b;
    return (x > y) - (x < y);
}

/* Median run length, or 0 if there are none. */
static double median_run(const t_runs *runs, double *scratch)
{
    size_t i;

    if (runs->n == 0)
        return 0.0;
    for (i = 0; i < runs->n; i++)
        scratch[i] = (double) runs->v[i].len;
    qsort(scratch, runs->n, sizeof *scratch, cmp_double);
    return scratch[runs->n / 2];
}

/* One pass: absorb interior runs shorter than min_len into the run before
   them, then coalesce neighbours that now share a state. Returns the new
   run count. */
static size_t despeckle_pass(t_runs *runs, double min_len)
{
    size_t out = 0, i;

    for (i = 0; i < runs->n; i++) {
        /* A short run between two others is a glitch, not keying. Leading
           and trailing runs are left alone. */
        if (out > 0 && i + 1 < runs->n && (double) runs->v[i].len < min_len) {
            runs->v[out - 1].len += runs->v[i].len;
            continue;
        }
        if (out > 0 && runs->v[out - 1].on == runs->v[i].on) {
            runs->v[out - 1].len += runs->v[i].len;
            continue;
        }
        runs->v[out++] = runs->v[i];
    }

    runs->n = out;
    return out;
}

/* Repeats despeckle_pass, re-measuring the median each time, until it stops
   removing anything. */
static void despeckle(t_runs *runs, double *scratch)
{
    int pass;

    for (pass = 0; pass < 10; pass++) {
        double med, min_len;
        size_t before = runs->n;

        if (runs->n < 4)
            return;
        med = median_run(runs, scratch);
        min_len = med / SPECKLE_FRACTION;
        if (min_len < 2.0)
            return;
        if (despeckle_pass(runs, min_len) == before)
            return;
    }
}

/* ------------------------------------------------------------------ */
/* Stage 4: timing                                                     */
/* ------------------------------------------------------------------ */

typedef struct {
    double score;       /* between-class variance of the split at idx */
    size_t idx;         /* last index of the group below the jump */
} t_jump;

static int cmp_jump_desc(const void *a, const void *b)
{
    double x = ((const t_jump *) a)->score, y = ((const t_jump *) b)->score;
    return (x < y) - (x > y);
}

static int cmp_size(const void *a, const void *b)
{
    size_t x = *(const size_t *) a, y = *(const size_t *) b;
    return (x > y) - (x < y);
}

/* Sorts v ascending and cuts it where consecutive values jump by at least
   GROUP_RATIO. Where there is more than one such jump the cuts kept are the
   ones that separate the data best, measured as between-class variance over
   the log durations, rather than simply the biggest jumps: one stray run
   makes a large ratio but a poor split. Group g runs from bounds[g] up to
   but not including bounds[g+1]; returns the number of groups, and bounds
   holds that many entries plus one. */
static int split_groups(double *v, size_t n, int max_groups, size_t *bounds)
{
    t_jump *jumps;
    double *prefix;
    size_t cuts[2];
    size_t n_jumps = 0, i;
    int n_cuts, g;

    qsort(v, n, sizeof *v, cmp_double);

    bounds[0] = 0;
    if (n < 2 || max_groups < 2) {
        bounds[1] = n;
        return 1;
    }

    jumps = (t_jump *) malloc((n - 1) * sizeof *jumps);
    prefix = (double *) malloc((n + 1) * sizeof *prefix);
    if (!jumps || !prefix) {
        free(jumps);
        free(prefix);
        bounds[1] = n;
        return 1;
    }

    prefix[0] = 0.0;
    for (i = 0; i < n; i++)
        prefix[i + 1] = prefix[i] + log(v[i] > 0.0 ? v[i] : 1e-9);

    for (i = 0; i + 1 < n; i++) {
        double mean_a, mean_b, na, nb;

        if (!(v[i] > 0.0) || v[i + 1] / v[i] < GROUP_RATIO)
            continue;
        na = (double) (i + 1);
        nb = (double) (n - i - 1);
        mean_a = prefix[i + 1] / na;
        mean_b = (prefix[n] - prefix[i + 1]) / nb;
        jumps[n_jumps].score = na * nb * (mean_a - mean_b) * (mean_a - mean_b);
        jumps[n_jumps].idx = i;
        n_jumps++;
    }
    free(prefix);
    qsort(jumps, n_jumps, sizeof *jumps, cmp_jump_desc);

    n_cuts = (int) ((n_jumps < (size_t) (max_groups - 1)) ? n_jumps : max_groups - 1);
    for (g = 0; g < n_cuts; g++)
        cuts[g] = jumps[g].idx;
    free(jumps);
    qsort(cuts, n_cuts, sizeof *cuts, cmp_size);

    for (g = 0; g < n_cuts; g++)
        bounds[g + 1] = cuts[g] + 1;
    bounds[n_cuts + 1] = n;
    return n_cuts + 1;
}

/* Median of the sorted slice v[a..b). */
static double slice_median(const double *v, size_t a, size_t b)
{
    return v[a + (b - a) / 2];
}

/* Works out every timing threshold from the run lengths themselves.
   Returns 0 on success, -1 if there is nothing to measure. */
static int analyse_timing(const t_runs *runs, t_timing *t)
{
    double *marks, *spaces;
    size_t n_marks = 0, n_spaces = 0, i;
    size_t mb[3], sb[4];
    int n_mg, n_sg;
    double dit, mark_thr, el, mark_med;

    if (runs->n == 0)
        return -1;

    marks = (double *) malloc(runs->n * sizeof *marks);
    spaces = (double *) malloc(runs->n * sizeof *spaces);
    if (!marks || !spaces) {
        free(marks);
        free(spaces);
        return -1;
    }

    for (i = 0; i < runs->n; i++) {
        if (runs->v[i].on)
            marks[n_marks++] = (double) runs->v[i].len;
        else if (i > 0 && i + 1 < runs->n)      /* interior spaces only */
            spaces[n_spaces++] = (double) runs->v[i].len;
    }

    if (n_marks == 0) {
        free(marks);
        free(spaces);
        return -1;
    }

    n_mg = split_groups(marks, n_marks, 2, mb);
    mark_med = slice_median(marks, 0, n_marks);

    if (n_mg == 2) {
        double d = slice_median(marks, mb[0], mb[1]);
        double h = slice_median(marks, mb[1], mb[2]);
        dit = d;
        mark_thr = sqrt(d * h);
    } else {
        /* Every mark is the same length; the space lengths decide below
           whether they are all dits or all dahs. */
        dit = mark_med;
        mark_thr = dit * 2.0;
    }

    if (n_spaces == 0) {
        t->dit = dit;
        t->mark_thr = mark_thr;
        t->char_thr = dit * 2.0;
        t->word_thr = dit * 5.0;
        free(marks);
        free(spaces);
        return 0;
    }

    n_sg = split_groups(spaces, n_spaces, 3, sb);
    el = slice_median(spaces, sb[0], sb[1]);

    if (n_mg == 1) {
        /* Marks that match the shortest space are dits, otherwise they are
           dahs and the dit has to be inferred. */
        dit = (mark_med < el * 2.0) ? el : mark_med / 3.0;
        mark_thr = dit * 2.0;
    }

    if (n_sg == 3) {
        double g1 = slice_median(spaces, sb[1], sb[2]);
        double g2 = slice_median(spaces, sb[2], sb[3]);
        t->char_thr = sqrt(el * g1);
        t->word_thr = sqrt(g1 * g2);
    } else if (n_sg == 2) {
        double g1 = slice_median(spaces, sb[1], sb[2]);
        if (el < dit * 2.0) {
            /* Symbol gaps and character gaps, no word gaps. */
            t->char_thr = sqrt(el * g1);
            t->word_thr = g1 * 2.5;
        } else {
            /* No symbol gaps at all: character gaps and word gaps. */
            t->char_thr = el / 1.5;
            t->word_thr = sqrt(el * g1);
        }
    } else {
        if (el < dit * 2.0) {
            /* Only symbol gaps: one character, or one long word. */
            t->char_thr = el * 2.0;
            t->word_thr = el * 5.0;
        } else {
            /* Only character gaps. */
            t->char_thr = el / 1.5;
            t->word_thr = el * 2.5;
        }
    }

    t->dit = dit;
    t->mark_thr = mark_thr;
    free(marks);
    free(spaces);
    return 0;
}

/* ------------------------------------------------------------------ */
/* Stage 5: runs to text                                               */
/* ------------------------------------------------------------------ */

/* Emits the character for the pattern collected so far, if any. */
static void flush_symbol(char *code, int *len, FILE *out, long *chars, long *unknown)
{
    const char *text;

    if (*len == 0)
        return;
    code[*len] = '\0';
    *len = 0;

    text = lookup_morse(code);
    if (text) {
        fputs(text, out);
        (*chars)++;
    } else {
        /* Keep what was heard rather than silently dropping it. */
        fprintf(out, "<%s>", code);
        (*unknown)++;
    }
}

static void decode_runs(const t_runs *runs, const t_timing *t, FILE *out,
                        long *chars, long *words, long *unknown)
{
    char code[MAX_SYMBOLS + 1];
    int len = 0;
    size_t i;

    for (i = 0; i < runs->n; i++) {
        double n = (double) runs->v[i].len;

        if (runs->v[i].on) {
            if (len < MAX_SYMBOLS)
                code[len++] = (n >= t->mark_thr) ? '-' : '.';
            continue;
        }

        /* Leading and trailing silence carries no gap information. */
        if (i == 0 || i + 1 == runs->n)
            continue;

        if (n >= t->word_thr) {
            flush_symbol(code, &len, out, chars, unknown);
            fputc(' ', out);
            (*words)++;
        } else if (n >= t->char_thr) {
            flush_symbol(code, &len, out, chars, unknown);
        }
    }

    flush_symbol(code, &len, out, chars, unknown);
}

/* ------------------------------------------------------------------ */
/* Driver                                                              */
/* ------------------------------------------------------------------ */

static void usage(FILE *out)
{
    fprintf(out, "usage: %s [-s rate] [-f tone] [-o outfile] [-v] [infile]\n",
            progname);
    fprintf(out, "  Decodes morse code in raw 64 bit float PCM audio to text.\n");
    fprintf(out, "  -s rate   sample rate in Hz (default: 32000)\n");
    fprintf(out, "  -f tone   listen only near this tone in Hz, instead of to\n");
    fprintf(out, "            the whole band; use when other signals or noise\n");
    fprintf(out, "            share the audio\n");
    fprintf(out, "  -o file   write text here (default: stdout)\n");
    fprintf(out, "  -v        report what was measured on stderr\n");
    fprintf(out, "  infile defaults to stdin, as does '-'.\n");
}

int main(int argc, char **argv)
{
    const char *in_path = NULL, *out_path = NULL;
    FILE *in = stdin, *out = stdout;
    long rate = 32000;
    double tone = 0.0;
    int verbose = 0, status = 0, i;
    size_t block_len, n;
    t_env env = {NULL, 0, 0};
    t_runs runs = {NULL, 0, 0};
    t_detect det;
    t_timing timing;
    double lo, hi, thr, mu_lo, mu_hi, hyst, *scratch = NULL;
    long chars = 0, words = 0, unknown = 0;

    memset(&det, 0, sizeof det);

    if (argc > 0 && argv[0] && argv[0][0])
        progname = argv[0];

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-o") == 0) {
            if (++i == argc) {
                fprintf(stderr, "%s: -o needs a filename\n", progname);
                return 1;
            }
            out_path = argv[i];
        } else if (strcmp(argv[i], "-s") == 0) {
            char *end;
            if (++i == argc) {
                fprintf(stderr, "%s: -s needs a sample rate\n", progname);
                return 1;
            }
            rate = strtol(argv[i], &end, 10);
            if (*end || rate <= 0) {
                fprintf(stderr, "%s: bad sample rate: %s\n", progname, argv[i]);
                return 1;
            }
        } else if (strcmp(argv[i], "-f") == 0) {
            char *end;
            if (++i == argc) {
                fprintf(stderr, "%s: -f needs a tone frequency\n", progname);
                return 1;
            }
            tone = strtod(argv[i], &end);
            if (*end || !(tone > 0.0)) {
                fprintf(stderr, "%s: bad tone frequency: %s\n", progname, argv[i]);
                return 1;
            }
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
        out = fopen(out_path, "w");
        if (!out) {
            fprintf(stderr, "%s: %s: %s\n", progname, out_path, strerror(errno));
            if (in != stdin)
                fclose(in);
            return 1;
        }
    }
#ifdef _WIN32
    if (in == stdin)
        _setmode(_fileno(stdin), _O_BINARY);
#endif

    block_len = (size_t) (rate * BLOCK_SECONDS + 0.5);
    if (block_len < 1)
        block_len = 1;

    /* Nyquist is the hard limit; above it there is nothing to listen to. */
    if (tone > 0.0 && tone >= rate / 2.0) {
        fprintf(stderr, "%s: tone %.1f Hz is above half the sample rate (%ld Hz)\n",
                progname, tone, rate);
        if (in != stdin)
            fclose(in);
        if (out != stdout)
            fclose(out);
        return 1;
    }

    if (detect_init(&det, block_len, tone, rate) != 0) {
        fprintf(stderr, "%s: out of memory\n", progname);
        status = 1;
        goto done;
    }

    if (build_envelope(in, &det, &env) != 0) {
        status = 1;
        goto done;
    }

    if (env.n < 2) {
        fprintf(stderr, "%s: too little audio to decode\n", progname);
        status = 1;
        goto done;
    }

    hi = env.v[0];
    for (n = 0; n < env.n; n++)
        if (env.v[n] > hi)
            hi = env.v[n];

    /* Floor the envelope so digital silence cannot stretch the histogram
       over hundreds of dB and leave the real detail in one bin. */
    lo = hi - ENV_FLOOR_DB;
    for (n = 0; n < env.n; n++)
        if (env.v[n] < lo)
            env.v[n] = (float) lo;
    lo = env.v[0];
    for (n = 0; n < env.n; n++)
        if (env.v[n] < lo)
            lo = env.v[n];

    /* Keying swings the envelope by tens of dB. A few dB means the input is
       silence, noise, or a continuous tone, and any threshold we picked
       would just be slicing the noise. */
    if (hi - lo < MIN_SPAN_DB) {
        fprintf(stderr, "%s: no keying found (envelope spans only %.1f dB)\n",
                progname, hi - lo);
        goto done;
    }

    thr = otsu_threshold(&env, lo, hi, &mu_lo, &mu_hi);

    /* Size the hysteresis from the nearer class mean, so the release level
       can never sit inside the noise cluster. */
    hyst = 0.25 * ((thr - mu_lo < mu_hi - thr) ? (thr - mu_lo) : (mu_hi - thr));
    if (hyst < 0.2)
        hyst = 0.2;
    if (hyst > 6.0)
        hyst = 6.0;

    if (envelope_to_runs(&env, thr, hyst, &runs) != 0) {
        fprintf(stderr, "%s: out of memory\n", progname);
        status = 1;
        goto done;
    }

    scratch = (double *) malloc((runs.n ? runs.n : 1) * sizeof *scratch);
    if (!scratch) {
        fprintf(stderr, "%s: out of memory\n", progname);
        status = 1;
        goto done;
    }

    despeckle(&runs, scratch);

    if (analyse_timing(&runs, &timing) != 0) {
        fprintf(stderr, "%s: no keying found\n", progname);
        goto done;
    }

    decode_runs(&runs, &timing, out, &chars, &words, &unknown);
    fputc('\n', out);

    if (verbose) {
        double dit_ms = timing.dit * block_len * 1000.0 / rate;
        fprintf(stderr, "%s: %lu blocks of %lu samples at %ld Hz\n",
                progname, (unsigned long) env.n, (unsigned long) block_len, rate);
        if (det.tone)
            fprintf(stderr, "%s: tuned to %.1f Hz, about %.0f Hz wide\n",
                    progname, tone, (double) rate / (double) det.win_len);
        else
            fprintf(stderr, "%s: broadband energy detector\n", progname);
        fprintf(stderr, "%s: envelope %.1f to %.1f dB, threshold %.1f dB, "
                        "hysteresis %.1f dB\n", progname, lo, hi, thr, hyst);
        fprintf(stderr, "%s: %lu runs, dit %.1f blocks (%.1f ms, %.1f WPM)\n",
                progname, (unsigned long) runs.n, timing.dit, dit_ms,
                dit_ms > 0.0 ? 1200.0 / dit_ms : 0.0);
        fprintf(stderr, "%s: dah at %.1f, character gap at %.1f, word gap at "
                        "%.1f blocks\n", progname, timing.mark_thr,
                timing.char_thr, timing.word_thr);
        fprintf(stderr, "%s: %ld characters, %ld word gaps, %ld unrecognised\n",
                progname, chars, words, unknown);
    }

done:
    detect_free(&det);
    free(scratch);
    free(env.v);
    free(runs.v);
    if (in != stdin)
        fclose(in);
    if (fflush(out) != 0 || (out != stdout && fclose(out) != 0)) {
        fprintf(stderr, "%s: %s: %s\n", progname,
                out_path ? out_path : "stdout", strerror(errno));
        status = 1;
    }
    return status;
}
