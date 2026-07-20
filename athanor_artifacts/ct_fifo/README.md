# ATH-2950 C910 ct_fifo Packet

This artifact records a module-local proof/optimization packet for the PULP C910 `ct_fifo` module.

## Customer Read

Status: scoped proof/evidence packet, NOT current-bar customer-ready or
packageable. The current product (certified main `0a569cdb7`) REJECTS this row:
proof is inconclusive (yosys timeout at 300s, closure=false), and the independent
replay times out (`replay_failed`/`replay_timeout`). What survived: negative-control
bite refuted at seq 8 over fifo_pop_data/vld/full/empty; sim bounded_match;
OpenSTA timing measured with WNS/TNS 0 (0.80ns to 2.73ns); generic cells 54 to 52
(-3.70%); toggle 1836 to 1947 (+6.05%, disclosed regression). Treat this as
measured local evidence with an open proof gap -- the induction/replay closure is
the live target for the prover program (ATH-3176/3177). `receipt.json`
`customer_ready=true` reflects the old scoped-proof bar; the current product
refuses this row at the package level. `metric_screen_receipt.json` remains
`customer_ready=false` (timing regression).

## Result

| item | status |
| --- | --- |
| Module | C910 `ct_fifo`, default `DEPTH=2`, `WIDTH=6`, `PTR_W=1` |
| Transform | Replace one-hot create pointer and two-bit pop pointer state with one-bit indices |
| Selected Sky130 area | `711.932800` to `678.150400`; lower area |
| OpenSTA max data-arrival | `1.02 ns` to `1.14 ns`; timing regression, rejects full metric promotion |
| OpenSTA estimated total power | `4.45e-05 nW` to `4.19e-05 nW`; lower estimated power under fixed activity |
| Exact visible-output check | Bounded proof through seq12 under reset-first |
| Mutant control | `fifo_full` inversion fails under the same bounded miter |
| Relation proof | Temporal induction closes at k=1 over state-exposed copies |
| Relation mutant | `fifo_full` inversion fails under the relation miter |
| Exact-to-debug bridge | Scripted passivity check proves debug wrappers are passive instrumentation only, with a biting selftest |
| Current packet status | Module-local visible-output equivalence packet |

## Scope

The checked visible outputs are `fifo_pop_data[5:0]`, `fifo_pop_data_vld`, `fifo_full`, and `fifo_empty`. The reset contract is `rst_b=0` at step 1 and `rst_b=1` at step 2.

The closed induction proof is `ct_fifo_relation_miter.sv`, which uses state-exposed copies of the gold and gate RTL to assert the visible outputs plus the create pointer, pop pointer, valid-vector, and stored-data relation. `bridge_passivity_check.py` normalizes those debug wrappers back to the exact RTL by stripping only debug ports, declarations, and assignments; its selftest rejects a non-passive logic edit. The exact gold/gate output miter has bounded proofs at seq6 and seq12; the raw exact-output temporal induction did not close.

## Metric Screen

The same-candidate metric screen is measured and bound to mapped Sky130
netlists, but it is a hard negative for full area/timing/OpenSTA-estimated-power
promotion. Area and OpenSTA estimated power improve, while OpenSTA max
data-arrival regresses from `1.02 ns` to `1.14 ns` under the package SDC.
The non-customer-ready metric evidence is recorded in
`metric_screen_receipt.json`.

The power row is an OpenSTA liberty estimate with
`set_power_activity -global -activity 0.1 -duty 0.5`. It is not signoff power
and not measured workload activity.

`ct_fifo_metric_negative.v` is a metric-only red-control netlist. It is not a
proof candidate and is kept separate from the functional proof mutants.

## Non-Claims

This artifact does not claim FIFO semantic correctness, full internal-state equivalence, whole C910 proof, BOOM proof, ISA correctness, memory consistency, speculation correctness, or whole-chip authority. The raw exact-output temporal-induction log remains a non-closure boundary, not the positive authority path.

## Replay

One command reproduces every claim in this package. It resolves the pinned
verdict-bearing toolchain, verifies each tool's identity, and fails loud with one
named provisioning error before any proof or metric if a tool is missing or its
bytes do not match:

```bash
python3 ../../athanor/replay_public_receipt.py ct_fifo
```

BYO / custom toolchain — set the pinned tool paths and run this package's
`replay.sh` directly (it requires each var and never substitutes an ambient tool):

Run:

```bash
YOSYS_BIN=/path/to/yosys \
STA_BIN=/path/to/sta \
LIBERTY=/path/to/sky130_fd_sc_hd__tt_025C_1v80.lib \
  ./replay.sh
```

The script reproduces the selected Sky130 area, OpenSTA max data-arrival,
OpenSTA estimated power, the seq12 exact-output bounded proof, the biting
mutants, the state-exposed relation induction, and the passive-debug bridge
check. The metric screen remains rejected because timing regresses.
