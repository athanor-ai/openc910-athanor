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


def _claimed_ready(root: Path) -> bool:
    """The receipt's OWN value, VALIDATED -- never coerced.

    `bool(x)` is not a type check, it is a truthiness cast, and on a published
    field the two differ in the direction that hides a defect: the string
    `"false"` casts to True, `null` casts to False, `1` casts to True. Each of
    those would then AGREE with some README and the packet would read as
    coherent while the field a customer parses is malformed.

    It also disagrees with the receipt verifier, which recognises only literal
    JSON `true`. Two instruments disagreeing about what the same published field
    means is worse than either being wrong alone.
    """
    receipt = json.loads((root / "receipt.json").read_text(encoding="utf-8"))
    value = receipt["customer_ready"]
    if not isinstance(value, bool):
        raise AssertionError(
            f"customer_ready must be JSON true or false, got {value!r} "
            f"({type(value).__name__}). A published boolean that is not a boolean "
            f"is read differently by every consumer that parses it."
        )
    return value


def assert_surface_is_coherent(root: Path) -> None:
    """THE PRODUCTION INVARIANT, in ONE place.

    Every test below calls THIS -- the live packet and all three negative
    controls. That is the point: a control that re-implements the assertion it
    is supposed to be testing proves only that the RE-IMPLEMENTATION works. The
    original controls put a fresh bare `claimed == described` inside
    `pytest.raises`, so deleting the real assertion left them green -- they
    tested a copy of the invariant while the invariant itself went unguarded.

    Routing every caller through one helper makes the controls load-bearing:
    neuter this function and the live test AND all three controls go red
    together.
    """
    claimed = _claimed_ready(root)
    readme_flat = " ".join((root / "README.md").read_text(encoding="utf-8").split())
    described = _readme_says_ready(readme_flat)
    if described is None:
        raise AssertionError(
            "the README states neither position; a customer cannot tell what this "
            "packet claims"
        )
    if claimed != described:
        raise AssertionError(
            f"the receipt says customer_ready={claimed} while the README describes "
            f"the packet as "
            f"{'customer-ready' if described else 'NOT current-bar customer-ready'}. "
            f"A published packet that contradicts itself is how a false claim "
            f"reaches a customer."
        )


def _packet(root: Path, ready: object, prose: str) -> Path:
    root.mkdir()
    (root / "receipt.json").write_text(
        json.dumps({"customer_ready": ready}), encoding="utf-8"
    )
    (root / "README.md").write_text(prose, encoding="utf-8")
    return root


def test_the_receipt_and_the_readme_agree_about_customer_readiness() -> None:
    """THE INVARIANT on the LIVE packet. Not the value -- the agreement."""
    assert_surface_is_coherent(CT_FIFO)


def test_a_contradicting_surface_is_caught(tmp_path: Path) -> None:
    """NEGATIVE CONTROL. An agreement check that cannot detect disagreement is the
    vacuous shape one layer up -- it would pass on any tree at all."""
    pkt = _packet(
        tmp_path / "pkt", True, f"Status: scoped packet, {_NOT_READY_PROSE} or promotable.\n"
    )
    with pytest.raises(AssertionError, match="contradicts itself"):
        assert_surface_is_coherent(pkt)


def test_a_readme_stating_neither_position_is_caught(tmp_path: Path) -> None:
    """Silence is not agreement. A README that says nothing about readiness leaves
    the receipt's claim unaccompanied, which is the absence-read-as-fine shape."""
    pkt = _packet(tmp_path / "pkt", False, "Status: a packet.\n")
    with pytest.raises(AssertionError, match="states neither position"):
        assert_surface_is_coherent(pkt)


@pytest.mark.parametrize(
    "bad_value",
    [
        "false",  # the string, which is TRUTHY -- casts to True
        "true",
        None,  # casts to False, so it would agree with a not-ready README
        1,  # casts to True, so it would agree with a ready README
        0,
    ],
    ids=["str-false", "str-true", "null", "int-1", "int-0"],
)
def test_a_malformed_customer_ready_is_loud_not_coerced(
    tmp_path: Path, bad_value: object
) -> None:
    """Each of these CASTS to a bool that AGREES with one of the two READMEs, so
    under `bool()` the packet reads as coherent while the published field is
    malformed. The failure must be about the TYPE, not laundered into a verdict.
    """
    prose = f"Status: scoped packet, {_NOT_READY_PROSE} or promotable.\n"
    if bool(bad_value):
        prose = f"Status: {_READY_PROSE} scope.\n"
    pkt = _packet(tmp_path / "pkt", bad_value, prose)
    with pytest.raises(AssertionError, match="must be JSON true or false"):
        assert_surface_is_coherent(pkt)


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
