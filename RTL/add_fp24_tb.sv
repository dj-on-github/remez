//-----------------------------------------------------------------------------
// add_fp24_tb.sv
//
// Stand-alone, self-checking testbench for add_fp24.
//
//   - Golden reference model (integer arithmetic, mirrors the documented
//     fp24 conventions: RNE rounding, denormal flush, overflow saturation,
//     underflow flush, signed-zero rules).
//   - Directed corner-case tests (single-issue, checks one-cycle valid pulse).
//   - Randomized tests issued back-to-back to exercise the pipeline at II=1,
//     biased toward cancellation, alignment-sticky, and rounding-tie paths.
//
// Build & run, e.g. with Verilator:
//   $ verilator --binary --timing add_fp24_tb.sv add_fp24.sv -o sim_add
//   $ ./obj_dir/sim_add
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

module add_fp24_tb;

    logic        clk = 1'b0;
    logic        rst_n;
    logic        go;
    logic [28:0] x, y;
    logic [28:0] z;
    logic        valid;

    int errors = 0;
    int checks = 0;
    int issued = 0;

    //--------------------------------------------------------------------------
    // DUT
    //--------------------------------------------------------------------------
    add_fp24 dut (
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
    function automatic logic [28:0] ref_add(input logic [28:0] a,
                                            input logic [28:0] b);
        logic              xz, yz;
        logic [28:0]       big, sml;
        logic              s, sub;
        logic [8:0]        sh9;
        logic [4:0]        sh;
        logic [23:0]       bige, smapre, smale, w;
        logic [24:0]       mask, sum;
        logic              st, g, r, st2;
        logic signed [12:0] e;
        logic [21:0]       mr;
        int                lz;
        begin
            xz = (a[27:20] == 8'd0);
            yz = (b[27:20] == 8'd0);
            if (xz && yz) return {a[28] & b[28], 8'd0, 20'd0};
            if (xz)       return b;
            if (yz)       return a;

            big   = (a[27:0] >= b[27:0]) ? a : b;
            sml = (a[27:0] >= b[27:0]) ? b : a;
            s     = big[28];
            sub   = a[28] ^ b[28];
            e     = {5'b0, big[27:20]};

            sh9    = {1'b0, big[27:20]} - {1'b0, sml[27:20]};
            sh     = (sh9 > 9'd24) ? 5'd24 : sh9[4:0];
            bige   = {1'b1, big[19:0], 3'b000};
            smapre = {1'b1, sml[19:0], 3'b000};
            smale  = smapre >> sh;
            mask   = (25'd1 << sh) - 25'd1;
            st     = |({1'b0, smapre} & mask);

            if (sub) sum = {1'b0, bige} - {1'b0, smale};
            else     sum = {1'b0, bige} + {1'b0, smale};

            if (sum == 25'd0) return {1'b0, 8'd0, 20'd0};

            if (sum[24]) begin
                w  = sum[24:1];
                e  = e + 13'sd1;
                st = st | sum[0];
            end else begin
                lz = 24;
                for (int i = 23; i >= 0; i--)
                    if (sum[i] && lz == 24) lz = 23 - i;
                w = sum[23:0] << lz;
                e = e - 13'(lz);
            end

            g   = w[2];
            r   = w[1];
            st2 = w[0] | st;
            if (g && (r || st2 || w[3]))
                mr = {1'b0, w[23:3]} + 22'd1;
            else
                mr = {1'b0, w[23:3]};

            if (mr[21]) e = e + 13'sd1;

            if (e >= 255) return {s, 8'd254, 20'hFFFFF};
            if (e <= 0)   return {s, 8'd0,   20'd0};
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
            exp_z = ref_add(a, b);
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

    task automatic issue(input logic [28:0] a, input logic [28:0] b);
        begin
            @(negedge clk);
            x = a; y = b; go = 1'b1;
            exp_q.push_back(ref_add(a, b));
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
            case ($urandom_range(0, 9))
                0:       e = 8'($urandom_range(1, 4));       // tiny
                1:       e = 8'($urandom_range(250, 254));   // huge
                default: e = 8'($urandom_range(60, 195));    // mid range
            endcase
            if ($urandom_range(0, 3) == 0)
                m = 20'($urandom_range(0, 15)) << $urandom_range(0, 16);
            else
                m = 20'({$urandom, $urandom});
            return {s, e, m};
        end
    endfunction

    // operand near `a` in magnitude: exercises alignment / cancellation
    function automatic logic [28:0] rand_near(logic [28:0] a);
        logic        s;
        logic [7:0]  e;
        logic [19:0] m;
        int          d;
        begin
            s = 1'($urandom_range(0, 1));
            d = int'($urandom_range(0, 8)) - 4;      // exponent within +-4
            e = 8'(int'({1'b0, a[27:20]}) + d);
            if (e == 8'd0 || e >= 8'd255) e = a[27:20];
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
        single(mk(0, 127, 20'h00000), mk(0, 127, 20'h00000), "1.0 + 1.0");
        single(mk(0, 127, 20'h00000), mk(1, 127, 20'h00000), "1.0 + -1.0 (=+0)");
        single(mk(1, 127, 20'h00000), mk(0, 127, 20'h00000), "-1.0 + 1.0 (=+0)");
        single(mk(1, 127, 20'h00000), mk(1, 127, 20'h00000), "-1.0 + -1.0");
        single(mk(0, 127, 20'h80000), mk(0, 127, 20'h80000), "1.5 + 1.5 (carry)");
        single(mk(0, 127, 20'h00000), mk(0, 106, 20'h00000), "1.0 + half-ulp tie");
        single(mk(0, 127, 20'h00001), mk(0, 106, 20'h00000), "tie up to even");
        single(mk(0, 127, 20'hFFFFF), mk(1, 127, 20'h00000), "1.99.. - 1.0 (norm)");
        single(mk(0, 130, 20'h00000), mk(0, 100, 20'h00000), "16 + tiny (absorb)");
        single(mk(0, 254, 20'hFFFFF), mk(0, 254, 20'hFFFFF), "max + max (ovf)");
        single(mk(0,   1, 20'h00000), mk(0,   1, 20'h00000), "min + min");
        single(mk(0,   0, 20'h00000), mk(0, 150, 20'hABCDE), "0 + x (pass)");
        single(mk(0,   0, 20'h00000), mk(1,   0, 20'h00000), "+0 + -0 (=+0)");
        single(mk(1,   0, 20'h00000), mk(1,   0, 20'h00000), "-0 + -0 (=-0)");
        single(mk(0,   0, 20'h12345), mk(0, 127, 20'h00000), "denormal + 1.0");
        single(mk(0, 150, 20'hAAAAA), mk(1, 150, 20'hAAAA9), "near cancel");
        single(mk(0, 127, 20'h00000), mk(1, 126, 20'hFFFFF), "1.0 - 0.999..");

        //------------------------------------------------------------------
        // Randomized back-to-back pipeline test
        //------------------------------------------------------------------
        pipe_mode = 1'b1;
        n_rand = 2000;
        for (int i = 0; i < n_rand; i++) begin
            a = rand_fp();
            // half the time pick b near a (deep alignment/cancellation paths)
            if ($urandom_range(0, 1) == 0) b = rand_near(a);
            else                           b = rand_fp();
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
