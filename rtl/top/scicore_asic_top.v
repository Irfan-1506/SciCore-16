// SciCore-16 v2.1: Full-Chip ASIC Top-Level I/O Wrapper (Phases 1 & 2 Complete)
// - Task 2.1: Uses auto-generated keymap_decode from integration/keymap.csv
// - Task 2.2: Multi-digit decimal number entry with '.', DEL, ENT, CLR, and operator auto-push
// - Task 1.5: User-indexed STO/RCL (STO/RCL followed by digit 0..3 selects M0..M3)
// - Task 2.3: Hardened keypad_scanner (2-FF sync, press/release debounce, row settling)
// - Task 2.4: Async-assert / sync-deassert 2-FF reset synchronizer + 2-FF uart_rx sync
// - Task 2.5: Honest spi_result_shifter (raw 16-bit SPI output)
// - Task 2.6: Real 8N1 UART TX (result + err_flags) & RX command trigger
module scicore_asic_top #(
    parameter integer CLK_HZ          = 10000000,
    parameter integer DEBOUNCE_CYCLES = 150000,
    parameter integer SETTLE_CYCLES   = 100,
    parameter integer UART_CLKS_BIT   = 87
) (
    input        clk,
    input        reset_n,
    output [3:0] row,
    input  [7:0] col,
    output       disp_clk,
    output       disp_mosi,
    output       disp_cs,
    output       disp_dc,
    output       disp_rst,
    output       disp_bl,
    output       uart_tx,
    input        uart_rx,
    output       busy,
    output       error
);
    // Task 2.4: Async-assert, sync-deassert reset synchronizer
    reg [1:0] rst_sync;
    wire      rst;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) rst_sync <= 2'b11;
        else          rst_sync <= {rst_sync[0], 1'b0};
    end
    assign rst = rst_sync[1];

    // Keypad scanner + CSV-generated keymap decoder
    wire       key_valid;
    wire [4:0] key_code;
    wire [2:0] key_kind; // 0=NOP, 1=DIGIT, 2=OP, 3=CTRL, 4=MEM
    wire [3:0] key_val;

    keypad_scanner #(
        .CLK_HZ(CLK_HZ),
        .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES),
        .SETTLE_CYCLES(SETTLE_CYCLES)
    ) u_keypad (
        .clk(clk), .rst(rst),
        .row(row), .col(col),
        .key_valid(key_valid), .key_code(key_code)
    );

    keymap_decode u_keymap (
        .key_code(key_code),
        .key_kind(key_kind),
        .key_val(key_val)
    );

    // Core calculator instance
    reg         cmd_valid;
    reg  [3:0]  cmd_op;
    reg  [15:0] cmd_imm;
    wire [15:0] core_result;
    /* verilator lint_off UNUSEDSIGNAL */
    wire [3:0]  stack_depth;
    /* verilator lint_on UNUSEDSIGNAL */
    wire        core_busy;
    wire        core_done;
    wire [4:0]  err_flags;

    scicore_top u_core (
        .clk(clk), .rst(rst),
        .cmd_valid(cmd_valid), .cmd_op(cmd_op), .cmd_imm(cmd_imm),
        .result(core_result), .stack_depth(stack_depth),
        .busy(core_busy), .done(core_done), .err_flags(err_flags)
    );

    // SPI Result Shifter (Task 2.5)
    wire spi_busy;
    spi_result_shifter u_spi (
        .clk(clk), .rst(rst),
        .update_valid(core_done), .data_in(core_result),
        .disp_clk(disp_clk), .disp_mosi(disp_mosi),
        .disp_cs(disp_cs), .disp_dc(disp_dc),
        .disp_rst(disp_rst), .disp_bl(disp_bl),
        .busy(spi_busy)
    );

    // 8N1 UART Debug TX/RX (Task 2.6)
    /* verilator lint_off UNUSEDSIGNAL */
    wire       uart_tx_busy;
    /* verilator lint_on UNUSEDSIGNAL */
    wire       uart_rx_valid;
    wire [7:0] uart_rx_byte;

    uart_debug #(.CLKS_PER_BIT(UART_CLKS_BIT)) u_uart (
        .clk(clk), .rst(rst),
        .tx_start(core_done), .tx_result(core_result), .tx_err(err_flags),
        .uart_tx(uart_tx), .tx_busy(uart_tx_busy),
        .uart_rx(uart_rx), .rx_valid(uart_rx_valid), .rx_byte(uart_rx_byte)
    );

    assign busy  = core_busy | spi_busy;
    assign error = (err_flags != 5'b00000);

    // --- Task 2.2 & 1.5: Multi-Digit Decimal Entry + Auto-Push + User-Indexed STO/RCL ---
    reg        entry_active;
    reg        in_frac;
    reg [7:0]  int_acc;       // 0..127
    reg [1:0]  frac_cnt;      // 0, 1, or 2 fractional digits
    reg [6:0]  frac_acc;      // 0..99 (decimal tenths or hundredths)
    reg [1:0]  mem_pending;   // 0=none, 1=wait digit for STO, 2=wait digit for RCL
    reg        op_pending;    // auto-push in progress; fire pending_op once PUSH completes
    reg [3:0]  pending_op;

    // Convert (int_acc, frac_acc, frac_cnt) to Q8.8 with round-to-nearest
    // 1 frac digit: (frac_acc * 256 + 5) / 10
    // 2 frac digits: (frac_acc * 256 + 50) / 100
    wire [15:0] frac_scaled;
    wire [7:0]  frac_q88;
    wire [15:0] entry_q88;

    assign frac_scaled = (frac_cnt == 2'd1) ? (({9'd0, frac_acc} * 16'd256 + 16'd5) / 16'd10) :
                         (frac_cnt == 2'd2) ? (({9'd0, frac_acc} * 16'd256 + 16'd50) / 16'd100) :
                                              16'd0;
    assign frac_q88    = (frac_scaled > 16'd255) ? 8'd255 : frac_scaled[7:0];
    assign entry_q88   = {1'b0, int_acc[6:0], frac_q88};

    // Next integer value when appending digit (clamped at 127)
    wire [11:0] int_next;
    assign int_next = ({4'd0, int_acc} * 12'd10) + {8'd0, key_val};

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cmd_valid    <= 1'b0;
            cmd_op       <= 4'h0;
            cmd_imm      <= 16'h0000;
            entry_active <= 1'b0;
            in_frac      <= 1'b0;
            int_acc      <= 8'd0;
            frac_cnt     <= 2'd0;
            frac_acc     <= 7'd0;
            mem_pending  <= 2'd0;
            op_pending   <= 1'b0;
            pending_op   <= 4'h0;
        end else begin
            cmd_valid <= 1'b0;

            // Step 2 of auto-push: once PUSH finishes, issue queued operator
            if (op_pending && core_done) begin
                cmd_valid  <= 1'b1;
                cmd_op     <= pending_op;
                cmd_imm    <= 16'h0000;
                op_pending <= 1'b0;
            end else if (key_valid && !core_busy && !op_pending) begin
                // Handle STO / RCL register index digit (0..3)
                if (mem_pending != 2'd0) begin
                    if (key_kind == 3'd1) begin
                        cmd_valid   <= 1'b1;
                        cmd_op      <= (mem_pending == 2'd1) ? 4'hC : 4'hD;
                        cmd_imm     <= {14'd0, key_val[1:0]};
                        mem_pending <= 2'd0;
                    end else begin
                        mem_pending <= 2'd0;
                    end
                end else begin
                    case (key_kind)
                        3'd1: begin // DIGIT 0..9
                            entry_active <= 1'b1;
                            if (!in_frac) begin
                                if (int_next <= 12'd127) int_acc <= int_next[7:0];
                            end else if (frac_cnt == 2'd0) begin
                                frac_acc <= {3'd0, key_val};
                                frac_cnt <= 2'd1;
                            end else if (frac_cnt == 2'd1) begin
                                frac_acc <= (frac_acc * 7'd10) + {3'd0, key_val};
                                frac_cnt <= 2'd2;
                            end
                        end

                        3'd3: begin // CTRL: 1=CLR, 2=DEL, 3=DOT, 4=ENT
                            if (key_val == 4'd1) begin // CLR
                                entry_active <= 1'b0;
                                in_frac      <= 1'b0;
                                int_acc      <= 8'd0;
                                frac_cnt     <= 2'd0;
                                frac_acc     <= 7'd0;
                                cmd_valid    <= 1'b1;
                                cmd_op       <= 4'h1;
                                cmd_imm      <= 16'h0000;
                            end else if (key_val == 4'd2) begin // DEL (backspace)
                                if (frac_cnt == 2'd2) begin
                                    frac_acc <= frac_acc / 7'd10;
                                    frac_cnt <= 2'd1;
                                end else if (frac_cnt == 2'd1) begin
                                    frac_acc <= 7'd0;
                                    frac_cnt <= 2'd0;
                                end else if (in_frac) begin
                                    in_frac <= 1'b0;
                                end else begin
                                    int_acc <= int_acc / 8'd10;
                                end
                            end else if (key_val == 4'd3) begin // '.'
                                entry_active <= 1'b1;
                                in_frac      <= 1'b1;
                            end else if (key_val == 4'd4) begin // ENT / '='
                                if (entry_active) begin
                                    cmd_valid    <= 1'b1;
                                    cmd_op       <= 4'h0; // PUSH
                                    cmd_imm      <= entry_q88;
                                    entry_active <= 1'b0;
                                    in_frac      <= 1'b0;
                                    int_acc      <= 8'd0;
                                    frac_cnt     <= 2'd0;
                                    frac_acc     <= 7'd0;
                                end
                            end
                        end

                        3'd2: begin // OP (ADD, SUB, MUL, DIV, NEG, SQRT, SIN, COS, TAN, LN, EXP, PI)
                            if (entry_active && (key_val != 4'hF)) begin
                                // Auto-push pending number entry, then run operator on core_done
                                cmd_valid    <= 1'b1;
                                cmd_op       <= 4'h0;
                                cmd_imm      <= entry_q88;
                                entry_active <= 1'b0;
                                in_frac      <= 1'b0;
                                int_acc      <= 8'd0;
                                frac_cnt     <= 2'd0;
                                frac_acc     <= 7'd0;
                                op_pending   <= 1'b1;
                                pending_op   <= key_val;
                            end else begin
                                cmd_valid <= 1'b1;
                                cmd_op    <= key_val;
                                cmd_imm   <= 16'h0000;
                            end
                        end

                        3'd4: begin // MEM (12=STO, 13=RCL -> wait for digit 0..3)
                            mem_pending <= (key_val == 4'd12) ? 2'd1 : 2'd2;
                        end

                        default: begin
                            // NOP (2ND, RAD)
                        end
                    endcase
                end
            end else if (uart_rx_valid && !core_busy && !op_pending) begin
                // Minimal UART RX command parser: 'c'=CLEAR, '+'=ADD, '-'=SUB, '*'=MUL, '/'=DIV, 'p'=PI
                case (uart_rx_byte)
                    8'h63: begin cmd_valid <= 1'b1; cmd_op <= 4'h1; cmd_imm <= 16'h0000; end // 'c'
                    8'h2B: begin cmd_valid <= 1'b1; cmd_op <= 4'h2; cmd_imm <= 16'h0000; end // '+'
                    8'h2D: begin cmd_valid <= 1'b1; cmd_op <= 4'h3; cmd_imm <= 16'h0000; end // '-'
                    8'h2A: begin cmd_valid <= 1'b1; cmd_op <= 4'h4; cmd_imm <= 16'h0000; end // '*'
                    8'h2F: begin cmd_valid <= 1'b1; cmd_op <= 4'h5; cmd_imm <= 16'h0000; end // '/'
                    8'h70: begin cmd_valid <= 1'b1; cmd_op <= 4'hF; cmd_imm <= 16'h0000; end // 'p'
                    default: ;
                endcase
            end
        end
    end
endmodule
