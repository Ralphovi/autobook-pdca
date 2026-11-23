# Build notes — issue 22, iteration 3 (package skeleton + contracts + fixtures)

All paths are in the worktree (`$PDCA_WORKTREE`, base `bd9a438`, `main`). Line numbers are
for the patched tree.

## Starting point

I applied `iteration-v2/patch.diff` unchanged (`git apply --check` clean), then fixed only the
one sign-off finding in the iteration 2 carry-forward. Design, scope, layout, stubs, fixtures,
docs and `.gitignore` are exactly as in iteration 2; see `iteration-v2/build-notes.md` and
`iteration-v1/build-notes.md` for those choices. `diff iteration-v2/patch.diff patch.diff`
shows only the two hunks below (plus blob hashes and hunk lengths).

## The finding and the fix

The finding: `CoaAccount.__post_init__` ran `self.type not in ACCOUNT_TYPES` before checking
that `type` is a string. `ACCOUNT_TYPES` is a `frozenset`, so the lookup hashes the value, and a
JSON array or object (`["BANK"]`, `{}`, `{"x": 1}`) raised `TypeError` instead of
`ContractError`, through `parse_coa`, `coa_from_json` and direct construction.

Fix, `src/autobook/contracts.py:178-181`: the check is now
`if _text(self.type, "type") not in ACCOUNT_TYPES:`. `_text` (`contracts.py:227`) raises
`ContractError("type: expected a string, got list")` for any non-string, so the set lookup only
ever sees a `str`. This is the change the sign-off asked for, word for word. A two-line comment
says why the order matters.

I checked the other closed-set and equality checks for the same fault:

- `sign` (`contracts.py:134`): `self.sign not in _SIGNS`, where `_SIGNS` is a **tuple**. Tuple
  membership compares with `==` and never hashes, so a list or dict gives `False` and then
  `ContractError`. No change needed.
- `provenance` (`:141`), `contract` name (`:218`) and `version` (`:222`) use `!=` or
  `type(...) is int`, which never hash.
- `_mapping` (`:203`) calls `set(value)` only after `isinstance(value, dict)`, and dict keys are
  always hashable.

So `type` was the only place an unhashable value reached a hash. The sign-off said to change
nothing else, so I did not add list/dict cases to the `sign` test.

## Test changes (`tests/test_contracts.py`, the binding test)

- `:324-337` the bad-type list is now a shared constant `BAD_ACCOUNT_TYPES`, with the old seven
  values plus `["BANK"]`, `{}` and `{"x": 1}`.
- `:340` `test_coa_rejects_an_account_type_outside_gnucash_set` — parses a decoded document
  (the existing test, now on the shared list).
- `:347` `test_coa_json_text_rejects_an_account_type_outside_gnucash_set` — new; goes through
  `coa_from_json(json.dumps(...))`.
- `:357` `test_coa_account_rejects_a_type_outside_gnucash_set_on_construction` — new; builds
  `CoaAccount(type=...)` directly through the existing `_coa_account` helper (`:381`).

That covers all three paths the sign-off named: document, JSON text, construction.

## Self-refutation (the three required answers)

**(a) Genuine red?** Yes, at two levels.

1. Only this finding's fix reverted: I put back `if self.type not in ACCOUNT_TYPES:` at
   `contracts.py:180` and ran
   `PDCA_WORKTREE=… ./engine/nox.sh test-3.14 -- tests/test_contracts.py -q -k "account_type or type_outside"`:
   **9 failed, 41 passed**. The 9 failures are exactly the three unhashable values times the
   three paths, each with `TypeError: cannot use 'dict' as a set element (unhashable type:
   'dict')` (or `list`) at `contracts.py:180`. The 41 that passed are the 20 valid types and the
   7 old bad values times 3 paths, which iteration 2 already refused. Then I restored the fix.
2. Whole patch reverted, through the C4 gate
   (`PDCA_BUNDLE=… PDCA_WORKTREE=… ./engine/scripts/run-verify.sh`):
   `PDCA-EVIDENCE: C4 PASS — red without the fix (177 of 177 failed), green with it`
   (ran 177, failed 177, setup errors 0, import/collection errors 0).

**(b) Production path?** Yes. The tests call the real `autobook.contracts.parse_coa`,
`coa_from_json` and `CoaAccount` loaded with `importlib.import_module`. Nothing is mocked.

**(c) Fixture includes the fault?** Yes. The new cases are the exact values the sign-off named
(`["BANK"]`, `{}`) plus `{"x": 1}` from the finding text, fed in the shape that triggered it: a
JSON array/object in the `type` field of a `coa` document, in JSON text, and as a constructor
argument.

## Gate and commit readiness

- `PDCA_WORKTREE=… ./engine/nox.sh gate` (Autobook's `nox -s gate`): fmt, lint, types (mypy
  strict), test (**179 passed, 1 skipped, 7 deselected**; the skip is the existing
  `tests/book/test_testenv_book.py:20` gnucash skip), typos, docs, all green.
- The first gate run failed fmt and lint on one line: my single-line `BAD_ACCOUNT_TYPES` was 97
  characters, over the 96 limit (`E501`). I wrote it one value per line, as `ruff format`
  wants, and the next run was all green.
- The target has no pre-commit hooks (same as iterations 1 and 2), so the gate's `ruff format`
  / `ruff check` are what a commit has to pass.
- `applier` / `live_paperless` still do not appear in any test file, so the gate does not start
  Docker.
- `patch.diff` is `git diff` of the worktree with new files added intent-to-add, excluding
  `tests/fixtures/synthetic/__pycache__/*.pyc` (visible to git because of the `.gitignore`
  un-ignore line; noted since iteration 1, out of this brief's scope). After the verify run I
  re-made the diff from the worktree and `cmp` matched `patch.diff`; the bundle's
  `test_contracts.py` also matches the worktree file.

## Things left alone

Everything else from iteration 2's notes still applies: fraction checked as a positive int, not
`== 100` (the 100 check belongs on the write path, #35/#37); the account-type list is the one the
human gave at sign-off and has not been checked against a live GnuCash build (#26's exporter test
is where a mismatch would show); `.pyc` under the un-ignored fixture folder; threat model is a
sign-off call; and the PR description must record the Plan-session decisions (XML book dropped
from #22 because `tests/book/synthetic_book.py` builds books at test time; package names;
`coa.json` mirrors `ACCOUNTS`).

No external dependency was missing; no NEEDS-HUMAN item from this build.
