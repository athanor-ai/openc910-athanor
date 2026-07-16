# C910 ct_rtu_compare_iid Candidate 1

Status: parent-integrated `ct_lsu_pfu_sdb_cmp` proof + full-PPA scout;
`customer_ready=false`.

This packet records a wrapped-IID comparator simplification. The candidate
replaces the hand-built bit-priority compare with the equivalent direct
wrapped-IID relation:

```verilog
assign x_iid0_older = (x_iid0[6] == x_iid1[6])
                    ? (x_iid1[5:0] > x_iid0[5:0])
                    : (x_iid0[5:0] > x_iid1[5:0]);
```

## Metrics

All numbers below are from the same pinned Yosys/OpenSTA/liberty flow. The two
LSU parent screens substitute the same helper candidate into the parent RTL and
rebuild the parent mapped netlist before measuring selected Sky130 area,
OpenSTA max data-arrival, and OpenSTA estimated power.

| Surface | Area | OpenSTA max data-arrival | OpenSTA estimated total power | Result |
| --- | ---: | ---: | ---: | --- |
| `ct_rtu_compare_iid` helper | `142.636800 -> 127.622400` | not measured | not measured | helper area improves |
| `ct_lsu_spec_fail_predict` parent | `6576.307200 -> 6546.278400` | `4.73 ns -> 4.67 ns` | `3.79e-04 -> 3.78e-04 nW` | parent area, timing, and estimated power improve |
| `ct_lsu_pfu_sdb_cmp` parent | `11684.956800 -> 11639.913600` | `8.14 ns -> 8.14 ns` max path, with the cross-clock reported path `7.00 ns -> 6.91 ns` | `5.92e-04 -> 5.91e-04 nW` | parent area and estimated power improve; worst reported max path is flat |

The parent screens use `PA_WIDTH=40` plus the shipped `gated_clk_cell` stub.
The proof-subject helper appears twice in `ct_lsu_spec_fail_predict` and three
times in `ct_lsu_pfu_sdb_cmp`.

## Proof

The helper-level Yosys equivalence check closes with `1` proven equivalence
cell and `0` unproven cells.

The `ct_lsu_pfu_sdb_cmp` parent same-state route now closes through the replayed
parent proof construction: per-side helper flattening, generated-temp blacklist,
`async2sync`, `dffunmap`, `equiv_simple -seq 8`, `equiv_induct -seq 8`, and
`equiv_status -assert`. The parent proof log records `366` proven equivalence
cells and `0` unproven cells. The `ct_lsu_spec_fail_predict` parent remains
PPA-screen evidence only; no proof authority is claimed for that parent.

## Negative Control

`ct_rtu_compare_iid_gate_proof_mutant.v` weakens the same-wrap branch from
strict `>` to `>=`. The same helper equivalence check rejects it with `1`
unproven equivalence cell. This bites the equality boundary, where identical
IIDs must not mark `x_iid0` older.

The same equality-boundary mutant also bites in the `ct_lsu_pfu_sdb_cmp` parent
proof route: the parent mutant replay leaves exactly `3` unproven cells at the
three helper comparator sites.

`ct_rtu_compare_iid_metric_negative.v` deliberately adds unrelated slow logic to
the helper output. Rebuilding the same two parent netlists with that helper
regresses both parent area/timing/power screens:

- `ct_lsu_spec_fail_predict`: area `8087.756800`, max data-arrival `7.74 ns`,
  estimated power `4.23e-04 nW`.
- `ct_lsu_pfu_sdb_cmp`: area `13952.131200`, max data-arrival `10.05 ns`,
  estimated power `6.57e-04 nW`.

## Replay

```bash
YOSYS_BIN=/path/to/oss-cad-suite-20260630/bin/yosys \
STA_BIN=/path/to/OpenSTA/bin/sta \
LIBERTY=/path/to/sky130_fd_sc_hd__tt_025C_1v80.lib \
  ./replay.sh
```

`replay.sh` writes generated logs and mapped netlists under ignored
`replay_out/` and checks the committed parent mapped-netlist hashes.

## Boundaries

- Parent-integrated full-PPA scout only; not promoted as a result row.
- `customer_ready=false`; no customer-ready result row is claimed.
- Helper proof is combinational `ct_rtu_compare_iid` equivalence under the
  checked RTL model.
- `ct_lsu_pfu_sdb_cmp` parent proof is same-state equivalence with `366/366`
  cells proven and a `3`-cell equality-boundary mutant bite.
- Parent evidence is same-candidate-bound selected Sky130 area, OpenSTA
  max-data-arrival, and OpenSTA estimated-power screening for two LSU parent
  surfaces.
- `ct_lsu_spec_fail_predict` parent same-state proof remains unsupported before
  verdict, so no proof authority is claimed for that parent.
- Not whole LSU, whole C910/BOOM, ISA, memory consistency, speculation
  recovery, composed optimization, or whole-chip authority.
