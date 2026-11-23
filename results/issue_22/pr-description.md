## Summary
**User impact:** Nothing changes yet for anyone running Autobook, because the
booking steps do not exist yet. This PR lays the groundwork they will run on,
and puts two promises in place before any of them can break them: money moves
between Autobook's parts only as whole cents, and an account is always named by
its parts ("Aktiva", "Girokonto"). It is never a single joined string that a
GnuCash setup with a different account separator (`.` or `:`) would read
differently.

This PR adds the code layout from architecture chapter 5 (one empty module per
building block), the versioned `corpus` and `coa` data formats that pass between
the pipeline and the book process, and invented test data for the steps that
follow.

Reported in [#22](https://github.com/Ralphovi/autobook/issues/22).

### Scope decisions made with the maintainer while planning
These were agreed in the planning session and are not on the issue thread yet,
so they are recorded here:

- **The hand-written synthetic XML book is dropped from #22.**
  `tests/book/synthetic_book.py` (from #48) builds XML and PostgreSQL books
  through the GnuCash bindings at test time. A hand-written file could only be
  checked inside Docker. #26 (exporter) will use that builder.
- **Package names:** `autobook.contracts`, `autobook.pipeline`, `autobook.book`.
  The staging store is its own top-level `autobook.staging`, not part of the
  pipeline, because chapter 5 lists it as its own block and the book process
  uses it too (read-back records `applied`, undo reads the transaction IDs).
- **`coa.json` mirrors `ACCOUNTS` in `tests/book/synthetic_book.py`** (same 8
  accounts, types and order), with paths as component lists.
- The `live_paperless` marker and its deselection in `nox -s gate`, also listed
  in #22, are already on `main` from #48.

## What to look at
- **The contracts module** is the one part with real logic. It is the interface
  every later step (#23–#26, #35, #37) builds on, so its shape is worth a full
  read against chapter 5 §5.1 and AGENTS.md.
- **The chapter 5 update** writes down the layout and the data format.
- The 18 building-block modules are one-pattern stubs, so a skim is enough.
- To try it: `pytest tests/test_contracts.py tests/test_skeleton.py
  tests/test_synthetic_fixtures.py` runs on the host with no GnuCash and no
  Docker. `nox -s gate` is green.

## Root cause
`src/autobook/` held only `__init__.py`, so every build-step-2 change would have
been all new code. Its tests would import modules that the same change adds, so
nothing could fail before the change and pass after it.

## Fix
- **Layout** (`src/autobook/`): `pipeline/` has 11 modules (`statement_source`,
  `admission`, `normaliser`, `correlator`, `bill_matcher`, `classifier`,
  `model_adapter`, `disposition`, `batch_gate`, `review_file`, `trial`).
  `book/` has 6 (`session`, `exporter`, `applier`, `readback`, `assertions`,
  `undo`), plus the top-level `staging.py`. Each sets `__all__` to its one
  entry point, which takes no arguments and raises `NotImplementedError`. No
  module imports `gnucash`, and `autobook/__init__.py` does not import the
  subpackages.
- **`autobook.contracts`** (standard library only): frozen dataclasses
  `CorpusRow`/`CorpusContract` and `CoaAccount`/`Commodity`/`CoaContract`, with
  `parse_*`/`serialise_*` on decoded dicts and `*_to_json`/`*_from_json` on
  text. Every document is `{"contract", "version", …}` with version `1`. Every
  rejection raises `ContractError`, a `ValueError` subclass. The rules are:
  - money is `type(x) is int`, so a float or bool is refused. `amount_cents` and
    `fraction` must be greater than zero.
  - `sign` is `"out"`/`"in"`, relative to `source_account`.
  - `provenance` must be `"observed"`.
  - `post_date` is `YYYY-MM-DD`.
  - a path is a non-empty list of non-empty strings, and a bare string is
    refused.
  - `type` is one of GnuCash's 20 account-type names, exact case. It is checked
    as a string first, so a JSON array or object gives `ContractError`, not
    `TypeError`.
  - missing or unknown fields are refused.

  The checks run in `__post_init__`, so a serialiser can only write documents a
  parser accepts. Nothing joins or splits a path on a separator.
- **Fixtures** (`tests/fixtures/synthetic/`): `README.md` (synthetic-only
  rule), `corpus_builder.py`, which uses a local `random.Random(seed)` with
  invented merchants, near-duplicate memos and exactly one novel merchant on the
  latest date, and `coa.json`.
- **`.gitignore`**: `*.pdf` goes in the financial-data block, above the
  `!tests/fixtures/synthetic/` un-ignore, because in `.gitignore` the last
  matching rule wins.
- **Docs**: chapter 5 replaces the "names are provisional `[OPEN]`" note with
  the layout and records the wire shape in §5.1. The `coa` row now says "paths
  (component lists)" instead of "full names".

## Verification
Line numbers are for the branch with this PR applied. Base is `main` @
`bd9a43898b393dfdd95a576fa360142c9a8c7c78`.

- **Claim:** both contracts round-trip (object → document → object, and
  canonical document → object → same document).
  **Checked:** `src/autobook/contracts.py:312-363` (corpus), `:370-426` (coa).
  **Test:** `tests/test_contracts.py:103-151`.
- **Claim:** an unknown contract name or version is rejected with
  `ContractError`.
  **Checked:** `src/autobook/contracts.py:216-225` (`_header`).
  **Test:** `tests/test_contracts.py:164-196`.
- **Claim:** money is only a plain int. `12.5`, `True`, `0` and negatives are
  refused for `amount_cents` and `fraction`.
  **Checked:** `src/autobook/contracts.py:235-242` (`_cents`).
  **Test:** `tests/test_contracts.py:203-214`.
- **Claim:** accounts are component lists, and a bare string such as `"Aktiva"`
  is refused rather than split into letters.
  **Checked:** `src/autobook/contracts.py:250-272`.
  **Test:** `tests/test_contracts.py:151`, `:224-238`, `:405-420`.
- **Claim:** the account `type` is GnuCash's closed set. `"equity"`,
  `"EQUITYY"`, `["BANK"]` and `{}` all give `ContractError` through a dict, JSON
  text and direct construction.
  **Checked:** `src/autobook/contracts.py:82-107`, `:176-187`.
  **Test:** `tests/test_contracts.py:319-363`.
- **Claim:** a writer cannot produce a document a reader would refuse.
  **Checked:** the `__post_init__` checks at `src/autobook/contracts.py:131-194`.
  **Test:** `tests/test_contracts.py:394-474`.
- **Claim:** there is one stub per block, staging is top-level, and nothing
  imports `gnucash`.
  **Checked:** `src/autobook/{pipeline,book}/*.py`, `src/autobook/staging.py`.
  **Test:** `tests/test_skeleton.py:33-60`. The `gnucash` check works the same
  way as `tests/test_smoke.py:21`.
- **Claim:** the fixtures are deterministic per seed, have near-duplicates and
  one novel merchant on the latest date, and `coa.json` is a valid `coa`
  document for the synthetic book's tree.
  **Test:** `tests/test_synthetic_fixtures.py:27-101`.
- **Claim:** synthetic PDFs stay committable and other PDFs are ignored.
  **Checked:** `.gitignore:42` (`*.pdf`), above the un-ignore lines that follow.
- **Before and after:** with all of `src/autobook/**` reverted, the 177 tests in
  `tests/test_contracts.py` all run and fail (`ModuleNotFoundError`, no
  collection errors). With the change, all 177 pass. A targeted check on the
  `type` fix put the old membership test back: 9 tests failed with `TypeError`,
  and they pass with the fix. Full `nox -s gate` (fmt, lint, mypy strict, tests,
  typos, docs) is green: 179 passed, 1 skipped (the existing gnucash-only test
  in `tests/book/test_testenv_book.py:20`).

### Not in this PR
- The `existing`, `apply-in` and `apply-out` contracts (#35, #37), and any real
  behaviour in a building block (#23–#26).
- `.oss-scanner/threat_model.md` is unchanged. The new paths match its
  security-relevant patterns, but the stubs add no input or trust boundary, and
  the contracts read only the user's own book, which the threat model treats as
  trusted.
- Some rejection messages repeat the rejected value (for example a bad `sign`).
  The input comes from the user's own book, so this is not a leak today. The
  writers of later contracts (#35, #37) should report a type or length instead
  of the value.

Fixes #22
