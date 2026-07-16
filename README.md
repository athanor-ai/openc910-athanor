# Athanor OpenC910 Evidence Surface

OpenC910 is a real 64-bit superscalar out-of-order RISC-V core. This fork is an
evidence surface for a specific question:

Can Athanor/Kairos find RTL optimizations on out-of-order CPU structures, bind
the exact candidate to area/timing/power measurements, and prove the scoped
behavior did not change?

How the work divides: the AI generates the optimization proposals and
scaffolding; open, formal tools generate the verdicts (Yosys equivalence,
OpenSTA timing/power, Lean invariants); and Kairos supplies the contract,
routing, binding, ledger, and claim discipline that turn a proposal plus a tool
run into a same-candidate-bound, replayable, negative-controlled result row.
Kairos does not replace the prover or the model -- it binds an exact candidate to
its measurements and proofs and refuses to promote anything that skips the bar.
Every row below is that discipline applied.

Public read in 30 seconds:

- Promoted results: four C910 module-local packets, each with area, OpenSTA max
  data-arrival, OpenSTA estimated power, replayable proof, and negative controls
  bound to the same candidate. Three are metric wins on all reported axes; the
  LFB data-entry packet is area/timing-positive with neutral reported power.
- Candidate scouts: remaining LSU queue/control and RTU table-helper candidates
  include positive screens and hard negatives; none becomes a result row until
  independent replay closes the full bar.
- Gate discipline: proof-clean and area-positive is not enough. FIFO, ROB, RTU
  parent lifts, and LSU create-pointer scouts are rejected when the exact
  candidate netlist regresses timing.
- Next bar: a subsystem win, measured on the composed parent netlist and closed
  with a reusable relation or Lean invariant.

The table below is the promoted packet set; anything outside it is a candidate,
denominator, or product-learning artifact.

## Executive Scoreboard

| Target | OoO structure | Metric result | Correctness receipt | Replay package |
| --- | --- | --- | --- | --- |
| `ct_prio` | CIU priority arbiter | Sky130 area `158.902400 -> 60.057600`; OpenSTA max data-arrival `0.85 ns -> 0.67 ns`; OpenSTA estimated total power `1.08e-05 nW -> 2.89e-06 nW` | Visible `sel[1:0]` temporal-induction proof under reset-first; functional mutant fails the same miter; metric red-control worsens all three axes | [`athanor_artifacts/ct_prio_area_timing_power_candidate1/`](athanor_artifacts/ct_prio_area_timing_power_candidate1/) |
| `ct_rtu_pst_preg_entry` | RTU physical-register-status lifecycle | Top-with-deps Sky130 area `3510.867200 -> 3482.089600`; max data-arrival `3.23 ns -> 2.91 ns`; estimated total power `1.38e-04 nW -> 1.35e-04 nW` | Passive-debug bridge plus lifecycle-encoding relation induction under reset-first; relation mutant fails; metric red-control worsens all three axes | [`athanor_artifacts/rtu_pst_preg_entry_area_timing_power_candidate1/`](athanor_artifacts/rtu_pst_preg_entry_area_timing_power_candidate1/) |
| `ct_rtu_pst_vreg_entry` | RTU vector-register-status lifecycle | Top-with-deps Sky130 area `3148.019200 -> 3057.932800`; max data-arrival `2.82 ns -> 2.81 ns` (small delta, not a material timing claim); estimated total power `1.28e-04 nW -> 1.24e-04 nW` | Passive-debug bridge plus lifecycle-encoding relation induction under reset-first; relation mutant fails; metric red-control worsens all three axes | [`athanor_artifacts/rtu_pst_vreg_entry_area_timing_power_candidate1/`](athanor_artifacts/rtu_pst_vreg_entry_area_timing_power_candidate1/) |
| `ct_lsu_lfb_data_entry` | LSU line-fill-buffer data-entry decode | Sky130 area `19467.420800 -> 19456.160000`; OpenSTA max data-arrival `8.17 ns -> 8.14 ns`; estimated total power flat at `1.33e-03 nW` reported precision | Shipped same-state executor proves `560/560` equivalence cells; shifted-address mutant leaves `8` cells unproven; metric red-control worsens all three axes; recorded as Lean fallback until a theorem binds this candidate | [`athanor_artifacts/ct_lsu_lfb_data_entry_candidate1/`](athanor_artifacts/ct_lsu_lfb_data_entry_candidate1/) |

Metric methodology: all promoted result rows are same-candidate-bound. Area,
timing, and OpenSTA estimated power are produced from the recorded candidate and
mapped netlist under one selected flow. OpenSTA power is a liberty estimate under
fixed activity, not silicon signoff and not workload-measured power.

## What This Shows

- Athanor is working on real out-of-order CPU RTL, not a toy block.
- The public result bar is now multi-axis: area, timing, power estimate, proof,
  negative controls, replay hashes, and non-author review.
- Changed-state optimizations are allowed when the proof target changes from
  same-state bit equality to a state relation. The PST rows demonstrate that
  discipline.
- Local module results are not whole-core correctness claims. Whole C910,
  speculation recovery, memory consistency, ISA correctness, and composed
  subsystem results require separate receipts.

## Next Ambitious Target

The current campaign target is a parent/subsystem result that a CPU architect can
audit, not a bundle of unrelated local edits:

1. Reuse a proven entry relation across repeated RTU instances by symmetry.
2. Prove the parent interconnect is unchanged except for the substituted entries.
3. Require a seam mutant that breaks the composition check.
4. Measure area, OpenSTA max data-arrival, and OpenSTA estimated power on the
   composed parent netlist, not by summing local wins.
5. Attach a Lean obligation for the invariant that raw bounded search cannot
   justify.

Naive parent lifts have already produced useful hard negatives: area can improve
while parent timing regresses. Those rejects are kept in the ledger because they
teach Kairos that composition must be proof-aware and metric-aware at the parent
netlist, not just locally attractive.

## Proof Artifacts Awaiting Metric Closure

These packets are useful engineering evidence, but they are not promoted as
metric results because the multi-axis bar above is not closed.

| Target | Status | Why it is not in the scoreboard | Artifact |
| --- | --- | --- | --- |
| `ct_fifo` | Accepted module-local proof packet; metric hard negative | Visible-output relation proof is replayable and non-vacuous. Same-candidate metrics are measured: area improves and OpenSTA estimated power improves, but OpenSTA max data-arrival regresses `1.02 ns -> 1.14 ns`, so it is not a result row | [`athanor_artifacts/ct_fifo/`](athanor_artifacts/ct_fifo/) |
| `ct_rtu_rob_entry` | Candidate packet | Same-state equivalence and area screening are positive, but metric promotion was rejected by OpenSTA timing regression; it remains a hard-negative / learning packet | [`athanor_artifacts/rtu_rob_entry_candidate1/`](athanor_artifacts/rtu_rob_entry_candidate1/) |
| `ct_lsu_vb` | Candidate metric scout | Same-candidate area, OpenSTA max data-arrival, and OpenSTA estimated power all improve, with a reset-first output miter and biting proof mutant; pending non-author replay before any result-row discussion | [`athanor_artifacts/ct_lsu_vb_area_timing_power_candidate1/`](athanor_artifacts/ct_lsu_vb_area_timing_power_candidate1/) |
| `ct_lsu_rb` | Candidate metric scout | Same-candidate area, OpenSTA max data-arrival, WNS, and OpenSTA estimated power all improve under a two-clock package SDC, with same-state equivalence and a biting proof mutant; pending non-author replay before any result-row discussion | [`athanor_artifacts/ct_lsu_rb_area_timing_power_candidate1/`](athanor_artifacts/ct_lsu_rb_area_timing_power_candidate1/) |
| LSU load/store data-control rotate decoders | Low-value positive scout | `ct_lsu_ld_dc` and `ct_lsu_st_dc` one-hot rotate-selector rewrites are proof-clean and non-regressing across all measured axes, but the gains are too small to stand alone as an architect-facing result; useful only as part of a broader decode-cleanup packet | [`athanor_artifacts/TARGET_ATLAS.md`](athanor_artifacts/TARGET_ATLAS.md) |
| LSU empty-slot create-pointer rewrites | Hard-negative scouts | `ct_lsu_lq` and `ct_lsu_sq` prove clean and improve area, but OpenSTA max data-arrival regresses, so the transform family is rejected for promotion | [`athanor_artifacts/KAIROS_GAP_LEDGER.md`](athanor_artifacts/KAIROS_GAP_LEDGER.md) |
| `ct_rtu_pst_vreg` parent lift | Scout only | Replacing all 64 vreg entries improves parent area but regresses parent max data-arrival. It needs a compositional proof plus direct parent metric closure | [`athanor_artifacts/KAIROS_GAP_LEDGER.md`](athanor_artifacts/KAIROS_GAP_LEDGER.md) |
| `ct_rtu_pst_vreg` encoder family | Candidate metric scout | Replacing the shared `ct_rtu_encode_64` helper across the parent table improves selected Sky130 area `234172.089600 -> 233181.139200` and OpenSTA estimated power `9.41e-03 nW -> 9.39e-03 nW`, with max data-arrival flat at `8.30 ns`; helper equivalence and a boundary-bit mutant bite, but this remains scout-only pending independent replay and promotion review | [`athanor_artifacts/rtu_pst_vreg_encoder_family_candidate1/`](athanor_artifacts/rtu_pst_vreg_encoder_family_candidate1/) |
| `ct_rtu_pst_preg` encoder family | Hard-negative metric scout | Replacing the shared `ct_rtu_encode_96` helper improves selected Sky130 area `384860.361600 -> 383196.265600` and OpenSTA estimated power `1.51e-02 nW -> 1.50e-02 nW`, but OpenSTA max data-arrival regresses `11.31 ns -> 11.35 ns`; this is a receipt-backed reject, not a result row | [`athanor_artifacts/rtu_pst_preg_encoder_family_candidate1/`](athanor_artifacts/rtu_pst_preg_encoder_family_candidate1/) |

## Evidence Bar

A promoted row must have:

1. Exact RTL provenance and package hashes.
2. Area, timing, and power-estimate measurements bound to the same candidate and
   selected flow.
3. A scoped equivalence or property proof on the exact subject.
4. A biting proof negative-control.
5. A metric red-control that can make the measurement gate fail.
6. Non-author replay or adversarial QA.

Anything missing one of these is a candidate, proof artifact, or hard negative,
not a result.

## Lean / Formal Moat

The next proof layer is Lean-backed composition, not longer bounded searches.
The goal is to turn every manual proof intervention into a reusable Kairos
obligation template. Concrete obligations now visible from this campaign:

| Obligation | Why it matters |
| --- | --- |
| FSM encoding theorem for PST lifecycle recodes | Prove reset establishes the gold/gate relation, each transition preserves it, and the relation implies the visible outputs. This turns the current SAT relation pattern into a reusable theorem template. |
| Repeated-entry composition for RTU parent lifts | Reuse one proven entry relation across many identical instances, prove parent interconnect identity, and require a seam mutant before reporting a composed win. |
| ROB / free-list / rename invariants | Move from module-local equivalence to OoO architectural facts: commit order, no duplicate physical registers, and rename/free-list consistency. |

Lean obligations should live beside the artifact package that needs them and must
do real proof work: no-sorry, RTL-bound, closes the failed proof route, and has a
theorem-level mutant or weakened-invariant check that fails.

## Active Target Map

| Subsystem | Next target | Needed receipt |
| --- | --- | --- |
| CIU FIFO | `ct_fifo` | Metric screen closed as hard negative; next FIFO work needs a different candidate or a candidate-bound Lean refinement, not promotion of the current timing-regressing candidate |
| RTU ROB | `ct_rtu_rob_entry`, then `ct_rtu_rob` | Timing-safe candidate or hard negative; ROB commit-order invariant before whole-ROB wording |
| RTU physical status | `ct_rtu_pst_preg`, `ct_rtu_pst_vreg` | Entry-to-parent composition proof and parent-level metric closure |
| IDU issue/dependency | `ct_idu_is_lsiq_entry`, AIQ entries | Issue wakeup/select and age-order invariant candidates |
| LSU queues | `ct_lsu_vb`, `ct_lsu_sq_entry`, `ct_lsu_lq_entry`, `ct_lsu_rb` | Load/store ordering and queue-consistency proof route |

## Replay Map

- Toolchain policy: [`athanor/toolchain_policy.json`](athanor/toolchain_policy.json)
- Public receipt verifier: `python3 athanor/verify_public_receipts.py`
- Export-safety gate: `python3 athanor/export_safety_gate.py --ref HEAD`
- Artifact packages: [`athanor_artifacts/`](athanor_artifacts/)
- Target atlas and gap ledger:
  [`athanor_artifacts/TARGET_ATLAS.md`](athanor_artifacts/TARGET_ATLAS.md),
  [`athanor_artifacts/KAIROS_GAP_LEDGER.md`](athanor_artifacts/KAIROS_GAP_LEDGER.md)

Each package carries `receipt.json`, `SHA256SUMS`, replay logs, proof/metric
negative controls, and a package-local `replay.sh` that takes public tool paths
through required environment variables.

## Upstream C910

The original T-Head XuanTie OpenC910 documentation and source tree are preserved
in this fork. See [`UPSTREAM_README.md`](UPSTREAM_README.md), `doc/`, and
`LICENSE` for upstream terms.
