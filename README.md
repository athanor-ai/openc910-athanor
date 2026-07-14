# Athanor OpenC910 Evidence Surface

OpenC910 is a real 64-bit superscalar out-of-order RISC-V core. This fork is an
evidence surface for a specific question:

Can Athanor/Kairos find RTL optimizations on out-of-order CPU structures, bind
the exact candidate to area/timing/power measurements, and prove the scoped
behavior did not change?

The answer so far is yes at module scope. The table below is the customer-facing
scoreboard. A row is only a result if it has all three metric axes plus a scoped
proof and a biting negative control.

## Executive Scoreboard

| Target | OoO structure | Metric result | Correctness receipt | Replay package |
| --- | --- | --- | --- | --- |
| `ct_prio` | CIU priority arbiter | Sky130 area `158.902400 -> 60.057600`; OpenSTA max data-arrival `0.85 ns -> 0.67 ns`; OpenSTA estimated total power `1.08e-05 nW -> 2.89e-06 nW` | Visible `sel[1:0]` temporal-induction proof under reset-first; functional mutant fails the same miter; metric red-control worsens all three axes | [`athanor_artifacts/ct_prio_area_timing_power_candidate1/`](athanor_artifacts/ct_prio_area_timing_power_candidate1/) |
| `ct_rtu_pst_preg_entry` | RTU physical-register-status lifecycle | Top-with-deps Sky130 area `3510.867200 -> 3482.089600`; max data-arrival `3.23 ns -> 2.91 ns`; estimated total power `1.38e-04 nW -> 1.35e-04 nW` | Passive-debug bridge plus lifecycle-encoding relation induction under reset-first; relation mutant fails; metric red-control worsens all three axes | [`athanor_artifacts/rtu_pst_preg_entry_area_timing_power_candidate1/`](athanor_artifacts/rtu_pst_preg_entry_area_timing_power_candidate1/) |
| `ct_rtu_pst_vreg_entry` | RTU vector-register-status lifecycle | Top-with-deps Sky130 area `3148.019200 -> 3057.932800`; max data-arrival `2.82 ns -> 2.81 ns`; estimated total power `1.28e-04 nW -> 1.24e-04 nW` | Passive-debug bridge plus lifecycle-encoding relation induction under reset-first; relation mutant fails; metric red-control worsens all three axes | [`athanor_artifacts/rtu_pst_vreg_entry_area_timing_power_candidate1/`](athanor_artifacts/rtu_pst_vreg_entry_area_timing_power_candidate1/) |

Metric methodology: all three result rows are same-candidate-bound. Area,
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

## Proof Artifacts Awaiting Metric Closure

These packets are useful engineering evidence, but they are not promoted as
metric results because the multi-axis bar above is not closed.

| Target | Status | Why it is not in the scoreboard | Artifact |
| --- | --- | --- | --- |
| `ct_fifo` | Accepted module-local proof packet | Visible-output relation proof is replayable and non-vacuous, but same-candidate timing/power metric closure is still required before it becomes a result row | [`athanor_artifacts/ct_fifo/`](athanor_artifacts/ct_fifo/) |
| `ct_rtu_rob_entry` | Candidate packet | Same-state equivalence and area screening are positive, but metric promotion was rejected by OpenSTA timing regression; it remains a hard-negative / learning packet | [`athanor_artifacts/rtu_rob_entry_candidate1/`](athanor_artifacts/rtu_rob_entry_candidate1/) |
| `ct_rtu_pst_vreg` parent lift | Scout only | Replacing all 64 vreg entries improves parent area but regresses parent max data-arrival. It needs ATH-2971 compositional proof plus direct parent metric closure | [`athanor_artifacts/KAIROS_GAP_LEDGER.md`](athanor_artifacts/KAIROS_GAP_LEDGER.md) |

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
Concrete obligations now visible from this campaign:

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
| CIU FIFO | `ct_fifo` | Same-candidate area/timing/power metric packet bound to the existing relation proof |
| RTU ROB | `ct_rtu_rob_entry`, then `ct_rtu_rob` | Timing-safe candidate or hard negative; ROB commit-order invariant before whole-ROB wording |
| RTU physical status | `ct_rtu_pst_preg`, `ct_rtu_pst_vreg` | Entry-to-parent composition proof and parent-level metric closure |
| IDU issue/dependency | `ct_idu_is_lsiq_entry`, AIQ entries | Issue wakeup/select and age-order invariant candidates |
| LSU queues | `ct_lsu_sq_entry`, `ct_lsu_lq_entry`, `ct_lsu_rb` | Load/store ordering and queue-consistency proof route |

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
