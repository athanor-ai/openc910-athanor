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

EQ_CMD='read_verilog -sv cpu_cfig.h gated_clk_cell.v ct_lsu_lfb_data_entry_gold.v; rename ct_lsu_lfb_data_entry ct_lsu_lfb_data_entry_gold; read_verilog -sv ct_lsu_lfb_data_entry_gate_candidate.v; rename ct_lsu_lfb_data_entry ct_lsu_lfb_data_entry_gate; proc; memory; opt; equiv_make ct_lsu_lfb_data_entry_gold ct_lsu_lfb_data_entry_gate equiv; hierarchy -top equiv; flatten; async2sync; dffunmap; opt; equiv_simple -seq 8; equiv_status -assert'

"$YOSYS_BIN" -p "$EQ_CMD" > "$OUT/same_state_equiv_seq8.replay.log" 2>&1

if "$YOSYS_BIN" -p 'read_verilog -sv cpu_cfig.h gated_clk_cell.v ct_lsu_lfb_data_entry_gold.v; rename ct_lsu_lfb_data_entry ct_lsu_lfb_data_entry_gold; read_verilog -sv ct_lsu_lfb_data_entry_gate_proof_mutant.v; rename ct_lsu_lfb_data_entry ct_lsu_lfb_data_entry_gate; proc; memory; opt; equiv_make ct_lsu_lfb_data_entry_gold ct_lsu_lfb_data_entry_gate equiv; hierarchy -top equiv; flatten; async2sync; dffunmap; opt; equiv_simple -seq 8; equiv_status -assert' \
  > "$OUT/proof_mutant_negative.replay.log" 2>&1; then
  echo "ERROR: proof mutant unexpectedly proved" >&2
  exit 1
fi

"$YOSYS_BIN" -p "read_verilog -sv cpu_cfig.h gated_clk_cell.v ct_lsu_lfb_data_entry_gold.v; synth -flatten -top ct_lsu_lfb_data_entry; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/ct_lsu_lfb_data_entry_gold.mapped.v" \
  > "$OUT/gold_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_verilog -sv cpu_cfig.h gated_clk_cell.v ct_lsu_lfb_data_entry_gate_candidate.v; synth -flatten -top ct_lsu_lfb_data_entry; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/ct_lsu_lfb_data_entry_gate_candidate.mapped.v" \
  > "$OUT/gate_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_verilog -sv cpu_cfig.h gated_clk_cell.v ct_lsu_lfb_data_entry_metric_negative.v; synth -flatten -top ct_lsu_lfb_data_entry; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/ct_lsu_lfb_data_entry_metric_negative.mapped.v" \
  > "$OUT/metric_negative_area.replay.log" 2>&1

echo "ef48fab5073aacf89b81a890d0e367b5dde80451ba55b4d09c8d4c34b545bcb9  $OUT/ct_lsu_lfb_data_entry_gold.mapped.v" | sha256sum -c -
echo "16da6514b7edbbb3289e89fc1b4c219a521b6539f734479fe1ff6e328d2af410  $OUT/ct_lsu_lfb_data_entry_gate_candidate.mapped.v" | sha256sum -c -
echo "16713ad843860d08f05917a4e0558f6f57b5c991b8e57212820dc071e89f3e96  $OUT/ct_lsu_lfb_data_entry_metric_negative.mapped.v" | sha256sum -c -

write_sta_tcl() {
  local netlist="$1"
  local out="$2"
  cat > "$out" <<EOF
read_liberty {$LIBERTY}
read_verilog {$netlist}
link_design ct_lsu_lfb_data_entry
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

write_sta_tcl "$OUT/ct_lsu_lfb_data_entry_gold.mapped.v" "$OUT/gold_opensta.tcl"
write_sta_tcl "$OUT/ct_lsu_lfb_data_entry_gate_candidate.mapped.v" "$OUT/gate_opensta.tcl"
write_sta_tcl "$OUT/ct_lsu_lfb_data_entry_metric_negative.mapped.v" "$OUT/metric_negative_opensta.tcl"

"$STA_BIN" -exit "$OUT/gold_opensta.tcl" > "$OUT/gold_opensta_area_timing_power.replay.log" 2>&1
"$STA_BIN" -exit "$OUT/gate_opensta.tcl" > "$OUT/gate_opensta_area_timing_power.replay.log" 2>&1
"$STA_BIN" -exit "$OUT/metric_negative_opensta.tcl" > "$OUT/metric_negative_opensta_area_timing_power.replay.log" 2>&1

grep -q "Equivalence successfully proven" "$OUT/same_state_equiv_seq8.replay.log"
grep -q "Found a total of 8 unproven" "$OUT/proof_mutant_negative.replay.log"
grep -q "Chip area for module '\\\\ct_lsu_lfb_data_entry': 19467.420800" "$OUT/gold_map.replay.log"
grep -q "Chip area for module '\\\\ct_lsu_lfb_data_entry': 19456.160000" "$OUT/gate_map.replay.log"
grep -q "Chip area for module '\\\\ct_lsu_lfb_data_entry': 23926.697600" "$OUT/metric_negative_area.replay.log"
grep -q "8.17   data arrival time" "$OUT/gold_opensta_area_timing_power.replay.log"
grep -q "8.14   data arrival time" "$OUT/gate_opensta_area_timing_power.replay.log"
grep -q "8.15   data arrival time" "$OUT/metric_negative_opensta_area_timing_power.replay.log"
grep -q "Total                  1.25e-03   7.73e-05   6.86e-09   1.33e-03" "$OUT/gold_opensta_area_timing_power.replay.log"
grep -q "Total                  1.25e-03   7.73e-05   6.85e-09   1.33e-03" "$OUT/gate_opensta_area_timing_power.replay.log"
grep -q "Total                  1.31e-03   1.59e-04   8.26e-09   1.47e-03" "$OUT/metric_negative_opensta_area_timing_power.replay.log"

echo "PASS: ct_lsu_lfb_data_entry candidate equivalence, proof mutant, area, timing, OpenSTA estimated-power, and metric negative controls reproduced"
