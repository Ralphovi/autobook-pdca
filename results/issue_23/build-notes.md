# Build notes — issue 23 / normaliser-profiles-version (v4 Do)

Target: Ralphovi/autobook @ `main`, base `origin/main` = 76bacce (checked in the worktree:
`git rev-parse --short HEAD origin/main` → 76bacce, 76bacce). Built in `$PDCA_WORKTREE`
(`/home/eddie/autobook/autobook.pdca-wt`). Line numbers below are on the base (`base:`)
or on the patched tree (`new:`).

## What the patch does

| File | Change |
|------|--------|
| `src/autobook/pipeline/normaliser.py` | Replaces the stub (base:13 `__all__ = ["normalise"]`, base:16-18 `normalise()` raising `NotImplementedError`) with the API the brief fixes. |
| `src/autobook/pipeline/profiles/default.toml` | New. The nine `default` rules, in the brief's order (new:15, 19, 23, 27, 31, 35, 39, 44, 50). |
| `src/autobook/pipeline/profiles/sepa.toml` | New. `extends = "default"` (new:12), one dropped-tag rule (new:21), one kept-tag rule (new:27). |
| `tests/test_normaliser.py` | New. Criteria (a)–(e), every *Errors* case, XDG fallback, listing rules, repr. 83 tests. |
| `tests/test_skeleton.py` | `IMPLEMENTED = {"autobook.pipeline.normaliser"}` (new:22); the stub-check loop (base:43-50) skips all three assertions for it (new:52-53). New:50 asserts every `IMPLEMENTED` name is a real block. |
| `docs/design/architecture/05-building-block-view.md` | §5.2 *Normaliser* rewritten (base:132-138 → new:133-268): API, profile format, `extends`, case-insensitive patterns, both profiles, the SEPA tag table, user directory, listing rules, mapping file, override rule, version rule with the Unicode version. The SEPA sentence (base:134) is gone. Package-layout lines (base:17-18, base:24) now say the normaliser exports its real API and that `pipeline/profiles/` is package data. |
| `docs/design/architecture/08-crosscutting-concepts.md` | §8.8 (base:144-148) gains the normaliser directory paragraph (new:150-155). |
| `docs/design/proposals/draft/0001-gnucash-auto-booking-pipeline.md` | Only the SEPA sentence at base:392 is replaced (new:392-396); base:393-394 ("dates, card fragments, … merchant / token.") are byte-identical in the diff. |
| `typos.toml` | One narrow exception for the deliberate misspelling `defualt.toml` (new:11-15). |

### normaliser.py, piece by piece (new: line numbers)

- `__all__` is exactly the five names (new:35-41). `NORMALISER_VERSION: Final[int] = 1` (new:45).
- `NormaliserError(ValueError)` (new:64), mirroring `ContractError(ValueError)` at
  `src/autobook/contracts.py:110`, as the brief's *Citations expected* asks.
- `NormalisedMemo` frozen dataclass (new:68-79): `raw_memo` and `token` both `field(repr=False)`
  (new:76-77). See *Decisions* for why `token` is hidden too.
- `Normaliser` (new:89-117): `version: Final[str]`; `normalise()` validates input
  (`_check_input`, new:378-390), looks up the profile (unmapped → `default`), upper-cases, applies
  the effective rules in order with `rule.sub(" ", …)` (new:111), and collapses/strips whitespace
  with `" ".join(text.split())` (new:114). `__init__` refuses any caller but `load` via a module
  sentinel (new:59, new:99).
- `load()` (new:120-137): default dir (new:143-147: absolute `XDG_CONFIG_HOME` only, else
  `~/.config`), package profiles via `importlib.resources.files("autobook.pipeline")`
  (new:157-172), user listing with `os.scandir` (new:175-207), user overrides replace whole
  files (new:133), `extends` resolved on the merged set (new:270-287), mapping parsed and checked
  against the merged set (new:293-326), "must be used" (new:329-344), version (new:350-372).
- Version (new:350-372): SHA-256 over JSON of `{normaliser, unicode, profiles, accounts}` with
  `sort_keys`, profiles sorted by name with their effective pattern strings in order, accounts
  sorted by path. No path, file name or mtime enters. `unicodedata.unidata_version` is read
  through the module at call time (new:361) so `monkeypatch.setattr` reaches it.
- Patterns compile with `re.IGNORECASE` (new:263).

## Decisions the brief left open, and why

1. **`token` is also `field(repr=False)`.** The brief fixes `raw_memo` as `repr=False` "so a
   logged `repr` never carries the memo (ch.8 §8.5: logs never carry memos)" (base ch.8:109).
   With only `raw_memo` hidden that goal fails for any memo without noise: the corpus row
   `MUSTER HAUSVERWALTUNG` (`corpus_builder.py:37`) has token == memo, so the repr would carry
   the memo verbatim. A kept `ABWA+`/`ABWE+` value can also be a person's name (brief, *Known
   limit*). Hiding the token costs nothing in the API (fields, types, constructor unchanged).
   `test_a_result_repr_carries_neither_the_memo_nor_the_token` (new test:595) uses exactly the
   no-noise memo.
2. **Only `load` can build a `Normaliser`** (brief: "built only by `load`"). A direct constructor
   could pair any `version` with any rules, which breaks the invariant ("any change … shows up
   as a different normaliser version"). Cost: a sentinel + 2-line check (new:59, new:99-100).
   Pinned by `test_a_normaliser_is_built_only_by_load` (new test:140).
3. **Cycle errors name every file in the cycle** (new:280-284). A user `default.toml` with
   `extends = "sepa"` closes a cycle through the *package* `sepa.toml`; naming only the file
   that closes the cycle would point the user at the installed package file.
4. **`accounts.toml` errors name the entry number, not the account path** (new:299-300), and
   pattern-compile errors do not echo the pattern (new:265). Account names are personal data
   (ch.8 §8.5, base:96-100), and a user pattern may name a person. The file path is always in
   the message, as the brief requires.
5. **`(?s)` on the dropped-tag rule** (sepa.toml new:21). Without it a dropped value cannot cross
   a line break, the match fails and the tag *and its value* stay (`EREF+ZZZ0815\nSVWZ+…` keeps
   `EREF+ZZZ0815`). Pinned by `test_sepa_memos_give_the_expected_token[EREF+ZZZ0815\nSVWZ+…]`
   and the `one-tag-per-line` case of (b1).
6. **`default` rules end in `\b` where a digit run is consumed** (e.g. `\bKARTE\s+\d+\b`), so
   `KARTE 12ABC` does not lose `12` from a word. All 334 rows of seeds 0–2 map to their merchant
   (criterion (a)).
7. **`_check_input` takes `object`** (new:378). mypy runs `strict` with `warn_unreachable`
   (`pyproject.toml:90-91`); an `isinstance` check on a parameter typed `str` would be flagged
   unreachable. Same approach as `contracts.py` (`_text(value: object, …)`, base:227).
8. **typos exception is a regex on the whole file name** (`extend-ignore-re = ['defualt\.toml']`,
   typos.toml new:15), not an `extend-words` entry. The brief's test plan requires the literal
   `defualt.toml`, and `typos` 1.48.0 flags it in the module docstring, the test and ch.5. An
   `extend-words` entry (`defualt = "defualt"`, also 1 line) would accept that typo anywhere in
   the repo; the regex keeps it caught everywhere else. Checked: a probe line `a defualt b`
   still fails `typos` with the exception in place. The brief's "add it to `typos.toml` with a
   reason, as existing entries do" is followed in spirit (comment + reason, typos.toml new:11-14).
9. **`IMMOBILIEN` replaced by `WOHNBAU`** in one (b2) test value: `typos` flagged it
   (`IMMOBILIEN` → `IMMOBILE`); the value is invented, so changing it is cheaper than an
   allowlist entry.
10. **Package profiles go through the same name filter** as the user directory (`_profile_name`,
    new:150-154); a package `accounts.toml` or non-file `*.toml` raises (new:165-166), and a
    package without `default.toml` raises (new:170-171) instead of a `KeyError` at `normalise`.

## Ruled out

- **Module-scope `from autobook.pipeline.normaliser import load`** — a collection error on the red
  leg (brief rule 1). The test imports the module only (`from autobook.pipeline import
  normaliser`, new test:24; ruff's PLR0402 rewrote my `import … as normaliser` into this form,
  which still binds the module object that exists as the stub on 76bacce).
- **`Path.glob` / `iterdir` without a guard** — `glob` swallows `PermissionError`; the mutation
  check below confirms the unreadable-directory and dangling-symlink tests catch it.
- **Rejecting patterns that can match the empty string** (`\d*`). Python's `re.sub` inserts the
  replacement at every empty match, so such a user rule spreads a token into single letters.
  Not in the brief's error list; I did not add an error case the brief did not ask for. A
  candidate follow-up issue.
- **Echoing unknown keys' values or the account path in errors** — see decision 4.

## Verification (all through the project's own runners)

- `engine/nox.sh gate` (= `nox -s gate` in the worktree): fmt, lint (ruff 0.14.2), types (mypy
  1.18.2 strict, 36 files), test-3.14 (262 passed, 1 skipped = the pre-existing gnucash-only
  book test, 7 deselected), typos, docs lint — all green, run after the last edit.
- `engine/scripts/run-verify.sh` (the C4-verify gate) with `PDCA_BUNDLE` = this bundle and
  `PDCA_WORKTREE` set: **green leg 88 passed (ran 88, 0 collection errors); red leg 83 of 88
  failed (ran 88, 0 collection errors) → `PDCA-EVIDENCE: C4 PASS`**. The 5 red-leg passes are
  `tests/test_skeleton.py` (the normaliser is in `IMPLEMENTED`, and the other checks hold for the
  stub too). The worktree was restored by the script's trap; `git apply --check -R patch.diff`
  confirms the tree equals base + patch.
- `patch.diff` applies cleanly to 76bacce (`git apply --cached --check` with the index at HEAD).
- Advisory `engine/scripts/check-threat-model-touch.sh`: `no security-relevant path touched`.
- Corpus: seeds 0, 1, 2 → 334 rows, all tokens equal the merchant name (also asserted by the
  test).
- Hostile input timing, both profiles, 200 kB memos (long tag value, repeated/glued tags, digit
  runs then a letter, `REF` + spaces + digits, punctuation runs, `2025-`, `1:`, `1.` runs,
  tag-prefix soup, `KARTE` runs): worst 30 ms (`default`), 40 ms (`sepa`), on `1:` runs. No
  nested quantifiers in any rule.

### Mutation checks (does each criterion's test bind its behaviour, not just "the API exists"?)

The red leg only shows the API was missing. So I broke one behaviour at a time in the patched
tree, ran `tests/test_normaliser.py`, and restored the file in a `finally`
(`PYTHONDONTWRITEBYTECODE=1`, own pycache prefix inside `.nox/`, so no stale bytecode). Every
mutation turned the named test(s) red; the unmutated and restored runs were 83/83 green:

| Mutation | Test that went red |
|----------|--------------------|
| no `re.IGNORECASE` | (e) `test_a_lower_case_user_pattern_matches` |
| `CRED+` moved to the dropped set | (b2) `…kept_value…[CRED+]` (+6 others) |
| `ABWA+`/`ABWE+` moved to the dropped set | (b2) `[ABWA+]`, `[ABWE+]` (+7 others) |
| `\b` required before the next tag | (b3) `EREF+NOTPROVIDEDSVWZ+…`, (b1) `[glued]` |
| `(?s)` removed | (b1) `[one-tag-per-line]`, (b3) line-break case |
| `BIC` removed from the dropped set | (b1) `[spaced]` (+5) |
| digit-run rule moved before the ISO-date rule | (b4) timestamps |
| package profile wins over the user file | (c) override test (+11) |
| `extends` resolved before user overrides | (c) `test_a_user_default_also_changes_accounts_mapped_to_sepa` |
| Unicode version left out of the digest | (d) Unicode test |
| rules left out of the digest | (d) one-rule test |
| mapping left out of the digest | (d) mapping-line test |
| user-directory path put into the digest | (d) "same files from any directory" (+2) |
| listing with `Path.glob` | unreadable directory, dangling directory symlink (+1) |
| relative `XDG_CONFIG_HOME` honoured | `…unless_xdg_config_home_is_absolute[relative-config]` |
| "must be used" check off | `[defualt.toml]`, `[Default.toml]` |
| `sepa.toml~` etc. read as profiles | ignored-entries test |
| `token` shown in repr / `raw_memo` shown in repr | repr test |
| input check (`_check_input` call) removed | the 6 malformed-account cases and the non-string memo test |

(Two harness slips on the way, both mine and both fixed before the run above: a rule-reorder
that split the TOML on a wrapped comment line and so moved only a comment, and two same-size
mutations in one second that let Python reuse stale bytecode. Neither touched `patch.diff`.)

## Refute-your-own-test (forced)

- **(a) Genuine red? Yes.** C4-verify reverted every non-test hunk (`git apply -R --exclude
  tests/*`): `normaliser.py` back to the 76bacce stub, both profile files gone. 83 of 88 tests
  ran and failed, 0 import/collection errors (they fail with `AttributeError` on
  `normaliser.load` / `normaliser.NormaliserError`). Beyond that, the 20 targeted mutations
  above each go red, so the tests bind the specific behaviours of (a)–(e), not just the API's
  existence.
- **(b) Production path? Yes.** Every test calls `normaliser.load(...)` and
  `Normaliser.normalise(...)` from `src/autobook/pipeline/normaliser.py` with the real package
  profiles read through `importlib.resources` from `src/autobook/pipeline/profiles/` (C4-verify
  puts the worktree's `src/` on `PYTHONPATH`; the nox session uses an editable install of the
  same tree). No mock, no copy of the rules. The only patches are `monkeypatch` of
  `unicodedata.unidata_version`, `HOME`, `XDG_CONFIG_HOME` and the cwd, which is what the brief
  prescribes.
- **(c) Fixture includes the fault? Yes.** The corpus test runs every row of seeds 0–2 (no row
  filtered; novel row included and asserted). The SEPA memos carry all 15 tags with values the
  `default` rules cannot remove (letters and digits glued), in spaced, glued, reversed,
  lower-case and one-per-line layouts. The error tests create the real failing condition on
  disk: `chmod 0o300` directory, a real dangling symlink, a real file as the directory, a real
  subdirectory and dangling symlink named `sepa.toml`, a real `chmod 0o000` profile, real
  invalid TOML and invalid UTF-8 bytes.

## Residual risks / not verified here

- **Python 3.11–3.13 not run locally**: only 3.14.4 is installed (`/usr/bin/python3.14`; no
  3.11–3.13, no `uv`). The project's gate tests on the running interpreter by design
  (`noxfile.py`, `gate` docstring) and CI's required `test-matrix` job runs 3.11–3.14 on the PR.
  I checked by reading for 3.11-only pitfalls: no f-string quote reuse or backslashes inside
  f-string expressions, `tomllib`/`importlib.resources.files`/`re` features used exist in 3.11,
  mypy ran with `python_version = "3.11"`, ruff with `target-version = "py311"`. Tests use ASCII
  memos and patch the Unicode version, so they do not depend on the interpreter's Unicode
  database. Look at the `test-matrix` job on the draft PR.
- **`chmod`-based tests assume a non-root runner** (root ignores the permission bits, so
  `test_an_unreadable_user_directory_is_rejected` and `test_an_unreadable_profile_is_rejected`
  would fail as root). The C4-verify runner and the GitHub runner are not root. The brief asked
  for `chmod 0o300` explicitly and forbids skips, so there is no root guard.

## Observations outside this slice (not fixed; candidates for issues)

- `.gitignore` re-includes everything under the fixtures (`!tests/fixtures/synthetic/**`,
  base:55), which also un-ignores `__pycache__/` (base:2) there: any test run leaves an untracked
  `tests/fixtures/synthetic/__pycache__/`, and a `git add -A` would commit `.pyc` files. It is in
  my worktree now and deliberately not in `patch.diff`.
- Empty-match user patterns (see *Ruled out*).

## Left in the worktree (not part of the patch; the harness reclaims the worktree)

- `.typos-probe.txt` — empty, hidden, untracked; held the `a defualt b` probe line for decision 8.
  Emptied, not deleted (the harness forbids `rm`-style commands). `typos` skips hidden files, and
  it is empty anyway.
- `.nox/pycache-mutation*` — bytecode caches from the mutation runs, inside the gitignored `.nox/`.
- `tests/fixtures/synthetic/__pycache__/` — see above.

## For the PR description (the brief requires these statements)

- The recorded value is **`Normaliser.version`** (the string `"<NORMALISER_VERSION>-<12 hex>"`),
  not the `NORMALISER_VERSION` int the issue's scope line names: the int alone would miss a
  user's profile edit (ch.8 §8.8). #24 records it with every vector; the version tuple (ch.8
  §8.3) and the future `proposals.normaliser_version` column will hold it.
- Settled with the maintainer and not on the issue thread: named TOML profiles in
  `$XDG_CONFIG_HOME/autobook/normaliser/`, whole-file override, `accounts.toml` with `default` as
  fallback, version = code constant + digest of effective profiles, mapping and Unicode version;
  the 15-tag SEPA table keeping the `CRED+`/`ABWA+`/`ABWE+` values (the v3 sign-off decision,
  also recorded by the corrected sentence in proposal 0001); `extends` resolved after overrides;
  case-insensitive patterns; the listing rules including "a user profile must be used"; one
  global version.
- Two choices beyond the brief's letter, for the reviewer to weigh: `token` hidden from `repr`
  (decision 1) and the narrow `typos` regex (decision 8).
