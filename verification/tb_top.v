// SciCore-16 M5 End-to-End Top-Level Testbench
module tb_top;
    reg         clk;
    reg         rst;
    reg         cmd_valid;
    reg  [3:0]  cmd_op;
    reg  [15:0] cmd_imm;
    wire [15:0] result;
    wire [3:0]  stack_depth;
    wire        busy;
    wire        done;
    wire [2:0]  err_flags;
    integer     i;

    scicore_top dut (
        .clk(clk), .rst(rst),
        .cmd_valid(cmd_valid), .cmd_op(cmd_op), .cmd_imm(cmd_imm),
        .result(result), .stack_depth(stack_depth),
        .busy(busy), .done(done), .err_flags(err_flags)
    );

    initial begin
        clk = 0; rst = 1; cmd_valid = 0; cmd_op = 4'h0; cmd_imm = 16'h0000;
        #5; clk = 1; #5; clk = 0;
        rst = 0;

        // === Expression 1: ((3.0 + 5.0) * 2.0) / 4.0 = 4.0 (0x0400) ===
        // PUSH 3.0
        cmd_op = 4'h0; cmd_imm = 16'h0300; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
        #5; clk = 1; #5; clk = 0;
        // PUSH 5.0
        cmd_op = 4'h0; cmd_imm = 16'h0500; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
        #5; clk = 1; #5; clk = 0;
        // ADD -> 8.0
        cmd_op = 4'h2; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
        #5; clk = 1; #5; clk = 0;
        // PUSH 2.0
        cmd_op = 4'h0; cmd_imm = 16'h0200; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
        #5; clk = 1; #5; clk = 0;
        // MUL -> 16.0 (wait 20 cycles)
        cmd_op = 4'h4; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
        for (i = 0; i < 20; i = i + 1) begin #5; clk = 1; #5; clk = 0; end
        // PUSH 4.0
        cmd_op = 4'h0; cmd_imm = 16'h0400; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
        #5; clk = 1; #5; clk = 0;
        // DIV -> 4.0 (wait 28 cycles)
        cmd_op = 4'h5; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
        for (i = 0; i < 28; i = i + 1) begin #5; clk = 1; #5; clk = 0; end
        $display("EXPR1 ((3+5)*2)/4: res=%h sp=%d err=%b", result, stack_depth, err_flags);

        // === Expression 2: sqrt(4.0) = 2.0 (0x0200) ===
        cmd_op = 4'h7; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
        for (i = 0; i < 16; i = i + 1) begin #5; clk = 1; #5; clk = 0; end
        $display("EXPR2 sqrt(4.0):   res=%h sp=%d err=%b", result, stack_depth, err_flags);

        // === Expression 3: sin(pi/6) + cos(0) = 0.5 + 1.0 = 1.5 (0x0180) ===
        cmd_op = 4'h1; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0; // CLEAR
        #5; clk = 1; #5; clk = 0;
        cmd_op = 4'h0; cmd_imm = 16'h0086; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0; // PUSH pi/6
        #5; clk = 1; #5; clk = 0;
        cmd_op = 4'h8; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0; // SIN
        for (i = 0; i < 16; i = i + 1) begin #5; clk = 1; #5; clk = 0; end
        cmd_op = 4'h0; cmd_imm = 16'h0000; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0; // PUSH 0
        #5; clk = 1; #5; clk = 0;
        cmd_op = 4'h9; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0; // COS
        for (i = 0; i < 16; i = i + 1) begin #5; clk = 1; #5; clk = 0; end
        cmd_op = 4'h2; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0; // ADD
        #5; clk = 1; #5; clk = 0;
        $display("EXPR3 sin+cos:     res=%h sp=%d err=%b", result, stack_depth, err_flags);

        // === Expression 4: ln(exp(1.0)) = 1.0 (0x0100) + STO/RCL M0 ===
        cmd_op = 4'h1; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0; // CLEAR
        #5; clk = 1; #5; clk = 0;
        cmd_op = 4'h0; cmd_imm = 16'h0100; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0; // PUSH 1.0
        #5; clk = 1; #5; clk = 0;
        cmd_op = 4'hB; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0; // EXP -> e
        for (i = 0; i < 6; i = i + 1) begin #5; clk = 1; #5; clk = 0; end
        cmd_op = 4'hA; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0; // LN -> 1.0
        for (i = 0; i < 10; i = i + 1) begin #5; clk = 1; #5; clk = 0; end
        $display("EXPR4 ln(exp(1)):  res=%h sp=%d err=%b", result, stack_depth, err_flags);

        // STO M0, CLEAR, RCL M0
        cmd_op = 4'hC; cmd_imm = 16'h0000; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
        #5; clk = 1; #5; clk = 0;
        cmd_op = 4'h1; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
        #5; clk = 1; #5; clk = 0;
        cmd_op = 4'hD; cmd_imm = 16'h0000; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
        #5; clk = 1; #5; clk = 0; #5; clk = 1; #5; clk = 0;
        $display("EXPR5 STO/RCL M0:  res=%h sp=%d err=%b", result, stack_depth, err_flags);

        $finish;
    end
endmodule
