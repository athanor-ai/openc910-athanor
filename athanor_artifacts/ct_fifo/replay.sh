#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${YOSYS_BIN:?set YOSYS_BIN to the pinned Yosys executable}"
: "${STA_BIN:?set STA_BIN to the OpenSTA executable}"
: "${LIBERTY:?set LIBERTY to sky130_fd_sc_hd__tt_025C_1v80.lib}"

cd "$ROOT"
OUT="$ROOT/replay_out"
rm -rf "$OUT"
mkdir -p "$OUT"

"$YOSYS_BIN" -p "read_verilog -sv gated_clk_cell.v ct_fifo_gold.v; synth -flatten -top ct_fifo; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/ct_fifo_gold.mapped.v" > "$OUT/replay_gold_sky130.replay.log" 2>&1
"$YOSYS_BIN" -p "read_verilog -sv gated_clk_cell.v ct_fifo_gate_candidate.v; synth -flatten -top ct_fifo_gate; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/ct_fifo_gate_candidate.mapped.v" > "$OUT/replay_gate_sky130.replay.log" 2>&1
"$YOSYS_BIN" -p "read_verilog -sv gated_clk_cell.v ct_fifo_metric_negative.v; synth -flatten -top ct_fifo_gate; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/ct_fifo_metric_negative.mapped.v" > "$OUT/replay_metric_negative_area.replay.log" 2>&1

"$YOSYS_BIN" -p 'read_verilog -formal -sv gated_clk_cell.v ct_fifo_gold.v ct_fifo_gate_candidate.v ct_fifo_output_miter.sv; prep -top ct_fifo_output_miter; flatten; async2sync; dffunmap; opt; sat -seq 12 -set-at 1 rst_b 0 -set-at 2 rst_b 1 -prove-asserts -verify' > "$OUT/replay_output_miter_bmc_seq12.replay.log" 2>&1

if "$YOSYS_BIN" -p 'read_verilog -formal -sv gated_clk_cell.v ct_fifo_gold.v ct_fifo_gate_mutant.v ct_fifo_output_miter.sv; prep -top ct_fifo_output_miter; flatten; async2sync; dffunmap; opt; sat -seq 6 -set-at 1 rst_b 0 -set-at 2 rst_b 1 -prove-asserts -verify' > "$OUT/replay_mutant_negative_bmc_seq6.replay.log" 2>&1; then
  echo "FAIL: seeded mutant unexpectedly proved" >&2
  exit 1
fi
grep -q 'proof did fail' "$OUT/replay_mutant_negative_bmc_seq6.replay.log"

"$YOSYS_BIN" -p 'read_verilog -formal -sv gated_clk_cell.v ct_fifo_gold_dbg.v ct_fifo_gate_dbg.v ct_fifo_relation_miter.sv; prep -top ct_fifo_relation_miter; flatten; async2sync; dffunmap; opt; sat -seq 8 -tempinduct -set-at 1 rst_b 0 -set-at 2 rst_b 1 -prove-asserts -verify' > "$OUT/replay_relation_miter_tempinduct_seq8.replay.log" 2>&1

if "$YOSYS_BIN" -p 'read_verilog -formal -sv gated_clk_cell.v ct_fifo_gold_dbg.v ct_fifo_gate_dbg_mutant.v ct_fifo_relation_miter.sv; prep -top ct_fifo_relation_miter; flatten; async2sync; dffunmap; opt; sat -seq 8 -tempinduct -set-at 1 rst_b 0 -set-at 2 rst_b 1 -prove-asserts -verify' > "$OUT/replay_relation_miter_mutant_negative_tempinduct_seq8.replay.log" 2>&1; then
  echo "FAIL: relation-miter mutant unexpectedly proved" >&2
  exit 1
fi
grep -q 'proof did fail' "$OUT/replay_relation_miter_mutant_negative_tempinduct_seq8.replay.log"

./bridge_passivity_check.py --selftest > "$OUT/replay_bridge_passivity_check.replay.log" 2>&1

write_sta_tcl() {
  local top="$1"
  local netlist="$2"
  local out="$3"
  cat > "$out" <<EOF
read_liberty {$LIBERTY}
read_verilog {$netlist}
link_design $top
create_clock -period 10.0 -name clk [get_ports clk]
if {[llength [get_ports rst_b]] > 0} { set_false_path -from [get_ports rst_b] }
foreach p [all_inputs] {
  set name [get_name \$p]
  if {\$name != "clk" && \$name != "rst_b"} { set_input_delay 0.0 -clock clk \$p }
}
foreach p [all_outputs] { set_output_delay 0.0 -clock clk \$p }
set_power_activity -global -activity 0.1 -duty 0.5
report_checks -path_delay max -format full_clock_expanded
report_tns
report_wns
report_power
exit
EOF
}

write_sta_tcl ct_fifo "$OUT/ct_fifo_gold.mapped.v" "$OUT/gold_opensta.tcl"
write_sta_tcl ct_fifo_gate "$OUT/ct_fifo_gate_candidate.mapped.v" "$OUT/gate_opensta.tcl"
write_sta_tcl ct_fifo_gate "$OUT/ct_fifo_metric_negative.mapped.v" "$OUT/metric_negative_opensta.tcl"

"$STA_BIN" -exit "$OUT/gold_opensta.tcl" > "$OUT/replay_gold_opensta_area_timing_power.replay.log" 2>&1
"$STA_BIN" -exit "$OUT/gate_opensta.tcl" > "$OUT/replay_gate_opensta_area_timing_power.replay.log" 2>&1
"$STA_BIN" -exit "$OUT/metric_negative_opensta.tcl" > "$OUT/replay_metric_negative_opensta_area_timing_power.replay.log" 2>&1

echo "996104aa377ecc9cd84e17401f8e2d1c575db684cf9f462fee06bc6ae46e5133  $OUT/ct_fifo_gold.mapped.v" | sha256sum -c -
echo "fb6019b57e44534743f0106e3cab3718c76a34dec860383f40561dc59a1d7865  $OUT/ct_fifo_gate_candidate.mapped.v" | sha256sum -c -
echo "076f2428ad13b12d5fff8cbe925c0651eb743a070f3459eeec94d2b85e31fb7c  $OUT/ct_fifo_metric_negative.mapped.v" | sha256sum -c -

grep -Fq "Chip area for module '\\ct_fifo': 711.932800" "$OUT/replay_gold_sky130.replay.log"
grep -Fq "Chip area for module '\\ct_fifo_gate': 678.150400" "$OUT/replay_gate_sky130.replay.log"
grep -Fq "Chip area for module '\\ct_fifo_gate': 784.502400" "$OUT/replay_metric_negative_area.replay.log"
grep -q 'SAT proof finished - no model found: SUCCESS' "$OUT/replay_output_miter_bmc_seq12.replay.log"
grep -q 'Induction step proven: SUCCESS' "$OUT/replay_relation_miter_tempinduct_seq8.replay.log"
grep -q 'PASS: selftest rejected non-passive gold_dbg logic edit' "$OUT/replay_bridge_passivity_check.replay.log"
grep -q '1.02   data arrival time' "$OUT/replay_gold_opensta_area_timing_power.replay.log"
grep -q '1.14   data arrival time' "$OUT/replay_gate_opensta_area_timing_power.replay.log"
grep -Fq "4.45e-05" "$OUT/replay_gold_opensta_area_timing_power.replay.log"
grep -Fq "4.19e-05" "$OUT/replay_gate_opensta_area_timing_power.replay.log"

echo "PASS: ct_fifo proof packet plus same-candidate area, OpenSTA timing, and OpenSTA estimated-power screen reproduced; full-metric promotion remains rejected by timing"
