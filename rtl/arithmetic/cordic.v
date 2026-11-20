// SciCore-16 M3: Circular Rotation-Mode CORDIC Engine (12-iteration)
// Input:  theta in Q8.8 signed radians, range [-pi/2, +pi/2] ([-1.57, +1.57])
// Output: sin_out, cos_out in Q8.8 signed fixed-point (internal Q2.14 precision)
module cordic (
    input         clk,
    input         rst,
    input         start,
    input  [15:0] theta,
    output reg [15:0] sin_out,
    output reg [15:0] cos_out,
    output reg    busy,
    output reg    done
);
    reg [15:0] x;
    reg [15:0] y;
    reg [15:0] z;
    reg [3:0]  iter;

    // Q2.14 arctan(2^-i) lookup table (round(atan(2^-i) * 16384))
    wire [15:0] atan_val;
    assign atan_val = (iter == 4'd0)  ? 16'h3244 :
                      (iter == 4'd1)  ? 16'h1DAC :
                      (iter == 4'd2)  ? 16'h0FAE :
                      (iter == 4'd3)  ? 16'h07F5 :
                      (iter == 4'd4)  ? 16'h03FF :
                      (iter == 4'd5)  ? 16'h0200 :
                      (iter == 4'd6)  ? 16'h0100 :
                      (iter == 4'd7)  ? 16'h0080 :
                      (iter == 4'd8)  ? 16'h0040 :
                      (iter == 4'd9)  ? 16'h0020 :
                      (iter == 4'd10) ? 16'h0010 : 16'h0008;

    // Explicit signed arithmetic right shifts x >>> iter and y >>> iter
    wire [15:0] x_shift;
    wire [15:0] y_shift;

    assign x_shift = (iter == 4'd0)  ? x :
                     (iter == 4'd1)  ? {x[15], x[15:1]} :
                     (iter == 4'd2)  ? {{2{x[15]}}, x[15:2]} :
                     (iter == 4'd3)  ? {{3{x[15]}}, x[15:3]} :
                     (iter == 4'd4)  ? {{4{x[15]}}, x[15:4]} :
                     (iter == 4'd5)  ? {{5{x[15]}}, x[15:5]} :
                     (iter == 4'd6)  ? {{6{x[15]}}, x[15:6]} :
                     (iter == 4'd7)  ? {{7{x[15]}}, x[15:7]} :
                     (iter == 4'd8)  ? {{8{x[15]}}, x[15:8]} :
                     (iter == 4'd9)  ? {{9{x[15]}}, x[15:9]} :
                     (iter == 4'd10) ? {{10{x[15]}}, x[15:10]} :
                                       {{11{x[15]}}, x[15:11]};

    assign y_shift = (iter == 4'd0)  ? y :
                     (iter == 4'd1)  ? {y[15], y[15:1]} :
                     (iter == 4'd2)  ? {{2{y[15]}}, y[15:2]} :
                     (iter == 4'd3)  ? {{3{y[15]}}, y[15:3]} :
                     (iter == 4'd4)  ? {{4{y[15]}}, y[15:4]} :
                     (iter == 4'd5)  ? {{5{y[15]}}, y[15:5]} :
                     (iter == 4'd6)  ? {{6{y[15]}}, y[15:6]} :
                     (iter == 4'd7)  ? {{7{y[15]}}, y[15:7]} :
                     (iter == 4'd8)  ? {{8{y[15]}}, y[15:8]} :
                     (iter == 4'd9)  ? {{9{y[15]}}, y[15:9]} :
                     (iter == 4'd10) ? {{10{y[15]}}, y[15:10]} :
                                       {{11{y[15]}}, y[15:11]};

    // Convert Q2.14 back to Q8.8 with rounding (+32 then >>> 6)
    wire [15:0] x_round;
    wire [15:0] y_round;
    assign x_round = x + 16'h0020;
    assign y_round = y + 16'h0020;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sin_out <= 16'h0000;
            cos_out <= 16'h0000;
            busy    <= 1'b0;
            done    <= 1'b0;
            x       <= 16'h0000;
            y       <= 16'h0000;
            z       <= 16'h0000;
            iter    <= 4'd0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                // K = 0.607253 in Q2.14 = 9949 = 16'h26DD
                x    <= 16'h26DD;
                y    <= 16'h0000;
                z    <= {theta[9:0], 6'b000000};
                iter <= 4'd0;
                busy <= 1'b1;
            end else if (busy) begin
                if (iter < 4'd12) begin
                    if (z[15] == 1'b0) begin
                        // z >= 0: rotate CCW
                        x <= x - y_shift;
                        y <= y + x_shift;
                        z <= z - atan_val;
                    end else begin
                        // z < 0: rotate CW
                        x <= x + y_shift;
                        y <= y - x_shift;
                        z <= z + atan_val;
                    end
                    iter <= iter + 4'd1;
                end else begin
                    cos_out <= {{6{x_round[15]}}, x_round[15:6]};
                    sin_out <= {{6{y_round[15]}}, y_round[15:6]};
                    busy    <= 1'b0;
                    done    <= 1'b1;
                end
            end
        end
    end
endmodule
