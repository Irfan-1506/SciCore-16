# SciCore-16 OpenROAD-flow-scripts (ORFS) SKY130HD Configuration
export DESIGN_NICKNAME = scicore16
export DESIGN_NAME     = scicore_top
export PLATFORM        = sky130hd

export VERILOG_FILES = \
    /work/rtl/arithmetic/alu16.v \
    /work/rtl/memory/register_bank.v \
    /work/rtl/arithmetic/multiplier.v \
    /work/rtl/arithmetic/divider.v \
    /work/rtl/arithmetic/cordic.v \
    /work/rtl/arithmetic/sqrt_unit.v \
    /work/rtl/arithmetic/log_exp.v \
    /work/rtl/memory/expression_stack.v \
    /work/rtl/top/scicore_top.v

export SDC_FILE = /work/physical_design/orfs/constraint.sdc

# Target 10 MHz (100 ns period), 40% core utilization
export CORE_UTILIZATION = 40
export PLACE_DENSITY    = 0.55
export TNS_END_PERCENT  = 100
