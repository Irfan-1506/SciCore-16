# SciCore-16 Timing Constraints (10 MHz / 100 ns period)
current_design scicore_top

set clk_name  clk
set clk_port  [get_ports clk]
set clk_period 100.0
set clk_io_pct 0.2

create_clock -name $clk_name -period $clk_period $clk_port

set non_clock_inputs [lsearch -inline -all -not -exact [all_inputs] $clk_port]

set_input_delay  [expr $clk_period * $clk_io_pct] -clock $clk_name $non_clock_inputs
set_output_delay [expr $clk_period * $clk_io_pct] -clock $clk_name [all_outputs]
