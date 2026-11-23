# Design proposal — issue 24 / knn-index-abstention-gates

> Plan artifact for Ralphovi/autobook#24 (build order 2c, milestone `03 · 2 — Premise`).
> The design is settled in proposal 0001 (*Classification cascade* §2 *kNN*), architecture
> ch.5 (§5.2 *Classifier*) and AGENTS.md (*Classification rules*). This proposal fixes what
> those leave open (where the code lives, the public API #25 builds on, how neighbours are
> chosen, how distance is measured, the vote and margin, how provenance is refused) so Do
> does not re-decide it. Do reads ONLY this file (and may open `iteration-v3/patch.diff`,
> its starting point).
>
> **Re-plan (iteration 4).** Iteration 3 built the API below with all gates green, and was
> sent back to Plan for two design gaps this brief had left open. Both are now decided
> (see *Neighbours* and *Distance*) and pinned by new criteria (j) and (k). Do starts from
> `iteration-v3/patch.diff` and changes only what this brief changes; it does not rebuild
> from scratch.
>
> **Plan-review revision.** A plan review left `exclude` underspecified. This revision
> decides it: `exclude` now also removes the row from the query's idf (*Distance*,
> *leave-one-out*), and an `exclude` that matches no row raises (*Neighbours* step 2).
> Both are pinned by criterion (m) and the new last case of (i). The brief also states the
> PR base and why the distance gate is `<=`.

- **Slug:** knn-index-abstention-gates
- **Kind:** enhancement (design proposal)
- **Goal:** Propose a single destination account for a normalised memo from the user's own history, through a character n-gram TF-IDF (term frequency–inverse document frequency) nearest-neighbour index per `(source_account, sign)`, and only when both gates pass: the nearest neighbour is close enough, and the recency-weighted vote has a clear winner. Otherwise abstain and say which gate failed. Only `observed` and `corrected` rows can enter the index. Text in a query that history never contained must count toward its distance, and the vote must not depend on the order rows were passed in.
- **Success criterion:** `tests/test_knn.py` passes with the patch applied and fails, with tests that RUN (not a collection error), with the production change reverted. With an index built from the rows of `build_corpus(0)` (`tests/fixtures/synthetic/corpus_builder.py`) dated before the planted novel row, normalised by `normaliser.load(<empty tmp dir>)` (#23), and thresholds `max_distance=0.5`, `min_margin=0.5`, it must assert: (a) positive control: a fresh `BEISPIELMARKT` memo with card noise, source `GIROKONTO`, sign `out`, is accepted with destination `LEBENSMITTEL`; (b) the planted novel merchant (`NOVEL_MERCHANT`) abstains, with no account and `"distance"` among the failed gates; (c) a planted split vote (an index built from only six invented rows: one merchant token booked three times to each of two destination accounts, on the same dates) abstains with failed gates exactly `{"margin"}` (its distance passes); (d) a row whose provenance is `"synthetic"` is refused with `KnnError`, both when constructing an `IndexRow` and when a row object carrying that provenance reaches `KnnIndex.build` (built by bypassing the constructor check, e.g. `object.__setattr__` on a frozen instance); (e) a query for source `REVOLUT` with sign `in` (a partition with no rows: the fixture books only `out` rows to `REVOLUT`) abstains with failed gates `{"distance"}` and `nearest_distance` `None`; (f) one normaliser version per index: `KnnIndex.build` on rows carrying two different `normaliser_version` values raises `KnnError`, and `query` with a `normaliser_version` other than the index's raises `KnnError`; (g) threshold validation: `build` raises `KnnError` for each of `max_distance=1.0`, `max_distance=-0.1`, `min_margin=0.0`, `min_margin=1.5`; (h) recency: in a separate index of five invented rows with one token, three to `LEBENSMITTEL` dated 1500 days before `as_of` and two to `MIETE` dated 10 days before `as_of`, a query of that token with the default `half_life_days` has `candidate == MIETE`; (i) `exclude`: in a separate index of rows `[R, R, S]` with one token (`R` to `LEBENSMITTEL`, `S` to `MIETE`, same date), a query with `exclude=R` has `margin == pytest.approx(0)`; in an index holding only `R`, a query with `exclude=R` gives `nearest_distance` `None` and failed gates `{"distance"}`; and in an index of 15 rows `BEISPIELMARKT` → `LEBENSMITTEL` plus one row `BEISPIELMARKT FILIALE` → `MIETE` (all `GIROKONTO`/`out`, same date), a query of `BEISPIELMARKT` has `margin == pytest.approx(1)` without `exclude` and `margin == pytest.approx(0.9430, abs=1e-3)` with `exclude=` one of the `BEISPIELMARKT` rows (the `MIETE` row now votes); and a query with an `exclude` row that the query's partition does not hold raises `KnnError`, both for a row the index does not hold at all (in the `[R, R, S]` index, a `MIETE` row with a token no row has) and for a row the index holds in another partition (an index of `R` as `GIROKONTO`/`out` and `T`, the same token as `GIROKONTO`/`in`; a `GIROKONTO`/`out` query with `exclude=T`); (j) recency over tied neighbours: an index of 20 rows token `MUSTER VERMIETER` → `LEBENSMITTEL` dated `1500 + 30*i` days before `as_of` (`i = 0..19`) and 5 rows of the same token → `MIETE` dated `10 + 30*i` days before `as_of` (`i = 0..4`), all `GIROKONTO`/`out`, passed to `build` oldest first, queried with that token and the default half-life, gives `candidate == MIETE`, `margin == pytest.approx(0.3630, abs=1e-3)` and failed gates `{"margin"}`; the same rows passed newest first, and in a `random.Random(<fixed seed>)` shuffle, give the same `candidate`, the same failed gates and the same margin (`pytest.approx`); (k) unseen n-grams count: in an index of one row `BEISPIELMARKT` → `LEBENSMITTEL` (`GIROKONTO`/`out`) with `max_distance=0.3`, `min_margin=0.5`, the query `BEISPIELMARKT` is accepted with `nearest_distance == pytest.approx(0)`, the query `BEISPIELMARKT QXZV` is accepted with `nearest_distance == pytest.approx(0.2368, abs=1e-3)`, and the query `BEISPIELMARKT QXZV WJKQ` has `nearest_distance == pytest.approx(0.3589, abs=1e-3)`, `account` `None` and failed gates `{"distance"}`; (l) `index_rows` carries provenance through: a `build_corpus(0)` corpus whose first `CorpusRow` had its `provenance` set to `"synthetic"` with `object.__setattr__` makes `index_rows` raise `KnnError`; (m) `exclude` takes the excluded row out of the query's idf too: in an index of two rows, `S` = `BEISPIELMARKT` → `LEBENSMITTEL` and `R` = `QXZV WJKQ` → `MIETE` (both `GIROKONTO`/`out`, same date), with `max_distance=0.3`, `min_margin=0.5`, the query `BEISPIELMARKT QXZV` without `exclude` has `nearest_distance == pytest.approx(0.1056, abs=1e-3)` (`QXZV` is known, from `R`), and with `exclude=R` has `nearest_distance == pytest.approx(0.2368, abs=1e-3)` (the same value as (k)'s index of `S` alone), `account == LEBENSMITTEL` and no failed gates.
- **Falsifiability:** RED is reachable on the C4-verify gate (`engine/scripts/run-verify.sh`: host pytest in `$PDCA_WORKTREE` on the instance `.venv`, `-m "not applier and not live_paperless"`). Its red leg reverts every non-test hunk, so `src/autobook/pipeline/classifier.py` returns to the stub (only `classify()`, raising `NotImplementedError`). The module exists on the base, so a module-scope `import autobook.pipeline.classifier as classifier` collects, and `classifier.KnnIndex` raises `AttributeError` inside the test body: a test that RAN and FAILED (iteration 3's red leg: 37 of 43 failed, 0 collection errors). This bundle runs in the wave after #23, on the folded base `pdca-integration/main-r1726f2053868` (tip `0df021f`) that holds #23's normaliser, which the red leg does not revert. Criteria (j) and (k) also fail against the iteration-3 code itself (checked at Plan in a scratch copy: (j) gives `LEBENSMITTEL`, margin 1.0, accepted, in oldest-first order; (k) gives distance 0.0 for all three queries), so they pin the change, not only the module. So do (m) and the last case of (i): iteration 3 removes `R` from the vote only, so (m) with `exclude=R` gives 0.1056, and it ignores an `exclude` that matches no row instead of raising. The values in (m) were computed at Plan (revision) with a prototype of the *Distance* rule on scikit-learn 1.9.1 (`.venv` of autobook-pdca); the same prototype reproduces (k)'s 0.2368 and 0.3589 and the FILIALE row's distance 0.589 in (i), with and without `exclude`. The values in (i), (j) and (k) were measured at Plan on a prototype of the rules below with scikit-learn 1.9.1 (iteration 3's 43 tests all still passed on it). The green leg needs scikit-learn: the gate's `engine/scripts/lib/sync_deps.py` installs the worktree's declared dependencies into the instance `.venv` from PyPI before the legs run, and reports UNVERIFIABLE (never a verdict) if it cannot.
- **Invariant to restore:** The kNN tier proposes an account only when both independent gates pass, failing either always falls through (no threshold is lowered and nothing is guessed), it only ever returns one destination account, and nothing but `observed` or `corrected` rows, all normalised under one normaliser version, can enter the index, through any path including `index_rows`. The distance gate measures the whole query: text history never contained moves the query away from history, never toward it ("Distance = genuine 'never seen this'"). The result is a function of the set of rows, not their order; a query with `exclude=R` measures the query as if `R` were not in history (its idf and vote; the other rows' fitted vectors are not refitted, see *leave-one-out*), and an `exclude` that names no row of the query's partition is an error, never a silent no-op; and recency weighting reaches every row that ties for a place in the vote ("a decision from four years ago should not outvote current practice"). Sources: AGENTS.md *Classification rules* ("Abstention is a feature, not a failure"; "Splits are rules-tier only"; "Provenance tagging is structural … Synthetic rows must not be able to enter the index"; "The normaliser version … changes what every vector means"); AGENTS.md rubric *Abstention erosion*; proposal 0001 §2 *kNN* (two gates; *Recency weighting*; *Why kNN over GnuCash's Bayes matcher*, row *Abstention*); ch.5 §5.2 *Classifier*; ch.8 §8.3.
- **Repo + branch target:** Ralphovi/autobook @ main
- **Depends on:** 23
- **Conflicts with:** none
- **Ordering note:** #22 (a prerequisite named on the issue) is merged (PR #49). Depends on #23 (draft PR #50, folded into this wave's base): it normalises through `autobook.pipeline.normaliser.load` / `Normaliser.normalise` and records `Normaliser.version`. #25 depends on this one. All three edit `tests/test_skeleton.py` (the `IMPLEMENTED` set #23 adds) and ch.5; the chain already keeps them in separate waves. PR base: the PR targets `main` (INTEGRATION §2), not the integration line. The driver cuts this bundle's branch from the line commit it was built on (`stack-base-tip`, `0df021f`), so the branch carries #23's commits: CI finds `normaliser`, and the PR shows #23's diff until draft PR #50 merges. Merge #50 first, then this PR (bottom-up, merge commits).
- **Surfaces:** data
- **Difficulty:** medium — one module made real (`src/autobook/pipeline/classifier.py`), the first runtime dependency (`pyproject.toml`: `dependencies` and mypy overrides), one test file, a one-line change to `tests/test_skeleton.py`, ch.5 and ch.8 docs. This round's delta is local to `_Partition` (distance, and the query-side idf with `exclude`), `KnnIndex.query` (neighbour choice, `exclude` removal and its no-match error) and `index_rows`; `HALF_LIFE_DAYS` is already `548.0` in iteration 3 and does not change. Rated medium because the gate semantics are what every later threshold and the #25 backtest rest on.
- **Scope:** (1) the kNN index in `src/autobook/pipeline/classifier.py` with the API and semantics below, starting from `iteration-v3/patch.diff` and changing: the distance, including the leave-one-out idf for `exclude` (*Distance*), the neighbour choice and `exclude` removal, with `KnnError` when it matches no row (*Neighbours*), `index_rows` (pass `row.provenance` through); `HALF_LIFE_DAYS = 548.0` and the `<=`/`>=` gate comparisons stay exactly as iteration 3 has them (no hunk expected); (2) `pyproject.toml` as in iteration 3: `scikit-learn` in `[project] dependencies` with a comment saying why, `[[tool.mypy.overrides]]` for `sklearn.*` and for numpy (keep iteration 3's numpy override; if `classifier.py` now imports numpy itself, correct that override's comment, which says nothing here imports numpy); (3) `tests/test_knn.py`: iteration 3's tests plus (j), (k), (l), (m) and the third and fourth cases of (i), and with the weak `exclude` test (`test_exclude_keeps_k_neighbours_when_the_partition_is_larger`) replaced by the (i) case that pins it; (4) `"autobook.pipeline.classifier"` in `IMPLEMENTED` in `tests/test_skeleton.py` (as iteration 3); (5) docs currency: ch.5 §5.2 *Classifier* and ch.8 §8.3, see *Docs currency*. / out of scope: **any edit to `.oss-scanner/threat_model.md`** (decided at Plan: the model already names both gates and rates "a kNN proposal passes with either gate failed" and "a synthetic row can enter the kNN index"; its stale "Nothing is built yet" line and a sentence on how distance is measured go to a follow-up issue, which the PR description names; sign-off clears the T2 item on that basis); a kNN index version (ch.8 §8.3 lists it in the version tuple; no code assembles that tuple yet, and the index is rebuilt in-process every run and never persisted; it arrives with the tuple); editing proposal 0001 (ch.8 is the current-state document; the PR description states the differences); the rules and LLM tiers, the cascade itself (`classify()` stays the `NotImplementedError` stub, listed in `__all__`); choosing threshold values (no default: #25 produces the evidence); the amount tie-breaker (proposal 0001: amount is "tie-breaker only", a later refinement); a third "coverage" gate (rejected at Plan, see *Alternatives*); explanations in the review file (build step 6); reading `corrected` rows from staging (build step 3); persisting the index.
- **External dependencies:** `pypi` (the C4-verify dependency sync and the nox gate both install scikit-learn from PyPI)
- **Test file:** tests/test_knn.py
- **Citations expected:** Do must cite path:line on the target branch for every change it builds on: the stub `src/autobook/pipeline/classifier.py` it replaces; `pyproject.toml` (`dependencies = []` and its comment; `[[tool.mypy.overrides]]` for `gnucash.*`, the peer for the new overrides); the `IMPLEMENTED` set in `tests/test_skeleton.py` (added by #23); `src/autobook/contracts.py` (`Sign`, `CorpusRow` and its `provenance` field at `:129`, `CorpusContract`, `ContractError` at `:110`, the peer for `KnnError`); `autobook.pipeline.normaliser` (`load`, `Normaliser.normalise`, `Normaliser.version`, `NormalisedMemo`; from #23); `tests/fixtures/synthetic/corpus_builder.py` (`build_corpus`, `NOVEL_MERCHANT`, `GIROKONTO`, `REVOLUT`, `LEBENSMITTEL`, `MIETE`; rows sorted oldest first at `:100`); ch.5 §5.2 *Classifier*; ch.8 §8.3. For each iteration-3 hunk kept unchanged, say so in `build-notes.md` rather than re-deriving it.
- **Prior-art check (triage cycles):** searched by path. `git -C ../autobook log --all -- src/autobook/pipeline pyproject.toml tests/test_skeleton.py` shows only the scaffold (0e0b7dc), a docs commit (2baf4d6), testenv (2a4b845), #22's skeleton (23ce73f) and #23's normaliser (6b5a99d, draft PR #50, folded base); `classifier.py` is a stub and `dependencies` is empty on `main`. `gh pr list --state all` (9 PRs: 8 merged, #50 draft) has nothing on kNN. Closed issue #5 (`NOT_PLANNED`) was split into #22–#26, not rejected; its kNN scope is this issue's. The only prior work is this bundle's own iterations 1–3 (`iteration-v1..v3/`), which this brief builds on.
- **Disposition hint:** new-feature

## Motivation

Build step 2 decides whether the design holds: whether the user's own history is dense
and consistent enough for kNN to abstain reliably on novel memos (ch.9). That needs an
index whose abstention is real: a distance gate that stops confident errors on unseen
merchants, and a margin gate that stops guesses between two habits. The backtest (#25)
measures exactly this index, so the two gaps iteration 3 exposed would have been measured
as part of "the design": a memo with new words scored as an exact match, and a recurring
payee whose booking changed voting with only its oldest rows.

## Design

### Where it lives

In `autobook.pipeline.classifier`, the Classifier building block of ch.5, of which kNN
is tier 5. No new module (a new module under `autobook.pipeline` would also be
discovered by `tests/test_skeleton.py`). `__all__` lists `classify` (still the stub) plus
the names below.

### Public API (fixed: #25 is briefed against it; unchanged from iteration 3)

- `class KnnError(ValueError)`: every refusal (bad provenance, mixed normaliser
  versions, invalid thresholds, malformed rows).
- `@dataclass(frozen=True) class IndexRow`: `token: str` (normalised memo),
  `source_account: tuple[str, ...]`, `sign: Sign` (from `autobook.contracts`),
  `destination_account: tuple[str, ...]`, `post_date: datetime.date`,
  `provenance: Literal["observed", "corrected"]`, `normaliser_version: str`.
  `__post_init__` validates every field (exact types, as iteration 3) and raises
  `KnnError` for any provenance other than `observed` or `corrected`.
- `index_rows(corpus: CorpusContract, normaliser: Normaliser) -> tuple[IndexRow, ...]`:
  one row per corpus row, `token` and `normaliser_version` from
  `normaliser.normalise(row.raw_memo, row.source_account)`, and **`provenance` copied
  from `row.provenance`** (never a literal), so the `IndexRow` check sees the real value.
  Today every corpus row is `observed`, so the output is unchanged.
- `HALF_LIFE_DAYS: Final[float] = 548.0` (ch.5 "~18-month half-life"; 18 × 365/12 =
  547.5, rounded). Fixed here because (j) pins a margin that depends on it.
- `KnnIndex.build(rows: Iterable[IndexRow], *, max_distance: float, min_margin: float,
  half_life_days: float = HALF_LIFE_DAYS) -> KnnIndex`.
- `KnnIndex.query(token: str, source_account: tuple[str, ...], sign: Sign, *, as_of:
  datetime.date, normaliser_version: str, exclude: IndexRow | None = None) -> KnnResult`.
- `@dataclass(frozen=True) class KnnResult`: `account`, `candidate`, `nearest_distance`,
  `margin`, `share`, `failed_gates: frozenset[Literal["distance", "margin"]]`, property
  `accepted`. As iteration 3.

### Semantics

Unchanged from iteration 3 (keep its code): provenance refused at two points
(constructor and `build`, exact types, `type(row) is IndexRow`); one normaliser version
per index (`build` and `query`); thresholds required, `0 <= max_distance < 1`,
`0 < min_margin <= 1`, half-life positive and finite; one partition per
`(source_account, sign)` fitting its own `TfidfVectorizer(analyzer="char_wb",
ngram_range=(3, 5), sublinear_tf=True)` (defaults otherwise: `smooth_idf=True`,
`norm="l2"`); `_clamp` (distance below `1e-9` is `0.0`, capped at `1.0`); weights
`(1 - distance) * 0.5 ** (age_days / half_life_days)` with `age_days = max(0, (as_of -
post_date).days)`; share, candidate (exact tie: smaller path tuple), `margin =
(share(candidate) - share(runner-up))`, total weight 0 gives margin 0; gates
`nearest_distance <= max_distance` and `margin >= min_margin`, both evaluated, every
failure listed (the distance gate stays `<=`, not the strict "under cutoff" of ch.5 and
proposal 0001: distances are continuous apart from the exact values 0 and 1, and
`max_distance < 1`, so the two comparisons differ only at `max_distance = 0`, where `<=`
means "exact matches only" and `<` would mean "nothing ever passes"; ch.5 states the
comparison and the PR description lists it among the differences from proposal 0001);
empty token or empty partition gives `nearest_distance = None` and
`failed_gates = {"distance"}`; one account only, no split type.

#### Distance (changed: unseen n-grams count)

The query is measured over **all** of its character n-grams, including those no row of
the partition contains. `TfidfVectorizer.transform` drops those silently; the index must
not.

- Take the n-grams the partition's own vectoriser analyser produces for the query
  (`build_analyzer()`, so the same `char_wb` 3–5 and lowercasing as the rows).
- Each distinct n-gram `g` with count `c` gets the component `(1 + ln c) * idf(g)`.
  `idf(g)` is the partition's fitted idf for an n-gram in its vocabulary, and
  `ln((1 + n) / 1) + 1` for one that is not, where `n` is the number of rows in the
  partition. That is scikit-learn's smooth idf at document frequency 0: the weight a term
  that no row contains would get.
- L2-normalise the query over all its components, unseen ones included. The distance to
  a row is `1 - (query · row)`, where `row` is the partition's own L2-normalised TF-IDF
  vector, then `_clamp`.
- Equivalently: the cosine similarity over known n-grams, scaled by
  `‖known part‖ / ‖whole query‖`. A query whose n-grams are all known gets exactly the
  distance it had in iteration 3, so criteria (a)–(i) are unaffected.
- A query whose n-grams are all unseen has similarity 0 to every row, so distance 1.
- Implementation is Do's choice (e.g. a `norm=None` transform plus the unseen mass, or a
  direct sparse dot product). A `HashingVectorizer` is **not** acceptable: its bucket
  collisions on a 30–60k-row history let unseen n-grams count as known, which is the
  defect being fixed. `NearestNeighbors` is no longer required (see *Neighbours*).

**Leave-one-out (`exclude`).** When `exclude=R` is given, the query's weights are
computed as if `R` were not in the partition: `n` becomes `n - 1`, and each n-gram's
document frequency drops by one if `R`'s token contains it (the n-grams of `R` from the
same `build_analyzer()`). The idf is then scikit-learn's smooth idf on those counts,
`ln((1 + n') / (1 + df')) + 1`, so an n-gram that only `R` contains gets the unseen
weight `ln(1 + n') + 1`. The query is still L2-normalised over all its components.
Without `exclude`, nothing changes (`n' = n`, `df' = df`).

- Why: #25 calibrates `max_distance` on leave-one-out distances. Without this, a novel
  merchant's own row would make its n-grams look known to itself, and its distance would
  come out lower than in production, which is the exact case the distance gate exists
  for. Criterion (m) pins it.
- What stays approximate: the other rows' vectors keep the idf fitted with `R` in. Making
  those exact means a refit per query, which is rejected below (*refit*). What differs is
  the idf of n-grams that `R` shares with other rows (their document frequency is one
  higher than without `R`, and `n` is one higher); n-grams only `R` has are absent from
  every other row's vector, so they do not matter there. The `query`
  docstring and ch.5 say so, so #25 knows its distances are leave-one-out for the query
  but not for the other rows.
- (m) is a case where the rule is exact: `S` and `R` share no n-gram, so `S`'s vector is
  the same with or without `R`, and `query(..., exclude=R)` equals a query on an index
  of `S` alone (0.2368, as in (k)).
- Implementation is Do's choice; the partition needs each vocabulary term's document
  frequency (e.g. `(X > 0).sum(axis=0)` at fit time).

#### Neighbours (changed: every row tied with the k-th distance votes; `exclude` first)

`k = 15`. For a query:

1. Compute the distance (above) from the query to **every** row of its partition.
2. If `exclude` is given, remove one row equal to it (dataclass equality; equal rows are
   interchangeable, so which one does not matter). Do this **before** choosing voters.
   If the query's partition holds no row equal to `exclude` (it is in no partition, or
   in another `(source_account, sign)` than the query's), raise `KnnError`: a
   leave-one-out that silently left nothing out would score the row against itself and
   make a broken backtest look perfect. Check this before any other result is returned,
   including the empty-token and empty-partition results. The message names the field
   (`exclude`) and the reason, never the row's memo (iteration 3's privacy rule for
   messages).
3. Let `m` be the rows left. If `m == 0`, return the empty result (`nearest_distance =
   None`, `{"distance"}`). Otherwise let `d_k` be the `min(k, m)`-th smallest distance.
   **Every** remaining row with distance `<= d_k` votes (after `_clamp`, so identical
   tokens tie exactly).
4. `nearest_distance` is the smallest remaining distance.

So a group of identical memos votes as a whole, and recency decides among them, instead
of input order deciding which 15 enter. The result depends only on the set of rows (up to
float summation order, which is why tests compare floats with `pytest.approx`). The vote
can hold more than 15 rows; brute force over one partition (at most tens of thousands of
rows) stays cheap.

### Tests and the gate (C4-verify requirements: read this before writing a test)

- `tests/test_knn.py`: success criterion (a)–(l), plus anything else above Do considers
  worth pinning. Keep iteration 3's hardening tests (exact-type checks, `str` subclass and
  `unittest.mock.ANY` provenance, float snap, privacy of messages).
  - Build the (a)/(b)/(e) index from `index_rows(build_corpus(0), normaliser)` restricted
    to rows dated before the novel row; query with `as_of` set to the novel row's date.
  - (c), (h), (i), (j), (k), (m): invented `IndexRow`s in the test, each in its own index.
  - (j): build the rows in chronological order first (that is the order `build_corpus`
    and a book export produce), then the reversed and shuffled orders.
  - (l): take a `build_corpus(0)` corpus, `object.__setattr__(corpus.rows[0],
    "provenance", "synthetic")`, assert `index_rows` raises `KnnError`.
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
#23. Confirm it has `normaliser.load`, `Normaliser.version`, `NormalisedMemo` and the
`IMPLEMENTED` set in `tests/test_skeleton.py` with the three-assertion exemption
(iteration 3 confirmed all of these at `normaliser.py:120`, `:89`, `:101`, `:69` and
`test_skeleton.py:22`/`:52`). If any is missing or shaped differently, stop and report
it in `build-notes.md`; do not re-implement #23's API.

### Docs currency (same PR)

ch.5 §5.2 *Classifier*, the kNN bullet (iteration 3 already wrote most of it; update it):
the API names, how distance is measured (unseen n-grams count, at the idf of a term no
row contains), how voters are chosen (every row tied with the 15th distance; `exclude`
removed first), what `exclude` does (leave-one-out for the query's idf and the vote, the
other rows not refitted; `KnnError` when it matches no row), the weight, share and margin
definitions, the gate comparisons (distance `<=`, margin `>=`, and why `<=`),
`HALF_LIFE_DAYS = 548`, the two provenance checks, `index_rows` copying provenance, and
the one-version rule. ch.8 §8.3: "Index construction filters on provenance" becomes a
refusal (construction raises on a row that is not `observed` or `corrected`); keep
"there is no path by which a synthetic row can enter". Do not edit proposal 0001 or the
threat model. Update the `pyproject.toml` comments as in Scope (2).

## Alternatives considered

- **Recency: break distance ties newest first, then cut to 15.** Rejected at Plan
  (maintainer, iteration 4): it fixes the order dependence but still drops older tied rows
  from the vote, so decay never sees them; on the (j) rows it gives margin 0.566 instead
  of 0.363, i.e. it accepts where weighing the whole group abstains.
- **Recency applied after a distance-only cut (iteration 3).** Rejected: with more than
  15 identical memos, input order picks the voters, oldest first in production, and the
  tier accepted a stale account with margin 1.0.
- **Unseen n-grams: a third "coverage" gate.** Rejected at Plan: the issue and proposal
  0001 define two gates; a third would change what #25 calibrates. Counting unseen
  n-grams inside the distance keeps two gates and makes the distance mean what the design
  says it means.
- **Unseen n-grams: a `HashingVectorizer`.** Rejected: same numbers as the chosen rule
  when nothing collides (checked at Plan), but collisions on a large history make unseen
  n-grams count as known.
- **Unseen n-grams: refit the vectoriser on partition + query.** Rejected: a refit per
  query is too slow for #25's leave-one-out over 30–60k rows, and it shifts every row's
  idf per query.
- **`exclude` removes the row from the vote only (iteration 3).** Rejected at Plan
  (revision): the query's idf still counts the row, so a novel merchant's n-grams look
  known to itself and leave-one-out distances run low on exactly the case #25 calibrates
  the distance gate for ((m): 0.1056 instead of 0.2368).
- **`exclude` that matches nothing is ignored.** Rejected at Plan (revision): it turns a
  leave-one-out bug into a perfect score.
- **Unseen n-grams: accept as a known gap in the threat model.** Rejected at Plan: it
  is a confident-error path through the distance gate (rubric *Abstention erosion*).
- **Silently dropping non-`observed`/`corrected` rows.** Rejected: it would hide a
  provenance bug that the design says cannot exist.
- **A pure-Python TF-IDF and cosine.** Rejected: proposal 0001 names scikit-learn.
- **Default threshold values in code.** Rejected: any default would be a threshold set
  without evidence.
- **Splitting this issue (core index first, gate refinements second).** Rejected at Plan
  (maintainer, iteration 4): the rounds went to separate hardening findings and two
  unstated design rules, not two features in one slice; a split would merge a core with
  a known confident-error path and cost a full extra cycle.

## Impact & compatibility

First runtime dependency (scikit-learn, with numpy, scipy, joblib, narwhals,
threadpoolctl). Supports Python ≥3.11, matching `requires-python` and the CI matrix
3.11–3.14. The pipeline still never imports `gnucash`; scikit-learn does not either.
Distances differ from iteration 3 only for queries with n-grams the partition never saw,
and only upward. Expect the advisory `T2-threat-model` check to land in SUMMARY §6
(`src/autobook/pipeline/classifier.py` matches its `*classif*` pattern). Decided at Plan:
no threat-model edit in this PR; a follow-up issue covers the stale "Nothing is built
yet" line (`.oss-scanner/threat_model.md:11`) and a sentence on how the kNN distance is
measured. Do does not edit `.oss-scanner/threat_model.md`; the PR description names the
follow-up.

## Open questions

None open. Settled with the maintainer (eduralph) at Plan, iteration 1: scikit-learn as a
dependency with a mypy override, provenance refusal raises, recency weighting included,
thresholds required with no default. Iteration 4: every row tied with the k-th distance
votes and `exclude` is applied first; unseen n-grams count in the distance at the idf of
a term no row contains; no threat-model edit, follow-up issue instead; no split.
Plan-review revision (planner decisions, for the maintainer to confirm at sign-off):
`exclude` is leave-one-out for the query's idf, the other rows not refitted; an
`exclude` that matches no row raises `KnnError`; the distance gate stays `<=`.
None of these are on the issue thread (`notes.json` has no comments). Sign-off confirms
them, and the PR description puts them on the record; it must state them, including that
construction refuses bad provenance where proposal 0001 says "filters", that the
neighbour and distance rules refine proposal 0001's `NearestNeighbors(n_neighbors=15)`
sketch, that the distance gate is `<=` where proposal 0001 and ch.5 say "under cutoff",
that `exclude` is leave-one-out for the query only (so #25's calibration knows), and
that a kNN index version is deferred to the version tuple.

## STOP discipline

Draft only until Check sign-off. Pushing to a feature/draft branch and opening a
draft PR MAY happen during the cycle (useful for CI feedback). The PR MUST NOT be
marked ready before sign-off accepts.

## Plan-review responses (plan-advisory-plan-reviewer.md)

Plan-review response: (1) `exclude` not leave-one-out: revised. *Distance* gains a
query-side leave-one-out rule, the residual approximation is stated (docstring, ch.5, PR
description), and criterion (m) tells the two behaviours apart (0.2368 vs 0.1056,
computed with a prototype).

Plan-review response: (2) `exclude` with no equal row: revised. It raises `KnnError`,
checked first, pinned by the new last case of (i) (absent row, and a row in another
partition).

Plan-review response: (3) maintainer rulings not on the tracker: the brief stands, with
a clarification. The rulings were made with the maintainer in the Plan session and are
recorded here. This revision's three new calls are marked as planner decisions to
confirm. *Open questions* now makes sign-off the place they are confirmed, and the PR
description puts all of them, and the proposal 0001 differences (`:316`, `:344`), on the
public record.

Plan-review response: (4) branch target: the brief stands; `main` is correct
(INTEGRATION §2). The driver cuts a wave>0 bundle's branch from the line commit it was
built on and opens the PR against the real base (`publish.py:261-282`), so the branch
carries #23 and CI finds `normaliser`. *Ordering note* now says this and that #50
merges first.

Plan-review response: (5) inclusive distance gate: the brief keeps `<=` and now says
why. The two comparisons differ only at `max_distance = 0`, since `max_distance < 1` and
the only exact distance values are 0 and 1. ch.5 and the PR description must state it
as a difference from "under cutoff".

Plan-review response: (6) half-life bookkeeping: revised. `HALF_LIFE_DAYS = 548.0` is
already in iteration 3 (`iteration-v3/patch.diff:162`), so no hunk is expected; *Scope*
and *Difficulty* now say so.

## Iteration 4 — carry-forward (from the previous attempt)
- Sign-off rationale: Auto-iterate (round 3): rebuilding for the implementation-level findings — T2 Shape — Accept the planned threat-model follow-up and ensure its tracking issue is named at publish — existing policy covers failed-gate acceptance and synthetic admission, but the security-touch gate explicitly leaves the unchanged model to sign-off (`gate-logs/T2-threat-model.log:10`, `target/.oss-scanner/threat_model.md:258`, `target/.oss-scanner/threat_model.md:269`, `brief.md:275`).; The `df - 1` leave-one-out rule at `src/autobook/pipeline/classifier.py:267-268` is pinned only where df goes from 1 to 0, so a wrong rule passes the whole suite. In (m) (`tests/test_knn.py:561`) every n-gram of the excluded row has df 1. In the 0.9430 case (`tests/test_knn.py:413`) every query n-gram has the same df (16), so any uniform change to df leaves the query vector proportional and the margin unchanged. I checked four variants, and all give 0.943 there: `df - 1`, `df = 0`, df unchanged, and n unchanged. A mutant that sets `df = 0` for every n-gram of the excluded row survives (i) and (m), but it treats n-grams shared with other rows as unseen, which pushes leave-one-out distances up for known merchants. Concrete case that tells them apart: rows `[BEISPIELMARKT, BEISPIELMARKT, BEISPIEL GMBH]` (one partition, same date), query `BEISPIELMARKT` with `exclude=` the first row. The correct rule gives `nearest_distance ≈ 0.000877` and 0.6602 to the GMBH row. The `df = 0` mutant gives 0.00781 and 0.5856. Add that case (confirm the values on scikit-learn first) so the shared-n-gram path of the rule is pinned.; The docs claim at `docs/design/architecture/05-building-block-view.md:366-367` ("so an exact token match passes even `max_distance = 0`") is false under `exclude`. With `exclude`, the query's idf uses `n - 1` and `df - 1`, but the remaining rows keep the idf they were fitted with (`classifier.py:257-274`). Whenever the query's n-grams have different dfs, the two weightings stop being proportional, so an identical remaining row is no longer at distance 0. With the rows above, the surviving exact duplicate measures 0.000877. That is above `_IDENTICAL` (`classifier.py:55`), so `max_distance=0` fails the distance gate on a leave-one-out of a repeated merchant. The sentence needs to say it holds without `exclude` only. The `exclude` bullet at `:390-395` says "exact on the query's side only", but it does not spell out this effect.. Deferred, not addressed here: 11 finding(s) that need human judgment, held in deferred-findings.json for the human at handover — not build work
- Full previous attempt preserved in `iteration-v4/` (patch.diff, build-notes.md, SUMMARY.md, check-*).
- Address the above; do NOT re-attempt the rejected approach unchanged. Satisfy the brief's Success criterion (the end result).
