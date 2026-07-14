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

"$YOSYS_BIN" -p 'read_verilog -formal -sv ct_prio_gold.v ct_prio_gate_candidate.v ct_prio_output_miter.sv; prep -top ct_prio_output_miter; flatten; async2sync; dffunmap; opt; sat -seq 8 -tempinduct -set-at 1 rst_b 0 -set-at 2 rst_b 1 -prove-asserts -verify' \
  > "$OUT/output_miter_proof.replay.log" 2>&1

if "$YOSYS_BIN" -p 'read_verilog -formal -sv ct_prio_gold.v ct_prio_gate_proof_mutant.v ct_prio_output_miter.sv; prep -top ct_prio_output_miter; flatten; async2sync; dffunmap; opt; sat -seq 8 -tempinduct -set-at 1 rst_b 0 -set-at 2 rst_b 1 -prove-asserts -verify' \
  > "$OUT/proof_mutant_negative.replay.log" 2>&1; then
  echo "ERROR: proof mutant unexpectedly proved" >&2
  exit 1
fi

"$YOSYS_BIN" -p "read_verilog -sv ct_prio_gold.v; synth -flatten -top ct_prio; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/ct_prio_gold.mapped.v" \
  > "$OUT/gold_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_verilog -sv ct_prio_gate_candidate.v; synth -flatten -top ct_prio_gate; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/ct_prio_gate_candidate.mapped.v" \
  > "$OUT/gate_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_liberty -lib $LIBERTY; read_verilog ct_prio_metric_negative.mapped.v; hierarchy -top ct_prio_gate; stat -liberty $LIBERTY" \
  > "$OUT/metric_negative_area.replay.log" 2>&1

echo "6bd565c238906c7bb011bba8fc0342f53522f304f84502d6ec7e564814ccfcaf  $OUT/ct_prio_gold.mapped.v" | sha256sum -c -
echo "cd38c2a5134b06248e151bbf8a40c1c210e8ddfb97e26585aadb7e87e18be250  $OUT/ct_prio_gate_candidate.mapped.v" | sha256sum -c -

write_sta_tcl() {
  local netlist="$1"
  local top="$2"
  local out="$3"
  cat > "$out" <<EOF
read_liberty {$LIBERTY}
read_verilog {$netlist}
link_design $top
create_clock -period 10.0 -name clk [get_ports clk]
set_false_path -from [get_ports rst_b]
set_input_delay 0.0 -clock clk [get_ports clr]
set_input_delay 0.0 -clock clk [get_ports {valid[0]}]
set_input_delay 0.0 -clock clk [get_ports {valid[1]}]
set_output_delay 0.0 -clock clk [get_ports {sel[0]}]
set_output_delay 0.0 -clock clk [get_ports {sel[1]}]
set_power_activity -global -activity 0.1 -duty 0.5
report_units
report_checks -path_delay min_max -format full_clock_expanded
report_tns
report_wns
report_power
exit
EOF
}

write_sta_tcl "$OUT/ct_prio_gold.mapped.v" ct_prio "$OUT/gold_opensta.tcl"
write_sta_tcl "$OUT/ct_prio_gate_candidate.mapped.v" ct_prio_gate "$OUT/gate_opensta.tcl"
write_sta_tcl "$ROOT/ct_prio_metric_negative.mapped.v" ct_prio_gate "$OUT/metric_negative_opensta.tcl"

"$STA_BIN" -exit "$OUT/gold_opensta.tcl" > "$OUT/gold_opensta_area_timing_power.replay.log" 2>&1
"$STA_BIN" -exit "$OUT/gate_opensta.tcl" > "$OUT/gate_opensta_area_timing_power.replay.log" 2>&1
"$STA_BIN" -exit "$OUT/metric_negative_opensta.tcl" > "$OUT/metric_negative_opensta_area_timing_power.replay.log" 2>&1

grep -q "Induction step proven: SUCCESS" "$OUT/output_miter_proof.replay.log"
grep -q "proof did fail" "$OUT/proof_mutant_negative.replay.log"
grep -q "Chip area for module '\\\\ct_prio': 158.902400" "$OUT/gold_map.replay.log"
grep -q "Chip area for module '\\\\ct_prio_gate': 60.057600" "$OUT/gate_map.replay.log"
grep -q "Chip area for module '\\\\ct_prio_gate': 390.374400" "$OUT/metric_negative_area.replay.log"
grep -q "0.85   data arrival time" "$OUT/gold_opensta_area_timing_power.replay.log"
grep -q "0.67   data arrival time" "$OUT/gate_opensta_area_timing_power.replay.log"
grep -q "2.45   data arrival time" "$OUT/metric_negative_opensta_area_timing_power.replay.log"
grep -q "Total                  9.85e-06   9.16e-07   6.13e-11   1.08e-05" "$OUT/gold_opensta_area_timing_power.replay.log"
grep -q "Total                  2.60e-06   2.92e-07   2.01e-11   2.89e-06" "$OUT/gate_opensta_area_timing_power.replay.log"
grep -q "Total                  1.53e-05   3.14e-06   1.72e-10   1.84e-05" "$OUT/metric_negative_opensta_area_timing_power.replay.log"

echo "PASS: ct_prio area, timing, OpenSTA estimated-power, output proof, proof mutant, and metric negative controls reproduced"
