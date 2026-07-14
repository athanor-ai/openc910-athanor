#!/usr/bin/env python3
"""ATH-2966 (part 2): public replay packages must REQUIRE explicit tool env vars.

The 2026-07-14 stall: a public fork replay.sh that hardcodes an internal tool
path, or silently defaults a tool env var to one, leaks internal build-dir
infrastructure into the customer package AND lets a proof replay run against an
unpinned/ambient tool. Human review caught the leak pre-merge; this gate
enforces it by tooling so a future packet cannot regress.

The contract every ``replay.sh`` must meet for each verdict-bearing tool env var
it USES (``$YOSYS_BIN``, ``$STA_BIN``, ``$OPENSTA``, ``$ABC_BIN``, ``$LIBERTY``):

  * REQUIRED, not defaulted: the var must be guarded by the fail-if-unset form
    ``${VAR:?...}`` (usually ``: "${VAR:?message}"``), so the replay fails loud
    when the pinned tool is not provided -- it never silently substitutes.
  * NEVER defaulted: ``${VAR:-...}`` / ``${VAR:=...}`` is forbidden -- a default
    silently substitutes (and, if the default is an internal path, leaks it).

The complementary internal-build-dir byte-leak is caught by
``export_safety_gate.py``; this gate is specifically the require-explicit-env
half of the ATH-2966 contract.
Capture-track forks with no replay.sh are a clean no-op.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
ARTIFACT_ROOT = REPO_ROOT / "athanor_artifacts"


def _rel(path: Path) -> Path:
    """Repo-relative for legible messages; fall back to the raw path for a tmp
    dir outside the repo (test fixtures), never crash on relative_to."""
    try:
        return path.relative_to(REPO_ROOT)
    except ValueError:
        return path

# Verdict-bearing tool env vars a proof/metric replay resolves to a pinned tool.
TOOL_ENV_VARS = ("YOSYS_BIN", "STA_BIN", "OPENSTA", "OPENSTA_BIN", "ABC_BIN", "LIBERTY")


def _used(text: str, var: str) -> bool:
    """The replay references the var as $VAR or ${VAR...} anywhere."""
    return re.search(r"\$\{?" + re.escape(var) + r"\b", text) is not None


def _required(text: str, var: str) -> bool:
    """The var is guarded by the fail-if-unset form ${VAR:?...} (or ${VAR?...})."""
    return re.search(r"\$\{" + re.escape(var) + r"\s*:?\?", text) is not None


def _defaulted(text: str, var: str) -> re.Match[str] | None:
    """The var is given a silent default via ${VAR:-...} or ${VAR:=...} (forbidden)."""
    return re.search(r"\$\{" + re.escape(var) + r"\s*:?[-=]", text)


def check(root: Path = ARTIFACT_ROOT) -> list[str]:
    if not root.is_dir():
        return []
    problems: list[str] = []
    for replay in sorted(root.glob("*/replay.sh")):
        try:
            text = replay.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            problems.append(f"{_rel(replay)}: unreadable ({exc})")
            continue
        rel = _rel(replay)
        for var in TOOL_ENV_VARS:
            if not _used(text, var):
                continue
            defaulted = _defaulted(text, var)
            if defaulted:
                problems.append(
                    f"{rel}: tool env var {var} is silently DEFAULTED "
                    f"({defaulted.group(0)}...) -- a public replay must REQUIRE it "
                    f"via ${{{var}:?...}}, never substitute (ATH-2966)"
                )
            elif not _required(text, var):
                problems.append(
                    f"{rel}: tool env var {var} is USED but not REQUIRED -- add a "
                    f"fail-if-unset guard : \"${{{var}:?set {var} to the pinned tool}}\" "
                    f"so the replay fails loud instead of running against an "
                    f"unset/ambient tool (ATH-2966)"
                )
    return problems


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="ATH-2966 replay explicit-env gate")
    parser.add_argument("--artifact-root", type=Path, default=ARTIFACT_ROOT)
    args = parser.parse_args(argv)
    problems = check(args.artifact_root)
    if problems:
        print("REPLAY EXPLICIT-ENV GATE FAILED (ATH-2966):", file=sys.stderr)
        for problem in problems:
            print(f"  FAIL: {problem}", file=sys.stderr)
        return 1
    n = len(list(args.artifact_root.glob("*/replay.sh"))) if args.artifact_root.is_dir() else 0
    print(f"OK: {n} replay.sh REQUIRE their pinned tool env vars (no silent default) (ATH-2966)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
