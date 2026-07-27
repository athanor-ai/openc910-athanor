# Athanor Artifacts

This directory holds replayable Athanor receipt packages for OpenC910 targets.

Each package should include:

- exact gold and candidate RTL used by the receipt,
- a `receipt.json` file,
- pinned logs for the selected proof and measurement checks,
- a package-local `replay.sh`, and
- `SHA256SUMS` covering the package files.

Packages that back promoted metric-result rows must bind area, timing, and
power/toggle evidence to the same candidate and selected flow. Proof-only or
screening packages can remain here, but they do not become public result rows
until that metric-closure package exists.

Run:

```bash
python3 athanor/verify_public_receipts.py
```

This verifier checks receipt JSON parsing and package hash parity. It does not
rerun the formal tools; use each package's `replay.sh` for that.

## Grandfathered identity strings in hashed artifacts

Some SHA-pinned receipt files in this tree contain internal reviewer and
author attributions from the reviews that produced them (fields such as
`created_by`, `assignee`, `reviewer`, `review_ruling`, and
`independent_review_summary` — e.g. in `ct_fifo/receipt.json` and
`rtu_rob_entry_candidate1/receipt.json`). They are left byte-unmodified on
purpose: rewriting published, hash-pinned evidence would invalidate receipts a
reader may already have checked. The packet producer no longer emits such
strings into hashed artifacts, and new packets get no exemption. This is the
only grandfathered identity class in this repository's hashed artifacts;
internal working-directory names were already masked before publication here.

A machine-checked enumeration of the grandfathered set (one line per packet)
ships with the labelling-honesty gate; this note is the human-readable
disclosure of the class it covers.
