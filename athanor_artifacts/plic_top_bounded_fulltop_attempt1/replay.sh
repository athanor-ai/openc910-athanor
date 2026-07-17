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

"$YOSYS_BIN" -V > "$OUT/yosys_version.replay.log" 2>&1
"$STA_BIN" -version > "$OUT/opensta_version.replay.log" 2>&1
sha256sum "$LIBERTY" > "$OUT/liberty_sha256.replay.log"

python3 ../../athanor/full_top_ppa_harness.py --check-package "$ROOT" \
  > "$OUT/receipt_contract.replay.log" 2>&1

PYTHONPATH="$REPO" python3 - "$REPO" "$OUT/plic_granu_arb_overlay.v" <<'PY'
from pathlib import Path
import sys

from athanor import full_top_ppa_harness as h

repo = Path(sys.argv[1])
out = Path(sys.argv[2])
candidate = repo / "athanor_artifacts/plic_32to1_arb_granu_balanced_candidate1/plic_granu_arb_gate_candidate.v"
out.write_text(h.rewrite_plic_granu_overlay(candidate.read_text(encoding="utf-8")), encoding="utf-8")
PY

COMMON_SOURCES=(
  "$REPO/C910_RTL_FACTORY/gen_rtl/cpu/rtl/cpu_cfig.h"
  "$REPO/C910_RTL_FACTORY/gen_rtl/clk/rtl/gated_clk_cell.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/common/rtl/sync_level2level.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/common/rtl/sync_level2pulse.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/plic/rtl/csky_apb_1tox_matrix.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/plic/rtl/plic_32to1_arb.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/plic/rtl/plic_arb_ctrl.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/plic/rtl/plic_ctrl.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/plic/rtl/plic_granu2_arb.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/plic/rtl/plic_hart_arb.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/plic/rtl/plic_hreg_busif.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/plic/rtl/plic_int_kid.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/plic/rtl/plic_kid_busif.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/plic/rtl/plic_top.v"
)
GOLD_SOURCES=("${COMMON_SOURCES[@]}" "$REPO/C910_RTL_FACTORY/gen_rtl/plic/rtl/plic_granu_arb.v")
GATE_SOURCES=("${COMMON_SOURCES[@]}" "$OUT/plic_granu_arb_overlay.v")

run_yosys_map() {
  local label="$1"
  local out_netlist="$2"
  shift 2
  local sources=("$@")
  local read_cmd="read_verilog -sv"
  local src
  for src in "${sources[@]}"; do
    read_cmd+=" $src"
  done
  "$YOSYS_BIN" -p "read_liberty -lib $LIBERTY; $read_cmd; hierarchy -top plic_top; synth -top plic_top; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean -purge; stat -liberty $LIBERTY; write_verilog -simple-lhs -noattr $out_netlist" \
    > "$OUT/${label}_yosys_map.replay.log" 2>&1
}

run_yosys_map gold "$OUT/plic_top_gold.mapped.v" "${GOLD_SOURCES[@]}"
run_yosys_map gate "$OUT/plic_top_gate.mapped.v" "${GATE_SOURCES[@]}"

PYTHONPATH="$REPO" python3 - "$OUT/gold_yosys_map.replay.log" "$OUT/gate_yosys_map.replay.log" > "$OUT/composed_area.replay.log" <<'PY'
from pathlib import Path
import sys

from athanor import full_top_ppa_harness as h

gold = h.composed_area_from_yosys_stat(Path(sys.argv[1]).read_text(encoding="utf-8", errors="ignore"), "plic_top")
gate = h.composed_area_from_yosys_stat(Path(sys.argv[2]).read_text(encoding="utf-8", errors="ignore"), "plic_top")
print("PLIC_TOP_BOUNDED_COMPOSED_AREA_V1")
print(f"gold_composed_area: {gold:.6f}")
print(f"gate_composed_area: {gate:.6f}")
PY

write_sta_tcl() {
  local netlist="$1"
  local out="$2"
  cat > "$out" <<EOF
read_liberty {$LIBERTY}
read_verilog {$netlist}
link_design plic_top
create_clock -period 10.0 [get_ports plic_clk]
foreach p [all_inputs] {
  set name [get_name \$p]
  if {\$name != "plic_clk"} { set_input_delay 0.0 -clock plic_clk \$p }
}
foreach p [all_outputs] { set_output_delay 0.0 -clock plic_clk \$p }
set_power_activity -global -activity 0.1 -duty 0.5
report_checks -path_delay max -format full_clock_expanded
report_tns
report_wns
report_power
exit
EOF
}

write_sta_tcl "$OUT/plic_top_gold.mapped.v" "$OUT/gold_opensta.tcl"
write_sta_tcl "$OUT/plic_top_gate.mapped.v" "$OUT/gate_opensta.tcl"
"$STA_BIN" -exit "$OUT/gold_opensta.tcl" > "$OUT/gold_opensta.replay.log" 2>&1
"$STA_BIN" -exit "$OUT/gate_opensta.tcl" > "$OUT/gate_opensta.replay.log" 2>&1

grep -q "Yosys 0.66+181" "$OUT/yosys_version.replay.log"
grep -q "2.2.0" "$OUT/opensta_version.replay.log"
grep -q "ec0e1067a35c8bf20b11e58d1e8ac53326067e4dac84a125cc1b917a3518d0d9" "$OUT/liberty_sha256.replay.log"
grep -q "PASS: plic_top bounded receipt contract is current" "$OUT/receipt_contract.replay.log"
echo "3ee24e70934fb28dcd03b0c60217b999819c0631f7ce3467855e228beaa5ecd6  $OUT/plic_top_gold.mapped.v" | sha256sum -c -
echo "afe52aae52b3095a98c2a22f99f78b2c47d6e8e6e3e0ad67df373c4d97c0af51  $OUT/plic_top_gate.mapped.v" | sha256sum -c -
grep -q "1039075.305600" "$OUT/composed_area.replay.log"
grep -q "1006879.427200" "$OUT/composed_area.replay.log"
grep -q "140.74   data arrival time" "$OUT/gold_opensta.replay.log"
grep -q "140.29   data arrival time" "$OUT/gate_opensta.replay.log"
grep -q "wns -130.87" "$OUT/gold_opensta.replay.log"
grep -q "wns -130.42" "$OUT/gate_opensta.replay.log"
grep -q "Total                  7.70e-02   2.01e-02   5.64e-07   9.71e-02" "$OUT/gold_opensta.replay.log"
grep -q "Total                  7.66e-02   1.95e-02   5.55e-07   9.60e-02" "$OUT/gate_opensta.replay.log"
grep -q "timing-flat" sta_screen.pinned.log

echo "PASS: plic_top bounded full-top Yosys/OpenSTA run reproduced under the pinned screen"
