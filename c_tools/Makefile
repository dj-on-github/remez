# Build the f64 audio and random number tools.
#
#     make            build everything
#     make <program>  build one program, e.g. make spectrumf64
#     make clean      remove the programs this Makefile builds

CC      ?= cc
CFLAGS  ?= -O2 -Wall
LDLIBS  += -lm

FILTERS = filter_300 filter_200_400 \
          ylian_200hz ylian_300hz ylian_400hz ylian_500hz ylian_600hz

PROGS   = randomf64 spectrumf64 playf64 f64compress morsedecode $(FILTERS)

all: $(PROGS)

# Plain programs are built from the .c of the same name by make's built-in
# rule, using CC, CFLAGS and LDLIBS. Only the exceptions are listed here.

spectrumf64: LDLIBS += -lz

# filter_200_400.c only has a main() when FILTER_MAIN is defined.
filter_200_400: CPPFLAGS += -DFILTER_MAIN

# playf64 streams to Core Audio on macOS and falls back to an external
# player elsewhere.
ifeq ($(shell uname -s),Darwin)
playf64: LDLIBS += -framework AudioToolbox -framework CoreFoundation
else
playf64: CPPFLAGS += -DPLAYF64_NO_COREAUDIO
endif

clean:
	rm -f $(PROGS)

.PHONY: all clean
