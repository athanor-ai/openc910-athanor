# C910 RTU Vreg Table Encoder-Family Candidate 1

Status: replay-confirmed candidate evidence; `customer_ready=false`.

This package records a parent-table encoder-family scout for `ct_rtu_pst_vreg`. The
candidate replaces the shared `ct_rtu_encode_64` priority-style encoder with bit-mask
reductions. It is packaged per table so the parent netlist, proof bite, and PPA
screen remain falsifiable for the exact table that uses the helper.

The family boundary is explicit: the 64-bit and 96-bit encoders are packaged
here because they showed parent-table area signal; the 32-bit encoder variant is
banked as a hard negative because its helper area regressed.

## Metrics

All metrics below are from the same selected Sky130 mapping flow and the same
parent-table candidate netlist recorded in `same_candidate_binding_receipt.json`.

| Axis | Gold | Candidate | Result |
| --- | ---: | ---: | --- |
| Selected Sky130 area, parent table | `234172.089600` | `233181.139200` | lower area |
| OpenSTA max data-arrival | `8.30 ns` | `8.30 ns` | flat at reported precision |
| OpenSTA estimated total power | `9.41e-03 nW` | `9.39e-03 nW` | lower estimate |

The vreg table keeps the parent area win and a lower OpenSTA estimated-power value, while max data-arrival is flat at the reported precision. A non-author second-seat replay on 2026-07-15 reproduced the manifest, helper proof, proof mutant, mapped-netlist hashes, area, timing, estimated power, and metric-negative controls. It remains non-customer-ready candidate evidence until an explicit promotion-row review closes.

The power row is an OpenSTA liberty estimate with
`set_power_activity -global -activity 0.1 -duty 0.5`. It is not signoff power
and not measured workload activity.

## Proof

The proof subject is the shared helper substitution, not a new parent-table
state relation. Yosys proves `ct_rtu_encode_64` gold versus candidate equivalent for all
helper inputs, and the boundary-bit mutant leaves one equivalence cell unproven
under the same check. The parent-table metric netlist is then synthesized with
that exact candidate helper, binding proof subject and metric subject by SHA.

## Negative Controls

`ct_rtu_encode_64_proof_mutant.v` is a proof negative control. It removes a boundary
index from the helper mask, and the same helper equivalence check rejects it.

`ct_rtu_pst_vreg_metric_negative.mapped.v` is a metric-only red control. It inserts a long
buffer chain into the mapped parent-table candidate netlist and is deliberately
worse on all three metric axes:

| Axis | Red-control value |
| --- | ---: |
| Selected Sky130 area | `235823.673600` |
| OpenSTA max data-arrival | `18.57 ns` |
| OpenSTA estimated total power | `1.19e-02 nW` |

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

- Replay-confirmed candidate evidence only; not promoted as a result row.
- Parent-table `ct_rtu_pst_vreg` only; not whole RTU or whole C910.
- Correctness evidence is helper-substitution equivalence plus a biting helper
  mutant; no parent-table relation theorem is claimed here.
- The metric red-control is metric-only and not a functional candidate.
- OpenSTA estimated power is not signoff power and not workload-measured power.
- Not whole C910/BOOM, ISA, memory consistency, speculation recovery, composed
  optimization, or whole-chip authority.
