// SciCore-16 v2.1 Self-Checking Vector Testbench: CORDIC [-pi, +pi] + domain_err
module tb_m3;
    reg         clk, rst, start;
    reg  [15:0] theta;
    wire [15:0] sin_out, cos_out;
    wire        domain_err, busy, done;

    reg [51:0] cor_mem [0:127]; // {theta[15:0], exp_sin[15:0], exp_cos[15:0], 3'b0, exp_derr}
    integer    k, c, checked, fails;

    cordic dut_cordic (
        .clk(clk), .rst(rst), .start(start), .theta(theta),
        .sin_out(sin_out), .cos_out(cos_out), .domain_err(domain_err),
        .busy(busy), .done(done)
    );

    initial begin
        for (k = 0; k < 128; k = k + 1) cor_mem[k] = 52'bx;
        $readmemh("verification/vectors/cordic_vectors.hex", cor_mem);
        fails = 0; checked = 0;
        clk = 0; rst = 1; start = 0; theta = 0;
        #5; clk = 1; #5; clk = 0; rst = 0;

        for (k = 0; k < 128; k = k + 1) begin
            if (cor_mem[k] !== 52'bx) begin
                theta = cor_mem[k][51:36];
                start = 1; #5; clk = 1; #5; clk = 0; start = 0;
                for (c = 0; c < 15 && !done; c = c + 1) begin #5; clk = 1; #5; clk = 0; end
                if (!done || sin_out !== cor_mem[k][35:20] || cos_out !== cor_mem[k][19:4] || domain_err !== cor_mem[k][0]) begin
                    $display("CORDIC FAIL idx=%0d th=%h got=%h/%h derr=%b exp=%h/%h derr=%b",
                             k, theta, sin_out, cos_out, domain_err, cor_mem[k][35:20], cor_mem[k][19:4], cor_mem[k][0]);
                    fails = fails + 1;
                end
                checked = checked + 1;
            end
        end

        if (fails != 0 || checked < 50) begin
            $display("tb_m3: FAIL (%0d errors, %0d checked)", fails, checked);
            $fatal(1, "tb_m3 failed");
        end
        $display("tb_m3: PASS (%0d/%0d CORDIC golden vectors bit-exact)", checked, checked);
        $finish;
    end
endmodule
