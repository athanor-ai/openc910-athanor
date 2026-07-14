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

DEPS="cpu_cfig.h gated_clk_cell.v ct_rtu_encode_8.v ct_rtu_expand_8.v ct_lsu_idfifo_entry.v ct_lsu_idfifo_8.v ct_lsu_rb_entry.v ct_lsu_rot_data.v"

"$YOSYS_BIN" -p "read_verilog -sv $DEPS ct_lsu_rb_gold.v; rename ct_lsu_rb ct_lsu_rb_gold; read_verilog -sv ct_lsu_rb_gate_candidate.v; rename ct_lsu_rb ct_lsu_rb_gate; proc; memory; opt; equiv_make ct_lsu_rb_gold ct_lsu_rb_gate equiv; hierarchy -top equiv; flatten; async2sync; dffunmap; opt; equiv_simple -seq 8; equiv_status -assert" \
  > "$OUT/same_state_equiv_seq8.replay.log" 2>&1

if "$YOSYS_BIN" -p "read_verilog -sv $DEPS ct_lsu_rb_gold.v; rename ct_lsu_rb ct_lsu_rb_gold; read_verilog -sv ct_lsu_rb_gate_proof_mutant.v; rename ct_lsu_rb ct_lsu_rb_gate; proc; memory; opt; equiv_make ct_lsu_rb_gold ct_lsu_rb_gate equiv; hierarchy -top equiv; flatten; async2sync; dffunmap; opt; equiv_simple -seq 8; equiv_status -assert" \
  > "$OUT/proof_mutant_negative.replay.log" 2>&1; then
  echo "ERROR: proof mutant unexpectedly proved" >&2
  exit 1
fi

"$YOSYS_BIN" -p "read_verilog -sv $DEPS ct_lsu_rb_gold.v; synth -flatten -top ct_lsu_rb; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/ct_lsu_rb_gold.mapped.v" \
  > "$OUT/gold_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_verilog -sv $DEPS ct_lsu_rb_gate_candidate.v; synth -flatten -top ct_lsu_rb; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/ct_lsu_rb_gate_candidate.mapped.v" \
  > "$OUT/gate_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_verilog -sv $DEPS ct_lsu_rb_metric_negative.v; synth -flatten -top ct_lsu_rb; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/ct_lsu_rb_metric_negative.mapped.v" \
  > "$OUT/metric_negative_area.replay.log" 2>&1

echo "7794a40b6e59b810cb42f6ba349c055d224728f823d599b1a1f6ca4d1b8b672f  $OUT/ct_lsu_rb_gold.mapped.v" | sha256sum -c -
echo "3eae30fa13bfe5a01390c060ff1f4a8a656dc729059c4570836585e51754a59c  $OUT/ct_lsu_rb_gate_candidate.mapped.v" | sha256sum -c -
echo "69dcc3008ae26fc36bddc4368ac76388f5f1a8bd7511c12ca016e099ddf009a6  $OUT/ct_lsu_rb_metric_negative.mapped.v" | sha256sum -c -

write_sta_tcl() {
  local netlist="$1"
  local out="$2"
  cat > "$out" <<EOF
read_liberty {$LIBERTY}
read_verilog {$netlist}
link_design ct_lsu_rb
create_clock -period 10.0 -name lsu_special_clk [get_ports lsu_special_clk]
create_clock -period 10.0 -name forever_cpuclk [get_ports forever_cpuclk]
if {[llength [get_ports cpurst_b]] > 0} { set_false_path -from [get_ports cpurst_b] }
foreach p [all_inputs] {
  set name [get_name \$p]
  if {\$name != "lsu_special_clk" && \$name != "forever_cpuclk" && \$name != "cpurst_b"} { set_input_delay 0.0 -clock lsu_special_clk \$p }
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

write_sta_tcl "$OUT/ct_lsu_rb_gold.mapped.v" "$OUT/gold_opensta.tcl"
write_sta_tcl "$OUT/ct_lsu_rb_gate_candidate.mapped.v" "$OUT/gate_opensta.tcl"
write_sta_tcl "$OUT/ct_lsu_rb_metric_negative.mapped.v" "$OUT/metric_negative_opensta.tcl"

"$STA_BIN" -exit "$OUT/gold_opensta.tcl" > "$OUT/gold_opensta_area_timing_power.replay.log" 2>&1
"$STA_BIN" -exit "$OUT/gate_opensta.tcl" > "$OUT/gate_opensta_area_timing_power.replay.log" 2>&1
"$STA_BIN" -exit "$OUT/metric_negative_opensta.tcl" > "$OUT/metric_negative_opensta_area_timing_power.replay.log" 2>&1

grep -q "Equivalence successfully proven" "$OUT/same_state_equiv_seq8.replay.log"
grep -q "Found a total of 8 unproven" "$OUT/proof_mutant_negative.replay.log"
grep -q "ERROR: Found 8 unproven" "$OUT/proof_mutant_negative.replay.log"
grep -q "Chip area for module '\\\\ct_lsu_rb': 105329.769600" "$OUT/gold_map.replay.log"
grep -q "Chip area for module '\\\\ct_lsu_rb': 105134.582400" "$OUT/gate_map.replay.log"
grep -q "Chip area for module '\\\\ct_lsu_rb': 107648.243200" "$OUT/metric_negative_area.replay.log"
grep -q "16.76   data arrival time" "$OUT/gold_opensta_area_timing_power.replay.log"
grep -q "16.59   data arrival time" "$OUT/gate_opensta_area_timing_power.replay.log"
grep -q "18.38   data arrival time" "$OUT/metric_negative_opensta_area_timing_power.replay.log"
grep -q "Total                  4.63e-03   1.31e-03   3.63e-08   5.94e-03" "$OUT/gold_opensta_area_timing_power.replay.log"
grep -q "Total                  4.63e-03   1.29e-03   3.60e-08   5.92e-03" "$OUT/gate_opensta_area_timing_power.replay.log"
grep -q "Total                  4.67e-03   1.33e-03   3.70e-08   6.00e-03" "$OUT/metric_negative_opensta_area_timing_power.replay.log"

echo "PASS: ct_lsu_rb same-state equivalence, proof mutant, area, timing, OpenSTA estimated-power, and metric negative controls reproduced"
