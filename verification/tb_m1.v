// SciCore-16 M1 Testbench: ALU
module tb_m1;
    reg  [15:0] a;
    reg  [15:0] b;
    reg  [2:0]  opcode;
    wire [15:0] result;
    wire        zero;
    wire        neg;
    wire        overflow;

    alu16 dut_alu (
        .a(a),
        .b(b),
        .opcode(opcode),
        .result(result),
        .zero(zero),
        .neg(neg),
        .overflow(overflow)
    );

    initial begin
        // 1.0 + 2.0 = 3.0 (Q8.8: 0x0100 + 0x0200 = 0x0300)
        a = 16'h0100; b = 16'h0200; opcode = 3'b000;
        #10;
        $display("ADD 1.0+2.0: res=%h z=%b n=%b ovf=%b", result, zero, neg, overflow);

        // 1.0 - 2.0 = -1.0 (0xFF00)
        opcode = 3'b001;
        #10;
        $display("SUB 1.0-2.0: res=%h z=%b n=%b ovf=%b", result, zero, neg, overflow);

        // Positive overflow: 0x7FFF + 0x0001 = 0x8000, ovf=1
        a = 16'h7FFF; b = 16'h0001; opcode = 3'b000;
        #10;
        $display("OVF ADD:     res=%h z=%b n=%b ovf=%b", result, zero, neg, overflow);

        // Zero test: 0x0380 - 0x0380 = 0x0000, z=1
        a = 16'h0380; b = 16'h0380; opcode = 3'b001;
        #10;
        $display("ZERO SUB:    res=%h z=%b n=%b ovf=%b", result, zero, neg, overflow);

        // SHL: 0x0100 << 1 = 0x0200
        a = 16'h0100; b = 16'h0000; opcode = 3'b101;
        #10;
        $display("SHL 1.0:     res=%h z=%b n=%b ovf=%b", result, zero, neg, overflow);

        // ASR: 0xFE00 (-2.0) >>> 1 = 0xFF00 (-1.0)
        a = 16'hFE00; opcode = 3'b110;
        #10;
        $display("ASR -2.0:    res=%h z=%b n=%b ovf=%b", result, zero, neg, overflow);

        // NEG: -3.5 (0x0380 -> 0xFC80)
        a = 16'h0380; opcode = 3'b111;
        #10;
        $display("NEG 3.5:     res=%h z=%b n=%b ovf=%b", result, zero, neg, overflow);

        // Logic AND / OR / XOR
        a = 16'h00F0; b = 16'h003C; opcode = 3'b010; #10;
        $display("AND:         res=%h", result);
        opcode = 3'b011; #10;
        $display("OR:          res=%h", result);
        opcode = 3'b100; #10;
        $display("XOR:         res=%h", result);

        $finish;
    end
endmodule
