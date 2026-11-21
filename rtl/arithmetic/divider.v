// SciCore-16 v2.1: Signed Q8.8 Restoring Divider (24-cycle, Saturating)
// Computes Q8.8 result = (a << 8) / b with divide-by-zero and saturating overflow.
module divider (
    input         clk,
    input         rst,
    input         start,
    input  [15:0] a,
    input  [15:0] b,
    output reg [15:0] result,
    output reg    div_zero,
    output reg    overflow,
    output reg    busy,
    output reg    done
);
    reg        res_sign;
    /* verilator lint_off UNUSEDSIGNAL */
    reg [16:0] rem;
    /* verilator lint_on UNUSEDSIGNAL */
    reg [23:0] quot;
    reg [15:0] divisor;
    reg [4:0]  cnt;

    wire [15:0] mag_a;
    wire [15:0] mag_b;
    wire [16:0] trial_rem;
    wire        can_sub;
    wire        ovf_pos;
    wire        ovf_neg;
    wire        ovf_any;

    assign mag_a     = a[15] ? (16'h0000 - a) : a;
    assign mag_b     = b[15] ? (16'h0000 - b) : b;
    assign trial_rem = {rem[15:0], quot[23]};
    assign can_sub   = (trial_rem >= {1'b0, divisor});
    assign ovf_pos   = (!res_sign) && (quot > 24'h007FFF);
    assign ovf_neg   = (res_sign)  && (quot > 24'h008000);
    assign ovf_any   = ovf_pos || ovf_neg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            result   <= 16'h0000;
            div_zero <= 1'b0;
            overflow <= 1'b0;
            busy     <= 1'b0;
            done     <= 1'b0;
            res_sign <= 1'b0;
            rem      <= 17'd0;
            quot     <= 24'd0;
            divisor  <= 16'd0;
            cnt      <= 5'd0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                if (b == 16'h0000) begin
                    result   <= 16'h0000;
                    div_zero <= 1'b1;
                    overflow <= 1'b0;
                    busy     <= 1'b0;
                    done     <= 1'b1;
                end else begin
                    res_sign <= a[15] ^ b[15];
                    rem      <= 17'd0;
                    quot     <= {mag_a, 8'h00};
                    divisor  <= mag_b;
                    cnt      <= 5'd24;
                    div_zero <= 1'b0;
                    overflow <= 1'b0;
                    busy     <= 1'b1;
                end
            end else if (busy) begin
                if (cnt != 5'd0) begin
                    if (can_sub) begin
                        rem  <= trial_rem - {1'b0, divisor};
                        quot <= {quot[22:0], 1'b1};
                    end else begin
                        rem  <= trial_rem;
                        quot <= {quot[22:0], 1'b0};
                    end
                    cnt <= cnt - 5'd1;
                end else begin
                    if (ovf_any) begin
                        result <= res_sign ? 16'h8000 : 16'h7FFF;
                    end else begin
                        result <= res_sign ? (16'h0000 - quot[15:0]) : quot[15:0];
                    end
                    overflow <= ovf_any;
                    busy     <= 1'b0;
                    done     <= 1'b1;
                end
            end
        end
    end
endmodule
