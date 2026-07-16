# C910 ct_rtu_compare_iid Candidate 1

Status: helper/parent area scout; `customer_ready=false`.

This packet records a wrapped-IID comparator simplification. The candidate
replaces the hand-built bit-priority compare with the equivalent direct
wrapped-IID relation:

```verilog
assign x_iid0_older = (x_iid0[6] == x_iid1[6])
                    ? (x_iid1[5:0] > x_iid0[5:0])
                    : (x_iid0[5:0] > x_iid1[5:0]);
```

## Metrics

All numbers below are selected Sky130 synthesis area screens from the same
pinned Yosys/liberty flow. They are not a promotion packet because timing and
power are not yet closed on a same-candidate package.

| Surface | Gold | Candidate | Result |
| --- | ---: | ---: | --- |
| `ct_rtu_compare_iid` helper | `142.636800` | `127.622400` | lower area |
| `ct_lsu_spec_fail_predict` parent screen | `1725.404800` | `1695.376000` | lower area with two helper instances |
| `ct_lsu_pfu_sdb_cmp` parent screen | `6052.054400` | `6007.011200` | lower area with three helper instances |

The parent screens use `PA_WIDTH=40` plus the shipped `gated_clk_cell` stub.
Both parent runs report unknown area for unchanged sequential cells; the helper
delta remains visible through the shared `ct_rtu_compare_iid` instances.

## Proof

The helper-level Yosys equivalence check closes with `1` proven equivalence
cell and `0` unproven cells.

## Negative Control

`ct_rtu_compare_iid_gate_proof_mutant.v` weakens the same-wrap branch from
strict `>` to `>=`. The same helper equivalence check rejects it with `1`
unproven equivalence cell. This bites the equality boundary, where identical
IIDs must not mark `x_iid0` older.

## Replay

```bash
YOSYS_BIN=/path/to/oss-cad-suite-20260630/bin/yosys \
LIBERTY=/path/to/sky130_fd_sc_hd__tt_025C_1v80.lib \
  ./replay.sh
```

`replay.sh` writes generated logs and mapped helper netlists under ignored
`replay_out/`.

## Boundaries

- Helper/parent area scout only; not promoted as a result row.
- `customer_ready=false`; no customer-ready PPA or proof-result row is claimed.
- Helper proof is combinational `ct_rtu_compare_iid` equivalence under the
  checked RTL model.
- Parent evidence is synthesis-area screening only for two LSU parent surfaces.
- Timing and power are not claimed here.
- Not whole LSU, whole C910/BOOM, ISA, memory consistency, speculation
  recovery, composed optimization, or whole-chip authority.
