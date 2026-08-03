-- =====================================================================
-- dut_tb: self-checking testbench for dut.
--
-- 50 samples, full scale among them so that the saturating
-- adders are exercised, with the expected output of every one as
-- computed by the generator's model of this datapath.  Reports PASS and
-- stops; asserts on the first mismatch.  Latency 1, so the
-- strobes here are 3 clocks apart.
--
--     $ ghdl -a --std=93 <design>.vhd <this file>
--     $ ghdl -e --std=93 dut_tb && ghdl -r dut_tb
-- =====================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dut_tb is
end entity dut_tb;

architecture sim of dut_tb is
    constant WCOEF    : positive := 10;
    constant HEADROOM : natural  := 2;
    constant WDATA    : positive := WCOEF + HEADROOM;
    constant NSAMPLES : positive := 50;   -- not NS: that is a time unit
    constant GAP      : positive := 3;

    type int_array_t is array (natural range <>) of integer;
    constant STIM : int_array_t(0 to NSAMPLES-1) := (
        1024, -1024, 2047, -2048, 0, 2047, -2048, 512,
        -512, 0, 280, -424, 330, 539, -454, 248,
        469, 937, 817, -1, 724, 967, -101, -57,
        -131, -402, -313, 753, -575, -988, -526, 737,
        664, 844, 366, 147, -498, -954, -858, 906,
        -748, 1022, -650, -98, 135, 330, -603, 825,
        794, 194
    );
    constant EXPECT : int_array_t(0 to NSAMPLES-1) := (
        54, 40, 64, -25, -127, 54, 258, 384,
        189, -90, -147, 24, 129, 6, -237, -309,
        -102, 114, 324, 216, 60, 83, 228, 531,
        698, 638, 535, 552, 572, 318, -135, -325,
        -54, 312, 245, -315, -752, -578, 114, 818,
        970, 541, -178, -734, -804, -395, 143, 386,
        262, -33
    );

    signal clk       : std_logic := '0';
    signal resetn    : std_logic := '0';
    signal din_strb  : std_logic := '0';
    signal din       : signed(WDATA-1 downto 0) := (others => '0');
    signal dout      : signed(WDATA-1 downto 0);
    signal dout_strb : std_logic;
    signal running   : boolean := true;
    signal seen      : natural := 0;
begin
    clock : process
    begin
        while running loop
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end loop;
        wait;
    end process clock;

    dut : entity work.dut
        port map (clk => clk, resetn => resetn, din => din,
                  din_strb => din_strb,
                  dout => dout, dout_strb => dout_strb);

    stimulus : process
    begin
        for i in 1 to 3 loop
            wait until rising_edge(clk);
        end loop;
        resetn <= '1';
        wait until rising_edge(clk);
        for i in 0 to NSAMPLES-1 loop
            din      <= to_signed(STIM(i), WDATA);
            din_strb <= '1';
            wait until rising_edge(clk);
            din_strb <= '0';
            for g in 1 to GAP-1 loop
                wait until rising_edge(clk);
            end loop;
        end loop;
        for g in 1 to GAP+4 loop
            wait until rising_edge(clk);
        end loop;
        assert seen = NSAMPLES
            report "FAIL: " & integer'image(seen) & " outputs, expected "
                   & integer'image(NSAMPLES)
            severity failure;
        report "PASS: " & integer'image(seen) & " samples matched";
        running <= false;
        wait;
    end process stimulus;

    checker : process (clk)
    begin
        if rising_edge(clk) then
            if resetn = '1' and dout_strb = '1' then
                assert dout = to_signed(EXPECT(seen), WDATA)
                    report "FAIL at " & integer'image(seen) & ": got "
                           & integer'image(to_integer(dout))
                           & ", expected "
                           & integer'image(EXPECT(seen))
                    severity failure;
                seen <= seen + 1;
            end if;
        end if;
    end process checker;
end architecture sim;
