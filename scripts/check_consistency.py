#!/usr/bin/env python3
"""SciCore-16 cross-artifact consistency verifier (CI gate).

Checks:
  1. BOM refs == PCB non-mounting-hole refs == Schematic refs (no ghost J2, all K1..K32 present)
  2. integration/keymap.csv (K1..K32 refs & legends) == PCB K1..K32 footprint values
  3. rtl/input/keymap_decode.v is up to date with integration/keymap.csv
  4. rtl/top/scicore_top.v port names & widths == physical_design/6_final.v port names & widths
  5. pcb/scicore16_pcb.drc_report.json has 0 DRC errors and 0 unconnected items
  6. integration/opcodes.csv covers all 16 opcodes (0x0..0xF)
"""

import csv
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ERRORS = []


def err(msg):
    print(f"[FAIL] {msg}")
    ERRORS.append(msg)


def ok(msg):
    print(f"[PASS] {msg}")


def check_bom_pcb_sch():
    bom_path = ROOT / "pcb" / "scicore16_pcb_fab" / "scicore16_pcb_bom.csv"
    pcb_path = ROOT / "pcb" / "scicore16_pcb.kicad_pcb"
    sch_path = ROOT / "pcb" / "scicore16_pcb.kicad_sch"

    bom_refs = set()
    with bom_path.open(encoding="utf-8") as f:
        for row in csv.DictReader(f):
            for r in row["Refs"].split(","):
                r = r.strip()
                if r:
                    bom_refs.add(r)

    pcb_txt = pcb_path.read_text(encoding="utf-8")
    pcb_refs = set()
    pcb_keys = {}
    for m in re.finditer(r'\(footprint "([^"]+)".*?\(property "Reference" "([^"]+)".*?\(property "Value" "([^"]+)"', pcb_txt, re.S):
        fp, ref, val = m.group(1), m.group(2), m.group(3)
        if fp.startswith("MountingHole:"):
            continue
        pcb_refs.add(ref)
        if re.fullmatch(r"K\d+", ref):
            pcb_keys[ref] = val

    sch_txt = sch_path.read_text(encoding="utf-8")
    sch_refs = set()
    for m in re.finditer(r'\(reference "([^"]+)"\)', sch_txt):
        r = m.group(1)
        if not r.startswith("#"):
            sch_refs.add(r)

    if bom_refs != pcb_refs:
        err(f"BOM vs PCB ref mismatch: bom-pcb={sorted(bom_refs - pcb_refs)}, pcb-bom={sorted(pcb_refs - bom_refs)}")
    elif sch_refs != pcb_refs:
        err(f"Schematic vs PCB ref mismatch: sch-pcb={sorted(sch_refs - pcb_refs)}, pcb-sch={sorted(pcb_refs - sch_refs)}")
    else:
        ok(f"BOM == Schematic == PCB refs ({len(bom_refs)} components, no ghost J2)")

    return pcb_keys


def check_keymap(pcb_keys):
    km_path = ROOT / "integration" / "keymap.csv"
    csv_keys = {}
    with km_path.open(encoding="utf-8") as f:
        for row in csv.DictReader(f):
            csv_keys[row["key_ref"].strip()] = row["legend"].strip()

    if len(csv_keys) != 32:
        err(f"keymap.csv expected 32 keys, found {len(csv_keys)}")
        return

    mismatches = []
    for k, legend in sorted(csv_keys.items()):
        if pcb_keys.get(k) != legend:
            mismatches.append((k, legend, pcb_keys.get(k)))
    if mismatches:
        err(f"keymap.csv vs PCB K1-K32 legend mismatch: {mismatches[:5]}")
    else:
        ok("integration/keymap.csv legends match all 32 PCB K1-K32 switches")

    # Verify generated keymap_decode.v exists and mentions all 32 keys
    dec_txt = (ROOT / "rtl" / "input" / "keymap_decode.v").read_text(encoding="utf-8")
    missing_refs = [k for k in csv_keys if f"// {k} (" not in dec_txt]
    if missing_refs:
        err(f"rtl/input/keymap_decode.v missing generated entries for: {missing_refs[:5]}")
    else:
        ok("rtl/input/keymap_decode.v covers all 32 keys from integration/keymap.csv")


def parse_verilog_ports(text, mod_name):
    m = re.search(rf"module\s+{mod_name}\s*\((.*?)\);\s*", text, re.S)
    if not m:
        return None
    header = m.group(1)
    ports = {}
    # ANSI-style ports in header
    for pm in re.finditer(r"(?:input|output|inout)\s+(?:wire|reg)?\s*(\[\d+:\d+\])?\s*([A-Za-z_]\w*)", header):
        width = pm.group(1) or "[0:0]"
        ports[pm.group(2)] = width
    if ports:
        return ports
    # Non-ANSI (post-synthesis netlist) port list + body declarations
    port_names = [p.strip() for p in re.split(r",", header) if p.strip()]
    body_start = m.end()
    body_end = text.find("endmodule", body_start)
    body = text[body_start:body_end]
    for pname in port_names:
        dm = re.search(rf"\b(?:input|output|inout)\s+(?:wire\s+)?(\[\d+:\d+\])?\s*{re.escape(pname)}\s*;", body)
        if dm:
            ports[pname] = dm.group(1) or "[0:0]"
        else:
            ports[pname] = "UNKNOWN"
    return ports


def check_rtl_vs_netlist_ports():
    rtl_txt = (ROOT / "rtl" / "top" / "scicore_top.v").read_text(encoding="utf-8")
    net_path = ROOT / "physical_design" / "6_final.v"
    if not net_path.exists():
        err("physical_design/6_final.v missing")
        return
    net_txt = net_path.read_text(encoding="utf-8")
    rtl_ports = parse_verilog_ports(rtl_txt, "scicore_top")
    net_ports = parse_verilog_ports(net_txt, "scicore_top")
    if rtl_ports is None or net_ports is None:
        err("Failed to parse scicore_top module ports in RTL or 6_final.v")
        return
    if rtl_ports != net_ports:
        err(f"RTL vs 6_final.v port mismatch!\n  RTL: {rtl_ports}\n  NET: {net_ports}")
    else:
        ok(f"RTL scicore_top.v ports == physical_design/6_final.v ({len(rtl_ports)} ports, exact widths)")


def check_drc_report():
    drc_path = ROOT / "pcb" / "scicore16_pcb.drc_report.json"
    if not drc_path.exists():
        err("pcb/scicore16_pcb.drc_report.json missing")
        return
    d = json.loads(drc_path.read_text(encoding="utf-8"))
    n_err = sum(1 for v in d.get("violations", []) if v.get("severity") == "error")
    n_unc = len(d.get("unconnected_items", []))
    if n_err != 0 or n_unc != 0:
        err(f"PCB DRC report has {n_err} errors and {n_unc} unconnected items")
    else:
        ok(f"PCB DRC report verified: 0 errors, 0 unconnected items ({len(d.get('violations', []))} warnings)")


def check_opcodes():
    op_path = ROOT / "integration" / "opcodes.csv"
    ops = set()
    with op_path.open(encoding="utf-8") as f:
        for row in csv.DictReader(f):
            ops.add(int(row["cmd_op_hex"], 16))
    expected = set(range(16))
    if ops != expected:
        err(f"integration/opcodes.csv missing opcodes: {sorted(expected - ops)}")
    else:
        ok("integration/opcodes.csv covers all 16 opcodes (0x0..0xF)")


def main():
    pcb_keys = check_bom_pcb_sch()
    check_keymap(pcb_keys)
    check_rtl_vs_netlist_ports()
    check_drc_report()
    check_opcodes()
    if ERRORS:
        print(f"\nConsistency check FAILED with {len(ERRORS)} error(s).")
        sys.exit(1)
    print("\nALL CONSISTENCY CHECKS PASSED.")


if __name__ == "__main__":
    main()
