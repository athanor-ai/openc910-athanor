# C910 RTU PST Preg Entry Area, Timing, and Estimated-Power Packet 1

Status: accepted module-local metric packet; `customer_ready=true` for scoped
area/timing/OpenSTA-estimated-power wording.

This package extends the accepted `ct_rtu_pst_preg_entry` relation packet with
same-candidate-bound selected area, OpenSTA max data-arrival, and OpenSTA
estimated total-power measurements. The RTL optimization itself is unchanged:
the candidate recodes the lifecycle FSM from 5-bit one-hot to 4-bit onehot0
with `WF_ALLOC` represented by zero.

## Same-Candidate Binding

Area, timing, and OpenSTA estimated-power use the exact committed mapped netlist
`ct_rtu_pst_preg_entry_gate_candidate.mapped.v`, whose SHA-256 is recorded in
`same_candidate_binding_receipt.json`. The gold mapped netlist is
`ct_rtu_pst_preg_entry_gold.mapped.v`.

## Metrics

| axis | gold | candidate | interpretation |
| --- | --- | --- | --- |
| Selected Sky130 area, top with deps | `3510.867200` | `3482.089600` | lower area in the selected flow |
| OpenSTA max data-arrival | `3.23 ns` | `2.91 ns` | lower delay under the package SDC |
| OpenSTA estimated total power | `1.38e-04 nW` | `1.35e-04 nW` | lower estimate under fixed activity |

The power row is an OpenSTA liberty estimate with
`set_power_activity -global -activity 0.1 -duty 0.5`. It is not signoff power
and not measured workload activity.

## Proof Control

The positive proof path is the accepted `ct_rtu_pst_preg_entry` lifecycle
relation proof: passive debug bridge plus closed lifecycle-encoding relation
induction under reset-first. The proof negative control is
`ct_rtu_pst_preg_entry_gate_dbg_mutant.v`; the same relation proof rejects it
with `proof did fail`.

## Metric Red-Control

`ct_rtu_pst_preg_entry_metric_negative.mapped.v` is a metric-only red control:
it adds a long buffer chain on `x_cur_state_dealloc` in the mapped candidate
netlist. It is deliberately worse on all three metric axes:

| axis | red-control |
| --- | --- |
| Selected Sky130 area, top with deps | `5711.728000` |
| OpenSTA max data-arrival | `11.88 ns` |
| OpenSTA estimated total power | `2.40e-04 nW` |

This file is not a proof candidate. It exists to prove the metric checks can
turn red on a worse mapped netlist.

## Replay

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
- Module-local `ct_rtu_pst_preg_entry` only.
- Correctness proof scope remains visible-output equivalence under reset-first
  through passive debug bridge plus lifecycle-encoding relation induction.
- OpenSTA estimated power is not signoff power and not workload-measured power.
- This is not whole RTU, whole C910, BOOM, ISA, memory-consistency,
  speculation, composed optimization, or whole-chip authority.
