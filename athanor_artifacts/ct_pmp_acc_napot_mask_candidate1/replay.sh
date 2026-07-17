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

"$YOSYS_BIN" -p "read_verilog -sv cpu_cfig.h; read_verilog -sv ct_pmp_comp_hit_gold.v; rename ct_pmp_comp_hit gold; read_verilog -sv ct_pmp_comp_hit_gate_candidate.v; rename ct_pmp_comp_hit gate; proc; opt; memory; opt; equiv_make gold gate equiv; prep -top equiv; equiv_simple; equiv_status -assert" \
  > "$OUT/helper_same_state.replay.log" 2>&1

if "$YOSYS_BIN" -p "read_verilog -sv cpu_cfig.h; read_verilog -sv ct_pmp_comp_hit_gold.v; rename ct_pmp_comp_hit gold; read_verilog -sv ct_pmp_comp_hit_gate_proof_mutant.v; rename ct_pmp_comp_hit gate; proc; opt; memory; opt; equiv_make gold gate equiv; prep -top equiv; equiv_simple; equiv_status -assert" \
  > "$OUT/helper_proof_mutant_negative.replay.log" 2>&1; then
  echo "ERROR: proof mutant unexpectedly proved" >&2
  exit 1
fi

"$YOSYS_BIN" -p "read_verilog -sv cpu_cfig.h; read_verilog -sv ct_pmp_comp_hit_gold.v; read_verilog -sv ct_pmp_acc_gold.v; hierarchy -top ct_pmp_acc; proc; opt; memory; opt; flatten; opt; rename ct_pmp_acc gold; write_rtlil $OUT/ct_pmp_acc_gold.il" \
  > "$OUT/parent_flatten_gold.replay.log" 2>&1
"$YOSYS_BIN" -p "read_verilog -sv cpu_cfig.h; read_verilog -sv ct_pmp_comp_hit_gate_candidate.v; read_verilog -sv ct_pmp_acc_gold.v; hierarchy -top ct_pmp_acc; proc; opt; memory; opt; flatten; opt; rename ct_pmp_acc gate; write_rtlil $OUT/ct_pmp_acc_gate.il" \
  > "$OUT/parent_flatten_gate.replay.log" 2>&1
"$YOSYS_BIN" -p "read_rtlil $OUT/ct_pmp_acc_gold.il; read_rtlil $OUT/ct_pmp_acc_gate.il; equiv_make gold gate equiv; prep -top equiv; equiv_simple; equiv_status -assert" \
  > "$OUT/parent_same_state.replay.log" 2>&1

"$YOSYS_BIN" -p "read_verilog -sv cpu_cfig.h; read_verilog -sv ct_pmp_comp_hit_gold.v; synth -top ct_pmp_comp_hit; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr -noexpr $OUT/ct_pmp_comp_hit_gold.mapped.v" \
  > "$OUT/helper_gold_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_verilog -sv cpu_cfig.h; read_verilog -sv ct_pmp_comp_hit_gate_candidate.v; synth -top ct_pmp_comp_hit; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr -noexpr $OUT/ct_pmp_comp_hit_gate_candidate.mapped.v" \
  > "$OUT/helper_gate_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_verilog -sv cpu_cfig.h; read_verilog -sv ct_pmp_comp_hit_gold.v; read_verilog -sv ct_pmp_acc_gold.v; synth -top ct_pmp_acc; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr -noexpr $OUT/ct_pmp_acc_gold.mapped.v" \
  > "$OUT/parent_gold_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_verilog -sv cpu_cfig.h; read_verilog -sv ct_pmp_comp_hit_gate_candidate.v; read_verilog -sv ct_pmp_acc_gold.v; synth -top ct_pmp_acc; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr -noexpr $OUT/ct_pmp_acc_gate_candidate.mapped.v" \
  > "$OUT/parent_gate_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_verilog -sv cpu_cfig.h; read_verilog -sv ct_pmp_comp_hit_metric_negative.v; read_verilog -sv ct_pmp_acc_gold.v; synth -top ct_pmp_acc; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr -noexpr $OUT/ct_pmp_acc_metric_negative.mapped.v" \
  > "$OUT/metric_negative_area.replay.log" 2>&1

echo "3f3760c3bb93ead1ecbda75692bebd00b4a9c548308da16b48a6b76ed008ddce  $OUT/ct_pmp_comp_hit_gold.mapped.v" | sha256sum -c -
echo "0fdb46a1da35af66c48e80971a7811d0cbefbcbcc2ca3935959b59217f83953a  $OUT/ct_pmp_comp_hit_gate_candidate.mapped.v" | sha256sum -c -
echo "1b04301e73985bfa0fba2df15710b9f7fb5f00e833bd0a9fe51dd1b2681e5415  $OUT/ct_pmp_acc_gold.mapped.v" | sha256sum -c -
echo "a8b9fc6c0840eab42f6d7bf12af68ba7d22573d126acf5902137322ea7d602ad  $OUT/ct_pmp_acc_gate_candidate.mapped.v" | sha256sum -c -
echo "1b04301e73985bfa0fba2df15710b9f7fb5f00e833bd0a9fe51dd1b2681e5415  $OUT/ct_pmp_acc_metric_negative.mapped.v" | sha256sum -c -

write_sta_tcl() {
  local top="$1"
  local netlist="$2"
  local out="$3"
  cat > "$out" <<EOF
read_liberty {$LIBERTY}
read_verilog {$netlist}
link_design $top
create_clock -period 10.0 -name virtual_clk
foreach p [all_inputs] { set_input_delay 0.0 -clock virtual_clk \$p }
foreach p [all_outputs] { set_output_delay 0.0 -clock virtual_clk \$p }
set_power_activity -global -activity 0.1 -duty 0.5
report_checks -path_delay max -format full_clock_expanded
report_tns
report_wns
report_power
exit
EOF
}

write_sta_tcl "ct_pmp_comp_hit" "$OUT/ct_pmp_comp_hit_gold.mapped.v" "$OUT/helper_gold_opensta.tcl"
write_sta_tcl "ct_pmp_comp_hit" "$OUT/ct_pmp_comp_hit_gate_candidate.mapped.v" "$OUT/helper_gate_opensta.tcl"
write_sta_tcl "ct_pmp_acc" "$OUT/ct_pmp_acc_gold.mapped.v" "$OUT/parent_gold_opensta.tcl"
write_sta_tcl "ct_pmp_acc" "$OUT/ct_pmp_acc_gate_candidate.mapped.v" "$OUT/parent_gate_opensta.tcl"
write_sta_tcl "ct_pmp_acc" "$OUT/ct_pmp_acc_metric_negative.mapped.v" "$OUT/metric_negative_opensta.tcl"

"$STA_BIN" -exit "$OUT/helper_gold_opensta.tcl" > "$OUT/helper_gold_opensta_area_timing_power.replay.log" 2>&1 || true
"$STA_BIN" -exit "$OUT/helper_gate_opensta.tcl" > "$OUT/helper_gate_opensta_area_timing_power.replay.log" 2>&1 || true
"$STA_BIN" -exit "$OUT/parent_gold_opensta.tcl" > "$OUT/parent_gold_opensta_area_timing_power.replay.log" 2>&1 || true
"$STA_BIN" -exit "$OUT/parent_gate_opensta.tcl" > "$OUT/parent_gate_opensta_area_timing_power.replay.log" 2>&1 || true
"$STA_BIN" -exit "$OUT/metric_negative_opensta.tcl" > "$OUT/metric_negative_opensta_area_timing_power.replay.log" 2>&1 || true

grep -q "Equivalence successfully proven" "$OUT/helper_same_state.replay.log"
grep -q "Equivalence successfully proven" "$OUT/parent_same_state.replay.log"
grep -q "Found a total of 2 unproven" "$OUT/helper_proof_mutant_negative.replay.log"
grep -q "ERROR: Found 2 unproven" "$OUT/helper_proof_mutant_negative.replay.log"
grep -Fq "Chip area for module '\\ct_pmp_comp_hit': 945.907200" "$OUT/helper_gold_map.replay.log"
grep -Fq "Chip area for module '\\ct_pmp_comp_hit': 894.608000" "$OUT/helper_gate_map.replay.log"
grep -Fq "Chip area for top module '\\ct_pmp_acc': 7826.256000" "$OUT/parent_gold_map.replay.log"
grep -Fq "Chip area for top module '\\ct_pmp_acc': 7415.862400" "$OUT/parent_gate_map.replay.log"
grep -Fq "Chip area for top module '\\ct_pmp_acc': 7826.256000" "$OUT/metric_negative_area.replay.log"
grep -q "2.24   data arrival time" "$OUT/helper_gold_opensta_area_timing_power.replay.log"
grep -q "2.57   data arrival time" "$OUT/helper_gate_opensta_area_timing_power.replay.log"
grep -q "3.58   data arrival time" "$OUT/parent_gold_opensta_area_timing_power.replay.log"
grep -q "3.51   data arrival time" "$OUT/parent_gate_opensta_area_timing_power.replay.log"
grep -q "3.58   data arrival time" "$OUT/metric_negative_opensta_area_timing_power.replay.log"
grep -q "Total                  1.16e-05   9.02e-06   2.94e-10   2.06e-05" "$OUT/helper_gold_opensta_area_timing_power.replay.log"
grep -q "Total                  1.10e-05   8.82e-06   2.60e-10   1.98e-05" "$OUT/helper_gate_opensta_area_timing_power.replay.log"
grep -q "Total                  9.60e-05   7.64e-05   2.43e-09   1.72e-04" "$OUT/parent_gold_opensta_area_timing_power.replay.log"
grep -q "Total                  9.16e-05   7.49e-05   2.16e-09   1.67e-04" "$OUT/parent_gate_opensta_area_timing_power.replay.log"
grep -q "Total                  9.60e-05   7.64e-05   2.43e-09   1.72e-04" "$OUT/metric_negative_opensta_area_timing_power.replay.log"

echo "PASS: ct_pmp_acc NAPOT-mask candidate helper proof, parent proof, proof mutant, parent/helper area, timing, OpenSTA estimated-power, and metric-negative controls reproduced"
