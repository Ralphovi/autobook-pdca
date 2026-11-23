Review the rolling-origin backtest and JSON CLI for issue #25: past-only classification, novel-stratum threshold evidence, and private reporting.

| Item | Verdict | Basis |
|------|---------|-------|
| C1 Spec | PASS | The required evidence distinguishes future leakage, within-month leakage, novel abstention, and report privacy with concrete expected results; `brief.md:10`, `target/tests/test_backtest.py:129`, `target/tests/test_backtest.py:164`. |
| C2 Reproduction (red pre-fix) | PASS | Frozen execution shows 14 tests failing on missing trial APIs, five passing, and zero collection/setup errors; this establishes the absent functionality, not a dependency failure (`gate-logs/C4-verify.log:488`). |
| C3 Change | PASS | The five affected files stay within the agreed backtest, tests, skeleton exemption, and architecture scope; the CLI and report are documented together (`target/src/autobook/pipeline/trial.py:277`, `target/docs/design/architecture/05-building-block-view.md:504`, `target/docs/design/architecture/06-runtime-view.md:149`). |
| C4 Verification (red→green) | PASS | Frozen logs substantiate 19/19 green after 14 pre-fix failures and CI's 327 passes plus successful format/lint/types/typos/docs; independent Python reruns were unavailable, as detailed below (`gate-logs/C4-verify.log:10`, `gate-logs/C4-verify.log:488`, `gate-logs/C4-ci.log:58`). |
| C5 Causal adequacy | NEEDS-HUMAN [impl] | Sanitize rejected-input diagnostics and test stderr privacy — the CLI forwards validation text containing transaction amounts/dates into logs, violating the promised output boundary (`target/src/autobook/pipeline/trial.py:418`, `target/src/autobook/contracts.py:240`, `target/tests/test_backtest.py:205`). |
| T1 Structure | PASS | The pipeline retains the JSON boundary and reuses the normaliser/index APIs; it introduces neither book access nor a runtime dependency (`target/src/autobook/pipeline/trial.py:42`, `target/src/autobook/pipeline/trial.py:289`). |
| T2 Shape | PASS | The path-based threat-model gate reports no matching security-sensitive path; this limited scanner result does not discharge the diagnostic privacy defect recorded in C5 (`gate-logs/T2-threat-model.log:10`). |
| T3 Runtime | PASS | Frozen execution exercises both classifiers, blank histories, partition isolation, sweep acceptances, and CLI refusal/success; this supports fixture behavior only, not production-scale timing (`target/tests/test_backtest.py:217`, `target/tests/test_backtest.py:264`, `target/tests/test_backtest.py:317`, `gate-logs/C4-ci.log:45`). |
| T4 Contribution | N/A | Contribution artifacts are deliberately absent at Check; the substantive user-impact/tracker audit must rerun at publish (`gate-logs/T4-contribution.log:10`). |
| T5 Judgment | NEEDS-HUMAN | Confirm affected-path prior art across merged and closed/rejected work — the brief records a search, but this snapshot has one base commit, no remote, and no captured path-level PR evidence, so superseded or rejected work cannot be independently ruled out (`brief.md:25`; investigation below). |
| Validation — fitness-to-purpose | NEEDS-HUMAN | Decide whether the novel-stratum evidence is sufficient for the step-2 premise and later threshold choices — synthetic correctness tests do not establish representative accuracy or the stated 30–60k-row runtime expectation (`target/tests/test_backtest.py:157`, `target/src/autobook/pipeline/trial.py:347`, `brief.md:188`). |

All source citations above resolve in the supplied `$PDCA_TARGET` (`target/`); no stale-target caveat was needed. No other checkout or builder notes were consulted. The supplied target has no `INTEGRATION.md`, so no additional human-only list could be inspected.

The implementation concern is the newly exposed error-output boundary. `main()` catches `ContractError`, `NormaliserError`, and `KnnError` and forwards `str(exc)` to `_fail()`. An otherwise well-shaped invented corpus row with `amount_cents=-1250` produces:

```text
error: corpus.rows[0].amount_cents: must be at least 1, got -1250
```

A malformed calendar date similarly produces `not a calendar date: '2025-02-30'`. I exercised the actual contract parser and the unchanged `_fail` function extracted from the target source; `reviewer-privacy-probe.log` records the amount case and exit 2. This was a source-function probe, not a full CLI invocation. The connection between them is explicit at `target/src/autobook/pipeline/trial.py:418`. Preserve useful field/location and error-category information without echoing input values, and add captured-stderr assertions for refused corpus/profile inputs. The current invalid-input test checks exit status and absence of the report but not stderr (`target/tests/test_backtest.py:205`).

The core temporal boundary is sound on inspection: history is selected before the first day of each tested month before either model is built (`target/src/autobook/pipeline/trial.py:300`). The sweep scores the candidate independently of acceptance at the run's own thresholds (`target/src/autobook/pipeline/trial.py:217`). The added nonzero sweep, Bayes-prior/smoothing, partition, and blank-token cases address the earlier test weaknesses. The C5 capability-probe smell test does not fire: ignoring words outside the fitted vocabulary is the model's defined feature handling, not a fallback around a capability that should have been loaded.

Independent verification was limited by the review host: Python 3.14.4 is present, but pytest, scikit-learn, numpy, nox, ruff, and mypy are absent. A venv created entirely inside the scratch root could not install pytest (`reviewer-install.log:1`). Consequently I did not stash the patch for an unexecutable pytest run or claim a fresh red→green. I read every supplied gate log. The original gate did exercise the actual classifier dependency and completed its Python tests; the review-host install failure is not evidence that PyPI was undischarged in that run. The frozen CI log explicitly skips the unavailable GnuCash book test and deselects seven integration tests; these are outside this pipeline-only patch. The gate wrappers are instance-scoped and were not treated as missing target code.

I independently ran `python3 docs/tools/lint_docs.py` (two ADRs checked), `typos`, and `git diff --check` in the target. They completed successfully; the environment also emitted stream-fd diagnostics during that command batch. No source was edited.

For prior art I ran `git log --all --` with all five affected file paths, and inspected `git remote -v`. The only history returned was `71ea4be pre-fix base 450f7c8f2fe91181d435e3824b88c2494ca9e9d7`; the remote list was empty. The brief's reported historical search and disposition of closed issue #5 provide context, but the artifact bundle cannot independently confirm affected-path coverage of closed/rejected PRs. The T5 decision is to accept that recorded triage or supply the missing path-level history evidence.

This review is advisory; its C4 PASS describes the captured checks, and does not certify the untested error-output privacy property or choose production thresholds.
<!-- pdca:leaf-complete -->
