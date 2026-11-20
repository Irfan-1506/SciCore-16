# SciCore-16 (v2.0) Engineering Report

## 1. Executive Summary
**SciCore-16** is a 16-bit Q8.8 fixed-point scientific calculator System-on-Chip designed in synthesizable Verilog-2001, verified functionally in **SiliconForge** and against an exhaustive **Python golden reference model**, taken through a **SkyWater SKY130HD 130 nm RTL-to-GDSII** physical design flow in **OpenROAD**, and integrated onto a **100 × 75 mm 2-layer KiCad PCB** with a complete schematic, DRC-clean routing, and behavioral power-network simulation.

---

## 2. v2.0 Audit Fixes Implemented
| Audit ID | Issue | Resolution in v2.0 |
| :--- | :--- | :--- |
| **SC-01** | `done` asserted 1 cycle before `expression_stack` commit | Added `COMPLETE` FSM state (`state == 2'd3`) in `scicore_top.v`; `tb_top.v` verifies `result` on exact cycle `done == 1`. |
| **SC-02** | Missing stack overflow/underflow guards & flags | Expanded `err_flags[4:0] = {stk_ovf, stk_udf, div_zero, domain_err, arith_ovf}`; invalid ops rejected before launching units. |
| **SC-03** | Empty KiCad schematic (`scicore16_pcb.kicad_sch`) | Populated all 20 component symbols, assigned footprints, and attached 85 net labels matching the routed PCB 1-to-1. |
| **SC-04** | PCB ↔ RTL interface mismatch | Built synthesizable `keypad_scanner.v`, `display_controller.v`, and `scicore_asic_top.v` + `integration/pin_mapping.csv`. |
| **SC-06/07/12** | Limited numerical sweep & missing golden model | Added `verification/golden_model.py` (exhaustive CORDIC/SQRT/LN/EXP + 10k randomized MUL/DIV) & `numerical_accuracy_report.md`. |
| **SC-08/09/10/11** | Hardcoded ORFS paths, minimal SDC, missing CI | Made `config.mk` portable (`SCICORE_ROOT`), added clock uncertainty/transition/load to `constraint.sdc`, added `scripts/run_synthesis.sh` & GitHub Actions CI. |

---

## 3. RTL Synthesis Breakdown (Yosys, v2.0 `scicore_asic_top`)
- **Full-Chip SoC (`scicore_asic_top` incl. Keypad Scanner + SPI Display Controller + UART + `scicore_top`):** **5,454 cells**, **4,593 wires**, **0 errors, 0 inferred latches**.
- Core module breakdown: `log_exp` (1,155), `cordic` (1,093), `expression_stack` (672), `multiplier` (598), `alu16` (470), `divider` (442), `sqrt_unit` (203), `register_bank` (172), plus `scicore_top`, `keypad_scanner`, `display_controller`, and `scicore_asic_top`.

---

## 4. Verification & Numerical Accuracy
- **6 Directed & Top-Level Testbenches** (`tb_m1.v`, `tb_regbank.v`, `tb_m2.v`, `tb_m3.v`, `tb_m4.v`, `tb_top.v`) — all passed with **0 simulation errors** in SiliconForge (`*.vcd` waveforms archived in `verification/`).
- **Exhaustive Python Golden Model (`verification/golden_model.py`, seed `20261120`):**
  - `multiplier`: max `0.50 LSB` (round-to-nearest half-up on magnitude)
  - `divider`: max `1.00 LSB` (truncation; `-128.0 / -1.0` overflow verified)
  - `cordic`: max `0.61 LSB` (`sin`), `0.63 LSB` (`cos`) across all 805 Q8.8 angles in `[-π/2, +π/2]`
  - `sqrt_unit`: max `1.00 LSB` across all 32,768 non-negative Q8.8 inputs
  - `log_exp`: `ln(x)` max `1.66 LSB` across all 32,767 positive inputs; `exp(x)` max `1.56` (~1.2% relative error near `exp(4.85) ≈ 127.7` due to shift-add `log2(e)` approximation)

---

## 5. Physical Design & Power Methodology
- **Block-Level SCMOS P&R (SiliconForge):** `alu16.mag` (`197,775 λ²`, -72.59%, 0 DRC, LVS matched), `multiplier.mag` (`775,440 λ²`, -82.64%, 0 DRC, LVS matched), `register_bank.mag` (0 DRC), `divider.mag` (0 DRC).
- **Full-Chip Core Macro (SKY130HD, OpenROAD Flow Scripts, `sky130_fd_sc_hd__tt_025C_1v80`, `10 MHz`):**
  - `53,041 µm²` active logic area (`44%` utilization; `120,448 µm²` total core), `19,028` placed instances
  - `167,357 µm` wirelength (`met1–met4`), `43,328` vias, **0 DRC**, **0 antenna**, **LEC passed**, `6_final.gds` (`7.65 MB`)
  - **Power Methodology Disclosure:** `0.710 mW` total power and `13.4 µV` worst-case VDD IR drop were computed via OpenROAD's vectorless default-activity PDNSim flow at `1.80 V` (`tt_025C_1v80`), not VCD-annotated post-layout SPICE.

---

## 6. PCB Design & Behavioral Power Simulation
- **KiCad 10 PCB (`100 × 75 mm`, 2-layer):** 20 components + 4× M3 mounting holes, populated schematic (`scicore16_pcb.kicad_sch`, 85 net labels), 30 routed nets, 129 copper segments, 16 vias, continuous `B.Cu` GND plane, **0 DRC errors**, **0 unconnected items**.
- **Power Simulation Disclosure (`pcb/simulation/power_network.cir`):** Uses simplified behavioral LDO models (output impedance + dropout voltage) rather than manufacturer transistor-level SPICE subcircuits. Steady-state rails: `4.9963 V` (5 V USB), `3.2962 V` (3.3 V I/O), `1.7994 V` (1.8 V core idle) → `1.7970 V` under `25 mA` burst (`2.40 mV` / `0.13%` droop); `RESET_N` releases at `0.728 ms`.

---

## 7. Remaining Scope Boundaries (Pre-Tapeout)
- `6_final.gds` is a **core-level SKY130HD macro** (`scicore_top`) without an ESD I/O pad ring or foundry bond-out; re-running ORFS with `DESIGN_NAME = scicore_asic_top` and a Caravel/Tiny Tapeout padframe is the next step for physical silicon fabrication.
- The QFN-64 PCB package pinout (`integration/pin_mapping.csv`) is a logical board-level interface specification until matched to a real packaged die bond-out.
