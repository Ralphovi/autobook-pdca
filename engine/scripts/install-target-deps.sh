#!/usr/bin/env bash
# [install].extra_bootstrap: put the tools the gates need into this instance's .venv —
# nox (C4-ci delegates to `nox -s gate`), pytest (C4-verify runs the bundle's tests
# directly), and Autobook's own runtime + dev dependencies — but NOT Autobook itself.
# C4-verify runs the target's tests from a patched worktree with its src/ on PYTHONPATH;
# an installed copy of the package would be a second, stale autobook that could shadow
# the code under test.
#
# Reads ../autobook/pyproject.toml (the sibling checkout), so a dependency added there is
# picked up by the next `make install`. Idempotent. Ported from eduralph/nl-shell-pdca.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
target="${AUTOBOOK_REPO:-$here/../autobook}"
py="$here/.venv/bin/python3"

"$py" -m pip install --quiet nox pytest

if [ ! -f "$target/pyproject.toml" ]; then
  echo "install-target-deps: $target/pyproject.toml not found — installed nox and pytest only;" \
       "re-run 'make install' once ../autobook is checked out" >&2
  exit 0
fi

mapfile -t deps < <("$py" - "$target/pyproject.toml" <<'PY'
import sys, tomllib
project = tomllib.load(open(sys.argv[1], "rb"))["project"]
for dep in project.get("dependencies", []) + project.get("optional-dependencies", {}).get("dev", []):
    print(dep)
PY
)
if [ "${#deps[@]}" -eq 0 ]; then
  echo "install-target-deps: nox, pytest (autobook declares no dependencies yet)"
  exit 0
fi
echo "install-target-deps: nox, pytest, ${deps[*]}"
"$py" -m pip install --quiet "${deps[@]}"
