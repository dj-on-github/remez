/*
 * Play raw 64 bit floating point PCM audio through the speakers.
 *
 *     playf64 [-s rate] [-c channels] [-v] [infile]
 *
 * Input is headerless doubles in the machine's native byte order, the
 * format written by wavtof64.py, read from infile or from stdin when no
 * file is named. Because the format carries no header there is nothing to
 * tell us the sample rate or channel count, so those come from the command
 * line. Samples are nominally in the range -1.0 to 1.0 with any channels
 * interleaved.
 *
 * On macOS the samples are streamed straight to an AudioQueue, so the
 * audio starts immediately and an input of any length can be played from a
 * pipe. Everywhere else, and with -DPLAYF64_NO_COREAUDIO, the samples are
 * wrapped in a temporary WAV file which is handed to whichever of afplay,
 * aplay, ffplay or play is on the PATH.
 *
 * Compile with:  cc -O2 -o playf64 playf64.c -framework AudioToolbox \
 *                                            -framework CoreFoundation
 *           or:  cc -O2 -DPLAYF64_NO_COREAUDIO -o playf64 playf64.c
 */

#include <errno.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#if defined(__APPLE__) && !defined(PLAYF64_NO_COREAUDIO)
#define USE_COREAUDIO 1
#include <AudioToolbox/AudioToolbox.h>
#else
#include <sys/wait.h>
#endif

/* Seconds of audio per queue buffer, and how many of them. Small enough to
   start promptly, large enough not to starve. */
#define BUFFER_SECONDS 0.1
#define NUM_BUFFERS 3

/* Players tried, in order, when there is no CoreAudio. */
#define MAX_PLAYER_ARGS 8

static const char *progname = "playf64";

/* ------------------------------------------------------------------ */
/* Sample source                                                       */
/* ------------------------------------------------------------------ */

typedef struct {
    FILE          *in;
    int            channels;
    int            eof;
    unsigned char *scratch;     /* raw bytes for one buffer's worth */
    size_t         scratch_len;
    unsigned char  carry[8];    /* bytes left over from the last read */
    size_t         n_carry;
    unsigned long  frames;
    unsigned long  clipped;
    unsigned long  nonfinite;
} t_src;

/* Reads a double from 8 little endian bytes, whatever the host is. */
static double get_double(const unsigned char *p)
{
    uint64_t u = (uint64_t)p[0]        | ((uint64_t)p[1] <<  8)
               | ((uint64_t)p[2] << 16) | ((uint64_t)p[3] << 24)
               | ((uint64_t)p[4] << 32) | ((uint64_t)p[5] << 40)
               | ((uint64_t)p[6] << 48) | ((uint64_t)p[7] << 56);
    double d;
    memcpy(&d, &u, 8);
    return d;
}

/* Fills out with up to max_samples floats. Returns how many it wrote, or 0
   once the input has run out. Sound cards want 32 bit floats, so the
   doubles are narrowed on the way through. */
static int src_fill(t_src *src, float *out, int max_samples)
{
    size_t want, got, total, count, i;

    if (src->eof)
        return 0;

    want = (size_t)max_samples * 8;
    if (want > src->scratch_len)
        want = src->scratch_len;
    if (want < src->n_carry)
        return 0;
    want -= src->n_carry;

    memcpy(src->scratch, src->carry, src->n_carry);
    got = fread(src->scratch + src->n_carry, 1, want, src->in);
    if (got == 0)
        src->eof = 1;

    total = src->n_carry + got;
    count = total / 8;

    for (i = 0; i < count; i++) {
        double v = get_double(src->scratch + i * 8);

        /* A sample that is not a finite number would be a nasty noise */
        if (!isfinite(v)) {
            v = 0.0;
            src->nonfinite++;
        }
        if (v > 1.0)  { v = 1.0;  src->clipped++; }
        if (v < -1.0) { v = -1.0; src->clipped++; }
        out[i] = (float)v;
    }

    /* Keep any bytes that did not make up a whole sample */
    src->n_carry = total - count * 8;
    if (src->n_carry)
        memcpy(src->carry, src->scratch + count * 8, src->n_carry);

    src->frames += (unsigned long)count / (unsigned long)src->channels;
    return (int)count;
}

/* ------------------------------------------------------------------ */
/* Playback through CoreAudio                                          */
/* ------------------------------------------------------------------ */

#ifdef USE_COREAUDIO

typedef struct {
    t_src *src;
    int    done;
    int    started;
    int    queued;      /* buffers handed to the queue so far */
    int    samples_per_buffer;
} t_play;

static void queue_callback(void *user, AudioQueueRef queue, AudioQueueBufferRef buf)
{
    t_play *play = (t_play *) user;
    int samples;

    samples = src_fill(play->src, (float *) buf->mAudioData,
                       play->samples_per_buffer);
    if (samples > 0) {
        buf->mAudioDataByteSize = (UInt32)(samples * (int)sizeof(float));
        AudioQueueEnqueueBuffer(queue, buf, 0, NULL);
        play->queued++;
    }
    else if (play->started) {
        /* Let whatever is already queued finish, then stop. */
        AudioQueueStop(queue, false);
    }
}

static void running_callback(void *user, AudioQueueRef queue, AudioQueuePropertyID id)
{
    t_play *play = (t_play *) user;
    UInt32 running = 0;
    UInt32 size = sizeof(running);

    (void)id;
    if (AudioQueueGetProperty(queue, kAudioQueueProperty_IsRunning,
                              &running, &size) != noErr)
        return;
    if (running == 0) {
        play->done = 1;
        CFRunLoopStop(CFRunLoopGetCurrent());
    }
}

/* Returns 0 on success, -1 after reporting a problem. */
static int play_audio(t_src *src, long rate, int channels)
{
    AudioStreamBasicDescription fmt;
    AudioQueueRef queue = NULL;
    AudioQueueBufferRef bufs[NUM_BUFFERS];
    t_play play;
    OSStatus err;
    int bytes_per_buffer;
    int i;

    memset(&fmt, 0, sizeof fmt);
    fmt.mSampleRate       = (Float64)rate;
    fmt.mFormatID         = kAudioFormatLinearPCM;
    fmt.mFormatFlags      = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
    fmt.mFramesPerPacket  = 1;
    fmt.mChannelsPerFrame = (UInt32)channels;
    fmt.mBitsPerChannel   = 32;
    fmt.mBytesPerFrame    = (UInt32)(channels * (int)sizeof(float));
    fmt.mBytesPerPacket   = fmt.mBytesPerFrame;

    memset(&play, 0, sizeof play);
    play.src = src;
    play.samples_per_buffer = (int)(rate * BUFFER_SECONDS) * channels;
    if (play.samples_per_buffer < channels)
        play.samples_per_buffer = channels;
    bytes_per_buffer = play.samples_per_buffer * (int)sizeof(float);

    err = AudioQueueNewOutput(&fmt, queue_callback, &play,
                              CFRunLoopGetCurrent(), kCFRunLoopCommonModes,
                              0, &queue);
    if (err != noErr) {
        fprintf(stderr, "%s: could not open the audio device (error %d)\n",
                progname, (int)err);
        return -1;
    }

    AudioQueueAddPropertyListener(queue, kAudioQueueProperty_IsRunning,
                                  running_callback, &play);

    /* Prime every buffer before starting, so playback does not stutter */
    for (i = 0; i < NUM_BUFFERS; i++) {
        err = AudioQueueAllocateBuffer(queue, (UInt32)bytes_per_buffer, &bufs[i]);
        if (err != noErr) {
            fprintf(stderr, "%s: could not allocate an audio buffer (error %d)\n",
                    progname, (int)err);
            AudioQueueDispose(queue, true);
            return -1;
        }
        queue_callback(&play, queue, bufs[i]);
    }

    if (play.queued == 0) {
        fprintf(stderr, "%s: no samples to play\n", progname);
        AudioQueueDispose(queue, true);
        return -1;
    }

    play.started = 1;
    err = AudioQueueStart(queue, NULL);
    if (err != noErr) {
        fprintf(stderr, "%s: could not start playback (error %d)\n",
                progname, (int)err);
        AudioQueueDispose(queue, true);
        return -1;
    }

    while (play.done == 0)
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.25, false);

    AudioQueueDispose(queue, true);
    return 0;
}

#else /* ---------------- no CoreAudio: hand a WAV to a player ------- */

static const char *players[][MAX_PLAYER_ARGS] = {
    { "afplay", NULL },
    { "aplay", "-q", NULL },
    { "ffplay", "-nodisp", "-autoexit", "-loglevel", "error", NULL },
    { "play", "-q", NULL }
};

#define NUM_PLAYERS ((int)(sizeof(players) / sizeof(players[0])))

static void put16(unsigned char *p, unsigned int v)
{
    p[0] = (unsigned char)(v & 0xFF);
    p[1] = (unsigned char)((v >> 8) & 0xFF);
}

static void put32(unsigned char *p, unsigned long v)
{
    p[0] = (unsigned char)(v & 0xFF);
    p[1] = (unsigned char)((v >> 8) & 0xFF);
    p[2] = (unsigned char)((v >> 16) & 0xFF);
    p[3] = (unsigned char)((v >> 24) & 0xFF);
}

/* Is this program on the PATH? */
static int on_path(const char *name)
{
    const char *path = getenv("PATH");
    char probe[1024];
    const char *p, *q;
    size_t n;

    if (!path)
        return 0;
    for (p = path; *p; p = (*q == ':') ? q + 1 : q) {
        for (q = p; *q && *q != ':'; q++)
            ;
        n = (size_t)(q - p);
        if (n == 0 || n + strlen(name) + 2 > sizeof(probe))
            continue;
        memcpy(probe, p, n);
        probe[n] = '/';
        strcpy(probe + n + 1, name);
        if (access(probe, X_OK) == 0)
            return 1;
        if (*q == '\0')
            break;
    }
    return 0;
}

/* Returns 0 on success, -1 after reporting a problem. */
static int play_audio(t_src *src, long rate, int channels)
{
    char tmp_path[] = "/tmp/playf64_XXXXXX";
    unsigned char header[60];
    float *block;
    FILE *out;
    unsigned long databytes = 0;
    int samples_per_block = (int)(rate * BUFFER_SECONDS) * channels;
    int block_align = channels * (int)sizeof(float);
    int fd, samples, i, status;
    pid_t pid;

    for (i = 0; i < NUM_PLAYERS; i++)
        if (on_path(players[i][0]))
            break;
    if (i == NUM_PLAYERS) {
        fprintf(stderr, "%s: no way to play audio, none of these are on the "
                        "PATH:", progname);
        for (i = 0; i < NUM_PLAYERS; i++)
            fprintf(stderr, " %s", players[i][0]);
        fprintf(stderr, "\n");
        return -1;
    }

    if (samples_per_block < channels)
        samples_per_block = channels;
    block = (float *) malloc((size_t)samples_per_block * sizeof *block);
    if (!block) {
        fprintf(stderr, "%s: out of memory\n", progname);
        return -1;
    }

    fd = mkstemp(tmp_path);
    if (fd < 0 || (out = fdopen(fd, "wb")) == NULL) {
        fprintf(stderr, "%s: could not make a temporary file: %s\n",
                progname, strerror(errno));
        free(block);
        return -1;
    }

    /* A 32 bit float WAV. Non PCM needs the cbSize field and a fact chunk. */
    memcpy(header, "RIFF", 4);
    memcpy(header + 8, "WAVE", 4);
    memcpy(header + 12, "fmt ", 4);
    put32(header + 16, 18);
    put16(header + 20, 3);                      /* WAVE_FORMAT_IEEE_FLOAT */
    put16(header + 22, (unsigned int)channels);
    put32(header + 24, (unsigned long)rate);
    put32(header + 28, (unsigned long)rate * (unsigned long)block_align);
    put16(header + 32, (unsigned int)block_align);
    put16(header + 34, 32);
    put16(header + 36, 0);                      /* cbSize */
    memcpy(header + 38, "fact", 4);
    put32(header + 42, 4);
    memcpy(header + 50, "data", 4);
    fwrite(header, 54 + 4, 1, out);             /* through the data size */

    while ((samples = src_fill(src, block, samples_per_block)) > 0) {
        fwrite(block, sizeof *block, (size_t)samples, out);
        databytes += (unsigned long)samples * (unsigned long)sizeof *block;
    }
    free(block);

    /* Now the length is known, go back and fill the size fields in */
    put32(header + 4, 58UL - 8UL + databytes);
    put32(header + 46, databytes / (unsigned long)block_align);
    put32(header + 54, databytes);
    if (fseek(out, 0L, SEEK_SET) == 0)
        fwrite(header, 58, 1, out);
    fclose(out);

    if (databytes == 0) {
        fprintf(stderr, "%s: no samples to play\n", progname);
        unlink(tmp_path);
        return -1;
    }

    pid = fork();
    if (pid < 0) {
        fprintf(stderr, "%s: could not start %s: %s\n",
                progname, players[i][0], strerror(errno));
        unlink(tmp_path);
        return -1;
    }
    if (pid == 0) {
        char *argv[MAX_PLAYER_ARGS + 2];
        int n = 0;
        while (players[i][n] != NULL && n < MAX_PLAYER_ARGS) {
            argv[n] = (char *) players[i][n];
            n++;
        }
        argv[n++] = tmp_path;
        argv[n] = NULL;
        execvp(argv[0], argv);
        _exit(127);
    }

    if (waitpid(pid, &status, 0) < 0) {
        fprintf(stderr, "%s: %s: %s\n", progname, players[i][0], strerror(errno));
        unlink(tmp_path);
        return -1;
    }
    unlink(tmp_path);

    if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
        fprintf(stderr, "%s: %s failed\n", progname, players[i][0]);
        return -1;
    }
    return 0;
}

#endif

/* ------------------------------------------------------------------ */
/* Driver                                                              */
/* ------------------------------------------------------------------ */

static void usage(FILE *out)
{
    fprintf(out, "usage: %s [-s rate] [-c channels] [-v] [infile]\n", progname);
    fprintf(out, "  Plays raw 64 bit float PCM samples through the speakers.\n");
    fprintf(out, "  -s rate   sample rate in Hz (default: 32000)\n");
    fprintf(out, "  -c n      number of interleaved channels (default: 1)\n");
    fprintf(out, "  -v        report what was played on stderr\n");
    fprintf(out, "  infile defaults to stdin, as does '-'.\n");
}

int main(int argc, char **argv)
{
    const char *in_path = NULL;
    FILE *in = stdin;
    long rate = 32000;
    int channels = 1;
    int verbose = 0, status = 0, i;
    t_src src;
    int samples_per_buffer;

    memset(&src, 0, sizeof src);

    if (argc > 0 && argv[0] && argv[0][0])
        progname = argv[0];

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-s") == 0) {
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
        } else if (strcmp(argv[i], "-c") == 0) {
            char *end;
            if (++i == argc) {
                fprintf(stderr, "%s: -c needs a channel count\n", progname);
                return 1;
            }
            channels = (int) strtol(argv[i], &end, 10);
            if (*end || channels < 1) {
                fprintf(stderr, "%s: bad channel count: %s\n", progname, argv[i]);
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
    else if (isatty(fileno(stdin))) {
        /* Waiting on a keyboard for binary samples just looks like a hang */
        fprintf(stderr, "%s: no input file given and stdin is a terminal\n",
                progname);
        return 1;
    }

    samples_per_buffer = (int)(rate * BUFFER_SECONDS) * channels;
    if (samples_per_buffer < channels)
        samples_per_buffer = channels;

    src.in = in;
    src.channels = channels;
    src.scratch_len = (size_t)samples_per_buffer * 8;
    src.scratch = (unsigned char *) malloc(src.scratch_len);
    if (!src.scratch) {
        fprintf(stderr, "%s: out of memory\n", progname);
        if (in != stdin)
            fclose(in);
        return 1;
    }

    fprintf(stderr, "%s: %ld Hz, %d channel(s)\n",
            (in_path != NULL) ? in_path : "<stdin>", rate, channels);

    if (play_audio(&src, rate, channels) != 0)
        status = 1;

    if (src.n_carry > 0)
        fprintf(stderr, "%s: ignored %lu trailing byte(s), not a whole sample\n",
                progname, (unsigned long)src.n_carry);

    if (verbose == 1) {
        fprintf(stderr, "%s: played %lu frames, %.2f seconds\n",
                progname, src.frames, (double)src.frames / (double)rate);
        if (src.clipped > 0)
            fprintf(stderr, "%s: %lu sample(s) outside -1.0 to 1.0 were clipped\n",
                    progname, src.clipped);
        if (src.nonfinite > 0)
            fprintf(stderr, "%s: %lu sample(s) were not finite and were silenced\n",
                    progname, src.nonfinite);
    }

    free(src.scratch);
    if (in != stdin)
        fclose(in);
    return status;
}
