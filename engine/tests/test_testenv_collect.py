"""Engine tests: check-testenv-collect.sh (gating C4, autobook-pdca#12).

A fake `docker` on PATH stands in for Docker, so these run anywhere; the real thing was
checked by hand against Ralphovi/autobook#52's tree (FAIL without Ralphovi/autobook#53,
PASS with it).

Run: python3 -m unittest discover -s engine/tests
"""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

INSTANCE = Path(__file__).resolve().parents[2]
SCRIPT = INSTANCE / "engine" / "scripts" / "check-testenv-collect.sh"

FAKE_DOCKER = """\
#!/usr/bin/env bash
echo "AUTOBOOK_SRC=${AUTOBOOK_SRC:-} $*" >> "$FAKE_DOCKER_LOG"
case " $* " in
  *" compose version "*) exit "${FAKE_COMPOSE_RC:-0}" ;;
  *" build "*) echo "build output"; exit "${FAKE_BUILD_RC:-0}" ;;
  *" run "*) echo "collect output"; exit "${FAKE_RUN_RC:-0}" ;;
esac
exit 0
"""


def _diff(paths: list[str]) -> str:
    return "".join(f"diff --git a/{p} b/{p}\nnew file mode 100644\n--- /dev/null\n+++ b/{p}\n@@ -0,0 +1 @@\n+x\n"
                   for p in paths)


class TestenvCollect(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.bundle = self.tmp / "bundle"
        self.wt = self.tmp / "wt"
        self.bin = self.tmp / "bin"
        for d in (self.bundle, self.wt, self.bin):
            d.mkdir()
        docker = self.bin / "docker"
        docker.write_text(FAKE_DOCKER, encoding="utf-8")
        docker.chmod(0o755)
        self.log = self.tmp / "docker.log"

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _testenv(self) -> None:
        (self.wt / "testenv").mkdir()
        (self.wt / "testenv" / "compose.yaml").write_text("services: {}\n", encoding="utf-8")

    def _run(self, paths: list[str], **fake: str) -> subprocess.CompletedProcess[str]:
        (self.bundle / "patch.diff").write_text(_diff(paths), encoding="utf-8")
        env = {**os.environ, "PDCA_BUNDLE": str(self.bundle), "PDCA_WORKTREE": str(self.wt),
               "PDCA_LANE": "2", "PATH": f"{self.bin}:{os.environ['PATH']}",
               "FAKE_DOCKER_LOG": str(self.log), **fake}
        return subprocess.run(["bash", str(SCRIPT)], cwd=INSTANCE, env=env,
                              capture_output=True, text=True)

    def assertVerdict(self, result, rc: int, needle: str) -> None:
        out = result.stdout + result.stderr
        self.assertEqual(result.returncode, rc, out)
        self.assertIn(needle, out)

    def _calls(self) -> str:
        return self.log.read_text(encoding="utf-8") if self.log.exists() else ""

    def test_patch_without_dependency_or_test_change_never_starts_docker(self) -> None:
        self._testenv()
        self.assertVerdict(self._run(["src/autobook/pipeline/x.py", "docs/a.md"]), 0, "nothing to check")
        self.assertEqual(self._calls(), "")

    def test_missing_testenv_is_unverifiable(self) -> None:
        self.assertVerdict(self._run(["pyproject.toml"]), 77, "no testenv/ in the worktree")

    def test_missing_docker_compose_is_unverifiable(self) -> None:
        self._testenv()
        self.assertVerdict(self._run(["pyproject.toml"], FAKE_COMPOSE_RC="1"), 77, "no Docker with compose")

    def test_failed_image_build_is_unverifiable(self) -> None:
        self._testenv()
        result = self._run(["pyproject.toml"], FAKE_BUILD_RC="1")
        self.assertVerdict(result, 77, "did not build")
        self.assertIn("build output", result.stdout)

    def test_clean_collection_passes_on_the_lane_project_and_worktree(self) -> None:
        self._testenv()
        self.assertVerdict(self._run(["pyproject.toml", "tests/test_knn.py"]), 0, "PASS")
        calls = self._calls()
        self.assertIn(f"AUTOBOOK_SRC={self.wt} compose -f {self.wt}/testenv/compose.yaml -p autobook-pdca-l2 build -q book", calls)
        self.assertIn("run --rm --no-deps -T book python3 -m pytest", calls)
        self.assertIn("--collect-only", calls)

    def test_collection_error_fails(self) -> None:
        self._testenv()
        result = self._run(["tests/test_knn.py"], FAKE_RUN_RC="2")
        self.assertVerdict(result, 1, "C4 FAIL")
        self.assertIn("collect output", result.stdout)

    def test_nothing_collected_passes(self) -> None:
        self._testenv()
        self.assertVerdict(self._run(["tests/test_x.py"], FAKE_RUN_RC="5"), 0, "collected no tests")

    def test_docker_run_failure_is_unverifiable(self) -> None:
        self._testenv()
        self.assertVerdict(self._run(["pyproject.toml"], FAKE_RUN_RC="125"), 77, "could not run the book container")

    def test_testenv_change_triggers_the_check(self) -> None:
        self._testenv()
        self.assertVerdict(self._run(["testenv/book/Dockerfile"]), 0, "PASS")
        self.assertIn("build -q book", self._calls())

    def test_missing_patch_passes_with_nothing_to_check(self) -> None:
        r = subprocess.run(["bash", str(SCRIPT)], cwd=INSTANCE, capture_output=True, text=True,
                           env={**os.environ, "PDCA_BUNDLE": str(self.bundle), "PDCA_WORKTREE": str(self.wt)})
        self.assertVerdict(r, 0, "no patch.diff")


if __name__ == "__main__":
    unittest.main()
