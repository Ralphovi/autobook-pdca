# build-notes — issue 23 / normaliser-profiles-version

Target: Ralphovi/autobook @ main (76bacce). All paths are in that tree.

## What changed

- `src/autobook/pipeline/normaliser.py` — the stub (one `normalise()` raising
  `NotImplementedError`, old lines 1-15) is replaced by the API in the brief:
  `NORMALISER_VERSION`, `NormaliserError(ValueError)` (mirrors `ContractError`,
  `src/autobook/contracts.py:110`), `NormalisedMemo`, `Normaliser`, `load`.
- `src/autobook/pipeline/profiles/default.toml`, `sepa.toml` — new package data, no
  `__init__.py`, so `pkgutil` does not count them as a block. Read through
  `importlib.resources.files("autobook.pipeline") / "profiles"`.
- `tests/test_skeleton.py:17-22,47-50` — `IMPLEMENTED` set; those modules skip all three
  stub assertions, every other skeleton check still covers them.
- `tests/test_normaliser.py` — 37 tests (criteria a–d plus errors, XDG, whitespace/case).
- Docs: ch.5 §5.2 *Normaliser* (API, format, package profiles, override, version) and
  ch.8 §8.8 (the `normaliser/` directory).

## Decisions

- **Version** = `"<NORMALISER_VERSION>-<12 hex>"` of SHA-256 over canonical JSON of
  `{"profiles": [[name, [patterns...]]...], "accounts": [[path, profile]...]}`, both sorted.
  Only profile name, rules in order, and account path/profile enter it. No directory,
  file name, mtime. `ensure_ascii=True` so the digest does not depend on locale.
  Includes unused profiles on purpose (they are "in effect" and a later mapping edit
  would pick them up anyway).
- **`sepa` repeats the `default` rules.** The brief fixes the file format as `rules`
  only (no include key), so `sepa.toml` carries a copy; a comment in both says to keep
  them in step. Rejected: adding an `extends` key — it changes a user-facing promise the
  brief fixed. Cost of the duplication: 6 rules (about 17 lines).
- **SEPA value rule**: `\b(?:EREF|MREF|CRED|ABWA)\+[\s\S]*?(?=\b(?:EREF|MREF|CRED|SVWZ|ABWA)\+|\Z)`.
  `[\s\S]` and `\Z` rather than `.`/`$` so a memo with a newline still works. As the
  brief specifies, the value runs to the next tag, so a merchant sitting *after* an
  `EREF+` and before any tag is eaten; real bank memos put the purpose under `SVWZ+`.
- **Errors**: all raise `NormaliserError` naming the file (and the rule/entry number).
  Unreadable/invalid TOML, bad UTF-8, extra keys, wrong types, bad regex, unknown profile
  in mapping, duplicate account, path not a non-empty list of non-empty strings. A user
  dir that exists but is a file is also an error; a missing one is fine.
- `accounts.toml` is skipped when scanning profiles, in both the package and user
  directory.
- `Normaliser.normalise` also validates `source_account` with the same path check.

## Things I did not do

- Reject patterns that match the empty string (e.g. `\d*`). `re.sub` would then put a
  space between every character; whitespace collapsing makes the token read `A B C`.
  The brief lists the error cases and this is not one; flagging for sign-off.
- No `T2-threat-model` change: user regexes are the user's own input (brief's call).
- No version tuple or staging column (out of scope).

## PR description must state

`Normaliser.version` (a string) is the recorded value, not the `NORMALISER_VERSION`
integer; and the settled design points from the brief's *Open questions* (named TOML
profiles, `$XDG_CONFIG_HOME/autobook/normaliser/`, whole-file override, `accounts.toml`
with `default` fallback).

## Evidence

- `./engine/nox.sh gate` with `PDCA_WORKTREE` set: fmt, lint (ruff), types (mypy strict),
  test, typos, docs all green; 216 passed, 1 skipped (gnucash absent, pre-existing).
  The first run failed lint (S105 on `result.token == "…"`, E501, PLR0402); fixed with a
  `_text()` helper in the test and `ruff format`. No `noqa` added, no config changed.
- `engine/scripts/run-verify.sh`: `C4 PASS — red without the fix (37 of 42 failed),
  green with it; 0 import/collection errors`.

## Refute-my-own-test (forced)

- **(a) Genuine red?** Yes. run-verify's red leg reverts the production hunks
  (normaliser.py back to the stub, profiles gone): 37 of 42 ran-and-failed, with
  `AttributeError` from `normaliser.load`. The 5 that stay green are the skeleton tests.
- **(b) Production path?** Yes. Tests call `normaliser.load(...)` and `.normalise(...)`
  on the real module, reading the real shipped `default.toml` / `sepa.toml` through
  `importlib.resources`. No copy of the logic in the test.
- **(c) Fixture includes the fault?** Yes. (a) iterates every row of `build_corpus(0..2)`
  including the novel-merchant row and the `""` noise rows; (b) uses SEPA memos with all
  five tags and asserts none survives; a control test shows an unmapped account keeps
  `EREF+` (so the mapping really matters). Version tests use two separate sub-directories
  of `tmp_path` and single-rule / single-mapping-line edits.

Module-scope imports are `from autobook.pipeline import normaliser` and
`from tests.fixtures.synthetic import corpus_builder` only (modules that exist at
base); every new name is reached through the module object in the test body. The words
the gate greps for are not in the test file.
