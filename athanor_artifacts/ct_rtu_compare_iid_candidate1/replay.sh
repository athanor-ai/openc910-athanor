#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${YOSYS_BIN:?set YOSYS_BIN to the pinned Yosys executable}"
: "${LIBERTY:?set LIBERTY to sky130_fd_sc_hd__tt_025C_1v80.lib}"

OUT="$ROOT/replay_out"
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

"$YOSYS_BIN" -p "read_verilog -sv -D PA_WIDTH=40 gated_clk_cell.v ct_rtu_compare_iid_gold.v ct_lsu_spec_fail_predict.v; synth -top ct_lsu_spec_fail_predict; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY" \
  > "$OUT/spec_fail_predict_gold_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_verilog -sv -D PA_WIDTH=40 gated_clk_cell.v ct_rtu_compare_iid_gate_candidate.v ct_lsu_spec_fail_predict.v; synth -top ct_lsu_spec_fail_predict; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY" \
  > "$OUT/spec_fail_predict_gate_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_verilog -sv -D PA_WIDTH=40 gated_clk_cell.v ct_rtu_compare_iid_gold.v ct_lsu_pfu_sdb_cmp.v; synth -top ct_lsu_pfu_sdb_cmp; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY" \
  > "$OUT/pfu_sdb_cmp_gold_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_verilog -sv -D PA_WIDTH=40 gated_clk_cell.v ct_rtu_compare_iid_gate_candidate.v ct_lsu_pfu_sdb_cmp.v; synth -top ct_lsu_pfu_sdb_cmp; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY" \
  > "$OUT/pfu_sdb_cmp_gate_map.replay.log" 2>&1

echo "253b9875c6451919d2f13940ae5a3582730bf787a8e9b7b592fc9659c6000beb  $OUT/ct_rtu_compare_iid_gold.mapped.v" | sha256sum -c -
echo "e85f7daf3d85c1ae187988ad67530a4c56656cff532094b69eea05d6b0484524  $OUT/ct_rtu_compare_iid_gate_candidate.mapped.v" | sha256sum -c -

grep -q "Equivalence successfully proven" "$OUT/same_state_equiv.replay.log"
grep -q "Found a total of 1 unproven" "$OUT/proof_mutant_negative.replay.log"
grep -q "Chip area for module '\\\\ct_rtu_compare_iid': 142.636800" "$OUT/helper_gold_map.replay.log"
grep -q "Chip area for module '\\\\ct_rtu_compare_iid': 127.622400" "$OUT/helper_gate_map.replay.log"
grep -q "Chip area for top module '\\\\ct_lsu_spec_fail_predict': 1725.404800" "$OUT/spec_fail_predict_gold_map.replay.log"
grep -q "Chip area for top module '\\\\ct_lsu_spec_fail_predict': 1695.376000" "$OUT/spec_fail_predict_gate_map.replay.log"
grep -q "Chip area for top module '\\\\ct_lsu_pfu_sdb_cmp': 6052.054400" "$OUT/pfu_sdb_cmp_gold_map.replay.log"
grep -q "Chip area for top module '\\\\ct_lsu_pfu_sdb_cmp': 6007.011200" "$OUT/pfu_sdb_cmp_gate_map.replay.log"

echo "PASS: ct_rtu_compare_iid helper equivalence, equality-boundary mutant, helper area, and two LSU parent area screens reproduced"
