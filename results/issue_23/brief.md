# Design proposal — issue 23 / normaliser-profiles-version

> Plan artifact for Ralphovi/autobook#23 (build order 2b, milestone `03 · 2 — Premise`).
> The design is settled in proposal 0001 (*Normalisation*), architecture ch.5 (§5.2
> *Normaliser*) and ch.8 (§8.3, §8.4, §8.5, §8.8). This proposal fixes what those leave
> open (profile file format, user directory, override and `extends` rules, the SEPA tag
> set, how the version is derived, the public API that #24 and #25 build on) so Do does
> not re-decide it. Do reads ONLY this file.
>
> **Re-plan (v4).** Attempts v1–v3 are archived in `iteration-v1/` … `iteration-v3/`. The
> v3 code followed the v3 brief and passed every gate; sign-off sent the *brief* back
> because the `sepa` profile was too narrow. What changed from v3 is listed under
> *Changes from v3* at the end. The hardening that v1–v3 review rounds added (unreadable
> or dangling user directory, relative `XDG_CONFIG_HOME`, glued SEPA tags) is now written
> into this brief as requirements; keep it.

- **Slug:** normaliser-profiles-version
- **Kind:** enhancement (design proposal)
- **Goal:** Turn a raw bank memo into a stable merchant token, in one place in the pipeline, driven by named per-source-account profiles (shipped in the package, overridable from a user directory), with a normaliser version that changes whenever anything that affects the output changes, carried on every normalised result.
- **Success criterion:** `tests/test_normaliser.py` passes with the patch applied and fails, with tests that RUN (not a collection error), with the production change reverted. It must assert: (a) with an empty user directory, for every row of `build_corpus(seed).rows` for seeds 0, 1 and 2 (`tests/fixtures/synthetic/corpus_builder.py`), the token equals that row's merchant name (`Merchant.token` of the merchant whose name starts the memo, or `NOVEL_MERCHANT`); (b) for synthetic SEPA memos normalised for a source account the user directory maps to `sepa`: (b1) no tag of the full SEPA tag set (*Profiles*) survives in any token, and no value of a dropped tag does (a synthetic `IBAN+`, `BIC+`, `EREF+`, `KREF+`, `MREF+` or `DEBT+` value); (b2) two memos that differ only in the `CRED+` value give different tokens, each containing its creditor ID, and the same holds for two memos that differ only in the `ABWA+` name and for two that differ only in the `ABWE+` name; (b3) a dropped tag's value ends at the next tag of the full set, also when the tags are glued with no space: `SVWZ+MIETE EREF+1 ABWE+MUSTER HAUSVERWALTUNG` gives `MIETE MUSTER HAUSVERWALTUNG` and `EREF+NOTPROVIDEDSVWZ+BEISPIELMARKT` gives `BEISPIELMARKT`; (b4) two card-payment memos that differ only in an ISO timestamp (`SVWZ+BEISPIELMARKT//MUENCHEN/DE 2025-03-05T10:11:12` vs `… 2025-04-17T18:02:59`) give the same token; (c) a user-directory profile with the same name as a package profile replaces it (a memo the package profile reduces to one token gives a different, expected token), and with that user file absent the package profile applies again; a user `default.toml` override also changes the token of a memo normalised for a `sepa`-mapped account (through `extends`); (d) two loads of the same profiles give the same `version`, including identical profile and `accounts.toml` files written into two *different* user directories (two separate subdirectories of `tmp_path`), so no path enters the digest; changing one rule in a user profile, or one line of the account mapping, or the Unicode database version (`monkeypatch.setattr(unicodedata, "unidata_version", …)`), gives a different `version`; every result carries the normaliser's `version` and the unchanged `raw_memo`; (e) a user rule written in lower case (`pattern = '\bfiliale\b'`) matches the memo `Beispielmarkt Filiale` and gives `BEISPIELMARKT`.
- **Falsifiability:** RED is reachable on the C4-verify gate (`engine/scripts/run-verify.sh`: host pytest in `$PDCA_WORKTREE` on the instance `.venv`, `-m "not applier and not live_paperless"`). Its red leg reverts every non-test hunk, so `src/autobook/pipeline/normaliser.py` returns to the stub on `origin/main` (76bacce), which exposes only `normalise()` raising `NotImplementedError`, and the profile files are gone. The module still exists, so a test that imports `autobook.pipeline.normaliser` at module scope collects, and the first call to `normaliser.load(...)` raises `AttributeError` inside the test body: a test that RAN and FAILED. v3 ran on this exact gate and base: red 48 of 53 failed with 0 collection errors, green 53/53 (`iteration-v3/gate-logs/C4-verify.log`). Gate config is unchanged since (`pdca.toml`, `engine/scripts/run-verify.sh`: no commits after the v3 run), and the base is still 76bacce. Re-checked at the plan-review revision: in the harness repo, `git log -- pdca.toml engine/scripts/run-verify.sh` ends at 0584b33 (2026-10-15 03:21), before the v3 `C4-verify.log` (written 12:33 the same day), with no uncommitted changes to either file; `git -C ../autobook rev-parse --short origin/main` after a fetch is 76bacce. A module-scope `from autobook.pipeline.normaliser import load` would instead be a collection error (UNVERIFIABLE, §6), so the import rule under *Tests and the gate* is binding.
- **Invariant to restore:** All memo normalisation happens in one pipeline component, driven by data (profiles) rather than code, and any change to what that component outputs for any memo shows up as a different normaliser version, so no vector, backtest or proposal can silently mix two normalisations. Sources: AGENTS.md *Classification rules* ("Normalisation lives in the pipeline, never in an ofxstatement plugin"; "The normaliser version is part of the gate tuple. Changing it changes what every vector means"); ch.8 §8.4 ("Normalisation is data, and lives in one place"); proposal 0001 *Normalisation*.
- **Repo + branch target:** Ralphovi/autobook @ main
- **Depends on:** none
- **Conflicts with:** none
- **Ordering note:** #22 (its prerequisite) is merged (PR #49, 76bacce on `origin/main`, re-checked at this re-plan). First wave of the chain #23 → #24 → #25: #24 normalises through this API, #25 through both. All three edit `tests/test_skeleton.py` and `docs/design/architecture/05-building-block-view.md`; the `Depends on` chain already puts them in separate waves, each folded onto the next one's base.
- **Surfaces:** data
- **Difficulty:** medium — one module made real (`src/autobook/pipeline/normaliser.py`), two new package-data profile files, one test file, a small change to `tests/test_skeleton.py`, and ch.5/ch.8 docs. No existing caller. Rated up from low because #24 and #25 build on this public API, its profile format and its version rule.
- **Scope:** (1) the normaliser in `src/autobook/pipeline/normaliser.py`, with the API, profile format, `extends` rule, override rule and version rule below; (2) two package profiles, `default` and `sepa`, as TOML files in `src/autobook/pipeline/profiles/`; (3) `tests/test_normaliser.py`; (4) `tests/test_skeleton.py` exempts the normaliser from the stub checks (below); (5) docs currency: ch.5 §5.2 *Normaliser* and ch.8 §8.8 record the profile format, `extends`, case-insensitive matching, the SEPA tag table, the user directory, the mapping file, the override rule and the version rule; and the one SEPA sentence in proposal 0001 *Normalisation* (`docs/design/proposals/draft/0001-gnucash-auto-booking-pipeline.md:392`) is corrected so it no longer says `CRED+`/`ABWA+` values are stripped (see *Docs currency*). / out of scope: assembling the version tuple or the batch gate that compares it (no code for either exists yet; this slice only provides the value); any staging column write (`normaliser_version` in `proposals` arrives with staging, build step 3); bank profiles beyond `default` and `sepa` (Revolut, PayPal …); PayPal pass-through merchant parsing (correlator); stripping IBAN-shaped text that is not behind an `IBAN+` tag (see *Profiles*); any ofxstatement plugin; the kNN index (#24) and backtest (#25); new runtime dependencies (`tomllib` and `unicodedata` are in the standard library; Python 3.11 is the minimum, `pyproject.toml:10`).
- **External dependencies:** none
- **Test file:** tests/test_normaliser.py
- **Citations expected:** Do must cite path:line on the target branch for every change it builds on: the stub `src/autobook/pipeline/normaliser.py` it replaces; `tests/test_skeleton.py:43-50` (the stub check it narrows); `tests/fixtures/synthetic/corpus_builder.py` (`MERCHANTS` :33, `NOVEL_MERCHANT` :43, `NOISE`, `GIROKONTO` :17; `build_corpus` returns a `CorpusContract` whose `.rows` are the rows); `src/autobook/contracts.py` (`CorpusRow`, account paths as `tuple[str, ...]`); `pyproject.toml` (ruff selection incl. `S`, `PL`, `T20`; mypy `strict`); ch.5 §5.2 *Normaliser* (the SEPA sentence at `docs/design/architecture/05-building-block-view.md:134`) and ch.8 §8.4/§8.5/§8.8; proposal 0001 *Normalisation* (`docs/design/proposals/draft/0001-gnucash-auto-booking-pipeline.md:392`, the sentence it corrects). Peer for the "reject loudly with a module error" pattern: `ContractError` in `src/autobook/contracts.py:110`, a `ValueError` subclass; mirror it as `NormaliserError`.
- **Prior-art check (triage cycles):** searched by path. `git -C ../autobook log origin/main -- src/autobook/pipeline tests/test_skeleton.py docs/design/architecture/05-building-block-view.md docs/design/architecture/08-crosscutting-concepts.md` shows only #22's skeleton (23ce73f) and two docs commits (8bfe271, 1192f9e); the normaliser is a stub. `gh pr list --state all` (8 PRs, all merged) has nothing on normalisation. Closed issue #5 (step 2, `NOT_PLANNED`) was split into #22–#26, not rejected; its normalisation scope is this issue's. Re-checked at this re-plan: unchanged. Sign-off on v3 confirmed prior art as settled.
- **Disposition hint:** new-feature

## Motivation

Classification quality depends more on memo preprocessing than on k or the metric
(proposal 0001). The kNN index (#24) and the backtest (#25) need a stable token per
memo, and they need to know when the meaning of that token changed. Normalisation is
the part tuned most, so it must be data that a user can change without a release, and
every change must be visible as a new version.

The token must also keep what tells two merchants apart. A token that is the same for
two different creditors makes a merchant the index has never seen look familiar, which
defeats the distance gate that exists to make the classifier abstain (proposal 0001,
*kNN*: "This gate is what stops confident errors on unseen merchants").

## Design

### Public API (fixed: #24 and #25 are briefed against it)

All in `autobook.pipeline.normaliser`. `__all__` lists exactly these names:

- `NORMALISER_VERSION: Final[int]`: the code's algorithm version, starting at `1`.
  Bump it when the code (not a profile) changes what a token looks like. It is one
  *input* to `Normaliser.version` and is **never recorded on its own** (see *Version*).
- `class NormaliserError(ValueError)`: every bad input raises this, with the file (or
  directory) and what is wrong. Never a silent fallback. The cases are listed under
  *Errors*.
- `@dataclass(frozen=True) class NormalisedMemo`: `raw_memo: str` (unchanged input),
  `token: str`, `profile: str` (name of the profile selected for the account),
  `version: str`. Declare `raw_memo` with `field(repr=False)` so a logged `repr` never
  carries the memo (ch.8 §8.5: logs never carry memos).
- `class Normaliser`: built only by `load`. Attribute `version: str`. Method
  `normalise(raw_memo: str, source_account: tuple[str, ...]) -> NormalisedMemo`.
- `load(user_dir: pathlib.Path | None = None) -> Normaliser`. `None` means the default
  user directory: `$XDG_CONFIG_HOME/autobook/normaliser/`, or
  `~/.config/autobook/normaliser/` when `XDG_CONFIG_HOME` is unset, empty or **not an
  absolute path** (the XDG Base Directory spec says relative values are invalid and are
  ignored). ch.8 §8.8: configuration is TOML under `$XDG_CONFIG_HOME/autobook/`. A
  directory that does not exist (and is not a dangling symlink) is allowed and means
  "package profiles only, no mapping". Tests always pass an explicit `tmp_path`, or set
  `XDG_CONFIG_HOME` with `monkeypatch.setenv`, and never read the real user directory.

The old stub entry point `normalise()` goes away (it is replaced by the API above).

### Profiles

A profile is a named, ordered list of rules. Each rule is a regular expression whose
matches are removed (replaced by a space). The name of a profile is its file name
without `.toml`. The file layout is fixed here (users write these files by hand, so it
is a compatibility promise; ch.5 documents it as written here):

```toml
# <name>.toml
extends = "default"     # optional

[[rules]]
pattern = '\bKARTE \d+'

[[rules]]
pattern = '\bREF \d+'
```

- Top-level keys: `rules`, an array of tables, and optionally `extends`, a string. A
  file with no `[[rules]]` is a profile with no rules of its own.
- Each rule table has exactly one key, `pattern`: a string in Python `re` syntax,
  compiled at `load` **with `re.IGNORECASE`**, so the case of a pattern does not matter.
  The memo is upper-cased before matching (below), so tokens are upper case either way.
  TOML literal strings (`'…'`) keep backslashes as written.
- **`extends`** names another profile (package or user). A profile's *effective rules*
  are its own rules in file order, followed by the effective rules of the profile it
  extends. The name is resolved against the effective profile set, i.e. **after** user
  overrides: a user `default.toml` therefore also changes every profile that extends
  `default`, including the package `sepa`. Chains are allowed. A name that does not
  exist, a profile that extends itself, or a longer cycle raises `NormaliserError`.
- Any other key, at the top level or in a rule, a non-string `pattern` or `extends`, or
  a pattern that does not compile raises `NormaliserError` naming the file (a typo must
  never silently become a rule that does nothing).
- `accounts` is reserved: `accounts.toml` is the mapping file below, never a profile.

Normalising a memo with a profile, in this order: upper-case it (`str.upper()`), apply
the profile's effective rules in order, collapse runs of whitespace to one space, strip
both ends. The result is the token. It may be empty when the memo is all noise; that is
allowed (#24 treats an empty token as having no neighbour).

Package profiles live in `src/autobook/pipeline/profiles/` (a data directory with no
`__init__.py`, so `pkgutil` does not see it as a building block) and are read through
`importlib.resources.files("autobook.pipeline")`, so they work both from an installed
wheel (hatch includes non-Python files under `src/autobook`) and from `src/` on
`PYTHONPATH` (how C4-verify runs). Two ship:

- `default` strips noise in general form, not as literal strings. In this order:
  1. the `SAGT DANKE` boilerplate;
  2. card fragments (`KARTE <digits>`);
  3. reference fragments (`REF <digits>`, `NR. <digits>`, `NR.<digits>`);
  4. ISO dates with optional time (`2025-03-05`, `2025-03-05T10:11`, `2025-03-05T10:11:12`);
  5. clock times (`10:11`, `10:11:12`);
  6. day-month dates (`DD.MM.`, `DD.MM.YYYY`);
  7. month-year (`01.2025`);
  8. standalone digit runs;
  9. whitespace-delimited fragments made only of punctuation (the ` . ` or ` - ` left
     behind by the rules above; `//MUENCHEN/DE` is not touched because it has letters).

  Multi-word merchant names survive intact (`MUSTER HAUSVERWALTUNG`, `BEISPIEL
  ARBEITGEBER GMBH`, `TESTHOF GEMUESE`). Checked at Plan: these rules map all 334 rows of
  seeds 0–2 to their merchant name. Rules 4–5 must run before 6–8, or the digit-run rule
  leaves `- -05T10: :` behind.
- `sepa` is `extends = "default"` plus only the SEPA rules. The full SEPA tag set (the
  structured-purpose tags of the German MT940 field 86 / CAMT export) is
  `EREF+ KREF+ MREF+ CRED+ DEBT+ COAM+ OAMT+ SVWZ+ ABWA+ ABWE+ IBAN+ BIC+ BREF+ RREF+ PURP+`.
  Every tag in the set marks the end of the previous tag's value. A tag is found
  **without** a word boundary in front, because some exports glue the fields
  (`EREF+NOTPROVIDEDSVWZ+…`). Each tag is handled one of two ways:

  | Tags | Handling | Why |
  |------|----------|-----|
  | `SVWZ+`, `CRED+`, `ABWA+`, `ABWE+` | remove the tag, **keep the value** (the `default` rules then clean it) | They tell merchants apart: the purpose text, the creditor ID (a registered business identifier, allowed in shareable data by ch.8 §8.5 and proposal 0001 *Rules*), the ultimate debtor and the ultimate creditor (the real payee when a provider pays on a merchant's behalf). |
  | `EREF+`, `KREF+`, `MREF+`, `DEBT+`, `COAM+`, `OAMT+`, `IBAN+`, `BIC+`, `BREF+`, `RREF+`, `PURP+` | remove the tag **and its value**, up to the next tag of the full set or the end | References and amounts change from one payment to the next. An IBAN must never reach the model adapter (ch.8 §8.5) and may belong to a person (proposal 0001 *Rules*). `DEBT+` (originator ID) may identify a person. A BIC names a bank, not a merchant. |

  So the `sepa` rules are: first one rule removing every dropped tag with its value (a
  lazy match up to a lookahead on the full tag set or `\Z`), then one rule removing the
  kept tags. Results checked at Plan with these rules (and `default`):
  `EREF+1 CRED+DE98ZZZ01111111111 SVWZ+MITGLIEDSBEITRAG 01.2025` →
  `DE98ZZZ01111111111 MITGLIEDSBEITRAG`;
  `SVWZ+ZAHLUNG 1234 ABWA+MUSTERBAECKEREI` → `ZAHLUNG MUSTERBAECKEREI`;
  `SVWZ+BEISPIELMARKT IBAN+DE00ZZZ BIC+TESTDEFF` → `BEISPIELMARKT`;
  `SVWZ+BEISPIELMARKT//MUENCHEN/DE 2025-03-05T10:11:12` → `BEISPIELMARKT//MUENCHEN/DE`.

  Known limit, recorded on purpose: a value kept from `ABWA+`/`ABWE+` (and the `SVWZ+`
  text) can be a person's name, and an IBAN typed into the `SVWZ+` text by the sender is
  not removed (a generic IBAN-shape rule would also remove creditor IDs, which have the
  same shape). This matches proposal 0001 *Community contribution* ("Normalised memos
  routinely still carry counterparty names … Normalisation strips some and cannot
  guarantee all"); the guard is the adapter boundary (ch.8 §8.5), which sends a token to
  a remote backend only if it matches a pack entry or the user's allowlist.

The raw memo is never changed or discarded: it is returned in `NormalisedMemo.raw_memo`,
and `CorpusRow.raw_memo` stays the stored form. No normalisation happens anywhere else.

### User directory: overrides and the account mapping

- A `<name>.toml` in the user directory **replaces** the package profile of the same
  name entirely (no merge). A user file with a new name adds a profile. Because
  `extends` resolves after overrides, replacing `default` also changes `sepa`; to change
  only `sepa`-mapped accounts, the user overrides `sepa`.
- `accounts.toml` in the user directory maps source accounts to profile names, each
  entry an account **path as a list of components** (never a separator-joined string,
  as in the contracts: ch.5 §5.1) and a profile name. The layout is fixed here:

  ```toml
  # accounts.toml
  [[accounts]]
  path = ["Aktiva", "Girokonto"]
  profile = "sepa"
  ```

  The only top-level key is `accounts`, an array of tables; each has exactly `path` (a
  non-empty array of non-empty strings) and `profile` (a string).
- An account with no mapping uses `default`. The package itself maps no account (it
  cannot know the user's account names).
- **What `load` reads from the user directory** (top level only, no recursion):
  - An entry whose name ends in exactly `.toml` (lower case) and does not start with `.`
    is a profile file (or `accounts.toml`). It must be a regular file, or a symlink to
    one; anything else with that name (a directory, a dangling symlink) raises
    `NormaliserError`.
  - Every other entry is ignored and does not enter the version: subdirectories,
    dotfiles, editor backups (`sepa.toml~`, `sepa.toml.bak`), other suffixes (`sepa.tml`,
    `SEPA.TOML`), a `README`. A misspelled suffix is not caught; that is accepted, since
    ignoring other files is what lets a user keep notes and backups next to the profiles.
  - Profile names are case-sensitive: `Default.toml` is a profile named `Default`, not an
    override of `default`.
  - **A user profile must be used.** A user profile whose name is not a package profile
    name (`default`, `sepa`), is not named by any `accounts.toml` entry, and is not named
    by any profile's `extends`, raises `NormaliserError` naming the file. This is what
    catches `defualt.toml` and `Default.toml`: they would otherwise add a profile nothing
    uses while the package `default` silently keeps applying. Package profiles are exempt
    (`sepa` ships unmapped).

### Errors (all `NormaliserError`, raised at `load` unless noted)

An unreadable or invalid profile or `accounts.toml` file; an unknown key or wrong type
in either; a pattern that does not compile; an `extends` naming an unknown profile, or a
cycle; a mapping naming a profile that does not exist; the same account mapped twice;
a user directory that exists but cannot be listed (list it with `os.scandir` or
`iterdir` inside a `try` that maps `OSError` to `NormaliserError`, since `Path.glob`
swallows `PermissionError`); a user directory path that is a dangling symlink (on
`FileNotFoundError`, return "no user files" only if `not os.path.lexists(directory)`);
a user directory path that is a file; a `*.toml` entry that is not a regular file; a
user profile that nothing uses (above). At `normalise`: a malformed `source_account`
(not a non-empty tuple of non-empty strings). Error messages never contain a memo.

### Version

`Normaliser.version` is a string built from `NORMALISER_VERSION` and a SHA-256 digest
of a canonical serialisation of everything that affects a token: the **effective**
rules of every profile (name and resolved rule list, in order), the account mapping,
and the interpreter's Unicode database version (`unicodedata.unidata_version`, read at
`load` through the module attribute, not imported by name, so a test can patch it):
`str.upper()` and the regex classes `\d`, `\b`, `\s` depend on it, and CI runs Python
3.11–3.14, which ship different Unicode versions. Canonical means sorted by profile name
and by account path, so the version does not depend on file system order, modification
times, or the directory's path (no path, file name other than the profile name, or
timestamp enters the serialisation). Entries the listing ignores (see *User directory*)
never enter it. Format: `"<NORMALISER_VERSION>-<first 12 hex
digits>"`. Consequences the tests pin: same files → same version, also from a different
directory; one changed rule, mapping line or Unicode version → a different version;
every `NormalisedMemo.version` equals `Normaliser.version`.

**One global version, on purpose.** Any change to any profile or any mapping line gives a
new `Normaliser.version` for every account, including accounts whose tokens did not
change. That costs nothing extra: proposal 0001 rebuilds the whole kNN index every run
("Rebuild the whole index each run — cheaper than any incremental scheme",
`docs/design/proposals/draft/0001-gnucash-auto-booking-pipeline.md:320`), so no stored
per-partition vectors outlive a run and wait to be invalidated. A backtest re-run after a
mapping change is the cost, and is what the version gate is there to force. A per-profile
or per-account version is **not** part of this API; if it is ever wanted it would be a
new attribute next to `version`, not a change to what `version` means. The "must be
used" rule (*User directory*) keeps unused user profiles from changing the version.

**The recorded value is `Normaliser.version` (the string), not `NORMALISER_VERSION`.**
The issue's scope line says "`NORMALISER_VERSION`, recorded with every vector and in the
version tuple"; this design deliberately narrows that, because the int alone would miss
a user's profile edit (ch.8 §8.8: every configuration value that can change a
classification is part of the version tuple). So `Normaliser.version` is what #24
records with every vector, what the version tuple (ch.8 §8.3) will record, and what the
future `proposals.normaliser_version` staging column (ch.5) will hold. Nothing in this
slice builds the tuple or the column. The PR description must state this mapping from
the issue's wording.

### Tests and the gate (C4-verify requirements: read this before writing a test)

- `tests/test_normaliser.py`: success criterion (a)–(e). Also pin every case under
  *Errors* (the unreadable directory with `chmod 0o300`, the dangling directory symlink,
  an `extends` cycle and an unknown `extends` name), the relative `XDG_CONFIG_HOME`
  fallback via `monkeypatch.setenv`, and that `repr(result)` does not contain the memo.
  - (b): write the SEPA memos in the test. Every value is invented. A creditor ID
    shape such as `DE98ZZZ09999999999` is fine (the `ZZZ` marks it as synthetic). The
    `IBAN+` value must be visibly fake (`DE00ZZZ…`-style), never a valid-looking IBAN.
  - (c): create the user profiles and `accounts.toml` in `tmp_path` in the test.
  - Every user profile a test writes must override a package profile or be mapped /
    extended, or `load` raises (the "must be used" rule). Pin that rule itself
    (`defualt.toml` alone raises; `Default.toml` alone raises), and that ignored entries
    (`sepa.toml~`, a subdirectory, `notes.txt`) neither raise nor change the version.
  - (d): patch `unicodedata.unidata_version` with `monkeypatch.setattr` and compare two
    `load` results.
- `tests/test_skeleton.py`: add an explicit set of implemented building blocks,
  `IMPLEMENTED = {"autobook.pipeline.normaliser"}`. In
  `test_every_block_has_one_entry_point_that_is_not_implemented`, a module in
  `IMPLEMENTED` skips **all three** assertions of the loop body: `len(__all__) == 1`, the
  `callable` check and the `NotImplementedError` check (#24 and #25 rely on this: their
  modules export several names). Every other check (module count, staging placement, no
  `gnucash` import) still covers every module, the normaliser included. #24 and #25 add
  their modules to the same set.

Rules every test file in this patch must follow, or the gate cannot judge it:

1. **Import only modules that exist on `origin/main` at module scope**, as modules
   (`import autobook.pipeline.normaliser as normaliser`, `from tests.fixtures.synthetic
   import corpus_builder`). Reach every name this patch adds through the module object
   inside the test body (`normaliser.load(...)`). Never `from autobook.pipeline.normaliser
   import <new name>` at module scope: on the red leg that is a collection error, which
   the gate reports as UNVERIFIABLE, not red. Annotate the module as `Any` where mypy
   needs it (`tests/test_skeleton.py:45` does the same).
2. **Keep the words `applier` and `live_paperless` out of every test file.** The gate
   greps test files for them and then starts Autobook's Docker test environment, which
   this cycle does not need.
3. **No `pytest.importorskip`, no skips.** A leg in which nothing ran is UNVERIFIABLE.

### Docs currency (same PR)

AGENTS.md and ch.8 §8.9 require it for a new configuration key: update ch.5 §5.2
*Normaliser* (API, profile format with `extends` and case-insensitive patterns, the two
package profiles with the SEPA tag table, the user directory, mapping file, override
rule, version rule including the Unicode version) and ch.8 §8.8 (the normaliser
directory under `$XDG_CONFIG_HOME/autobook/`). ch.5 must not describe `sepa` as a copy
of `default`: it extends it. The current ch.5 sentence "Strips SEPA boilerplate (`EREF+`,
`MREF+`, `CRED+`, `SVWZ+`, `ABWA+`) …" (`05-building-block-view.md:134`) is replaced by
the tag table.

Proposal 0001 says the same thing at
`docs/design/proposals/draft/0001-gnucash-auto-booking-pipeline.md:392`. It is still a
**draft** (under `proposals/draft/`), so AGENTS.md's "supersede, never rewrite" rule
(which applies once a proposal is accepted) does not apply, and it may be edited. Change
only that sentence: say the SEPA tags are removed, that reference, amount, IBAN and BIC
values are dropped, and that the purpose text, creditor ID and ultimate debtor/creditor
names are kept because they tell merchants apart; point to ch.5 §5.2 for the full table.
Do not touch the rest of the proposal. This in-repo edit plus the PR description are the
record of the v3 sign-off decision to keep `CRED+`/`ABWA+` values. `nox -s gate` runs the docs lint and `typos`. If `typos`
flags an invented German word, add it to `typos.toml` with a reason, as existing entries
do.

## Alternatives considered

- **A hand-bumped version constant only.** Rejected: a user editing a profile would
  change every token without changing the version, which is exactly what the version
  gate exists to catch (issue's "Done when": changing a rule changes the version).
- **Merging a user profile into the package profile.** Rejected (decided with the
  maintainer at Plan): whole-file replacement is predictable, and the version shows the
  result either way.
- **`sepa` repeats the `default` rules, no `extends`** (v3). Rejected at the v3
  sign-off: a user's `default` override did not reach `sepa`-mapped accounts, ch.5's
  "`default`, plus …" misled, and the copy needed a drift test.
- **Remove `CRED+` and `ABWA+` with their values** (v1–v3, from the proposal's
  boilerplate list). Rejected at the v3 sign-off: two creditors with the same purpose
  text (`MITGLIEDSBEITRAG`) collapsed to one token, making a new merchant look familiar.
- **Reject lower-case patterns instead of matching case-insensitively.** Rejected: hard
  to detect reliably (`\d`, `\b`, `[a-z]`), and `IGNORECASE` makes the question moot.
- **Strip IBAN-shaped text anywhere.** Rejected: creditor IDs have the same shape and
  must survive; privacy for remote backends is enforced at the adapter boundary.
- **Profiles keyed directly by account inside each profile file.** Rejected: one
  mapping file keeps "which account uses what" in one place, and lets a shared profile
  (a bank format) carry no personal account names.
- **Unmapped accounts are an error.** Rejected: normalising never books anything; the
  generic `default` profile is a safe start, and mapping is how a user refines it.

## Impact & compatibility

New behaviour behind an existing stub; the stub entry point `normalise()` is replaced.
No new runtime dependency. Reads files only from the package and the user directory;
writes nothing. Expect the advisory `T2-threat-model` check to stay quiet: `normaliser.py`
matches none of its path patterns. A user-supplied regular expression is a new input,
but a slow pattern only slows the user's own run (trusted config, rated Low). The v3
security review found the v3 rules linear on 200 kB hostile memos; the v4 rule set
(both profiles, as specified above) was timed at Plan on the same kind of input (long
tag, digit, punctuation, `2025-`, `1:` and repeated-tag runs): each under 0.05 s. The
punctuation-only rule turns `M & S` into `M S`; accepted, the letters survive. Keeping
`ABWA+`/`ABWE+` names in tokens does not widen what leaves the machine: the adapter
boundary (ch.8 §8.5) is unchanged.

## Open questions

None open. Settled with the maintainer (eduralph) in the Plan sessions: named TOML
profiles, user directory `$XDG_CONFIG_HOME/autobook/normaliser/`, whole-file override,
`accounts.toml` mapping with `default` as fallback, version = code constant + digest of
the effective profiles, mapping and Unicode version, and the two TOML layouts (now with
the optional `extends` key). Settled at this re-plan: the SEPA tag table above, keeping
`CRED+`/`ABWA+`/`ABWE+` values, the new `default` rules (ISO date/time, clock time,
month-year, punctuation-only fragments), `extends` resolved after overrides,
case-insensitive patterns, and the Unicode version in the digest. These are not on the
issue thread (`notes.json` has no comments); the PR description must state them,
including that `Normaliser.version` (not the `NORMALISER_VERSION` int) is the recorded
value. Decided at the plan-review revision and confirmed by the maintainer in the same
session: the user-directory listing rules, including the "a user profile must be used"
error; the one global version.

## Changes from v3

1. SEPA tag set widened from 5 to 15 tags; every tag ends the previous value.
2. `CRED+`, `ABWA+`, `ABWE+` keep their values; `IBAN+`, `BIC+`, `KREF+`, `DEBT+` and
   the others are dropped with their values.
3. `default` gains ISO date/time, clock-time, month-year and punctuation-only rules.
4. New optional `extends` key; `sepa` extends `default` and no longer copies its rules
   (drop v3's "sepa ends with exactly the default rules" test).
5. Patterns compile with `re.IGNORECASE`.
6. `unicodedata.unidata_version` enters the version digest.
7. `NormalisedMemo.raw_memo` is `field(repr=False)` (v3 security-review hardening note).
8. Criterion (b), (c), (d) extended and (e) added to pin 1–6.
9. (Plan-review revision) User-directory listing rules pinned, including "a user profile
   must be used"; the version is stated as deliberately global; proposal 0001's SEPA
   sentence joins the docs scope.

Plan-review response: (1) proposal 0001 contradiction: fixed. It is a draft, so its one SEPA sentence is corrected in this PR alongside ch.5 (*Docs currency*); together with the PR description that is the in-repo record of the v3 sign-off decision. Posting it on issue #23 as well is the human's choice at sign-off, not something Do or the brief can do. (2) user-directory listing: fixed, pinned under *User directory* and *Errors*, with tests. The "must be used" error was proposed at this revision and confirmed by the maintainer. (3) global version: stands, now stated with its reason (the index is rebuilt every run, proposal 0001:320) and with the note that a per-profile version would be a new attribute, not a change to `version`. (4) `extends` in this slice: stands. It is not scope creep: the maintainer rejected v3 at sign-off because a user's `default` override did not reach `sepa` accounts and `sepa` was a hand-kept copy (*Alternatives considered*); `extends` is the fix for that rejection, and deferring it means shipping the design that was already rejected. It is one optional key with three error cases. (5) red-leg evidence: re-checked with git at this revision (see *Falsifiability*): gate config last changed before the v3 run, base still 76bacce.

## STOP discipline

Draft only until Check sign-off. Pushing to a feature/draft branch and opening a
draft PR MAY happen during the cycle (useful for CI feedback). The PR MUST NOT be
marked ready before sign-off accepts.
