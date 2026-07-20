# plic_32to1_arb_granu_balanced_candidate1

Module-local OpenC910 PLIC scout packet for replacing the second-stage
`plic_granu_arb` priority selector inside `plic_32to1_arb` with a balanced
9-way comparator tree.

Status: scoped historical evidence packet, NOT current-bar customer-ready.
`customer_ready=false`. The current product (certified main `0a569cdb7`) either
REJECTS the legacy package contract (`inconsistent_package`: public_path_leak,
missing producer/top/clock/reset/binding/provenance) or emits bounded gaps on
both parent and helper surfaces. Parent mapped: GAP, proof inconclusive
(`gate_elaboration_failed: duplicate_module`), PPA/timing/sim/toggle unavailable.
Helper source: GAP, generic cells 762 to 448 (-41.21%) but proof inconclusive
(`Can't match gold port int_in_id_gold to a gate port`), no discriminator
(`bite=false`/`no_discriminator`), timing/sim/toggle setup gaps. Legacy
area/timing/power improvement language is NOT current-product authority.
Helper-only evidence does not rescue the parent claim. Not whole-C910, ISA,
composed, or customer-ready authority.

## Evidence

- Helper proof: 9-way `plic_granu_arb` SAT miter proves the balanced candidate
  equal to the original selector.
- Proof negative: changing tie behavior from lower-index wins to later-index
  wins fails the miter.
- Parent proof: flattened `plic_32to1_arb` same-state proof closes
  `66557/66557` cells with the implementation-internal helper-ID wires
  blacklisted from matching; top-level parent outputs remain checked.
- Parent metrics, real `arb_clk` OpenSTA screen:
  - Sky130 selected area: `140709.952000 -> 136564.726400`
  - max data-arrival: `13.26 ns -> 7.39 ns`
  - OpenSTA estimated total power: `3.73e-03 -> 3.59e-03`
- Helper metrics:
  - Sky130 selected area: `5975.731200 -> 1671.603200`
  - max data-arrival: `12.56 ns -> 6.42 ns`
  - OpenSTA estimated total power: `1.82e-04 -> 4.48e-05`

## Boundary

This is a module-local PLIC packet, not a whole-C910 interrupt-controller,
privilege, platform, timing-signoff, workload-power, or Lean theorem-registry
claim. OpenSTA power is estimated under fixed global activity and is not signoff
power. The parent timing screen uses a real `arb_clk` constraint; the helper
screen uses the package's virtual-clock combinational convention. Both
blacklisted parent-equivalence names are implementation-internal helper-ID wires;
no parent ports are blacklisted.

## Replay

Preferred one-command replay:

```bash
python3 ../../athanor/replay_public_receipt.py plic_32to1_arb_granu_balanced_candidate1
```

BYO explicit-tool replay:

```bash
YOSYS_BIN=/path/to/oss-cad-suite/bin/yosys \
STA_BIN=/path/to/OpenSTA/bin/sta \
LIBERTY=/path/to/sky130_fd_sc_hd__tt_025C_1v80.lib \
./replay.sh
```
