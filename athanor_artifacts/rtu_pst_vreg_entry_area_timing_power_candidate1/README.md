# C910 RTU PST Vreg Entry Area, Timing, and Estimated-Power Packet 1

Status: scoped historical evidence packet, NOT current-bar customer-ready.
`customer_ready=false`. The current product (certified main `0a569cdb7`) REJECTS
the legacy root (`inconsistent_package`: public_path_leak, missing contract
fields) and the fresh source emit (`replay_failed`/`replay_timeout`). Current-main
measurements: generic cells REGRESS 578 to 599 (+3.63%); timing 3.38ns to 3.28ns
(WNS/TNS 0); sim bounded_match; toggle flat (7534 to 7534). Proof: inconclusive
(tempinduct seq 8, multiple unresolved state labels). No discriminator
(`bite=false`, `port_signature_mismatch`). Mapped metric emit does not rescue
(proof/negative inconclusive, measurement gaps). Old estimated-power/workload-power
wording is historical evidence, not current-product authority. Not whole-C910, ISA,
composed, or customer-ready authority.

This package records a same-candidate-bound metric packet for
`ct_rtu_pst_vreg_entry`. The candidate recodes the lifecycle FSM from the
original 5-bit one-hot representation to a 4-bit onehot0 representation with
`WF_ALLOC` represented by zero, matching the proof shape used for the physical
register PST entry.

## Same-Candidate Binding

Area, timing, and OpenSTA estimated-power use the exact committed mapped netlist
`ct_rtu_pst_vreg_entry_gate_candidate.mapped.v`, whose SHA-256 is recorded in
`same_candidate_binding_receipt.json`. The gold mapped netlist is
`ct_rtu_pst_vreg_entry_gold.mapped.v`.

## Metrics

| axis | gold | candidate | interpretation |
| --- | --- | --- | --- |
| Selected Sky130 area, top with deps | `3148.019200` | `3057.932800` | lower area in the selected flow |
| OpenSTA max data-arrival | `2.82 ns` | `2.81 ns` | small lower data-arrival delta under the package SDC; not a material timing claim |
| OpenSTA estimated total power | `1.28e-04 nW` | `1.24e-04 nW` | lower estimate under fixed activity |

The power row is an OpenSTA liberty estimate with
`set_power_activity -global -activity 0.1 -duty 0.5`. It is not signoff power
and not measured workload activity.

## Proof Control

The positive proof path is a passive debug bridge plus closed lifecycle-encoding
relation induction under reset-first. The proof negative control is
`ct_rtu_pst_vreg_entry_gate_dbg_mutant.v`; the same relation proof rejects it
with `proof did fail`.

A real bridge-obligation package is committed at `lean_bridge_obligation.json`.
It is SHA-bound to this package's gold/candidate RTL, proof receipt,
and mutant bite, and is intended as input to the local Lean theorem batch
worker. It does not change this package to `lean_authority`; the receipt
stays `lean_fallback` until a kernel-checked theorem is audited and
stamped.

## Metric Red-Control

`ct_rtu_pst_vreg_entry_metric_negative.mapped.v` is a metric-only red control:
it adds a long buffer chain in the mapped candidate netlist. It is deliberately
worse on all three metric axes:

| axis | red-control |
| --- | --- |
| Selected Sky130 area, top with deps | `5287.571200` |
| OpenSTA max data-arrival | `12.78 ns` |
| OpenSTA estimated total power | `2.29e-04 nW` |

This file is not a proof candidate. It exists to prove the metric checks can
turn red on a worse mapped netlist.

## Replay

One command reproduces every claim in this package. It resolves the pinned
verdict-bearing toolchain, verifies each tool's identity, and fails loud with one
named provisioning error before any proof or metric if a tool is missing or its
bytes do not match:

```bash
python3 ../../athanor/replay_public_receipt.py rtu_pst_vreg_entry_area_timing_power_candidate1
```

BYO / custom toolchain — set the pinned tool paths and run this package's
`replay.sh` directly (it requires each var and never substitutes an ambient tool):

Run:

```bash
YOSYS_BIN=/path/to/yosys \
STA_BIN=/path/to/sta \
LIBERTY=/path/to/sky130_fd_sc_hd__tt_025C_1v80.lib \
  ./replay.sh
```

The replay regenerates the selected mapped netlists, checks their SHA-256
bindings, replays the lifecycle relation proof and proof mutant, reruns area
and OpenSTA metrics, and confirms the metric red-control is worse on all three
axes.

## Boundaries

- Customer-ready only for scoped module-local area/timing/OpenSTA-estimated-power
  wording.
- Module-local `ct_rtu_pst_vreg_entry` only.
- Correctness proof scope remains visible-output equivalence under reset-first
  through passive debug bridge plus lifecycle-encoding relation induction.
- OpenSTA estimated power is not signoff power and not workload-measured power.
- This is not whole RTU, whole C910, BOOM, ISA, memory-consistency,
  speculation, composed optimization, or whole-chip authority.
