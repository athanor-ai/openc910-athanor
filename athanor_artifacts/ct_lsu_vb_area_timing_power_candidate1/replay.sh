#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${YOSYS_BIN:?set YOSYS_BIN to the pinned Yosys executable}"
: "${STA_BIN:?set STA_BIN to the OpenSTA executable}"
: "${LIBERTY:?set LIBERTY to sky130_fd_sc_hd__tt_025C_1v80.lib}"

OUT="$ROOT/replay_out"
rm -rf "$OUT"
mkdir -p "$OUT"
cd "$ROOT"

rename_gate() {
  local src="$1"
  local dst="$2"
  python3 - "$src" "$dst" <<'PY'
from pathlib import Path
import re
import sys

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
text = src.read_text()
text = re.sub(r"\bmodule\s+ct_lsu_vb\s*\(", "module ct_lsu_vb_gate(", text, count=1)
dst.write_text(text)
PY
}

rename_gate ct_lsu_vb_gate_candidate.v "$OUT/ct_lsu_vb_gate_candidate.renamed.v"
rename_gate ct_lsu_vb_gate_proof_mutant.v "$OUT/ct_lsu_vb_gate_proof_mutant.renamed.v"

RESET_ARGS=(-set-at 1 cpurst_b 0)
for step in 2 3 4 5 6 7 8; do
  RESET_ARGS+=(-set-at "$step" cpurst_b 1)
done

METER_DEPS="cpu_cfig.h gated_clk_cell.v ct_rtu_expand_8.v ct_lsu_vb_addr_entry.v"
PROOF_CMD="read_verilog -sv $METER_DEPS ct_lsu_vb_gold.v $OUT/ct_lsu_vb_gate_candidate.renamed.v ct_lsu_vb_output_miter.sv; prep -top ct_lsu_vb_output_miter; flatten; async2sync; dffunmap; opt; select -module ct_lsu_vb_output_miter; sat -seq 8 ${RESET_ARGS[*]} -prove-asserts -verify"

"$YOSYS_BIN" -p "$PROOF_CMD" > "$OUT/output_miter_seq8.replay.log" 2>&1

if "$YOSYS_BIN" -p "read_verilog -sv $METER_DEPS ct_lsu_vb_gold.v $OUT/ct_lsu_vb_gate_proof_mutant.renamed.v ct_lsu_vb_output_miter.sv; prep -top ct_lsu_vb_output_miter; flatten; async2sync; dffunmap; opt; select -module ct_lsu_vb_output_miter; sat -seq 8 ${RESET_ARGS[*]} -prove-asserts -verify" \
  > "$OUT/proof_mutant_negative.replay.log" 2>&1; then
  echo "ERROR: proof mutant unexpectedly proved" >&2
  exit 1
fi

MAP_DEPS="cpu_cfig.h gated_clk_cell.v ct_rtu_expand_8.v ct_lsu_vb_addr_entry.v"
"$YOSYS_BIN" -p "read_verilog -sv $MAP_DEPS ct_lsu_vb_gold.v; synth -flatten -top ct_lsu_vb; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/ct_lsu_vb_gold.mapped.v" \
  > "$OUT/gold_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_verilog -sv $MAP_DEPS ct_lsu_vb_gate_candidate.v; synth -flatten -top ct_lsu_vb; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/ct_lsu_vb_gate_candidate.mapped.v" \
  > "$OUT/gate_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_verilog -sv $MAP_DEPS ct_lsu_vb_metric_negative.v; synth -flatten -top ct_lsu_vb; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/ct_lsu_vb_metric_negative.mapped.v" \
  > "$OUT/metric_negative_area.replay.log" 2>&1

echo "0b37bd4200de933a7d4f09f65afeecd9db0c83ac1f990313e850aef9b55a9906  $OUT/ct_lsu_vb_gold.mapped.v" | sha256sum -c -
echo "f290807e5166729be5200ffb8934f1abc02ef604bb39281ee934ad1d0d854339  $OUT/ct_lsu_vb_gate_candidate.mapped.v" | sha256sum -c -
echo "adbe85217d0bc8b4dda37154e9cfb863914b15620fe30b72794860f3e0e32ae7  $OUT/ct_lsu_vb_metric_negative.mapped.v" | sha256sum -c -

write_sta_tcl() {
  local netlist="$1"
  local out="$2"
  cat > "$out" <<EOF
read_liberty {$LIBERTY}
read_verilog {$netlist}
link_design ct_lsu_vb
create_clock -period 10.0 -name lsu_special_clk [get_ports lsu_special_clk]
if {[llength [get_ports cpurst_b]] > 0} { set_false_path -from [get_ports cpurst_b] }
foreach p [all_inputs] {
  set name [get_name \$p]
  if {\$name != "lsu_special_clk" && \$name != "cpurst_b"} { set_input_delay 0.0 -clock lsu_special_clk \$p }
}
foreach p [all_outputs] { set_output_delay 0.0 -clock lsu_special_clk \$p }
set_power_activity -global -activity 0.1 -duty 0.5
report_checks -path_delay max -format full_clock_expanded
report_tns
report_wns
report_power
exit
EOF
}

write_sta_tcl "$OUT/ct_lsu_vb_gold.mapped.v" "$OUT/gold_opensta.tcl"
write_sta_tcl "$OUT/ct_lsu_vb_gate_candidate.mapped.v" "$OUT/gate_opensta.tcl"
write_sta_tcl "$OUT/ct_lsu_vb_metric_negative.mapped.v" "$OUT/metric_negative_opensta.tcl"

"$STA_BIN" -exit "$OUT/gold_opensta.tcl" > "$OUT/gold_opensta_area_timing_power.replay.log" 2>&1
"$STA_BIN" -exit "$OUT/gate_opensta.tcl" > "$OUT/gate_opensta_area_timing_power.replay.log" 2>&1
"$STA_BIN" -exit "$OUT/metric_negative_opensta.tcl" > "$OUT/metric_negative_opensta_area_timing_power.replay.log" 2>&1

grep -q "SAT proof finished - no model found: SUCCESS" "$OUT/output_miter_seq8.replay.log"
grep -q "SAT proof finished - model found: FAIL" "$OUT/proof_mutant_negative.replay.log"
grep -q "Called with -verify and proof did fail" "$OUT/proof_mutant_negative.replay.log"
grep -q "Chip area for module '\\\\ct_lsu_vb': 13043.760000" "$OUT/gold_map.replay.log"
grep -q "Chip area for module '\\\\ct_lsu_vb': 13038.755200" "$OUT/gate_map.replay.log"
grep -q "Chip area for module '\\\\ct_lsu_vb': 15312.185600" "$OUT/metric_negative_area.replay.log"
grep -q "6.01   data arrival time" "$OUT/gold_opensta_area_timing_power.replay.log"
grep -q "4.99   data arrival time" "$OUT/gate_opensta_area_timing_power.replay.log"
grep -q "8.93   data arrival time" "$OUT/metric_negative_opensta_area_timing_power.replay.log"
grep -q "Total                  4.42e-04   1.52e-04   4.54e-09   5.95e-04" "$OUT/gold_opensta_area_timing_power.replay.log"
grep -q "Total                  4.42e-04   1.51e-04   4.55e-09   5.93e-04" "$OUT/gate_opensta_area_timing_power.replay.log"
grep -q "Total                  4.75e-04   1.87e-04   5.27e-09   6.62e-04" "$OUT/metric_negative_opensta_area_timing_power.replay.log"

echo "PASS: ct_lsu_vb candidate output miter, proof mutant, area, timing, OpenSTA estimated-power, and metric negative controls reproduced"
