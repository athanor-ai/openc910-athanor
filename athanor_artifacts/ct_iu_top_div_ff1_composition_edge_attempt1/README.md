# ct_iu_top divider FF1 composition-edge attempt 1

Status: `customer_ready=false`. This is a composition-edge route receipt for
lifting the promoted `ct_iu_div` FF1 candidate to the `ct_iu_top` boundary. It
is not a promoted customer packet and not a flat whole-IU proof.

The package records three facts:

- The only RTL source difference at the `ct_iu_top` boundary is `ct_iu_div.v`;
  the `ct_iu_top` source is byte-identical and the `ct_iu_div` public interface
  is identical across gold and gate.
- The already-promoted `ct_iu_div` packet remains the proof authority for the
  changed module: same-state equivalence proves `1966/1966` cells, and its proof
  mutant leaves exactly `2` unproven cells.
- A bounded `ct_iu_top` selected-flow screen is area/power-positive and
  timing-flat under the package clock screen:
  area `729976.355200 -> 728213.414400`, OpenSTA max data-arrival
  `34.3786 ns -> 34.3786 ns`, WNS `-24.53 -> -24.53`, and estimated total power
  `8.23e-02 -> 8.21e-02`.

The flat `ct_iu_top` proof route is explicitly not claimed. The live flat proof
attempt capped out at this boundary, so the intended route is compositional:
module-local proof for `ct_iu_div`, source-hash identity for unchanged modules,
and an unchanged-boundary/interface check at `ct_iu_top`.

## Boundaries

This is a route receipt for `ct_iu_top` only. It is not a whole-IU, whole-C910,
ISA, architectural-retire, signoff-timing, workload-power, or Lean-authority
claim. OpenSTA estimated power is not signoff power and not measured workload
activity.
