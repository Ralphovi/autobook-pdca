# Design proposal — issue 24 / knn-index-abstention-gates

> Plan artifact for Ralphovi/autobook#24 (build order 2c, milestone `03 · 2 — Premise`).
> The design is settled in proposal 0001 (*Classification cascade* §2 *kNN*), architecture
> ch.5 (§5.2 *Classifier*) and AGENTS.md (*Classification rules*). This proposal fixes what
> those leave open (where the code lives, the public API #25 builds on, the vote and
> margin definitions, how provenance is refused) so Do does not re-decide it. Do reads
> ONLY this file.

- **Slug:** knn-index-abstention-gates
- **Kind:** enhancement (design proposal)
- **Goal:** Propose a single destination account for a normalised memo from the user's own history, through a character n-gram TF-IDF (term frequency–inverse document frequency) nearest-neighbour index per `(source_account, sign)`, and only when both gates pass: the nearest neighbour is close enough, and the recency-weighted vote has a clear winner. Otherwise abstain and say which gate failed. Only `observed` and `corrected` rows can enter the index.
- **Success criterion:** `tests/test_knn.py` passes with the patch applied and fails, with tests that RUN (not a collection error), with the production change reverted. With an index built from the rows of `build_corpus(0)` (`tests/fixtures/synthetic/corpus_builder.py`) dated before the planted novel row, normalised by `normaliser.load(<empty tmp dir>)` (#23), and thresholds `max_distance=0.5`, `min_margin=0.5`, it must assert: (a) positive control: a fresh `BEISPIELMARKT` memo with card noise, source `GIROKONTO`, sign `out`, is accepted with destination `LEBENSMITTEL`; (b) the planted novel merchant (`NOVEL_MERCHANT`) abstains, with no account and `"distance"` among the failed gates; (c) a planted split vote (an index built from only six invented rows: one merchant token booked three times to each of two destination accounts, on the same dates) abstains with failed gates exactly `{"margin"}` (its distance passes); (d) a row whose provenance is `"synthetic"` is refused with `KnnError`, both when constructing an `IndexRow` and when a row object carrying that provenance reaches `KnnIndex.build` (built by bypassing the constructor check, e.g. `object.__setattr__` on a frozen instance); (e) a query for source `REVOLUT` with sign `in` (a partition with no rows: the fixture books only `out` rows to `REVOLUT`) abstains with failed gates `{"distance"}` and `nearest_distance` `None`; (f) one normaliser version per index: `KnnIndex.build` on rows carrying two different `normaliser_version` values raises `KnnError`, and `query` with a `normaliser_version` other than the index's raises `KnnError`; (g) threshold validation: `build` raises `KnnError` for each of `max_distance=1.0`, `max_distance=-0.1`, `min_margin=0.0`, `min_margin=1.5`; (h) recency: in a separate index of five invented rows with one token, three to `LEBENSMITTEL` dated 1500 days before `as_of` and two to `MIETE` dated 10 days before `as_of`, a query of that token with the default `half_life_days` has `candidate == MIETE` (without decay the 3:2 count would pick `LEBENSMITTEL`); (i) `exclude`: in a separate index of rows `[R, R, S]` with one token (`R` to `LEBENSMITTEL`, `S` to `MIETE`, same date), a query with `exclude=R` has `margin == pytest.approx(0)` (exactly one `R` was left out; removing both would give margin 1), and in an index holding only `R`, a query with `exclude=R` gives `nearest_distance` `None` and failed gates `{"distance"}`.
- **Falsifiability:** RED is reachable on the C4-verify gate (`engine/scripts/run-verify.sh`: host pytest in `$PDCA_WORKTREE` on the instance `.venv`, `-m "not applier and not live_paperless"`). Its red leg reverts every non-test hunk, so `src/autobook/pipeline/classifier.py` returns to the stub (only `classify()`, raising `NotImplementedError`). The module exists on the base, so a module-scope `import autobook.pipeline.classifier as classifier` collects, and `classifier.KnnIndex` raises `AttributeError` inside the test body: a test that RAN and FAILED (scratch probe at Plan on an `origin/main` export: 3 ran, 3 failed, 0 collection errors). This bundle runs in the wave after #23, so the driver prepares its tree on the folded base that already holds #23's normaliser, which the red leg does not revert. The green leg needs scikit-learn: the gate's `engine/scripts/lib/sync_deps.py` installs the worktree's declared dependencies into the instance `.venv` from PyPI before the legs run, and reports UNVERIFIABLE (never a verdict) if it cannot.
- **Invariant to restore:** The kNN tier proposes an account only when both independent gates pass, failing either always falls through (no threshold is lowered and nothing is guessed), it only ever returns one destination account, and nothing but `observed` or `corrected` rows, all normalised under one normaliser version, can enter the index. Sources: AGENTS.md *Classification rules* ("Abstention is a feature, not a failure"; "Splits are rules-tier only"; "Provenance tagging is structural … Synthetic rows must not be able to enter the index"; "The normaliser version … changes what every vector means"); AGENTS.md rubric *Abstention erosion*; ch.5 §5.2 *Classifier*; ch.8 §8.3.
- **Repo + branch target:** Ralphovi/autobook @ main
- **Depends on:** 23
- **Conflicts with:** none
- **Ordering note:** #22 (a prerequisite named on the issue) is merged (PR #49). Depends on #23: it normalises through `autobook.pipeline.normaliser.load` / `Normaliser.normalise` and records `Normaliser.version`. #25 depends on this one. All three edit `tests/test_skeleton.py` (the `IMPLEMENTED` set #23 adds) and ch.5; the chain already keeps them in separate waves.
- **Surfaces:** data
- **Difficulty:** medium — one module made real (`src/autobook/pipeline/classifier.py`), the first runtime dependency (`pyproject.toml`: `dependencies` and a mypy override), one test file, a one-line change to `tests/test_skeleton.py`, ch.5 docs. Rated medium because the gate semantics are what every later threshold and the #25 backtest rest on.
- **Scope:** (1) the kNN index in `src/autobook/pipeline/classifier.py` with the API and semantics below; (2) add `scikit-learn` to `[project] dependencies` in `pyproject.toml` (lower bound Do's choice, no upper pin), replacing the "Deliberately empty" comment with one that says why it is there, and add a `[[tool.mypy.overrides]]` entry with `ignore_missing_imports = true` for `sklearn.*` (scikit-learn ships no `py.typed`: checked at Plan on the 1.9.1 wheel) and for `scipy.*` only if the code imports scipy; (3) `tests/test_knn.py`; (4) add `"autobook.pipeline.classifier"` to `IMPLEMENTED` in `tests/test_skeleton.py` (#23 defines it so that an `IMPLEMENTED` module skips all three assertions of `test_every_block_has_one_entry_point_that_is_not_implemented`: `len(__all__) == 1`, `callable`, `NotImplementedError`; the other skeleton tests still cover it); (5) docs currency: ch.5 §5.2 *Classifier* records the API, the vote and margin definitions, the gate comparison, the half-life, `exclude`, and the provenance refusal; ch.8 §8.3 *The corpus has provenance* changes "Index construction filters on provenance" to say construction refuses (raises on) any row that is not `observed` or `corrected`. / out of scope: a kNN index version (ch.8 §8.3 lists it in the version tuple; no code assembles that tuple yet, as in #23, and the index is rebuilt in-process every run and never persisted, so there is no stored artifact to version; it arrives with the tuple); editing proposal 0001 (its "filters on provenance" sentence stays; ch.8 is the current-state document, and the PR description states the difference); the rules and LLM tiers, the cascade itself (`classify()` stays the `NotImplementedError` stub, now listed in `__all__` next to the new names); choosing threshold values (no default: #25 produces the evidence, ch.8 §8.3); the amount tie-breaker (proposal 0001: amount is "tie-breaker only", a later refinement); explanations in the review file (build step 6); reading `corrected` rows from staging (build step 3: the type accepts them, nothing produces them yet); persisting the index (it is rebuilt every run, in-process).
- **External dependencies:** `pypi` (the C4-verify dependency sync and the nox gate both install scikit-learn from PyPI)
- **Test file:** tests/test_knn.py
- **Citations expected:** Do must cite path:line on the target branch for every change it builds on: the stub `src/autobook/pipeline/classifier.py` it replaces; `pyproject.toml` (`dependencies = []` and its comment; `[[tool.mypy.overrides]]` for `gnucash.*`, the peer for the new override); the `IMPLEMENTED` set in `tests/test_skeleton.py` (added by #23); `src/autobook/contracts.py` (`Sign`, `CorpusRow`, `CorpusContract`, `ContractError` at `:110`, the peer for `KnnError`); `autobook.pipeline.normaliser` (`load`, `Normaliser.normalise`, `Normaliser.version`, `NormalisedMemo`; from #23); `tests/fixtures/synthetic/corpus_builder.py` (`build_corpus`, `NOVEL_MERCHANT`, `GIROKONTO`, `LEBENSMITTEL`, `MIETE`); ch.5 §5.2 *Classifier*.
- **Prior-art check (triage cycles):** searched by path. `git -C ../autobook log --all -- src/autobook/pipeline pyproject.toml tests/test_skeleton.py` shows only the scaffold (0e0b7dc), a docs commit (2baf4d6), testenv (2a4b845) and #22's skeleton (23ce73f); `classifier.py` is a stub and `dependencies` is empty. `gh pr list --state all` (8 PRs, all merged) has nothing on kNN. Closed issue #5 (`NOT_PLANNED`) was split into #22–#26, not rejected; its kNN scope is this issue's. Nothing to reuse.
- **Disposition hint:** new-feature

## Motivation

Build step 2 decides whether the design holds: whether the user's own history is dense
and consistent enough for kNN to abstain reliably on novel memos (ch.9). That needs an
index whose abstention is real: a distance gate that stops confident errors on unseen
merchants, and a margin gate that stops guesses between two habits. The backtest (#25)
measures exactly this index.

## Design

### Where it lives

In `autobook.pipeline.classifier`, the Classifier building block of ch.5, of which kNN
is tier 5. No new module (a new module under `autobook.pipeline` would also be
discovered by `tests/test_skeleton.py`). `__all__` lists `classify` (still the stub) plus
the names below.

### Public API (fixed: #25 is briefed against it)

- `class KnnError(ValueError)`: every refusal (bad provenance, mixed normaliser
  versions, invalid thresholds, malformed rows).
- `@dataclass(frozen=True) class IndexRow`: `token: str` (normalised memo),
  `source_account: tuple[str, ...]`, `sign: Sign` (from `autobook.contracts`),
  `destination_account: tuple[str, ...]`, `post_date: datetime.date`,
  `provenance: Literal["observed", "corrected"]`, `normaliser_version: str`.
  `__post_init__` validates every field and raises `KnnError` for any provenance other
  than `observed` or `corrected`.
- `index_rows(corpus: CorpusContract, normaliser: Normaliser) -> tuple[IndexRow, ...]`:
  one `observed` row per corpus row, `token` and `normaliser_version` from
  `normaliser.normalise(row.raw_memo, row.source_account)`.
- `KnnIndex.build(rows: Iterable[IndexRow], *, max_distance: float, min_margin: float,
  half_life_days: float = HALF_LIFE_DAYS) -> KnnIndex`. `HALF_LIFE_DAYS` is a module
  constant of about 18 months (ch.5: "~18-month half-life"; Do picks the day count and
  documents it).
- `KnnIndex.query(token: str, source_account: tuple[str, ...], sign: Sign, *, as_of:
  datetime.date, normaliser_version: str, exclude: IndexRow | None = None) -> KnnResult`.
  `exclude` leaves one occurrence of a row equal to it (dataclass equality) out of the
  neighbours: ask for `min(k + 1, rows in the partition)` neighbours, drop the first one
  equal to `exclude`, keep at most `k`. If no neighbour is left, the result is the same
  as for an empty partition (see *Gates*). It exists for #25's leave-one-out upper bound,
  which must not rebuild the index once per row (30–60k rows on real history), and it is
  pinned by success criterion (i).
- `@dataclass(frozen=True) class KnnResult`: `account: tuple[str, ...] | None` (set only
  when accepted), `candidate: tuple[str, ...] | None` (the vote winner, whether or not
  accepted, so a review can show it), `nearest_distance: float | None`, `margin: float |
  None`, `share: float | None` (the winner's weighted share), `failed_gates:
  frozenset[Literal["distance", "margin"]]`, and a property `accepted` (true iff
  `failed_gates` is empty). Both gate numbers are always reported when they exist
  (proposal 0001: "Report both numbers").

### Semantics

- **Provenance is refused at two points.** The `IndexRow` constructor, and `build`
  itself, which re-checks every row's `provenance` at run time and raises `KnnError` on
  the first bad one. Nothing is returned, so no partial index exists. Refusal is an
  error, not a silent skip (decided with the maintainer at Plan: a silently wrong
  booking is worse than a loud failure, AGENTS.md).
- **One normaliser version per index.** `build` raises `KnnError` if rows carry more
  than one `normaliser_version`; `query` raises `KnnError` if its `normaliser_version`
  differs from the index's.
- **Thresholds.** Both are required keyword arguments with no default (thresholds come
  from backtest evidence, never from code, AGENTS.md "Never widen a threshold …").
  `build` validates `0 <= max_distance < 1` and `0 < min_margin <= 1`, else `KnnError`.
  `min_margin > 0` means a tie can never be accepted.
- **Partitions.** One sub-index per `(source_account, sign)`. Each fits its own
  `TfidfVectorizer(analyzer="char_wb", ngram_range=(3, 5), sublinear_tf=True)` on its
  rows' tokens and a `NearestNeighbors(metric="cosine", algorithm="brute")` on the
  result, as in proposal 0001. A query never sees another partition. No FAISS, no
  vector database, no persistence.
- **Neighbours.** `k = min(15, rows in the partition)`. Cosine distance, clamped to
  `[0, 1]` before use (scikit-learn can return a tiny negative value for identical rows
  or a value just over 1). Tests compare float results with `pytest.approx`, never `==`.
- **Weights and vote.** Each neighbour's weight is `(1 - distance) * 0.5 ** (age_days /
  half_life_days)`, where `age_days = max(0, (as_of - post_date).days)`. An account's
  share is the sum of its neighbours' weights over the total. The candidate is the
  account with the largest share; on an exact tie, the smaller path tuple, so results
  are deterministic. `margin = share(candidate) - share(runner-up)` (runner-up `0` when
  there is only one account). A total weight of `0` gives `margin = 0`.
- **Gates.** Distance passes iff `nearest_distance <= max_distance`. Margin passes iff
  `margin >= min_margin`. Both are evaluated and every failure is listed. An empty
  token, or a partition with no rows, gives `nearest_distance = None` and
  `failed_gates = {"distance"}` (nothing is near).
- **Single account.** The result type can only hold one account path; no split type
  exists in this module.

### Tests and the gate (C4-verify requirements: read this before writing a test)

- `tests/test_knn.py`: success criterion (a)–(i), plus anything else above Do considers
  worth pinning (determinism of the tie rule, malformed rows).
  - Build the index from `index_rows(build_corpus(0), normaliser)` restricted to rows
    dated before the novel row; query with `as_of` set to the novel row's date.
  - (c): create the split-vote rows in the test as `IndexRow` objects with one invented
    merchant token (e.g. `NEUBAU DROGERIE`), three to `LEBENSMITTEL` and three to
    `MIETE`, on the same dates, and build a **separate** index from only those six rows.
    Recency weights are then equal, every distance is `0` and the margin is `0`. Mixed
    into the fixture's partition, tokens sharing n-grams with it would add weight to
    one side and the margin would no longer be `0`.
- Thresholds in the tests are the explicit values in the success criterion. They are
  test inputs, not a recommendation.

Rules every test file in this patch must follow, or the gate cannot judge it:

1. **Import only modules that exist on the base at module scope, as modules**
   (`import autobook.pipeline.classifier as classifier`, `import
   autobook.pipeline.normaliser as normaliser`, `from tests.fixtures.synthetic import
   corpus_builder`). Reach every name this patch adds through the module object inside
   the test body. Never `from autobook.pipeline.classifier import KnnIndex` at module
   scope: on the red leg that is a collection error (UNVERIFIABLE), not red. Do not
   import `sklearn` in the test file.
2. **Keep the words `applier` and `live_paperless` out of every test file.**
3. **No `pytest.importorskip`, no skips.**

**Prerequisite check before building.** The tree Do gets is the folded base holding
#23. Before writing code, confirm it has `normaliser.load`, `Normaliser.version`,
`NormalisedMemo` and the `IMPLEMENTED` set in `tests/test_skeleton.py` with the
three-assertion exemption described in Scope (4). If any is missing or shaped
differently, stop and report it in `build-notes.md`; do not re-implement #23's API or
change the skeleton exemption in this patch.

### Docs currency (same PR)

Update ch.5 §5.2 *Classifier* (the kNN bullet) with: the API names, the weight, share and
margin definitions, the gate comparisons, `HALF_LIFE_DAYS`, `exclude`, the two
provenance checks and the one-version rule. Update ch.8 §8.3: "Index construction
filters on provenance" becomes a refusal (construction raises on a row that is not
`observed` or `corrected`); keep "there is no path by which a synthetic row can enter".
Do not edit proposal 0001. Update the `pyproject.toml` comment on `dependencies`.

## Alternatives considered

- **Silently dropping non-`observed`/`corrected` rows.** Rejected at Plan: it would
  hide a provenance bug that the design says cannot exist; an error makes it visible.
- **A pure-Python TF-IDF and cosine.** Rejected: proposal 0001 names scikit-learn, and
  the `pyproject.toml` comment already expects it with build step 2.
- **Recency weighting left for later.** Rejected at Plan: ch.5 makes it part of the kNN
  tier, and #25 must measure the classifier as designed.
- **Default threshold values in code.** Rejected: any default would be a threshold set
  without evidence.
- **A separate `autobook.pipeline.knn` module.** Not chosen: ch.5 has one module per
  building block, and kNN is part of the Classifier block.

## Impact & compatibility

First runtime dependency (scikit-learn, with numpy, scipy, joblib, narwhals,
threadpoolctl). Supports Python ≥3.11 (1.9.1 wheel: `Requires-Python: >=3.11`), which
matches `requires-python` and the CI matrix 3.11–3.14. The pipeline still never imports
`gnucash`; scikit-learn does not either. Expect the advisory `T2-threat-model` check to
land in SUMMARY §6: `src/autobook/pipeline/classifier.py` matches its `*classif*`
pattern. The change adds no new external input and no network use, so no threat-model
update is expected; that is a sign-off call, and Do does not edit
`.oss-scanner/threat_model.md`.

## Open questions

None open. Settled with the maintainer (eduralph) in the Plan session: scikit-learn as a
dependency with a mypy override, provenance refusal raises, recency weighting included,
thresholds required with no default. These are not on the issue thread; the PR
description must state them, including that construction now refuses bad provenance
where proposal 0001 says "filters", and that a kNN index version is deferred to the
version tuple.

Plan-review response: (1) the folded-base dependency on #23 is real and declared
(`Depends on: 23`); #23's brief now states the exemption covers all three skeleton
assertions, this brief repeats it in Scope (4), and Do must stop if the base lacks it;
(2) version mismatch, threshold validation, recency and `exclude` are now criteria
(f)–(i), so the invariant and #25's API are tested; (3) ch.8 §8.3 is added to docs
currency, proposal 0001 is left as the design record and the PR states the difference
(posting the provenance decision to issue #24 is left to the maintainer: Plan does not
write to the tracker in a revision pass); (4) `exclude` stays in this slice, now pinned
by (i), because moving it to #25 would make #25 edit this module; (5) the kNN index
version is now explicitly out of scope with a reason; (6) distances are clamped to
`[0, 1]` and float checks use `pytest.approx`.

## STOP discipline

Draft only until Check sign-off. Pushing to a feature/draft branch and opening a
draft PR MAY happen during the cycle (useful for CI feedback). The PR MUST NOT be
marked ready before sign-off accepts.

## Iteration 1 — carry-forward (from the previous attempt)
- Sign-off rationale: Auto-iterate (round 1): rebuilding for the implementation-level findings — C4 Verification (red→green) — Resolve the dependency/type-checker compatibility failure and obtain a completed type check — the logged 37-test green follows real dependency installation, but mypy stops in NumPy stubs before checking completes; this is a toolchain caveat, not a confirmed classifier defect (`gate-logs/C4-verify.log:10`, `gate-logs/C4-ci.log:36`, `target/pyproject.toml:89`).; T2 Shape — Decide whether the threat model needs a current-state update — classification gates now have executable enforcement, while the existing model already describes their invariant and the patch introduces no network boundary (`gate-logs/T2-threat-model.log:10`, `target/.oss-scanner/threat_model.md:11`, `target/.oss-scanner/threat_model.md:190`).; `pyproject.toml:31` + `pyproject.toml:101-104` (sklearn override): the `C4-ci` gate fails on both attempts, in the `types` session: `numpy/__init__.pyi:737: error: Type statement is only supported in Python 3.12 and greater [syntax]` (gate-logs/C4-ci.log:36 and :108). Cause: `dependencies = ["scikit-learn>=1.5"]` installs numpy into the mypy environment. mypy is set to `python_version = "3.11"` (`pyproject.toml:89`), so it cannot parse numpy's stubs, which use the 3.12 `type X = ...` syntax. The new override silences only `sklearn.*`. Something in the mypy import graph still reaches numpy. The likely path is pytest's typed `_pytest/python_api.py` importing `numpy.ndarray` under `TYPE_CHECKING`, which `tests/test_knn.py` drags in through `pytest.approx`; I could not confirm this without pytest installed. The failure does not depend on the interpreter, because mypy targets 3.11 everywhere, so the PR's CI `types` job will also be red. Fix: add an override so mypy does not parse numpy (for example `module = ["numpy", "numpy.*"]` with `follow_imports = "skip"`), plus scipy if it shows up next. Then re-run `nox -s gate`. Do not raise `python_version`, because `requires-python` is 3.11.; `src/autobook/pipeline/classifier.py:248` (`row._validate()` in `build`): the second provenance check is a method lookup on the row's own class, so a subclass can turn it off. Concrete case: `class R(classifier.IndexRow): def _validate(self) -> None: pass`. Build `R(...)` with `provenance="observed"`, then `object.__setattr__(r, "provenance", "synthetic")`. It passes `isinstance(row, IndexRow)` at `:246`, its `_validate` does nothing, and the synthetic row enters the index. AGENTS.md says synthetic rows "must not be able to enter the index" as a structural rule, and the brief's criterion (d) is about getting around the constructor. The `object.__setattr__` test (`tests/test_knn.py:167`) covers only one way around it. A one-line fix closes the gap: call `IndexRow._validate(row)` instead of the bound method, or require `type(row) is IndexRow`. Add a test for the subclass route. Low severity: it needs deliberate misuse, but the brief makes this refusal an invariant.; `tests/test_knn.py:367`: `test_the_result_holds_one_account_and_the_stub_entry_point_remains` is the one bundle test that passes on the red leg (gate-logs/C4-verify.log: 31 of 37 failed; the other 6 green are the 5 skeleton tests plus this one). That is acceptable for a regression guard, but its name claims "the result holds one account" and it asserts nothing about `KnnResult`. The brief's "Single account" invariant (no split type) has no test. Either rename it, or add a check that `KnnResult` has exactly one account-typed field (`account`, a single `tuple[str, ...] | None`) and that the module exports no split type.; C4 Autobook gate: nox -s gate (fmt/lint/types/test/typos/docs) FAILED (gating) — nox > * docs: success. Deferred, not addressed here: 8 finding(s) that need human judgment, held in deferred-findings.json for the human at handover — not build work
- Failing gate: C4 Autobook gate: nox -s gate (fmt/lint/types/test/typos/docs) — nox > * docs: success
- Full previous attempt preserved in `iteration-v1/` (patch.diff, build-notes.md, SUMMARY.md, check-*).
- Address the above; do NOT re-attempt the rejected approach unchanged. Satisfy the brief's Success criterion (the end result).

## Iteration 2 — carry-forward (from the previous attempt)
- Sign-off rationale: Auto-iterate (round 2): rebuilding for the implementation-level findings — T2 Shape — Decide whether executable classification enforcement requires a threat-model update — the existing model names these gates, but the security-sensitive-path check explicitly leaves currency to sign-off (`gate-logs/T2-threat-model.log:10`, `target/.oss-scanner/threat_model.md:190`).; `src/autobook/pipeline/classifier.py:115` (and the doc claim at `docs/design/architecture/05-building-block-view.md:373`, "so the check cannot be overridden"): **the provenance check is a `not in` test, which an object with its own equality can pass.** `IndexRow(..., provenance=unittest.mock.ANY, ...)` passes the constructor and `build`, and the query is accepted. The same happens with `class S(str): __eq__ = lambda s, o: True` and `S("synthetic")`: `build` accepts a row whose `provenance` string is `"synthetic"`. The round-1 subclass hole was closed for the row (`type(row) is not IndexRow`, `:250`) but is still open for the field. Fix: in `_check_row`, require `type(row.provenance) is str` before the membership test (and the same for `sign`, `token` and `normaliser_version` if the doc's claim is meant to hold). Add a test with a `str` subclass. This needs deliberate misuse, so severity is low, but the brief makes this refusal an invariant and the docs now claim it cannot be bypassed.; `src/autobook/pipeline/classifier.py:190` and `:333`, with `tests/test_knn.py:298`: **an exact token match does not always get distance 0.** The clamp only removes negative values. scikit-learn often returns `2.22e-16` for identical vectors: in 92 of 300 random tokens, an index containing the exact token returned a nonzero `nearest_distance`. In a realistic 30-row partition, `MUSTER HAUSVERWALTUNG` matched itself at `1.11e-16`. Validation allows `max_distance=0.0` (`0 <= max_distance`), and with that setting these exact matches fail the distance gate. `test_boundary_thresholds_are_accepted` passes only because `"BEISPIELMARKT"` alone happens to come out at exactly 0, so the test is luck-dependent and may break on a different numpy or BLAS (the math library numpy uses). Fix: round distances below about `1e-12` to 0, or stop claiming `max_distance=0` as a supported boundary. Low practical impact, because no backtest is likely to pick 0.. Deferred, not addressed here: 8 finding(s) that need human judgment, held in deferred-findings.json for the human at handover — not build work
- Full previous attempt preserved in `iteration-v2/` (patch.diff, build-notes.md, SUMMARY.md, check-*).
- Address the above; do NOT re-attempt the rejected approach unchanged. Satisfy the brief's Success criterion (the end result).

## Iteration 3 — carry-forward (from the previous attempt)
- Sign-off rationale: Rejected for design issues that a rebuild cannot settle; decide them at Plan: 1. Recency is applied only after the k=15 cut, and distance ties are broken by input order (oldest first). With more than 15 identical-token rows, recent bookings can be left out of the vote, giving a confident wrong account on recurring payees (e.g. rent moved to a new account). Plan must fix the rule (e.g. order ties newest first, or let every row tied with the k-th distance vote) and the criterion must include a test with >15 tied rows in chronological order. 2. Unseen n-grams are silently dropped by TfidfVectorizer.transform, so "known merchant + new words" can score distance 0 and pass the distance gate. Plan must choose a treatment (coverage check, fit on partition + query, hashing vectoriser, or accept as a documented known gap in the threat model) and pin it in the criterion. Also carry into the next brief: index_rows must pass row.provenance through instead of hard-coding "observed" (add a test smuggling it via CorpusRow); the exclude k+1 test must have a dissenting farthest neighbour so the k+1 rule is actually covered; decide the threat-model update (T2). The size limit fired after 3 attempts, so consider splitting (core index first, gate refinements second) with `autobook-pdca split 24`.
- Sign-off session carry-forward (captured live, before §9 flattened it):
  Rejected for design issues that a rebuild cannot settle; decide them at Plan:
  1. Recency is applied only after the k=15 cut, and distance ties are broken by input order (oldest first). With more than 15 identical-token rows, recent bookings can be left out of the vote, giving a confident wrong account on recurring payees (e.g. rent moved to a new account). Plan must fix the rule (e.g. order ties newest first, or let every row tied with the k-th distance vote) and the criterion must include a test with >15 tied rows in chronological order.
  2. Unseen n-grams are silently dropped by TfidfVectorizer.transform, so "known merchant + new words" can score distance 0 and pass the distance gate. Plan must choose a treatment (coverage check, fit on partition + query, hashing vectoriser, or accept as a documented known gap in the threat model) and pin it in the criterion.
  Also carry into the next brief: index_rows must pass row.provenance through instead of hard-coding "observed" (add a test smuggling it via CorpusRow); the exclude k+1 test must have a dissenting farthest neighbour so the k+1 rule is actually covered; decide the threat-model update (T2). The size limit fired after 3 attempts, so consider splitting (core index first, gate refinements second) with `autobook-pdca split 24`.
- Full previous attempt preserved in `iteration-v3/` (patch.diff, build-notes.md, SUMMARY.md, check-*).
- Address the above; do NOT re-attempt the rejected approach unchanged. Satisfy the brief's Success criterion (the end result).
