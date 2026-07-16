"""Bite tests for the one-command replay wrapper (ATH-3010).

The wrapper resolves the PINNED verdict-bearing toolchain and fails closed
BEFORE any proof/metric runs if a tool is missing or its bytes do not match.
These bites hide or corrupt a required tool and assert the wrapper fails loud
before the verdict-bearing replay -- never a silent substitution, never an
ambient tool, and never a replay that ran against the wrong bytes.

The bites are hermetic: they build fake tools + a fake policy in a tmp dir, so
they do not depend on the real pinned oss-cad-suite being present on the runner.
"""

from __future__ import annotations

import hashlib
import stat
from pathlib import Path

import pytest

from athanor import replay_public_receipt as rp

PINNED_YOSYS = "Yosys 0.66+181"
PINNED_STA = "2.2.0"


def _make_tool(path: Path, version_line: str) -> Path:
    """Write an executable fake tool that echoes a version line on any arg."""
    path.write_text(f'#!/usr/bin/env bash\necho "{version_line}"\n')
    path.chmod(path.stat().st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)
    return path


def _policy_for(liberty: Path) -> dict:
    return {
        "selected_tools": {
            "yosys": {"version": PINNED_YOSYS, "source": "oss-cad-suite-20260630",
                      "required_env": "YOSYS_BIN"},
            "opensta": {"version": PINNED_STA, "required_env": "STA_BIN"},
            "liberty": {"name": liberty.name,
                        "sha256": hashlib.sha256(liberty.read_bytes()).hexdigest(),
                        "required_env": "LIBERTY"},
        }
    }


@pytest.fixture()
def liberty(tmp_path: Path) -> Path:
    lib = tmp_path / "sky130_fd_sc_hd__tt_025C_1v80.lib"
    lib.write_text("library(demo) { /* pinned bytes */ }\n")
    return lib


# --- yosys identity ---------------------------------------------------------

def test_yosys_wrong_version_fails_closed(tmp_path, liberty, monkeypatch):
    fake = _make_tool(tmp_path / "yosys", "Yosys 0.9 (git sha1 deadbeef)")
    monkeypatch.setenv("YOSYS_BIN", str(fake))
    with pytest.raises(rp.ProvisioningError) as exc:
        rp.resolve_yosys(_policy_for(liberty))
    assert "YOSYS_BIN" in str(exc.value) and PINNED_YOSYS in str(exc.value)
    assert "Yosys 0.9" in str(exc.value)  # the mismatched bytes are named


def test_yosys_correct_version_resolves(tmp_path, liberty, monkeypatch):
    fake = _make_tool(tmp_path / "yosys", f"{PINNED_YOSYS} (git sha1 afe6b18f2)")
    monkeypatch.setenv("YOSYS_BIN", str(fake))
    got, ident = rp.resolve_yosys(_policy_for(liberty))
    assert got == fake and ident.startswith(PINNED_YOSYS)


def test_yosys_missing_suite_fails_closed_not_ambient(tmp_path, liberty, monkeypatch):
    # No YOSYS_BIN, and the only candidate roots are empty -> must fail closed,
    # NOT fall back to an ambient system yosys.
    monkeypatch.delenv("YOSYS_BIN", raising=False)
    monkeypatch.delenv("OSS_CAD_ROOT", raising=False)
    empty = tmp_path / "empty"
    empty.mkdir()
    monkeypatch.setattr(rp, "_oss_cad_roots", lambda: [empty])
    with pytest.raises(rp.ProvisioningError) as exc:
        rp.resolve_yosys(_policy_for(liberty))
    assert "ambient" in str(exc.value).lower()


# --- liberty identity -------------------------------------------------------

def test_liberty_sha_mismatch_fails_closed(tmp_path, liberty, monkeypatch):
    corrupt = tmp_path / "corrupt.lib"
    corrupt.write_text("library(demo) { /* TAMPERED */ }\n")
    monkeypatch.setenv("LIBERTY", str(corrupt))
    with pytest.raises(rp.ProvisioningError) as exc:
        rp.resolve_liberty(_policy_for(liberty))
    assert "sha256" in str(exc.value) and "does not match" in str(exc.value)


def test_liberty_correct_sha_resolves(liberty, monkeypatch):
    monkeypatch.setenv("LIBERTY", str(liberty))
    got, _ident = rp.resolve_liberty(_policy_for(liberty))
    assert got == liberty


# --- opensta identity -------------------------------------------------------

def test_sta_wrong_version_fails_closed(tmp_path, liberty, monkeypatch):
    fake = _make_tool(tmp_path / "sta", "1.0.0")
    monkeypatch.setenv("STA_BIN", str(fake))
    with pytest.raises(rp.ProvisioningError) as exc:
        rp.resolve_sta(_policy_for(liberty))
    assert "STA_BIN" in str(exc.value) and PINNED_STA in str(exc.value)


# --- AC4 headline: provisioning failure runs NO verdict-bearing replay ------

def test_provisioning_failure_runs_no_replay(tmp_path, liberty, monkeypatch):
    """The headline AC4 guarantee: a missing/mismatched tool fails loud BEFORE
    the package's replay.sh is ever executed."""
    pkg = tmp_path / "pkg"
    pkg.mkdir()
    sentinel = tmp_path / "REPLAY_RAN"
    (pkg / "replay.sh").write_text(
        f'#!/usr/bin/env bash\n"$YOSYS_BIN" -V\ntouch \'{sentinel}\'\n'
    )

    # A real provisioning failure: YOSYS_BIN points at a non-existent file.
    monkeypatch.setenv("YOSYS_BIN", str(tmp_path / "no_such_yosys"))
    monkeypatch.setenv("STA_BIN", str(_make_tool(tmp_path / "sta", PINNED_STA)))
    monkeypatch.setenv("LIBERTY", str(liberty))

    rc = rp.replay_package(pkg, _policy_for(liberty))

    assert rc == rp.EXIT_PROVISIONING
    assert not sentinel.exists(), "replay.sh executed despite a provisioning failure"
    assert not (pkg / "replay_out").exists()


def test_only_needed_tools_are_resolved(tmp_path, liberty, monkeypatch):
    """A proof/area package that never invokes OpenSTA must NOT be forced to
    provision STA_BIN -- resolve only the tools its replay.sh references."""
    replay_text = '#!/usr/bin/env bash\necho "$YOSYS_BIN ${LIBERTY}"\n'
    assert rp._required_tool_vars(replay_text) == ["YOSYS_BIN", "LIBERTY"]

    fake_yosys = _make_tool(tmp_path / "yosys", f"{PINNED_YOSYS} (git sha1 x)")
    monkeypatch.setenv("YOSYS_BIN", str(fake_yosys))
    monkeypatch.setenv("LIBERTY", str(liberty))
    monkeypatch.delenv("STA_BIN", raising=False)
    # STA is deliberately unresolvable; it must not be required for this package.
    monkeypatch.setattr(rp.shutil, "which", lambda _n: None)

    resolved = rp._resolve_env(_policy_for(liberty),
                               rp._required_tool_vars(replay_text))
    assert set(resolved) == {"YOSYS_BIN", "LIBERTY"}


def test_stale_replay_out_cleared_on_provisioning_failure(tmp_path, liberty, monkeypatch):
    """Dexter #53 hold 1: a provisioning failure must leave NO stale replay_out,
    even after a prior successful run left one behind -- the exit-3 / no-output
    customer contract has to survive a re-run."""
    pkg = tmp_path / "pkg"
    pkg.mkdir()
    (pkg / "replay.sh").write_text('#!/usr/bin/env bash\n"$YOSYS_BIN" -V\n')
    stale = pkg / "replay_out"
    stale.mkdir()
    (stale / "old.replay.log").write_text("stale output from a prior PASS\n")

    monkeypatch.setenv("YOSYS_BIN", str(tmp_path / "no_such_yosys"))
    rc = rp.replay_package(pkg, _policy_for(liberty))

    assert rc == rp.EXIT_PROVISIONING
    assert not stale.exists(), "stale replay_out survived a provisioning failure"


def test_tool_crash_in_replay_log_is_tool_error_not_verdict(tmp_path, liberty, monkeypatch):
    """Dexter #53 hold 2: a tool crash whose signature is REDIRECTED into a
    replay_out log (not the wrapper's stdout/stderr) must classify as tool-error
    (exit 2), not verdict-red. This is the real failure shape -- replay scripts
    send tool output to replay_out/*.log."""
    pkg = tmp_path / "pkg"
    pkg.mkdir()
    (pkg / "replay.sh").write_text(
        "#!/usr/bin/env bash\n"
        '"$YOSYS_BIN" -V >/dev/null 2>&1 || true\n'
        "mkdir -p replay_out\n"
        "cat > replay_out/tool.replay.log <<'LOG'\n"
        "ERROR: Assert `count_id(wire->name) == 0' failed in kernel/rtlil.cc:2886.\n"
        "LOG\n"
        "exit 1\n"
    )
    monkeypatch.setenv("YOSYS_BIN", str(_make_tool(tmp_path / "yosys", f"{PINNED_YOSYS} x")))
    rc = rp.replay_package(pkg, _policy_for(liberty))
    assert rc == rp.EXIT_TOOL_ERROR


def test_reproduction_mismatch_stays_verdict_red(tmp_path, liberty, monkeypatch):
    """Control for the above: a normal reproduction mismatch (no crash signature
    in the logs) must stay verdict-red, so tool-error detection does not over-fire
    on every nonzero replay."""
    pkg = tmp_path / "pkg"
    pkg.mkdir()
    (pkg / "replay.sh").write_text(
        "#!/usr/bin/env bash\n"
        '"$YOSYS_BIN" -V >/dev/null 2>&1 || true\n'
        "mkdir -p replay_out\n"
        "echo 'Chip area 19467.4 (expected 19456.1) -- assertion mismatch' > replay_out/map.replay.log\n"
        "exit 1\n"
    )
    monkeypatch.setenv("YOSYS_BIN", str(_make_tool(tmp_path / "yosys", f"{PINNED_YOSYS} x")))
    rc = rp.replay_package(pkg, _policy_for(liberty))
    assert rc == rp.EXIT_VERDICT_RED


def test_exit_codes_are_distinct() -> None:
    # provisioning / verdict-red / tool-error / ok must never collapse.
    assert len({rp.EXIT_OK, rp.EXIT_VERDICT_RED, rp.EXIT_TOOL_ERROR,
                rp.EXIT_PROVISIONING}) == 4
