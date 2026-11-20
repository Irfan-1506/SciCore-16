// SciCore-16 M5: 8x16-bit RPN Expression Operand Stack
// Operations (mutually exclusive):
//   clear       : reset stack pointer to 0
//   push        : push wdata onto stack (sp <= sp + 1)
//   replace_top : overwrite top-of-stack s[sp-1] with wdata (unary op)
//   pop2_push1  : overwrite s[sp-2] with wdata and decrement sp (binary op)
module expression_stack (
    input         clk,
    input         rst,
    input         clear,
    input         push,
    input         replace_top,
    input         pop2_push1,
    input  [15:0] wdata,
    output [15:0] tos,
    output [15:0] nos,
    output reg [3:0] sp,
    output        empty,
    output        full
);
    reg [15:0] s0, s1, s2, s3, s4, s5, s6, s7;

    wire [2:0] tos_idx;
    wire [2:0] nos_idx;

    assign tos_idx = (sp > 4'd0) ? (sp[2:0] - 3'd1) : 3'd0;
    assign nos_idx = (sp > 4'd1) ? (sp[2:0] - 3'd2) : 3'd0;

    assign tos = (tos_idx == 3'd0) ? s0 :
                 (tos_idx == 3'd1) ? s1 :
                 (tos_idx == 3'd2) ? s2 :
                 (tos_idx == 3'd3) ? s3 :
                 (tos_idx == 3'd4) ? s4 :
                 (tos_idx == 3'd5) ? s5 :
                 (tos_idx == 3'd6) ? s6 : s7;

    assign nos = (nos_idx == 3'd0) ? s0 :
                 (nos_idx == 3'd1) ? s1 :
                 (nos_idx == 3'd2) ? s2 :
                 (nos_idx == 3'd3) ? s3 :
                 (nos_idx == 3'd4) ? s4 :
                 (nos_idx == 3'd5) ? s5 :
                 (nos_idx == 3'd6) ? s6 : s7;

    assign empty = (sp == 4'd0);
    assign full  = (sp == 4'd8);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sp <= 4'd0;
            s0 <= 16'h0000; s1 <= 16'h0000; s2 <= 16'h0000; s3 <= 16'h0000;
            s4 <= 16'h0000; s5 <= 16'h0000; s6 <= 16'h0000; s7 <= 16'h0000;
        end else if (clear) begin
            sp <= 4'd0;
        end else if (push && (sp < 4'd8)) begin
            case (sp[2:0])
                3'd0: s0 <= wdata;
                3'd1: s1 <= wdata;
                3'd2: s2 <= wdata;
                3'd3: s3 <= wdata;
                3'd4: s4 <= wdata;
                3'd5: s5 <= wdata;
                3'd6: s6 <= wdata;
                3'd7: s7 <= wdata;
            endcase
            sp <= sp + 4'd1;
        end else if (replace_top && (sp >= 4'd1)) begin
            case (tos_idx)
                3'd0: s0 <= wdata;
                3'd1: s1 <= wdata;
                3'd2: s2 <= wdata;
                3'd3: s3 <= wdata;
                3'd4: s4 <= wdata;
                3'd5: s5 <= wdata;
                3'd6: s6 <= wdata;
                3'd7: s7 <= wdata;
            endcase
        end else if (pop2_push1 && (sp >= 4'd2)) begin
            case (nos_idx)
                3'd0: s0 <= wdata;
                3'd1: s1 <= wdata;
                3'd2: s2 <= wdata;
                3'd3: s3 <= wdata;
                3'd4: s4 <= wdata;
                3'd5: s5 <= wdata;
                3'd6: s6 <= wdata;
                3'd7: s7 <= wdata;
            endcase
            sp <= sp - 4'd1;
        end
    end
endmodule
