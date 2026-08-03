import 'package:remez/src/fir_core.dart';

void main() {
  final cases = [
    ['41 taps', 41], ['101 taps', 101], ['201 taps', 201], ['401 taps', 401],
  ];
  for (final c in cases) {
    final n = c[1] as int;
    final bands = [
      Band.flat(0, 0.2, 1.0),
      Band.flat(0.25, 0.5, 0.0, weight: 10.0),
    ];
    design(n, bands); // warm up
    final sw = Stopwatch()..start();
    var reps = 0;
    while (sw.elapsedMilliseconds < 1500) {
      design(n, bands);
      reps++;
    }
    sw.stop();
    print('${c[0]}: ${(sw.elapsedMicroseconds / reps / 1000).toStringAsFixed(2)} ms');
  }
}
