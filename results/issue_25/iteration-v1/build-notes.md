# Build notes — issue 25 / rolling-origin-backtest

Base: folded #23+#24 tip `450f7c8` (worktree `autobook.pdca-wt`). Nothing on the base
differed from what the brief assumed, so no "stop and report" item was triggered.

## What changed (paths on the target branch)

- `src/autobook/pipeline/trial.py` (stub at base: one `run_trial()` raising
  `NotImplementedError`, old lines 1-17): now holds `backtest()`, `main()`, the constants
  `REPORT_VERSION`, `BANDS`, `SWEEP_DISTANCES`, `SWEEP_MARGINS`, and the private
  token-Bayes class. `run_trial()` stays the stub.
- `tests/test_backtest.py` (new): criteria (a)-(e) plus leave-one-out placement, band sums,
  sweep size, up-front threshold validation.
- `tests/test_skeleton.py:24`: `"autobook.pipeline.trial"` added to `IMPLEMENTED`. The base
  already has the exemption (`test_skeleton.py:46-48` skips an `IMPLEMENTED` module), so
  nothing about the exemption was changed.
- `docs/design/architecture/05-building-block-view.md` (§5.2 *Trial tooling*) and
  `06-runtime-view.md` (§6.6): method, strata, bands, sweep, upper bound, report fields,
  privacy rule, and the command line.

## Upstream APIs used

- `normaliser.load`, `Normaliser.version`, `NormaliserError`
  (`src/autobook/pipeline/normaliser.py:120`, `:93`, `:64`).
- `classifier.index_rows` (`classifier.py`, `index_rows`), `IndexRow`, `KnnIndex.build`,
  `KnnIndex.query(..., as_of, normaliser_version, exclude)`, `KnnResult`, `KnnError`,
  `HALF_LIFE_DAYS`.
- `contracts.corpus_from_json`, `ContractError`, `CorpusContract`, `CorpusRow`,
  `corpus_to_json`.

## Decisions

- **Month boundary, not row date.** For month m the history is every row with
  `post_date < first day of m` (`trial.py`, `backtest`). One kNN index and one token-Bayes
  model per tested month. This is what makes (e) bite: a row-date bound or one global
  index lets 2025-02-01 vote for 2025-02-20.
- **Which months count as tested.** Months after the first that hold at least one row.
  A gap month has no rows, so it is not listed and does not add to `tested`.
- **Thresholds validated up front** with `KnnIndex.build([], ...)`, so a one-month corpus
  (no month tested, no index built) still refuses bad thresholds instead of writing a
  report with numbers nobody asked for. `KnnError` maps to exit 2 in `main`.
- **Bands.** Per-band entry is `accepted`, `correct`, `precision`, `coverage`
  (coverage = band accepted / all tested rows of that method). I left `rows` out of a
  band entry: "rows in the band" and "accepted in the band" are the same set by
  definition, so a `rows` field would just repeat `accepted`.
- **Strata keys always present** (`seen`, `novel`, `all`), with `precision`/`coverage`
  `null` on zero rows, so a consumer never has to test for a missing key.
- **Token-Bayes** uses the partition vocabulary size V for smoothing; an unseen word
  contributes `1 / (class_total + V)`, which differs by class only through the class
  total. Standard library only (`math`, `collections`).
- **Leave-one-out "seen"** = another row in the partition has the same token
  (`Counter > 1`), as the brief specifies. `as_of` is the row's own date; later rows get
  age 0 (`max(0, ...)` in the classifier), which is exactly why it is an upper bound.
- **Errors.** `ContractError`, `NormaliserError`, `KnnError`, `OSError`,
  `UnicodeDecodeError` -> one line on stderr, exit 2, report written only after the
  backtest finished. The OS-error message carries the exception class name, not
  `str(exc)`, to keep the line short and free of paths other than the user's own.
- **No `print`**: `sys.stderr.write` (ruff T20).
- **Sweep grid:** distances 0.1-0.9, margins 0.1-1.0, both inside the ranges
  `KnnIndex.build` accepts.

## Rejected

- *Per-account breakdown*: privacy (brief).
- *Re-querying per sweep pair*: the gates in the classifier are pure comparisons on
  `nearest_distance` and `margin`, which `KnnResult` already carries, so re-applying them
  costs one list comprehension per grid pair (`_sweep`, ~20 lines) against
  90 pairs × N queries per tested month for re-querying.
- *Per-cluster results*: out of scope (brief); deferred in the PR description.

## Red reason on the folded base

Ran `engine/scripts/run-verify.sh` against the worktree (`PDCA_BUNDLE`, `PDCA_WORKTREE`):

```
10 failed, 5 passed   (production hunks reverted)
C4 PASS — red without the fix (10 of 15 failed), green with it
```

The failures are `AttributeError: module 'autobook.pipeline.trial' has no attribute
'backtest'` (or `'main'`), a missing `trial` name, not a missing #23/#24 name. The 5 that
still pass on the red leg are the `test_skeleton.py` tests, which do not touch the change.
Full suite with the fix: 323 passed, 8 skipped (live tests).

## Self-refutation

- **(a) Genuine red?** Yes. The gate's red leg reverted the non-test hunks and 10 of the
  10 `test_backtest.py` tests ran and failed on the missing `trial.backtest` / `trial.main`.
- **(b) Production path?** Yes. Every test calls `trial.backtest` or `trial.main` with the
  real `normaliser.load` on an empty dir, the real `KnnIndex`, and the real contracts.
  No mocks and no copy of the logic in the test.
- **(c) Fixture includes the fault?** Yes. The planted corpora include the cases the
  brief names: the within-month `CHARLIE` pair (e), the March future rows (b), the
  distance-1 `ZULU KIOSK` row (a), and the real `build_corpus(0..2)` with its novel
  merchant (c, d). Nothing was curated out.

## Not done / needs the human

- **ruff and mypy are not installed** in this environment (not in the instance venv, not
  on PATH). The configured formatter and type check were therefore NOT run. I checked
  line length ≤ 96 by hand and followed the style of `classifier.py`, but `nox -s fmt`,
  `lint` and `types` must be run before commit.

NEEDS-HUMAN external dependency: ruff 0.14.2 and mypy 1.18.2 (the project's `nox -s fmt/lint/types` tools) — not installed in the instance venv, so the target's format/lint/type gates were not run on this patch.

```toml
[[doctor.checks]]
id    = "ruff-mypy"
cmd   = ".venv/bin/python3 -m ruff --version && .venv/bin/python3 -m mypy --version"
hint  = "pip install ruff==0.14.2 mypy==1.18.2 into the instance .venv (versions pinned in the target's noxfile.py LINT_DEPS / TYPE_DEPS)"
level = "WARN"
```

- Not tested: run time on 30-60k rows (brief says not tested here).
- Follow-up outside this patch: set `[manual_test].cmd` in `pdca.toml` once merged.
- PR description must state the settled CLI form, counts-only JSON, novel sweep, and that
  per-cluster results are deferred.
