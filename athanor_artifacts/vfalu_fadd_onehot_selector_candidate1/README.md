# VFALU FADD onehot selector scout

This package records a helper-level scout for two VFALU FADD close-path selector
modules:

- `ct_fadd_onehot_sel_h`
- `ct_fadd_onehot_sel_d`

The candidate replaces case-based onehot shift selectors with masked-shift OR
reductions. The correctness claim is deliberately scoped: the selectors are
checked under a onehot-or-zero input contract. Multihot selector behavior is not
claimed by this package.

## Local metrics

| module | Sky130 area | OpenSTA max data-arrival | OpenSTA estimated total power |
| --- | --- | --- | --- |
| `ct_fadd_onehot_sel_h` | `599.324800 -> 339.075200` | `2.29 ns -> 0.54 ns` | `1.55e-05 -> 5.90e-06 nW` |
| `ct_fadd_onehot_sel_d` | `8134.051200 -> 6563.795200` | `7.07 ns -> 1.03 ns` | `2.25e-04 -> 1.19e-04 nW` |

The package remains `customer_ready=false`: it is a helper-level scout, not a
parent VFALU result row. Non-author replay has reproduced the helper package;
parent integration is still required before any promotion discussion.
