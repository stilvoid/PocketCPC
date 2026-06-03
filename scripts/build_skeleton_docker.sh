#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FPGA_DIR="$ROOT/src/apf_amstrad_skeleton/src/fpga"
CORE_DIR="$ROOT/src/apf_amstrad_skeleton/Cores/steve.AmstradCPC"
IMAGE="${QUARTUS_DOCKER_IMAGE:-raetro/quartus:18.1}"

docker run --rm --platform linux/amd64 \
  --user "$(id -u):$(id -g)" \
  -v "$FPGA_DIR:/work" \
  -w /work \
  "$IMAGE" \
  /opt/intelFPGA/quartus/bin/quartus_sh --flow compile ap_core

python3 "$ROOT/scripts/reverse_rbf_bits.py" \
  "$FPGA_DIR/output_files/ap_core.rbf" \
  "$CORE_DIR/bitstream.rbf_r"
echo "Wrote $CORE_DIR/bitstream.rbf_r"
