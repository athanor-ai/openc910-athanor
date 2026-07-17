#!/usr/bin/env python3
"""Bounded composed PPA receipt helpers for OpenC910 top-level screens.

This module supports ATH-3121's first plic_top harness: it validates the
receipt structure, binds the screen configuration by hash, and computes cache
keys from source bytes instead of from filenames or module names alone. The
first packet is intentionally a partial composed receipt, not a whole-C910 or
customer-ready promotion.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]

PLIC_TOP_SOURCE_PATHS = (
    "C910_RTL_FACTORY/gen_rtl/cpu/rtl/cpu_cfig.h",
    "C910_RTL_FACTORY/gen_rtl/clk/rtl/gated_clk_cell.v",
    "C910_RTL_FACTORY/gen_rtl/common/rtl/sync_level2level.v",
    "C910_RTL_FACTORY/gen_rtl/common/rtl/sync_level2pulse.v",
    "C910_RTL_FACTORY/gen_rtl/plic/rtl/csky_apb_1tox_matrix.v",
    "C910_RTL_FACTORY/gen_rtl/plic/rtl/plic_32to1_arb.v",
    "C910_RTL_FACTORY/gen_rtl/plic/rtl/plic_arb_ctrl.v",
    "C910_RTL_FACTORY/gen_rtl/plic/rtl/plic_ctrl.v",
    "C910_RTL_FACTORY/gen_rtl/plic/rtl/plic_granu2_arb.v",
    "C910_RTL_FACTORY/gen_rtl/plic/rtl/plic_granu_arb.v",
    "C910_RTL_FACTORY/gen_rtl/plic/rtl/plic_hart_arb.v",
    "C910_RTL_FACTORY/gen_rtl/plic/rtl/plic_hreg_busif.v",
    "C910_RTL_FACTORY/gen_rtl/plic/rtl/plic_int_kid.v",
    "C910_RTL_FACTORY/gen_rtl/plic/rtl/plic_kid_busif.v",
    "C910_RTL_FACTORY/gen_rtl/plic/rtl/plic_top.v",
)

OVERLAY_MODULE_FROM = "module plic_granu_arb_gate("
OVERLAY_MODULE_TO = "module plic_granu_arb("


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_text(text: str) -> str:
    return sha256_bytes(text.encode("utf-8"))


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def canonical_json_bytes(data: Any) -> bytes:
    return (json.dumps(data, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def canonical_json_sha256(data: Any) -> str:
    return sha256_bytes(canonical_json_bytes(data))


def screen_config_sha256(screen_config: dict[str, Any]) -> str:
    """Hash the path-independent STA screen definition.

    The hash deliberately excludes the caller's absolute Liberty/netlist paths.
    Those are replay inputs, not the screen identity. The hash covers the clock,
    delay policy, extraction mode, activity policy, and requested reports.
    """
    return canonical_json_sha256(screen_config)


def rewrite_plic_granu_overlay(candidate_text: str) -> str:
    if candidate_text.count(OVERLAY_MODULE_FROM) != 1:
        raise ValueError("expected exactly one plic_granu_arb_gate module declaration")
    return candidate_text.replace(OVERLAY_MODULE_FROM, OVERLAY_MODULE_TO, 1)


def source_manifest(repo_root: Path, *, overlay_sha256: str | None = None) -> dict[str, Any]:
    sources: list[dict[str, str]] = []
    for rel in PLIC_TOP_SOURCE_PATHS:
        path = repo_root / rel
        if not path.is_file():
            raise FileNotFoundError(rel)
        role = "gold_and_gate"
        if rel.endswith("/plic_granu_arb.v"):
            role = "gold_only_replaced_by_candidate_overlay_for_gate"
        sources.append({"path": rel, "role": role, "sha256": sha256_file(path)})
    manifest: dict[str, Any] = {
        "schema": "openc910.plic_top_source_manifest.v1",
        "target": "plic_top",
        "sources": sources,
    }
    if overlay_sha256:
        manifest["gate_overlay"] = {
            "role": "gate_only_replaces_plic_granu_arb",
            "sha256": overlay_sha256,
        }
    manifest["source_manifest_sha256"] = source_manifest_sha256(manifest)
    return manifest


def source_manifest_sha256(manifest: dict[str, Any]) -> str:
    comparable = {
        "schema": manifest.get("schema"),
        "target": manifest.get("target"),
        "sources": sorted(manifest.get("sources", []), key=lambda item: item["path"]),
        "gate_overlay": manifest.get("gate_overlay"),
    }
    return canonical_json_sha256(comparable)


def cache_key(
    *,
    mode: str,
    boundary_scope: str,
    source_manifest_digest: str,
    screen_config_digest: str,
    selected_flow: str,
    toolchain_digest: str,
    overlay_sha256: str | None,
) -> str:
    return canonical_json_sha256(
        {
            "mode": mode,
            "boundary_scope": boundary_scope,
            "source_manifest_sha256": source_manifest_digest,
            "screen_config_sha256": screen_config_digest,
            "selected_flow": selected_flow,
            "toolchain_sha256": toolchain_digest,
            "overlay_sha256": overlay_sha256,
        }
    )


def named_partial_receipt(
    *,
    leg: str,
    reason: str,
    cap_seconds: int,
    screen_config_digest: str,
) -> dict[str, Any]:
    return {
        "schema": "openc910.bounded_composed_ppa_attempt.v1",
        "status": "partial_receipt",
        "customer_ready": False,
        "target": {
            "boundary_module": "plic_top",
            "claim_scope": "bounded_plic_top_only",
            "not_whole_c910": True,
        },
        "screen": {"screen_config_sha256": screen_config_digest},
        "audit_hooks": {
            "content_hash_cache_key": True,
            "composed_not_whole_top": True,
            "named_partial_receipts": True,
            "screen_config_hash": True,
        },
        "legs": {
            leg: {
                "status": "cap_out",
                "reason": reason,
                "cap_seconds": cap_seconds,
            }
        },
    }


def _iter_strings(obj: Any) -> list[str]:
    out: list[str] = []
    if isinstance(obj, str):
        out.append(obj)
    elif isinstance(obj, dict):
        for value in obj.values():
            out.extend(_iter_strings(value))
    elif isinstance(obj, list):
        for value in obj:
            out.extend(_iter_strings(value))
    return out


def validate_receipt_contract(
    receipt: dict[str, Any],
    *,
    screen_config: dict[str, Any],
    source_manifest_data: dict[str, Any] | None = None,
    cache_keys_data: dict[str, Any] | None = None,
) -> list[str]:
    problems: list[str] = []
    rel = "receipt.json"
    if receipt.get("customer_ready") is not False:
        problems.append(f"{rel}: bounded plic_top receipt must keep customer_ready=false")
    status = str(receipt.get("status", ""))
    if "promoted" in status or "customer_ready" in status:
        problems.append(f"{rel}: status must not present a promotion/customer-ready claim")

    target = receipt.get("target")
    if not isinstance(target, dict):
        problems.append(f"{rel}: missing target object")
        return problems
    if target.get("boundary_module") != "plic_top":
        problems.append(f"{rel}: boundary_module must be plic_top")
    if target.get("claim_scope") != "bounded_plic_top_only":
        problems.append(f"{rel}: claim_scope must be bounded_plic_top_only")
    if target.get("whole_c910") is True:
        problems.append(f"{rel}: plic_top receipt must not claim whole_c910")
    if target.get("customer_claim") is True:
        problems.append(f"{rel}: plic_top receipt must not set customer_claim=true")

    expected_screen_sha = screen_config_sha256(screen_config)
    screen = receipt.get("screen")
    if not isinstance(screen, dict):
        problems.append(f"{rel}: missing screen object")
    else:
        got = screen.get("screen_config_sha256")
        if got != expected_screen_sha:
            problems.append(
                f"{rel}: screen_config_sha256={got!r} does not match canonical screen {expected_screen_sha}"
            )

    source_digest = receipt.get("source_manifest_sha256")
    if source_manifest_data is not None:
        expected_source_digest = source_manifest_sha256(source_manifest_data)
        if source_manifest_data.get("source_manifest_sha256") != expected_source_digest:
            problems.append("source_manifest.json: source_manifest_sha256 is stale")
        if source_digest != expected_source_digest:
            problems.append(
                f"{rel}: source_manifest_sha256={source_digest!r} does not match source manifest"
            )

    audit_hooks = receipt.get("audit_hooks")
    if not isinstance(audit_hooks, dict):
        problems.append(f"{rel}: missing audit_hooks object")
    else:
        for key in (
            "content_hash_cache_key",
            "composed_not_whole_top",
            "named_partial_receipts",
            "screen_config_hash",
        ):
            if audit_hooks.get(key) is not True:
                problems.append(f"{rel}: audit_hooks.{key} must be true")

    legs = receipt.get("legs", {})
    if isinstance(legs, dict):
        for name, leg in legs.items():
            if not isinstance(leg, dict):
                continue
            if leg.get("status") == "cap_out":
                if not isinstance(leg.get("cap_seconds"), int) or leg["cap_seconds"] <= 0:
                    problems.append(f"{rel}: legs.{name}.cap_out missing positive cap_seconds")
                if not leg.get("reason"):
                    problems.append(f"{rel}: legs.{name}.cap_out missing reason")

    if cache_keys_data is not None:
        selected_flow = str(receipt.get("selected_flow", ""))
        toolchain_digest = str(receipt.get("toolchain_sha256", ""))
        overlay_sha = receipt.get("overlay_sha256")
        if not isinstance(overlay_sha, str):
            overlay_sha = None
        expected_source_digest = str(source_digest)
        expected_screen_digest = expected_screen_sha
        for mode in ("gold", "gate"):
            expected = cache_key(
                mode=mode,
                boundary_scope="bounded_plic_top_only",
                source_manifest_digest=expected_source_digest,
                screen_config_digest=expected_screen_digest,
                selected_flow=selected_flow,
                toolchain_digest=toolchain_digest,
                overlay_sha256=overlay_sha if mode == "gate" else None,
            )
            got = cache_keys_data.get(mode)
            if got != expected:
                problems.append(f"cache_keys.json: {mode} cache key is stale")

    for text in _iter_strings(receipt):
        if "timing slightly improves" in text.lower():
            problems.append(
                f"{rel}: screen mismatch is unresolved; use conservative timing-flat wording"
            )
    return problems


@dataclass(frozen=True)
class ModuleStat:
    local_area: float
    submodules: tuple[tuple[int, str], ...]


def parse_yosys_stat_modules(log_text: str) -> dict[str, ModuleStat]:
    modules: dict[str, dict[str, Any]] = {}
    current: str | None = None
    in_submodules = False
    for line in log_text.splitlines():
        heading = re.match(r"^=== (.+) ===$", line)
        if heading:
            current = heading.group(1).removeprefix("\\")
            modules[current] = {"local_area": 0.0, "submodules": []}
            in_submodules = False
            continue
        if current is None:
            continue
        area = re.search(r"Chip area for module '([^']+)':\s+([0-9.Ee+-]+)", line)
        if area:
            name = area.group(1).removeprefix("\\")
            key = name if name in modules else current
            modules[key]["local_area"] = float(area.group(2))
            in_submodules = False
            continue
        if re.match(r"^\s+\d+\s+-\s+submodules\s*$", line):
            in_submodules = True
            continue
        if in_submodules:
            sub = re.match(r"^\s+(\d+)\s+-\s{3}(.+)$", line)
            if sub:
                modules[current]["submodules"].append((int(sub.group(1)), sub.group(2).removeprefix("\\")))
                continue
            if line.strip():
                in_submodules = False
    return {
        name: ModuleStat(
            local_area=float(data["local_area"]),
            submodules=tuple(data["submodules"]),
        )
        for name, data in modules.items()
    }


def composed_area_from_yosys_stat(log_text: str, top: str) -> float:
    modules = parse_yosys_stat_modules(log_text)
    seen: dict[str, float] = {}

    def total(name: str) -> float:
        key = name.removeprefix("\\")
        if key in seen:
            return seen[key]
        if key not in modules:
            # Some OpenC910 wrappers such as gated_clk_cell remain source-level
            # pass-through modules after stat. They contribute no mapped cell
            # area at this level unless Yosys emitted a module section for them.
            return 0.0
        stat = modules[key]
        value = stat.local_area
        for count, sub in stat.submodules:
            value += count * total(sub)
        seen[key] = value
        return value

    return total(top)


def _load_json(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return data


def validate_package(package: Path) -> list[str]:
    receipt = _load_json(package / "receipt.json")
    screen = _load_json(package / "screen_config.json")
    source = _load_json(package / "source_manifest.json")
    cache_keys = _load_json(package / "cache_keys.json")
    return validate_receipt_contract(
        receipt,
        screen_config=screen,
        source_manifest_data=source,
        cache_keys_data=cache_keys,
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate bounded full-top PPA receipts")
    parser.add_argument("--check-package", type=Path, help="artifact package to validate")
    parser.add_argument("--print-plic-top-manifest", action="store_true")
    args = parser.parse_args(argv)

    if args.print_plic_top_manifest:
        print(json.dumps(source_manifest(REPO_ROOT), indent=2, sort_keys=True))
        return 0

    if args.check_package:
        problems = validate_package(args.check_package)
        if problems:
            for problem in problems:
                print(f"FAIL: {problem}", file=sys.stderr)
            return 1
        print("PASS: plic_top bounded receipt contract is current")
        return 0

    parser.error("choose --check-package or --print-plic-top-manifest")


if __name__ == "__main__":
    sys.exit(main())
