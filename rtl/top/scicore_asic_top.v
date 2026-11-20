// SciCore-16 v2.0: Full-Chip ASIC Top-Level I/O Wrapper (Fixes SC-04)
// Matches the QFN-64 PCB signal pinout 1-to-1:
//   - Active-low RESET_N, 10 MHz CLK
//   - 4x8 Matrix Keypad (ROW[3:0], COL[7:0])
//   - 128x64 SPI Display (DISP_CLK, DISP_MOSI, DISP_CS, DISP_DC, DISP_RST, DISP_BL)
//   - UART Debug (UART_TX, UART_RX)
//   - Status LEDs (BUSY, ERROR)
module scicore_asic_top (
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
    output reg   uart_tx,
    input        uart_rx,
    output       busy,
    output       error
);
    wire        rst;
    wire        key_valid;
    wire [4:0]  key_code;

    reg         cmd_valid;
    reg  [3:0]  cmd_op;
    reg  [15:0] cmd_imm;

    wire [15:0] core_result;
    wire [3:0]  stack_depth;
    wire        core_busy;
    wire        core_done;
    wire [4:0]  err_flags;
    wire        disp_busy;

    assign rst   = ~reset_n;
    assign busy  = core_busy | disp_busy;
    assign error = (err_flags != 5'b00000);

    // 4x8 Keypad Scanner + Debouncer
    keypad_scanner u_keypad (
        .clk(clk), .rst(rst),
        .row(row), .col(col),
        .key_valid(key_valid), .key_code(key_code)
    );

    // Core SciCore-16 Scientific Calculator Engine
    scicore_top u_core (
        .clk(clk), .rst(rst),
        .cmd_valid(cmd_valid), .cmd_op(cmd_op), .cmd_imm(cmd_imm),
        .result(core_result), .stack_depth(stack_depth),
        .busy(core_busy), .done(core_done), .err_flags(err_flags)
    );

    // 128x64 SPI Display Controller
    display_controller u_disp (
        .clk(clk), .rst(rst),
        .update_valid(core_done), .data_in(core_result),
        .disp_clk(disp_clk), .disp_mosi(disp_mosi),
        .disp_cs(disp_cs), .disp_dc(disp_dc),
        .disp_rst(disp_rst), .disp_bl(disp_bl),
        .busy(disp_busy)
    );

    // Map 32 keypad codes to RPN commands (0..9 -> PUSH integer Q8.8, 10..23 -> ops)
    // and echo result status on UART_TX (idle high, simple debug heartbeat on core_done)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cmd_valid <= 1'b0;
            cmd_op    <= 4'h0;
            cmd_imm   <= 16'h0000;
            uart_tx   <= 1'b1;
        end else begin
            cmd_valid <= 1'b0;
            uart_tx   <= core_done ? core_result[15] : (uart_rx ? 1'b1 : 1'b1);
            if (key_valid && !core_busy) begin
                cmd_valid <= 1'b1;
                if (key_code < 5'd10) begin
                    cmd_op  <= 4'h0; // PUSH digit as Q8.8 integer
                    cmd_imm <= {4'd0, key_code[3:0], 8'h00};
                end else if (key_code == 5'd10) begin
                    cmd_op  <= 4'h1; // CLEAR
                end else if (key_code <= 5'd22) begin
                    cmd_op  <= key_code[3:0] - 4'd9; // ADD..RCL
                    cmd_imm <= 16'h0000;
                end else begin
                    cmd_op  <= 4'h0;
                    cmd_imm <= 16'h0080; // 0.5 constant
                end
            end
        end
    end
endmodule
