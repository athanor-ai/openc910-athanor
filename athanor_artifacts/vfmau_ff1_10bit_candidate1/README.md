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

The package remains `customer_ready=false`: it is a helper-level metric scout
pending independent replay and parent integration review.
