# Adversarial review — issue 25 / rolling-origin-backtest (iteration 3)

**Verdict: I tried to refute the fix and could not.** No finding blocks this patch. I re-ran the
green leg myself: `tests/test_backtest.py` and `tests/test_skeleton.py`, 24 passed, using the
autobook-pdca `.venv` interpreter against `$PDCA_TARGET`. The red leg in `gate-logs/C4-verify.log`
fails for the right reason: 19 of 24 tests fail, 0 collection errors. Each failure is an
`AttributeError` on a name this patch adds (`trial.backtest`, `trial.main`, `trial._Outcome`), never a
missing #23/#24 name. The 5 tests that pass on the red leg are the `test_skeleton.py` ones. The tests
call the production `trial.backtest` / `trial.main`. Nothing in them re-implements the logic.

## What I attacked, and what held

- **The no-future rule** (`src/autobook/pipeline/trial.py:301-312`). The history is
  `post_date < first day of m`, and the kNN index, the token-Bayes counts and the `seen` set are all
  built from that one list. Criterion (e) (`tests/test_backtest.py:165-177`) fails a row-date bound
  or a global index. A "build the index once" mutant fails `test_recency_…` at
  `tests/test_backtest.py:448-468`. Moving `as_of` to the first day of the month cannot be seen in
  the rolling origin: every neighbour is older than that date, so all weights shrink by the same
  factor. That is an equivalent mutant, not a test gap. The test comment at
  `tests/test_backtest.py:472-474` says the same.
- **Last round's carry-forward items.** The sweep edges are now pinned on stored outcomes
  (`tests/test_backtest.py:407-430`): the `<=`/`<` and `>=`/`>` mutants fail. The half-open band edge
  is pinned by an exact token-Bayes tie at 0.5 (`:433-443`), so a `bisect_left` mutant fails.
  Recency is pinned at `:448-468`. The CLI's stderr no longer carries values: `_refused`
  (`trial.py:411-422`) passes on only a leading field path made of names and indices. Contract
  errors put file-read keys and values after `": "` (`src/autobook/contracts.py:199-212, 279`).
  Normaliser errors start with a file path that contains `/`, which `_FIELD` (`trial.py:408`)
  rejects. Both are tested at `tests/test_backtest.py:218-265`.
- **Token-Bayes crash and smoothing** (`trial.py:118-140`). Blank-token history no longer divides
  by zero: unknown words are skipped, so `vocabulary >= 1` wherever a word is scored. Removing the
  priors, the vocabulary term or the unknown-word skip each changes a pinned band
  (`tests/test_backtest.py:289-313`).
- **Leave-one-out** (`trial.py:351-369`). Duplicate rows: `exclude` drops one equal row
  (`classifier.py:191-195, 229-230`), and `seen` = count > 1 matches that. Future rows are clamped
  to age 0 (`classifier.py:417`), pinned at `tests/test_backtest.py:471-487`. The upper bound never
  appears under `methods` or in the sweep.
- **Thresholds and odd inputs.** NaN, inf, `1.0` and a bool are refused by `KnnIndex.build`
  (`classifier.py:327-334`), which runs before any work (`trial.py:290`). The CLI returns 2 and
  writes no file (probed). An empty corpus and a one-month corpus give `tested: 0` and a 90-cell
  sweep with `rows: 0`, with no crash (probed).
- **Run time** (brief *Impact*: "seconds to a minute"). A synthetic corpus of 30,000 rows over
  120 months, 1,500 merchants and one partition ran in 42 s. That is within budget, but 60k rows
  will likely go past a minute: each month refits every partition on the whole history. The brief
  marks this "not tested here", so it is not a finding.

## Minor observations (advisory, none blocks)

- NEEDS-HUMAN [human] — `src/autobook/pipeline/trial.py:306,310`: `seen` means exactly the same
  token, as the brief specifies. But the kNN treats some different tokens as identical:
  `char_wb` n-grams (overlapping 3–5 character chunks, built word by word) ignore word order.
  Probed case: January has `ALPHA MARKT` ×3 → `LEBENSMITTEL`; February has `MARKT ALPHA`. It is
  counted `novel`, sits at distance 0 and is accepted even at `max_distance=0.0, min_margin=1.0`.
  Such rows make the novel stratum, where thresholds are set, look a little easier than truly
  novel merchants. On real memos the effect is probably small (word-order variants are rare). It
  is a question about how the brief defines the strata, not an implementation slip. A human may
  accept it as is, or ask a follow-up to define `seen` as "an index row at distance 0".
- `src/autobook/pipeline/trial.py:437-449`: a refused run leaves an existing `--out` file alone.
  Probed: a stale `OLD` report survives a failed run, with exit 2. This matches the brief ("no
  report file is created") and is safer than deleting user files. I note it because a reader
  could take the old report for the new one. Not filed as NEEDS-HUMAN.
- `src/autobook/pipeline/trial.py:427`: argparse errors (a missing required flag) raise
  `SystemExit(2)` and do not return 2, which is standard argparse behaviour. A file of 100,000
  nested `[` makes `json.loads` raise `RecursionError` at `src/autobook/contracts.py:430`, which
  gives a traceback with no data in it and writes no report. The `contracts.py` behaviour predates
  this patch, and neither case leaks data, so I don't file them for this diff.
- `src/autobook/pipeline/trial.py:296`: a calendar month with no rows inside the corpus's range is
  neither tested nor listed under `by_month` (probed: rows in Jan and Apr give `tested: 1`). Such a
  month has nothing to test, so no number changes.

No other finding: I tried to break the strata, the bands, the sweep, the upper bound, privacy and
the CLI error paths, and the code held on each.

<!-- pdca:leaf-complete -->
