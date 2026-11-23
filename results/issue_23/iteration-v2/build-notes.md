# Build notes — issue 23 / normaliser-profiles-version (iteration 2)

Target: Ralphovi/autobook @ main, base `76baccee40f2` (the worktree HEAD). Line numbers
below are in the patched worktree unless they say "base".

## What this iteration changes

I started from the iteration-1 patch (`iteration-v1/patch.diff`), which met criteria
(a)–(d), and fixed the three implementation findings from the carry-forward. I did not
re-decide the design. The brief fixes it, and the remaining review items are human
calls held in `deferred-findings.json`.

### 1. An unreadable user directory now raises instead of being treated as missing

- Before: `load()` used `directory.exists()` and `directory.glob("*.toml")`
  (iteration-1 `normaliser.py:105-108`). On Python 3.14, `Path.exists()` returns False
  on *any* `OSError`, and `Path.glob()` swallows `PermissionError`. So a directory with
  mode `0300`, or one under a parent the user can't search, loaded as "package profiles
  only". The version was the same as a really absent directory, and the user's
  `accounts.toml` and overrides were dropped with no message. The brief says "Never a
  silent fallback" (brief.md:45-47).
- Now: `load()` gets its files from `_user_files()` (`src/autobook/pipeline/normaliser.py:105`,
  `:131-153`). It lists the directory with `os.scandir` inside one `try`:
  - only `FileNotFoundError` means "missing directory, no user files" (`:148`). The brief
    allows a missing directory (brief.md:56).
  - any other `OSError` (`PermissionError`, `NotADirectoryError`, …) becomes
    `NormaliserError` naming the directory (`:150`).
  - the `exists()` / `is_dir()` / `is_file()` probes are gone, so nothing swallows errors
    any more. Directories named `*.toml` are skipped. Anything else named `*.toml` is
    read, so a dangling symlink `sepa.toml` raises through `_read_toml` (`:170`) instead
    of being skipped quietly.
  - hidden names are skipped. Without that, the change above would make an Emacs lock
    file (`.#sepa.toml`, a dangling symlink) break `load()` while the user has a profile
    open. Hidden files were never meant to be profiles. I wrote this in ch.5
    (`docs/design/architecture/05-building-block-view.md:163`).
- Side effect: `user_dir` pointing at a regular file, or *through* one
  (`file/normaliser`), now raises. Iteration 1 already raised for the first case and
  silently ignored the second.
- What I didn't do: wrap the `os.scandir` in a probe before falling back. That would
  still hide the cause. Mapping the error is the cause fix. It replaces five lines
  (`exists`/`is_dir`/`glob`/`is_file`) with one `try` (+23/−5 in `load`, incl. docstring).

### 2. SEPA tags are found even when glued to the previous value

- Before: `sepa.toml` put `\b` in front of every tag, both at the start of a match and in
  the "next tag" lookahead (iteration-1 `sepa.toml:7`, `:11`). In
  `EREF+NOTPROVIDEDSVWZ+BEISPIELMARKT` there is no word boundary before `SVWZ+`, so the
  `EREF+` value ran to the end of the memo and the token came out empty. In
  `SVWZ+BEISPIELMARKTEREF+ABC`, the `EREF+ABC` part stayed in the token.
- Now: no `\b` before any tag (`src/autobook/pipeline/profiles/sepa.toml:10`, `:14`). A tag
  is four capitals plus `+`, so a false match inside a merchant name would need a literal
  `EREF+`/`MREF+`/`CRED+`/`SVWZ+`/`ABWA+` in it. That is unlikely, and when it happens
  it is visible in the token. The brief says "up to the next SEPA tag or the end"
  (brief.md:103-106). It does not ask for a word break first. ch.5 now says so
  (`05-building-block-view.md:158-159`).
- I left the extra SEPA tags (`KREF+`, `COAM+`, `DEBT+`, …) out. The brief names exactly
  five tags, and other bank profiles are out of scope (brief.md:21).

### 3. A test that `sepa` repeats `default`'s rules exactly

`tests/test_normaliser.py:102` (`test_sepa_profile_ends_with_exactly_the_default_rules`)
reads both package files through `importlib.resources` and checks that `sepa`'s rules end
with exactly `default`'s rules, in order, and that `sepa` has more rules than `default`.
The `sepa.toml` header comment now points at this test instead of saying "keep the two
files in step" (`sepa.toml:2-3`). I considered an `include` key so the rules would not be
copied, and rejected it: the brief fixes the profile format to a single top-level key,
`rules` (brief.md:77), and that format is a promise to users.

## The rest of the patch (unchanged from iteration 1)

- `src/autobook/pipeline/normaliser.py` replaces the base stub (base
  `src/autobook/pipeline/normaliser.py:1-18`, `__all__ = ["normalise"]`, raising
  `NotImplementedError`). It has the public API from brief.md:40-57: `__all__` at `:30`,
  `NORMALISER_VERSION` at `:41`, `NormaliserError(ValueError)` at `:48`, which mirrors
  `ContractError` in base `src/autobook/contracts.py:110`. The version digest is at `:242`:
  canonical JSON, sorted by profile name and account path, with no path in it.
- `tests/test_skeleton.py:22` adds `IMPLEMENTED`, and `:50` skips all three stub-shape
  assertions for those modules (base `tests/test_skeleton.py:43-50`). Every other
  skeleton check still covers the normaliser.
- ch.5 §5.2 and ch.8 §8.8 docs, as the brief asks.
- Test fixtures use names from `tests/fixtures/synthetic/corpus_builder.py` (base:
  `GIROKONTO` `:17`, `REVOLUT` `:18`, `MERCHANTS` `:34-38`, `NOVEL_MERCHANT` `:43`,
  `NOISE` `:54`). All SEPA values are invented. The creditor ID is
  `DE98ZZZ09999999999` (`ZZZ` marks it synthetic), and there are no IBAN-shaped strings.

New tests this iteration: four glued-tag cases in (b) (`tests/test_normaliser.py:86-90`),
`test_an_unreadable_user_directory_raises` (`:303`), `test_a_user_directory_that_is_a_file_raises`
(`:317`) and `test_a_broken_profile_link_raises_and_a_hidden_one_is_ignored` (`:325`).
The unreadable-directory test asserts it is not running as root (root can list a `0300`
directory) instead of skipping, because the brief bans skips (brief.md:185). The gate
runs as uid 1000.

## Evidence

- `./engine/nox.sh gate` on the worktree: fmt, lint, types, test-3.14 (224 passed,
  1 skipped for the missing `gnucash` module, 7 deselected), typos and docs all succeed.
  The first run failed on ruff `S105` for `….token == "X"` in a test. I switched it to the
  file's `_text()` helper, which exists for the same reason.
- `engine/scripts/run-verify.sh` (C4): `C4 PASS — red without the fix (45 of 50 failed),
  green with it`. 0 collection errors. The 5 tests that pass on the red leg are in
  `tests/test_skeleton.py`.

## Refuting my own test

- **(a) Genuine red?** Yes, at two levels.
  1. The whole fix reverted (the C4 red leg): 45 of 50 fail with
     `AttributeError: … has no attribute 'load'` and none fail to collect.
  2. Only this iteration's fixes reverted, with the iteration-1 behaviour put back (the
     `\b` in `sepa.toml`, and `load()` back on `exists()`/`is_dir()`/`glob()`/`is_file()`),
     run through `nox -s test-3.14`: exactly the 7 new tests fail (4 glued-tag cases,
     unreadable dir, dir-is-a-file, broken link) and the other 217 pass. For
     dir-is-a-file, iteration 1 already raised for the plain-file case. The red comes from
     the `file/normaliser` case, which iteration 1 silently treated as missing.
  3. Changing one rule in `default.toml` only (`REF \d+` → `REF\.? \d+`) makes
     `test_sepa_profile_ends_with_exactly_the_default_rules` fail.

  After each check I restored the tree from `patch.diff`, and `git diff | cmp - patch.diff`
  printed SAME.
- **(b) Production path?** Yes. Every test calls the real `normaliser.load()` with the
  shipped package profiles and real files in `tmp_path`. Nothing is mocked. The drift
  test reads the real package files through the same `importlib.resources` root that
  `_load_package_profiles` uses.
- **(c) Fixture includes the fault?** Yes. The unreadable-directory test uses a real
  `chmod 0o300` directory that holds an `accounts.toml`, i.e. the config that used to be
  dropped. It is not a mocked `PermissionError`. The glued-tag memos are the exact shapes
  the reviewer and adversary reproduced (`EREF+NOTPROVIDEDSVWZ+…`,
  `EREF+123 MREF+456SVWZ+…`, `SVWZ+…EREF+ABC`), plus one with three glued tags. The
  broken-link test uses a real dangling symlink.

## Not addressed (and why)

- **Patterns that match the empty string** (adversary note, "not a blocker"). A user rule
  `pattern = ''` spreads a token out letter by letter. The brief only rejects patterns that
  don't compile (brief.md:82-84), and no static check catches every pattern that can
  match empty (`\b` alone matches only between characters). Left for a follow-up if the
  human wants it.
- **`CRED+`/`ABWA+` values removed** (abstention-erosion concern). This is the brief's
  design (brief.md:103-106) and is held as a human item in `deferred-findings.json`.
- **PR description wording** about `Normaliser.version` vs `NORMALISER_VERSION`
  (brief.md:145-153). That belongs to publish, not this patch.

## Housekeeping

While checking the targeted red I set aside the patched files inside the worktree, as
`src/autobook/pipeline/.profiles-scratch-old/` and `tests/.test_normaliser-scratch-old`.
They are untracked, hidden, and not in `patch.diff`. pytest does not collect them,
`pkgutil` and the profile loader ignore them, and the gate stays green with them present.
Cleanup is the harness's job.
