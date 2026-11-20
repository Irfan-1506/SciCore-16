# SciCore-16 v2.0 OpenROAD-flow-scripts (ORFS) SKY130HD Configuration (Portable)
SCICORE_ROOT ?= /work

export DESIGN_NICKNAME = scicore16
export DESIGN_NAME     = scicore_top
export PLATFORM        = sky130hd

export VERILOG_FILES = \
    $(SCICORE_ROOT)/rtl/arithmetic/alu16.v \
    $(SCICORE_ROOT)/rtl/memory/register_bank.v \
    $(SCICORE_ROOT)/rtl/arithmetic/multiplier.v \
    $(SCICORE_ROOT)/rtl/arithmetic/divider.v \
    $(SCICORE_ROOT)/rtl/arithmetic/cordic.v \
    $(SCICORE_ROOT)/rtl/arithmetic/sqrt_unit.v \
    $(SCICORE_ROOT)/rtl/arithmetic/log_exp.v \
    $(SCICORE_ROOT)/rtl/memory/expression_stack.v \
    $(SCICORE_ROOT)/rtl/top/scicore_top.v

export SDC_FILE = $(SCICORE_ROOT)/physical_design/orfs/constraint.sdc

# Target 10 MHz (100 ns period), 40% core utilization
export CORE_UTILIZATION = 40
export PLACE_DENSITY    = 0.55
export TNS_END_PERCENT  = 100
