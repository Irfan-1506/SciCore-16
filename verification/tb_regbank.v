// SciCore-16 v2.1 Self-Checking Testbench: register_bank
module tb_regbank;
    reg         clk, rst, we;
    reg  [1:0]  waddr, raddr_a, raddr_b;
    reg  [15:0] wdata;
    wire [15:0] rdata_a, rdata_b;
    integer     fails;

    register_bank dut_rb (
        .clk(clk), .rst(rst), .we(we), .waddr(waddr), .wdata(wdata),
        .raddr_a(raddr_a), .raddr_b(raddr_b), .rdata_a(rdata_a), .rdata_b(rdata_b)
    );

    initial begin
        fails = 0;
        clk = 0; rst = 1; we = 0;
        waddr = 2'b00; wdata = 16'h0000; raddr_a = 2'b00; raddr_b = 2'b01;
        #10;
        if (rdata_a !== 16'h0000 || rdata_b !== 16'h0000) fails = fails + 1;

        rst = 0; we = 1;
        waddr = 2'b00; wdata = 16'h0100; #5; clk = 1; #5; clk = 0;
        waddr = 2'b01; wdata = 16'h0280; #5; clk = 1; #5; clk = 0;
        waddr = 2'b10; wdata = 16'hFF00; #5; clk = 1; #5; clk = 0;
        waddr = 2'b11; wdata = 16'h0380; #5; clk = 1; #5; clk = 0;

        we = 0; wdata = 16'hBEEF;
        raddr_a = 2'b00; raddr_b = 2'b01; #5; clk = 1; #5; clk = 0;
        if (rdata_a !== 16'h0100 || rdata_b !== 16'h0280) fails = fails + 1;

        raddr_a = 2'b10; raddr_b = 2'b11; #10;
        if (rdata_a !== 16'hFF00 || rdata_b !== 16'h0380) fails = fails + 1;

        rst = 1; #10;
        if (rdata_a !== 16'h0000 || rdata_b !== 16'h0000) fails = fails + 1;

        if (fails != 0) begin
            $display("tb_regbank: FAIL (%0d errors)", fails);
            $fatal(1, "tb_regbank failed");
        end
        $display("tb_regbank: PASS (4/4 checks)");
        $finish;
    end
endmodule
