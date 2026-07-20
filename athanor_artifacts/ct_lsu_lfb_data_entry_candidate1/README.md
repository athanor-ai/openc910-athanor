# C910 ct_lsu_lfb_data_entry Candidate 1

Status: scoped replayable evidence packet (bounded public receipt, module-local,
`customer_ready=false` under the current bar). The current product (certified main
`0a569cdb7`) classifies this as a GAP with recommendation
`add_composition_edge_or_stronger_proof`. Timing: measured/improved (3.66ns to
3.49ns, WNS/TNS 0). Toggle: flat (4254 to 4254, 0.0%). Generic cells: regress
1166 to 1174 (+0.69%) -- not a current-product area win. Replay: ok. Named gaps:
proof inconclusive (`yosys_equiv_setup_gap` / `combinational_state_check_failed:
gold design is not proven stateless`); sim unavailable (`design_compile_failed`);
negative-control has no discriminator (`bite=false`, `bite_kind=no_discriminator`).
Missing gates: `equivalence_proof`, `metric_negative_control`. Not whole-C910, ISA,
composed, or customer-ready authority.

This packet records an LSU line-fill-buffer data-entry decode simplification.
The candidate replaces the eight-way case decode for `lfb_data_entry_addr_id`
with a one-hot shift from `lfb_data_entry_biu_id[2:0]`.

## Metrics

All metrics below are from the same selected Sky130 mapping flow and the same
candidate netlist recorded in `same_candidate_binding_receipt.json`.

| Axis | Gold | Candidate | Result |
| --- | ---: | ---: | --- |
| Selected Sky130 area | `19467.420800` | `19456.160000` | lower area |
| OpenSTA max data-arrival | `8.17 ns` | `8.14 ns` | small lower data-arrival delta under the package SDC |
| OpenSTA estimated total power | `1.33e-03 nW` | `1.33e-03 nW` | flat at reported precision under fixed activity |

The power row is an OpenSTA liberty estimate with
`set_power_activity -global -activity 0.1 -duty 0.5`. It is not signoff power
and not measured workload activity.

## Proof

The same-state Yosys equivalence check closes with `560` proven equivalence
cells and `0` unproven cells after `equiv_simple -seq 8`. The shipped
same-state executor path was then rerun on this package after the C910
normalization fix: it proved the candidate with `560/560` equivalence cells and
rejected the shifted-address mutant with `8` unproven cells.

This is still recorded as `lean_fallback`: no discharged Lean theorem binds this
exact candidate netlist yet. The current customer-ready authority is the scoped
module-local Yosys proof plus biting controls and same-candidate-bound PPA
receipts.

A real bridge-obligation package is committed at `lean_bridge_obligation.json`.
It is SHA-bound to the gold/candidate RTL, the same-state proof receipt, and
the shifted-address mutant bite, and is intended as input to the Lean theorem
batch worker. It does not change this package to `lean_authority`; the receipt
stays `lean_fallback` until a kernel-checked theorem is audited and stamped.

## Negative Controls

`ct_lsu_lfb_data_entry_gate_proof_mutant.v` is a proof negative control. It
changes the one-hot shift index, and the same equivalence check leaves `8`
address-ID equivalence cells unproven.

`ct_lsu_lfb_data_entry_metric_negative.mapped.v` is a metric-only red control.
It deliberately worsens the measured candidate on all three axes:

| Axis | Red-control value |
| --- | ---: |
| Selected Sky130 area | `23926.697600` |
| OpenSTA max data-arrival | `8.15 ns` |
| OpenSTA estimated total power | `1.47e-03 nW` |

This file is not a proof candidate. It exists to prove the metric checks can
turn red on regressions.

## Replay

One command reproduces every claim in this package. It resolves the pinned
verdict-bearing toolchain (the version-stamped oss-cad-suite Yosys, OpenSTA, and
the sky130 Liberty), verifies each tool's identity, and fails loud with one named
provisioning error before any proof or metric if a tool is missing or its bytes
do not match:

```bash
python3 ../../athanor/replay_public_receipt.py ct_lsu_lfb_data_entry_candidate1
```

BYO / custom toolchain: set the pinned tool paths explicitly and run this
package's `replay.sh` directly. `replay.sh` requires each var and never
substitutes an ambient tool:

```bash
YOSYS_BIN=/path/to/oss-cad-suite-20260630/bin/yosys \
STA_BIN=/path/to/sta \
LIBERTY=/path/to/sky130_fd_sc_hd__tt_025C_1v80.lib \
  ./replay.sh
```

`replay.sh` writes generated logs and Tcl files under ignored `replay_out/`.

## Boundaries

- Scoped evidence only (not current-bar customer-ready) for the scoped module-local same-state proof and
  same-candidate-bound selected Sky130/OpenSTA metric packet.
- Module-local `ct_lsu_lfb_data_entry` only.
- Same-state module equivalence under the checked RTL model is the proof
  subject.
- The timing movement is small, and the OpenSTA estimated-power result is flat
  at reported precision.
- OpenSTA estimated power is not signoff power and not workload-measured power.
- Not whole LSU, whole C910/BOOM, ISA, memory consistency, speculation
  recovery, composed optimization, or whole-chip authority.
