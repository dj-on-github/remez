//-----------------------------------------------------------------------------
// add_fp24.sv
//
// Fast, fully synchronous, 3-stage pipelined floating-point adder for the
// custom 29-bit "fp24" format (same as mult_fp24):
//
//     [28]    sign
//     [27:20] exponent  (8 bits, bias = 127)
//     [19:0]  mantissa  (20 bits, implicit leading 1 for normals)
//
// Behavior:
//   - Assert `go` for one clock with operands on `x` and `y`.
//   - Exactly 3 clocks later `valid` pulses high for one cycle and the
//     sum is available on `z`.
//   - New operations may be issued on consecutive clocks (fully pipelined,
//     II = 1).
//
// Arithmetic conventions (identical to mult_fp24):
//   - Rounding: round-to-nearest-even.
//   - Denormal inputs (exponent == 0, mantissa != 0) are flushed to zero.
//   - Overflow saturates to the largest normal (exp = 254, mantissa = all 1s).
//   - Underflow flushes to zero (sign of the result is kept).
//   - Exact cancellation (a + (-a)) yields +0; (+0) + (-0) = +0 and
//     (-0) + (-0) = -0 per IEEE round-to-nearest rules.
//   - A zero operand passes the other operand through unchanged.
//
// Synthesizable SystemVerilog; no latches, single clock, async active-low
// reset on control only (data path registers are unreset for speed/area).
//-----------------------------------------------------------------------------

module add_fp24 (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        go,
    input  logic [28:0] x,
    input  logic [28:0] y,
    output logic [28:0] z,
    output logic        valid
);

    localparam int EXP_SAT = 254;      // largest normal exponent field

    //--------------------------------------------------------------------------
    // Stage 1 : unpack, order by magnitude, compute alignment shift
    //--------------------------------------------------------------------------
    logic              s1_vld;
    logic              s1_sign;        // sign of larger-magnitude operand
    logic signed [12:0] s1_e;          // exponent field of larger operand
    logic [20:0]       s1_mbig;        // significand of larger (implicit 1)
    logic [20:0]       s1_msmall;      // significand of smaller
    logic [8:0]        s1_shift;       // exponent difference (>= 0)
    logic              s1_sub;         // effective subtraction (signs differ)
    logic              s1_bypass;      // one operand is (flushed-to-)zero
    logic [28:0]       s1_bypass_val;

    // combinational unpack
    logic        c_xzero, c_yzero;
    logic        c_xbig;
    logic [28:0] c_big, c_small;

    always_comb begin
        c_xzero = (x[27:20] == 8'd0);
        c_yzero = (y[27:20] == 8'd0);
        // magnitude order on {exponent, mantissa} (valid for normals)
        c_xbig  = (x[27:0] >= y[27:0]);
        c_big   = c_xbig ? x : y;
        c_small = c_xbig ? y : x;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) s1_vld <= 1'b0;
        else        s1_vld <= go;
    end

    always_ff @(posedge clk) begin
        if (go) begin
            s1_sign   <= c_big[28];
            s1_e      <= {5'b0, c_big[27:20]};
            s1_mbig   <= {1'b1, c_big[19:0]};
            s1_msmall <= {1'b1, c_small[19:0]};
            s1_shift  <= {1'b0, c_big[27:20]} - {1'b0, c_small[27:20]};
            s1_sub    <= c_big[28] ^ c_small[28];
            s1_bypass <= c_xzero || c_yzero;
            if (c_xzero && c_yzero)
                s1_bypass_val <= {x[28] & y[28], 8'd0, 20'd0};  // +-0 rules
            else if (c_xzero)
                s1_bypass_val <= y;
            else
                s1_bypass_val <= x;
        end
    end

    //--------------------------------------------------------------------------
    // Stage 2 : align smaller significand, add/subtract (24-bit + carry,
    //           3 extra bits: guard/round/sticky capture)
    //--------------------------------------------------------------------------
    logic              s2_vld;
    logic              s2_sign;
    logic signed [12:0] s2_e;
    logic [24:0]       s2_sum;
    logic              s2_sticky;
    logic              s2_bypass;
    logic [28:0]       s2_bypass_val;

    // combinational align/add
    logic [4:0]  c_sh;
    logic [23:0] c_big_ext, c_small_pre, c_small_ext;
    logic [24:0] c_mask;
    logic        c_sticky;
    logic [24:0] c_sum;

    always_comb begin
        // clamp: beyond 24 shifts the small operand contributes only sticky
        c_sh        = (s1_shift > 9'd24) ? 5'd24 : s1_shift[4:0];
        c_big_ext   = {s1_mbig, 3'b000};
        c_small_pre = {s1_msmall, 3'b000};
        c_small_ext = c_small_pre >> c_sh;
        c_mask      = (25'd1 << c_sh) - 25'd1;
        c_sticky    = |({1'b0, c_small_pre} & c_mask);
        if (s1_sub)
            c_sum = {1'b0, c_big_ext} - {1'b0, c_small_ext};  // never negative
        else
            c_sum = {1'b0, c_big_ext} + {1'b0, c_small_ext};
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) s2_vld <= 1'b0;
        else        s2_vld <= s1_vld;
    end

    always_ff @(posedge clk) begin
        if (s1_vld) begin
            s2_sign       <= s1_sign;
            s2_e          <= s1_e;
            s2_sum        <= c_sum;
            s2_sticky     <= c_sticky;
            s2_bypass     <= s1_bypass;
            s2_bypass_val <= s1_bypass_val;
        end
    end

    //--------------------------------------------------------------------------
    // Stage 3 : normalize (leading-zero count), round-to-nearest-even,
    //           handle over/underflow, pack
    //--------------------------------------------------------------------------
    logic s3_vld;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) s3_vld <= 1'b0;
        else        s3_vld <= s2_vld;
    end

    // count leading zeros of a 24-bit vector (returns 24 for all-zero)
    function automatic logic [4:0] clz24(input logic [23:0] v);
        logic [4:0] n;
        begin
            n = 5'd24;
            for (int i = 23; i >= 0; i--)
                if (v[i] && (n == 5'd24))
                    n = 5'(23 - i);
            return n;
        end
    endfunction

    logic signed [12:0] c_e;
    logic [23:0]       c_w;            // normalized significand, bit23 = 1
    logic              c_st;
    logic              c_g, c_r, c_s;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [21:0]       c_mr;           // rounded significand (may carry)
    /* verilator lint_on UNUSEDSIGNAL */
    logic [4:0]        c_lz;
    logic [28:0]       c_z;

    always_comb begin
        // defaults (avoid latches; overridden on the arithmetic path)
        c_e  = 13'sd0;
        c_w  = 24'd0;
        c_st = 1'b0;
        c_g  = 1'b0;
        c_r  = 1'b0;
        c_s  = 1'b0;
        c_mr = 22'd0;
        c_lz = 5'd0;

        if (s2_bypass) begin
            c_z = s2_bypass_val;
        end else if (s2_sum == 25'd0) begin
            c_z = {1'b0, 8'd0, 20'd0};               // exact cancellation -> +0
        end else begin
            if (s2_sum[24]) begin
                // addition carried out: shift right one
                c_w  = s2_sum[24:1];
                c_e  = s2_e + 13'sd1;
                c_st = s2_sticky | s2_sum[0];
            end else begin
                // subtraction may need multi-bit left normalization
                c_lz = clz24(s2_sum[23:0]);
                c_w  = s2_sum[23:0] << c_lz;
                c_e  = s2_e - {8'd0, c_lz};
                c_st = s2_sticky;
            end

            // round to nearest even on 24-bit significand
            c_g = c_w[2];
            c_r = c_w[1];
            c_s = c_w[0] | c_st;
            if (c_g && (c_r || c_s || c_w[3]))
                c_mr = {1'b0, c_w[23:3]} + 22'd1;
            else
                c_mr = {1'b0, c_w[23:3]};

            if (c_mr[21]) c_e = c_e + 13'sd1;        // rounding carried out

            if (c_e >= 13'sd255)
                c_z = {s2_sign, EXP_SAT[7:0], 20'hFFFFF};   // overflow: saturate
            else if (c_e <= 13'sd0)
                c_z = {s2_sign, 8'd0, 20'd0};               // underflow: zero
            else
                c_z = {s2_sign, c_e[7:0], c_mr[21] ? 20'd0 : c_mr[19:0]};
        end
    end

    always_ff @(posedge clk) begin
        if (s2_vld)
            z <= c_z;
    end

    assign valid = s3_vld;

endmodule
