# Design proposal — issue 23 / normaliser-profiles-version

> Plan artifact for Ralphovi/autobook#23 (build order 2b, milestone `03 · 2 — Premise`).
> The design is settled in proposal 0001 (*Normalisation*), architecture ch.5 (§5.2
> *Normaliser*) and ch.8 (§8.3, §8.4, §8.8). This proposal fixes what those leave open
> (profile file format, user directory, override rule, how the version is derived, the
> public API that #24 and #25 build on) so Do does not re-decide it. Do reads ONLY this file.

- **Slug:** normaliser-profiles-version
- **Kind:** enhancement (design proposal)
- **Goal:** Turn a raw bank memo into a stable merchant token, in one place in the pipeline, driven by named per-source-account profiles (shipped in the package, overridable from a user directory), with a normaliser version that changes whenever anything that affects the output changes, carried on every normalised result.
- **Success criterion:** `tests/test_normaliser.py` passes with the patch applied and fails, with tests that RUN (not a collection error), with the production change reverted. It must assert: (a) with an empty user directory, for every row of `build_corpus(seed)` for seeds 0, 1 and 2 (`tests/fixtures/synthetic/corpus_builder.py`), the token equals that row's merchant name (`Merchant.token` of the merchant whose name starts the memo, or `NOVEL_MERCHANT`); (b) synthetic SEPA memos, normalised for a source account the user directory maps to the `sepa` profile, give the expected token, and none of `EREF+`, `MREF+`, `CRED+`, `SVWZ+`, `ABWA+` survives in any token; (c) a user-directory profile with the same name as a package profile replaces it (a memo the package profile reduces to one token gives a different, expected token), and with that user file absent the package profile applies again; (d) two loads of the same profiles give the same `version`, including identical profile and `accounts.toml` files written into two *different* user directories (two separate subdirectories of `tmp_path`), so no path enters the digest; changing one rule in a user profile, or one line of the account mapping, gives a different `version`; every result carries the normaliser's `version` and the unchanged `raw_memo`.
- **Falsifiability:** RED is reachable on the C4-verify gate (`engine/scripts/run-verify.sh`: host pytest in `$PDCA_WORKTREE` on the instance `.venv`, `-m "not applier and not live_paperless"`). Its red leg reverts every non-test hunk, so `src/autobook/pipeline/normaliser.py` returns to the stub on `origin/main` (76bacce), which exposes only `normalise()` raising `NotImplementedError`. The module still exists, so a test that imports `autobook.pipeline.normaliser` at module scope collects, and the first call to `normaliser.load(...)` raises `AttributeError` inside the test body: a test that RAN and FAILED. Checked at Plan with a scratch probe on an `origin/main` export under the same interpreter and flags: 3 ran, 3 failed, 0 collection errors. A module-scope `from autobook.pipeline.normaliser import load` would instead be a collection error (UNVERIFIABLE, §6), so the import rule under *Tests and the gate* is binding.
- **Invariant to restore:** All memo normalisation happens in one pipeline component, driven by data (profiles) rather than code, and any change to what that component outputs for any memo shows up as a different normaliser version, so no vector, backtest or proposal can silently mix two normalisations. Sources: AGENTS.md *Classification rules* ("Normalisation lives in the pipeline, never in an ofxstatement plugin"; "The normaliser version is part of the gate tuple. Changing it changes what every vector means"); ch.8 §8.4 ("Normalisation is data, and lives in one place"); proposal 0001 *Normalisation*.
- **Repo + branch target:** Ralphovi/autobook @ main
- **Depends on:** none
- **Conflicts with:** none
- **Ordering note:** #22 (its prerequisite) is merged (PR #49, 76bacce on `origin/main`). First wave of the chain #23 → #24 → #25: #24 normalises through this API, #25 through both. All three edit `tests/test_skeleton.py` and `docs/design/architecture/05-building-block-view.md`; the `Depends on` chain already puts them in separate waves, each folded onto the next one's base.
- **Surfaces:** data
- **Difficulty:** medium — one module made real (`src/autobook/pipeline/normaliser.py`), two new package-data profile files, one test file, a small change to `tests/test_skeleton.py`, and ch.5/ch.8 docs. No existing caller. Rated up from low because #24 and #25 build on this public API and its version rule.
- **Scope:** (1) the normaliser in `src/autobook/pipeline/normaliser.py`, with the API, profile format, override rule and version rule below; (2) two package profiles, `default` and `sepa`, as TOML files in `src/autobook/pipeline/profiles/`; (3) `tests/test_normaliser.py`; (4) `tests/test_skeleton.py` exempts the normaliser from the stub checks (below); (5) docs currency: ch.5 §5.2 *Normaliser* and ch.8 §8.8 record the profile format, the user directory, the mapping file, the override rule and the version rule. / out of scope: assembling the version tuple or the batch gate that compares it (no code for either exists yet; this slice only provides the value); any staging column write (`normaliser_version` in `proposals` arrives with staging, build step 3); bank profiles beyond `default` and `sepa` (Revolut, PayPal …); PayPal pass-through merchant parsing (correlator); any ofxstatement plugin; the kNN index (#24) and backtest (#25); new runtime dependencies (`tomllib` is in the standard library from Python 3.11, the minimum).
- **External dependencies:** none
- **Test file:** tests/test_normaliser.py
- **Citations expected:** Do must cite path:line on the target branch for every change it builds on: the stub `src/autobook/pipeline/normaliser.py` it replaces; `tests/test_skeleton.py:43-50` (the stub check it narrows); `tests/fixtures/synthetic/corpus_builder.py` (`MERCHANTS`, `NOVEL_MERCHANT`, `NOISE`, `GIROKONTO`); `src/autobook/contracts.py` (`CorpusRow`, account paths as `tuple[str, ...]`); `pyproject.toml` (ruff selection incl. `S`, `PL`, `T20`; mypy `strict`); ch.5 §5.2 *Normaliser* and ch.8 §8.4/§8.8. Peer for the "reject loudly with a module error" pattern: `ContractError` in `src/autobook/contracts.py:110`, a `ValueError` subclass; mirror it as `NormaliserError`.
- **Prior-art check (triage cycles):** searched by path. `git -C ../autobook log --all -- src/autobook/pipeline tests/test_skeleton.py pyproject.toml` shows only the scaffold (0e0b7dc), a docs commit (2baf4d6), testenv (2a4b845) and #22's skeleton (23ce73f); the normaliser is a stub. `gh pr list --state all` (8 PRs, all merged) has nothing on normalisation. Closed issue #5 (step 2, `NOT_PLANNED`) was split into #22–#26, not rejected; its normalisation scope is this issue's. Nothing to reuse beyond #22's fixtures.
- **Disposition hint:** new-feature

## Motivation

Classification quality depends more on memo preprocessing than on k or the metric
(proposal 0001). The kNN index (#24) and the backtest (#25) need a stable token per
memo, and they need to know when the meaning of that token changed. Normalisation is
the part tuned most, so it must be data that a user can change without a release, and
every change must be visible as a new version.

## Design

### Public API (fixed: #24 and #25 are briefed against it)

All in `autobook.pipeline.normaliser`. `__all__` lists exactly these names:

- `NORMALISER_VERSION: Final[int]`: the code's algorithm version, starting at `1`.
  Bump it when the code (not a profile) changes what a token looks like. It is one
  *input* to `Normaliser.version` and is **never recorded on its own** (see *Version*).
- `class NormaliserError(ValueError)`: every bad input (unreadable or invalid profile
  file, invalid regular expression, unknown profile named in the mapping, malformed
  account path) raises this, with the file and what is wrong. Never a silent fallback.
- `@dataclass(frozen=True) class NormalisedMemo`: `raw_memo: str` (unchanged input),
  `token: str`, `profile: str` (name of the profile used), `version: str`.
- `class Normaliser`: built only by `load`. Attribute `version: str`. Method
  `normalise(raw_memo: str, source_account: tuple[str, ...]) -> NormalisedMemo`.
- `load(user_dir: pathlib.Path | None = None) -> Normaliser`. `None` means the default
  user directory: `$XDG_CONFIG_HOME/autobook/normaliser/`, or
  `~/.config/autobook/normaliser/` when `XDG_CONFIG_HOME` is unset or empty (ch.8 §8.8:
  configuration is TOML under `$XDG_CONFIG_HOME/autobook/`). A missing directory is
  allowed and means "package profiles only, no mapping". Tests always pass an explicit
  `tmp_path` and never read the real user directory.

The old stub entry point `normalise()` goes away (it is replaced by the API above).

### Profiles

A profile is a named, ordered list of rules. Each rule is a regular expression whose
matches are removed (replaced by a space). The name of a profile is its file name
without `.toml`. The file layout is fixed here (users write these files by hand, so it
is a compatibility promise; ch.5 documents it as written here):

```toml
# <name>.toml
[[rules]]
pattern = '\bKARTE \d+'

[[rules]]
pattern = '\bREF \d+'
```

- The only top-level key is `rules`, an array of tables. A file with no `[[rules]]` is
  an empty profile (upper-casing and whitespace collapsing only).
- Each rule table has exactly one key, `pattern`: a string in Python `re` syntax,
  compiled at `load`, matched against the **upper-cased** memo (so patterns are written
  in upper case). TOML literal strings (`'…'`) keep backslashes as written.
- Any other key, at the top level or in a rule, a non-string `pattern`, or a pattern
  that does not compile raises `NormaliserError` naming the file (a typo must never
  silently become a rule that does nothing).
- `accounts` is reserved: `accounts.toml` is the mapping file below, never a profile.

Normalising a memo with a profile, in this order: upper-case it (`str.upper()`), apply
the profile's rules in file order, collapse runs of whitespace to one space, strip both
ends. The result is the token. It may be empty when the memo is all noise; that is
allowed (#24 treats an empty token as having no neighbour).

Package profiles live in `src/autobook/pipeline/profiles/` (a data directory with no
`__init__.py`, so `pkgutil` does not see it as a building block: checked at Plan) and are
read through `importlib.resources.files("autobook.pipeline")`, so they work both from an
installed wheel (hatch includes non-Python files under `src/autobook`) and from `src/`
on `PYTHONPATH` (how C4-verify runs). Two ship:

- `default`: strips the noise in `corpus_builder.NOISE`, in general form, not as literal
  strings: card fragments (`KARTE <digits>`), reference fragments (`REF <digits>`,
  `NR. <digits>`), embedded dates (`DD.MM.`, `DD.MM.YYYY`), standalone digit runs,
  and the `SAGT DANKE` boilerplate. Multi-word merchant names survive intact
  (`MUSTER HAUSVERWALTUNG`, `BEISPIEL ARBEITGEBER GMBH`, `TESTHOF GEMUESE`).
- `sepa`: everything `default` does, plus the SEPA fields. For `EREF+`, `MREF+`,
  `CRED+` and `ABWA+`, remove the tag **and its value** (up to the next SEPA tag or the
  end). For `SVWZ+` (the payment purpose text), remove only the tag and keep the text,
  which the other rules then clean.

The raw memo is never changed or discarded: it is returned in `NormalisedMemo.raw_memo`,
and `CorpusRow.raw_memo` stays the stored form. No normalisation happens anywhere else.

### User directory: overrides and the account mapping

- A `<name>.toml` in the user directory **replaces** the package profile of the same
  name entirely (no merge). A user file with a new name adds a profile.
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
  non-empty array of non-empty strings) and `profile` (a string). Any other key, a
  wrong type, a mapping that names a profile that does not exist, or the same account
  twice raises `NormaliserError` at `load`.
- An account with no mapping uses `default`. The package itself maps no account (it
  cannot know the user's account names).

### Version

`Normaliser.version` is a string built from `NORMALISER_VERSION` and a SHA-256 digest
of a canonical serialisation of everything in effect: every effective profile (name and
rules, in order) and the account mapping. Canonical means sorted by profile name and by
account path, so the version does not depend on file system order, modification times,
or the directory's path (no path, file name other than the profile name, or timestamp
enters the serialisation). Format: `"<NORMALISER_VERSION>-<first 12 hex digits>"`.
Consequences the tests pin: same files → same version, also from a different directory;
one changed rule or mapping line → a different version; every `NormalisedMemo.version`
equals `Normaliser.version`.

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

- `tests/test_normaliser.py`: success criterion (a)–(d), plus anything else above that
  Do considers worth pinning (`NormaliserError` cases, `XDG_CONFIG_HOME` resolution via
  `monkeypatch.setenv`, whitespace and case).
  - (b): write the SEPA memos in the test. Every value is invented. A creditor ID
    shape such as `DE98ZZZ09999999999` is fine (the `ZZZ` marks it as synthetic);
    no IBAN-shaped strings.
  - (c): create the user profile in `tmp_path` in the test.
- `tests/test_skeleton.py`: add an explicit set of implemented building blocks,
  `IMPLEMENTED = {"autobook.pipeline.normaliser"}`. In
  `test_every_block_has_one_entry_point_that_is_not_implemented`, a module in
  `IMPLEMENTED` skips **all three** assertions of the loop body: `len(__all__) == 1`, the
  `callable` check and the `NotImplementedError` check (#24 and #25 rely on this: their
  modules export several names). Every other check (module count, staging placement, no `gnucash`
  import) still covers every module, the normaliser included. #24 and #25 add their
  modules to the same set.

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
*Normaliser* (API, profile format, the two package profiles, user directory, mapping
file, override rule, version rule) and ch.8 §8.8 (the normaliser directory under
`$XDG_CONFIG_HOME/autobook/`). `nox -s gate` runs the docs lint and `typos`. If `typos`
flags an invented German word, add it to `typos.toml` with a reason, as existing entries
do.

## Alternatives considered

- **A hand-bumped version constant only.** Rejected: a user editing a profile would
  change every token without changing the version, which is exactly what the version
  gate exists to catch (issue's "Done when": changing a rule changes the version).
- **Merging a user profile into the package profile.** Rejected (decided with the
  maintainer at Plan): whole-file replacement is predictable, and the version shows the
  result either way.
- **Profiles keyed directly by account inside each profile file.** Rejected: one
  mapping file keeps "which account uses what" in one place, and lets a shared profile
  (a bank format) carry no personal account names.
- **Unmapped accounts are an error.** Rejected: normalising never books anything; the
  generic `default` profile is a safe start, and mapping is how a user refines it.

## Impact & compatibility

New behaviour behind an existing stub; the stub entry point `normalise()` is replaced.
No new runtime dependency. Reads files only from the package and the user directory;
writes nothing. Expect the advisory `T2-threat-model` check to stay quiet:
`normaliser.py` matches none of its path patterns (checked against
`engine/scripts/check-threat-model-touch.sh`), though a user-supplied regular expression
is a new input. A pathological pattern can only slow the user's own run (a local,
self-inflicted input), so no threat-model change is expected; that is a sign-off call.

## Open questions

None open. Settled with the maintainer (eduralph) in the Plan session: named TOML
profiles, user directory `$XDG_CONFIG_HOME/autobook/normaliser/`, whole-file override,
`accounts.toml` mapping with `default` as fallback, version = code constant + digest of
the effective profiles and mapping. These are not on the issue thread (`notes.json` has
no comments); the PR description must state them, including that `Normaliser.version`
(not the `NORMALISER_VERSION` int) is the recorded value. The two TOML layouts were
fixed in the plan-review revision (see *Profiles*, *User directory*); sign-off confirms
them, since they become a promise to users.

Plan-review response: (1) criterion (d) now requires the same `version` from two
different directories; (2) *Version* states that `Normaliser.version` is the recorded
value and the PR must say so; (3) both TOML layouts are now fixed in this brief, not
left to Do; (4) base verified at revision: `git -C ../autobook log origin/main` shows
`76bacce` as the merge of PR #49, and `gh pr view 49` reports MERGED with merge commit
`76baccee40f2`, so `Depends on: none` stands. The skeleton exemption is also now
explicit about all three assertions, which #24 and #25 rely on.

## STOP discipline

Draft only until Check sign-off. Pushing to a feature/draft branch and opening a
draft PR MAY happen during the cycle (useful for CI feedback). The PR MUST NOT be
marked ready before sign-off accepts.

## Iteration 1 — carry-forward (from the previous attempt)
- Sign-off rationale: Auto-iterate (round 1): rebuilding for the implementation-level findings — C5 Causal adequacy — Fix unreadable-directory fallback and adjacent-tag parsing before relying on these profiles downstream: both produce incorrect tokens despite green tests; src/autobook/pipeline/normaliser.py:108 and src/autobook/pipeline/profiles/sepa.toml:7; reproduced in reviewer-edge-cases.log:3 and reviewer-edge-cases.log:6.; `target/src/autobook/pipeline/profiles/sepa.toml:7` and `:11`: the `\b` in front of each tag in the lookahead (and in the `SVWZ+` rule) means a tag glued to the previous value is not seen as a tag. Then the `EREF+`/`MREF+`/`CRED+`/`ABWA+` value runs on to the end of the memo and the merchant is deleted. Concrete cases, run against the production loader with `Aktiva/Girokonto` mapped to `sepa`:; `target/src/autobook/pipeline/normaliser.py:105-108`: a user directory that exists but cannot be read (mode `0300`) loads with no error. `Path.glob` swallows the `PermissionError` and returns nothing. The result is package profiles only, with the same version as package-only (`1-63b3ea5b316e` both ways), so the user's `accounts.toml` and overrides are dropped without a word. The brief says "unreadable … profile file … raises `NormaliserError`. Never a silent fallback." An unreadable *file* does raise correctly (`_read_toml`, `:149`). Fix: list the directory with `os.scandir`/`iterdir` inside a `try` that maps `OSError` to `NormaliserError`, and add a test with `chmod 0o300`.; `target/src/autobook/pipeline/profiles/sepa.toml:3` relies on a comment ("keep the two files in step") to keep the copied `default` rules in `sepa` equal to `default.toml`. No test checks this. If someone edits `default.toml:23-26` and not `sepa.toml`, behaviour drifts with no test going red. The version still changes, so it is not hidden from the gate tuple, only from tests. Fix: one test that `sepa`'s rules end with exactly `default`'s rules.. Deferred, not addressed here: 6 finding(s) that need human judgment, held in deferred-findings.json for the human at handover — not build work
- Full previous attempt preserved in `iteration-v1/` (patch.diff, build-notes.md, SUMMARY.md, check-*).
- Address the above; do NOT re-attempt the rejected approach unchanged. Satisfy the brief's Success criterion (the end result).

## Iteration 2 — carry-forward (from the previous attempt)
- Sign-off rationale: Auto-iterate (round 2): rebuilding for the implementation-level findings — `src/autobook/pipeline/normaliser.py:148-149`: if the user directory is a **broken symlink**, the loader silently treats it as missing. `os.scandir` raises `FileNotFoundError` for a link whose target is gone, and that error is mapped to "no user files". Reproduced: `~/.config/autobook/normaliser` → a dotfiles checkout that has moved or isn't mounted. `load(link).version` was `1-d7b5c9384833`, the same as `load(<absent dir>).version`. So the user's `accounts.toml` and overrides are dropped with no error, and the version doesn't change. This is the same silent drop that last round's fix closed for an unreadable directory. It also contradicts the patch's own rule that a broken *profile* link raises (`tests/test_normaliser.py:325-333`). Fix: when `FileNotFoundError` is raised, return `[]` only if `not os.path.lexists(directory)`; otherwise raise `NormaliserError`. Add a test with a dangling directory symlink.; `src/autobook/pipeline/normaliser.py:126-127`: a relative `XDG_CONFIG_HOME` is used as given, so it resolves against the current working directory. The XDG Base Directory spec (the freedesktop.org rules for config paths) says relative values are invalid and must be ignored. Concrete case: with `XDG_CONFIG_HOME=rel`, `_default_user_dir()` returns `rel/autobook/normaliser` (checked). The profiles in effect, and so every token and the `version`, then depend on the directory autobook was started from. Fix: use the variable only when `os.path.isabs(config_home)`; otherwise fall back to `~/.config`. Add one `monkeypatch.setenv` test.. Deferred, not addressed here: 7 finding(s) that need human judgment, held in deferred-findings.json for the human at handover — not build work
- Full previous attempt preserved in `iteration-v2/` (patch.diff, build-notes.md, SUMMARY.md, check-*).
- Address the above; do NOT re-attempt the rejected approach unchanged. Satisfy the brief's Success criterion (the end result).

## Iteration 3 — carry-forward (from the previous attempt)
- Sign-off rationale: Rejected because the brief's `sepa` profile is too narrow. The code follows the brief, but the brief needs fixing before #24 starts storing tokens. Re-plan: - Widen the SEPA tag set. Recognise at least KREF+, ABWE+, IBAN+, BIC+ and DEBT+, both as fields to handle and as the end of the previous tag's value. Today `EREF+1 ABWE+MUSTER` swallows everything to the end of the memo, and an IBAN or payee name can end up in the token. - Rethink removing CRED+ (creditor ID) and ABWA+ values completely. Two different creditors currently give the same token (e.g. `MITGLIEDSBEITRAG .`). Keep whatever tells merchants apart, or record why not. - Strip card-payment timestamps (ISO date/time in SVWZ+), so the token stays the same from one payment to the next. Also settle in the brief: whether `sepa` inherits user overrides of `default` (or at least document that it doesn't), and whether user patterns match case-insensitively. Python Unicode version in the version string: optional. Already settled, keep as is: prior art is clear (no overlapping or rejected work), the base is 76bacce (#22 merged), and the version-string contract and TOML layouts in the current brief are fine.
- Sign-off session carry-forward (captured live, before §9 flattened it):
  Rejected because the brief's `sepa` profile is too narrow. The code follows the brief, but the brief needs fixing before #24 starts storing tokens. Re-plan:
  - Widen the SEPA tag set. Recognise at least KREF+, ABWE+, IBAN+, BIC+ and DEBT+, both as fields to handle and as the end of the previous tag's value. Today `EREF+1 ABWE+MUSTER` swallows everything to the end of the memo, and an IBAN or payee name can end up in the token.
  - Rethink removing CRED+ (creditor ID) and ABWA+ values completely. Two different creditors currently give the same token (e.g. `MITGLIEDSBEITRAG .`). Keep whatever tells merchants apart, or record why not.
  - Strip card-payment timestamps (ISO date/time in SVWZ+), so the token stays the same from one payment to the next.
  Also settle in the brief: whether `sepa` inherits user overrides of `default` (or at least document that it doesn't), and whether user patterns match case-insensitively. Python Unicode version in the version string: optional.
  Already settled, keep as is: prior art is clear (no overlapping or rejected work), the base is 76bacce (#22 merged), and the version-string contract and TOML layouts in the current brief are fine.
- Full previous attempt preserved in `iteration-v3/` (patch.diff, build-notes.md, SUMMARY.md, check-*).
- Address the above; do NOT re-attempt the rejected approach unchanged. Satisfy the brief's Success criterion (the end result).
