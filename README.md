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
| Accepted evidence | First accepted out-of-order row: `ct_prio` (the OoO priority arbiter), a module-local optimization with a replayable temporal-induction equivalence proof and a biting negative control. |
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

*(Further OoO-pipeline rows land here as they clear the Evidence Bar.)*

## Latest Accepted Module-Local Discovery: `ct_prio`

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
   is the first ambitious subsystem -- `ct_rtu_rob_entry` (ROB entry state) and
   `ct_rtu_pst_preg_entry` (physical-status / free-list), composing toward the
   full `ct_rtu_rob`. Next-tier targets are the IDU issue/dependency queue
   (`ct_idu_is_lsiq_entry`) and the LSU store queue (`ct_lsu_sq_entry`). These are
   real sequential, high-port OoO blocks, not leaf toys.
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

The first accepted row links to the routed ATH-2950 packet in
`athanor-ai/athanor-kairos`. Fork-local packages will use this layout as they
land:

- Toolchain policy: `athanor/toolchain_policy.json`
- Receipt verifier: `python3 athanor/verify_public_receipts.py`
- Artifact packages: `athanor_artifacts/`
- Replay commands: each artifact package carries `COMMANDS.md` and `SHA256SUMS`.

Common receipt files per package:

- `SOURCE_DIFF.patch` or gate source: the bounded RTL change.
- `area*.json` / `reports/`: selected-flow PPA data.
- `equiv_*.ys` and `equiv_*.log`: equivalence / induction replay.
- `SHA256SUMS`: package hash binding.
- `COMMANDS.md`: replay commands.

## Upstream C910

The original T-Head XuanTie OpenC910 documentation and source tree are preserved
in this fork. See [`UPSTREAM_README.md`](UPSTREAM_README.md), the `doc/` tree, and
`LICENSE` for the manual and license terms.
