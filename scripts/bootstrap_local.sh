#!/usr/bin/env bash
set -euo pipefail

mkdir -p upstreams

if [ ! -d upstreams/Amstrad_MiSTer ]; then
  git clone https://github.com/MiSTer-devel/Amstrad_MiSTer.git upstreams/Amstrad_MiSTer
fi

if [ ! -d upstreams/OpenFPGA_ZX-Spectrum ]; then
  git clone https://github.com/dave18/OpenFPGA_ZX-Spectrum.git upstreams/OpenFPGA_ZX-Spectrum
fi

echo "Upstreams are ready under ./upstreams"
echo "Next: run python3 scripts/check_expected_files.py"
