#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "=== Verilator Lint: scicore_top ==="
verilator --lint-only -Wall --top-module scicore_top \
  rtl/arithmetic/alu16.v rtl/arithmetic/multiplier.v rtl/arithmetic/divider.v \
  rtl/arithmetic/cordic.v rtl/arithmetic/sqrt_unit.v rtl/arithmetic/log_exp.v \
  rtl/memory/register_bank.v rtl/memory/expression_stack.v \
  rtl/top/scicore_top.v

echo "=== Verilator Lint: scicore_asic_top ==="
verilator --lint-only -Wall --top-module scicore_asic_top \
  rtl/arithmetic/alu16.v rtl/arithmetic/multiplier.v rtl/arithmetic/divider.v \
  rtl/arithmetic/cordic.v rtl/arithmetic/sqrt_unit.v rtl/arithmetic/log_exp.v \
  rtl/memory/register_bank.v rtl/memory/expression_stack.v \
  rtl/input/keypad_scanner.v rtl/input/keymap_decode.v \
  rtl/output/spi_result_shifter.v rtl/output/uart_debug.v \
  rtl/top/scicore_top.v rtl/top/scicore_asic_top.v

echo "=== Yosys Latch & Synthesis Check: scicore_top ==="
yosys -q -p "
  read_verilog rtl/arithmetic/alu16.v rtl/arithmetic/multiplier.v rtl/arithmetic/divider.v \
               rtl/arithmetic/cordic.v rtl/arithmetic/sqrt_unit.v rtl/arithmetic/log_exp.v \
               rtl/memory/register_bank.v rtl/memory/expression_stack.v rtl/top/scicore_top.v;
  hierarchy -check -top scicore_top;
  proc;
  opt;
  check -assert;
  stat
" | tee /tmp/yosys_core_stat.txt
if grep -qE '\$dlatch|\$_DLATCH' /tmp/yosys_core_stat.txt; then
  echo "ERROR: Latch detected in scicore_top!"
  exit 1
fi

echo "=== Yosys Latch & Synthesis Check: scicore_asic_top ==="
yosys -q -p "
  read_verilog rtl/arithmetic/alu16.v rtl/arithmetic/multiplier.v rtl/arithmetic/divider.v \
               rtl/arithmetic/cordic.v rtl/arithmetic/sqrt_unit.v rtl/arithmetic/log_exp.v \
               rtl/memory/register_bank.v rtl/memory/expression_stack.v \
               rtl/input/keypad_scanner.v rtl/input/keymap_decode.v \
               rtl/output/spi_result_shifter.v rtl/output/uart_debug.v \
               rtl/top/scicore_top.v rtl/top/scicore_asic_top.v;
  hierarchy -check -top scicore_asic_top;
  proc;
  opt;
  check -assert;
  stat
" | tee /tmp/yosys_asic_stat.txt
if grep -qE '\$dlatch|\$_DLATCH' /tmp/yosys_asic_stat.txt; then
  echo "ERROR: Latch detected in scicore_asic_top!"
  exit 1
fi

echo "=== LINT & YOSYS LATCH CHECK PASSED ==="
