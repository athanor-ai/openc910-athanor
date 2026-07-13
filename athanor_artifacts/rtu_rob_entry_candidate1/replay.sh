#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YOSYS_BIN="${YOSYS_BIN:-/workdir/_tools/oss-cad-suite-20260630/bin/yosys}"
LIBERTY="${LIBERTY:-/workdir/athanor-kairos-runall/src/kairos/data/liberty/sky130_fd_sc_hd__tt_025C_1v80.lib}"

cd "$ROOT"

"$YOSYS_BIN" -p "read_verilog gated_clk_cell.v ct_rtu_compare_iid.v ct_rtu_rob_entry_gold.v; hierarchy -check -top ct_rtu_rob_entry; proc; opt; memory; opt; stat" \
  > gold_generic.replay.log 2>&1
"$YOSYS_BIN" -p "read_verilog gated_clk_cell.v ct_rtu_compare_iid.v ct_rtu_rob_entry_gate_candidate.v; hierarchy -check -top ct_rtu_rob_entry; proc; opt; memory; opt; stat" \
  > gate_generic.replay.log 2>&1

"$YOSYS_BIN" -p "read_verilog gated_clk_cell.v ct_rtu_compare_iid.v ct_rtu_rob_entry_gold.v; synth -top ct_rtu_rob_entry; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; stat -liberty $LIBERTY" \
  > gold_sky130.replay.log 2>&1
"$YOSYS_BIN" -p "read_verilog gated_clk_cell.v ct_rtu_compare_iid.v ct_rtu_rob_entry_gate_candidate.v; synth -top ct_rtu_rob_entry; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; stat -liberty $LIBERTY" \
  > gate_sky130.replay.log 2>&1

"$YOSYS_BIN" -p "read_verilog gated_clk_cell.v ct_rtu_compare_iid.v ct_rtu_rob_entry_gold.v; rename ct_rtu_rob_entry gold; read_verilog ct_rtu_rob_entry_gate_candidate.v; rename ct_rtu_rob_entry gate; proc; opt; memory; opt; async2sync; equiv_make gold gate equiv; hierarchy -top equiv; flatten; clean; opt; equiv_simple; equiv_induct -seq 8; equiv_status -assert" \
  > same_state_equiv_seq8.replay.log 2>&1

if "$YOSYS_BIN" -p "read_verilog gated_clk_cell.v ct_rtu_compare_iid.v ct_rtu_rob_entry_gold.v; rename ct_rtu_rob_entry gold; read_verilog ct_rtu_rob_entry_gate_mutant.v; rename ct_rtu_rob_entry gate; proc; opt; memory; opt; async2sync; equiv_make gold gate equiv; hierarchy -top equiv; flatten; clean; opt; equiv_simple; equiv_induct -seq 8; equiv_status -assert" \
  > mutant_negative_equiv_seq8.replay.log 2>&1; then
  echo "ERROR: mutant unexpectedly passed equivalence" >&2
  exit 1
fi

grep -q "      129 cells" gold_generic.replay.log
grep -q "       94 cells" gate_generic.replay.log
grep -q "Chip area for module '\\\\ct_rtu_rob_entry': 2287.193600" gold_sky130.replay.log
grep -q "Chip area for module '\\\\ct_rtu_rob_entry': 2265.923200" gate_sky130.replay.log
grep -q "Of those cells 94 are proven and 0 are unproven" same_state_equiv_seq8.replay.log
grep -q "Equivalence successfully proven" same_state_equiv_seq8.replay.log
grep -q "Found a total of 4 unproven" mutant_negative_equiv_seq8.replay.log

echo "PASS: ct_rtu_rob_entry area, same-state equivalence, and mutant bite reproduced"
