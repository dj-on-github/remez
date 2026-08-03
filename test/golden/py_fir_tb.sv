// =====================================================================
// dut_tb: self-checking testbench for dut.
//
// 50 samples, full scale among them so that the saturating
// adders are exercised, with the expected output of every one as
// computed by the generator's model of this datapath.  Prints PASS and
// finishes; stops on the first mismatch.  Latency 1, so
// the strobes here are 3 clocks apart.
//
// $ verilator --binary --timing --top-module dut_tb \
//       -o sim <design>.sv <this file> && ./sim
// =====================================================================

`default_nettype none

module dut_tb;
    localparam int WCOEF = 10;
    localparam int HEADROOM = 2;
    localparam int WDATA = WCOEF + HEADROOM;
    localparam int NS = 50;
    localparam int GAP = 3;

    localparam longint STIM   [0:NS-1] = '{
        1024, -1024, 2047, -2048, 0, 2047, -2048, 512,
        -512, 0, 280, -424, 330, 539, -454, 248,
        469, 937, 817, -1, 724, 967, -101, -57,
        -131, -402, -313, 753, -575, -988, -526, 737,
        664, 844, 366, 147, -498, -954, -858, 906,
        -748, 1022, -650, -98, 135, 330, -603, 825,
        794, 194
    };
    localparam longint EXPECT [0:NS-1] = '{
        54, 40, 64, -25, -127, 54, 258, 384,
        189, -90, -147, 24, 129, 6, -237, -309,
        -102, 114, 324, 216, 60, 83, 228, 531,
        698, 638, 535, 552, 572, 318, -135, -325,
        -54, 312, 245, -315, -752, -578, 114, 818,
        970, 541, -178, -734, -804, -395, 143, 386,
        262, -33
    };

    logic clk, resetn, din_strb;
    logic signed [WDATA-1:0] din;
    logic signed [WDATA-1:0] dout;
    logic dout_strb;
    int   seen;

    dut dut (
        .clk(clk), .resetn(resetn), .din(din), .din_strb(din_strb),
        .dout(dout), .dout_strb(dout_strb));

    always #5 clk = ~clk;

    initial begin
        clk      = 1'b0;
        resetn   = 1'b0;
        din_strb = 1'b0;
        din      = '0;
        seen     = 0;
        repeat (3) @(posedge clk);
        resetn = 1'b1;
        @(posedge clk);
        for (int i = 0; i < NS; i++) begin
            din      = WDATA'(STIM[i]);
            din_strb = 1'b1;
            @(posedge clk);
            din_strb = 1'b0;
            repeat (GAP - 1) @(posedge clk);
        end
        repeat (GAP + 4) @(posedge clk);
        if (seen != NS) begin
            $display("FAIL: %0d outputs, expected %0d", seen, NS);
            $fatal(1, "wrong number of outputs");
        end
        $display("PASS: %0d samples matched", seen);
        $finish;
    end

    always @(posedge clk) begin
        if (resetn && dout_strb) begin
            if (dout !== WDATA'(EXPECT[seen])) begin
                $display("FAIL at %0d: got %0d, expected %0d",
                         seen, dout, EXPECT[seen]);
                $fatal(1, "mismatch");
            end
            seen <= seen + 1;
        end
    end
endmodule

`default_nettype wire
