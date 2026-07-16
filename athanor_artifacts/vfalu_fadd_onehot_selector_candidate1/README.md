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

## Replay

One command reproduces every claim in this package. It resolves the pinned
verdict-bearing toolchain, verifies each tool's identity, and fails loud with one
named provisioning error before any proof or metric if a tool is missing or its
bytes do not match:

```bash
python3 ../../athanor/replay_public_receipt.py vfalu_fadd_onehot_selector_candidate1
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
