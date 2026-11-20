// SciCore-16 M1 Testbench: 4x16-bit Register Bank
module tb_regbank;
    reg         clk;
    reg         rst;
    reg         we;
    reg  [1:0]  waddr;
    reg  [15:0] wdata;
    reg  [1:0]  raddr_a;
    reg  [1:0]  raddr_b;
    wire [15:0] rdata_a;
    wire [15:0] rdata_b;

    register_bank dut_rb (
        .clk(clk),
        .rst(rst),
        .we(we),
        .waddr(waddr),
        .wdata(wdata),
        .raddr_a(raddr_a),
        .raddr_b(raddr_b),
        .rdata_a(rdata_a),
        .rdata_b(rdata_b)
    );

    initial begin
        clk = 0; rst = 1; we = 0;
        waddr = 2'b00; wdata = 16'h0000;
        raddr_a = 2'b00; raddr_b = 2'b01;
        #10;
        $display("RST:     ra=%h rb=%h", rdata_a, rdata_b);

        // Release reset, write r0 = 0x0100 (1.0)
        rst = 0; we = 1; waddr = 2'b00; wdata = 16'h0100;
        #5; clk = 1; #5; clk = 0;

        // Write r1 = 0x0280 (2.5)
        waddr = 2'b01; wdata = 16'h0280;
        #5; clk = 1; #5; clk = 0;

        // Write r2 = 0xFF00 (-1.0)
        waddr = 2'b10; wdata = 16'hFF00;
        #5; clk = 1; #5; clk = 0;

        // Write r3 = 0x0380 (3.5)
        waddr = 2'b11; wdata = 16'h0380;
        #5; clk = 1; #5; clk = 0;

        // Disable write, verify dual-port reads
        we = 0; wdata = 16'hBEEF;
        raddr_a = 2'b00; raddr_b = 2'b01;
        #5; clk = 1; #5; clk = 0;
        $display("RD r0,r1: ra=%h rb=%h", rdata_a, rdata_b);

        raddr_a = 2'b10; raddr_b = 2'b11;
        #10;
        $display("RD r2,r3: ra=%h rb=%h", rdata_a, rdata_b);

        // Re-assert reset
        rst = 1; #10;
        $display("RST2:    ra=%h rb=%h", rdata_a, rdata_b);

        $finish;
    end
endmodule
