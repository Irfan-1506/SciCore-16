// SciCore-16 M4: 12-cycle Restoring Square Root Unit (Q8.8)
// Computes sqrt(x) in Q8.8 via 24-bit integer sqrt(x << 8).
// Asserts domain_err if x < 0.
module sqrt_unit (
    input         clk,
    input         rst,
    input         start,
    input  [15:0] x,
    output reg [15:0] result,
    output reg    domain_err,
    output reg    busy,
    output reg    done
);
    reg [23:0] rad;
    /* verilator lint_off UNUSEDSIGNAL */
    reg [13:0] rem;
    /* verilator lint_on UNUSEDSIGNAL */
    reg [11:0] root;
    reg [3:0]  cnt;

    wire [13:0] next_rem;
    wire [13:0] trial_sub;
    wire        can_sub;

    assign next_rem  = {rem[11:0], rad[23:22]};
    assign trial_sub = {root, 2'b01};
    assign can_sub   = (next_rem >= trial_sub);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            result     <= 16'h0000;
            domain_err <= 1'b0;
            busy       <= 1'b0;
            done       <= 1'b0;
            rad        <= 24'd0;
            rem        <= 14'd0;
            root       <= 12'd0;
            cnt        <= 4'd0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                if (x[15] == 1'b1) begin
                    result     <= 16'h0000;
                    domain_err <= 1'b1;
                    busy       <= 1'b0;
                    done       <= 1'b1;
                end else begin
                    rad        <= {x, 8'h00};
                    rem        <= 14'd0;
                    root       <= 12'd0;
                    cnt        <= 4'd12;
                    domain_err <= 1'b0;
                    busy       <= 1'b1;
                end
            end else if (busy) begin
                if (cnt != 4'd0) begin
                    if (can_sub) begin
                        rem  <= next_rem - trial_sub;
                        root <= {root[10:0], 1'b1};
                    end else begin
                        rem  <= next_rem;
                        root <= {root[10:0], 1'b0};
                    end
                    rad <= {rad[21:0], 2'b00};
                    cnt <= cnt - 4'd1;
                end else begin
                    result <= {4'b0000, root};
                    busy   <= 1'b0;
                    done   <= 1'b1;
                end
            end
        end
    end
endmodule
