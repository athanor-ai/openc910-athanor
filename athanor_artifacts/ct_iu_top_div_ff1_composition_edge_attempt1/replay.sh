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
REPO="$(cd "$ROOT/../.." && pwd)"

check_hash() {
  local expected="$1"
  local rel="$2"
  echo "$expected  $REPO/$rel" | sha256sum -c -
}

check_hash f95edd68a9a93f0214ec0f2d1c09e03c4c6efbb2d43c5997a4c99ef14dcc097e C910_RTL_FACTORY/gen_rtl/cpu/rtl/cpu_cfig.h
check_hash 23b223f76f42d776fadfae0ae3b2f297791e5d95a985245e47f1642698a9e4f5 C910_RTL_FACTORY/gen_rtl/common/rtl/BUFGCE.v
check_hash 6b29b6e8090bec94889dc4083fdd2f54b7e667ce2bd41238dd51bd429fca656a C910_RTL_FACTORY/gen_rtl/common/rtl/booth_code.v
check_hash 64abfc68384cffa1e44f9290f5f798334311e2e2df3ca41a419f1b1db7c1d708 C910_RTL_FACTORY/gen_rtl/common/rtl/booth_code_v1.v
check_hash cb552cdf693f16f34f62c4ba52565ec43cb08c990893d62460abdc772812f5a2 C910_RTL_FACTORY/gen_rtl/common/rtl/compressor_32.v
check_hash ca352a7bae4e31134c17846410ea000c61e86ab9ea246f2cf8f11205c4829c7d C910_RTL_FACTORY/gen_rtl/common/rtl/compressor_42.v
check_hash 7530a4e8a17cd2ed2fcc9710634e10e9ae5754f1262e5a0f84619e9cbcfeeef1 C910_RTL_FACTORY/gen_rtl/common/rtl/sync_level2level.v
check_hash 774051f9aad6aed2c6aad8536d3c9e60eb17740abfe84838ac659f5cffb44588 C910_RTL_FACTORY/gen_rtl/common/rtl/sync_level2pulse.v
check_hash 6cfad397c18daabdff77e3a520ccbf964e4178197cc9a0f8dd825bbf928a91c8 C910_RTL_FACTORY/gen_rtl/clk/rtl/gated_clk_cell.v
check_hash 8d48e7519e1ef4e89a99b6eece6e2db8d69c595411f30296094ea797c7fb4acd C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_alu.v
check_hash 0548ffd26829f516eef3482c1478010fc0a593df3226ce12948fac18b0e52b14 C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_bju.v
check_hash 4bd1b208125776f7010f2ad243bf6717eb5246c658dad8b13b92bfd404c43cd3 C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_bju_pcfifo.v
check_hash e609da4d098c66c61b614830bda3caba946990db5b47f7b30cea6e89d21f2ffc C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_bju_pcfifo_entry.v
check_hash 292c7f1f31d8ad91677038a38220e33746b65954c4328a3e9c6b37ee213a476c C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_bju_pcfifo_read_entry.v
check_hash c470891e63ba731c365155f9b008ebd60b51b76a33e44298fb4a63b72b2fd9ab C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_cbus.v
check_hash e51738e1d2c9c25c39d4a00e4f640217d258a6f1ade5ac95fa36ba1b7a34e860 C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_div.v
check_hash cc70fc5f572f4b229dc19d7e43937f3cd85e4cdab9192ade725e58a13a4cf569 C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_div_entry.v
check_hash 9bd2402ba7738d29b8728d7bcd1681523ae005017da7eb476863ad2d3d79f56c C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_div_srt_radix16.v
check_hash 4c7dd62c5cb049c1bf0caa02287d8ae6dc5fafdaa48879c420212f67b87931a2 C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_mult.v
check_hash fb7cdc7abfed4f8a9b7502286de450d00f5afe42d4d20c8ef2d7162b485803e6 C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_rbus.v
check_hash 95b34fd4cf45e6867f81a0516fa6d90dc58dad09150b6985bb3ebd17c6ef734e C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_special.v
check_hash 851911e8a59c8832d5ae4e327164a6626ca2dc7b9abdfe170ff161a33dfde5db C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_top.v
check_hash f772f0b5895020ff4e4c59cd2210dccf9198bf62015599b1ac586d886a4bdd86 C910_RTL_FACTORY/gen_rtl/iu/rtl/multiplier_65x65_3_stage.v
check_hash d697c75c481b73b3220592ea887fb0bdd2219131d7136b9079f7c7263d387a8f C910_RTL_FACTORY/gen_rtl/rtu/rtl/ct_rtu_compare_iid.v
check_hash b50d7c9faf452630f6eec0cd0f7a51f27bacbaadb6da001f82c368bc92d89bbe C910_RTL_FACTORY/gen_rtl/rtu/rtl/ct_rtu_encode_32.v
check_hash b6c552220af70c8448a14e571ac98086661e2f03606bc1a66ff47d6f2b3a094f C910_RTL_FACTORY/gen_rtl/rtu/rtl/ct_rtu_encode_64.v
check_hash e2934244d6933c5ea2c1220074e4171a277006f1004c1917eaf4e4c612478f00 C910_RTL_FACTORY/gen_rtl/rtu/rtl/ct_rtu_encode_8.v
check_hash 93b710e31372d1d51d2dd50092eab6baf5ac281fd88c9db585aca73ce40520d7 C910_RTL_FACTORY/gen_rtl/rtu/rtl/ct_rtu_encode_96.v
check_hash 4467b90f7b447790649fa18b44b6f9425a0f6eca990e2220e2482a7dd636c27e C910_RTL_FACTORY/gen_rtl/rtu/rtl/ct_rtu_expand_32.v
check_hash 2af0b2fb30d7d8742e09db11291b12abb8f27fe06b9ceb669250ff0d2f0c0942 C910_RTL_FACTORY/gen_rtl/rtu/rtl/ct_rtu_expand_64.v
check_hash 4ce9e12bcb4658ab96e101a1357918caff0a652f4090e952625cee2029d1c8d0 C910_RTL_FACTORY/gen_rtl/rtu/rtl/ct_rtu_expand_8.v
check_hash 04bf6a1cf653991ca05a82732fed2a4a2e9bc160121b807792ecbbfa8ec104ec C910_RTL_FACTORY/gen_rtl/rtu/rtl/ct_rtu_expand_96.v
check_hash dd3fe6708001b89cf78d52db5d81085e05bc4bd0e1b60ea3f269c60094193fdb C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_srt_radix16_bound_table.v
check_hash d1a0dd2dba3ae8a1156fe2606d27ad1875abac87060be086a18a31b79f27d73f C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_srt_radix16_only_div.v
check_hash 2ea9f277f6853d07d0a9da208834cf3bbb1f28266d816485da1b4daf7676579a athanor_artifacts/ct_iu_div_ff1_tree_candidate1/ct_iu_div_gate_candidate.v

"$YOSYS_BIN" -V > "$OUT/yosys_version.replay.log" 2>&1
"$STA_BIN" -version > "$OUT/opensta_version.replay.log" 2>&1
sha256sum "$LIBERTY" > "$OUT/liberty_sha256.replay.log"

PYTHONPATH="$REPO" python3 - "$REPO/C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_div.v" "$REPO/athanor_artifacts/ct_iu_div_ff1_tree_candidate1/ct_iu_div_gate_candidate.v" "$OUT/boundary_identity.replay.log" <<'PY'
from pathlib import Path
import re
import sys

gold = Path(sys.argv[1]).read_text(encoding="utf-8")
gate = Path(sys.argv[2]).read_text(encoding="utf-8")

def port_list(text: str) -> list[str]:
    match = re.search(r"module\s+ct_iu_div\s*\((.*?)\)\s*;", text, re.S)
    if not match:
        raise SystemExit("missing ct_iu_div module port list")
    return [line.strip().rstrip(",") for line in match.group(1).splitlines() if line.strip()]

def port_decls(text: str) -> list[str]:
    match = re.search(r"// &Ports;.*?// &Regs;", text, re.S)
    if not match:
        raise SystemExit("missing ct_iu_div port declaration block")
    out = []
    for raw in match.group(0).splitlines():
        line = raw.split("//", 1)[0].strip().rstrip(";")
        if line.startswith(("input", "output", "inout")):
            out.append(re.sub(r"\s+", " ", line))
    return sorted(out)

gold_ports = port_list(gold)
gate_ports = port_list(gate)
gold_decls = port_decls(gold)
gate_decls = port_decls(gate)
if gold_ports != gate_ports:
    raise SystemExit("ct_iu_div module port list changed")
if gold_decls != gate_decls:
    raise SystemExit("ct_iu_div port declarations changed")
Path(sys.argv[3]).write_text(
    "PASS: ct_iu_div interface identical across gold and candidate\n"
    f"port_count: {len(gold_decls)}\n",
    encoding="utf-8",
)
PY

SOURCES_BEFORE_DIV=(
  "$REPO/C910_RTL_FACTORY/gen_rtl/common/rtl/BUFGCE.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/common/rtl/booth_code.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/common/rtl/booth_code_v1.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/common/rtl/compressor_32.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/common/rtl/compressor_42.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_alu.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_bju.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_bju_pcfifo.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_bju_pcfifo_entry.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_bju_pcfifo_read_entry.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_cbus.v"
)
SOURCES_AFTER_DIV=(
  "$REPO/C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_div_entry.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_div_srt_radix16.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_mult.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_rbus.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_special.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_top.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/rtu/rtl/ct_rtu_compare_iid.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/rtu/rtl/ct_rtu_encode_32.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/rtu/rtl/ct_rtu_encode_64.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/rtu/rtl/ct_rtu_encode_8.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/rtu/rtl/ct_rtu_encode_96.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/rtu/rtl/ct_rtu_expand_32.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/rtu/rtl/ct_rtu_expand_64.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/rtu/rtl/ct_rtu_expand_8.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/rtu/rtl/ct_rtu_expand_96.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_srt_radix16_bound_table.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_srt_radix16_only_div.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/clk/rtl/gated_clk_cell.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/iu/rtl/multiplier_65x65_3_stage.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/common/rtl/sync_level2level.v"
  "$REPO/C910_RTL_FACTORY/gen_rtl/common/rtl/sync_level2pulse.v"
)
GOLD_SOURCES=(
  "$REPO/C910_RTL_FACTORY/gen_rtl/cpu/rtl/cpu_cfig.h"
  "${SOURCES_BEFORE_DIV[@]}"
  "$REPO/C910_RTL_FACTORY/gen_rtl/iu/rtl/ct_iu_div.v"
  "${SOURCES_AFTER_DIV[@]}"
)
GATE_SOURCES=(
  "$REPO/C910_RTL_FACTORY/gen_rtl/cpu/rtl/cpu_cfig.h"
  "${SOURCES_BEFORE_DIV[@]}"
  "$REPO/athanor_artifacts/ct_iu_div_ff1_tree_candidate1/ct_iu_div_gate_candidate.v"
  "${SOURCES_AFTER_DIV[@]}"
)

run_yosys_map() {
  local label="$1"
  local out_netlist="$2"
  shift 2
  local sources=("$@")
  local read_cmd="read_verilog -sv"
  local src
  for src in "${sources[@]}"; do
    read_cmd+=" $src"
  done
  "$YOSYS_BIN" -p "read_liberty -lib $LIBERTY; $read_cmd; synth -top ct_iu_top; dfflibmap -liberty $LIBERTY; abc -liberty $LIBERTY; clean -purge; rename -unescape; stat -liberty $LIBERTY; write_verilog -simple-lhs -noattr $out_netlist" \
    > "$OUT/${label}_yosys_map.replay.log" 2>&1
}

run_yosys_map gold "$OUT/ct_iu_top_gold.mapped.v" "${GOLD_SOURCES[@]}"
run_yosys_map gate "$OUT/ct_iu_top_gate.mapped.v" "${GATE_SOURCES[@]}"

write_sta_tcl() {
  local netlist="$1"
  local out="$2"
  cat > "$out" <<EOF
read_liberty $LIBERTY
read_verilog $netlist
link_design ct_iu_top
create_clock -name forever_cpuclk -period 10 [get_ports forever_cpuclk]
set_propagated_clock [all_clocks]
report_checks -path_delay max -fields {slew cap input_pin net} -digits 4
report_wns
report_tns
report_power
EOF
}

write_sta_tcl "$OUT/ct_iu_top_gold.mapped.v" "$OUT/ct_iu_top_gold_opensta.tcl"
write_sta_tcl "$OUT/ct_iu_top_gate.mapped.v" "$OUT/ct_iu_top_gate_opensta.tcl"
"$STA_BIN" "$OUT/ct_iu_top_gold_opensta.tcl" > "$OUT/ct_iu_top_gold_opensta.replay.log" 2>&1
"$STA_BIN" "$OUT/ct_iu_top_gate_opensta.tcl" > "$OUT/ct_iu_top_gate_opensta.replay.log" 2>&1

grep -q "Yosys 0.66+181" "$OUT/yosys_version.replay.log"
grep -q "2.2.0" "$OUT/opensta_version.replay.log"
grep -q "ec0e1067a35c8bf20b11e58d1e8ac53326067e4dac84a125cc1b917a3518d0d9" "$OUT/liberty_sha256.replay.log"
grep -q "PASS: ct_iu_div interface identical" "$OUT/boundary_identity.replay.log"
echo "d06b50960678e5d91f9de446d239d823c3c34239064db310798817d8fb06594c  $OUT/ct_iu_top_gold.mapped.v" | sha256sum -c -
echo "a5eff6846380d0532ab05cfd019e90b65e3f0d983ef9e69e0161274eb0bf8b00  $OUT/ct_iu_top_gate.mapped.v" | sha256sum -c -
grep -Fq "Chip area for top module '\\ct_iu_top': 729976.355200" "$OUT/gold_yosys_map.replay.log"
grep -Fq "Chip area for top module '\\ct_iu_top': 728213.414400" "$OUT/gate_yosys_map.replay.log"
grep -Fq "Chip area for module '\\ct_iu_div': 23092.147200" "$OUT/gold_yosys_map.replay.log"
grep -Fq "Chip area for module '\\ct_iu_div': 21329.206400" "$OUT/gate_yosys_map.replay.log"
grep -q "34.3786   data arrival time" "$OUT/ct_iu_top_gold_opensta.replay.log"
grep -q "34.3786   data arrival time" "$OUT/ct_iu_top_gate_opensta.replay.log"
grep -q "wns -24.53" "$OUT/ct_iu_top_gold_opensta.replay.log"
grep -q "wns -24.53" "$OUT/ct_iu_top_gate_opensta.replay.log"
grep -q "tns -47241.97" "$OUT/ct_iu_top_gold_opensta.replay.log"
grep -q "tns -47221.35" "$OUT/ct_iu_top_gate_opensta.replay.log"
grep -q "Total                  5.38e-02   2.84e-02   2.59e-07   8.23e-02" "$OUT/ct_iu_top_gold_opensta.replay.log"
grep -q "Total                  5.38e-02   2.84e-02   2.59e-07   8.21e-02" "$OUT/ct_iu_top_gate_opensta.replay.log"
grep -q "729976.355200" metric_screen.pinned.log
grep -q "728213.414400" metric_screen.pinned.log
grep -q "flat ct_iu_top proof is not claimed" proof_route.pinned.log

echo "PASS: ct_iu_top divider FF1 composition-edge boundary and bounded screen reproduced"
