# ATH-2950 C910 ct_prio Packet

This packet is a module-local proof/optimization receipt for the PULP C910
`ct_prio` priority arbiter at upstream head
`896e5d339480762c4f89ac8c7a7c6e11cae08379`.

## What It Shows

- Kairos produced a structural candidate for the C910 `ct_prio` block.
- The selected Sky130 area replay is `158.902400 -> 93.840000`; this legacy
  packet is not the promoted PPA result row. Use
  `ct_prio_area_timing_power_candidate1` for the same-candidate area, timing,
  and OpenSTA estimated-power result.
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

One command reproduces every claim in this package. It resolves the pinned
verdict-bearing toolchain, verifies each tool's identity, and fails loud with one
named provisioning error before any proof or metric if a tool is missing or its
bytes do not match:

```bash
python3 ../../athanor/replay_public_receipt.py ct_prio
```

BYO / custom toolchain — set the pinned tool paths and run this package's
`replay.sh` directly (it requires each var and never substitutes an ambient tool):

Run:

```bash
./replay.sh
```

The script requires:

- `YOSYS_BIN` pointing to the pinned Yosys executable.
- `LIBERTY` pointing to `sky130_fd_sc_hd__tt_025C_1v80.lib`.

No internal path defaults are embedded in this public package.
