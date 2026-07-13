# ATH-2950 C910 RTU ROB Entry Candidate 1

This artifact records a module-local optimization receipt for the PULP C910
`ct_rtu_rob_entry` reorder-buffer entry at upstream head
`896e5d339480762c4f89ac8c7a7c6e11cae08379`.

## Result

| item | status |
| --- | --- |
| Module | C910 `ct_rtu_rob_entry` |
| Subsystem | RTU reorder buffer entry |
| Transform | Replace enumerated completion-fold decodes with an exact popcount decode over `x_cmplt_vld[0]`, `[1]`, `[5]`, and `[6]` |
| Generic cells | `129` to `94` in standalone pinned `proc; opt; memory; opt` stats |
| Selected Sky130 area | `2287.193600` to `2265.923200` |
| Equivalence check | Same-state Yosys equivalence closes with `94` proven equiv cells and `0` unproven |
| Mutant control | A deliberate `cmplt_2_fold_inst` decode fault leaves `4` unproven equiv cells and fails under the same check |
| Current packet status | Module-local candidate receipt, independent replay requested |

## Scope

The candidate is a local rewrite of the completion-count preparation logic. It
does not change the `ct_rtu_rob_entry` flop set, state encoding, port list, or
submodule dependencies. The positive equivalence receipt is same-state module
equivalence under the checked RTL model, with `gated_clk_cell` from the C910 tree
included as a transparent dependency.

## Non-Claims

This artifact is not a whole `ct_rtu_rob` proof, not a whole C910 proof, not an
ISA-correctness proof, not memory-consistency or speculation correctness, not a
composed optimization result, and not whole-chip authority. It is the first RTU
candidate receipt for the broader ATH-2950 OoO-core campaign.

## Replay

Run:

```bash
YOSYS_BIN=/path/to/yosys LIBERTY=/path/to/sky130_fd_sc_hd__tt_025C_1v80.lib ./replay.sh
```

The script requires `YOSYS_BIN` and `LIBERTY`; no internal path defaults are
embedded in this public package.
