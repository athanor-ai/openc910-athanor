#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${YOSYS_BIN:?set YOSYS_BIN to the pinned Yosys executable}"
: "${LIBERTY:?set LIBERTY to sky130_fd_sc_hd__tt_025C_1v80.lib}"

cd "$ROOT"

"$YOSYS_BIN" -p "read_verilog gated_clk_cell.v ct_rtu_expand_32.v ct_rtu_expand_96.v ct_rtu_pst_preg_entry_gold.v; hierarchy -check -top ct_rtu_pst_preg_entry; proc; opt; memory; opt; stat" \
  > gold_generic.replay.log 2>&1
"$YOSYS_BIN" -p "read_verilog gated_clk_cell.v ct_rtu_expand_32.v ct_rtu_expand_96.v ct_rtu_pst_preg_entry_gate_candidate.v; hierarchy -check -top ct_rtu_pst_preg_entry_gate; proc; opt; memory; opt; stat" \
  > gate_generic.replay.log 2>&1

"$YOSYS_BIN" -p "read_verilog gated_clk_cell.v ct_rtu_expand_32.v ct_rtu_expand_96.v ct_rtu_pst_preg_entry_gold.v; synth -top ct_rtu_pst_preg_entry; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; stat -liberty $LIBERTY" \
  > gold_sky130.replay.log 2>&1
"$YOSYS_BIN" -p "read_verilog gated_clk_cell.v ct_rtu_expand_32.v ct_rtu_expand_96.v ct_rtu_pst_preg_entry_gate_candidate.v; synth -top ct_rtu_pst_preg_entry_gate; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; stat -liberty $LIBERTY" \
  > gate_sky130.replay.log 2>&1

"$YOSYS_BIN" -p "read_verilog -formal -sv gated_clk_cell.v ct_rtu_expand_32.v ct_rtu_expand_96.v ct_rtu_pst_preg_entry_gold.v ct_rtu_pst_preg_entry_gate_candidate.v ct_rtu_pst_preg_entry_output_miter.sv; prep -top ct_rtu_pst_preg_entry_output_miter; flatten; async2sync; dffunmap; opt; sat -seq 12 -set forever_cpuclk 1 -set cp0_yy_clk_en 1 -set cp0_rtu_icg_en 1 -set pad_yy_icg_scan_en 0 -set-at 1 cpurst_b 0 -set-at 2 cpurst_b 1 -prove-asserts -verify" \
  > output_miter_bmc_seq12.replay.log 2>&1

if "$YOSYS_BIN" -p "read_verilog -formal -sv gated_clk_cell.v ct_rtu_expand_32.v ct_rtu_expand_96.v ct_rtu_pst_preg_entry_gold.v ct_rtu_pst_preg_entry_gate_candidate.v ct_rtu_pst_preg_entry_output_miter.sv; prep -top ct_rtu_pst_preg_entry_output_miter; flatten; async2sync; dffunmap; opt; sat -seq 6 -set forever_cpuclk 1 -set cp0_yy_clk_en 1 -set cp0_rtu_icg_en 1 -set pad_yy_icg_scan_en 0 -prove-asserts -verify" \
  > output_miter_no_reset_bmc_seq6.replay.log 2>&1; then
  echo "FAIL: no-reset output miter unexpectedly proved" >&2
  exit 1
fi
grep -q "proof did fail" output_miter_no_reset_bmc_seq6.replay.log

"$YOSYS_BIN" -p "read_verilog -formal -sv gated_clk_cell.v ct_rtu_expand_32.v ct_rtu_expand_96.v ct_rtu_pst_preg_entry_gold_dbg.v ct_rtu_pst_preg_entry_gate_dbg.v ct_rtu_pst_preg_entry_relation_miter.sv; prep -top ct_rtu_pst_preg_entry_relation_dbg_ports_miter; flatten; async2sync; dffunmap; opt; sat -seq 8 -tempinduct -set forever_cpuclk 1 -set cp0_yy_clk_en 1 -set cp0_rtu_icg_en 1 -set pad_yy_icg_scan_en 0 -set-at 1 cpurst_b 0 -set-at 2 cpurst_b 1 -prove ok_life 1 -prove ok_storage 1 -prove ok_outputs 1 -verify" \
  > relation_miter_tempinduct_seq8.replay.log 2>&1

if "$YOSYS_BIN" -p "read_verilog -formal -sv gated_clk_cell.v ct_rtu_expand_32.v ct_rtu_expand_96.v ct_rtu_pst_preg_entry_gold_dbg.v ct_rtu_pst_preg_entry_gate_dbg_mutant.v ct_rtu_pst_preg_entry_relation_miter.sv; prep -top ct_rtu_pst_preg_entry_relation_dbg_ports_miter; flatten; async2sync; dffunmap; opt; sat -seq 8 -tempinduct -set forever_cpuclk 1 -set cp0_yy_clk_en 1 -set cp0_rtu_icg_en 1 -set pad_yy_icg_scan_en 0 -set-at 1 cpurst_b 0 -set-at 2 cpurst_b 1 -prove ok_life 1 -prove ok_storage 1 -prove ok_outputs 1 -verify" \
  > relation_miter_mutant_negative_tempinduct_seq8.replay.log 2>&1; then
  echo "FAIL: relation mutant unexpectedly proved" >&2
  exit 1
fi
grep -q "proof did fail" relation_miter_mutant_negative_tempinduct_seq8.replay.log

./bridge_passivity_check.py --selftest > bridge_passivity_check.replay.log 2>&1

grep -q "      101 cells" gold_generic.replay.log
grep -q "      101 cells" gate_generic.replay.log
grep -q "Chip area for module '\\\\ct_rtu_pst_preg_entry': 2677.568000" gold_sky130.replay.log
grep -q "Chip area for module '\\\\ct_rtu_pst_preg_entry_gate': 2648.790400" gate_sky130.replay.log
grep -q "Chip area for top module '\\\\ct_rtu_pst_preg_entry': 3510.867200" gold_sky130.replay.log
grep -q "Chip area for top module '\\\\ct_rtu_pst_preg_entry_gate': 3482.089600" gate_sky130.replay.log
grep -q "SAT proof finished - no model found: SUCCESS" output_miter_bmc_seq12.replay.log
grep -q "Induction step proven: SUCCESS" relation_miter_tempinduct_seq8.replay.log
grep -q "PASS: selftest rejected non-passive gold_dbg logic edit" bridge_passivity_check.replay.log

echo "PASS: rtu_pst_preg_entry area, output screening, reset boundary, relation proof, mutant bite, and passive bridge reproduced"
