"""Bites-tests for the scrub hash-closure check (ATH-3397).

The check answers one narrow question: for every file a change edits, has every
occurrence of that file's OLD hash been updated? It does not classify citations,
so these tests are about COVERAGE and FAILING CLOSED rather than about semantics.
"""
from __future__ import annotations

import hashlib
import os
import subprocess
from pathlib import Path

from athanor import check_scrub_hash_closure as closure


def _repo(tmp_path: Path) -> tuple[Path, str]:
    """A real git repo with a receipt citing another file's hash two ways."""
    env = {
        "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
        "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t",
        "PATH": os.environ.get("PATH", ""),
    }

    def run(*args: str) -> str:
        return subprocess.run(
            args, cwd=tmp_path, capture_output=True, text=True, env=env, check=True
        ).stdout.strip()

    run("git", "init", "-q")
    notes = tmp_path / "NOTES.md"
    notes.write_text("original content\n", encoding="utf-8")
    sha = hashlib.sha256(notes.read_bytes()).hexdigest()
    (tmp_path / "SHA256SUMS").write_text(f"{sha}  NOTES.md\n", encoding="utf-8")
    (tmp_path / "receipt.json").write_text(
        '{\n  "files": {\n    "NOTES.md": "' + sha + '"\n  }\n}\n', encoding="utf-8"
    )
    (tmp_path / "README.md").write_text(
        f"The evidence file is pinned at `{sha.upper()}` (uppercase on purpose).\n",
        encoding="utf-8",
    )
    run("git", "add", "-A")
    run("git", "commit", "-qm", "base")
    return tmp_path, run("git", "rev-parse", "HEAD")


def _rehash(root: Path, name: str) -> str:
    return hashlib.sha256((root / name).read_bytes()).hexdigest()


def test_an_untouched_tree_is_clean(tmp_path: Path) -> None:
    root, base = _repo(tmp_path)
    assert closure.check(base, root) == []


def test_a_scrub_that_updates_nothing_reds_everywhere(tmp_path: Path) -> None:
    """NECESSITY: editing a file leaves its old hash in every citing place."""
    root, base = _repo(tmp_path)
    (root / "NOTES.md").write_text("scrubbed content\n", encoding="utf-8")
    findings = closure.check(base, root)
    cited = {f.split(":")[0] for f in findings}
    assert cited == {"SHA256SUMS", "receipt.json", "README.md"}, findings


def test_updating_sha256sums_but_missing_the_receipt_still_reds(tmp_path: Path) -> None:
    """The exact miss that shipped 13 times: manifest updated, citation not."""
    root, base = _repo(tmp_path)
    (root / "NOTES.md").write_text("scrubbed content\n", encoding="utf-8")
    new = _rehash(root, "NOTES.md")
    (root / "SHA256SUMS").write_text(f"{new}  NOTES.md\n", encoding="utf-8")
    (root / "README.md").write_text(f"pinned at `{new.upper()}`\n", encoding="utf-8")
    findings = closure.check(base, root)
    assert findings and all("receipt.json" in f for f in findings), findings


def test_uppercase_occurrences_are_found(tmp_path: Path) -> None:
    """Published hashes appear in both cases; a case-sensitive sweep misses one."""
    root, base = _repo(tmp_path)
    (root / "NOTES.md").write_text("scrubbed content\n", encoding="utf-8")
    new = _rehash(root, "NOTES.md")
    old = closure.old_hashes(base, ["NOTES.md"], root)["NOTES.md"]
    (root / "SHA256SUMS").write_text(f"{new}  NOTES.md\n", encoding="utf-8")
    (root / "receipt.json").write_text(
        '{\n  "files": {\n    "NOTES.md": "' + new + '"\n  }\n}\n', encoding="utf-8"
    )
    findings = closure.check(base, root)
    assert any("README.md" in f for f in findings), (old, findings)


def test_a_fully_updated_scrub_is_clean(tmp_path: Path) -> None:
    """GREEN is reachable -- otherwise the gate is unsatisfiable."""
    root, base = _repo(tmp_path)
    (root / "NOTES.md").write_text("scrubbed content\n", encoding="utf-8")
    new = _rehash(root, "NOTES.md")
    (root / "SHA256SUMS").write_text(f"{new}  NOTES.md\n", encoding="utf-8")
    (root / "receipt.json").write_text(
        '{\n  "files": {\n    "NOTES.md": "' + new + '"\n  }\n}\n', encoding="utf-8"
    )
    (root / "README.md").write_text(f"pinned at `{new.upper()}`\n", encoding="utf-8")
    assert closure.check(base, root) == []


def test_a_hash_in_a_file_type_no_classifier_inspects_is_found(tmp_path: Path) -> None:
    """COVERAGE is the whole point: this never asks what kind of reference it is,
    so a replay script, a log or a brand-new file format is covered for free."""
    root, base = _repo(tmp_path)
    old = closure.old_hashes(base, [], root)
    sha = hashlib.sha256((root / "NOTES.md").read_bytes()).hexdigest()
    (root / "replay.sh").write_text(f"check_hash {sha} NOTES.md\n", encoding="utf-8")
    subprocess.run(["git", "add", "-A"], cwd=root, capture_output=True, check=False)
    subprocess.run(
        ["git", "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "add replay"],
        cwd=root, capture_output=True, check=False,
    )
    base2 = subprocess.run(["git", "rev-parse", "HEAD"], cwd=root,
                           capture_output=True, text=True, check=True).stdout.strip()
    (root / "NOTES.md").write_text("scrubbed\n", encoding="utf-8")
    findings = closure.check(base2, root)
    assert any("replay.sh" in f for f in findings), (old, findings)


def test_an_unresolvable_base_is_a_tool_error_not_a_pass(tmp_path: Path) -> None:
    """FAIL CLOSED: a base that cannot be read must never report a scrub clean."""
    root, _ = _repo(tmp_path)
    assert closure.main(["--base", "no/such/ref", "--root", str(root)]) == 2


def test_exit_codes_follow_the_repo_contract(tmp_path: Path) -> None:
    root, base = _repo(tmp_path)
    assert closure.main(["--base", base, "--root", str(root)]) == 0
    (root / "NOTES.md").write_text("scrubbed\n", encoding="utf-8")
    assert closure.main(["--base", base, "--root", str(root)]) == 1
