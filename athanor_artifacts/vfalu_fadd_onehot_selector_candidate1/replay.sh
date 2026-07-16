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

run_yosys() {
  "$YOSYS_BIN" -p "$1" > "$2" 2>&1
}

run_yosys 'read_verilog -sv ct_fadd_onehot_sel_h_gold.v; rename ct_fadd_onehot_sel_h gold; read_verilog -sv ct_fadd_onehot_sel_h_gate_candidate.v; rename ct_fadd_onehot_sel_h gate; read_verilog -formal ct_fadd_onehot_sel_h_onehot_miter.sv; prep -top miter; flatten; opt; sat -prove fail 0 -verify' "$OUT/h_onehot_contract.replay.log"
if run_yosys 'read_verilog -sv ct_fadd_onehot_sel_h_gold.v; rename ct_fadd_onehot_sel_h gold; read_verilog -sv ct_fadd_onehot_sel_h_proof_mutant.v; rename ct_fadd_onehot_sel_h gate; read_verilog -formal ct_fadd_onehot_sel_h_onehot_miter.sv; prep -top miter; flatten; opt; sat -prove fail 0 -verify' "$OUT/h_proof_mutant_negative.replay.log"; then
  echo "ERROR: h proof mutant unexpectedly passed" >&2
  exit 1
fi

run_yosys 'read_verilog -sv ct_fadd_onehot_sel_d_gold.v; rename ct_fadd_onehot_sel_d gold; read_verilog -sv ct_fadd_onehot_sel_d_gate_candidate.v; rename ct_fadd_onehot_sel_d gate; read_verilog -formal ct_fadd_onehot_sel_d_onehot_miter.sv; prep -top miter; flatten; opt; sat -prove fail 0 -verify' "$OUT/d_onehot_contract.replay.log"
if run_yosys 'read_verilog -sv ct_fadd_onehot_sel_d_gold.v; rename ct_fadd_onehot_sel_d gold; read_verilog -sv ct_fadd_onehot_sel_d_proof_mutant.v; rename ct_fadd_onehot_sel_d gate; read_verilog -formal ct_fadd_onehot_sel_d_onehot_miter.sv; prep -top miter; flatten; opt; sat -prove fail 0 -verify' "$OUT/d_proof_mutant_negative.replay.log"; then
  echo "ERROR: d proof mutant unexpectedly passed" >&2
  exit 1
fi

for tag in h d; do
  mod="ct_fadd_onehot_sel_${tag}"
  "$YOSYS_BIN" -p "read_verilog -sv ${mod}_gold.v; synth -flatten -top ${mod}; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr -simple-lhs $OUT/${mod}_gold.mapped.v" > "$OUT/${tag}_gold_map.replay.log" 2>&1
  "$YOSYS_BIN" -p "read_verilog -sv ${mod}_gate_candidate.v; synth -flatten -top ${mod}; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr -simple-lhs $OUT/${mod}_gate.mapped.v" > "$OUT/${tag}_gate_map.replay.log" 2>&1
done

write_sta_tcl() {
  local netlist="$1"
  local top="$2"
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

write_sta_tcl "$OUT/ct_fadd_onehot_sel_h_gold.mapped.v" ct_fadd_onehot_sel_h "$OUT/h_gold_opensta.tcl"
write_sta_tcl "$OUT/ct_fadd_onehot_sel_h_gate.mapped.v" ct_fadd_onehot_sel_h "$OUT/h_gate_opensta.tcl"
write_sta_tcl "$OUT/ct_fadd_onehot_sel_d_gold.mapped.v" ct_fadd_onehot_sel_d "$OUT/d_gold_opensta.tcl"
write_sta_tcl "$OUT/ct_fadd_onehot_sel_d_gate.mapped.v" ct_fadd_onehot_sel_d "$OUT/d_gate_opensta.tcl"

"$STA_BIN" -exit "$OUT/h_gold_opensta.tcl" > "$OUT/h_gold_opensta.replay.log" 2>&1
"$STA_BIN" -exit "$OUT/h_gate_opensta.tcl" > "$OUT/h_gate_opensta.replay.log" 2>&1
"$STA_BIN" -exit "$OUT/d_gold_opensta.tcl" > "$OUT/d_gold_opensta.replay.log" 2>&1
"$STA_BIN" -exit "$OUT/d_gate_opensta.tcl" > "$OUT/d_gate_opensta.replay.log" 2>&1

echo "80a8a0e909e77f54eaf32d5cbc2ee6f5aeb4a623c6784ee992310dec790bc01f  $OUT/ct_fadd_onehot_sel_h_gold.mapped.v" | sha256sum -c -
echo "6a9d406e2326e6cd62229f873699672ff3c0a945503586ae7424256f7fd06c22  $OUT/ct_fadd_onehot_sel_h_gate.mapped.v" | sha256sum -c -
echo "b7917217d2cbea9195e71ebe92615e4a16a1ff91a33e67a84a4d94ad3a8c8d3c  $OUT/ct_fadd_onehot_sel_d_gold.mapped.v" | sha256sum -c -
echo "03891890329123f59b5e04ec96e3bf7bb5d63c9eac9e75296e0f76b1794b62dd  $OUT/ct_fadd_onehot_sel_d_gate.mapped.v" | sha256sum -c -

grep -qF "SAT proof finished - no model found: SUCCESS" "$OUT/h_onehot_contract.replay.log"
grep -qF "proof did fail" "$OUT/h_proof_mutant_negative.replay.log"
grep -qF "SAT proof finished - no model found: SUCCESS" "$OUT/d_onehot_contract.replay.log"
grep -qF "proof did fail" "$OUT/d_proof_mutant_negative.replay.log"
grep -qF "Chip area for module '\\ct_fadd_onehot_sel_h': 599.324800" "$OUT/h_gold_map.replay.log"
grep -qF "Chip area for module '\\ct_fadd_onehot_sel_h': 339.075200" "$OUT/h_gate_map.replay.log"
grep -qF "Chip area for module '\\ct_fadd_onehot_sel_d': 8134.051200" "$OUT/d_gold_map.replay.log"
grep -qF "Chip area for module '\\ct_fadd_onehot_sel_d': 6563.795200" "$OUT/d_gate_map.replay.log"
grep -qF "2.29   data arrival time" "$OUT/h_gold_opensta.replay.log"
grep -qF "0.54   data arrival time" "$OUT/h_gate_opensta.replay.log"
grep -qF "7.07   data arrival time" "$OUT/d_gold_opensta.replay.log"
grep -qF "1.03   data arrival time" "$OUT/d_gate_opensta.replay.log"
grep -qF "Total                  7.98e-06   7.57e-06   1.83e-10   1.55e-05" "$OUT/h_gold_opensta.replay.log"
grep -qF "Total                  4.41e-06   1.48e-06   1.08e-10   5.90e-06" "$OUT/h_gate_opensta.replay.log"
grep -qF "Total                  1.13e-04   1.13e-04   2.43e-09   2.25e-04" "$OUT/d_gold_opensta.replay.log"
grep -qF "Total                  8.58e-05   3.34e-05   1.83e-09   1.19e-04" "$OUT/d_gate_opensta.replay.log"

echo "PASS: ct_fadd_onehot_sel_h/d onehot-contract proof, mutants, area, timing, and OpenSTA estimated power reproduced"
