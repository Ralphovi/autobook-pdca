"""The security-review advisory leaf (autobook-pdca#3, ported from eduralph/nl-shell-pdca).

No new orchestration code: the leaf composes from the advisory-leaf mechanism (#64). This
locks in the *shipped config*: pdca.toml carries the leaf, it is always on (no `when` — a
planner-written field must not route a patch away from it), its role prompt exists for both
vendors, and a cycle writes `check-advisory-security-review.md` whose NEEDS-HUMAN finding
lands in SUMMARY §6. Run from the project root:
    PYTHONPATH=src python -m unittest discover -s tests
"""

from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

from pdca_harness import driver, signoff
from pdca_harness.config import Config

from tests.test_driver_slice import TOY_BRIEF, _stub_config

ROOT = Path(__file__).resolve().parents[1]
LEAF_ID = "security-review"


def _shipped_leaf() -> dict:
    leaves = [a for a in Config.load(ROOT).advisory_leaves if a.get("id") == LEAF_ID]
    if len(leaves) != 1:
        raise AssertionError(f"pdca.toml must carry exactly one [[leaves.advisory]] "
                             f"id = {LEAF_ID!r}; found {len(leaves)}")
    return leaves[0]


class ShippedConfig(unittest.TestCase):
    def test_leaf_is_always_on(self) -> None:
        self.assertNotIn("when", _shipped_leaf())

    def test_role_prompt_exists_for_both_vendors(self) -> None:
        self.assertTrue((ROOT / "agents" / f"{LEAF_ID}.md").is_file())
        self.assertTrue((ROOT / ".claude" / "agents" / f"{LEAF_ID}.md").is_file())

    def test_claude_argv_names_the_agent(self) -> None:
        leaf = _shipped_leaf()
        if leaf.get("family") == "claude":
            argv = leaf["argv"]
            self.assertEqual(argv[argv.index("--agent") + 1], LEAF_ID)

    def test_prompt_reads_the_threat_model(self) -> None:
        body = (ROOT / "agents" / f"{LEAF_ID}.md").read_text(encoding="utf-8")
        self.assertIn("$PDCA_TARGET/.oss-scanner/threat_model.md", body)


class CycleSlice(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.cfg = _stub_config(self.tmp)
        self.d = self.cfg.bundle("SEC")
        self.d.mkdir(parents=True)
        shutil.copyfile(TOY_BRIEF, self.d / "brief.md")

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_runs_beside_other_advisory_leaves_and_routes_to_section6(self) -> None:
        leaf = dict(_shipped_leaf(), mode="stub")  # offline, whatever the shipped mode
        self.cfg.advisory_leaves = [
            {"id": "adversary", "role": "x", "mode": "stub"},
            {"id": "code-review", "role": "x", "mode": "stub"},
            leaf,
        ]
        driver.run_issue(self.d, self.cfg)
        for leaf_id in ("adversary", "code-review", LEAF_ID):
            self.assertTrue((self.d / f"check-advisory-{leaf_id}.md").exists(), leaf_id)
        summary = (self.d / "SUMMARY.md").read_text(encoding="utf-8")
        self.assertIn(f"Advisory — {LEAF_ID}", summary)
        items = signoff.open_needs_human(self.d / "SUMMARY.md")
        self.assertTrue(any(LEAF_ID in it for it in items), items)


if __name__ == "__main__":
    unittest.main()
