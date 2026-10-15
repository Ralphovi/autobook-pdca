#!/usr/bin/env bash
# Gating C4 check (autobook-pdca#12): can Autobook's test environment still IMPORT every
# test module once this patch is applied?
#
# pytest imports every test module before it filters by marker, so one module that imports
# a package the test environment's `book` image lacks breaks the whole container run — book
# tests included — even when that module holds no book test. The other gates never see it:
# C4-ci and C4-verify install dependencies on the host, and C4-verify starts the container
# only for bundles whose own tests are book or paperless tests. Ralphovi/autobook#51 and
# #52 passed every gate here and failed GitHub's `testenv` workflow that way.
#
# Runs only when the patch changes what the container imports or is built from:
# pyproject.toml, a test module (tests/**.py) or testenv/. Then it builds the lane's `book`
# image from the worktree (the image installs the tree's [project].dependencies,
# Ralphovi/autobook#53) and runs `pytest --collect-only` over the whole suite in it — no
# services are started, so it costs the image build plus a few seconds.
#
#   patch touches none of those paths      -> exit 0, nothing to check
#   no Docker, or no testenv/ in the tree   -> exit 77, UNVERIFIABLE (machine, not patch)
#   image build fails / docker can't run    -> exit 77, UNVERIFIABLE
#   collection succeeds (or collects none)  -> exit 0, PASS
#   collection errors                       -> exit 1, C4 FAIL
set -euo pipefail

BUNDLE="${PDCA_BUNDLE:?run from the driver — \$PDCA_BUNDLE must be set}"
WT="${PDCA_WORKTREE:?worktree isolation must be on — \$PDCA_WORKTREE must be set}"
PATCH="$BUNDLE/patch.diff"

[ -s "$PATCH" ] || { echo "PDCA-EVIDENCE: no patch.diff, nothing to check"; exit 0; }

mapfile -t CHANGED < <(cd "$WT" && git apply --numstat "$PATCH" | awk -F'\t' '{print $3}')
TRIGGER=()
for p in "${CHANGED[@]}"; do
  case "$p" in
    pyproject.toml|tests/*.py|testenv/*) TRIGGER+=("$p") ;;
  esac
done
if [ "${#TRIGGER[@]}" -eq 0 ]; then
  echo "PDCA-EVIDENCE: the patch changes no dependency, test module or testenv/ file — nothing to check"
  exit 0
fi

if [ ! -f "$WT/testenv/compose.yaml" ]; then
  echo "PDCA-UNVERIFIABLE: no testenv/ in the worktree, so the test environment's imports can't be checked (changed: ${TRIGGER[*]})"
  exit 77
fi
if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
  echo "PDCA-UNVERIFIABLE: no Docker with compose, so the test environment's imports can't be checked (changed: ${TRIGGER[*]})"
  exit 77
fi

# One compose project per lane, the same one C4-verify uses, so the image is shared.
compose=(docker compose -f "$WT/testenv/compose.yaml" -p "autobook-pdca-l${PDCA_LANE:-0}")
log="$(mktemp)"
trap 'rm -f "$log"' EXIT

echo "== test environment: building the book image from the worktree (changed: ${TRIGGER[*]})"
if ! AUTOBOOK_SRC="$WT" "${compose[@]}" build -q book >"$log" 2>&1; then
  tail -n 30 "$log"
  echo "PDCA-UNVERIFIABLE: the book image did not build — check the output above; a dependency that can't be installed fails the host's dependency sync too"
  exit 77
fi

echo "== test environment: pytest --collect-only over the whole suite"
rc=0
AUTOBOOK_SRC="$WT" "${compose[@]}" run --rm --no-deps -T book \
  python3 -m pytest -p no:cacheprovider -q --collect-only -o addopts="--strict-markers" >"$log" 2>&1 || rc=$?
tail -n 30 "$log"

case "$rc" in
  0) echo "PDCA-EVIDENCE: PASS — the test environment imports every test module" ;;
  5) echo "PDCA-EVIDENCE: PASS — the test environment collected no tests, and nothing failed to import" ;;
  12[5-7]) echo "PDCA-UNVERIFIABLE: docker could not run the book container (exit $rc) — a machine problem, not evidence about the patch"
       exit 77 ;;
  *) echo "PDCA-EVIDENCE: C4 FAIL — pytest could not collect the suite in the test environment (exit $rc); a test module imports something the book image lacks, so GitHub's testenv workflow fails too"
     exit 1 ;;
esac
