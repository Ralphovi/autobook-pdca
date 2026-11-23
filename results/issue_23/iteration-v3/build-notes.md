# Build notes — issue 23 / normaliser-profiles-version (iteration 3)

Target: Ralphovi/autobook @ main, base `76baccee40f2` (the worktree HEAD). Line numbers
below are in the patched worktree unless they say "base".

## What this iteration changes

I started from the iteration-2 patch (`iteration-v2/patch.diff`, applied cleanly to the
base) and fixed the two implementation findings in the round-2 carry-forward. I did not
re-decide the design; the brief fixes it, and the other review items are human calls held
in `deferred-findings.json`.

### 1. A user directory behind a broken symlink now raises instead of counting as missing

- Before: `_user_files()` mapped every `FileNotFoundError` from `os.scandir` to "no user
  files" (iteration-2 `normaliser.py:148-149`). A dangling symlink for the directory raises
  `FileNotFoundError`, so a moved dotfiles checkout loaded as package-only, with the same
  version as a really absent directory.
- Now: on `FileNotFoundError`, `_user_files()` (`src/autobook/pipeline/normaliser.py:155`)
  asks `_broken_link_on_path()` (`:168-180`) whether a broken link explains it. That
  function walks from the directory up through its parents (`:175`) to the deepest part that
  exists without following a final link (`os.path.lexists`). If that part is a symlink whose
  target is gone, it is returned and `load()` raises `NormaliserError` "… is a broken
  symlink". Otherwise the directory is just not there and the result is `[]`, as the brief
  allows (brief.md:55-56).
- Why I went further than the reviewer's suggested fix. The reviewer proposed
  `return [] only if not os.path.lexists(directory)`. That covers only the last part. The
  default path is `~/.config/autobook/normaliser`, and linking `~/.config/autobook` itself
  to a dotfiles checkout is at least as common as linking `normaliser/`. With the leaf-only
  check, a dangling `~/.config/autobook` makes `lexists(…/normaliser)` False, so the same
  silent drop comes back one level up. I checked this: with the walk cut to the leaf only
  (`for part in (directory,):`), the second assertion of
  `test_a_user_directory_behind_a_broken_link_raises` fails with "DID NOT RAISE". The walk
  costs 13 lines (`:168-180`) over the leaf-only check's ~3.
- A link that works but leads to a directory with no `normaliser/` under it is still just
  "missing" (`tests/test_normaliser.py:358-365` pins this), so the walk does not turn a
  normal absent directory into an error.
- `os.path.exists` returns False on `PermissionError` too, but that case never reaches here:
  `scandir` raises `PermissionError` first, which the existing `OSError` branch maps to
  `NormaliserError` (`normaliser.py:162`).

### 2. A relative `XDG_CONFIG_HOME` is ignored

- Before: `_default_user_dir()` used any non-empty value (iteration-2 `normaliser.py:126-127`),
  so `XDG_CONFIG_HOME=rel` resolved against the current working directory, and the tokens
  and version depended on where autobook was started.
- Now: the value is used only when `os.path.isabs()` is true
  (`src/autobook/pipeline/normaliser.py:126-133`, check at `:130`); unset, empty or relative
  all fall back to `~/.config`. This is the XDG Base Directory spec's rule. The brief says
  "unset or empty" (brief.md:53-55); a relative value is invalid by the spec ch.8 §8.8 points
  at, so treating it like unset keeps to the brief's intent.
- Docs: the `load()` docstring (`:99-101`) and ch.5 §5.2
  (`docs/design/architecture/05-building-block-view.md:161-168`) now say "unset, empty or
  relative" and mention the broken-symlink error.

### New tests

- `test_a_relative_xdg_config_home_is_ignored` (`tests/test_normaliser.py:258`): two user
  profiles, one under `$HOME/.config/…`, one under `<cwd>/rel/…`; `chdir` to the cwd and set
  `XDG_CONFIG_HOME=rel`. The token must come from the `$HOME` one.
- `test_a_user_directory_behind_a_broken_link_raises` (`:346`): a dangling link as the
  directory, then a dangling link as its parent.
- `test_a_user_directory_behind_a_working_link_loads` (`:358`): the control. A link to a real
  directory gives the same version as the target; a link to a real parent with no
  `normaliser/` under it gives the package-only version.

## The rest of the patch (unchanged from iterations 1-2)

- `src/autobook/pipeline/normaliser.py` replaces the base stub (base
  `src/autobook/pipeline/normaliser.py:1-18`, `__all__ = ["normalise"]`, raising
  `NotImplementedError`). Public API per brief.md:40-57: `__all__` at `:30`,
  `NORMALISER_VERSION` at `:41`, `NormaliserError(ValueError)` at `:48`, which mirrors
  `ContractError` in base `src/autobook/contracts.py:110`. Version digest in `_version()`:
  canonical JSON sorted by profile name and account path, no path in it.
- Unreadable directory raises (`_user_files`, `os.scandir` in one `try`); hidden names
  skipped; SEPA tags found without a preceding word break
  (`src/autobook/pipeline/profiles/sepa.toml`); a test pins that `sepa` ends with exactly
  `default`'s rules. All from iteration 2.
- `tests/test_skeleton.py:22` adds `IMPLEMENTED`; the stub-shape loop skips all three
  assertions for those modules (base `tests/test_skeleton.py:43-50`).
- ch.5 §5.2 and ch.8 §8.8 docs.
- Fixtures use names from base `tests/fixtures/synthetic/corpus_builder.py` (`GIROKONTO`
  `:17`, `MERCHANTS` `:34-38`, `NOVEL_MERCHANT` `:43`, `NOISE` `:54`). SEPA values are
  invented; creditor ID `DE98ZZZ09999999999`; no IBAN-shaped strings.

## Evidence

- `./engine/nox.sh gate` on the worktree: gate, fmt, lint, types, test-3.14 (227 passed,
  1 skipped for the missing `gnucash` module, 7 deselected), typos and docs all succeed.
  This is the target's own formatter and linters, so the patch is commit-ready.
- `engine/scripts/run-verify.sh` (C4): `C4 PASS — red without the fix (48 of 53 failed),
  green with it`; 0 collection errors. The 5 that pass on the red leg are in
  `tests/test_skeleton.py`.

## Refuting my own test

- **(a) Genuine red?** Yes.
  1. Whole fix reverted (C4 red leg): 48 of 53 fail, none fail to collect.
  2. Only this iteration's fixes reverted (`normaliser.py` put back to the iteration-2
     file, everything else unchanged), via `nox -s test-3.14`: exactly
     `test_a_relative_xdg_config_home_is_ignored` and
     `test_a_user_directory_behind_a_broken_link_raises` fail; 225 pass. The working-link
     test passes there too, which is right: it is the control that the fix does not
     over-reach.
  3. The reviewer's leaf-only variant: the broken-link test still fails on the parent case.
  After each check I restored `normaliser.py` from `patch.diff`, and
  `git diff | cmp - patch.diff` printed SAME.
- **(b) Production path?** Yes. The tests call the real `normaliser.load()`; the XDG test
  goes through `load()` with no argument, so it runs the real `_default_user_dir()`. Nothing
  is mocked; `monkeypatch` only sets `HOME`, `XDG_CONFIG_HOME` and the working directory.
- **(c) Fixture includes the fault?** Yes. Real dangling symlinks made with
  `Path.symlink_to` on a missing target, at both the leaf and the parent. The relative-XDG
  test puts a real, different profile at the cwd-relative path, so reading it would change
  the token; it is not just an empty path.

## Not addressed (and why)

- **Patterns that match the empty string** (adversary note from round 1, "not a blocker"):
  unchanged; the brief only rejects patterns that don't compile (brief.md:82-84).
- **`CRED+`/`ABWA+` values removed**: the brief's design (brief.md:103-106); held in
  `deferred-findings.json`.
- **PR description wording** on `Normaliser.version` vs `NORMALISER_VERSION`
  (brief.md:145-153): belongs to publish.

## Housekeeping

I wrote no scratch files this iteration. The worktree has an untracked
`tests/fixtures/synthetic/__pycache__/` from the test runs (the only untracked entry in
`git status`); it is not in `patch.diff`.
