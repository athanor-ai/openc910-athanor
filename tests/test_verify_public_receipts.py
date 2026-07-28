from __future__ import annotations

import hashlib
import importlib.util
import os
import subprocess
import json
import sys
from pathlib import Path
from typing import Any

_SCRIPT = Path(__file__).resolve().parents[1] / "athanor" / "verify_public_receipts.py"
_spec = importlib.util.spec_from_file_location("verify_public_receipts", _SCRIPT)
verify_public_receipts = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
sys.modules[_spec.name] = verify_public_receipts
_spec.loader.exec_module(verify_public_receipts)


FLOW = "yosys66_sky130_synth_dfflibmap_abc_opensta_contract_v1"


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _merge(base: dict[str, Any], patch: dict[str, Any]) -> dict[str, Any]:
    result = dict(base)
    for key, value in patch.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = _merge(result[key], value)
        else:
            result[key] = value
    return result


def _write_package(
    root: Path,
    *,
    receipt_patch: dict[str, Any] | None = None,
    binding_patch: dict[str, Any] | None = None,
    omit_same_candidate: bool = False,
) -> Path:
    verify_public_receipts.REPO_ROOT = root
    package = root / "packet"
    package.mkdir(parents=True)
    files = {
        "gold.v": "module gold; endmodule\n",
        "gate.v": "module gate; endmodule\n",
        "gate.mapped.v": "module gate_mapped; endmodule\n",
        "area_red.v": "module area_red; endmodule\n",
        "timing_red.v": "module timing_red; endmodule\n",
        "power_red.v": "module power_red; endmodule\n",
        "metric_red.log": "red control log\n",
        "replay.sh": "#!/usr/bin/env bash\ngrep -q red metric_red.log\n",
    }
    for rel, text in files.items():
        (package / rel).write_text(text, encoding="utf-8")
    gold_sha = _sha(package / "gold.v")
    gate_sha = _sha(package / "gate.v")
    mapped_sha = _sha(package / "gate.mapped.v")
    area_red_sha = _sha(package / "area_red.v")
    timing_red_sha = _sha(package / "timing_red.v")
    power_red_sha = _sha(package / "power_red.v")
    receipt: dict[str, Any] = {
        "status": "accepted_module_local_area_timing_opensta_estimated_power_packet",
        "customer_ready": True,
        "candidate": {
            "candidate_sha256": gate_sha,
            "mapped_netlist_sha256": mapped_sha,
            "selected_flow": FLOW,
        },
        "lean_fallback": {
            "reason": "Lean theorem not yet discharged for this candidate.",
            "strongest_evidence": "Yosys proof plus OpenSTA metrics.",
            "scope_boundary": "module-local packet only",
            "candidate_binding": {
                "gold_sha256": gold_sha,
                "gate_sha256": gate_sha,
            },
        },
    }
    if receipt_patch:
        receipt = _merge(receipt, receipt_patch)
    binding: dict[str, Any] = {
        "schema": "athanor.same_candidate_metric_binding.v1",
        "status": "accepted_module_local_area_timing_opensta_estimated_power_packet",
        "candidate": {
            "candidate_sha256": gate_sha,
            "mapped_netlist_sha256": mapped_sha,
            "selected_flow": FLOW,
        },
        "axes": {
            "area": {
                "candidate_sha256": gate_sha,
                "mapped_netlist_sha256": mapped_sha,
                "selected_flow": FLOW,
                "instrument": "yosys_stat_liberty",
                "instrument_version": "Yosys test",
                "metric": {"gold": 2.0, "gate": 1.0, "unit": "sky130_selected_area"},
                "negative_control": {
                    "regressed_candidate_sha256": area_red_sha,
                    "axis_reds": True,
                    "metric": {"regressed": 3.0},
                    "log_ref": "metric_red.log",
                },
            },
            "timing": {
                "candidate_sha256": gate_sha,
                "mapped_netlist_sha256": mapped_sha,
                "selected_flow": FLOW,
                "instrument": "opensta",
                "instrument_version": "OpenSTA test",
                "metric": {"gold_max_data_arrival_ns": 2.0, "gate_max_data_arrival_ns": 1.0},
                "negative_control": {
                    "regressed_candidate_sha256": timing_red_sha,
                    "axis_reds": True,
                    "metric": {"regressed_max_data_arrival_ns": 3.0},
                    "log_ref": "metric_red.log",
                },
            },
            "power": {
                "candidate_sha256": gate_sha,
                "mapped_netlist_sha256": mapped_sha,
                "selected_flow": FLOW,
                "instrument": "opensta_report_power",
                "instrument_version": "OpenSTA test",
                "metric": {
                    "gold_total_power_nw": 2.0,
                    "gate_total_power_nw": 1.0,
                    "methodology_boundary": (
                        "OpenSTA liberty estimate under fixed global activity; "
                        "not signoff power and not measured workload activity"
                    ),
                },
                "negative_control": {
                    "regressed_candidate_sha256": power_red_sha,
                    "axis_reds": True,
                    "metric": {"regressed_total_power_nw": 3.0},
                    "log_ref": "metric_red.log",
                },
            },
        },
    }
    if binding_patch:
        binding = _merge(binding, binding_patch)
    (package / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    if not omit_same_candidate:
        (package / "same_candidate_binding_receipt.json").write_text(
            json.dumps(binding, indent=2) + "\n",
            encoding="utf-8",
        )
    listed = []
    for path in sorted(package.iterdir()):
        if path.name == "SHA256SUMS":
            continue
        if path.is_file():
            listed.append(f"{_sha(path)}  {path.name}\n")
    (package / "SHA256SUMS").write_text("".join(listed), encoding="utf-8")
    return package


def test_customer_ready_metric_packet_requires_same_candidate_binding(tmp_path: Path) -> None:
    _write_package(tmp_path, omit_same_candidate=True)

    problems = verify_public_receipts.verify(tmp_path)

    assert any("missing same_candidate_binding_receipt.json" in problem for problem in problems)


def test_customer_ready_metric_packet_rejects_axis_candidate_drift(tmp_path: Path) -> None:
    _write_package(tmp_path, binding_patch={"axes": {"timing": {"candidate_sha256": "0" * 64}}})

    problems = verify_public_receipts.verify(tmp_path)

    assert any("timing.candidate_sha256" in problem for problem in problems)


def test_customer_ready_metric_mapped_netlist_must_be_sha_bound(tmp_path: Path) -> None:
    _write_package(
        tmp_path,
        receipt_patch={"candidate": {"mapped_netlist_sha256": "f" * 64}},
        binding_patch={
            "candidate": {"mapped_netlist_sha256": "f" * 64},
            "axes": {
                "area": {"mapped_netlist_sha256": "f" * 64},
                "timing": {"mapped_netlist_sha256": "f" * 64},
                "power": {"mapped_netlist_sha256": "f" * 64},
            },
        },
    )

    problems = verify_public_receipts.verify(tmp_path)

    assert any("candidate.mapped_netlist_sha256 is not bound by SHA256SUMS" in problem for problem in problems)


def test_customer_ready_metric_packet_requires_biting_metric_red_control(tmp_path: Path) -> None:
    _write_package(tmp_path, binding_patch={"axes": {"power": {"negative_control": {"axis_reds": False}}}})

    problems = verify_public_receipts.verify(tmp_path)

    assert any("power.negative_control.axis_reds must be true" in problem for problem in problems)


def test_customer_ready_metric_red_control_must_be_distinct_and_sha_bound(tmp_path: Path) -> None:
    same_as_candidate = _write_package(
        tmp_path / "same",
        binding_patch={"axes": {"area": {"negative_control": {"regressed_candidate_sha256": ""}}}},
    )
    receipt = json.loads((same_as_candidate / "receipt.json").read_text(encoding="utf-8"))
    candidate_sha = receipt["candidate"]["candidate_sha256"]
    binding = json.loads((same_as_candidate / "same_candidate_binding_receipt.json").read_text(encoding="utf-8"))
    binding["axes"]["area"]["negative_control"]["regressed_candidate_sha256"] = candidate_sha
    (same_as_candidate / "same_candidate_binding_receipt.json").write_text(
        json.dumps(binding, indent=2) + "\n",
        encoding="utf-8",
    )
    # Rehash so the only failure is the decorative red-control SHA, not manifest drift.
    lines = []
    for path in sorted(same_as_candidate.iterdir()):
        if path.name != "SHA256SUMS" and path.is_file():
            lines.append(f"{_sha(path)}  {path.name}\n")
    (same_as_candidate / "SHA256SUMS").write_text("".join(lines), encoding="utf-8")

    _write_package(
        tmp_path / "unbound",
        binding_patch={"axes": {"timing": {"negative_control": {"regressed_candidate_sha256": "f" * 64}}}},
    )

    verify_public_receipts.REPO_ROOT = tmp_path / "same"
    same_problems = verify_public_receipts.verify(tmp_path / "same")
    verify_public_receipts.REPO_ROOT = tmp_path / "unbound"
    unbound_problems = verify_public_receipts.verify(tmp_path / "unbound")

    assert any("must differ from the accepted candidate_sha256" in problem for problem in same_problems)
    assert any("regressed_candidate_sha256=" in problem and "not bound by SHA256SUMS" in problem for problem in unbound_problems)


def test_customer_ready_authority_binding_must_be_sha_bound(tmp_path: Path) -> None:
    _write_package(
        tmp_path,
        receipt_patch={
            "lean_fallback": {
                "candidate_binding": {
                    "gold_sha256": "d" * 64,
                    "gate_sha256": "e" * 64,
                }
            }
        },
    )

    problems = verify_public_receipts.verify(tmp_path)

    assert any("candidate_binding.gold_sha256" in problem for problem in problems)
    assert any("candidate_binding.gate_sha256" in problem for problem in problems)


def test_customer_ready_authority_requires_receipt_candidate_sha(tmp_path: Path) -> None:
    package = _write_package(tmp_path)
    receipt = json.loads((package / "receipt.json").read_text(encoding="utf-8"))
    receipt["candidate"] = {}
    (package / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    lines = []
    for path in sorted(package.iterdir()):
        if path.name != "SHA256SUMS" and path.is_file():
            lines.append(f"{_sha(path)}  {path.name}\n")
    (package / "SHA256SUMS").write_text("".join(lines), encoding="utf-8")

    problems = verify_public_receipts.verify(tmp_path)

    assert any("missing candidate.candidate_sha256" in problem for problem in problems)


def test_sha256sums_paths_must_be_package_local(tmp_path: Path) -> None:
    package = _write_package(tmp_path)
    outside_gold = tmp_path / "gold_outside.v"
    outside_gold.write_text("module gold_outside; endmodule\n", encoding="utf-8")
    lines = (package / "SHA256SUMS").read_text(encoding="utf-8").splitlines()
    lines.append(f"{_sha(outside_gold)}  ../gold_outside.v")
    (package / "SHA256SUMS").write_text("\n".join(lines) + "\n", encoding="utf-8")

    problems = verify_public_receipts.verify(tmp_path)

    assert any("SHA256SUMS path escapes package" in problem for problem in problems)


def _rehash(package: Path) -> None:
    lines = [
        f"{_sha(path)}  {path.name}\n"
        for path in sorted(package.iterdir())
        if path.name != "SHA256SUMS" and path.is_file()
    ]
    (package / "SHA256SUMS").write_text("".join(lines), encoding="utf-8")


def test_customer_ready_renamed_axes_fail_closed(tmp_path: Path) -> None:
    # Renamed AXES under the metrics key + an unrecognized status dodge
    # _is_metric_packet. The fail-closed type check must RED rather than pass an
    # unbound PPA surface.
    package = _write_package(tmp_path, omit_same_candidate=True)
    receipt = json.loads((package / "receipt.json").read_text(encoding="utf-8"))
    receipt["status"] = "accepted_module_local_optimization_packet"
    receipt["metrics"] = {
        "selected_area_um2": {"gold": 2.0, "gate": 1.0},
        "max_arrival_ns": {"gold": 2.0, "gate": 1.0},
        "est_total_power_nw": {"gold": 2.0, "gate": 1.0},
    }
    (package / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    _rehash(package)  # rehash so the ONLY discriminator is the fail-closed type check

    assert not verify_public_receipts._is_metric_packet(receipt)
    problems = verify_public_receipts.verify(tmp_path)

    assert any("unrecognized status" in problem for problem in problems)


def test_customer_ready_renamed_container_fail_closed(tmp_path: Path) -> None:
    # The SAME evasion one level up -- rename the CONTAINER, not just the axes.
    # PPA numbers under receipt["ppa_block"] with an unrecognized status. A
    # name-based cure keyed on the literal "metrics" key would miss this; the
    # type check catches it too.
    package = _write_package(tmp_path, omit_same_candidate=True)
    receipt = json.loads((package / "receipt.json").read_text(encoding="utf-8"))
    receipt["status"] = "accepted_module_local_optimization_packet"
    receipt["ppa_block"] = {
        "sel_footprint_um2": {"gold": 2.0, "gate": 1.0},
        "arr_ns": {"gold": 2.0, "gate": 1.0},
        "pwr_nw": {"gold": 2.0, "gate": 1.0},
    }
    (package / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    _rehash(package)

    assert not verify_public_receipts._is_metric_packet(receipt)
    problems = verify_public_receipts.verify(tmp_path)

    assert any("unrecognized status" in problem for problem in problems)


def test_recognized_proof_packet_with_generic_cells_not_false_redded(tmp_path: Path) -> None:
    # Guard against the false-red that rejected a pure gold/gate SHAPE cure: a
    # recognized proof/equivalence packet legitimately carries gold/gate generic
    # cell counts (documented non-headline context). It must NOT trip the
    # metric-binding leg despite the gold/gate numeric shape.
    package = _write_package(tmp_path, omit_same_candidate=True)
    receipt = json.loads((package / "receipt.json").read_text(encoding="utf-8"))
    receipt["status"] = "accepted_module_local_visible_output_relation_packet"
    receipt["area_receipts"] = {
        "generic_cells": {
            "gold_local_cells": 101,
            "gate_local_cells": 101,
            "gold_total_cells_with_deps": 229,
            "gate_total_cells_with_deps": 229,
        }
    }
    (package / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")

    assert not verify_public_receipts._is_metric_packet(receipt)
    # Both the metric-binding leg AND the smuggled-PPA leg must stay silent for a
    # recognized proof type carrying legitimate generic cell-count context.
    assert verify_public_receipts._verify_same_candidate_metric_binding(package, receipt) == []
    assert verify_public_receipts._verify_proof_packet_no_smuggled_ppa(package, receipt) == []


def test_proof_status_smuggled_ppa_container_reds(tmp_path: Path) -> None:
    # The recognized-proof-status PPA-smuggling hold: a recognized PROOF/
    # equivalence status can ride while PPA-shaped gold/gate values hide under a
    # renamed container with no
    # same-candidate binding -- dodging both the type check (status recognized) and
    # the metric-binding leg (not a metric packet). The smuggled-PPA leg reds any
    # gold/gate numeric pair that is not documented generic cell-count context.
    package = _write_package(tmp_path, omit_same_candidate=True)
    receipt = json.loads((package / "receipt.json").read_text(encoding="utf-8"))
    receipt["status"] = "accepted_module_local_visible_output_relation_packet"
    receipt["ppa_block"] = {
        "sel_footprint_um2": {"gold": 100.0, "gate": 80.0},
        "arr_ns": {"gold": 9.0, "gate": 8.0},
        "pwr_nw": {"gold": 1.5e-3, "gate": 1.1e-3},
    }
    (package / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    _rehash(package)

    assert not verify_public_receipts._is_metric_packet(receipt)
    problems = verify_public_receipts.verify(tmp_path)

    assert any("not documented generic cell-count context" in problem for problem in problems)


def test_valid_customer_ready_metric_packet_passes_receipt_gate(tmp_path: Path) -> None:
    _write_package(tmp_path)

    assert verify_public_receipts.verify(tmp_path) == []


def test_replay_out_generated_files_do_not_self_trip_manifest_gate(tmp_path: Path) -> None:
    package = _write_package(tmp_path)
    replay_out = package / "replay_out"
    replay_out.mkdir()
    (replay_out / "generated.tcl").write_text("read_liberty $LIBERTY\n", encoding="utf-8")
    (replay_out / "generated.mapped.v").write_text("module generated; endmodule\n", encoding="utf-8")

    assert verify_public_receipts.verify(tmp_path) == []


# --- inline hash-citation validation (ATH-3397 cross-reference closure) -------
#
# _verify_sums proves SHA256SUMS matches CONTENT; it is blind to the hashes a
# receipt quotes INLINE. These tests come in the three classes that matter:
# NECESSITY (does it catch a stale citation), NARROWNESS (does it stay silent on
# the many hash-shaped things in an RTL tree that are not content citations), and
# FAIL-CLOSED (does an unreadable receipt read as clean).


def _repin(package: Path) -> None:
    """Rewrite SHA256SUMS after editing package contents."""
    listed = []
    for path in sorted(package.iterdir()):
        if path.name == "SHA256SUMS" or not path.is_file():
            continue
        listed.append(f"{_sha(path)}  {path.name}\n")
    (package / "SHA256SUMS").write_text("".join(listed), encoding="utf-8")


def _cite(package: Path, entries: dict[str, Any]) -> None:
    receipt = json.loads((package / "receipt.json").read_text(encoding="utf-8"))
    receipt.update(entries)
    (package / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    _repin(package)


def _citation_problems(root: Path) -> list[str]:
    """Every citation finding carries the word "citation" -- a filter that silently
    drops one would hide exactly the findings these tests exist to prove."""
    return [p for p in verify_public_receipts.verify(root) if "citation" in p]


def test_stale_inline_citation_is_caught(tmp_path: Path) -> None:
    """NECESSITY: the exact miss that shipped -- SHA256SUMS right, receipt stale."""
    package = _write_package(tmp_path)
    (package / "NOTES.md").write_text("original\n", encoding="utf-8")
    _cite(package, {"files": {"NOTES.md": _sha(package / "NOTES.md")}})
    assert _citation_problems(tmp_path) == []
    # Edit the cited file and re-pin SHA256SUMS *without* touching the citation.
    (package / "NOTES.md").write_text("edited later by another PR\n", encoding="utf-8")
    _repin(package)
    problems = _citation_problems(tmp_path)
    assert any("STALE citation at files.NOTES.md" in p for p in problems), problems


def test_correct_inline_citation_passes(tmp_path: Path) -> None:
    package = _write_package(tmp_path)
    (package / "NOTES.md").write_text("stable\n", encoding="utf-8")
    _cite(package, {"files": {"NOTES.md": _sha(package / "NOTES.md")}})
    assert _citation_problems(tmp_path) == []


def test_verilog_literals_are_not_treated_as_citations(tmp_path: Path) -> None:
    """NARROWNESS: 246 tokens in this tree are 64-char Verilog literals."""
    package = _write_package(tmp_path)
    _cite(package, {"waveform_note": "b" + "0" * 64 + " sha256 sample"})
    assert _citation_problems(tmp_path) == []


def test_commit_identifiers_are_not_treated_as_content_hashes(tmp_path: Path) -> None:
    """NARROWNESS: source_commit is a git SHA -- it resolves to no file by design."""
    package = _write_package(tmp_path)
    _cite(package, {"note": "sha256 evidence; production receipt source_commit 93ce85eeb"})
    assert _citation_problems(tmp_path) == []


def test_external_input_keys_are_not_required_to_resolve(tmp_path: Path) -> None:
    """NARROWNESS: the PDK Liberty library is not shipped; its hash cannot resolve."""
    package = _write_package(tmp_path)
    _cite(package, {"liberty_sha256": "e" * 64})
    assert _citation_problems(tmp_path) == []


def test_citation_naming_a_file_outside_the_package_is_caught(tmp_path: Path) -> None:
    package = _write_package(tmp_path)
    _cite(package, {"files": {"absent_file.md": "a" * 64}})
    problems = _citation_problems(tmp_path)
    assert any("not in the package" in p for p in problems), problems


def test_abbreviated_prose_citation_is_checked(tmp_path: Path) -> None:
    """NECESSITY: citations also appear abbreviated; a full-64 rule is blind."""
    package = _write_package(tmp_path)
    _cite(package, {"summary": "gold candidate deadbeef01 was screened"})
    problems = _citation_problems(tmp_path)
    assert any("abbreviated citation deadbeef01" in p for p in problems), problems


def test_unreadable_receipt_fails_closed(tmp_path: Path) -> None:
    """FAIL-CLOSED: an unreadable receipt is not a clean receipt."""
    package = _write_package(tmp_path)
    (package / "broken.json").write_bytes(b'{"a": "\xff\xfe not utf-8"}')
    _repin(package)
    problems = verify_public_receipts.verify(tmp_path)
    assert any("could not read for citation check" in p for p in problems), problems


# --- supersession: the remedy, and the guard against it becoming a loophole ----


def _supersede(package: Path, name: str, record: dict[str, Any]) -> None:
    receipt = json.loads((package / "receipt.json").read_text(encoding="utf-8"))
    receipt.setdefault("files_supersession", {})[name] = record
    (package / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    _repin(package)


def _stale_package(tmp_path: Path) -> Path:
    """A package whose receipt cites NOTES.md at a hash the file no longer has."""
    package = _write_package(tmp_path)
    (package / "NOTES.md").write_text("original\n", encoding="utf-8")
    _cite(package, {"files": {"NOTES.md": _sha(package / "NOTES.md")}})
    (package / "NOTES.md").write_text("edited later by another PR\n", encoding="utf-8")
    _repin(package)
    return package


def test_supersession_with_matching_current_is_accepted(tmp_path: Path) -> None:
    """Without this the 13 stay red forever and the gate is unsatisfiable."""
    package = _stale_package(tmp_path)
    assert _citation_problems(tmp_path) != []
    _supersede(package, "NOTES.md", {
        "current": _sha(package / "NOTES.md"),
        "superseded_by": "#54 / 0743b51",
        "reason": "one-command replay added after this receipt was written",
    })
    assert _citation_problems(tmp_path) == []


def test_supersession_claiming_the_wrong_current_still_reds(tmp_path: Path) -> None:
    """NARROWNESS: the remedy must not become the loophole."""
    package = _stale_package(tmp_path)
    _supersede(package, "NOTES.md", {
        "current": "f" * 64,
        "superseded_by": "#54 / 0743b51",
        "reason": "whatever",
    })
    problems = _citation_problems(tmp_path)
    assert any("claims current" in p for p in problems), problems


def test_supersession_missing_provenance_fields_reds(tmp_path: Path) -> None:
    """A supersession that does not say what changed it is not a record."""
    package = _stale_package(tmp_path)
    _supersede(package, "NOTES.md", {"current": _sha(package / "NOTES.md")})
    problems = _citation_problems(tmp_path)
    assert any("missing superseded_by, reason" in p for p in problems), problems


def test_supersession_record_for_an_unchanged_citation_reds(tmp_path: Path) -> None:
    """Stale bookkeeping would rot into cover for a later real drift."""
    package = _write_package(tmp_path)
    (package / "NOTES.md").write_text("stable\n", encoding="utf-8")
    _cite(package, {"files": {"NOTES.md": _sha(package / "NOTES.md")}})
    _supersede(package, "NOTES.md", {
        "current": _sha(package / "NOTES.md"),
        "superseded_by": "#54",
        "reason": "none",
    })
    problems = _citation_problems(tmp_path)
    assert any("supersession record claims it was superseded" in p for p in problems), problems


def test_the_original_hash_remains_the_primary_value(tmp_path: Path) -> None:
    """The receipt must keep asserting what it actually claimed at the time."""
    package = _stale_package(tmp_path)
    original = json.loads((package / "receipt.json").read_text(encoding="utf-8"))["files"]["NOTES.md"]
    _supersede(package, "NOTES.md", {
        "current": _sha(package / "NOTES.md"),
        "superseded_by": "#54 / 0743b51",
        "reason": "one-command replay added after this receipt was written",
    })
    receipt = json.loads((package / "receipt.json").read_text(encoding="utf-8"))
    assert receipt["files"]["NOTES.md"] == original
    assert receipt["files_supersession"]["NOTES.md"]["current"] != original


def test_every_citation_finding_says_citation(tmp_path: Path) -> None:
    """Force the convention instead of trusting it.

    Callers (and these tests) select citation findings by the word "citation".
    A finding phrased without it is silently invisible -- which already happened
    twice while building this check. This asserts the property rather than
    re-checking each message by eye.
    """
    package = _stale_package(tmp_path)
    cases = [
        {},                                                        # no record -> STALE
        {"current": "f" * 64, "superseded_by": "#54", "reason": "x"},  # wrong current
        {"current": _sha(package / "NOTES.md")},                    # missing provenance
    ]
    for record in cases:
        receipt = json.loads((package / "receipt.json").read_text(encoding="utf-8"))
        if record:
            receipt["files_supersession"] = {"NOTES.md": record}
        else:
            receipt.pop("files_supersession", None)
        (package / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
        _repin(package)
        problems = [p for p in verify_public_receipts.verify(tmp_path) if "NOTES.md" in p]
        assert problems, f"no finding at all for record={record}"
        for problem in problems:
            assert "citation" in problem, f"finding is invisible to callers: {problem}"


def test_supersession_provenance_accepts_a_ticket_or_pr_reference(tmp_path: Path) -> None:
    """A SELF-REFERENTIAL supersession cannot name its own commit SHA -- the SHA does
    not exist until after the record is written. Ticket/PR form must therefore be
    valid provenance, or the remedy is unrecognisable to the gate that demands it.
    The rule: name the most specific identifier that EXISTS at write time.
    """
    package = _stale_package(tmp_path)
    _supersede(package, "NOTES.md", {
        "current": _sha(package / "NOTES.md"),
        "superseded_by": "ATH-3397 handle scrub (#82)",
        "reason": "internal handle scrubbed from this artifact",
    })
    assert _citation_problems(tmp_path) == []


def test_supersession_provenance_must_not_be_empty_or_blank(tmp_path: Path) -> None:
    """Accepting ticket form must not degrade into accepting anything."""
    package = _stale_package(tmp_path)
    for bad in ("", "   ", None):
        _supersede(package, "NOTES.md", {
            "current": _sha(package / "NOTES.md"),
            "superseded_by": bad,
            "reason": "internal handle scrubbed from this artifact",
        })
        problems = _citation_problems(tmp_path)
        assert any("missing superseded_by" in p for p in problems), (bad, problems)


# --- regressions for the four bypasses dexter constructed on #81 --------------
#
# The root defect was scanning TEXT LINES and calling it JSON. The fix is parsed
# traversal; these pin each construction that got through the line version.


def test_a_citation_split_across_lines_is_still_caught(tmp_path: Path) -> None:
    """BYPASS 1: valid JSON may put the key and value on separate lines."""
    package = _write_package(tmp_path)
    (package / "NOTES.md").write_text("original\n", encoding="utf-8")
    stale = _sha(package / "NOTES.md")
    (package / "NOTES.md").write_text("changed\n", encoding="utf-8")
    receipt = json.loads((package / "receipt.json").read_text(encoding="utf-8"))
    receipt["files"] = {"NOTES.md": stale}
    text = json.dumps(receipt, indent=2).replace(
        f'"NOTES.md": "{stale}"', f'"NOTES.md":\n        "{stale}"'
    )
    (package / "receipt.json").write_text(text + "\n", encoding="utf-8")
    _repin(package)
    problems = _citation_problems(tmp_path)
    assert any("STALE citation at files.NOTES.md" in p for p in problems), problems


def test_uppercase_hex_is_still_a_citation(tmp_path: Path) -> None:
    """BYPASS 1b: a lowercase-only regex let uppercase hex through."""
    package = _write_package(tmp_path)
    (package / "NOTES.md").write_text("original\n", encoding="utf-8")
    stale = _sha(package / "NOTES.md").upper()
    (package / "NOTES.md").write_text("changed\n", encoding="utf-8")
    _cite(package, {"files": {"NOTES.md": stale}})
    problems = _citation_problems(tmp_path)
    assert any("STALE citation at files.NOTES.md" in p for p in problems), problems


def test_extensions_outside_the_old_allow_list_are_inspected(tmp_path: Path) -> None:
    """BYPASS 1c: the live corpus maps .py/.h/.gitattributes -- 18 entries the
    extension allow-list never looked at, reported as clean."""
    package = _write_package(tmp_path)
    for name in ("helper.py", "cpu_cfig.h", ".gitattributes"):
        (package / name).write_text("original\n", encoding="utf-8")
    stale = {n: _sha(package / n) for n in ("helper.py", "cpu_cfig.h", ".gitattributes")}
    for name in stale:
        (package / name).write_text("changed later\n", encoding="utf-8")
    _cite(package, {"files": stale})
    problems = _citation_problems(tmp_path)
    for name in stale:
        assert any(f"STALE citation at files.{name}" in p for p in problems), (name, problems)


def test_a_supersession_in_an_unrelated_container_does_not_bless(tmp_path: Path) -> None:
    """BYPASS 2: records were indexed by bare filename, so one living anywhere in
    the document excused a citation it had nothing to do with."""
    package = _stale_package(tmp_path)
    receipt = json.loads((package / "receipt.json").read_text(encoding="utf-8"))
    receipt["unrelated_supersession"] = {"NOTES.md": {
        "current": _sha(package / "NOTES.md"),
        "superseded_by": "bogus",
        "reason": "bogus",
    }}
    (package / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    _repin(package)
    problems = _citation_problems(tmp_path)
    assert any("STALE citation at files.NOTES.md" in p for p in problems), problems


def test_a_commit_word_elsewhere_does_not_suppress_an_abbreviated_finding(tmp_path: Path) -> None:
    """BYPASS 3: the exemption read the whole line, so adding "source_commit"
    beside an unrelated token silenced it. Trigger and exemption are span-local."""
    package = _write_package(tmp_path)
    _cite(package, {"summary": "source_commit abc1234def; screened candidate deadbeef01"})
    problems = _citation_problems(tmp_path)
    assert any("abbreviated citation deadbeef01" in p for p in problems), problems


def test_a_genuine_commit_reference_is_still_exempt(tmp_path: Path) -> None:
    """NARROWNESS companion: span-local must not make commit SHAs red."""
    package = _write_package(tmp_path)
    _cite(package, {"note": "sha256 evidence; production receipt source_commit 93ce85eeb"})
    assert _citation_problems(tmp_path) == []


def _git_repo_with_history(tmp_path: Path) -> tuple[Path, str, list[tuple[str, str]]]:
    """A REAL git repo whose NOTES.md has a two-transition history.

    The lineage check reads git, so exercising it against a stub would test the
    stub. This builds the actual subject: cited hash, then two real commits.
    """
    package = _write_package(tmp_path)
    env = {"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t",
           "GIT_COMMITTER_EMAIL": "t@t", "PATH": os.environ.get("PATH", "")}
    def run(*args: str) -> str:
        return subprocess.run(args, cwd=tmp_path, capture_output=True, text=True,
                              env=env, check=True).stdout.strip()
    run("git", "init", "-q")
    notes = package / "NOTES.md"
    notes.write_text("original\n", encoding="utf-8")
    cited = _sha(notes)
    run("git", "add", "-A")
    run("git", "commit", "-qm", "original")
    hops: list[tuple[str, str]] = []
    for text in ("second\n", "third\n"):
        notes.write_text(text, encoding="utf-8")
        run("git", "add", "-A")
        run("git", "commit", "-qm", text.strip())
        hops.append((run("git", "rev-parse", "--short", "HEAD"), _sha(notes)))
    return package, cited, hops


def test_a_real_two_hop_chain_is_accepted(tmp_path: Path) -> None:
    """Every hop is checked against git, so a true lineage must pass."""
    package, cited, hops = _git_repo_with_history(tmp_path)
    _cite(package, {"files": {"NOTES.md": cited}})
    _supersede(package, "NOTES.md", {
        "current": hops[-1][1],
        "superseded_by": f"{hops[0][0]} (second)",
        "reason": "superseded more than once; every transition recorded",
        "hops": [{"commit": c, "resulting_sha256": h} for c, h in hops],
    })
    assert _citation_problems(tmp_path) == []


def test_a_compressed_chain_that_skips_a_real_transition_is_rejected(tmp_path: Path) -> None:
    """The defect the rule exists to stop: recording only the LAST transition.
    Ending at current is necessary, not sufficient."""
    package, cited, hops = _git_repo_with_history(tmp_path)
    _cite(package, {"files": {"NOTES.md": cited}})
    _supersede(package, "NOTES.md", {
        "current": hops[-1][1],
        "superseded_by": f"{hops[-1][0]} (third)",
        "reason": "compressed to the latest transition",
        "hops": [{"commit": hops[-1][0], "resulting_sha256": hops[-1][1]}],
    })
    problems = _citation_problems(tmp_path)
    assert any("a transition is missing" in p for p in problems), problems


def test_a_hop_claiming_a_commit_that_never_produced_it_is_rejected(tmp_path: Path) -> None:
    package, cited, hops = _git_repo_with_history(tmp_path)
    _cite(package, {"files": {"NOTES.md": cited}})
    _supersede(package, "NOTES.md", {
        "current": hops[-1][1],
        "superseded_by": f"{hops[0][0]} (second)",
        "reason": "wrong attribution",
        "hops": [{"commit": hops[0][0], "resulting_sha256": "a" * 64},
                 {"commit": hops[1][0], "resulting_sha256": hops[-1][1]}],
    })
    problems = _citation_problems(tmp_path)
    assert any("produced" in p for p in problems), problems


def test_superseded_by_must_name_the_first_transition_not_the_last(tmp_path: Path) -> None:
    package, cited, hops = _git_repo_with_history(tmp_path)
    _cite(package, {"files": {"NOTES.md": cited}})
    _supersede(package, "NOTES.md", {
        "current": hops[-1][1],
        "superseded_by": f"{hops[-1][0]} (third)",
        "reason": "names the last transition, not the first",
        "hops": [{"commit": c, "resulting_sha256": h} for c, h in hops],
    })
    problems = _citation_problems(tmp_path)
    assert any("does not name the FIRST transition" in p for p in problems), problems


def test_a_chain_that_cannot_be_checked_against_history_fails_closed(tmp_path: Path) -> None:
    """Absence has more than one cause: no git checkout is UNVERIFIABLE, which
    must not read the same as verified."""
    package = _stale_package(tmp_path)
    _supersede(package, "NOTES.md", {
        "current": _sha(package / "NOTES.md"),
        "superseded_by": "abc1234 (subject)",
        "reason": "x",
        "hops": [{"commit": "abc1234", "resulting_sha256": _sha(package / "NOTES.md")}],
    })
    problems = _citation_problems(tmp_path)
    assert any("no git history available" in p for p in problems), problems


# --- dexter's second round of constructions on 702f90e ------------------------
#
# Written BEFORE the fix, so each is observed failing first. The prior round's
# lesson repeated one layer up: pairing was still resolved through a global map,
# just keyed by container name instead of basename.


def _receipt(package: Path, doc: dict[str, Any]) -> None:
    (package / "receipt.json").write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
    _repin(package)


def test_a_supersession_in_a_same_named_container_elsewhere_does_not_bless(tmp_path: Path) -> None:
    """GAP 1: two objects both having a "files" key -- the last one seen won a
    global lookup, so b.files_supersession blessed a.files' stale citation."""
    package = _write_package(tmp_path)
    (package / "NOTES.md").write_text("original\n", encoding="utf-8")
    stale = _sha(package / "NOTES.md")
    (package / "NOTES.md").write_text("changed\n", encoding="utf-8")
    current = _sha(package / "NOTES.md")
    _receipt(package, {
        "a": {"files": {"NOTES.md": stale}},
        "b": {"files": {}, "files_supersession": {"NOTES.md": {
            "current": current, "superseded_by": "bogus", "reason": "bogus"}}},
    })
    problems = _citation_problems(tmp_path)
    assert any("STALE citation at a.files.NOTES.md" in p for p in problems), problems


def test_a_dotted_non_filename_key_is_not_invented_as_a_citation(tmp_path: Path) -> None:
    """GAP 2a: "contains a dot" is not a filename schema -- schema.v2 is a
    versioned semantic key, not a file, and was reported as a missing file."""
    package = _write_package(tmp_path)
    _receipt(package, {"schema.v2": "a" * 64})
    assert _citation_problems(tmp_path) == []


def test_a_malformed_hash_in_a_citation_role_fails_closed(tmp_path: Path) -> None:
    """GAP 2b: an entry in files with a non-hash value was silently ignored."""
    package = _write_package(tmp_path)
    (package / "NOTES.md").write_text("x\n", encoding="utf-8")
    _receipt(package, {"files": {"NOTES.md": "not-a-hash"}})
    problems = _citation_problems(tmp_path)
    assert any("NOTES.md" in p for p in problems), problems


def test_a_path_escaping_citation_fails_closed(tmp_path: Path) -> None:
    """GAP 2c: ../outside.md was rejected by the filename heuristic BEFORE the
    escape check ran, so the escape was never reported."""
    package = _write_package(tmp_path)
    _receipt(package, {"files": {"../outside.md": "a" * 64}})
    problems = _citation_problems(tmp_path)
    assert any("outside.md" in p for p in problems), problems


def test_abbreviated_context_is_not_a_character_distance(tmp_path: Path) -> None:
    """GAP 3: a 40-character window is a magic boundary -- gap 20 red, gap 45
    clean. Context must be a structural unit, not a distance."""
    package = _write_package(tmp_path)
    _receipt(package, {"summary": "candidate " + "x" * 45 + " deadbeef01"})
    problems = _citation_problems(tmp_path)
    assert any("abbreviated citation deadbeef01" in p for p in problems), problems


def test_a_fictional_one_hop_chain_is_rejected(tmp_path: Path) -> None:
    """GAP 4: ending at current is necessary, not sufficient -- a compressed or
    invented lineage satisfied the very rule meant to prevent compression."""
    package = _stale_package(tmp_path)
    _supersede(package, "NOTES.md", {
        "current": _sha(package / "NOTES.md"),
        "superseded_by": "not-a-real-transition",
        "reason": "compressed",
        "hops": [{"resulting_sha256": _sha(package / "NOTES.md")}],
    })
    problems = _citation_problems(tmp_path)
    assert problems, "a fictional one-hop chain was accepted"


def test_the_role_to_path_citation_shape_is_inspected(tmp_path: Path) -> None:
    """A citation role holds two shapes. {"gold": {"path": ..., "sha256": ...}}
    was inspected by NO earlier version -- its key is a role name and its value
    is not a string, so both the extension heuristic and the first role-bound
    pass walked straight past it. 23 live citations use it."""
    package = _write_package(tmp_path)
    (package / "gold.v").write_text("module gold; endmodule\n", encoding="utf-8")
    stale = _sha(package / "gold.v")
    (package / "gold.v").write_text("module gold_changed; endmodule\n", encoding="utf-8")
    _cite(package, {"files": {"gold": {"path": "gold.v", "sha256": stale}}})
    problems = _citation_problems(tmp_path)
    assert any("STALE citation at files.gold" in p for p in problems), problems
