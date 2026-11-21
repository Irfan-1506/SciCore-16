# SciCore-16 Full-Domain Numerical Accuracy Report (v2.1)

Generated automatically by `verification/golden_model.py` (PRNG seed `20261121`).

## Acceptance Targets Verified
- **CORDIC `[-π, +π]` (1,609 Q8.8 angles):** `sin` max **`0.83 LSB`**, `cos` max **`0.75 LSB`** (target `<= 1.00 LSB` — **PASS**)
- **EXP `[-5.55, +4.85]` (2,663 Q8.8 inputs):** max relative error (`>= 1.0`) **`0.180%`** (target `<= 0.50%` — **PASS**); max absolute error (`< 1.0`) **`0.51 LSB`** (target `<= 2.00 LSB` — **PASS**)

| Unit & Domain | Samples Tested | Max Abs Error | Mean Abs Error | RMS Error | Max Error (Q8.8 LSB) |
| :--- | :---: | :---: | :---: | :---: | :---: |
| Multiplier (`mul`, stratified non-ovf) | 8,096 | `0.00195` | `0.00097` | `0.00112` | **`0.50 LSB`** |
| Divider (`div`, stratified non-ovf) | 9,991 | `0.00391` | `0.00195` | `0.00225` | **`1.00 LSB`** |
| CORDIC `sin(x)` (`[-π, +π]`) | 1,609 | `0.00323` | `0.00096` | `0.00116` | **`0.83 LSB`** |
| CORDIC `cos(x)` (`[-π, +π]`) | 1,609 | `0.00291` | `0.00097` | `0.00116` | **`0.75 LSB`** |
| Square Root `sqrt(x)` (`[0, 127.996]`) | 32,768 | `0.00391` | `0.00196` | `0.00226` | **`1.00 LSB`** |
| Natural Log `ln(x)` (`[1/256, 127.996]`) | 32,767 | `0.00648` | `0.00160` | `0.00199` | **`1.66 LSB`** |
| Exponential `exp(x)` (`[-5.55, +4.85]`) | 2,663 | `0.03647` | `0.00242` | `0.00505` | **`9.34 LSB`** |
