// SciCore-16 M3 Testbench: CORDIC sin/cos (Q8.8 radians)
module tb_m3;
    reg         clk;
    reg         rst;
    reg         start;
    reg  [15:0] theta;
    wire [15:0] sin_out;
    wire [15:0] cos_out;
    wire        busy;
    wire        done;
    integer     i;

    cordic dut_cordic (
        .clk(clk), .rst(rst), .start(start),
        .theta(theta),
        .sin_out(sin_out), .cos_out(cos_out),
        .busy(busy), .done(done)
    );

    initial begin
        clk = 0; rst = 1; start = 0; theta = 16'h0000;
        #5; clk = 1; #5; clk = 0;
        rst = 0;

        // Test 1: theta = 0 rad (0x0000) -> sin=0.0 (0x0000), cos=1.0 (0x0100)
        theta = 16'h0000; start = 1;
        #5; clk = 1; #5; clk = 0;
        start = 0;
        for (i = 0; i < 14; i = i + 1) begin #5; clk = 1; #5; clk = 0; end
        $display("CORDIC  0:     sin=%h cos=%h", sin_out, cos_out);

        // Test 2: theta = pi/6 (~0.5236 -> 0x0086) -> sin=0.5 (0x0080), cos=0.866 (0x00DE)
        theta = 16'h0086; start = 1;
        #5; clk = 1; #5; clk = 0;
        start = 0;
        for (i = 0; i < 14; i = i + 1) begin #5; clk = 1; #5; clk = 0; end
        $display("CORDIC  pi/6:  sin=%h cos=%h", sin_out, cos_out);

        // Test 3: theta = pi/4 (~0.7854 -> 0x00C9) -> sin=0.707 (0x00B5), cos=0.707 (0x00B5)
        theta = 16'h00C9; start = 1;
        #5; clk = 1; #5; clk = 0;
        start = 0;
        for (i = 0; i < 14; i = i + 1) begin #5; clk = 1; #5; clk = 0; end
        $display("CORDIC  pi/4:  sin=%h cos=%h", sin_out, cos_out);

        // Test 4: theta = pi/2 (~1.5708 -> 0x0192) -> sin=1.0 (0x0100), cos=0.0 (0x0000)
        theta = 16'h0192; start = 1;
        #5; clk = 1; #5; clk = 0;
        start = 0;
        for (i = 0; i < 14; i = i + 1) begin #5; clk = 1; #5; clk = 0; end
        $display("CORDIC  pi/2:  sin=%h cos=%h", sin_out, cos_out);

        // Test 5: theta = -pi/4 (-201 -> 0xFF37) -> sin=-0.707 (0xFF4B), cos=+0.707 (0x00B5)
        theta = 16'hFF37; start = 1;
        #5; clk = 1; #5; clk = 0;
        start = 0;
        for (i = 0; i < 14; i = i + 1) begin #5; clk = 1; #5; clk = 0; end
        $display("CORDIC -pi/4:  sin=%h cos=%h", sin_out, cos_out);

        $finish;
    end
endmodule
