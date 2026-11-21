// SciCore-16 v2.1: 4x8 Matrix Keypad Scanner with 2-FF Sync, Press/Release Debounce & Row Settling (Task 2.3)
// Default at 10 MHz: DEBOUNCE_CYCLES = 150,000 (~15 ms), SETTLE_CYCLES = 100 (10 us).
// Override parameters in simulation for fast testbenches.
module keypad_scanner #(
    parameter integer CLK_HZ          = 10000000,
    parameter integer DEBOUNCE_MS     = 15,
    parameter integer DEBOUNCE_CYCLES = (CLK_HZ / 1000) * DEBOUNCE_MS,
    parameter integer SETTLE_CYCLES   = 100
) (
    input            clk,
    input            rst,
    output reg [3:0] row,
    input      [7:0] col,
    output reg       key_valid,
    output reg [4:0] key_code
);
    // 2-FF synchronizers on asynchronous column inputs
    reg [7:0] col_sync1;
    reg [7:0] col_sync2;

    // Scanner & debounce FSM
    // 2'd0 = SETTLE (wait for row line & column pull-ups to settle)
    // 2'd1 = SCAN   (sample col_sync2; advance row if idle, else press-debounce)
    // 2'd2 = PRESS_DB
    // 2'd3 = WAIT_REL (wait for release + release-debounce)
    reg [1:0]  state;
    reg [1:0]  scan_row;
    reg [2:0]  latched_col;
    reg [19:0] cnt;

    wire       any_col_low;
    wire [2:0] col_idx;

    assign any_col_low = (col_sync2 != 8'hFF);
    assign col_idx = (!col_sync2[0]) ? 3'd0 :
                     (!col_sync2[1]) ? 3'd1 :
                     (!col_sync2[2]) ? 3'd2 :
                     (!col_sync2[3]) ? 3'd3 :
                     (!col_sync2[4]) ? 3'd4 :
                     (!col_sync2[5]) ? 3'd5 :
                     (!col_sync2[6]) ? 3'd6 : 3'd7;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            col_sync1   <= 8'hFF;
            col_sync2   <= 8'hFF;
            state       <= 2'd0;
            scan_row    <= 2'd0;
            row         <= 4'b1110;
            latched_col <= 3'd0;
            cnt         <= 20'd0;
            key_valid   <= 1'b0;
            key_code    <= 5'd0;
        end else begin
            col_sync1 <= col;
            col_sync2 <= col_sync1;
            key_valid <= 1'b0;

            case (state)
                2'd0: begin // SETTLE
                    if (cnt >= SETTLE_CYCLES[19:0]) begin
                        cnt   <= 20'd0;
                        state <= 2'd1;
                    end else begin
                        cnt <= cnt + 20'd1;
                    end
                end

                2'd1: begin // SCAN
                    if (any_col_low) begin
                        latched_col <= col_idx;
                        cnt         <= 20'd0;
                        state       <= 2'd2;
                    end else begin
                        scan_row <= scan_row + 2'd1;
                        case (scan_row + 2'd1)
                            2'd0: row <= 4'b1110;
                            2'd1: row <= 4'b1101;
                            2'd2: row <= 4'b1011;
                            2'd3: row <= 4'b0111;
                            default: row <= 4'b1110;
                        endcase
                        cnt   <= 20'd0;
                        state <= 2'd0;
                    end
                end

                2'd2: begin // PRESS_DB
                    if (any_col_low && (col_idx == latched_col)) begin
                        if (cnt >= DEBOUNCE_CYCLES[19:0]) begin
                            key_valid <= 1'b1;
                            key_code  <= {scan_row, latched_col};
                            cnt       <= 20'd0;
                            state     <= 2'd3;
                        end else begin
                            cnt <= cnt + 20'd1;
                        end
                    end else begin
                        // Bounce / glitch: restart scan
                        cnt   <= 20'd0;
                        state <= 2'd1;
                    end
                end

                2'd3: begin // WAIT_REL (release debounce)
                    if (!any_col_low) begin
                        if (cnt >= DEBOUNCE_CYCLES[19:0]) begin
                            cnt   <= 20'd0;
                            state <= 2'd1;
                        end else begin
                            cnt <= cnt + 20'd1;
                        end
                    end else begin
                        cnt <= 20'd0;
                    end
                end

                default: begin
                    state <= 2'd0;
                    cnt   <= 20'd0;
                end
            endcase
        end
    end
endmodule
