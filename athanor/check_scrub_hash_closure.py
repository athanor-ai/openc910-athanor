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
    # MODIFIED **and DELETED**. --diff-filter=M alone meant DELETING a file
    # produced an empty changed set, so the check returned clean while the
    # deleted file's old hash was still cited -- deletion is the strongest
    # possible scrub and it disabled the gate entirely. --no-renames decomposes a
    # rename into delete+add so the old path is always visible.
    result = _git(
        "diff", "--no-renames", "--name-only", "--diff-filter=MD", base, root=root
    )
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


def _string_values(node: object) -> set[str]:
    """Every STRING VALUE in a parsed object, exactly as parsed."""
    found: set[str] = set()
    if isinstance(node, dict):
        for value in node.values():
            found |= _string_values(value)
    elif isinstance(node, list):
        for item in node:
            found |= _string_values(item)
    elif isinstance(node, str):
        found.add(node)
    return found


def excused_spans(path: Path, root: Path, old_of: dict[str, str]) -> set[int]:
    """Offsets of hash occurrences a supersession record legitimately accounts for.

    Identity is the literal OCCURRENCE OFFSET -- unique by construction. But an
    offset alone cannot say whether a RECORD exists, so the exemption is granted
    only from PARSED structure:

      SYNTAX      the file must parse, and so must the record object. A raw brace
                  scan happily finds spans in malformed JSON, so trailing commas
                  earned an exemption from a file that is not a record at all.
      REPLACEMENT some VALUE must EQUAL the file's current hash. Substring
                  containment let "not-a-replacement-<CURRENT>-tail" pose as the
                  replacement while no value was the hash.
      SUBJECT     the occurrence must be that same file's own prior hash.
      CONTAINMENT only the record's own occurrences are excused.

    Keys are read DECODED: a JSON key may be escaped (NOTES\\u002emd) and still
    name NOTES.md, so comparing raw key text produces false findings.
    """
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return set()
    try:
        json.loads(text)
    except ValueError:
        # A file that does not parse cannot establish that any record exists.
        # Fail closed: it earns no exemptions at all.
        return set()
    excused: set[int] = set()
    for start, end in _object_spans(text):
        raw_key = _key_naming(text, start)
        if raw_key is None:
            continue
        try:
            key = json.loads(f'"{raw_key}"')
        except ValueError:
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
        try:
            record = json.loads(body)
        except ValueError:
            continue
        current = hashlib.sha256(target.read_bytes()).hexdigest()
        values = {v.lower() for v in _string_values(record)}
        if current.lower() not in values:
            continue
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
