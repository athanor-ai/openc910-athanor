# Athanor evidence layout (openc910-athanor)

This directory and `athanor_artifacts/` hold the receipts behind every row in the
top-level [`README.md`](../README.md). The rule is simple: a result is a
**candidate** until it has a replayable, hash-bound package here that a
non-author can re-run. This document defines the package format so every
contributor's artifacts are consistent and customer-verifiable.

## Artifact package format

Each accepted or candidate row has a package at `athanor_artifacts/<row_name>/`
(e.g. `athanor_artifacts/ct_prio/`). A package MUST contain:

| File | Purpose |
| --- | --- |
| `SOURCE_DIFF.patch` (or `*_gold.v` + `*_gate.v`) | The bounded RTL change: original vs optimized. |
| `*_gate_mutant.v` (or `*_exposed.v`) | The deliberately-broken candidate used by the non-vacuity control. |
| `area_*.json` / `reports/` | Selected-flow PPA (cells, area, timing) on the pinned toolchain. |
| `equiv_*.ys` + `equiv_*.log` (or the induction/miter script + log) | The equivalence / temporal-induction proof and its replay. |
| `*_manifest.json` | The row's claim: subject, proof method, scope, assumptions, PPA deltas, control result. |
| `COMMANDS.md` | Exact commands to reproduce the package from the RTL. |
| `SHA256SUMS` | `sha256` of every other file in the package. The hash binding. |

Where a proof is Lean-backed rather than (or in addition to) a Yosys miter, the
package also carries the `.lean` obligation and its discharge log, and the
manifest names the theorem and whether it is discharged or carries a `sorry`
with a stated route to closure.

## Manifest fields (the honest-scope contract)

Every `*_manifest.json` states the claim precisely so a green proof cannot be
read as more than it is:

- `subject`: the exact module/gate proven.
- `proof_method`: e.g. `yosys_sat_kinduction`, `sby_pdr`, `lean_theorem`.
- `scope`: `visible_output_miter` vs `full_internal_state`; `module_local` vs `whole_core`.
- `assumptions`: named (e.g. `reset_first`), each with whether removal was tested to break the proof.
- `ppa`: before/after, with the metric and toolchain.
- `nonvacuity`: the control (broken candidate) and that it fails the same proof.

## Replay

```
# verify every package's hashes + manifest consistency
python3 athanor/verify_public_receipts.py

# reproduce one package from RTL
cd athanor_artifacts/<row_name> && sh COMMANDS.md   # (commands are listed, run the ones for your toolchain)
```

`SHA256SUMS` binds the package: `sha256sum -c SHA256SUMS` inside a package must
pass. The verifier also checks each manifest's scope/assumption fields are
present, so a row cannot silently drop its scope statement.

## Toolchain

The selected toolchain (pinned Yosys + Sky130 standard-cell library and their
versions) is recorded in `athanor/toolchain_policy.json`. PPA and equivalence
numbers are only comparable within one recorded toolchain; cross-toolchain
numbers are not added together.

## Evidence bar (summary)

A row is promoted from candidate to accepted only with: a bounded RTL diff;
selected-flow PPA; an equivalence or formal proof on the exact subject with its
scope stated; a non-vacuity control that a broken candidate fails; replay hashes;
and non-author cold review. Module-local rows are never presented as whole-core
claims, and local wins are not summed without an integrated end-to-end receipt.
