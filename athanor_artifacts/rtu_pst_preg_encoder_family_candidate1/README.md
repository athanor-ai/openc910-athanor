# C910 RTU Preg Table Encoder-Family Candidate 1

Status: proof-backed metric hard negative for promotion; `customer_ready=false`.

This package records a parent-table encoder-family scout for `ct_rtu_pst_preg`. The
candidate replaces the shared `ct_rtu_encode_96` priority-style encoder with bit-mask
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
| Selected Sky130 area, parent table | `384860.361600` | `383196.265600` | lower area |
| OpenSTA max data-arrival | `11.31 ns` | `11.35 ns` | data-arrival regression |
| OpenSTA estimated total power | `1.51e-02 nW` | `1.50e-02 nW` | lower estimate |

The preg table keeps the parent area and estimated-power improvements, but
OpenSTA max data-arrival regresses. This package is therefore a proof-backed
hard-negative receipt for promotion, not a result row.

The power row is an OpenSTA liberty estimate with
`set_power_activity -global -activity 0.1 -duty 0.5`. It is not signoff power
and not measured workload activity.

## Proof

The proof subject now includes both the shared helper substitution and the
`ct_rtu_pst_preg` parent table. Yosys proves `ct_rtu_encode_96` gold versus
candidate equivalent for all helper inputs, and the boundary-bit mutant leaves
one equivalence cell unproven under the same check.

For the parent table, the replay flattens each side with the exact packaged
helper, builds a generated-temp blacklist, runs `async2sync`, `dffunmap`,
`equiv_simple -seq 8`, `equiv_induct -seq 8`, and `equiv_status -assert`, and
proves `31716` equivalence cells with `0` unproven cells. The same helper
boundary-bit mutant leaves `35` parent-table cells unproven, so the parent proof
route is non-vacuous. The parent-table metric netlist is synthesized with that
exact candidate helper, binding proof subject and metric subject by SHA.

## Negative Controls

`ct_rtu_encode_96_proof_mutant.v` is a proof negative control. It removes a boundary
index from the helper mask, and the same helper equivalence check rejects it.
The parent-table proof route rejects the same mutant with `35` unproven cells
across recover/dealloc outputs.

`ct_rtu_pst_preg_metric_negative.mapped.v` is a metric-only red control. It inserts a long
buffer chain into the mapped parent-table candidate netlist and is deliberately
worse on all three metric axes:

| Axis | Red-control value |
| --- | ---: |
| Selected Sky130 area | `385838.800000` |
| OpenSTA max data-arrival | `18.57 ns` |
| OpenSTA estimated total power | `1.75e-02 nW` |

This file is not a proof candidate. It exists to prove the metric checks can
turn red on regressions.

## Replay

One command reproduces every claim in this package. It resolves the pinned
verdict-bearing toolchain, verifies each tool's identity, and fails loud with one
named provisioning error before any proof or metric if a tool is missing or its
bytes do not match:

```bash
python3 ../../athanor/replay_public_receipt.py rtu_pst_preg_encoder_family_candidate1
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

- Proof-backed hard-negative evidence only; not promoted as a result row.
- Parent-table `ct_rtu_pst_preg` only; not whole RTU or whole C910.
- Correctness evidence is helper-substitution equivalence plus parent-table
  same-state equivalence through the packaged replay route; no Lean theorem or
  whole-table theorem-registry authority is claimed here.
- The metric red-control is metric-only and not a functional candidate.
- OpenSTA estimated power is not signoff power and not workload-measured power.
- Not whole C910/BOOM, ISA, memory consistency, speculation recovery, composed
  optimization, or whole-chip authority.
