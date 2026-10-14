#!/usr/bin/env bash
# Per-fix correctness gate (C4) for autobook-pdca — target: Ralphovi/autobook (pytest).
# Ported from eduralph/nl-shell-pdca (autobook-pdca#3).
#
# Wired from pdca.toml as a bundle-scoped GATING check. The driver has already
# reconstructed base + patch.diff in $PDCA_WORKTREE, so this script proves red→green by
# reverting and re-applying the patch's PRODUCTION hunks in place:
#   green leg — the bundle's tests with the fix applied MUST pass;
#   red leg   — with only the production hunks reverted they MUST fail.
# Exits 0 iff both hold. The base exports ($PDCA_BASE / $PDCA_VERIFY_BASE /
# $PDCA_BRIEF_BASE) need no handling here: the driver prepares the tree on the right base
# before any gate runs, so this script never resolves a base itself.
#
# Each leg is judged by TWO facts — pytest's exit code AND how many tests actually ran,
# read from its JUnit XML report (engine/scripts/lib/junit_count.py) — never the exit
# code alone (engine/README.md, "The two gate shapes that matter"):
#
#   leg    exit  ran  collect-error  verdict
#   -----  ----  ---  -------------  ----------------------------------------------------
#   green   any   0       no         UNVERIFIABLE (77): nothing ran, no evidence
#   green  !=0    -       -          C4 FAIL: red (or not importable) WITH the fix
#   red     any   -      yes         UNVERIFIABLE (77): the test module failed to import
#                                    once the fix was reverted — usually a test importing
#                                    API the patch adds; nothing was measured
#   red     any   0       no         UNVERIFIABLE (77): nothing ran
#   red      0   >0       no         C4 FAIL: green WITHOUT the fix — no red, no repro
#   red    !=0   >0       no         PASS (when >0 of them failed): the genuine red
#
# Classification first (issue #165): a patch with no test, or whose only non-test changes
# are non-behavioral (docs/, .github/, .oss-scanner/, Markdown, LICENSE/NOTICE/DCO) has
# no revert that can go red: PDCA-UNVERIFIABLE, exit 77 (→ SUMMARY §6, non-gating).
# Autobook adds its repo config (pyproject.toml, noxfile.py, typos.toml, editor and
# agent files) to that set: reverting it can't change what a test sees.
#
# Applier tests never run here. `-m "not applier"` mirrors Autobook's own gate: they need
# the system python3-gnucash and a restored copy of a book, never an unattended driver.
# A bundle whose only test is an applier test therefore runs 0 tests: UNVERIFIABLE.
# ---------------------------------------------------------------------------------
# The published C4 contract, verbatim from the template skeleton (pdca-harness v0.59.0).
# tests/test_verify_red_leg.py and tests/test_verify_base.py still assert this wording is
# present in THIS file, so a filled-in gate that drops it turns `make check` red.
# TEMPORARY, pending eduralph/pdca-harness#507 — the same stopgap pdca-pdca carries. The
# rule does not depend on this block: engine/README.md states the same contract. Once #507
# scopes those assertions to the template checkout, delete this block.
# ---------------------------------------------------------------------------------
# The driver exports $PDCA_BUNDLE = the bundle dir (results/issue_<id>/), which
# holds patch.diff and the brief that names the test. It also exports, when set:
#   - $PDCA_WORKTREE   — the tree Do edited (worktree isolation, #94); run/reset here.
#   - $PDCA_BASE / $PDCA_VERIFY_BASE / $PDCA_BRIEF_BASE — the base to reset to before
#       applying patch.diff. The driver sets EXACTLY ONE of these for the PER-FIX VERIFIER
#       row — this script, wired as tier "C4" above — and NONE for any other configured
#       gate (issue #474): the test base must never diverge from the base publish will
#       commit to, and only the row that resets to it has any use for it. Each is already
#       a fully-qualified remote-tracking ref (`<remote>/<branch>`) — use it as-is,
#       never `origin/$VAR` (that doubles the remote).
#         * $PDCA_BASE (issue #54) — the brief's `Onto branch`. Publish appends the fix as a
#           commit to that existing PR head, so the gate must prove red->green on IT.
#         * $PDCA_VERIFY_BASE (issue #273) — the wave's folded integration branch
#           (`origin/pdca-integration/<base>-r<key>`, the run's own line, #591) for a wave>0
#           bundle in a dependency batch, so a dependent verifies against base+prereqs.
#           Resetting to the brief's origin base instead would false-fail "patch does not
#           apply — stale" for a dependent that shares a file with its prereq, or measure
#           red->green against a tree LACKING it.
#         * $PDCA_BRIEF_BASE (issue #387) — the ordinary case: the brief's own
#           `Repo + branch target` base (or the project default branch when it names none),
#           resolved by the driver with the SAME parser publish uses. Do NOT re-derive it by
#           parsing brief.md in shell: that parse is subtle (a backticked ref counts only at
#           the START of the field, so `main (feature branch \`feat/x\`)` means `main`) and
#           a re-derivation drifts from the base publish commits to — the divergence #235
#           and #262 fixed in Python and this export removes from shell.
#       Resolve as: $PDCA_BASE > $PDCA_VERIFY_BASE > your own override > $PDCA_BRIEF_BASE.
# The contract this script must enforce, exiting 0 iff BOTH hold:
#   - WITHOUT the fix applied, the bundle's test FAILS (red) — proves the repro.
#   - WITH the fix (patch.diff) applied, the bundle's test PASSES (green).
# That validates THIS change, not the whole suite (see engine/README.md).
#
# Typical shape (pseudocode — replace with your project's apply/run/revert):
#   1. read the test path from $PDCA_BUNDLE/brief.md
#   2. revert the production change, run the test  -> expect a REAL red: a test that RAN
#      and failed (judge it by the two facts below, never by the exit code alone)
#   3. apply $PDCA_BUNDLE/patch.diff, run the test -> expect PASS (green)
#   4. exit 0 on red-then-green, non-zero otherwise
#
# JUDGE EVERY LEG BY TWO FACTS: the runner's exit code AND how many tests actually ran.
# A test runner exits non-zero for two unrelated reasons — the test RAN and failed (the red
# leg's proof), or NO test ran at all (it failed to compile/import/collect, the runner could
# not find it, the runner itself died). An exit code cannot tell those apart, so a leg judged
# on the exit code alone reports PASS for a bundle whose test never executed. That is an
# everyday shape, not a corner case: reverting the fix also removes any symbol the fix
# introduced, so a test that calls one cannot even build on the red leg.
# Capture BOTH per run: the exit code, and a COUNT of executed tests parsed from the runner's
# own machine-readable report (TAP, JUnit XML, `--format json`, `python -m unittest -v`, …).
# Never infer that count from the exit code.
#
#   exit code | tests ran | what it means -> what to report
#   ----------+-----------+---------------------------------------------------------------
#    0        |  0        | nothing ran -> PDCA-UNVERIFIABLE (77): no evidence either way
#    0        | >0        | test PASSED -> green leg: OK; red leg: C4 FAIL (green without
#             |           |                the fix — the test does not capture the defect)
#    non-zero | >0        | test FAILED -> red leg: the red you want; green leg: C4 FAIL
#    non-zero |  0        | nothing ran -> PDCA-UNVERIFIABLE (77), NEVER PASS: the runner
#             |           |                died before/while collecting, so its non-zero
#             |           |                exit proves nothing about the defect
#
# Keep the two "nothing ran" cases distinguishable in the reason you print — the human
# reading §6 needs different things from each: `no test executed (runner exited 0: nothing
# was selected — wrong test path or filter?)` vs `no test executed (runner exited <rc>: the
# test did not build/import — e.g. it calls a symbol the reverted fix added)`.
# THE RULE, for every leg you add here and for every other verification step: a step in
# which no test ran is UNVERIFIABLE — exit 77 / `PDCA-UNVERIFIABLE: <reason>` (-> SUMMARY §6
# NEEDS-HUMAN, non-gating) — never a pass and never a fail. A gate never turns "no evidence"
# into a verdict.
#
# CLASSIFY THE PATCH FIRST (issue #165). If the patch's only non-test change is a
# NON-BEHAVIORAL file a project must update but that can't move the test — a translation
# manifest / file-registration list / generated asset (e.g. po/POTFILES.{in,skip}) — there
# is nothing to revert that would go red. Emit `PDCA-UNVERIFIABLE: <reason>` and exit 77
# (-> SUMMARY §6 NEEDS-HUMAN, non-gating) instead of a red->green the bundle is guaranteed
# to fail (a false C4 fail for a verify-first test-only fix). Keep the non-production set as
# a config list of path globs. See engine/README.md (§The two gate shapes that matter).
# ---------------------------------------------------------------------------------
set -euo pipefail

BUNDLE="${PDCA_BUNDLE:?run from the driver — \$PDCA_BUNDLE must be set}"
WT="${PDCA_WORKTREE:?worktree isolation must be on — \$PDCA_WORKTREE must be set}"
PATCH="$BUNDLE/patch.diff"
ENGINE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The instance venv holds pytest and Autobook's dependencies (but never Autobook itself:
# engine/scripts/install-target-deps.sh), so the code under test is the worktree's src/.
# Autobook's pytest config doesn't put src/ on sys.path (its nox sessions install the
# package), so run_tests does, via PYTHONPATH.
PY="$ENGINE/../../.venv/bin/python3"
[ -x "$PY" ] || PY="$(command -v python3)"

[ -s "$PATCH" ] || { echo "PDCA-UNVERIFIABLE: bundle has no patch.diff"; exit 77; }

cd "$WT"

mapfile -t CHANGED < <(git apply --numstat "$PATCH" | awk -F'\t' '{print $3}')

TESTS=() PROD=()
for p in "${CHANGED[@]}"; do
  case "$p" in
    tests/conftest.py|tests/*/conftest.py) ;;                          # test support (* spans /)
    tests/test_*.py|tests/*/test_*.py|tests/*_test.py) TESTS+=("$p") ;;
    tests/*) ;;                                                        # fixtures, data
    docs/*|.github/*|.oss-scanner/*|*.md|LICENSE|NOTICE|DCO) ;;        # non-behavioral
    pyproject.toml|noxfile.py|typos.toml|*.code-workspace|.claude/*|.gitignore|.gitattributes) ;;
    *) PROD+=("$p") ;;
  esac
done

if [ "${#TESTS[@]}" -eq 0 ]; then
  echo "PDCA-UNVERIFIABLE: patch ships no test (changed: ${CHANGED[*]})"; exit 77
fi
if [ "${#PROD[@]}" -eq 0 ]; then
  echo "PDCA-UNVERIFIABLE: no behavioral production change to revert (test-only or docs-only patch)"; exit 77
fi

REPORT="$(mktemp)"
trap 'rm -f "$REPORT"' EXIT
RAN=0 FAILED=0 ERRORS=0 COLLECT=0

run_tests() {
  local rc=0 pycache
  rm -f "$REPORT"
  # A fresh, empty bytecode cache per leg. Python trusts a cached .pyc whose source has
  # the same size and mtime second, and reverting `a + b` to `a - b` changes neither — so
  # without this the red leg can silently run the green leg's compiled code (found by
  # engine/tests: test_genuine_red_then_green_passes_and_restores_the_tree).
  pycache="$(mktemp -d)"
  PYTHONPATH="$WT/src${PYTHONPATH:+:$PYTHONPATH}" PYTHONPYCACHEPREFIX="$pycache" \
    "$PY" -m pytest -p no:cacheprovider -q -m "not applier" --junitxml="$REPORT" "${TESTS[@]}" 2>&1 || rc=$?
  rm -rf "$pycache"
  read -r RAN FAILED ERRORS COLLECT < <("$PY" "$ENGINE/lib/junit_count.py" "$REPORT")
  echo "   (pytest exit $rc; ran $RAN, failed $FAILED, setup errors $ERRORS, import/collection errors $COLLECT)"
  return "$rc"
}

echo "== C4 green leg: bundle test(s) with the fix applied: ${TESTS[*]}"
GREEN_RC=0
run_tests || GREEN_RC=$?

if [ "$RAN" -eq 0 ] && [ "$COLLECT" -eq 0 ] && [ "$ERRORS" -eq 0 ]; then
  echo "PDCA-UNVERIFIABLE: 0 tests ran with the fix applied (pytest exit $GREEN_RC), so the green leg asserted nothing — the test is skipped, deselected (applier tests always are), or the file has no test"
  exit 77
fi
if [ "$GREEN_RC" -ne 0 ]; then
  echo "PDCA-EVIDENCE: C4 FAIL — bundle test red (or not importable) WITH the fix applied"
  exit 1
fi

# Red leg: revert only the production hunks; the tests stay in place. Restore on every
# exit path so later gates always see base + full patch.
EXCLUDES=(--exclude='tests/*' --exclude='tests/**')
restore() { git apply "${EXCLUDES[@]}" "$PATCH" 2>/dev/null || true; rm -f "$REPORT"; }
trap restore EXIT
git apply -R "${EXCLUDES[@]}" "$PATCH"

echo "== C4 red leg: bundle test(s) with the production change reverted"
RED_RC=0
run_tests || RED_RC=$?

if [ "$COLLECT" -gt 0 ]; then
  echo "PDCA-UNVERIFIABLE: the red leg's test module failed to IMPORT, so no test ran and no red was established — this is NOT 'red without the fix'. The usual cause is a test that imports API this patch ADDS, so reverting the fix removes it. Exercise the behaviour through pre-existing API, or record at sign-off why this slice has no isolable red"
  exit 77
fi
if [ "$RAN" -eq 0 ]; then
  echo "PDCA-UNVERIFIABLE: 0 tests ran with the production change reverted (pytest exit $RED_RC), so no red could be established — the test never ran"
  exit 77
fi
if [ "$RED_RC" -eq 0 ] || [ "$FAILED" -eq 0 ]; then
  echo "PDCA-EVIDENCE: C4 FAIL — bundle test still green WITHOUT the fix, it does not capture the defect"
  exit 1
fi

echo "PDCA-EVIDENCE: C4 PASS — red without the fix ($FAILED of $RAN failed), green with it"
