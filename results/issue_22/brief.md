# Design proposal — issue 22 / package-skeleton-contracts-fixtures

> Plan artifact for Ralphovi/autobook#22 (build order 2a, milestone `03 · 2 — Premise`).
> The design itself is already settled in Autobook's architecture ch.5
> (`docs/design/architecture/05-building-block-view.md`); this proposal fixes the few
> choices ch.5 leaves `[OPEN]` (package and module names, contract wire shape) so Do does
> not re-decide them. Do reads ONLY this file.

- **Slug:** package-skeleton-contracts-fixtures
- **Kind:** enhancement (design proposal)
- **Goal:** Give every later build-step-2 cycle (2b normaliser, 2c kNN, 2d backtest, 2e exporter) existing symbols to test against: the package layout of ch.5 with one stub module per building block, versioned and validated `corpus` and `coa` JSON contracts, and synthetic fixtures (a seeded corpus builder and a synthetic `coa.json`).
- **Success criterion:** `tests/test_contracts.py` passes with the patch applied and fails, with tests that RUN (not a collection error), with the production change reverted. It must assert, for BOTH `corpus` and `coa`: (a) round-trip — parsing the serialised form of a contract object gives back an equal object, and serialising a parsed canonical document gives back the same document; (b) a document whose version is not one this code knows is rejected with the module's contract error; (c) a non-integer value (a float such as `12.5`, or a bool) is rejected where the contract requires an integer: `amount_cents` in `corpus`, `fraction` in `coa`.
- **Falsifiability:** RED is reachable on the C4-verify gate (`engine/scripts/run-verify.sh`, host pytest in `$PDCA_WORKTREE`, `-m "not applier and not live_paperless"`). Its red leg reverts every non-test hunk (all of `src/autobook/**`), so `autobook.contracts` no longer exists. A test that loads the module inside the test body with `importlib.import_module` then raises `ModuleNotFoundError` during the test call, and pytest records it as a test that RAN and FAILED. Checked at Plan with a scratch probe under Autobook's `pyproject.toml`: 2 ran, 2 failed, 0 collection errors. A module-level `import autobook.contracts` would instead be a collection error, which the gate reports as UNVERIFIABLE (§6), not red. So this holds only if every test file in the patch follows the import rule under *Design → Tests and the gate*.
- **Invariant to restore:** Every contract document crossing the pipeline/book-process boundary is accepted only when its contract name and version are ones the reading code knows, carries money only as integer cents, and names accounts only as a list of path components, never a separator-joined string. Sources: AGENTS.md "The pipeline/book-process boundary is load-bearing" (JSON contract, widened deliberately) and "Money is exact" (integer cents, never floats, fixtures included); ch.5 §5.1 "The JSON contracts" (each contract is versioned); the #22 maintainer comment and `testenv/README.md` (GnuCash's account separator is a user preference outside the book, so never build or parse paths with a hard-coded separator).
- **Repo + branch target:** Ralphovi/autobook @ main
- **Depends on:** none
- **Conflicts with:** none
- **Ordering note:** single-issue batch. #23–#26 (2b–2e) depend on this one and are not in this run. #26 (exporter) will build its XML book with `tests/book/synthetic_book.build()` from #48 rather than a hand-written XML file (the maintainer dropped that item from #22 at Plan).
- **Surfaces:** data
- **Difficulty:** medium — about 20 new files, all greenfield with no existing callers, plus `.gitignore` and ch.5. Rated up from low because `autobook.contracts` defines the cross-process interface every later step builds on, so a reviewer must check its shape against ch.5 and AGENTS.md as a whole.
- **Scope:** (1) the package layout below, with every pipeline and book-process building block as its own module exposing one entry point that raises `NotImplementedError`, plus `autobook/staging.py` as its own top-level stub module (the Staging store block); (2) `autobook.contracts`, the versioned `corpus` and `coa` contract dataclasses with serialise/parse, a version check and value validation; (3) `tests/fixtures/synthetic/` with a README stating the synthetic-only rule, a seeded corpus builder and a synthetic `coa.json`; (4) add `*.pdf` to `.gitignore` inside the "Never commit financial data" block (`.gitignore:31-43`, e.g. after `*.camt*.xml`), never after the synthetic un-ignore lines `.gitignore:53-54` (last match wins, so a trailing `*.pdf` would re-ignore synthetic PDF fixtures); (5) record the chosen layout and the contracts' wire shape in ch.5 (docs currency, AGENTS.md). / out of scope: the hand-written synthetic XML book (dropped by the maintainer; `tests/book/synthetic_book.py` covers it); registering the `live_paperless` marker and deselecting it in `nox -s gate` (already on main, `pyproject.toml` markers and `noxfile.py` `test` session, from #48); the `existing`, `apply-in` and `apply-out` contracts (#35, #37); any real behaviour in a building-block module (normaliser #23, kNN #24, backtest #25, exporter #26); importing `gnucash` anywhere, and the per-file ruff exception for the book process (#26 adds it with the first module that needs it); the launcher (a shell script, build step 5, #40); new runtime dependencies (`pyproject.toml` `dependencies` stays empty); any change to `.oss-scanner/threat_model.md`.
- **Repro instruction:** On `origin/main` (bd9a438), `python3 -c "import autobook.contracts"` fails with `ModuleNotFoundError`, and `src/autobook/` holds only `__init__.py`. After the patch, `pytest tests/test_contracts.py tests/test_skeleton.py tests/test_synthetic_fixtures.py` passes on the host with no GnuCash and no Docker, and `nox -s gate` is green.
- **External dependencies:** none
- **Test file:** tests/test_contracts.py
- **Citations expected:** Do must cite path:line on the target branch for every change it builds on: `pyproject.toml` (ruff config, `[tool.ruff.lint.per-file-ignores]`, mypy `strict`, pytest markers), `.gitignore` (the financial-data block `.gitignore:26-43` where `*.pdf` goes, and the synthetic-fixture un-ignore `.gitignore:53-54` it must stay above), `tests/test_smoke.py` (the gnucash-boundary test to mirror), and `docs/design/architecture/05-building-block-view.md` (§5.1 "The JSON contracts", the `[OPEN]` naming note at the top). Peer callsite for account paths: `tests/book/synthetic_book.py` `lookup()` walks components instead of splitting on GnuCash's separator. The `coa` contract carries the same component list. For the synthetic `coa.json`, mirror `ACCOUNTS` in that file (same names, same types, same parent order).
- **Prior-art check (triage cycles):** searched by path. `git -C ../autobook log --all -- src/autobook tests/fixtures` shows only the scaffold (0e0b7dc) and a docstring update (2baf4d6), with no contracts, pipeline or book-process code. `gh pr list --state all` (7 PRs, all merged) has nothing touching these paths except #48 (testenv), which added `tests/book/synthetic_book.py` and the `live_paperless` marker. `gh search issues "contract"` finds only the dependents #26, #35 and #37. No closed or rejected attempt. Result: nothing to reuse beyond #48's book builder and marker.
- **Disposition hint:** new-feature

## Motivation

The C4-verify gate can only prove red→green against code that exists. Until the
package layout and the contracts exist, every step-2 cycle would be pure greenfield:
its tests import API the same patch adds, so the gate reports "unverifiable" instead of
a red. This cycle creates the shared base (layout, contracts, fixtures) once, so that
from 2b on each cycle changes behaviour behind an existing symbol and gets a real red.

## Design

### Package layout (the maintainer approved these names at Plan)

All under `src/autobook/`. One module per building block of ch.5. Each module has a
docstring that names its building block and the ch.5 section it implements, and one
entry-point function that raises `NotImplementedError` (coverage already excludes that
line: `pyproject.toml` `[tool.coverage.report] exclude_also`). **Entry-point convention
(fixed, so `tests/test_skeleton.py` and #23–#26 can find it):** each building-block module
sets `__all__` to a list of exactly one name, the entry point. In this cycle the entry
point takes **no required parameters** (e.g. `def normalise() -> None`), so the test can
call it with no arguments and assert `NotImplementedError`. The function name is Do's
choice, fully typed for `mypy --strict`. Later cycles replace the signature and may grow
`__all__`; the one-name rule binds this cycle's stubs only.

- `autobook/contracts.py` — the versioned JSON contracts (below). **Standard library
  only**: both the pipeline venv and the book process's system Python (3.14 in testenv)
  must import it, and it must never import `gnucash`.
- `autobook/pipeline/__init__.py` and one module each for: `statement_source`,
  `admission` (admission and dedup), `normaliser`, `correlator`, `bill_matcher`,
  `classifier`, `model_adapter`, `disposition`, `batch_gate`, `review_file`, `trial`
  (trial tooling: backtest, rule builder, assistant detector, pack validator, linkage
  backtest). That is 11 pipeline modules.
- `autobook/staging.py` — the staging store, its own top-level block as in ch.5 §5.1
  (`05-building-block-view.md:22`). Same rules as `contracts.py`: **standard library
  only**, never imports `gnucash`, because both processes use it (the pipeline writes
  decisions; the book process's read-back records `applied` and undo reads the GUID list,
  ch.5 book-process table). Same entry-point convention as the building-block modules.
- `autobook/book/__init__.py` (the book process) and one module each for: `session`
  (session manager), `exporter`, `applier`, `readback`, `assertions`, `undo`. None of
  them imports `gnucash` in this cycle. The ban stays fully in force, and the first
  per-file exception arrives with #26.
- No launcher module. It is a shell wrapper and arrives with build step 5.
- `autobook/__init__.py` must not import the subpackages. `import autobook` stays as
  light as it is now, and `tests/test_smoke.py` must keep passing unchanged.

### Contracts (`autobook.contracts`)

Frozen dataclasses with a parse function and a serialise function per contract. Do
chooses whether these work on JSON text or on decoded dicts, as long as both
directions exist and round-trip. Every contract document carries its **contract name**
(`"corpus"` / `"coa"`) and an **integer version** (start at `1`, as a module constant
per contract). Parse rejects, with one module-defined exception type (a `ValueError`
subclass), any document that has:

- a missing or different contract name, or a version that is not the known one;
- a money field that is not a plain `int`: reject `float`, and reject `bool`, since
  `bool` is a subclass of `int` in Python;
- an account path that is not a non-empty list of non-empty strings;
- a missing or unknown field, or a value outside a closed set listed below.

`corpus` (book → pipeline; ch.5 §5.1): a list of rows. Each row has `raw_memo` (str),
`amount_cents` (**positive** int, the magnitude; `0` is rejected like a negative, because a zero-amount row has no direction and carries no signal for the classifier — the #26 exporter drops zero-amount transactions rather than emitting them), `sign` (a closed two-value set
giving the direction; Do picks the representation and documents it in ch.5),
`source_account` and `destination_account` (path components), `post_date` (ISO 8601
date `YYYY-MM-DD`), and `provenance`. The corpus contract accepts only `observed`
provenance: `corrected` rows never come from the book (ch.5 §5.1, AGENTS.md
"Provenance tagging is structural"). The corpus is two-split transactions only, so one
source and one destination per row and no split specification.

`coa` (book → pipeline): a list of accounts. Each account has `path` (components, root
account excluded), `type` (GnuCash's account-type name as a string, e.g. `ASSET`,
`BANK`, `EXPENSE`, `INCOME`, `EQUITY`, `TRADING`), `placeholder` (bool), `commodity`
(namespace and mnemonic, e.g. `CURRENCY` / `EUR`), and `fraction` (positive int, e.g.
`100`). The LLM label check later filters placeholder, Equity and Trading accounts
using exactly these fields.

Nothing in `autobook.contracts` joins or splits an account path on any separator
character.

### Synthetic fixtures (`tests/fixtures/synthetic/`)

`.gitignore` already un-ignores this path and only this path (end of `.gitignore`).
Add `tests/fixtures/__init__.py` and `tests/fixtures/synthetic/__init__.py` so the
builder can be imported as `tests.fixtures.synthetic.<module>`. Name the builder module
anything **not** matching `test_*.py`, because the gate treats `tests/*/test_*.py` as a
test file.

- `README.md` — the synthetic-only rule: every name, memo and amount is invented; no
  real statement, memo, IBAN, document or correspondent name, and nothing derived from
  one, even normalised (AGENTS.md "Never collect or commit transactions").
- The **seeded corpus builder** — a function taking an integer seed that returns a
  `corpus` contract object. Same seed gives an equal corpus, and a different seed gives
  a different one. Content: invented merchants × destination accounts across several
  months; **near-duplicates** (the same merchant under several memo variants, differing
  by the kind of noise the normaliser will strip: reference fragments, card fragments,
  sequence numbers, dates); and exactly **one planted novel merchant**, which occurs
  once, on the latest date in the corpus, so a rolling-origin backtest sees it only in
  its final month. Integer cents only. No IBAN-shaped strings. Use invented merchant
  names in the style of `tests/book/synthetic_book.py` (`BEISPIELMARKT …`). Account
  paths reuse that file's tree. Use a local `random.Random(seed)`, never the global
  generator. ruff `S311` fires under `tests/**`, so add a narrow `# noqa: S311` with a
  reason, not a blanket ignore.
- `coa.json` — a valid `coa` contract document describing exactly the account tree that
  `tests/book/synthetic_book.py` `ACCOUNTS` builds: the same 8 accounts and types,
  `placeholder: false`, commodity `CURRENCY`/`EUR`, fraction `100`, and paths as
  component lists (`["Aktiva", "Girokonto"]`). #26 will compare its export of the built
  book against this file. Matching it against `synthetic_book.py` belongs to #26,
  because that module imports `gnucash` and cannot be loaded on the host.

### Tests and the gate (C4-verify requirements, read this before writing a test)

- `tests/test_contracts.py` — the binding test (success criterion a–c), plus anything
  else from the parse rules above that Do considers worth pinning.
- `tests/test_skeleton.py` — every module under `autobook.pipeline` and `autobook.book`,
  plus `autobook.staging`, imports, has `__all__` of exactly one name, that name is callable, and calling it with
  no arguments raises `NotImplementedError`. Importing all of them plus
  `autobook.contracts` and `autobook.staging` does not put `gnucash` in `sys.modules` (mirror
  `tests/test_smoke.py:21-30`, an in-process check). This relies on the C4 host having no
  importable `gnucash`, which holds (checked at Plan: `python3 -c "import gnucash"` →
  `ModuleNotFoundError`); `tests/test_smoke.py` already carries the same assumption, and
  `tests/book/test_testenv_book.py:20` skips at collection there. Do not switch to a
  subprocess check (it would need a `S603` exception under `tests/**`).
- `tests/test_synthetic_fixtures.py` — the builder is deterministic per seed, contains
  near-duplicates and exactly one novel-merchant row on the latest date, and its output
  round-trips through the `corpus` contract. `coa.json` parses as a `coa` contract.

Three rules every test file in this patch must follow, or the gate cannot judge it:

1. **Load new modules inside the test body, never at module scope.** That covers
   `autobook.contracts`, `autobook.pipeline.*`, `autobook.book.*` and the fixture
   builder (which itself imports `autobook.contracts`). Use
   `importlib.import_module(...)` in the test. A bare in-function `import` trips ruff
   `PLC0415` (selected through `PL`, not ignored for `tests/**`). A module-scope import
   turns the red leg into a collection error, which is UNVERIFIABLE, not red.
2. **Keep the words `applier` and `live_paperless` out of every test file.** The gate
   greps test files for `\b(applier|live_paperless)\b` and, on a match, starts Autobook's
   Docker test environment, which this cycle does not need. So `tests/test_skeleton.py`
   discovers the modules of `autobook.book` / `autobook.pipeline` (e.g. with `pkgutil`)
   instead of naming them, and asserts a minimum module count per package (11 pipeline,
   6 book process) so a missing module still fails. `autobook.staging` is checked by
   name (it has no forbidden word).
3. **No `pytest.importorskip`, no skips.** A skipped test does not count as run, and a
   leg in which nothing ran is UNVERIFIABLE.

### Docs currency (same PR)

Update `docs/design/architecture/05-building-block-view.md`: replace the "package and
module names are provisional `[OPEN]`" note with the layout above, and in §5.1 "The
JSON contracts" record that every contract document carries its name and an integer
version, that accounts are path-component lists (never separator-joined, with the
reason), the `corpus` sign representation, and that `corpus` accepts only `observed`.
`nox -s gate` runs the docs lint (`docs/tools/lint_docs.py`) and `typos`. If `typos`
flags an invented German word in a fixture, add it to `typos.toml` with a reason, the
way the existing entries are added.

## Alternatives considered

- **A hand-written GnuCash XML book in this cycle** (in the original issue scope).
  Dropped by the maintainer at Plan: `tests/book/synthetic_book.py` (#48) builds XML and
  PostgreSQL books through the bindings at test time, and a hand-written file could only
  be checked inside Docker.
- **Account full names as strings** (ch.5's `coa` row says "full names"). Rejected: the
  separator is a user preference outside the book (`.` headless, often `:` on a
  desktop), so a string path means different things on different machines (#22
  maintainer comment).
- **Module-scope imports in tests.** Rejected because they make C4-verify report
  "unverifiable" on a greenfield patch (Falsifiability above).
- **The staging store inside `autobook.pipeline`** (an earlier draft of this brief).
  Rejected at plan review: ch.5 §5.1 lists the Staging store as its own block
  (`05-building-block-view.md:22`), and the book process uses it too (Read-back records
  `applied` in staging; Undo reads staging's GUIDs). Placing it under the pipeline would
  hide that the book process depends on it, so it is the top-level `autobook.staging`.
- **Signed `amount_cents` without a `sign` field.** Not chosen: ch.5 lists both, and
  the kNN index is keyed by `(source_account, sign)`.

## Impact & compatibility

New code only. Behaviour of `import autobook` does not change. No new runtime
dependency. The C4-verify red leg is fully local (no Docker). Expect the advisory
`T2-threat-model` check to land in SUMMARY §6, because the new paths match its
security-relevant patterns (`src/autobook/book/*`, `*corpus*`, `*staging*` and others).
The modules carry no behaviour, so no threat-model change is expected. That is a
sign-off call, and Do does not edit `.oss-scanner/threat_model.md`.

## Open questions

None open. Settled with the maintainer (eduralph, the issue author) in the Plan session:
drop the XML book; use package names `autobook.contracts` / `autobook.pipeline` /
`autobook.book`; `coa.json` mirrors `synthetic_book.ACCOUNTS` with component-list paths.
These decisions are not yet on the issue thread (`notes.json` has only the separator
comment). The PR description must state them, naming the XML book as dropped from #22's
scope and why, so the tracker record matches what ships.

## STOP discipline

Draft only until Check sign-off. Pushing to a feature/draft branch and opening a
draft PR MAY happen during the cycle (useful for CI feedback). The PR MUST NOT be
marked ready before sign-off accepts.

Plan-review response: revised for findings 2 (`*.pdf` placed in the financial-data block above `.gitignore:53-54`), 3 (fixed entry-point convention: one-name `__all__`, no required parameters), 5 (`amount_cents` strictly positive) and 6 (staging moved to a top-level `autobook.staging`, since ch.5 lists it as its own block and the book process's read-back and undo use it; pipeline count is now 11; this changes the approved layout slightly, so the human should confirm it). Finding 4: the brief stands with the in-process check; the C4 host has no importable `gnucash` (verified at Plan), the assumption is now stated, and it matches `tests/test_smoke.py`. Finding 1: the decisions were made with the maintainer in the Plan session and are not on the issue thread; the brief now requires the PR description to record them. The human should confirm them at sign-off or comment on #22.

## Iteration 1 — carry-forward (from the previous attempt)
- Sign-off rationale: Keep the design and scope; fix the three adversarial findings, each with a test: 1. tests/test_skeleton.py staging test can never fail (it checks a string its own helper added). Assert importlib.util.find_spec("autobook.staging") is not None (or import it) and importlib.util.find_spec("autobook.pipeline.staging") is None, so it goes red when the change is reverted. 2. contracts.py serialisers validate nothing: a str account path (e.g. "Aktiva") is written as ["A","k","t","i","v","a"] and the parser accepts it. Validate on construction (__post_init__ with the same cents/path/sign checks, rejecting a str path) or round-trip serialise output through parse before returning. Add a test that a str path is rejected. 3. coa account `type` accepts any non-empty string. Restrict it to GnuCash's closed account-type set (NONE, BANK, CASH, CREDIT, ASSET, LIABILITY, STOCK, MUTUAL, CURRENCY, INCOME, EXPENSE, EQUITY, RECEIVABLE, PAYABLE, ROOT, TRADING, CHECKING, SAVINGS, MONEYMRKT, CREDITLINE), exact case; add a test rejecting e.g. "equity" and "EQUITYY".
- Sign-off session carry-forward (captured live, before §9 flattened it):
  Keep the design and scope; fix the three adversarial findings, each with a test:
  1. tests/test_skeleton.py staging test can never fail (it checks a string its own helper added). Assert importlib.util.find_spec("autobook.staging") is not None (or import it) and importlib.util.find_spec("autobook.pipeline.staging") is None, so it goes red when the change is reverted.
  2. contracts.py serialisers validate nothing: a str account path (e.g. "Aktiva") is written as ["A","k","t","i","v","a"] and the parser accepts it. Validate on construction (__post_init__ with the same cents/path/sign checks, rejecting a str path) or round-trip serialise output through parse before returning. Add a test that a str path is rejected.
  3. coa account `type` accepts any non-empty string. Restrict it to GnuCash's closed account-type set (NONE, BANK, CASH, CREDIT, ASSET, LIABILITY, STOCK, MUTUAL, CURRENCY, INCOME, EXPENSE, EQUITY, RECEIVABLE, PAYABLE, ROOT, TRADING, CHECKING, SAVINGS, MONEYMRKT, CREDITLINE), exact case; add a test rejecting e.g. "equity" and "EQUITYY".
- Full previous attempt preserved in `iteration-v1/` (patch.diff, build-notes.md, SUMMARY.md, check-*).
- Address the above; do NOT re-attempt the rejected approach unchanged. Satisfy the brief's Success criterion (the end result).

## Iteration 2 — carry-forward (from the previous attempt)
- Sign-off rationale: Keep the design, scope and everything else in the patch unchanged; fix only the one remaining adversarial finding, with a test: 1. src/autobook/contracts.py:178 — the coa account `type` closed-set check (`self.type not in ACCOUNT_TYPES`) hashes the value before checking it is a string, so a JSON array/object `type` (e.g. ["BANK"], {}, {"x": 1}) raises TypeError instead of ContractError, through both parse_coa and coa_from_json and on direct construction. Validate with `_text(self.type, "type")` before the membership test so every malformed type raises ContractError. 2. Add ["BANK"] and {} (array and object) cases to the non-string `type` parametrize list in tests/test_contracts.py (~:324), covering parsing (document and JSON text) and direct construction. Do not re-open the size question: the 31 files are mostly 18 one-pattern stubs; the slice stays as one.
- Sign-off session carry-forward (captured live, before §9 flattened it):
  Keep the design, scope and everything else in the patch unchanged; fix only the one remaining adversarial finding, with a test:
  1. src/autobook/contracts.py:178 — the coa account `type` closed-set check (`self.type not in ACCOUNT_TYPES`) hashes the value before checking it is a string, so a JSON array/object `type` (e.g. ["BANK"], {}, {"x": 1}) raises TypeError instead of ContractError, through both parse_coa and coa_from_json and on direct construction. Validate with `_text(self.type, "type")` before the membership test so every malformed type raises ContractError.
  2. Add ["BANK"] and {} (array and object) cases to the non-string `type` parametrize list in tests/test_contracts.py (~:324), covering parsing (document and JSON text) and direct construction.
  Do not re-open the size question: the 31 files are mostly 18 one-pattern stubs; the slice stays as one.
- Full previous attempt preserved in `iteration-v2/` (patch.diff, build-notes.md, SUMMARY.md, check-*).
- Address the above; do NOT re-attempt the rejected approach unchanged. Satisfy the brief's Success criterion (the end result).
