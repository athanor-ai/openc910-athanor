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


def _object_spans(text: str) -> list[tuple[int, int]]:
    """(start, end) of every JSON object in the raw text, string-aware.

    Spans are computed on the TEXT because the identity that matters is a literal
    occurrence, not a parsed scalar. json.loads() cannot supply this: it drops a
    hash embedded INSIDE a longer string, and it silently collapses duplicate
    keys, so both hide an occurrence that is physically present in the file.
    """
    spans: list[tuple[int, int]] = []
    stack: list[int] = []
    in_string = False
    escaped = False
    for index, char in enumerate(text):
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue
        if char == '"':
            in_string = True
        elif char == "{":
            stack.append(index)
        elif char == "}" and stack:
            spans.append((stack.pop(), index))
    return spans


_KEY_BEFORE = re.compile(r'"((?:[^"\\]|\\.)*)"\s*:\s*$')


def _key_naming(text: str, start: int) -> str | None:
    """The key an object is bound to, read from the text immediately before it."""
    match = _KEY_BEFORE.search(text[:start])
    return match.group(1) if match else None


def excused_spans(path: Path, root: Path, old_of: dict[str, str]) -> set[int]:
    """Offsets of hash occurrences a supersession record legitimately accounts for.

    Identity is the literal OCCURRENCE OFFSET -- unique by construction, unlike a
    dotted path string, which collides when a key is literally named like a
    nested path.

    An occurrence is excused only when ALL of these hold:
      (a) CONTAINMENT   it lies inside a record object, and only that object's
                        own occurrences are excused;
      (b) REPLACEMENT   that object contains the NAMED FILE'S CURRENT content
                        hash, so the record proves what replaced it;
      (c) SUBJECT       the occurrence is the old hash OF THAT SAME FILE. Without
                        this a valid record for one file excuses an unrelated
                        file's stale hash parked inside it -- the record must be
                        ABOUT the transition it is excusing.
    """
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return set()
    excused: set[int] = set()
    for start, end in _object_spans(text):
        key = _key_naming(text, start)
        if not key:
            continue
        target = None
        for base in (path.parent, root):
            candidate = base / key
            if candidate.is_file():
                target = candidate
                break
        if target is None:
            continue
        try:
            rel = str(target.resolve().relative_to(root.resolve()))
        except ValueError:
            continue
        prior = old_of.get(rel)
        if prior is None:
            continue
        body = text[start:end + 1]
        current = hashlib.sha256(target.read_bytes()).hexdigest()
        if current.lower() not in body.lower():
            continue
        # Only THIS file's prior hash, and only inside THIS object.
        for match in re.finditer(re.escape(prior), body, re.IGNORECASE):
            excused.add(start + match.start())
    return excused


def surviving_occurrences(hashes: dict[str, str], root: Path) -> list[str]:
    """Every place an old hash still appears in the committed tree."""
    wanted = {sha.lower(): rel for rel, sha in hashes.items()}
    old_of = {rel: sha.lower() for rel, sha in hashes.items()}
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
        # Literal occurrences, located in the TEXT. Every reference is found the
        # same way regardless of file type; only the EXEMPTION knows about JSON.
        excused = excused_spans(path, root, old_of) if path.suffix.lower() == ".json" else set()
        for sha, owner in wanted.items():
            for match in re.finditer(re.escape(sha), lowered):
                if match.start() in excused:
                    continue
                lineno = lowered.count("\n", 0, match.start()) + 1
                line_start = text.rfind("\n", 0, match.start()) + 1
                line_end = text.find("\n", match.start())
                context = text[line_start:line_end if line_end != -1 else None].strip()
                findings.append(
                    f"{path.relative_to(root)}:{lineno}: still cites the OLD hash of "
                    f"{owner} ({sha[:12]}...) -- update it in the same commit"
                    f" [{context[:80]}]"
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
