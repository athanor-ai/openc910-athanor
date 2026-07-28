#!/usr/bin/env python3
"""No published artifact may carry a working-directory path named after a person.

ATH-3397 / ATH-3444 follow-up. 412 fleet-agent handle occurrences live in 7
published logs on this PUBLIC fork, and every one of them is the same thing:

    .scratch/<handle>_<topic>/<file>.v

a LOCAL WORKING DIRECTORY whose name happens to contain an internal handle,
baked into a synthesis log by the tool that ran there.

WHY THIS CHECK AND NOT JUST THE EXPORT GATE. The export gate reports handles
wherever they appear, at WARN, in a population of thousands. That answers "is
there a handle in the tree". It does not answer the PRODUCER question -- "did a
package arrive whose paths are named after whoever generated it" -- and the
producer question is the one that decides whether this class regrows. asabi's
ruling on the normalisation was explicit: without the naming convention and a
check for it, the class comes back and we are editing published evidence again,
which is the situation the never-rewrite rule exists to keep us out of.

WHY A BASELINE RATHER THAN A CLEAN RED. The 412 are already committed. A check
that reds on them cannot land before the normalisation, and asabi ruled the
convention must land FIRST -- a normalisation shipping ahead of the rule that
prevents its recurrence is a repair with a known expiry. So this lands with a
baseline naming exactly the files that already carry the class, DERIVED from
this checker's own output rather than hand-listed. Anything NOT in the baseline
reds. Entries leave as the normalisation lands; the file is deleted when empty.

That is the ATH-3444 PR A shape, which is already reviewed and merged, applied
to a second class -- and its three properties carry over unchanged:

  * an entry binds to the WHOLE finding, so a NEW handle in an already-listed
    file still reds rather than riding in under the file's name
  * an entry matching nothing is ITSELF a finding, so the baseline cannot
    outlive its subject and rot into a list of things that used to be wrong
  * a missing/unparseable baseline at an EXPLICIT --baseline path is rc 2, no
    verdict; an absent DEFAULT path means the class is closed, not unmeasured
    (absence has two causes and they are opposite verdicts)

Exit codes: 0 clean-or-baselined, 1 finding, 2 could-not-establish.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    # Run as a script, `athanor` is not importable without this. The check
    # fail-closed to rc 2 rather than a false clean, which is the correct
    # contract -- but a tool that can only be imported is not a tool.
    sys.path.insert(0, str(REPO_ROOT))
ARTIFACT_ROOT = REPO_ROOT / "athanor_artifacts"
BASELINE_PATH = REPO_ROOT / "athanor" / "ath3397_known_scratch_paths.json"

# A working-directory component: a path segment under a scratch/tmp/work root.
# Handles come from the SAME denylist the export gate uses -- a second list here
# would drift from it, and a drifting denylist is the maintained-list defect this
# fork has hit four times.
# NO PREFIX CLASS. The first version required the scratch root to follow
# start-of-line, whitespace, a quote or a slash -- and the shape carrying ~95% of
# this fork's population is a Yosys cell name, `$flatten\\x.$logic_not$.scratch/
# dexter_.../f.v:30$13699_gate`, where it follows `$`. Anchoring on the
# characters I had seen found 21 of 412. The root is recognisable on its own;
# constraining what may precede it constrains nothing but my own reach.
_SCRATCH_ROOT = re.compile(
    r"(?:\.?scratch|tmp|temp|work(?:dir|space)?|build|out)/"
    r"(?P<segment>[A-Za-z0-9._-]+)/",
    re.IGNORECASE,
)


def _handles() -> tuple[set[str], list[str]]:
    """The fleet-handle denylist, read from the export gate's single source."""
    try:
        from athanor import export_safety_gate as esg
    except Exception as exc:  # pragma: no cover - import shape is environmental
        return set(), [f"cannot import the export gate to read its denylist: {exc}"]
    path = REPO_ROOT / esg.DENYLIST_REL
    if not path.is_file():
        return set(), [f"denylist absent at {path}"]
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return set(), [f"denylist unreadable at {path}: {exc}"]
    names = doc.get("handles")
    if not isinstance(names, list) or not names:
        return set(), [f"denylist at {path} carries no handles"]
    return {str(n).lower() for n in names if str(n).strip()}, []


def _committed_files(ref: str, root: Path) -> tuple[list[str], list[str]]:
    try:
        out = subprocess.run(
            ["git", "ls-tree", "-r", "--name-only", ref],
            cwd=root, capture_output=True, text=True, check=False,
        )
    except OSError as exc:
        return [], [f"cannot list the committed tree at {ref}: {exc}"]
    if out.returncode != 0:
        return [], [f"cannot list the committed tree at {ref}: {out.stderr.strip()}"]
    return [l for l in out.stdout.splitlines() if l.strip()], []


def findings(ref: str = "HEAD", root: Path = REPO_ROOT) -> tuple[list[str], list[str]]:
    """(findings, tool_errors). A tool error is never a verdict."""
    handles, errs = _handles()
    if errs:
        return [], errs
    files, errs = _committed_files(ref, root)
    if errs:
        return [], errs
    found: list[str] = []
    for rel in files:
        if not rel.startswith("athanor_artifacts/"):
            continue
        path = root / rel
        if not path.is_file():
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError as exc:
            return [], [f"cannot read {rel}: {exc}"]
        seen: set[tuple[int, str]] = set()
        for lineno, line in enumerate(text.splitlines(), 1):
            for match in _SCRATCH_ROOT.finditer(line):
                segment = match.group("segment")
                # A segment is named after a person if a denylisted handle appears
                # as a WORD inside it -- `dexter_plic_granu_scout` does, `dexterity`
                # would not, and neither would an unrelated `plic_granu_scout`.
                for part in re.split(r"[._-]+", segment):
                    if part.lower() in handles:
                        key = (lineno, segment)
                        if key not in seen:
                            seen.add(key)
                            found.append(
                                f"{rel}:{lineno}: working-directory segment "
                                f"{segment!r} is named after a fleet-agent handle"
                            )
                        break
    return sorted(found), []


def _baseline(path: Path, explicit: bool) -> tuple[set[str], list[str]]:
    if not path.is_file():
        if explicit:
            return set(), [f"baseline file missing: {path}"]
        # Default path absent = the class is closed. See the module docstring:
        # treating that as a tool error makes FINISHING the job unable to pass.
        return set(), []
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return set(), [f"baseline unparseable at {path}: {exc}"]
    entries = doc.get("entries")
    if not isinstance(entries, list):
        return set(), [f"baseline at {path} has no entries list"]
    return {str(e) for e in entries}, []


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ref", default="HEAD")
    parser.add_argument("--root", type=Path, default=REPO_ROOT)
    parser.add_argument("--baseline", type=Path, default=None)
    parser.add_argument("--no-baseline", action="store_true")
    parser.add_argument(
        "--emit-baseline", action="store_true",
        help="print a baseline DERIVED from this run (never hand-list it)",
    )
    args = parser.parse_args(argv)

    found, errs = findings(args.ref, args.root)
    if errs:
        for e in errs:
            print(f"TOOL-ERROR: {e}; NO VERDICT.", file=sys.stderr)
        return 2

    if args.emit_baseline:
        print(json.dumps({
            "schema": "ath3397_known_scratch_paths_v1",
            "why": "Working-directory segments named after a fleet agent that were "
                   "ALREADY committed when this check landed. DERIVED from the "
                   "checker's own output. Each entry is a DEFECT AWAITING "
                   "NORMALISATION, not accepted state. Entries leave as they are "
                   "corrected; delete the file when empty.",
            "corrected_by": "ATH-3397 scratch-path normalisation",
            "entries": found,
        }, indent=1))
        return 0

    if args.no_baseline:
        known: set[str] = set()
    else:
        explicit = args.baseline is not None
        known, errs = _baseline(args.baseline or BASELINE_PATH, explicit)
        if errs:
            for e in errs:
                print(f"TOOL-ERROR: {e}; NO VERDICT.", file=sys.stderr)
            return 2

    unbaselined = [f for f in found if f not in known]
    orphaned = sorted(known - set(found))

    if orphaned:
        print(
            f"\nFAIL: {len(orphaned)} baseline entr(ies) match nothing. The path was "
            f"normalised but the baseline still lists it -- remove the entry, or the "
            f"file becomes a list of things that used to be wrong:", file=sys.stderr)
        for o in orphaned:
            print(f"  orphaned-baseline: {o}", file=sys.stderr)
        return 1

    if unbaselined:
        print(f"\nFAIL: {len(unbaselined)} working-directory path(s) named after a "
              f"fleet agent, not in the baseline:", file=sys.stderr)
        for u in unbaselined:
            print(f"  {u}", file=sys.stderr)
        print(
            "\nA published artifact must not carry a path named after whoever "
            "generated it. Name the working directory for the WORK, not the worker.",
            file=sys.stderr)
        return 1

    if known:
        print(f"KNOWN (ATH-3397): {len(known)} baselined scratch-path instance(s) "
              f"still present -- defects awaiting normalisation, not accepted state.")
        return 0

    print(f"OK: no published artifact carries a working-directory path named after a "
          f"fleet agent ({args.ref}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
