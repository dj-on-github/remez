//-----------------------------------------------------------------------------
// mult_fp24.sv
//
// Fast, fully synchronous, 3-stage pipelined floating-point multiplier for a
// custom 29-bit "fp24" format:
//
//     [28]    sign
//     [27:20] exponent  (8 bits, bias = 127)
//     [19:0]  mantissa  (20 bits, implicit leading 1 for normals)
//
// Behavior:
//   - Assert `go` for one clock with operands on `x` and `y`.
//   - Exactly 3 clocks later `valid` pulses high for one cycle and the
//     product is available on `z`.
//   - New operations may be issued on consecutive clocks (fully pipelined,
//     II = 1).
//
// Arithmetic conventions (documented, hardware-friendly):
//   - Rounding: round-to-nearest-even.
//   - Denormal inputs (exponent == 0, mantissa != 0) are flushed to zero.
//   - Overflow saturates to the largest normal (exp = 254, mantissa = all 1s).
//   - Underflow flushes to zero.
//   - Zero results carry the XOR of the input signs (IEEE-style signed zero).
//
// Synthesizable SystemVerilog; no latches, single clock, async active-low
// reset on control only (data path registers are unreset for speed/area).
//-----------------------------------------------------------------------------

module mult_fp24 (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        go,
    input  logic [28:0] x,
    input  logic [28:0] y,
    output logic [28:0] z,
    output logic        valid
);

    localparam int EXP_SAT    = 254;   // largest normal exponent field

    //--------------------------------------------------------------------------
    // Stage 1 : unpack operands
    //--------------------------------------------------------------------------
    logic        s1_sign;
    logic [9:0]  s1_ex, s1_ey;     // zero-extended exponents
    logic [20:0] s1_mx, s1_my;     // significands with implicit leading 1
    logic        s1_zero;          // either operand is (flushed-to-)zero
    logic        s1_vld;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_vld <= 1'b0;
        end else begin
            s1_vld <= go;
        end
    end

    always_ff @(posedge clk) begin
        if (go) begin
            s1_sign <= x[28] ^ y[28];
            s1_ex   <= {2'b00, x[27:20]};
            s1_ey   <= {2'b00, y[27:20]};
            // implicit leading 1 for normals; flush denormals to zero
            s1_mx   <= (x[27:20] != 8'd0) ? {1'b1, x[19:0]} : 21'd0;
            s1_my   <= (y[27:20] != 8'd0) ? {1'b1, y[19:0]} : 21'd0;
            s1_zero <= (x[27:20] == 8'd0) || (y[27:20] == 8'd0);
        end
    end

    //--------------------------------------------------------------------------
    // Stage 2 : 21x21 significand multiply + exponent add
    //--------------------------------------------------------------------------
    logic [41:0] s2_prod;          // product in [2^40, 2^42)
    logic signed [11:0] s2_e;      // unbiased result exponent (pre-normalize)
    logic        s2_sign;
    logic        s2_zero;
    logic        s2_vld;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_vld <= 1'b0;
        end else begin
            s2_vld <= s1_vld;
        end
    end

    always_ff @(posedge clk) begin
        if (s1_vld) begin
            s2_prod <= s1_mx * s1_my;
            // unbiased exponent = (ex - BIAS) + (ey - BIAS)
            s2_e    <= $signed({2'b00, s1_ex}) + $signed({2'b00, s1_ey})
                       - 12'sd254;
            s2_sign <= s1_sign;
            s2_zero <= s1_zero;
        end
    end

    //--------------------------------------------------------------------------
    // Stage 3 : normalize, round-to-nearest-even, handle over/underflow, pack
    //--------------------------------------------------------------------------
    logic        s3_vld;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s3_vld <= 1'b0;
        end else begin
            s3_vld <= s2_vld;
        end
    end

    // Combinational normalize/round for stage-3 register input
    logic        c_sign;
    logic signed [11:0] c_e;
    logic [20:0] c_m;              // normalized significand (leading 1)
    logic        c_g, c_r, c_s;    // guard, round, sticky
    /* verilator lint_off UNUSEDSIGNAL */
    logic [21:0] c_m_round;        // significand after rounding (may carry)
    /* verilator lint_on UNUSEDSIGNAL */
    logic signed [11:0] c_e_round;
    logic [28:0] c_z;

    always_comb begin
        // Normalize: product is either 1xx... (bit41) or 01x... (bit40)
        if (s2_prod[41]) begin
            c_m = s2_prod[41:21];
            c_e = s2_e + 12'sd1;
            {c_g, c_r} = s2_prod[20:19];
            c_s = |s2_prod[18:0];
        end else begin
            c_m = s2_prod[40:20];
            c_e = s2_e;
            {c_g, c_r} = s2_prod[19:18];
            c_s = |s2_prod[17:0];
        end

        // Round to nearest even
        if (c_g && (c_r || c_s || c_m[0]))
            c_m_round = {1'b0, c_m} + 22'd1;
        else
            c_m_round = {1'b0, c_m};

        // Handle rounding carry-out (11...1 + 1 -> 100...0, shift right)
        if (c_m_round[21]) begin
            c_e_round = c_e + 12'sd1;
        end else begin
            c_e_round = c_e;
        end

        c_sign = s2_sign;

        // Pack with exception handling
        if (s2_zero) begin
            c_z = {c_sign, 8'd0, 20'd0};                      // signed zero
        end else if (c_e_round >= 12'sd255) begin
            c_z = {c_sign, EXP_SAT[7:0], 20'hFFFFF};          // overflow: saturate
        end else if (c_e_round <= 12'sd0) begin
            c_z = {c_sign, 8'd0, 20'd0};                      // underflow: flush to zero
        end else begin
            // If rounding carried, significand is 100...0 -> stored mantissa 0
            c_z = {c_sign,
                   c_e_round[7:0],
                   c_m_round[21] ? 20'd0 : c_m_round[19:0]};
        end
    end

    always_ff @(posedge clk) begin
        if (s2_vld)
            z <= c_z;
    end

    assign valid = s3_vld;

endmodule
