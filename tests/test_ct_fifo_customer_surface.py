from __future__ import annotations

import json
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CT_FIFO = REPO_ROOT / "athanor_artifacts" / "ct_fifo"


def test_ct_fifo_customer_surface_keeps_metric_hard_negative_separate() -> None:
    receipt = json.loads((CT_FIFO / "receipt.json").read_text(encoding="utf-8"))
    metric_screen = json.loads((CT_FIFO / "metric_screen_receipt.json").read_text(encoding="utf-8"))
    readme = (CT_FIFO / "README.md").read_text(encoding="utf-8")
    readme_flat = " ".join(readme.split())

    assert receipt["customer_ready"] is True
    assert receipt["status"] == "module_local_visible_output_equivalence_packet"
    assert metric_screen["customer_ready"] is False
    assert metric_screen["status"] == "full_metric_promotion_rejected"
    assert metric_screen["candidate"]["candidate_sha256"] == receipt["candidate"]["candidate_sha256"]

    assert "customer-ready only for the scoped `ct_fifo` visible-output equivalence" in readme_flat
    assert "`metric_screen_receipt.json` is deliberately" in readme_flat
    assert "`customer_ready=false`" in readme_flat
    assert "regresses OpenSTA max data-arrival" in readme_flat
    assert "not as a FIFO optimization win" in readme_flat
