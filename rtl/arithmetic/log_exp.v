// SciCore-16 M4: Fixed-Point Q8.8 Natural Log & Exponential Unit
// mode = 0: ln(x)  for x > 0 (domain_err if x <= 0)
// mode = 1: exp(x) for x in [-5.54, +4.85] (overflow if x > 4.85)
// Uses binary range reduction + 16-entry LUT with 4-bit linear interpolation.
module log_exp (
    input         clk,
    input         rst,
    input         start,
    input         mode,
    input  [15:0] x,
    output reg [15:0] result,
    output reg    domain_err,
    output reg    overflow,
    output reg    busy,
    output reg    done
);
    reg        op_mode;
    reg [1:0]  state;
    reg [15:0] m;
    reg [4:0]  k_signed; // 5-bit signed exponent (-16..+15)

    // --- ln(1 + i/16) LUT in Q0.8 (round(256 * ln(1 + i/16))) ---
    wire [3:0] ln_idx;
    wire [3:0] ln_frac;
    wire [7:0] ln_lo;
    wire [7:0] ln_hi;
    wire [7:0] ln_diff;
    wire [11:0] ln_prod;
    wire [15:0] ln_frac_part;

    assign ln_idx  = m[7:4];
    assign ln_frac = m[3:0];

    assign ln_lo = (ln_idx == 4'd0)  ? 8'd0   :
                   (ln_idx == 4'd1)  ? 8'd16  :
                   (ln_idx == 4'd2)  ? 8'd30  :
                   (ln_idx == 4'd3)  ? 8'd44  :
                   (ln_idx == 4'd4)  ? 8'd57  :
                   (ln_idx == 4'd5)  ? 8'd70  :
                   (ln_idx == 4'd6)  ? 8'd82  :
                   (ln_idx == 4'd7)  ? 8'd93  :
                   (ln_idx == 4'd8)  ? 8'd104 :
                   (ln_idx == 4'd9)  ? 8'd114 :
                   (ln_idx == 4'd10) ? 8'd124 :
                   (ln_idx == 4'd11) ? 8'd134 :
                   (ln_idx == 4'd12) ? 8'd143 :
                   (ln_idx == 4'd13) ? 8'd152 :
                   (ln_idx == 4'd14) ? 8'd161 : 8'd169;

    assign ln_hi = (ln_idx == 4'd0)  ? 8'd16  :
                   (ln_idx == 4'd1)  ? 8'd30  :
                   (ln_idx == 4'd2)  ? 8'd44  :
                   (ln_idx == 4'd3)  ? 8'd57  :
                   (ln_idx == 4'd4)  ? 8'd70  :
                   (ln_idx == 4'd5)  ? 8'd82  :
                   (ln_idx == 4'd6)  ? 8'd93  :
                   (ln_idx == 4'd7)  ? 8'd104 :
                   (ln_idx == 4'd8)  ? 8'd114 :
                   (ln_idx == 4'd9)  ? 8'd124 :
                   (ln_idx == 4'd10) ? 8'd134 :
                   (ln_idx == 4'd11) ? 8'd143 :
                   (ln_idx == 4'd12) ? 8'd152 :
                   (ln_idx == 4'd13) ? 8'd161 :
                   (ln_idx == 4'd14) ? 8'd169 : 8'd177;

    assign ln_diff      = ln_hi - ln_lo;
    assign ln_prod      = (ln_diff * ln_frac) + 12'd8;
    assign ln_frac_part = {8'd0, ln_lo} + {12'd0, ln_prod[7:4]};

    // k * ln(2) in Q8.8 (ln(2) = 177.45/256; use k * 177 with +/- round)
    wire        k_neg;
    wire [4:0]  k_abs;
    wire [15:0] k_ln2_mag;
    wire [15:0] k_ln2_signed;

    assign k_neg        = k_signed[4];
    assign k_abs        = k_neg ? (5'd0 - k_signed) : k_signed;
    // 177.45 * k_abs ~= (k_abs * 177) + (k_abs >> 1)
    assign k_ln2_mag    = (k_abs * 16'd177) + {12'd0, k_abs[4:1]};
    assign k_ln2_signed = k_neg ? (16'h0000 - k_ln2_mag) : k_ln2_mag;

    // --- exp(x) = 2^(x * log2(e)) ---
    // Approximate x * log2(e) where log2(e) = 1.442695 ~= 1 + 1/4 + 1/8 + 1/16 + 1/256
    wire [15:0] x_s2;
    wire [15:0] x_s3;
    wire [15:0] x_s4;
    wire [15:0] x_s8;
    wire [15:0] u_val;

    assign x_s2  = {{2{x[15]}}, x[15:2]};
    assign x_s3  = {{3{x[15]}}, x[15:3]};
    assign x_s4  = {{4{x[15]}}, x[15:4]};
    assign x_s8  = {{8{x[15]}}, x[15:8]};
    assign u_val = x + x_s2 + x_s3 + x_s4 + x_s8;

    // 2^(i/16) LUT in Q8.8 (round(256 * 2^(i/16)))
    wire [3:0]  exp_idx;
    wire [3:0]  exp_frac;
    wire [9:0]  exp_lo;
    wire [9:0]  exp_hi;
    wire [9:0]  exp_diff;
    wire [13:0] exp_prod;
    wire [15:0] pow2_frac;

    assign exp_idx  = m[7:4];
    assign exp_frac = m[3:0];

    assign exp_lo = (exp_idx == 4'd0)  ? 10'd256 :
                    (exp_idx == 4'd1)  ? 10'd267 :
                    (exp_idx == 4'd2)  ? 10'd279 :
                    (exp_idx == 4'd3)  ? 10'd292 :
                    (exp_idx == 4'd4)  ? 10'd304 :
                    (exp_idx == 4'd5)  ? 10'd318 :
                    (exp_idx == 4'd6)  ? 10'd332 :
                    (exp_idx == 4'd7)  ? 10'd347 :
                    (exp_idx == 4'd8)  ? 10'd362 :
                    (exp_idx == 4'd9)  ? 10'd378 :
                    (exp_idx == 4'd10) ? 10'd395 :
                    (exp_idx == 4'd11) ? 10'd412 :
                    (exp_idx == 4'd12) ? 10'd431 :
                    (exp_idx == 4'd13) ? 10'd450 :
                    (exp_idx == 4'd14) ? 10'd470 : 10'd490;

    assign exp_hi = (exp_idx == 4'd0)  ? 10'd267 :
                    (exp_idx == 4'd1)  ? 10'd279 :
                    (exp_idx == 4'd2)  ? 10'd292 :
                    (exp_idx == 4'd3)  ? 10'd304 :
                    (exp_idx == 4'd4)  ? 10'd318 :
                    (exp_idx == 4'd5)  ? 10'd332 :
                    (exp_idx == 4'd6)  ? 10'd347 :
                    (exp_idx == 4'd7)  ? 10'd362 :
                    (exp_idx == 4'd8)  ? 10'd378 :
                    (exp_idx == 4'd9)  ? 10'd395 :
                    (exp_idx == 4'd10) ? 10'd412 :
                    (exp_idx == 4'd11) ? 10'd431 :
                    (exp_idx == 4'd12) ? 10'd450 :
                    (exp_idx == 4'd13) ? 10'd470 :
                    (exp_idx == 4'd14) ? 10'd490 : 10'd512;

    assign exp_diff  = exp_hi - exp_lo;
    assign exp_prod  = (exp_diff * exp_frac) + 14'd8;
    assign pow2_frac = {6'd0, exp_lo} + {6'd0, exp_prod[13:4]};

    // Shift pow2_frac by signed integer k_signed (-8..+6)
    wire [15:0] exp_shifted;
    assign exp_shifted = (k_signed == 5'd0)  ? pow2_frac :
                         (k_signed == 5'd1)  ? {pow2_frac[14:0], 1'b0} :
                         (k_signed == 5'd2)  ? {pow2_frac[13:0], 2'b00} :
                         (k_signed == 5'd3)  ? {pow2_frac[12:0], 3'b000} :
                         (k_signed == 5'd4)  ? {pow2_frac[11:0], 4'b0000} :
                         (k_signed == 5'd5)  ? {pow2_frac[10:0], 5'b00000} :
                         (k_signed == 5'd6)  ? {pow2_frac[9:0],  6'b000000} :
                         (k_signed == 5'h1F) ? {1'b0, pow2_frac[15:1]} :
                         (k_signed == 5'h1E) ? {2'b00, pow2_frac[15:2]} :
                         (k_signed == 5'h1D) ? {3'b000, pow2_frac[15:3]} :
                         (k_signed == 5'h1C) ? {4'b0000, pow2_frac[15:4]} :
                         (k_signed == 5'h1B) ? {5'b00000, pow2_frac[15:5]} :
                         (k_signed == 5'h1A) ? {6'b000000, pow2_frac[15:6]} :
                         (k_signed == 5'h19) ? {7'b0000000, pow2_frac[15:7]} :
                         (k_signed == 5'h18) ? {8'b00000000, pow2_frac[15:8]} :
                                               16'h0000;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            result     <= 16'h0000;
            domain_err <= 1'b0;
            overflow   <= 1'b0;
            busy       <= 1'b0;
            done       <= 1'b0;
            op_mode    <= 1'b0;
            state      <= 2'd0;
            m          <= 16'h0000;
            k_signed   <= 5'd0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                domain_err <= 1'b0;
                overflow   <= 1'b0;
                op_mode    <= mode;
                if (mode == 1'b0) begin
                    // LN(x): require x > 0
                    if ((x == 16'h0000) || (x[15] == 1'b1)) begin
                        result     <= 16'h0000;
                        domain_err <= 1'b1;
                        busy       <= 1'b0;
                        done       <= 1'b1;
                    end else begin
                        m        <= x;
                        k_signed <= 5'd0;
                        state    <= 2'd1; // Normalize loop
                        busy     <= 1'b1;
                    end
                end else begin
                    // EXP(x): check overflow (x > 4.85 -> 0x04DA) and underflow (x < -5.55 -> 0xFA74)
                    if ((x[15] == 1'b0) && (x > 16'h04DA)) begin
                        result   <= 16'h7FFF;
                        overflow <= 1'b1;
                        busy     <= 1'b0;
                        done     <= 1'b1;
                    end else if ((x[15] == 1'b1) && (x < 16'hFA74)) begin
                        result <= 16'h0000;
                        busy   <= 1'b0;
                        done   <= 1'b1;
                    end else begin
                        m        <= {8'h00, u_val[7:0]};
                        k_signed <= u_val[12:8];
                        state    <= 2'd2; // Eval exp
                        busy     <= 1'b1;
                    end
                end
            end else if (busy) begin
                if (state == 2'd1) begin
                    // Normalize m into [0x0100, 0x01FF]
                    if (m >= 16'h0200) begin
                        m        <= {1'b0, m[15:1]};
                        k_signed <= k_signed + 5'd1;
                    end else if (m < 16'h0100) begin
                        m        <= {m[14:0], 1'b0};
                        k_signed <= k_signed - 5'd1;
                    end else begin
                        state <= 2'd2;
                    end
                end else if (state == 2'd2) begin
                    if (op_mode == 1'b0) begin
                        result <= k_ln2_signed + ln_frac_part;
                    end else begin
                        result <= exp_shifted;
                    end
                    busy  <= 1'b0;
                    done  <= 1'b1;
                    state <= 2'd0;
                end
            end
        end
    end
endmodule
