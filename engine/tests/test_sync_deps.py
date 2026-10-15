"""Engine tests: lib/sync_deps.py keeps the instance venv in step with the worktree's
declared dependencies (autobook-pdca#5).

Run: python3 -m unittest discover -s engine/tests
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

INSTANCE = Path(__file__).resolve().parents[2]
SYNC = INSTANCE / "engine" / "scripts" / "lib" / "sync_deps.py"


class SyncDeps(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.wt = self.tmp / "wt"
        self.wt.mkdir()
        self.stamp = self.tmp / "venv" / ".deps.json"
        self.calls = self.tmp / "pip-calls"
        # A fake pip that records its arguments and exits with $FAKE_PIP_RC.
        self.pip = self.tmp / "fake-pip"
        self.pip.write_text(f'#!/bin/sh\necho "$@" >> "{self.calls}"\nexit "${{FAKE_PIP_RC:-0}}"\n')
        self.pip.chmod(0o755)

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _pyproject(self, deps: list[str]) -> None:
        body = '[project]\nname = "demo"\nversion = "0"\ndependencies = [' + \
               ", ".join(f'"{d}"' for d in deps) + "]\n"
        (self.wt / "pyproject.toml").write_text(body, encoding="utf-8")

    def _run(self, rc: int = 0) -> subprocess.CompletedProcess[str]:
        env = {**os.environ, "PDCA_PIP": str(self.pip), "FAKE_PIP_RC": str(rc)}
        return subprocess.run([sys.executable, str(SYNC), str(self.wt), str(self.stamp)],
                              env=env, capture_output=True, text=True)

    def _pip_calls(self) -> list[str]:
        return self.calls.read_text().splitlines() if self.calls.exists() else []

    def test_no_declared_dependencies_is_a_no_op(self) -> None:
        self._pyproject([])
        self.assertEqual(self._run().returncode, 0)
        self.assertEqual(self._pip_calls(), [])
        self.assertFalse(self.stamp.exists())

    def test_new_dependencies_are_installed_once(self) -> None:
        self._pyproject(["scikit-learn>=1.5"])
        self.assertEqual(self._run().returncode, 0)
        self.assertEqual(self._pip_calls(), ["install --quiet scikit-learn>=1.5"])
        self.assertEqual(json.loads(self.stamp.read_text()), ["scikit-learn>=1.5"])
        self.assertEqual(self._run().returncode, 0)          # unchanged → no second install
        self.assertEqual(len(self._pip_calls()), 1)

    def test_changed_dependencies_are_reinstalled(self) -> None:
        self._pyproject(["scikit-learn>=1.5"])
        self._run()
        self._pyproject(["scikit-learn>=1.5", "httpx"])
        self._run()
        self.assertEqual(len(self._pip_calls()), 2)
        self.assertIn("httpx", self._pip_calls()[-1])

    def test_failed_install_is_unverifiable_and_not_recorded(self) -> None:
        self._pyproject(["scikit-learn>=1.5"])
        r = self._run(rc=1)
        self.assertEqual(r.returncode, 77, r.stdout)
        self.assertIn("PDCA-UNVERIFIABLE", r.stdout)
        self.assertFalse(self.stamp.exists())


if __name__ == "__main__":
    unittest.main()
