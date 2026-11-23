## Summary
**User impact:** Autobook cannot yet turn a bank statement line into a merchant it can
recognise. The memo cleaner was a placeholder that stopped with "not implemented", so
the steps that learn from past bookings and suggest an account for new ones had nothing
to work with. There was also no way to tell when the cleaning rules changed, which
would let old and new results mix without anyone noticing.

This PR makes the memo cleaner real. It reduces a raw memo such as
`EREF+123 CRED+DE98ZZZ01111111111 SVWZ+MITGLIEDSBEITRAG 01.2025` to a stable token
(`DE98ZZZ01111111111 MITGLIEDSBEITRAG`) using rule files called profiles. Users can
edit or replace those files without a new release. Every result is stamped with a
version that changes whenever anything that affects the output changes.

Reported in [#23](https://github.com/Ralphovi/autobook/issues/23).

## What to look at
- **The cleaner itself:** `src/autobook/pipeline/normaliser.py`. It loads the profiles
  and cleans memos.
- **The two built-in profiles:** `src/autobook/pipeline/profiles/default.toml` (general
  noise such as card numbers, references, dates and times) and `sepa.toml` (German
  SEPA bank-transfer fields). Each rule is a short regular expression, and they are
  meant to be read by people.
- **User files:** profiles and an `accounts.toml` (which bank account uses which
  profile) in `$XDG_CONFIG_HOME/autobook/normaliser/`. The format is documented in
  architecture chapter 5.2.

To try it:

```python
from autobook.pipeline import normaliser
n = normaliser.load()  # package profiles + your user directory
n.normalise("SVWZ+BEISPIELMARKT//MUENCHEN/DE 2025-03-05T10:11:12", ("Aktiva", "Girokonto"))
```

Map `["Aktiva", "Girokonto"]` to `sepa` in `accounts.toml` and the SEPA rules apply.
Without a mapping, the account uses `default`.

### Decisions agreed with the maintainer (not on the issue thread)
- **The value to record is `Normaliser.version`, not the `NORMALISER_VERSION`
  integer.** The issue says "`NORMALISER_VERSION`, recorded with every vector and in
  the version tuple". This PR narrows that on purpose: the integer alone would not
  change when a user edits a profile, and chapter 8.8 requires every setting that can
  change a classification to be part of the version tuple. `Normaliser.version`
  (`"<NORMALISER_VERSION>-<12 hex digits>"`) is what #24 records with every vector,
  what the version tuple (chapter 8.3) will record, and what the future
  `proposals.normaliser_version` staging column will hold. Nothing in this PR builds
  the tuple or the column yet.
- **Named TOML profiles** live in `$XDG_CONFIG_HOME/autobook/normaliser/`. A user file
  replaces the built-in profile of the same name as a whole file, with no merging.
  `accounts.toml` maps accounts to profiles, and unmapped accounts use `default`.
- **SEPA tags.** All 15 tags are recognised, and each one ends the value before it.
  `CRED+` (creditor ID), `ABWA+` and `ABWE+` (ultimate debtor/creditor) **keep their
  values**. Dropping them made two different creditors with the same purpose text
  collapse to one token, so a merchant the system has never seen would look familiar.
  Draft proposal 0001 said these values were stripped, and that one sentence is
  corrected in this PR.
- **`extends`.** A profile may build on another one. It is resolved after user
  overrides, so a user's `default.toml` also reaches accounts mapped to `sepa`.
- **Pattern case.** Patterns match regardless of case.
- **What feeds the version.** It is the code version plus a digest of the effective
  profiles, the account mapping and the interpreter's Unicode database version
  (`str.upper()` and `\d`/`\b`/`\s` depend on it, and CI runs Python 3.11–3.14).
- **One global version.** Any profile or mapping change gives every account a new
  version, even accounts whose tokens did not change. This costs nothing extra
  because the kNN index (the nearest-neighbour lookup in #24) is rebuilt every run.
- **User-directory listing rules.** Only `*.toml` files are read, and backups, dotfiles
  and notes are ignored. A user profile that nothing uses is an error, which catches
  misspellings like `defualt.toml` and `Default.toml`.

### Two choices beyond the spec, for the reviewer to weigh
- `NormalisedMemo.token` is hidden from `repr`, as well as `raw_memo`. For a memo with
  no noise the token *is* the memo, so a logged `repr` would otherwise leak it
  (chapter 8.5: logs never carry memos).
- `typos.toml` gets a narrow regex exception for the literal `defualt.toml`, which the
  tests and docs need. It is not a word-level allow entry, so the misspelling is still
  caught everywhere else.

### Known limits (follow-up candidates)
- A SEPA tag split by a line break inside the tag (`IBA\nN+…`) is not recognised, so a
  dropped value such as an IBAN can end up in the token. Whether that can happen
  depends on how the statement source joins wrapped lines.
- Tags can match in the middle of a word (`ARABIC+` → `ARA`), and merchant names made
  only of digits and punctuation are erased (`1&1 TELECOM` → `TELECOM`).
- A name kept from `ABWA+`/`ABWE+`/`SVWZ+` can be a person's name, and an IBAN typed
  into the purpose text is not removed. Both are documented in chapter 5.2. The guard
  is the model-adapter boundary (chapter 8.5), which this PR does not change.
- A user pattern that can match the empty string (`\d*`) is accepted and splits the
  token into single letters.

## Root cause
`src/autobook/pipeline/normaliser.py` on `main` (76bacce) was the skeleton stub: a
single `normalise()` that raised `NotImplementedError`. There were no profiles and
no version. The design (proposal 0001 *Normalisation*, chapters 5.2 and 8.3–8.8)
left the file format, user directory, override rule, SEPA tag set and version rule
open.

## Fix
- `normaliser.py` replaces the stub with the public API that #24 and #25 build on:
  `NORMALISER_VERSION`, `NormaliserError(ValueError)`, `NormalisedMemo`,
  `Normaliser`, `load()`. Only `load` can build a `Normaliser`, so a version can
  never be paired with the wrong rules.
- New package data: `profiles/default.toml` (9 rules) and `profiles/sepa.toml`
  (`extends = "default"`, one rule removing the dropped tags with their values, one
  removing the kept tags only).
- `tests/test_skeleton.py` gets an `IMPLEMENTED` set. Modules in it skip the stub-only
  checks, and every other skeleton check still covers them.
- Docs: chapter 5.2 *Normaliser* is rewritten (API, file formats, SEPA tag table, user
  directory, override and version rules), chapter 8.8 gains the normaliser directory,
  and the SEPA sentence in draft proposal 0001 is corrected.

## Verification
- **Claim:** every synthetic corpus memo (seeds 0–2, 334 rows) normalises to its
  merchant name with no user files.
  - **Checked:** `src/autobook/pipeline/profiles/default.toml:1-50`, rule order (ISO
    dates/times before digit runs).
  - **Test:** `tests/test_normaliser.py:149-167`.
- **Claim:** no SEPA tag and no dropped value (`IBAN+`, `BIC+`, `EREF+`, `KREF+`,
  `MREF+`, `DEBT+`, …) survives. This holds for spaced, glued, reversed, lower-case and
  one-tag-per-line layouts.
  - **Checked:** `src/autobook/pipeline/profiles/sepa.toml:21` (no word boundary is
    needed before a tag, and `(?s)` lets a value cross a line break) and `:27`.
  - **Test:** `tests/test_normaliser.py:176-198`.
- **Claim:** memos that differ only in the `CRED+`, `ABWA+` or `ABWE+` value get
  different tokens, a glued `EREF+NOTPROVIDEDSVWZ+BEISPIELMARKT` gives
  `BEISPIELMARKT`, and card payments that differ only in the timestamp get the same
  token.
  - **Test:** `tests/test_normaliser.py:201-258`.
- **Claim:** a user profile replaces the built-in one, and a user `default.toml`
  reaches `sepa`-mapped accounts through `extends`.
  - **Checked:** `normaliser.py:120-137` (`load`) and the `extends` resolution on the
    merged set.
  - **Test:** `tests/test_normaliser.py:270-292`.
- **Claim:** the same files give the same version, even from a different directory.
  One changed rule, one changed mapping line or a different Unicode version gives a
  different version. Every result carries the version and the unchanged memo.
  - **Checked:** `normaliser.py:350-372` (canonical JSON, sorted, no paths, Unicode
    version read at `:361`).
  - **Test:** `tests/test_normaliser.py:316-366`.
- **Claim:** lower-case user patterns match.
  - **Checked:** `normaliser.py:263` (`re.IGNORECASE`).
  - **Test:** `tests/test_normaliser.py:368-382`.
- **Claim:** bad input fails loudly and never echoes a memo. This covers an unreadable
  or dangling-symlink user directory, invalid TOML, unknown keys, `extends` cycles, an
  unused user profile and a malformed account. It also covers the relative
  `XDG_CONFIG_HOME` fallback and a `repr` that carries neither memo nor token.
  - **Test:** `tests/test_normaliser.py:384-604`.
- **Fails before, passes after:** with the production change reverted, 83 of 88
  tests run and fail (0 collection errors). The 5 that still pass are the skeleton
  checks. With the change, 88/88 pass. The full `nox -s gate` (format, lint, mypy
  strict, tests, typos, docs lint) is green on Python 3.14. 3.11–3.13 were not run
  locally, so please check the `test-matrix` CI job.
- **Each behaviour is pinned:** each behaviour above was broken on purpose, one at a
  time (for example: no `IGNORECASE`, `CRED+` moved to the dropped set, the Unicode
  version or the mapping left out of the digest, `Path.glob` instead of `os.scandir`).
  Each break turned the matching test red.
- **Performance:** both profiles run under 50 ms on 200 kB hostile memos. No rule has
  nested quantifiers.

Fixes #23
