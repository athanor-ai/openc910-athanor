#!/usr/bin/env python3
"""Check that ct_fifo debug wrappers are passive instrumentation only."""

from __future__ import annotations

import argparse
import difflib
import shutil
import sys
import tempfile
from pathlib import Path


DEBUG_PORTS = {
    "dbg_create_ptr",
    "dbg_pop_ptr",
    "dbg_entry_vld",
    "dbg_entry_cont0",
    "dbg_entry_cont1",
}


def _strip_debug_lines(text: str, *, debug_module: str, exact_module: str) -> str:
    normalized: list[str] = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("module " + debug_module + "("):
            normalized.append(line.replace(debug_module, exact_module, 1))
            continue
        if any(stripped == port + "," or stripped == port for port in DEBUG_PORTS):
            continue
        if stripped.startswith("output ") and any(port in stripped for port in DEBUG_PORTS):
            continue
        if stripped.startswith("assign dbg_"):
            continue
        if stripped == "fifo_icg_en,":
            normalized.append(line.replace("fifo_icg_en,", "fifo_icg_en"))
            continue
        normalized.append(line)
    return "\n".join(normalized) + "\n"


def _check_pair(exact: Path, debug: Path, *, debug_module: str, exact_module: str) -> tuple[bool, str]:
    exact_text = exact.read_text()
    normalized_debug = _strip_debug_lines(
        debug.read_text(),
        debug_module=debug_module,
        exact_module=exact_module,
    )
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
        (
            root / "ct_fifo_gold.v",
            root / "ct_fifo_gold_dbg.v",
            "ct_fifo_gold_dbg",
            "ct_fifo",
            "gold",
        ),
        (
            root / "ct_fifo_gate_candidate.v",
            root / "ct_fifo_gate_dbg.v",
            "ct_fifo_gate_dbg",
            "ct_fifo_gate",
            "gate",
        ),
    ]
    messages: list[str] = []
    ok = True
    for exact, debug, debug_module, exact_module, label in checks:
        pair_ok, detail = _check_pair(
            exact,
            debug,
            debug_module=debug_module,
            exact_module=exact_module,
        )
        if pair_ok:
            messages.append(f"PASS: {label}_dbg is passive instrumentation only")
        else:
            ok = False
            messages.append(f"FAIL: {label}_dbg has non-passive changes\n{detail}")
    return ok, messages


def _selftest(root: Path) -> tuple[bool, str]:
    with tempfile.TemporaryDirectory(prefix="ct_fifo_passivity_") as tmp:
        tmp_root = Path(tmp)
        for path in root.iterdir():
            if path.is_file():
                shutil.copy2(path, tmp_root / path.name)
        target = tmp_root / "ct_fifo_gold_dbg.v"
        text = target.read_text()
        tampered = text.replace(
            "assign fifo_not_empty = |fifo_entry_vld[DEPTH-1:0];",
            "assign fifo_not_empty = &fifo_entry_vld[DEPTH-1:0];",
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
