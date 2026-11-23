# Adversarial review — issue 25 / rolling-origin-backtest (iteration 4)

**Verdict: I tried to refute the round-3 fixes and could not.** The sign-off asked for two
changes: keep relative profile paths out of stderr, and list empty calendar months. Both are
in place, and each has a test that fails when the fix is reverted. I found no concrete failing
input.

## Evidence

- Re-ran the green leg on `$PDCA_TARGET`, with `src:.` on the path and the instance venv:
  `tests/test_backtest.py tests/test_skeleton.py` gives 26 passed. This matches
  `gate-logs/C4-verify.log:12`. The red leg in the same log (`:777`, 21 failed, 5 passed,
  0 collection errors) fails on `AttributeError: ... no attribute 'backtest'`. That is the
  missing production name, so these are real red tests, not collection errors. The 5 that
  pass on red are the `test_skeleton.py` tests, which is expected.
- The tests call the production path: `trial.backtest` / `trial.main` in process, not a copy
  of the logic.

## Refutation attempts (none landed)

- **Fix 1, privacy of the profile path** (`src/autobook/pipeline/trial.py:423-438`, `:457`).
  - Mutant: drop the `field["root"] in roots` check at `trial.py:436`. Caught:
    `test_a_relative_profile_path_never_reaches_stderr` (`tests/test_backtest.py:294-310`)
    goes red, because it asserts the exact stderr line.
  - Mutant: pass `()` instead of `{CORPUS_NAME}` at `trial.py:454`. Caught by
    `tests/test_backtest.py:267`, so contract locations are still named.
  - Can a contract location carry text from the file? I checked every `where` built in
    `src/autobook/contracts.py:199-334`. Each one is assembled in code (`corpus`,
    `corpus.rows[i]`, `corpus.rows[i].<fixed key>`). Unknown key names from the file only
    appear after the `": "` (`contracts.py:212`), and `trial.py:434` cuts that part off.
    The test at `tests/test_backtest.py:272-279` covers this case. No leak.
  - KnnError locations are limited to `max_distance` / `min_margin` (`trial.py:420`). I
    probed `--max-distance nan`, `--min-margin nan` and `--max-distance inf`. Each gives
    exit 2, a one-line message and no report file. There is no uncaught `json.dumps`
    `allow_nan` crash.
- **Fix 2, empty calendar months** (`trial.py:151-155`, `:305`, `:318`).
  - Mutant: go back to `months = sorted(by_month)`. Caught by
    `tests/test_backtest.py:180-203`, which also covers a gap that crosses a year end
    (Nov→Feb) and checks that March is still classified against January's history.
  - Edge cases: an empty corpus gives `first`/`last` = `null`, `tested` = 0, empty
    `by_month`, all-null rates and no crash. A one-month corpus still validates its
    thresholds (`trial.py:297`, test at `tests/test_backtest.py:550`).
- **Scope.** The diff stays within the two fixes the sign-off allowed. The docs were updated
  to match: ch.5 says empty months are listed, and ch.6 says a refused normaliser profile is
  reported with no location (`docs/design/architecture/05-building-block-view.md`,
  `06-runtime-view.md`, hunks at `patch.diff:59-60` and `:88-93`).

## Note (informational, not a refutation)

- `trial.py:310-313` builds a full `KnnIndex` (and scans all rows) even for a month that has
  no rows to classify. With the gap-month change, one far-future row in an export (for
  example a mistyped year 2099) adds about 900 such builds. I timed one build on 34.5k rows
  at 0.30 s, so that adds about 4–5 minutes. That exceeds proposal 0001's "seconds to a
  minute" budget, but the report is still correct. The run time is untested by the brief,
  and the sign-off said "do not change anything else", so I am not raising this as a
  NEEDS-HUMAN item. Skipping the index build when `by_month.get(month)` is empty would remove
  the cost if a human wants that later.

No NEEDS-HUMAN findings.

<!-- pdca:leaf-complete -->
