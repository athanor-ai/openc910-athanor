# Kairos Gap Ledger From The C910 Campaign

The customer campaign must feed product work back into Kairos. Manual
interventions are recorded here until they are converted into Linear tickets or
Kairos automation.

## Gaps Found So Far

| gap | observed on | product improvement |
| --- | --- | --- |
| Same-state equivalence is the wrong default for changed-flop/state-encoding candidates | `ct_fifo`; `rtu_pst_preg_entry_candidate1` lifecycle recode | Kairos should detect state encoding changes and automatically generate a relation proof skeleton, passive debug bridge, relation mutant, and Lean invariant obligation. |
| Raw induction can wander into unreachable states and fail to close | `ct_fifo` raw exact-output induction; `rtu_pst_preg_entry_candidate1` raw output induction | Kairos should promote reachable-state invariant synthesis before blind longer-depth induction. The generated obligation should name pointer/state-domain, valid-vector, and gold-to-gate relation facts. |
| Manual RTL intervention found a ROB-entry win not yet produced as an autonomous compounding campaign | `ct_rtu_rob_entry` completion-fold popcount rewrite | Kairos should emit candidate lineage for agent/manual proposals too, score them with the authoritative scorer, and feed successful transforms into strategy memory. |
| A composed win needs a falsifiable no-interference check | ATH-2950 compounding plan | Kairos should run disjoint-patch, composed-equivalence, and seam-mutant checks before reporting `best_composed`. |
| Lean obligations are currently human-written | `ct_fifo` reachable-state invariant; `ct_rtu_pst_preg_entry` lifecycle relation | Kairos should call the Lean-prove cycle or Aristotle-style subagent automatically when BMC/PDR/k-induction stalls on an invariant-shaped proof. |

## First Lean Obligation

Target: `ct_rtu_pst_preg_entry` lifecycle state recode.

Gold state is five-state one-hot:

```text
DEALLOC  = 5'b00001
WF_ALLOC = 5'b00010
ALLOC    = 5'b00100
RETIRE   = 5'b01000
RELEASE  = 5'b10000
```

Gate state is four-bit onehot0:

```text
DEALLOC  = 4'b0001
WF_ALLOC = 4'b0000
ALLOC    = 4'b0010
RETIRE   = 4'b0100
RELEASE  = 4'b1000
```

Required relation:

```text
gold DEALLOC  <-> gate 0001
gold WF_ALLOC <-> gate 0000
gold ALLOC    <-> gate 0010
gold RETIRE   <-> gate 0100
gold RELEASE  <-> gate 1000
```

Critical hazard: gate zero is a valid reachable `WF_ALLOC`; gold zero is an
invalid state that the original RTL default maps toward `DEALLOC`. Any proof
must state that gold is exactly one of the five valid states and must never
relate invalid gold zero to gate zero.

Lean should prove reset relation, transition preservation, predicate
equivalence for `DEALLOC`/`ALLOC`/`RETIRE`/`RELEASE`/`WF_ALLOC`, and visible
output equivalence under the relation. Yosys/SAT should keep the concrete RTL
bounded checks, PPA replay, and mutant controls.

`rtu_pst_preg_entry_candidate1` now carries the concrete SAT relation proof
path for this obligation: passive debug wrappers, lifecycle encoding relation,
storage/retire state relation, visible-output implication, and a relation mutant
that fails. The Lean obligation remains valuable as the reusable theorem
template Kairos should synthesize for future FSM recodes rather than relying on
manual relation derivation.
