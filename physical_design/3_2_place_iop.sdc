###############################################################################
# Created by write_sdc
###############################################################################
current_design scicore_top
###############################################################################
# Timing Constraints
###############################################################################
create_clock -name clk -period 100.0000 [get_ports {clk}]
set_input_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {cmd_imm[0]}]
set_input_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {cmd_imm[10]}]
set_input_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {cmd_imm[11]}]
set_input_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {cmd_imm[12]}]
set_input_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {cmd_imm[13]}]
set_input_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {cmd_imm[14]}]
set_input_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {cmd_imm[15]}]
set_input_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {cmd_imm[1]}]
set_input_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {cmd_imm[2]}]
set_input_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {cmd_imm[3]}]
set_input_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {cmd_imm[4]}]
set_input_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {cmd_imm[5]}]
set_input_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {cmd_imm[6]}]
set_input_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {cmd_imm[7]}]
set_input_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {cmd_imm[8]}]
set_input_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {cmd_imm[9]}]
set_input_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {cmd_op[0]}]
set_input_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {cmd_op[1]}]
set_input_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {cmd_op[2]}]
set_input_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {cmd_op[3]}]
set_input_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {cmd_valid}]
set_input_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {rst}]
set_output_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {busy}]
set_output_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {done}]
set_output_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {err_flags[0]}]
set_output_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {err_flags[1]}]
set_output_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {err_flags[2]}]
set_output_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {result[0]}]
set_output_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {result[10]}]
set_output_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {result[11]}]
set_output_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {result[12]}]
set_output_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {result[13]}]
set_output_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {result[14]}]
set_output_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {result[15]}]
set_output_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {result[1]}]
set_output_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {result[2]}]
set_output_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {result[3]}]
set_output_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {result[4]}]
set_output_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {result[5]}]
set_output_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {result[6]}]
set_output_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {result[7]}]
set_output_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {result[8]}]
set_output_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {result[9]}]
set_output_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {stack_depth[0]}]
set_output_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {stack_depth[1]}]
set_output_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {stack_depth[2]}]
set_output_delay 20.0000 -clock [get_clocks {clk}] -add_delay [get_ports {stack_depth[3]}]
###############################################################################
# Environment
###############################################################################
###############################################################################
# Design Rules
###############################################################################
