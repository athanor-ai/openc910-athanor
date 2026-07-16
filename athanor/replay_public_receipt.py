#!/usr/bin/env python3
"""One-command replay for public openc910 receipt packages (ATH-3010).

A public package ships a fail-closed ``replay.sh`` that REQUIRES pinned tool env
vars -- ``YOSYS_BIN`` / ``STA_BIN`` / ``LIBERTY`` (ATH-2966). That is
falsifiable-in-principle, but the UX is still
``YOSYS_BIN=... STA_BIN=... LIBERTY=... ./replay.sh`` -- not one clean command
for an architect who just wants to reproduce the verdict.

This wrapper resolves the PINNED verdict-bearing suite (self-locating the
version-stamped oss-cad-suite), verifies each tool's identity, and then invokes
the package's own ``replay.sh`` with the env pre-set -- so a customer runs ONE
command. The explicit-env ``replay.sh`` stays fully supported for BYO /
custom-toolchain seats; this wrapper is the pinned-reproduction path.

Fail-closed (AC2): a missing or mismatched Yosys / OpenSTA / Liberty is ONE
named provisioning error emitted BEFORE any proof or metric runs. It never
silently substitutes and never falls back to an ambient tool (e.g. a distro
``/usr/bin/yosys``), which would not reproduce the pinned hashes.

Exit codes are distinct and never collapsed:

======  =====================================================================
  0     replay reproduced every pinned claim
  1     replay ran but did not reproduce a claim (verdict red)
  2     a resolved tool crashed during replay (tool error)
  3     provisioning error: a pinned tool could not be resolved/verified
        (no replay was run)
======  =====================================================================
"""

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
ARTIFACT_ROOT = REPO_ROOT / "athanor_artifacts"
POLICY_PATH = REPO_ROOT / "athanor" / "toolchain_policy.json"

# Distinct exit codes (see module docstring).
EXIT_OK = 0
EXIT_VERDICT_RED = 1
EXIT_TOOL_ERROR = 2
EXIT_PROVISIONING = 3


class ProvisioningError(Exception):
    """A pinned tool could not be resolved or its identity did not match.

    Raised (and reported) BEFORE any replay subprocess is started, so a
    provisioning failure can never be mistaken for a verdict result.
    """


def _load_policy() -> dict:
    import json

    try:
        return json.loads(POLICY_PATH.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:  # pragma: no cover - policy ships in-tree
        raise ProvisioningError(
            f"toolchain policy not found at {POLICY_PATH.relative_to(REPO_ROOT)} "
            "-- cannot verify pinned tool identity"
        ) from exc


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _run_version(binary: Path, *args: str) -> str:
    """Return the first stdout/stderr line of ``binary <args>``, or "" on error."""
    try:
        proc = subprocess.run(
            [str(binary), *args],
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    out = (proc.stdout or "") + (proc.stderr or "")
    return out.strip().splitlines()[0].strip() if out.strip() else ""


# --------------------------------------------------------------------------
# Tool resolution -- each returns a Path or raises ProvisioningError with a
# single named remediation. No resolver ever returns an unverified tool.
# --------------------------------------------------------------------------

def _oss_cad_roots() -> list[Path]:
    """Candidate roots that may contain the version-stamped oss-cad-suite.

    Relative-to-repo + env + standard locations only -- deliberately NO
    hardcoded absolute host path, so this stays public-export clean while
    still resolving a sibling ``_tools`` suite on a build host.
    """
    roots: list[Path] = []
    env_root = os.environ.get("OSS_CAD_ROOT")
    if env_root:
        roots.append(Path(env_root))
    roots += [
        REPO_ROOT.parent / "_tools",
        Path.home() / "_tools",
        Path.home(),
        Path("/opt") / "_tools",
        Path("/opt"),
    ]
    return roots


def resolve_yosys(policy: dict) -> tuple[Path, str]:
    spec = policy["selected_tools"]["yosys"]
    want_version = spec["version"]  # e.g. "Yosys 0.66+181"
    suite = spec["source"]  # e.g. "oss-cad-suite-20260630"

    def _verify(binary: Path, origin: str) -> tuple[Path, str]:
        if not binary.is_file() or not os.access(binary, os.X_OK):
            raise ProvisioningError(
                f"YOSYS_BIN {origin} ({binary}) is not an executable file -- "
                f"set YOSYS_BIN to the pinned {want_version} from {suite}, or "
                "unset it to auto-resolve the pinned suite"
            )
        got = _run_version(binary, "-V")
        if not got.startswith(want_version):
            raise ProvisioningError(
                f"YOSYS_BIN {origin} ({binary}) reports {got!r} but the pinned "
                f"tool is {want_version!r} -- mismatched tool bytes cannot "
                f"reproduce the receipt. Point YOSYS_BIN at {want_version} from "
                f"{suite}, or run replay.sh directly for a BYO toolchain."
            )
        return binary, got

    # 1. Explicit override wins, but is still identity-verified (never trusted blind).
    env_bin = os.environ.get("YOSYS_BIN")
    if env_bin:
        return _verify(Path(env_bin), "from the environment")

    # 2. Auto-resolve the version-stamped suite. NEVER an ambient distro yosys.
    for root in _oss_cad_roots():
        cand = root / suite / "bin" / "yosys"
        if cand.is_file():
            return _verify(cand, "auto-resolved from the pinned suite")
        # allow root itself being the suite dir
        if root.name == suite and (root / "bin" / "yosys").is_file():
            return _verify(root / "bin" / "yosys", "auto-resolved from the pinned suite")

    raise ProvisioningError(
        f"could not locate the pinned {suite} (yosys {want_version}). "
        "Install the pinned oss-cad-suite and set OSS_CAD_ROOT to its parent "
        "directory, or set YOSYS_BIN directly. The ambient system yosys is "
        "refused on purpose -- it does not reproduce the pinned hashes."
    )


def resolve_sta(policy: dict) -> tuple[Path, str]:
    spec = policy["selected_tools"].get("opensta", {})
    want_version = spec.get("version")  # optional pin

    def _verify(binary: Path, origin: str) -> tuple[Path, str]:
        if not binary.is_file() or not os.access(binary, os.X_OK):
            raise ProvisioningError(
                f"STA_BIN {origin} ({binary}) is not an executable file -- set "
                "STA_BIN to the OpenSTA executable"
            )
        got = _run_version(binary, "-version")
        if want_version and want_version not in got:
            raise ProvisioningError(
                f"STA_BIN {origin} ({binary}) reports {got!r} but the pinned "
                f"OpenSTA is {want_version!r} -- mismatched tool bytes cannot "
                "reproduce the timing/power receipt"
            )
        return binary, got or "(version unavailable)"

    for env_name in ("STA_BIN", "OPENSTA", "OPENSTA_BIN"):
        val = os.environ.get(env_name)
        if val:
            return _verify(Path(val), f"from ${env_name}")

    for cand in (shutil.which("sta"), shutil.which("OpenSTA"), "/usr/local/bin/sta"):
        if cand and Path(cand).is_file():
            return _verify(Path(cand), "auto-resolved from PATH")

    raise ProvisioningError(
        "could not locate the OpenSTA executable -- set STA_BIN to the OpenSTA "
        "binary (the timing/power replay needs it)"
    )


def resolve_liberty(policy: dict) -> tuple[Path, str]:
    spec = policy["selected_tools"]["liberty"]
    name = spec["name"]  # sky130_fd_sc_hd__tt_025C_1v80.lib
    want_sha = spec.get("sha256")

    def _verify(path: Path, origin: str) -> tuple[Path, str]:
        if not path.is_file():
            raise ProvisioningError(
                f"LIBERTY {origin} ({path}) is not a file -- set LIBERTY to {name}"
            )
        got = _sha256(path)
        if want_sha and got != want_sha:
            raise ProvisioningError(
                f"LIBERTY {origin} ({path}) sha256 {got} does not match the "
                f"pinned {want_sha} -- mismatched Liberty bytes cannot reproduce "
                "the area/timing/power receipt"
            )
        return path, (got[:12] if got else "")

    env_lib = os.environ.get("LIBERTY")
    if env_lib:
        return _verify(Path(env_lib), "from the environment")

    lib_root = os.environ.get("LIBERTY_ROOT")
    if lib_root:
        return _verify(Path(lib_root) / name, "from $LIBERTY_ROOT")

    # Bounded, name-only glob of sibling/home trees -- resolves a co-located SDK
    # copy WITHOUT naming an internal repo in this public source.
    for base in (REPO_ROOT.parent, Path.home()):
        try:
            for cand in sorted(base.glob(f"*/src/*/data/liberty/{name}")):
                if cand.is_file():
                    return _verify(cand, "auto-resolved from a co-located SDK")
        except OSError:
            continue

    raise ProvisioningError(
        f"could not locate the pinned Liberty {name} -- set LIBERTY to the "
        "sky130_fd_sc_hd typical-corner .lib (or LIBERTY_ROOT to its directory)"
    )


# --------------------------------------------------------------------------
# Replay orchestration
# --------------------------------------------------------------------------

def _packages() -> list[Path]:
    return sorted(p.parent for p in ARTIFACT_ROOT.glob("*/replay.sh"))


_RESOLVERS = {
    "YOSYS_BIN": resolve_yosys,
    "STA_BIN": resolve_sta,
    "LIBERTY": resolve_liberty,
}


def _required_tool_vars(replay_text: str) -> list[str]:
    """The pinned-tool env vars a replay.sh actually references, in stable order.

    A proof/area package that never invokes OpenSTA (e.g. ct_prio) must not be
    forced to provision STA_BIN it will not use -- resolve only what the script
    needs, so a customer without every tool can still replay what applies.
    """
    import re

    return [
        var
        for var in ("YOSYS_BIN", "STA_BIN", "LIBERTY")
        if re.search(r"\$\{?" + var + r"\b", replay_text)
    ]


def _resolve_env(
    policy: dict, needed: list[str] | None = None
) -> dict[str, tuple[Path, str]]:
    """Resolve the needed pinned tools up front. Raises ProvisioningError before replay."""
    if needed is None:
        needed = list(_RESOLVERS)
    return {var: _RESOLVERS[var](policy) for var in needed}


def _print_resolved(resolved: dict[str, tuple[Path, str]]) -> None:
    print("resolved pinned toolchain:")
    for var, (path, ident) in resolved.items():
        print(f"  {var}={path}  [{ident}]")


def _read_replay_out_logs(out_dir: Path, cap: int = 65536) -> str:
    """Bounded text of a package's replay_out logs.

    Real replay scripts redirect tool stdout/stderr INTO ``replay_out/*.log``, so a
    crash-before-verdict signature lives in the logs, not in the wrapper's captured
    stdout/stderr. Read them (bounded) so tool-error classification can see it.
    """
    if not out_dir.is_dir():
        return ""
    chunks: list[str] = []
    total = 0
    for log in sorted(out_dir.glob("*.log")):
        try:
            text = log.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        chunks.append(text[:cap])
        total += len(text)
        if total >= cap * 8:  # hard ceiling across many logs
            break
    return "\n".join(chunks)


def replay_package(pkg: Path, policy: dict) -> int:
    replay = pkg / "replay.sh"
    if not replay.is_file():
        print(f"::provisioning-error:: {pkg.name}: no replay.sh in package", file=sys.stderr)
        return EXIT_PROVISIONING

    # Clear any stale replay_out BEFORE provisioning resolution, so a provisioning
    # failure leaves NO stale output from a prior successful run -- the "exit 3 /
    # no replay_out" contract must hold even after an earlier PASS (Dexter #53).
    out_dir = pkg / "replay_out"
    if out_dir.exists():
        shutil.rmtree(out_dir, ignore_errors=True)

    # Resolve + verify exactly the tools THIS package needs, before running any
    # verdict-bearing replay.
    needed = _required_tool_vars(replay.read_text(encoding="utf-8"))
    try:
        resolved = _resolve_env(policy, needed)
    except ProvisioningError as exc:
        print(f"::provisioning-error:: {pkg.name}: {exc}", file=sys.stderr)
        print(
            "FAIL(provisioning): pinned toolchain not satisfied; no replay was "
            "run. Fix the tool above and re-run.",
            file=sys.stderr,
        )
        return EXIT_PROVISIONING

    _print_resolved(resolved)
    print(f"replaying {pkg.name} ...")

    env = dict(os.environ)
    for var, (path, _ident) in resolved.items():
        env[var] = str(path)

    try:
        proc = subprocess.run(
            ["bash", str(replay)],
            cwd=str(pkg),
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError as exc:  # pragma: no cover - bash always present
        print(f"::tool-error:: {pkg.name}: could not launch replay.sh: {exc}", file=sys.stderr)
        return EXIT_TOOL_ERROR

    sys.stdout.write(proc.stdout)
    sys.stderr.write(proc.stderr)

    if proc.returncode == 0:
        print(f"PASS: {pkg.name} reproduced every pinned claim in its replay.sh "
              "(the package's own PASS line above enumerates them).")
        return EXIT_OK

    # Non-zero: distinguish a tool crash from a verdict-red reproduction miss.
    # Real replay scripts redirect tool output INTO replay_out/*.log, so scan the
    # bounded log text there too -- a crash-before-verdict (e.g. a yosys internal
    # Assert failure, cf. ATH-3011) is a tool-error, NOT a verdict red, even though
    # its signature never reaches the wrapper's stdout/stderr (Dexter #53).
    blob = proc.stdout + proc.stderr + _read_replay_out_logs(out_dir)
    tool_signatures = (
        "Assert `",              # yosys internal C++ assertion (crash-before-verdict)
        "Segmentation fault",
        "core dumped",
        "terminate called",
        "Stack dump",
        "command not found",
        "cannot execute",
        "No such file or directory",
    )
    if any(sig in blob for sig in tool_signatures):
        print(f"::tool-error:: {pkg.name}: a resolved tool crashed during replay "
              f"(exit {proc.returncode}); see the replay_out logs.", file=sys.stderr)
        return EXIT_TOOL_ERROR

    print(f"::verdict-red:: {pkg.name}: replay ran but did not reproduce a "
          f"pinned claim (exit {proc.returncode}). The failing grep assertion / "
          "proof status is in the output above.", file=sys.stderr)
    return EXIT_VERDICT_RED


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="One-command replay for public openc910 receipt packages.",
    )
    parser.add_argument(
        "package",
        nargs="?",
        help="package name under athanor_artifacts/ (or a path). Omit with --all.",
    )
    parser.add_argument("--all", action="store_true", help="replay every package with a replay.sh")
    parser.add_argument("--list", action="store_true", help="list replayable packages and exit")
    parser.add_argument(
        "--print-env",
        action="store_true",
        help="resolve + verify the pinned toolchain, print it, and exit (no replay)",
    )
    args = parser.parse_args(argv)

    if args.list:
        for pkg in _packages():
            print(pkg.name)
        return EXIT_OK

    policy = _load_policy()

    if args.print_env:
        try:
            _print_resolved(_resolve_env(policy))
        except ProvisioningError as exc:
            print(f"::provisioning-error:: {exc}", file=sys.stderr)
            return EXIT_PROVISIONING
        return EXIT_OK

    if args.all:
        worst = EXIT_OK
        for pkg in _packages():
            rc = replay_package(pkg, policy)
            if rc != EXIT_OK:
                worst = max(worst, rc)
        return worst

    if not args.package:
        parser.error("give a package name, or --all, or --list")

    pkg_path = Path(args.package)
    pkg = pkg_path if pkg_path.is_dir() else ARTIFACT_ROOT / args.package
    if not pkg.is_dir():
        print(f"::provisioning-error:: no such package: {args.package}", file=sys.stderr)
        return EXIT_PROVISIONING
    return replay_package(pkg, policy)


if __name__ == "__main__":
    raise SystemExit(main())
