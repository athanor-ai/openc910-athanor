#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${YOSYS_BIN:?set YOSYS_BIN to the pinned Yosys executable}"
: "${STA_BIN:?set STA_BIN to the OpenSTA executable}"
: "${LIBERTY:?set LIBERTY to sky130_fd_sc_hd__tt_025C_1v80.lib}"

OUT="replay_out"
rm -rf "$OUT"
mkdir -p "$OUT"
cd "$ROOT"

DEPS="gated_clk_cell.v ct_rtu_expand_32.v ct_rtu_expand_96.v ct_rtu_pst_preg_entry.v"

"$YOSYS_BIN" -p "read_verilog -sv ct_rtu_encode_96_gold.v; rename ct_rtu_encode_96 gold; read_verilog -sv ct_rtu_encode_96_gate_candidate.v; rename ct_rtu_encode_96 gate; proc; opt; equiv_make gold gate equiv; hierarchy -top equiv; flatten; opt; equiv_simple; equiv_status -assert"   > "$OUT/helper_same_state_equiv.replay.log" 2>&1

if "$YOSYS_BIN" -p "read_verilog -sv ct_rtu_encode_96_gold.v; rename ct_rtu_encode_96 gold; read_verilog -sv ct_rtu_encode_96_proof_mutant.v; rename ct_rtu_encode_96 gate; proc; opt; equiv_make gold gate equiv; hierarchy -top equiv; flatten; opt; equiv_simple; equiv_status -assert"   > "$OUT/helper_proof_mutant_negative.replay.log" 2>&1; then
  echo "ERROR: helper proof mutant unexpectedly proved" >&2
  exit 1
fi

flatten_parent_for_proof() {
  local helper="$1"
  local parent="$2"
  local module_name="$3"
  local out="$4"
  "$YOSYS_BIN" -p "read_verilog -sv $DEPS $helper $parent; hierarchy -top ct_rtu_pst_preg; proc; memory; flatten; async2sync; dffunmap; opt; rename ct_rtu_pst_preg $module_name; clean; write_verilog -noattr -simple-lhs $OUT/$out" \
    > "$OUT/${out%.v}.prep.replay.log" 2>&1
}

write_generated_temp_blacklist() {
  awk '
    /^[[:space:]]*(wire|reg)[[:space:]]/ {
      line = $0
      sub(/;.*/, "", line)
      n = split(line, fields, /[[:space:]]+/)
      name = fields[n]
      sub(/^\\\\/, "", name)
      if (name ~ /^_/) print name
    }
  ' "$@" | sort -u
}

flatten_parent_for_proof ct_rtu_encode_96_gold.v ct_rtu_pst_preg_gold.v gold parent_gold_flat.v
flatten_parent_for_proof ct_rtu_encode_96_gate_candidate.v ct_rtu_pst_preg_gate_candidate.v gate parent_gate_flat.v
flatten_parent_for_proof ct_rtu_encode_96_proof_mutant.v ct_rtu_pst_preg_gate_candidate.v gate parent_gate_mutant_flat.v
write_generated_temp_blacklist \
  "$OUT/parent_gold_flat.v" \
  "$OUT/parent_gate_flat.v" \
  "$OUT/parent_gate_mutant_flat.v" \
  > "$OUT/parent_generated_temps.blacklist"

"$YOSYS_BIN" -p "read_verilog -sv $OUT/parent_gold_flat.v; read_verilog -sv $OUT/parent_gate_flat.v; proc; memory; opt; equiv_make -blacklist $OUT/parent_generated_temps.blacklist gold gate equiv; hierarchy -top equiv; flatten; async2sync; dffunmap; opt; equiv_simple -seq 8; equiv_induct -seq 8; equiv_status -assert" \
  > "$OUT/parent_same_state_equiv.replay.log" 2>&1

if "$YOSYS_BIN" -p "read_verilog -sv $OUT/parent_gold_flat.v; read_verilog -sv $OUT/parent_gate_mutant_flat.v; proc; memory; opt; equiv_make -blacklist $OUT/parent_generated_temps.blacklist gold gate equiv; hierarchy -top equiv; flatten; async2sync; dffunmap; opt; equiv_simple -seq 8; equiv_induct -seq 8; equiv_status -assert" \
  > "$OUT/parent_proof_mutant_negative.replay.log" 2>&1; then
  echo "ERROR: parent proof mutant unexpectedly proved" >&2
  exit 1
fi

"$YOSYS_BIN" -p "read_verilog -sv $DEPS ct_rtu_encode_96_gold.v ct_rtu_pst_preg_gold.v; synth -top ct_rtu_pst_preg; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/ct_rtu_pst_preg_gold.mapped.v"   > "$OUT/gold_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_verilog -sv $DEPS ct_rtu_encode_96_gate_candidate.v ct_rtu_pst_preg_gate_candidate.v; synth -top ct_rtu_pst_preg; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/ct_rtu_pst_preg_gate_candidate.mapped.v"   > "$OUT/gate_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_liberty -lib $LIBERTY; read_verilog ct_rtu_pst_preg_metric_negative.mapped.v; hierarchy -top ct_rtu_pst_preg; stat -liberty $LIBERTY"   > "$OUT/metric_negative_area.replay.log" 2>&1

echo "ff0dc6d4fa7b3750c69e6de8a2f1c9aab4d314f1860603fecfe1b07112b6c1be  $OUT/ct_rtu_pst_preg_gold.mapped.v" | sha256sum -c -
echo "793e6c02a7d10ad8c0110a9c949ddca7c86faa792d050da484c64def59f11abc  $OUT/ct_rtu_pst_preg_gate_candidate.mapped.v" | sha256sum -c -

write_sta_tcl() {
  local netlist="$1"
  local out="$2"
  cat > "$out" <<EOF
read_liberty {$LIBERTY}
read_verilog {$netlist}
link_design ct_rtu_pst_preg
if {[llength [get_ports forever_cpuclk]] > 0} { create_clock -period 10.0 -name forever_cpuclk [get_ports forever_cpuclk] }
foreach rst {cpurst_b ifu_xx_sync_reset} {
  if {[llength [get_ports \$rst]] > 0} { set_false_path -from [get_ports \$rst] }
}
foreach p [all_inputs] {
  set name [get_name \$p]
  if {\$name != "forever_cpuclk" && \$name != "cpurst_b" && \$name != "ifu_xx_sync_reset"} { set_input_delay 0.0 -clock forever_cpuclk \$p }
}
foreach p [all_outputs] { set_output_delay 0.0 -clock forever_cpuclk \$p }
set_power_activity -global -activity 0.1 -duty 0.5
report_checks -path_delay max -format full_clock_expanded
report_tns
report_wns
report_power
exit
EOF
}

write_sta_tcl "$OUT/ct_rtu_pst_preg_gold.mapped.v" "$OUT/gold_opensta.tcl"
write_sta_tcl "$OUT/ct_rtu_pst_preg_gate_candidate.mapped.v" "$OUT/gate_opensta.tcl"
write_sta_tcl "$ROOT/ct_rtu_pst_preg_metric_negative.mapped.v" "$OUT/metric_negative_opensta.tcl"

"$STA_BIN" -exit "$OUT/gold_opensta.tcl" > "$OUT/gold_opensta_area_timing_power.replay.log" 2>&1
"$STA_BIN" -exit "$OUT/gate_opensta.tcl" > "$OUT/gate_opensta_area_timing_power.replay.log" 2>&1
"$STA_BIN" -exit "$OUT/metric_negative_opensta.tcl" > "$OUT/metric_negative_opensta_area_timing_power.replay.log" 2>&1

grep -qF "Equivalence successfully proven" "$OUT/helper_same_state_equiv.replay.log"
grep -qF "Found a total of 1 unproven" "$OUT/helper_proof_mutant_negative.replay.log"
grep -qF "Of those cells 31716 are proven and 0 are unproven" "$OUT/parent_same_state_equiv.replay.log"
grep -qF "Equivalence successfully proven" "$OUT/parent_same_state_equiv.replay.log"
grep -qF "Of those cells 31681 are proven and 35 are unproven" "$OUT/parent_proof_mutant_negative.replay.log"
grep -qF "Found a total of 35 unproven" "$OUT/parent_proof_mutant_negative.replay.log"
grep -qF "Chip area for top module '\\ct_rtu_pst_preg': 384860.361600" "$OUT/gold_map.replay.log"
grep -qF "Chip area for top module '\\ct_rtu_pst_preg': 383196.265600" "$OUT/gate_map.replay.log"
grep -qF "Chip area for top module '\\ct_rtu_pst_preg': 385838.800000" "$OUT/metric_negative_area.replay.log"
grep -qF "11.31   data arrival time" "$OUT/gold_opensta_area_timing_power.replay.log"
grep -qF "11.35   data arrival time" "$OUT/gate_opensta_area_timing_power.replay.log"
grep -qF "18.57   data arrival time" "$OUT/metric_negative_opensta_area_timing_power.replay.log"
grep -qF "Total                  9.92e-03   5.16e-03   1.30e-07   1.51e-02" "$OUT/gold_opensta_area_timing_power.replay.log"
grep -qF "Total                  9.90e-03   5.13e-03   1.29e-07   1.50e-02" "$OUT/gate_opensta_area_timing_power.replay.log"
grep -qF "Total                  1.19e-02   5.58e-03   1.31e-07   1.75e-02" "$OUT/metric_negative_opensta_area_timing_power.replay.log"

echo "PASS: ct_rtu_pst_preg encoder-family helper proof, parent-table proof, proof mutants, parent area, OpenSTA timing regression, OpenSTA estimated-power, and metric negative controls reproduced"
