# Athanor OpenC910 Results

OpenC910 is a real 64-bit superscalar out-of-order RISC-V core. This fork
publishes Athanor C910 optimization evidence. Every row binds the exact RTL
candidate to metrics, proof, negative controls, and replayable artifacts.

## Evidence Summary (ATH-3180, re-verified on certified main `0a569cdb7`)
Ten scoped evidence packets are public. Under the current product bar, two carry
bounded receipts with current-product wins (ct_prio: proof + timing + toggle;
rtu_rob_entry: area -4.79% + disclosed toggle regression). The remaining eight
are scoped historical evidence with named gaps -- three are honest proof-timeout
rejections that became the Lean rescue lane's live fixture set. No whole-core
C910, signoff, or PnR claim is made.

## Status

| Field | Status |
| --- | --- |
| Core | T-Head XuanTie OpenC910 |
| Evidence level | Ten scoped evidence packets (module-local + one subsystem-top); no whole-core C910 claim |
| Latest public bar | Current-bar bounded receipt: proof + timing + sim + toggle + negative-control + replay, all measured on certified main `0a569cdb7`. Legacy `customer_ready=true` labels corrected to `false` on all rows per the ATH-3180 audit. |
| Claim boundary | All rows are module-local except the scoped `ct_pmp_top` subsystem-top packet. No ISA, memory-consistency, speculation-recovery, or full-core performance claim is made here. |

## Evidence Status

| Target | Scope | Current-bar status | Bite tier | Package |
| --- | --- | --- | --- | --- |
| `ct_prio` | CIU priority arbiter | Bounded receipt: proof + timing (2.19->2.18ns) + toggle (-25.43%); area NEUTRAL under current product | Refuted | [`ct_prio_area_timing_power_candidate1`](athanor_artifacts/ct_prio_area_timing_power_candidate1/) |
| `ct_rtu_rob_entry` | RTU reorder-buffer entry | Bounded receipt: area -4.79% + timing WNS/TNS 0 + toggle +2.29% (disclosed regression) | Refuted | [`rtu_rob_entry_candidate1`](athanor_artifacts/rtu_rob_entry_candidate1/) |
| `ct_fifo` | FIFO buffer | Product REJECTS: proof timeout, replay fails; prover-program target (ATH-3176/3177) | Refuted | [`ct_fifo`](athanor_artifacts/ct_fifo/) |
| `ct_iu_div` | IU divider FF1 | GAP: timing REJECTED (18.2% degradation); proof inconclusive; area -1.83% | Unproven | [`ct_iu_div_ff1_tree_candidate1`](athanor_artifacts/ct_iu_div_ff1_tree_candidate1/) |
| `ct_lsu_lfb_data_entry` | LSU LFB data-entry decode | GAP: timing improved (3.66->3.49ns); proof/sim/discriminator gaps; cells +0.69% | No discriminator | [`ct_lsu_lfb_data_entry_candidate1`](athanor_artifacts/ct_lsu_lfb_data_entry_candidate1/) |
| `ct_pmp_top` | PMP subsystem top | GAP: proof PROVED (11906/0) but PPA/timing/sim/toggle unavailable (mapped-cell tool gaps) | No discriminator | [`ct_pmp_top_napot_mask_candidate1`](athanor_artifacts/ct_pmp_top_napot_mask_candidate1/) |
| `ct_pmp_acc` | PMP access permission | Parent REJECTED (degenerate mutant); helper gap-only | No discriminator | [`ct_pmp_acc_napot_mask_candidate1`](athanor_artifacts/ct_pmp_acc_napot_mask_candidate1/) |
| `plic_32to1_arb` | PLIC interrupt arbiter | Legacy REJECTED + parent/helper gaps | No discriminator | [`plic_32to1_arb_granu_balanced_candidate1`](athanor_artifacts/plic_32to1_arb_granu_balanced_candidate1/) |
| `ct_rtu_pst_preg_entry` | RTU preg-status entry | Legacy rejected; source replay timeout; mapped metric gap | No discriminator | [`rtu_pst_preg_entry_area_timing_power_candidate1`](athanor_artifacts/rtu_pst_preg_entry_area_timing_power_candidate1/) |
| `ct_rtu_pst_vreg_entry` | RTU vreg-status entry | Legacy rejected; cells REGRESS +3.63%; replay timeout | No discriminator | [`rtu_pst_vreg_entry_area_timing_power_candidate1`](athanor_artifacts/rtu_pst_vreg_entry_area_timing_power_candidate1/) |

## Proofs And Receipts

Proofs and replay receipts live inside the package linked from each row.

| Evidence | Where to look |
| --- | --- |
| Lean bridge obligations | `lean_bridge_obligation.json` where present; packets without Lean authority state that boundary explicitly |
| Temporal induction / equivalence | `output_miter_proof.pinned.log`, `relation_miter_tempinduct_seq8.pinned.log`, or `same_state_equiv_seq8.pinned.log` in the package |
| Negative controls | `proof_mutant_negative.pinned.log` or `relation_miter_mutant_negative_tempinduct_seq8.pinned.log` in the package |
| Metrics and replay | `receipt.json`, `same_candidate_binding_receipt.json`, `SHA256SUMS`, package-local `replay.sh`, and `python3 athanor/verify_public_receipts.py` |

## Evidence Ledger

Other packages ([`athanor_artifacts/README.md`](athanor_artifacts/README.md),
[`TARGET_ATLAS.md`](athanor_artifacts/TARGET_ATLAS.md),
[`KAIROS_GAP_LEDGER.md`](athanor_artifacts/KAIROS_GAP_LEDGER.md)) are classified
as scout, helper-only, hard negative, or proof artifact.

## Evidence Bar

A current-bar bounded receipt requires:

1. Exact RTL provenance and package hashes.
2. Area, timing, and power-estimate measurements bound to the same candidate.
3. A scoped equivalence or property proof on the exact subject.
4. A biting proof negative-control.
5. A metric red-control that can fail the measurement gate.
6. Non-author replay or adversarial QA.

Anything missing one of these is a scout, hard negative, helper-only package, or
proof artifact, not a current-bar bounded receipt.

## Replay

- Toolchain policy: [`athanor/toolchain_policy.json`](athanor/toolchain_policy.json)
- Public receipt verifier: `python3 athanor/verify_public_receipts.py`
- Export-safety gate: `python3 athanor/export_safety_gate.py --ref HEAD`
- Artifact packages: [`athanor_artifacts/`](athanor_artifacts/)

Each evidence package carries `receipt.json`, `SHA256SUMS`, replay logs,
proof/metric negative controls, and a package-local `replay.sh` where available.

## Upstream

The original T-Head XuanTie OpenC910 documentation and source tree are preserved
in this fork. See [`UPSTREAM_README.md`](UPSTREAM_README.md), `doc/`, and
`LICENSE` for upstream terms.
