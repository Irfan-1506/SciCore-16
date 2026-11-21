// SciCore-16 v2.1: Circular Rotation-Mode CORDIC Engine (12-iteration, [-pi, +pi])
// Task 1.1: Quadrant folding for |theta| in (pi/2, pi], domain_err for |theta| > pi.
// Input:  theta in Q8.8 signed radians, valid range [-pi, +pi] ([-804, +804] = [0xFCDC, 0x0324])
// Output: sin_out, cos_out in Q8.8 signed fixed-point (internal Q2.14 precision, symmetric rounding)
module cordic (
    input         clk,
    input         rst,
    input         start,
    input  [15:0] theta,
    output reg [15:0] sin_out,
    output reg [15:0] cos_out,
    output reg    domain_err,
    output reg    busy,
    output reg    done
);
    reg [15:0] x;
    reg [15:0] y;
    reg [15:0] z;
    reg [3:0]  iter;
    reg        cos_negate;

    // Range checks in Q8.8:
    //   +pi   = +804 = 16'h0324,  -pi   = -804 = 16'hFCDC
    //   +pi/2 = +402 = 16'h0192,  -pi/2 = -402 = 16'hFE6E
    wire theta_neg;
    wire out_of_range;
    wire fold_pos;
    wire fold_neg;
    /* verilator lint_off UNUSEDSIGNAL */
    wire [15:0] theta_folded;
    /* verilator lint_on UNUSEDSIGNAL */

    assign theta_neg    = theta[15];
    assign out_of_range = ((!theta_neg) && (theta > 16'h0324)) ||
                          (theta_neg    && (theta < 16'hFCDC));
    assign fold_pos     = (!theta_neg) && (theta > 16'h0192);
    assign fold_neg     = theta_neg    && (theta < 16'hFE6E);
    assign theta_folded = fold_pos ? (16'h0324 - theta) :
                          fold_neg ? (16'hFCDC - theta) : theta;

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

    // Symmetric round-to-nearest from Q2.14 to Q8.8 (magnitude round, then sign restore)
    wire [15:0] x_mag;
    wire [15:0] y_mag;
    /* verilator lint_off UNUSEDSIGNAL */
    wire [15:0] x_mag_rnd;
    wire [15:0] y_mag_rnd;
    /* verilator lint_on UNUSEDSIGNAL */
    wire [15:0] cos_raw;
    wire [15:0] sin_raw;

    assign x_mag     = x[15] ? (16'h0000 - x) : x;
    assign y_mag     = y[15] ? (16'h0000 - y) : y;
    assign x_mag_rnd = x_mag + 16'h0020;
    assign y_mag_rnd = y_mag + 16'h0020;
    assign cos_raw   = x[15] ? (16'h0000 - {6'b000000, x_mag_rnd[15:6]}) : {6'b000000, x_mag_rnd[15:6]};
    assign sin_raw   = y[15] ? (16'h0000 - {6'b000000, y_mag_rnd[15:6]}) : {6'b000000, y_mag_rnd[15:6]};

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sin_out    <= 16'h0000;
            cos_out    <= 16'h0000;
            domain_err <= 1'b0;
            busy       <= 1'b0;
            done       <= 1'b0;
            x          <= 16'h0000;
            y          <= 16'h0000;
            z          <= 16'h0000;
            iter       <= 4'd0;
            cos_negate <= 1'b0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                if (out_of_range) begin
                    sin_out    <= 16'h0000;
                    cos_out    <= 16'h0000;
                    domain_err <= 1'b1;
                    busy       <= 1'b0;
                    done       <= 1'b1;
                end else begin
                    // K = 0.607253 in Q2.14 = 9949 = 16'h26DD
                    x          <= 16'h26DD;
                    y          <= 16'h0000;
                    z          <= {theta_folded[9:0], 6'b000000};
                    cos_negate <= fold_pos || fold_neg;
                    domain_err <= 1'b0;
                    iter       <= 4'd0;
                    busy       <= 1'b1;
                end
            end else if (busy) begin
                if (iter < 4'd12) begin
                    if (z[15] == 1'b0) begin
                        x <= x - y_shift;
                        y <= y + x_shift;
                        z <= z - atan_val;
                    end else begin
                        x <= x + y_shift;
                        y <= y - x_shift;
                        z <= z + atan_val;
                    end
                    iter <= iter + 4'd1;
                end else begin
                    cos_out <= cos_negate ? (16'h0000 - cos_raw) : cos_raw;
                    sin_out <= sin_raw;
                    busy    <= 1'b0;
                    done    <= 1'b1;
                end
            end
        end
    end
endmodule
