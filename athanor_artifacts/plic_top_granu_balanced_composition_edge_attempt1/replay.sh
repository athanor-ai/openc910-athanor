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
REPO="$(cd "$ROOT/../.." && pwd)"

sha256sum -c SHA256SUMS > "$OUT/package_hashes.replay.log"

"$YOSYS_BIN" -V > "$OUT/yosys_version.replay.log" 2>&1
"$STA_BIN" -version > "$OUT/opensta_version.replay.log" 2>&1
sha256sum "$LIBERTY" > "$OUT/liberty_sha256.replay.log"

PYTHONPATH="$REPO" python3 - "$REPO" "$OUT/plic_granu_arb_overlay.v" <<'PY'
from pathlib import Path
import sys

from athanor import full_top_ppa_harness as h

repo = Path(sys.argv[1])
out = Path(sys.argv[2])
candidate = repo / "athanor_artifacts/plic_32to1_arb_granu_balanced_candidate1/plic_granu_arb_gate_candidate.v"
out.write_text(h.rewrite_plic_granu_overlay(candidate.read_text(encoding="utf-8")), encoding="utf-8")
PY

PYTHONPATH="$REPO" python3 - "$REPO" "$OUT/boundary_identity.replay.log" <<'PY'
from pathlib import Path
import re
import sys

repo = Path(sys.argv[1])
out = Path(sys.argv[2])
gold = (repo / "C910_RTL_FACTORY/gen_rtl/plic/rtl/plic_granu_arb.v").read_text(encoding="utf-8")
gate = (repo / "athanor_artifacts/plic_32to1_arb_granu_balanced_candidate1/plic_granu_arb_gate_candidate.v").read_text(encoding="utf-8")

def port_list(text: str, module: str) -> list[str]:
    match = re.search(rf"module\s+{module}\s*\((.*?)\)\s*;", text, re.S)
    if not match:
        raise SystemExit(f"missing {module} module port list")
    return [line.strip().rstrip(",") for line in match.group(1).splitlines() if line.strip() and not line.strip().startswith("//")]

def port_decls(text: str, ports: list[str]) -> list[str]:
    wanted = set(ports)
    out = []
    for raw in text.splitlines():
        line = raw.split("//", 1)[0].strip().rstrip(";")
        if line.startswith(("input", "output", "inout")):
            match = re.search(r"\b([A-Za-z_][A-Za-z0-9_]*)$", line)
            if match and match.group(1) in wanted:
                out.append(re.sub(r"\s+", " ", line))
    return sorted(out)

gold_ports = port_list(gold, "plic_granu_arb")
gate_ports = port_list(gate, "plic_granu_arb_gate")
gold_decls = port_decls(gold, gold_ports)
gate_decls = port_decls(gate, gate_ports)
if gold_ports != gate_ports:
    raise SystemExit("plic_granu_arb module port list changed")
if gold_decls != gate_decls:
    raise SystemExit("plic_granu_arb port declarations changed")
out.write_text(
    "PASS: plic_granu_arb interface identical across gold and candidate\n"
    f"port_count: {len(gold_decls)}\n",
    encoding="utf-8",
)
PY

(
  cd "$REPO/athanor_artifacts/plic_top_bounded_fulltop_attempt1"
  ./replay.sh
) > "$OUT/plic_top_bounded_package_replay.replay.log" 2>&1

grep -q "Yosys 0.66+181" "$OUT/yosys_version.replay.log"
grep -q "2.2.0" "$OUT/opensta_version.replay.log"
grep -q "ec0e1067a35c8bf20b11e58d1e8ac53326067e4dac84a125cc1b917a3518d0d9" "$OUT/liberty_sha256.replay.log"
grep -q "PASS: plic_granu_arb interface identical" "$OUT/boundary_identity.replay.log"
grep -q "PASS: plic_top bounded full-top Yosys/OpenSTA run reproduced under the pinned screen" "$OUT/plic_top_bounded_package_replay.replay.log"
grep -q "1039075.305600" metric_screen.pinned.log
grep -q "1006879.427200" metric_screen.pinned.log
grep -q "flat plic_top proof is not claimed" proof_route.pinned.log
grep -q "66557 proven, 0 unproven" proof_route.pinned.log
grep -q "20812 unproven cells" proof_route.pinned.log

echo "PASS: plic_top PLIC composition-edge route receipt reproduced"
