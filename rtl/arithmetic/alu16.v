// SciCore-16 M1: 16-bit Fixed-Point ALU (Verilog-2001)
// Opcodes:
//   000: ADD  (a + b, signed overflow)
//   001: SUB  (a - b, signed overflow)
//   010: AND  (a & b)
//   011: OR   (a | b)
//   100: XOR  (a ^ b)
//   101: SHL  (a << 1)
//   110: ASR  (signed a >>> 1)
//   111: NEG  (-a, signed overflow on 0x8000)
module alu16 (
    input  [15:0] a,
    input  [15:0] b,
    input  [2:0]  opcode,
    output reg [15:0] result,
    output        zero,
    output        neg,
    output reg    overflow
);
    wire [15:0] sum_val;
    wire [15:0] diff_val;
    wire [15:0] neg_val;
    wire        add_ovf;
    wire        sub_ovf;
    wire        neg_ovf;

    assign sum_val  = a + b;
    assign diff_val = a - b;
    assign neg_val  = 16'h0000 - a;

    assign add_ovf = (a[15] == b[15]) && (sum_val[15] != a[15]);
    assign sub_ovf = (a[15] != b[15]) && (diff_val[15] != a[15]);
    assign neg_ovf = (a == 16'h8000);

    always @(*) begin
        result   = 16'h0000;
        overflow = 1'b0;
        case (opcode)
            3'b000: begin
                result   = sum_val;
                overflow = add_ovf;
            end
            3'b001: begin
                result   = diff_val;
                overflow = sub_ovf;
            end
            3'b010: result = a & b;
            3'b011: result = a | b;
            3'b100: result = a ^ b;
            3'b101: result = {a[14:0], 1'b0};
            3'b110: result = {a[15], a[15:1]};
            3'b111: begin
                result   = neg_val;
                overflow = neg_ovf;
            end
            default: begin
                result   = 16'h0000;
                overflow = 1'b0;
            end
        endcase
    end

    assign zero = (result == 16'h0000);
    assign neg  = result[15];
endmodule
