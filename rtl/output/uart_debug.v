// SciCore-16 v2.1: 8N1 UART Debug TX & RX (Task 2.6)
// Default: 115200 baud @ 10 MHz -> CLKS_PER_BIT = 87.
// TX: On tx_start, formats and transmits 8-byte ASCII frame: "XXXX_E\r\n"
//     (4 hex chars for result[15:0], space, hex char for err_flags[3:0], CR, LF).
// RX: Synchronizes uart_rx (2-FF) and outputs rx_valid + rx_byte[7:0] on valid 8N1 frame.
module uart_debug #(
    parameter integer CLKS_PER_BIT = 87
) (
    input         clk,
    input         rst,
    input         tx_start,
    input  [15:0] tx_result,
    input  [4:0]  tx_err,
    output reg    uart_tx,
    output reg    tx_busy,
    input         uart_rx,
    output reg    rx_valid,
    output reg [7:0] rx_byte
);
    // Hex nibble to ASCII
    function [7:0] hex2ascii;
        input [3:0] nib;
        begin
            if (nib < 4'd10) hex2ascii = 8'h30 + {4'd0, nib};
            else             hex2ascii = 8'h37 + {4'd0, nib}; // 'A' - 10 = 0x37
        end
    endfunction

    // --- TX Engine (8 bytes: H3 H2 H1 H0 ' ' ERR '\r' '\n') ---
    reg [15:0] lat_res;
    reg [4:0]  lat_err;
    reg [2:0]  byte_idx;
    reg [3:0]  tx_bit_idx; // 0=start, 1..8=data, 9=stop
    reg [15:0] tx_clk_cnt;
    reg [7:0]  tx_cur_byte;

    always @(*) begin
        case (byte_idx)
            3'd0: tx_cur_byte = hex2ascii(lat_res[15:12]);
            3'd1: tx_cur_byte = hex2ascii(lat_res[11:8]);
            3'd2: tx_cur_byte = hex2ascii(lat_res[7:4]);
            3'd3: tx_cur_byte = hex2ascii(lat_res[3:0]);
            3'd4: tx_cur_byte = 8'h20; // ' '
            3'd5: tx_cur_byte = hex2ascii({lat_err[4] | lat_err[3], lat_err[2:0]});
            3'd6: tx_cur_byte = 8'h0D; // '\r'
            3'd7: tx_cur_byte = 8'h0A; // '\n'
            default: tx_cur_byte = 8'h0A;
        endcase
    end

    // --- RX Engine (2-FF sync + 8N1 receiver) ---
    reg        rx_s1, rx_s2;
    reg [1:0]  rx_state; // 0=IDLE, 1=START, 2=DATA, 3=STOP
    reg [2:0]  rx_bit_idx;
    reg [15:0] rx_clk_cnt;
    reg [7:0]  rx_shift;

    wire [15:0] half_bit;
    wire [15:0] full_bit;
    assign half_bit = CLKS_PER_BIT[15:0] >> 1;
    assign full_bit = CLKS_PER_BIT[15:0] - 16'd1;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            uart_tx    <= 1'b1;
            tx_busy    <= 1'b0;
            lat_res    <= 16'h0000;
            lat_err    <= 5'd0;
            byte_idx   <= 3'd0;
            tx_bit_idx <= 4'd0;
            tx_clk_cnt <= 16'd0;

            rx_s1      <= 1'b1;
            rx_s2      <= 1'b1;
            rx_state   <= 2'd0;
            rx_bit_idx <= 3'd0;
            rx_clk_cnt <= 16'd0;
            rx_shift   <= 8'd0;
            rx_valid   <= 1'b0;
            rx_byte    <= 8'd0;
        end else begin
            // --- TX ---
            if (!tx_busy) begin
                uart_tx <= 1'b1;
                if (tx_start) begin
                    lat_res    <= tx_result;
                    lat_err    <= tx_err;
                    byte_idx   <= 3'd0;
                    tx_bit_idx <= 4'd0;
                    tx_clk_cnt <= 16'd0;
                    tx_busy    <= 1'b1;
                    uart_tx    <= 1'b0; // start bit
                end
            end else begin
                if (tx_clk_cnt < full_bit) begin
                    tx_clk_cnt <= tx_clk_cnt + 16'd1;
                end else begin
                    tx_clk_cnt <= 16'd0;
                    if (tx_bit_idx < 4'd8) begin
                        uart_tx    <= tx_cur_byte[tx_bit_idx[2:0]];
                        tx_bit_idx <= tx_bit_idx + 4'd1;
                    end else if (tx_bit_idx == 4'd8) begin
                        uart_tx    <= 1'b1; // stop bit
                        tx_bit_idx <= 4'd9;
                    end else begin
                        if (byte_idx == 3'd7) begin
                            tx_busy <= 1'b0;
                            uart_tx <= 1'b1;
                        end else begin
                            byte_idx   <= byte_idx + 3'd1;
                            tx_bit_idx <= 4'd0;
                            uart_tx    <= 1'b0; // next start bit
                        end
                    end
                end
            end

            // --- RX ---
            rx_s1    <= uart_rx;
            rx_s2    <= rx_s1;
            rx_valid <= 1'b0;

            case (rx_state)
                2'd0: begin // IDLE
                    if (!rx_s2) begin
                        rx_clk_cnt <= 16'd0;
                        rx_state   <= 2'd1;
                    end
                end
                2'd1: begin // START mid-bit check
                    if (rx_clk_cnt >= half_bit) begin
                        if (!rx_s2) begin
                            rx_clk_cnt <= 16'd0;
                            rx_bit_idx <= 3'd0;
                            rx_state   <= 2'd2;
                        end else begin
                            rx_state <= 2'd0;
                        end
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 16'd1;
                    end
                end
                2'd2: begin // DATA bits
                    if (rx_clk_cnt >= full_bit) begin
                        rx_clk_cnt <= 16'd0;
                        rx_shift[rx_bit_idx] <= rx_s2;
                        if (rx_bit_idx == 3'd7) begin
                            rx_state <= 2'd3;
                        end else begin
                            rx_bit_idx <= rx_bit_idx + 3'd1;
                        end
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 16'd1;
                    end
                end
                2'd3: begin // STOP bit
                    if (rx_clk_cnt >= full_bit) begin
                        if (rx_s2) begin
                            rx_byte  <= rx_shift;
                            rx_valid <= 1'b1;
                        end
                        rx_state <= 2'd0;
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 16'd1;
                    end
                end
                default: rx_state <= 2'd0;
            endcase
        end
    end
endmodule
