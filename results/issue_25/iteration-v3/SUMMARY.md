# Result — issue 25 / rolling-origin-backtest

## 1. Spec (from brief.md)              ← Check verifies against THIS
- Defect / goal: Measure the premise of build step 2 honestly: a rolling-origin backtest in which month m is classified only by rows dated before month m, reporting precision and coverage per method (gated kNN, token-Bayes as the negative control) and per confidence band, stratified into memos seen before and novel memos, with a threshold sweep on the novel stratum, leave-one-out only as a labelled upper bound, and a CLI that writes the report to a file.
- Success criterion: `tests/test_backtest.py` passes with the patch applied and fails, with tests that RUN (not a collection error), with the production change reverted. It must assert: (a) on a planted corpus built in the test (source `GIROKONTO`, sign `out`, normalised with `normaliser.load(<empty tmp dir>)`): January 2025 holds `ALPHA` three times to `LEBENSMITTEL` and `BRAVO` three times to `MIETE`; February 2025 holds `ALPHA 123` to `LEBENSMITTEL`, `BRAVO REF 9` to `LEBENSMITTEL` and `ZULU KIOSK` to `LEBENSMITTEL`. With `max_distance=0.5`, `min_margin=0.5`, the kNN rolling-origin result is exactly: one month tested; stratum `seen` rows 2, accepted 2, correct 1, precision 0.5, coverage 1.0; stratum `novel` rows 1, accepted 0, correct 0, precision `null`, coverage 0.0; and `token_bayes` reports 3 rows in stratum `all`. (b) a future row never votes for a past one: adding five March 2025 rows `ALPHA` to `MIETE` to the planted corpus leaves the February entry of the per-month results identical, for every method. (c) on `build_corpus(seed)` for seeds 0, 1 and 2, with the same thresholds, the kNN `novel` stratum has exactly 1 row (the planted novel merchant) and it is not accepted. (d) `main(["backtest", "--corpus", <file>, "--out", <file>, "--max-distance", "0.5", "--min-margin", "0.5", "--normaliser-dir", <empty dir>])` on the serialised `build_corpus(0)` returns 0 and writes a JSON report whose text contains no merchant name from the fixture and no account path component (`Aktiva`, `Girokonto`, `Ausgaben`, …); on a file that is not a valid `corpus` contract it returns non-zero and writes no report. (e) the month boundary, not the row's own date, bounds the past: on a planted corpus (source `GIROKONTO`, sign `out`) with January 2025 holding `ALPHA` three times to `LEBENSMITTEL`, and February 2025 holding `CHARLIE` to `MIETE` on 2025-02-01 and `CHARLIE` to `MIETE` on 2025-02-20, the February kNN result is: stratum `novel` rows 2, accepted 0; stratum `seen` rows 0; and `token_bayes` in stratum `all` has accepted 2, correct 0. An index or token-Bayes count bounded by "rows before this row's date" would let the 1 February row vote for the 20 February one (kNN: `seen` and accepted; token-Bayes: `MIETE`, correct), and a single global index would do the same.
- Repo + branch target: Ralphovi/autobook @ main
- Scope (one logical fix) / out of scope: (1) the backtest and its CLI in `src/autobook/pipeline/trial.py` (API, method, report and CLI below); (2) `tests/test_backtest.py`; (3) add `"autobook.pipeline.trial"` to `IMPLEMENTED` in `tests/test_skeleton.py` (#23 defines it so that an `IMPLEMENTED` module skips all three assertions of `test_every_block_has_one_entry_point_that_is_not_implemented`: `len(__all__) == 1`, `callable`, `NotImplementedError`; if the folded base lacks this, stop and report it in `build-notes.md` rather than changing the exemption here); (4) docs currency: ch.5 §5.2 *Trial tooling* (method, strata, bands, sweep, report shape) and ch.6 §6.6 (the CLI command and its flags). / out of scope: the rule builder, assistant detector, pack validator and linkage backtest (the rest of the trial tooling); recording the version tuple of a successful trial (no tuple code exists yet); writing or changing any threshold anywhere (the report is evidence; a human sets thresholds); the corpus export from a real book (#26); the LLM; any new runtime dependency; setting `[manual_test].cmd` in autobook-pdca (follow-up after merge); a console-script entry point in `pyproject.toml`; per-cluster results (proposal 0001 *Scenario 1* says the backtest "yields per-method, per-cluster precision"; clusters come with the rule builder, which is out of scope here, and the issue does not ask for them; the PR description says they are deferred).

## 2. Disposition claimed               ← sign-off confirms or overrides
- Outcome: new-feature
- Confidence: medium
- Recommendation: (set by Do)

## 3. Correctness (Check — chain)
- C1 Spec: none — brief.md
- C2 Reproduction (red pre-fix): none — (no gate configured)
- C3 Change: none — patch.diff
- C4 Autobook gate: nox -s gate (fmt/lint/types/test/typos/docs): pass — nox > * docs: success
- C4 fix verified: bundle test red pre-fix, green post-fix (pytest): pass — C4 PASS — red without the fix (19 of 24 failed), green with it
- C5 Causal adequacy: none — reviewer + human sign-off

## 4. Conformance (Check — stack)
- T1 Structure: none — (no gate configured)
- T2 security-relevant change also updates the threat model: pass — no security-relevant path touched
- T3 Runtime: none — (no gate configured)
- T4 PR body has a user-impact opener + tracker id in both artifacts: deferred — pr-description.md not drafted yet — the substantive T4 audit of the contribution artifacts runs at publish
- T5 Judgment: none — reviewer + human sign-off
- T5 judgment: → see §5.

## 5. Advisory review (artifact-only, decorrelated)
Reviewer ran without build-notes.md. Summary:

Review issue #25: implement a rolling-origin backtest and CLI with past-only training, novel-stratum threshold evidence, and reports that exclude identifying data.

| Item | Verdict | Basis |
|------|---------|-------|
| C1 Spec | PASS | The brief fixes testable counts, temporal boundaries, scope, and privacy requirements; the supplied target contains the prerequisite normaliser and index APIs (`brief.md:11`, `brief.md:57`, `target/src/autobook/pipeline/classifier.py:163`). |
| C2 Reproduction (red pre-fix) | PASS | Frozen evidence shows 19 executed tests failing on missing trial APIs, five passing, and zero collection/setup errors; this reproduces the unimplemented feature, not a dependency failure (`gate-logs/C4-verify.log:14`, `gate-logs/C4-verify.log:693`). |
| C3 Change | PASS | Changes stay within the trial module, its tests, the skeleton exemption, and the two architecture chapters authorized by the brief; reverse-application checking confirms that the supplied patch matches this target (`target/src/autobook/pipeline/trial.py:277`, `patch.diff:1`). |
| C4 Verification (red→green) | PASS | Frozen logs substantiate 24 green bundle tests and successful fmt/lint/types/test/typos/docs sessions; local docs, spelling, and whitespace checks pass, but local pytest/nox reruns are unavailable, so red→green is log-backed (`gate-logs/C4-verify.log:12`, `gate-logs/C4-ci.log:58`, `gate-logs/C4-ci.log:67`). |
| C5 Causal adequacy | NEEDS-HUMAN [impl] | Close the diagnostic privacy gap and restore the specified calendar-month coverage — relative profile paths can reach stderr, and empty intervening months disappear from the report; both gaps need regression cases (`target/src/autobook/pipeline/trial.py:419`, `target/src/autobook/pipeline/trial.py:296`). |
| T1 Structure | PASS | The backtest composes existing contract, normaliser, and classifier APIs without crossing the book-process boundary or introducing a dependency; future trial tooling remains explicitly unimplemented (`target/src/autobook/pipeline/trial.py:43`, `target/src/autobook/pipeline/trial.py:372`). |
| T2 Shape | FAIL | The documented diagnostic boundary excludes profile paths, but syntactic field-name matching admits a relative profile path; the path-based threat-model scanner's pass does not discharge this content-level defect (`target/src/autobook/pipeline/trial.py:408`, `target/docs/design/architecture/06-runtime-view.md:159`, `gate-logs/T2-threat-model.log:10`). |
| T3 Runtime | PASS | Logged executions cover planted counts, future/within-month isolation, blank tokens, partitions, sweep boundaries, recency, and CLI refusals; this supports fixture-scale behavior, not a 30–60k-row performance claim (`target/tests/test_backtest.py:129`, `target/tests/test_backtest.py:268`, `target/tests/test_backtest.py:368`, `gate-logs/C4-ci.log:45`). |
| T4 Contribution | N/A | Contribution artifacts are absent by design; their substantive audit is deferred to the mandatory publish-time rerun, not human clearance during Check (`gate-logs/T4-contribution.log:10`). |
| T5 Judgment | NEEDS-HUMAN | Confirm prior-art coverage by affected file path across merged and closed/rejected work — the brief reports a search, but this one-commit target has no remote or historical PR evidence to independently settle whether earlier work constrains the contribution (`brief.md:25`). |
| Validation — fitness-to-purpose | NEEDS-HUMAN | Decide whether the resulting report supports the step-2 premise and threshold decisions on representative data — synthetic correctness evidence does not establish useful real-corpus precision, coverage, or acceptable 30–60k-row runtime (`brief.md:30`, `target/docs/design/architecture/05-building-block-view.md:487`, `target/src/autobook/pipeline/trial.py:347`). |

Two implementation findings remain:

1. **Rejected relative profile paths leak through the diagnostic sanitizer.** At `target/src/autobook/pipeline/trial.py:419`, `_refused` treats any error prefix matching `_FIELD` as a trustworthy contract field path. A user-supplied relative path can match that grammar too. I created an invented regular file named `PRIVATE_PROFILE` in the review sandbox and called the actual `normaliser.load(Path("PRIVATE_PROFILE"))`. Its `NormaliserError` originates at `target/src/autobook/pipeline/normaliser.py:189`. Passing that exception through the unchanged `_refused` and `_fail` functions produced status 2 and exactly:

   ```text
   error: the normaliser profiles were refused (NormaliserError at PRIVATE_PROFILE)
   ```

   This contradicts the promise that profile paths never reach stderr (`target/docs/design/architecture/06-runtime-view.md:159`). The existing privacy test uses an absolute profile path containing slashes (`target/tests/test_backtest.py:255`), which the regex rejects, so it misses the relative-path case. Restrict locations to known field roots for the relevant exception type, or omit normaliser locations entirely, and add a relative-path regression. This was an isolated execution of the real normaliser and AST-extracted, unmodified diagnostic functions; it was not a full CLI execution, because the local numerical dependencies are missing.

2. **Empty calendar months are omitted from the report.** The brief specifies every calendar month from the first to the last date (`brief.md:57`), but `target/src/autobook/pipeline/trial.py:293` groups only months containing rows, and line 301 iterates that group list. Executing the unchanged grouping statements with January and March dates produced `[(2025, 1), (2025, 3)]`, so only March is iterated. February has no zero-count entry, and `months.tested` becomes 1 instead of 2 (`target/src/autobook/pipeline/trial.py:333`). This affects the reported observation timeline, not the aggregate row precision or the past-only training boundary. Enumerate the inclusive calendar range and add a gap-month case asserting zero counts for both methods. This probe exercised the grouping statements only, not the full numerical backtest.

Verification limits and disposition:

- The target is current enough for this review: `git -C target apply --reverse --check ../patch.diff` succeeded, and the folded normaliser/classifier implementations are present. No stale-target compile or application defect is alleged. Production files were not edited.
- Independent `python3 -m pytest` and `python3 -m nox -s gate` attempts stopped because those modules are absent; `sklearn`, `ruff`, and `mypy` are also absent from the local interpreter. I therefore did not stash the patch for an unusable red leg. The complete frozen verification log records 19 missing-API failures without collection errors and 24 green bundle tests. The CI log records 332 passing tests, one GnuCash import skip, and seven deselections; the skipped book/live surfaces are outside this change (`gate-logs/C4-ci.log:43`, `gate-logs/C4-ci.log:57`). No full independent red→green rerun is claimed.
- Independently executed `python3 docs/tools/lint_docs.py`, `typos`, and `git diff --check` successfully in the target. The docs validator reported `lint_docs: OK (2 ADR(s) checked)`. The instance-scoped threat-model and contribution wrappers are not supplied; their readable logs establish respectively the path-scanner pass and the publish-time deferral. All four named gate logs were read.
- The declared PyPI/scikit-learn dependency was exercised in the logged gate environment: project installation and real classifier/backtest tests ran (`target/pyproject.toml:31`, `gate-logs/C4-ci.log:35`, `gate-logs/C4-ci.log:49`). Its absence in this reviewer host limits independent reproduction; it does not establish an undischarged dependency in the supplied gate run. The isolated diagnostic/grouping probes do not substitute for those numerical tests.
- The C5 capability-probe smell-test does not trigger: the patch adds no optional-capability probe around a path requiring that capability. Month-start history construction addresses temporal leakage directly (`target/src/autobook/pipeline/trial.py:302`), and the sweep uses candidate correctness independently of the run's acceptance threshold (`target/src/autobook/pipeline/trial.py:218`).
- The path-scoped prior-art investigation returned only `3c21db2 pre-fix base 450f7c8f2fe91181d435e3824b88c2494ca9e9d7`; `git remote -v` returned nothing. The brief's merged-history and closed-issue summary is recorded evidence, but closed/rejected work by each affected path cannot be independently confirmed from this bundle. No `INTEGRATION.md` was supplied, so no additional project-specific human-only list was available to apply.

This review is advisory; the findings do not replace deterministic gates or the human acceptance decision.

<!-- pdca:leaf-complete -->

### Advisory — adversary

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

### Advisory — security-review

# Security review — issue 25 / rolling-origin-backtest

Attacker-reachable inputs this diff touches: **the corpus file** (`--corpus`), whose `raw_memo` fields carry counterparty text (threat model, "Where untrusted input enters" item 1), and, indirectly, the error text that the contract, normaliser and kNN validators produce from that file. The user-owned inputs (`--out`, `--normaliser-dir`, the thresholds, the user's normaliser profiles) are trusted under the threat model ("the user's own rules file and config"). The diff writes nothing to the book, staging, paperless or a model backend, and opens no network connection. The T2-threat-model gate log agrees: no security-relevant path touched.

No finding. Here is what I checked:

- **The report holds no personal data.** `src/autobook/pipeline/trial.py:320-348` builds the report only from counts, rates, band labels, `YYYY-MM` month labels, the thresholds, `HALF_LIFE_DAYS` and `normaliser.version`. No memo, token, account path or amount is stored in `_Outcome` (`trial.py:82-93`), so none can reach the output. `seen`/`known` keys (`trial.py:306`, `:359`) stay in memory. `tests/test_backtest.py:180-202` checks the written report for every fixture merchant name, every account path part and day-level dates. Severity if broken would be High ("personal data reaches a log"). It holds.
- **stderr carries no file content.** `_refused` (`trial.py:411-422`) passes on only the part of the error text before the first `": "`, and only when it is made of field names and `[n]` indices (`_FIELD`, `trial.py:408`). I checked where that prefix comes from. In `contracts.py:199-200`, `:279` and `classifier.py:72-73` it is always built from code constants and loop indices. Values read from the file (unknown keys, bad dates, amounts, `contract` name) only appear after the `": "` (`contracts.py:212`, `:219`, `:240`, `:286`, `:290`), so they are cut off. Normaliser errors start with a filesystem path (`normaliser.py:166-223`, `:340`), which contains `/` and fails the pattern, so only the exception type name is printed. JSON decode errors are wrapped as `corpus: not valid JSON: …` (`contracts.py:432`), so only `corpus` is printed. `OSError`/`UnicodeDecodeError` print the type name only (`trial.py:443-444`). `tests/test_backtest.py:218-265` covers field-value refusals, a row-level refusal containing a merchant name, and a normaliser refusal containing a pattern, each asserting the value is absent from stderr. That is the hostile case, not just the friendly one.
- **No report on refusal.** All parsing, loading and computing happens before the `--out` write (`trial.py:428-447`), so a refused input writes no file (`tests/test_backtest.py:205`).
- **Non-finite thresholds.** `--max-distance nan` / `inf` are refused by `KnnIndex.build` (`classifier.py:327-334`: the checks `0 <= d < 1` and `0 < m <= 1` are false for NaN), which `backtest` calls first (`trial.py:290`). So `json.dumps(..., allow_nan=False)` (`trial.py:446`) cannot crash on them.
- **Crash from statement-derived text.** Token-Bayes skips words not in the history and so never divides by zero (`trial.py:126-135`). The round-1 blank-token crash is fixed and tested (`tests/test_backtest.py:268`). A deeply nested JSON corpus could still end in an uncaught `RecursionError` traceback from `json.loads`. That traceback holds no file content, and the file is the user's own book export, so at most it is Low and not worth a round.
- **Future data / gates.** Each month's history is cut at the first day of the month (`trial.py:302-305`), and the sweep only re-reads stored results; it never changes `KnnIndex` thresholds or writes any threshold back (`trial.py:202-221`). No gate on the production path is loosened. This is an evaluation tool, and the synthetic rows it indexes stay in a throwaway in-memory index, so the "synthetic row can enter the kNN index" rule (Medium) does not apply.
- **Resource use.** About one index build per tested month plus one leave-one-out build. That grows with the book's own size, not with anything a counterparty can inflate past one memo per row. Not a finding.
- **Other invariants.** No `gnucash` import, no float on a book-bound money path (amounts are never read by this module), no network, no temporary files.

<!-- pdca:leaf-complete -->

## 6. NEEDS-HUMAN — items the human must clear before sign-off
- [ ] C5 Causal adequacy — Close the diagnostic privacy gap and restore the specified calendar-month coverage — relative profile paths can reach stderr, and empty intervening months disappear from the report; both gaps need regression cases (`target/src/autobook/pipeline/trial.py:419`, `target/src/autobook/pipeline/trial.py:296`).
- [x] T5 Judgment — Confirm prior-art coverage by affected file path across merged and closed/rejected work — the brief reports a search, but this one-commit target has no remote or historical PR evidence to independently settle whether earlier work constrains the contribution (`brief.md:25`).
- [x] Validation — fitness-to-purpose — Decide whether the resulting report supports the step-2 premise and threshold decisions on representative data — synthetic correctness evidence does not establish useful real-corpus precision, coverage, or acceptable 30–60k-row runtime (`brief.md:30`, `target/docs/design/architecture/05-building-block-view.md:487`, `target/src/autobook/pipeline/trial.py:347`).
- [x] `src/autobook/pipeline/trial.py:306,310`: `seen` means exactly the same token, as the brief specifies. But the kNN treats some different tokens as identical: `char_wb` n-grams (overlapping 3–5 character chunks, built word by word) ignore word order. Probed case: January has `ALPHA MARKT` ×3 → `LEBENSMITTEL`; February has `MARKT ALPHA`. It is counted `novel`, sits at distance 0 and is accepted even at `max_distance=0.0, min_margin=1.0`. Such rows make the novel stratum, where thresholds are set, look a little easier than truly novel merchants. On real memos the effect is probably small (word-order variants are rare). It is a question about how the brief defines the strata, not an implementation slip. A human may accept it as is, or ask a follow-up to define `seen` as "an index row at distance 0".
- [x] **Criterion (b) cannot catch the leak the invariant is about.** The brief's rule is "Nothing dated on or after the first day of m enters month m's index" (Method, *Rolling origin*), and every query also passes `as_of` = the row's own `post_date`. Test (b) only adds rows from a *later* month (March). If `KnnIndex.query(as_of=…)` already ignores rows after `as_of`, two wrong builds still pass (b) for `knn`: (1) one global index, or (2) an index built from "rows before this row's date" instead of "rows before month m". Build (2) leaks earlier rows of the same month, which is the within-month future the invariant forbids. Suggest adding a planted case to (b) or (a) in which an earlier row of month m would change a later row of month m: for example a Feb-01 `CHARLIE`→`MIETE` followed by a Feb-20 `CHARLIE`, which must stay `novel` and not accepted. Then the month-boundary rule is checked by a test and not only by reading the code.
- [x] **The exact numbers in (a) depend on #24's vote formula, which neither the brief nor the target shows.** The target branch still has the stub classifier: `src/autobook/pipeline/classifier.py:13-18` exports only `classify()`, which raises `NotImplementedError`, and `normaliser.py:13-18` is also a stub. In the planted (a) corpus, the `GIROKONTO/out` partition has 6 rows. Proposal 0001 sets `n_neighbors=15` (`sources/0001…md:316`), so a `BRAVO REF 9` query sees 3 `BRAVO`→`MIETE` rows at distance 0 and 3 `ALPHA`→`LEBENSMITTEL` rows at distance 1. The vote is only "unanimous" (Tests section: "at distance 0 with a unanimous vote") if #24 weights votes by similarity or drops far neighbours. With recency-only weights (proposal line 338: "Recency weighting") the vote is 3:3, the margin is 0, and the expected `accepted 2, precision 0.5` fails. The same applies to `result.share` as the confidence and to `BRAVO REF 9` normalising to `BRAVO`, which needs #23's `default` profile to strip `REF <1 digit>`. The brief states these as facts from "the design" but cites no #23/#24 path:line. Ask the planner to cite #24's vote/margin definition and #23's REF rule, or to say that Do must re-derive (a) on the folded base before freezing the numbers. Otherwise Do will hit a red that is in the spec, not the code.
- [x] **(c) assumes that #23 strips every `NOISE` variant down to the bare merchant token.** `tests/fixtures/synthetic/corpus_builder.py:54-61` includes `"SAGT DANKE {n}"`, `"KARTE {n} {d}.{m}."` and `"NR. {n}"`. "Seen" is defined as an exact token match in the partition (Method, *Stratum*). If any variant leaves a residue, for example `BEISPIELMARKT SAGT DANKE`, its first occurrence after January counts as `novel`, and "exactly 1 row" fails for some seed. The fixture comment (line 52, "The kind of noise the normaliser strips") suggests this was intended, but the brief should name the #23 rules (or #23's own test) that guarantee it, since (c) rests on them.
- [x] **The falsifiability probe was not run on the base the gate will use.** Falsifiability says "scratch probe at Plan on an `origin/main` export: 3 ran, 3 failed". On `origin/main`, `normaliser.load` does not exist (`normaliser.py:13`), so any test body that calls it fails for that reason and not because `trial` is missing. That result does not show that the red leg on the folded #23+#24 base fails for the right reason. "3 tests" also does not match the four criteria (a)–(d). The probe should be repeated on the folded base after #24 lands, or the claim should be softened.
- [x] **The brief drops "per-cluster" results from the source design without saying so.** Proposal 0001 *Scenario 1* (`sources/0001…md:510`) says the backtest "yields per-method, per-cluster precision". The brief reports per method, stratum, band and month. Its *Alternatives* section only rejects per-*account* results (privacy). The issue thread does not ask for clusters, so leaving them out is probably right, but the PR description should say per-cluster is deferred (to the rule builder) so Check does not raise it as a gap against the source.
- [x] **Undeclared direct dependency on #23.** The brief needs #23's `normaliser.load`, `Normaliser`, `NormaliserError` and the `IMPLEMENTED` set (Citations, Ordering note), but it declares only `Depends on: 24`. `dependency-state.json` lists only `24` (PLANNED, not merged). This is fine if #24 itself depends on #23 and the fold includes it. If not, the base may be missing `IMPLEMENTED`: `tests/test_skeleton.py:43-50` on the target has no `IMPLEMENTED` set and asserts `len(module.__all__) == 1` for every block. That would make scope item (3) impossible and fail the skeleton test on green. Suggest declaring `Depends on: 23, 24`, or confirming that #24 depends on #23.
- [x] size backstop — this slice is behaving oversized: 2 round(s) already spent (threshold 2). Recommend answering `iterate-plan` at sign-off and authoring the split in the re-plan (`pdca split`), rather than `iterate-do`: a slice that is too big yields implementation-shaped findings every round, and splitting authors briefs, which is Plan's beat.
- [x] T5 Judgment — Confirm affected-path prior art across merged and closed/rejected work — the brief records a search, but this snapshot contains only one base commit and GitHub access failed, so duplication or a prior rejection cannot be independently settled; brief.md:25, reviewer-evidence/checks.log:38.
- [x] external dependency: ruff 0.14.2 and mypy 1.18.2 (the project's `nox -s fmt/lint/types` tools) — not installed in the instance venv, so the target's format/lint/type gates were not run on this patch.
- [x] T5 Judgment — Confirm affected-path prior art across merged and closed/rejected work — the brief records a search, but this snapshot has one base commit, no remote, and no captured path-level PR evidence, so superseded or rejected work cannot be independently ruled out (`brief.md:25`; investigation below).

## 7. Proven / not proven
- Proven by which oracle: gates overall = pass (stub oracles).
- Unproven / needs manual run: anything flagged in §6.

## 8. Ready-to-ship attachments
- patch.diff
- tracker-comment.md     (ALWAYS, every tracker item)
- build-notes.md         (builder rationale — for the human, not the reviewer)

## 9. Check sign-off                     ← human completes Check here
- Disposition confirmed / overridden:
- Outcome: iterated-to-Do
- Iteration delta (if iterating): Rest of the patch is accepted as-is; fix only the two C5 findings, each with a regression test: 1. Error-message privacy: `_refused` (trial.py, `_FIELD` match) lets a slash-free relative normaliser profile path (e.g. `PRIVATE_PROFILE`) reach stderr, breaking the ch.6 §6.6 promise that profile paths never appear. Only pass on locations from known contract/index field roots (or drop normaliser locations entirely). Add a test using a relative, slash-free profile path. 2. Empty calendar months: the backtest groups only months that contain rows, so a gap month (e.g. rows in Jan and Mar) is neither listed in `by_month` nor counted in `months.tested`. The brief requires every calendar month from first to last post_date. Enumerate the inclusive range; a gap month gets zero counts for every method. Add a gap-month test asserting zero-count entries and the right `tested` count. Do not change anything else — strata, bands, sweep, leave-one-out and the report shape were reviewed and cleared.
- By / date: Eduard Ralph / 2026-10-15

## 10. Act candidates (hints for the next Act review)
- Plan advisory: 6 finding(s); brief revised: yes (plan-advisory-*.md)
- (empty is the common case)
