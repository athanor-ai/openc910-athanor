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
