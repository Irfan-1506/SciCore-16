// SciCore-16 v2.1: Top-Level Scientific Calculator Core (RPN Datapath + Controller)
// Implements:
//   - Task 1.1: CORDIC [-pi, +pi] quadrant folding + domain_err wired to err_flags[1]
//   - Task 1.3: Explicit error policy:
//       * Overflow (ADD/SUB/NEG/MUL/DIV/EXP): saturate to 0x7FFF / 0x8000, commit, set err_flags[0]
//       * Fatal/Domain/Stack errors (div_zero, domain_err, stack_ovf, stack_udf):
//         leave RPN stack UNCHANGED and latch corresponding bit in err_flags[4:0]
//   - Task 1.4: TAN (0xE, micro-sequence CORDIC -> DIV) and PUSH_PI (0xF, 0x0324)
//   - Task 1.5: STO/RCL use cmd_imm[1:0] register index
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
    output [4:0]  err_flags
);
    // Stack control
    reg        st_clear, st_push, st_rep, st_pop2;
    reg [15:0] st_wdata;
    wire [15:0] tos, nos;
    wire        st_empty, st_full;

    // Register bank (user memory M0..M3)
    reg        rb_we;
    reg [1:0]  rb_addr;
    /* verilator lint_off UNUSEDSIGNAL */
    wire [15:0] rb_rdata_a, rb_rdata_b;

    // ALU signals
    wire [2:0]  alu_op;
    wire [15:0] alu_a, alu_b, alu_res;
    wire        alu_zero, alu_neg, alu_ovf;

    // Multi-cycle unit handshakes
    reg        mul_start;
    wire [15:0] mul_res;
    wire        mul_ovf, mul_busy, mul_done;

    reg        div_start;
    reg        div_use_tan;
    reg [15:0] tan_sin_lat;
    reg [15:0] tan_cos_lat;
    wire [15:0] div_a_mux;
    wire [15:0] div_b_mux;
    wire [15:0] div_res;
    wire        div_zero, div_ovf, div_busy, div_done;

    reg        cor_start;
    wire [15:0] cor_sin, cor_cos;
    wire        cor_dom_err, cor_busy, cor_done;

    reg        sq_start;
    wire [15:0] sq_res;
    wire        sq_err, sq_busy, sq_done;

    reg        le_start, le_mode;
    wire [15:0] le_res;
    wire        le_err, le_ovf, le_busy, le_done;
    /* verilator lint_on UNUSEDSIGNAL */

    // Controller FSM states:
    //   3'd0 = IDLE
    //   3'd1 = WAIT_UNIT   (waiting for single arithmetic unit)
    //   3'd2 = RCL_FETCH   (waiting 1 cycle for register_bank read address)
    //   3'd3 = COMPLETE    (stack/reg write committed -> assert done)
    //   3'd4 = TAN_DIV     (second half of TAN micro-sequence: wait for DIV)
    reg [2:0]  state;
    reg [3:0]  active_op;
    reg        err_ovf, err_dom, err_dz, err_stk_udf, err_stk_ovf;

    assign alu_op    = (cmd_op == 4'h2) ? 3'b000 :
                       (cmd_op == 4'h3) ? 3'b001 : 3'b111;
    assign alu_a     = (cmd_op == 4'h6) ? tos : nos;
    assign alu_b     = tos;
    assign div_a_mux = div_use_tan ? tan_sin_lat : nos;
    assign div_b_mux = div_use_tan ? tan_cos_lat : tos;

    assign result    = tos;
    assign err_flags = {err_stk_ovf, err_stk_udf, err_dz, err_dom, err_ovf};

    expression_stack u_stack (
        .clk(clk), .rst(rst), .clear(st_clear), .push(st_push),
        .replace_top(st_rep), .pop2_push1(st_pop2), .wdata(st_wdata),
        .tos(tos), .nos(nos), .sp(stack_depth), .empty(st_empty), .full(st_full)
    );

    register_bank u_regbank (
        .clk(clk), .rst(rst), .we(rb_we), .waddr(rb_addr), .wdata(tos),
        .raddr_a(rb_addr), .raddr_b(2'b00), .rdata_a(rb_rdata_a), .rdata_b(rb_rdata_b)
    );

    alu16 u_alu (
        .a(alu_a), .b(alu_b), .opcode(alu_op),
        .result(alu_res), .zero(alu_zero), .neg(alu_neg), .overflow(alu_ovf)
    );

    multiplier u_mul (
        .clk(clk), .rst(rst), .start(mul_start), .a(nos), .b(tos),
        .result(mul_res), .overflow(mul_ovf), .busy(mul_busy), .done(mul_done)
    );

    divider u_div (
        .clk(clk), .rst(rst), .start(div_start), .a(div_a_mux), .b(div_b_mux),
        .result(div_res), .div_zero(div_zero), .overflow(div_ovf), .busy(div_busy), .done(div_done)
    );

    cordic u_cordic (
        .clk(clk), .rst(rst), .start(cor_start), .theta(tos),
        .sin_out(cor_sin), .cos_out(cor_cos), .domain_err(cor_dom_err),
        .busy(cor_busy), .done(cor_done)
    );

    sqrt_unit u_sqrt (
        .clk(clk), .rst(rst), .start(sq_start), .x(tos),
        .result(sq_res), .domain_err(sq_err), .busy(sq_busy), .done(sq_done)
    );

    log_exp u_logexp (
        .clk(clk), .rst(rst), .start(le_start), .mode(le_mode), .x(tos),
        .result(le_res), .domain_err(le_err), .overflow(le_ovf), .busy(le_busy), .done(le_done)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= 3'd0;
            active_op   <= 4'h0;
            busy        <= 1'b0;
            done        <= 1'b0;
            st_clear    <= 1'b0;
            st_push     <= 1'b0;
            st_rep      <= 1'b0;
            st_pop2     <= 1'b0;
            st_wdata    <= 16'h0000;
            rb_we       <= 1'b0;
            rb_addr     <= 2'b00;
            mul_start   <= 1'b0;
            div_start   <= 1'b0;
            div_use_tan <= 1'b0;
            tan_sin_lat <= 16'h0000;
            tan_cos_lat <= 16'h0000;
            cor_start   <= 1'b0;
            sq_start    <= 1'b0;
            le_start    <= 1'b0;
            le_mode     <= 1'b0;
            err_ovf     <= 1'b0;
            err_dom     <= 1'b0;
            err_dz      <= 1'b0;
            err_stk_udf <= 1'b0;
            err_stk_ovf <= 1'b0;
        end else begin
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

            case (state)
                3'd0: begin // IDLE
                    div_use_tan <= 1'b0;
                    if (cmd_valid) begin
                        active_op <= cmd_op;
                        case (cmd_op)
                            4'h0: begin // PUSH
                                if (st_full) begin
                                    err_stk_ovf <= 1'b1;
                                    done        <= 1'b1;
                                end else begin
                                    st_push  <= 1'b1;
                                    st_wdata <= cmd_imm;
                                    busy     <= 1'b1;
                                    state    <= 3'd3;
                                end
                            end
                            4'h1: begin // CLEAR
                                st_clear    <= 1'b1;
                                err_ovf     <= 1'b0;
                                err_dom     <= 1'b0;
                                err_dz      <= 1'b0;
                                err_stk_udf <= 1'b0;
                                err_stk_ovf <= 1'b0;
                                busy        <= 1'b1;
                                state       <= 3'd3;
                            end
                            4'h2, 4'h3: begin // ADD, SUB (saturating)
                                if (stack_depth < 4'd2) begin
                                    err_stk_udf <= 1'b1;
                                    done        <= 1'b1;
                                end else begin
                                    st_pop2  <= 1'b1;
                                    st_wdata <= alu_res;
                                    err_ovf  <= err_ovf | alu_ovf;
                                    busy     <= 1'b1;
                                    state    <= 3'd3;
                                end
                            end
                            4'h6: begin // NEG (saturating)
                                if (st_empty) begin
                                    err_stk_udf <= 1'b1;
                                    done        <= 1'b1;
                                end else begin
                                    st_rep   <= 1'b1;
                                    st_wdata <= alu_res;
                                    err_ovf  <= err_ovf | alu_ovf;
                                    busy     <= 1'b1;
                                    state    <= 3'd3;
                                end
                            end
                            4'h4: begin // MUL
                                if (stack_depth < 4'd2) begin
                                    err_stk_udf <= 1'b1;
                                    done        <= 1'b1;
                                end else begin
                                    mul_start <= 1'b1;
                                    busy      <= 1'b1;
                                    state     <= 3'd1;
                                end
                            end
                            4'h5: begin // DIV
                                if (stack_depth < 4'd2) begin
                                    err_stk_udf <= 1'b1;
                                    done        <= 1'b1;
                                end else begin
                                    div_use_tan <= 1'b0;
                                    div_start   <= 1'b1;
                                    busy        <= 1'b1;
                                    state       <= 3'd1;
                                end
                            end
                            4'h7: begin // SQRT
                                if (st_empty) begin
                                    err_stk_udf <= 1'b1;
                                    done        <= 1'b1;
                                end else begin
                                    sq_start <= 1'b1;
                                    busy     <= 1'b1;
                                    state    <= 3'd1;
                                end
                            end
                            4'h8, 4'h9, 4'hE: begin // SIN, COS, TAN
                                if (st_empty) begin
                                    err_stk_udf <= 1'b1;
                                    done        <= 1'b1;
                                end else begin
                                    cor_start <= 1'b1;
                                    busy      <= 1'b1;
                                    state     <= 3'd1;
                                end
                            end
                            4'hA: begin // LN
                                if (st_empty) begin
                                    err_stk_udf <= 1'b1;
                                    done        <= 1'b1;
                                end else begin
                                    le_mode  <= 1'b0;
                                    le_start <= 1'b1;
                                    busy     <= 1'b1;
                                    state    <= 3'd1;
                                end
                            end
                            4'hB: begin // EXP
                                if (st_empty) begin
                                    err_stk_udf <= 1'b1;
                                    done        <= 1'b1;
                                end else begin
                                    le_mode  <= 1'b1;
                                    le_start <= 1'b1;
                                    busy     <= 1'b1;
                                    state    <= 3'd1;
                                end
                            end
                            4'hC: begin // STO M[cmd_imm[1:0]]
                                if (st_empty) begin
                                    err_stk_udf <= 1'b1;
                                    done        <= 1'b1;
                                end else begin
                                    rb_addr <= cmd_imm[1:0];
                                    rb_we   <= 1'b1;
                                    busy    <= 1'b1;
                                    state   <= 3'd3;
                                end
                            end
                            4'hD: begin // RCL M[cmd_imm[1:0]]
                                if (st_full) begin
                                    err_stk_ovf <= 1'b1;
                                    done        <= 1'b1;
                                end else begin
                                    rb_addr <= cmd_imm[1:0];
                                    busy    <= 1'b1;
                                    state   <= 3'd2;
                                end
                            end
                            4'hF: begin // PUSH_PI (0x0324 = 3.140625)
                                if (st_full) begin
                                    err_stk_ovf <= 1'b1;
                                    done        <= 1'b1;
                                end else begin
                                    st_push  <= 1'b1;
                                    st_wdata <= 16'h0324;
                                    busy     <= 1'b1;
                                    state    <= 3'd3;
                                end
                            end
                            default: begin
                                done <= 1'b1;
                            end
                        endcase
                    end
                end

                3'd1: begin // WAIT_UNIT
                    if ((active_op == 4'h4) && mul_done) begin
                        st_pop2  <= 1'b1;
                        st_wdata <= mul_res;
                        err_ovf  <= err_ovf | mul_ovf;
                        state    <= 3'd3;
                    end else if ((active_op == 4'h5) && div_done) begin
                        if (div_zero) begin
                            // Error policy: leave stack UNCHANGED on div_zero
                            err_dz <= 1'b1;
                        end else begin
                            st_pop2  <= 1'b1;
                            st_wdata <= div_res;
                            err_ovf  <= err_ovf | div_ovf;
                        end
                        state <= 3'd3;
                    end else if ((active_op == 4'h7) && sq_done) begin
                        if (sq_err) begin
                            err_dom <= 1'b1;
                        end else begin
                            st_rep   <= 1'b1;
                            st_wdata <= sq_res;
                        end
                        state <= 3'd3;
                    end else if ((active_op == 4'h8) && cor_done) begin
                        if (cor_dom_err) begin
                            err_dom <= 1'b1;
                        end else begin
                            st_rep   <= 1'b1;
                            st_wdata <= cor_sin;
                        end
                        state <= 3'd3;
                    end else if ((active_op == 4'h9) && cor_done) begin
                        if (cor_dom_err) begin
                            err_dom <= 1'b1;
                        end else begin
                            st_rep   <= 1'b1;
                            st_wdata <= cor_cos;
                        end
                        state <= 3'd3;
                    end else if ((active_op == 4'hE) && cor_done) begin
                        if (cor_dom_err) begin
                            err_dom <= 1'b1;
                            state   <= 3'd3;
                        end else begin
                            // TAN step 2: latch sin/cos and launch DIV(sin, cos)
                            tan_sin_lat <= cor_sin;
                            tan_cos_lat <= cor_cos;
                            div_use_tan <= 1'b1;
                            div_start   <= 1'b1;
                            state       <= 3'd4;
                        end
                    end else if (((active_op == 4'hA) || (active_op == 4'hB)) && le_done) begin
                        if (le_err) begin
                            err_dom <= 1'b1;
                        end else begin
                            st_rep   <= 1'b1;
                            st_wdata <= le_res;
                            err_ovf  <= err_ovf | le_ovf;
                        end
                        state <= 3'd3;
                    end
                end

                3'd2: begin // RCL_FETCH
                    st_push  <= 1'b1;
                    st_wdata <= rb_rdata_a;
                    state    <= 3'd3;
                end

                3'd3: begin // COMPLETE (stack/reg committed)
                    busy        <= 1'b0;
                    done        <= 1'b1;
                    div_use_tan <= 1'b0;
                    state       <= 3'd0;
                end

                3'd4: begin // TAN_DIV
                    if (div_done) begin
                        div_use_tan <= 1'b0;
                        if (div_zero) begin
                            err_dz <= 1'b1;
                        end else begin
                            st_rep   <= 1'b1;
                            st_wdata <= div_res;
                            err_ovf  <= err_ovf | div_ovf;
                        end
                        state <= 3'd3;
                    end
                end

                default: begin
                    busy  <= 1'b0;
                    state <= 3'd0;
                end
            endcase
        end
    end
endmodule
