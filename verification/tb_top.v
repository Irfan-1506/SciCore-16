// SciCore-16 v2.0 End-to-End Top-Level Testbench
// Verifies SC-01 (result valid on exact cycle done==1) and SC-02 (stack underflow/overflow flags)
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
    wire [4:0]  err_flags;
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

        // === SC-02 Test 1: Stack Underflow on empty SQRT ===
        cmd_op = 4'h7; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
        $display("UDF SQRT empty: done=%b err=%b sp=%d", done, err_flags, stack_depth);

        // === SC-01 Test: PUSH 3.0 -> sample result on exact cycle done==1 ===
        cmd_op = 4'h1; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
        #5; clk = 1; #5; clk = 0; // wait COMPLETE
        cmd_op = 4'h0; cmd_imm = 16'h0300; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
        #5; clk = 1; #5; clk = 0; // COMPLETE cycle -> done must be 1 AND result==0x0300!
        $display("PUSH 3.0 @done: done=%b res=%h sp=%d err=%b", done, result, stack_depth, err_flags);

        // === SC-02 Test 2: Stack Underflow on binary ADD with only 1 item ===
        cmd_op = 4'h2; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
        $display("UDF ADD 1-item: done=%b err=%b sp=%d", done, err_flags, stack_depth);

        // === Clear & run Expression 1: ((3.0 + 5.0) * 2.0) / 4.0 = 4.0 (0x0400) ===
        cmd_op = 4'h1; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
        #5; clk = 1; #5; clk = 0;
        cmd_op = 4'h0; cmd_imm = 16'h0300; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
        #5; clk = 1; #5; clk = 0;
        cmd_op = 4'h0; cmd_imm = 16'h0500; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
        #5; clk = 1; #5; clk = 0;
        cmd_op = 4'h2; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
        #5; clk = 1; #5; clk = 0;
        $display("ADD 3+5 @done:  done=%b res=%h sp=%d err=%b", done, result, stack_depth, err_flags);

        cmd_op = 4'h0; cmd_imm = 16'h0200; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
        #5; clk = 1; #5; clk = 0;
        cmd_op = 4'h4; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
        for (i = 0; i < 20; i = i + 1) begin #5; clk = 1; #5; clk = 0; end
        cmd_op = 4'h0; cmd_imm = 16'h0400; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
        #5; clk = 1; #5; clk = 0;
        cmd_op = 4'h5; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
        for (i = 0; i < 28; i = i + 1) begin #5; clk = 1; #5; clk = 0; end
        $display("EXPR1 ((3+5)*2)/4: res=%h sp=%d err=%b", result, stack_depth, err_flags);

        // === SC-02 Test 3: Stack Overflow (push 8 items + 9th push -> err[4]=1) ===
        cmd_op = 4'h1; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
        #5; clk = 1; #5; clk = 0;
        for (i = 0; i < 8; i = i + 1) begin
            cmd_op = 4'h0; cmd_imm = 16'h0100; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
            #5; clk = 1; #5; clk = 0;
        end
        cmd_op = 4'h0; cmd_imm = 16'h0200; cmd_valid = 1; #5; clk = 1; #5; clk = 0; cmd_valid = 0;
        $display("OVF 9th PUSH:   done=%b err=%b sp=%d", done, err_flags, stack_depth);

        $finish;
    end
endmodule
