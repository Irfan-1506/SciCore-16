// SciCore-16 v2.1 Self-Checking Vector Testbench: multiplier & divider
// Reads 256 stratified golden vectors each from verification/vectors/{mul,div}_vectors.hex
module tb_m2;
    reg         clk, rst;
    reg         mul_start;
    reg  [15:0] mul_a, mul_b;
    wire [15:0] mul_res;
    wire        mul_ovf, mul_busy, mul_done;

    reg         div_start;
    reg  [15:0] div_a, div_b;
    wire [15:0] div_res;
    wire        div_zero, div_ovf, div_busy, div_done;

    reg [51:0] mul_mem [0:255]; // {a[15:0], b[15:0], exp_res[15:0], 3'b0, exp_ovf}
    reg [55:0] div_mem [0:255]; // {a[15:0], b[15:0], exp_res[15:0], 3'b0, exp_dz, 3'b0, exp_ovf}
    integer    k, c, fails;

    multiplier dut_mul (
        .clk(clk), .rst(rst), .start(mul_start), .a(mul_a), .b(mul_b),
        .result(mul_res), .overflow(mul_ovf), .busy(mul_busy), .done(mul_done)
    );
    divider dut_div (
        .clk(clk), .rst(rst), .start(div_start), .a(div_a), .b(div_b),
        .result(div_res), .div_zero(div_zero), .overflow(div_ovf), .busy(div_busy), .done(div_done)
    );

    initial begin
        $readmemh("verification/vectors/mul_vectors.hex", mul_mem);
        $readmemh("verification/vectors/div_vectors.hex", div_mem);
        fails = 0;
        clk = 0; rst = 1;
        mul_start = 0; mul_a = 0; mul_b = 0;
        div_start = 0; div_a = 0; div_b = 0;
        #5; clk = 1; #5; clk = 0; rst = 0;

        for (k = 0; k < 256; k = k + 1) begin
            mul_a = mul_mem[k][51:36];
            mul_b = mul_mem[k][35:20];
            mul_start = 1; #5; clk = 1; #5; clk = 0; mul_start = 0;
            for (c = 0; c < 18 && !mul_done; c = c + 1) begin #5; clk = 1; #5; clk = 0; end
            if (!mul_done || mul_res !== mul_mem[k][19:4] || mul_ovf !== mul_mem[k][0]) begin
                $display("MUL FAIL idx=%0d a=%h b=%h got=%h/%b exp=%h/%b",
                         k, mul_a, mul_b, mul_res, mul_ovf, mul_mem[k][19:4], mul_mem[k][0]);
                fails = fails + 1;
            end
        end

        for (k = 0; k < 256; k = k + 1) begin
            div_a = div_mem[k][55:40];
            div_b = div_mem[k][39:24];
            div_start = 1; #5; clk = 1; #5; clk = 0; div_start = 0;
            for (c = 0; c < 26 && !div_done; c = c + 1) begin #5; clk = 1; #5; clk = 0; end
            if (!div_done || div_res !== div_mem[k][23:8] || div_zero !== div_mem[k][4] || div_ovf !== div_mem[k][0]) begin
                $display("DIV FAIL idx=%0d a=%h b=%h got=%h dz=%b ovf=%b exp=%h dz=%b ovf=%b",
                         k, div_a, div_b, div_res, div_zero, div_ovf, div_mem[k][23:8], div_mem[k][4], div_mem[k][0]);
                fails = fails + 1;
            end
        end

        if (fails != 0) begin
            $display("tb_m2: FAIL (%0d errors)", fails);
            $fatal(1, "tb_m2 failed");
        end
        $display("tb_m2: PASS (512/512 golden vectors bit-exact)");
        $finish;
    end
endmodule
