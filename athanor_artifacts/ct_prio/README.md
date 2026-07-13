# ATH-2950 C910 ct_prio Packet

This packet is a module-local proof/optimization receipt for the PULP C910
`ct_prio` priority arbiter at upstream head
`896e5d339480762c4f89ac8c7a7c6e11cae08379`.

## What It Shows

- Kairos produced a structural candidate for the C910 `ct_prio` block.
- The selected Sky130 area replay is `158.902400 -> 93.840000`.
- The visible-output miter proves `sel[1:0]` equivalence under the reset-first
  assumption `rst_b=0` at time 1 and `rst_b=1` at time 2.
- The seeded mutant fails under the same miter, so the proof check rejects a
  broken candidate.
- The same-state internal equivalence check is intentionally included as a
  boundary artifact: 4 equiv cells prove, 2 internal priority-state bits remain
  unproven.

## What It Does Not Show

This is not a full internal-state equivalence proof, not a whole C910 proof, not
an ISA-correctness proof, not a memory-consistency or speculation proof, and not
whole-chip customer authority.

## Replay

Run:

```bash
./replay.sh
```

The script requires:

- `YOSYS_BIN` pointing to the pinned Yosys executable.
- `LIBERTY` pointing to `sky130_fd_sc_hd__tt_025C_1v80.lib`.

No internal path defaults are embedded in this public package.
