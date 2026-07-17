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
| Parent-level lifts need compositional proof, not deeper bounded output search | `ct_rtu_pst_vreg` all-entry substitution scout; tracked as ATH-2971 | Kairos should detect repeated proven-instance substitutions, reuse the per-instance relation proof by symmetry, prove parent interconnect identity, and require a seam mutant before reporting a parent lift. Bounded parent-output BMC remains screening evidence. |
| Area/proof candidates need metric screening before promotion | `ct_rtu_rob_entry` same-state proof packet | Kairos should run the same-candidate area/timing/power screen before attempting customer metric promotion. The ROB-entry area win is proof-clean but OpenSTA max data-arrival regresses. |
| Candidate triage must preserve near-misses until the full proof/replay bar closes, and flat axes must stay neutral in customer wording | `ct_lsu_lfb_data_entry` address-ID shift-decode package | Kairos should package proof-clean, same-candidate-bound near-misses as candidate scouts while independent replay or shipped-executor proof is missing. If later evidence closes the full scoped packet with no metric regression, a flat axis may be reported as neutral evidence, but it must not be described as a power win. The LSU data-entry candidate now has shipped-executor proof, a biting mutant, same-candidate metrics, metric red-controls, and non-author replay; its customer-ready scope is therefore area/timing-positive with OpenSTA estimated power flat at reported precision. |
| Transform memory must distinguish request-vector lowbit selection from empty-slot create-pointer selection | `ct_lsu_rb` replay-confirmed mixed scout; `ct_lsu_lq` and `ct_lsu_sq` empty-slot hard negatives | Kairos should not generalize a lowbit rewrite across all priority-looking logic. First-asserted request vectors can improve area and the worst violating timing path, but `ct_lsu_rb` still exposed a reported met cross-clock path regression under independent replay, so it stays out of the result table. Empty-slot queue create pointers improved area but regressed OpenSTA max data-arrival on both LQ and SQ. Candidate memory needs transform-family context and per-path metric review, not just syntax. |
| Encoder rewrites need family-specific memory, not syntax-only reuse | `ct_iu_div` FF1 tree promoted module-local packet; IDU issue create-slot helper hard negative | Binary leading-one replacement is strong on the IU division positive FF1 encoders under the selected flow, but a first-empty create-slot bit-isolate helper regressed selected area. Kairos should bank encoder transforms with signal semantics, direction, and selected-flow context before spending parent-screen effort. |
| Micro-gains need materiality and batching before customer-surface promotion | `ct_lsu_ld_dc` and `ct_lsu_st_dc` rotate-selector scouts | Kairos should group small decode cleanups and score the combined packet instead of promoting tiny standalone rows. LD/ST rotate-selector rewrites are proof-clean and non-regressing across all measured axes, but the individual gains are too small to matter to a CPU architect. |
| Proof tooling needs an automatic miter fallback when direct equivalence setup fails | `ct_lsu_dcache_arb`; `ct_lsu_ld_dc`; `ct_lsu_st_dc` | Pinned Yosys `equiv_make` can hit an internal assertion on some flattened modules. For local decode rewrites, `miter -equiv -make_assert` plus SAT closed the LD/ST proof route. Kairos should retry that route automatically and report a tool-error distinctly from a proof counterexample. |
| Shared helper wins need parent-screen batching, full PPA closure, and parent proof routing before promotion | `ct_rtu_compare_iid` wrapped-IID comparator scout | Kairos should recognize small reusable helpers, run a helper proof plus multiple parent screens, package same-candidate parent area/timing/power plus a metric red-control, then hold promotion until supported parent proof routes close. The compare-IID helper is proof-clean and parent-integrated full-PPA positive across two LSU parents; the `ct_lsu_pfu_sdb_cmp` parent same-state proof now closes with a biting equality-boundary mutant, but `ct_lsu_spec_fail_predict` remains proof-route-pending, so the package stays scout-scoped rather than customer-ready. |
| Encoder-family transforms are width-sensitive | `ct_rtu_encode_32`; `ct_rtu_encode_64`; `ct_rtu_encode_96` | Kairos should batch related helpers by family but still score each width and each parent table independently. The 64-bit vreg table package now has a parent-table proof route with a biting mutant plus area/power signal and flat timing; the 96-bit preg table package also proves at parent-table scope, but is still rejected by timing regression; and the 32-bit helper is a hard negative. A syntax pattern is not authority without per-table proof, PPA, and red controls. |
| Forwarding-mux one-hot rewrites are lane-family specific | `ct_idu_rf_fwd_preg`; `ct_idu_rf_fwd_vreg` | Kairos should require a one-hot forwarding contract and per-helper metric screen before proposing masked-OR rewrites across IDU register forwarding. The PREG helper has area/timing/power signal under the contract, while the VREG sibling regresses area and estimated power despite timing improvement. |

## Parent-Lift Composition Gap

Target: `ct_rtu_pst_vreg` with all 64 `ct_rtu_pst_vreg_entry` instances
substituted to the accepted vreg-entry candidate.

Screening evidence:

- Selected Sky130 parent area moved from `234172.089600` to `228406.560000`.
- Parent visible-output BMC through seq6 is clean under reset-first.
- Dropping reset-first fails, so the reset contract changes the result.
- A parent-visible output mutant that corrupts `rtu_idu_alloc_xreg0_vld` fails
  the parent-output miter, so the parent miter is discriminating.

Hard negative:

- Under the same OpenSTA contract used for the module metric packets, parent
  max data-arrival moves from `8.30 ns` to `8.40 ns`. The parent lift is not a
  customer metric packet as-is.

Automation gap:

- The accepted entry relation proof covers one entry instance, and the parent
  substitution repeats that instance 64 times.
- The parent proof Kairos should synthesize is a compositional certificate:
  per-instance relation reuse by symmetry, parent interconnect identity, and a
  seam mutant that bites the interconnect check.
- The composed netlist must be scored directly. A local entry win cannot be
  summed into a parent win because fan-out, interconnect, and shared arbitration
  can move the parent critical path.
- The inherited entry-level relation mutant is not expected to bite a bounded
  parent-output miter quickly; parent-visible outputs are a corollary of the
  composed relation, not the proof authority.

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
bounded checks, selected-flow area replay, and mutant controls. Timing/power
remain separate axes and are not claimed by the current packets.

`rtu_pst_preg_entry_candidate1` now carries the concrete SAT relation proof
path for this obligation: passive debug wrappers, lifecycle encoding relation,
storage/retire state relation, visible-output implication, and a relation mutant
that fails. The Lean obligation remains valuable as the reusable theorem
template Kairos should synthesize for future FSM recodes rather than relying on
manual relation derivation.
