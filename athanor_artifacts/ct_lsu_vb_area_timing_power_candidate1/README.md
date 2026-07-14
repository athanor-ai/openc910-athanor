# C910 ct_lsu_vb Candidate 1

Status: candidate metric scout; `customer_ready=false`.

This packet records an LSU victim-buffer decode simplification. The candidate
replaces two 2-entry address-ID case decodes with direct one-hot shifts:
`vb_biu_aw_addr_ptr` and `vb_addr_b_resp_ptr`.

## Metrics

All metrics below are from the same selected Sky130 mapping flow and the same
candidate netlist recorded in `same_candidate_binding_receipt.json`.

| Axis | Gold | Candidate | Result |
| --- | ---: | ---: | --- |
| Selected Sky130 area | `13043.760000` | `13038.755200` | lower area |
| OpenSTA max data-arrival | `6.01 ns` | `4.99 ns` | lower data-arrival under the package SDC |
| OpenSTA estimated total power | `5.95e-04 nW` | `5.93e-04 nW` | lower estimated power under fixed activity |

The power row is an OpenSTA liberty estimate with
`set_power_activity -global -activity 0.1 -duty 0.5`. It is not signoff power
and not measured workload activity.

## Proof

The candidate is checked with a reset-first visible-output miter over all
module outputs. Yosys `sat -seq 8 -prove-asserts -verify` closes with no model
found after forcing reset low at step 1 and high from steps 2 through 8.

## Negative Controls

`ct_lsu_vb_gate_proof_mutant.v` is a proof negative control. It flips the two
one-hot shift indices, and the same output miter fails as expected.

`ct_lsu_vb_metric_negative.mapped.v` is a metric-only red control. It
deliberately worsens the measured candidate on all three axes:

| Axis | Red-control value |
| --- | ---: |
| Selected Sky130 area | `15312.185600` |
| OpenSTA max data-arrival | `8.93 ns` |
| OpenSTA estimated total power | `6.62e-04 nW` |

This file is not a proof candidate. It exists to prove the metric checks can
turn red on regressions.

## Replay

```bash
YOSYS_BIN=/path/to/oss-cad-suite-20260630/bin/yosys \
STA_BIN=/path/to/sta \
LIBERTY=/path/to/sky130_fd_sc_hd__tt_025C_1v80.lib \
  ./replay.sh
```

`replay.sh` writes generated logs and Tcl files under ignored `replay_out/`.

## Boundaries

- Candidate metric scout only; not promoted as a result row.
- Module-local `ct_lsu_vb` only.
- Visible-output equivalence under the reset-first bounded miter is the proof
  subject.
- OpenSTA estimated power is not signoff power and not workload-measured power.
- Not whole LSU, whole C910/BOOM, ISA, memory consistency, speculation
  recovery, composed optimization, or whole-chip authority.
