# Build notes — issue 22, iteration 2 (package skeleton + contracts + fixtures)

All paths are in the worktree (`$PDCA_WORKTREE`, base `bd9a438`, `main`). Line numbers are
for the patched tree.

## Starting point

I applied `iteration-v1/patch.diff` unchanged, then fixed the three sign-off findings from the
carry-forward block. The design, scope, layout, stub names, fixtures and `.gitignore` change
(`*.pdf` at `.gitignore:42`, above the un-ignore lines) are as in iteration 1; see
`iteration-v1/build-notes.md` for those choices. Only the three fixes and their tests are new.

## The three findings and what changed

### 1. The staging test could never fail

Before: `tests/test_skeleton.py` checked `"autobook.staging" in _all_building_blocks()`, but that
helper puts the string `"autobook.staging"` in its own list, so the first assertion always held.

Now (`tests/test_skeleton.py:37-40`) the test asks the import system:
`importlib.util.find_spec("autobook.staging") is not None` and
`importlib.util.find_spec("autobook.pipeline.staging") is None`. `import importlib.util` was
added at `tests/test_skeleton.py:10`. This is the fix the sign-off asked for, word for word.

### 2. Serialisers validated nothing (a str path became one component per character)

Before: only `parse_*` checked values. `CorpusRow(source_account="Aktiva")` built fine and
`serialise_corpus` wrote `["A","k","t","i","v","a"]`, which `parse_corpus` then accepted.

Now every contract dataclass checks its own fields in `__post_init__`
(`src/autobook/contracts.py:131` `CorpusRow`, `:152` `CorpusContract`, `:161` `Commodity`,
`:176` `CoaAccount`, `:190` `CoaContract`). So an object that exists is one `serialise_*` may
write. The checks:

- paths must be a non-empty **tuple** of non-empty strings (`_path`, `contracts.py:248`). A
  `str` is refused (that is the finding), and so is a `list`, so frozen objects stay hashable;
- `amount_cents` / `fraction` via the same `type(x) is int` check as before (`_cents`);
- `sign`, `provenance`, `raw_memo`, `placeholder` (`type is bool`), `commodity`
  (`type is Commodity`);
- `post_date` must be exactly `datetime.date`. A `datetime.datetime` is a subclass and would
  serialise as `2026-03-09T12:00:00`, which `parse_corpus` refuses;
- `rows` / `accounts` must be a tuple of the right object type (`_items`, `contracts.py:257`).

`parse_corpus` / `parse_coa` (`contracts.py:310`, `:368`) now only convert JSON shapes (array to
tuple via `_components`, `:265`; string to date via `_date`) and build the objects through
`_build` (`contracts.py:272`), which adds the document location to the error
(`corpus.rows[3].amount_cents: must be at least 1`). The value rules live in one place, the
dataclasses, so parse and construction cannot drift apart.

I chose construction-time checks over the other option the sign-off offered (run the serialised
output back through `parse_*` before returning it). Comparison:

- *Round-trip in serialise*: about 2 lines per serialiser. But a bad object can still exist and
  be passed around, compared, or put in a set, and the error only shows up at write time, far
  from the code that built it. It also doubles the work of every serialise.
- *`__post_init__` (chosen)*: about 45 added lines in the dataclasses, and parse lost about 30
  lines of duplicated checks. The error appears where the bad object is built. This also covers
  the corpus builder in `tests/fixtures/synthetic/corpus_builder.py`, which builds `CorpusRow`
  objects directly.

The invariant in the brief ("money only as integer cents, accounts only as path components")
is about what crosses the boundary, so a writer that can emit a bad document breaks it. The
construction check closes that at the source.

### 3. coa `type` accepted any non-empty string

Now `ACCOUNT_TYPES` (`contracts.py:84`, exported in `__all__`) is the closed set the sign-off
listed: `NONE, BANK, CASH, CREDIT, ASSET, LIABILITY, STOCK, MUTUAL, CURRENCY, INCOME, EXPENSE,
EQUITY, RECEIVABLE, PAYABLE, ROOT, TRADING, CHECKING, SAVINGS, MONEYMRKT, CREDITLINE`, exact
case. `CoaAccount.__post_init__` refuses anything else. In iteration 1 I declined a closed set
because I could not check the list against a GnuCash install here; the human has now supplied
the list at sign-off, so I used it as given. I still have not checked it against a live
GnuCash build. #26's exporter test against `synthetic_book.py` is where a mismatch would show.

### Docs

`docs/design/architecture/05-building-block-view.md:67-70` now says the checks also run when an
object is built (with the str-path reason), and `:77-81` lists the account-type set for `coa`.
The module docstring of `contracts.py` says the same.

## Tests added (all in `tests/test_contracts.py`, the binding test)

- `:319` every one of the 20 types is accepted; `:325` `"equity"`, `"Equity"`, `"EQUITYY"`,
  `""`, `" BANK"`, `1`, `None` are refused by `parse_coa`.
- `:360` the helper objects used below are valid (so each negative case fails only on the one
  field it changes).
- `:371` / `:380` `CorpusRow` and `CoaAccount` refuse a `str` path (`"Aktiva"`,
  `"Aktiva:Girokonto"`), a list, an empty tuple, and an empty component.
- `:398` / `:414` / `:419` construction refuses float/bool/zero money, bad sign, `corrected`,
  string or `datetime` date, non-str memo, bad type, non-bool placeholder, tuple-not-Commodity,
  empty mnemonic.
- `:434` `CorpusContract` / `CoaContract` refuse a list instead of a tuple, and items of the
  wrong type.

## Self-refutation (the three required answers)

**(a) Genuine red?** Yes, at two levels.

1. Whole fix reverted, through the project's own C4 gate
   (`PDCA_BUNDLE=… PDCA_WORKTREE=… ./engine/scripts/run-verify.sh`): green leg passed, red leg
   **154 ran, 154 failed, 0 collection errors** (`ModuleNotFoundError: autobook.contracts`
   inside the test call). Output: `PDCA-EVIDENCE: C4 PASS — red without the fix (154 of 154 failed), green with it`.
2. Each finding against **iteration 1's code** (the thing the sign-off rejected), run through
   `./engine/nox.sh test-3.14 -- …`:
   - Finding 2 + 3: I put iteration 1's `contracts.py` back and ran the new
     `tests/test_contracts.py`: **37 failed, 106 passed**. Every str-path, construction and
     account-type case failed (`"equity"`, `"Equity"`, `"EQUITYY"`, `" BANK"` among them). The
     three type cases that passed (`""`, `1`, `None`) were already refused in iteration 1.
     Then I restored the new file (`cmp` identical).
   - Finding 1: I moved `staging.py` to `pipeline/staging.py` (the exact fault):
     the staging test failed on `find_spec("autobook.staging") is not None`. Then I put
     staging at the top level **and** a copy under `pipeline/`: only the staging test failed,
     on `find_spec("autobook.pipeline.staging") is None`. Iteration 1's test would have passed
     its first assertion in both cases. Tree restored afterwards; the stray copy was moved to
     the ignored `.nox/` folder, not left in `src/`.

**(b) Production path?** Yes. Every test calls the real `autobook.contracts` objects and parse
functions through `importlib.import_module`; the staging test asks the real import system about
the real package. Nothing is mocked.

**(c) Fixture includes the fault?** Yes. The str-path tests feed the exact value from the
finding (`"Aktiva"`); the type tests feed the exact values the sign-off named (`"equity"`,
`"EQUITYY"`); the staging test was run against the misplaced-module layout itself.

## Gate and commit readiness

- `PDCA_WORKTREE=… ./engine/nox.sh gate` (Autobook's `nox -s gate`): fmt, lint, types (mypy
  strict), test (**156 passed, 1 skipped, 7 deselected**; the skip is the existing
  `tests/book/test_testenv_book.py:20` gnucash skip), typos, docs, all green.
- The first gate run caught an import-order issue in `contracts.py` and a mypy
  `no-untyped-call` in a lambda loop in the new test; both fixed before the run above.
- The target has no pre-commit hooks (no config file, no hooks in the git dir), so the gate's
  `ruff format` / `ruff check` are what a commit has to pass.
- `grep -w 'applier|live_paperless'` over the three test files: no match, so the gate does not
  start Docker.
- `patch.diff` = `git diff` of the worktree with new files added intent-to-add; checked with
  `cmp` after the experiments above. It excludes `tests/fixtures/synthetic/__pycache__/*.pyc`,
  which the `.gitignore` un-ignore line makes visible to git (noted in iteration 1, still true,
  still out of this brief's scope).

## Things left alone

- Fraction is checked to be a positive int, not `== 100`. The rubric's "commodity whose
  fraction is not checked to be 100" is a check for the applier's write path (#35/#37); the
  `coa` contract has to describe accounts truthfully, including non-cent commodities.
- The other notes from iteration 1 still apply (`.pyc` under the un-ignored fixture folder,
  `*.pdf` repo-wide, `autobook/__init__.py` docstring, threat model as a sign-off call, and the
  PR description must record the Plan-session decisions: XML book dropped from #22 because
  `tests/book/synthetic_book.py` builds books at test time; package names; `coa.json` mirrors
  `ACCOUNTS`).

No external dependency was missing; no NEEDS-HUMAN item from this build.
