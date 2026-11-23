# Build notes — issue 25 / rolling-origin-backtest (iteration 4)

Base: folded #23+#24 tip `450f7c8` (`pdca-integration/main-r1726f2053868`, worktree
`autobook.pdca-wt`). Line numbers below are on that base plus this patch.

The iteration-3 sign-off accepted the rest of the patch and asked for exactly two fixes,
each with a regression test. So this iteration starts from `iteration-v3/patch.diff`
(applied cleanly with `git apply`) and changes nothing else: strata, bands, sweep,
leave-one-out and the report shape are untouched. The interdiff against
`iteration-v3/patch.diff` is the two code fixes, their two tests, and one sentence in each
of ch.5 and ch.6. Iteration 2's and 3's notes (`iteration-v2/`, `iteration-v3/
build-notes.md`) still hold for everything else.

## 1. A relative, slash-free profile path reached stderr

**Cause.** `_refused` passed on any error prefix (the text before the first `": "`) that
*looked* like a field path (`_FIELD`). The shape is not the problem; the source is.
Contract errors are located at contract fields (`contracts.py:199-200`, `:279`, `:316-330`,
`:432`) and kNN errors at code-constant field names (`classifier.py:72-73`, `:331`, `:334`).
But normaliser errors are located at a file or directory path the user chose
(`normaliser.py:185`, `:189`, `:192`, and the other `{path}:` / `{source}:` messages at
`:166-344`). A relative path with no slash, such as `PRIVATE_PROFILE`, passes `_FIELD`.
Reviewer's probe: `--normaliser-dir PRIVATE_PROFILE` naming a regular file gives
`NormaliserError("PRIVATE_PROFILE: the user directory is not a directory")`
(`normaliser.py:189`), and stderr read `... (NormaliserError at PRIVATE_PROFILE)`.

**Fix** (`src/autobook/pipeline/trial.py:417-459`). Each `except` clause in `main()` now
tells `_refused` which roots a location of that error kind may start at. The location
is passed on only if it matches `_FIELD` **and** its first name is one of those roots
(`trial.py:435-436`; `_FIELD` gained a named `root` group at `:417`):

- `ContractError`: `{CORPUS_NAME}` (`trial.py:454`; `contracts.py:63`). Every location
  `corpus_from_json` can produce starts at `corpus`.
- `KnnError`: `_THRESHOLDS` = `max_distance`, `min_margin` (`trial.py:420`, `:459`), the
  only kNN errors the command line can cause (`classifier.py:331`, `:334`). A row-level
  kNN error cannot come from a corpus that passed the contract; if one ever did, it would
  be reported with no location.
- `NormaliserError`: no roots (`trial.py:455-457`), so never a location. This is the
  sign-off's "drop normaliser locations entirely" and "only known roots" together. The
  only slash-free code-constant normaliser locations (`raw_memo`, `source_account`,
  `normaliser.py:382`, `:388`) cannot come from a corpus that passed the contract either.

The `_FIELD` shape check stays as a second guard: a location must start at a known root
*and* be made of names and `[n]` indices.

Alternatives considered:
- *Drop normaliser locations only, keep the shape-only check for the rest*: 1 line
  smaller (the normaliser clause calls `_fail` directly). Not chosen: it leaves the same
  trust-by-shape rule for the other two kinds, so a future upstream message that starts
  with a value would be echoed again. The root list costs 1 constant (`_THRESHOLDS`), one
  parameter and one named group.
- *Drop every location*: about 6 lines smaller. Not chosen (same reason as in
  iteration 3): a user with a broken 50k-row export needs `corpus.rows[3].amount_cents`
  to find the row, and a field path is an ID, which ch.8 §8.5 allows in logs.

**Test:** `test_a_relative_profile_path_never_reaches_stderr` (`tests/test_backtest.py:294`).
It `chdir`s into `tmp_path`, creates a regular file `PRIVATE_PROFILE`, runs the real
`trial.main` with `--normaliser-dir PRIVATE_PROFILE` (a relative, slash-free path), and
asserts exit 2, no report, and stderr exactly
`error: the normaliser profiles were refused (NormaliserError)\n`. A second part runs
`--max-distance 1.5` and asserts stderr is exactly
`... (KnnError at max_distance)\n`, so the fix cannot over-correct by dropping a
threshold name. The existing `test_cli_refusals_name_the_field_never_the_value`
(`:244`) still pins `corpus.rows[1].<field>` and `ContractError at corpus.rows[0]`.

Red on the iteration-3 code (run before the fix, through the runner):
`AssertionError: ... + liserError at PRIVATE_PROFILE)`.

## 2. Calendar months without rows were skipped

**Cause.** `backtest()` iterated `sorted(by_month)`, the months that hold rows. A month
with no rows inside the range was neither listed under `by_month` nor counted in
`tested`, while the brief says "The months are the calendar months from the first to the
last `post_date`".

**Fix.** `_calendar(first, last)` (`trial.py:151-155`) lists every calendar month from
`first` to `last`, both included, by counting months since year 0
(`year * 12 + month - 1`), so a year end needs no special case. `backtest()` uses it for
`months` (`trial.py:303-305`) and reads a month's rows with `by_month.get(month, [])`
(`:318`). A month with no rows goes through the same loop: zero outcomes, so
`_counts([])` gives `{"rows": 0, "accepted": 0, "correct": 0}` for both methods, and it
counts in `tested` (`:342`, `len(monthly)`). It adds no outcome, so strata, bands and the
sweep are unchanged. `first`/`last` are the same as before.

Alternative considered: *skip the index build for an empty month*. It would need either a
guard that writes the zero entry separately (about 4 lines, and a second place that
knows the per-month entry has `knn` and `token_bayes`) or re-indenting the 9-line body
under `if rows:`. Not chosen. The current code builds one `KnnIndex` and one
`_TokenBayes` that nothing queries, once per empty month. Cost, from the iteration-3
adversary's timing (30,000 rows over 120 months in 42 s, `iteration-v3/
check-advisory-adversary.md:41-43`): under 0.35 s per month at that size, less with no
queries. A real book has rows in nearly every month, so this is rare. It also follows
the brief's wording literally: "For every later month m: build one KnnIndex …".

**Test:** `test_a_calendar_month_without_rows_is_listed_with_zero_counts`
(`tests/test_backtest.py:180`). January `ALPHA` ×3 and March `ALPHA` (no February):
`first`/`last`/`tested` = `2025-01`/`2025-03`/`2`; February is
`{"knn": zero, "token_bayes": zero}`; March is `(1, 1, 1)` for both methods, so the empty
month does not cut the history. Then November 2024 and February 2025: `by_month` keys
are `["2024-12", "2025-01", "2025-02"]` in that order and `tested` is 3, which pins the
year end.

Red on the iteration-3 code: `months["tested"]` was 1 (`At index 2 diff: 1 != 2`).

## Docs

- ch.5 §5.2 *Trial tooling*, *Report* bullet (`05-building-block-view.md:527-529`): every
  calendar month after the first is tested and listed, one with no rows with zero counts.
- ch.6 §6.6 (`06-runtime-view.md:158-163`): the message names, at most, the corpus field
  or the threshold (`corpus.rows[3].amount_cents`, `max_distance`); a refused normaliser
  profile gets no location at all.

## Mutation run (this iteration's targets)

Script in the worktree's git-ignored `.nox/scratch/mutate_v4.py`: each mutant applied to
a clean copy of `trial.py`, `tests/test_backtest.py` run through
`./engine/nox.sh test-3.14 -- tests/test_backtest.py` (with `timeout 600`), then the clean
file restored. Restore checked by hash (`ddf99410…` before and after).

| Mutant | Killed by |
|---|---|
| A: roots ignored, shape-only check (the iteration-3 rule) | `test_a_relative_profile_path_never_reaches_stderr` |
| B: kNN roots empty (threshold name dropped) | `test_a_relative_profile_path_never_reaches_stderr` |
| C: contract roots empty (corpus field dropped) | `test_cli_refusals_name_the_field_never_the_value` |
| D: `_calendar` drops the last month | 12 tests, the gap-month test among them |
| E: `_calendar` month off by one | 13 tests, the gap-month test among them |
| F: only months that hold rows (the iteration-3 rule) | `test_a_calendar_month_without_rows_is_listed_with_zero_counts` |
| H: `_calendar` within one year only | the gap-month test (year-end part) and `test_recency_is_measured_from_the_test_row_after_its_history` |

7 of 7 killed.

## Gates run (the project's own runners)

- `./engine/nox.sh fmt -- --fix`: 39 files unchanged, `ruff check` clean.
- `./engine/nox.sh gate` (= C4-ci) with `PDCA_WORKTREE` set: fmt, lint, types,
  test-3.14 (334 passed, 1 skipped (no `gnucash` on the host), 7 deselected), typos,
  docs: all success.
- `engine/scripts/run-verify.sh` (= C4-verify) with `PDCA_BUNDLE`/`PDCA_WORKTREE`:
  `PDCA-EVIDENCE: C4 PASS — red without the fix (21 of 26 failed), green with it`.
  Green leg: ran 26, failed 0. Red leg: ran 26, failed 21, 0 setup errors, 0
  import/collection errors. The 5 that pass on the red leg are `tests/test_skeleton.py`.
  Afterwards the worktree diff was byte-identical to the bundle's `patch.diff`.

## Red reason on the folded base (brief: Falsifiability)

With the production hunks reverted, all 21 `test_backtest.py` tests fail on a missing
`trial` name: 16 × `has no attribute 'backtest'`, 4 × `'main'`, 1 × `'_Outcome'` (the
sweep-edge test). None fails on a missing #23/#24 name. The two new tests fail there on
`backtest` (gap month, via `_run`) and `main` (profile path, via `_cli`); their specific
red against the iteration-3 code is recorded above.

## Self-refutation

- **(a) Genuine red?** Yes. Two levels. Against the reverted production code
  (`run-verify.sh`), 21 of 21 backtest tests ran and failed. Against the iteration-3 code
  (the exact defects the sign-off named), the two new tests ran and failed with the
  leaked `PRIVATE_PROFILE` and `tested == 1`, then passed after the fix. Mutants A–H
  above each go red.
- **(b) Production path?** Yes. The privacy test calls the real `trial.main`, which runs
  the real `corpus_from_json` and the real `normaliser.load` on a real relative path in
  the real cwd, and reads the real `sys.stderr`. The gap-month test calls the real
  `trial.backtest` with the real normaliser and kNN index. Nothing is mocked, and no
  test holds a copy of the logic.
- **(c) Fixture includes the fault?** Yes. The privacy fixture is the reviewer's exact
  case: a relative, slash-free path that is a regular file, so `normaliser.py:189`
  raises with that path as its location. The gap-month fixtures have an empty month
  inside the range, and two empty months across a year end.

## Rubric pass

- *Privacy:* stderr now carries a location only when it starts at a root the caller
  names for that error kind. A normaliser error never carries one. The report is
  unchanged: counts, rates, versions, thresholds, month labels, band labels and grid
  values. An empty month adds only a `YYYY-MM` label with zero counts. Every test row is
  invented (`ALPHA`, `BRAVO`, …).
- *Failure granularity:* unchanged; an empty month is a tested month with zero rows,
  not an error.
- *Abstention erosion:* no threshold is set or widened.
- Money, book writes, idempotency, double-booking, documents, backend: not touched.

## Upstream APIs used (path:line on the target; unchanged from iteration 3, re-checked)

- Stub replaced: `src/autobook/pipeline/trial.py:1-18` at base; `run_trial` kept.
- `normaliser.load` `normaliser.py:120`, `Normaliser` `:89`, `NormaliserError` `:64`.
- `classifier.index_rows` `classifier.py:163`, `IndexRow` `:107`, `KnnResult` `:144`,
  `KnnIndex` `:293`, `.build` `:311`, `.query(..., as_of, exclude)` `:356`, `KnnError`
  `:64`, `HALF_LIFE_DAYS` `:46`, weight rule `:418`.
- `contracts.CORPUS_NAME` `contracts.py:63` (new use this iteration), `ContractError`
  `:110`, `CorpusRow` `:120`, `CorpusContract` `:149`, `corpus_to_json` `:357`,
  `corpus_from_json` `:361`, `Sign` `:71`.
- `tests/fixtures/synthetic/corpus_builder.py`: `GIROKONTO` `:17`, `REVOLUT` `:18`,
  `LEBENSMITTEL` `:19`, `MIETE` `:20`, `GEHALT` `:21`, `MERCHANTS` `:33`,
  `NOVEL_MERCHANT` `:43`, `build_corpus` `:69`.
- `IMPLEMENTED` in `tests/test_skeleton.py:22` (from #23); this patch adds
  `"autobook.pipeline.trial"` (`:25`).
- `pyproject.toml:59` ruff `T20`: output goes through `sys.stderr.write` (`_fail`,
  `trial.py:411`).

## Housekeeping

- **Stray file outside the allowed roots:** by mistake I ran a command that wrote
  `/tmp/claude-scratch-ignore` (a copy of the worktree's `git diff` at that moment: code
  and synthetic test data only, nothing personal). I did not delete it; please remove
  it.
- In the worktree's git-ignored `.nox/scratch/`: `trial.py.pristine-v4` (clean copy for
  the mutation run), `mutate_v4.py`, `verify-v4.log`. Also left from test runs: an
  untracked `tests/fixtures/synthetic/__pycache__/`. None is in `patch.diff`.
- `git add -N tests/test_backtest.py` is in the worktree index (intent-to-add), so
  `git diff` includes the new file.
- The bundle's `test_backtest.py` is a byte copy of `tests/test_backtest.py` in the
  worktree.

## Not done / for the human

- The band `rows` definition (iteration 2) is a reading of an ambiguous sentence in the
  brief. It was cleared at the iteration-3 sign-off; noted again only for the record.
- Run time on 30–60k rows: not tested (the brief says so).
- After merge: set `[manual_test].cmd` in `pdca.toml` (out of scope here).
- The PR description must state the settled CLI form, the counts-only JSON, the novel
  sweep, and that per-cluster results are deferred.
