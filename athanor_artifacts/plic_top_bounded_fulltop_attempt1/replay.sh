#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${YOSYS_BIN:?set YOSYS_BIN to the pinned Yosys executable}"
: "${STA_BIN:?set STA_BIN to the pinned OpenSTA executable}"
: "${LIBERTY:?set LIBERTY to sky130_fd_sc_hd__tt_025C_1v80.lib}"

OUT="$ROOT/replay_out"
rm -rf "$OUT"
mkdir -p "$OUT"
cd "$ROOT"

"$YOSYS_BIN" -V > "$OUT/yosys_version.replay.log" 2>&1
"$STA_BIN" -version > "$OUT/opensta_version.replay.log" 2>&1
sha256sum "$LIBERTY" > "$OUT/liberty_sha256.replay.log"

python3 ../../athanor/full_top_ppa_harness.py --check-package "$ROOT" \
  > "$OUT/receipt_contract.replay.log" 2>&1

grep -q "Yosys 0.66+181" "$OUT/yosys_version.replay.log"
grep -q "2.2.0" "$OUT/opensta_version.replay.log"
grep -q "ec0e1067a35c8bf20b11e58d1e8ac53326067e4dac84a125cc1b917a3518d0d9" "$OUT/liberty_sha256.replay.log"
grep -q "PASS: plic_top bounded receipt contract is current" "$OUT/receipt_contract.replay.log"
grep -q "1039075.305600" composed_area.pinned.log
grep -q "1006879.427200" composed_area.pinned.log
grep -q "timing-flat" sta_screen.pinned.log

echo "PASS: plic_top bounded full-top receipt contract, screen hash, cache keys, tool identities, and conservative timing wording reproduced"
