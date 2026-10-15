"""Install the target worktree's declared dependencies into the instance venv when they
changed since the last install (autobook-pdca#5).

C4-verify runs the bundle's tests on `.venv/bin/python3` with the worktree's `src/` on
PYTHONPATH. `make install` installs Autobook's dependencies once, so a patch that adds
one (scikit-learn, an HTTP client …) would otherwise fail its own green leg with an
ImportError that is the machine's fault, not the patch's.

Usage: sync_deps.py <worktree> <stamp-file>
Reads <worktree>/pyproject.toml ([project].dependencies + the `dev` extra). If the list is
empty or equals the one recorded in <stamp-file>, does nothing. Otherwise installs it with
$PDCA_PIP (default: this interpreter's pip) and records it. Exit 0 = in sync; exit 77 =
install failed (the gate then reports UNVERIFIABLE, never a verdict). A lock file next to
the stamp serialises lanes that share the venv.
"""
from __future__ import annotations

import fcntl
import json
import os
import shlex
import subprocess
import sys
import tomllib
from pathlib import Path


def declared(worktree: Path) -> list[str]:
    path = worktree / "pyproject.toml"
    if not path.is_file():
        return []
    project = tomllib.loads(path.read_text(encoding="utf-8")).get("project", {})
    deps = list(project.get("dependencies", []))
    deps += list(project.get("optional-dependencies", {}).get("dev", []))
    return sorted(set(deps))


def main() -> int:
    worktree, stamp = Path(sys.argv[1]), Path(sys.argv[2])
    deps = declared(worktree)
    if not deps:
        return 0
    stamp.parent.mkdir(parents=True, exist_ok=True)
    with open(stamp.with_suffix(".lock"), "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            recorded = json.loads(stamp.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            recorded = None
        if recorded == deps:
            return 0
        pip = shlex.split(os.environ.get("PDCA_PIP", "")) or [sys.executable, "-m", "pip"]
        print(f"== dependency sync: installing {' '.join(deps)}")
        r = subprocess.run([*pip, "install", "--quiet", *deps])
        if r.returncode != 0:
            print(f"PDCA-UNVERIFIABLE: could not install the worktree's dependencies "
                  f"(pip exit {r.returncode}): {' '.join(deps)} — a machine problem, not "
                  f"evidence about the patch; fix the network or run `make install`")
            return 77
        stamp.write_text(json.dumps(deps), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
