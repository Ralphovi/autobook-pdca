"""Engine tests: run-verify.sh (C4) honours its contract.

Each case builds a throwaway pytest project shaped like Autobook (src/ layout, NO pytest
`pythonpath`, strict markers with `applier` declared), commits a base, applies a bundle patch to the working tree — the
state the driver hands a gate — and runs the script as the driver would: cwd = the
instance root, $PDCA_BUNDLE and $PDCA_WORKTREE exported. One case per row of the C4 truth
table in run-verify.sh. Skips when no interpreter the scripts would use has pytest.

Run: python3 -m unittest discover -s engine/tests
"""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path

INSTANCE = Path(__file__).resolve().parents[2]
VERIFY = INSTANCE / "engine" / "scripts" / "run-verify.sh"


def _script_python() -> str:
    venv = INSTANCE / ".venv" / "bin" / "python3"
    return str(venv) if venv.exists() else shutil.which("python3") or "python3"


def _has_pytest() -> bool:
    return subprocess.run([_script_python(), "-c", "import pytest"],
                          capture_output=True).returncode == 0


PYPROJECT = """\
[project]
name = "demo"
version = "0"

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "-ra --strict-markers --strict-config"
markers = ["applier: requires the system python3-gnucash"]
"""

BUGGY = "def add(a, b):\n    return a - b\n"
FIXED = "def add(a, b):\n    return a + b\n"
ADD_TEST = "from demo.calc import add\n\n\ndef test_add():\n    assert add(2, 3) == 5\n"


@unittest.skipUnless(_has_pytest(), "pytest not importable by the gate interpreter")
class Gates(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.wt = self.tmp / "wt"
        self.bundle = self.tmp / "bundle"
        self.bundle.mkdir()
        self._write({
            "pyproject.toml": PYPROJECT,
            "src/demo/__init__.py": "",
            "src/demo/calc.py": BUGGY,
            "tests/test_existing.py": "def test_truth():\n    assert True\n",
        })
        self._git("init", "-q", "-b", "main")
        self._git("add", "-A")
        self._git("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "-m", "base")

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)

    # -- helpers --------------------------------------------------------------------
    def _write(self, files: dict[str, str]) -> None:
        for rel, body in files.items():
            p = self.wt / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(body, encoding="utf-8")

    def _git(self, *args: str) -> str:
        return subprocess.run(["git", "-C", str(self.wt), *args], check=True,
                              capture_output=True, text=True).stdout

    def _patch(self, files: dict[str, str]) -> None:
        """Change the worktree, record the diff as patch.diff, leave it applied."""
        self._write(files)
        self._git("add", "-A")
        (self.bundle / "patch.diff").write_text(self._git("diff", "--cached"), encoding="utf-8")
        self._git("reset", "-q")

    def _run(self, script: Path) -> subprocess.CompletedProcess[str]:
        env = {**os.environ, "PDCA_BUNDLE": str(self.bundle), "PDCA_WORKTREE": str(self.wt)}
        return subprocess.run(["bash", str(script)], cwd=INSTANCE, env=env,
                              capture_output=True, text=True)

    def assertVerdict(self, result, rc: int, needle: str) -> None:
        out = result.stdout + result.stderr
        self.assertEqual(result.returncode, rc, out)
        self.assertIn(needle, out)

    # -- C4 truth table -------------------------------------------------------------
    def test_genuine_red_then_green_passes_and_restores_the_tree(self) -> None:
        self._patch({"src/demo/calc.py": FIXED, "tests/test_add.py": ADD_TEST})
        self.assertVerdict(self._run(VERIFY), 0, "C4 PASS")
        # Later gates must see base + the full patch again.
        self.assertEqual((self.wt / "src/demo/calc.py").read_text(), FIXED)

    def test_test_green_without_the_fix_fails(self) -> None:
        self._patch({"src/demo/calc.py": FIXED,
                     "tests/test_add.py": "def test_unrelated():\n    assert 1 + 1 == 2\n"})
        self.assertVerdict(self._run(VERIFY), 1, "still green WITHOUT the fix")

    def test_green_leg_red_fails(self) -> None:
        self._patch({"src/demo/calc.py": "def add(a, b):\n    return a * b\n",
                     "tests/test_add.py": ADD_TEST})
        self.assertVerdict(self._run(VERIFY), 1, "red (or not importable) WITH the fix")

    def test_import_failure_on_red_leg_is_unverifiable_not_a_pass(self) -> None:
        self._patch({"src/demo/fresh.py": "def new():\n    return 1\n",
                     "tests/test_fresh.py":
                         "from demo.fresh import new\n\n\ndef test_new():\n    assert new() == 1\n"})
        self.assertVerdict(self._run(VERIFY), 77, "failed to IMPORT")

    def test_zero_tests_is_unverifiable(self) -> None:
        self._patch({"src/demo/calc.py": FIXED, "tests/test_add.py": "# no tests yet\n"})
        self.assertVerdict(self._run(VERIFY), 77, "0 tests ran with the fix applied")

    def test_skipped_test_is_unverifiable(self) -> None:
        self._patch({"src/demo/calc.py": FIXED,
                     "tests/test_add.py": "import pytest\n\n\n@pytest.mark.skip\n" + ADD_TEST.split("\n\n\n", 1)[1]})
        self.assertVerdict(self._run(VERIFY), 77, "0 tests ran with the fix applied")

    def test_patch_without_a_test_is_unverifiable(self) -> None:
        self._patch({"src/demo/calc.py": FIXED})
        self.assertVerdict(self._run(VERIFY), 77, "patch ships no test")

    def test_docs_and_test_only_patch_is_unverifiable(self) -> None:
        self._patch({"docs/notes.md": "x\n", "tests/test_add.py": ADD_TEST})
        self.assertVerdict(self._run(VERIFY), 77, "no behavioral production change")

    def test_conftest_is_not_mistaken_for_production(self) -> None:
        self._patch({"tests/conftest.py": "X = 1\n", "tests/test_add.py": ADD_TEST})
        self.assertVerdict(self._run(VERIFY), 77, "no behavioral production change")

    def test_missing_patch_is_unverifiable(self) -> None:
        self.assertVerdict(self._run(VERIFY), 77, "no patch.diff")

    # -- Autobook additions ---------------------------------------------------------
    def test_book_test_without_a_test_environment_is_unverifiable(self) -> None:
        # The throwaway project has no testenv/, so the applier-marked test runs nowhere.
        self._patch({"src/demo/calc.py": FIXED,
                     "tests/test_add.py": "import pytest\n\n\n@pytest.mark.applier\n"
                                          + ADD_TEST.split("\n\n\n", 1)[1]})
        result = self._run(VERIFY)
        self.assertVerdict(result, 77, "0 tests ran with the fix applied")
        self.assertIn("they are not run", result.stdout)

    def test_applier_only_test_is_deselected_and_unverifiable(self) -> None:
        self._patch({"src/demo/calc.py": FIXED,
                     "tests/test_add.py": "import pytest\n\n\n@pytest.mark.applier\n"
                                          + ADD_TEST.split("\n\n\n", 1)[1]})
        self.assertVerdict(self._run(VERIFY), 77, "0 tests ran with the fix applied")

    def test_repo_config_is_not_mistaken_for_production(self) -> None:
        self._patch({"pyproject.toml": PYPROJECT + "\n# touched\n", "noxfile.py": "X = 1\n",
                     "tests/test_add.py": ADD_TEST})
        self.assertVerdict(self._run(VERIFY), 77, "no behavioral production change")


if __name__ == "__main__":
    unittest.main()
