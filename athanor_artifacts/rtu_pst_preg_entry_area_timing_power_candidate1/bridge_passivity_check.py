#!/usr/bin/env python3
"""Check that PST preg-entry debug copies add observation-only ports."""

from __future__ import annotations

import argparse
import difflib
import shutil
import sys
import tempfile
from pathlib import Path


DEBUG_PORTS = {
    "dbg_lifecycle_cur_state",
    "dbg_iid",
    "dbg_dst_reg",
    "dbg_rel_preg",
    "dbg_wb_cur_state",
    "dbg_retire_inst0_iid_match",
    "dbg_retire_inst1_iid_match",
    "dbg_retire_inst2_iid_match",
}


def _strip_debug_lines(text: str) -> str:
    normalized: list[str] = []
    for line in text.splitlines():
        stripped = line.strip()
        if any(stripped == port + "," or stripped == port for port in DEBUG_PORTS):
            continue
        if stripped.startswith("output ") and any(port in stripped for port in DEBUG_PORTS):
            continue
        if stripped.startswith("assign dbg_"):
            continue
        if stripped == "x_wb_vld,":
            normalized.append(line.replace("x_wb_vld,", "x_wb_vld"))
            continue
        normalized.append(line)
    return "\n".join(normalized) + "\n"


def _canonical(text: str) -> str:
    return text.rstrip() + "\n"


def _check_pair(exact: Path, debug: Path) -> tuple[bool, str]:
    exact_text = _canonical(exact.read_text())
    normalized_debug = _canonical(_strip_debug_lines(debug.read_text()))
    if exact_text == normalized_debug:
        return True, ""
    diff = "\n".join(
        difflib.unified_diff(
            exact_text.splitlines(),
            normalized_debug.splitlines(),
            fromfile=exact.name,
            tofile=debug.name + " normalized",
            lineterm="",
        )
    )
    return False, diff


def _run_checks(root: Path) -> tuple[bool, list[str]]:
    checks = [
        (root / "ct_rtu_pst_preg_entry_gold.v", root / "ct_rtu_pst_preg_entry_gold_dbg.v", "gold"),
        (root / "ct_rtu_pst_preg_entry_gate_candidate.v", root / "ct_rtu_pst_preg_entry_gate_dbg.v", "gate"),
    ]
    messages: list[str] = []
    ok = True
    for exact, debug, label in checks:
        pair_ok, detail = _check_pair(exact, debug)
        if pair_ok:
            messages.append(f"PASS: {label}_dbg is passive instrumentation only")
        else:
            ok = False
            messages.append(f"FAIL: {label}_dbg has non-passive changes\n{detail}")
    return ok, messages


def _selftest(root: Path) -> tuple[bool, str]:
    with tempfile.TemporaryDirectory(prefix="ct_rtu_pst_passivity_") as tmp:
        tmp_root = Path(tmp)
        for path in root.iterdir():
            if path.is_file():
                shutil.copy2(path, tmp_root / path.name)
        target = tmp_root / "ct_rtu_pst_preg_entry_gold_dbg.v"
        text = target.read_text()
        tampered = text.replace(
            "assign x_cur_state_dealloc          = lifecycle_cur_state_dealloc;",
            "assign x_cur_state_dealloc          = ~lifecycle_cur_state_dealloc;",
            1,
        )
        if tampered == text:
            return False, "selftest setup failed: tamper target was not found"
        target.write_text(tampered)
        ok, messages = _run_checks(tmp_root)
        if ok:
            return False, "selftest failed: non-passive edit was accepted"
        return True, "PASS: selftest rejected non-passive gold_dbg logic edit\n" + "\n".join(messages)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args()

    ok, messages = _run_checks(args.root)
    if args.selftest:
        selftest_ok, selftest_message = _selftest(args.root)
        ok = ok and selftest_ok
        messages.append(selftest_message)

    for message in messages:
        print(message)
    return 0 if ok else 2


if __name__ == "__main__":
    sys.exit(main())
