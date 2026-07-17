# Pilot Demo Packet

This packet is a presentation index for the current public OpenC910 demo wins.
It does not introduce new proof, metric, replay, customer-readiness, or theorem
authority. The authoritative evidence remains in the linked artifact packages
and in `TARGET_ATLAS.md`.

## Demo headline

| Target | Demo story | Selected-flow metric result | Verification chain |
| --- | --- | --- | --- |
| [`plic_32to1_arb`](plic_32to1_arb_granu_balanced_candidate1/) | Largest raw timing win: a balanced second-stage PLIC selector tree. | Parent area `140709.952000 -> 136564.726400`; real `arb_clk` max data-arrival `13.26 ns -> 7.39 ns`; OpenSTA estimated power `3.73e-03 -> 3.59e-03 nW`. | Helper SAT miter proves; tie-rule mutant reds; flattened parent proof closes `66557/66557`; non-author replay reproduced all mapped netlists byte-exact. |
| [`ct_iu_div`](ct_iu_div_ff1_tree_candidate1/) | Divider FF1 normalization with a material timing improvement on a hard path. | Area `158090.371200 -> 156941.769600`; max data-arrival `39.67 ns -> 34.03 ns`; OpenSTA estimated power `7.06e-03 -> 7.03e-03 nW`. | Same-state proof closes `1966/1966`; FF1 mutant leaves `2` unproven cells; non-author replay reproduced mapped netlists byte-exact. |
| [`ct_pmp_acc`](ct_pmp_acc_napot_mask_candidate1/) | Explainable NAPOT identity: replace `casez` mask table with prefix-AND logic. | Parent area `7826.256000 -> 7415.862400`; max data-arrival `3.58 ns -> 3.51 ns`; OpenSTA estimated power `1.72e-04 -> 1.67e-04 nW`. | Helper proof closes `33/33`; parent proof closes `273/273`; NAPOT mutant leaves `2` unproven cells; non-author replay reproduced mapped netlists byte-exact. |

## Demo flow

1. Start with `plic_32to1_arb_granu_balanced_candidate1`: it is the simplest
   founder-facing headline, with a `44%` timing improvement on the parent path
   and area/power also down.
2. Show `ct_iu_div_ff1_tree_candidate1`: the win is on a real divider path, but
   the receipt honestly says both gold and candidate still violate the 10 ns
   ideal package clock. This is improvement, not timing closure.
3. Show `ct_pmp_acc_napot_mask_candidate1`: the transform is easy to explain,
   and the packet demonstrates why parent metrics decide. The helper timing
   screen regresses, but the checked parent path improves across all axes.

## Replay path

Run the public receipt verifier from the repository root:

```bash
python3 athanor/verify_public_receipts.py
```

Run one-command replay from a package directory, for example:

```bash
cd athanor_artifacts/plic_32to1_arb_granu_balanced_candidate1
python3 ../../athanor/replay_public_receipt.py plic_32to1_arb_granu_balanced_candidate1
```

The same pattern applies to the other promoted packages. A replay is meaningful
only when the pinned toolchain identity, package hashes, proof route, metric
logs, and negative controls all reproduce.

## Fences that make the wins credible

The demo story is not "every rewrite wins." Publicly promoted rows carry
replayable numbers above; rejected scouts stay qualitative here unless their
underlying receipt is also public.

| Target family | Lesson |
| --- | --- |
| `ct_lsu_snoop_snq` oldest-ready masks | Explicit first-ready equations are not free on this LSU parent. |
| `ct_lsu_snoop_snq` SDB create pointers | Similar-looking create-pointer rewrites need parent screening before proof spend. |
| `ct_l2c_cmp` one-hot way decode | A row that is smaller can still fail selected timing. |
| `ct_mmu_sysmap` flag grouping | Single-axis wins are not promoted. |
| `ct_lsu_dcache_arb` priority equations | Near-misses stay in the atlas until all selected axes clear. |
| IFU selector scouts | Cheap metric screens should run before expensive proofs on selector rewrites. |

## Non-claims

These packets do not claim whole-C910 correctness, ISA correctness, privilege or
interrupt-controller architectural authority, memory consistency, speculation
recovery, signoff timing, measured workload power, or Lean theorem-registry
authority. They are scoped module-local optimization receipts under the pinned
public Yosys/OpenSTA/Sky130 flow.
