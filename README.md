# Athanor C910: Verifiable Out-of-Order RISC-V Optimization

C910 is a real out-of-order, superscalar 64-bit RISC-V CPU core. This fork uses
it as a public testbed for the hard case the simpler cores do not exercise:
finding small RTL changes that improve power, performance, or area on an
**out-of-order** pipeline without weakening correctness.

The goal is not to collect anecdotes. Every result here is tied to receipts:
selected-toolchain PPA, equivalence or formal proof on the exact subject,
activity checks, hash replay, and non-author review. If a row has not cleared
that bar, it is called a candidate, not a win. Scope is stated on every row --
module-local proofs are labelled as such and are never presented as a whole-core
claim.

## Current Status

| Topic | State |
| --- | --- |
| Accepted evidence | Two accepted out-of-order module-local rows: `ct_prio` (the OoO priority arbiter) and `ct_fifo` (the DEPTH=2 CIU FIFO), each with a replayable equivalence proof on its stated scope and a biting negative control. Two RTU candidates (`ct_rtu_rob_entry`, `ct_rtu_pst_preg_entry`) have landed and await independent cold replay before any promotion wording (see Gaps). |
| Tooling claim | Athanor/Kairos is used here as the optimization, measurement, filtering, replay, and evidence pipeline. Where the tool stalls on OoO-specific structure, the structural insight is human-guided; the tool supplies the receipts. This README does **not** claim autonomous discovery. |
| Honest scope | Module-level optimization + equivalence proof on OoO-core RTL: demonstrated. Whole-core out-of-order *sequential* equivalence: research frontier, a staged Lean-backed program (see Gaps), not claimed here. |
| Main gaps | More module-local rows across the OoO pipeline (decode / issue / rename / ALU / LSU / BIU-CIU); Lean closure of an architectural OoO invariant against the RTL; verified compound optimization across modules. |

## Evidence Bar

Promotion requires evidence for the exact claim:

1. Bounded RTL diff.
2. Selected-flow PPA on the recorded toolchain. Area-only rows must say that
   they are area-only; timing is required when timing is part of the claim.
3. Equivalence or hosted formal proof on the exact subject, with its scope stated (e.g. visible-output miter vs full internal-state; any reset or environment assumption named).
4. A non-vacuity control: a deliberately broken candidate must fail the same proof.
5. Replayable hashes plus non-author cold review.

Module-local movement is useful evidence, but a whole-core claim requires a
whole-core receipt. Local wins are not added together without an integrated run;
a "compound" result must carry its own end-to-end receipt at each step.

## Results Snapshot

| Transform | Status | PPA signal | Correctness / activity | Receipt |
| --- | --- | --- | --- | --- |
| `ct_prio` / priority-arbiter simplification | Accepted module-local artifact | Generic cells `22 -> 20`; Sky130 area `158.9 -> 93.8` (~41% on this block, verified real logic simplification, not dropped dead-logic); timing is not claimed for this row | Yosys SAT temporal (k-)induction closes on `sel[1:0]` at depth 4 (unbounded, visible-output miter under a documented reset-first assumption); negative control: a broken candidate fails the same proof; internal-state boundary log-backed | [routed packet](https://github.com/athanor-ai/athanor-kairos/tree/f905d40047076aad2d2214ffceff1a9625d7644d/artifacts/ath2950_c910_ct_prio) |
| `ct_fifo` / DEPTH=2 pointer-representation specialization | Accepted module-local artifact | Sky130 area `711.9 -> 678.2` (~4.7% on this block); area-only, timing is not claimed for this row | Exact visible-output equivalence (`fifo_pop_data[5:0]`, `fifo_pop_data_vld`, `fifo_full`, `fifo_empty`) proved **bounded through seq12** under a reset-first contract; an *unbounded* temporal-induction closure (k=1) holds over state-exposed copies that assert those outputs plus the create/pop-pointer, valid-vector and stored-data relation, gated by a scripted self-tested passivity check that the exact->debug bridge is instrumentation-only; negative control (inverted `fifo_full`) fails both the bounded miter and the relation miter | [`athanor_artifacts/ct_fifo/`](athanor_artifacts/ct_fifo/) |
| `ct_rtu_pst_preg_entry` / lifecycle-state recode | Candidate packet pending independent replay; `customer_ready=false` | Sky130 local area `2677.6 -> 2648.8`; top-with-deps area `3510.9 -> 3482.1`; generic cells flat. Area-only, timing is not claimed for this row | Exact visible-output BMC passes through seq12 under reset-first; no-reset check fails and records the reset boundary. Positive unbounded path is a passive-debug bridge plus lifecycle-encoding relation induction; relation mutant fails. Same-state bit equivalence partial (`304` proven / `6` unproven) and raw exact-output induction non-closure are retained as boundary artifacts. | [`athanor_artifacts/rtu_pst_preg_entry_candidate1/`](athanor_artifacts/rtu_pst_preg_entry_candidate1/) |

*(Further OoO-pipeline rows land here as they clear the Evidence Bar.)*

## Accepted Module-Local Rows

### `ct_prio` -- priority arbiter

`ct_prio` is C910's request-priority arbiter on the out-of-order issue path -- it
selects which pending request wins each cycle. The selected-toolchain row records
a Sky130 area reduction `158.9 -> 93.8`; timing is not claimed for this row.
Correctness is carried by a Yosys SAT temporal-induction miter that proves the
optimized block produces identical `sel[1:0]` output to the original (an
*unbounded* proof via k-induction at depth 4), under a reset-first assumption
whose removal was tested to break the proof, so it is not hiding a vacuous
result. A non-vacuity bite where a broken candidate fails the same miter
confirms the proof discriminates.

Scope: this is visible-output equivalence of the arbiter's `sel` output -- the
block's functional contract -- not full internal-state equivalence, and not a
whole-core proof. It is a module-local row on a real out-of-order core.

### `ct_fifo` -- DEPTH=2 CIU FIFO

`ct_fifo` is a small synchronous FIFO in C910's CIU. The optimization
specializes the default `DEPTH=2` create/pop pointer representation from a
one-hot create pointer plus two-bit pop pointer to one-bit indices, preserving
the visible FIFO outputs. The selected-toolchain row records a Sky130 area
reduction `711.9 -> 678.2`; this is an area-only row and timing is not claimed.

Correctness has two layers, and the boundary between them is stated on purpose.
The exact gold/gate output miter proves the visible outputs
(`fifo_pop_data[5:0]`, `fifo_pop_data_vld`, `fifo_full`, `fifo_empty`) identical
under a reset-first contract, but only as a *bounded* proof through seq12 -- the
raw exact-output temporal induction did **not** close, and that non-closure is
recorded, not hidden. The *unbounded* claim is carried by a temporal-induction
proof (closing at k=1) over state-exposed copies that additionally assert the
create-pointer, pop-pointer, valid-vector and stored-data relation; a scripted,
self-tested passivity check confirms the exact->debug bridge only adds
instrumentation and changes no logic. Two negative controls bite: an inverted
`fifo_full` candidate fails both the bounded exact miter and the stronger
relation miter, so neither proof is vacuous.

Scope: module-local visible-output equivalence only. No FIFO semantic
correctness, no full internal-state equivalence on the exact modules, and no
whole-core claim. The exact gold/gate proof is bounded visible-output
equivalence through seq12. The state-exposed relation is the unbounded authority;
the exact-to-debug bridge is mechanical and biting, not a second independent
formal miter.

## What This Shows

- Kairos ingests real out-of-order RISC-V RTL directly and produces module-level
  optimization + formal-equivalence receipts on it, in minutes.
- The useful signal is multi-axis: area, timing, proof, non-vacuity control, and
  replay all matter.
- Whole-core OoO sequential equivalence is not a push-button proof today; the
  honest path is compositional (module proofs + BMC bounds + Lean closure of the
  hard sequential invariants), and it is presented as a program, not a claim.
- The combination on offer: human-expert-level RTL insight where the tool stalls,
  plus tool-generated formal receipts, plus honest scope on every row.

## Gaps And Next Work

1. Module-local rows across the OoO pipeline, RTU-first: the retire/reorder unit
   is the first ambitious subsystem. A first **candidate** packet has landed for
   `ct_rtu_rob_entry` (ROB entry state) at
   [`athanor_artifacts/rtu_rob_entry_candidate1/`](athanor_artifacts/rtu_rob_entry_candidate1/):
   a completion-fold popcount recode with a module-local same-state equivalence
   proof (`equiv_induct -seq 8`, all 94 mapped cells proven, biting negative
   control). It is labelled a candidate, not an accepted row -- it awaits an
   independent cold-review reproduce before promotion, and its measured win is
   generic-cell count (`129 -> 94`), *not* Sky130 area (`2287.2 -> 2265.9`,
   ~0.9%), so it is not presented as an area result. Still open in this
   subsystem: `ct_rtu_pst_preg_entry` (physical-status / free-list). Its first
   candidate packet is now fork-local at
   [`athanor_artifacts/rtu_pst_preg_entry_candidate1/`](athanor_artifacts/rtu_pst_preg_entry_candidate1/).
   It carries a lifecycle onehot0 state-recode, selected Sky130 area improvement,
   bounded exact-output evidence, a passive-debug bridge, closed
   lifecycle-encoding relation induction, and a relation mutant that fails. It
   remains a candidate until independent non-author replay reproduces the packet.
   Composing these RTU entry wins toward the full `ct_rtu_rob` still needs
   candidate-lineage and no-interference receipts. Next-tier targets are the IDU issue/dependency
   queue (`ct_idu_is_lsiq_entry`) and the LSU store queue (`ct_lsu_sq_entry`).
   These are real sequential, high-port OoO blocks, not leaf toys.
2. Close a real OoO architectural invariant in Lean against the C910 RTL --
   rename bijection or free-list no-duplicate on the RTU state -- as a
   deductively discharged obligation, not a doc promise.
3. Verified compound optimization: compose module wins with a formal proof at
   each step, carrying an integrated receipt (not summed local wins).
4. Speculation-aware formal verification (branch mispredict / recovery) is a
   future capability, flagged honestly as not-yet.
5. Machine-enforced proof-subject binding so a green formal row cannot prove the
   wrong RTL.

## Audit Map

The `ct_prio` row links to the routed ATH-2950 packet in
`athanor-ai/athanor-kairos`; `ct_fifo`, `ct_rtu_rob_entry`, and
`ct_rtu_pst_preg_entry` candidate packets are fork-local packages under
`athanor_artifacts/`, each replayable in place. The
receipt verifier checks every fork-local package's hash binding and manifest:

- Toolchain policy: `athanor/toolchain_policy.json`
- Receipt verifier: `python3 athanor/verify_public_receipts.py`
- Artifact packages: `athanor_artifacts/`
- Replay: each fork-local package carries a `replay.sh` that takes the toolchain
  as required env vars (`YOSYS_BIN`, `LIBERTY`), plus a `SHA256SUMS` hash binding.

Common files per fork-local package:

- `*_gold.v` and `*_gate_candidate.v`: the bounded RTL change (original vs optimized).
- `*_gate_mutant.v`: the deliberately-broken candidate the non-vacuity control must reject.
- `*_miter.sv`: the equivalence / induction miter(s).
- `*.pinned.log`: pinned selected-flow PPA and proof-replay logs.
- `receipt.json`: the row's claim -- subject, proof method, scope, assumptions, PPA deltas, control result, and known boundaries.
- `README.md`: the per-packet scope and non-claims.
- `SHA256SUMS`: package hash binding.
- `replay.sh`: the replay entrypoint.

## Upstream C910

The original T-Head XuanTie OpenC910 documentation and source tree are preserved
in this fork. See [`UPSTREAM_README.md`](UPSTREAM_README.md), the `doc/` tree, and
`LICENSE` for the manual and license terms.
