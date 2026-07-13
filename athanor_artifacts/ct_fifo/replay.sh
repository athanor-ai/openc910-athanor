#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${YOSYS_BIN:?set YOSYS_BIN to the pinned Yosys executable}"
: "${LIBERTY:?set LIBERTY to sky130_fd_sc_hd__tt_025C_1v80.lib}"

cd "$ROOT"

"$YOSYS_BIN" -p "read_verilog -sv gated_clk_cell.v ct_fifo_gold.v; synth -flatten -top ct_fifo; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY" > replay_gold_sky130.pinned.log 2>&1
"$YOSYS_BIN" -p "read_verilog -sv gated_clk_cell.v ct_fifo_gate_candidate.v; synth -flatten -top ct_fifo_gate; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY" > replay_gate_sky130.pinned.log 2>&1

"$YOSYS_BIN" -p 'read_verilog -formal -sv gated_clk_cell.v ct_fifo_gold.v ct_fifo_gate_candidate.v ct_fifo_output_miter.sv; prep -top ct_fifo_output_miter; flatten; async2sync; dffunmap; opt; sat -seq 12 -set-at 1 rst_b 0 -set-at 2 rst_b 1 -prove-asserts -verify' > replay_output_miter_bmc_seq12.pinned.log 2>&1

if "$YOSYS_BIN" -p 'read_verilog -formal -sv gated_clk_cell.v ct_fifo_gold.v ct_fifo_gate_mutant.v ct_fifo_output_miter.sv; prep -top ct_fifo_output_miter; flatten; async2sync; dffunmap; opt; sat -seq 6 -set-at 1 rst_b 0 -set-at 2 rst_b 1 -prove-asserts -verify' > replay_mutant_negative_bmc_seq6.pinned.log 2>&1; then
  echo "FAIL: seeded mutant unexpectedly proved" >&2
  exit 1
fi
grep -q 'proof did fail' replay_mutant_negative_bmc_seq6.pinned.log

"$YOSYS_BIN" -p 'read_verilog -formal -sv gated_clk_cell.v ct_fifo_gold_dbg.v ct_fifo_gate_dbg.v ct_fifo_relation_miter.sv; prep -top ct_fifo_relation_miter; flatten; async2sync; dffunmap; opt; sat -seq 8 -tempinduct -set-at 1 rst_b 0 -set-at 2 rst_b 1 -prove-asserts -verify' > replay_relation_miter_tempinduct_seq8.pinned.log 2>&1

if "$YOSYS_BIN" -p 'read_verilog -formal -sv gated_clk_cell.v ct_fifo_gold_dbg.v ct_fifo_gate_dbg_mutant.v ct_fifo_relation_miter.sv; prep -top ct_fifo_relation_miter; flatten; async2sync; dffunmap; opt; sat -seq 8 -tempinduct -set-at 1 rst_b 0 -set-at 2 rst_b 1 -prove-asserts -verify' > replay_relation_miter_mutant_negative_tempinduct_seq8.pinned.log 2>&1; then
  echo "FAIL: relation-miter mutant unexpectedly proved" >&2
  exit 1
fi
grep -q 'proof did fail' replay_relation_miter_mutant_negative_tempinduct_seq8.pinned.log

./bridge_passivity_check.py --selftest > replay_bridge_passivity_check.pinned.log 2>&1

grep -q 'Chip area for module .\\ct_fifo.: 711.932800' replay_gold_sky130.pinned.log
grep -q 'Chip area for module .\\ct_fifo_gate.: 678.150400' replay_gate_sky130.pinned.log
grep -q 'SAT proof finished - no model found: SUCCESS' replay_output_miter_bmc_seq12.pinned.log
grep -q 'Induction step proven: SUCCESS' replay_relation_miter_tempinduct_seq8.pinned.log
grep -q 'PASS: selftest rejected non-passive gold_dbg logic edit' replay_bridge_passivity_check.pinned.log

echo "PASS: ct_fifo selected area, bounded exact-output miter, mutant bites, state-relation induction, and passive debug bridge reproduced"
