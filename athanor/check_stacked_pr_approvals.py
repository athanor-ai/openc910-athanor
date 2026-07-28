#!/usr/bin/env python3
"""A stacked PR must meet the same approval bar as one targeting the default branch.

WHY THIS EXISTS AT THE PR LAYER AND NOT THE RULESET LAYER (ATH-3450, 2026-07-28).

Branch protection is per-branch. A ruleset on the default branch does not govern
a PR whose base is a feature branch, so a stack's internal merges are unprotected
while its external merge is not. Measured on openc910:

    #89  base main                              REVIEW_REQUIRED  BLOCKED
    #91  base main                              REVIEW_REQUIRED  BLOCKED
    #90  base perry/ath3444-validator-baseline  APPROVED  CLEAN   <- one arm

The obvious fix -- a ruleset targeting every branch -- WAS TRIED, ACTIVE, ON FOUR
REPOS. It refused commits to every feature branch: a `pull_request` rule's
mechanism is refusing direct pushes to targeted branches, and there is no
merge-versus-push discriminator. Reverted after ~2 minutes. So the property we
want,

    TWO ARMS ON A STACK MERGE, and nothing else,

is not expressible at the ruleset layer at all. It is expressible here.

WHAT "AT HEAD" MEANS AND WHY IT IS THE WHOLE CHECK. An approval names a commit.
GitHub's `reviewDecision` aggregates approvals regardless of how far behind the
head they sit -- ibex #62 read APPROVED on an arm ten commits and 1,383 lines
stale. So this counts only approvals bound to the CURRENT head sha, and only the
latest review per reviewer, because a reviewer who approved and later requested
changes has not approved.

Exit codes: 0 satisfied or not applicable, 1 finding, 2 could-not-determine.
A could-not-determine is never a verdict -- with no review data every PR looks
compliant, which is the most dangerous possible false green for an approval gate.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys

REQUIRED_APPROVALS = 2


def _gh_json(path: str, token: str | None) -> tuple[object | None, str | None]:
    """GET a REST path via the gh CLI. (payload, error)."""
    env = dict(os.environ)
    if token:
        env["GH_TOKEN"] = token
    try:
        out = subprocess.run(
            ["gh", "api", path],
            capture_output=True, text=True, check=False, env=env,
        )
    except OSError as exc:
        return None, f"cannot invoke gh for {path}: {exc}"
    if out.returncode != 0:
        return None, f"gh api {path} failed: {out.stderr.strip()[:200]}"
    try:
        return json.loads(out.stdout), None
    except ValueError as exc:
        return None, f"gh api {path} returned unparseable JSON: {exc}"


def approvals_at_head(reviews: list[dict], head_sha: str) -> set[str]:
    """Logins whose LATEST review approves the CURRENT head.

    Two reductions, both load-bearing:

    * LATEST PER REVIEWER. A reviewer who approved at head and then requested
      changes at head has not approved. Counting every APPROVED row would let a
      superseded approval keep a PR alive against its own author's reviewer.
    * BOUND TO THIS HEAD. An approval names a commit; an approval of a different
      commit is a fact about that commit. This is the ibex #62 defect, which
      read APPROVED on an arm ten commits back.
    """
    latest: dict[str, str] = {}
    for review in reviews:
        state = review.get("state")
        # COMMENTED does not change a reviewer's standing position, and
        # DISMISSED means the platform already discarded it.
        if state not in {"APPROVED", "CHANGES_REQUESTED"}:
            continue
        if review.get("commit_id") != head_sha:
            continue
        login = (review.get("user") or {}).get("login")
        if login:
            latest[login] = state
    return {who for who, state in latest.items() if state == "APPROVED"}


def evaluate(pr: dict, reviews: list[dict], default_branch: str) -> tuple[int, str]:
    """(exit_code, message). Pure -- no I/O, so both polarities are testable."""
    base = (pr.get("base") or {}).get("ref")
    head_sha = (pr.get("head") or {}).get("sha")
    number = pr.get("number")
    if not base or not head_sha:
        return 2, "pull request payload carries no base ref or head sha; NO VERDICT."
    if base == default_branch:
        return 0, (
            f"not applicable: #{number} targets the default branch "
            f"({default_branch}), which branch protection already governs."
        )
    approvers = approvals_at_head(reviews, head_sha)
    if len(approvers) >= REQUIRED_APPROVALS:
        return 0, (
            f"OK: stacked PR #{number} (base {base!r}) carries "
            f"{len(approvers)} approval(s) at {head_sha[:10]} — "
            f"{', '.join(sorted(approvers))}."
        )
    return 1, (
        f"STACKED PR UNDER THE APPROVAL BAR: #{number} targets {base!r}, not the "
        f"default branch, so branch protection does not govern its merge. It "
        f"carries {len(approvers)} approval(s) at head {head_sha[:10]} and needs "
        f"{REQUIRED_APPROVALS}.\n"
        f"  A stack's internal merges must meet the same bar as its external one; "
        f"otherwise a reviewer of the parent PR inherits content approved to a "
        f"lower standard than the one they are applying."
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True, help="owner/name")
    parser.add_argument("--pr", required=True, type=int)
    parser.add_argument("--token", default=os.environ.get("GH_TOKEN"))
    args = parser.parse_args(argv)

    repo_doc, err = _gh_json(f"repos/{args.repo}", args.token)
    if err or not isinstance(repo_doc, dict):
        print(f"TOOL-ERROR: {err or 'unreadable repo'}; NO VERDICT.", file=sys.stderr)
        return 2
    default_branch = repo_doc.get("default_branch")
    if not default_branch:
        print("TOOL-ERROR: repo reports no default branch; NO VERDICT.", file=sys.stderr)
        return 2

    pr, err = _gh_json(f"repos/{args.repo}/pulls/{args.pr}", args.token)
    if err or not isinstance(pr, dict):
        print(f"TOOL-ERROR: {err or 'unreadable pull request'}; NO VERDICT.",
              file=sys.stderr)
        return 2

    reviews, err = _gh_json(f"repos/{args.repo}/pulls/{args.pr}/reviews?per_page=100",
                            args.token)
    if err or not isinstance(reviews, list):
        # NEVER fall back to "no reviews found". Absent review data and zero
        # approvals are opposite verdicts and only one of them is a measurement.
        print(f"TOOL-ERROR: {err or 'unreadable reviews'}; NO VERDICT.", file=sys.stderr)
        return 2

    code, message = evaluate(pr, reviews, default_branch)
    print(message, file=sys.stderr if code else sys.stdout)
    return code


if __name__ == "__main__":
    sys.exit(main())
