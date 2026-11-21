// SciCore-16 v2.1 Self-Checking Testbench: alu16 (incl. saturating ADD/SUB/NEG)
module tb_m1;
    reg  [15:0] a, b;
    reg  [2:0]  opcode;
    wire [15:0] result;
    wire        zero, neg, overflow;
    integer     fails;

    alu16 dut_alu (
        .a(a), .b(b), .opcode(opcode),
        .result(result), .zero(zero), .neg(neg), .overflow(overflow)
    );

    task check;
        input [15:0] exp_res;
        input        exp_z;
        input        exp_n;
        input        exp_ovf;
        begin
            #10;
            if (result !== exp_res || zero !== exp_z || neg !== exp_n || overflow !== exp_ovf) begin
                $display("FAIL op=%b a=%h b=%h got res=%h z=%b n=%b ovf=%b exp=%h %b %b %b",
                         opcode, a, b, result, zero, neg, overflow, exp_res, exp_z, exp_n, exp_ovf);
                fails = fails + 1;
            end
        end
    endtask

    initial begin
        fails = 0;
        a = 16'h0100; b = 16'h0200; opcode = 3'b000; check(16'h0300, 1'b0, 1'b0, 1'b0); // 1+2=3
        opcode = 3'b001;                             check(16'hFF00, 1'b0, 1'b1, 1'b0); // 1-2=-1
        // Positive ADD overflow -> saturates to 0x7FFF, ovf=1
        a = 16'h7FFF; b = 16'h0001; opcode = 3'b000; check(16'h7FFF, 1'b0, 1'b0, 1'b1);
        // Negative ADD overflow -> saturates to 0x8000, ovf=1
        a = 16'h8000; b = 16'hFF00; opcode = 3'b000; check(16'h8000, 1'b0, 1'b1, 1'b1);
        // NEG(-128.0) overflow -> saturates to 0x7FFF, ovf=1
        a = 16'h8000; b = 16'h0000; opcode = 3'b111; check(16'h7FFF, 1'b0, 1'b0, 1'b1);
        // Zero SUB
        a = 16'h0380; b = 16'h0380; opcode = 3'b001; check(16'h0000, 1'b1, 1'b0, 1'b0);
        // SHL / ASR / NEG / Logic
        a = 16'h0100; b = 16'h0000; opcode = 3'b101; check(16'h0200, 1'b0, 1'b0, 1'b0);
        a = 16'hFE00;               opcode = 3'b110; check(16'hFF00, 1'b0, 1'b1, 1'b0);
        a = 16'h0380;               opcode = 3'b111; check(16'hFC80, 1'b0, 1'b1, 1'b0);
        a = 16'h00F0; b = 16'h003C; opcode = 3'b010; check(16'h0030, 1'b0, 1'b0, 1'b0);
        opcode = 3'b011;                             check(16'h00FC, 1'b0, 1'b0, 1'b0);
        opcode = 3'b100;                             check(16'h00CC, 1'b0, 1'b0, 1'b0);

        if (fails != 0) begin
            $display("tb_m1: FAIL (%0d errors)", fails);
            $fatal(1, "tb_m1 failed");
        end
        $display("tb_m1: PASS (12/12 checks)");
        $finish;
    end
endmodule
