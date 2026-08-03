/// The command line.
///
/// Kept apart from `main` so it can be tested without starting a window, and
/// so that adding an option is a change here rather than to the startup path.
/// A future batch mode -- design a filter and write the coefficients or the
/// RTL without ever opening a window -- goes in as a subcommand alongside the
/// design file, with the designer remaining what happens when nothing is given.
library;

import 'labels.dart';

const String version = '1.0.0';

final String usage = '''
usage: $programName [-h] [--version] [DESIGN.$designExtension]

Interactive digital filter designer: Remez-exchange FIR and classical IIR.

positional arguments:
  DESIGN.$designExtension  a design saved by File > Save design, opened at startup

options:
  -h, --help   show this help message and exit
  --version    show the program's version number and exit

With no arguments it opens the designer on a default lowpass.''';

/// What the command line asked for.
class CliResult {
  const CliResult({this.designPath, this.message, this.exitCode});

  /// A design file to open at startup, if one was named.
  final String? designPath;

  /// Text to print instead of starting: help, the version, or an error.
  final String? message;

  /// The status to exit with when [message] is set. Null means carry on.
  final int? exitCode;

  bool get shouldExit => exitCode != null;

  /// Errors go to stderr, help and the version to stdout, as they should.
  bool get isError => (exitCode ?? 0) != 0;
}

/// Parse [args], the way the Python's argparse does.
CliResult parseArgs(List<String> args) {
  String? design;
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '-h' || arg == '--help') {
      return CliResult(message: usage, exitCode: 0);
    }
    if (arg == '--version') {
      return CliResult(message: '$programName $version', exitCode: 0);
    }
    if (arg == '--') {
      // Everything after this is positional, whatever it looks like.
      for (final rest in args.skip(i + 1)) {
        if (design != null) return _tooMany();
        design = rest;
      }
      break;
    }
    if (arg.startsWith('-') && arg.length > 1) {
      return CliResult(
          message: '$programName: unrecognized arguments: $arg\n$usage',
          exitCode: 2);
    }
    if (design != null) return _tooMany();
    design = arg;
  }
  return CliResult(designPath: design);
}

CliResult _tooMany() => CliResult(
    message: '$programName: only one design file may be given\n$usage',
    exitCode: 2);
