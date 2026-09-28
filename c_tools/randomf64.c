#include <stdlib.h>
#include <sys/random.h>
#include <stdio.h>
#include <stdint.h>
#include <math.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>

uint64_t get_random_bits() {
    uint64_t x;
    if (getentropy(&x, sizeof x) != 0) {
        fprintf(stderr, "getentropy failed: %s\n", strerror(errno));
        exit(1);
    }
    return x;
}

uint64_t choose_exponent(uint64_t start) {
    uint64_t e;

    e = start;
    do {
        if ((get_random_bits() & 0x01) == 1) return e;
        e = e-1;
    } while (e > 0);
    return ((uint64_t)0);
}

double make_f64() {
    uint64_t start;
    uint64_t mantissa;
    uint64_t exponent;
    uint64_t sign;
    uint64_t x;
    double *f;

    start = 1022;

    mantissa = get_random_bits() & 0x0fffffffffffff;
    exponent = choose_exponent(start);
    sign = get_random_bits() & 0x01;
    x = (sign << 63) | ((exponent & 0x7ff) << 52) | mantissa;
    f = (double *)&x;
    return(*f);
}

static void usage(const char *prog) {
    fprintf(stderr,
        "Usage: %s [-h] [-b] [-o <filename>] [-n <number_of_f64s> | -k <number_of_kilo_f64s>]\n"
        "  -h                        Print this help and exit\n"
        "  -o <filename>             Write output to <filename> instead of stdout\n"
        "  -b                        Output binary f64 data instead of text\n"
        "  -n <number_of_f64s>       Output this many f64 values\n"
        "  -k <number_of_kilo_f64s>  Output this many multiples of 1024 f64 values\n"
        "With neither -n nor -k, a single value is output.\n",
        prog);
}

static int parse_count(const char *s, uint64_t *out) {
    char *end;
    unsigned long long v;

    if (*s == '-') return 0;
    errno = 0;
    v = strtoull(s, &end, 10);
    if (errno != 0 || end == s || *end != '\0') return 0;
    *out = (uint64_t)v;
    return 1;
}

int main(int argc, char *argv[]) {
    int opt;
    int binary = 0;
    int have_n = 0;
    int have_k = 0;
    char *filename = NULL;
    uint64_t n = 1;
    uint64_t k = 0;
    uint64_t count;
    uint64_t i;
    FILE *out;
    double f;

    while ((opt = getopt(argc, argv, "ho:bn:k:")) != -1) {
        switch (opt) {
        case 'h':
            usage(argv[0]);
            return 0;
        case 'o':
            filename = optarg;
            break;
        case 'b':
            binary = 1;
            break;
        case 'n':
            if (!parse_count(optarg, &n)) {
                fprintf(stderr, "%s: invalid number for -n: %s\n", argv[0], optarg);
                return 1;
            }
            have_n = 1;
            break;
        case 'k':
            if (!parse_count(optarg, &k)) {
                fprintf(stderr, "%s: invalid number for -k: %s\n", argv[0], optarg);
                return 1;
            }
            have_k = 1;
            break;
        default:
            usage(argv[0]);
            return 1;
        }
    }

    if (optind < argc) {
        fprintf(stderr, "%s: unexpected argument: %s\n", argv[0], argv[optind]);
        usage(argv[0]);
        return 1;
    }

    if (have_n && have_k) {
        fprintf(stderr, "%s: use only one of -n or -k\n", argv[0]);
        usage(argv[0]);
        return 1;
    }

    if (have_k) {
        if (k > UINT64_MAX / 1024) {
            fprintf(stderr, "%s: -k value too large: %llu\n", argv[0], (unsigned long long)k);
            return 1;
        }
        count = k * 1024;
    } else {
        count = n;
    }

    if (filename != NULL) {
        out = fopen(filename, binary ? "wb" : "w");
        if (out == NULL) {
            fprintf(stderr, "%s: cannot open %s: %s\n", argv[0], filename, strerror(errno));
            return 1;
        }
    } else {
        out = stdout;
    }

    for (i = 0; i < count; i++) {
        f = make_f64();
        if (binary) {
            if (fwrite(&f, sizeof f, 1, out) != 1) break;
        } else {
            if (fprintf(out, "%.17g\n", f) < 0) break;
        }
    }

    if (ferror(out) || (out != stdout ? fclose(out) : fflush(out)) != 0) {
        fprintf(stderr, "%s: error writing output: %s\n", argv[0], strerror(errno));
        return 1;
    }
    return 0;
}
