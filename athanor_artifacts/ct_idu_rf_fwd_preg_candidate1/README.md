# IDU RF forward PREG helper scout

This package records a helper-level scout for `ct_idu_rf_fwd_preg`, the integer
physical-register forwarding mux used by the IDU register-read path.

The candidate replaces the original priority `casez` selection with explicit
one-hot lane matching plus masked data OR-reduction. The correctness claim is
contracted: the forwarded data output is checked only when exactly one forwarding
lane matches the source register. The `x_src_no_fwd` output is checked
unconditionally.

## Local Metrics

| module | Sky130 area | OpenSTA max data-arrival | OpenSTA estimated total power |
| --- | --- | --- | --- |
| `ct_idu_rf_fwd_preg` | `2706.345600 -> 2382.284800` | `11.23 ns -> 6.10 ns` | `7.42e-05 -> 6.39e-05 nW` |

The package remains `customer_ready=false`: it is a replay-confirmed helper-level
one-hot-contract metric scout, not a parent IDU/register-file result row. Parent
integration is still required before any promotion discussion.

## Replay

One command reproduces every claim in this package. It resolves the pinned
verdict-bearing toolchain, verifies each tool's identity, and fails loud with one
named provisioning error before any proof or metric if a tool is missing or its
bytes do not match:

```bash
python3 ../../athanor/replay_public_receipt.py ct_idu_rf_fwd_preg_candidate1
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
