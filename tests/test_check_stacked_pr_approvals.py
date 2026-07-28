"""A stacked PR must meet the same approval bar as a default-branch one.

Both polarities plus a non-vacuity guard: a check that only ever sees
default-branch PRs is green on a repo with no stacks, which is `all([])` wearing
an approval gate.
"""

from __future__ import annotations

import pytest

from athanor import check_stacked_pr_approvals as chk


DEFAULT = "main"
HEAD = "a" * 40
OLD = "b" * 40


def _pr(base: str, head: str = HEAD, number: int = 90) -> dict:
    return {"number": number, "base": {"ref": base}, "head": {"sha": head}}


def _review(login: str, state: str, sha: str = HEAD) -> dict:
    return {"user": {"login": login}, "state": state, "commit_id": sha}


def test_a_stacked_pr_under_the_bar_reds() -> None:
    """THE LIVE INSTANCE: c910 #90, base perry/ath3444-validator-baseline, one arm."""
    code, msg = chk.evaluate(
        _pr("perry/ath3444-validator-baseline"),
        [_review("athanor-quan[bot]", "APPROVED")],
        DEFAULT,
    )
    assert code == 1, msg
    assert "1 approval(s)" in msg and "needs 2" in msg


def test_a_stacked_pr_at_the_bar_passes() -> None:
    """NARROWNESS. A check that reds every stacked PR would be routed around in a
    day; the claim is about the BAR, not about stacking."""
    code, msg = chk.evaluate(
        _pr("perry/ath3444-validator-baseline"),
        [_review("athanor-quan[bot]", "APPROVED"),
         _review("athanor-dexter[bot]", "APPROVED")],
        DEFAULT,
    )
    assert code == 0, msg


def test_a_default_branch_pr_is_not_this_check_s_business() -> None:
    """Branch protection already governs these. Reporting on them would produce a
    second, weaker authority over a branch that already has one."""
    code, msg = chk.evaluate(_pr(DEFAULT), [], DEFAULT)
    assert code == 0, msg
    assert "not applicable" in msg


def test_an_approval_on_an_OLDER_HEAD_does_not_count() -> None:
    """THE ibex #62 DEFECT, pinned. Its reviewDecision read APPROVED on an arm ten
    commits and 1,383 lines back, because GitHub aggregates approvals without
    regard to the commit they name. An approval names a commit."""
    code, msg = chk.evaluate(
        _pr("perry/stack-base"),
        [_review("athanor-quan[bot]", "APPROVED"),
         _review("athanor-dexter[bot]", "APPROVED", sha=OLD)],
        DEFAULT,
    )
    assert code == 1, msg
    assert "1 approval(s)" in msg


def test_a_reviewer_who_later_requested_changes_is_not_an_approver() -> None:
    """LATEST PER REVIEWER. Counting every APPROVED row would let a superseded
    approval keep a PR alive against the reviewer's own current position."""
    code, msg = chk.evaluate(
        _pr("perry/stack-base"),
        [_review("athanor-quan[bot]", "APPROVED"),
         _review("athanor-dexter[bot]", "APPROVED"),
         _review("athanor-dexter[bot]", "CHANGES_REQUESTED")],
        DEFAULT,
    )
    assert code == 1, msg


def test_one_reviewer_cannot_be_two_approvals() -> None:
    """Deduplication by login. Two APPROVED rows from one reviewer at the same
    head is one arm, however many times they pressed the button."""
    code, msg = chk.evaluate(
        _pr("perry/stack-base"),
        [_review("athanor-quan[bot]", "APPROVED"),
         _review("athanor-quan[bot]", "APPROVED")],
        DEFAULT,
    )
    assert code == 1, msg


def test_a_dismissed_or_commented_review_changes_nothing() -> None:
    code, msg = chk.evaluate(
        _pr("perry/stack-base"),
        [_review("athanor-quan[bot]", "APPROVED"),
         _review("athanor-bob[bot]", "DISMISSED"),
         _review("athanor-cody[bot]", "COMMENTED")],
        DEFAULT,
    )
    assert code == 1, msg


def test_a_malformed_payload_is_rc2_not_a_pass() -> None:
    """COULD-NOT-DETERMINE IS NEVER A VERDICT. With no base ref the PR is not
    classifiable, and treating that as 'not a stack' would make every unreadable
    payload compliant."""
    code, msg = chk.evaluate({"number": 1, "base": {}, "head": {}}, [], DEFAULT)
    assert code == 2, msg
    assert "NO VERDICT" in msg


@pytest.mark.parametrize("default", ["main", "master"])
def test_the_default_branch_is_read_not_assumed(default: str) -> None:
    """ibex's default is `master` and openc910's is `main`. A hardcoded 'main'
    would classify every ibex PR as a stack and red the whole repo."""
    code, _ = chk.evaluate(_pr(default), [], default)
    assert code == 0


def test_the_population_contains_a_stacked_pr_or_this_suite_proves_nothing() -> None:
    """NON-VACUITY GUARD.

    Every assertion above is about stacked PRs. If the fixtures only ever built
    default-branch ones, the suite would pass while testing nothing -- the same
    `all([])` shape as a coverage report over an empty population. This asserts
    the discriminating case is actually constructible and actually discriminates:
    the SAME reviews produce opposite verdicts either side of the base ref.
    """
    reviews = [_review("athanor-quan[bot]", "APPROVED")]
    stacked, _ = chk.evaluate(_pr("perry/stack-base"), reviews, DEFAULT)
    on_default, _ = chk.evaluate(_pr(DEFAULT), reviews, DEFAULT)
    assert stacked == 1, "the stacked case must be constructible and must red"
    assert on_default == 0, "the default-branch case must be untouched"
    assert stacked != on_default, "base ref must be what decides, not the reviews"
