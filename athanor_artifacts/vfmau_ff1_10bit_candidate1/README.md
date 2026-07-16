# VFMAC FF1 10-bit helper scout

This package records a helper-level scout for `ct_vfmau_ff1_10bit`, a first-one
encoder used by the VFMAC SIMD-half multiplier path.

The candidate replaces the original priority `casez` table with explicit
first-one masking and a binary OR reduction. The correctness claim is scoped to
the helper module output only; this package does not claim parent
`ct_vfmau_mult_simd_half` integration or a full VFMAC result row.

## Local Metrics

| module | Sky130 area | OpenSTA max data-arrival | OpenSTA estimated total power |
| --- | --- | --- | --- |
| `ct_vfmau_ff1_10bit` | `111.356800 -> 97.593600` | `0.89 ns -> 0.61 ns` | `2.46e-06 -> 2.06e-06 nW` |

The package remains `customer_ready=false`: it is a replay-confirmed helper-level
metric scout, not a parent VFMAC result row. Parent integration review is still
required before any promotion discussion.

## Replay

One command reproduces every claim in this package. It resolves the pinned
verdict-bearing toolchain, verifies each tool's identity, and fails loud with one
named provisioning error before any proof or metric if a tool is missing or its
bytes do not match:

```bash
python3 ../../athanor/replay_public_receipt.py vfmau_ff1_10bit_candidate1
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
