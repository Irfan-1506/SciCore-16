#!/usr/bin/env bash
set -euo pipefail
source /OpenROAD-flow-scripts/env.sh
PDK=/OpenROAD-flow-scripts/flow/platforms/sky130hd

echo "=== 1. Generating 6_final.gds from 6_final.def via ORFS def2stream.py ==="
/opt/orfs-python/bin/python3 /OpenROAD-flow-scripts/flow/util/generate_klayout_tech.py \
  --template "$PDK/sky130hd.lyt" \
  --output /tmp/klayout.lyt \
  --lef-files "$PDK/lef/sky130_fd_sc_hd.tlef" "$PDK/lef/sky130_fd_sc_hd_merged.lef" \
  --map-files

/opt/orfs-python/bin/python3 /OpenROAD-flow-scripts/flow/util/def2stream.py \
  --design-name=scicore_top \
  --in-def=/work/physical_design/6_final.def \
  --in-files="$PDK/gds/sky130_fd_sc_hd.gds" \
  --seal-file="" \
  --out-file=/work/physical_design/6_final.gds \
  --tech-file=/tmp/klayout.lyt \
  --layer-map=

echo "=== 2. Running Post-Route OpenSTA Timing & Vectorless Power Report ==="
cat << 'EOF' > /tmp/sta_report.tcl
read_lef /OpenROAD-flow-scripts/flow/platforms/sky130hd/lef/sky130_fd_sc_hd.tlef
read_lef /OpenROAD-flow-scripts/flow/platforms/sky130hd/lef/sky130_fd_sc_hd_merged.lef
read_liberty /OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog /work/physical_design/6_final.v
link_design scicore_top
read_spef /work/physical_design/6_final.spef
read_sdc /work/physical_design/6_final.sdc
puts "=== SETUP TIMING SUMMARY ==="
report_wns
report_tns
report_worst_slack -max
puts "=== HOLD TIMING SUMMARY ==="
report_worst_slack -min
puts "=== CRITICAL SETUP PATH ==="
report_checks -path_delay max -fields {slew cap input_pins nets} -digits 4
puts "=== CRITICAL HOLD PATH ==="
report_checks -path_delay min -digits 4
puts "=== VECTORLESS POWER SUMMARY (DEFAULT ACTIVITY, NOT VCD) ==="
report_power -digits 4
exit
EOF

/OpenROAD-flow-scripts/tools/install/OpenROAD/bin/openroad -exit /tmp/sta_report.tcl \
  | tee /work/physical_design/reports/final_sta_power.rpt

ls -lh /work/physical_design/6_final.gds /work/physical_design/reports/final_sta_power.rpt
