#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="${TMPDIR:-/tmp}/scicore16_sim"
mkdir -p "$TMP_DIR"

echo "=== 1. tb_m1 (ALU16) ==="
iverilog -g2001 -Wall -o "$TMP_DIR/tb_m1.vvp" rtl/arithmetic/alu16.v verification/tb_m1.v
vvp "$TMP_DIR/tb_m1.vvp"

echo "=== 2. tb_regbank (Register Bank) ==="
iverilog -g2001 -Wall -o "$TMP_DIR/tb_regbank.vvp" rtl/memory/register_bank.v verification/tb_regbank.v
vvp "$TMP_DIR/tb_regbank.vvp"

echo "=== 3. tb_m2 (Multiplier + Divider) ==="
iverilog -g2001 -Wall -o "$TMP_DIR/tb_m2.vvp" rtl/arithmetic/multiplier.v rtl/arithmetic/divider.v verification/tb_m2.v
vvp "$TMP_DIR/tb_m2.vvp"

echo "=== 4. tb_m3 (CORDIC + SQRT + LOG_EXP) ==="
iverilog -g2001 -Wall -o "$TMP_DIR/tb_m3.vvp" rtl/arithmetic/cordic.v rtl/arithmetic/sqrt_unit.v rtl/arithmetic/log_exp.v verification/tb_m3.v
vvp "$TMP_DIR/tb_m3.vvp"

echo "=== 5. tb_m4 (SQRT + LOG_EXP + Expression Stack) ==="
iverilog -g2001 -Wall -o "$TMP_DIR/tb_m4.vvp" rtl/arithmetic/sqrt_unit.v rtl/arithmetic/log_exp.v rtl/memory/expression_stack.v verification/tb_m4.v
vvp "$TMP_DIR/tb_m4.vvp"

echo "=== 6. tb_top (SciCore-16 Core Top) ==="
iverilog -g2001 -Wall -o "$TMP_DIR/tb_top.vvp" \
  rtl/arithmetic/alu16.v rtl/arithmetic/multiplier.v rtl/arithmetic/divider.v \
  rtl/arithmetic/cordic.v rtl/arithmetic/sqrt_unit.v rtl/arithmetic/log_exp.v \
  rtl/memory/register_bank.v rtl/memory/expression_stack.v \
  rtl/top/scicore_top.v verification/tb_top.v
vvp "$TMP_DIR/tb_top.vvp"

echo "=== 7. tb_asic_top (SciCore-16 ASIC Wrapper Top) ==="
iverilog -g2001 -Wall -o "$TMP_DIR/tb_asic_top.vvp" \
  rtl/arithmetic/alu16.v rtl/arithmetic/multiplier.v rtl/arithmetic/divider.v \
  rtl/arithmetic/cordic.v rtl/arithmetic/sqrt_unit.v rtl/arithmetic/log_exp.v \
  rtl/memory/register_bank.v rtl/memory/expression_stack.v \
  rtl/input/keypad_scanner.v rtl/input/keymap_decode.v \
  rtl/output/spi_result_shifter.v rtl/output/uart_debug.v \
  rtl/top/scicore_top.v rtl/top/scicore_asic_top.v verification/tb_asic_top.v
vvp "$TMP_DIR/tb_asic_top.vvp"

echo "=== ALL 7 TESTBENCHES PASSED ==="
