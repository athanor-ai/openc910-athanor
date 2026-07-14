"""Bite tests for the ATH-2966 replay explicit-env gate (part 2).

Each bite builds a fake artifact root with one replay.sh and asserts the gate
reds on exactly the require-explicit-env violation, plus a compliant control.
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

_SCRIPT = Path(__file__).resolve().parents[1] / "athanor" / "check_replay_env.py"
_spec = importlib.util.spec_from_file_location("check_replay_env", _SCRIPT)
gate = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
sys.modules[_spec.name] = gate
_spec.loader.exec_module(gate)


def _artifact_root(root: Path, name: str, replay_body: str) -> Path:
    art = root / "athanor_artifacts"
    pkg = art / name
    pkg.mkdir(parents=True)
    (pkg / "replay.sh").write_text(replay_body, encoding="utf-8")
    return art


def test_compliant_replay_passes(tmp_path: Path) -> None:
    art = _artifact_root(
        tmp_path,
        "p",
        ': "${YOSYS_BIN:?set YOSYS_BIN to the pinned Yosys}"\n'
        ': "${LIBERTY:?set LIBERTY}"\n'
        '"$YOSYS_BIN" -p "read_verilog gold.v" -liberty "$LIBERTY"\n',
    )
    assert gate.check(art) == []


def test_defaulted_tool_var_reds(tmp_path: Path) -> None:
    # A silent internal-path default -- the exact ATH-2966 leak/substitution class.
    art = _artifact_root(
        tmp_path,
        "p",
        # The default value is irrelevant -- the gate reds on the :- substitution
        # pattern itself (a default silently substitutes, and a leaky one leaks).
        'YOSYS="${YOSYS_BIN:-/opt/oss-cad-suite/bin/yosys}"\n'
        '"$YOSYS_BIN" -p "read_verilog gold.v"\n',
    )
    problems = gate.check(art)
    assert any("YOSYS_BIN" in p and "DEFAULTED" in p for p in problems), problems


def test_used_but_not_required_reds(tmp_path: Path) -> None:
    # Uses $YOSYS_BIN but never guards it -- runs against an unset/ambient tool.
    art = _artifact_root(
        tmp_path,
        "p",
        '"$YOSYS_BIN" -p "read_verilog gold.v"\n',
    )
    problems = gate.check(art)
    assert any("YOSYS_BIN" in p and "USED but not REQUIRED" in p for p in problems), problems


def test_capture_track_no_replay_is_noop(tmp_path: Path) -> None:
    art = tmp_path / "athanor_artifacts"
    (art / "generated_rtl_capture").mkdir(parents=True)
    assert gate.check(art) == []
