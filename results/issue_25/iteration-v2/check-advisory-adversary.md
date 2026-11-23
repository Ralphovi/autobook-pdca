# Adversarial review — issue 25 / rolling-origin-backtest (iteration 2)

**Bottom line: I could not refute the fix.** The red→green proof holds, and the rules about past-only data and privacy hold under every attack I tried. What's left is three test gaps the builder can close in one pass, plus one minor point about the spec.

## Evidence re-run

- Green: I ran `tests/test_backtest.py` and `tests/test_skeleton.py` from `$PDCA_TARGET`. All 19 passed. scikit-learn is not installed on the host, so I used an existing venv that has it, only as the interpreter, with `src/` from the target.
- Red: `gate-logs/C4-verify.log` shows all 14 backtest tests failing for the right reason: 12 with `AttributeError ... no attribute 'backtest'` and 2 with `... 'main'`. There were no collection errors. The 5 tests that pass on the red leg are the skeleton tests.
- The tests call the production path (`trial.backtest` / `trial.main`), not a copy of it.

## Findings

- NEEDS-HUMAN [impl] — `src/autobook/pipeline/trial.py:212-213`: no test pins the sweep's gate boundaries. Changing `<=` to `<` or `>=` to `>` leaves all 14 tests passing (I checked each mutant). The `>` case does real damage. A unanimous vote has a margin of exactly `1.0`, the most common case for a familiar merchant, so under the mutant the whole `min_margin=1.0` column of `novel_sweep` would read 0 accepted. On the corpus of `test_sweep_re_applies_both_gates_to_the_novel_stratum`, cell `(0.5, 1.0)` is `(accepted 2, correct 1)` today, and the mutant gives `(0, 0)`. Add `(0.5, 1.0): (2, 1)` to `expected` at `tests/test_backtest.py:341`.
- NEEDS-HUMAN [impl] — `src/autobook/pipeline/trial.py:193`: no test pins the half-open band edges either. Swapping `bisect_right` for `bisect_left` leaves every test green. Concrete case: January has `ALPHA`→`MIETE` and `ALPHA`→`LEBENSMITTEL`, and February has `ALPHA`. Token-Bayes then ties at a confidence of exactly `0.5`. Today that lands in `[0.5,0.7)` (I probed it). Under the mutant it lands in `[0,0.5)`, which breaks the `[0.5,0.7)` contract in the brief and in ch.5. One `_band_accepted` assertion on that corpus would pin it.
- NEEDS-HUMAN [impl] — `src/autobook/pipeline/trial.py:235`: no test pins `as_of=row.post_date`, which the brief requires for every test row. Shifting `as_of` ten years into the future leaves all 14 tests green. In every planted corpus the competing neighbours are about the same age, so recency decay never changes the winner. A small test with an old class and a recent class at equal distance would pin it, for example 2 old rows against 1 recent row, where the half-life flips the vote.
- `src/autobook/pipeline/trial.py:295`, `:300`, `:332` (minor, no number changes): the brief says the months run "from the first to the last `post_date`". The code only walks months that contain rows. On a corpus with rows in January and March only, the probe gives `tested: 1` and `by_month` has no `2025-02` entry. Precision and coverage are unaffected. A reader just can't tell an empty month from a missing one. Either list empty months with zero counts, or say in ch.5 that only months with rows are listed.

## Refutation attempts that failed

- **Future leakage.** Training token-Bayes on all rows is caught. So is testing the first month. A row-date-bounded or global index is caught by criterion (e) (`seen` rows would be non-zero). Comparing months as tuples instead of with `< start` gives the same results, so it is not a real mutant.
- **Blank-token history** (the previous round's `ZeroDivisionError`). Now handled by skipping words the partition has never seen (`trial.py:120-123`), and pinned by a test that goes through both the API and the CLI. Skipping unseen words is a documented choice (ch.5). It matches how scikit-learn's naive Bayes treats unseen features.
- **Sweep honesty.** The previous round's `o.correct` mutant is now caught: the run's own gates accept no novel row, so `correct` in the sweep can only come from `candidate_correct`. Seen rows leaking into the sweep is also caught (`rows` would be 4, not 3).
- **Leave-one-out** without `exclude` is caught. Leave-one-out never appears under `methods` or in the sweep.
- **Privacy.** The report holds only counts, rates, thresholds, band labels, `YYYY-MM` labels and `normaliser_version`. That version is a SHA-256 digest (a fixed-length fingerprint) of the normaliser's settings, so it reveals no profile or account name (`normaliser.py:350-371`). CLI errors print exception messages and type names, never row content from the backtest itself.
- **Edge inputs.** An empty corpus gives `tested: 0` with `first`/`last` set to null and no crash. Bad thresholds (including `nan`) are refused up front by `KnnIndex.build`, even when no month gets tested. A non-corpus file, bad JSON or a missing file each give exit code 2 and no report.
- **Reviewer claims.** The `C4-verify` claim "red without the fix (14 of 19 failed), green with it" matches the log and my re-run. `C4-ci` is green on every nox session (nox runs the repo's checks: format, lint, types, tests, typos, docs).

<!-- pdca:leaf-complete -->
