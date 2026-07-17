from __future__ import annotations

import json

from athanor import full_top_ppa_harness as harness


def _screen(period: float = 10.0) -> dict:
    return {
        "schema": "openc910.opensta_screen.v1",
        "target": "plic_top",
        "clock": {"port": "plic_clk", "period_ns": period},
        "input_delay": {"policy": "zero_delay_except_clock", "clock": "plic_clk"},
        "output_delay": {"policy": "zero_delay_all_outputs", "clock": "plic_clk"},
        "power_activity": {"global_activity": 0.1, "duty": 0.5},
        "extraction_mode": "hierarchical_mapped_netlist",
        "reports": ["report_checks", "report_tns", "report_wns", "report_power"],
    }


def _receipt(screen_sha: str, source_sha: str = "a" * 64, overlay_sha: str = "b" * 64) -> dict:
    toolchain_sha = "c" * 64
    flow = "test_flow_v1"
    return {
        "schema": "openc910.bounded_composed_ppa_attempt.v1",
        "status": "bounded_composed_plic_top_ppa_attempt",
        "customer_ready": False,
        "target": {
            "boundary_module": "plic_top",
            "claim_scope": "bounded_plic_top_only",
            "not_whole_c910": True,
        },
        "selected_flow": flow,
        "toolchain_sha256": toolchain_sha,
        "overlay_sha256": overlay_sha,
        "source_manifest_sha256": source_sha,
        "screen": {"screen_config_sha256": screen_sha},
        "audit_hooks": {
            "content_hash_cache_key": True,
            "composed_not_whole_top": True,
            "named_partial_receipts": True,
            "screen_config_hash": True,
        },
        "legs": {
            "synth_gold": {"status": "passed"},
            "synth_gate": {"status": "passed"},
        },
    }


def test_screen_hash_changes_when_clock_definition_changes() -> None:
    base = harness.screen_config_sha256(_screen(10.0))
    changed = harness.screen_config_sha256(_screen(8.0))

    assert base != changed


def test_cache_key_binds_source_manifest_overlay_and_screen() -> None:
    kwargs = {
        "mode": "gate",
        "boundary_scope": "bounded_plic_top_only",
        "source_manifest_digest": "1" * 64,
        "screen_config_digest": harness.screen_config_sha256(_screen()),
        "selected_flow": "test_flow_v1",
        "toolchain_digest": "2" * 64,
        "overlay_sha256": "3" * 64,
    }

    base = harness.cache_key(**kwargs)

    assert harness.cache_key(**{**kwargs, "source_manifest_digest": "4" * 64}) != base
    assert harness.cache_key(**{**kwargs, "screen_config_digest": "5" * 64}) != base
    assert harness.cache_key(**{**kwargs, "overlay_sha256": "6" * 64}) != base


def test_receipt_contract_rejects_customer_ready_or_whole_c910_upgrade() -> None:
    screen = _screen()
    receipt = _receipt(harness.screen_config_sha256(screen))
    receipt["customer_ready"] = True
    receipt["target"]["whole_c910"] = True

    problems = harness.validate_receipt_contract(receipt, screen_config=screen)

    assert any("customer_ready=false" in problem for problem in problems)
    assert any("whole_c910" in problem for problem in problems)


def test_receipt_contract_requires_canonical_screen_hash() -> None:
    screen = _screen()
    receipt = _receipt("0" * 64)

    problems = harness.validate_receipt_contract(receipt, screen_config=screen)

    assert any("screen_config_sha256" in problem for problem in problems)


def test_named_partial_receipt_capout_is_valid_when_named() -> None:
    screen = _screen()
    receipt = harness.named_partial_receipt(
        leg="synth_gate",
        reason="bounded run exceeded wall-time cap",
        cap_seconds=600,
        screen_config_digest=harness.screen_config_sha256(screen),
    )

    problems = harness.validate_receipt_contract(receipt, screen_config=screen)

    assert problems == []


def test_capout_without_reason_or_cap_seconds_fails() -> None:
    screen = _screen()
    receipt = _receipt(harness.screen_config_sha256(screen))
    receipt["legs"]["synth_gate"] = {"status": "cap_out", "cap_seconds": 0}

    problems = harness.validate_receipt_contract(receipt, screen_config=screen)

    assert any("cap_seconds" in problem for problem in problems)
    assert any("reason" in problem for problem in problems)


def test_overlay_rewrite_is_exact_and_single_site() -> None:
    text = "module plic_granu_arb_gate(input a); endmodule\n"

    assert "module plic_granu_arb(" in harness.rewrite_plic_granu_overlay(text)

    try:
        harness.rewrite_plic_granu_overlay("module other(input a); endmodule\n")
    except ValueError as exc:
        assert "exactly one" in str(exc)
    else:
        raise AssertionError("bad overlay name did not fail closed")


def test_composed_area_parser_expands_submodules() -> None:
    log = """
=== top ===
        2   10.000 cells
        2        - submodules
        2        -   child
   Chip area for module '\\top': 10.000000
=== child ===
        1   7.500 cells
   Chip area for module '\\child': 7.500000
"""

    assert harness.composed_area_from_yosys_stat(log, "top") == 25.0


def test_package_validator_recomputes_cache_keys(tmp_path) -> None:
    screen = _screen()
    screen_sha = harness.screen_config_sha256(screen)
    source_manifest = {
        "schema": "openc910.plic_top_source_manifest.v1",
        "target": "plic_top",
        "sources": [{"path": "a.v", "role": "gold_and_gate", "sha256": "1" * 64}],
        "gate_overlay": {"role": "gate_only_replaces_plic_granu_arb", "sha256": "2" * 64},
    }
    source_manifest["source_manifest_sha256"] = harness.source_manifest_sha256(source_manifest)
    receipt = _receipt(screen_sha, source_manifest["source_manifest_sha256"], "2" * 64)
    cache_keys = {
        mode: harness.cache_key(
            mode=mode,
            boundary_scope="bounded_plic_top_only",
            source_manifest_digest=source_manifest["source_manifest_sha256"],
            screen_config_digest=screen_sha,
            selected_flow=receipt["selected_flow"],
            toolchain_digest=receipt["toolchain_sha256"],
            overlay_sha256="2" * 64 if mode == "gate" else None,
        )
        for mode in ("gold", "gate")
    }

    pkg = tmp_path / "pkg"
    pkg.mkdir()
    (pkg / "screen_config.json").write_text(json.dumps(screen), encoding="utf-8")
    (pkg / "source_manifest.json").write_text(json.dumps(source_manifest), encoding="utf-8")
    (pkg / "receipt.json").write_text(json.dumps(receipt), encoding="utf-8")
    (pkg / "cache_keys.json").write_text(json.dumps(cache_keys), encoding="utf-8")

    assert harness.validate_package(pkg) == []
    cache_keys["gate"] = "0" * 64
    (pkg / "cache_keys.json").write_text(json.dumps(cache_keys), encoding="utf-8")
    assert any("gate cache key" in problem for problem in harness.validate_package(pkg))
