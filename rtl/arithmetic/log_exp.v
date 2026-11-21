// SciCore-16 v2.1: Fixed-Point Q8.8 Natural Log & Exponential Unit (Task 1.2)
// mode = 0: ln(x)  for x > 0 (domain_err if x <= 0)
// mode = 1: exp(x) for x in [-5.55, +4.85] (saturates 0x7FFF + overflow if x > 4.85)
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
    reg [4:0]  k_signed;

    // --- ln(1 + i/16) LUT in Q0.8 ---
    wire [3:0]  ln_idx;
    wire [3:0]  ln_frac;
    wire [7:0]  ln_lo;
    wire [7:0]  ln_hi;
    wire [7:0]  ln_diff;
    /* verilator lint_off UNUSEDSIGNAL */
    wire [11:0] ln_prod;
    /* verilator lint_on UNUSEDSIGNAL */
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

    wire        k_neg;
    wire [4:0]  k_abs;
    wire [15:0] k_ln2_mag;
    wire [15:0] k_ln2_signed;

    assign k_neg        = k_signed[4];
    assign k_abs        = k_neg ? (5'd0 - k_signed) : k_signed;
    assign k_ln2_mag    = (k_abs * 16'd177) + {12'd0, k_abs[4:1]};
    assign k_ln2_signed = k_neg ? (16'h0000 - k_ln2_mag) : k_ln2_mag;

    // --- High-precision EXP: u = x * log2(e) in Q8.12 ---
    // log2(e) * 4096 = 5909.28 -> 14'd5909 (0.0047% error)
    wire [15:0] x_abs;
    wire [29:0] u_prod;
    /* verilator lint_off UNUSEDSIGNAL */
    wire [29:0] u_prod_rnd;
    wire [19:0] u_q812;
    /* verilator lint_on UNUSEDSIGNAL */

    assign x_abs      = x[15] ? (16'h0000 - x) : x;
    assign u_prod     = x_abs * 14'd5909;
    assign u_prod_rnd = u_prod + 30'd128;
    assign u_q812     = x[15] ? (20'd0 - u_prod_rnd[27:8]) : u_prod_rnd[27:8];

    // 32-entry Q2.14 LUT for 2^(i/32) = round(16384 * 2^(i/32))
    wire [4:0]  exp_idx;
    wire [6:0]  exp_frac;
    reg  [15:0] exp_lo;
    reg  [15:0] exp_hi;
    wire [15:0] exp_diff;
    /* verilator lint_off UNUSEDSIGNAL */
    wire [22:0] exp_prod;
    /* verilator lint_on UNUSEDSIGNAL */
    wire [15:0] pow2_q214;

    assign exp_idx  = m[11:7];
    assign exp_frac = m[6:0];

    always @(*) begin
        case (exp_idx)
            5'd0:  begin exp_lo = 16'd16384; exp_hi = 16'd16743; end
            5'd1:  begin exp_lo = 16'd16743; exp_hi = 16'd17109; end
            5'd2:  begin exp_lo = 16'd17109; exp_hi = 16'd17484; end
            5'd3:  begin exp_lo = 16'd17484; exp_hi = 16'd17867; end
            5'd4:  begin exp_lo = 16'd17867; exp_hi = 16'd18258; end
            5'd5:  begin exp_lo = 16'd18258; exp_hi = 16'd18658; end
            5'd6:  begin exp_lo = 16'd18658; exp_hi = 16'd19066; end
            5'd7:  begin exp_lo = 16'd19066; exp_hi = 16'd19484; end
            5'd8:  begin exp_lo = 16'd19484; exp_hi = 16'd19911; end
            5'd9:  begin exp_lo = 16'd19911; exp_hi = 16'd20347; end
            5'd10: begin exp_lo = 16'd20347; exp_hi = 16'd20792; end
            5'd11: begin exp_lo = 16'd20792; exp_hi = 16'd21247; end
            5'd12: begin exp_lo = 16'd21247; exp_hi = 16'd21713; end
            5'd13: begin exp_lo = 16'd21713; exp_hi = 16'd22188; end
            5'd14: begin exp_lo = 16'd22188; exp_hi = 16'd22674; end
            5'd15: begin exp_lo = 16'd22674; exp_hi = 16'd23170; end
            5'd16: begin exp_lo = 16'd23170; exp_hi = 16'd23678; end
            5'd17: begin exp_lo = 16'd23678; exp_hi = 16'd24196; end
            5'd18: begin exp_lo = 16'd24196; exp_hi = 16'd24726; end
            5'd19: begin exp_lo = 16'd24726; exp_hi = 16'd25268; end
            5'd20: begin exp_lo = 16'd25268; exp_hi = 16'd25821; end
            5'd21: begin exp_lo = 16'd25821; exp_hi = 16'd26386; end
            5'd22: begin exp_lo = 16'd26386; exp_hi = 16'd26964; end
            5'd23: begin exp_lo = 16'd26964; exp_hi = 16'd27554; end
            5'd24: begin exp_lo = 16'd27554; exp_hi = 16'd28158; end
            5'd25: begin exp_lo = 16'd28158; exp_hi = 16'd28774; end
            5'd26: begin exp_lo = 16'd28774; exp_hi = 16'd29405; end
            5'd27: begin exp_lo = 16'd29405; exp_hi = 16'd30048; end
            5'd28: begin exp_lo = 16'd30048; exp_hi = 16'd30706; end
            5'd29: begin exp_lo = 16'd30706; exp_hi = 16'd31379; end
            5'd30: begin exp_lo = 16'd31379; exp_hi = 16'd32066; end
            default: begin exp_lo = 16'd32066; exp_hi = 16'd32768; end
        endcase
    end

    assign exp_diff  = exp_hi - exp_lo;
    assign exp_prod  = (exp_diff * exp_frac) + 23'd64;
    assign pow2_q214 = exp_lo + exp_prod[22:7];

    // Shift Q2.14 pow2_q214 by k_signed and round-to-nearest into Q8.8
    reg [16:0] exp_q88_raw;
    always @(*) begin
        case (k_signed)
            5'd6:  exp_q88_raw = {1'b0, pow2_q214};
            5'd5:  exp_q88_raw = ({1'b0, pow2_q214} + 17'd1)     >> 1;
            5'd4:  exp_q88_raw = ({1'b0, pow2_q214} + 17'd2)     >> 2;
            5'd3:  exp_q88_raw = ({1'b0, pow2_q214} + 17'd4)     >> 3;
            5'd2:  exp_q88_raw = ({1'b0, pow2_q214} + 17'd8)     >> 4;
            5'd1:  exp_q88_raw = ({1'b0, pow2_q214} + 17'd16)    >> 5;
            5'd0:  exp_q88_raw = ({1'b0, pow2_q214} + 17'd32)    >> 6;
            5'h1F: exp_q88_raw = ({1'b0, pow2_q214} + 17'd64)    >> 7;
            5'h1E: exp_q88_raw = ({1'b0, pow2_q214} + 17'd128)   >> 8;
            5'h1D: exp_q88_raw = ({1'b0, pow2_q214} + 17'd256)   >> 9;
            5'h1C: exp_q88_raw = ({1'b0, pow2_q214} + 17'd512)   >> 10;
            5'h1B: exp_q88_raw = ({1'b0, pow2_q214} + 17'd1024)  >> 11;
            5'h1A: exp_q88_raw = ({1'b0, pow2_q214} + 17'd2048)  >> 12;
            5'h19: exp_q88_raw = ({1'b0, pow2_q214} + 17'd4096)  >> 13;
            5'h18: exp_q88_raw = ({1'b0, pow2_q214} + 17'd8192)  >> 14;
            5'h17: exp_q88_raw = ({1'b0, pow2_q214} + 17'd16384) >> 15;
            default: exp_q88_raw = 17'd0;
        endcase
    end

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
                    if ((x == 16'h0000) || (x[15] == 1'b1)) begin
                        result     <= 16'h0000;
                        domain_err <= 1'b1;
                        busy       <= 1'b0;
                        done       <= 1'b1;
                    end else begin
                        m        <= x;
                        k_signed <= 5'd0;
                        state    <= 2'd1;
                        busy     <= 1'b1;
                    end
                end else begin
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
                        m        <= {4'd0, u_q812[11:0]};
                        k_signed <= u_q812[16:12];
                        state    <= 2'd2;
                        busy     <= 1'b1;
                    end
                end
            end else if (busy) begin
                if (state == 2'd1) begin
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
                        if (exp_q88_raw > 17'h07FFF) begin
                            result   <= 16'h7FFF;
                            overflow <= 1'b1;
                        end else begin
                            result <= exp_q88_raw[15:0];
                        end
                    end
                    busy  <= 1'b0;
                    done  <= 1'b1;
                    state <= 2'd0;
                end else begin
                    busy  <= 1'b0;
                    state <= 2'd0;
                end
            end
        end
    end
endmodule
