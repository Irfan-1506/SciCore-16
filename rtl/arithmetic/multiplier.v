// SciCore-16 v2.1: Signed Q8.8 Iterative Shift-Add Multiplier (16-cycle, Saturating)
// Rounding policy: symmetric round-to-nearest (half-up on magnitude before sign restore)
// Overflow policy (Task 1.3): saturates to 0x7FFF (+127.996) or 0x8000 (-128.0) and sets overflow=1.
module multiplier (
    input         clk,
    input         rst,
    input         start,
    input  [15:0] a,
    input  [15:0] b,
    output reg [15:0] result,
    output reg    overflow,
    output reg    busy,
    output reg    done
);
    reg        res_sign;
    reg [31:0] mcand;
    reg [15:0] mplier;
    reg [31:0] acc;
    reg [4:0]  cnt;

    wire [15:0] mag_a;
    wire [15:0] mag_b;
    /* verilator lint_off UNUSEDSIGNAL */
    wire [31:0] acc_rounded;
    /* verilator lint_on UNUSEDSIGNAL */
    wire [23:0] scaled_mag;
    wire        ovf_pos;
    wire        ovf_neg;
    wire        ovf_any;

    assign mag_a       = a[15] ? (16'h0000 - a) : a;
    assign mag_b       = b[15] ? (16'h0000 - b) : b;
    assign acc_rounded = acc + 32'h00000080;
    assign scaled_mag  = acc_rounded[31:8];
    assign ovf_pos     = (!res_sign) && (scaled_mag > 24'h007FFF);
    assign ovf_neg     = (res_sign)  && (scaled_mag > 24'h008000);
    assign ovf_any     = ovf_pos || ovf_neg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            result   <= 16'h0000;
            overflow <= 1'b0;
            busy     <= 1'b0;
            done     <= 1'b0;
            res_sign <= 1'b0;
            mcand    <= 32'h00000000;
            mplier   <= 16'h0000;
            acc      <= 32'h00000000;
            cnt      <= 5'd0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                res_sign <= a[15] ^ b[15];
                mcand    <= {16'h0000, mag_a};
                mplier   <= mag_b;
                acc      <= 32'h00000000;
                cnt      <= 5'd16;
                busy     <= 1'b1;
                overflow <= 1'b0;
            end else if (busy) begin
                if (cnt != 5'd0) begin
                    if (mplier[0]) begin
                        acc <= acc + mcand;
                    end
                    mcand  <= {mcand[30:0], 1'b0};
                    mplier <= {1'b0, mplier[15:1]};
                    cnt    <= cnt - 5'd1;
                end else begin
                    if (ovf_any) begin
                        result <= res_sign ? 16'h8000 : 16'h7FFF;
                    end else begin
                        result <= res_sign ? (16'h0000 - scaled_mag[15:0]) : scaled_mag[15:0];
                    end
                    overflow <= ovf_any;
                    busy     <= 1'b0;
                    done     <= 1'b1;
                end
            end
        end
    end
endmodule
