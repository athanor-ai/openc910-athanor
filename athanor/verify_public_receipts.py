#!/usr/bin/env python3
"""Verify public Athanor receipt packages in this fork.

The verifier is intentionally small: each package under ``athanor_artifacts``
must provide ``SHA256SUMS`` and any ``receipt.json`` must parse. Replay scripts
remain package-local because they depend on the caller's pinned Yosys/Liberty
paths.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
ARTIFACT_ROOT = REPO_ROOT / "athanor_artifacts"


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _verify_sums(package: Path) -> list[str]:
    problems: list[str] = []
    sums_path = package / "SHA256SUMS"
    if not sums_path.is_file():
        return [f"{package.relative_to(REPO_ROOT)} missing SHA256SUMS"]
    for lineno, raw in enumerate(sums_path.read_text(encoding="utf-8").splitlines(), 1):
        if not raw.strip():
            continue
        try:
            expected, rel = raw.split(maxsplit=1)
        except ValueError:
            problems.append(f"{sums_path.relative_to(REPO_ROOT)}:{lineno}: malformed line")
            continue
        rel = rel.removeprefix("./")
        target = package / rel
        if not target.is_file():
            problems.append(f"{sums_path.relative_to(REPO_ROOT)}:{lineno}: missing {rel}")
            continue
        got = _sha256(target)
        if got != expected:
            problems.append(
                f"{target.relative_to(REPO_ROOT)} sha256 mismatch: {got} != {expected}"
            )
    return problems


def _verify_receipt_json(package: Path) -> list[str]:
    receipt = package / "receipt.json"
    if not receipt.exists():
        return []
    try:
        json.loads(receipt.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return [f"{receipt.relative_to(REPO_ROOT)} JSON parse failed: {exc}"]
    return []


def verify(root: Path = ARTIFACT_ROOT) -> list[str]:
    if not root.is_dir():
        return [f"{root.relative_to(REPO_ROOT)} is missing"]
    problems: list[str] = []
    packages = [p for p in sorted(root.iterdir()) if p.is_dir()]
    if not packages:
        return [f"{root.relative_to(REPO_ROOT)} has no package directories"]
    for package in packages:
        problems.extend(_verify_sums(package))
        problems.extend(_verify_receipt_json(package))
    return problems


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--artifact-root",
        type=Path,
        default=ARTIFACT_ROOT,
        help="artifact package root, default: athanor_artifacts",
    )
    args = parser.parse_args(argv)

    problems = verify(args.artifact_root)
    if problems:
        for problem in problems:
            print(f"FAIL: {problem}", file=sys.stderr)
        return 1
    print(f"OK: verified public receipts under {args.artifact_root.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
