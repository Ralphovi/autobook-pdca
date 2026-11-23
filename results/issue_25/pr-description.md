## Summary
**User impact:** There is no honest way yet to tell how often the automatic account
suggestions would be right on your own book. The only measure described so far
(leave-one-out) lets a transaction be judged with help from later ones, so it looks
best exactly where suggestions are most likely to be wrong: shops and payees you pay
for the first time. A decision on whether the classifier is good enough, or where its
confidence thresholds should sit, would rest on a flattering number.

This PR adds a backtest command that replays the book month by month, using only
what was known before each month started, and writes a report of how often the
suggestions were accepted and right, split into payees seen before and new payees.
The report holds counts and rates only, never a transaction detail.

Reported in [#25](https://github.com/Ralphovi/autobook/issues/25).

**Stacked PR.** This builds on the normaliser (#50, for #23) and the kNN index (#51,
for #24), both still drafts. Please review and merge those first; until then this
branch's diff against `main` also shows their changes.

## What to look at
- **The command.** `python -m autobook.pipeline.trial backtest --corpus <corpus.json>
  --out <report.json> --max-distance <x> --min-margin <y> [--normaliser-dir <dir>]`.
  Both thresholds are required; there is no default.
- **Try it** on the synthetic fixture: serialise `build_corpus(0)` from
  `tests/fixtures/synthetic/corpus_builder.py` with `corpus_to_json`, run the command
  above with `--max-distance 0.5 --min-margin 0.5`, and read the JSON. You should see
  one new-payee row per tested month (the planted novel merchant), not accepted, and no
  merchant or account name anywhere in the file.
- **What the report contains:** for the kNN classifier and for a simple token-Bayes
  comparison (the kind of matcher GnuCash's import uses, kept as a negative control),
  precision and coverage for "seen before" vs "new" payees and per confidence band; a
  per-month breakdown; a threshold sweep on new payees only; and leave-one-out, labelled
  as an upper bound and kept out of everything else.

**Decisions settled with the maintainer during design** (not on the issue thread):
- The command line form is `python -m autobook.pipeline.trial backtest …`, with
  sub-commands so the rest of the trial tooling can join later. No console script yet.
- The report is JSON with counts, rates, versions, thresholds and months only. No
  per-account breakdown: account names are personal data, and per-account counts would
  show what someone spends on.
- The threshold sweep runs on new payees only, since that is where confident errors
  happen. The report is evidence; it sets no threshold.
- Per-cluster results (proposal 0001, *Scenario 1*) are **deferred**: clusters come with
  the rule builder, which is out of scope here.
- Follow-up after merge, outside this repo: point the manual-test command of
  Ralphovi/autobook-pdca at this CLI.

**Known limitation.** Every calendar month between the first and last date is tested,
including months with no rows (they get zero counts, so the per-month list has no
holes). Each such month still builds an index that nothing queries. On a normal book
that costs little, but one mistyped far-future date (say 2099) would add about 900
empty builds, roughly 4–5 minutes on 34.5k rows. Skipping the build for empty months
is a small follow-up.

## Root cause
`src/autobook/pipeline/trial.py` was a stub (`run_trial()` raising
`NotImplementedError`), so nothing measured the classifier at all. The design (proposal
0001, ch.6 §6.6) had already replaced leave-one-out with a rolling-origin backtest, but
it left the strata, bands, report shape, privacy rule and command line open.

## Fix
- `backtest()` (`src/autobook/pipeline/trial.py:284-358`): for each calendar month
  after the first, builds one kNN index and one token-Bayes model from rows dated
  **before the first day of that month**, and classifies the month's rows against them
  with `as_of` set to each row's own date. A row is "seen" if the same token exists in
  the same source account and sign in that history; otherwise "novel".
- Token-Bayes negative control (`trial.py:96-141`): multinomial naive Bayes over the
  token's words per source account and sign, add-one smoothing over the partition
  vocabulary, priors from counts, no recency. Standard library only.
- Bands, sweep and leave-one-out (`trial.py:67-72`, `:188-229`, `:360-380`): bands are
  `[0, 0.5)`, `[0.5, 0.7)`, `[0.7, 0.9)`, `[0.9, 1]`. The sweep re-applies the kNN
  gates (`distance <= max_distance`, `margin >= min_margin`) to the stored novel-row
  results without re-querying. Leave-one-out uses one index over all rows with
  `exclude=row` and is reported only under `upper_bound`.
- CLI (`trial.py:389-470`): `argparse` sub-command; reads the corpus with
  `corpus_from_json`. A refused corpus, profile set or threshold gives a one-line
  message on stderr, exit code 2 and no report file. The message names at most a corpus
  field path or a threshold name (`trial.py:417-440`), never a value and never a profile
  path. Output goes through `sys.stdout`/`sys.stderr`, not `print`.
- `tests/test_skeleton.py`: `autobook.pipeline.trial` added to `IMPLEMENTED`.
- Docs: ch.5 §5.2 *Trial tooling* (`05-building-block-view.md:484-535`) and ch.6 §6.6
  (`06-runtime-view.md:143-166`) describe the method, report fields, privacy rule and
  command line.

No new runtime dependency. No network, no book access; reads one corpus file and the
normaliser profiles, writes one report file.

## Verification
Line numbers are on this branch (the stacked base plus this change).

- **Claim:** nothing dated on or after the start of the tested month is used, not even
  rows earlier in the same month.
  **Checked:** `trial.py:310-313` (history is `post_date < start`, built once per month).
  **Test:** `test_a_future_row_never_votes_for_a_past_one` (adding later rows leaves
  February unchanged for every method) and
  `test_the_month_boundary_bounds_the_past_not_the_row_date` (a 1 Feb row cannot vote
  for a 20 Feb row), `tests/test_backtest.py:145`, `:165`.
- **Claim:** the planted corpus gives the exact numbers in the issue (seen: 2 rows, 2
  accepted, 1 correct; novel: 1 row, 0 accepted).
  **Test:** `test_planted_corpus_numbers`, `tests/test_backtest.py:129`; on the
  synthetic corpus for seeds 0–2 the only novel row is the planted merchant, not
  accepted (`:157`).
- **Claim:** every calendar month in range is tested and listed, including empty ones
  and across a year end.
  **Checked:** `trial.py:151-155`, `:303-305`.
  **Test:** `test_a_calendar_month_without_rows_is_listed_with_zero_counts`, `:180`.
- **Claim:** the report and stderr carry no identifying data.
  **Checked:** `trial.py:417-459` (only known field roots are echoed; profile paths
  never).
  **Test:** `test_cli_writes_a_report_without_identifying_data`,
  `test_cli_refusals_name_the_field_never_the_value`,
  `test_a_relative_profile_path_never_reaches_stderr`, `:206`, `:244`, `:294`.
- **Claim:** the sweep, bands and token-Bayes behave as specified at their edges.
  **Test:** `test_sweep_re_applies_both_gates_to_the_novel_stratum`,
  `test_sweep_gates_are_inclusive_at_both_edges`,
  `test_a_confidence_on_a_band_edge_falls_in_the_band_above`,
  `test_token_bayes_smooths_over_the_partition_vocabulary`,
  `test_a_history_of_blank_tokens_still_gives_a_report`,
  `test_seen_is_decided_within_the_source_account_and_sign`,
  `test_recency_is_measured_from_the_test_row_after_its_history`, `:325`–`:528`.
- **Red/green:** with the change to `trial.py` reverted, 21 of the 26 tests in
  `tests/test_backtest.py` fail (they run; none is a collection error); with it, all
  26 pass. Mutating the sweep gates, band edges, `as_of`, the seen/novel key, the
  month enumeration or the error-message filter is caught by at least one test.
- **Full gate:** `nox -s gate` (fmt, lint, types, test, typos, docs) passes.

Fixes #25
