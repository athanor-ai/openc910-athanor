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


def _base_blobs(base: str, root: Path) -> dict[str, str]:
    """path -> sha256 of its CONTENT at the base, for every file in the base tree."""
    listing = _git("ls-tree", "-r", "-z", base, root=root)
    if listing.returncode != 0:
        raise ToolError(
            f"could not read the tree at {base!r} -- refusing to report a scrub "
            f"clean against a base that could not be enumerated"
        )
    entries: list[tuple[str, str]] = []
    for record in listing.stdout.decode("utf-8", "surrogateescape").split("\0"):
        if not record.strip():
            continue
        # "<mode> <type> <oid>\t<path>"
        meta, _, path = record.partition("\t")
        fields = meta.split()
        if len(fields) < 3 or fields[1] != "blob":
            continue
        entries.append((fields[2], path))
    if not entries:
        return {}
    proc = subprocess.run(
        ["git", "cat-file", "--batch"],
        cwd=root,
        input=("\n".join(oid for oid, _ in entries) + "\n").encode(),
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        raise ToolError(f"could not read blobs at {base!r}")
    out = proc.stdout
    result: dict[str, str] = {}
    offset = 0
    for _, path in entries:
        newline = out.index(b"\n", offset)
        header = out[offset:newline].split()
        size = int(header[2])
        body = out[newline + 1:newline + 1 + size]
        result[path] = hashlib.sha256(body).hexdigest()
        offset = newline + 1 + size + 1
    return result


def superseded_content(base: str, root: Path) -> dict[str, str]:
    """path -> the base content hash that PATH no longer has.

    PER PATH, and COMMITTED bytes on both sides. Two earlier shapes each lost
    something the rule needs:

      a git STATUS list     enumerated how the tree CHANGED instead of asking
                            whether content was superseded, and failed in both
                            directions -- typechange missed, chmod-only invented
      a global CONTENT set  discarded PATH IDENTITY. One identical copy ANYWHERE
                            laundered a changed file's old hash, and because the
                            set walked the host worktree, an UNTRACKED file
                            outside the subject controlled the denominator

    Comparing base[path] to head[path] keeps the content predicate and restores
    identity. Mode-only change is excluded for free (same blob); typechange and
    deletion are included for free (different blob, or absent).
    """
    probe = _git("rev-parse", "--verify", f"{base}^{{commit}}", root=root)
    if probe.returncode != 0:
        raise ToolError(
            f"base ref {base!r} does not resolve -- refusing to report a scrub "
            f"clean against a base that could not be read"
        )
    at_base = _base_blobs(base, root)
    at_head = _base_blobs("HEAD", root)
    return {
        path: sha for path, sha in at_base.items() if at_head.get(path) != sha
    }


def moved_content(base: str, root: Path) -> dict[str, str]:
    """path -> another COMMITTED path now holding exactly its base content.

    A content-preserving rename cannot be RESOLVED by this checker: a citation
    of the moved hash may be CORRECT (the receipt was updated to the new path)
    or STALE (it still names the old one), and the hash alone cannot tell them
    apart. Silently reddening a correct citation and silently passing a stale
    one are both wrong, so this is reported as an explicit, named refusal.
    """
    at_base = _base_blobs(base, root)
    at_head = _base_blobs("HEAD", root)
    first_at: dict[str, str] = {}
    for path, sha in at_head.items():
        first_at.setdefault(sha, path)
    moved: dict[str, str] = {}
    for path, sha in at_base.items():
        if at_head.get(path) == sha:
            continue
        landed = first_at.get(sha)
        if landed is not None and landed != path:
            moved[path] = landed
    return moved


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
    # COMMITTED paths only. Sweeping the host worktree let an UNTRACKED file --
    # something outside the change under review entirely -- take part in the
    # verdict. The subject of this check is the committed tree.
    listing = _git("ls-tree", "-r", "-z", "--name-only", "HEAD", root=root)
    if listing.returncode != 0:
        raise ToolError("could not enumerate the committed tree at HEAD")
    committed = [
        p for p in listing.stdout.decode("utf-8", "surrogateescape").split("\0") if p
    ]
    for rel in sorted(committed):
        path = root / rel
        if not path.is_file():
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
    gone = superseded_content(base, root)
    findings: list[str] = []
    for path, landed in sorted(moved_content(base, root).items()):
        # A NAMED REFUSAL, not a silent verdict either way.
        findings.append(
            f"{path}: content moved to {landed} unchanged. A citation of its hash "
            f"may be correct (receipt updated to the new path) or stale (still "
            f"naming the old one), and the hash cannot distinguish them -- "
            f"rename is not supported by this check; confirm the citation by hand"
        )
    if gone:
        findings.extend(surviving_occurrences(gone, root))
    return findings


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
