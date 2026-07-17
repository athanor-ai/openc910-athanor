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

normalize_top() {
  local comp_hit="$1"
  local regs="$2"
  local top="$3"
  local name="$4"
  local log="$5"
  "$YOSYS_BIN" -p "read_verilog -sv cpu_cfig.h; read_verilog -sv gated_clk_cell.v $comp_hit ct_pmp_acc_gold.v $regs $top; hierarchy -top ct_pmp_top; proc; opt; memory; flatten; opt; async2sync; dffunmap; opt_clean; rename ct_pmp_top $name; write_rtlil $OUT/${name}_norm.il" \
    > "$OUT/$log" 2>&1
}

normalize_top ct_pmp_comp_hit_gold.v ct_pmp_regs_gold.v ct_pmp_top_gold.v gold normalize_gold.replay.log
normalize_top ct_pmp_comp_hit_gate_candidate.v ct_pmp_regs_gold.v ct_pmp_top_gold.v gate normalize_gate.replay.log
"$YOSYS_BIN" -p "read_rtlil $OUT/gold_norm.il; read_rtlil $OUT/gate_norm.il; equiv_make gold gate equiv; prep -top equiv; equiv_simple -seq 1; equiv_induct -seq 1; equiv_status -assert" \
  > "$OUT/ct_pmp_top_same_state.replay.log" 2>&1

normalize_top ct_pmp_comp_hit_gate_proof_mutant.v ct_pmp_regs_gold.v ct_pmp_top_gold.v gate normalize_mutant_gate.replay.log
if "$YOSYS_BIN" -p "read_rtlil $OUT/gold_norm.il; read_rtlil $OUT/gate_norm.il; equiv_make gold gate equiv; prep -top equiv; equiv_simple -seq 1; equiv_induct -seq 1; equiv_status -assert" \
  > "$OUT/ct_pmp_top_proof_mutant_negative.replay.log" 2>&1; then
  echo "ERROR: proof mutant unexpectedly proved" >&2
  exit 1
fi

map_top() {
  local comp_hit="$1"
  local regs="$2"
  local top="$3"
  local out_v="$4"
  local log="$5"
  "$YOSYS_BIN" -p "read_liberty -lib $LIBERTY; read_verilog -sv cpu_cfig.h gated_clk_cell.v $comp_hit ct_pmp_acc_gold.v $regs $top; synth -top ct_pmp_top; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean -purge; rename -unescape; stat -liberty $LIBERTY; write_verilog -simple-lhs -noattr $OUT/$out_v" \
    > "$OUT/$log" 2>&1
}

map_top ct_pmp_comp_hit_gold.v ct_pmp_regs_gold.v ct_pmp_top_gold.v ct_pmp_top_gold.mapped.v ct_pmp_top_gold_map.replay.log
map_top ct_pmp_comp_hit_gate_candidate.v ct_pmp_regs_gold.v ct_pmp_top_gold.v ct_pmp_top_gate_candidate.mapped.v ct_pmp_top_gate_map.replay.log
map_top ct_pmp_comp_hit_gate_candidate.v ct_pmp_regs_metric_negative.v ct_pmp_top_metric_negative.v ct_pmp_top_metric_negative.mapped.v metric_negative_area.replay.log

echo "f8adf118d123a6efdc27f2839ab96f9d1e36874c8f2efc672528861bd230d74a  $OUT/ct_pmp_top_gold.mapped.v" | sha256sum -c -
echo "f5c17dce321c3b897020f3ebdaa8c752120d22adf5859b23ba5c95e8ea41ae07  $OUT/ct_pmp_top_gate_candidate.mapped.v" | sha256sum -c -
echo "7f439ab05f8177d671e3f9e8a73228ff66c35dc13e6720104c61f0deacb1d990  $OUT/ct_pmp_top_metric_negative.mapped.v" | sha256sum -c -

write_sta_tcl() {
  local netlist="$1"
  local out="$2"
  cat > "$out" <<EOF
read_liberty $LIBERTY
read_verilog $netlist
link_design ct_pmp_top
create_clock -name forever_cpuclk -period 10 [get_ports forever_cpuclk]
set_propagated_clock [all_clocks]
report_checks -path_delay max -fields {slew cap input_pin net} -digits 4
report_wns
report_tns
report_power
EOF
}

write_sta_tcl "$OUT/ct_pmp_top_gold.mapped.v" "$OUT/ct_pmp_top_gold_opensta.tcl"
write_sta_tcl "$OUT/ct_pmp_top_gate_candidate.mapped.v" "$OUT/ct_pmp_top_gate_opensta.tcl"
write_sta_tcl "$OUT/ct_pmp_top_metric_negative.mapped.v" "$OUT/metric_negative_opensta.tcl"

"$STA_BIN" "$OUT/ct_pmp_top_gold_opensta.tcl" > "$OUT/ct_pmp_top_gold_opensta_area_timing_power.replay.log" 2>&1
"$STA_BIN" "$OUT/ct_pmp_top_gate_opensta.tcl" > "$OUT/ct_pmp_top_gate_opensta_area_timing_power.replay.log" 2>&1
"$STA_BIN" "$OUT/metric_negative_opensta.tcl" > "$OUT/metric_negative_opensta_area_timing_power.replay.log" 2>&1

grep -q "Equivalence successfully proven" "$OUT/ct_pmp_top_same_state.replay.log"
grep -q "Of those cells 831 are proven and 0 are unproven" "$OUT/ct_pmp_top_same_state.replay.log"
grep -q "Found a total of 48 unproven" "$OUT/ct_pmp_top_proof_mutant_negative.replay.log"
grep -q "ERROR: Found 48 unproven" "$OUT/ct_pmp_top_proof_mutant_negative.replay.log"
grep -Fq "Chip area for top module '\\ct_pmp_top': 50325.766400" "$OUT/ct_pmp_top_gold_map.replay.log"
grep -Fq "Chip area for top module '\\ct_pmp_top': 49474.950400" "$OUT/ct_pmp_top_gate_map.replay.log"
grep -Fq "Chip area for top module '\\ct_pmp_top': 63387.043200" "$OUT/metric_negative_area.replay.log"
grep -q "3.2370   data arrival time" "$OUT/ct_pmp_top_gold_opensta_area_timing_power.replay.log"
grep -q "3.2370   data arrival time" "$OUT/ct_pmp_top_gate_opensta_area_timing_power.replay.log"
grep -q "7.3389   data arrival time" "$OUT/metric_negative_opensta_area_timing_power.replay.log"
grep -q "Total                  1.21e-03   7.11e-04   1.66e-08   1.92e-03" "$OUT/ct_pmp_top_gold_opensta_area_timing_power.replay.log"
grep -q "Total                  1.20e-03   7.01e-04   1.50e-08   1.90e-03" "$OUT/ct_pmp_top_gate_opensta_area_timing_power.replay.log"
grep -q "Total                  1.52e-03   1.03e-03   2.09e-08   2.56e-03" "$OUT/metric_negative_opensta_area_timing_power.replay.log"

echo "PASS: ct_pmp_top NAPOT-mask candidate proof, proof mutant, subsystem area/power/timing screen, and three-axis metric-negative control reproduced"
