# ct_iu_div FF1 tree candidate 1

Status: accepted module-local metric packet; `customer_ready=true` for the
scoped `ct_iu_div` packet only.

This packet records a C910 integer divider candidate. The source has two
64-way positive FF1 encoders for `dvd` and `dvr`; the candidate replaces those
case trees with a binary leading-one encoder function while preserving the
module's all-zero behavior (`6'd63`). No divider state machine, SRT helper, or
external interface is otherwise changed.

## Evidence

- Same-state Yosys equivalence over the full `ct_iu_div` top-with-deps proves
  `1966/1966` equivalence cells with `0` unproven.
- A one-bit FF1 proof mutant is rejected by the same route, leaving exactly `2`
  unproven cells (`div_ex1_src0_pos_ff1_disp[0]` and
  `div_ex1_src1_pos_ff1_disp[0]`).
- Same-candidate Sky130 selected-flow area improves
  `158090.371200 -> 156941.769600`.
- OpenSTA max data-arrival under the package clock contract improves
  `39.67 ns -> 34.03 ns`; both gold and candidate violate the 10 ns ideal clock,
  so this is an improvement measurement, not timing closure.
- OpenSTA estimated total power under fixed global activity improves
  `7.06e-03 nW -> 7.03e-03 nW`.
- A metric-negative candidate deliberately corrupts `div_rbus_data`; it worsens
  area (`159225.209600`), timing (`46.01 ns` max data-arrival), and estimated
  power (`7.14e-03 nW`).

## Boundaries

This is a module-local `ct_iu_div` promoted packet. It is not a whole-IU or
whole-C910 claim, not ISA correctness, not division-algorithm authority, and not
signoff timing or power. Both gold and candidate still violate the 10 ns ideal
package clock; the packet reports a same-flow timing improvement, not closure.

Independent non-author replay has closed: the replayed mapped netlists matched
the package hashes byte-for-byte, the same-state proof and proof mutant matched,
and area/timing/power plus the metric red-control reproduced under the pinned
Yosys/OpenSTA/Sky130 suite.
