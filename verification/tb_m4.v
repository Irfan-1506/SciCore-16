// SciCore-16 M4 Testbench: Square Root + Natural Log & Exponential
module tb_m4;
    reg         clk;
    reg         rst;

    reg         sq_start;
    reg  [15:0] sq_x;
    wire [15:0] sq_res;
    wire        sq_err;
    wire        sq_busy;
    wire        sq_done;

    reg         le_start;
    reg         le_mode;
    reg  [15:0] le_x;
    wire [15:0] le_res;
    wire        le_err;
    wire        le_ovf;
    wire        le_busy;
    wire        le_done;

    integer i;

    sqrt_unit dut_sq (
        .clk(clk), .rst(rst), .start(sq_start), .x(sq_x),
        .result(sq_res), .domain_err(sq_err), .busy(sq_busy), .done(sq_done)
    );

    log_exp dut_le (
        .clk(clk), .rst(rst), .start(le_start), .mode(le_mode), .x(le_x),
        .result(le_res), .domain_err(le_err), .overflow(le_ovf),
        .busy(le_busy), .done(le_done)
    );

    initial begin
        clk = 0; rst = 1;
        sq_start = 0; sq_x = 16'h0000;
        le_start = 0; le_mode = 0; le_x = 16'h0000;
        #5; clk = 1; #5; clk = 0;
        rst = 0;

        // --- SQRT Tests ---
        sq_x = 16'h0000; sq_start = 1; #5; clk = 1; #5; clk = 0; sq_start = 0;
        for (i = 0; i < 14; i = i + 1) begin #5; clk = 1; #5; clk = 0; end
        $display("SQRT  0.0: res=%h err=%b", sq_res, sq_err);

        sq_x = 16'h0400; sq_start = 1; #5; clk = 1; #5; clk = 0; sq_start = 0;
        for (i = 0; i < 14; i = i + 1) begin #5; clk = 1; #5; clk = 0; end
        $display("SQRT  4.0: res=%h err=%b", sq_res, sq_err);

        sq_x = 16'h0200; sq_start = 1; #5; clk = 1; #5; clk = 0; sq_start = 0;
        for (i = 0; i < 14; i = i + 1) begin #5; clk = 1; #5; clk = 0; end
        $display("SQRT  2.0: res=%h err=%b", sq_res, sq_err);

        sq_x = 16'hFF00; sq_start = 1; #5; clk = 1; #5; clk = 0; sq_start = 0;
        #5; clk = 1; #5; clk = 0;
        $display("SQRT -1.0: res=%h err=%b", sq_res, sq_err);

        // --- LN Tests (mode = 0) ---
        le_mode = 0; le_x = 16'h0100; le_start = 1; #5; clk = 1; #5; clk = 0; le_start = 0;
        for (i = 0; i < 10; i = i + 1) begin #5; clk = 1; #5; clk = 0; end
        $display("LN    1.0: res=%h err=%b", le_res, le_err);

        le_mode = 0; le_x = 16'h0200; le_start = 1; #5; clk = 1; #5; clk = 0; le_start = 0;
        for (i = 0; i < 10; i = i + 1) begin #5; clk = 1; #5; clk = 0; end
        $display("LN    2.0: res=%h err=%b", le_res, le_err);

        le_mode = 0; le_x = 16'h02B8; le_start = 1; #5; clk = 1; #5; clk = 0; le_start = 0;
        for (i = 0; i < 10; i = i + 1) begin #5; clk = 1; #5; clk = 0; end
        $display("LN      e: res=%h err=%b", le_res, le_err);

        le_mode = 0; le_x = 16'h0080; le_start = 1; #5; clk = 1; #5; clk = 0; le_start = 0;
        for (i = 0; i < 10; i = i + 1) begin #5; clk = 1; #5; clk = 0; end
        $display("LN    0.5: res=%h err=%b", le_res, le_err);

        le_mode = 0; le_x = 16'h0000; le_start = 1; #5; clk = 1; #5; clk = 0; le_start = 0;
        #5; clk = 1; #5; clk = 0;
        $display("LN    0.0: res=%h err=%b", le_res, le_err);

        // --- EXP Tests (mode = 1) ---
        le_mode = 1; le_x = 16'h0000; le_start = 1; #5; clk = 1; #5; clk = 0; le_start = 0;
        for (i = 0; i < 4; i = i + 1) begin #5; clk = 1; #5; clk = 0; end
        $display("EXP   0.0: res=%h ovf=%b", le_res, le_ovf);

        le_mode = 1; le_x = 16'h0100; le_start = 1; #5; clk = 1; #5; clk = 0; le_start = 0;
        for (i = 0; i < 4; i = i + 1) begin #5; clk = 1; #5; clk = 0; end
        $display("EXP   1.0: res=%h ovf=%b", le_res, le_ovf);

        le_mode = 1; le_x = 16'hFF00; le_start = 1; #5; clk = 1; #5; clk = 0; le_start = 0;
        for (i = 0; i < 4; i = i + 1) begin #5; clk = 1; #5; clk = 0; end
        $display("EXP  -1.0: res=%h ovf=%b", le_res, le_ovf);

        le_mode = 1; le_x = 16'h0500; le_start = 1; #5; clk = 1; #5; clk = 0; le_start = 0;
        #5; clk = 1; #5; clk = 0;
        $display("EXP   5.0: res=%h ovf=%b", le_res, le_ovf);

        $finish;
    end
endmodule
