# ct_pmp_top NAPOT mask candidate 1

Status: `customer_ready=true` for the subsystem-top `ct_pmp_top` packet under
the pinned public replay flow. A non-author replay reproduced the proof,
proof-mutant, mapped netlist hashes, metric-negative control, and recorded
area/timing/OpenSTA estimated-power metrics from the public package path.

This packet lifts the promoted `ct_pmp_acc` NAPOT mask candidate through the
`ct_pmp_top` subsystem. The only accepted RTL delta is still the
`ct_pmp_comp_hit` replacement:

```verilog
addr_mask[i] = ~&pmpaddr_x_value[i:0]
```

The subsystem result is area/power-positive and timing-flat under the pinned
selected flow. The proof gap observed under raw sequential induction was a
method error, not a candidate gap: the promoted-packet same-state route closes
the subsystem proof.

## Evidence

- Flattened `ct_pmp_top` same-state Yosys equivalence proves `831/831`
  equivalence cells with `0` unproven.
- The same route rejects the package proof mutant, leaving exactly `48`
  unproven cells.
- Selected-flow subsystem area improves `50325.766400 -> 49474.950400`.
- OpenSTA max data-arrival is flat at `3.2370 ns -> 3.2370 ns`.
- OpenSTA estimated total power improves `1.92e-03 nW -> 1.90e-03 nW`.
- A synthetic metric-negative control is SHA-bound in this package and reds all
  three metric axes: area `63387.043200`, max data-arrival `7.3389 ns`, and
  estimated power `2.56e-03 nW`.
- Non-author replay reproduced all three replay-produced mapped netlists
  byte-exact against `SHA256SUMS`, the `831/831` same-state proof, the exact
  `48`-cell proof-mutant failure, and the three-axis metric-negative red.

## Boundaries

This is a subsystem-top packet for `ct_pmp_top`, not a whole-PMP, whole-MMU,
whole-C910, ISA, privilege-model, signoff-timing, workload-power, or
Lean-authority theorem claim. The metric-negative control is deliberately
synthetic and exists only to prove the measurement gate can reject a worse
same-flow point. OpenSTA timing and estimated power are not signoff timing or
measured workload power.
