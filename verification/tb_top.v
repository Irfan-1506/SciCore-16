// SciCore-16 v2.1 Self-Checking Full-Opcode Testbench: scicore_top (all 16 opcodes 0x0..0xF)
module tb_top;
    reg         clk, rst, cmd_valid;
    reg  [3:0]  cmd_op;
    reg  [15:0] cmd_imm;
    wire [15:0] result;
    wire [3:0]  stack_depth;
    wire        busy, done;
    wire [4:0]  err_flags;
    integer     fails;

    scicore_top dut (
        .clk(clk), .rst(rst),
        .cmd_valid(cmd_valid), .cmd_op(cmd_op), .cmd_imm(cmd_imm),
        .result(result), .stack_depth(stack_depth),
        .busy(busy), .done(done), .err_flags(err_flags)
    );

    task exec_cmd;
        input [3:0]  op;
        input [15:0] imm;
        integer cyc;
        begin
            cmd_op = op; cmd_imm = imm; cmd_valid = 1;
            #5; clk = 1; #5; clk = 0;
            cmd_valid = 0;
            for (cyc = 0; cyc < 50 && !done; cyc = cyc + 1) begin
                #5; clk = 1; #5; clk = 0;
            end
            if (!done) begin
                $display("TIMEOUT op=%h imm=%h", op, imm);
                fails = fails + 1;
            end
        end
    endtask

    task expect_state;
        input [15:0] exp_res;
        input [3:0]  exp_sp;
        input [4:0]  exp_err;
        begin
            if (result !== exp_res || stack_depth !== exp_sp || err_flags !== exp_err) begin
                $display("FAIL got res=%h sp=%0d err=%b | exp res=%h sp=%0d err=%b",
                         result, stack_depth, err_flags, exp_res, exp_sp, exp_err);
                fails = fails + 1;
            end
        end
    endtask

    initial begin
        fails = 0;
        clk = 0; rst = 1; cmd_valid = 0; cmd_op = 0; cmd_imm = 0;
        #5; clk = 1; #5; clk = 0; rst = 0;

        // 1. Stack underflow on empty SQRT -> stack unchanged, err_flags[3]=1
        exec_cmd(4'h7, 16'h0000); expect_state(16'h0000, 4'd0, 5'b01000);

        // 2. CLEAR + PUSH 3.0 + PUSH 5.0 + ADD -> 8.0, MUL 2.0 -> 16.0, DIV 4.0 -> 4.0
        exec_cmd(4'h1, 16'h0000); expect_state(16'h0000, 4'd0, 5'b00000);
        exec_cmd(4'h0, 16'h0300); expect_state(16'h0300, 4'd1, 5'b00000);
        exec_cmd(4'h0, 16'h0500); expect_state(16'h0500, 4'd2, 5'b00000);
        exec_cmd(4'h2, 16'h0000); expect_state(16'h0800, 4'd1, 5'b00000);
        exec_cmd(4'h0, 16'h0200);
        exec_cmd(4'h4, 16'h0000); expect_state(16'h1000, 4'd1, 5'b00000);
        exec_cmd(4'h0, 16'h0400);
        exec_cmd(4'h5, 16'h0000); expect_state(16'h0400, 4'd1, 5'b00000);

        // 3. SQRT(4.0)=2.0, NEG -> -2.0, SUB
        exec_cmd(4'h7, 16'h0000); expect_state(16'h0200, 4'd1, 5'b00000);
        exec_cmd(4'h6, 16'h0000); expect_state(16'hFE00, 4'd1, 5'b00000);
        exec_cmd(4'h0, 16'h0100);
        exec_cmd(4'h3, 16'h0000); expect_state(16'hFD00, 4'd1, 5'b00000); // -2 - 1 = -3

        // 4. Div-by-zero leaves stack UNCHANGED! (tos=0, nos=-3 -> sp stays 2, err[2]=1)
        exec_cmd(4'h0, 16'h0000);
        exec_cmd(4'h5, 16'h0000); expect_state(16'h0000, 4'd2, 5'b00100);

        // 5. PUSH_PI (0xF) -> 0x0324, COS(pi) -> -1.0 (0xFF00), TAN(pi/4) -> 1.0 (0x0100)
        exec_cmd(4'h1, 16'h0000);
        exec_cmd(4'hF, 16'h0000); expect_state(16'h0324, 4'd1, 5'b00000);
        exec_cmd(4'h9, 16'h0000); expect_state(16'hFF00, 4'd1, 5'b00000); // cos(pi) = -1.0!
        exec_cmd(4'h1, 16'h0000);
        exec_cmd(4'h0, 16'h00C9); // pi/4
        exec_cmd(4'hE, 16'h0000); expect_state(16'h0100, 4'd1, 5'b00000); // tan(pi/4) = 1.0!

        // 6. CORDIC out-of-range (4.0 > pi) -> domain_err, stack unchanged
        exec_cmd(4'h1, 16'h0000);
        exec_cmd(4'h0, 16'h0400);
        exec_cmd(4'h8, 16'h0000); expect_state(16'h0400, 4'd1, 5'b00010);

        // 7. EXP(1.0) -> 0x02B8, LN(e) -> 0x0100, STO M2, CLEAR, RCL M2
        exec_cmd(4'h1, 16'h0000);
        exec_cmd(4'h0, 16'h0100);
        exec_cmd(4'hB, 16'h0000); expect_state(16'h02B8, 4'd1, 5'b00000);
        exec_cmd(4'hA, 16'h0000); expect_state(16'h0100, 4'd1, 5'b00000);
        exec_cmd(4'hC, 16'h0002); // STO M2
        exec_cmd(4'h1, 16'h0000);
        exec_cmd(4'hD, 16'h0002); expect_state(16'h0100, 4'd1, 5'b00000); // RCL M2

        // 8. Stack overflow (9th push -> err[4]=1, sp stays 8)
        exec_cmd(4'h1, 16'h0000);
        exec_cmd(4'h0, 16'h0100); exec_cmd(4'h0, 16'h0100); exec_cmd(4'h0, 16'h0100); exec_cmd(4'h0, 16'h0100);
        exec_cmd(4'h0, 16'h0100); exec_cmd(4'h0, 16'h0100); exec_cmd(4'h0, 16'h0100); exec_cmd(4'h0, 16'h0100);
        exec_cmd(4'h0, 16'h0200); expect_state(16'h0100, 4'd8, 5'b10000);

        if (fails != 0) begin
            $display("tb_top: FAIL (%0d errors)", fails);
            $fatal(1, "tb_top failed");
        end
        $display("tb_top: PASS (all 16 opcodes + error policies verified)");
        $finish;
    end
endmodule
