#!/usr/bin/env python3
"""Prove a scrub left no stale hash behind (ATH-3397).

This answers ONE question, narrowly: for every file this change edits, has every
occurrence of that file's OLD hash been updated?

It deliberately does NOT classify citations. A general citation classifier --
which entry is a citation, which is a semantic field, which is an external
reference -- is a genuinely hard problem, and the version being reviewed on #81
has produced five population corrections and six adversarial rounds without
converging. This check does not need any of it: the scrub's population is a list
of OLD HASHES it already holds, and a literal string is unambiguous. That makes
it STRONGER than the classifier for this job, not weaker -- it cannot miss an
occurrence by misjudging what kind of reference it was, because it never judges.

    diff base..worktree  ->  for each changed file, its OLD sha256
    grep the whole tree  ->  any surviving occurrence of an old hash is a finding

Every file type is covered, including ones no classifier looks at: SHA256SUMS
lines, inline receipt maps, prose, replay scripts, READMEs, and files added after
the classifier's role list was written. Matching is case-insensitive because
published hashes appear in both cases.

Exit codes follow the repo-wide contract:
    0  ran, clean
    1  ran, found a surviving old hash
    2  COULD NOT RUN (tool defect) -- never reported as clean
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]

EXIT_CLEAN = 0
EXIT_FOUND = 1
EXIT_TOOL_ERROR = 2

# Directories that are not part of the published tree.
SKIP_DIRS = {".git", "__pycache__", ".pytest_cache"}


class ToolError(Exception):
    """The check could not run. Never reported as clean."""


def _git(*args: str, root: Path) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(
            ["git", *args], cwd=root, capture_output=True, check=False
        )
    except OSError as exc:  # git missing entirely
        raise ToolError(f"git could not be run: {exc}") from exc


def changed_files(base: str, root: Path) -> list[str]:
    """Files this change edits, relative to the repo root."""
    probe = _git("rev-parse", "--verify", f"{base}^{{commit}}", root=root)
    if probe.returncode != 0:
        raise ToolError(
            f"base ref {base!r} does not resolve -- refusing to report a scrub "
            f"clean against a base that could not be read"
        )
    result = _git("diff", "--name-only", "--diff-filter=M", base, root=root)
    if result.returncode != 0:
        raise ToolError(f"git diff against {base} failed: {result.stderr.decode()[:200]}")
    return [line for line in result.stdout.decode().splitlines() if line.strip()]


def old_hashes(base: str, paths: list[str], root: Path) -> dict[str, str]:
    """sha256 each changed file had AT THE BASE -- the value a citation would hold."""
    out: dict[str, str] = {}
    for rel in paths:
        blob = _git("show", f"{base}:{rel}", root=root)
        if blob.returncode != 0:
            # Modified-but-unreadable at base is a defect in the check's input,
            # not a clean result.
            raise ToolError(f"could not read {rel} at {base}")
        out[rel] = hashlib.sha256(blob.stdout).hexdigest()
    return out


_HEX64_ANY = re.compile(r"(?i)(?<![0-9a-z])[0-9a-f]{64}(?![0-9a-z])")


def _hash_occurrences(node: object, trail: str = "") -> list[tuple[str, str]]:
    """(json_path, hash) for every 64-hex string, each with a UNIQUE path."""
    found: list[tuple[str, str]] = []
    if isinstance(node, dict):
        for key, value in node.items():
            found.extend(_hash_occurrences(value, f"{trail}.{key}" if trail else key))
    elif isinstance(node, list):
        for index, item in enumerate(node):
            found.extend(_hash_occurrences(item, f"{trail}[{index}]"))
    elif isinstance(node, str) and _HEX64_ANY.fullmatch(node):
        found.append((trail, node.lower()))
    return found


def excused_paths(path: Path, root: Path) -> set[str]:
    """The exact JSON PATHS an old hash is allowed to occupy.

    Identity, not arithmetic. An earlier repair counted how many occurrences the
    valid records accounted for, and counting cannot survive NESTING: a valid
    record containing another valid record has the inner occurrence counted by
    the outer record AND again by the recursive walk, so the total exceeds the
    physical occurrences and an unrelated sibling citation is excused by the
    surplus. Paths are unique, so the same occurrence marked twice is still one
    path -- and reporting by path also fixes the attribution, which counting
    could only ever approximate.

    An old hash may survive ONLY ALONGSIDE ITS REPLACEMENT, inside a record that
    can prove what replaced it:

    (a) STRUCTURAL CONTAINMENT, not proximity -- only that record's own
        occurrences are excused.
    (b) The replacement must be the NAMED FILE'S CURRENT CONTENT HASH, so it is
        verifiable rather than merely present.
    (c) A CHAIN may co-occur (old1, old2, current) inside one record.

    Condition (b) is why no key-name list is needed: a supersession is not a
    thing with a NAME, it is an old hash that can prove what replaced it.
    """
    if path.suffix.lower() != ".json":
        return set()
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return set()
    excused: set[str] = set()

    def walk(node: object, trail: str = "") -> None:
        if isinstance(node, dict):
            for key, value in node.items():
                where = f"{trail}.{key}" if trail else key
                if isinstance(value, dict):
                    target = None
                    for base in (path.parent, root):
                        candidate = base / key
                        if candidate.is_file():
                            target = candidate
                            break
                    if target is not None:
                        occurrences = _hash_occurrences(value, where)
                        current = hashlib.sha256(target.read_bytes()).hexdigest()
                        if current in {h for _, h in occurrences}:
                            excused.update(
                                p for p, h in occurrences if h != current
                            )
                walk(value, where)
        elif isinstance(node, list):
            for index, item in enumerate(node):
                walk(item, f"{trail}[{index}]")

    walk(doc)
    return excused


def surviving_occurrences(hashes: dict[str, str], root: Path) -> list[str]:
    """Every place an old hash still appears in the committed tree."""
    wanted = {sha.lower(): rel for rel, sha in hashes.items()}
    findings: list[str] = []
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError as exc:
            raise ToolError(f"could not read {path} while sweeping: {exc}") from exc
        lowered = text.lower()
        if path.suffix.lower() == ".json":
            # Exact occurrence identity: report the JSON PATHS that no
            # supersession record accounts for, so the finding names the
            # offending occurrence rather than the first matching line.
            try:
                doc = json.loads(text)
            except ValueError:
                doc = None
            if doc is not None:
                excused = excused_paths(path, root)
                for where_path, sha in _hash_occurrences(doc):
                    owner = wanted.get(sha)
                    if owner is None or where_path in excused:
                        continue
                    findings.append(
                        f"{path.relative_to(root)}:{where_path}: still cites the OLD "
                        f"hash of {owner} ({sha[:12]}...) -- update it in the same commit"
                    )
                continue
        for sha, owner in wanted.items():
            if sha not in lowered:
                continue
            where = path.relative_to(root)
            for lineno, line in enumerate(text.splitlines(), 1):
                if sha in line.lower():
                    findings.append(
                        f"{where}:{lineno}: still cites the OLD hash of {owner} "
                        f"({sha[:12]}...) -- update it in the same commit"
                    )
    return findings


def check(base: str, root: Path = REPO_ROOT) -> list[str]:
    paths = changed_files(base, root)
    if not paths:
        return []
    return surviving_occurrences(old_hashes(base, paths, root), root)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--base",
        default="origin/main",
        help="ref the scrub is measured against, default: origin/main",
    )
    parser.add_argument("--root", type=Path, default=REPO_ROOT)
    args = parser.parse_args(argv)
    try:
        findings = check(args.base, args.root)
    except ToolError as exc:
        print(f"TOOL ERROR: {exc}", file=sys.stderr)
        return EXIT_TOOL_ERROR
    if findings:
        for finding in findings:
            print(f"FAIL: {finding}", file=sys.stderr)
        print(
            f"\n{len(findings)} surviving reference(s) to a pre-scrub hash. The scrub "
            f"and every citation of it must land in ONE commit.",
            file=sys.stderr,
        )
        return EXIT_FOUND
    print(f"OK: no pre-scrub hash survives anywhere in the tree (base {args.base})")
    return EXIT_CLEAN


if __name__ == "__main__":
    sys.exit(main())
