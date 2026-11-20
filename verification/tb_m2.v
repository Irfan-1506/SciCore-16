// SciCore-16 M2 Testbench: Iterative Multiplier & Restoring Divider
module tb_m2;
    reg         clk;
    reg         rst;

    reg         mul_start;
    reg  [15:0] mul_a;
    reg  [15:0] mul_b;
    wire [15:0] mul_res;
    wire        mul_ovf;
    wire        mul_busy;
    wire        mul_done;

    reg         div_start;
    reg  [15:0] div_a;
    reg  [15:0] div_b;
    wire [15:0] div_res;
    wire        div_zero;
    wire        div_ovf;
    wire        div_busy;
    wire        div_done;

    integer i;

    multiplier dut_mul (
        .clk(clk), .rst(rst), .start(mul_start),
        .a(mul_a), .b(mul_b),
        .result(mul_res), .overflow(mul_ovf),
        .busy(mul_busy), .done(mul_done)
    );

    divider dut_div (
        .clk(clk), .rst(rst), .start(div_start),
        .a(div_a), .b(div_b),
        .result(div_res), .div_zero(div_zero), .overflow(div_ovf),
        .busy(div_busy), .done(div_done)
    );

    initial begin
        clk = 0; rst = 1;
        mul_start = 0; mul_a = 16'h0000; mul_b = 16'h0000;
        div_start = 0; div_a = 16'h0000; div_b = 16'h0000;
        #5; clk = 1; #5; clk = 0;
        rst = 0;

        // --- MUL Test 1: 1.5 * 2.0 = 3.0 (0x0180 * 0x0200 = 0x0300) ---
        mul_a = 16'h0180; mul_b = 16'h0200; mul_start = 1;
        #5; clk = 1; #5; clk = 0;
        mul_start = 0;
        for (i = 0; i < 18; i = i + 1) begin
            #5; clk = 1; #5; clk = 0;
        end
        $display("MUL  1.5*2.0:  res=%h ovf=%b", mul_res, mul_ovf);

        // --- MUL Test 2: -2.5 * 3.0 = -7.5 (0xFD80 * 0x0300 = 0xF880) ---
        mul_a = 16'hFD80; mul_b = 16'h0300; mul_start = 1;
        #5; clk = 1; #5; clk = 0;
        mul_start = 0;
        for (i = 0; i < 18; i = i + 1) begin
            #5; clk = 1; #5; clk = 0;
        end
        $display("MUL -2.5*3.0:  res=%h ovf=%b", mul_res, mul_ovf);

        // --- MUL Test 3: Overflow 20.0 * 10.0 = 200.0 (ovf=1) ---
        mul_a = 16'h1400; mul_b = 16'h0A00; mul_start = 1;
        #5; clk = 1; #5; clk = 0;
        mul_start = 0;
        for (i = 0; i < 18; i = i + 1) begin
            #5; clk = 1; #5; clk = 0;
        end
        $display("MUL OVF 20*10: res=%h ovf=%b", mul_res, mul_ovf);

        // --- DIV Test 1: 7.0 / 2.0 = 3.5 (0x0700 / 0x0200 = 0x0380) ---
        div_a = 16'h0700; div_b = 16'h0200; div_start = 1;
        #5; clk = 1; #5; clk = 0;
        div_start = 0;
        for (i = 0; i < 26; i = i + 1) begin
            #5; clk = 1; #5; clk = 0;
        end
        $display("DIV  7.0/2.0:  res=%h dz=%b ovf=%b", div_res, div_zero, div_ovf);

        // --- DIV Test 2: -3.0 / 2.0 = -1.5 (0xFD00 / 0x0200 = 0xFE80) ---
        div_a = 16'hFD00; div_b = 16'h0200; div_start = 1;
        #5; clk = 1; #5; clk = 0;
        div_start = 0;
        for (i = 0; i < 26; i = i + 1) begin
            #5; clk = 1; #5; clk = 0;
        end
        $display("DIV -3.0/2.0:  res=%h dz=%b ovf=%b", div_res, div_zero, div_ovf);

        // --- DIV Test 3: Divide by zero (1.0 / 0.0 -> dz=1) ---
        div_a = 16'h0100; div_b = 16'h0000; div_start = 1;
        #5; clk = 1; #5; clk = 0;
        div_start = 0;
        #5; clk = 1; #5; clk = 0;
        $display("DIV  1.0/0.0:  res=%h dz=%b ovf=%b", div_res, div_zero, div_ovf);

        // --- DIV Test 4: Overflow 100.0 / 0.5 = 200.0 (ovf=1) ---
        div_a = 16'h6400; div_b = 16'h0080; div_start = 1;
        #5; clk = 1; #5; clk = 0;
        div_start = 0;
        for (i = 0; i < 26; i = i + 1) begin
            #5; clk = 1; #5; clk = 0;
        end
        $display("DIV OVF 100/.5: res=%h dz=%b ovf=%b", div_res, div_zero, div_ovf);

        $finish;
    end
endmodule
