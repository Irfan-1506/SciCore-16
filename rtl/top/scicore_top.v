// SciCore-16 M5: Top-Level Scientific Calculator SoC (RPN Datapath + Controller)
// Commands (cmd_op[3:0]):
//   0x0: PUSH  (push cmd_imm)
//   0x1: CLEAR (clear stack & error flags)
//   0x2: ADD   (nos + tos)
//   0x3: SUB   (nos - tos)
//   0x4: MUL   (nos * tos)
//   0x5: DIV   (nos / tos)
//   0x6: NEG   (-tos)
//   0x7: SQRT  (sqrt(tos))
//   0x8: SIN   (sin(tos))
//   0x9: COS   (cos(tos))
//   0xA: LN    (ln(tos))
//   0xB: EXP   (exp(tos))
//   0xC: STO   (reg[cmd_imm[1:0]] <= tos)
//   0xD: RCL   (push reg[cmd_imm[1:0]])
module scicore_top (
    input         clk,
    input         rst,
    input         cmd_valid,
    input  [3:0]  cmd_op,
    input  [15:0] cmd_imm,
    output [15:0] result,
    output [3:0]  stack_depth,
    output reg    busy,
    output reg    done,
    output [2:0]  err_flags
);
    // Stack control
    reg        st_clear;
    reg        st_push;
    reg        st_rep;
    reg        st_pop2;
    reg [15:0] st_wdata;
    wire [15:0] tos;
    wire [15:0] nos;
    wire        st_empty;
    wire        st_full;

    // Register bank (user memory M0..M3)
    reg        rb_we;
    reg [1:0]  rb_addr;
    wire [15:0] rb_rdata_a;
    wire [15:0] rb_rdata_b;

    // ALU signals
    wire [2:0]  alu_op;
    wire [15:0] alu_a;
    wire [15:0] alu_b;
    wire [15:0] alu_res;
    wire        alu_zero;
    wire        alu_neg;
    wire        alu_ovf;

    // Multi-cycle unit handshakes
    reg        mul_start;
    wire [15:0] mul_res;
    wire        mul_ovf;
    wire        mul_busy;
    wire        mul_done;

    reg        div_start;
    wire [15:0] div_res;
    wire        div_zero;
    wire        div_ovf;
    wire        div_busy;
    wire        div_done;

    reg        cor_start;
    wire [15:0] cor_sin;
    wire [15:0] cor_cos;
    wire        cor_busy;
    wire        cor_done;

    reg        sq_start;
    wire [15:0] sq_res;
    wire        sq_err;
    wire        sq_busy;
    wire        sq_done;

    reg        le_start;
    reg        le_mode;
    wire [15:0] le_res;
    wire        le_err;
    wire        le_ovf;
    wire        le_busy;
    wire        le_done;

    // Controller state
    reg [1:0]  state; // 0=IDLE, 1=WAIT_UNIT, 2=RCL_PUSH
    reg [3:0]  active_op;
    reg        err_ovf;
    reg        err_dom;
    reg        err_dz;

    // ALU operand & opcode mux
    assign alu_op = (cmd_op == 4'h2) ? 3'b000 :
                    (cmd_op == 4'h3) ? 3'b001 : 3'b111;
    assign alu_a  = (cmd_op == 4'h6) ? tos : nos;
    assign alu_b  = tos;

    assign result    = tos;
    assign err_flags = {err_dz, err_dom, err_ovf};

    // Submodule instantiations
    expression_stack u_stack (
        .clk(clk), .rst(rst),
        .clear(st_clear), .push(st_push),
        .replace_top(st_rep), .pop2_push1(st_pop2),
        .wdata(st_wdata),
        .tos(tos), .nos(nos), .sp(stack_depth),
        .empty(st_empty), .full(st_full)
    );

    register_bank u_regbank (
        .clk(clk), .rst(rst),
        .we(rb_we), .waddr(rb_addr), .wdata(tos),
        .raddr_a(rb_addr), .raddr_b(2'b00),
        .rdata_a(rb_rdata_a), .rdata_b(rb_rdata_b)
    );

    alu16 u_alu (
        .a(alu_a), .b(alu_b), .opcode(alu_op),
        .result(alu_res), .zero(alu_zero), .neg(alu_neg), .overflow(alu_ovf)
    );

    multiplier u_mul (
        .clk(clk), .rst(rst), .start(mul_start),
        .a(nos), .b(tos),
        .result(mul_res), .overflow(mul_ovf), .busy(mul_busy), .done(mul_done)
    );

    divider u_div (
        .clk(clk), .rst(rst), .start(div_start),
        .a(nos), .b(tos),
        .result(div_res), .div_zero(div_zero), .overflow(div_ovf),
        .busy(div_busy), .done(div_done)
    );

    cordic u_cordic (
        .clk(clk), .rst(rst), .start(cor_start),
        .theta(tos),
        .sin_out(cor_sin), .cos_out(cor_cos),
        .busy(cor_busy), .done(cor_done)
    );

    sqrt_unit u_sqrt (
        .clk(clk), .rst(rst), .start(sq_start),
        .x(tos),
        .result(sq_res), .domain_err(sq_err),
        .busy(sq_busy), .done(sq_done)
    );

    log_exp u_logexp (
        .clk(clk), .rst(rst), .start(le_start), .mode(le_mode),
        .x(tos),
        .result(le_res), .domain_err(le_err), .overflow(le_ovf),
        .busy(le_busy), .done(le_done)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= 2'd0;
            active_op <= 4'h0;
            busy      <= 1'b0;
            done      <= 1'b0;
            st_clear  <= 1'b0;
            st_push   <= 1'b0;
            st_rep    <= 1'b0;
            st_pop2   <= 1'b0;
            st_wdata  <= 16'h0000;
            rb_we     <= 1'b0;
            rb_addr   <= 2'b00;
            mul_start <= 1'b0;
            div_start <= 1'b0;
            cor_start <= 1'b0;
            sq_start  <= 1'b0;
            le_start  <= 1'b0;
            le_mode   <= 1'b0;
            err_ovf   <= 1'b0;
            err_dom   <= 1'b0;
            err_dz    <= 1'b0;
        end else begin
            // Default 1-cycle pulses low
            done      <= 1'b0;
            st_clear  <= 1'b0;
            st_push   <= 1'b0;
            st_rep    <= 1'b0;
            st_pop2   <= 1'b0;
            rb_we     <= 1'b0;
            mul_start <= 1'b0;
            div_start <= 1'b0;
            cor_start <= 1'b0;
            sq_start  <= 1'b0;
            le_start  <= 1'b0;

            if (state == 2'd0) begin
                if (cmd_valid) begin
                    active_op <= cmd_op;
                    case (cmd_op)
                        4'h0: begin // PUSH
                            st_push  <= 1'b1;
                            st_wdata <= cmd_imm;
                            done     <= 1'b1;
                        end
                        4'h1: begin // CLEAR
                            st_clear <= 1'b1;
                            err_ovf  <= 1'b0;
                            err_dom  <= 1'b0;
                            err_dz   <= 1'b0;
                            done     <= 1'b1;
                        end
                        4'h2, 4'h3: begin // ADD, SUB
                            st_pop2  <= 1'b1;
                            st_wdata <= alu_res;
                            err_ovf  <= err_ovf | alu_ovf;
                            done     <= 1'b1;
                        end
                        4'h6: begin // NEG
                            st_rep   <= 1'b1;
                            st_wdata <= alu_res;
                            err_ovf  <= err_ovf | alu_ovf;
                            done     <= 1'b1;
                        end
                        4'h4: begin // MUL
                            mul_start <= 1'b1;
                            busy      <= 1'b1;
                            state     <= 2'd1;
                        end
                        4'h5: begin // DIV
                            div_start <= 1'b1;
                            busy      <= 1'b1;
                            state     <= 2'd1;
                        end
                        4'h7: begin // SQRT
                            sq_start <= 1'b1;
                            busy     <= 1'b1;
                            state    <= 2'd1;
                        end
                        4'h8, 4'h9: begin // SIN, COS
                            cor_start <= 1'b1;
                            busy      <= 1'b1;
                            state     <= 2'd1;
                        end
                        4'hA: begin // LN
                            le_mode  <= 1'b0;
                            le_start <= 1'b1;
                            busy     <= 1'b1;
                            state    <= 2'd1;
                        end
                        4'hB: begin // EXP
                            le_mode  <= 1'b1;
                            le_start <= 1'b1;
                            busy     <= 1'b1;
                            state    <= 2'd1;
                        end
                        4'hC: begin // STO
                            rb_addr <= cmd_imm[1:0];
                            rb_we   <= 1'b1;
                            done    <= 1'b1;
                        end
                        4'hD: begin // RCL
                            rb_addr <= cmd_imm[1:0];
                            busy    <= 1'b1;
                            state   <= 2'd2;
                        end
                        default: begin
                            done <= 1'b1;
                        end
                    endcase
                end
            end else if (state == 2'd1) begin
                if ((active_op == 4'h4) && mul_done) begin
                    st_pop2  <= 1'b1;
                    st_wdata <= mul_res;
                    err_ovf  <= err_ovf | mul_ovf;
                    busy     <= 1'b0;
                    done     <= 1'b1;
                    state    <= 2'd0;
                end else if ((active_op == 4'h5) && div_done) begin
                    st_pop2  <= 1'b1;
                    st_wdata <= div_res;
                    err_dz   <= err_dz  | div_zero;
                    err_ovf  <= err_ovf | div_ovf;
                    busy     <= 1'b0;
                    done     <= 1'b1;
                    state    <= 2'd0;
                end else if ((active_op == 4'h7) && sq_done) begin
                    st_rep   <= 1'b1;
                    st_wdata <= sq_res;
                    err_dom  <= err_dom | sq_err;
                    busy     <= 1'b0;
                    done     <= 1'b1;
                    state    <= 2'd0;
                end else if ((active_op == 4'h8) && cor_done) begin
                    st_rep   <= 1'b1;
                    st_wdata <= cor_sin;
                    busy     <= 1'b0;
                    done     <= 1'b1;
                    state    <= 2'd0;
                end else if ((active_op == 4'h9) && cor_done) begin
                    st_rep   <= 1'b1;
                    st_wdata <= cor_cos;
                    busy     <= 1'b0;
                    done     <= 1'b1;
                    state    <= 2'd0;
                end else if (((active_op == 4'hA) || (active_op == 4'hB)) && le_done) begin
                    st_rep   <= 1'b1;
                    st_wdata <= le_res;
                    err_dom  <= err_dom | le_err;
                    err_ovf  <= err_ovf | le_ovf;
                    busy     <= 1'b0;
                    done     <= 1'b1;
                    state    <= 2'd0;
                end
            end else if (state == 2'd2) begin
                // Complete RCL push on next cycle after rb_addr settles
                st_push  <= 1'b1;
                st_wdata <= rb_rdata_a;
                busy     <= 1'b0;
                done     <= 1'b1;
                state    <= 2'd0;
            end
        end
    end
endmodule
