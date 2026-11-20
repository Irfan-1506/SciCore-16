# SciCore-16 Engineering Report

## 1. Executive Summary
**SciCore-16** is a 16-bit Q8.8 fixed-point scientific calculator System-on-Chip designed in synthesizable Verilog-2001, verified functionally in **SiliconForge**, taken through a full **SkyWater SKY130HD 130 nm RTL-to-GDSII** physical design flow in **OpenROAD**, and integrated onto a **100 × 75 mm 2-layer KiCad PCB** with electrical power-network validation.

---

## 2. RTL Architecture & Synthesis Breakdown

| Module | File | Function | Yosys Cells | Yosys Wires |
| :--- | :--- | :--- | :---: | :---: |
| `alu16` | `rtl/arithmetic/alu16.v` | Combinational ADD/SUB/NEG/Logic/Shift | 474 | 464 |
| `register_bank` | `rtl/memory/register_bank.v` | 4×16-bit 2R1W user memory (`STO`/`RCL`) | 172 | 89 |
| `multiplier` | `rtl/arithmetic/multiplier.v` | 16-cycle shift-add Q8.8 multiplier | 594 | 425 |
| `divider` | `rtl/arithmetic/divider.v` | 24-cycle restoring Q8.8 divider | 443 | 308 |
| `cordic` | `rtl/arithmetic/cordic.v` | 12-iteration Q2.14 circular CORDIC (`sin`/`cos`) | 1,088 | 962 |
| `sqrt_unit` | `rtl/arithmetic/sqrt_unit.v` | 12-cycle restoring Q8.8 square root | 203 | 118 |
| `log_exp` | `rtl/arithmetic/log_exp.v` | Range-reduction + 16-entry LUT `ln`/`exp` | 1,161 | 1,108 |
| `expression_stack` | `rtl/memory/expression_stack.v` | 8×16-bit RPN operand stack | 672 | 523 |
| `scicore_top` | `rtl/top/scicore_top.v` | Unified command FSM & datapath integration | 456 | 445 |
| **Total Hierarchy** | | **Complete SciCore-16 SoC** | **5,263** | **4,442** |

---

## 3. Verification Summary

| Testbench | Scope | End Time | Errors | Key Verified Cases |
| :--- | :--- | :---: | :---: | :--- |
| `tb_m1.v` | `alu16` | 100 ns | 0 | ADD, SUB, +OVF, ZERO, SHL, ASR, NEG, AND/OR/XOR |
| `tb_regbank.v` | `register_bank` | 80 ns | 0 | Async reset, 4-reg write, `we` gating, dual-port read |
| `tb_m2.v` | `multiplier`, `divider` | 1410 ns | 0 | Signed Q8.8 mul/div, rounding, overflow, 1-cycle `div_zero` |
| `tb_m3.v` | `cordic` | 760 ns | 0 | `0`, `π/6`, `π/4`, `π/2`, `-π/4` — **0 LSB error** |
| `tb_m4.v` | `sqrt_unit`, `log_exp` | 1110 ns | 0 | `sqrt(0,2,4,-1)`, `ln(0,0.5,1,2,e)`, `exp(-1,0,1,5)` |
| `tb_top.v` | `scicore_top` | 1490 ns | 0 | `((3+5)*2)/4`, `sqrt(4)`, `sin(π/6)+cos(0)`, `ln(exp(1))`, `STO/RCL` |

---

## 4. Physical Design Results

### 4.1 Block-Level SCMOS P&R (SiliconForge)
- **`alu16.mag`:** Compacted `1465 × 135 λ` (`197,775 λ²`, **-72.59% area**, **-49.74% wirelength**), **0 DRC**, **LVS Matched**
- **`multiplier.mag`:** Compacted `3231 × 240 λ` (`775,440 λ²`, **-82.64% area**, **-39.13% wirelength**), **0 DRC**, **LVS Matched**
- **`register_bank.mag`:** `1660 × 321 λ` (`532,860 λ²`), **0 DRC**
- **`divider.mag`:** `5714 × 1098 λ` (`6,273,972 λ²`), **0 DRC**

### 4.2 Full-Chip SKY130HD RTL-to-GDSII (OpenROAD Flow Scripts)
- **PDK / Corner:** `sky130_fd_sc_hd__tt_025C_1v80` (`1.80 V`, `25 °C`), `10 MHz` (`100 ns`)
- **Area & Utilization:** `53,041 µm²` active logic area (`44%` utilization), `120,448 µm²` (`0.120 mm²`) total core
- **Cell Count:** `19,028` placed instances (`601` sequential, `4,538` multi-input comb, `203` inverters, `176` timing repair buffers, `98` clock buffers, `40` clock inverters, `1,612` tap cells, `11,760` filler cells)
- **Routing:** `167,357 µm` total wirelength (`met1`: `75,876 µm`, `met2`: `75,440 µm`, `met3`: `9,715 µm`, `met4`: `6,324 µm`), `43,328` vias
- **Signoff Checks:**
  - Detailed Route DRC: **0 violations**
  - Antenna Check: **0 net violations, 0 pin violations**
  - Logical Equivalence (LEC): **Passed**
  - GDSII Merge (`6_final.gds`, `7.65 MB`): **All LEF cells matched, 0 orphan cells**
- **Power & PDN IR Drop:**
  - Total power: **`0.710 mW`** at `1.80 V`
  - Worst-case VDD IR drop: **`13.4 µV`** (`0.00%`); worst-case VSS bounce: **`13.6 µV`** (`0.00%`)

---

## 5. PCB Design & Electrical Simulation (KiCad 10 + SPICE)
- **Board Geometry:** `100 × 75 mm`, 2-layer FR-4 (`F.Cu` + continuous `B.Cu` GND plane)
- **Net & Trace Count:** 30 nets, 129 copper segments (`0.50–0.60 mm` power, `0.20–0.25 mm` signal), 16 vias (including 13 GND stitching vias)
- **DRC Verification:** **0 DRC errors**, **0 unconnected items**, **0 clearance/courtyard violations**
- **Power Network Transient Simulation (`pcb/simulation/power_network.cir`):**
  - 5 V USB input steady: `4.9963 V`
  - 3.3 V I/O LDO steady: `3.2962 V`
  - 1.8 V SKY130 Core LDO steady (`5 mA` idle): `1.7994 V`
  - 1.8 V Core dynamic load step (`5 mA → 25 mA`): minimum `1.7970 V` (**`2.40 mV` / `0.13%` droop**)
  - RC Power-On Reset (`10 kΩ / 100 nF`): `RESET_N` crosses `1.65 V` at **`0.728 ms`**

---

## 6. Known Limitations & Future Improvements
1. **Q8.8 Dynamic Range:** Fixed-point Q8.8 (`±128`) overflows for `exp(x > 4.85)` or large products. Upgrading the datapath to **Q16.16** or **32-bit floating-point** is the natural v2 step.
2. **Pad Ring & I/O Peripherals:** `6_final.gds` is a core-level SKY130HD macro (no ESD pad ring or Caravel wrapper), and keypad/LCD scanning is currently offloaded to the command interface (`cmd_valid/cmd_op/cmd_imm`).
3. **PCB Fabrication Readiness:** The QFN-64 ASIC footprint (`U1`) uses a logical pin assignment for board-level layout and power-network simulation; physical tapeout would require matching the final packaged die bond-out and ESD pad ring.
4. **Exhaustive Verification:** Directed unit and top-level tests passed 100%; adding a 10,000-vector randomized Verilator + Python golden-model regression suite is recommended before any real silicon tapeout.
