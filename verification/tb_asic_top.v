// SciCore-16 v2.1 Self-Checking Full-ASIC Testbench: scicore_asic_top (Tasks 2.1-2.6, 3.3)
// Tests physical matrix key presses with simulated contact bounce:
//   1) 1 2 . 5 ENT 3 *  -> 37.5 (0x2580)
//   2) CLR 2 SQRT       -> 1.414 (0x016A)
//   3) CLR 0 . 5 SIN    -> 0.480 (0x007B)
//   4) CLR 5 ENT STO 2 CLR RCL 2 -> 5.0 (0x0500)
module tb_asic_top;
    reg        clk, reset_n;
    wire [3:0] row;
    reg  [7:0] col;
    wire       disp_clk, disp_mosi, disp_cs, disp_dc, disp_rst, disp_bl;
    wire       uart_tx, busy, error;
    reg        uart_rx;
    integer    fails;

    // Key currently held down (active_key_row, active_key_col)
    reg        key_down;
    reg [1:0]  held_row;
    reg [2:0]  held_col;

    // Fast debounce/settle parameters for simulation
    scicore_asic_top #(
        .CLK_HZ(10000000),
        .DEBOUNCE_CYCLES(4),
        .SETTLE_CYCLES(2),
        .UART_CLKS_BIT(4)
    ) dut (
        .clk(clk), .reset_n(reset_n),
        .row(row), .col(col),
        .disp_clk(disp_clk), .disp_mosi(disp_mosi), .disp_cs(disp_cs),
        .disp_dc(disp_dc), .disp_rst(disp_rst), .disp_bl(disp_bl),
        .uart_tx(uart_tx), .uart_rx(uart_rx),
        .busy(busy), .error(error)
    );

    // Physical 4x8 switch matrix model: pull col[held_col] low when row[held_row] is driven low
    always @(*) begin
        col = 8'hFF;
        if (key_down && (row[held_row] == 1'b0)) begin
            col[held_col] = 1'b0;
        end
    end

    task step_clks;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                #5; clk = 1; #5; clk = 0;
            end
        end
    endtask

    // Press physical key (r, c) with simulated 2-cycle contact bounce before steady hold
    task press_key;
        input [1:0] r;
        input [2:0] c;
        begin
            held_row = r; held_col = c;
            // Contact bounce glitch (too short to pass DEBOUNCE_CYCLES=4)
            key_down = 1; step_clks(2);
            key_down = 0; step_clks(2);
            // Steady press long enough for full row scan + 2-FF sync + press debounce
            key_down = 1; step_clks(40);
            // Release + release debounce
            key_down = 0; step_clks(20);
            // Wait for any multi-cycle op to finish
            step_clks(45);
        end
    endtask

    initial begin
        fails = 0;
        clk = 0; reset_n = 0; uart_rx = 1; key_down = 0; held_row = 0; held_col = 0;
        step_clks(4);
        reset_n = 1;
        step_clks(6);

        // Test 1: 1 2 . 5 ENT 3 *  (K21=0,5; K22=1,5; K26=1,6; K18=1,4; K27=2,6; K23=2,5; K20=3,4)
        press_key(2'd0, 3'd5); // '1'
        press_key(2'd1, 3'd5); // '2'
        press_key(2'd1, 3'd6); // '.'
        press_key(2'd1, 3'd4); // '5'
        press_key(2'd2, 3'd6); // ENT -> pushes 12.5 (0x0C80)
        press_key(2'd2, 3'd5); // '3'
        press_key(2'd3, 3'd4); // '*' -> auto-pushes 3.0, multiplies -> 37.5 (0x2580)
        if (dut.u_core.result !== 16'h2580 || error !== 1'b0) begin
            $display("ASIC FAIL Test1 (12.5*3): got=%h err=%b exp=2580", dut.u_core.result, error);
            fails = fails + 1;
        end

        // Test 2: CLR 2 SQRT (K11=2,2; K22=1,5; K4=3,0) -> 0x016A
        press_key(2'd2, 3'd2); // CLR
        press_key(2'd1, 3'd5); // '2'
        press_key(2'd3, 3'd0); // SQRT
        if (dut.u_core.result !== 16'h016A || error !== 1'b0) begin
            $display("ASIC FAIL Test2 (sqrt 2): got=%h err=%b exp=016A", dut.u_core.result, error);
            fails = fails + 1;
        end

        // Test 3: CLR 0 . 5 SIN (K11=2,2; K25=0,6; K26=1,6; K18=1,4; K1=0,0) -> 0x007B
        press_key(2'd2, 3'd2); // CLR
        press_key(2'd0, 3'd6); // '0'
        press_key(2'd1, 3'd6); // '.'
        press_key(2'd1, 3'd4); // '5'
        press_key(2'd0, 3'd0); // SIN
        if (dut.u_core.result !== 16'h007B || error !== 1'b0) begin
            $display("ASIC FAIL Test3 (sin 0.5): got=%h err=%b exp=007B", dut.u_core.result, error);
            fails = fails + 1;
        end

        // Test 4: CLR 5 ENT STO 2 CLR RCL 2 (K9=0,2 STO; K10=1,2 RCL; K22=1,5 '2') -> 5.0 (0x0500)
        press_key(2'd2, 3'd2); // CLR
        press_key(2'd1, 3'd4); // '5'
        press_key(2'd2, 3'd6); // ENT
        press_key(2'd0, 3'd2); // STO
        press_key(2'd1, 3'd5); // '2' -> M2
        press_key(2'd2, 3'd2); // CLR
        press_key(2'd1, 3'd2); // RCL
        press_key(2'd1, 3'd5); // '2' -> M2
        if (dut.u_core.result !== 16'h0500 || error !== 1'b0) begin
            $display("ASIC FAIL Test4 (STO/RCL M2): got=%h err=%b exp=0500", dut.u_core.result, error);
            fails = fails + 1;
        end

        if (fails != 0) begin
            $display("tb_asic_top: FAIL (%0d errors)", fails);
            $fatal(1, "tb_asic_top failed");
        end
        $display("tb_asic_top: PASS (12.5*3=37.5, sqrt(2)=1.414, sin(0.5)=0.480, STO/RCL M2 + debounce)");
        $finish;
    end
endmodule
