# OpenC910 plic_top Bounded PPA Attempt 1

Status: bounded composed PLIC screen; `customer_ready=false`.

This package is the first ATH-3121 full-top harness receipt attempt against the
`plic_32to1_arb_granu_balanced_candidate1` overlay. It lifts the candidate from
the promoted parent packet into the larger `plic_top` boundary and records the
screen, source set, and cache keys needed for repeatable comparison.

## Result

| Axis | Gold | Candidate | Demo wording |
| --- | ---: | ---: | --- |
| Composed hierarchical Sky130 area | `1039075.305600` | `1006879.427200` | improves under this bounded PLIC screen |
| OpenSTA WNS | `-130.87 ns` | `-130.42 ns` | timing-flat until screen reconciliation |
| OpenSTA estimated total power | `9.71e-02 nW` | `9.60e-02 nW` | improves under fixed activity |

The timing row is intentionally conservative. A prior simple plic_clk screen and
this composed screen disagree on whether the timing row is exactly flat or
slightly better. The committed receipt therefore pins the screen configuration
by hash and uses the customer-facing wording `timing-flat` until all compared
runs share the same screen hash.

## Boundaries

- This is a `plic_top` composed screen, not a whole-C910, ISA, privilege, or
  interrupt-controller architecture claim.
- The package does not promote a new public result row.
- The package does not claim signoff timing or measured workload power.
- The package does not introduce a new proof; it consumes the already promoted
  helper/parent proof packet and checks a larger metric boundary.
- Cache keys are content-hash based: source bytes, overlay bytes, toolchain
  identity, selected flow, and screen configuration all affect the key.
- Cap-outs are named partial receipts, never success.

## Replay

One command checks the hash-bound receipt contract, regenerates the gate overlay,
runs Yosys mapping for gold and candidate `plic_top`, runs OpenSTA under the
pinned screen, and verifies the mapped-netlist hashes and metric values:

```bash
YOSYS_BIN=/path/to/oss-cad-suite-20260630/bin/yosys \
STA_BIN=/path/to/sta \
LIBERTY=/path/to/sky130_fd_sc_hd__tt_025C_1v80.lib \
  ./replay.sh
```

`replay.sh` writes local logs, Tcl files, and large mapped netlists under ignored
`replay_out/`. The public package does not ship those large netlists; the cache
keys bind the source, overlay, toolchain, flow, and screen inputs that produce
them. The next ATH-3121 leg adds cache invalidation bites around persistent
cache reuse.
