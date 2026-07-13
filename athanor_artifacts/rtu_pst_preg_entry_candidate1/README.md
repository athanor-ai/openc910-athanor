# C910 RTU PST Preg Entry Candidate 1

This package records a module-local optimization packet for
`ct_rtu_pst_preg_entry`, the C910 RTU physical-register-status entry.

## Claim

The candidate recodes the lifecycle FSM from a 5-bit one-hot encoding to a
4-bit onehot0 encoding where `WF_ALLOC` is represented by zero.

The supported claim is module-local visible-output equivalence under the
reset-first contract. The proof path is a passive debug bridge plus a closed
lifecycle-encoding relation proof. The same proof check rejects a broken
candidate.

## PPA

Selected Sky130 area improves in the replay flow:

- Local module: `2677.568000 -> 2648.790400`
- Top with `ct_rtu_expand_32`, `ct_rtu_expand_96`, and `gated_clk_cell` deps:
  `3510.867200 -> 3482.089600`

Generic cells are flat in the standalone stats: local `101 -> 101`, total
with deps `229 -> 229`.

## Proof Scope

The relation proof covers:

- lifecycle encoding relation between 5-bit one-hot gold state and 4-bit
  onehot0 candidate state,
- storage and retire-derived debug state used by the visible outputs,
- visible outputs `x_cur_state_dealloc`, `x_dreg[31:0]`,
  `x_rel_preg_expand[95:0]`, and `x_retired_released_wb`.

The reset-first assumption is required; the no-reset output check fails and is
kept as a boundary artifact.

## Non-Claims

This is not full same-state bit equivalence. Same-state equivalence is expected
to fail because the lifecycle state encoding intentionally changes, and the
failure log is included as a boundary artifact.

This is not a whole RTU, whole C910, BOOM, ISA, memory-consistency,
speculation-recovery, or whole-chip proof.
