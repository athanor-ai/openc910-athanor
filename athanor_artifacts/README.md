# Athanor Artifacts

This directory holds replayable Athanor receipt packages for OpenC910 targets.

Each package should include:

- exact gold and candidate RTL used by the receipt,
- a `receipt.json` file,
- pinned logs for the selected proof and measurement checks, with any missing
  PPA axes named in the package,
- a package-local `replay.sh`, and
- `SHA256SUMS` covering the package files.

Run:

```bash
python3 athanor/verify_public_receipts.py
```

This verifier checks receipt JSON parsing and package hash parity. It does not
rerun the formal tools; use each package's `replay.sh` for that.
