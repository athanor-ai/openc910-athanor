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

"$YOSYS_BIN" -p 'read_verilog -sv ct_vfmau_ff1_10bit_gold.v; rename ct_vfmau_ff1_10bit gold; read_verilog -sv ct_vfmau_ff1_10bit_gate_candidate.v; rename ct_vfmau_ff1_10bit gate; proc; opt; equiv_make gold gate equiv; hierarchy -top equiv; flatten; opt; equiv_simple; equiv_status -assert' > "$OUT/equiv_candidate.replay.log" 2>&1
if "$YOSYS_BIN" -p 'read_verilog -sv ct_vfmau_ff1_10bit_gold.v; rename ct_vfmau_ff1_10bit gold; read_verilog -sv ct_vfmau_ff1_10bit_proof_mutant.v; rename ct_vfmau_ff1_10bit gate; proc; opt; equiv_make gold gate equiv; hierarchy -top equiv; flatten; opt; equiv_simple; equiv_status -assert' > "$OUT/proof_mutant_negative.replay.log" 2>&1; then
  echo "ERROR: proof mutant unexpectedly passed" >&2
  exit 1
fi

"$YOSYS_BIN" -p "read_verilog -sv ct_vfmau_ff1_10bit_gold.v; synth -flatten -top ct_vfmau_ff1_10bit; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/ct_vfmau_ff1_10bit_gold.mapped.v" > "$OUT/gold_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_verilog -sv ct_vfmau_ff1_10bit_gate_candidate.v; synth -flatten -top ct_vfmau_ff1_10bit; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/ct_vfmau_ff1_10bit_gate.mapped.v" > "$OUT/gate_map.replay.log" 2>&1

write_sta_tcl() {
  local netlist="$1"
  local out="$2"
  cat > "$out" <<EOF
read_liberty {$LIBERTY}
read_verilog {$netlist}
link_design ct_vfmau_ff1_10bit
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

write_sta_tcl "$OUT/ct_vfmau_ff1_10bit_gold.mapped.v" "$OUT/gold_opensta.tcl"
write_sta_tcl "$OUT/ct_vfmau_ff1_10bit_gate.mapped.v" "$OUT/gate_opensta.tcl"

"$STA_BIN" -exit "$OUT/gold_opensta.tcl" > "$OUT/gold_opensta.replay.log" 2>&1
"$STA_BIN" -exit "$OUT/gate_opensta.tcl" > "$OUT/gate_opensta.replay.log" 2>&1

echo "66d6cc7beb836e1634cad768bc59f245e3f7f26c644d7cb86ad0be83ffb87f71  $OUT/ct_vfmau_ff1_10bit_gold.mapped.v" | sha256sum -c -
echo "963d5f9f42d0667e7dff33bfbf9d027aa8919838547f01c9022e5bb36ab70804  $OUT/ct_vfmau_ff1_10bit_gate.mapped.v" | sha256sum -c -

grep -qF "Equivalence successfully proven!" "$OUT/equiv_candidate.replay.log"
grep -qF "ERROR: Found 2 unproven" "$OUT/proof_mutant_negative.replay.log"
grep -qF "Chip area for module '\\ct_vfmau_ff1_10bit': 111.356800" "$OUT/gold_map.replay.log"
grep -qF "Chip area for module '\\ct_vfmau_ff1_10bit': 97.593600" "$OUT/gate_map.replay.log"
grep -qF "0.89   data arrival time" "$OUT/gold_opensta.replay.log"
grep -qF "0.61   data arrival time" "$OUT/gate_opensta.replay.log"
grep -qF "Total                  1.40e-06   1.06e-06   2.37e-11   2.46e-06" "$OUT/gold_opensta.replay.log"
grep -qF "Total                  1.21e-06   8.49e-07   2.96e-11   2.06e-06" "$OUT/gate_opensta.replay.log"

echo "PASS: ct_vfmau_ff1_10bit helper equivalence, proof mutant, area, timing, and OpenSTA estimated power reproduced"
