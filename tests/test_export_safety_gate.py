"""Export-safety gate pattern coverage (ATH-2960 hardening).

Rail for the fail-open Quan found while reviewing openc910 #38: the internal
project namespace as a schema/module PATH (e.g. a receipt `schema` string or a
`from <ns>.sub import` line) matched NO pattern, and the ticket-id WARN was
case+hyphen pinned so `ath2852` (the natural machine form) evaded it.

Every internal-marker literal below is FRAGMENT-BUILT (never contiguous in this
source) so this committed test file does not self-trip the gate's own
committed-tree scan; the leak forms are reassembled at runtime and written into
throwaway temp git repos, which is where we WANT them.
"""
import hashlib
import importlib.util
import json
import re
import subprocess
from pathlib import Path

import pytest
import importlib.util as _ilu

_GATE = Path(__file__).resolve().parent.parent / "athanor" / "export_safety_gate.py"
_spec = importlib.util.spec_from_file_location("export_safety_gate", _GATE)
esg = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(esg)

# --- fragments: the contiguous marker bytes never appear in this file's source
NS = "kai" + "ros"            # internal project namespace
WD = "/work" + "dir"         # internal build path
POINTER = "athanor-" + NS    # internal repo pointer (WARN tier)
TICKET_DIGITS = "2852"
# AI-tool / vendor authorship markers -- fragment-built so the contiguous marker
# never appears in this committed test file (else it self-trips the gate's own
# committed-tree scan). Reassembled at runtime into throwaway fixtures.
TOOL = "Cla" + "ude"                       # AI-tool name
VENDOR = "anthro" + "pic"                  # AI-vendor name
FOOTER = "Generated with " + TOOL + " Code"  # the bot auto-attribution footer


def _git(args, cwd):
    subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True)


def _scan(tmp_path, files):
    """Commit ``files`` (rel -> content) into a temp repo and byte-scan HEAD.

    Returns (block, warn, skipped) from the SHIPPED ``_scan_committed`` -- the
    exact path CI runs, isolated from the receipt verifier.
    """
    files = dict(files)
    files.setdefault(esg.DENYLIST_REL, _denylist_json(_padded([_H_A, _H_B])))
    tmp_path.mkdir(parents=True, exist_ok=True)
    _git(["init", "-q"], tmp_path)
    _git(["config", "user.email", "t@example.invalid"], tmp_path)
    _git(["config", "user.name", "t"], tmp_path)
    for rel, content in files.items():
        p = tmp_path / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content)
        _git(["add", rel], tmp_path)
    _git(["commit", "-q", "-m", "fixture"], tmp_path)
    return esg._scan_committed("HEAD", tmp_path)


def _padded(handles):
    """Fixture denylists must clear MIN_HANDLES (the truncation tripwire), so pad
    with filler names that appear in no fixture content."""
    filler = [f"fillerperson{i}" for i in range(esg.MIN_HANDLES)]
    return sorted(set(list(handles) + filler))


def _repo_with_denylist(tmp_path, payload_text):
    """Commit ``payload_text`` as the denylist and return (ref, root)."""
    tmp_path.mkdir(parents=True, exist_ok=True)
    _git(["init", "-q"], tmp_path)
    _git(["config", "user.email", "t@example.invalid"], tmp_path)
    _git(["config", "user.name", "t"], tmp_path)
    p = tmp_path / esg.DENYLIST_REL
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(payload_text)
    _git(["add", esg.DENYLIST_REL], tmp_path)
    _git(["commit", "-q", "-m", "denylist"], tmp_path)
    return "HEAD", tmp_path


def _has(entries, needle):
    return any(needle in e for e in entries)


# --- the fix: namespace schema/module path is BLOCK ------------------------

def test_kairos_namespace_schema_path_is_block(tmp_path):
    # the REAL #38 leak form: a receipt schema string
    leak = '  "schema": "' + NS + "." + "ath" + TICKET_DIGITS + '.helper_parent_area_scout.v1"\n'
    block, warn, _ = _scan(tmp_path, {"athanor/receipt.json": leak})
    assert _has(block, "Kairos namespace"), block


def test_kairos_module_import_path_is_block(tmp_path):
    leak = "from " + NS + ".sv_bundle_parse import convert\n"
    block, warn, _ = _scan(tmp_path, {"athanor/helper.py": leak})
    assert _has(block, "Kairos namespace"), block


# --- the fix: AI-tool / vendor authorship footer is BLOCK (asabi ruling) ---

def test_ai_tool_footer_committed_is_block(tmp_path):
    # the real recurring leak: the bot attribution footer in a committed file
    block, warn, _ = _scan(tmp_path, {"athanor/notes.md": "// " + FOOTER + "\n"})
    assert _has(block, "AI-tool authorship footer"), block
    assert _has(block, "AI-tool name"), block  # broad token net also fires


def test_ai_vendor_coauthor_trailer_committed_is_block(tmp_path):
    # the co-author trailer form: "<tool> <noreply@<vendor>.com>"
    leak = "Co-Authored-By: " + TOOL + " <noreply@" + VENDOR + ".com>\n"
    block, warn, _ = _scan(tmp_path, {"athanor/notes.md": leak})
    assert _has(block, "AI-vendor name"), block


def test_ai_tool_footer_in_pr_body_text_is_block():
    # Quan's ask: a FRESH fork PR body carrying the footer must red via the
    # PR-text surface (scan_text) -- the committed-tree scan cannot see PR
    # metadata, and the footer is exactly what lands there. Same BLOCK_ALWAYS
    # source of truth, so committed-tree and PR-text can never drift.
    body = "This PR ports the branch-predictor encoder table.\n\n" + FOOTER + "\n"
    findings = esg.scan_text(body, source="pr-body")
    assert _has(findings, "AI-tool authorship footer"), findings


def test_ai_tool_name_is_case_insensitive(tmp_path):
    # footer casing varies across bots; the (?i) net must catch a lowercased form
    block, warn, _ = _scan(tmp_path, {"athanor/x.md": "built by " + TOOL.lower() + "\n"})
    assert _has(block, "AI-tool name"), block


def test_ordinary_words_are_not_a_false_ai_tool_hit(tmp_path):
    # precision: 'cla'+'ude' is a specific token -- words that merely share a
    # prefix ('clause', 'cladding') or contain 'clude' ('included') are NOT the
    # tool name and must never false-block a legitimate RTL/prose line.
    clean = "the included clause of the cladding module is public\n"
    block, warn, _ = _scan(tmp_path, {"athanor/rtl.v": clean})
    assert not _has(block, "AI-tool name"), block
    assert not _has(block, "AI-vendor name"), block


def test_allowed_verdict_tools_are_not_blocked(tmp_path):
    # The owner boundary (Quan control): the VERDICT tools -- Yosys / OpenSTA /
    # Lean -- are public BY DESIGN (our posture names them). Only the proprietary
    # proposal-side AI-tool/vendor markers are the leak. Naming a verdict tool in
    # a committed receipt/README must NEVER trip the vendor class.
    ok = "Verified with Yosys + OpenSTA; the proof was discharged in Lean.\n"
    block, warn, _ = _scan(tmp_path, {"athanor/receipt_notes.md": ok})
    assert not _has(block, "AI-tool name"), block
    assert not _has(block, "AI-vendor name"), block
    assert not _has(block, "AI-tool authorship footer"), block


# --- tier preservation: the repo pointer stays WARN, never upgraded --------

def test_repo_pointer_plain_stays_warn_not_block(tmp_path):
    block, warn, _ = _scan(tmp_path, {"athanor/notes.md": "see " + POINTER + " internal repo\n"})
    assert not _has(block, "Kairos namespace"), block
    assert _has(warn, "Kairos-repo pointer"), warn


def test_repo_pointer_dotted_form_is_not_upgraded_to_block(tmp_path):
    # (?<!athanor-) must keep the dotted repo URL out of the namespace BLOCK
    block, warn, _ = _scan(tmp_path, {"athanor/notes.md": "clone " + POINTER + ".git\n"})
    assert not _has(block, "Kairos namespace"), block
    assert _has(warn, "Kairos-repo pointer"), warn


# --- the fix: ticket id is case-insensitive + hyphen-optional (WARN) -------

@pytest.mark.parametrize("ticket", [
    "A" + "TH-" + TICKET_DIGITS,    # ATH-2852  (original form, still WARN)
    "a" + "th-" + TICKET_DIGITS,    # ath-2852  (lowercase)
    "a" + "th" + TICKET_DIGITS,     # ath2852   (lowercase, no hyphen -- the evader)
    "A" + "th-" + TICKET_DIGITS,    # Ath-2852  (mixed case)
    "A" + "TH" + TICKET_DIGITS,     # ATH2852   (upper, no hyphen)
])
def test_ticket_id_case_and_hyphen_variants_warn(tmp_path, ticket):
    block, warn, _ = _scan(tmp_path, {"athanor/r.json": '  "ref": "' + ticket + '"\n'})
    assert _has(warn, "Linear ticket id"), (ticket, warn)


def test_datapath_digits_are_not_a_false_ticket(tmp_path):
    # leading \b keeps the widened ticket pattern off in-word digits
    block, warn, _ = _scan(tmp_path, {"athanor/rtl.v": "wire " + "datapath" + "2960" + ";\n"})
    assert not _has(warn, "Linear ticket id"), warn


# --- positive controls: unrelated tiers unchanged --------------------------

def test_workdir_path_still_blocks(tmp_path):
    block, warn, _ = _scan(tmp_path, {"athanor/log.txt": "at " + WD + "/athanor/x\n"})
    assert _has(block, "workdir"), block


def test_clean_tree_is_silent(tmp_path):
    block, warn, _ = _scan(tmp_path, {"athanor/ok.txt": "a plain public line\n"})
    assert block == [] and warn == [], (block, warn)


# --- scanner is the sole discriminator (seeded secret + valid manifest) ----

def test_scanner_blocks_namespace_independent_of_valid_receipt_manifest(tmp_path):
    # Seed the namespace into a committed artifact AND give it a VALID SHA256SUMS
    # entry. The byte-scanner must block regardless of the manifest verifying --
    # the scanner, not the receipt hash, is the sole discriminator.
    leak = NS + "." + "ath" + TICKET_DIGITS + ".scout.v1\n"
    digest = hashlib.sha256(leak.encode()).hexdigest()
    sums = digest + "  receipt.json\n"
    block, warn, _ = _scan(tmp_path, {
        "athanor_artifacts/receipt.json": leak,
        "athanor_artifacts/SHA256SUMS": sums,
    })
    assert _has(block, "Kairos namespace"), block


# --- ATH-3397 denylist-infra: roster-derivation tests (generator only; the
# gate that CONSUMES the denylist rides the separate red-by-design PR #76).
_H_A = "qu" + "an"
_H_B = "ai" + "dan"
_H_C = "an" + "ton"
_RK = "buil" + "der"


def _denylist_json(handles):
    """A denylist DATA file body with a correct integrity stamp for ``handles``."""
    import hashlib as _hl
    import json as _j
    hs = sorted(handles)
    stamp = _hl.sha256("\n".join(hs).encode()).hexdigest()
    return _j.dumps({"handles": hs, "stamp": stamp})


def _load_gen():
    gen_path = Path(__file__).resolve().parent.parent / "athanor" / "gen_fleet_handle_denylist.py"
    spec = _ilu.spec_from_file_location("gen_fhd_infra", gen_path)
    gen = _ilu.module_from_spec(spec)
    spec.loader.exec_module(gen)
    return gen


def test_derive_handles_excludes_role_keys_includes_persons():
    gen = _load_gen()
    roles = {"roles": {"platform": {}, "maurice": {}, "research": {}},
             "_renames": {"perry": "platform", _H_A: "qa", _RK: _RK}}
    handles = gen.derive_handles(roles)
    assert "perry" in handles and "maurice" in handles and _H_A in handles
    assert "platform" not in handles and "research" not in handles and _RK not in handles


def test_derive_handles_reads_humans_section_from_roster():
    # ATH-3427 (builder #943): humans live in roles.json's `humans` section now;
    # the generator reads them there instead of AST-parsing slack_post.
    gen = _load_gen()
    name_a = "ai" + "dan"
    name_b = "an" + "ton"
    roles = {
        "roles": {"platform": {}, "maurice": {}},
        "humans": {name_a: {"slack_user_id": "U0"}, name_b: {"slack_user_id": "U1"},
                   "founder": {"slack_user_id": "U2"}},
        "_renames": {"perry": "platform"},
    }
    handles = gen.derive_handles(roles)
    assert name_a in handles and name_b in handles
    assert "maurice" in handles and "perry" in handles
    assert "founder" not in handles and "platform" not in handles

def test_alt_handles_reach_the_derived_set():
    # asabi/Bob 2026-07-27: a denylist of canonical names does not catch a
    # founder alt-handle; KNOWN_ALT_HANDLES is the ATH-3427 stopgap and must
    # reach the derived set with no source-list entry.
    gen = _load_gen()
    handles = gen.derive_handles({"roles": {}, "_renames": {}})
    assert ("aidan" + "by") in handles
    assert ("hongsk" + "sam") in handles


def test_generation_reads_declared_builder_commit_not_worktree(tmp_path):
    # ATH-3427/#61: reads roles.json (single identity SSOT) at the DECLARED
    # commit via git show, never the working tree — Dexter's hold preserved.
    gen = _load_gen()
    builder = tmp_path / "builder"
    handoff = builder / "tools" / "agent-handoff"
    handoff.mkdir(parents=True)
    roles_path = handoff / "roles.json"
    roles_path.write_text(json.dumps(
        {"roles": {_H_A: {}, "research": {}}, "humans": {_H_B: {"slack_user_id": "U0"}},
         "_renames": {}}))
    _git(["init", "-q"], builder)
    _git(["config", "user.email", "t@example.invalid"], builder)
    _git(["config", "user.name", "t"], builder)
    _git(["add", "tools/agent-handoff/roles.json"], builder)
    _git(["commit", "-q", "-m", "authority"], builder)
    commit = subprocess.check_output(["git", "-C", str(builder), "rev-parse", "HEAD"], text=True).strip()

    roles_path.write_text(json.dumps(
        {"roles": {"dirtyperson": {}, "research": {}}, "humans": {_H_C: {"slack_user_id": "U1"}},
         "_renames": {}}))

    out = tmp_path / "denylist.json"
    assert gen.main(["--source-repo", str(builder), "--source-ref", commit, "--out", str(out)]) == 0
    payload = json.loads(out.read_text())
    assert _H_A in payload["handles"] and _H_B in payload["handles"]
    assert "dirtyperson" not in payload["handles"] and _H_C not in payload["handles"]
    assert payload["source"] == {
        "repo": "athanor-builder",
        "files": ["tools/agent-handoff/roles.json (roles + humans + _renames)"],
        "commit": commit,
        "ref": commit,
    }
    assert _H_A in payload["handles"] and _H_B in payload["handles"]
    assert "dirtyperson" not in payload["handles"] and _H_C not in payload["handles"]


# --- ATH-3397: fleet-agent handle GATE tests (the gate that consumes the
# denylist; derivation tests live above from the infra split). --------------

def test_agent_handle_in_customer_artifact_prose_is_block(tmp_path, monkeypatch):
    # select the tier explicitly: this test is about DETECTION capability,
    # not about which tier happens to be the default (asabi: a test coupled
    # to the default measures configuration, not capability).
    monkeypatch.setattr(esg, "HANDLE_FINDING_TIER", "block")
    leak = '{"note":"cross-VM replay required (' + _H_A.capitalize() + ')"}\n'
    block, _, _ = _scan(tmp_path, {"athanor_artifacts/pkt/receipt.json": leak})
    assert _has(block, "fleet-agent handle")
    assert _has(block, "receipt.json")


def test_generic_role_key_is_not_a_handle_hit(tmp_path):
    text = "the " + _RK + " pattern is common in this rtl\n"
    block, _, _ = _scan(tmp_path, {"athanor_artifacts/pkt/notes.md": text})
    assert not _has(block, "fleet-agent handle")


def test_denylist_data_file_is_exempt_not_self_flagged(tmp_path):
    block, _, _ = _scan(tmp_path, {})
    assert not any("fleet-agent handle" in b and esg.DENYLIST_REL in b for b in block)


def test_tooling_py_source_is_out_of_handle_scope(tmp_path):
    src = "# hardening pass reviewed by " + _H_A.capitalize() + "\n"
    block, _, _ = _scan(tmp_path, {"athanor/helper.py": src})
    assert not _has(block, "fleet-agent handle")


def test_denylist_stamp_mismatch_fails_closed(tmp_path):
    bad = json.dumps({"handles": _padded([_H_A, _H_B]), "stamp": "0" * 64})
    ref, root = _repo_with_denylist(tmp_path, bad)
    with pytest.raises(esg.GateError):
        esg._load_agent_handles(ref, root)


def test_missing_denylist_fails_closed(tmp_path):
    _git(["init", "-q"], tmp_path)
    _git(["config", "user.email", "t@example.invalid"], tmp_path)
    _git(["config", "user.name", "t"], tmp_path)
    (tmp_path / "x.txt").write_text("x")
    _git(["add", "x.txt"], tmp_path)
    _git(["commit", "-q", "-m", "no denylist"], tmp_path)
    with pytest.raises(esg.GateError):
        esg._load_agent_handles("HEAD", tmp_path)

def test_correctly_stamped_but_emptied_denylist_fails_closed(tmp_path):
    # dexter's #59 finding: the stamp proves the file was not hand-edited, NOT that
    # it still has content. Empty/gutted lists with VALID stamps compile zero
    # patterns and make the gate scan for nothing — they must fail closed.
    import hashlib as _hl
    for i, handles in enumerate(([], [_H_A], [_H_A, _H_B])):
        hs = sorted(handles)
        body = json.dumps({"handles": hs,
                           "stamp": _hl.sha256("\n".join(hs).encode()).hexdigest()})
        ref, root = _repo_with_denylist(tmp_path / f"r{i}", body)
        with pytest.raises(esg.GateError):
            esg._load_agent_handles(ref, root)

def test_a_full_denylist_still_loads(tmp_path):
    # control: the truncation floor must not reject a normal derived set.
    import hashlib as _hl
    handles = sorted(f"person{i}" for i in range(esg.MIN_HANDLES + 3))
    body = json.dumps({"handles": handles,
                       "stamp": _hl.sha256("\n".join(handles).encode()).hexdigest()})
    ref, root = _repo_with_denylist(tmp_path, body)
    assert esg._load_agent_handles(ref, root) == handles

def test_worktree_denylist_tamper_cannot_hide_committed_leaks(tmp_path):
    # dexter's #59 re-read: the scan reads COMMITTED bytes at --ref, so the denylist
    # must load from the SAME ref. Reading it from the working tree let anyone
    # silence the gate by emptying an UNCOMMITTED file — config and subject from
    # different trees.
    import hashlib as _hl
    good = _padded([_H_A, _H_B])
    body = json.dumps({"handles": good,
                       "stamp": _hl.sha256("\n".join(good).encode()).hexdigest()})
    ref, root = _repo_with_denylist(tmp_path, body)
    # now gut the WORKING TREE copy without committing it
    empty = json.dumps({"handles": [], "stamp": _hl.sha256(b"").hexdigest()})
    (root / esg.DENYLIST_REL).write_text(empty)
    assert esg._load_agent_handles(ref, root) == good  # committed content wins


def test_denylist_container_must_be_a_list_not_a_string(tmp_path):
    # dexter (#59): a JSON STRING "abcdefgh" has len 8 and iterates into eight
    # one-character handles, each a non-empty string — clearing a naive floor
    # while compiling nothing useful. Python duck typing hides it: every length
    # and iteration behaves plausibly while measuring CHARACTERS.
    import hashlib as _hl
    body = json.dumps({"handles": "abcdefgh",
                       "stamp": _hl.sha256("\n".join(sorted("abcdefgh")).encode()).hexdigest()})
    ref, root = _repo_with_denylist(tmp_path, body)
    with pytest.raises(esg.GateError):
        esg._load_agent_handles(ref, root)


def test_duplicate_handles_do_not_clear_the_floor(tmp_path):
    # dexter (#59): ["alpha"] * 8 is eight entries and ONE effective pattern.
    # The floor exists to prove distinct coverage, so it must count UNIQUE handles.
    import hashlib as _hl
    handles = ["alpha"] * esg.MIN_HANDLES
    body = json.dumps({"handles": handles,
                       "stamp": _hl.sha256("\n".join(sorted(handles)).encode()).hexdigest()})
    ref, root = _repo_with_denylist(tmp_path, body)
    with pytest.raises(esg.GateError):
        esg._load_agent_handles(ref, root)


def test_case_variants_are_not_distinct_handles(tmp_path):
    # the same name in different cases is one pattern (the scan is case-insensitive).
    import hashlib as _hl
    handles = sorted({f"Alpha{i % 2}" for i in range(2)} | {"ALPHA0", "alpha1"})
    body = json.dumps({"handles": handles,
                       "stamp": _hl.sha256("\n".join(handles).encode()).hexdigest()})
    ref, root = _repo_with_denylist(tmp_path, body)
    with pytest.raises(esg.GateError):
        esg._load_agent_handles(ref, root)


def test_floor_boundary_min_minus_one_fails_and_min_passes(tmp_path):
    # both sides of the boundary, so the floor cannot drift silently.
    import hashlib as _hl
    for n, should_pass in ((esg.MIN_HANDLES - 1, False), (esg.MIN_HANDLES, True)):
        handles = sorted(f"person{i}" for i in range(n))
        body = json.dumps({"handles": handles,
                           "stamp": _hl.sha256("\n".join(handles).encode()).hexdigest()})
        ref, root = _repo_with_denylist(tmp_path / f"n{n}", body)
        if should_pass:
            assert esg._load_agent_handles(ref, root) == handles
        else:
            with pytest.raises(esg.GateError):
                esg._load_agent_handles(ref, root)


def test_whitespace_wrapped_handles_fail_closed(tmp_path):
    # dexter (#59/#76, third pass): the floor counted h.strip().casefold() while the
    # loader returned — and the scanner compiled — the untrimmed h. Eight distinct
    # whitespace-wrapped names cleared the floor while matching nothing, because the
    # floor measured a DIFFERENT pattern set than the scan compiles.
    import hashlib as _hl
    wrapped = [f" name{i} " for i in range(esg.MIN_HANDLES)]
    body = json.dumps({"handles": wrapped,
                       "stamp": _hl.sha256("\n".join(sorted(wrapped)).encode()).hexdigest()})
    ref, root = _repo_with_denylist(tmp_path, body)
    with pytest.raises(esg.GateError):
        esg._load_agent_handles(ref, root)


def test_canonical_denylist_catches_the_bare_name_end_to_end(tmp_path, monkeypatch):
    # select the tier explicitly: this test is about DETECTION capability,
    # not about which tier happens to be the default (asabi: a test coupled
    # to the default measures configuration, not capability).
    monkeypatch.setattr(esg, "HANDLE_FINDING_TIER", "block")
    # the other direction: a canonical MIN-sized list loads AND the compiled
    # patterns actually catch the bare name in a customer artifact.
    import hashlib as _hl
    handles = sorted(f"name{i}" for i in range(esg.MIN_HANDLES))
    files = {
        esg.DENYLIST_REL: json.dumps(
            {"handles": handles,
             "stamp": _hl.sha256("\n".join(handles).encode()).hexdigest()}),
        "athanor_artifacts/pkt/receipt.json": '{"reviewer": "name3"}\n',
    }
    block, _, _ = _scan(tmp_path, files)
    assert _has(block, "fleet-agent handle")
    assert _has(block, "receipt.json")


# --- ATH-3397 tier staging: the handle scan lands at WARN on forks where
# export-safety is a REQUIRED context, then is PROMOTED to BLOCK after the scrub.
# asabi's condition 2: the promotion must be proven by EXERCISE on a constructed
# instance, because a tier promoted against an empty population has never once
# blocked anything — a required gate that emits green because it cannot fail is
# the dead-gate shape arriving through the back door of a correct plan.

def _repo_with_a_live_handle_instance(tmp_path):
    """Commit a denylist plus a customer artifact containing one of its handles."""
    import hashlib as _hl
    handles = _padded([_H_A, _H_B])
    files = {
        esg.DENYLIST_REL: json.dumps(
            {"handles": handles,
             "stamp": _hl.sha256("\n".join(sorted(handles)).encode()).hexdigest()}),
        "athanor_artifacts/pkt/receipt.json": '{"reviewer": "' + _H_A + '"}\n',
    }
    tmp_path.mkdir(parents=True, exist_ok=True)
    _git(["init", "-q"], tmp_path)
    _git(["config", "user.email", "t@example.invalid"], tmp_path)
    _git(["config", "user.name", "t"], tmp_path)
    for rel, content in files.items():
        p = tmp_path / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content)
        _git(["add", rel], tmp_path)
    _git(["commit", "-q", "-m", "live instance"], tmp_path)
    return tmp_path


# The AFFIRMATIVE cleanliness claim, as the gate emits it. Pinned once so the
# two verdict tests below cannot drift to different notions of "says clean".
_AFFIRMATIVE_CLEAN = "gate clean at"


def _repo_with_many_generic_warnings(tmp_path, count):
    """Commit ``count`` distinct GENERIC (non-handle) WARN findings.

    Generic on purpose: the staged handle section is uncapped, so only generic
    findings exercise --warn-limit, which is the path whose coverage claim is
    under test.
    """
    import hashlib as _hl
    handles = _padded([_H_A, _H_B])
    files = {
        esg.DENYLIST_REL: json.dumps(
            {"handles": handles,
             "stamp": _hl.sha256("\n".join(sorted(handles)).encode()).hexdigest()}),
    }
    for i in range(count):
        files[f"athanor/notes_{i}.md"] = f"see {POINTER} internal repo, note {i}\n"
    tmp_path.mkdir(parents=True, exist_ok=True)
    _git(["init", "-q"], tmp_path)
    _git(["config", "user.email", "t@example.invalid"], tmp_path)
    _git(["config", "user.name", "t"], tmp_path)
    for rel, content in files.items():
        p = tmp_path / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content)
        _git(["add", rel], tmp_path)
    _git(["commit", "-q", "-m", "many warns"], tmp_path)
    return tmp_path


def _repo_with_no_findings(tmp_path):
    """Same shape as above but the artifact cites NO handle -- nothing to report.

    Deliberately identical in every other respect (same denylist, same paths, one
    committed artifact) so the only variable between this and the live-instance
    fixture is whether a finding exists.
    """
    import hashlib as _hl
    handles = _padded([_H_A, _H_B])
    files = {
        esg.DENYLIST_REL: json.dumps(
            {"handles": handles,
             "stamp": _hl.sha256("\n".join(sorted(handles)).encode()).hexdigest()}),
        "athanor_artifacts/pkt/receipt.json": '{"reviewer": "a-name-not-on-the-list"}\n',
    }
    tmp_path.mkdir(parents=True, exist_ok=True)
    _git(["init", "-q"], tmp_path)
    _git(["config", "user.email", "t@example.invalid"], tmp_path)
    _git(["config", "user.name", "t"], tmp_path)
    for rel, content in files.items():
        p = tmp_path / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content)
        _git(["add", rel], tmp_path)
    _git(["commit", "-q", "-m", "no findings"], tmp_path)
    return tmp_path


def test_block_tier_exits_nonzero_on_a_constructed_instance(tmp_path, monkeypatch, capsys):
    # THE PROMOTION BITE. Proves the BLOCK tier actually blocks, on a population we
    # construct — the real population is zero by promotion time, which is why
    # inheriting confidence from WARN would prove nothing.
    #
    # The verifier is neutralised deliberately: a synthetic tree has no receipts,
    # so it fail-closes and would make rc != 0 EVEN IF the tier were broken. An
    # earlier draft of this test asserted only rc != 0 and passed for exactly that
    # wrong reason. The assertion is on the CAUSE, not just the exit code.
    root = _repo_with_a_live_handle_instance(tmp_path)
    monkeypatch.setattr(esg, "HANDLE_FINDING_TIER", "block")
    monkeypatch.setattr(esg, "_run_receipt_verifier", lambda root: [])
    monkeypatch.chdir(root)
    rc = esg.main(["--ref", "HEAD"])
    out = capsys.readouterr()
    combined = out.out + out.err
    assert rc != 0, "BLOCK tier did not fail on a live handle instance"
    assert "block: [internal fleet-agent handle]" in combined, (
        "nonzero exit was not caused by the handle finding: " + combined[-300:])



def test_warn_tier_reports_the_instance_but_does_not_fail(tmp_path, monkeypatch, capsys):
    # THE STAGING PROPERTY. The gate lands, NAMES its live population in the log,
    # and leaves the required context green so the PR introducing it can merge.
    # Verifier neutralised for the same reason as the BLOCK test: a synthetic tree
    # has no receipts, so its fail-closed finding would mask the tier behaviour.
    root = _repo_with_a_live_handle_instance(tmp_path)
    monkeypatch.setattr(esg, "HANDLE_FINDING_TIER", "warn")
    monkeypatch.setattr(esg, "_run_receipt_verifier", lambda root: [])
    monkeypatch.chdir(root)
    rc = esg.main(["--ref", "HEAD"])
    out = capsys.readouterr()
    combined = out.out + out.err
    assert rc == 0, "WARN tier must not fail the required context: " + combined[-300:]
    assert "fleet-agent handle" in combined, "WARN tier must still REPORT the instance"
    assert "block: [internal fleet-agent handle]" not in combined, (
        "WARN tier must not emit the finding as a BLOCK row")


def test_the_verdict_line_does_not_say_clean_while_reporting_findings(
    tmp_path, monkeypatch, capsys
):
    """CLEAN is a claim about the TREE. 0 BLOCK is a fact about the TIER.

    The summary line used to say ``gate clean`` whenever nothing reached BLOCK
    tier -- so on the real c910 main it printed CLEAN while naming 412 live
    fleet-agent-handle instances across 7 published artifacts on a PUBLIC fork.
    Accurate about what it measured, false about what it claimed, in the gate
    whose whole job is catching that, on the one line a reader quotes.

    Exit code is NOT the subject here: rc==0 is correct at WARN tier and the
    staging test above already pins it. This pins the WORD -- a verdict may use
    CLEAN only when there is nothing to report.
    """
    root = _repo_with_a_live_handle_instance(tmp_path)
    monkeypatch.setattr(esg, "HANDLE_FINDING_TIER", "warn")
    monkeypatch.setattr(esg, "_run_receipt_verifier", lambda root: [])
    monkeypatch.chdir(root)
    rc = esg.main(["--ref", "HEAD"])
    combined = "".join(capsys.readouterr())

    assert rc == 0, "tier behaviour must be unchanged: " + combined[-300:]
    verdict = [ln for ln in combined.splitlines() if ln.startswith("OK")]
    assert verdict, "no verdict line emitted: " + combined[-300:]
    line = verdict[-1]

    # The AFFIRMATIVE phrase, not the bare word. `"clean" in line` is true of
    # "NOT clean" -- substring-where-a-value-was-meant, which this repo has now
    # hit five times, once in the first draft of THIS test.
    assert _AFFIRMATIVE_CLEAN not in line, (
        "the verdict called the tree CLEAN while findings were reported above "
        "it. That is the defect this gate exists to catch, in its own summary: "
        + line
    )
    assert "NOT clean" in line, (
        "the verdict must SAY it is not clean, not merely omit the claim -- an "
        "omission reads as an oversight, a denial reads as a measurement: " + line
    )
    assert "WARN finding" in line, (
        "the verdict must carry the COUNT it is reporting, not just a denial: "
        + line
    )


def test_the_verdict_does_not_claim_coverage_the_display_cap_withheld(
    tmp_path, monkeypatch, capsys
):
    """THE SAME OVERCLAIM ONE FIELD OVER, in the fix for the overclaim.

    The first draft of the corrected verdict said "every finding is named
    above" -- false whenever --warn-limit bites, which is the DEFAULT. I had
    replaced a verdict that lied about CLEANLINESS with one that lied about
    COVERAGE, while writing the change whose entire subject is verdicts that
    claim more than they measured.

    So this pins the second claim the way the test above pins the first: when
    rows are withheld, the verdict must say how many, and it must not assert
    completeness.
    """
    root = _repo_with_many_generic_warnings(tmp_path, count=5)
    monkeypatch.setattr(esg, "_run_receipt_verifier", lambda root: [])
    monkeypatch.chdir(root)
    rc = esg.main(["--ref", "HEAD", "--warn-limit", "2"])
    combined = "".join(capsys.readouterr())

    assert rc == 0, combined[-300:]
    verdict = [ln for ln in combined.splitlines() if ln.startswith("OK")][-1]
    assert "not shown" in verdict, (
        "the cap withheld findings and the verdict did not say so: " + verdict
    )
    assert "all named above" not in verdict, (
        "the verdict claimed completeness the display did not deliver: " + verdict
    )

    # The withheld count must RECONCILE with the rows actually printed -- a
    # number that does not add up is the miscount this change exists to fix.
    shown = len([r for r in combined.splitlines() if r.strip().startswith("warn:")])
    withheld = int(re.search(r"(\d+) not shown", verdict).group(1))
    total = int(re.search(r"raised (\d+) WARN", verdict).group(1))
    assert shown + withheld == total, (
        f"shown {shown} + withheld {withheld} != reported total {total}; the "
        "row display and the verdict are counting different populations"
    )


def test_the_verdict_line_still_says_clean_when_there_is_nothing_to_report(
    tmp_path, monkeypatch, capsys
):
    """NARROWNESS CONTROL for the test above.

    A check that forbids the word CLEAN unconditionally would pass the previous
    test while destroying the verdict's only useful positive statement. So the
    clean tree must still be ABLE to say clean -- otherwise the fix is just a
    different false claim pointing the other way.
    """
    root = _repo_with_no_findings(tmp_path)
    monkeypatch.setattr(esg, "_run_receipt_verifier", lambda root: [])
    monkeypatch.chdir(root)
    rc = esg.main(["--ref", "HEAD"])
    combined = "".join(capsys.readouterr())

    assert rc == 0, combined[-300:]
    assert _AFFIRMATIVE_CLEAN in combined, (
        "a tree with nothing to report must still be reportable as clean: "
        + combined[-300:]
    )


def test_warn_staging_reports_the_same_population_block_would(tmp_path, monkeypatch, capsys):
    # DEXTER'S PAIRED ASSERTION, and the one that catches the real defect: it is not
    # enough that BLOCK bites and WARN exits 0 — WARN must REPORT THE SAME live
    # population, or the staging silently shrinks the set the scrub is measured
    # against. On the real tree the generic --warn-limit truncated every handle
    # finding away, so the landing would have named ZERO while claiming to name its
    # population. The fixture below is padded past the cap to reproduce that.
    import hashlib as _hl
    handles = _padded([_H_A, _H_B])
    files = {
        esg.DENYLIST_REL: json.dumps(
            {"handles": handles,
             "stamp": _hl.sha256("\n".join(sorted(handles)).encode()).hexdigest()}),
        "athanor_artifacts/pkt/receipt.json": '{"reviewer": "' + _H_A + '"}\n',
    }
    # bury it under many generic WARN-tier findings (ticket ids), past any cap
    for i in range(60):
        files[f"athanor_artifacts/noise/n{i}.md"] = f"tracking ATH-{2000 + i}\n"
    tmp_path.mkdir(parents=True, exist_ok=True)
    _git(["init", "-q"], tmp_path)
    _git(["config", "user.email", "t@example.invalid"], tmp_path)
    _git(["config", "user.name", "t"], tmp_path)
    for rel, content in files.items():
        p = tmp_path / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content)
        _git(["add", rel], tmp_path)
    _git(["commit", "-q", "-m", "buried instance"], tmp_path)

    monkeypatch.setattr(esg, "_run_receipt_verifier", lambda root: [])
    monkeypatch.chdir(tmp_path)

    monkeypatch.setattr(esg, "HANDLE_FINDING_TIER", "block")
    esg.main(["--ref", "HEAD"])
    block_out = capsys.readouterr()
    block_n = (block_out.out + block_out.err).count("[internal fleet-agent handle]")

    monkeypatch.setattr(esg, "HANDLE_FINDING_TIER", "warn")
    rc = esg.main(["--ref", "HEAD"])
    warn_out = capsys.readouterr()
    warn_n = (warn_out.out + warn_out.err).count("[internal fleet-agent handle]")

    assert rc == 0, "WARN must not fail the required context"
    assert block_n > 0, "control: BLOCK must have reported instances"
    assert warn_n == block_n, (
        f"WARN staging reported {warn_n} instances but BLOCK reported {block_n} — "
        "the staging is hiding part of the population it claims to name")


def test_handle_pattern_catches_identifier_forms(tmp_path, monkeypatch):
    # ATH-3439 pattern ruling applied here: `_` is a word character, so a \b-bounded
    # handle MISSES quan_review / reviewer_quan / created_by_quan — which is exactly
    # how a handle lands in a receipt field. These must all be caught.
    monkeypatch.setattr(esg, "HANDLE_FINDING_TIER", "block")
    for body in ('{"n": "' + _H_A + '_review"}',
                 '{"n": "reviewer_' + _H_A + '"}',
                 '{"d": "' + _H_A + '-ath2686-run"}',
                 '{"reviewer": "' + _H_A + '"}'):
        block, _, _ = _scan(tmp_path / f"r{abs(hash(body))%9999}",
                            {"athanor_artifacts/pkt/receipt.json": body + "\n"})
        assert _has(block, "fleet-agent handle"), f"identifier form missed: {body}"


def test_handle_pattern_does_not_flag_ordinary_vocabulary(tmp_path, monkeypatch):
    # THE NEGATIVE HALF (asabi: a suite that only proves necessity cannot detect
    # over-matching). A substring pattern would flag our own domain vocabulary —
    # "memory banking" is RTL optimisation language on a hardware product. These
    # must NOT be flagged, or the gate deletes the product's own words.
    monkeypatch.setattr(esg, "HANDLE_FINDING_TIER", "block")
    clean = [
        '{"note": "memory banking splits large memories"}',
        '{"note": "adversarial thinking is required"}',
        '{"note": "quantum quantity quantile"}',
        '{"note": "the platform and plate and plating"}',
    ]
    for i, body in enumerate(clean):
        block, _, _ = _scan(tmp_path / f"c{i}",
                            {"athanor_artifacts/pkt/notes.json": body + "\n"})
        assert not _has(block, "fleet-agent handle"), f"false positive on: {body}"


def test_invalid_tier_fails_closed(tmp_path, monkeypatch):
    # dexter (#76): HANDLE_FINDING_TIER="blok" routed 32 live findings into the warn
    # bucket while the uncapped STAGED section (which runs only for exactly "warn")
    # stayed silent — exit 0, "gate clean", 32 instances invisible. A typo on the
    # one constant the promotion PR edits silently disabled the gate.
    monkeypatch.setattr(esg, "HANDLE_FINDING_TIER", "blok")
    with pytest.raises(esg.GateError):
        _scan(tmp_path, {"athanor_artifacts/pkt/receipt.json": '{"r": "' + _H_A + '"}\n'})


def test_both_valid_tiers_are_accepted(tmp_path, monkeypatch):
    # control: the guard must not reject the two legitimate values, or it would
    # simply break the gate rather than harden it.
    for tier in ("warn", "block"):
        monkeypatch.setattr(esg, "HANDLE_FINDING_TIER", tier)
        _scan(tmp_path / tier, {"athanor_artifacts/pkt/receipt.json": '{"r": "x"}\n'})


def test_artifact_extension_match_is_case_insensitive(tmp_path, monkeypatch):
    # dexter (#76): the scan normalised `ext` to lower case and then ignored it,
    # using path.endswith((".json",".md")) — so RECEIPT.JSON, a perfectly ordinary
    # way to name a published artifact, was never scanned at all.
    monkeypatch.setattr(esg, "HANDLE_FINDING_TIER", "block")
    for i, name in enumerate(("RECEIPT.JSON", "receipt.Json", "NOTES.MD", "notes.Md")):
        block, _, _ = _scan(tmp_path / f"e{i}",
                            {f"athanor_artifacts/pkt/{name}": '{"r": "' + _H_A + '"}\n'})
        assert _has(block, "fleet-agent handle"), f"{name} was not scanned"


def test_path_scope_decisions_are_case_insensitive(tmp_path, monkeypatch):
    # THE FIFTH INSTANCE of the compute-then-ignore family (asabi: at four, the file
    # needs a structural pass). Scope was decided on the RAW path, so
    # Athanor_Artifacts/pkt/receipt.json escaped OUR_ADDED_PREFIXES and was never
    # scanned at all. Every decision now consumes the normalised path_key; the raw
    # path survives only for DISPLAY.
    monkeypatch.setattr(esg, "HANDLE_FINDING_TIER", "block")
    for i, rel in enumerate((
        "athanor_artifacts/pkt/receipt.json",
        "Athanor_Artifacts/pkt/receipt.json",
        "ATHANOR_ARTIFACTS/pkt/RECEIPT.JSON",
    )):
        block, _, _ = _scan(tmp_path / f"p{i}", {rel: '{"r": "' + _H_A + '"}\n'})
        assert _has(block, "fleet-agent handle"), f"scope missed: {rel}"


def test_findings_display_the_original_path_casing(tmp_path, monkeypatch):
    # the raw path must still be what a reader sees, or the finding points at a file
    # that does not exist. Normalise for DECISIONS, display the original.
    monkeypatch.setattr(esg, "HANDLE_FINDING_TIER", "block")
    block, _, _ = _scan(tmp_path, {"Athanor_Artifacts/pkt/RECEIPT.JSON":
                                   '{"r": "' + _H_A + '"}\n'})
    assert any("Athanor_Artifacts/pkt/RECEIPT.JSON" in b for b in block), block


def test_the_handle_scan_has_no_extension_allow_list():
    """SCOPE IS DERIVED, NOT ENUMERATED.

    The scan used a positive extension list of (".json", ".md"), which inspected
    89 of 598 published artifact files -- 15% -- and reported CLEAN over the other
    85%. Seven published, hash-bound .log files carried an internal workspace path
    the entire time and the gate said zero.

    This fails if an inclusion list is reintroduced. Exemptions are still allowed,
    but they must be NAMED with a reason, so an unknown or new file type is loud
    rather than silently out of scope.
    """
    import ast

    # BEHAVIOUR, NOT SPELLING. Asserting the retired symbol's absence passes on a
    # pure RENAME -- which is exactly what happened: the handle scan's allow-list
    # was removed and BINARY_ASSET_EXT carried the same class forward under a
    # different name. This rejects ANY frozenset/tuple/set of dotted extension
    # literals in the module, whatever it is called.
    tree = ast.parse(Path(esg.__file__).read_text(encoding="utf-8"))
    for node in ast.walk(tree):
        if not isinstance(node, (ast.Set, ast.Tuple, ast.List)):
            continue
        literals = [e.value for e in node.elts if isinstance(e, ast.Constant)]
        dotted = [x for x in literals if isinstance(x, str) and re.fullmatch(r"\.[a-z0-9]{1,6}", x)]
        assert len(dotted) < 3, (
            f"an extension allow-list is back in the gate ({dotted[:5]}); scope "
            f"must be derived -- scan every committed TEXT file (decided by "
            f"content), with skips named in HANDLE_SCAN_EXEMPT_PATHS"
        )


def test_every_scan_exemption_carries_a_reason():
    """A keep-set is only arguable if it says WHY. Each exemption maps to prose a
    reviewer can disagree with, not a bare path."""
    for path, reason in esg.HANDLE_SCAN_EXEMPT_PATHS.items():
        assert isinstance(reason, str) and len(reason.strip()) > 20, (
            f"exemption for {path} has no stated reason"
        )


def test_a_handle_in_a_log_file_is_now_scanned(tmp_path, monkeypatch, capsys):
    """The exact live instance the allow-list missed: a handle inside a .log,
    which no earlier version of this gate would have inspected."""
    root = _repo_with_a_live_handle_instance(tmp_path)
    handle = _H_A
    log = root / "athanor_artifacts" / "pkg" / "run.log"
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text(
        f"read_verilog -sv .scratch/{handle}_scout/design.v\n", encoding="utf-8"
    )
    subprocess.run(["git", "add", "-A"], cwd=root, capture_output=True, check=False)
    subprocess.run(
        ["git", "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "log"],
        cwd=root, capture_output=True, check=False,
    )
    monkeypatch.setattr(esg, "_run_receipt_verifier", lambda root: [])
    monkeypatch.chdir(root)
    esg.main(["--ref", "HEAD"])
    combined = capsys.readouterr()
    assert "run.log" in combined.out + combined.err, (
        "a handle inside a .log was not scanned: " + (combined.out + combined.err)[-400:]
    )


def test_an_exemption_matches_an_exact_path_not_a_substring(tmp_path, monkeypatch, capsys):
    """quan's construction. A substring or prefix exemption OVER-EXEMPTS -- the
    same substring-where-a-value-was-meant shape as the closure gate's
    replacement check. The operator is set membership on the exact rel-path;
    this pins it so it cannot decay into `startswith` or `in`."""
    root = _repo_with_a_live_handle_instance(tmp_path)
    exempt = next(iter(esg.HANDLE_SCAN_EXEMPT_PATHS))
    # A DIFFERENT path that merely CONTAINS an exempt path as a substring.
    decoy = root / (exempt + ".backup.md")
    decoy.parent.mkdir(parents=True, exist_ok=True)
    decoy.write_text(f"reviewed by {_H_A}\n", encoding="utf-8")
    subprocess.run(["git", "add", "-A"], cwd=root, capture_output=True, check=False)
    subprocess.run(
        ["git", "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "decoy"],
        cwd=root, capture_output=True, check=False,
    )
    monkeypatch.setattr(esg, "_run_receipt_verifier", lambda root: [])
    monkeypatch.chdir(root)
    esg.main(["--ref", "HEAD"])
    out = capsys.readouterr()
    assert ".backup.md" in out.out + out.err, (
        "a path containing an exempt path as a SUBSTRING was exempted"
    )


def test_a_file_that_cannot_be_byte_scanned_is_named_not_silently_skipped(
    tmp_path, monkeypatch, capsys
):
    """quan's second construction, and asabi's rule one gate over: "could not
    classify" must not render as "fine". A binary file cannot be scanned for
    handles -- that is a real limitation -- but it must be NAMED in the output so
    the reader can size what the gate did not inspect, rather than the file
    vanishing from the denominator in silence."""
    root = _repo_with_a_live_handle_instance(tmp_path)
    blob = root / "athanor_artifacts" / "pkg" / "opaque.bin"
    blob.parent.mkdir(parents=True, exist_ok=True)
    blob.write_bytes(b"\x00\x01binary payload\x00")
    subprocess.run(["git", "add", "-A"], cwd=root, capture_output=True, check=False)
    subprocess.run(
        ["git", "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "bin"],
        cwd=root, capture_output=True, check=False,
    )
    monkeypatch.setattr(esg, "_run_receipt_verifier", lambda root: [])
    monkeypatch.chdir(root)
    esg.main(["--ref", "HEAD"])
    out = capsys.readouterr()
    combined = out.out + out.err
    assert "opaque.bin" in combined, (
        "an unscannable file was dropped silently; it must be named so the "
        "un-inspected population is visible: " + combined[-400:]
    )


def test_binary_is_decided_by_content_not_by_extension(tmp_path, monkeypatch, capsys):
    """#83's OWN SUBJECT, surviving inside #83's fix. The handle scan's extension
    allow-list was replaced, and BINARY_ASSET_EXT -- another extension allow-list
    -- carried the class forward: an ASCII file named .bin was skipped on its
    NAME while its contents were perfectly scannable. readable.bin is decidable
    by opening it."""
    root = _repo_with_a_live_handle_instance(tmp_path)
    readable = root / "athanor_artifacts" / "pkg" / "readable.bin"
    readable.parent.mkdir(parents=True, exist_ok=True)
    readable.write_text(f"synthesis ran as {_H_A}\n", encoding="utf-8")
    subprocess.run(["git", "add", "-A"], cwd=root, capture_output=True, check=False)
    subprocess.run(
        ["git", "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "bin"],
        cwd=root, capture_output=True, check=False,
    )
    monkeypatch.setattr(esg, "_run_receipt_verifier", lambda root: [])
    monkeypatch.chdir(root)
    esg.main(["--ref", "HEAD"])
    out = capsys.readouterr()
    combined = out.out + out.err
    rows = [
        r for r in combined.splitlines()
        if "readable.bin" in r and "fleet-agent handle" in r
    ]
    assert rows, (
        "an ASCII file named .bin was skipped on its EXTENSION -- its handle was "
        "never reported as a finding: " + combined[-400:]
    )


def test_a_real_binary_is_still_skipped(tmp_path, monkeypatch, capsys):
    """NEGATIVE CONTROL, so the fix is a narrowing and not just a widening."""
    root = _repo_with_a_live_handle_instance(tmp_path)
    blob = root / "athanor_artifacts" / "pkg" / "real.bin"
    blob.parent.mkdir(parents=True, exist_ok=True)
    blob.write_bytes(b"\x00\x01\x02 not text \x00")
    subprocess.run(["git", "add", "-A"], cwd=root, capture_output=True, check=False)
    subprocess.run(
        ["git", "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "bin2"],
        cwd=root, capture_output=True, check=False,
    )
    monkeypatch.setattr(esg, "_run_receipt_verifier", lambda root: [])
    monkeypatch.chdir(root)
    esg.main(["--ref", "HEAD"])
    combined = capsys.readouterr()
    assert "real.bin (binary: contains a NUL byte)" in combined.out + combined.err


def test_two_distinct_handles_on_one_line_produce_two_rows(tmp_path, monkeypatch, capsys):
    """One alternation plus one search() was NOT the same semantics as 19
    separate regexes: it collapsed a line carrying two handles to a single row.
    Four live receipt lines do exactly that, which is the 395-vs-399 delta."""
    root = _repo_with_a_live_handle_instance(tmp_path)
    both = root / "athanor_artifacts" / "pkg" / "pair.md"
    both.parent.mkdir(parents=True, exist_ok=True)
    both.write_text(f"reviewed by {_H_A} and {_H_B}\n", encoding="utf-8")
    subprocess.run(["git", "add", "-A"], cwd=root, capture_output=True, check=False)
    subprocess.run(
        ["git", "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "pair"],
        cwd=root, capture_output=True, check=False,
    )
    monkeypatch.setattr(esg, "_run_receipt_verifier", lambda root: [])
    monkeypatch.chdir(root)
    esg.main(["--ref", "HEAD"])
    combined = capsys.readouterr()
    # The SUBJECT is one row per distinct handle -- not which section renders it.
    # This used to select on the `warn:` prefix, which passed only because handle
    # findings were printed TWICE: once in the capped generic list and again in
    # the uncapped STAGED section. That duplication is what made the suppression
    # notice overstate what was hidden, so it is now de-duplicated and handle
    # findings render only as `staged-handle:` while the tier is warn.
    #
    # Selecting on either finding prefix pins the property the test is named for
    # and stops it re-breaking the next time the rendering moves.
    rows = [
        r for r in (combined.out + combined.err).splitlines()
        if "pair.md" in r and r.strip().startswith(("warn:", "staged-handle:"))
    ]
    assert len(rows) == 2, f"expected 2 rows for 2 distinct handles, got {len(rows)}: {rows}"


def test_a_handle_finding_is_rendered_exactly_once(tmp_path, monkeypatch, capsys):
    """NO DOUBLE-COUNTING. A finding printed in two sections under two labels is
    counted as hidden by the suppression notice while being visible to the
    reader -- on main that made the notice say 451 more when 367 of those were
    on screen. The row display, the suppression count and the verdict must all
    derive from ONE partition of the finding list."""
    root = _repo_with_a_live_handle_instance(tmp_path)
    monkeypatch.setattr(esg, "HANDLE_FINDING_TIER", "warn")
    monkeypatch.setattr(esg, "_run_receipt_verifier", lambda root: [])
    monkeypatch.chdir(root)
    esg.main(["--ref", "HEAD"])
    combined = "".join(capsys.readouterr())

    handle_rows = [
        r for r in combined.splitlines()
        if r.strip().startswith(("warn:", "staged-handle:"))
        and "internal fleet-agent handle" in r
    ]
    assert len(handle_rows) == 1, (
        "the handle finding was rendered more than once, so any count derived "
        f"from the row list disagrees with the finding list: {handle_rows}"
    )


def test_the_keep_set_reasons_reach_the_output(tmp_path, monkeypatch, capsys):
    """A reason that exists only in a dict is not a published reason. If the
    keep-set is invisible the denominator is silently short again -- which is
    how this gate came to report 32 over 15% of the tree."""
    root = _repo_with_a_live_handle_instance(tmp_path)
    exempt_name = "athanor/export_safety_gate.py"
    target = root / exempt_name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(f"# detector source mentioning {_H_A}\n", encoding="utf-8")
    subprocess.run(["git", "add", "-A"], cwd=root, capture_output=True, check=False)
    subprocess.run(
        ["git", "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "exempt"],
        cwd=root, capture_output=True, check=False,
    )
    monkeypatch.setattr(esg, "_run_receipt_verifier", lambda root: [])
    monkeypatch.chdir(root)
    esg.main(["--ref", "HEAD"])
    combined = capsys.readouterr()
    text = combined.out + combined.err
    assert "exempt:" in text and "detector necessarily contains" in text, (
        "the keep-set reason never reached the reader: " + text[-400:]
    )
