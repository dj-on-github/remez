/// VHDL generation for a designed filter.
///
/// The same hardware `sv_export.dart` writes in SystemVerilog, written in VHDL
/// instead: the same topology, the same arithmetic, the same interface and the
/// same names, planned by the same `rtl_common.dart` and checked against the
/// same `datapath.dart` model. One file comes out, holding
///
///     <name>_sat     clamps a wide signed value into a narrow one
///     <name>_mul     one coefficient multiply, rounded and saturated
///     <name>_add     one datapath-width add or subtract, saturating
///     <name>_delay   one register
///     <name>         the filter
///     <name>_tb      a testbench that checks it against known-good vectors
///
/// VHDL-93 with `ieee.numeric_std`; nothing here needs 2008. Coefficients are
/// carried as `integer` generics, which is what limits the coefficient word
/// length to 31 bits on this path.
library;

import 'dart:math' as math;

import 'fir_core.dart' as fir;
import 'fixed_point.dart' as fx;
import 'format.dart';
import 'labels.dart';
import 'rtl_common.dart';
import 'sv_export.dart' show stimulus;

/// An integer generic is 32 bits signed, and that is how the coefficients
/// travel.
const int maxCoefBits = 31;

const List<String> _head = [
  'library ieee;',
  'use ieee.std_logic_1164.all;',
  'use ieee.numeric_std.all;',
  '',
];

RtlPlan _check(RtlPlan plan) {
  if (plan.wcoef > maxCoefBits) {
    throw RtlError(
        'the VHDL output carries coefficients as integer generics, so it is '
        'limited to $maxCoefBits bits; this design has ${plan.wcoef}. '
        'Use the SystemVerilog output, or fewer coefficient bits.');
  }
  return plan;
}

// ---------------------------------------------------------------------------
// the reusable entities
// ---------------------------------------------------------------------------

/// The reusable entities. The widening pre-adder is only for folding.
List<String> _library(String name, {bool folded = false}) => [
      '-- ---------------------------------------------------------------------',
      '-- Clamp a wide signed value into a narrow one.  Overflow is detected by',
      "-- looking at the bits above the target's sign bit: if they all match it,",
      '-- the value fits.  That avoids computing the limits as integers, which',
      '-- would themselves overflow for a wide datapath.',
      '-- ---------------------------------------------------------------------',
      ..._head,
      'entity ${name}_sat is',
      '    generic (',
      '        WIN  : positive := 32;',
      '        WOUT : positive := 16);',
      '    port (',
      '        din  : in  signed(WIN-1 downto 0);',
      '        dout : out signed(WOUT-1 downto 0));',
      'end entity ${name}_sat;',
      '',
      'architecture rtl of ${name}_sat is',
      '    -- 0111..1 and 1000..0.  Built by shifting rather than as an',
      '    -- aggregate, because a choice that depends on a generic is not',
      "    -- locally static and so cannot be mixed with 'others'.",
      '    constant HI : signed(WOUT-1 downto 0) := to_signed(-1, WOUT) srl 1;',
      '    constant LO : signed(WOUT-1 downto 0) := not HI;',
      'begin',
      '    process (din)',
      '        variable top : signed(WIN-WOUT downto 0);',
      '    begin',
      '        top := din(WIN-1 downto WOUT-1);',
      "        if top = to_signed(0, top'length) or",
      "           top = to_signed(-1, top'length) then",
      '            dout <= din(WOUT-1 downto 0);',
      "        elsif din(WIN-1) = '0' then",
      '            dout <= HI;',
      '        else',
      '            dout <= LO;',
      '        end if;',
      '    end process;',
      'end architecture rtl;',
      '',
      '',
      '-- ---------------------------------------------------------------------',
      '-- One coefficient multiply.',
      '--',
      '-- The product is formed exactly in WDATA+WCOEF bits, which leaves it with',
      '-- 2*FRAC fractional bits; half an LSB is added and it is shifted back',
      '-- down to FRAC, then saturated into the datapath width.  With FIXED true',
      '-- the coefficient is a generic, so synthesis can fold the multiply down',
      '-- to shifts and adds; otherwise it comes from the port.  NEG negates it,',
      '-- which is how the feedback taps of a biquad are subtracted without a',
      '-- separate subtractor.',
      '-- ---------------------------------------------------------------------',
      ..._head,
      'entity ${name}_mul is',
      '    generic (',
      '        WDATA : positive := 16;',
      '        WIN   : positive := 16;   -- wider for a folded pre-add',
      '        WCOEF : positive := 12;',
      '        FRAC  : natural  := 11;',
      '        FIXED : boolean  := true;',
      '        NEG   : boolean  := false;',
      '        COEF_FIXED : integer := 0);   -- COEF would clash with the port',
      '    port (',
      '        coef : in  signed(WCOEF-1 downto 0);',
      '        din  : in  signed(WIN-1 downto 0);',
      '        dout : out signed(WDATA-1 downto 0));',
      'end entity ${name}_mul;',
      '',
      'architecture rtl of ${name}_mul is',
      '    constant WPROD : positive := WIN + WCOEF;',
      '    constant CMAX  : integer  := 2**(WCOEF-1) - 1;',
      '    constant CMIN  : integer  := -(2**(WCOEF-1));',
      '    -- Saturating negate at elaboration, for the fixed case.  A',
      '    -- conditional expression in a constant would need VHDL-2019, so this',
      '    -- is a function.',
      '    function chosen (v : integer; flip : boolean) return integer is',
      '    begin',
      '        if not flip then',
      '            return v;',
      '        elsif -v > CMAX then',
      '            return CMAX;',
      '        elsif -v < CMIN then',
      '            return CMIN;',
      '        else',
      '            return -v;',
      '        end if;',
      '    end function chosen;',
      '    constant CFIX : integer := chosen(COEF_FIXED, NEG);',
      '',
      '    signal c       : signed(WCOEF-1 downto 0);',
      '    signal rounded : signed(WPROD-1 downto 0);',
      'begin',
      '    coefficient : process (coef)',
      '    begin',
      '        if FIXED then',
      '            c <= to_signed(CFIX, WCOEF);',
      '        elsif NEG then',
      '            if coef = to_signed(CMIN, WCOEF) then',
      '                c <= to_signed(CMAX, WCOEF);',
      '            else',
      '                c <= -coef;',
      '            end if;',
      '        else',
      '            c <= coef;',
      '        end if;',
      '    end process coefficient;',
      '',
      '    product : process (din, c)',
      '        variable prod : signed(WPROD-1 downto 0);',
      '        variable half : signed(WPROD-1 downto 0);',
      '    begin',
      '        prod := din * c;',
      '        if FRAC > 0 then',
      '            half    := to_signed(0, WPROD);',
      "            half(FRAC-1) := '1';",
      '            rounded <= shift_right(prod + half, FRAC);',
      '        else',
      '            rounded <= prod;',
      '        end if;',
      '    end process product;',
      '',
      '    u_sat : entity work.${name}_sat',
      '        generic map (WIN => WPROD, WOUT => WDATA)',
      '        port map (din => rounded, dout => dout);',
      'end architecture rtl;',
      '',
      '',
      '-- ---------------------------------------------------------------------',
      '-- One datapath-width add, saturating rather than wrapping: a filter that',
      '-- clips is bad, one that wraps is unrecognisable.  SUB subtracts, which',
      '-- is what the pre-adders of a folded antisymmetric filter do.',
      '-- ---------------------------------------------------------------------',
      ..._head,
      'entity ${name}_add is',
      '    generic (',
      '        WDATA : positive := 16;',
      '        SUB   : boolean  := false);',
      '    port (',
      '        a   : in  signed(WDATA-1 downto 0);',
      '        b   : in  signed(WDATA-1 downto 0);',
      '        sum : out signed(WDATA-1 downto 0));',
      'end entity ${name}_add;',
      '',
      'architecture rtl of ${name}_add is',
      '    signal full : signed(WDATA downto 0);',
      'begin',
      '    process (a, b)',
      '    begin',
      '        if SUB then',
      '            full <= resize(a, WDATA+1) - resize(b, WDATA+1);',
      '        else',
      '            full <= resize(a, WDATA+1) + resize(b, WDATA+1);',
      '        end if;',
      '    end process;',
      '',
      '    u_sat : entity work.${name}_sat',
      '        generic map (WIN => WDATA+1, WOUT => WDATA)',
      '        port map (din => full, dout => sum);',
      'end architecture rtl;',
      '',
      '',
      if (folded) ..._preadder(name),
      '-- ---------------------------------------------------------------------',
      '-- One register.  It advances only when enabled, which makes it both the',
      '-- unit delay of the filter (enabled once per input sample) and the',
      '-- pipeline register between adder-tree levels.',
      '-- ---------------------------------------------------------------------',
      ..._head,
      'entity ${name}_delay is',
      '    generic (',
      '        WDATA : positive := 16);',
      '    port (',
      '        clk    : in  std_logic;',
      '        resetn : in  std_logic;',
      '        en     : in  std_logic;',
      '        d      : in  signed(WDATA-1 downto 0);',
      '        q      : out signed(WDATA-1 downto 0));',
      'end entity ${name}_delay;',
      '',
      'architecture rtl of ${name}_delay is',
      'begin',
      '    process (clk)',
      '    begin',
      '        if rising_edge(clk) then',
      "            if resetn = '0' then",
      "                q <= (others => '0');",
      "            elsif en = '1' then",
      '                q <= d;',
      '            end if;',
      '        end if;',
      '    end process;',
      'end architecture rtl;',
      '',
      '',
    ];

List<String> _preadder(String name) => [
      '-- ---------------------------------------------------------------------',
      '-- A widening add for the pre-adders of a folded filter.  It sums two',
      '-- samples that may each be at full scale, so the result is one bit wider',
      '-- and nothing is clipped: saturating here would throw away signal rather',
      '-- than round it.  SUB subtracts, as an antisymmetric filter needs.',
      '-- ---------------------------------------------------------------------',
      ..._head,
      'entity ${name}_addw is',
      '    generic (',
      '        WDATA : positive := 16;',
      '        SUB   : boolean  := false);',
      '    port (',
      '        a   : in  signed(WDATA-1 downto 0);',
      '        b   : in  signed(WDATA-1 downto 0);',
      '        sum : out signed(WDATA downto 0));',
      'end entity ${name}_addw;',
      '',
      'architecture rtl of ${name}_addw is',
      'begin',
      '    process (a, b)',
      '    begin',
      '        if SUB then',
      '            sum <= resize(a, WDATA+1) - resize(b, WDATA+1);',
      '        else',
      '            sum <= resize(a, WDATA+1) + resize(b, WDATA+1);',
      '        end if;',
      '    end process;',
      'end architecture rtl;',
      '',
      '',
    ];

List<String> _preamble(RtlPlan plan) {
  final intBits = plan.wcoef - 1 - plan.frac;
  final (lo, hi) = plan.limits;
  final res = plan.resources;
  final unity = 1 << plan.frac;
  final out = <String>[
    '-- ${'=' * 69}',
    '-- ${plan.title}',
    '--',
    for (final line in plan.detail) '-- $line',
    '--',
    '-- Coefficients  ${plan.wcoef} bits, Q$intBits.${plan.frac}'
        '   (value = integer * 2^-${plan.frac})',
    '-- Datapath      ${plan.wdata} bits = ${plan.wcoef} + ${plan.headroom} '
        'headroom, Q${intBits + plan.headroom}.${plan.frac}',
    '--               unity is $unity, '
        'range [${formatG(lo / unity)}, ${formatG(hi / unity)}]',
    '-- Products are exact, then rounded to nearest and saturated; adds',
    '-- saturate.  Headroom is what keeps the adders off their limits.',
    '--',
    '-- Costs         ${res.multipliers} multiplier'
        '${res.multipliers != 1 ? 's' : ''}, '
        '${res.adders} adder${res.adders != 1 ? 's' : ''}, '
        '${res.delays} delay${res.delays != 1 ? 's' : ''}'
        '${res.pipeline > 0 ? ', ${res.pipeline} pipeline levels' : ''}',
    '--',
    '-- clk / resetn        synchronous, active-low reset',
    '-- din, din_strb       one sample per strobe',
    '-- dout, dout_strb     the result, ${plan.latency} clock'
        '${plan.latency != 1 ? 's' : ''} after din_strb',
    if (plan.structure == 'mac') ...[
      '--                     strobes must be at least LATENCY clocks',
      '--                     apart; any arriving while busy are ignored',
    ],
    '--',
  ];
  if (plan.fixedCoeffs) {
    out.addAll([
      '-- Coefficients are elaboration-time generics, so synthesis can',
      '-- specialise each multiplier.  There is no coefficient port.',
      '--',
    ]);
  } else {
    out.addAll([
      "-- Coefficients arrive on the packed 'coeff' port and may change",
      '-- while the filter runs.  Slice k is',
      '-- coeff((k+1)*WCOEF-1 downto k*WCOEF):',
      '--',
      for (var i = 0; i < plan.coeffLabels.length; i++)
        '--   [${i.toString().padLeft(3)}] ${plan.coeffLabels[i]}',
      '--',
    ]);
  }
  out.addAll([
    '-- Generated by $programName.  Analyse it with, for example:',
    '--     \$ ghdl -a --std=93 <this file>',
    '-- ${'=' * 69}',
    '',
    '',
  ]);
  return out;
}

List<String> _generics(RtlPlan plan) => [
      '    generic (',
      '        -- These describe the filter that was generated: the',
      '        -- coefficients below are stored in this format, so overriding',
      '        -- them would leave the two disagreeing.  LATENCY is here to be',
      '        -- read by whatever instantiates this.',
      if (plan.kind == 'iir')
        '        NSEC     : positive := ${plan.nsec};'
      else ...[
        '        NTAPS    : positive := ${plan.numtaps};',
        '        NTERM    : positive := ${plan.nterms};',
      ],
      '        NCOEF    : positive := ${plan.coeffs.length};',
      '        WCOEF    : positive := ${plan.wcoef};',
      '        FRAC     : natural  := ${plan.frac};',
      '        HEADROOM : natural  := ${plan.headroom};',
      '        LATENCY  : positive := ${plan.latency};',
      '        WDATA    : positive := ${plan.wdata});',
    ];

List<String> _ports(RtlPlan plan) => [
      '    port (',
      '        clk       : in  std_logic;',
      '        resetn    : in  std_logic;',
      '        din       : in  signed(WDATA-1 downto 0);',
      '        din_strb  : in  std_logic;',
      if (!plan.fixedCoeffs)
        '        coeff     : in  signed(NCOEF*WCOEF-1 downto 0);',
      '        dout      : out signed(WDATA-1 downto 0);',
      '        dout_strb : out std_logic);',
    ];

List<String> _declarations(RtlPlan plan) {
  final group = plan.kind == 'iir' ? 5 : 8;
  // A folded pre-adder is one bit wider than the datapath, because it sums
  // two samples that may each be at full scale.
  final out = <String>[
    '    constant WTERM : positive := WDATA + ${plan.folded ? 1 : 0};',
    '',
    '    type data_array_t is array (natural range <>) of '
        'signed(WDATA-1 downto 0);',
    '    type term_array_t is array (natural range <>) of '
        'signed(WTERM-1 downto 0);',
    '    type coef_array_t is array (natural range <>) of integer;',
    '',
  ];
  final what = plan.kind == 'iir'
      ? 'Five stored integers per section, in the order b0 b1 b2 a1 a2.'
      : (plan.folded
          ? 'One per multiply: the coefficient a folded pair shares.'
          : 'The impulse response, as stored integers.');
  out.add('    -- $what');
  out.add('    constant COEF : coef_array_t(0 to NCOEF-1) := (');
  for (var start = 0; start < plan.coeffs.length; start += group) {
    final end = math.min(start + group, plan.coeffs.length);
    var text = plan.coeffs.sublist(start, end).join(', ');
    if (end < plan.coeffs.length) text += ',';
    out.add('        $text');
  }
  out.add('    );');
  out.add('');
  return out;
}

String _coefExpr(RtlPlan plan, String index) => plan.fixedCoeffs
    ? 'to_signed(0, WCOEF)'
    : 'coeff(($index+1)*WCOEF-1 downto ($index)*WCOEF)';

List<String> _mulInst(RtlPlan plan, String name, String label, String index,
    String din, String dout,
    {String neg = 'false', int indent = 8, String? win}) {
  final pad = ' ' * indent;
  final width = win == null
      ? 'WDATA => WDATA, WIN => WDATA'
      : 'WDATA => WDATA, WIN => $win';
  return [
    '$pad$label : entity work.${name}_mul',
    '$pad    generic map ($width, WCOEF => WCOEF, FRAC => FRAC,',
    '$pad                 FIXED => ${plan.fixedCoeffs ? 'true' : 'false'},'
        ' NEG => $neg,',
    '$pad                 COEF_FIXED => COEF($index))',
    '$pad    port map (coef => ${_coefExpr(plan, index)},',
    '$pad              din => $din, dout => $dout);',
  ];
}

// ---------------------------------------------------------------------------
// FIR
// ---------------------------------------------------------------------------

List<String> _firProducts(RtlPlan plan, String name) {
  final out = <String>[
    "    -- x(0) is this cycle's sample; x(k) is it delayed by k strobes.",
    '    x(0) <= din;',
    '',
    '    g_delay : for k in 1 to NTAPS-1 generate',
    '        u_z : entity work.${name}_delay',
    '            generic map (WDATA => WDATA)',
    '            port map (clk => clk, resetn => resetn, en => din_strb,',
    '                      d => x(k-1), q => x(k));',
    '    end generate g_delay;',
    '',
  ];
  if (plan.folded) {
    final sub = plan.subtracts ? 'true' : 'false';
    final word = plan.subtracts ? 'subtract' : 'add';
    out.addAll([
      '    -- Folded: one pre-$word per symmetric pair, so one multiplier',
      '    -- serves two taps.',
      '    g_pre : for k in 0 to NPAIR-1 generate',
      '        u_pre : entity work.${name}_addw',
      '            generic map (WDATA => WDATA, SUB => $sub)',
      '            port map (a => x(k), b => x(NTAPS-1-k), sum => term(k));',
      '    end generate g_pre;',
      '',
    ]);
    if (plan.hasCentre) {
      out.addAll([
        '    -- The unpaired centre tap goes straight in, resized to',
        '    -- the width the pre-adders produce.',
        '    term(NTERM-1) <= resize(x(NTAPS/2), WTERM);',
        '',
      ]);
    }
  } else {
    out.addAll([
      '    g_term : for k in 0 to NTERM-1 generate',
      '        term(k) <= x(k);',
      '    end generate g_term;',
      '',
    ]);
  }
  out.add('    g_mul : for k in 0 to NTERM-1 generate');
  out.addAll(
      _mulInst(plan, name, 'u_mul', 'k', 'term(k)', 'prod(k)', win: 'WTERM'));
  out.addAll(['    end generate g_mul;', '']);
  return out;
}

List<String> _firChain(String name) => [
      '    -- Sum the products along a chain of adders, in tap order.',
      '    acc(0) <= prod(0);',
      '',
      '    g_sum : for k in 1 to NTERM-1 generate',
      '        u_add : entity work.${name}_add',
      '            generic map (WDATA => WDATA)',
      '            port map (a => acc(k-1), b => prod(k), sum => acc(k));',
      '    end generate g_sum;',
      '',
      '    output : process (clk)',
      '    begin',
      '        if rising_edge(clk) then',
      "            if resetn = '0' then",
      "                dout      <= (others => '0');",
      "                dout_strb <= '0';",
      '            else',
      "                if din_strb = '1' then",
      '                    dout <= acc(NTERM-1);',
      '                end if;',
      '                dout_strb <= din_strb;',
      '            end if;',
      '        end if;',
      '    end process output;',
    ];

List<String> _firTree(String name) => [
      '    -- Balanced adder tree: LEVELS deep instead of NTERM long, with a',
      '    -- register between levels so the clock is not held back by the whole',
      '    -- summation.  vld(L) is high in the cycle where level L holds this',
      "    -- sample's data, and is what enables the level after it.",
      '    g_leaf : for k in 0 to NTERM-1 generate',
      '        node(level_offset(0) + k) <= prod(k);',
      '    end generate g_leaf;',
      '',
      '    valid : process (clk)',
      '    begin',
      '        if rising_edge(clk) then',
      "            if resetn = '0' then",
      "                vld <= (others => '0');",
      '            else',
      '                vld <= vld(LEVELS-2 downto 0) & din_strb;',
      '            end if;',
      '        end if;',
      '    end process valid;',
      '',
      '    g_level : for L in 0 to LEVELS-1 generate',
      '        g_node : for i in 0 to level_count(L+1)-1 generate',
      '            signal partial : signed(WDATA-1 downto 0);',
      '            signal enable  : std_logic;',
      '        begin',
      '            g_add : if 2*i + 1 < level_count(L) generate',
      '                u_add : entity work.${name}_add',
      '                    generic map (WDATA => WDATA)',
      '                    port map (a => node(level_offset(L) + 2*i),',
      '                              b => node(level_offset(L) + 2*i + 1),',
      '                              sum => partial);',
      '            end generate g_add;',
      '',
      '            -- An odd one out waits a level rather than being added to',
      '            -- something that is not there.',
      '            g_pass : if 2*i + 1 >= level_count(L) generate',
      '                partial <= node(level_offset(L) + 2*i);',
      '            end generate g_pass;',
      '',
      '            g_en0 : if L = 0 generate',
      '                enable <= din_strb;',
      '            end generate g_en0;',
      '            g_enL : if L > 0 generate',
      '                enable <= vld(L-1);',
      '            end generate g_enL;',
      '',
      '            u_reg : entity work.${name}_delay',
      '                generic map (WDATA => WDATA)',
      '                port map (clk => clk, resetn => resetn, en => enable,',
      '                          d => partial,',
      '                          q => node(level_offset(L+1) + i));',
      '        end generate g_node;',
      '    end generate g_level;',
      '',
      '    output : process (clk)',
      '    begin',
      '        if rising_edge(clk) then',
      "            if resetn = '0' then",
      "                dout      <= (others => '0');",
      "                dout_strb <= '0';",
      '            else',
      "                if vld(LEVELS-1) = '1' then",
      '                    dout <= node(level_offset(LEVELS));',
      '                end if;',
      '                dout_strb <= vld(LEVELS-1);',
      '            end if;',
      '        end if;',
      '    end process output;',
    ];

List<String> _firMac(RtlPlan plan, String name) {
  final pre = plan.folded;
  final out = <String>[
    '    -- One multiplier, reused.  The delay line is a register file with a',
    '    -- write pointer rather than a shift chain, so any tap can be fetched',
    '    -- by index; the accumulator then walks the terms one per clock.',
    '    sample <= mem(rp);',
  ];
  if (pre) {
    final sub = plan.subtracts ? 'true' : 'false';
    out.addAll([
      '    mirror <= mem(rp2);',
      '',
      '    u_pre : entity work.${name}_addw',
      '        generic map (WDATA => WDATA, SUB => $sub)',
      '        port map (a => sample, b => mirror, sum => paired);',
      '',
    ]);
    if (plan.hasCentre) {
      out.addAll([
        '    -- The centre tap of an odd-length symmetric filter has no',
        '    -- partner, so on that term the pre-adder is bypassed.',
        '    term_in <= resize(sample, WTERM) when k = NTERM-1 else paired;',
      ]);
    } else {
      out.add('    term_in <= paired;');
    }
  } else {
    out.add('    term_in <= sample;');
  }
  out.addAll([
    '',
    '    -- One multiplier serves every tap, so the coefficient is looked up',
    '    -- per term rather than built into a multiplier.',
    '    coef_sel <= ${plan.fixedCoeffs ? 'to_signed(COEF(k), WCOEF);' : 'coeff((k+1)*WCOEF-1 downto k*WCOEF);'}',
    '',
    '    u_mul : entity work.${name}_mul',
    '        generic map (WDATA => WDATA, WIN => WTERM, WCOEF => WCOEF,',
    '                     FRAC => FRAC, FIXED => false, NEG => false)',
    '        port map (coef => coef_sel, din => term_in, dout => prod);',
    '',
    '    u_acc : entity work.${name}_add',
    '        generic map (WDATA => WDATA)',
    '        port map (a => acc, b => prod, sum => acc_next);',
    '',
    '    sequencer : process (clk)',
    '    begin',
    '        if rising_edge(clk) then',
    "            if resetn = '0' then",
    '                -- The delay line is cleared, as the shift-register',
    '                -- structures clear theirs: without it the first NTAPS',
    '                -- outputs would depend on whatever the memory held.',
    '                for i in 0 to NTAPS-1 loop',
    "                    mem(i) <= (others => '0');",
    '                end loop;',
    '                wp        <= 0;',
    '                rp        <= 0;',
    if (pre) '                rp2       <= 0;',
    '                k         <= 0;',
    "                busy      <= '0';",
    "                acc       <= (others => '0');",
    "                dout      <= (others => '0');",
    "                dout_strb <= '0';",
    '            else',
    "                dout_strb <= '0';",
    '',
    '                -- A strobe arriving mid-sum would corrupt it, so it is',
    '                -- ignored: keep them LATENCY clocks apart.',
    "                if din_strb = '1' and busy = '0' then",
    '                    mem(wp) <= din;',
    '                    rp      <= wp;',
    if (pre) ...[
      '                    if wp = NTAPS-1 then',
      '                        rp2 <= 0;',
      '                    else',
      '                        rp2 <= wp + 1;',
      '                    end if;',
    ],
    '                    if wp = NTAPS-1 then',
    '                        wp <= 0;',
    '                    else',
    '                        wp <= wp + 1;',
    '                    end if;',
    '                    k       <= 0;',
    "                    acc     <= (others => '0');",
    "                    busy    <= '1';",
    "                elsif busy = '1' then",
    '                    acc <= acc_next;',
    '                    if k = NTERM-1 then',
    "                        busy      <= '0';",
    '                        dout      <= acc_next;',
    "                        dout_strb <= '1';",
    '                    else',
    '                        k <= k + 1;',
    '                        if rp = 0 then',
    '                            rp <= NTAPS-1;',
    '                        else',
    '                            rp <= rp - 1;',
    '                        end if;',
    if (pre) ...[
      '                        if rp2 = NTAPS-1 then',
      '                            rp2 <= 0;',
      '                        else',
      '                            rp2 <= rp2 + 1;',
      '                        end if;',
    ],
    '                    end if;',
    '                end if;',
    '            end if;',
    '        end if;',
    '    end process sequencer;',
  ]);
  return out;
}

List<String> _firSignals(RtlPlan plan) {
  if (plan.structure == 'mac') {
    return [
      '    signal mem      : data_array_t(0 to NTAPS-1);',
      '    signal wp, rp   : integer range 0 to NTAPS-1;',
      if (plan.folded) '    signal rp2      : integer range 0 to NTAPS-1;',
      '    signal k        : integer range 0 to NTERM-1;',
      '    signal busy     : std_logic;',
      '    signal acc      : signed(WDATA-1 downto 0);',
      '    signal acc_next : signed(WDATA-1 downto 0);',
      '    signal sample   : signed(WDATA-1 downto 0);',
      '    signal term_in  : signed(WTERM-1 downto 0);',
      '    signal prod     : signed(WDATA-1 downto 0);',
      '    signal coef_sel : signed(WCOEF-1 downto 0);',
      if (plan.folded) ...[
        '    signal mirror   : signed(WDATA-1 downto 0);',
        '    signal paired   : signed(WTERM-1 downto 0);',
      ],
    ];
  }

  final out = <String>[
    if (plan.folded) '    constant NPAIR : positive := ${plan.npairs};',
    '    signal x    : data_array_t(0 to NTAPS-1);',
    '    signal term : term_array_t(0 to NTERM-1);',
    '    signal prod : data_array_t(0 to NTERM-1);',
  ];
  if (plan.structure == 'tree') {
    out.addAll([
      '',
      '    constant LEVELS : positive := LATENCY - 1;',
      '',
      '    -- How wide each level of the tree is, and where it starts in the',
      '    -- flat array of nodes.',
      '    function level_count (lvl : natural) return natural is',
      '        variable n : natural := NTERM;',
      '    begin',
      '        for i in 1 to lvl loop',
      '            n := (n + 1) / 2;',
      '        end loop;',
      '        return n;',
      '    end function level_count;',
      '',
      '    function level_offset (lvl : natural) return natural is',
      '        variable total : natural := 0;',
      '    begin',
      '        for i in 0 to lvl-1 loop',
      '            total := total + level_count(i);',
      '        end loop;',
      '        return total;',
      '    end function level_offset;',
      '',
      '    signal node : data_array_t(0 to level_offset(LEVELS+1)-1);',
      '    signal vld  : std_logic_vector(LEVELS-1 downto 0);',
    ]);
  } else {
    out.add('    signal acc  : data_array_t(0 to NTERM-1);');
  }
  return out;
}

String firSource(fir.RemezResult res, fx.Fixed? fixed, RtlOptions opts) =>
    renderFir(_check(planFor('fir', res, fixed, opts)));

String renderFir(RtlPlan plan) {
  _check(plan);
  final name = plan.name;
  final lines = <String>[
    ..._preamble(plan),
    ..._library(name, folded: plan.folded),
    '-- ---------------------------------------------------------------------',
    '-- $name: the filter itself.',
    '-- ---------------------------------------------------------------------',
    ..._head,
    'entity $name is',
    ..._generics(plan),
    ..._ports(plan),
    'end entity $name;',
    '',
    'architecture rtl of $name is',
    ..._declarations(plan),
    ..._firSignals(plan),
    'begin',
    if (plan.structure == 'mac')
      ..._firMac(plan, name)
    else ...[
      ..._firProducts(plan, name),
      ...(plan.structure == 'tree' ? _firTree(name) : _firChain(name)),
    ],
    'end architecture rtl;',
    '',
  ];
  return lines.join('\n');
}

// ---------------------------------------------------------------------------
// IIR
// ---------------------------------------------------------------------------

String iirSource(Object res, fx.Fixed? fixed, RtlOptions opts) =>
    renderIir(_check(planFor('iir', res, fixed, opts)));

String renderIir(RtlPlan plan) {
  _check(plan);
  final name = plan.name;
  final lines = <String>[
    ..._preamble(plan),
    ..._library(name, folded: plan.folded),
    '-- ---------------------------------------------------------------------',
    '-- $name: the filter itself.',
    '-- ---------------------------------------------------------------------',
    ..._head,
    'entity $name is',
    ..._generics(plan),
    ..._ports(plan),
    'end entity $name;',
    '',
    'architecture rtl of $name is',
    ..._declarations(plan),
    '    signal chain : data_array_t(0 to NSEC);',
    'begin',
    '    -- chain(0) is the input; chain(s+1) is the output of section s.',
    '    chain(0) <= din;',
    '',
    '    g_sec : for s in 0 to NSEC-1 generate',
    '        signal x  : signed(WDATA-1 downto 0);',
    '        signal y  : signed(WDATA-1 downto 0);',
    '        signal s1, s2 : signed(WDATA-1 downto 0);      -- delay outputs',
    '        signal pb0, pb1, pb2, pa1, pa2 : signed(WDATA-1 downto 0);',
    '        signal u1, s1_next, s2_next    : signed(WDATA-1 downto 0);',
    '    begin',
    '        x <= chain(s);',
    '',
    '        -- The five multipliers.  a1 and a2 get NEG, which turns their',
    '        -- adds into the subtractions the recursion wants.',
  ];
  const slots = [
    ('pb0', 0, 'false'),
    ('pb1', 1, 'false'),
    ('pb2', 2, 'false'),
    ('pa1', 3, 'true'),
    ('pa2', 4, 'true'),
  ];
  for (final (target, slot, neg) in slots) {
    final source = target.startsWith('pb') ? 'x' : 'y';
    lines.addAll(_mulInst(
        plan, name, 'u_mul_$target', 's*5 + $slot', source, target,
        neg: neg));
    lines.add('');
  }
  lines.addAll([
    '        -- y = b0*x + s1',
    '        u_add_y : entity work.${name}_add',
    '            generic map (WDATA => WDATA)',
    '            port map (a => pb0, b => s1, sum => y);',
    '',
    '        -- s1 <- b1*x - a1*y + s2',
    '        u_add_u1 : entity work.${name}_add',
    '            generic map (WDATA => WDATA)',
    '            port map (a => pb1, b => pa1, sum => u1);',
    '        u_add_s1 : entity work.${name}_add',
    '            generic map (WDATA => WDATA)',
    '            port map (a => u1, b => s2, sum => s1_next);',
    '',
    '        -- s2 <- b2*x - a2*y',
    '        u_add_s2 : entity work.${name}_add',
    '            generic map (WDATA => WDATA)',
    '            port map (a => pb2, b => pa2, sum => s2_next);',
    '',
    '        u_z1 : entity work.${name}_delay',
    '            generic map (WDATA => WDATA)',
    '            port map (clk => clk, resetn => resetn, en => din_strb,',
    '                      d => s1_next, q => s1);',
    '        u_z2 : entity work.${name}_delay',
    '            generic map (WDATA => WDATA)',
    '            port map (clk => clk, resetn => resetn, en => din_strb,',
    '                      d => s2_next, q => s2);',
    '',
    '        chain(s+1) <= y;',
    '    end generate g_sec;',
    '',
    '    output : process (clk)',
    '    begin',
    '        if rising_edge(clk) then',
    "            if resetn = '0' then",
    "                dout      <= (others => '0');",
    "                dout_strb <= '0';",
    '            else',
    "                if din_strb = '1' then",
    '                    dout <= chain(NSEC);',
    '                end if;',
    '                dout_strb <= din_strb;',
    '            end if;',
    '        end if;',
    '    end process output;',
    'end architecture rtl;',
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

/// A testbench that drives known stimulus and checks the known answers.
String testbenchFor(String kind, Object res, fx.Fixed? fixed, RtlOptions opts,
        {List<int>? samples, int seed = 20240}) =>
    testbenchForPlan(planFor(kind, res, fixed, opts),
        samples: samples, seed: seed);

String testbenchForPlan(RtlPlan plan, {List<int>? samples, int seed = 20240}) {
  _check(plan);
  final stim = stimulus(plan, samples: samples, seed: seed);
  final expect = plan.simulate(stim);
  final name = plan.name;
  final gap = plan.latency + 2;

  final lines = <String>[
    '-- ${'=' * 69}',
    '-- ${name}_tb: self-checking testbench for $name.',
    '--',
    '-- ${stim.length} samples, full scale among them so that the saturating',
    '-- adders are exercised, with the expected output of every one as',
    "-- computed by the generator's model of this datapath.  Reports PASS and",
    '-- stops; asserts on the first mismatch.  Latency ${plan.latency}, so the',
    '-- strobes here are $gap clocks apart.',
    '--',
    '--     \$ ghdl -a --std=93 <design>.vhd <this file>',
    '--     \$ ghdl -e --std=93 ${name}_tb && ghdl -r ${name}_tb',
    '-- ${'=' * 69}',
    '',
    ..._head,
    'entity ${name}_tb is',
    'end entity ${name}_tb;',
    '',
    'architecture sim of ${name}_tb is',
    '    constant WCOEF    : positive := ${plan.wcoef};',
    '    constant HEADROOM : natural  := ${plan.headroom};',
    '    constant WDATA    : positive := WCOEF + HEADROOM;',
    '    constant NSAMPLES : positive := ${stim.length};'
        '   -- not NS: that is a time unit',
    '    constant GAP      : positive := $gap;',
    '',
    '    type int_array_t is array (natural range <>) of integer;',
    '    constant STIM : int_array_t(0 to NSAMPLES-1) := (',
    ..._wrap(stim),
    '    );',
    '    constant EXPECT : int_array_t(0 to NSAMPLES-1) := (',
    ..._wrap(expect),
    '    );',
    '',
  ];

  final packing = <String>[];
  if (!plan.fixedCoeffs) {
    final nbits = plan.coeffs.length * plan.wcoef;
    final parts = plan.coeffs.reversed
        .map((v) => 'std_logic_vector(to_signed($v, WCOEF))')
        .join(' & ');
    lines.addAll([
      '    -- The same coefficients the fixed build would compile in,',
      '    -- packed with slice 0 in the low bits.',
      '    signal coeff : signed($nbits-1 downto 0);',
      '',
    ]);
    packing.add('    coeff <= signed($parts);');
  }

  lines.addAll([
    "    signal clk       : std_logic := '0';",
    "    signal resetn    : std_logic := '0';",
    "    signal din_strb  : std_logic := '0';",
    "    signal din       : signed(WDATA-1 downto 0) := (others => '0');",
    '    signal dout      : signed(WDATA-1 downto 0);',
    '    signal dout_strb : std_logic;',
    '    signal running   : boolean := true;',
    '    signal seen      : natural := 0;',
    'begin',
    '    clock : process',
    '    begin',
    '        while running loop',
    "            clk <= '0';",
    '            wait for 5 ns;',
    "            clk <= '1';",
    '            wait for 5 ns;',
    '        end loop;',
    '        wait;',
    '    end process clock;',
    '',
    ...packing,
    if (packing.isNotEmpty) '',
    '    dut : entity work.$name',
    '        port map (clk => clk, resetn => resetn, din => din,',
    '                  din_strb => din_strb,',
    if (!plan.fixedCoeffs) '                  coeff => coeff,',
    '                  dout => dout, dout_strb => dout_strb);',
    '',
    '    stimulus : process',
    '    begin',
    '        for i in 1 to 3 loop',
    '            wait until rising_edge(clk);',
    '        end loop;',
    "        resetn <= '1';",
    '        wait until rising_edge(clk);',
    '        for i in 0 to NSAMPLES-1 loop',
    '            din      <= to_signed(STIM(i), WDATA);',
    "            din_strb <= '1';",
    '            wait until rising_edge(clk);',
    "            din_strb <= '0';",
    '            for g in 1 to GAP-1 loop',
    '                wait until rising_edge(clk);',
    '            end loop;',
    '        end loop;',
    '        for g in 1 to GAP+4 loop',
    '            wait until rising_edge(clk);',
    '        end loop;',
    '        assert seen = NSAMPLES',
    '            report "FAIL: " & integer\'image(seen) & " outputs, expected "',
    "                   & integer'image(NSAMPLES)",
    '            severity failure;',
    '        report "PASS: " & integer\'image(seen) & " samples matched";',
    '        running <= false;',
    '        wait;',
    '    end process stimulus;',
    '',
    '    checker : process (clk)',
    '    begin',
    '        if rising_edge(clk) then',
    "            if resetn = '1' and dout_strb = '1' then",
    '                assert dout = to_signed(EXPECT(seen), WDATA)',
    '                    report "FAIL at " & integer\'image(seen) & ": got "',
    "                           & integer'image(to_integer(dout))",
    '                           & ", expected "',
    "                           & integer'image(EXPECT(seen))",
    '                    severity failure;',
    '                seen <= seen + 1;',
    '            end if;',
    '        end if;',
    '    end process checker;',
    'end architecture sim;',
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
