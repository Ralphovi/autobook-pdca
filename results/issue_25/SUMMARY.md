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
- C4 fix verified: bundle test red pre-fix, green post-fix (pytest): pass — C4 PASS — red without the fix (21 of 26 failed), green with it
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

Review issue #25’s rolling-origin backtest and CLI, focusing on the remaining fixes for private profile-path diagnostics and omitted empty calendar months.

| Item | Verdict | Basis |
|------|---------|-------|
| C1 Spec | PASS | The required month boundary, privacy boundary, and two remaining corrections are explicit and testable; no unresolved scope decision is needed (brief.md:230; target/tests/test_backtest.py:180; target/tests/test_backtest.py:294). |
| C2 Reproduction (red pre-fix) | PASS | Frozen execution establishes genuine pre-fix failures: 21 failed and 5 passed, with zero setup or collection errors; failures reach missing trial symbols (gate-logs/C4-verify.log:40; gate-logs/C4-verify.log:777). |
| C3 Change | PASS | The five affected paths fit the authorized implementation, regression-test, skeleton, and architecture scope; reverse-apply checking confirms citations refer to the supplied patched target (brief.md:21; review-checks.log:8; target/tests/test_skeleton.py:22). |
| C4 Verification (red→green) | PASS | Frozen logs substantiate 26/26 bundle tests green and 334 full-suite passes, plus formatting, lint, types, spelling, and docs success; local docs, spelling, and whitespace reruns pass, while the missing local Python toolchain prevents an independent full rerun (gate-logs/C4-verify.log:10; gate-logs/C4-ci.log:58; review-checks.log:1). |
| C5 Causal adequacy | PASS | Empty-month omission and profile-path disclosure are addressed at their causes, with regression assertions for gap months, year rollover, and slash-free relative paths; no optional-capability probe masks a load-time cause (target/src/autobook/pipeline/trial.py:151; target/src/autobook/pipeline/trial.py:305; target/src/autobook/pipeline/trial.py:455; target/tests/test_backtest.py:180; target/tests/test_backtest.py:294). |
| T1 Structure | PASS | The backtest remains in the pipeline and reuses the contract, normaliser, and classifier boundaries without new dependencies or book access; architecture documents the public report and CLI (target/src/autobook/pipeline/trial.py:43; target/docs/design/architecture/05-building-block-view.md:501; target/docs/design/architecture/06-runtime-view.md:149). |
| T2 Shape | PASS | The documented aggregate-only output and diagnostic privacy boundary are preserved, with normaliser locations excluded entirely; the path-triggered threat-model gate reports no matching security-sensitive paths, not a general security certification (target/src/autobook/pipeline/trial.py:329; target/src/autobook/pipeline/trial.py:423; gate-logs/T2-threat-model.log:10). |
| T3 Runtime | PASS | Frozen tests exercise actual backtest/CLI behavior, including both remaining regressions; independent extracted-helper probes confirm inclusive calendars and removal of a real normaliser error’s relative path, with their narrower scope explicitly recorded (gate-logs/C4-ci.log:45; target/tests/test_backtest.py:180; target/tests/test_backtest.py:294; review-probes.log:1). |
| T4 Contribution | N/A | Contribution artifacts are absent by design at Check; the substantive contribution audit is deferred to its mandatory publish rerun (gate-logs/T4-contribution.log:10). |
| T5 Judgment | NEEDS-HUMAN | Confirm merged and closed/rejected prior art by affected file path — the brief records a search, but this snapshot has only one base commit and GitHub access failed, so its completeness cannot be independently established (brief.md:25; review-checks.log:10; review-checks.log:14). |
| Validation — fitness-to-purpose | NEEDS-HUMAN | Decide whether these aggregate reports adequately support the step-2 premise and subsequent human threshold selection — passing synthetic regressions establishes specified behavior, not useful precision or coverage on the intended corpus (brief.md:9; target/docs/design/architecture/05-building-block-view.md:519; target/tests/test_backtest.py:157). |

No builder-fixable defect found in the remaining corrections. The latest carry-forward explicitly accepts the rest of the patch; this review does not reopen those settled implementation decisions (brief.md:230).

Evidence and limits:

- All source citations above resolve inside `$PDCA_TARGET` (`target/`). The supplied patch passes `git apply --reverse --check`; no stale-target caveat arose. No implementation files were edited.
- Independent checks: docs lint passed, `typos` passed, `git diff --check` passed, and all three changed Python files compiled. Exact calendar and diagnostic helper functions extracted from the target passed focused probes, including a real `NormaliserError` from an existing relative file path. These probes do not execute the complete CLI or classifier and are not substitutes for the frozen pytest evidence (`review-probes.log:5`).
- This sandbox lacks pytest, scikit-learn, nox, ruff, and mypy (`review-checks.log:1`). Consequently I did not stash the patch for an unexecutable red/green rerun. C2/C4 runtime verdicts rely on the readable frozen gate logs, whose commands and worktree are recorded in their headers. Those logs show dependency installation and actual classifier/backtest execution, not a shim or code-read substitute. The missing local toolchain is a reviewer-host limitation, not an undischarged dependency in the recorded gate run.
- The full suite explicitly skipped the unavailable GnuCash book test and deselected seven tests; these are outside this pipeline-only patch, and are not claimed as verified (`gate-logs/C4-ci.log:57`). The threat-model wrapper is instance-scoped; its recorded output was read rather than treating its absence here as a defect. No `INTEGRATION.md` was present in the supplied target.
- Prior-art investigation ran against all five affected paths. The target has one snapshot commit and no remote; the explicit GitHub closed-PR query failed to connect. Human confirmation of the brief’s prior-art search remains owed; it is not an implementation revision request (`review-checks.log:10`).

<!-- pdca:leaf-complete -->

### Advisory — adversary

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

### Advisory — security-review

# Security review — issue 25 / rolling-origin backtest

Attacker-reachable inputs this diff touches: the **corpus file** (`--corpus`), whose `raw_memo` fields carry counterparty text (threat model, "Where untrusted input enters" item 1) and whose account paths are personal data. The **normaliser profile directory** (`--normaliser-dir`) is user config, which the threat model trusts. The **thresholds** are typed by the user. The output is the **report file** plus **stderr**. The diff has no book access, no model adapter, no paperless client, no review file and no network, so most "What must hold" properties are out of reach. The ones that apply are "Nothing personal leaves the machine" (logs, crash output) and "a threshold is never lowered" (thresholds stay human-set).

## Findings

No finding.

## What I checked

- **The report holds nothing that identifies a transaction.** `backtest()` (`src/autobook/pipeline/trial.py:329-357`) builds the report from counts, rates, the normaliser version, thresholds from the command line, band labels made from constants, and `YYYY-MM` month labels. No token, memo, account tuple, amount or day reaches it. `_Outcome` (`trial.py:82-93`) holds only bools and floats. Accounts are compared for equality and never written out. The sweep (`trial.py:209-228`) adds only grid constants. `test_cli_writes_a_report_without_identifying_data` (`tests/test_backtest.py:206`) checks the serialised report against every fixture merchant name, every account path part, and day-level dates.
- **Stderr never quotes the refused value.** `_refused` (`trial.py:423-438`) drops the exception text. It passes on only the leading location, and only if that location fully matches a names-and-digit-indices pattern rooted at a caller-approved name (`corpus`, or the two threshold names). I traced the contract error sites. `_fail`/`_build` in `src/autobook/contracts.py:199-200,274-279` build the location from field names the code supplies plus `[i]` indices. Values (`{text!r}`, unknown field names) only appear after the `": "` split, so a key or value read from the file cannot reach the location part. Normaliser errors are never located (roots `()`, `trial.py:457`), so a profile path the user chose cannot leak. OS errors print only the exception type (`trial.py:460-461,465-466`). Tests at `tests/test_backtest.py:244-320` cover the hostile path: refused values, a memo-like string, and a relative profile path must not show up in stderr, and stderr is exactly one line.
- **No traceback leaks data from the file.** Every error the corpus file or the thresholds can cause is caught (`ContractError`, `NormaliserError`, `KnnError`, `OSError`, `UnicodeDecodeError`). `--max-distance nan` is refused by `KnnIndex.build` (`src/autobook/pipeline/classifier.py:329-334`; a NaN fails both range checks), and `trial.py:297` checks the thresholds before any data is touched, so `json.dumps(..., allow_nan=False)` (`trial.py:463`) cannot raise on a threshold. Every float inside the report is a count ratio or a constant. Leave-one-out's `exclude=row` cannot hit the "no equal row" error, because each row is in its own index.
- **No partial report on a refusal.** The report is written only after the whole run succeeds (`trial.py:462-464`). `test_cli_refuses_a_file_that_is_not_a_corpus` and the refusal tests assert `not out.exists()`.
- **Thresholds stay human-set.** The sweep re-applies the gates to stored results and never feeds back (`trial.py:356`). Nothing in the diff writes a threshold anywhere. Leave-one-out appears only under `upper_bound` (`tests/test_backtest.py:390-401`).
- **No money path or float on a booking path.** Amounts are not read by this module at all.
- **Resources:** one index build per month over a history that grows each month, plus one leave-one-out build. The cost scales with the corpus the user exports, not with anything a counterparty controls. This is not a security issue.
- **Fixtures:** the planted corpora use invented names (`ALPHA`, `BRAVO`, `ZULU KIOSK`, `CHARLIE`) and the synthetic `corpus_builder`. No data from a real statement.
- **Out of scope here:** a crafted memo that makes the #23 normaliser's regexes slow, and JSON nesting deep enough to cause a `RecursionError` in `corpus_from_json`. Both are in upstream modules this diff does not change.

Gates: C4-ci and C4-verify pass (21 of 26 red without the fix). T2 reports no security-relevant path touched, which matches what I found: the diff is a read-only, offline tool, and its only output channels are the report file and stderr, both checked above.

<!-- pdca:leaf-complete -->

## 6. NEEDS-HUMAN — items the human must clear before sign-off
- [x] T5 Judgment — Confirm merged and closed/rejected prior art by affected file path — the brief records a search, but this snapshot has only one base commit and GitHub access failed, so its completeness cannot be independently established (brief.md:25; review-checks.log:10; review-checks.log:14).
- [x] Validation — fitness-to-purpose — Decide whether these aggregate reports adequately support the step-2 premise and subsequent human threshold selection — passing synthetic regressions establishes specified behavior, not useful precision or coverage on the intended corpus (brief.md:9; target/docs/design/architecture/05-building-block-view.md:519; target/tests/test_backtest.py:157).
- [x] **Criterion (b) cannot catch the leak the invariant is about.** The brief's rule is "Nothing dated on or after the first day of m enters month m's index" (Method, *Rolling origin*), and every query also passes `as_of` = the row's own `post_date`. Test (b) only adds rows from a *later* month (March). If `KnnIndex.query(as_of=…)` already ignores rows after `as_of`, two wrong builds still pass (b) for `knn`: (1) one global index, or (2) an index built from "rows before this row's date" instead of "rows before month m". Build (2) leaks earlier rows of the same month, which is the within-month future the invariant forbids. Suggest adding a planted case to (b) or (a) in which an earlier row of month m would change a later row of month m: for example a Feb-01 `CHARLIE`→`MIETE` followed by a Feb-20 `CHARLIE`, which must stay `novel` and not accepted. Then the month-boundary rule is checked by a test and not only by reading the code.
- [x] **The exact numbers in (a) depend on #24's vote formula, which neither the brief nor the target shows.** The target branch still has the stub classifier: `src/autobook/pipeline/classifier.py:13-18` exports only `classify()`, which raises `NotImplementedError`, and `normaliser.py:13-18` is also a stub. In the planted (a) corpus, the `GIROKONTO/out` partition has 6 rows. Proposal 0001 sets `n_neighbors=15` (`sources/0001…md:316`), so a `BRAVO REF 9` query sees 3 `BRAVO`→`MIETE` rows at distance 0 and 3 `ALPHA`→`LEBENSMITTEL` rows at distance 1. The vote is only "unanimous" (Tests section: "at distance 0 with a unanimous vote") if #24 weights votes by similarity or drops far neighbours. With recency-only weights (proposal line 338: "Recency weighting") the vote is 3:3, the margin is 0, and the expected `accepted 2, precision 0.5` fails. The same applies to `result.share` as the confidence and to `BRAVO REF 9` normalising to `BRAVO`, which needs #23's `default` profile to strip `REF <1 digit>`. The brief states these as facts from "the design" but cites no #23/#24 path:line. Ask the planner to cite #24's vote/margin definition and #23's REF rule, or to say that Do must re-derive (a) on the folded base before freezing the numbers. Otherwise Do will hit a red that is in the spec, not the code.
- [x] **(c) assumes that #23 strips every `NOISE` variant down to the bare merchant token.** `tests/fixtures/synthetic/corpus_builder.py:54-61` includes `"SAGT DANKE {n}"`, `"KARTE {n} {d}.{m}."` and `"NR. {n}"`. "Seen" is defined as an exact token match in the partition (Method, *Stratum*). If any variant leaves a residue, for example `BEISPIELMARKT SAGT DANKE`, its first occurrence after January counts as `novel`, and "exactly 1 row" fails for some seed. The fixture comment (line 52, "The kind of noise the normaliser strips") suggests this was intended, but the brief should name the #23 rules (or #23's own test) that guarantee it, since (c) rests on them.
- [x] **The falsifiability probe was not run on the base the gate will use.** Falsifiability says "scratch probe at Plan on an `origin/main` export: 3 ran, 3 failed". On `origin/main`, `normaliser.load` does not exist (`normaliser.py:13`), so any test body that calls it fails for that reason and not because `trial` is missing. That result does not show that the red leg on the folded #23+#24 base fails for the right reason. "3 tests" also does not match the four criteria (a)–(d). The probe should be repeated on the folded base after #24 lands, or the claim should be softened.
- [x] **The brief drops "per-cluster" results from the source design without saying so.** Proposal 0001 *Scenario 1* (`sources/0001…md:510`) says the backtest "yields per-method, per-cluster precision". The brief reports per method, stratum, band and month. Its *Alternatives* section only rejects per-*account* results (privacy). The issue thread does not ask for clusters, so leaving them out is probably right, but the PR description should say per-cluster is deferred (to the rule builder) so Check does not raise it as a gap against the source.
- [x] **Undeclared direct dependency on #23.** The brief needs #23's `normaliser.load`, `Normaliser`, `NormaliserError` and the `IMPLEMENTED` set (Citations, Ordering note), but it declares only `Depends on: 24`. `dependency-state.json` lists only `24` (PLANNED, not merged). This is fine if #24 itself depends on #23 and the fold includes it. If not, the base may be missing `IMPLEMENTED`: `tests/test_skeleton.py:43-50` on the target has no `IMPLEMENTED` set and asserts `len(module.__all__) == 1` for every block. That would make scope item (3) impossible and fail the skeleton test on green. Suggest declaring `Depends on: 23, 24`, or confirming that #24 depends on #23.
- [x] size backstop — this slice is behaving oversized: 3 round(s) already spent (threshold 2). Recommend answering `iterate-plan` at sign-off and authoring the split in the re-plan (`pdca split`), rather than `iterate-do`: a slice that is too big yields implementation-shaped findings every round, and splitting authors briefs, which is Plan's beat.

## 7. Proven / not proven
- Proven by which oracle: gates overall = pass (stub oracles).
- Unproven / needs manual run: anything flagged in §6.

## 8. Ready-to-ship attachments
- patch.diff
- tracker-comment.md     (ALWAYS, every tracker item)
- build-notes.md         (builder rationale — for the human, not the reviewer)

## 9. Check sign-off                     ← human completes Check here
- Disposition confirmed / overridden:
- Outcome: merged-wider
- Iteration delta (if iterating):
- By / date: Eduard Ralph / 2026-10-15

## 10. Act candidates (hints for the next Act review)
- Plan advisory: 6 finding(s); brief revised: yes (plan-advisory-*.md)
- (empty is the common case)
- issue_25 follow-up: backtest builds a kNN index for every calendar month, even empty ones; one mistyped far-future date (e.g. 2099) adds ~900 builds (~4–5 min on 34.5k rows). Skip the index build when a month has no rows (trial.py:310-313).
