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

"$YOSYS_BIN" -p "read_verilog plic_granu_arb_gold.v; rename plic_granu_arb plic_granu_arb_gold; read_verilog -sv plic_granu_arb_gate_candidate.v plic_granu_arb_miter.sv; prep -top plic_granu_arb_miter; flatten; sat -prove bad 0 -verify -show bad -show int_in_prio -show int_in_req" \
  > "$OUT/helper_same_state.replay.log" 2>&1

if "$YOSYS_BIN" -p "read_verilog plic_granu_arb_gold.v; rename plic_granu_arb plic_granu_arb_gold; read_verilog -sv plic_granu_arb_proof_mutant.v plic_granu_arb_miter.sv; prep -top plic_granu_arb_miter; flatten; sat -prove bad 0 -verify -show bad -show int_in_prio -show int_in_req -show int_in_id" \
  > "$OUT/helper_proof_mutant_negative.replay.log" 2>&1; then
  echo "ERROR: proof mutant unexpectedly proved" >&2
  exit 1
fi

"$YOSYS_BIN" -p "read_verilog plic_granu_arb_gold.v plic_granu2_arb.v plic_32to1_arb_gold.v; hierarchy -top plic_32to1_arb; proc; opt; memory; flatten; opt; async2sync; dffunmap; opt_clean; rename plic_32to1_arb plic_32to1_arb_gold; design -save gold; design -reset; read_verilog -sv plic_granu_arb_gate_candidate.v; rename plic_granu_arb_gate plic_granu_arb; read_verilog plic_granu2_arb.v plic_32to1_arb_gold.v; hierarchy -top plic_32to1_arb; proc; opt; memory; flatten; opt; async2sync; dffunmap; opt_clean; rename plic_32to1_arb plic_32to1_arb_gate; design -save gate; design -load gold; design -copy-from gate plic_32to1_arb_gate; equiv_make -blacklist parent_internal_blacklist.txt plic_32to1_arb_gold plic_32to1_arb_gate equiv; hierarchy -top equiv; equiv_simple -seq 1; equiv_induct -seq 1; equiv_status -assert" \
  > "$OUT/parent_same_state.replay.log" 2>&1

"$YOSYS_BIN" -p "read_liberty -lib $LIBERTY; read_verilog plic_granu_arb_gold.v; hierarchy -top plic_granu_arb -chparam SEL_NUM 9 -chparam SEL_BIT 4 -chparam ID_NUM 10 -chparam PRIO_BIT 5; synth -top plic_granu_arb; abc -liberty $LIBERTY; clean -purge; rename -unescape; stat -liberty $LIBERTY; write_verilog -simple-lhs -noattr $OUT/plic_granu_arb_gold.mapped.v" \
  > "$OUT/helper_gold_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_liberty -lib $LIBERTY; read_verilog -sv plic_granu_arb_gate_candidate.v; hierarchy -top plic_granu_arb_gate -chparam SEL_NUM 9 -chparam SEL_BIT 4 -chparam ID_NUM 10 -chparam PRIO_BIT 5; synth -top plic_granu_arb_gate; abc -liberty $LIBERTY; clean -purge; rename -unescape; stat -liberty $LIBERTY; write_verilog -simple-lhs -noattr $OUT/plic_granu_arb_gate_candidate.mapped.v" \
  > "$OUT/helper_gate_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_liberty -lib $LIBERTY; read_verilog plic_granu_arb_gold.v plic_granu2_arb.v plic_32to1_arb_gold.v; synth -top plic_32to1_arb; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean -purge; rename -unescape; stat -liberty $LIBERTY; write_verilog -simple-lhs -noattr $OUT/plic_32to1_arb_gold.mapped.v" \
  > "$OUT/parent_gold_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_liberty -lib $LIBERTY; read_verilog -sv plic_granu_arb_gate_candidate.v; rename plic_granu_arb_gate plic_granu_arb; read_verilog plic_granu2_arb.v plic_32to1_arb_gold.v; synth -top plic_32to1_arb; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean -purge; rename -unescape; stat -liberty $LIBERTY; write_verilog -simple-lhs -noattr $OUT/plic_32to1_arb_gate_candidate.mapped.v" \
  > "$OUT/parent_gate_map.replay.log" 2>&1

echo "725f5a87f90a8c73f7489e8a623da8ee5067b9b28d677775a6e5c3ee91b435f3  $OUT/plic_granu_arb_gold.mapped.v" | sha256sum -c -
echo "b40d87d863efdb53c914ae759470d2a4d83e34049e48c268bdc4ca1718c2b0c3  $OUT/plic_granu_arb_gate_candidate.mapped.v" | sha256sum -c -
echo "1b10b5482ed017edd417d76b355a1ee142289750e35fa321236639415b482fd3  $OUT/plic_32to1_arb_gold.mapped.v" | sha256sum -c -
echo "ba7a68b2b847ebe1a64eea029637bd0f8d106b6316fb38d98b91b01ef08a874a  $OUT/plic_32to1_arb_gate_candidate.mapped.v" | sha256sum -c -

write_helper_sta_tcl() {
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

write_parent_sta_tcl() {
  local netlist="$1"
  local out="$2"
  cat > "$out" <<EOF
read_liberty {$LIBERTY}
read_verilog {$netlist}
link_design plic_32to1_arb
create_clock -period 10.0 [get_ports arb_clk]
foreach p [all_inputs] { set_input_delay 0.0 -clock arb_clk \$p }
foreach p [all_outputs] { set_output_delay 0.0 -clock arb_clk \$p }
set_power_activity -global -activity 0.1 -duty 0.5
report_checks -path_delay max -format full_clock_expanded
report_tns
report_wns
report_power
exit
EOF
}

write_helper_sta_tcl "plic_granu_arb" "$OUT/plic_granu_arb_gold.mapped.v" "$OUT/helper_gold_opensta.tcl"
write_helper_sta_tcl "plic_granu_arb_gate" "$OUT/plic_granu_arb_gate_candidate.mapped.v" "$OUT/helper_gate_opensta.tcl"
write_parent_sta_tcl "$OUT/plic_32to1_arb_gold.mapped.v" "$OUT/parent_gold_opensta.tcl"
write_parent_sta_tcl "$OUT/plic_32to1_arb_gate_candidate.mapped.v" "$OUT/parent_gate_opensta.tcl"

"$STA_BIN" -exit "$OUT/helper_gold_opensta.tcl" > "$OUT/helper_gold_opensta_area_timing_power.replay.log" 2>&1 || true
"$STA_BIN" -exit "$OUT/helper_gate_opensta.tcl" > "$OUT/helper_gate_opensta_area_timing_power.replay.log" 2>&1 || true
"$STA_BIN" -exit "$OUT/parent_gold_opensta.tcl" > "$OUT/parent_gold_opensta_area_timing_power.replay.log" 2>&1 || true
"$STA_BIN" -exit "$OUT/parent_gate_opensta.tcl" > "$OUT/parent_gate_opensta_area_timing_power.replay.log" 2>&1 || true

grep -q "SAT proof finished - no model found: SUCCESS" "$OUT/helper_same_state.replay.log"
grep -q "SAT proof finished - model found: FAIL" "$OUT/helper_proof_mutant_negative.replay.log"
grep -q "ERROR: Called with -verify and proof did fail" "$OUT/helper_proof_mutant_negative.replay.log"
grep -q "66557 are proven and 0 are unproven" "$OUT/parent_same_state.replay.log"
grep -q "Equivalence successfully proven" "$OUT/parent_same_state.replay.log"
grep -Fq "Chip area for top module '\\plic_granu_arb': 5975.731200" "$OUT/helper_gold_map.replay.log"
grep -Fq "Chip area for module '\\plic_granu_arb_gate': 1671.603200" "$OUT/helper_gate_map.replay.log"
grep -Fq "Chip area for top module '\\plic_32to1_arb': 140709.952000" "$OUT/parent_gold_map.replay.log"
grep -Fq "Chip area for top module '\\plic_32to1_arb': 136564.726400" "$OUT/parent_gate_map.replay.log"
grep -q "12.56   data arrival time" "$OUT/helper_gold_opensta_area_timing_power.replay.log"
grep -q "6.42   data arrival time" "$OUT/helper_gate_opensta_area_timing_power.replay.log"
grep -q "13.26   data arrival time" "$OUT/parent_gold_opensta_area_timing_power.replay.log"
grep -q "7.39   data arrival time" "$OUT/parent_gate_opensta_area_timing_power.replay.log"
grep -q "Total                  7.12e-05   1.11e-04   1.39e-09   1.82e-04" "$OUT/helper_gold_opensta_area_timing_power.replay.log"
grep -q "Total                  2.15e-05   2.33e-05   5.80e-10   4.48e-05" "$OUT/helper_gate_opensta_area_timing_power.replay.log"
grep -q "Total                  2.01e-03   1.72e-03   4.18e-08   3.73e-03" "$OUT/parent_gold_opensta_area_timing_power.replay.log"
grep -q "Total                  1.97e-03   1.63e-03   4.10e-08   3.59e-03" "$OUT/parent_gate_opensta_area_timing_power.replay.log"

echo "PASS: plic_32to1_arb balanced granu selector helper proof, parent proof, proof mutant, mapped hashes, area, timing, and OpenSTA estimated-power reproduced"
