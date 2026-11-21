#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORFS_IMAGE="${ORFS_IMAGE:-openroad/orfs:latest}"

echo "=== Running OpenROAD-flow-scripts ($ORFS_IMAGE) for SciCore-16 (scicore_top, sky130hd) ==="
docker run --rm \
  -v "$ROOT_DIR:/work" \
  "$ORFS_IMAGE" \
  bash -lc '
    set -euo pipefail
    cd /OpenROAD-flow-scripts/flow
    make DESIGN_CONFIG=/work/physical_design/orfs/config.mk SCICORE_ROOT=/work clean_all
    make DESIGN_CONFIG=/work/physical_design/orfs/config.mk SCICORE_ROOT=/work

    RES_DIR=/OpenROAD-flow-scripts/flow/results/sky130hd/scicore16/base
    RPT_DIR=/OpenROAD-flow-scripts/flow/reports/sky130hd/scicore16/base
    LOG_DIR=/OpenROAD-flow-scripts/flow/logs/sky130hd/scicore16/base

    mkdir -p /work/physical_design/reports /work/physical_design/logs
    for f in 6_final.gds 6_final.def 6_final.v 6_final.spef 6_final.sdc 6_final.odb; do
      [ -f "$RES_DIR/$f" ] && cp "$RES_DIR/$f" /work/physical_design/
    done
    cp -r "$RPT_DIR/"* /work/physical_design/reports/ 2>/dev/null || true
    cp -r "$LOG_DIR/"*.log "$LOG_DIR/"*.json /work/physical_design/logs/ 2>/dev/null || true
    echo "=== ORFS FLOW COMPLETE ==="
  '
