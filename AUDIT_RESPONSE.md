# SciCore-16 Independent Audit v2.1 Response (`fix/audit-v2.1`)

Every task below lists its status (`done` / `partial` / `blocked`) and concrete command + output evidence reproduced locally on branch `fix/audit-v2.1`. No metrics have been invented or estimated; unexecuted signoff items are explicitly marked `NOT VERIFIED`.

---

## Phase 1 — Core RTL Correctness

| Task | Status | Evidence (Command & Measured Output) |
| :--- | :---: | :--- |
| **1.1 CORDIC range safety (`rtl/arithmetic/cordic.v`)** | **done** | Added `[-π, +π]` (`[0xFCDC, 0x0324]`) quadrant folding (`sin(π-x)=sin(x)`, `cos(π-x)=-cos(x)`), symmetric magnitude rounding, and `domain_err` for `|θ| > π` wired to `err_dom` in `scicore_top.v`. `python3 verification/golden_model.py` (all 1,609 Q8.8 angles): `sin` max **`0.83 LSB`**, `cos` max **`0.75 LSB`** (`<= 1.00 LSB` PASS). `tb_m3`: **`PASS (114/114 CORDIC golden vectors bit-exact)`**. |
| **1.2 EXP accuracy (`rtl/arithmetic/log_exp.v`)** | **done** | Replaced shift-add `log2(e)` with 14-bit constant (`5909/4096`), sign-magnitude 30-bit product (zero negative truncation bias), 32-entry Q2.14 LUT + 7-bit linear interpolation, and round-to-nearest shift. `python3 verification/golden_model.py` (all 2,663 inputs in `[-5.55, +4.85]`): max rel error (`>= 1.0`) **`0.180%`** (`<= 0.50%` PASS); max abs error (`< 1.0`) **`0.51 LSB`** (`<= 2.00 LSB` PASS). `tb_m4`: **`PASS (SQRT=134, LN=70, EXP=88 golden vectors bit-exact)`**. |
| **1.3 Error semantics & saturation (`scicore_top.v`, `alu16.v`, `multiplier.v`, `divider.v`)** | **done** | Documented & enforced policy: overflow in `ADD`/`SUB`/`NEG`/`MUL`/`DIV`/`EXP` saturates to `0x7FFF`/`0x8000` while setting `err_ovf`; `div_zero`, `domain_err`, `stack_overflow`, `stack_underflow` leave the RPN stack **unchanged**. Verified in `tb_m1` (`12/12`), `tb_m2` (`512/512`), and `tb_top` (`PASS (all 16 opcodes + error policies verified)`). |
| **1.4 Add `TAN` & `PUSH_PI` + `integration/opcodes.csv`** | **done** | Added `0xE = TAN` (micro-sequenced `CORDIC → DIV`, state `3'd4`) and `0xF = PUSH_PI` (`0x0324`) in `scicore_top.v` without breaking `0x0..0xD`. Documented all 16 opcodes in `integration/opcodes.csv` and `README.md`. Verified in `tb_top` and `scripts/check_consistency.py`. |
| **1.5 User-indexed `STO`/`RCL`** | **done** | `scicore_top.v` uses `cmd_imm[1:0]` for `M0..M3`; `scicore_asic_top.v` latches `STO`/`RCL` prefix and consumes the next digit key (`0..3`) as the register index. Verified in `tb_asic_top` (`STO/RCL M2`). |

---

## Phase 2 — I/O Wrapper (`rtl/input`, `rtl/output`, `rtl/top/scicore_asic_top.v`)

| Task | Status | Evidence (Command & Measured Output) |
| :--- | :---: | :--- |
| **2.1 Single-source `integration/keymap.csv` + `scripts/gen_keymap.py`** | **done** | Created `integration/keymap.csv` matching all 32 PCB silkscreened switches `K1–K32`, generated `rtl/input/keymap_decode.v` via `scripts/gen_keymap.py`, and added CI verification in `scripts/check_consistency.py` (`[PASS] integration/keymap.csv legends match all 32 PCB K1-K32 switches`). |
| **2.2 Multi-digit decimal entry & RPN flow** | **done** | Implemented `0–9`, `.`, `DEL`, `ENT`, `CLR`, operator auto-push, and rounded decimal-to-Q8.8 conversion in `scicore_asic_top.v`. Verified in `tb_asic_top` (`12.5*3=37.5`, `sqrt(2)=1.414`, `sin(0.5)=0.480`). |
| **2.3 `keypad_scanner.v` sync & debounce** | **done** | Added 2-FF synchronizers on `col[7:0]`, parameterized `CLK_HZ=10000000`, `DEBOUNCE_MS=15` (`150,000` cycles press & release debounce), and `SETTLE_CYCLES=100` row-settling wait. Tested with simulated contact bounce in `tb_asic_top`. |
| **2.4 Async-assert / sync-deassert reset + `uart_rx` sync** | **done** | Added 2-FF async-assert / sync-deassert reset synchronizer in `scicore_asic_top.v` and 2-FF `uart_rx` synchronizer in `rtl/output/uart_debug.v`. |
| **2.5 Honest display module rename (`spi_result_shifter.v`)** | **done** | Chose the honest scope option: removed `rtl/output/display_controller.v`, created `rtl/output/spi_result_shifter.v` (raw 16-bit Q8.8 SPI output for external display bridge/MCU), and removed all on-die "128×64 LCD controller" claims from `README.md` and `integration/pin_mapping.csv`. |
| **2.6 Real 8N1 UART TX/RX (`rtl/output/uart_debug.v`)** | **done** | Implemented parameterized 8N1 UART TX (`CLKS_PER_BIT=87` for 115200 baud @ 10 MHz, prints `"XXXX E\r\n"`) and 8N1 RX receiver with minimal ASCII command trigger; removed dead `uart_rx ? 1 : 1` logic. |

---

## Phase 3 — Verification & Lint

| Task | Status | Evidence (Command & Measured Output) |
| :--- | :---: | :--- |
| **3.1 Self-checking testbenches** | **done** | All 7 testbenches (`tb_m1`, `tb_regbank`, `tb_m2`, `tb_m3`, `tb_m4`, `tb_top`, `tb_asic_top`) call `$fatal` on mismatch and print PASS/FAIL summaries. `bash scripts/run_tests.sh` exits 0 (`ALL 7 TESTBENCHES PASSED`). |
| **3.2 Golden vector generation & RTL co-check** | **done** | `python3 verification/golden_model.py` generates `verification/vectors/{mul,div,cordic,sqrt,ln,exp}_vectors.hex` verified bit-exact by `tb_m2`, `tb_m3`, `tb_m4`. |
| **3.3 Verilator `-Wall` & Yosys latch check** | **done** | `bash scripts/run_lint.sh`: `verilator --lint-only -Wall` exits 0 with **0 warnings** on both `scicore_top` and `scicore_asic_top`; Yosys `check -assert` confirms **0 latches** on both. |
| **3.4 CI workflow** | **done** | Updated `.github/workflows/verification.yml` to run `golden_model.py`, `scripts/run_tests.sh`, `scripts/run_lint.sh`, and `scripts/check_consistency.py`. |

---

## Phase 4 — Physical Design (SKY130HD OpenROAD)

| Task | Status | Evidence (Command & Measured Output) |
| :--- | :---: | :--- |
| **4.1–4.3 Re-run ORFS on v2.1 `scicore_top`, clean intermediates, commit reports** | **done** | Ran `openroad/orfs:latest` (`Yosys 0.68+post`, `sky130hd`, `10 MHz`) on v2.1 `scicore_top`. Deleted 29 redundant intermediate stage files in `physical_design/`. Committed `6_final.{gds,def,v,spef,sdc}`, `physical_design/reports/orfs_run.log`, `physical_design/reports/final_sta_power.rpt`, `scripts/run_orfs.sh`, and `scripts/gen_final_gds_and_sta.sh`. Measured: `394.34 × 394.34 µm` die, `67,486 µm²` cell area (`44%` util), **0 DRT DRC**, **0 antenna** (2 diodes), setup WNS `0.00 ns` (`+73.41 ns` slack), hold slack `-8.3 ps` (`VIOLATED` under `0.5 ns` uncertainty — documented honestly), vectorless power `0.8695 mW`. |
| **4.4 Port-match CI check & scope disclosure** | **done** | `scripts/check_consistency.py` verifies `rtl/top/scicore_top.v` ports == `physical_design/6_final.v` (`10 ports, exact widths`, including `err_flags[4:0]`). Explicitly documented as `scicore_top` core macro only (`scicore_asic_top` P&R, SS/FF corners, Magic DRC, and Netgen LVS marked **`NOT VERIFIED`**). |

---

## Phase 5 — PCB & Power Simulation

| Task | Status | Evidence (Command & Measured Output) |
| :--- | :---: | :--- |
| **5.1–5.2 Schematic/PCB/BOM sync, LED polarity fix, DRC & ERC reports** | **done** | Removed obsolete `J2` from `scicore16_pcb.kicad_sch` and `integration/pin_mapping.csv`; rotated `D1`/`D2` 180° to fix reverse-biased LED polarity; renamed mounting holes to `H1–H4` (`board_only`); regenerated `scicore16_pcb_bom.csv` (51 components), Gerbers, drill, pos, and `scicore16_pcb_fab.zip` via `kicad-cli` 10.0.6. Committed `pcb/scicore16_pcb.drc_report.json` (**0 errors, 0 unconnected**, 8 warnings) and `pcb/scicore16_pcb.erc_report.json`. |
| **5.3 Power network simulation (`ngspice-42`)** | **done** | Added `330 Ω` (`5.45 mA`) 1.8 V bleed resistor (`R_bleed18`) for AMS1117-1.8 minimum load, disclosed behavioral LDO model limits in header comments, executed `ngspice -b pcb/simulation/power_network.cir`, and committed `pcb/simulation/power_network.log` (`v3v3=3.2970 V`, `v1v8=1.7993 V`, min droop `1.7969 V`, `t_reset_release=0.725 ms`). |

---

## Phase 6 — Consistency, Docs & Hygiene

| Task | Status | Evidence (Command & Measured Output) |
| :--- | :---: | :--- |
| **6.1 Cross-artifact consistency checker** | **done** | Added `scripts/check_consistency.py` (6 checks: BOM/Sch/PCB refs, `keymap.csv` vs PCB `K1–K32`, `keymap_decode.v` coverage, RTL vs `6_final.v` ports, DRC 0-error gate, 16-opcode table) — all **6/6 PASS**. |
| **6.2–6.3 Docs grounded in real reports** | **done** | Updated `README.md` with only measured numbers from committed logs/reports, fixed `100×75` → `85×155`, `20` → `51` components, removed fake LCD driver claims, and labeled all unverified signoff items `NOT VERIFIED`. |
| **6.4 Hygiene (`LICENSE`, `Makefile`, `.vlsiproj`, `temp-freerouting.dsn`)** | **done** | Removed tracked `pcb/temp-freerouting.dsn`, gave `SciCore16_M1/M2/M3/M5.vlsiproj` unique `name` fields, added MIT `LICENSE` and top-level `Makefile`. |
