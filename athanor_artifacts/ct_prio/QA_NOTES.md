# ATH-2950 ct_prio: Independent Adversarial QA Notes (quan)

Independent non-author QA pass (receipt.json `next_independent_check.assignee = quan`).
Every command below was re-run on pinned Yosys `0.66+181`
(`yosys`); logs were regenerated, not read.

## End-to-end replay from a fresh clone

`./replay.sh` was run from a clean clone of this branch (not the author's working
copy): `PASS: ct_prio output proof, mutant bite, Sky130 area replay, and same-state
boundary reproduced` (exit 0). This QA pass covers the legacy proof packet; the
promoted PPA result row lives in `ct_prio_area_timing_power_candidate1`.
The customer reproduction path works from a bare checkout.

## Three adversarial probes beyond re-running

1. **Baseline provenance anchored to upstream, cross-source consistent.**
   `ct_prio_gold.v` (sha256 `2cd7d0e3...`) is byte-identical to *two independent
   upstream sources*: `T-head-Semi/openc910` master (fetched independently via
   github raw) **and** `pulp-platform/pulp-c910` @ `896e5d33` (the clone in
   `receipt.json`). The optimized baseline is genuine, unmodified upstream C910
   RTL, not an author-authored or doctored copy.

2. **The reset-first assumption is required by the miter (not a hidden/vacuous caveat).**
   Re-running the output-miter proof with the `-set-at 1 rst_b 0 -set-at 2 rst_b 1`
   constraint *removed* yields `rc=1, model found for base case: FAIL!`. So the
   documented reset-first boundary genuinely has teeth: `miter -equiv` gives the two
   copies free independent initial register state, which legitimately diverges
   `sel` at t=0. The proof holds *because of*, and only under, the disclosed
   assumption.

3. **The 41% Sky130 selected-area reduction is honest logic simplification, not
   dropped dead-logic.** Diffing `ct_prio_gold.v` vs
   `ct_prio_gate_candidate.v`: the
   `sel[i]` grant expression is byte-identical. The entire win is rewriting the
   priority-matrix *update*: gold's `(clr_bus==(1<<i)) ? ~clr_bus : prio&~clr_bus`
   mux plus the `clr_bus` wire to the candidate's per-bit `if(sel[i]&&i!=j) set;
   else if(sel[j]) clear`. Real cells removed, output-equivalent under proof.

## Note on generic cell count

Generic cell count is flow-sensitive (pinned 17 to 19, ambient 21, kairos-selected 22).
The Sky130 selected-area delta (`158.902400 -> 93.840000`) is the
tool-independent headline for this legacy proof packet; generic cell count is
not. The promoted full-PPA result row lives in
`ct_prio_area_timing_power_candidate1`.

## Boundary (unchanged, supported)

Module-local visible `sel[1:0]` equivalence under the reset-first assumption, with a
biting mutant and selected Sky130 area replay. This QA note is not the promoted
full-PPA result row; use `ct_prio_area_timing_power_candidate1` for that claim.
NOT full internal-state equivalence
(2 internal `prio` bits unproven, see `ct_prio_same_state_equiv_fail.pinned.log`),
NOT whole-core C910 / BOOM, NOT ISA / memory-consistency / speculation, NOT
whole-chip customer authority.
