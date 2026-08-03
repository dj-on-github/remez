/// A small radix-2 FFT.
///
/// The design only needs one transform -- recovering the cosine-series
/// coefficients of the interpolating polynomial -- and it always asks for a
/// power-of-two length, so an iterative radix-2 is all that is wanted. Pulling
/// in a package for it would cost more than it saves.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// The real and imaginary halves of a spectrum.
class Spectrum {
  Spectrum(this.re, this.im);
  final Float64List re;
  final Float64List im;
  int get length => re.length;
}

/// Forward DFT of real input, returning bins 0..n/2 inclusive.
///
/// The input length must be a power of two.
Spectrum realFft(Float64List input) {
  final n = input.length;
  if (n == 0 || (n & (n - 1)) != 0) {
    throw ArgumentError('length must be a power of two, got $n');
  }
  final re = Float64List(n)..setAll(0, input);
  final im = Float64List(n);
  _transform(re, im);

  final half = n ~/ 2 + 1;
  return Spectrum(
    Float64List.sublistView(re, 0, half),
    Float64List.sublistView(im, 0, half),
  );
}

/// In-place iterative Cooley-Tukey, decimation in time.
void _transform(Float64List re, Float64List im) {
  final n = re.length;

  // Bit-reversal permutation.
  for (var i = 1, j = 0; i < n; i++) {
    var bit = n >> 1;
    for (; j & bit != 0; bit >>= 1) {
      j ^= bit;
    }
    j ^= bit;
    if (i < j) {
      var t = re[i];
      re[i] = re[j];
      re[j] = t;
      t = im[i];
      im[i] = im[j];
      im[j] = t;
    }
  }

  for (var len = 2; len <= n; len <<= 1) {
    final angle = -2.0 * math.pi / len;
    final wRe = math.cos(angle);
    final wIm = math.sin(angle);
    for (var i = 0; i < n; i += len) {
      var curRe = 1.0, curIm = 0.0;
      for (var k = 0; k < len ~/ 2; k++) {
        final aRe = re[i + k], aIm = im[i + k];
        final bRe = re[i + k + len ~/ 2], bIm = im[i + k + len ~/ 2];
        final tRe = bRe * curRe - bIm * curIm;
        final tIm = bRe * curIm + bIm * curRe;
        re[i + k] = aRe + tRe;
        im[i + k] = aIm + tIm;
        re[i + k + len ~/ 2] = aRe - tRe;
        im[i + k + len ~/ 2] = aIm - tIm;
        final nextRe = curRe * wRe - curIm * wIm;
        curIm = curRe * wIm + curIm * wRe;
        curRe = nextRe;
      }
    }
  }
}
