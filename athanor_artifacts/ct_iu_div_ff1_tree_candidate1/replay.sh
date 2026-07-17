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

DEPS="cpu_cfig.h gated_clk_cell.v ct_vfdsu_srt_radix16_bound_table.v ct_vfdsu_srt_radix16_only_div.v ct_iu_div_entry.v ct_iu_div_srt_radix16.v"

"$YOSYS_BIN" -p "read_verilog -sv $DEPS ct_iu_div_gold.v; rename ct_iu_div ct_iu_div_gold; read_verilog -sv ct_iu_div_gate_candidate.v; rename ct_iu_div ct_iu_div_gate; proc; memory; opt; equiv_make ct_iu_div_gold ct_iu_div_gate equiv; hierarchy -top equiv; flatten; async2sync; dffunmap; opt; equiv_simple -seq 8; equiv_induct -seq 8; equiv_status -assert"   > "$OUT/same_state_equiv_seq8.replay.log" 2>&1

if "$YOSYS_BIN" -p "read_verilog -sv $DEPS ct_iu_div_gold.v; rename ct_iu_div ct_iu_div_gold; read_verilog -sv ct_iu_div_gate_proof_mutant.v; rename ct_iu_div ct_iu_div_gate; proc; memory; opt; equiv_make ct_iu_div_gold ct_iu_div_gate equiv; hierarchy -top equiv; flatten; async2sync; dffunmap; opt; equiv_simple -seq 8; equiv_induct -seq 8; equiv_status -assert"   > "$OUT/proof_mutant_negative.replay.log" 2>&1; then
  echo "ERROR: proof mutant unexpectedly proved" >&2
  exit 1
fi

"$YOSYS_BIN" -p "read_verilog -sv $DEPS ct_iu_div_gold.v; synth -flatten -top ct_iu_div; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/ct_iu_div_gold.mapped.v"   > "$OUT/gold_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_verilog -sv $DEPS ct_iu_div_gate_candidate.v; synth -flatten -top ct_iu_div; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/ct_iu_div_gate_candidate.mapped.v"   > "$OUT/gate_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_verilog -sv $DEPS ct_iu_div_metric_negative.v; synth -flatten -top ct_iu_div; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/ct_iu_div_metric_negative.mapped.v"   > "$OUT/metric_negative_area.replay.log" 2>&1

echo "718db47e41bbf6254819f33eabe4311e0625c2161cb82d6c2e230d003cf72c63  $OUT/ct_iu_div_gold.mapped.v" | sha256sum -c -
echo "18768bfcaf48275a9e124fa3c0959247fc9ad56d52b642a4691ac633faaff944  $OUT/ct_iu_div_gate_candidate.mapped.v" | sha256sum -c -
echo "2e47d7c23f9ace1c682a5d36a53b35f43b867681e48550e79536dd731aa6694e  $OUT/ct_iu_div_metric_negative.mapped.v" | sha256sum -c -

write_sta_tcl() {
  local netlist="$1"
  local out="$2"
  cat > "$out" <<EOF
read_liberty {$LIBERTY}
read_verilog {$netlist}
link_design ct_iu_div
create_clock -period 10.0 -name forever_cpuclk [get_ports forever_cpuclk]
if {[llength [get_ports cpurst_b]] > 0} { set_false_path -from [get_ports cpurst_b] }
foreach p [all_inputs] {
  set name [get_name \$p]
  if {\$name != "forever_cpuclk" && \$name != "cpurst_b"} { set_input_delay 0.0 -clock forever_cpuclk \$p }
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

write_sta_tcl "$OUT/ct_iu_div_gold.mapped.v" "$OUT/gold_opensta.tcl"
write_sta_tcl "$OUT/ct_iu_div_gate_candidate.mapped.v" "$OUT/gate_opensta.tcl"
write_sta_tcl "$OUT/ct_iu_div_metric_negative.mapped.v" "$OUT/metric_negative_opensta.tcl"

"$STA_BIN" -exit "$OUT/gold_opensta.tcl" > "$OUT/gold_opensta_area_timing_power.replay.log" 2>&1 || true
"$STA_BIN" -exit "$OUT/gate_opensta.tcl" > "$OUT/gate_opensta_area_timing_power.replay.log" 2>&1 || true
"$STA_BIN" -exit "$OUT/metric_negative_opensta.tcl" > "$OUT/metric_negative_opensta_area_timing_power.replay.log" 2>&1 || true

grep -q "Equivalence successfully proven" "$OUT/same_state_equiv_seq8.replay.log"
grep -q "Found a total of 2 unproven" "$OUT/proof_mutant_negative.replay.log"
grep -q "ERROR: Found 2 unproven" "$OUT/proof_mutant_negative.replay.log"
grep -Fq "Chip area for module '\ct_iu_div': 158090.371200" "$OUT/gold_map.replay.log"
grep -Fq "Chip area for module '\ct_iu_div': 156941.769600" "$OUT/gate_map.replay.log"
grep -Fq "Chip area for module '\ct_iu_div': 159225.209600" "$OUT/metric_negative_area.replay.log"
grep -q "39.67   data arrival time" "$OUT/gold_opensta_area_timing_power.replay.log"
grep -q "34.03   data arrival time" "$OUT/gate_opensta_area_timing_power.replay.log"
grep -q "46.01   data arrival time" "$OUT/metric_negative_opensta_area_timing_power.replay.log"
grep -q "Total                  4.37e-03   2.69e-03   5.12e-08   7.06e-03" "$OUT/gold_opensta_area_timing_power.replay.log"
grep -q "Total                  4.35e-03   2.67e-03   5.09e-08   7.03e-03" "$OUT/gate_opensta_area_timing_power.replay.log"
grep -q "Total                  4.42e-03   2.72e-03   5.19e-08   7.14e-03" "$OUT/metric_negative_opensta_area_timing_power.replay.log"

echo "PASS: ct_iu_div FF1-tree candidate proof, proof mutant, area, timing, OpenSTA estimated-power, and metric-negative controls reproduced"
