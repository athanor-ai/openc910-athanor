"""A published artifact must not carry a path named after whoever produced it.

Every test builds a REAL git repo and drives the shipped entry point. The check
reads the committed tree, so a fixture that only writes files tests nothing.
"""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
from pathlib import Path

import pytest

from athanor import check_scratch_path_convention as chk


_ENV = {
    "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
    "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t",
    "PATH": os.environ.get("PATH", ""),
}


def _git(root: Path, *args: str) -> None:
    subprocess.run(("git", *args), cwd=root, check=True,
                   capture_output=True, env=_ENV)


def _repo(tmp_path: Path, log_body: str, handles=("dexter",)) -> Path:
    """A committed artifact tree whose denylist names ``handles``."""
    from athanor import export_safety_gate as esg
    hs = sorted(set(list(handles) + [f"fillerperson{i}" for i in range(esg.MIN_HANDLES)]))
    denylist = tmp_path / esg.DENYLIST_REL
    denylist.parent.mkdir(parents=True, exist_ok=True)
    denylist.write_text(json.dumps({
        "handles": hs,
        "stamp": hashlib.sha256("\n".join(hs).encode()).hexdigest(),
    }), encoding="utf-8")
    art = tmp_path / "athanor_artifacts" / "pkt"
    art.mkdir(parents=True, exist_ok=True)
    (art / "run.log").write_text(log_body, encoding="utf-8")
    _git(tmp_path, "init", "-q")
    _git(tmp_path, "add", "-A")
    _git(tmp_path, "commit", "-qm", "fixture")
    return tmp_path


def _findings(root: Path, monkeypatch) -> list[str]:
    monkeypatch.setattr(chk, "REPO_ROOT", root)
    found, errors = chk.findings("HEAD", root)
    assert errors == [], errors
    return found


def test_a_working_directory_named_after_an_agent_reds(tmp_path, monkeypatch) -> None:
    root = _repo(tmp_path, "wrote .scratch/dexter_plic_scout/gate.v ok\n")
    found = _findings(root, monkeypatch)
    assert len(found) == 1, found
    assert "dexter_plic_scout" in found[0]


def test_the_yosys_cell_name_shape_is_reachable(tmp_path, monkeypatch) -> None:
    """THE REACH DEFECT IN MY OWN FIRST VERSION, pinned.

    I required the scratch root to follow start-of-line, whitespace, a quote or
    a slash. The shape carrying ~95% of this fork's real population is a Yosys
    cell name where it follows ``$``:

        $flatten\\x_sel.$logic_not$.scratch/dexter_plic_granu_scout/f.v:30$13699_gate

    That prefix class found 21 of 412. Anchoring on the characters I had already
    seen constrained nothing except my own reach, so there is no prefix class at
    all now -- the scratch root is recognisable on its own.
    """
    body = ("Changing input A of cell $flatten\\x_sel.$logic_not$"
            ".scratch/dexter_plic_granu_scout/gate.v:30$13699_gate ($logic_not)\n")
    found = _findings(_repo(tmp_path, body), monkeypatch)
    assert len(found) == 1, found
    assert "dexter_plic_granu_scout" in found[0]


def test_a_working_directory_not_named_after_anyone_passes(tmp_path, monkeypatch) -> None:
    """NARROWNESS. The convention is about NAMING, not about scratch paths --
    a check that reds on every working directory would be turned off in a day."""
    root = _repo(tmp_path, "wrote .scratch/plic_granu_scout/gate.v ok\n")
    assert _findings(root, monkeypatch) == []


def test_a_handle_that_is_only_a_substring_does_not_red(tmp_path, monkeypatch) -> None:
    """NARROWNESS, the boundary case. `dexterity` contains `dexter` and names
    nobody. Substring matching here would red on ordinary English and the
    finding would stop being believed."""
    root = _repo(tmp_path, "wrote .scratch/dexterity_bench/gate.v ok\n")
    assert _findings(root, monkeypatch) == []


def test_only_published_artifacts_are_in_scope(tmp_path, monkeypatch) -> None:
    """Internal tooling may name its own scratch dirs however it likes; the
    claim is about what we PUBLISH."""
    root = _repo(tmp_path, "clean\n")
    internal = root / "athanor" / "notes.md"
    internal.parent.mkdir(parents=True, exist_ok=True)
    internal.write_text("built in .scratch/dexter_local/x.v\n", encoding="utf-8")
    _git(root, "add", "-A")
    _git(root, "commit", "-qm", "internal note")
    assert _findings(root, monkeypatch) == []


def test_an_unbaselined_finding_reds_and_a_baselined_one_does_not(tmp_path, monkeypatch) -> None:
    root = _repo(tmp_path, "wrote .scratch/dexter_a/gate.v ok\n")
    monkeypatch.setattr(chk, "REPO_ROOT", root)
    missing = root / "no_baseline.json"
    monkeypatch.setattr(chk, "BASELINE_PATH", missing)
    assert chk.main(["--ref", "HEAD", "--root", str(root)]) == 1

    found, _ = chk.findings("HEAD", root)
    baseline = root / "b.json"
    baseline.write_text(json.dumps({"entries": found}), encoding="utf-8")
    monkeypatch.setattr(chk, "BASELINE_PATH", baseline)
    assert chk.main(["--ref", "HEAD", "--root", str(root)]) == 0


def test_a_new_instance_in_an_ALREADY_BASELINED_FILE_still_reds(tmp_path, monkeypatch) -> None:
    """The entry binds to the WHOLE finding, not to the file.

    A baseline keyed on the path would let a SECOND, NEW handle-named directory
    in the same log ride in under the first one's entry -- the file-wide
    exemption defect. This is the property that makes the baseline a receipt
    rather than a mute button.
    """
    root = _repo(tmp_path, "wrote .scratch/dexter_a/gate.v ok\n")
    monkeypatch.setattr(chk, "REPO_ROOT", root)
    found, _ = chk.findings("HEAD", root)
    baseline = root / "b.json"
    baseline.write_text(json.dumps({"entries": found}), encoding="utf-8")
    monkeypatch.setattr(chk, "BASELINE_PATH", baseline)
    assert chk.main(["--ref", "HEAD", "--root", str(root)]) == 0

    log = root / "athanor_artifacts" / "pkt" / "run.log"
    log.write_text(log.read_text() + "and .scratch/dexter_b/other.v too\n",
                   encoding="utf-8")
    _git(root, "add", "-A")
    _git(root, "commit", "-qm", "a second instance in the same file")
    assert chk.main(["--ref", "HEAD", "--root", str(root)]) == 1


def test_an_orphaned_baseline_entry_reds(tmp_path, monkeypatch) -> None:
    """Otherwise the baseline outlives its subject and the file quietly becomes
    a list of things that used to be wrong."""
    root = _repo(tmp_path, "wrote .scratch/plic_only/gate.v ok\n")
    monkeypatch.setattr(chk, "REPO_ROOT", root)
    baseline = root / "b.json"
    baseline.write_text(json.dumps(
        {"entries": ["athanor_artifacts/pkt/run.log:1: working-directory segment "
                     "'dexter_gone' is named after a fleet-agent handle"]}),
        encoding="utf-8")
    monkeypatch.setattr(chk, "BASELINE_PATH", baseline)
    assert chk.main(["--ref", "HEAD", "--root", str(root)]) == 1


@pytest.mark.parametrize("explicit, expected", [(True, 2), (False, 0)])
def test_absence_of_a_baseline_has_two_causes(tmp_path, monkeypatch, explicit, expected) -> None:
    """ABSENCE HAS TWO CAUSES AND THEY ARE OPPOSITE VERDICTS.

    An explicitly named baseline that is not there is a TOOL ERROR -- the
    operator asked for a file that does not exist. The DEFAULT path being absent
    means the class is closed, which is the state normalising the last instance
    produces. Making that a tool error would mean finishing the job could never
    land green.
    """
    root = _repo(tmp_path, "clean, no scratch dirs here\n")
    monkeypatch.setattr(chk, "REPO_ROOT", root)
    missing = root / "no_such_baseline.json"
    monkeypatch.setattr(chk, "BASELINE_PATH", missing)
    argv = ["--ref", "HEAD", "--root", str(root)]
    if explicit:
        argv += ["--baseline", str(missing)]
    assert chk.main(argv) == expected


def test_an_absent_default_baseline_makes_a_finding_LOUDER_not_quieter(tmp_path, monkeypatch) -> None:
    """The safety argument for the branch above, executed rather than asserted:
    deleting the baseline while an instance remains must red, not go silent."""
    root = _repo(tmp_path, "wrote .scratch/dexter_a/gate.v ok\n")
    monkeypatch.setattr(chk, "REPO_ROOT", root)
    monkeypatch.setattr(chk, "BASELINE_PATH", root / "no_such_baseline.json")
    assert chk.main(["--ref", "HEAD", "--root", str(root)]) == 1


def test_an_unparseable_denylist_is_rc2_not_a_clean_verdict(tmp_path, monkeypatch) -> None:
    """COULD-NOT-ESTABLISH MUST NEVER RENDER AS CLEAN. Without a denylist the
    check knows no handles, so every tree looks compliant -- the most dangerous
    possible false green for a check about published exposure."""
    from athanor import export_safety_gate as esg
    root = _repo(tmp_path, "wrote .scratch/dexter_a/gate.v ok\n")
    monkeypatch.setattr(chk, "REPO_ROOT", root)
    (root / esg.DENYLIST_REL).write_text("{not json", encoding="utf-8")
    assert chk.main(["--ref", "HEAD", "--root", str(root)]) == 2


def test_the_shipped_baseline_matches_the_live_tree(tmp_path) -> None:
    """The committed baseline must be DERIVED, not drifted.

    If it stops matching what the checker finds on the real tree, either an
    instance was added without being seen or one was normalised without the
    entry being removed. Both are findings, and this is the test that makes the
    shipped file self-enforcing rather than decorative.
    """
    found, errors = chk.findings("HEAD", chk.REPO_ROOT)
    assert errors == [], errors
    if not chk.BASELINE_PATH.is_file():
        assert found == [], (
            "the baseline is gone but the checker still finds instances: "
            f"{found[:3]}"
        )
        return
    entries = set(json.loads(chk.BASELINE_PATH.read_text())["entries"])
    assert entries == set(found), (
        f"baseline drift: {len(entries - set(found))} orphaned, "
        f"{len(set(found) - entries)} unbaselined"
    )
