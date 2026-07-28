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


def _commit_all(root: Path, message: str) -> None:
    subprocess.run(["git", "add", "-A"], cwd=root, capture_output=True, check=False)
    subprocess.run(
        ["git", "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", message],
        cwd=root, capture_output=True, check=False,
    )


def _rehash(root: Path, name: str) -> str:
    return hashlib.sha256((root / name).read_bytes()).hexdigest()


def test_an_untouched_tree_is_clean(tmp_path: Path) -> None:
    root, base = _repo(tmp_path)
    assert closure.check(base, root)[0] == []


def test_a_scrub_that_updates_nothing_reds_everywhere(tmp_path: Path) -> None:
    """NECESSITY: editing a file leaves its old hash in every citing place."""
    root, base = _repo(tmp_path)
    (root / "NOTES.md").write_text("scrubbed content\n", encoding="utf-8")
    _commit_all(root, "edit")
    findings, _incon = closure.check(base, root)
    cited = {f.split(":")[0] for f in findings}
    assert cited == {"SHA256SUMS", "receipt.json", "README.md"}, findings


def test_updating_sha256sums_but_missing_the_receipt_still_reds(tmp_path: Path) -> None:
    """The exact miss that shipped 13 times: manifest updated, citation not."""
    root, base = _repo(tmp_path)
    (root / "NOTES.md").write_text("scrubbed content\n", encoding="utf-8")
    new = _rehash(root, "NOTES.md")
    (root / "SHA256SUMS").write_text(f"{new}  NOTES.md\n", encoding="utf-8")
    (root / "README.md").write_text(f"pinned at `{new.upper()}`\n", encoding="utf-8")
    _commit_all(root, "partial")
    findings, _incon = closure.check(base, root)
    assert findings and all("receipt.json" in f for f in findings), findings


def test_uppercase_occurrences_are_found(tmp_path: Path) -> None:
    """Published hashes appear in both cases; a case-sensitive sweep misses one."""
    root, base = _repo(tmp_path)
    (root / "NOTES.md").write_text("scrubbed content\n", encoding="utf-8")
    new = _rehash(root, "NOTES.md")
    (root / "SHA256SUMS").write_text(f"{new}  NOTES.md\n", encoding="utf-8")
    (root / "receipt.json").write_text(
        '{\n  "files": {\n    "NOTES.md": "' + new + '"\n  }\n}\n', encoding="utf-8"
    )
    _commit_all(root, "partial scrub, README left uppercase")
    findings, _incon = closure.check(base, root)
    assert any("README.md" in f for f in findings), findings


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
    _commit_all(root, "full")
    assert closure.check(base, root)[0] == []


def test_a_hash_in_a_file_type_no_classifier_inspects_is_found(tmp_path: Path) -> None:
    """COVERAGE is the whole point: this never asks what kind of reference it is,
    so a replay script, a log or a brand-new file format is covered for free."""
    root, base = _repo(tmp_path)
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
    _commit_all(root, "scrub")
    findings, _incon = closure.check(base2, root)
    assert any("replay.sh" in f for f in findings), findings


def test_an_unresolvable_base_is_a_tool_error_not_a_pass(tmp_path: Path) -> None:
    """FAIL CLOSED: a base that cannot be read must never report a scrub clean."""
    root, _ = _repo(tmp_path)
    assert closure.main(["--base", "no/such/ref", "--root", str(root)]) == 2


def test_exit_codes_follow_the_repo_contract(tmp_path: Path) -> None:
    root, base = _repo(tmp_path)
    assert closure.main(["--base", base, "--root", str(root)]) == 0
    (root / "NOTES.md").write_text("scrubbed\n", encoding="utf-8")
    _commit_all(root, "edit")
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
    _commit_all(root, "scrub")
    return old, new


def _record(root: Path, body: str) -> None:
    (root / "SUPERSEDED.json").write_text(body, encoding="utf-8")
    _commit_all(root, "record")


def test_a_supersession_record_lets_the_old_hash_survive(tmp_path: Path) -> None:
    root, base = _repo(tmp_path)
    old, new = _scrub(root)
    _record(root, '{\n  "NOTES.md": {\n    "superseded_sha256": "' + old +
            '",\n    "current_sha256": "' + new + '"\n  }\n}\n')
    assert closure.check(base, root)[0] == []


def test_a_record_that_cannot_prove_its_replacement_does_not_exempt(tmp_path: Path) -> None:
    """CONDITION (b): otherwise any stale citation becomes a supersession by
    calling itself one."""
    root, base = _repo(tmp_path)
    old, _ = _scrub(root)
    _record(root, '{\n  "NOTES.md": {\n    "superseded_sha256": "' + old + '"\n  }\n}\n')
    findings, _incon = closure.check(base, root)
    assert any("SUPERSEDED.json" in f for f in findings), findings


def test_an_arbitrary_second_hash_is_not_a_replacement(tmp_path: Path) -> None:
    """CONDITION (b): parking any other value beside the old hash must not work."""
    root, base = _repo(tmp_path)
    old, _ = _scrub(root)
    _record(root, '{\n  "NOTES.md": {\n    "superseded_sha256": "' + old +
            '",\n    "current_sha256": "' + "f" * 64 + '"\n  }\n}\n')
    findings, _incon = closure.check(base, root)
    assert any("SUPERSEDED.json" in f for f in findings), findings


def test_proximity_is_not_containment(tmp_path: Path) -> None:
    """CONDITION (a): the old hash must be INSIDE the same record object as its
    replacement, not merely nearby in the file. Proximity is the clause-scope
    defect that has already been found twice in the sibling instrument."""
    root, base = _repo(tmp_path)
    old, new = _scrub(root)
    _record(root, '{\n  "NOTES.md": {\n    "current_sha256": "' + new +
            '"\n  },\n  "unrelated": {\n    "leftover": "' + old + '"\n  }\n}\n')
    findings, _incon = closure.check(base, root)
    assert any("SUPERSEDED.json" in f for f in findings), findings


def test_a_chain_of_prior_states_is_permitted(tmp_path: Path) -> None:
    """CONDITION (c): old1, old2 and current may co-occur in one record."""
    root, base = _repo(tmp_path)
    old, new = _scrub(root)
    _record(root, '{\n  "NOTES.md": {\n    "history": ["' + "a" * 64 + '", "' + old +
            '"],\n    "current_sha256": "' + new + '"\n  }\n}\n')
    assert closure.check(base, root)[0] == []


def test_a_record_naming_a_file_that_does_not_exist_exempts_nothing(tmp_path: Path) -> None:
    """The record must name a REAL file, or there is nothing to verify against."""
    root, base = _repo(tmp_path)
    old, new = _scrub(root)
    _record(root, '{\n  "GONE.md": {\n    "superseded_sha256": "' + old +
            '",\n    "current_sha256": "' + new + '"\n  }\n}\n')
    findings, _incon = closure.check(base, root)
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
    findings, _incon = closure.check(base, root)
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
    findings, _incon = closure.check(base, root)
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
    findings, _incon = closure.check(base, root)
    assert any("SUPERSEDED.json" in f and "unrelated_citation" in f for f in findings), findings


def test_a_finding_names_the_offending_occurrence_not_the_first_match(tmp_path: Path) -> None:
    """Attribution: counting could only say HOW MANY were unaccounted for, so it
    reported the first matching line, which may be a legitimate one."""
    root, base = _repo(tmp_path)
    old, new = _scrub(root)
    _record(root, '{\n  "NOTES.md": {\n    "superseded_sha256": "' + old +
            '",\n    "current_sha256": "' + new + '"\n  },\n'
            '  "leftover": "' + old + '"\n}\n')
    found, _incon = closure.check(base, root)
    findings = [f for f in found if "SUPERSEDED.json" in f]
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
    _record(root, '{\n  "note": "previously published as ' + old + ' before the scrub"\n}\n')
    findings, _incon = closure.check(base, root)
    assert any("SUPERSEDED.json" in f for f in findings), findings


def test_a_duplicate_key_cannot_hide_an_occurrence(tmp_path: Path) -> None:
    """HOLD 1b. json.loads() silently keeps the LAST duplicate key, so a parsed
    walk never sees the first one -- but the bytes are in the published file."""
    root, base = _repo(tmp_path)
    old, new = _scrub(root)
    _record(root, '{\n  "NOTES.md": {\n    "superseded_sha256": "' + old + '"\n  },\n'
        '  "NOTES.md": {\n    "current_sha256": "' + new + '"\n  }\n}\n')
    findings, _incon = closure.check(base, root)
    assert any("SUPERSEDED.json" in f for f in findings), findings


def test_a_key_named_like_a_path_cannot_collide_with_one(tmp_path: Path) -> None:
    """HOLD 2. Dotted path STRINGS are not unique: a root key literally named
    "NOTES.md.superseded_sha256" produced the same path as the nested field, so
    both were excused by one valid record. Offsets cannot collide."""
    root, base = _repo(tmp_path)
    old, new = _scrub(root)
    _record(root, '{\n  "NOTES.md": {\n    "superseded_sha256": "' + old +
        '",\n    "current_sha256": "' + new + '"\n  },\n'
        '  "NOTES.md.superseded_sha256": "' + old + '"\n}\n')
    findings, _incon = closure.check(base, root)
    assert any("NOTES.md.superseded_sha256" in f for f in findings), findings


# --- W1/W2/W3: "could not establish X" must never render as "X is satisfied" ---
#
# Three false-cleans that are one defect in three costumes: an unparseable
# record, a non-exact match, and an unobservable file each converted an
# inability to establish something into a discharge. That is rc 2 rendering as
# rc 0. Each witness has a positive control so the fix is not just a refusal.


def test_W1_a_malformed_record_earns_no_exemption(tmp_path: Path) -> None:
    root, base = _repo(tmp_path)
    old, new = _scrub(root)
    _record(root, '{\n  "NOTES.md": {\n    "superseded_sha256": "' + old +
            '",\n    "current_sha256": "' + new + '",\n  },\n}\n')   # trailing commas
    findings, _incon = closure.check(base, root)
    assert any("SUPERSEDED.json" in f for f in findings), (
        "a record that does not PARSE cannot establish that a record exists", findings)


def test_W1_an_escaped_key_decodes_to_the_file_it_names(tmp_path: Path) -> None:
    """The pair of W1: fixing syntax validation must not start rejecting VALID
    records whose key happens to be escaped."""
    root, base = _repo(tmp_path)
    old, new = _scrub(root)
    _record(root, '{\n  "NOTES\\u002emd": {\n    "superseded_sha256": "' + old +
            '",\n    "current_sha256": "' + new + '"\n  }\n}\n')
    assert closure.check(base, root)[0] == []


def test_W1_the_literal_sweep_still_fires_on_non_json(tmp_path: Path) -> None:
    """Do not trade one blind spot for the other: structure governs the
    EXEMPTION, the literal sweep still finds every occurrence everywhere."""
    root, base = _repo(tmp_path)
    old, _ = _scrub(root)
    (root / "notes.txt").write_text(f"previously {old}\n", encoding="utf-8")
    _commit_all(root, "txt")
    findings, _incon = closure.check(base, root)
    assert any("notes.txt" in f for f in findings), findings


def test_W2_substring_containment_is_not_a_replacement(tmp_path: Path) -> None:
    root, base = _repo(tmp_path)
    old, new = _scrub(root)
    _record(root, '{\n  "NOTES.md": {\n    "superseded_sha256": "' + old +
            '",\n    "noise": "not-a-replacement-' + new + '-tail"\n  }\n}\n')
    findings, _incon = closure.check(base, root)
    assert any("SUPERSEDED.json" in f for f in findings), (
        "substring containment posed as the replacement", findings)


def test_W2_an_exact_token_replacement_still_passes(tmp_path: Path) -> None:
    """POSITIVE CONTROL for W2."""
    root, base = _repo(tmp_path)
    old, new = _scrub(root)
    _record(root, '{\n  "NOTES.md": {\n    "superseded_sha256": "' + old +
            '",\n    "current_sha256": "' + new + '"\n  }\n}\n')
    assert closure.check(base, root)[0] == []


def test_W3_deleting_the_file_does_not_disable_the_gate(tmp_path: Path) -> None:
    """DELETION IS THE STRONGEST SCRUB. With --diff-filter=M the changed set was
    EMPTY, so the gate passed while the deleted file's old hash stayed cited."""
    root, base = _repo(tmp_path)
    (root / "NOTES.md").unlink()
    _commit_all(root, "delete")
    findings, _incon = closure.check(base, root)
    assert any("receipt.json" in f for f in findings), (
        "a deleted file's old hash is still cited and the gate went quiet", findings)


def test_W3_a_content_preserving_rename_is_not_a_supersession(tmp_path: Path) -> None:
    """CORRECTED. This test previously asserted that a rename REDS, which encoded
    a false positive: if the content is unchanged, a citation of its hash still
    resolves to real content that the tree contains, just at another path. The
    hash was never superseded. Filtering by git STATUS could not see that;
    deriving the population from CONTENT gets it right with no special case."""
    root, base = _repo(tmp_path)
    (root / "NOTES.md").rename(root / "RENAMED.md")
    _commit_all(root, "rename")
    findings, inconclusive = closure.check(base, root)
    assert any("rename is not supported" in f for f in inconclusive), (
        "a content-preserving rename must be a NAMED refusal, not silence", inconclusive)
    assert findings == [], (
        "the refusal must NOT be reported as a surviving reference -- nothing "
        "stale was demonstrated", findings)


def test_W3_a_rename_that_also_changes_content_still_reds(tmp_path: Path) -> None:
    """The discriminating pair: renaming is irrelevant, CHANGING is what matters."""
    root, base = _repo(tmp_path)
    (root / "NOTES.md").rename(root / "RENAMED.md")
    (root / "RENAMED.md").write_text("renamed and edited\n", encoding="utf-8")
    _commit_all(root, "rename+edit")
    findings, _incon = closure.check(base, root)
    assert any("receipt.json" in f for f in findings), findings


def test_W3_an_unrelated_deletion_does_not_invent_findings(tmp_path: Path) -> None:
    """POSITIVE CONTROL for W3: deleting a file nothing cites stays clean."""
    root, base = _repo(tmp_path)
    (root / "SPARE.md").write_text("spare\n", encoding="utf-8")
    _commit_all(root, "add spare")
    base2 = subprocess.run(["git", "rev-parse", "HEAD"], cwd=root,
                           capture_output=True, text=True, check=True).stdout.strip()
    (root / "SPARE.md").unlink()
    _commit_all(root, "rm spare")
    assert closure.check(base2, root)[0] == []


# --- W3a-d: the population is a CONTENT property, not a git status ------------
#
# A status list failed in BOTH directions at once, which is what proves it is a
# proxy for a question it does not answer rather than an incomplete list:
# typechange was excluded (false clean), chmod-only was included (false red).
# M -> MD -> MDT each closes the instance in front of you and leaves the class.


def test_W3a_a_typechange_to_symlink_still_reds(tmp_path: Path) -> None:
    """Status T, excluded by MD. The old content is gone from the tree, so a
    citation of it is stale -- and the predicate says so without naming T."""
    root, base = _repo(tmp_path)
    (root / "NOTES.md").unlink()
    (root / "NOTES.md").symlink_to("README.md")
    _commit_all(root, "typechange")
    findings, _incon = closure.check(base, root)
    assert any("receipt.json" in f for f in findings), (
        "a regular file replaced by a symlink left its old hash cited", findings)


def test_W3b_a_mode_only_change_does_not_invent_a_finding(tmp_path: Path) -> None:
    """Status M, INCLUDED by MD, with identical bytes -- so the correct current
    citation was reported stale. A gate that invents findings spends the reader's
    trust on the true ones."""
    root, base = _repo(tmp_path)
    (root / "NOTES.md").chmod(0o755)
    _commit_all(root, "chmod only")
    assert closure.check(base, root)[0] == []


def test_W3d_no_git_status_letter_is_in_the_decision_path(tmp_path: Path) -> None:
    """The population must be DERIVED. This fails if a --diff-filter reappears,
    so the next unhandled status letter cannot be added as a sixth list entry.
    """
    import ast

    tree = ast.parse(Path(closure.__file__).read_text(encoding="utf-8"))
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        args = [a.value for a in node.args if isinstance(a, ast.Constant)]
        assert not any(
            isinstance(a, str) and a.startswith("--diff-filter") for a in args
        ), (
            "the population is being filtered by git STATUS again; derive it from "
            "content -- base content != current content -- so there is no list to "
            "keep current and no next letter to miss"
        )
        assert "diff" not in args[:1], (
            "the population is coming from `git diff` again; it must be derived "
            "by comparing base content to current content"
        )


def test_an_identical_copy_elsewhere_does_not_launder_a_changed_file(tmp_path: Path) -> None:
    """A global CONTENT set discarded PATH IDENTITY: any file anywhere holding the
    old bytes made the changed file's old hash look still-live, so a stale
    citation went clean. Third time in this checker that a set lost identity --
    after the file-wide exemption set and the accounted-for count."""
    root, base = _repo(tmp_path)
    old = hashlib.sha256((root / "NOTES.md").read_bytes()).hexdigest()
    (root / "COPY.md").write_text("original content\n", encoding="utf-8")  # same bytes
    (root / "NOTES.md").write_text("scrubbed content\n", encoding="utf-8")
    _commit_all(root, "copy + edit, receipt citation left stale")
    findings, _incon = closure.check(base, root)
    assert any("receipt.json" in f for f in findings), (
        f"an identical copy laundered the old hash {old[:12]}", findings)


def test_an_untracked_file_cannot_control_the_denominator(tmp_path: Path) -> None:
    """The population walked the HOST WORKTREE, so an UNTRACKED file -- something
    outside the change under review entirely -- could make a stale citation
    clean. The subject of this check is the COMMITTED tree."""
    root, base = _repo(tmp_path)
    (root / "NOTES.md").write_text("scrubbed content\n", encoding="utf-8")
    _commit_all(root, "edit, citation left stale")
    # Never added to git: it must not participate in the verdict.
    (root / "untracked_copy.md").write_text("original content\n", encoding="utf-8")
    findings, _incon = closure.check(base, root)
    assert any("receipt.json" in f for f in findings), (
        "an untracked file was allowed to satisfy the content predicate", findings)


def test_a_dirty_worktree_repair_does_not_clear_a_committed_finding(tmp_path: Path) -> None:
    """MIXED-TREE READ. The sweep enumerated committed path NAMES and then opened
    the file FROM DISK, so repairing only the dirty worktree -- without
    committing -- made a committed finding vanish. Both the sweep and the
    exemption validator must consume HEAD blobs."""
    root, base = _repo(tmp_path)
    old, new = _scrub(root)
    # Commit a scrub that leaves receipt.json citing the old hash.
    (root / "receipt.json").write_text(
        '{\n  "files": {\n    "NOTES.md": "' + old + '"\n  }\n}\n', encoding="utf-8")
    _commit_all(root, "scrub with a stale receipt")
    findings, _ = closure.check(base, root)
    assert any("receipt.json" in f for f in findings), ("expected a committed finding", findings)
    # Repair ONLY the working tree. Nothing is committed.
    (root / "receipt.json").write_text(
        '{\n  "files": {\n    "NOTES.md": "' + new + '"\n  }\n}\n', encoding="utf-8")
    findings_after, _ = closure.check(base, root)
    assert any("receipt.json" in f for f in findings_after), (
        "an uncommitted worktree repair cleared a COMMITTED finding", findings_after)


def test_an_inconclusive_rename_returns_rc_2_not_rc_1(tmp_path: Path) -> None:
    """A finding establishes that a pre-scrub hash SURVIVES. An inconclusive
    establishes only that this check cannot tell. Routing the second as the first
    claims a stale reference that was never demonstrated."""
    root, base = _repo(tmp_path)
    (root / "NOTES.md").rename(root / "RENAMED.md")
    _commit_all(root, "rename")
    assert closure.main(["--base", base, "--root", str(root)]) == 2
