#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${YOSYS_BIN:?set YOSYS_BIN to the pinned Yosys executable}"
: "${LIBERTY:?set LIBERTY to sky130_fd_sc_hd__tt_025C_1v80.lib}"

export PATH="$(dirname "$YOSYS_BIN"):$PATH"
cd "$ROOT"

"$YOSYS_BIN" -p 'read_verilog -formal -sv ct_prio_gold.v ct_prio_gate_candidate.v ct_prio_output_miter.sv; prep -top ct_prio_output_miter; flatten; async2sync; dffunmap; opt; sat -seq 8 -tempinduct -set-at 1 rst_b 0 -set-at 2 rst_b 1 -prove-asserts -verify' \
  > ct_prio_output_miter_proof.replay.log 2>&1

if "$YOSYS_BIN" -p 'read_verilog -formal -sv ct_prio_gold.v ct_prio_gate_mutant.v ct_prio_output_miter.sv; prep -top ct_prio_output_miter; flatten; async2sync; dffunmap; opt; sat -seq 8 -tempinduct -set-at 1 rst_b 0 -set-at 2 rst_b 1 -prove-asserts -verify' \
  > ct_prio_mutant_negative.replay.log 2>&1; then
  echo "ERROR: mutant unexpectedly proved" >&2
  exit 1
fi

"$YOSYS_BIN" -p "read_verilog -sv ct_prio_gold.v; synth -flatten -top ct_prio; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY" \
  > ct_prio_gold_sky130.replay.log 2>&1
"$YOSYS_BIN" -p "read_verilog -sv ct_prio_gate_candidate.v; synth -flatten -top ct_prio_gate; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY" \
  > ct_prio_gate_sky130.replay.log 2>&1

"$YOSYS_BIN" -p "read_verilog -sv ct_prio_gold.v; rename ct_prio gold; read_verilog -sv ct_prio_gate_candidate.v; rename ct_prio_gate gate; proc; opt; memory; opt; async2sync; equiv_make gold gate equiv; hierarchy -top equiv; clean; opt; equiv_simple; equiv_induct -seq 8; equiv_status" \
  > ct_prio_same_state_equiv_fail.replay.log 2>&1

grep -q "Induction step proven: SUCCESS" ct_prio_output_miter_proof.replay.log
grep -q "proof did fail" ct_prio_mutant_negative.replay.log
grep -q "Chip area for module '\\\\ct_prio': 158.902400" ct_prio_gold_sky130.replay.log
grep -q "Chip area for module '\\\\ct_prio_gate': 93.840000" ct_prio_gate_sky130.replay.log
grep -q "Of those cells 4 are proven and 2 are unproven" ct_prio_same_state_equiv_fail.replay.log

echo "PASS: ct_prio output proof, mutant bite, Sky130 area, and same-state boundary reproduced"
