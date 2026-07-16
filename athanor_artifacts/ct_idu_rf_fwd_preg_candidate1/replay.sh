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

"$YOSYS_BIN" -s onehot_contract.pinned.ys > "$OUT/onehot_contract.replay.log" 2>&1
if "$YOSYS_BIN" -s proof_mutant_negative.pinned.ys > "$OUT/proof_mutant_negative.replay.log" 2>&1; then
  echo "ERROR: proof mutant unexpectedly passed" >&2
  exit 1
fi

"$YOSYS_BIN" -p "read_verilog -sv ct_idu_rf_fwd_preg_gold.v; synth -flatten -top ct_idu_rf_fwd_preg; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/ct_idu_rf_fwd_preg_gold.mapped.v" > "$OUT/gold_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_verilog -sv ct_idu_rf_fwd_preg_gate_candidate.v; synth -flatten -top ct_idu_rf_fwd_preg; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/ct_idu_rf_fwd_preg_gate.mapped.v" > "$OUT/gate_map.replay.log" 2>&1

write_sta_tcl() {
  local netlist="$1"
  local out="$2"
  cat > "$out" <<EOF
read_liberty {$LIBERTY}
read_verilog {$netlist}
link_design ct_idu_rf_fwd_preg
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

write_sta_tcl "$OUT/ct_idu_rf_fwd_preg_gold.mapped.v" "$OUT/gold_opensta.tcl"
write_sta_tcl "$OUT/ct_idu_rf_fwd_preg_gate.mapped.v" "$OUT/gate_opensta.tcl"

"$STA_BIN" -exit "$OUT/gold_opensta.tcl" > "$OUT/gold_opensta.replay.log" 2>&1
"$STA_BIN" -exit "$OUT/gate_opensta.tcl" > "$OUT/gate_opensta.replay.log" 2>&1

echo "6745927dca1cd39f89b8525da24bfb1355895207349d26bc509c795ac0c37a19  $OUT/ct_idu_rf_fwd_preg_gold.mapped.v" | sha256sum -c -
echo "7a6b492e4d035d5776ac7b4dd6e25724d5a92143ceb51e5668c1f279c9ecc3b7  $OUT/ct_idu_rf_fwd_preg_gate.mapped.v" | sha256sum -c -

grep -qF "SAT proof finished - no model found: SUCCESS!" "$OUT/onehot_contract.replay.log"
grep -qF "ERROR: Called with -verify and proof did fail!" "$OUT/proof_mutant_negative.replay.log"
grep -qF "Chip area for module '\\ct_idu_rf_fwd_preg': 2706.345600" "$OUT/gold_map.replay.log"
grep -qF "Chip area for module '\\ct_idu_rf_fwd_preg': 2382.284800" "$OUT/gate_map.replay.log"
grep -qF "11.23   data arrival time" "$OUT/gold_opensta.replay.log"
grep -qF "6.10   data arrival time" "$OUT/gate_opensta.replay.log"
grep -qF "Total                  3.96e-05   3.46e-05   1.09e-09   7.42e-05" "$OUT/gold_opensta.replay.log"
grep -qF "Total                  3.22e-05   3.17e-05   7.39e-10   6.39e-05" "$OUT/gate_opensta.replay.log"

echo "PASS: ct_idu_rf_fwd_preg one-hot contract, proof mutant, area, timing, and OpenSTA estimated power reproduced"
