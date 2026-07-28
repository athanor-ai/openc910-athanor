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


# --- supersession: an old hash may survive ONLY alongside its replacement -----
#
# Constraint 2 (never erase that the old hash existed) and constraint 4 (no
# pre-scrub hash survives) collide head-on: the remedy for one is what the check
# for the other rejects. The rule that resolves it needs no key-name list,
# because a supersession is not a thing with a NAME -- it is an old hash that can
# prove what replaced it.


def _scrub(root: Path) -> tuple[str, str]:
    old = hashlib.sha256((root / "NOTES.md").read_bytes()).hexdigest()
    (root / "NOTES.md").write_text("scrubbed content\n", encoding="utf-8")
    new = _rehash(root, "NOTES.md")
    (root / "SHA256SUMS").write_text(f"{new}  NOTES.md\n", encoding="utf-8")
    (root / "receipt.json").write_text(
        '{\n  "files": {\n    "NOTES.md": "' + new + '"\n  }\n}\n', encoding="utf-8"
    )
    (root / "README.md").write_text(f"pinned at `{new.upper()}`\n", encoding="utf-8")
    return old, new


def _record(root: Path, body: str) -> None:
    (root / "SUPERSEDED.json").write_text(body, encoding="utf-8")


def test_a_supersession_record_lets_the_old_hash_survive(tmp_path: Path) -> None:
    root, base = _repo(tmp_path)
    old, new = _scrub(root)
    _record(root, '{\n  "NOTES.md": {\n    "superseded_sha256": "' + old +
            '",\n    "current_sha256": "' + new + '"\n  }\n}\n')
    assert closure.check(base, root) == []


def test_a_record_that_cannot_prove_its_replacement_does_not_exempt(tmp_path: Path) -> None:
    """CONDITION (b): otherwise any stale citation becomes a supersession by
    calling itself one."""
    root, base = _repo(tmp_path)
    old, _ = _scrub(root)
    _record(root, '{\n  "NOTES.md": {\n    "superseded_sha256": "' + old + '"\n  }\n}\n')
    findings = closure.check(base, root)
    assert any("SUPERSEDED.json" in f for f in findings), findings


def test_an_arbitrary_second_hash_is_not_a_replacement(tmp_path: Path) -> None:
    """CONDITION (b): parking any other value beside the old hash must not work."""
    root, base = _repo(tmp_path)
    old, _ = _scrub(root)
    _record(root, '{\n  "NOTES.md": {\n    "superseded_sha256": "' + old +
            '",\n    "current_sha256": "' + "f" * 64 + '"\n  }\n}\n')
    findings = closure.check(base, root)
    assert any("SUPERSEDED.json" in f for f in findings), findings


def test_proximity_is_not_containment(tmp_path: Path) -> None:
    """CONDITION (a): the old hash must be INSIDE the same record object as its
    replacement, not merely nearby in the file. Proximity is the clause-scope
    defect that has already been found twice in the sibling instrument."""
    root, base = _repo(tmp_path)
    old, new = _scrub(root)
    _record(root, '{\n  "NOTES.md": {\n    "current_sha256": "' + new +
            '"\n  },\n  "unrelated": {\n    "leftover": "' + old + '"\n  }\n}\n')
    findings = closure.check(base, root)
    assert any("SUPERSEDED.json" in f for f in findings), findings


def test_a_chain_of_prior_states_is_permitted(tmp_path: Path) -> None:
    """CONDITION (c): old1, old2 and current may co-occur in one record."""
    root, base = _repo(tmp_path)
    old, new = _scrub(root)
    _record(root, '{\n  "NOTES.md": {\n    "history": ["' + "a" * 64 + '", "' + old +
            '"],\n    "current_sha256": "' + new + '"\n  }\n}\n')
    assert closure.check(base, root) == []


def test_a_record_naming_a_file_that_does_not_exist_exempts_nothing(tmp_path: Path) -> None:
    """The record must name a REAL file, or there is nothing to verify against."""
    root, base = _repo(tmp_path)
    old, new = _scrub(root)
    _record(root, '{\n  "GONE.md": {\n    "superseded_sha256": "' + old +
            '",\n    "current_sha256": "' + new + '"\n  }\n}\n')
    findings = closure.check(base, root)
    assert any("SUPERSEDED.json" in f for f in findings), findings


def test_a_valid_record_does_not_exempt_an_unrelated_sibling_citation(tmp_path: Path) -> None:
    """CONDITION (a), the way it actually breaks: collapsing a file's records into
    a SET of allowed hashes makes one valid record excuse that hash FILE-WIDE, so
    an unrelated sibling citation of the same stale hash goes silent. The
    exemption must stay bound to the records that earn it."""
    root, base = _repo(tmp_path)
    old, new = _scrub(root)
    _record(root, '{\n  "NOTES.md": {\n    "superseded_sha256": "' + old +
            '",\n    "current_sha256": "' + new + '"\n  },\n'
            '  "unrelated_citation": "' + old + '"\n}\n')
    findings = closure.check(base, root)
    assert any("SUPERSEDED.json" in f for f in findings), findings


def test_a_record_only_excuses_its_OWN_files_prior_hash(tmp_path: Path) -> None:
    """CONDITION (c), SUBJECT. A valid record for OTHER.md that happens to carry
    NOTES.md's old hash must NOT excuse it -- the record has to be ABOUT the
    transition it excuses, or a decoy record with its own valid current hash
    launders an unrelated victim's stale citation."""
    root, base = _repo(tmp_path)
    old, new = _scrub(root)
    (root / "OTHER.md").write_text("other\n", encoding="utf-8")
    other = hashlib.sha256((root / "OTHER.md").read_bytes()).hexdigest()
    _record(root, '{\n  "OTHER.md": {\n    "superseded_sha256": "' + old +
            '",\n    "current_sha256": "' + other + '"\n  }\n}\n')
    findings = closure.check(base, root)
    assert any("SUPERSEDED.json" in f for f in findings), findings


def test_nested_valid_records_do_not_excuse_an_unrelated_sibling(tmp_path: Path) -> None:
    """COUNTING CANNOT SURVIVE NESTING. A valid record containing another valid
    record has the inner occurrence counted by the outer record AND again by the
    recursive walk, so the accounted total exceeds the physical occurrences and
    the surplus excuses an unrelated sibling citation. Paths are unique, so the
    same occurrence marked twice is still one path."""
    root, base = _repo(tmp_path)
    old, new = _scrub(root)
    (root / "OTHER.md").write_text("other\n", encoding="utf-8")
    other = hashlib.sha256((root / "OTHER.md").read_bytes()).hexdigest()
    _record(root, '{\n'
            '  "NOTES.md": {\n'
            '    "superseded_sha256": "' + old + '",\n'
            '    "current_sha256": "' + new + '",\n'
            '    "OTHER.md": {\n'
            '      "superseded_sha256": "' + old + '",\n'
            '      "current_sha256": "' + other + '"\n'
            '    }\n'
            '  },\n'
            '  "unrelated_citation": "' + old + '"\n}\n')
    findings = closure.check(base, root)
    assert any("SUPERSEDED.json" in f and "unrelated_citation" in f for f in findings), findings


def test_a_finding_names_the_offending_occurrence_not_the_first_match(tmp_path: Path) -> None:
    """Attribution: counting could only say HOW MANY were unaccounted for, so it
    reported the first matching line, which may be a legitimate one."""
    root, base = _repo(tmp_path)
    old, new = _scrub(root)
    _record(root, '{\n  "NOTES.md": {\n    "superseded_sha256": "' + old +
            '",\n    "current_sha256": "' + new + '"\n  },\n'
            '  "leftover": "' + old + '"\n}\n')
    findings = [f for f in closure.check(base, root) if "SUPERSEDED.json" in f]
    assert findings, "the unaccounted occurrence was not reported"
    assert all("leftover" in f for f in findings), (
        "the finding pointed somewhere other than the offending occurrence: " + str(findings)
    )


def test_the_workflow_binds_the_denominator_to_the_immutable_event_base(tmp_path: Path) -> None:
    """WIRING CONTRACT. The base-SHA repair lives in the workflow, so every unit
    test stays green if someone reverts it to the moving ref -- the fix would be
    correct and unpinned, which is how enforcement gets silently switched off.
    """
    workflow = (Path(__file__).resolve().parents[1]
                / ".github" / "workflows" / "export-safety.yml").read_text(encoding="utf-8")
    step = workflow.split("Scrub hash closure", 1)
    assert len(step) == 2, "the scrub hash closure step is not wired into export-safety"
    body = step[1].split("- name:", 1)[0]
    assert "github.event.pull_request.base.sha" in body, (
        "the scrub check must diff against the IMMUTABLE PR event base SHA"
    )
    assert "origin/${{ github.base_ref }}" not in body, (
        "the scrub check is diffing against a MOVING branch ref: if the base "
        "advances after the merge ref is synthesized, the check measures a "
        "different base than the tree it is checking"
    )


def test_a_hash_embedded_inside_a_longer_string_is_found(tmp_path: Path) -> None:
    """HOLD 1a. Parsed-only scanning accepts full SCALAR values, so a hash inside
    a longer string is invisible to it while being physically present in the
    published file. The literal sweep finds every occurrence; only the EXEMPTION
    needs structure."""
    root, base = _repo(tmp_path)
    old, new = _scrub(root)
    (root / "SUPERSEDED.json").write_text(
        '{\n  "note": "previously published as ' + old + ' before the scrub"\n}\n',
        encoding="utf-8")
    findings = closure.check(base, root)
    assert any("SUPERSEDED.json" in f for f in findings), findings


def test_a_duplicate_key_cannot_hide_an_occurrence(tmp_path: Path) -> None:
    """HOLD 1b. json.loads() silently keeps the LAST duplicate key, so a parsed
    walk never sees the first one -- but the bytes are in the published file."""
    root, base = _repo(tmp_path)
    old, new = _scrub(root)
    (root / "SUPERSEDED.json").write_text(
        '{\n  "NOTES.md": {\n    "superseded_sha256": "' + old + '"\n  },\n'
        '  "NOTES.md": {\n    "current_sha256": "' + new + '"\n  }\n}\n',
        encoding="utf-8")
    findings = closure.check(base, root)
    assert any("SUPERSEDED.json" in f for f in findings), findings


def test_a_key_named_like_a_path_cannot_collide_with_one(tmp_path: Path) -> None:
    """HOLD 2. Dotted path STRINGS are not unique: a root key literally named
    "NOTES.md.superseded_sha256" produced the same path as the nested field, so
    both were excused by one valid record. Offsets cannot collide."""
    root, base = _repo(tmp_path)
    old, new = _scrub(root)
    (root / "SUPERSEDED.json").write_text(
        '{\n  "NOTES.md": {\n    "superseded_sha256": "' + old +
        '",\n    "current_sha256": "' + new + '"\n  },\n'
        '  "NOTES.md.superseded_sha256": "' + old + '"\n}\n',
        encoding="utf-8")
    findings = closure.check(base, root)
    assert any("NOTES.md.superseded_sha256" in f for f in findings), findings
