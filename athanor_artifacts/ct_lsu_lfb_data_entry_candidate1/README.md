# C910 ct_lsu_lfb_data_entry Candidate 1

Status: candidate metric scout; `customer_ready=false`.

This packet records an LSU line-fill-buffer data-entry decode simplification.
The candidate replaces the eight-way case decode for `lfb_data_entry_addr_id`
with a one-hot shift from `lfb_data_entry_biu_id[2:0]`.

## Metrics

All metrics below are from the same selected Sky130 mapping flow and the same
candidate netlist recorded in `same_candidate_binding_receipt.json`.

| Axis | Gold | Candidate | Result |
| --- | ---: | ---: | --- |
| Selected Sky130 area | `19467.420800` | `19456.160000` | lower area |
| OpenSTA max data-arrival | `8.17 ns` | `8.14 ns` | small lower data-arrival delta under the package SDC |
| OpenSTA estimated total power | `1.33e-03 nW` | `1.33e-03 nW` | flat at reported precision under fixed activity |

The power row is an OpenSTA liberty estimate with
`set_power_activity -global -activity 0.1 -duty 0.5`. It is not signoff power
and not measured workload activity.

## Proof

The same-state Yosys equivalence check closes with `560` proven equivalence
cells and `0` unproven cells after `equiv_simple -seq 8`.

## Negative Controls

`ct_lsu_lfb_data_entry_gate_proof_mutant.v` is a proof negative control. It
changes the one-hot shift index, and the same equivalence check leaves `8`
address-ID equivalence cells unproven.

`ct_lsu_lfb_data_entry_metric_negative.mapped.v` is a metric-only red control.
It deliberately worsens the measured candidate on all three axes:

| Axis | Red-control value |
| --- | ---: |
| Selected Sky130 area | `23926.697600` |
| OpenSTA max data-arrival | `8.15 ns` |
| OpenSTA estimated total power | `1.47e-03 nW` |

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
- Module-local `ct_lsu_lfb_data_entry` only.
- Same-state module equivalence under the checked RTL model is the proof
  subject.
- The timing movement is small, and the OpenSTA estimated-power result is flat
  at reported precision.
- OpenSTA estimated power is not signoff power and not workload-measured power.
- Not whole LSU, whole C910/BOOM, ISA, memory consistency, speculation
  recovery, composed optimization, or whole-chip authority.
