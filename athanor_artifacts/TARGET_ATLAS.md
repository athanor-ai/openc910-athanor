# ATH-2950 C910 Target Atlas

This atlas tracks the Athanor campaign on OpenC910 out-of-order RTL. It is a
receipt index, not a whole-core proof claim.

## Current Packets

| target | subsystem | status | selected area signal | proof scope | artifact |
| --- | --- | --- | --- | --- | --- |
| `ct_prio` | CIU priority arbiter | accepted proof packet; superseded by metric packet for result reporting | Sky130 area `158.902400 -> 93.840000` | visible `sel[1:0]` temporal induction under reset-first, biting mutant, same-state non-claim logged | [`ct_prio/`](ct_prio/) |
| `ct_prio` metric packet 1 | CIU priority arbiter | accepted module-local metric packet | Same-candidate-bound Sky130 area `158.902400 -> 60.057600`; OpenSTA max data-arrival `0.85 ns -> 0.67 ns`; OpenSTA estimated total power `1.08e-05 nW -> 2.89e-06 nW` | visible `sel[1:0]` temporal induction under reset-first; proof mutant bites; metric red-control reds all three axes; OpenSTA power is estimated under fixed activity | [`ct_prio_area_timing_power_candidate1/`](ct_prio_area_timing_power_candidate1/) |
| `ct_fifo` | CIU FIFO/control | accepted proof packet; metric closure required before result promotion | Sky130 area `711.932800 -> 678.150400` | visible outputs under reset-first via bounded exact-output checks plus closed state-relation induction through passive debug wrappers; exact-output and relation mutants bite | [`ct_fifo/`](ct_fifo/) |
| `ct_rtu_rob_entry` candidate 1 | RTU reorder-buffer entry | candidate packet; metric scout rejected promotion | Sky130 area `2287.193600 -> 2265.923200`; OpenSTA max data-arrival regressed `6.07 ns -> 6.48 ns`; estimated power effectively flat | same-state Yosys equivalence `94` proven / `0` unproven, decode mutant bites | [`rtu_rob_entry_candidate1/`](rtu_rob_entry_candidate1/) |
| `ct_rtu_pst_preg_entry` candidate 1 | RTU physical-register-status entry | accepted proof packet; superseded by metric packet for result reporting | Sky130 local area `2677.568000 -> 2648.790400`; top-with-deps area `3510.867200 -> 3482.089600` | visible outputs under reset-first via passive debug bridge plus closed lifecycle-encoding relation induction; lifecycle and storage-path relation mutants bite; same-state non-claim logged | [`rtu_pst_preg_entry_candidate1/`](rtu_pst_preg_entry_candidate1/) |
| `ct_rtu_pst_preg_entry` metric packet 1 | RTU physical-register-status entry | accepted module-local metric packet | Same-candidate-bound top-with-deps Sky130 area `3510.867200 -> 3482.089600`; OpenSTA max data-arrival `3.23 ns -> 2.91 ns`; OpenSTA estimated total power `1.38e-04 nW -> 1.35e-04 nW` | visible outputs under reset-first via passive debug bridge plus closed lifecycle-encoding relation induction; proof mutant bites; metric red-control reds all three axes; OpenSTA power is estimated under fixed activity | [`rtu_pst_preg_entry_area_timing_power_candidate1/`](rtu_pst_preg_entry_area_timing_power_candidate1/) |
| `ct_rtu_pst_vreg_entry` metric packet 1 | RTU vector-register-status entry | accepted module-local metric packet | Same-candidate-bound top-with-deps Sky130 area `3148.019200 -> 3057.932800`; OpenSTA max data-arrival `2.82 ns -> 2.81 ns` (small delta, not a material timing claim); OpenSTA estimated total power `1.28e-04 nW -> 1.24e-04 nW` | visible outputs under reset-first via passive debug bridge plus closed lifecycle-encoding relation induction; proof mutant bites; metric red-control reds all three axes; OpenSTA power is estimated under fixed activity | [`rtu_pst_vreg_entry_area_timing_power_candidate1/`](rtu_pst_vreg_entry_area_timing_power_candidate1/) |
| `ct_lsu_lfb_data_entry` candidate 1 | LSU line-fill-buffer data entry | candidate metric scout; independent replay pending | Same-candidate-bound Sky130 area `19467.420800 -> 19456.160000`; OpenSTA max data-arrival `8.17 ns -> 8.14 ns`; OpenSTA estimated total power flat at `1.33e-03 nW` | same-state Yosys equivalence `560` proven / `0` unproven; proof mutant leaves `8` address-ID cells unproven; metric red-control reds all three axes | [`ct_lsu_lfb_data_entry_candidate1/`](ct_lsu_lfb_data_entry_candidate1/) |
| `ct_lsu_vb` candidate 1 | LSU victim-buffer control | candidate metric scout; independent replay pending | Same-candidate-bound Sky130 area `13043.760000 -> 13038.755200`; OpenSTA max data-arrival `6.01 ns -> 4.99 ns`; OpenSTA estimated total power `5.95e-04 nW -> 5.93e-04 nW` | reset-first visible-output miter through seq8 proves; proof mutant fails the same miter; metric red-control reds all three axes; OpenSTA power is estimated under fixed activity | [`ct_lsu_vb_area_timing_power_candidate1/`](ct_lsu_vb_area_timing_power_candidate1/) |
| `ct_lsu_rb` candidate 1 | LSU read-buffer control | candidate metric scout; independent replay pending | Same-candidate-bound Sky130 area `105329.769600 -> 105134.582400`; OpenSTA max data-arrival `16.76 ns -> 16.59 ns`; WNS `-7.19 ns -> -6.84 ns`; OpenSTA estimated total power `5.94e-03 nW -> 5.92e-03 nW` | same-state Yosys equivalence `2088` proven / `0` unproven; proof mutant leaves `8` pointer cells unproven; metric red-control reds all three axes; OpenSTA power is estimated under fixed activity | [`ct_lsu_rb_area_timing_power_candidate1/`](ct_lsu_rb_area_timing_power_candidate1/) |

## Active RTU Campaign

| target | campaign purpose | current read |
| --- | --- | --- |
| `ct_rtu_rob_entry` | First RTU ROB-entry local win and best-single seed for candidate-lineage receipts | Completion-fold popcount rewrite has positive selected Sky130 area and same-state equivalence. Metric scout rejects full-metric promotion: OpenSTA max data-arrival regresses `6.07 ns -> 6.48 ns` and estimated power is effectively flat. |
| `ct_rtu_pst_preg_entry` | Changed-flop/state-encoding proof target for physical-register status entries | Metric packet 1 is the public result row: same-candidate area, OpenSTA max data-arrival, OpenSTA estimated power, passive debug bridge, closed lifecycle-encoding relation induction, and two biting relation mutants. |
| `ct_rtu_pst_vreg_entry` | Vector-register companion to the PST lifecycle recode | Accepted metric packet packages the same lifecycle-encoding relation proof shape with same-candidate-bound selected area, OpenSTA max data-arrival, and OpenSTA estimated-power receipts. |
| `ct_rtu_pst_vreg` | Parent-lift composition target for 64 vector-status entries | Scout only: substituting the accepted vreg-entry candidate into all 64 instances improves selected Sky130 parent area but regresses OpenSTA max data-arrival. Bounded parent-output BMC through seq6 is clean under reset-first and a parent-visible output mutant bites. Needs ATH-2971 compositional proof work and composed-netlist metric scoring before any parent packet claim. |
| `ct_rtu_pst_preg` | Free-list / physical-register-status subsystem composition | Needs decomposition over entry recode, allocation priority, no-duplicate free-list invariant, and composed no-interference receipts. |
| `ct_rtu_rob` | ROB commit-order and entry composition | Needs ROB-entry candidate lineage plus commit-order invariant. Do not claim whole ROB correctness until the invariant is written and checked. |

## Next Target Classes

| subsystem | candidate modules | why it matters |
| --- | --- | --- |
| RTU / ROB | `ct_rtu_rob_entry`, `ct_rtu_rob` | Commit-order, completion accounting, reorder-buffer entry state. |
| RTU / physical status | `ct_rtu_pst_preg_entry`, `ct_rtu_pst_preg`, `ct_rtu_pst_vreg_entry` | Rename/free-list/physical-register lifecycle invariants. |
| IDU / issue | `ct_idu_is_aiq0_entry`, `ct_idu_is_lsiq_entry`, `ct_idu_dep_reg_entry` | Issue wakeup/select and age-order invariants. |
| LSU queues | `ct_lsu_lfb_data_entry`, `ct_lsu_vb`, `ct_lsu_sq_entry`, `ct_lsu_lq_entry`, `ct_lsu_rb` | Line-fill-buffer and victim-buffer decode/control, store/load ordering, and queue consistency. |

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
