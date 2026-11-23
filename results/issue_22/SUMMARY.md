# Result — issue 22 / package-skeleton-contracts-fixtures

## 1. Spec (from brief.md)              ← Check verifies against THIS
- Defect / goal: Give every later build-step-2 cycle (2b normaliser, 2c kNN, 2d backtest, 2e exporter) existing symbols to test against: the package layout of ch.5 with one stub module per building block, versioned and validated `corpus` and `coa` JSON contracts, and synthetic fixtures (a seeded corpus builder and a synthetic `coa.json`).
- Success criterion: `tests/test_contracts.py` passes with the patch applied and fails, with tests that RUN (not a collection error), with the production change reverted. It must assert, for BOTH `corpus` and `coa`: (a) round-trip — parsing the serialised form of a contract object gives back an equal object, and serialising a parsed canonical document gives back the same document; (b) a document whose version is not one this code knows is rejected with the module's contract error; (c) a non-integer value (a float such as `12.5`, or a bool) is rejected where the contract requires an integer: `amount_cents` in `corpus`, `fraction` in `coa`.
- Repo + branch target: Ralphovi/autobook @ main
- Scope (one logical fix) / out of scope: (1) the package layout below, with every pipeline and book-process building block as its own module exposing one entry point that raises `NotImplementedError`, plus `autobook/staging.py` as its own top-level stub module (the Staging store block); (2) `autobook.contracts`, the versioned `corpus` and `coa` contract dataclasses with serialise/parse, a version check and value validation; (3) `tests/fixtures/synthetic/` with a README stating the synthetic-only rule, a seeded corpus builder and a synthetic `coa.json`; (4) add `*.pdf` to `.gitignore` inside the "Never commit financial data" block (`.gitignore:31-43`, e.g. after `*.camt*.xml`), never after the synthetic un-ignore lines `.gitignore:53-54` (last match wins, so a trailing `*.pdf` would re-ignore synthetic PDF fixtures); (5) record the chosen layout and the contracts' wire shape in ch.5 (docs currency, AGENTS.md). / out of scope: the hand-written synthetic XML book (dropped by the maintainer; `tests/book/synthetic_book.py` covers it); registering the `live_paperless` marker and deselecting it in `nox -s gate` (already on main, `pyproject.toml` markers and `noxfile.py` `test` session, from #48); the `existing`, `apply-in` and `apply-out` contracts (#35, #37); any real behaviour in a building-block module (normaliser #23, kNN #24, backtest #25, exporter #26); importing `gnucash` anywhere, and the per-file ruff exception for the book process (#26 adds it with the first module that needs it); the launcher (a shell script, build step 5, #40); new runtime dependencies (`pyproject.toml` `dependencies` stays empty); any change to `.oss-scanner/threat_model.md`.

## 2. Disposition claimed               ← sign-off confirms or overrides
- Outcome: new-feature
- Confidence: medium
- Recommendation: (set by Do)

## 3. Correctness (Check — chain)
- C1 Spec: none — brief.md
- C2 Reproduction (red pre-fix): none — (no gate configured)
- C3 Change: none — patch.diff
- C4 Autobook gate: nox -s gate (fmt/lint/types/test/typos/docs): pass — nox > * docs: success
- C4 fix verified: bundle test red pre-fix, green post-fix (pytest): pass — C4 PASS — red without the fix (177 of 177 failed), green with it
- C5 Causal adequacy: none — reviewer + human sign-off

## 4. Conformance (Check — stack)
- T1 Structure: none — (no gate configured)
- T2 security-relevant change also updates the threat model: unverifiable — security-relevant paths changed without a threat-model update: src/autobook/book/__init__.py src/autobook/book/applier.p
- T3 Runtime: none — (no gate configured)
- T4 PR body has a user-impact opener + tracker id in both artifacts: deferred — pr-description.md not drafted yet — the substantive T4 audit of the contribution artifacts runs at publish
- T5 Judgment: none — reviewer + human sign-off
- T5 judgment: → see §5.

## 5. Advisory review (artifact-only, decorrelated)
Reviewer ran without build-notes.md. Summary:

Review issue #22: establish the package skeleton, validated versioned corpus/CoA contracts, and synthetic fixtures, including consistent rejection of malformed CoA account types.

| Item | Verdict | Basis |
|------|---------|-------|
| C1 Spec | PASS | The accepted foundation has falsifiable round-trip, version, integer-value, and malformed-type requirements; scope is settled in the latest carry-forward (brief.md:239; target/tests/test_contracts.py:102; target/tests/test_contracts.py:324). |
| C2 Reproduction (red pre-fix) | PASS | Missing production symbols reproduce the stated greenfield failure: five independent checks ran and failed with production stashed; frozen pytest evidence records 177 failures without collection errors (reviewer-red.log:134; gate-logs/C4-verify.log:5920). |
| C3 Change | PASS | The patch supplies the approved foundation without implementing book operations or adding runtime dependencies; contract and account-path semantics are documented for downstream consumers (target/docs/design/architecture/05-building-block-view.md:17; target/docs/design/architecture/05-building-block-view.md:55; target/pyproject.toml:30). |
| C4 Verification (red→green) | PASS | Independent checks reproduced 5 failing→5 passing; frozen evidence supports 177 failing→177 passing and the complete nox gate; local docs/spelling checks passed, while pytest/nox/ruff/mypy results are log-backed (reviewer-green.log:8; gate-logs/C4-verify.log:5922; gate-logs/C4-ci.log:54; gate-logs/C4-ci.log:70). |
| C5 Causal adequacy | PASS | Malformed account types now reach the contract error boundary before hashing; array/object cases pass through decoded parsing, JSON parsing, and construction, with no capability fallback masking an eager-load cause (target/src/autobook/contracts.py:176; target/tests/test_contracts.py:340; reviewer-green.log:2). |
| T1 Structure | PASS | The shared staging block remains outside the pipeline, all 18 building-block entry points raise NotImplementedError, and imports require no GnuCash; independent execution confirms the intended process separation (target/tests/test_skeleton.py:37; target/tests/test_skeleton.py:43; reviewer-green.log:4). |
| T2 Shape | NEEDS-HUMAN | Decide whether these new contract and stub surfaces require a threat-model update — the path scanner flags security-relevant additions, while the brief excludes that edit from this implementation (gate-logs/T2-threat-model.log:10; target/docs/design/architecture/05-building-block-view.md:55). |
| T3 Runtime | PASS | Executed boundary checks preserve integer cents and component paths; fixture checks across 50 seeds preserve deterministic generation and a single latest-date novel merchant, without invoking book services (target/src/autobook/contracts.py:235; target/tests/fixtures/synthetic/corpus_builder.py:69; reviewer-green.log:3; reviewer-green.log:5). |
| T4 Contribution | N/A | Contribution artifacts are absent by design at Check; the substantive user-impact/tracker audit is deferred to the required publish rerun (gate-logs/T4-contribution.log:10). |
| T5 Judgment | NEEDS-HUMAN | Confirm the affected-path prior-art search covers merged and closed/rejected work — the brief records that search, but this one-commit target has no historical evidence and the attempted GitHub query could not connect, leaving reuse/rejection history independently unconfirmed (brief.md:26). |
| Validation — fitness-to-purpose | NEEDS-HUMAN | Accept whether this documented contract and fixture foundation is sufficient for downstream normaliser/classifier/exporter work — tests establish boundary behavior, while suitability for those future consumers remains a sign-off decision (target/docs/design/architecture/05-building-block-view.md:71; target/tests/fixtures/synthetic/corpus_builder.py:69). |

Source citations prefixed `target/` were checked in `$PDCA_TARGET`, the disposable copy supplied with this review. `git apply --reverse --check ../patch.diff` succeeded there, so no stale-target caveat applies. The production-only stash included untracked additions under `src/autobook`; tests and fixtures stayed available. Restoration succeeded, and content hashes before and after matched for every non-cache file outside Git metadata. No implementation files were edited.

Independent execution used `PYTHONDONTWRITEBYTECODE=1 python3 reviewer_probe.py`, a standard-library unittest probe retained with its red and green logs. It exercised both contract round trips, invalid versions, integer/path validation, malformed CoA types through all three entry points, package entry points, and 50 fixture seeds. This is additional evidence, not a substitute pytest runner. The frozen red-leg output records missing production modules and missing skeleton assertions as test failures, rather than collection errors.

This sandbox has no importable pytest, nox, ruff, or mypy. Their full-gate results therefore rest on the supplied logs: formatting, lint, types, spelling, and docs succeeded; host tests recorded 179 passed, one GnuCash-dependent collection skip, and seven deselections. The focused bundle recorded 177 passed and 177 failed in its respective legs. Independently, `python3 docs/tools/lint_docs.py`, `typos`, and `git diff --check` exited successfully. The instance-root wrappers were not available here; their frozen logs were read instead. No missing log prevents adjudication. The brief declares no external dependencies, and real book/Paperless execution is outside this stub-and-contract scope.

The local affected-path history query returned only the harness's synthetic base commit. `gh pr list --repo Ralphovi/autobook --state closed --limit 100 --json number,title,state,files` failed with “error connecting to api.github.com”; no closed-work result is inferred from that failure. No INTEGRATION.md was supplied in the target or review bundle. The threat-model decision above is the explicit project-specific human item present in the provided evidence. No builder-fixable concern was found.

<!-- pdca:leaf-complete -->

### Advisory — adversary

# Adversarial review — issue 22, iteration 3 (package skeleton, contracts, fixtures)

**Verdict: I could not refute the fix.** I tried to break the round-3 change (the coa `type` check), the red→green evidence, the contract parsers in general, and the fixtures. Nothing I found breaks a brief requirement or a rubric class. The points below are informational. None needs a rebuild or a human decision, so there are no NEEDS-HUMAN bullets.

## What I tried and could not break

- `src/autobook/contracts.py:180`: the round-3 fix holds. I put the old line (`if self.type not in ACCOUNT_TYPES:`) back into a scratch copy of the module. With it, `["BANK"]`, `{}` and `{"x": 1}` raise `TypeError`, not `ContractError`. The new cases at `tests/test_contracts.py:334-336` run through all three paths (`:341` parsing a decoded document, `:348` parsing JSON text, `:358` direct construction). `pytest.raises(ContractError)` does not catch `TypeError`, so these tests fail on the old code and pass on the new. They call the production module, not a copy of it.
- Red→green evidence (`gate-logs/C4-verify.log`): green leg 177 passed; red leg 177 of 177 failed with no collection errors. Every red failure is `ModuleNotFoundError: autobook.contracts`, because this is new code and the red leg removes the whole module. So the gate proves the tests run and import the production module. It does not prove that each assertion catches a defect. The mutation check above covers that for the round-3 change. Earlier rounds' fixes (str path rejected at `contracts.py:253`, closed type set at `:84-107`, staging check by `find_spec` at `tests/test_skeleton.py:39-40`) all go through the production import and would fail if their line were removed. That is a design limit of a new-code cycle, which the brief accepts, not a flaw in this patch.
- Closed-set and type checks on other fields against unhashable or wrong-typed JSON values: `sign` (`contracts.py:134`) tests membership in a tuple, which compares with `==` and never hashes, so `["out"]` gives `ContractError`. `provenance` (`:141`), `contract` (`:218`) and `version` (`:222`) compare with `!=`/`is`, which works for any JSON value. Nested lists inside a path (`["Aktiva", ["x"]]`) are caught by `_text` at `:256`. `IntEnum`, `bool` and `float` amounts are refused by `type(...) is not int` (`:237`). `NaN`/`Infinity` and `1e2` parse as float and are refused.
- Money rubric: no float reaches any money field. The fixture amounts are `rng.randint` integers (`tests/fixtures/synthetic/corpus_builder.py:82,93`). `fraction` is a strict positive int (`contracts.py:185`).
- Fixtures: `tests/fixtures/synthetic/coa.json` matches `tests/book/synthetic_book.py:14-23` exactly: 8 accounts in the same order with the same types, `placeholder: false`, `CURRENCY`/`EUR`, fraction 100. The novel merchant is placed on day 28 (`corpus_builder.py:50`). Regular rows only use days 1-27 (`:77`), so it is the only row on the latest date for every seed, and the test checks this on three seeds (`tests/test_synthetic_fixtures.py:45-57`). The builder uses a local `random.Random(seed)` with a narrow `# noqa: S311` (`corpus_builder.py:71`).
- Gate hygiene: no test file contains `applier` or `live_paperless`. All new-module imports happen inside test bodies via `importlib`. There are no skips. `nox -s gate` is green (`gate-logs/C4-ci.log:64-70`).

## Informational (not NEEDS-HUMAN, take or leave)

- `src/autobook/contracts.py:428-432`: `_decode` catches only `ValueError`. A deeply nested JSON text, e.g. `corpus_from_json("[" * 100000)`, raises `RecursionError` instead of `ContractError`. I reproduced this on Python 3.14.4. It fails closed (the document is still refused, never accepted), and the input comes from Autobook's own book process. So this is a small gap against the "parse rejects with ContractError" wording at `:17-19`, not a safety issue. Catching `RecursionError` there too would close it.
- `src/autobook/contracts.py:370-396`: `parse_coa` accepts two accounts with the same `path` and different `type`s (e.g. `["A"]` as `BANK` and as `EXPENSE`). It also accepts a corpus row whose `source_account` equals its `destination_account`. The brief does not ask for either check, and the exporter (#26) is where such a tree would come from, so this belongs there or in a follow-up, not in this patch.
- `src/autobook/contracts.py:357-358`: a `raw_memo` holding a lone surrogate (JSON `"\ud800"`) parses fine. `corpus_to_json` then returns text that cannot be encoded as UTF-8 (`UnicodeEncodeError` on `.encode("utf-8")`). GnuCash stores memos as UTF-8, so a real book cannot produce this. Mentioned only for completeness.
- T2 threat-model row (`gate-logs/T2-threat-model.log`): flagged as the brief predicted. Every flagged file is a stub that raises `NotImplementedError` and adds no new input or trust boundary, so I see no threat-model change to request. That stays a sign-off call, as the brief says.

<!-- pdca:leaf-complete -->

### Advisory — security-review

# Advisory security review — issue 22 / package-skeleton-contracts-fixtures

**Attacker-reachable inputs this diff touches: none in the threat model's "Where untrusted input enters" list (§1–8).** The only new code that reads input is the parser in `autobook.contracts` (the `corpus` and `coa` documents). The book exporter writes those documents from the user's own book, which the threat model lists as **trusted** (the user's booking history and the live chart of accounts). No statement file, plugin output, FITID, model output, rule pack, review file, paperless metadata or downloaded original reaches any line in this patch. The 18 building-block modules (`src/autobook/book/*`, `src/autobook/pipeline/*`, `src/autobook/staging.py`) are inert stubs. Each one only imports `__future__` and raises `NotImplementedError`. None imports `gnucash`, opens a session, writes, logs or touches the network.

The T2-threat-model gate is UNVERIFIABLE (`gate-logs/T2-threat-model.log`) because the new stub paths match security-relevant patterns. Nothing in this diff adds an input, moves a trust boundary or changes a must-hold property, so I see no reason to edit `threat_model.md` for it. That is a call for sign-off, and the brief expected it.

## What I checked (no finding unless listed below)

- **Money (integer cents)**: `src/autobook/contracts.py:240-247` `_cents` uses `type(value) is not int`. A float (`12.5`, `1e2`), a bool, and JSON `NaN`/`Infinity` (they decode to float) are all rejected with `ContractError`. I confirmed `"amount_cents": 1e2` gives `expected an integer, got float`. A 5,000-digit integer hits Python's int-to-string digit limit. `_decode` (`contracts.py:428-432`) turns that `ValueError` into a `ContractError`, so it does not crash. `fraction` uses the same check (`:184`). No float appears anywhere in the fixtures or the builder (`tests/fixtures/synthetic/corpus_builder.py`, `coa.json`).
- **Version and name gate**: `contracts.py:215-225` rejects `True` and `1.0` as a version because of the `type(...) is int` check. Unknown or missing fields are rejected (`:204-213`).
- **Account paths**: `_path` (`:256-262`) rejects a bare `str`, so `"Aktiva"` cannot be read as six components. `_components` (`:274-278`) requires a JSON array. Nothing joins or splits a path on a separator. The account `type` is a closed set and is checked as a string first (`:179-181`). This is the fix from iteration 2, and I confirmed it.
- **Provenance**: only `observed` is accepted (`:142-146`), so a `corrected` row cannot enter through this contract.
- **Privacy / fixtures**: the merchants are invented (`BEISPIELMARKT`, `NEUHEIM KIOSK`, …). There are no IBAN-shaped strings, and the generator uses a local `random.Random(seed)`. `coa.json` holds only the synthetic tree. `.gitignore:40` adds `*.pdf` inside the financial-data block, above the synthetic un-ignore at `.gitignore:53-54`, so synthetic PDFs stay committable and other PDFs are ignored.
- **gnucash boundary**: `contracts.py` imports only the standard library (`:31-38`). `tests/test_skeleton.py` checks `sys.modules` for `gnucash`.

## Findings

- NEEDS-HUMAN [impl] — **Low** (on the threat model's scale it is "information in error messages". It would become High, "personal data reaches a log or crash report", only after an exporter bug, so it is an Accident-class cause). `src/autobook/contracts.py:135`, `:144`, `:181`, `:219`, `:286`, `:290` put the rejected value into the `ContractError` text with `!r`. `:212` does the same for unknown key names. The input is the `corpus` document, written by the book process (trusted source). If a future exporter misplaces a column, for example putting the memo where `sign` belongs, the raw memo ends up in an exception message, which a caller will typically log or print. Reproducer (synthetic): a corpus row with `"sign": "BEISPIELMARKT KARTE 1234"` raises `corpus.rows[0].sign: expected one of ['out', 'in'], got 'BEISPIELMARKT KARTE 1234'` (I ran this against the patched module). The fix is cheap and stays in scope: report the type and length, or a fixed placeholder, instead of the value. `!r` on values that are always closed-set constants is fine. Optional: the contract has no logging today, and this is a pattern guard for the `existing`/`apply-in`/`apply-out` contracts that will copy it (#35, #37), not a live leak.

### Noted, not filed (trusted-source input; outside the threat model's rating)

- `json.loads` keeps the last of two duplicate keys. `{"amount_cents": 5, "amount_cents": 500}` parses as `500` without any error. A deeply nested document (`"[" * 100000`) raises `RecursionError` from `_decode` (`:430`), not `ContractError`. Both need a malformed document from the book process, which the threat model trusts. They matter only if a later contract (for example `apply-in`, which carries review decisions) is ever fed from a less trusted writer. If so, add `object_pairs_hook` duplicate rejection there. No action for this patch.

The security-relevant tests cover the hostile cases that matter for this slice, not just the friendly path: float and bool cents, a wrong version, a str path, and bad `type` values (in `tests/test_contracts.py`). No finding there.

<!-- pdca:leaf-complete -->

## 6. NEEDS-HUMAN — items the human must clear before sign-off
- [x] T2 Shape — Decide whether these new contract and stub surfaces require a threat-model update — the path scanner flags security-relevant additions, while the brief excludes that edit from this implementation (gate-logs/T2-threat-model.log:10; target/docs/design/architecture/05-building-block-view.md:55).
- [x] T5 Judgment — Confirm the affected-path prior-art search covers merged and closed/rejected work — the brief records that search, but this one-commit target has no historical evidence and the attempted GitHub query could not connect, leaving reuse/rejection history independently unconfirmed (brief.md:26).
- [x] Validation — fitness-to-purpose — Accept whether this documented contract and fixture foundation is sufficient for downstream normaliser/classifier/exporter work — tests establish boundary behavior, while suitability for those future consumers remains a sign-off decision (target/docs/design/architecture/05-building-block-view.md:71; target/tests/fixtures/synthetic/corpus_builder.py:69).
- [x] **Low** (on the threat model's scale it is "information in error messages". It would become High, "personal data reaches a log or crash report", only after an exporter bug, so it is an Accident-class cause). `src/autobook/contracts.py:135`, `:144`, `:181`, `:219`, `:286`, `:290` put the rejected value into the `ContractError` text with `!r`. `:212` does the same for unknown key names. The input is the `corpus` document, written by the book process (trusted source). If a future exporter misplaces a column, for example putting the memo where `sign` belongs, the raw memo ends up in an exception message, which a caller will typically log or print. Reproducer (synthetic): a corpus row with `"sign": "BEISPIELMARKT KARTE 1234"` raises `corpus.rows[0].sign: expected one of ['out', 'in'], got 'BEISPIELMARKT KARTE 1234'` (I ran this against the patched module). The fix is cheap and stays in scope: report the type and length, or a fixed placeholder, instead of the value. `!r` on values that are always closed-set constants is fine. Optional: the contract has no logging today, and this is a pattern guard for the `existing`/`apply-in`/`apply-out` contracts that will copy it (#35, #37), not a live leak.
- [x] T2 security-relevant change also updates the threat model unverifiable — security-relevant paths changed without a threat-model update: src/autobook/book/__init__.py src/autobook/book/applier.p
- [x] **The maintainer decisions the brief relies on are not in the tracker record.** The brief says "Dropped by the maintainer at Plan" for the XML book, and "the maintainer approved these names at Plan" for `autobook.contracts` / `.pipeline` / `.book`. `notes.json` has only one comment, about the account separator. It says nothing about dropping the XML book or about package names. The issue body still lists "A tiny hand-written synthetic XML book … for book-process tests" in scope. If this is not confirmed, Check could flag the cycle as missing an in-scope item. Either confirm both decisions on the issue thread, or cite where they were recorded.
- [x] **Where `*.pdf` goes in `.gitignore` is not specified, and the obvious place breaks the synthetic exception.** `.gitignore:53-54` ends with `!tests/fixtures/synthetic/` and `!tests/fixtures/synthetic/**`. In gitignore the last matching pattern wins. If `*.pdf` is appended at the end of the file, as scope item (4) suggests, it re-ignores every synthetic PDF fixture (#23–#26 and proposal 0002 will need document fixtures). The brief should say to add it to the "Never commit financial data" block (`.gitignore:26-43`), before the un-ignore lines.
- [x] **`tests/test_skeleton.py` cannot find each module's entry point.** The brief says "Entry-point names and signatures are Do's choice". Rule 2 then forbids naming the modules and requires `pkgutil` discovery. Discovery alone does not tell the test which attribute to call, so the assertion "exposes its entry point, and the entry point raises `NotImplementedError`" is not defined. Fix one convention in the brief: a shared function name, or a module-level marker naming the entry point. Otherwise the test may check nothing per module, or Do will pick a convention that #23–#26 then have to discover. Signatures stay free, so calling the entry point with no arguments is also undefined. Either require no required parameters, or say to assert only that it is callable.
- [x] **The `gnucash not in sys.modules` assertion depends on which host runs it.** The Falsifiability line runs C4-verify as "host pytest in `$PDCA_WORKTREE`" with `-m "not applier …"`. A `-m` filter deselects tests after collection, but every module is still imported. `tests/book/test_testenv_book.py:20` runs `pytest.importorskip("gnucash")` at module scope and is collected before `tests/test_*.py`. On a host with system `python3-gnucash` visible, `gnucash` is already in `sys.modules`, so the new skeleton test fails on both legs. The criterion's test file is `test_contracts.py`, so this does not block red→green. It can still make `test_skeleton.py` red after the patch on such a host. The existing `tests/test_smoke.py:28` has the same exposure, so this is inherited. The brief should either confirm the C4 host has no `gnucash` importable, or make the skeleton test check a fresh subprocess or a `sys.modules` diff instead.
- [x] **One rejection rule in the corpus contract is still open.** `amount_cents` is "non-negative int", so zero passes parse. ch.5 §5.1 lists `sign` as a separate field, so a zero-amount row has an ambiguous direction. Either state that zero is allowed (and which `sign` it takes), or make it positive like `fraction`. As written, Do decides a contract rule that the brief says it fixes so Do does not re-decide it.
- [x] **(Minor) The staging store's placement goes unremarked.** The brief places `staging` in `autobook/pipeline/`, giving the count of 12 pipeline modules. ch.5 §5.1 (`05-building-block-view.md:22`) lists the **Staging store** as its own top-level block, next to Pipeline, Book process and Launcher, not as a pipeline component. That is defensible, because only the pipeline touches it. But the brief also has Do replace the ch.5 `[OPEN]` naming note, so the docs update will make this placement official. Note it as a deliberate choice in "Alternatives considered", so the reviewer does not read it as a drift from ch.5.
- [x] size backstop — this slice is behaving oversized: patch touches 31 files (threshold 20); 2 round(s) already spent (threshold 2). Recommend answering `iterate-plan` at sign-off and authoring the split in the re-plan (`pdca split`), rather than `iterate-do`: a slice that is too big yields implementation-shaped findings every round, and splitting authors briefs, which is Plan's beat.

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
