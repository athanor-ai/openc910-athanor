# Athanor OpenC910 Results

OpenC910 is a real 64-bit superscalar out-of-order RISC-V core. This fork
publishes Athanor C910 optimization results. Every promoted row binds the exact
RTL candidate to metrics, proof, negative controls, and replayable artifacts.

## Status

| Field | Status |
| --- | --- |
| Core | T-Head XuanTie OpenC910 |
| Evidence level | Five promoted module-local packets; no whole-core C910 claim |
| Latest public bar | Same-candidate area, OpenSTA max data-arrival, OpenSTA estimated power, proof, metric red-control, and non-author replay |
| Claim boundary | Module-local results only. No ISA, memory-consistency, speculation-recovery, or full-core performance claim is made here. |

## Promoted Evidence

| Target | Scope | Metric result | Correctness receipt | Package |
| --- | --- | --- | --- | --- |
| `ct_prio` | CIU priority arbiter | Area `158.902400 -> 60.057600`; max data-arrival `0.85 ns -> 0.67 ns`; estimated power `1.08e-05 -> 2.89e-06 nW` | Visible `sel[1:0]` temporal-induction proof; functional mutant fails | [`ct_prio_area_timing_power_candidate1`](athanor_artifacts/ct_prio_area_timing_power_candidate1/) |
| `ct_rtu_pst_preg_entry` | RTU physical-register-status entry | Area `3510.867200 -> 3482.089600`; max data-arrival `3.23 ns -> 2.91 ns`; estimated power `1.38e-04 -> 1.35e-04 nW` | Passive-debug bridge plus lifecycle relation induction; relation mutant fails | [`rtu_pst_preg_entry_area_timing_power_candidate1`](athanor_artifacts/rtu_pst_preg_entry_area_timing_power_candidate1/) |
| `ct_rtu_pst_vreg_entry` | RTU vector-register-status entry | Area `3148.019200 -> 3057.932800`; max data-arrival `2.82 ns -> 2.81 ns`; estimated power `1.28e-04 -> 1.24e-04 nW` | Passive-debug bridge plus lifecycle relation induction; relation mutant fails | [`rtu_pst_vreg_entry_area_timing_power_candidate1`](athanor_artifacts/rtu_pst_vreg_entry_area_timing_power_candidate1/) |
| `ct_lsu_lfb_data_entry` | LSU line-fill-buffer data-entry decode | Area `19467.420800 -> 19456.160000`; max data-arrival `8.17 ns -> 8.14 ns`; reported power flat at `1.33e-03 nW` precision | Same-state executor proves `560/560`; shifted-address mutant leaves `8` cells unproven; no C910 Lean-authority theorem is claimed for this packet | [`ct_lsu_lfb_data_entry_candidate1`](athanor_artifacts/ct_lsu_lfb_data_entry_candidate1/) |
| `ct_iu_div` | IU divider FF1 normalization | Area `158090.371200 -> 156941.769600`; max data-arrival `39.67 ns -> 34.03 ns`; estimated power `7.06e-03 -> 7.03e-03 nW` | Same-state proof closes `1966/1966`; FF1 proof mutant leaves `2` cells unproven; non-author replay reproduced mapped netlists bit-exact; no C910 Lean-authority theorem is claimed for this packet | [`ct_iu_div_ff1_tree_candidate1`](athanor_artifacts/ct_iu_div_ff1_tree_candidate1/) |

## Proofs And Receipts

Proofs and replay receipts live inside the package linked from each row.

| Evidence | Where to look |
| --- | --- |
| Lean bridge obligations | `lean_bridge_obligation.json` where present; packets without Lean authority state that boundary explicitly |
| Temporal induction / equivalence | `output_miter_proof.pinned.log`, `relation_miter_tempinduct_seq8.pinned.log`, or `same_state_equiv_seq8.pinned.log` in the package |
| Negative controls | `proof_mutant_negative.pinned.log` or `relation_miter_mutant_negative_tempinduct_seq8.pinned.log` in the package |
| Metrics and replay | `receipt.json`, `same_candidate_binding_receipt.json`, `SHA256SUMS`, package-local `replay.sh`, and `python3 athanor/verify_public_receipts.py` |

## Evidence Ledger

Non-promoted packages are kept as an audit ledger, not as an open task list. They are
classified in the artifact README, target atlas, or gap ledger as scout,
helper-only, hard negative, or proof artifact:

- [`athanor_artifacts/README.md`](athanor_artifacts/README.md)
- [`athanor_artifacts/TARGET_ATLAS.md`](athanor_artifacts/TARGET_ATLAS.md)
- [`athanor_artifacts/KAIROS_GAP_LEDGER.md`](athanor_artifacts/KAIROS_GAP_LEDGER.md)

Examples: `ct_fifo` is a real proof artifact but a timing hard negative for
promotion; parent RTU encoder-family packets are proof/PPA scouts until parent
metric and authority review close; helper-local VFALU/IDU rows are not promoted
without parent integration.

## Evidence Bar

A promoted row requires:

1. Exact RTL provenance and package hashes.
2. Area, timing, and power-estimate measurements bound to the same candidate.
3. A scoped equivalence or property proof on the exact subject.
4. A biting proof negative-control.
5. A metric red-control that can fail the measurement gate.
6. Non-author replay or adversarial QA.

Anything missing one of these is a scout, hard negative, helper-only package, or
proof artifact, not a promoted result.

## Replay

- Toolchain policy: [`athanor/toolchain_policy.json`](athanor/toolchain_policy.json)
- Public receipt verifier: `python3 athanor/verify_public_receipts.py`
- Export-safety gate: `python3 athanor/export_safety_gate.py --ref HEAD`
- Artifact packages: [`athanor_artifacts/`](athanor_artifacts/)

Each promoted package carries `receipt.json`, `SHA256SUMS`, replay logs,
proof/metric negative controls, and a package-local `replay.sh` where available.

## Upstream

The original T-Head XuanTie OpenC910 documentation and source tree are preserved
in this fork. See [`UPSTREAM_README.md`](UPSTREAM_README.md), `doc/`, and
`LICENSE` for upstream terms.
