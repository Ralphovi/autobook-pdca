"""Engine tests: check-threat-model-touch.sh (advisory T2, autobook-pdca#3).

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
SCRIPT = INSTANCE / "engine" / "scripts" / "check-threat-model-touch.sh"


def _diff(paths: list[str]) -> str:
    return "".join(f"diff --git a/{p} b/{p}\nnew file mode 100644\n--- /dev/null\n+++ b/{p}\n@@ -0,0 +1 @@\n+x\n"
                   for p in paths)


class ThreatModelTouch(unittest.TestCase):
    def setUp(self) -> None:
        self.bundle = Path(tempfile.mkdtemp())

    def tearDown(self) -> None:
        shutil.rmtree(self.bundle, ignore_errors=True)

    def _run(self, paths: list[str] | None) -> subprocess.CompletedProcess[str]:
        if paths is not None:
            (self.bundle / "patch.diff").write_text(_diff(paths), encoding="utf-8")
        return subprocess.run(["bash", str(SCRIPT)], cwd=INSTANCE, capture_output=True, text=True,
                              env={**os.environ, "PDCA_BUNDLE": str(self.bundle)})

    def test_unrelated_change_passes(self) -> None:
        r = self._run(["src/autobook/normalise.py", "tests/test_normalise.py"])
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertIn("no security-relevant path", r.stdout)

    def test_security_change_without_threat_model_is_unverifiable(self) -> None:
        r = self._run(["src/autobook/applier/write.py", "tests/test_applier.py"])
        self.assertEqual(r.returncode, 77, r.stdout)
        self.assertIn("src/autobook/applier/write.py", r.stdout)

    def test_hard_rules_change_counts_as_security_relevant(self) -> None:
        r = self._run(["AGENTS.md"])
        self.assertEqual(r.returncode, 77, r.stdout)

    def test_0002_surfaces_count_as_security_relevant(self) -> None:
        for path in ("src/autobook/pipeline/bill_matcher.py", "src/autobook/pipeline/admission.py",
                     "src/autobook/book/exporter.py", "src/autobook/pipeline/staging.py"):
            with self.subTest(path=path):
                r = self._run([path])
                self.assertEqual(r.returncode, 77, r.stdout)

    def test_security_change_with_threat_model_passes(self) -> None:
        r = self._run(["src/autobook/adapter/redact.py", ".oss-scanner/threat_model.md"])
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertIn("threat model updated", r.stdout)

    def test_missing_patch_passes(self) -> None:
        r = self._run(None)
        self.assertEqual(r.returncode, 0, r.stdout)


if __name__ == "__main__":
    unittest.main()
