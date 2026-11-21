"""
SciCore-16 v2.1 Python Golden Reference Model, Full-Domain Accuracy Audit & Hex Vector Generator
- Task 1.1: Verifies CORDIC <= 1 LSB across [-pi, +pi] (all 1,609 Q8.8 angles) + domain_err
- Task 1.2: Verifies EXP <= 0.5% relative error (res >= 1.0) & <= 2 LSB absolute (res < 1.0)
- Task 1.3: Saturating Q8.8 arithmetic for ALU/MUL/DIV/EXP
- Task 3.2: Emits stratified hex vector files under verification/vectors/ for self-checking TBs
"""
import math
import random
from pathlib import Path

SEED = 20261121
random.seed(SEED)

def to_s16(v):
    v &= 0xFFFF
    return v - 0x10000 if (v & 0x8000) else v

def u16(v):
    return v & 0xFFFF

# --- Exact v2.1 RTL Behavioral Models ---
def rtl_mul(a_u16, b_u16):
    a_s, b_s = to_s16(a_u16), to_s16(b_u16)
    sign = (a_u16 >> 15) ^ (b_u16 >> 15)
    mag_a = (-a_s) & 0xFFFF if a_s < 0 else a_s
    mag_b = (-b_s) & 0xFFFF if b_s < 0 else b_s
    acc = mag_a * mag_b
    scaled = ((acc + 0x80) >> 8) & 0xFFFFFF
    ovf = (scaled > 0x7FFF) if sign == 0 else (scaled > 0x8000)
    if ovf:
        res = 0x8000 if sign else 0x7FFF
    else:
        res = u16(-scaled) if sign else u16(scaled)
    return res, ovf

def rtl_div(a_u16, b_u16):
    if u16(b_u16) == 0:
        return 0, True, False
    a_s, b_s = to_s16(a_u16), to_s16(b_u16)
    sign = (a_u16 >> 15) ^ (b_u16 >> 15)
    mag_a = (-a_s) & 0xFFFF if a_s < 0 else a_s
    mag_b = (-b_s) & 0xFFFF if b_s < 0 else b_s
    quot = (mag_a << 8) // mag_b
    ovf = (quot > 0x7FFF) if sign == 0 else (quot > 0x8000)
    if ovf:
        res = 0x8000 if sign else 0x7FFF
    else:
        res = u16(-quot) if sign else u16(quot)
    return res, False, ovf

ATAN_LUT = [0x3244, 0x1DAC, 0x0FAE, 0x07F5, 0x03FF, 0x0200, 0x0100, 0x0080, 0x0040, 0x0020, 0x0010, 0x0008]

def rtl_cordic(theta_u16):
    th = to_s16(theta_u16)
    if th > 804 or th < -804:
        return 0, 0, True
    cos_neg = False
    if th > 402:
        th_fold = 804 - th
        cos_neg = True
    elif th < -402:
        th_fold = -804 - th
        cos_neg = True
    else:
        th_fold = th
    x = 0x26DD
    y = 0
    z = to_s16((u16(th_fold) & 0x3FF) << 6)
    for i in range(12):
        xs = x >> i
        ys = y >> i
        if z >= 0:
            x, y, z = to_s16(x - ys), to_s16(y + xs), to_s16(z - ATAN_LUT[i])
        else:
            x, y, z = to_s16(x + ys), to_s16(y - xs), to_s16(z + ATAN_LUT[i])
    xm = (-x) if x < 0 else x
    ym = (-y) if y < 0 else y
    xq = (xm + 0x20) >> 6
    yq = (ym + 0x20) >> 6
    cos_raw = -xq if x < 0 else xq
    sin_raw = -yq if y < 0 else yq
    cos_out = -cos_raw if cos_neg else cos_raw
    return sin_raw, cos_out, False

def rtl_sqrt(x_u16):
    if x_u16 & 0x8000:
        return 0, True
    rad = x_u16 << 8
    rem = 0
    root = 0
    for _ in range(12):
        next_rem = ((rem & 0xFFF) << 2) | ((rad >> 22) & 0x3)
        trial = (root << 2) | 1
        if next_rem >= trial:
            rem = next_rem - trial
            root = (root << 1) | 1
        else:
            rem = next_rem
            root = root << 1
        rad = (rad << 2) & 0xFFFFFF
    return root, False

LN_LUT = [0, 16, 30, 44, 57, 70, 82, 93, 104, 114, 124, 134, 143, 152, 161, 169, 177]
EXP_LUT32 = [round(16384 * (2.0 ** (i / 32.0))) for i in range(33)]

def rtl_ln(x_u16):
    if x_u16 == 0 or (x_u16 & 0x8000):
        return 0, True
    m, k = x_u16, 0
    while m >= 0x0200:
        m >>= 1; k += 1
    while m < 0x0100:
        m <<= 1; k -= 1
    idx = (m >> 4) & 0xF
    frac = m & 0xF
    ln_f = LN_LUT[idx] + (((LN_LUT[idx+1] - LN_LUT[idx]) * frac + 8) >> 4)
    k_abs = abs(k)
    k_ln2 = (k_abs * 177) + (k_abs >> 1)
    k_ln2_s = -k_ln2 if k < 0 else k_ln2
    return to_s16(k_ln2_s + ln_f), False

def rtl_exp(x_u16):
    x_s = to_s16(x_u16)
    if x_s > 0x04DA:
        return 0x7FFF, True
    if x_s < -1420:
        return 0, False
    x_abs = -x_s if x_s < 0 else x_s
    u_prod = x_abs * 5909
    u_mag = (u_prod + 128) >> 8
    u_q812 = (-u_mag if x_s < 0 else u_mag) & 0xFFFFF
    # 20-bit signed -> 5-bit signed k in bits [16:12], 12-bit unsigned f in bits [11:0]
    k_u5 = (u_q812 >> 12) & 0x1F
    k_s = k_u5 - 32 if (k_u5 & 0x10) else k_u5
    f = u_q812 & 0xFFF
    idx = (f >> 7) & 0x1F
    frac = f & 0x7F
    p2 = EXP_LUT32[idx] + (((EXP_LUT32[idx+1] - EXP_LUT32[idx]) * frac + 64) >> 7)
    shift = 6 - k_s
    if shift == 0:
        raw = p2
    elif 1 <= shift <= 15:
        raw = (p2 + (1 << (shift - 1))) >> shift
    else:
        raw = 0
    if raw > 0x7FFF:
        return 0x7FFF, True
    return raw, False

def stats(errs):
    n = len(errs)
    abs_e = [abs(e) for e in errs]
    return n, max(abs_e), sum(abs_e) / n, math.sqrt(sum(e * e for e in errs) / n), max(abs_e) * 256.0

def main():
    root = Path(__file__).resolve().parent.parent
    vec_dir = root / "verification" / "vectors"
    vec_dir.mkdir(parents=True, exist_ok=True)

    # 1. Stratified MUL & DIV vectors (80% in-range non-overflow, 20% full-range/boundary)
    mul_err, div_err = [], []
    mul_vecs, div_vecs = [], []
    mul_boundaries = [(0x0180, 0x0200), (0xFD80, 0x0300), (0x8000, 0x8000), (0x7FFF, 0x7FFF), (0x1400, 0x0A00), (0xFF80, 0x0100)]
    div_boundaries = [(0x0700, 0x0200), (0xFD00, 0x0200), (0x0100, 0x0000), (0x8000, 0xFF00), (0x0000, 0x0200), (0x6400, 0x0080)]

    for i in range(10000):
        if i < len(mul_boundaries):
            a_u, b_u = mul_boundaries[i]
        elif i < 8000:
            # In-range [-11.0, +11.0] so product stays inside [-128, +127.996]
            a_u = u16(random.randint(-2816, 2816))
            b_u = u16(random.randint(-2816, 2816))
        else:
            a_u = u16(random.randint(-32768, 32767))
            b_u = u16(random.randint(-32768, 32767))
        res, ovf = rtl_mul(a_u, b_u)
        if not ovf:
            mul_err.append(to_s16(res) / 256.0 - (to_s16(a_u) / 256.0) * (to_s16(b_u) / 256.0))
        if len(mul_vecs) < 256:
            mul_vecs.append(f"{a_u:04x}_{b_u:04x}_{res:04x}_{1 if ovf else 0}")

    for i in range(10000):
        if i < len(div_boundaries):
            a_u, b_u = div_boundaries[i]
        elif i < 8000:
            a_u = u16(random.randint(-16000, 16000))
            b_s = random.choice([random.randint(256, 8000), random.randint(-8000, -256)])
            b_u = u16(b_s)
        else:
            a_u = u16(random.randint(-32768, 32767))
            b_u = u16(random.randint(-32768, 32767))
        res, dz, ovf = rtl_div(a_u, b_u)
        if not dz and not ovf:
            div_err.append(to_s16(res) / 256.0 - (to_s16(a_u) / 256.0) / (to_s16(b_u) / 256.0))
        if len(div_vecs) < 256:
            div_vecs.append(f"{a_u:04x}_{b_u:04x}_{res:04x}_{1 if dz else 0}_{1 if ovf else 0}")

    (vec_dir / "mul_vectors.hex").write_text("\n".join(mul_vecs) + "\n", encoding="utf-8")
    (vec_dir / "div_vectors.hex").write_text("\n".join(div_vecs) + "\n", encoding="utf-8")

    # 2. Exhaustive CORDIC sweep across [-pi, +pi] (all 1,609 Q8.8 angles) + out-of-range check
    sin_err, cos_err, cor_vecs = [], [], []
    for t in range(-804, 805):
        s_q, c_q, derr = rtl_cordic(u16(t))
        assert not derr
        rad = t / 256.0
        sin_err.append(s_q / 256.0 - math.sin(rad))
        cos_err.append(c_q / 256.0 - math.cos(rad))
        if t in (-804, -603, -402, -201, 0, 134, 201, 402, 512, 603, 804) or (t % 16 == 0):
            cor_vecs.append(f"{u16(t):04x}_{u16(s_q):04x}_{u16(c_q):04x}_0")
    # Out-of-range domain_err checks
    for bad_t in (805, 1024, -805, -2048):
        s_q, c_q, derr = rtl_cordic(u16(bad_t))
        assert derr, f"CORDIC failed to flag domain_err for {bad_t}"
        cor_vecs.append(f"{u16(bad_t):04x}_0000_0000_1")
    (vec_dir / "cordic_vectors.hex").write_text("\n".join(cor_vecs) + "\n", encoding="utf-8")

    # 3. Exhaustive SQRT sweep [0, 32767]
    sqrt_err, sqrt_vecs = [], []
    for x in range(0, 32768):
        r_q, err = rtl_sqrt(x)
        assert not err
        sqrt_err.append(r_q / 256.0 - math.sqrt(x / 256.0))
        if x in (0, 1, 64, 128, 256, 512, 1024, 2304, 32767) or (x % 256 == 0):
            sqrt_vecs.append(f"{x:04x}_{r_q:04x}_0")
    for neg_x in (0xFF00, 0x8000):
        r_q, err = rtl_sqrt(neg_x)
        assert err
        sqrt_vecs.append(f"{neg_x:04x}_0000_1")
    (vec_dir / "sqrt_vectors.hex").write_text("\n".join(sqrt_vecs) + "\n", encoding="utf-8")

    # 4. Exhaustive LN sweep [1, 32767]
    ln_err, ln_vecs = [], []
    for x in range(1, 32768):
        r_q, err = rtl_ln(x)
        assert not err
        ln_err.append(r_q / 256.0 - math.log(x / 256.0))
        if x in (1, 128, 256, 512, 696, 2560, 32767) or (x % 512 == 0):
            ln_vecs.append(f"{x:04x}_{u16(r_q):04x}_0")
    for bad_x in (0x0000, 0xFF00):
        r_q, err = rtl_ln(bad_x)
        assert err
        ln_vecs.append(f"{bad_x:04x}_0000_1")
    (vec_dir / "ln_vectors.hex").write_text("\n".join(ln_vecs) + "\n", encoding="utf-8")

    # 5. Exhaustive EXP sweep [-1420, 1242] ([-5.547, +4.852])
    exp_err, exp_rel_ge1, exp_abs_lt1, exp_vecs = [], [], [], []
    for x in range(-1420, 1243):
        r_q, ovf = rtl_exp(u16(x))
        assert not ovf, f"Unexpected EXP overflow at x={x}"
        exact = math.exp(x / 256.0)
        got = r_q / 256.0
        err = got - exact
        exp_err.append(err)
        if exact >= 1.0:
            exp_rel_ge1.append(abs(err) / exact * 100.0)
        else:
            exp_abs_lt1.append(abs(err) * 256.0)
        if x in (-1420, -512, -256, 0, 256, 512, 1024, 1242) or (x % 32 == 0):
            exp_vecs.append(f"{u16(x):04x}_{r_q:04x}_0")
    for ovf_x in (0x04DB, 0x0500, 0x1000):
        r_q, ovf = rtl_exp(ovf_x)
        assert ovf and r_q == 0x7FFF
        exp_vecs.append(f"{ovf_x:04x}_7fff_1")
    (vec_dir / "exp_vectors.hex").write_text("\n".join(exp_vecs) + "\n", encoding="utf-8")

    # Enforce Phase 1.1 & 1.2 acceptance targets!
    _, _, _, _, sin_ulp = stats(sin_err)
    _, _, _, _, cos_ulp = stats(cos_err)
    max_exp_rel_pct = max(exp_rel_ge1)
    max_exp_lt1_lsb = max(exp_abs_lt1)

    print(f"CORDIC [-pi, +pi] (1,609 angles): sin max = {sin_ulp:.2f} LSB, cos max = {cos_ulp:.2f} LSB (target <= 1.00 LSB)")
    print(f"EXP [-5.55, +4.85] (2,663 pts):   rel(>=1.0) max = {max_exp_rel_pct:.3f}% (target <= 0.50%), abs(<1.0) max = {max_exp_lt1_lsb:.2f} LSB (target <= 2.00 LSB)")
    assert sin_ulp <= 1.0 and cos_ulp <= 1.0, f"CORDIC exceeded 1 LSB: sin={sin_ulp}, cos={cos_ulp}"
    assert max_exp_rel_pct <= 0.5, f"EXP rel error exceeded 0.5%: {max_exp_rel_pct:.3f}%"
    assert max_exp_lt1_lsb <= 2.0, f"EXP abs(<1.0) error exceeded 2 LSB: {max_exp_lt1_lsb:.2f}"

    rows = [
        ("Multiplier (`mul`, stratified non-ovf)", *stats(mul_err)),
        ("Divider (`div`, stratified non-ovf)", *stats(div_err)),
        ("CORDIC `sin(x)` (`[-π, +π]`)", *stats(sin_err)),
        ("CORDIC `cos(x)` (`[-π, +π]`)", *stats(cos_err)),
        ("Square Root `sqrt(x)` (`[0, 127.996]`)", *stats(sqrt_err)),
        ("Natural Log `ln(x)` (`[1/256, 127.996]`)", *stats(ln_err)),
        ("Exponential `exp(x)` (`[-5.55, +4.85]`)", *stats(exp_err)),
    ]

    md = [
        "# SciCore-16 Full-Domain Numerical Accuracy Report (v2.1)",
        "",
        f"Generated automatically by `verification/golden_model.py` (PRNG seed `{SEED}`).",
        "",
        "## Acceptance Targets Verified",
        f"- **CORDIC `[-π, +π]` (1,609 Q8.8 angles):** `sin` max **`{sin_ulp:.2f} LSB`**, `cos` max **`{cos_ulp:.2f} LSB`** (target `<= 1.00 LSB` — **PASS**)",
        f"- **EXP `[-5.55, +4.85]` (2,663 Q8.8 inputs):** max relative error (`>= 1.0`) **`{max_exp_rel_pct:.3f}%`** (target `<= 0.50%` — **PASS**); max absolute error (`< 1.0`) **`{max_exp_lt1_lsb:.2f} LSB`** (target `<= 2.00 LSB` — **PASS**)",
        "",
        "| Unit & Domain | Samples Tested | Max Abs Error | Mean Abs Error | RMS Error | Max Error (Q8.8 LSB) |",
        "| :--- | :---: | :---: | :---: | :---: | :---: |",
    ]
    for name, n, mx, mn, rms, ulp in rows:
        md.append(f"| {name} | {n:,} | `{mx:.5f}` | `{mn:.5f}` | `{rms:.5f}` | **`{ulp:.2f} LSB`** |")
        print(f"{name:42s} N={n:6d} max={mx:.5f} mean={mn:.5f} rms={rms:.5f} ulp={ulp:.2f}")

    (root / "documentation" / "numerical_accuracy_report.md").write_text("\n".join(md) + "\n", encoding="utf-8")
    print("ALL GOLDEN MODEL ACCEPTANCE CHECKS PASSED + HEX VECTORS GENERATED!")

if __name__ == "__main__":
    main()
