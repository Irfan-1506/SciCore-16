// SciCore-16 v2.1 Self-Checking Vector Testbench: sqrt_unit + log_exp (ln & exp)
module tb_m4;
    reg         clk, rst;
    reg         sq_start;
    reg  [15:0] sq_x;
    wire [15:0] sq_res;
    wire        sq_err, sq_busy, sq_done;

    reg         le_start, le_mode;
    reg  [15:0] le_x;
    wire [15:0] le_res;
    wire        le_err, le_ovf, le_busy, le_done;

    reg [35:0] sq_mem  [0:255];
    reg [35:0] ln_mem  [0:255];
    reg [35:0] exp_mem [0:255];
    integer    k, c, n_sq, n_ln, n_exp, fails;

    sqrt_unit dut_sq (
        .clk(clk), .rst(rst), .start(sq_start), .x(sq_x),
        .result(sq_res), .domain_err(sq_err), .busy(sq_busy), .done(sq_done)
    );
    log_exp dut_le (
        .clk(clk), .rst(rst), .start(le_start), .mode(le_mode), .x(le_x),
        .result(le_res), .domain_err(le_err), .overflow(le_ovf), .busy(le_busy), .done(le_done)
    );

    initial begin
        for (k = 0; k < 256; k = k + 1) begin
            sq_mem[k] = 36'bx; ln_mem[k] = 36'bx; exp_mem[k] = 36'bx;
        end
        $readmemh("verification/vectors/sqrt_vectors.hex", sq_mem);
        $readmemh("verification/vectors/ln_vectors.hex",   ln_mem);
        $readmemh("verification/vectors/exp_vectors.hex",  exp_mem);

        fails = 0; n_sq = 0; n_ln = 0; n_exp = 0;
        clk = 0; rst = 1; sq_start = 0; sq_x = 0; le_start = 0; le_mode = 0; le_x = 0;
        #5; clk = 1; #5; clk = 0; rst = 0;

        for (k = 0; k < 256; k = k + 1) begin
            if (sq_mem[k] !== 36'bx) begin
                sq_x = sq_mem[k][35:20];
                sq_start = 1; #5; clk = 1; #5; clk = 0; sq_start = 0;
                for (c = 0; c < 15 && !sq_done; c = c + 1) begin #5; clk = 1; #5; clk = 0; end
                if (!sq_done || sq_res !== sq_mem[k][19:4] || sq_err !== sq_mem[k][0]) begin
                    $display("SQRT FAIL x=%h got=%h/%b exp=%h/%b", sq_x, sq_res, sq_err, sq_mem[k][19:4], sq_mem[k][0]);
                    fails = fails + 1;
                end
                n_sq = n_sq + 1;
            end
        end

        le_mode = 1'b0;
        for (k = 0; k < 256; k = k + 1) begin
            if (ln_mem[k] !== 36'bx) begin
                le_x = ln_mem[k][35:20];
                le_start = 1; #5; clk = 1; #5; clk = 0; le_start = 0;
                for (c = 0; c < 15 && !le_done; c = c + 1) begin #5; clk = 1; #5; clk = 0; end
                if (!le_done || le_res !== ln_mem[k][19:4] || le_err !== ln_mem[k][0]) begin
                    $display("LN FAIL x=%h got=%h/%b exp=%h/%b", le_x, le_res, le_err, ln_mem[k][19:4], ln_mem[k][0]);
                    fails = fails + 1;
                end
                n_ln = n_ln + 1;
            end
        end

        le_mode = 1'b1;
        for (k = 0; k < 256; k = k + 1) begin
            if (exp_mem[k] !== 36'bx) begin
                le_x = exp_mem[k][35:20];
                le_start = 1; #5; clk = 1; #5; clk = 0; le_start = 0;
                for (c = 0; c < 6 && !le_done; c = c + 1) begin #5; clk = 1; #5; clk = 0; end
                if (!le_done || le_res !== exp_mem[k][19:4] || le_ovf !== exp_mem[k][0]) begin
                    $display("EXP FAIL x=%h got=%h/%b exp=%h/%b", le_x, le_res, le_ovf, exp_mem[k][19:4], exp_mem[k][0]);
                    fails = fails + 1;
                end
                n_exp = n_exp + 1;
            end
        end

        if (fails != 0) begin
            $display("tb_m4: FAIL (%0d errors)", fails);
            $fatal(1, "tb_m4 failed");
        end
        $display("tb_m4: PASS (SQRT=%0d, LN=%0d, EXP=%0d golden vectors bit-exact)", n_sq, n_ln, n_exp);
        $finish;
    end
endmodule
