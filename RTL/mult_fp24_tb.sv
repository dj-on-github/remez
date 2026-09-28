//-----------------------------------------------------------------------------
// mult_fp24_tb.sv
//
// Stand-alone, self-checking testbench for mult_fp24.
//
//   - Golden reference model (integer arithmetic, mirrors the documented
//     fp24 conventions: RNE rounding, denormal flush, overflow saturation,
//     underflow flush).
//   - Directed corner-case tests (single-issue, checks one-cycle valid pulse).
//   - Randomized tests issued back-to-back to exercise the pipeline at II=1.
//
// Build & run, e.g. with Verilator:
//   $ verilator --binary --timing mult_fp24_tb.sv mult_fp24.sv -o sim
//   $ ./obj_dir/sim
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

module mult_fp24_tb;

    logic        clk = 1'b0;
    logic        rst_n;
    logic        go;
    logic [28:0] x, y;
    logic [28:0] z;
    logic        valid;

    int errors     = 0;
    int checks     = 0;
    int issued     = 0;

    //--------------------------------------------------------------------------
    // DUT
    //--------------------------------------------------------------------------
    mult_fp24 dut (
        .clk   (clk),
        .rst_n (rst_n),
        .go    (go),
        .x     (x),
        .y     (y),
        .z     (z),
        .valid (valid)
    );

    //--------------------------------------------------------------------------
    // Clock
    //--------------------------------------------------------------------------
    always #5 clk = ~clk;

    //--------------------------------------------------------------------------
    // Golden reference model
    //--------------------------------------------------------------------------
    function automatic logic [28:0] ref_mult(input logic [28:0] a,
                                             input logic [28:0] b);
        logic              s;
        logic [20:0]       ma, mb;
        logic [41:0]       p;
        logic signed [12:0] e;
        logic [20:0]       m;
        logic              g, r, st;
        logic [21:0]       mr;
        begin
            s = a[28] ^ b[28];
            // zero / flushed-denormal operand -> signed zero
            if ((a[27:20] == 8'd0) || (b[27:20] == 8'd0))
                return {s, 8'd0, 20'd0};

            ma = {1'b1, a[19:0]};
            mb = {1'b1, b[19:0]};
            p  = ma * mb;
            e  = $signed({5'b0, a[27:20]}) + $signed({5'b0, b[27:20]})
                 - 13'sd254;

            if (p[41]) begin
                m  = p[41:21];
                e  = e + 13'sd1;
                g  = p[20];
                r  = p[19];
                st = |p[18:0];
            end else begin
                m  = p[40:20];
                g  = p[19];
                r  = p[18];
                st = |p[17:0];
            end

            // round to nearest even
            if (g && (r || st || m[0]))
                mr = {1'b0, m} + 22'd1;
            else
                mr = {1'b0, m};

            if (mr[21]) e = e + 13'sd1;   // rounding carried out

            if (e >= 255) return {s, 8'd254, 20'hFFFFF};  // overflow: saturate
            if (e <= 0)   return {s, 8'd0,   20'd0};      // underflow: zero
            return {s, e[7:0], mr[21] ? 20'd0 : mr[19:0]};
        end
    endfunction

    //--------------------------------------------------------------------------
    // Helpers
    //--------------------------------------------------------------------------
    function automatic logic [28:0] mk(input logic        s,
                                       input logic [7:0]  e,
                                       input logic [19:0] m);
        return {s, e, m};
    endfunction

    // Single-issue test: drive one operation, expect one result and a
    // single-cycle valid pulse.
    task automatic single(input logic [28:0] a, input logic [28:0] b,
                          input string name);
        logic [28:0] exp_z;
        begin
            exp_z = ref_mult(a, b);
            @(negedge clk);
            x = a; y = b; go = 1'b1;
            @(negedge clk);
            go = 1'b0; x = '0; y = '0;
            wait (valid === 1'b1);
            @(negedge clk);              // sample mid-pulse
            checks++;
            if (z !== exp_z) begin
                errors++;
                $display("FAIL [%s] x=%h y=%h : z=%h expected=%h",
                         name, a, b, z, exp_z);
            end
            @(negedge clk);
            if (valid !== 1'b0) begin
                errors++;
                $display("FAIL [%s] valid is not a single-cycle pulse", name);
            end
        end
    endtask

    //--------------------------------------------------------------------------
    // Back-to-back (pipelined) monitor: every valid pops one expected value.
    // Active only during the pipelined phase (pipe_mode).
    //--------------------------------------------------------------------------
    logic [28:0] exp_q[$];
    logic        pipe_mode = 1'b0;

    always @(negedge clk) begin
        if (pipe_mode && rst_n && valid) begin
            logic [28:0] e;
            if (exp_q.size() == 0) begin
                errors++;
                $display("FAIL: unexpected valid pulse, z=%h", z);
            end else begin
                e = exp_q.pop_front();
                checks++;
                if (z !== e) begin
                    errors++;
                    $display("FAIL [pipe] z=%h expected=%h", z, e);
                end
            end
        end
    end

    // Issue one operation per clock (call repeatedly on consecutive clocks)
    task automatic issue(input logic [28:0] a, input logic [28:0] b);
        begin
            @(negedge clk);
            x = a; y = b; go = 1'b1;
            exp_q.push_back(ref_mult(a, b));
            issued++;
        end
    endtask

    //--------------------------------------------------------------------------
    // Random operand generators
    //--------------------------------------------------------------------------
    function automatic logic [28:0] rand_fp();
        logic        s;
        logic [7:0]  e;
        logic [19:0] m;
        begin
            s = 1'($urandom_range(0, 1));
            // bias exponents toward the mid range, but allow extremes so
            // over/underflow paths get hit
            case ($urandom_range(0, 9))
                0:       e = 8'($urandom_range(1, 4));       // tiny -> underflow
                1:       e = 8'($urandom_range(250, 254));   // huge -> overflow
                default: e = 8'($urandom_range(60, 195));    // mid range
            endcase
            // sometimes short significands -> exact halfway rounding ties
            if ($urandom_range(0, 3) == 0)
                m = 20'($urandom_range(0, 15)) << $urandom_range(0, 16);
            else
                m = 20'({$urandom, $urandom});
            return {s, e, m};
        end
    endfunction

    //--------------------------------------------------------------------------
    // Test sequence
    //--------------------------------------------------------------------------
    initial begin
        logic [28:0] a, b;
        int n_rand;

        go = 0; x = '0; y = '0;
        rst_n = 0;
        repeat (4) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        //------------------------------------------------------------------
        // Directed corner cases (single issue)
        //------------------------------------------------------------------
        single(mk(0, 127, 20'h00000), mk(0, 127, 20'h00000), "1.0 * 1.0");
        single(mk(0, 127, 20'h00000), mk(1, 127, 20'h00000), "1.0 * -1.0");
        single(mk(0, 128, 20'h00000), mk(0, 128, 20'h80000), "2.0 * 3.0");
        single(mk(0, 130, 20'h00000), mk(0, 125, 20'h00000), "16.0 * 0.25");
        single(mk(0,   0, 20'h00000), mk(0, 150, 20'hABCDE), "0 * x");
        single(mk(1,   0, 20'h00000), mk(0, 150, 20'hABCDE), "-0 * x");
        single(mk(0,   0, 20'h12345), mk(0, 127, 20'h00000), "denormal * 1.0");
        single(mk(0, 254, 20'hFFFFF), mk(0, 254, 20'hFFFFF), "max * max (ovf)");
        single(mk(0,   1, 20'h00000), mk(0,   1, 20'h00000), "min * min (udf)");
        single(mk(0, 127, 20'hFFFFF), mk(0, 127, 20'hFFFFF), "1.999..^2 (rnd)");
        single(mk(0, 127, 20'h00001), mk(0, 127, 20'h00001), "1+eps squared");
        single(mk(1, 200, 20'h13579), mk(0,  60, 20'hBDF02), "mixed signs");

        //------------------------------------------------------------------
        // Randomized back-to-back pipeline test
        //------------------------------------------------------------------
        pipe_mode = 1'b1;
        n_rand = 2000;
        for (int i = 0; i < n_rand; i++) begin
            a = rand_fp();
            b = rand_fp();
            issue(a, b);
        end
        @(negedge clk);
        go = 1'b0; x = '0; y = '0;

        // drain the pipeline
        wait (exp_q.size() == 0);
        pipe_mode = 1'b0;
        repeat (4) @(negedge clk);
        if (valid !== 1'b0) begin
            errors++;
            $display("FAIL: valid stuck high after pipeline drained");
        end

        //------------------------------------------------------------------
        // Summary
        //------------------------------------------------------------------
        $display("--------------------------------------------------");
        $display("checks = %0d, errors = %0d", checks, errors);
        if (errors == 0 && checks > 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED");
        $display("--------------------------------------------------");
        $finish;
    end

    // Safety timeout
    initial begin
        #10ms;
        $display("FAIL: timeout");
        $finish;
    end

endmodule
