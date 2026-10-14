#!/usr/bin/env python3
"""Read a pytest JUnit XML report and print what actually EXECUTED.

Prints one line: `<ran> <failed> <errors> <collect_errors>`.

  ran            test cases that executed to a verdict (passed or failed an assertion)
  failed         of those, how many failed
  errors         cases that errored in setup/teardown — they never reached a verdict
  collect_errors modules pytest could not import/collect (no test in them ran at all)

A missing or unreadable report prints `0 0 0 0`: no evidence, never a pass.
"""

from __future__ import annotations

import sys
import xml.etree.ElementTree as ET


def count(path: str) -> tuple[int, int, int, int]:
    try:
        root = ET.parse(path).getroot()
    except (OSError, ET.ParseError):
        return 0, 0, 0, 0
    ran = failed = errors = collect = 0
    for case in root.iter("testcase"):
        kinds = {child.tag: child for child in case}
        if "skipped" in kinds:
            continue
        if "error" in kinds:
            if "collection failure" in (kinds["error"].get("message") or ""):
                collect += 1
            else:
                errors += 1
            continue
        ran += 1
        if "failure" in kinds:
            failed += 1
    return ran, failed, errors, collect


if __name__ == "__main__":
    print(*count(sys.argv[1]))
