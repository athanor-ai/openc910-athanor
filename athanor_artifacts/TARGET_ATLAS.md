# ATH-2950 C910 Target Atlas

This atlas tracks the Athanor campaign on OpenC910 out-of-order RTL. It is a
receipt index, not a whole-core proof claim.

## Current Packets

| target | subsystem | status | selected area signal | proof scope | artifact |
| --- | --- | --- | --- | --- | --- |
| `ct_prio` | CIU priority arbiter | accepted module-local packet | Sky130 area `158.902400 -> 93.840000`; timing/power not claimed | visible `sel[1:0]` temporal induction under reset-first, biting mutant, same-state non-claim logged | [`ct_prio/`](ct_prio/) |
| `ct_fifo` | CIU FIFO/control | accepted module-local packet | Sky130 area `711.932800 -> 678.150400`; timing/power not claimed | visible outputs under reset-first via bounded exact-output checks plus closed state-relation induction through passive debug wrappers; exact-output and relation mutants bite | [`ct_fifo/`](ct_fifo/) |
| `ct_rtu_rob_entry` candidate 1 | RTU reorder-buffer entry | candidate packet, independent replay complete in Kairos PR | Sky130 area `2287.193600 -> 2265.923200`; timing/power not claimed | same-state Yosys equivalence `94` proven / `0` unproven, decode mutant bites | [`rtu_rob_entry_candidate1/`](rtu_rob_entry_candidate1/) |
| `ct_rtu_pst_preg_entry` candidate 1 | RTU physical-register-status entry | accepted module-local relation packet | Sky130 local area `2677.568000 -> 2648.790400`; top-with-deps area `3510.867200 -> 3482.089600`; timing/power not claimed | visible outputs under reset-first via passive debug bridge plus closed lifecycle-encoding relation induction; lifecycle and storage-path relation mutants bite; same-state non-claim logged | [`rtu_pst_preg_entry_candidate1/`](rtu_pst_preg_entry_candidate1/) |
| `ct_rtu_pst_vreg_entry` metric candidate 1 | RTU vector-register-status entry | candidate pending independent replay | Same-candidate-bound top-with-deps Sky130 area `3148.019200 -> 3057.932800`; OpenSTA max data-arrival `2.82 ns -> 2.81 ns`; OpenSTA estimated total power `1.28e-04 nW -> 1.24e-04 nW` | visible outputs under reset-first via passive debug bridge plus closed lifecycle-encoding relation induction; proof mutant bites; metric red-control reds all three axes | [`rtu_pst_vreg_entry_area_timing_power_candidate1/`](rtu_pst_vreg_entry_area_timing_power_candidate1/) |

## Active RTU Campaign

| target | campaign purpose | current read |
| --- | --- | --- |
| `ct_rtu_rob_entry` | First RTU ROB-entry local win and best-single seed for candidate-lineage receipts | Completion-fold popcount rewrite has positive selected Sky130 area and same-state equivalence; timing/power not claimed. Next: compose with a distinct compatible RTU/PST win. |
| `ct_rtu_pst_preg_entry` | Changed-flop/state-encoding proof target for physical-register status entries | Candidate 1 packages the WF_ALLOC-zero lifecycle recode with a passive debug bridge, closed lifecycle-encoding relation induction, two biting relation mutants, reset-boundary log, same-state non-claim, and selected Sky130 area improvement; timing/power not claimed. Accepted only as a module-local visible-output relation packet. |
| `ct_rtu_pst_vreg_entry` | Vector-register companion to the PST lifecycle recode | Metric candidate packages the same lifecycle-encoding relation proof shape with same-candidate-bound selected area, OpenSTA max data-arrival, and OpenSTA estimated-power receipts; pending independent replay and not customer-ready. |
| `ct_rtu_pst_preg` | Free-list / physical-register-status subsystem composition | Needs decomposition over entry recode, allocation priority, no-duplicate free-list invariant, and composed no-interference receipts. |
| `ct_rtu_rob` | ROB commit-order and entry composition | Needs ROB-entry candidate lineage plus commit-order invariant. Do not claim whole ROB correctness until the invariant is written and checked. |

## Next Target Classes

| subsystem | candidate modules | why it matters |
| --- | --- | --- |
| RTU / ROB | `ct_rtu_rob_entry`, `ct_rtu_rob` | Commit-order, completion accounting, reorder-buffer entry state. |
| RTU / physical status | `ct_rtu_pst_preg_entry`, `ct_rtu_pst_preg`, `ct_rtu_pst_vreg_entry` | Rename/free-list/physical-register lifecycle invariants. |
| IDU / issue | `ct_idu_is_aiq0_entry`, `ct_idu_is_lsiq_entry`, `ct_idu_dep_reg_entry` | Issue wakeup/select and age-order invariants. |
| LSU queues | `ct_lsu_sq_entry`, `ct_lsu_lq_entry`, `ct_lsu_rb` | Store/load ordering and queue consistency. |

## Evidence Bar

Every promoted packet must include:

1. Exact source provenance and artifact hashes.
2. Authoritative selected-flow measurement replay, not model self-proxy scoring.
3. A scoped equivalence or property proof with the reset and environment
   contract stated.
4. A biting negative control.
5. Independent non-author replay or QA notes.

Composed wins additionally require candidate-lineage receipts: best single,
best composed, authoritative scorer result for each candidate, and a
no-interference check showing disjoint patches, composed equivalence, and a
seam mutant that bites.

## Non-Claims

This atlas does not claim whole C910 proof, BOOM proof, ISA correctness, memory
consistency, speculation correctness, or whole-chip authority. Whole-core OoO
proof remains a staged decomposition and Lean-backed invariant program.
