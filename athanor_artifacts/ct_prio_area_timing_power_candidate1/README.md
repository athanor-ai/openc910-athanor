# C910 ct_prio Area, Timing, and Estimated-Power Packet 1

Status: accepted module-local metric packet; `customer_ready=true` for scoped
area/timing/OpenSTA-estimated-power wording.

This package records a more aggressive `ct_prio` priority-encoding rewrite than
the accepted public `ct_prio` packet. The candidate collapses the live priority
state to one flop and keeps the same visible `sel[1:0]` behavior under the same
reset-first output miter.

## Metrics

All metrics are from the same selected Sky130 mapping flow. Timing and
estimated-power use the exact committed mapped netlist
`ct_prio_gate_candidate.mapped.v`, whose SHA-256 is recorded in
`same_candidate_binding_receipt.json`.

| Axis | Gold | Candidate | Result |
| --- | ---: | ---: | --- |
| Selected Sky130 area | `158.902400` | `60.057600` | lower area |
| OpenSTA max data-arrival | `0.85 ns` | `0.67 ns` | lower delay under the package SDC |
| OpenSTA estimated total power | `1.08e-05 nW` | `2.89e-06 nW` | lower estimate under fixed activity |

The power row is an OpenSTA liberty estimate with
`set_power_activity -global -activity 0.1 -duty 0.5`. It is not signoff power
and not measured workload activity.

## Proof

The visible-output proof reuses the accepted `ct_prio` miter shape:
`sat -seq 8 -tempinduct -set-at 1 rst_b 0 -set-at 2 rst_b 1 -prove-asserts
-verify` closes on `sel[1:0]`.

## Negative Controls

`ct_prio_gate_proof_mutant.v` is a proof negative control. It breaks the
`sel[0]` priority expression while keeping the same module interface. The same
visible-output temporal-induction miter rejects it with `proof did fail`, so the
correctness proof is discriminating.

`ct_prio_metric_negative.mapped.v` is a metric-only red control: it inserts a
buffer chain on the candidate flop D path. It is deliberately worse on all
three metric axes:

| Axis | Red-control value |
| --- | ---: |
| Selected Sky130 area | `390.374400` |
| OpenSTA max data-arrival | `2.45 ns` |
| OpenSTA estimated total power | `1.84e-05 nW` |

This file is not a proof candidate. It exists to prove the metric checks can
turn red on regressions.

## Replay

One command reproduces every claim in this package. It resolves the pinned
verdict-bearing toolchain, verifies each tool's identity, and fails loud with one
named provisioning error before any proof or metric if a tool is missing or its
bytes do not match:

```bash
python3 ../../athanor/replay_public_receipt.py ct_prio_area_timing_power_candidate1
```

BYO / custom toolchain — set the pinned tool paths and run this package's
`replay.sh` directly (it requires each var and never substitutes an ambient tool):

```bash
YOSYS_BIN=/path/to/oss-cad-suite-20260630/bin/yosys \
STA_BIN=/path/to/sta \
LIBERTY=/path/to/sky130_fd_sc_hd__tt_025C_1v80.lib \
  ./replay.sh
```

`replay.sh` writes generated logs and Tcl files under ignored `replay_out/`.

## Boundaries

- Customer-ready only for scoped module-local area/timing/OpenSTA-estimated-power
  wording.
- Module-local `ct_prio` only.
- Visible `sel[1:0]` output behavior under reset-first is the proof subject.
- Not full internal-state equivalence.
- OpenSTA estimated power is not signoff power and not workload-measured power.
- Not whole C910/BOOM, ISA, memory consistency, speculation recovery, composed
  optimization, or whole-chip authority.
