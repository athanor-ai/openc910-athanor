# ATH-2950 C910 ct_fifo Packet

This artifact records a module-local proof/optimization packet for the PULP C910 `ct_fifo` module.

## Result

| item | status |
| --- | --- |
| Module | C910 `ct_fifo`, default `DEPTH=2`, `WIDTH=6`, `PTR_W=1` |
| Transform | Replace one-hot create pointer and two-bit pop pointer state with one-bit indices |
| Selected Sky130 area | `711.932800` to `678.150400` |
| Exact visible-output check | Bounded proof through seq12 under reset-first |
| Mutant control | `fifo_full` inversion fails under the same bounded miter |
| Relation proof | Temporal induction closes at k=1 over state-exposed copies |
| Relation mutant | `fifo_full` inversion fails under the relation miter |
| Exact-to-debug bridge | Scripted passivity check proves debug wrappers are passive instrumentation only, with a biting selftest |
| Current packet status | Module-local visible-output equivalence packet |

## Scope

The checked visible outputs are `fifo_pop_data[5:0]`, `fifo_pop_data_vld`, `fifo_full`, and `fifo_empty`. The reset contract is `rst_b=0` at step 1 and `rst_b=1` at step 2.

The closed induction proof is `ct_fifo_relation_miter.sv`, which uses state-exposed copies of the gold and gate RTL to assert the visible outputs plus the create pointer, pop pointer, valid-vector, and stored-data relation. `bridge_passivity_check.py` normalizes those debug wrappers back to the exact RTL by stripping only debug ports, declarations, and assignments; its selftest rejects a non-passive logic edit. The exact gold/gate output miter has bounded proofs at seq6 and seq12; the raw exact-output temporal induction did not close.

## Non-Claims

This artifact does not claim FIFO semantic correctness, full internal-state equivalence, whole C910 proof, BOOM proof, ISA correctness, memory consistency, speculation correctness, or whole-chip authority. The raw exact-output temporal-induction log remains a non-closure boundary, not the positive authority path.

## Replay

Run:

```bash
YOSYS_BIN=/path/to/yosys LIBERTY=/path/to/sky130_fd_sc_hd__tt_025C_1v80.lib ./replay.sh
```

The script reproduces the selected Sky130 area, the seq12 exact-output bounded proof, the biting mutants, the state-exposed relation induction, and the passive-debug bridge check.
