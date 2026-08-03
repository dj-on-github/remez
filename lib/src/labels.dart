/// The names things go by, in one place.
///
/// The internal keys are lower case and unspaced; the prose spellings are what
/// the pulldowns show and what a saved design file records, because the Python
/// tool saves what its combobox is displaying rather than the key behind it.
library;

/// What the program calls itself: in its usage text, in the messages it prints
/// to a terminal, and in the header of every file it generates.
///
/// The Python tool of the same name says `remez.py` in those headers, so the
/// two are still told apart by what generated a file, without either of them
/// pretending to be the other.
const String programName = 'remez';

/// The extension a saved design gets.
///
/// The contents are still JSON -- the macOS type declaration says so, and the
/// Python tool reads and writes the same thing -- so this only changes what the
/// file is called and which program the desktop hands it to.
const String designExtension = 'remz';

/// Extensions the open dialog will show.
///
/// `.json` stays on the list: designs saved before this, and every design the
/// Python tool writes, are named that way.
const List<String> designExtensions = [designExtension, 'json'];

const Map<String, String> responseLabels = {
  'lowpass': 'Lowpass',
  'highpass': 'Highpass',
  'bandpass': 'Bandpass',
  'bandstop': 'Bandstop',
};

const Map<String, String> approximationLabels = {
  'butterworth': 'Butterworth',
  'chebyshev1': 'Chebyshev I',
  'chebyshev2': 'Chebyshev II',
  'elliptic': 'Elliptic',
};

/// How an approximation is written in prose.
String labelOf(String approximation) =>
    approximationLabels[approximation] ?? approximation;

/// A label or a key, whichever was given, back to the key.
String keyFor(Map<String, String> labels, String value, String fallback) {
  if (labels.containsKey(value)) return value;
  for (final entry in labels.entries) {
    if (entry.value == value) return entry.key;
  }
  return fallback;
}

/// Turn a file stem into an identifier C, SystemVerilog and VHDL all accept.
String sanitiseName(String text) {
  var name = text.trim().replaceAll(RegExp(r'\W'), '_');
  name = name.replaceAll(RegExp('_+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  if (name.isEmpty || !RegExp('[A-Za-z]').hasMatch(name[0])) {
    name = 'filt_$name'.replaceAll(RegExp(r'_+$'), '');
  }
  return name.toLowerCase();
}
