# C910 RTU PST Preg Entry Relation Packet

Status: scoped historical evidence packet, NOT current-bar customer-ready.
`customer_ready=false`. The current product (certified main `0a569cdb7`) REJECTS
both legacy artifact roots (`inconsistent_package`: public_path_leak, missing
contract fields) and the fresh source emit (`replay_failed`/`replay_timeout`).
Current-main measurable evidence: generic cells 680 to 669 (-1.62%), timing
4.72ns to 4.71ns (WNS/TNS 0), sim bounded_match, toggle flat (7516 to 7516).
Proof: inconclusive (yosys timeout 300s). No discriminator (`bite=false`,
`port_signature_mismatch`). Mapped metric emit does not rescue (Sky130 SAT-model
unsupported). Old selected-flow OpenSTA estimated-power is historical evidence,
not current-product power authority. Not whole-C910, ISA, composed, or
customer-ready authority.

This package records a module-local optimization packet for
`ct_rtu_pst_preg_entry`, the C910 RTU physical-register-status entry.

## Claim

The candidate recodes the lifecycle FSM from a 5-bit one-hot encoding to a
4-bit onehot0 encoding where `WF_ALLOC` is represented by zero.

The supported claim is module-local visible-output equivalence under the
reset-first contract. The proof path is a passive debug bridge plus a closed
lifecycle-encoding relation proof. The same proof check rejects a broken
candidate, and independent QA confirmed a second storage-path mutant also fails.

## Selected Area

Selected Sky130 area improves in this legacy proof packet. Full PPA promotion is
handled by the separate `rtu_pst_preg_entry_area_timing_power_candidate1`
packet, which binds area, timing, and OpenSTA estimated power to the same
candidate:

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

## Replay

One command reproduces every claim in this package. It resolves the pinned
verdict-bearing toolchain, verifies each tool's identity, and fails loud with one
named provisioning error before any proof or metric if a tool is missing or its
bytes do not match:

```bash
python3 ../../athanor/replay_public_receipt.py rtu_pst_preg_entry_candidate1
```

BYO / custom toolchain — set the pinned tool paths and run this package's
`replay.sh` directly (it requires each var and never substitutes an ambient tool):

```bash
YOSYS_BIN=/path/to/oss-cad-suite-20260630/bin/yosys \
LIBERTY=/path/to/sky130_fd_sc_hd__tt_025C_1v80.lib \
  ./replay.sh
```

`replay.sh` writes generated logs and Tcl files under ignored `replay_out/`.
