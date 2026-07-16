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

EQ_CMD='read_verilog -sv ct_rtu_compare_iid_gold.v; rename ct_rtu_compare_iid ct_rtu_compare_iid_gold; read_verilog -sv ct_rtu_compare_iid_gate_candidate.v; proc; opt; equiv_make ct_rtu_compare_iid_gold ct_rtu_compare_iid equiv; hierarchy -top equiv; flatten; opt; equiv_simple; equiv_status -assert'
MUTANT_CMD='read_verilog -sv ct_rtu_compare_iid_gold.v; rename ct_rtu_compare_iid ct_rtu_compare_iid_gold; read_verilog -sv ct_rtu_compare_iid_gate_proof_mutant.v; proc; opt; equiv_make ct_rtu_compare_iid_gold ct_rtu_compare_iid equiv; hierarchy -top equiv; flatten; opt; equiv_simple; equiv_status -assert'

"$YOSYS_BIN" -p "$EQ_CMD" > "$OUT/same_state_equiv.replay.log" 2>&1

if "$YOSYS_BIN" -p "$MUTANT_CMD" > "$OUT/proof_mutant_negative.replay.log" 2>&1; then
  echo "ERROR: proof mutant unexpectedly proved" >&2
  exit 1
fi

"$YOSYS_BIN" -p "read_verilog -sv ct_rtu_compare_iid_gold.v; synth -top ct_rtu_compare_iid; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr -simple-lhs $OUT/ct_rtu_compare_iid_gold.mapped.v" \
  > "$OUT/helper_gold_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_verilog -sv ct_rtu_compare_iid_gate_candidate.v; synth -top ct_rtu_compare_iid; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr -simple-lhs $OUT/ct_rtu_compare_iid_gate_candidate.mapped.v" \
  > "$OUT/helper_gate_map.replay.log" 2>&1

flatten_pfu_parent_for_proof() {
  local helper="$1"
  local module_name="$2"
  local out="$3"
  "$YOSYS_BIN" -p "read_verilog -sv -D PA_WIDTH=40 gated_clk_cell.v $helper ct_lsu_pfu_sdb_cmp.v; hierarchy -top ct_lsu_pfu_sdb_cmp; proc; memory; flatten; async2sync; dffunmap; opt; rename ct_lsu_pfu_sdb_cmp $module_name; clean; write_verilog -noattr -simple-lhs $OUT/$out" \
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

flatten_pfu_parent_for_proof ct_rtu_compare_iid_gold.v gold pfu_parent_gold_flat.v
flatten_pfu_parent_for_proof ct_rtu_compare_iid_gate_candidate.v gate pfu_parent_gate_flat.v
flatten_pfu_parent_for_proof ct_rtu_compare_iid_gate_proof_mutant.v gate pfu_parent_gate_mutant_flat.v
write_generated_temp_blacklist \
  "$OUT/pfu_parent_gold_flat.v" \
  "$OUT/pfu_parent_gate_flat.v" \
  "$OUT/pfu_parent_gate_mutant_flat.v" \
  > "$OUT/pfu_parent_generated_temps.blacklist"

"$YOSYS_BIN" -p "read_verilog -sv $OUT/pfu_parent_gold_flat.v; read_verilog -sv $OUT/pfu_parent_gate_flat.v; proc; memory; opt; equiv_make -blacklist $OUT/pfu_parent_generated_temps.blacklist gold gate equiv; hierarchy -top equiv; flatten; async2sync; dffunmap; opt; equiv_simple -seq 8; equiv_induct -seq 8; equiv_status -assert" \
  > "$OUT/pfu_parent_same_state_equiv.replay.log" 2>&1

if "$YOSYS_BIN" -p "read_verilog -sv $OUT/pfu_parent_gold_flat.v; read_verilog -sv $OUT/pfu_parent_gate_mutant_flat.v; proc; memory; opt; equiv_make -blacklist $OUT/pfu_parent_generated_temps.blacklist gold gate equiv; hierarchy -top equiv; flatten; async2sync; dffunmap; opt; equiv_simple -seq 8; equiv_induct -seq 8; equiv_status -assert" \
  > "$OUT/pfu_parent_proof_mutant_negative.replay.log" 2>&1; then
  echo "ERROR: pfu parent proof mutant unexpectedly proved" >&2
  exit 1
fi

map_parent() {
  local top="$1"
  local helper="$2"
  local out="$3"
  local log="$4"
  "$YOSYS_BIN" -p "read_verilog -sv -D PA_WIDTH=40 gated_clk_cell.v $helper ${top}.v; synth -top $top; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/$out" \
    > "$OUT/$log" 2>&1
}

map_parent ct_lsu_spec_fail_predict ct_rtu_compare_iid_gold.v ct_lsu_spec_fail_predict_gold.mapped.v spec_fail_predict_gold_map.replay.log
map_parent ct_lsu_spec_fail_predict ct_rtu_compare_iid_gate_candidate.v ct_lsu_spec_fail_predict_gate.mapped.v spec_fail_predict_gate_map.replay.log
map_parent ct_lsu_spec_fail_predict ct_rtu_compare_iid_metric_negative.v ct_lsu_spec_fail_predict_metric_negative.mapped.v spec_fail_predict_metric_negative_map.replay.log
map_parent ct_lsu_pfu_sdb_cmp ct_rtu_compare_iid_gold.v ct_lsu_pfu_sdb_cmp_gold.mapped.v pfu_sdb_cmp_gold_map.replay.log
map_parent ct_lsu_pfu_sdb_cmp ct_rtu_compare_iid_gate_candidate.v ct_lsu_pfu_sdb_cmp_gate.mapped.v pfu_sdb_cmp_gate_map.replay.log
map_parent ct_lsu_pfu_sdb_cmp ct_rtu_compare_iid_metric_negative.v ct_lsu_pfu_sdb_cmp_metric_negative.mapped.v pfu_sdb_cmp_metric_negative_map.replay.log

echo "253b9875c6451919d2f13940ae5a3582730bf787a8e9b7b592fc9659c6000beb  $OUT/ct_rtu_compare_iid_gold.mapped.v" | sha256sum -c -
echo "e85f7daf3d85c1ae187988ad67530a4c56656cff532094b69eea05d6b0484524  $OUT/ct_rtu_compare_iid_gate_candidate.mapped.v" | sha256sum -c -
echo "25dc4da90a7a5c52a01688b2afc034dc1e8d2aead01907a077381bd0d71e7923  $OUT/ct_lsu_spec_fail_predict_gold.mapped.v" | sha256sum -c -
echo "59096de1f8c21256d043a6f8def8af7779ff6fe7f0bf36fd12da85c01f0a32f7  $OUT/ct_lsu_spec_fail_predict_gate.mapped.v" | sha256sum -c -
echo "57f78f84f42bf2b01f8e5829d2177964459c5bffeafca924566f493dc1b1381d  $OUT/ct_lsu_spec_fail_predict_metric_negative.mapped.v" | sha256sum -c -
echo "7269eddd214e906623921026d340673dd3bd9db2d5fc54769cc7108a9d206538  $OUT/ct_lsu_pfu_sdb_cmp_gold.mapped.v" | sha256sum -c -
echo "94f92c27e4812e3fb1b13c78c832c1e1843853fc1cd789240ca01b7ce9d6ebc1  $OUT/ct_lsu_pfu_sdb_cmp_gate.mapped.v" | sha256sum -c -
echo "35c76c777ddeff2f534af62d16e743c7fbf329dbd59e6e2d842603f979a17a66  $OUT/ct_lsu_pfu_sdb_cmp_metric_negative.mapped.v" | sha256sum -c -

write_sta_tcl() {
  local top="$1"
  local netlist="$2"
  local out="$3"
  cat > "$out" <<EOF
read_liberty {$LIBERTY}
read_verilog {$netlist}
link_design $top
set clock_name virtual_clk
set created_clock 0
foreach c {forever_cpuclk entry_clk lsu_special_clk} {
  if {[llength [get_ports \$c]] > 0} {
    create_clock -period 10.0 -name \$c [get_ports \$c]
    if {\$created_clock == 0} {
      set clock_name \$c
      set created_clock 1
    }
  }
}
if {\$created_clock == 0} {
  create_clock -period 10.0 -name virtual_clk
}
foreach rst {cpurst_b rst_b ifu_xx_sync_reset} {
  if {[llength [get_ports \$rst]] > 0} { set_false_path -from [get_ports \$rst] }
}
foreach p [all_inputs] {
  set name [get_name \$p]
  if {\$name != "forever_cpuclk" && \$name != "entry_clk" && \$name != "lsu_special_clk" && \$name != "cpurst_b" && \$name != "rst_b" && \$name != "ifu_xx_sync_reset"} {
    set_input_delay 0.0 -clock \$clock_name \$p
  }
}
foreach p [all_outputs] { set_output_delay 0.0 -clock \$clock_name \$p }
set_power_activity -global -activity 0.1 -duty 0.5
report_checks -path_delay max -format full_clock_expanded
report_tns
report_wns
report_power
exit
EOF
}

write_sta_tcl ct_lsu_spec_fail_predict "$OUT/ct_lsu_spec_fail_predict_gold.mapped.v" "$OUT/spec_fail_predict_gold_opensta.tcl"
write_sta_tcl ct_lsu_spec_fail_predict "$OUT/ct_lsu_spec_fail_predict_gate.mapped.v" "$OUT/spec_fail_predict_gate_opensta.tcl"
write_sta_tcl ct_lsu_spec_fail_predict "$OUT/ct_lsu_spec_fail_predict_metric_negative.mapped.v" "$OUT/spec_fail_predict_metric_negative_opensta.tcl"
write_sta_tcl ct_lsu_pfu_sdb_cmp "$OUT/ct_lsu_pfu_sdb_cmp_gold.mapped.v" "$OUT/pfu_sdb_cmp_gold_opensta.tcl"
write_sta_tcl ct_lsu_pfu_sdb_cmp "$OUT/ct_lsu_pfu_sdb_cmp_gate.mapped.v" "$OUT/pfu_sdb_cmp_gate_opensta.tcl"
write_sta_tcl ct_lsu_pfu_sdb_cmp "$OUT/ct_lsu_pfu_sdb_cmp_metric_negative.mapped.v" "$OUT/pfu_sdb_cmp_metric_negative_opensta.tcl"

"$STA_BIN" -exit "$OUT/spec_fail_predict_gold_opensta.tcl" > "$OUT/spec_fail_predict_gold_opensta_area_timing_power.replay.log" 2>&1
"$STA_BIN" -exit "$OUT/spec_fail_predict_gate_opensta.tcl" > "$OUT/spec_fail_predict_gate_opensta_area_timing_power.replay.log" 2>&1
"$STA_BIN" -exit "$OUT/spec_fail_predict_metric_negative_opensta.tcl" > "$OUT/spec_fail_predict_metric_negative_opensta_area_timing_power.replay.log" 2>&1
"$STA_BIN" -exit "$OUT/pfu_sdb_cmp_gold_opensta.tcl" > "$OUT/pfu_sdb_cmp_gold_opensta_area_timing_power.replay.log" 2>&1
"$STA_BIN" -exit "$OUT/pfu_sdb_cmp_gate_opensta.tcl" > "$OUT/pfu_sdb_cmp_gate_opensta_area_timing_power.replay.log" 2>&1
"$STA_BIN" -exit "$OUT/pfu_sdb_cmp_metric_negative_opensta.tcl" > "$OUT/pfu_sdb_cmp_metric_negative_opensta_area_timing_power.replay.log" 2>&1

grep -q "Equivalence successfully proven" "$OUT/same_state_equiv.replay.log"
grep -q "Found a total of 1 unproven" "$OUT/proof_mutant_negative.replay.log"
grep -q "Of those cells 366 are proven and 0 are unproven" "$OUT/pfu_parent_same_state_equiv.replay.log"
grep -q "Equivalence successfully proven" "$OUT/pfu_parent_same_state_equiv.replay.log"
grep -q "Of those cells 363 are proven and 3 are unproven" "$OUT/pfu_parent_proof_mutant_negative.replay.log"
grep -q "Found a total of 3 unproven" "$OUT/pfu_parent_proof_mutant_negative.replay.log"
grep -q "Chip area for module '\\\\ct_rtu_compare_iid': 142.636800" "$OUT/helper_gold_map.replay.log"
grep -q "Chip area for module '\\\\ct_rtu_compare_iid': 127.622400" "$OUT/helper_gate_map.replay.log"
grep -q "Chip area for top module '\\\\ct_lsu_spec_fail_predict': 6576.307200" "$OUT/spec_fail_predict_gold_map.replay.log"
grep -q "Chip area for top module '\\\\ct_lsu_spec_fail_predict': 6546.278400" "$OUT/spec_fail_predict_gate_map.replay.log"
grep -q "Chip area for top module '\\\\ct_lsu_spec_fail_predict': 8087.756800" "$OUT/spec_fail_predict_metric_negative_map.replay.log"
grep -q "Chip area for top module '\\\\ct_lsu_pfu_sdb_cmp': 11684.956800" "$OUT/pfu_sdb_cmp_gold_map.replay.log"
grep -q "Chip area for top module '\\\\ct_lsu_pfu_sdb_cmp': 11639.913600" "$OUT/pfu_sdb_cmp_gate_map.replay.log"
grep -q "Chip area for top module '\\\\ct_lsu_pfu_sdb_cmp': 13952.131200" "$OUT/pfu_sdb_cmp_metric_negative_map.replay.log"
grep -q "4.73   data arrival time" "$OUT/spec_fail_predict_gold_opensta_area_timing_power.replay.log"
grep -q "4.67   data arrival time" "$OUT/spec_fail_predict_gate_opensta_area_timing_power.replay.log"
grep -q "7.74   data arrival time" "$OUT/spec_fail_predict_metric_negative_opensta_area_timing_power.replay.log"
grep -q "7.00   data arrival time" "$OUT/pfu_sdb_cmp_gold_opensta_area_timing_power.replay.log"
grep -q "6.91   data arrival time" "$OUT/pfu_sdb_cmp_gate_opensta_area_timing_power.replay.log"
grep -q "8.14   data arrival time" "$OUT/pfu_sdb_cmp_gold_opensta_area_timing_power.replay.log"
grep -q "8.14   data arrival time" "$OUT/pfu_sdb_cmp_gate_opensta_area_timing_power.replay.log"
grep -q "10.05   data arrival time" "$OUT/pfu_sdb_cmp_metric_negative_opensta_area_timing_power.replay.log"
grep -q "Total                  3.26e-04   5.23e-05   2.33e-09   3.79e-04" "$OUT/spec_fail_predict_gold_opensta_area_timing_power.replay.log"
grep -q "Total                  3.26e-04   5.22e-05   2.32e-09   3.78e-04" "$OUT/spec_fail_predict_gate_opensta_area_timing_power.replay.log"
grep -q "Total                  3.45e-04   7.79e-05   2.91e-09   4.23e-04" "$OUT/spec_fail_predict_metric_negative_opensta_area_timing_power.replay.log"
grep -q "Total                  4.57e-04   1.34e-04   4.17e-09   5.92e-04" "$OUT/pfu_sdb_cmp_gold_opensta_area_timing_power.replay.log"
grep -q "Total                  4.57e-04   1.34e-04   4.15e-09   5.91e-04" "$OUT/pfu_sdb_cmp_gate_opensta_area_timing_power.replay.log"
grep -q "Total                  4.85e-04   1.73e-04   5.03e-09   6.57e-04" "$OUT/pfu_sdb_cmp_metric_negative_opensta_area_timing_power.replay.log"

echo "PASS: ct_rtu_compare_iid helper equivalence, pfu parent same-state proof, equality-boundary mutants, two LSU parent area/timing/OpenSTA-estimated-power screens, and metric negative controls reproduced"
