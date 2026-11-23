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
- C4 fix verified: bundle test red pre-fix, green post-fix (pytest): pass — C4 PASS — red without the fix (154 of 154 failed), green with it
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

Review issue #22: establish Autobook’s package stubs, validated versioned corpus/CoA contracts, and deterministic synthetic fixtures for subsequent build steps.

| Item | Verdict | Basis |
|------|---------|-------|
| C1 Spec | PASS | The bounded scaffold and contract requirements give executable acceptance criteria without requiring book access; `brief.md:11`, `target/docs/design/architecture/05-building-block-view.md:55`. |
| C2 Reproduction (red pre-fix) | PASS | Removing the production additions makes the independent probe fail on the absent contracts module; the frozen pytest red leg records 154 executed failures and no collection errors; `reviewer-rerun.log:17`, `gate-logs/C4-verify.log:5187`. |
| C3 Change | PASS | Changed surfaces stay within the approved skeleton/contracts/fixtures/docs scope, including PDF exclusion before synthetic exceptions; `target/.gitignore:42`, `target/.gitignore:54`, `target/docs/design/architecture/05-building-block-view.md:17`. |
| C4 Verification (red→green) | PASS | Independent probe returns green after stash restoration; frozen logs substantiate 154 new tests green and the full gate green, with local tooling limits detailed below; `reviewer-rerun.log:43`, `gate-logs/C4-verify.log:14`, `gate-logs/C4-ci.log:54`. |
| C5 Causal adequacy | NEEDS-HUMAN [impl] | Correct malformed CoA type handling before callers rely on the promised exception boundary — JSON arrays/objects currently escape as TypeError rather than ContractError; `target/src/autobook/contracts.py:178`, `reviewer-adversarial.log:1`. |
| T1 Structure | PASS | Shared contracts and staging remain independent of GnuCash and the pipeline, and all 18 block entry points execute as explicit stubs; `target/src/autobook/staging.py:5`, `target/tests/test_skeleton.py:40`, `reviewer-rerun.log:43`. |
| T2 Shape | NEEDS-HUMAN | Decide whether the new contract boundary and security-sensitive module paths require a threat-model update — the scanner flagged those paths, while this scope permits only stubs and excludes that document; `gate-logs/T2-threat-model.log:10`, `target/docs/design/architecture/05-building-block-view.md:55`. |
| T3 Runtime | PASS | Exercised valid contract round trips, integer/version rejection, fixture determinism, and imports without GnuCash; malformed type handling is separately recorded in C5; `reviewer-probe.py:16`, `reviewer-rerun.log:43`. |
| T4 Contribution | N/A | Contribution artifacts are absent by design; the substantive tracker/opener audit must rerun at publish; `gate-logs/T4-contribution.log:10`. |
| T5 Judgment | NEEDS-HUMAN | Confirm the path-based prior-art conclusion covers merged and closed/rejected work — the brief records a search, but this one-commit target and unreachable GitHub cannot independently establish historical coverage; `brief.md:26`. |
| Validation — fitness-to-purpose | NEEDS-HUMAN | Accept the shared API and synthetic dataset as the foundation for steps 2b–2e, including top-level staging and dropping the handwritten XML fixture — these scope choices require the maintainer’s sign-off and tracker record; `brief.md:212`, `brief.md:227`, `target/docs/design/architecture/05-building-block-view.md:23`. |

One implementation finding: **P2 — reject unhashable account types through ContractError.** At `target/src/autobook/contracts.py:178`, membership in the frozenset hashes `self.type` before validating that it is a string. A syntactically valid CoA JSON document with an account’s `type` set to `[]`, `{}`, or `["BANK"]` therefore raises `TypeError`. `_build` catches only `ContractError` (`target/src/autobook/contracts.py:276`), so both the decoded-document and JSON-text entry points leak the exception. A caller handling malformed contracts through the documented exception will miss it. Validate the string type before membership and add array/object cases for parsing and direct construction; current negative cases cover only hashable values (`target/tests/test_contracts.py:324`). Reproduction: from this report’s directory run `PYTHONDONTWRITEBYTECODE=1 python3 reviewer-adversarial.py`; all three observed cases print `ContractError=False` in `reviewer-adversarial.log`.

Verification limits and evidence: the disposable target is readable and current; `git apply --reverse --check ../patch.diff` succeeds. Only production additions were stashed, leaving tests and fixtures available; the target was restored afterward. The independent standard-library probe is supplementary evidence, not a claim to have rerun pytest. This sandbox lacks pytest, nox, ruff, and mypy. I read all four frozen logs: C4-ci shows formatting, lint, types, spelling and docs success, plus 156 tests passed, one GnuCash-dependent test skipped and seven live tests deselected; C4-verify shows 154 passed with the patch and 154 failed without it, zero setup/collection errors. I independently reran docs lint and typos successfully. The excluded book/live environments are outside this cycle’s scope, not an unmet external dependency for these standard-library contracts (`brief.md:23`).

The three carry-forward changes are present: staging is checked through the import system, object construction rejects string paths, and account types have the requested closed set. The remaining finding concerns malformed JSON value types in that new set check. The C5 symptom-guard rule does not fire: the added exception handlers report invalid input, and no capability probe masks a load-time side effect. The fixture’s eight accounts and types agree with `target/tests/book/synthetic_book.py:14` by source inspection; no GnuCash export comparison is claimed.

Prior-art investigation: `git log --all -- src/autobook tests/fixtures` returned only synthetic base commit `21adc8e`; `git remote -v` returned nothing. `gh pr list --repo Ralphovi/autobook --state all --limit 100 --json number,state,title,files` failed with “error connecting to api.github.com.” The brief documents path-based merged-history review and an all-state PR review, but that historical conclusion remains unconfirmed here. No INTEGRATION.md was supplied or found under the target; the supplied standing rubric was applied. This report is advisory and does not gate acceptance.

<!-- pdca:leaf-complete -->

### Advisory — adversary

# Adversarial review — issue 22 / package-skeleton-contracts-fixtures (iteration 2)

I re-ran nothing through the gate. Instead I read the frozen logs and probed the patched
target directly with `python3 -B` (`sys.path` pointed at `target/src`, no files written).
I found one concrete failing input. Everything else I tried held up.

## Findings

- NEEDS-HUMAN [impl] — `src/autobook/contracts.py:178`: `parse_coa` crashes with an
  uncaught `TypeError` instead of `ContractError` when an account's `type` is a JSON array
  or object. `if self.type not in ACCOUNT_TYPES` checks membership in a `frozenset`, and
  that needs a hashable value. Repro: take `tests/fixtures/synthetic/coa.json`, set
  `accounts[0].type` to `["BANK"]` (or `{"x": 1}`), then call `parse_coa` →
  `TypeError: cannot use 'list' as a set element`. `coa_from_json` goes the same way
  (`isinstance(e, ContractError)` is False). This breaks the brief's rule that parse
  rejects bad documents "with one module-defined exception type". A reader that catches
  `ContractError` (or `ValueError`) to reject a bad export gets an unexpected crash instead.
  This is the same closed-set check the iteration-1 carry-forward asked for (finding 3).
  The new test `tests/test_contracts.py:324` only feeds it hashable non-strings (`1`,
  `None`), so it never hits this. Fix: run `_text(self.type, "type")` before the
  membership test, and add `["BANK"]` / `{}` to that parametrize list.

## What I tried and could not break

- **Red→green evidence.** `gate-logs/C4-verify.log`: 154 ran, 154 failed, 0 collection
  errors. That count fits the green run in `gate-logs/C4-ci.log`: 156 passed, minus the 2
  pre-existing `test_smoke.py` tests. Every test loads `autobook.contracts` / the builder
  through `importlib.import_module` inside the test body, so they test the real production
  module, not a copy. The red leg only shows the module is missing: every red failure is a
  `ModuleNotFoundError`. It does not show that each validation rule matters. The brief
  accepts that for a greenfield patch, so I don't count it as a refutation.
- **Tests passing for the wrong reason.** I worked out, by reading the tests (I did not run mutants), which removed checks the
  tests would catch. Using `isinstance` instead of `type(...) is int` in `_cents`
  (`True` passes the `>= 1` test) is caught by the `True` cases for amount and fraction.
  Removing `type(found) is not int` in `_header` (`1.0 == 1`) is caught by the
  `1.0`/`True` version cases. Removing the regex in `_date` is caught by
  `"20260102"`/`"2026-W01-5"`. Removing the `isinstance(value, tuple)` check in `_path` is
  caught by the str-path construction tests (carry-forward finding 2). Removing the
  closed-set `type` check is caught by `equity`/`EQUITYY` (finding 3). The staging test
  now asks `importlib.util.find_spec` (the import system) rather than its own helper, so
  it can go red (finding 1).
- **Serialiser writing a document the parser refuses.** `__post_init__` on every
  dataclass runs the same checks, and `_components` copies the parsed list into a tuple.
  I found no way to build an object, short of `object.__setattr__`, whose serialised form
  `parse_*` rejects.
- **Money.** A float, a bool, `0` and negative values are all rejected for
  `amount_cents` and `fraction`, both when parsing and when building an object.
  `NaN`/`Infinity` in the JSON text decode to floats and are rejected the same way.
- **Fixtures.** `coa.json` matches `tests/book/synthetic_book.py:14-23` `ACCOUNTS`
  account by account (same 8 paths, types and order). The novel row is on day 28, and
  every regular row is on day 27 or earlier, so it really is alone on the latest date.
- **`.gitignore`.** `*.pdf` sits at `.gitignore:42`, inside the financial-data block and
  above the un-ignore lines at `.gitignore:54-55`, so synthetic PDFs stay committable.

## Non-findings, recorded so nobody chases them

- A 100k-deep nested JSON array raises `RecursionError` from `json.loads`, not
  `ContractError` (`contracts.py:429` catches only `ValueError`). That comes from the
  standard library, and the book process will never emit such a document. Not raised.
- The `coa` contract accepts `type: "ROOT"` even though paths "exclude the root
  account". The sign-off carry-forward named `ROOT` in the closed set, so this was decided
  on purpose. Not raised.
- The T2 threat-model row is UNVERIFIABLE, as the brief expected. The new modules are
  stubs with no behaviour. That call belongs to sign-off, not to me.

<!-- pdca:leaf-complete -->

### Advisory — security-review

# Security review — issue 22 (package skeleton, contracts, fixtures)

Attacker-reachable inputs this diff touches: **none live yet.** The new `corpus` and `coa` contracts (`src/autobook/contracts.py`) are book → pipeline documents built from the user's own booking history and live chart of accounts, which the threat model lists as trusted. The one field that started life as counterparty text is `raw_memo` (threat model "Where untrusted input enters" item 1). In this diff it is only stored as a `str` and has no consumer: no normaliser, review file, log or model adapter reads it yet. Every building-block module is a `NotImplementedError` stub with no imports.

No findings. Here is what I checked against the threat model's "What must hold" list and the rubric's recurring defect classes:

- **Money is exact.** `_cents` uses `type(value) is not int` (`src/autobook/contracts.py:235`), so `12.5`, `1250.0`, `True` and `NaN`/`Infinity` (which `json.loads` returns as floats) are all rejected, and `0`/negatives are rejected by `minimum=1` (`:237`). The same check covers `fraction` (`:183`) and `version` (`:220`). Oversized integer strings hit Python's int-digit limit inside `json.loads`, which raises `ValueError`, and `_decode` turns that into `ContractError` (`:427-430`). No float path exists. `tests/test_contracts.py:202-209` and `:388-407` cover float, bool, string, None, zero and negative for both fields. That is the hostile case, not only the friendly one.
- **Account paths.** A bare string is refused on both sides: `_components` needs a JSON list (`:267`), and `_path` needs a non-empty tuple of non-empty strings (`:251-254`). Nothing joins or splits on a separator, so a component holding `:` or `.` stays one component.
- **Provenance.** Only `observed` is accepted (`:141`), so a `corrected` row cannot enter through the corpus contract.
- **Unknown or missing fields, closed sets.** `_mapping` rejects both (`:204-210`). `sign` and the GnuCash `type` are closed sets (`:134`, `:178`). Any later LLM label check that filters on `type` therefore cannot be dodged with a misspelt or lower-case type.
- **Personal data in error messages.** `ContractError` text never contains `raw_memo` or path-component values. `_text` reports only the type name (`:227`). Values that do get echoed (`sign`, `contract`, `version`, `post_date`, unknown key names) are structural fields from the exporter, not memo text. A `json.JSONDecodeError` message carries a position, not the document content. If one of these were ever wrong, it would be Low on the threat model's scale ("non-personal information in error messages") at most.
- **The pipeline never imports `gnucash`.** None of the 11 pipeline stubs, 6 book stubs, `staging.py` or `contracts.py` imports anything beyond the standard library. `tests/test_skeleton.py` asserts `gnucash` is not in `sys.modules` after importing them all. The C4-verify log shows 154 tests ran red without the fix and green with it, with 0 collection errors.
- **Committed fixtures.** `tests/fixtures/synthetic/corpus_builder.py:33-61` uses invented `BEISPIEL…`/`MUSTER…` names. Its noise templates contain only digits and dates, with no IBAN-shaped strings. It uses a local `random.Random(seed)` with a narrow `# noqa: S311` (`:71`). `coa.json` holds only the synthetic tree, with integer `fraction: 100`. The README states the synthetic-only rule.
- **`.gitignore`.** `*.pdf` lands inside the financial-data block (`.gitignore:42`), above the `!tests/fixtures/synthetic/` un-ignore lines that now sit at the end of the file. Real statement PDFs are now ignored, and synthetic ones are not re-ignored.

Out of scope here and not raised: the apply-time check that the commodity is shared and has fraction 100 belongs to the applier (#26/#35/#37). This contract only carries `fraction` as a positive integer, as the brief asks.

<!-- pdca:leaf-complete -->

## 6. NEEDS-HUMAN — items the human must clear before sign-off
- [ ] C5 Causal adequacy — Correct malformed CoA type handling before callers rely on the promised exception boundary — JSON arrays/objects currently escape as TypeError rather than ContractError; `target/src/autobook/contracts.py:178`, `reviewer-adversarial.log:1`.
- [ ] T2 Shape — Decide whether the new contract boundary and security-sensitive module paths require a threat-model update — the scanner flagged those paths, while this scope permits only stubs and excludes that document; `gate-logs/T2-threat-model.log:10`, `target/docs/design/architecture/05-building-block-view.md:55`.
- [ ] T5 Judgment — Confirm the path-based prior-art conclusion covers merged and closed/rejected work — the brief records a search, but this one-commit target and unreachable GitHub cannot independently establish historical coverage; `brief.md:26`.
- [ ] Validation — fitness-to-purpose — Accept the shared API and synthetic dataset as the foundation for steps 2b–2e, including top-level staging and dropping the handwritten XML fixture — these scope choices require the maintainer’s sign-off and tracker record; `brief.md:212`, `brief.md:227`, `target/docs/design/architecture/05-building-block-view.md:23`.
- [ ] `src/autobook/contracts.py:178`: `parse_coa` crashes with an uncaught `TypeError` instead of `ContractError` when an account's `type` is a JSON array or object. `if self.type not in ACCOUNT_TYPES` checks membership in a `frozenset`, and that needs a hashable value. Repro: take `tests/fixtures/synthetic/coa.json`, set `accounts[0].type` to `["BANK"]` (or `{"x": 1}`), then call `parse_coa` → `TypeError: cannot use 'list' as a set element`. `coa_from_json` goes the same way (`isinstance(e, ContractError)` is False). This breaks the brief's rule that parse rejects bad documents "with one module-defined exception type". A reader that catches `ContractError` (or `ValueError`) to reject a bad export gets an unexpected crash instead. This is the same closed-set check the iteration-1 carry-forward asked for (finding 3). The new test `tests/test_contracts.py:324` only feeds it hashable non-strings (`1`, `None`), so it never hits this. Fix: run `_text(self.type, "type")` before the membership test, and add `["BANK"]` / `{}` to that parametrize list.
- [ ] T2 security-relevant change also updates the threat model unverifiable — security-relevant paths changed without a threat-model update: src/autobook/book/__init__.py src/autobook/book/applier.p
- [ ] **The maintainer decisions the brief relies on are not in the tracker record.** The brief says "Dropped by the maintainer at Plan" for the XML book, and "the maintainer approved these names at Plan" for `autobook.contracts` / `.pipeline` / `.book`. `notes.json` has only one comment, about the account separator. It says nothing about dropping the XML book or about package names. The issue body still lists "A tiny hand-written synthetic XML book … for book-process tests" in scope. If this is not confirmed, Check could flag the cycle as missing an in-scope item. Either confirm both decisions on the issue thread, or cite where they were recorded.
- [ ] **Where `*.pdf` goes in `.gitignore` is not specified, and the obvious place breaks the synthetic exception.** `.gitignore:53-54` ends with `!tests/fixtures/synthetic/` and `!tests/fixtures/synthetic/**`. In gitignore the last matching pattern wins. If `*.pdf` is appended at the end of the file, as scope item (4) suggests, it re-ignores every synthetic PDF fixture (#23–#26 and proposal 0002 will need document fixtures). The brief should say to add it to the "Never commit financial data" block (`.gitignore:26-43`), before the un-ignore lines.
- [ ] **`tests/test_skeleton.py` cannot find each module's entry point.** The brief says "Entry-point names and signatures are Do's choice". Rule 2 then forbids naming the modules and requires `pkgutil` discovery. Discovery alone does not tell the test which attribute to call, so the assertion "exposes its entry point, and the entry point raises `NotImplementedError`" is not defined. Fix one convention in the brief: a shared function name, or a module-level marker naming the entry point. Otherwise the test may check nothing per module, or Do will pick a convention that #23–#26 then have to discover. Signatures stay free, so calling the entry point with no arguments is also undefined. Either require no required parameters, or say to assert only that it is callable.
- [ ] **The `gnucash not in sys.modules` assertion depends on which host runs it.** The Falsifiability line runs C4-verify as "host pytest in `$PDCA_WORKTREE`" with `-m "not applier …"`. A `-m` filter deselects tests after collection, but every module is still imported. `tests/book/test_testenv_book.py:20` runs `pytest.importorskip("gnucash")` at module scope and is collected before `tests/test_*.py`. On a host with system `python3-gnucash` visible, `gnucash` is already in `sys.modules`, so the new skeleton test fails on both legs. The criterion's test file is `test_contracts.py`, so this does not block red→green. It can still make `test_skeleton.py` red after the patch on such a host. The existing `tests/test_smoke.py:28` has the same exposure, so this is inherited. The brief should either confirm the C4 host has no `gnucash` importable, or make the skeleton test check a fresh subprocess or a `sys.modules` diff instead.
- [ ] **One rejection rule in the corpus contract is still open.** `amount_cents` is "non-negative int", so zero passes parse. ch.5 §5.1 lists `sign` as a separate field, so a zero-amount row has an ambiguous direction. Either state that zero is allowed (and which `sign` it takes), or make it positive like `fraction`. As written, Do decides a contract rule that the brief says it fixes so Do does not re-decide it.
- [ ] **(Minor) The staging store's placement goes unremarked.** The brief places `staging` in `autobook/pipeline/`, giving the count of 12 pipeline modules. ch.5 §5.1 (`05-building-block-view.md:22`) lists the **Staging store** as its own top-level block, next to Pipeline, Book process and Launcher, not as a pipeline component. That is defensible, because only the pipeline touches it. But the brief also has Do replace the ch.5 `[OPEN]` naming note, so the docs update will make this placement official. Note it as a deliberate choice in "Alternatives considered", so the reviewer does not read it as a drift from ch.5.
- [ ] size backstop — this slice is behaving oversized: patch touches 31 files (threshold 20). Recommend answering `iterate-plan` at sign-off and authoring the split in the re-plan (`pdca split`), rather than `iterate-do`: a slice that is too big yields implementation-shaped findings every round, and splitting authors briefs, which is Plan's beat.

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
- Iteration delta (if iterating): Keep the design, scope and everything else in the patch unchanged; fix only the one remaining adversarial finding, with a test: 1. src/autobook/contracts.py:178 — the coa account `type` closed-set check (`self.type not in ACCOUNT_TYPES`) hashes the value before checking it is a string, so a JSON array/object `type` (e.g. ["BANK"], {}, {"x": 1}) raises TypeError instead of ContractError, through both parse_coa and coa_from_json and on direct construction. Validate with `_text(self.type, "type")` before the membership test so every malformed type raises ContractError. 2. Add ["BANK"] and {} (array and object) cases to the non-string `type` parametrize list in tests/test_contracts.py (~:324), covering parsing (document and JSON text) and direct construction. Do not re-open the size question: the 31 files are mostly 18 one-pattern stubs; the slice stays as one.
- By / date: Eduard Ralph / 2026-10-15

## 10. Act candidates (hints for the next Act review)
- Plan advisory: 6 finding(s); brief revised: yes (plan-advisory-*.md)
- (empty is the common case)
