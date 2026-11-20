// SciCore-16 M1: 4x16-bit Register Bank (2 Read, 1 Write)
module register_bank (
    input         clk,
    input         rst,
    input         we,
    input  [1:0]  waddr,
    input  [15:0] wdata,
    input  [1:0]  raddr_a,
    input  [1:0]  raddr_b,
    output [15:0] rdata_a,
    output [15:0] rdata_b
);
    reg [15:0] r0;
    reg [15:0] r1;
    reg [15:0] r2;
    reg [15:0] r3;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            r0 <= 16'h0000;
            r1 <= 16'h0000;
            r2 <= 16'h0000;
            r3 <= 16'h0000;
        end else if (we) begin
            case (waddr)
                2'b00: r0 <= wdata;
                2'b01: r1 <= wdata;
                2'b10: r2 <= wdata;
                2'b11: r3 <= wdata;
            endcase
        end
    end

    assign rdata_a = (raddr_a == 2'b00) ? r0 :
                     (raddr_a == 2'b01) ? r1 :
                     (raddr_a == 2'b10) ? r2 : r3;

    assign rdata_b = (raddr_b == 2'b00) ? r0 :
                     (raddr_b == 2'b01) ? r1 :
                     (raddr_b == 2'b10) ? r2 : r3;
endmodule
