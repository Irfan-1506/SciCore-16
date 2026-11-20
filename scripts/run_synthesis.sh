#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "=== Running Yosys Synthesis Check on scicore_asic_top (Full SoC + I/O Wrapper) ==="
yosys -p "
  read_verilog rtl/arithmetic/alu16.v rtl/memory/register_bank.v \
               rtl/arithmetic/multiplier.v rtl/arithmetic/divider.v \
               rtl/arithmetic/cordic.v rtl/arithmetic/sqrt_unit.v \
               rtl/arithmetic/log_exp.v rtl/memory/expression_stack.v \
               rtl/top/scicore_top.v rtl/input/keypad_scanner.v \
               rtl/output/display_controller.v rtl/top/scicore_asic_top.v;
  hierarchy -check -top scicore_asic_top;
  synth -top scicore_asic_top;
  stat
"
