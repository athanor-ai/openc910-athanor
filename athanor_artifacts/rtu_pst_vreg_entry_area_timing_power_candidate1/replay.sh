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

"$YOSYS_BIN" -p "read_verilog gated_clk_cell.v ct_rtu_expand_32.v ct_rtu_expand_64.v ct_rtu_pst_vreg_entry_gold.v; synth -top ct_rtu_pst_vreg_entry; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/ct_rtu_pst_vreg_entry_gold.mapped.v" \
  > "$OUT/gold_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_verilog gated_clk_cell.v ct_rtu_expand_32.v ct_rtu_expand_64.v ct_rtu_pst_vreg_entry_gate_candidate.v; synth -top ct_rtu_pst_vreg_entry_gate; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean; stat -liberty $LIBERTY; write_verilog -noattr $OUT/ct_rtu_pst_vreg_entry_gate_candidate.mapped.v" \
  > "$OUT/gate_map.replay.log" 2>&1
"$YOSYS_BIN" -p "read_liberty -lib $LIBERTY; read_verilog ct_rtu_pst_vreg_entry_metric_negative.mapped.v; hierarchy -top ct_rtu_pst_vreg_entry_gate; stat -liberty $LIBERTY" \
  > "$OUT/metric_negative_area.replay.log" 2>&1

echo "6d7cd77c653ab249186541f9ae6aac4d7f8e5ac605f74dd99cb34f7876b0d125  $OUT/ct_rtu_pst_vreg_entry_gold.mapped.v" | sha256sum -c -
echo "b85271d29def0252c646c80c99c1ab3040cfa893dfedd201d353b67ce00fb5e3  $OUT/ct_rtu_pst_vreg_entry_gate_candidate.mapped.v" | sha256sum -c -

"$YOSYS_BIN" -p "read_verilog -formal -sv gated_clk_cell.v ct_rtu_expand_32.v ct_rtu_expand_64.v ct_rtu_pst_vreg_entry_gold_dbg.v ct_rtu_pst_vreg_entry_gate_dbg.v ct_rtu_pst_vreg_entry_relation_miter.sv; prep -top ct_rtu_pst_vreg_entry_relation_dbg_ports_miter; flatten; async2sync; dffunmap; opt; sat -seq 8 -tempinduct -set vreg_top_clk 1 -set cp0_yy_clk_en 1 -set cp0_rtu_icg_en 1 -set pad_yy_icg_scan_en 0 -set-at 1 cpurst_b 0 -set-at 2 cpurst_b 1 -prove ok_life 1 -prove ok_storage 1 -prove ok_outputs 1 -verify" \
  > "$OUT/relation_miter_tempinduct_seq8.replay.log" 2>&1

if "$YOSYS_BIN" -p "read_verilog -formal -sv gated_clk_cell.v ct_rtu_expand_32.v ct_rtu_expand_64.v ct_rtu_pst_vreg_entry_gold_dbg.v ct_rtu_pst_vreg_entry_gate_dbg_mutant.v ct_rtu_pst_vreg_entry_relation_miter.sv; prep -top ct_rtu_pst_vreg_entry_relation_dbg_ports_miter; flatten; async2sync; dffunmap; opt; sat -seq 8 -tempinduct -set vreg_top_clk 1 -set cp0_yy_clk_en 1 -set cp0_rtu_icg_en 1 -set pad_yy_icg_scan_en 0 -set-at 1 cpurst_b 0 -set-at 2 cpurst_b 1 -prove ok_life 1 -prove ok_storage 1 -prove ok_outputs 1 -verify" \
  > "$OUT/relation_miter_mutant_negative_tempinduct_seq8.replay.log" 2>&1; then
  echo "ERROR: relation proof mutant unexpectedly proved" >&2
  exit 1
fi

./bridge_passivity_check.py --selftest > "$OUT/bridge_passivity_check.replay.log" 2>&1

write_sta_tcl() {
  local netlist="$1"
  local top="$2"
  local out="$3"
  python3 - "$netlist" "$top" "$out" "$LIBERTY" <<'PY'
import re
import sys
from pathlib import Path

netlist, top, out, liberty = sys.argv[1:]
inputs = []
outputs = []
for line in Path(netlist).read_text(errors="ignore").splitlines():
    m = re.match(r"\s*(input|output)(?:\s+\[(\d+):(\d+)\])?\s+([^;]+);", line)
    if not m:
        continue
    kind, hi, lo, names = m.groups()
    target = inputs if kind == "input" else outputs
    for name in [part.strip() for part in names.split(",")]:
        if not name:
            continue
        if hi is None:
            target.append(name)
        else:
            a, b = int(hi), int(lo)
            step = 1 if b >= a else -1
            for idx in range(a, b + step, step):
                target.append(f"{name}[{idx}]")

clock = "vreg_top_clk" if "vreg_top_clk" in inputs else "clk"
resets = {"cpurst_b", "rst_b"}
with open(out, "w") as f:
    f.write(f"read_liberty {{{liberty}}}\n")
    f.write(f"read_verilog {{{netlist}}}\n")
    f.write(f"link_design {top}\n")
    f.write(f"create_clock -period 10.0 -name clk [get_ports {{{clock}}}]\n")
    for reset in sorted(resets & set(inputs)):
        f.write(f"set_false_path -from [get_ports {{{reset}}}]\n")
    for port in inputs:
        if port == clock or port in resets:
            continue
        f.write(f"set_input_delay 0.0 -clock clk [get_ports {{{port}}}]\n")
    for port in outputs:
        f.write(f"set_output_delay 0.0 -clock clk [get_ports {{{port}}}]\n")
    f.write("set_power_activity -global -activity 0.1 -duty 0.5\n")
    f.write("report_units\n")
    f.write("report_checks -path_delay min_max -format full_clock_expanded\n")
    f.write("report_tns\n")
    f.write("report_wns\n")
    f.write("report_power\n")
    f.write("exit\n")
PY
}

write_sta_tcl "$OUT/ct_rtu_pst_vreg_entry_gold.mapped.v" ct_rtu_pst_vreg_entry "$OUT/gold_opensta.tcl"
write_sta_tcl "$OUT/ct_rtu_pst_vreg_entry_gate_candidate.mapped.v" ct_rtu_pst_vreg_entry_gate "$OUT/gate_opensta.tcl"
write_sta_tcl "$ROOT/ct_rtu_pst_vreg_entry_metric_negative.mapped.v" ct_rtu_pst_vreg_entry_gate "$OUT/metric_negative_opensta.tcl"

"$STA_BIN" -exit "$OUT/gold_opensta.tcl" > "$OUT/gold_opensta_area_timing_power.replay.log" 2>&1
"$STA_BIN" -exit "$OUT/gate_opensta.tcl" > "$OUT/gate_opensta_area_timing_power.replay.log" 2>&1
"$STA_BIN" -exit "$OUT/metric_negative_opensta.tcl" > "$OUT/metric_negative_opensta_area_timing_power.replay.log" 2>&1

grep -q "Chip area for top module '\\\\ct_rtu_pst_vreg_entry': 3148.019200" "$OUT/gold_map.replay.log"
grep -q "Chip area for top module '\\\\ct_rtu_pst_vreg_entry_gate': 3057.932800" "$OUT/gate_map.replay.log"
grep -q "Chip area for top module '\\\\ct_rtu_pst_vreg_entry_gate': 5287.571200" "$OUT/metric_negative_area.replay.log"
grep -q "Induction step proven: SUCCESS" "$OUT/relation_miter_tempinduct_seq8.replay.log"
grep -q "proof did fail" "$OUT/relation_miter_mutant_negative_tempinduct_seq8.replay.log"
grep -q "PASS: selftest rejected non-passive gold_dbg logic edit" "$OUT/bridge_passivity_check.replay.log"
grep -q "2.82   data arrival time" "$OUT/gold_opensta_area_timing_power.replay.log"
grep -q "2.81   data arrival time" "$OUT/gate_opensta_area_timing_power.replay.log"
grep -q "12.78   data arrival time" "$OUT/metric_negative_opensta_area_timing_power.replay.log"
grep -q "tns -2.78" "$OUT/metric_negative_opensta_area_timing_power.replay.log"
grep -q "wns -2.78" "$OUT/metric_negative_opensta_area_timing_power.replay.log"
grep -q "Total                  9.06e-05   3.78e-05   1.30e-09   1.28e-04" "$OUT/gold_opensta_area_timing_power.replay.log"
grep -q "Total                  8.78e-05   3.63e-05   1.28e-09   1.24e-04" "$OUT/gate_opensta_area_timing_power.replay.log"
grep -q "Total                  1.74e-04   5.55e-05   2.31e-09   2.29e-04" "$OUT/metric_negative_opensta_area_timing_power.replay.log"

echo "PASS: rtu_pst_vreg_entry area, timing, OpenSTA estimated-power, relation proof, proof mutant, and metric negative controls reproduced"
