// SciCore-16 v2.0: 4x8 Matrix Keypad Scanner with Debounce
// Scans active-low row[3:0] and samples active-low col[7:0].
// Emits 1-cycle key_valid pulse with 5-bit key_code = {row_idx[1:0], col_idx[2:0]}.
module keypad_scanner (
    input            clk,
    input            rst,
    output reg [3:0] row,
    input      [7:0] col,
    output reg       key_valid,
    output reg [4:0] key_code
);
    reg [1:0]  scan_row;
    reg [7:0]  debounce_cnt;
    reg        key_latched;
    wire       any_col_low;
    wire [2:0] col_idx;

    assign any_col_low = (col != 8'hFF);
    assign col_idx = (!col[0]) ? 3'd0 :
                     (!col[1]) ? 3'd1 :
                     (!col[2]) ? 3'd2 :
                     (!col[3]) ? 3'd3 :
                     (!col[4]) ? 3'd4 :
                     (!col[5]) ? 3'd5 :
                     (!col[6]) ? 3'd6 : 3'd7;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scan_row     <= 2'd0;
            row          <= 4'b1110;
            debounce_cnt <= 8'd0;
            key_latched  <= 1'b0;
            key_valid    <= 1'b0;
            key_code     <= 5'd0;
        end else begin
            key_valid <= 1'b0;
            if (any_col_low) begin
                if (!key_latched) begin
                    if (debounce_cnt == 8'hFF) begin
                        key_valid   <= 1'b1;
                        key_code    <= {scan_row, col_idx};
                        key_latched <= 1'b1;
                    end else begin
                        debounce_cnt <= debounce_cnt + 8'd1;
                    end
                end
            end else begin
                debounce_cnt <= 8'd0;
                key_latched  <= 1'b0;
                scan_row     <= scan_row + 2'd1;
                case (scan_row + 2'd1)
                    2'd0: row <= 4'b1110;
                    2'd1: row <= 4'b1101;
                    2'd2: row <= 4'b1011;
                    2'd3: row <= 4'b0111;
                endcase
            end
        end
    end
endmodule
