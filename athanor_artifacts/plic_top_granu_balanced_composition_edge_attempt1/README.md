# plic_top PLIC composition-edge attempt 1

Status: composition-edge route receipt only. This is not a promoted packet and
not a flat `plic_top` proof.

This package lifts the promoted `plic_32to1_arb` balanced-granule candidate to
the larger `plic_top` boundary by recording three facts:

- The only RTL source difference at the `plic_top` boundary is
  `plic_granu_arb.v`; `plic_top.v` is byte-identical and the changed module's
  public interface is identical across gold and gate.
- The already-promoted `plic_32to1_arb` packet remains the proof authority for
  the changed logic: flattened parent same-state equivalence closes
  `66557/66557`, and the tie-rule proof mutant fails as expected.
- The bounded `plic_top` selected-flow screen is area/power-positive and uses
  conservative timing-flat wording under the pinned screen:
  composed area `1039075.305600 -> 1006879.427200`, OpenSTA max data-arrival
  `140.74 ns -> 140.29 ns`, WNS `-130.87 -> -130.42`, and estimated total
  power `9.71e-02 -> 9.60e-02`.

The flat `plic_top` proof route is explicitly not claimed. The live flat attempt
capped out at this boundary with `20812` unproven cells and zero completed
prove-batches under a 15-minute cap, dominated by unchanged register-bus cones.
The route is therefore compositional: promoted parent proof for
`plic_32to1_arb`, source-hash identity for unchanged modules, and an
unchanged-boundary/interface check at `plic_top`.

## Boundaries

This is a route receipt for `plic_top` only. It is not a whole-PLIC,
whole-C910, ISA, privilege, platform, architectural-retire, signoff-timing,
workload-power, or Lean-authority claim. OpenSTA estimated power is not signoff
power and not measured workload activity.
