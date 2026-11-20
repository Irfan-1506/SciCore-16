// SciCore-16 v2.0: SPI Display Controller (128x64 Graphical LCD Interface)
// Shifts 16-bit Q8.8 result MSB-first over SPI Mode 0 when update_valid pulses.
module display_controller (
    input         clk,
    input         rst,
    input         update_valid,
    input  [15:0] data_in,
    output reg    disp_clk,
    output reg    disp_mosi,
    output reg    disp_cs,
    output reg    disp_dc,
    output        disp_rst,
    output        disp_bl,
    output reg    busy
);
    reg [15:0] shift_reg;
    reg [4:0]  bit_cnt;
    reg        phase;

    assign disp_rst = ~rst;
    assign disp_bl  = 1'b1;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            disp_clk  <= 1'b0;
            disp_mosi <= 1'b0;
            disp_cs   <= 1'b1;
            disp_dc   <= 1'b1;
            busy      <= 1'b0;
            shift_reg <= 16'h0000;
            bit_cnt   <= 5'd0;
            phase     <= 1'b0;
        end else begin
            if (!busy) begin
                disp_clk <= 1'b0;
                disp_cs  <= 1'b1;
                if (update_valid) begin
                    shift_reg <= data_in;
                    disp_mosi <= data_in[15];
                    disp_cs   <= 1'b0;
                    disp_dc   <= 1'b1;
                    bit_cnt   <= 5'd16;
                    phase     <= 1'b0;
                    busy      <= 1'b1;
                end
            end else begin
                if (!phase) begin
                    disp_clk <= 1'b1;
                    phase    <= 1'b1;
                end else begin
                    disp_clk <= 1'b0;
                    phase    <= 1'b0;
                    if (bit_cnt == 5'd1) begin
                        disp_cs <= 1'b1;
                        busy    <= 1'b0;
                    end else begin
                        shift_reg <= {shift_reg[14:0], 1'b0};
                        disp_mosi <= shift_reg[14];
                        bit_cnt   <= bit_cnt - 5'd1;
                    end
                end
            end
        end
    end
endmodule
