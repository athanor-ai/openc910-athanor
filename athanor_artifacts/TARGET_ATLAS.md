# ATH-2950 C910 Target Atlas

This atlas tracks the Athanor campaign on OpenC910 out-of-order RTL. It is a
receipt index, not a whole-core proof claim.

## Current Packets

| target | subsystem | status | selected PPA | proof scope | artifact |
| --- | --- | --- | --- | --- | --- |
| `ct_prio` | CIU priority arbiter | accepted module-local packet | Sky130 `158.902400 -> 93.840000` | visible `sel[1:0]` temporal induction under reset-first, biting mutant, same-state non-claim logged | [`ct_prio/`](ct_prio/) |
| `ct_fifo` | CIU FIFO/control | accepted module-local packet | Sky130 `711.932800 -> 678.150400` | visible outputs under reset-first via bounded exact-output checks plus closed state-relation induction through passive debug wrappers; exact-output and relation mutants bite | [`ct_fifo/`](ct_fifo/) |
| `ct_rtu_rob_entry` candidate 1 | RTU reorder-buffer entry | candidate packet, independent replay complete in Kairos PR | Sky130 `2287.193600 -> 2265.923200` | same-state Yosys equivalence `94` proven / `0` unproven, decode mutant bites | [`rtu_rob_entry_candidate1/`](rtu_rob_entry_candidate1/) |

## Active RTU Campaign

| target | campaign purpose | current read |
| --- | --- | --- |
| `ct_rtu_rob_entry` | First RTU ROB-entry local win and best-single seed for candidate-lineage receipts | Completion-fold popcount rewrite has positive selected area and same-state equivalence. Next: compose with a distinct compatible RTU/PST win. |
| `ct_rtu_pst_preg_entry` | Changed-flop/state-encoding proof target for physical-register status entries | WF_ALLOC-zero lifecycle recode is area-positive in scratch (`2677.568000 -> 2648.790400`) and bounded visible-output clean through seq6, but raw same-state equivalence leaves state-relation cells unclosed and raw output induction did not close in the exploratory pass. This is the first Lean invariant ledger target. |
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
2. Authoritative selected PPA replay, not model self-proxy scoring.
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
