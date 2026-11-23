# Design proposal — issue 25 / rolling-origin-backtest

> Plan artifact for Ralphovi/autobook#25 (build order 2d, milestone `03 · 2 — Premise`).
> The design is settled in proposal 0001 (*Scenario 1*, *Why kNN over GnuCash's Bayes
> matcher*), architecture ch.5 (§5.2 *Trial tooling*), ch.6 (§6.6) and ch.8 (§8.3). This
> proposal fixes what those leave open (strata, bands, the report's shape and privacy, the
> CLI) so Do does not re-decide it. Do reads ONLY this file.

- **Slug:** rolling-origin-backtest
- **Kind:** enhancement (design proposal)
- **Goal:** Measure the premise of build step 2 honestly: a rolling-origin backtest in which month m is classified only by rows dated before month m, reporting precision and coverage per method (gated kNN, token-Bayes as the negative control) and per confidence band, stratified into memos seen before and novel memos, with a threshold sweep on the novel stratum, leave-one-out only as a labelled upper bound, and a CLI that writes the report to a file.
- **Success criterion:** `tests/test_backtest.py` passes with the patch applied and fails, with tests that RUN (not a collection error), with the production change reverted. It must assert: (a) on a planted corpus built in the test (source `GIROKONTO`, sign `out`, normalised with `normaliser.load(<empty tmp dir>)`): January 2025 holds `ALPHA` three times to `LEBENSMITTEL` and `BRAVO` three times to `MIETE`; February 2025 holds `ALPHA 123` to `LEBENSMITTEL`, `BRAVO REF 9` to `LEBENSMITTEL` and `ZULU KIOSK` to `LEBENSMITTEL`. With `max_distance=0.5`, `min_margin=0.5`, the kNN rolling-origin result is exactly: one month tested; stratum `seen` rows 2, accepted 2, correct 1, precision 0.5, coverage 1.0; stratum `novel` rows 1, accepted 0, correct 0, precision `null`, coverage 0.0; and `token_bayes` reports 3 rows in stratum `all`. (b) a future row never votes for a past one: adding five March 2025 rows `ALPHA` to `MIETE` to the planted corpus leaves the February entry of the per-month results identical, for every method. (c) on `build_corpus(seed)` for seeds 0, 1 and 2, with the same thresholds, the kNN `novel` stratum has exactly 1 row (the planted novel merchant) and it is not accepted. (d) `main(["backtest", "--corpus", <file>, "--out", <file>, "--max-distance", "0.5", "--min-margin", "0.5", "--normaliser-dir", <empty dir>])` on the serialised `build_corpus(0)` returns 0 and writes a JSON report whose text contains no merchant name from the fixture and no account path component (`Aktiva`, `Girokonto`, `Ausgaben`, …); on a file that is not a valid `corpus` contract it returns non-zero and writes no report. (e) the month boundary, not the row's own date, bounds the past: on a planted corpus (source `GIROKONTO`, sign `out`) with January 2025 holding `ALPHA` three times to `LEBENSMITTEL`, and February 2025 holding `CHARLIE` to `MIETE` on 2025-02-01 and `CHARLIE` to `MIETE` on 2025-02-20, the February kNN result is: stratum `novel` rows 2, accepted 0; stratum `seen` rows 0; and `token_bayes` in stratum `all` has accepted 2, correct 0. An index or token-Bayes count bounded by "rows before this row's date" would let the 1 February row vote for the 20 February one (kNN: `seen` and accepted; token-Bayes: `MIETE`, correct), and a single global index would do the same.
- **Falsifiability:** RED is reachable on the C4-verify gate (`engine/scripts/run-verify.sh`: host pytest in `$PDCA_WORKTREE` on the instance `.venv`, `-m "not applier and not live_paperless"`). Its red leg reverts every non-test hunk, so `src/autobook/pipeline/trial.py` returns to the stub (only `run_trial()`, raising `NotImplementedError`). The module exists on the base, so a module-scope `import autobook.pipeline.trial as trial` collects, and `trial.backtest` / `trial.main` raise `AttributeError` inside the test body: tests that RAN and FAILED. The scratch probe at Plan (3 placeholder tests on an `origin/main` export: 3 ran, 3 failed, 0 collection errors) only shows the collection shape: on `origin/main` such a test can also fail earlier, on the missing `normaliser.load`. The folded #23+#24 base does not exist yet, so the red *reason* on it cannot be probed at Plan; `trial.py` is not touched by #23 or #24, so it is still the stub there, and the first name this patch adds that a test reaches is `trial.backtest` / `trial.main`. Do confirms in `build-notes.md` that, with the production change reverted on the folded base, each test fails on a missing `trial` name and not on a missing #23/#24 name. This bundle runs in the wave after #24, on a folded base that holds #23's normaliser and #24's index (and scikit-learn, installed by the gate's dependency sync), none of which the red leg reverts.
- **Invariant to restore:** No backtest number is computed with information from the future of the row being classified (except leave-one-out, which is labelled an upper bound and never used for thresholds), threshold evidence comes from the novel stratum, and nothing that identifies a transaction (memo, token, merchant name, account name, amount, exact date) leaves the run in the report. Sources: proposal 0001 *Scenario 1* ("never lets a row's own future vote for it"; "gate thresholds are set on the novel stratum"; "Leave-one-out remains only as an upper bound"); ch.8 §8.3 ("Thresholds have evidence"); ch.8 §8.5 and AGENTS.md *Privacy rules* ("Never collect or commit transactions"; account names such as `Kirchensteuer` are Art. 9 data; logs carry IDs, counts and versions).
- **Repo + branch target:** Ralphovi/autobook @ main
- **Depends on:** 23, 24
- **Conflicts with:** none
- **Ordering note:** third wave of the chain #23 → #24 → #25. Declares #23 as well as #24 because it calls #23's API and needs #23's `IMPLEMENTED` set directly; the wave order does not change (#24 already depends on #23). Uses #23's `normaliser.load` / `Normaliser` and #24's `index_rows`, `IndexRow`, `KnnIndex` (including `query(..., exclude=...)`, added in #24 for this issue's leave-one-out). All three edit `tests/test_skeleton.py` and ch.5; the chain keeps them in separate waves. After this merges, set `[manual_test].cmd` in autobook-pdca's `pdca.toml` to the CLI (a harness change, not part of this patch).
- **Surfaces:** data
- **Difficulty:** high — one module made real (`src/autobook/pipeline/trial.py`), but it composes the contracts, the normaliser and the kNN index, adds the first CLI (a docs-currency item in ch.5 and ch.6), and its numbers are what the step-2 decision point is made on. A reviewer must hold the no-future rule, the strata, the privacy of the report and three upstream APIs in view at once.
- **Scope:** (1) the backtest and its CLI in `src/autobook/pipeline/trial.py` (API, method, report and CLI below); (2) `tests/test_backtest.py`; (3) add `"autobook.pipeline.trial"` to `IMPLEMENTED` in `tests/test_skeleton.py` (#23 defines it so that an `IMPLEMENTED` module skips all three assertions of `test_every_block_has_one_entry_point_that_is_not_implemented`: `len(__all__) == 1`, `callable`, `NotImplementedError`; if the folded base lacks this, stop and report it in `build-notes.md` rather than changing the exemption here); (4) docs currency: ch.5 §5.2 *Trial tooling* (method, strata, bands, sweep, report shape) and ch.6 §6.6 (the CLI command and its flags). / out of scope: the rule builder, assistant detector, pack validator and linkage backtest (the rest of the trial tooling); recording the version tuple of a successful trial (no tuple code exists yet); writing or changing any threshold anywhere (the report is evidence; a human sets thresholds); the corpus export from a real book (#26); the LLM; any new runtime dependency; setting `[manual_test].cmd` in autobook-pdca (follow-up after merge); a console-script entry point in `pyproject.toml`; per-cluster results (proposal 0001 *Scenario 1* says the backtest "yields per-method, per-cluster precision"; clusters come with the rule builder, which is out of scope here, and the issue does not ask for them; the PR description says they are deferred).
- **External dependencies:** `pypi` (the C4-verify dependency sync installs scikit-learn, declared by #24, into a fresh instance venv)
- **Test file:** tests/test_backtest.py
- **Citations expected:** Do must cite path:line on the target branch for every change it builds on: the stub `src/autobook/pipeline/trial.py` it replaces; the `IMPLEMENTED` set in `tests/test_skeleton.py` (from #23); `autobook.pipeline.normaliser` (`load`, `Normaliser`, `version`; from #23); `autobook.pipeline.classifier` (`index_rows`, `IndexRow`, `KnnIndex.build`, `KnnIndex.query` with `as_of` and `exclude`, `KnnResult`; from #24); `src/autobook/contracts.py` (`corpus_from_json`, `ContractError`, `CorpusRow`, `CorpusContract`, `corpus_to_json`); `tests/fixtures/synthetic/corpus_builder.py` (`build_corpus`, `MERCHANTS`, `NOVEL_MERCHANT`, `GIROKONTO`, `LEBENSMITTEL`, `MIETE`); `pyproject.toml` (ruff `T20`: no `print` in library code); ch.5 §5.2 *Trial tooling*, ch.6 §6.6.
- **Prior-art check (triage cycles):** searched by path. `git -C ../autobook log --all -- src/autobook/pipeline tests/test_skeleton.py` shows only the scaffold (0e0b7dc), a docs commit (2baf4d6), testenv (2a4b845) and #22's skeleton (23ce73f); `trial.py` is a stub. `gh pr list --state all` (8 PRs, all merged) has nothing on backtesting. Closed issue #5 (`NOT_PLANNED`) was split into #22–#26, not rejected; it described leave-one-out as the harness, which ch.6 §6.6 and proposal 0001 have since replaced with rolling-origin (leave-one-out kept only as an upper bound). Open #29 (linkage backtest) and #10 (shadow evidence) are later consumers, not prior art.
- **Disposition hint:** new-feature

## Motivation

Build step 2 is a decision point (ch.9): proposal 0001 is accepted or reworked on this
report. A leave-one-out number lets each row's future vote for it and flatters the
classifier exactly where it matters, on merchants seen for the first time. Rolling-origin
uses only the past, as production does, and the novel stratum is where confident errors
happen, so that is where thresholds are set.

## Design

### Public API

In `autobook.pipeline.trial`. `__all__` lists `run_trial` (still the stub, for the rest
of the trial tooling) plus:

- `backtest(corpus: CorpusContract, normaliser: Normaliser, *, max_distance: float,
  min_margin: float) -> dict[str, Any]`: runs everything below and returns the report as
  a JSON-ready dict (the exact object the CLI writes).
- `main(argv: Sequence[str] | None = None) -> int`: the CLI, below. The module ends with
  `if __name__ == "__main__": raise SystemExit(main())`.
- Module constants written into every report: `REPORT_VERSION = 1`, `BANDS` (band edges
  over confidence: `(0.5, 0.7, 0.9)`, giving `[0, 0.5)`, `[0.5, 0.7)`, `[0.7, 0.9)`,
  `[0.9, 1]`), `SWEEP_DISTANCES` and `SWEEP_MARGINS` (the sweep grid; Do picks values
  covering `(0, 1)`).

### Method

- **Rows.** `index_rows(corpus, normaliser)` (#24) gives one `IndexRow` per corpus row.
  The corpus row's `destination_account` is the truth.
- **Rolling origin.** The months are the calendar months from the first to the last
  `post_date`. The first month is never tested (its index would be empty). For every
  later month m: build one `KnnIndex` from all rows with `post_date` before the first day
  of m, and classify every row of m against it with `as_of` = that row's `post_date`.
  Nothing dated on or after the first day of m enters month m's index or month m's
  token-Bayes counts.
- **Stratum.** A test row is `seen` if some index row in the same `(source_account,
  sign)` partition has the same token; otherwise `novel`. Every result is also reported
  for `all`.
- **Methods.**
  - `knn`: the gated kNN of #24 with the given thresholds. A row counts as accepted iff
    `result.accepted`. Its confidence is `result.share`.
  - `token_bayes`, the negative control (proposal 0001: "reimplement token-Bayes …
    as a negative control"): per `(source_account, sign)`, multinomial naive Bayes over
    the whitespace-separated words of the token, trained on the same past-only rows,
    Laplace smoothing (add one), class priors from counts, no recency, computed in log
    space. It abstains only when the partition has no rows; ties go to the smaller path
    tuple, as in #24. Its confidence is the winner's normalised posterior. Standard
    library only.
- **Metrics,** per method and stratum: `rows`, `accepted`, `correct` (accepted and equal
  to the truth), `precision = correct / accepted` (`null` when `accepted` is 0),
  `coverage = accepted / rows` (`null` when `rows` is 0). Per method and band: the same
  counts over accepted rows whose confidence falls in the band.
- **Per month.** For every tested month, per method: `rows`, `accepted`, `correct`. This
  is what success criterion (b) compares.
- **Threshold sweep, novel stratum only.** For every pair in `SWEEP_DISTANCES ×
  SWEEP_MARGINS`, the kNN `rows`, `accepted`, `correct`, `precision`, `coverage` on the
  novel stratum, by re-applying the gate comparisons of #24 (`nearest_distance <=
  max_distance`, `margin >= min_margin`) to the stored rolling-origin results; no
  re-querying. A sweep never feeds back into the run.
- **Leave-one-out, upper bound only.** One `KnnIndex` over all rows, and every row
  queried with `exclude=row` (#24) and `as_of` = its own `post_date`. Reported under
  `upper_bound`, never in `methods`, never in the sweep. Strata as above, with "seen"
  meaning another row of the partition has the same token.

### Report (JSON)

One object: `report` (`"backtest"`), `report_version`, `normaliser_version`,
`thresholds` (`max_distance`, `min_margin`, `half_life_days`), `bands`, `months`
(`first` and `last` as `YYYY-MM`, `tested`, and the per-month list keyed by `YYYY-MM`),
`methods` (`knn`, `token_bayes`, each with `strata` and `bands`), `upper_bound`
(`knn_leave_one_out`, with `strata`), and `novel_sweep`. Do may add fields; these are the
ones tests and ch.5 rely on.

**Privacy.** The report holds counts, rates, versions, thresholds and months only: no
memo, token, merchant name, account name or path, amount or day. Accounts are not
named even as indices, because a per-account breakdown on a real book would show what a
user spends on (ch.8 §8.5). The CLI logs nothing else.

### CLI

`python -m autobook.pipeline.trial backtest --corpus <corpus.json> --out <report.json>
--max-distance <x> --min-margin <y> [--normaliser-dir <dir>]`, with `argparse`
sub-commands so the rest of the trial tooling can join later. `--max-distance` and
`--min-margin` are required (no default threshold, as in #24). `--normaliser-dir` is
passed to `normaliser.load`; omitted, the default user directory applies. The corpus file
is read with `corpus_from_json`; a `ContractError`, an unreadable file or a
`NormaliserError` gives a one-line message on stderr and exit code 2, and no report file
is created. On success the report is written (UTF-8, indented JSON) and the exit code is
0. Output goes through `sys.stdout` / `sys.stderr` writes, not `print` (ruff `T20`).

### Tests and the gate (C4-verify requirements: read this before writing a test)

- `tests/test_backtest.py`: success criterion (a)–(e), plus anything else above Do
  considers worth pinning (leave-one-out reported only under `upper_bound`, band counts
  summing to `accepted`, sweep row count). Build the planted corpora of (a) and (b) as
  `CorpusRow`s in the test (integer cents, invented names). Write the corpus file for
  (d) with `corpus_to_json` into `tmp_path`.
- Expected numbers in (a) and (e) follow from the #23 and #24 briefs, which fix these
  rules (their code is on the folded base, not on `origin/main`):
  - #23 brief, *Profiles*, `default`: strips `REF <digits>` and standalone digit runs,
    so `ALPHA 123` → `ALPHA` and `BRAVO REF 9` → `BRAVO`; both are `seen`.
  - #24 brief, *Semantics*, *Weights and vote*: each neighbour weighs `(1 - distance) *
    0.5 ** (age_days / half_life_days)`, so a neighbour at cosine distance 1 weighs 0.
    `ALPHA` and `BRAVO` share no `char_wb` 3–5-gram, so in the 6-row partition a
    `BRAVO` query sees 3 `BRAVO`→`MIETE` rows at distance 0 and 3 `ALPHA` rows at
    distance 1 with weight 0: `MIETE` share 1, margin 1, accepted, and wrong (truth
    `LEBENSMITTEL`). Same for `ALPHA` (accepted, correct).
  - `ZULU KIOSK` (and `CHARLIE` in (e)) share no 3–5-gram with the history: distance 1,
    the distance gate fails.
  Check these on the folded base first. If #23's `default` profile or #24's weight rule
  there differs from the above, stop and report the mismatch in `build-notes.md`; do
  not change the expected numbers to fit the code.
- (c) rests on two facts: #23's success criterion (a) guarantees that for seeds 0, 1
  and 2 every `build_corpus` row normalises to exactly its merchant token (every `NOISE`
  variant, including `SAGT DANKE {n}`, `KARTE {n} {d}.{m}.` and `NR. {n}`, is
  stripped); and `corpus_builder.MERCHANTS` books every merchant at least once a month
  (`per_month` lower bound 1), so after January each merchant is `seen` and only the
  planted `NOVEL_MERCHANT` row is `novel`.
- `tests/test_skeleton.py`: add `"autobook.pipeline.trial"` to `IMPLEMENTED`.

Rules every test file in this patch must follow, or the gate cannot judge it:

1. **Import only modules that exist on the base at module scope, as modules**
   (`import autobook.pipeline.trial as trial`, `import autobook.pipeline.normaliser as
   normaliser`, `import autobook.contracts as contracts`, `from tests.fixtures.synthetic
   import corpus_builder`). Reach every name this patch adds through the module object
   inside the test body. A module-scope `from autobook.pipeline.trial import backtest`
   is a collection error on the red leg (UNVERIFIABLE), not red. Call `main(...)` in
   process; do not start a subprocess (that would need an `S603` exception under
   `tests/**`).
2. **Keep the words `applier` and `live_paperless` out of every test file.**
3. **No `pytest.importorskip`, no skips.**

### Docs currency (same PR)

A new CLI command and flags (AGENTS.md *Docs currency*; ch.8 §8.9): update ch.5 §5.2
*Trial tooling* (method, strata, methods, bands, sweep, upper bound, report fields,
privacy rule) and ch.6 §6.6 (the command line).

## Alternatives considered

- **Leave-one-out as the main number** (closed #5). Rejected by proposal 0001 and ch.6:
  it lets a row's future vote for it.
- **Thresholds chosen by the harness.** Rejected: the report is evidence; thresholds
  move by a human decision on that evidence (AGENTS.md "Never widen a threshold …").
- **Per-account results in the report.** Rejected for privacy: account names are
  personal data, and per-account counts reveal spending patterns.
- **A console script in `pyproject.toml`.** Not chosen: `python -m` works from `src/` on
  `PYTHONPATH`, which is how C4-verify and `autobook-pdca try` run the worktree, and adds
  no packaging surface yet.
- **Markdown report.** Not chosen: JSON can be compared across runs and read by later
  tooling (#10 shadow evidence); a human-readable rendering can come later.

## Impact & compatibility

New behaviour behind an existing stub; the first CLI. Reads one corpus file and the
normaliser profiles; writes one report file. No network, no book access, no new
dependency. Expect the advisory `T2-threat-model` check to stay quiet:
`src/autobook/pipeline/trial.py` matches none of its path patterns (checked against
`engine/scripts/check-threat-model-touch.sh`). Run time is one index build per tested
month plus one leave-one-out build, which should stay within proposal 0001's "seconds to
a minute" on 30–60k rows; not tested here.

## Open questions

None open. Settled with the maintainer (eduralph) in the Plan session: the CLI form
`python -m autobook.pipeline.trial backtest …`, a JSON report holding counts and rates
only, the novel-stratum threshold sweep, and setting `[manual_test].cmd` in autobook-pdca
as a follow-up after merge. These are not on the issue thread; the PR description must
state them, and that per-cluster results (proposal 0001 *Scenario 1*) are deferred.

Plan-review response: (1) new criterion (e) plants a within-month case that a
row-date-bounded or global index fails, so the month-boundary rule is tested; (2) the
reasoning for (a)'s numbers now cites the #24 weight rule (a distance-1 neighbour
weighs 0, so the vote is unanimous) and #23's `REF`/digit rules, and Do must stop
rather than adjust the numbers if the folded base differs; (3) (c) now names what
guarantees it: #23's criterion (a) over the same seeds, plus every merchant being
booked monthly (checked in `corpus_builder.py` on `origin/main`); (4) Falsifiability
no longer presents the `origin/main` probe as proof of the red reason, and Do confirms
the reason on the folded base; (5) per-cluster results are out of scope and named for
the PR; (6) `Depends on` is now `23, 24`.

## STOP discipline

Draft only until Check sign-off. Pushing to a feature/draft branch and opening a
draft PR MAY happen during the cycle (useful for CI feedback). The PR MUST NOT be
marked ready before sign-off accepts.

## Iteration 1 — carry-forward (from the previous attempt)
- Sign-off rationale: Auto-iterate (round 1): rebuilding for the implementation-level findings — C5 Causal adequacy — Fix empty-vocabulary token-Bayes and restore the specified band counts — valid corpus data currently aborts the report, and band records omit required evidence; independently probed at src/autobook/pipeline/trial.py:125 and src/autobook/pipeline/trial.py:185.; The gating C4-ci row fails on both attempts (`gate-logs/C4-ci.log`). `ruff check` raises PLR0402 at `tests/test_backtest.py:21`, `:22` and `:23` (`import autobook.pipeline.trial as trial` etc.). `ruff format --check` wants to reformat `tests/test_backtest.py:105-107`. The brief prescribed the `import a.b.c as c` form, but `from autobook.pipeline import trial, normaliser` / `from autobook import contracts` is also a module-scope module import, so it collects on the red leg too. Existing tests already use that form (`tests/test_knn.py:23`, `tests/test_normaliser.py:24`). Then run `ruff format`. Until this is fixed, the gate is red and the patch cannot be accepted, whatever the review says.; `src/autobook/pipeline/trial.py:125-128` crashes with `ZeroDivisionError` when a month's past rows in a `(source_account, sign)` partition all have blank tokens and the test row has words. In that case `vocabulary == 0` and the class word count is 0, so `denominator == 0`. Blank tokens are normal normaliser output: under the `default` profile, `"12345"`, `"REF 99"` and `" "` all normalise to `''`. Concrete failing case: January has one row `"12345"` → `MIETE`, February has one row `"ALPHA"` → `MIETE` (both `GIROKONTO`/`out`). `backtest()` raises `ZeroDivisionError` at `trial.py:128`. On the CLI path, `main()` (`trial.py:413-416`) catches only `ContractError`/`NormaliserError`/`KnnError`/`OSError`/`UnicodeDecodeError`, so a real corpus export with a reference-only first month in some partition ends with a traceback, not a report. Guard `denominator == 0`, or use `vocabulary + 1`-style smoothing so that unseen words still give a finite likelihood, and add a test.; The threshold-evidence path is barely tested. `tests/test_backtest.py:221-228` only checks a sweep where every cell is `accepted == 0` (one novel row at distance 1), so any sweep that returns zeros passes. I mutated `trial.py:212` from `o.candidate_correct` to `o.correct` (only rows accepted at the run's own thresholds). That would make sweep precision wrong at every looser grid point, which is exactly the number a human sets thresholds from, and all 10 tests still passed. These mutants also survived: the token-Bayes prior dropped (`trial.py:126` → `score = 0.0`), Laplace smoothing removed (`trial.py:128`), the leave-one-out `seen` rule changed to `> 0` (`trial.py:359`), and the `seen` key made to ignore the `(source_account, sign)` partition (`trial.py:300/304`; no test has two partitions). The code is correct today, but nothing pins it. Add one planted near-match novel row (for example `ALPHA MARKT` history vs `ALPHA MARKET`) with expected sweep `accepted`/`correct` at two grid cells, plus a two-partition `seen` case.; C4 Autobook gate: nox -s gate (fmt/lint/types/test/typos/docs) FAILED (gating) — nox > * docs: success. Deferred, not addressed here: 8 finding(s) that need human judgment, held in deferred-findings.json for the human at handover — not build work
- Failing gate: C4 Autobook gate: nox -s gate (fmt/lint/types/test/typos/docs) — nox > * docs: success
- Full previous attempt preserved in `iteration-v1/` (patch.diff, build-notes.md, SUMMARY.md, check-*).
- Address the above; do NOT re-attempt the rejected approach unchanged. Satisfy the brief's Success criterion (the end result).

## Iteration 2 — carry-forward (from the previous attempt)
- Sign-off rationale: Auto-iterate (round 2): rebuilding for the implementation-level findings — C5 Causal adequacy — Sanitize rejected-input diagnostics and test stderr privacy — the CLI forwards validation text containing transaction amounts/dates into logs, violating the promised output boundary (`target/src/autobook/pipeline/trial.py:418`, `target/src/autobook/contracts.py:240`, `target/tests/test_backtest.py:205`).; `src/autobook/pipeline/trial.py:212-213`: no test pins the sweep's gate boundaries. Changing `<=` to `<` or `>=` to `>` leaves all 14 tests passing (I checked each mutant). The `>` case does real damage. A unanimous vote has a margin of exactly `1.0`, the most common case for a familiar merchant, so under the mutant the whole `min_margin=1.0` column of `novel_sweep` would read 0 accepted. On the corpus of `test_sweep_re_applies_both_gates_to_the_novel_stratum`, cell `(0.5, 1.0)` is `(accepted 2, correct 1)` today, and the mutant gives `(0, 0)`. Add `(0.5, 1.0): (2, 1)` to `expected` at `tests/test_backtest.py:341`.; `src/autobook/pipeline/trial.py:193`: no test pins the half-open band edges either. Swapping `bisect_right` for `bisect_left` leaves every test green. Concrete case: January has `ALPHA`→`MIETE` and `ALPHA`→`LEBENSMITTEL`, and February has `ALPHA`. Token-Bayes then ties at a confidence of exactly `0.5`. Today that lands in `[0.5,0.7)` (I probed it). Under the mutant it lands in `[0,0.5)`, which breaks the `[0.5,0.7)` contract in the brief and in ch.5. One `_band_accepted` assertion on that corpus would pin it.; `src/autobook/pipeline/trial.py:235`: no test pins `as_of=row.post_date`, which the brief requires for every test row. Shifting `as_of` ten years into the future leaves all 14 tests green. In every planted corpus the competing neighbours are about the same age, so recency decay never changes the winner. A small test with an old class and a recent class at equal distance would pin it, for example 2 old rows against 1 recent row, where the half-life flips the vote.. Deferred, not addressed here: 7 finding(s) that need human judgment, held in deferred-findings.json for the human at handover — not build work
- Full previous attempt preserved in `iteration-v2/` (patch.diff, build-notes.md, SUMMARY.md, check-*).
- Address the above; do NOT re-attempt the rejected approach unchanged. Satisfy the brief's Success criterion (the end result).

## Iteration 3 — carry-forward (from the previous attempt)
- Sign-off rationale: Rest of the patch is accepted as-is; fix only the two C5 findings, each with a regression test: 1. Error-message privacy: `_refused` (trial.py, `_FIELD` match) lets a slash-free relative normaliser profile path (e.g. `PRIVATE_PROFILE`) reach stderr, breaking the ch.6 §6.6 promise that profile paths never appear. Only pass on locations from known contract/index field roots (or drop normaliser locations entirely). Add a test using a relative, slash-free profile path. 2. Empty calendar months: the backtest groups only months that contain rows, so a gap month (e.g. rows in Jan and Mar) is neither listed in `by_month` nor counted in `months.tested`. The brief requires every calendar month from first to last post_date. Enumerate the inclusive range; a gap month gets zero counts for every method. Add a gap-month test asserting zero-count entries and the right `tested` count. Do not change anything else — strata, bands, sweep, leave-one-out and the report shape were reviewed and cleared.
- Sign-off session carry-forward (captured live, before §9 flattened it):
  Rest of the patch is accepted as-is; fix only the two C5 findings, each with a regression test:
  1. Error-message privacy: `_refused` (trial.py, `_FIELD` match) lets a slash-free relative normaliser profile path (e.g. `PRIVATE_PROFILE`) reach stderr, breaking the ch.6 §6.6 promise that profile paths never appear. Only pass on locations from known contract/index field roots (or drop normaliser locations entirely). Add a test using a relative, slash-free profile path.
  2. Empty calendar months: the backtest groups only months that contain rows, so a gap month (e.g. rows in Jan and Mar) is neither listed in `by_month` nor counted in `months.tested`. The brief requires every calendar month from first to last post_date. Enumerate the inclusive range; a gap month gets zero counts for every method. Add a gap-month test asserting zero-count entries and the right `tested` count.
  Do not change anything else — strata, bands, sweep, leave-one-out and the report shape were reviewed and cleared.
- Full previous attempt preserved in `iteration-v3/` (patch.diff, build-notes.md, SUMMARY.md, check-*).
- Address the above; do NOT re-attempt the rejected approach unchanged. Satisfy the brief's Success criterion (the end result).
