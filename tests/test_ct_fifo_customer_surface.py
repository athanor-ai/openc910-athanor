"""ct_fifo customer-surface invariants (ATH-3445).

This test used to pin VALUES: `customer_ready is True` plus a set of literal
README phrases. #74 (ATH-3180) deliberately retracted that claim -- it set the
receipt to `false` AND rewrote the README to say the packet is not current-bar
customer-ready, coherently, in one change. So the test was STALE, not a caught
regression, and the diff that moved the value is what distinguishes those.

Re-pinning it to the NEW literals would have been the wrong repair. A
values-pinned test RATIFIES whatever is in the tree: it would pass today, and it
would pass equally if someone flipped the receipt back to `true` while the README
still said not-customer-ready -- and that contradiction is exactly what ships a
false claim to a customer. The test would be green through the failure it exists
to prevent.

So this pins the INVARIANT instead: the receipt's `customer_ready` and the
README's status prose must AGREE, whichever way the bar has moved. Both
directions are caught, it survives the next bar change without an edit, and it is
derived rather than another hand-maintained list of expected strings.
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
CT_FIFO = REPO_ROOT / "athanor_artifacts" / "ct_fifo"

# The README's own vocabulary for the two positions.
_NOT_READY_PROSE = "NOT current-bar customer-ready"
_READY_PROSE = "customer-ready only for the scoped"


def _readme_says_ready(readme_flat: str) -> bool | None:
    """True/False when the prose states a position, None when it states neither."""
    not_ready = _NOT_READY_PROSE.lower() in readme_flat.lower()
    ready = _READY_PROSE.lower() in readme_flat.lower()
    if not_ready and not ready:
        return False
    if ready and not not_ready:
        return True
    return None


def _surface(root: Path) -> tuple[bool, bool | None]:
    receipt = json.loads((root / "receipt.json").read_text(encoding="utf-8"))
    readme_flat = " ".join((root / "README.md").read_text(encoding="utf-8").split())
    return bool(receipt["customer_ready"]), _readme_says_ready(readme_flat)


def test_the_receipt_and_the_readme_agree_about_customer_readiness() -> None:
    """THE INVARIANT. Not the value -- the agreement between the two surfaces."""
    claimed, described = _surface(CT_FIFO)
    assert described is not None, (
        "the README states neither position; a customer cannot tell what this "
        "packet claims"
    )
    assert claimed == described, (
        f"the receipt says customer_ready={claimed} while the README describes the "
        f"packet as "
        f"{'customer-ready' if described else 'NOT current-bar customer-ready'}. "
        f"A published packet that contradicts itself is how a false claim reaches "
        f"a customer."
    )


def test_a_contradicting_surface_is_caught(tmp_path: Path) -> None:
    """NEGATIVE CONTROL. An agreement check that cannot detect disagreement is the
    vacuous shape one layer up -- it would pass on any tree at all."""
    root = tmp_path / "pkt"
    root.mkdir()
    (root / "receipt.json").write_text(json.dumps({"customer_ready": True}), encoding="utf-8")
    (root / "README.md").write_text(
        f"Status: scoped proof/evidence packet, {_NOT_READY_PROSE} or promotable.\n",
        encoding="utf-8",
    )
    claimed, described = _surface(root)
    assert claimed is True and described is False, (claimed, described)
    with pytest.raises(AssertionError):
        assert claimed == described, "a constructed contradiction must not pass"


def test_a_readme_stating_neither_position_is_caught(tmp_path: Path) -> None:
    """Silence is not agreement. A README that says nothing about readiness leaves
    the receipt's claim unaccompanied, which is the absence-read-as-fine shape."""
    root = tmp_path / "pkt"
    root.mkdir()
    (root / "receipt.json").write_text(json.dumps({"customer_ready": False}), encoding="utf-8")
    (root / "README.md").write_text("Status: a packet.\n", encoding="utf-8")
    _claimed, described = _surface(root)
    assert described is None


def test_the_metric_hard_negative_stays_separate() -> None:
    """The original test's real subject, which was never stale: the metric screen
    is a SEPARATE receipt carrying its own rejection, bound to the same candidate.
    Collapsing them would let a rejected metric ride on an accepted proof."""
    receipt = json.loads((CT_FIFO / "receipt.json").read_text(encoding="utf-8"))
    metric = json.loads((CT_FIFO / "metric_screen_receipt.json").read_text(encoding="utf-8"))

    assert metric["customer_ready"] is False, "the metric screen must stay a hard negative"
    assert metric["status"] == "full_metric_promotion_rejected"
    assert metric["candidate"]["candidate_sha256"] == receipt["candidate"]["candidate_sha256"], (
        "the metric screen must be bound to the SAME candidate as the proof "
        "receipt, or the rejection is about a different subject"
    )


def test_ci_runs_the_test_directory_not_a_hand_listed_set() -> None:
    """WIRING CONTRACT. This file pins a customer surface and CI did not invoke
    it -- the workflow enumerated 4 of 7 test files by name, so a correct
    assertion here would still have been unread. A corrected assertion in a file
    nothing runs is the unwired-gate defect wearing a different hat.

    Asserting the directory is run is what makes every OTHER test in this repo
    load-bearing, so it lives here rather than anywhere else.
    """
    workflow = (REPO_ROOT / ".github" / "workflows" / "export-safety.yml").read_text(
        encoding="utf-8"
    )
    # EXACT invocation, not a substring. "pytest -q tests/" also matches
    # "pytest -q tests/test_export_safety_gate.py", so a substring check passes
    # on precisely the enumeration it exists to forbid -- substring where a value
    # was meant, which is the same defect this repo has now hit four times.
    invocations = [
        line.strip() for line in workflow.splitlines() if "python3 -m pytest" in line
    ]
    assert any(line.endswith("pytest -q tests/") for line in invocations), (
        "export-safety no longer runs the test DIRECTORY; a hand-listed set of "
        f"test files goes stale silently and always toward running fewer. "
        f"Found only: {invocations}"
    )
