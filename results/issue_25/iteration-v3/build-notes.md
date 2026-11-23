# Build notes — issue 25 / rolling-origin-backtest (iteration 3)

Base: folded #23+#24 tip `450f7c8` (`pdca-integration/main-r1726f2053868`, worktree
`autobook.pdca-wt`). Line numbers below are on that base plus this patch.

This iteration starts from the iteration-2 patch (`iteration-v2/patch.diff`, applied
cleanly) and fixes the four findings in the round-2 carry-forward. The design is
otherwise unchanged; iteration 2's notes (`iteration-v2/build-notes.md`) still hold for
the token-Bayes blank-history fix, the band `rows` definition and the earlier mutants.

## Carry-forward, item by item

### 1. CLI forwarded error text with amounts and dates to stderr

Cause: `main()` wrote `str(exc)` for `ContractError`, `NormaliserError` and `KnnError`.
Those messages quote the refused value: `contracts.py:240` (`got {value}` on
`amount_cents`), `contracts.py:286` and `:290` (`got {text!r}` on `post_date`),
`contracts.py:135` (`got {self.sign!r}`), `contracts.py:212` (unknown field names read
from the file), and normaliser errors quote profile paths and regex text
(`normaliser.py:166-266`).

Fix (`src/autobook/pipeline/trial.py:405-442`): `_refused()` never passes the error's
own text on. It writes a fixed sentence per error kind, the exception class, and the
leading field path (`corpus.rows[1].amount_cents`) only when that path matches
`_FIELD` (`trial.py:408`): names and `[index]` parts only. That path is the text before
the first `": "`; in `contracts.py` it is always built from field names and row indices
(`contracts.py:200`, `:279`, `:315-330`). The regex is a second guard, so a future
upstream message that puts a value first is dropped, not echoed. A normaliser path
never matches the regex (it has `/`), so a normaliser error gives only the class.

- Why keep the field path at all: a user with a broken export needs to find the row.
  A row index and field name are IDs, which ch.8 §8.5 allows in logs.
- Considered and not chosen: a fixed message with no location. Smaller (about 6 fewer
  lines), but it leaves the user with no pointer into a 50k-row file.
- Test: `test_cli_refusals_name_the_field_never_the_value` (`tests/test_backtest.py:218`).
  Bad `amount_cents` (-4711), `post_date` (`2025-02-30`), `sign` (`ZULU KIOSK`), an
  unknown field named `ZULU KIOSK`, and a normaliser profile whose dir and pattern hold
  `ALPHA`. It checks exit 2, no report, one stderr line, the field path present, and
  the value absent. Against iteration 2's `str(exc)` it fails (mutant run below).
- Docs: ch.6 §6.6 says what the message holds (`06-runtime-view.md:158-161`).

### 2. Sweep gate boundaries not pinned

- Added the reviewer's cell `(0.5, 1.0): (2, 1)` to `expected`
  (`tests/test_backtest.py:398`). A unanimous vote has margin exactly 1.0, so this kills
  `>=` → `>` on the margin (`trial.py:214`).
- That cell does not kill `<=` → `<` on the distance (`trial.py:213`): real TF-IDF
  distances on this corpus are 0.374, 0.465, 0.481, never a grid value, and the grid
  does not hold 0. So I added `test_sweep_gates_are_inclusive_at_both_edges`
  (`tests/test_backtest.py:407`), which feeds two stored outcomes to the production
  `trial._sweep` directly: one at exactly `(0.5, 1.0)`, one just outside both edges.
  This is the real function on real `_Outcome` objects, not a copy. It reaches two
  private names, so it is coupled to them; the end-to-end sweep test stays as the
  behavioural check.

### 3. Band edge not pinned (`bisect_right` → `bisect_left`)

`test_a_confidence_on_a_band_edge_falls_in_the_band_above` (`tests/test_backtest.py:433`):
the reviewer's corpus (January `ALPHA` → MIETE and → LEBENSMITTEL, February `ALPHA`).
Token-Bayes is an exact tie; I checked the float: the posterior is exactly `0.5`, not
`0.49999…`. It wins LEBENSMITTEL (smaller path) in band `[0.5,0.7)`. kNN is a near tie
(recency alone splits it, margin under 0.01) and refuses; the test pins that too.

### 4. `as_of=row.post_date` not pinned

The reviewer's suggested mutant (shift `as_of` ten years later) **cannot change any
rolling-origin number**. In month m, every history row is dated before the first day of
m, so every age is positive whether `as_of` is the row's date or later. The weight is
`(1 - d) * 0.5 ** ((as_of - date) / h)` (`classifier.py:418`). Moving `as_of` by X
multiplies every weight by the same `0.5 ** (X / h)`. Share and margin are ratios of
weights (`classifier.py:428-429`), so they do not move. The `age = max(0, …)` clamp
(`classifier.py:417`) never triggers. For the rolling origin, that mutant is equivalent
to the original, and no test there can catch it.

Where `as_of` is observable, two tests now pin it:
- `test_recency_is_measured_from_the_test_row_after_its_history`
  (`tests/test_backtest.py:448`): two `ALPHA` → MIETE rows from 2022 and one recent
  `ALPHA` → LEBENSMITTEL row. Measured from the row's date, the recent row wins (share
  0.66, margin 0.31, at `min_margin=0.2`). From any `as_of` at or before the history
  (e.g. `datetime.date.min`), every age clamps to 0 and the two old rows win. This
  catches an `as_of` earlier than the history.
- `test_leave_one_out_measures_age_from_the_row_itself` (`tests/test_backtest.py:471`):
  leave-one-out has future rows, and from the row's own date they clamp to age 0. Two
  equal January 2025 rows plus one 2027 row: a tie for each January row (refused), so
  `all` is `(3, 1, 0)`. With `as_of` ten years later, the 2027 row outweighs the January
  one (share 0.78) and the result is `(3, 3, 0)`. `_knn_outcome` (`trial.py:224-249`) is
  shared by both paths, so this catches the reviewer's mutant on the shared line
  `trial.py:236`.

## Mutation run (this iteration's targets)

Each mutant applied to `trial.py`, `tests/test_backtest.py` run through
`./engine/nox.sh test-3.14 -- tests/test_backtest.py`, then the file restored (diffed
against a saved copy: identical).

| Mutant | Killed by |
|---|---|
| `_refused` → `_fail(str(exc))` | `test_cli_refusals_name_the_field_never_the_value` |
| sweep `nearest_distance <=` → `<` (`:213`) | `test_sweep_gates_are_inclusive_at_both_edges` |
| sweep `margin >=` → `>` (`:214`) | that test and `test_sweep_re_applies_both_gates_to_the_novel_stratum` |
| `bisect_right` → `bisect_left` (`:194`) | `test_a_confidence_on_a_band_edge_falls_in_the_band_above` |
| `as_of=datetime.date.min` (`:236`) | `test_recency_is_measured_from_the_test_row_after_its_history` |
| `as_of=row.post_date + 3650 days` (`:236`) | `test_leave_one_out_measures_age_from_the_row_itself` (survived before that test was added, as derived above) |

6 of 6 killed.

## Brief checks on the folded base (re-confirmed, unchanged)

- #23 `default` profile: `ALPHA 123` → `ALPHA`, `BRAVO REF 9` → `BRAVO`
  (`normaliser.load`, `src/autobook/pipeline/normaliser.py:120`).
- #24 weight rule `(1 - distance) * 0.5 ** (age/half_life)` at `classifier.py:418`,
  gates at `:433-436`. As the brief states; no "stop and report" item triggered.
- `IMPLEMENTED` exists on the base (`tests/test_skeleton.py:22`, used at `:56`); this
  patch only adds `"autobook.pipeline.trial"` (`:25`).

## Upstream APIs used (path:line on the target)

- Stub replaced: `src/autobook/pipeline/trial.py:1-18` at base; `run_trial` kept at
  `trial.py:372`.
- `normaliser.load` `normaliser.py:120`, `Normaliser` `:89`, `NormaliserError` `:64`.
- `classifier.index_rows` `classifier.py:163`, `IndexRow` `:107`, `KnnResult` `:144`,
  `KnnIndex` `:293`, `.build` `:311`, `.query(..., as_of, exclude)` `:356`, `KnnError`
  `:64`, `HALF_LIFE_DAYS` `:46`.
- `contracts.ContractError` `contracts.py:110`, `CorpusRow` `:120`, `CorpusContract`
  `:149`, `corpus_to_json` `:357`, `corpus_from_json` `:361`, `Sign` `:71`.
- `tests/fixtures/synthetic/corpus_builder.py`: `GIROKONTO` `:17`, `REVOLUT` `:18`,
  `LEBENSMITTEL` `:19`, `MIETE` `:20`, `GEHALT` `:21`, `MERCHANTS` `:33`,
  `NOVEL_MERCHANT` `:43`, `build_corpus` `:69`.
- `pyproject.toml` ruff `T20`: output goes through `sys.stderr.write` (`_fail`,
  `trial.py:402`).
- Docs: ch.5 §5.2 *Trial tooling* (`05-building-block-view.md`), ch.6 §6.6
  (`06-runtime-view.md:138-161`).

## Gates run (the project's own runners)

- `./engine/nox.sh fmt -- --fix`: 39 files unchanged, ruff clean (commit-ready).
- `./engine/nox.sh gate` (= C4-ci) with `PDCA_WORKTREE` set: fmt, lint, types,
  test-3.14 (332 passed, 1 skipped, 7 deselected), typos, docs: all success.
- `engine/scripts/run-verify.sh` (= C4-verify) with `PDCA_BUNDLE`/`PDCA_WORKTREE`:
  `PDCA-EVIDENCE: C4 PASS — red without the fix (19 of 24 failed), green with it`.
  0 collection errors. The 5 that pass on the red leg are `tests/test_skeleton.py`.

## Red reason on the folded base (brief: Falsifiability)

With the production hunks reverted, all 19 `test_backtest.py` tests fail on a missing
`trial` name: 15 × `has no attribute 'backtest'`, 3 × `'main'`, 1 × `'_Outcome'` (the
sweep-edge test). None fails on a missing #23/#24 name.

## Self-refutation

- **(a) Genuine red?** Yes. `run-verify.sh` reverted the non-test hunks: 19 of 19
  `test_backtest.py` tests ran and failed. Each new test in this iteration was also run
  against the specific defect it targets (mutation table): each goes red there. So they
  bind the fixes, not just the existence of `backtest`.
- **(b) Production path?** Yes. Every test calls `trial.backtest`, `trial.main` or
  `trial._sweep` with the real `normaliser.load` on an empty dir (or a real broken
  profile dir), the real `index_rows`/`KnnIndex`, and the real contracts parser. The
  stderr test captures the real `sys.stderr` output of `main()`. Nothing is mocked; the
  test has no copy of the logic.
- **(c) Fixture includes the fault?** Yes. The stderr test's files carry the identifying
  values (an amount, a date, a merchant-like string in a value, a field name and a
  profile path/pattern) that the old code echoed. The band test has a confidence of
  exactly 0.5. The recency and leave-one-out tests have old, recent and future rows
  whose votes flip with `as_of`. The earlier fixtures (blank history, within-month
  `CHARLIE` pair, March future rows, two partitions, `build_corpus(0..2)`) are kept.

## Rubric pass

- *Privacy:* the report holds counts, rates, versions, thresholds, month labels, band
  labels and grid values only. The CLI's stderr now holds only fixed text, an exception
  class and a field path (this iteration). argparse's own usage errors still echo the
  argument the user typed (a threshold or a path), which is the user's own input, not
  transaction data. Every test row is invented.
- *Failure granularity:* malformed input refuses the whole run with exit 2 and no
  report; that is validation of the corpus as a whole, not a per-row problem.
- *Abstention erosion:* no threshold is set or widened anywhere. The sweep is reported,
  never fed back.
- Money, book writes, idempotency, double-booking, documents, backend: not touched.

## Housekeeping

- For the mutation run I saved a copy of `trial.py` and afterwards moved it to
  `.nox/scratch/trial.py.orig-mut` (git-ignored). An untracked
  `tests/fixtures/synthetic/__pycache__/` is also left from test runs. Neither is in
  `patch.diff`. I did not delete them (cleanup is the harness's job).
- `git add -N tests/test_backtest.py` was used so `git diff` includes the new file; the
  index holds an intent-to-add entry for it.

## Not done / for the human

- The band `rows` definition (iteration 2, item 3) is a reading of an ambiguous
  sentence in the brief. Confirm at sign-off.
- Run time on 30–60k rows: not tested (the brief says so).
- After merge: set `[manual_test].cmd` in `pdca.toml` (out of scope here).
- The PR description must state the settled CLI form, the counts-only JSON, the novel
  sweep, and that per-cluster results are deferred.
