# C910 ct_lsu_rb Candidate 1

Status: candidate metric scout; `customer_ready=false`.

This packet records an LSU read-buffer static-priority simplification. The
candidate replaces two eight-way writeback pointer `casez` encoders with a
direct low-bit one-hot expression for `rb_ld_wb_data_ptr_pre` and
`rb_ld_wb_cmplt_ptr`.

## Metrics

All metrics below are from the same selected Sky130 mapping flow and the same
candidate netlist recorded in `same_candidate_binding_receipt.json`.

| Axis | Gold | Candidate | Result |
| --- | ---: | ---: | --- |
| Selected Sky130 area | `105329.769600` | `105134.582400` | lower area |
| OpenSTA max data-arrival | `16.76 ns` | `16.59 ns` | lower data-arrival under the package SDC |
| OpenSTA WNS | `-7.19 ns` | `-6.84 ns` | less negative WNS under the package SDC |
| OpenSTA estimated total power | `5.94e-03 nW` | `5.92e-03 nW` | lower estimated power under fixed activity |

The package SDC creates 10 ns clocks on both `lsu_special_clk` and
`forever_cpuclk`. The power row is an OpenSTA liberty estimate with
`set_power_activity -global -activity 0.1 -duty 0.5`. It is not signoff power
and not measured workload activity.

## Proof

The same-state Yosys equivalence check closes with `2088` proven equivalence
cells and `0` unproven cells after `equiv_simple -seq 8`.

## Negative Controls

`ct_lsu_rb_gate_proof_mutant.v` is a proof negative control. It breaks the
direct data writeback pointer expression, and the same equivalence check leaves
`8` pointer equivalence cells unproven.

`ct_lsu_rb_metric_negative.mapped.v` is a metric-only red control. It
deliberately worsens the measured candidate on all three axes:

| Axis | Red-control value |
| --- | ---: |
| Selected Sky130 area | `107648.243200` |
| OpenSTA max data-arrival | `18.38 ns` |
| OpenSTA estimated total power | `6.00e-03 nW` |

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
- Module-local `ct_lsu_rb` only.
- Same-state module equivalence under the checked RTL model is the proof
  subject.
- The mapped netlist violates a 10 ns ideal-clock package SDC in both gold and
  candidate forms; the candidate improves max data-arrival and WNS, but this is
  not timing closure.
- OpenSTA estimated power is not signoff power and not workload-measured power.
- Not whole LSU, whole C910/BOOM, ISA, memory consistency, speculation
  recovery, composed optimization, or whole-chip authority.
