# Build notes — issue 22, package skeleton + contracts + fixtures

All paths are in the worktree (`$PDCA_WORKTREE`, base `bd9a438`, `main`).

## What was built

| Change | Where |
|--------|-------|
| Versioned `corpus` and `coa` contracts, parse + serialise (dict and JSON text), one `ContractError(ValueError)` | `src/autobook/contracts.py` |
| 11 pipeline stubs + package `__init__` | `src/autobook/pipeline/*.py` |
| 6 book-process stubs + package `__init__` | `src/autobook/book/*.py` |
| Top-level staging stub | `src/autobook/staging.py` |
| Seeded corpus builder, `coa.json`, README, `__init__` files | `tests/fixtures/synthetic/`, `tests/fixtures/__init__.py` |
| Tests | `tests/test_contracts.py` (binding), `tests/test_skeleton.py`, `tests/test_synthetic_fixtures.py` |
| `*.pdf` in the financial-data block, after `*.camt*.xml`, above the un-ignore lines | `.gitignore:42` |
| Layout + wire shape recorded, `[OPEN]` note removed, `coa` row says "paths (component lists)" | `docs/design/architecture/05-building-block-view.md` (header note, "Package layout", "The JSON contracts") |

`autobook/__init__.py` is untouched (`src/autobook/__init__.py:17-21`), so `import autobook` stays light and
`tests/test_smoke.py` passes unchanged.

## Choices the brief left to Do

- **Contract objects work on decoded dicts**, with thin `*_from_json` / `*_to_json` wrappers. Both
  directions exist and round-trip. Dicts are what the book process will build; the text wrappers
  cover the real wire.
- **Sign representation:** `"out"` / `"in"`, direction of the money relative to `source_account`.
  `amount_cents` is the magnitude. Chosen over `debit`/`credit` because those words flip meaning
  between asset and liability accounts. Documented in ch.5 §5.1.
- **Frozen dataclasses with tuples** for paths and rows, so objects are hashable and `==` compares
  by value.
- **Version check uses `type(x) is int`**, not `isinstance`: `True == 1` and `1.0 == 1` would
  otherwise pass as version 1. Same for money and `fraction`.
- **Dates:** a regex (`[0-9]{4}-[0-9]{2}-[0-9]{2}`) runs before `date.fromisoformat`, because on
  Python 3.11+ `fromisoformat` also accepts `20260102` and `2026-W01-5`, which would break
  "serialise a parsed canonical document gives back the same document".
- **`type` in `coa` is any non-empty string**, not a closed set. The brief names GnuCash's type
  names only as examples; a closed list copied from memory could reject a valid account type.
  The closed sets the brief does list (`sign`, `provenance`) are enforced.
- **Stub entry points:** `read_statements`, `admit_statement`, `normalise`, `correlate_transfers`,
  `match_bills`, `classify`, `ask_model`, `disposition_rows`, `check_batch`, `write_review_file`,
  `run_trial`; book: `open_session`, `export_book`, `apply_rows`, `read_back`, `check_assertions`,
  `undo_batch`; `staging.open_store`. All `() -> None`, `raise NotImplementedError`.
- **Builder** keeps regular rows on days 1–27 and puts the novel merchant on day 28 of the last
  month, so its date is unique and strictly the latest by construction, not by luck of the seed.
  The last month also has ordinary rows, so a rolling-origin backtest has an index to test against.
  Module name `corpus_builder.py` does not match `test_*.py`.
- `coa.json` was written by hand in `synthetic_book.ACCOUNTS` order; the test asserts the order,
  types and that `serialise(parse(doc)) == doc`.

## Self-refutation (the three required answers)

**(a) Genuine red?** Yes. I put the base `src/` (`git archive HEAD src`) first on `PYTHONPATH`
and ran the three test files with the same marker expression the gate uses
(`-m "not applier and not live_paperless"`): **93 ran, 93 failed, 0 collection errors**
(`ModuleNotFoundError: autobook.contracts` / `autobook.pipeline` raised inside the test call).
With the patch: **95 passed, 1 skipped** over the whole suite (the skip is the existing
`tests/book/test_testenv_book.py:20` collection skip, not one of mine; 7 deselected by marker).
The base `src/` holds only `__init__.py`, which is what the gate's red leg leaves after reverting `src/autobook/**`.

**(b) Production path?** Yes. Every test calls the real `autobook.contracts` and the real stub
modules through `importlib.import_module`; nothing is mocked. The fixture tests run the real
builder and feed its output through the real `parse_corpus` / `parse_coa`.

**(c) Fixture includes the fault?** Yes. The rejection tests feed the actual bad value (`12.5`,
`True`, `1.0` version, `"Aktiva:Girokonto"` as a path, `"corrected"`) into a canonical document that
otherwise parses, so a failure can only come from that field. Each parametrized negative case
mutates a document that the positive tests prove is accepted. The novel-merchant test checks
the row count, the date, and that the date is not shared, for three seeds.

## Gate-adjacent checks run

Run with ruff 0.14.2 and mypy 1.18.2 (the pins in `noxfile.py:45-46`) from a throwaway venv under
`.mypy_cache/` in the worktree (gitignored):

- `ruff format --check src tests` → clean; `ruff check src tests` → clean.
- `mypy` (strict, `MYPYPATH=src`) → no issues in 35 files.
- `typos` → clean, no `typos.toml` change needed.
- `python3 docs/tools/lint_docs.py` → OK.
- `grep -w applier|live_paperless` over the three test files → no match, so the gate will not start Docker.
- I did not run `nox -s gate` itself; I ran its parts (fmt, lint, types, test, typos, docs) separately.

## Things I noticed and left alone

- **`.gitignore` un-ignore re-includes `__pycache__` under `tests/fixtures/synthetic/`.** The
  `!tests/fixtures/synthetic/**` line (`.gitignore:54-55`, last match wins) overrides the earlier
  `__pycache__/` and `*.py[cod]` entries, so running pytest there leaves untracked `.pyc` files that
  `git add -A` would stage (it happened to me; I removed them from the index and from the patch).
  The brief limits the `.gitignore` change to `*.pdf`, so I did not touch the un-ignore block. A
  follow-up could add `tests/fixtures/synthetic/**/__pycache__/` and `*.py[cod]` below it. Not raised as an
  issue from here; the human can decide.
- **`*.pdf` is now ignored for the whole repo**, including `docs/`. `git ls-files '*.pdf'` on the base
  shows none tracked, so nothing existing is affected. Synthetic PDFs under
  `tests/fixtures/synthetic/` stay un-ignored because the new line sits above the un-ignore.
- **`autobook/__init__.py` docstring still says "There is no implementation yet."** Still true
  for behaviour; left unchanged to keep `import autobook` and that file out of this diff.
- **Threat model:** the new paths match the `T2-threat-model` patterns; the modules hold no behaviour,
  and I did not edit `.oss-scanner/threat_model.md`. Sign-off call, per the brief.
- **PR description must record the Plan-session decisions** (XML book dropped from #22's scope
  because `tests/book/synthetic_book.py` builds books at test time and a hand-written file could
  only be checked in Docker; package names; `coa.json` mirrors `ACCOUNTS`). Not done here: I do not open PRs.

## Alternatives rejected

- **Signed `amount_cents`, no `sign` field.** Brief rules it out; the kNN index key needs `sign`.
- **Closed set for `coa.type`.** See above; it would add one tuple of about 20 names that I cannot check
  against a GnuCash install here, and the brief does not list one.
- **A `pytest` fixture that imports the module.** A failing fixture import is a setup *error*, not a
  failed test, and the gate counts those separately. Plain helper functions called from the test body
  give a real failure.

No external dependency was missing; no NEEDS-HUMAN item from this build.
