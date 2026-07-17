# ct_pmp_acc NAPOT mask candidate 1

Status: parent-positive replay package; `customer_ready=false` until an
independent non-author replay closes.

This packet records a C910 PMP candidate. The source `ct_pmp_comp_hit` computes
the NAPOT address mask through a long `casez` table. The candidate replaces that
table with the equivalent prefix-AND identity:

```verilog
addr_mask[i] = ~&pmpaddr_x_value[i:0]
```

The candidate is checked both at the helper level and inside the flattened
`ct_pmp_acc` parent. The parent result is the headline screen: the helper-local
timing leg regresses, but the selected parent path improves.

## Evidence

- Helper same-state Yosys equivalence proves `33/33` equivalence cells with `0`
  unproven.
- Flattened parent `ct_pmp_acc` same-state Yosys equivalence proves `273/273`
  equivalence cells with `0` unproven.
- A mask-formula proof mutant is rejected by the same helper route, leaving
  exactly `2` unproven cells (`mmu_napot_addr_match` and `addr_mask[1]`).
- Helper selected-flow area improves `945.907200 -> 894.608000`; helper OpenSTA
  max data-arrival regresses `2.24 ns -> 2.57 ns`; helper OpenSTA estimated
  power improves `2.06e-05 nW -> 1.98e-05 nW`.
- Parent selected-flow area improves `7826.256000 -> 7415.862400`.
- Parent OpenSTA max data-arrival improves `3.58 ns -> 3.51 ns`.
- Parent OpenSTA estimated total power improves `1.72e-04 nW -> 1.67e-04 nW`.

## Boundaries

This is a parent-positive scout package for `ct_pmp_acc` using the package's
pinned Yosys/OpenSTA/Sky130 selected flow. It is not a customer-ready promoted
row yet, not a whole-PMP or whole-C910 claim, not a Lean theorem-registry claim,
and not signoff timing or workload power. The next gate is an independent
non-author public-path replay of this package.
