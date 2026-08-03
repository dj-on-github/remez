/// SystemVerilog generation for a designed filter.
///
/// The structure the design view draws -- multipliers, adders and unit delays
/// -- written out as synthesisable RTL, plus a self-checking testbench for it.
/// The arithmetic is defined once in `datapath.dart`, the hardware is planned
/// once in `rtl_common.dart`, and this file only renders it.
///
///     <name>_mul     one coefficient multiply, rounded and saturated back to
///                    the datapath format
///     <name>_add     one datapath-width add or subtract, saturating
///     <name>_sat     clamps a wide signed value into a narrow one
///     <name>_delay   one register: the filter's unit delay, and the pipeline
///                    register between adder-tree levels
///     <name>         the filter
///     <name>_tb      a testbench that checks it against known-good vectors
///
/// ## Numbers
///
/// Coefficients are `WCOEF` bits with `FRAC` fractional bits, exactly as the
/// Arithmetic panel quantized them. The datapath carries the same `FRAC`
/// fractional bits and `HEADROOM` extra integer bits, so every signal is
/// `WDATA = WCOEF + HEADROOM` bits and unity is `1 << FRAC`. Products are
/// exact, then rounded to nearest and saturated; adds saturate.
///
/// ## Timing
///
/// Synchronous, one sample per `din_strb`, active-low synchronous reset. The
/// result appears on `dout` with `dout_strb` high for one cycle, `LATENCY`
/// clocks after the strobe: one clock for the chain, one per tree level plus
/// one for the tree, and one per term plus two for the MAC. The MAC form needs
/// strobes at least `LATENCY` clocks apart and ignores any that arrive while it
/// is busy.
library;

import 'dart:math' as math;

import 'fir_core.dart' as fir;
import 'fixed_point.dart' as fx;
import 'format.dart';
import 'labels.dart';
import 'rtl_common.dart';

// ---------------------------------------------------------------------------
// the reusable modules
// ---------------------------------------------------------------------------

/// The reusable modules.
///
/// The widening pre-adder is only for folding, and an unused module would be a
/// second candidate top for the tools.
List<String> _library(String name, {bool folded = false}) => [
      '// ---------------------------------------------------------------------',
      '// One coefficient multiply.',
      '//',
      '// The product is formed exactly in WDATA+WCOEF bits, which leaves it',
      '// with 2*FRAC fractional bits; half an LSB is added and it is shifted',
      '// back down to FRAC, then saturated into the datapath width.  With',
      '// FIXED set the coefficient is a parameter, so synthesis can fold the',
      '// multiply down to shifts and adds; otherwise it comes from the port.',
      '// NEG negates the coefficient, which is how the feedback taps of a',
      '// biquad are subtracted without a separate subtractor.',
      '// ---------------------------------------------------------------------',
      'module ${name}_mul #(',
      '    parameter int     WDATA = 16,',
      '    parameter int     WIN   = WDATA,   // wider for a folded pre-add',
      '    parameter int     WCOEF = 12,',
      '    parameter int     FRAC  = 11,',
      "    parameter bit     FIXED = 1'b1,",
      "    parameter bit     NEG   = 1'b0,",
      '    parameter longint COEF  = 0',
      ') (',
      '    input  logic signed [WCOEF-1:0] coef,',
      '    input  logic signed [WIN-1:0]   din,',
      '    output logic signed [WDATA-1:0] dout',
      ');',
      '    localparam int WPROD = WIN + WCOEF;',
      "    localparam longint CMAX =  (64'sd1 <<< (WCOEF-1)) - 1;",
      "    localparam longint CMIN = -(64'sd1 <<< (WCOEF-1));",
      '    // Saturating negate at elaboration, for the fixed case.',
      '    localparam longint CFIX = NEG ? ((-COEF > CMAX) ? CMAX :',
      '                                    (-COEF < CMIN) ? CMIN : -COEF) : COEF;',
      '',
      '    logic signed [WCOEF-1:0] c;',
      '    always_comb begin',
      "        if (FIXED)      c = WCOEF'(CFIX);",
      "        else if (NEG)   c = (coef == WCOEF'(CMIN)) ? WCOEF'(CMAX) : -coef;",
      '        else            c = coef;',
      '    end',
      '',
      '    logic signed [WPROD-1:0] prod, rounded;',
      '    always_comb begin',
      r'        prod    = $signed(din) * $signed(c);',
      "        rounded = (FRAC > 0) ? ((prod + (WPROD'(1) <<< (FRAC-1))) >>> FRAC)",
      '                             : prod;',
      '    end',
      '',
      '    ${name}_sat #(.WIN(WPROD), .WOUT(WDATA)) u_sat (.din(rounded), .dout(dout));',
      'endmodule',
      '',
      '',
      '// ---------------------------------------------------------------------',
      '// One datapath-width add, saturating rather than wrapping: a filter',
      '// that clips is bad, one that wraps is unrecognisable.  SUB subtracts,',
      '// which is what the pre-adders of a folded antisymmetric filter do.',
      '// ---------------------------------------------------------------------',
      'module ${name}_add #(',
      '    parameter int WDATA = 16,',
      "    parameter bit SUB   = 1'b0",
      ') (',
      '    input  logic signed [WDATA-1:0] a,',
      '    input  logic signed [WDATA-1:0] b,',
      '    output logic signed [WDATA-1:0] sum',
      ');',
      '    logic signed [WDATA:0] full;',
      r'    always_comb full = SUB ? ($signed(a) - $signed(b))',
      r'                           : ($signed(a) + $signed(b));',
      '    ${name}_sat #(.WIN(WDATA+1), .WOUT(WDATA)) u_sat (.din(full), .dout(sum));',
      'endmodule',
      '',
      '',
      if (folded) ..._preadder(name),
      '// ---------------------------------------------------------------------',
      '// Clamp a wide signed value into a narrow one.',
      '// ---------------------------------------------------------------------',
      'module ${name}_sat #(',
      '    parameter int WIN  = 32,',
      '    parameter int WOUT = 16',
      ') (',
      '    input  logic signed [WIN-1:0]  din,',
      '    output logic signed [WOUT-1:0] dout',
      ');',
      "    localparam logic signed [WIN-1:0] HI =  (WIN'(1) <<< (WOUT-1)) - 1;",
      "    localparam logic signed [WIN-1:0] LO = -(WIN'(1) <<< (WOUT-1));",
      '    always_comb begin',
      r"        if      ($signed(din) > HI) dout = WOUT'(HI);",
      r"        else if ($signed(din) < LO) dout = WOUT'(LO);",
      '        else                        dout = din[WOUT-1:0];',
      '    end',
      'endmodule',
      '',
      '',
      '// ---------------------------------------------------------------------',
      '// One register.  It advances only when enabled, which makes it both the',
      '// unit delay of the filter (enabled once per input sample) and the',
      '// pipeline register between adder-tree levels.',
      '// ---------------------------------------------------------------------',
      'module ${name}_delay #(',
      '    parameter int WDATA = 16',
      ') (',
      '    input  logic                    clk,',
      '    input  logic                    resetn,',
      '    input  logic                    en,',
      '    input  logic signed [WDATA-1:0] d,',
      '    output logic signed [WDATA-1:0] q',
      ');',
      '    always_ff @(posedge clk) begin',
      "        if (!resetn) q <= '0;",
      '        else if (en) q <= d;',
      '    end',
      'endmodule',
      '',
      '',
    ];

List<String> _preadder(String name) => [
      '// ---------------------------------------------------------------------',
      '// A widening add for the pre-adders of a folded filter.  It sums two',
      '// samples that may each be at full scale, so the result is one bit wider',
      '// and nothing is clipped: saturating here would throw away signal rather',
      '// than round it.  SUB subtracts, as an antisymmetric filter needs.',
      '// ---------------------------------------------------------------------',
      'module ${name}_addw #(',
      '    parameter int WDATA = 16,',
      "    parameter bit SUB   = 1'b0",
      ') (',
      '    input  logic signed [WDATA-1:0] a,',
      '    input  logic signed [WDATA-1:0] b,',
      '    output logic signed [WDATA:0]   sum',
      ');',
      r'    always_comb sum = SUB ? ($signed(a) - $signed(b))',
      r'                          : ($signed(a) + $signed(b));',
      'endmodule',
      '',
      '',
    ];

List<String> _preamble(RtlPlan plan) {
  final intBits = plan.wcoef - 1 - plan.frac;
  final (lo, hi) = plan.limits;
  final res = plan.resources;
  final unity = 1 << plan.frac;
  final out = <String>[
    '// ${'=' * 69}',
    '// ${plan.title}',
    '//',
    for (final line in plan.detail) '// $line',
    '//',
    '// Coefficients  ${plan.wcoef} bits, Q$intBits.${plan.frac}'
        '   (value = integer * 2^-${plan.frac})',
    '// Datapath      ${plan.wdata} bits = ${plan.wcoef} + ${plan.headroom} '
        'headroom, Q${intBits + plan.headroom}.${plan.frac}',
    '//               unity is $unity, '
        'range [${formatG(lo / unity)}, ${formatG(hi / unity)}]',
    '// Products are exact, then rounded to nearest and saturated; adds',
    '// saturate.  Headroom is what keeps the adders off their limits.',
    '//',
    '// Costs         ${res.multipliers} multiplier'
        '${res.multipliers != 1 ? 's' : ''}, '
        '${res.adders} adder${res.adders != 1 ? 's' : ''}, '
        '${res.delays} delay${res.delays != 1 ? 's' : ''}'
        '${res.pipeline > 0 ? ', ${res.pipeline} pipeline levels' : ''}',
    '//',
    '// clk / resetn        synchronous, active-low reset',
    '// din, din_strb       one sample per strobe',
    '// dout, dout_strb     the result, ${plan.latency} clock'
        '${plan.latency != 1 ? 's' : ''} after din_strb',
    if (plan.structure == 'mac') ...[
      '//                     strobes must be at least LATENCY clocks',
      '//                     apart; any arriving while busy are ignored',
    ],
    '//',
  ];
  if (plan.fixedCoeffs) {
    out.addAll([
      '// Coefficients are elaboration-time parameters, so synthesis can',
      '// specialise each multiplier.  There is no coefficient port.',
      '//',
    ]);
  } else {
    out.addAll([
      "// Coefficients arrive on the packed 'coeff' port and may change",
      '// while the filter runs.  Slice k is coeff[k*WCOEF +: WCOEF]:',
      '//',
      for (var i = 0; i < plan.coeffLabels.length; i++)
        '//   [${i.toString().padLeft(3)}] ${plan.coeffLabels[i]}',
      '//',
    ]);
  }
  out.addAll([
    '// Generated by $programName.  Lint it with, for example:',
    // A comment whose first word is the tool name is read as a pragma.
    '//     \$ verilator --lint-only -Wall <this file>',
    '// ${'=' * 69}',
    '',
    '`default_nettype none',
    '',
    "// Everything the filter needs is in this one file, so the checker's",
    '// one-module-per-file rule does not apply to it.',
    '/* verilator lint_off DECLFILENAME */',
    '',
    '',
  ]);
  return out;
}

/// The MAC reads the table as data, so with a coefficient port it has none.
bool _needsCoeffTable(RtlPlan plan) =>
    plan.fixedCoeffs || plan.structure != 'mac';

List<String> _coeffTable(RtlPlan plan, {int indent = 4}) {
  if (!_needsCoeffTable(plan)) return const [];
  final pad = ' ' * indent;
  final group = plan.kind == 'iir' ? 5 : 8;
  final what = plan.kind == 'iir'
      ? 'Five stored integers per section, in the order b0 b1 b2 a1 a2.'
      : (plan.folded
          ? 'One per multiply: the coefficient a folded pair shares.'
          : 'The impulse response, as stored integers.');
  // A shared multiplier reads the table at the coefficient width, as data; the
  // other structures pass its entries as parameters, which want longint.
  final declare =
      plan.structure == 'mac' ? 'logic signed [WCOEF-1:0]' : 'longint';
  final out = <String>[
    '$pad// $what',
    "${pad}localparam $declare COEF [0:NCOEF-1] = '{",
  ];
  for (var start = 0; start < plan.coeffs.length; start += group) {
    final end = math.min(start + group, plan.coeffs.length);
    var text = plan.coeffs.sublist(start, end).join(', ');
    if (end < plan.coeffs.length) text += ',';
    out.add('$pad    $text');
  }
  out.add('$pad};');
  return out;
}

List<String> _params(RtlPlan plan) => [
      '    // These describe the filter that was generated: the coefficients',
      '    // below are stored in this format, so overriding them would leave',
      '    // the two disagreeing.  They live here, rather than in the body, so',
      '    // that the port declarations can use them.  LATENCY is here to be',
      '    // read by whatever instantiates this, and is not used inside every',
      '    // structure, hence the pragma.',
      '    /* verilator lint_off UNUSEDPARAM */',
      if (plan.kind == 'iir')
        '    parameter int NSEC     = ${plan.nsec},'
      else ...[
        '    parameter int NTAPS    = ${plan.numtaps},',
        '    parameter int NTERM    = ${plan.nterms},',
      ],
      '    parameter int NCOEF    = ${plan.coeffs.length},',
      '    parameter int WCOEF    = ${plan.wcoef},',
      '    parameter int FRAC     = ${plan.frac},',
      '    parameter int HEADROOM = ${plan.headroom},',
      '    parameter int LATENCY  = ${plan.latency},',
      '    parameter int WDATA    = WCOEF + HEADROOM',
      '    /* verilator lint_on UNUSEDPARAM */',
    ];

List<String> _ports(RtlPlan plan) => [
      '    input  wire                     clk,',
      '    input  wire                     resetn,',
      '    input  wire signed [WDATA-1:0]  din,',
      '    input  wire                     din_strb,',
      if (!plan.fixedCoeffs)
        '    input  wire signed [NCOEF*WCOEF-1:0] coeff,',
      '    output logic signed [WDATA-1:0] dout,',
      '    output logic                    dout_strb',
    ];

String _coefPort(RtlPlan plan, String index) =>
    plan.fixedCoeffs ? "'0" : 'coeff[($index)*WCOEF +: WCOEF]';

List<String> _mulInst(RtlPlan plan, String name, String label, String index,
    String din, String dout,
    {String neg = "1'b0", int indent = 12, String? win}) {
  final pad = ' ' * indent;
  final width =
      win == null ? '.WDATA(WDATA)' : '.WDATA(WDATA), .WIN($win)';
  return [
    '$pad${name}_mul #(',
    '$pad    $width, .WCOEF(WCOEF), .FRAC(FRAC),',
    "$pad    .FIXED(1'b${plan.fixedCoeffs ? 1 : 0}), .NEG($neg),",
    '$pad    .COEF(COEF[$index])',
    '$pad) $label (',
    '$pad    .coef(${_coefPort(plan, index)}),',
    '$pad    .din($din), .dout($dout));',
  ];
}

// ---------------------------------------------------------------------------
// FIR
// ---------------------------------------------------------------------------

/// The delay line, the pre-adders if folded, and the multipliers.
List<String> _firProducts(RtlPlan plan, String name) {
  final out = <String>[
    "    // x[0] is this cycle's sample; x[k] is it delayed by k strobes.",
    '    wire signed [WDATA-1:0] x    [0:NTAPS-1];',
    '    wire signed [WTERM-1:0] term [0:NTERM-1];',
    '    wire signed [WDATA-1:0] prod [0:NTERM-1];',
    '',
    '    assign x[0] = din;',
    '',
    '    generate',
    '        for (genvar k = 1; k < NTAPS; k++) begin : g_delay',
    '            ${name}_delay #(.WDATA(WDATA)) u_z (',
    '                .clk(clk), .resetn(resetn), .en(din_strb),',
    '                .d(x[k-1]), .q(x[k]));',
    '        end',
    '',
  ];
  if (plan.folded) {
    final sub = "1'b${plan.subtracts ? 1 : 0}";
    final word = plan.subtracts ? 'subtract' : 'add';
    out.addAll([
      '        // Folded: one pre-$word per symmetric pair, so one',
      '        // multiplier serves two taps.',
      '        for (genvar k = 0; k < NPAIR; k++) begin : g_pre',
      '            ${name}_addw #(.WDATA(WDATA), .SUB($sub)) u_pre (',
      '                .a(x[k]), .b(x[NTAPS-1-k]), .sum(term[k]));',
      '        end',
    ]);
    if (plan.hasCentre) {
      out.addAll([
        '',
        '        // The unpaired centre tap goes straight in, sign',
        '        // extended to the width the pre-adders produce.',
        r"        assign term[NTERM-1] = WTERM'($signed(x[NTAPS/2]));",
      ]);
    }
    out.add('');
  } else {
    out.addAll([
      '        for (genvar k = 0; k < NTERM; k++) begin : g_term',
      '            assign term[k] = x[k];',
      '        end',
      '',
    ]);
  }
  out.add('        for (genvar k = 0; k < NTERM; k++) begin : g_mul');
  out.addAll(_mulInst(plan, name, 'u_mul', 'k', 'term[k]', 'prod[k]',
      win: 'WTERM'));
  out.addAll(['        end', '    endgenerate', '']);
  return out;
}

List<String> _firChain(String name) => [
      '    // Sum the products along a chain of adders, in tap order.',
      '    wire signed [WDATA-1:0] acc [0:NTERM-1];',
      '    assign acc[0] = prod[0];',
      '',
      '    generate',
      '        for (genvar k = 1; k < NTERM; k++) begin : g_sum',
      '            ${name}_add #(.WDATA(WDATA)) u_add (',
      '                .a(acc[k-1]), .b(prod[k]), .sum(acc[k]));',
      '        end',
      '    endgenerate',
      '',
      '    always_ff @(posedge clk) begin',
      '        if (!resetn) begin',
      "            dout      <= '0;",
      "            dout_strb <= 1'b0;",
      '        end else begin',
      '            if (din_strb) dout <= acc[NTERM-1];',
      '            dout_strb <= din_strb;',
      '        end',
      '    end',
    ];

/// Balanced adder tree with a register between levels.
List<String> _firTree(String name) => [
      '    // Balanced adder tree: LEVELS deep instead of NTERM long, with a',
      '    // register between levels so the clock is not held back by the whole',
      '    // summation.  vld[L] is high in the cycle where level L holds this',
      "    // sample's data, and is what enables the level after it.",
      '    localparam int LEVELS = LATENCY - 1;',
      '',
      '    function automatic int level_count(input int lvl);',
      '        int n;',
      '        n = NTERM;',
      '        for (int i = 0; i < lvl; i++) n = (n + 1) / 2;',
      '        return n;',
      '    endfunction',
      '',
      '    logic [LEVELS-1:0] vld;',
      '    always_ff @(posedge clk) begin',
      "        if (!resetn) vld <= '0;",
      '        else         vld <= {vld[LEVELS-2:0], din_strb};',
      '    end',
      '',
      '    wire signed [WDATA-1:0] node [0:LEVELS][0:NTERM-1];',
      '',
      '    generate',
      '        for (genvar k = 0; k < NTERM; k++) begin : g_leaf',
      '            assign node[0][k] = prod[k];',
      '        end',
      '',
      '        for (genvar L = 0; L < LEVELS; L++) begin : g_level',
      '            for (genvar i = 0; i < level_count(L+1); i++) begin : g_node',
      '                wire signed [WDATA-1:0] partial;',
      '                if (2*i + 1 < level_count(L)) begin : g_add',
      '                    ${name}_add #(.WDATA(WDATA)) u_add (',
      '                        .a(node[L][2*i]), .b(node[L][2*i+1]),',
      '                        .sum(partial));',
      '                end else begin : g_pass',
      '                    // An odd one out waits a level rather than being',
      '                    // added to something that is not there.',
      '                    assign partial = node[L][2*i];',
      '                end',
      '                ${name}_delay #(.WDATA(WDATA)) u_reg (',
      '                    .clk(clk), .resetn(resetn),',
      '                    .en(L == 0 ? din_strb : vld[L-1]),',
      '                    .d(partial), .q(node[L+1][i]));',
      '            end',
      '        end',
      '    endgenerate',
      '',
      '    always_ff @(posedge clk) begin',
      '        if (!resetn) begin',
      "            dout      <= '0;",
      "            dout_strb <= 1'b0;",
      '        end else begin',
      '            if (vld[LEVELS-1]) dout <= node[LEVELS][0];',
      '            dout_strb <= vld[LEVELS-1];',
      '        end',
      '    end',
    ];

/// One multiplier walked over the terms, one per clock.
List<String> _firMac(RtlPlan plan, String name) {
  final pre = plan.folded;
  final out = <String>[
    '    // One multiplier, reused.  The delay line is a register file with a',
    '    // write pointer rather than a shift chain, so any tap can be fetched',
    '    // by index; the accumulator then walks the terms one per clock.',
    '    // AW addresses the delay line, KW counts the terms; folding makes',
    '    // those two different sizes.',
    r"    localparam int AW = (NTAPS > 1) ? $clog2(NTAPS) : 1;",
    r"    localparam int KW = (NTERM > 1) ? $clog2(NTERM) : 1;",
    '',
    '    logic signed [WDATA-1:0] mem [0:NTAPS-1];',
    '    logic [AW-1:0]           wp, rp;',
    if (pre) '    logic [AW-1:0]           rp2;',
    '    logic [KW-1:0]           k;',
    '    logic                    busy;',
    '    logic signed [WDATA-1:0] acc;',
    '',
    '    wire signed [WDATA-1:0] sample = mem[rp];',
  ];
  if (pre) {
    final sub = "1'b${plan.subtracts ? 1 : 0}";
    out.addAll([
      '    wire signed [WDATA-1:0] mirror = mem[rp2];',
      '    wire signed [WTERM-1:0] paired;',
      '    ${name}_addw #(.WDATA(WDATA), .SUB($sub)) u_pre (',
      '        .a(sample), .b(mirror), .sum(paired));',
    ]);
    if (plan.hasCentre) {
      out.addAll([
        '',
        '    // The centre tap of an odd-length symmetric filter has',
        '    // no partner, so on that term the pre-adder is bypassed.',
        r"    wire signed [WTERM-1:0] term_in = (k == KW'(NTERM-1)) ? WTERM'($signed(sample)) : paired;",
      ]);
    } else {
      out.add('    wire signed [WTERM-1:0] term_in = paired;');
    }
  } else {
    out.add('    wire signed [WTERM-1:0] term_in = sample;');
  }

  // There is one multiplier for every tap, so its coefficient is selected
  // while the filter runs and cannot be an elaboration-time constant. With
  // fixed coefficients the table becomes a ROM read by the term counter --
  // which still saves the coefficient port, but cannot specialise the
  // multiplier the way a tap-per-multiplier structure can.
  out.addAll([
    '',
    '    // One multiplier serves every tap, so the coefficient is looked',
    '    // up per term rather than built into a multiplier.',
    '    wire signed [WCOEF-1:0] coef_sel = '
        '${plan.fixedCoeffs ? 'COEF[k];' : 'coeff[k*WCOEF +: WCOEF];'}',
    '',
    '    wire signed [WDATA-1:0] prod;',
    '    ${name}_mul #(',
    '        .WDATA(WDATA), .WIN(WTERM), .WCOEF(WCOEF), .FRAC(FRAC),',
    "        .FIXED(1'b0), .NEG(1'b0)",
    '    ) u_mul (',
    '        .coef(coef_sel),',
    '        .din(term_in), .dout(prod));',
    '',
    '    wire signed [WDATA-1:0] acc_next;',
    '    ${name}_add #(.WDATA(WDATA)) u_acc (',
    '        .a(acc), .b(prod), .sum(acc_next));',
    '',
    '    always_ff @(posedge clk) begin',
    '        if (!resetn) begin',
    '            // The delay line is cleared, as the shift-register',
    '            // structures clear theirs: without it the first NTAPS',
    '            // outputs would depend on whatever the memory held.',
    "            for (int i = 0; i < NTAPS; i++) mem[i] <= '0;",
    "            wp        <= '0;",
    "            rp        <= '0;",
    if (pre) "            rp2       <= '0;",
    "            k         <= '0;",
    "            busy      <= 1'b0;",
    "            acc       <= '0;",
    "            dout      <= '0;",
    "            dout_strb <= 1'b0;",
    '        end else begin',
    "            dout_strb <= 1'b0;",
    '',
    '            // A strobe arriving mid-sum would corrupt it, so it is',
    '            // ignored: keep them LATENCY clocks apart.',
    '            if (din_strb && !busy) begin',
    '                mem[wp] <= din;',
    '                rp      <= wp;',
    if (pre)
      "                rp2     <= (wp == AW'(NTAPS-1)) ? '0 : wp + AW'(1);",
    "                wp      <= (wp == AW'(NTAPS-1)) ? '0 : wp + AW'(1);",
    "                k       <= '0;",
    "                acc     <= '0;",
    "                busy    <= 1'b1;",
    '            end else if (busy) begin',
    '                acc <= acc_next;',
    "                if (k == KW'(NTERM-1)) begin",
    "                    busy      <= 1'b0;",
    '                    dout      <= acc_next;',
    "                    dout_strb <= 1'b1;",
    '                end else begin',
    "                    k   <= k + KW'(1);",
    "                    rp  <= (rp == '0) ? AW'(NTAPS-1) : rp - AW'(1);",
    if (pre)
      "                    rp2 <= (rp2 == AW'(NTAPS-1)) ? '0 : rp2 + AW'(1);",
    '                end',
    '            end',
    '        end',
    '    end',
  ]);
  return out;
}

/// RTL for a FIR in the requested structure.
String firSource(fir.RemezResult res, fx.Fixed? fixed, RtlOptions opts) =>
    renderFir(planFor('fir', res, fixed, opts));

String renderFir(RtlPlan plan) {
  final name = plan.name;
  final lines = <String>[
    ..._preamble(plan),
    ..._library(name, folded: plan.folded),
    '// ---------------------------------------------------------------------',
    '// $name: the filter itself.',
    '// ---------------------------------------------------------------------',
    'module $name #(',
    ..._params(plan),
    ') (',
    ..._ports(plan),
    ');',
    // A folded pre-adder is one bit wider than the datapath, because it sums
    // two samples that may each be at full scale.
    '    localparam int WTERM = WDATA + ${plan.folded ? 1 : 0};',
    // The shared-multiplier form walks terms rather than instantiating a
    // pre-adder per pair, so it has no use for the count.
    if (plan.folded && plan.structure != 'mac')
      '    localparam int NPAIR = ${plan.npairs};',
    ..._coeffTable(plan),
    '',
    if (plan.structure == 'mac')
      ..._firMac(plan, name)
    else ...[
      ..._firProducts(plan, name),
      ...(plan.structure == 'tree' ? _firTree(name) : _firChain(name)),
    ],
    'endmodule',
    '',
    '/* verilator lint_on DECLFILENAME */',
    '`default_nettype wire',
    '',
  ];
  return lines.join('\n');
}

// ---------------------------------------------------------------------------
// IIR
// ---------------------------------------------------------------------------

/// RTL for the biquad cascade, each section in transposed direct form II.
String iirSource(Object res, fx.Fixed? fixed, RtlOptions opts) =>
    renderIir(planFor('iir', res, fixed, opts));

String renderIir(RtlPlan plan) {
  final name = plan.name;
  final lines = <String>[
    ..._preamble(plan),
    ..._library(name, folded: plan.folded),
    '// ---------------------------------------------------------------------',
    '// $name: the filter itself.',
    '// ---------------------------------------------------------------------',
    'module $name #(',
    ..._params(plan),
    ') (',
    ..._ports(plan),
    ');',
    ..._coeffTable(plan),
    '',
    '    // chain[0] is the input; chain[s+1] is the output of section s.',
    '    wire signed [WDATA-1:0] chain [0:NSEC];',
    '    assign chain[0] = din;',
    '',
    '    generate',
    '        for (genvar s = 0; s < NSEC; s++) begin : g_sec',
    '            wire signed [WDATA-1:0] x = chain[s];',
    '            wire signed [WDATA-1:0] y;',
    '            wire signed [WDATA-1:0] s1, s2;          // delay outputs',
    '            wire signed [WDATA-1:0] pb0, pb1, pb2, pa1, pa2;',
    '            wire signed [WDATA-1:0] u1, s1_next, s2_next;',
    '',
    '            // The five multipliers.  a1 and a2 get NEG, which turns',
    '            // their adds into the subtractions the recursion wants.',
  ];
  const slots = [
    ('pb0', 0, "1'b0"),
    ('pb1', 1, "1'b0"),
    ('pb2', 2, "1'b0"),
    ('pa1', 3, "1'b1"),
    ('pa2', 4, "1'b1"),
  ];
  for (final (target, slot, neg) in slots) {
    final source = target.startsWith('pb') ? 'x' : 'y';
    lines.addAll(_mulInst(
        plan, name, 'u_mul_$target', 's*5 + $slot', source, target,
        neg: neg));
    lines.add('');
  }
  lines.addAll([
    '            // y = b0*x + s1',
    '            ${name}_add #(.WDATA(WDATA)) u_add_y (',
    '                .a(pb0), .b(s1), .sum(y));',
    '',
    '            // s1 <- b1*x - a1*y + s2',
    '            ${name}_add #(.WDATA(WDATA)) u_add_u1 (',
    '                .a(pb1), .b(pa1), .sum(u1));',
    '            ${name}_add #(.WDATA(WDATA)) u_add_s1 (',
    '                .a(u1), .b(s2), .sum(s1_next));',
    '',
    '            // s2 <- b2*x - a2*y',
    '            ${name}_add #(.WDATA(WDATA)) u_add_s2 (',
    '                .a(pb2), .b(pa2), .sum(s2_next));',
    '',
    '            ${name}_delay #(.WDATA(WDATA)) u_z1 (',
    '                .clk(clk), .resetn(resetn), .en(din_strb),',
    '                .d(s1_next), .q(s1));',
    '            ${name}_delay #(.WDATA(WDATA)) u_z2 (',
    '                .clk(clk), .resetn(resetn), .en(din_strb),',
    '                .d(s2_next), .q(s2));',
    '',
    '            assign chain[s+1] = y;',
    '        end',
    '    endgenerate',
    '',
    '    always_ff @(posedge clk) begin',
    '        if (!resetn) begin',
    "            dout      <= '0;",
    "            dout_strb <= 1'b0;",
    '        end else begin',
    '            if (din_strb) dout <= chain[NSEC];',
    '            dout_strb <= din_strb;',
    '        end',
    '    end',
    'endmodule',
    '',
    '/* verilator lint_on DECLFILENAME */',
    '`default_nettype wire',
    '',
  ]);
  return lines.join('\n');
}

String sourceFor(String kind, Object res, fx.Fixed? fixed, RtlOptions opts) =>
    kind == 'iir'
        ? iirSource(res, fixed, opts)
        : firSource(res as fir.RemezResult, fixed, opts);

// ---------------------------------------------------------------------------
// self-checking testbench
// ---------------------------------------------------------------------------

/// Test samples: full scale both ways, so the saturating adders get used.
List<int> stimulus(RtlPlan plan, {List<int>? samples, int seed = 20240}) {
  if (samples != null) return List<int>.from(samples);
  final (lo, hi) = plan.limits;
  final unity = 1 << plan.frac;
  final rng = math.Random(seed);
  final edge = [unity, -unity, hi, lo, 0, hi, lo, unity ~/ 2, -unity ~/ 2, 0];
  final low = lo ~/ 2;
  final span = hi ~/ 2 - low;
  return [...edge, for (var i = 0; i < 40; i++) low + rng.nextInt(span)];
}

/// A testbench that drives known stimulus and checks the known answers.
///
/// The expected values come from the model in `datapath.dart`, so running this
/// proves the RTL agrees with the same description of the arithmetic that the
/// plots and the reports are drawn from. It reports on every mismatch and stops
/// on the first.
String testbenchFor(String kind, Object res, fx.Fixed? fixed, RtlOptions opts,
    {List<int>? samples, int seed = 20240}) {
  final plan = planFor(kind, res, fixed, opts);
  return testbenchForPlan(plan, samples: samples, seed: seed);
}

String testbenchForPlan(RtlPlan plan, {List<int>? samples, int seed = 20240}) {
  final stim = stimulus(plan, samples: samples, seed: seed);
  final expect = plan.simulate(stim);
  final name = plan.name;
  final gap = plan.latency + 2;

  final lines = <String>[
    '// ${'=' * 69}',
    '// ${name}_tb: self-checking testbench for $name.',
    '//',
    '// ${stim.length} samples, full scale among them so that the saturating',
    '// adders are exercised, with the expected output of every one as',
    "// computed by the generator's model of this datapath.  Prints PASS and",
    '// finishes; stops on the first mismatch.  Latency ${plan.latency}, so',
    '// the strobes here are $gap clocks apart.',
    '//',
    '// \$ verilator --binary --timing --top-module ${name}_tb \\',
    '//       -o sim <design>.sv <this file> && ./sim',
    '// ${'=' * 69}',
    '',
    '`default_nettype none',
    '',
    'module ${name}_tb;',
    '    localparam int WCOEF = ${plan.wcoef};',
    '    localparam int HEADROOM = ${plan.headroom};',
    '    localparam int WDATA = WCOEF + HEADROOM;',
    '    localparam int NS = ${stim.length};',
    '    localparam int GAP = $gap;',
    '',
    "    localparam longint STIM   [0:NS-1] = '{",
    ..._wrap(stim),
    '    };',
    "    localparam longint EXPECT [0:NS-1] = '{",
    ..._wrap(expect),
    '    };',
    '',
  ];

  if (!plan.fixedCoeffs) {
    final nbits = plan.coeffs.length * plan.wcoef;
    final mask = (BigInt.one << plan.wcoef) - BigInt.one;
    var packed = BigInt.zero;
    for (var i = 0; i < plan.coeffs.length; i++) {
      packed |= (BigInt.from(plan.coeffs[i]) & mask) << (i * plan.wcoef);
    }
    lines.addAll([
      '    // The same coefficients the fixed build would compile in.',
      '    localparam logic signed [${nbits - 1}:0] COEFF = '
          "$nbits'h${packed.toRadixString(16)};",
      '',
    ]);
  }

  lines.addAll([
    '    logic clk, resetn, din_strb;',
    '    logic signed [WDATA-1:0] din;',
    '    logic signed [WDATA-1:0] dout;',
    '    logic dout_strb;',
    '    int   seen;',
    '',
    '    $name dut (',
    '        .clk(clk), .resetn(resetn), .din(din), .din_strb(din_strb),',
    if (!plan.fixedCoeffs) '        .coeff(COEFF),',
    '        .dout(dout), .dout_strb(dout_strb));',
    '',
    '    always #5 clk = ~clk;',
    '',
    '    initial begin',
    "        clk      = 1'b0;",
    "        resetn   = 1'b0;",
    "        din_strb = 1'b0;",
    "        din      = '0;",
    '        seen     = 0;',
    '        repeat (3) @(posedge clk);',
    "        resetn = 1'b1;",
    '        @(posedge clk);',
    '        for (int i = 0; i < NS; i++) begin',
    r"            din      = WDATA'(STIM[i]);",
    "            din_strb = 1'b1;",
    '            @(posedge clk);',
    "            din_strb = 1'b0;",
    '            repeat (GAP - 1) @(posedge clk);',
    '        end',
    '        repeat (GAP + 4) @(posedge clk);',
    '        if (seen != NS) begin',
    r'            $display("FAIL: %0d outputs, expected %0d", seen, NS);',
    r'            $fatal(1, "wrong number of outputs");',
    '        end',
    r'        $display("PASS: %0d samples matched", seen);',
    r'        $finish;',
    '    end',
    '',
    '    always @(posedge clk) begin',
    '        if (resetn && dout_strb) begin',
    r"            if (dout !== WDATA'(EXPECT[seen])) begin",
    r'                $display("FAIL at %0d: got %0d, expected %0d",',
    '                         seen, dout, EXPECT[seen]);',
    r'                $fatal(1, "mismatch");',
    '            end',
    '            seen <= seen + 1;',
    '        end',
    '    end',
    'endmodule',
    '',
    '`default_nettype wire',
    '',
  ]);
  return lines.join('\n');
}

List<String> _wrap(List<int> values, {int indent = 8, int group = 8}) {
  final pad = ' ' * indent;
  final out = <String>[];
  for (var start = 0; start < values.length; start += group) {
    final end = math.min(start + group, values.length);
    var text = values.sublist(start, end).join(', ');
    if (end < values.length) text += ',';
    out.add(pad + text);
  }
  return out;
}
