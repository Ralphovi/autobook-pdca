# Build notes — issue 25 / rolling-origin-backtest (iteration 2)

Base: folded #23+#24 tip `450f7c8` (`pdca-integration/main-r1726f2053868`, worktree
`autobook.pdca-wt`). Line numbers below are on that base plus this patch.

This iteration starts from the iteration-1 patch (`iteration-v1/patch.diff`) and fixes
everything the carry-forward names. The design is otherwise unchanged.

## Carry-forward, item by item

1. **C4-ci red: PLR0402 and `ruff format`.** The test now imports
   `from autobook import contracts` and `from autobook.pipeline import normaliser, trial`
   (`tests/test_backtest.py:21-22`), the form `tests/test_knn.py:23` uses. These are still
   module-scope module imports, so the red leg still collects (checked below). The file
   was run through `nox -s fmt -- --fix`. That reflowed one line in `trial.py:197`. The
   test-file line it flagged last time (`:105-107`) is now written as two locals
   (`tests/test_backtest.py:150-153`). `mypy` also flagged `sign: str` against
   `CorpusRow.sign: Sign`. The test now uses `contracts.Sign` (`src/autobook/contracts.py:71`).

2. **Token-Bayes `ZeroDivisionError` on a blank-token history**
   (`iteration-v1` `trial.py:125-128`). Cause: an unseen word was scored as
   `1 / (class_words + V)`, and when every history token of the partition is blank,
   `class_words == V == 0`. Fix (`trial.py:123-127`): only words the partition's history
   holds are scored. This is the textbook multinomial NB test step (Manning et al., *IR*,
   ch.13, `ExtractTokensFromDoc(V, d)`): a word outside the vocabulary carries no evidence
   for any class. With that rule, every scored word is in the vocabulary, so `V >= 1` and
   the denominator is `>= 1`. A token with no known word, or a blank one, is decided by the
   priors. This keeps the brief's "abstains only when the partition has no rows".
   - Considered and not chosen: `V + 1` in the denominator (an "unknown word" slot). That
     also removes the crash, with one line changed. But it keeps the old effect where an
     unseen word pushes toward the class with fewer words. That is an artefact, not
     evidence, and it would make the negative control weaker for no reason. Same size of
     change either way (one line), so the deciding axis was correctness, not cost.
   - Regression: `test_a_history_of_blank_tokens_still_gives_a_report`
     (`tests/test_backtest.py:218`). January `12345` (normalises to `''`) → MIETE,
     February `ALPHA` → MIETE. It checks the report through `backtest()` and that the
     CLI returns 0 and writes the identical report. Against the iteration-1 `trial.py` it
     fails (ZeroDivisionError).
   - Behaviour change from iteration 1: an unseen word no longer moves the posterior.
     (e)'s expected numbers do not depend on it (one class in the history).
   - Docs: ch.5 now says unknown words are skipped (`05-building-block-view.md`, *Methods*).

3. **Band records omit `rows`** (`iteration-v1` `trial.py:185`). `_bands`
   (`trial.py:180-198`) now builds each band with the same `_rates` helper as a stratum, so
   it carries `rows`, `accepted`, `correct`, `precision`, `coverage`. **Definition I chose
   for `rows`:** every tested row of the method, i.e. the coverage denominator. So a
   band's coverage is "share of all rows accepted at this confidence", and the bands'
   `accepted` and `coverage` add up to the `all` stratum. The brief says "the same counts
   over accepted rows whose confidence falls in the band". Read literally, that makes
   `rows == accepted` and `coverage == 1` in every band, which tells a reader nothing. The
   reviewer asked to "test each field and its denominator", so `rows` is the denominator.
   This is a judgment call; if the human wants the literal reading, it is a one-line
   change at `trial.py:197` (`_rates(accepted[i], accepted[i], correct[i])`). Documented
   in the `_bands` docstring and in ch.5 *Bands*. Test:
   `test_band_records_carry_every_count` (`tests/test_backtest.py:297`) checks `rows`,
   `coverage = accepted/rows`, `precision = correct/accepted` (or `null`), and that the
   band `accepted` and `correct` sum to the `all` stratum, for both methods.

4. **Threshold-evidence path barely tested; mutants survived.** New tests, and the
   mutants each one kills (all run against this patch, each restored after):

   | Mutant (iteration-1 reviewer's list + two more) | Killed by |
   |---|---|
   | sweep counts `o.correct` instead of `o.candidate_correct` (`trial.py:217`) | `test_sweep_re_applies_both_gates_to_the_novel_stratum` |
   | sweep ignores the margin gate (`trial.py:213`) | same |
   | token-Bayes prior dropped (`trial.py:132` → `score = 0.0`) | `test_token_bayes_priors_decide_a_token_with_no_known_word` |
   | Laplace `+1` removed (`trial.py:134`) | `test_token_bayes_smooths_over_the_partition_vocabulary` |
   | `+ vocabulary` dropped from the denominator (`trial.py:131`) | same |
   | leave-one-out `seen` as `> 0` (`trial.py:364`) | `test_leave_one_out_is_reported_only_as_an_upper_bound` |
   | `seen` ignores `(source_account, sign)` (`trial.py:309`) | `test_seen_is_decided_within_the_source_account_and_sign` |
   | one global index instead of month-bounded history (`trial.py:302`) | `test_planted_corpus_numbers` (and (e)) |

   Result of the mutation run: 8 of 8 killed.

   The sweep test (`tests/test_backtest.py:318`) plants three novel near-matches with
   different distances and margins, and one seen row that must stay out of the sweep. It
   runs the backtest at strict gates (0.2 / 0.5), so the run itself accepts no novel row
   and every sweep acceptance comes from re-applying the gates. It pins five grid cells:
   distance only, margin only, both, and none. The distances are not derived by hand.
   I measured them with the real `KnnIndex` on this corpus: `BRAVO HAUSE` 0.374,
   `MARKT HAUS` 0.465 with margin 0.109, `ALPHA MARKET` 0.481. The pinned cells are at
   least 0.009 from every measured value. The computation is deterministic (TF-IDF on a
   fixed corpus), so this is stable unless #24's distance changes. If it does, the test
   should be re-derived, not loosened.

   The two token-Bayes numbers are derived by hand in the test comments:
   - priors 3:1, no known word → MIETE at 0.75, band `[0.7,0.9)`. Without priors it is a
     tie → LEBENSMITTEL at 0.5.
   - vocabulary 6, query `ALPHA` → posterior 22/29 ≈ 0.759, band `[0.7,0.9)`. Without `V`
     it is 10/11 ≈ 0.909, the band above.

## Brief checks on the folded base (unchanged from iteration 1, re-confirmed)

- #23 `default` profile: `ALPHA 123` → `ALPHA`, `BRAVO REF 9` → `BRAVO`, and `12345` /
  `REF 99` / `" "` → `''` (probed through `normaliser.load(<empty dir>)`,
  `src/autobook/pipeline/normaliser.py:120`).
- #24 weight rule: `(1 - distance) * 0.5 ** (age/half_life)` at
  `src/autobook/pipeline/classifier.py:418`; gates at `:433-436`. As the brief states.
  No "stop and report" item was triggered.
- `IMPLEMENTED` exists on the base (`tests/test_skeleton.py:22`, used at `:56`); this
  patch only adds `"autobook.pipeline.trial"` (`:25`).

## Upstream APIs used (path:line on the target)

- Stub replaced: `src/autobook/pipeline/trial.py:1-18` at base (`run_trial` raising
  `NotImplementedError`; kept, now `trial.py:371`).
- `normaliser.load` `normaliser.py:120`, `Normaliser` `:89`, `NormaliserError` `:64`.
- `classifier.index_rows` `classifier.py:163`, `IndexRow` `:107`, `KnnResult` `:144`,
  `KnnIndex` `:293`, `.build` `:311`, `.query(..., as_of, exclude)` `:356`,
  `HALF_LIFE_DAYS` `:46`.
- `contracts.ContractError` `contracts.py:110`, `CorpusRow` `:120`, `CorpusContract` `:149`,
  `corpus_to_json` `:357`, `corpus_from_json` `:361`, `Sign` `:71`.
- `tests/fixtures/synthetic/corpus_builder.py`: `GIROKONTO` `:17`, `REVOLUT` `:18`,
  `LEBENSMITTEL` `:19`, `MIETE` `:20`, `GEHALT` `:21`, `MERCHANTS` `:33`,
  `NOVEL_MERCHANT` `:43`, `build_corpus` `:69`.
- `pyproject.toml:59` (ruff `T20`): output goes through `sys.stderr.write` (`_fail`, `trial.py:401-403`).
- Docs: ch.5 §5.2 *Trial tooling* (`05-building-block-view.md:484`), ch.6 §6.6
  (`06-runtime-view.md:138`).

## Gates run (the project's own runners)

- `./engine/nox.sh gate` (= the C4-ci row) with `PDCA_WORKTREE` set: fmt, lint, types,
  test-3.14 (327 passed, 1 skipped, 7 deselected), typos, docs: **all success**.
  This answers iteration 1's NEEDS-HUMAN about ruff/mypy not being installed: nox
  installs them into `.nox/` itself, so they did run this time. That item is closed.
- `engine/scripts/run-verify.sh` (= C4-verify) with `PDCA_BUNDLE`/`PDCA_WORKTREE`:
  `PDCA-EVIDENCE: C4 PASS — red without the fix (14 of 19 failed), green with it`.
  0 collection errors. The 5 that pass on the red leg are `tests/test_skeleton.py`.

## Red reason on the folded base (brief: Falsifiability)

With the production hunks reverted, the 14 failures are, verbatim:
12 × `AttributeError: module 'autobook.pipeline.trial' has no attribute 'backtest'`,
2 × `... has no attribute 'main'`. Every red is a missing `trial` name, not a missing
#23/#24 name.

## Self-refutation

- **(a) Genuine red?** Yes. `run-verify.sh` reverted the non-test hunks: 14 of 14
  `test_backtest.py` tests ran and failed (output above). I also ran the new tests
  against the iteration-1 `trial.py`: the blank-token, priors and band tests fail there
  (ZeroDivisionError, wrong band, KeyError `rows`). So they bind this iteration's fixes
  too, not just the existence of `backtest`.
- **(b) Production path?** Yes. Every test calls `trial.backtest` or `trial.main` with the
  real `normaliser.load` on an empty dir, the real `index_rows`/`KnnIndex`, and the real
  contracts. Nothing is mocked and the test has no copy of the logic.
- **(c) Fixture includes the fault?** Yes. The blank-token history (the crash case) is
  in the fixture. So are the within-month `CHARLIE` pair (e), the March future rows (b),
  the distance-1 `ZULU KIOSK` row (a), novel rows the run rejects but a looser sweep cell
  accepts, a second partition with the same token, and the real `build_corpus(0..2)`.
  Nothing was curated out.

## Rubric pass

- *Failure granularity:* the one per-row crash (blank history) is removed at its cause.
  Malformed input (`ContractError`, `KnnError` from `index_rows`, `NormaliserError`,
  unreadable file) still refuses the whole run with exit 2 and no report. That is input
  validation of the corpus as a whole, not a per-row problem.
- *Privacy:* the report holds counts, rates, versions, thresholds, month labels, band
  labels and grid values only. The CLI test checks that no merchant name or account
  path part appears in it. Every test row is invented.
- *Abstention erosion:* no threshold is set or widened anywhere. The sweep is reported,
  never fed back.
- Money, book writes, idempotency, double-booking, documents, backend: not touched.

## Housekeeping

- Running scratch probes left an untracked `tests/fixtures/synthetic/__pycache__/` and
  `.nox/scratch/` in the worktree. Neither is in `patch.diff` (`.nox` is ignored; the
  pycache is not in any listed path). I did not delete them (cleanup is the harness's).

## Not done / for the human

- The band `rows` definition (item 3) is a reading of an ambiguous sentence in the brief.
  Confirm at sign-off.
- Run time on 30–60k rows: not tested (the brief says so).
- After merge: set `[manual_test].cmd` in `pdca.toml` (out of scope here).
- The PR description must state the settled CLI form, the counts-only JSON, the novel
  sweep, and that per-cluster results are deferred.
