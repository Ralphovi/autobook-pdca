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
