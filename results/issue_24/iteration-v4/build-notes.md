# Build notes — issue 24 / knn-index-abstention-gates (iteration 4)

Target: Ralphovi/autobook @ `main`, built on the folded base
`pdca-integration/main-r1726f2053868` (tip `0df021f`, holds #23). Worktree:
`$PDCA_WORKTREE` = `/home/eddie/autobook/autobook.pdca-wt`. Starting point:
`iteration-v3/patch.diff`, applied cleanly to `0df021f`, then changed only where the brief
changes it.

Line references: `base:` = the target branch at `0df021f`; `new:` = the patched tree.

## Prerequisite check (#23 on the base)

All present and shaped as the brief says, so nothing of #23 was re-implemented:
`NormalisedMemo` (base: `src/autobook/pipeline/normaliser.py:69`), `Normaliser`
(`:89`), `Normaliser.version` (`:101`), `Normaliser.normalise` (`:105`), `load`
(`:120`); `IMPLEMENTED` (base: `tests/test_skeleton.py:22`) and the exemption
(`:52`).

## What changed against iteration 3, and why

1. **Distance counts unseen n-grams** (brief *Distance*). `_Partition._distances`
   (new: `src/autobook/pipeline/classifier.py:242-274`) builds the query vector itself
   from the partition's own analyser (`build_analyzer()`, kept at new `:210`): each distinct
   n-gram gets `(1 + ln c) * (ln((1 + n) / (1 + df)) + 1)`, with `df = 0` for an n-gram
   outside the vocabulary. The L2 norm runs over every component (`squared`, `:270`); only
   vocabulary columns go into the dense query vector (`:271-272`); the distance is
   `1 - matrix @ query / norm`, then `_clamp` (`:274`). Document frequencies come from the
   fitted matrix, `(X > 0).sum(axis=0)` (new: `:213`), as the brief suggests.
   - Checked against the pinned values: (k) 0.2368 / 0.3589, (m) 0.1056 / 0.2368, and
     the FILIALE row in (i) at 0.589. The tests pass on them, and a hand calculation
     agrees: `BEISPIELMARKT` has 36 distinct n-grams and each four-letter word has 9, so
     1 − 6/√(36 + 9·1.6931²) = 0.23677, 1 − 6/√(36 + 18·1.6931²) = 0.35894,
     1 − 6/√45 = 0.10557, and 1 − 6/√(36 + 18·3.1401²) = 0.58936.
   - Implementation choice: one code path, with the idf computed from `(n, df)` for every
     n-gram rather than reading `idf_` for known ones. With `exclude`, `n` changes for
     every n-gram, so `idf_` could not be reused there anyway. Without `exclude` the
     formula is scikit-learn's own (`TfidfTransformer.fit`: `log((n + 1) / (df + 1)) + 1`),
     so all-known queries get iteration 3's distances up to float rounding (the
     exact-match raw values come out about −2e-16, and `_clamp` snaps them to 0).
   - Rejected: `transform()` with `norm=None` plus the unseen mass. It covers the
     no-`exclude` case but not the leave-one-out idf, which needs `n − 1` for every
     n-gram. It would mean two code paths for one rule. `HashingVectorizer` and a refit
     per query are rejected by the brief.
   - `NearestNeighbors` is gone (it is no longer needed: brief *Neighbours*), and so is
     its import.

2. **Every row tied with the k-th distance votes; `exclude` first** (brief
   *Neighbours*). `_Partition.voters` (new: `:219-240`): drop one equal row first (`:229-230`,
   position from the `_position` map at `:191-195`), empty → no voters (`:231-232`),
   cutoff = the `min(k, m)`-th smallest remaining distance via `np.partition` (`:235-236`),
   every remaining row `<= cutoff` votes (`:237`), sorted closest first with a stable sort
   (`:239`). `nearest_distance` is then `voters[0]`, which `_vote` already reads
   (unchanged). Distances are clamped before the cutoff, so identical tokens tie exactly.

3. **`exclude` leaves the row out of the query's idf** (brief *Leave-one-out*).
   `_distances` lowers `n` by one and the `df` of each of the excluded row's n-grams by one
   (new: `:257-268`). The other rows' vectors stay as fitted; the `query` docstring
   (new: `:366-379`) and ch.5 say so.

4. **`exclude` that matches no row raises `KnnError`, before any result** (new:
   `:400-404`). The partition lookup and `holds` (new: `:215-217`) run before the
   empty-token and empty-partition results. The message names `exclude` and the reason,
   never the memo (tested).

5. **`index_rows` copies `row.provenance`** (new: `:163-183`, the line at `:179`).
   `CorpusRow.provenance` is `Literal["observed"]` (base: `src/autobook/contracts.py:129`),
   which fits `IndexRow.provenance`, so mypy is satisfied with no cast.

6. **`_clamp` works on arrays** (new: `:277-284`). The same rule as iteration 3: under
   `1e-9` is 0, capped at 1. I dropped "opposite ones just over 1" from the docstring: with
   non-negative vectors the dot product is never negative, so the computed distance cannot
   exceed 1; the cap stays as a guard.

7. **One addition beyond the brief's list: `query` runs `_check_row` on `exclude`**
   (new: `:386-391`). Equality and hashing then see exact field types only. Without it,
   an `exclude` carrying `unittest.mock.ANY` or a list in a field (set with
   `object.__setattr__`) raises `TypeError` from the dict lookup, not `KnnError` (mutation
   M6 below shows both cases). It keeps "every refusal is a `KnnError`" true, and it costs
   a handful of type checks per query. Messages keep `_check_row`'s field names (for
   example `provenance: …`), without an `exclude.` prefix. Adding the prefix would have
   meant touching every line of `_check_row`, which the brief says to keep.

`_vote` (new: `:410` on), `build`, `IndexRow`, `KnnResult`, the validators, the
constants (`HALF_LIFE_DAYS = 548.0` at new `:46`, `_IDENTICAL`), and the `<=`/`>=` gate
comparisons (new: `:431`, `:433`) are unchanged from iteration 3. The only exception is
the `_K` comment (new: `:48-49`), which now describes the tie rule.

### Iteration-3 hunks kept unchanged (not re-derived)

- `docs/design/architecture/08-crosscutting-concepts.md` (base: `:69-70` → new: `:69-70`):
  "filters" → "refuses (raises on)", keeping "there is no path by which a synthetic row can
  enter". Exactly as the brief asks.
- `tests/test_skeleton.py:22`: `IMPLEMENTED` gains `"autobook.pipeline.classifier"`.
- `pyproject.toml`: `dependencies = ["scikit-learn>=1.5"]` (base: `:30` → new: `:31`), the
  `sklearn.*` override (new: `:101-104`, peer of the `gnucash.*` override at base
  `:94-98`), and the numpy override's settings (new: `:114-116`).
- `classifier.py`: module docstring, `__all__`, `KnnError`/`_fail` (peer: `ContractError`,
  base `src/autobook/contracts.py:110`), `_text`/`_choice`/`_path`, `IndexRow`,
  `_check_row`, `KnnResult`, `_threshold`, `KnnIndex.__init__`/`build`, `_vote`,
  `classify` (still the stub, base: `src/autobook/pipeline/classifier.py:16-18`).

### Changed in this round beyond the code

- `pyproject.toml` comments: the scikit-learn comment (new: `:25-30`) no longer says it
  does the nearest-neighbour search. The numpy override comment (new: `:106-113`) no
  longer says nothing imports numpy: the classifier now does (new: `classifier.py:29`).
  I confirmed the comment's other claim. numpy 2.5.4's `.pyi` files in `.nox/types` use
  `type X = ...` statements (for example `numpy/matlib.pyi`).
- ch.5 §5.2 *Classifier* (base: `docs/design/architecture/05-building-block-view.md:310`,
  kNN bullet `:335-341` → new `:335-409`). The kNN text has the API names, *Distance*
  (unseen n-grams at the idf of a term no row contains), *Vote* (rows tied with the 15th
  all vote), *Gates* (with why `<=`), *`exclude`* (leave-one-out on the query side only;
  `KnnError` when nothing matches), and *Provenance and version* (two checks;
  `index_rows` copies provenance; one version).
  **One edit to the pre-existing sentence:** "is under its cutoff" → "is within its
  cutoff" (new: `:339`), so the chapter does not contradict its own `<=` statement.
  Proposal 0001 is untouched; the PR description must still list `<=` against "under
  cutoff" as a difference (brief *Open questions*).

## Decisions for sign-off

- **numpy is imported directly but not declared** (`dependencies` lists only
  scikit-learn, as the brief's Scope (2) says). scikit-learn hard-requires numpy, so it is
  always installed. Declaring it would be a one-line change:
  `dependencies = ["numpy", "scikit-learn>=1.5"]` plus a clause in the comment. I left it
  out because the brief fixes the dependency list and the maintainer agreed scikit-learn
  only. If you want direct imports declared, add that line.
- **Test imports**: the brief's example `import autobook.pipeline.classifier as classifier`
  is rejected by the target's lint: ruff PLR0402, "Use `from autobook.pipeline import
  classifier` in lieu of alias" (checked with the gate's ruff 0.14.2). The test keeps
  iteration 3's `from autobook.pipeline import classifier, normaliser`
  (`tests/test_knn.py:23`). That is still a module import, and the red leg confirmed 0
  collection errors.
- **Order independence is up to float rounding**, as the brief accepts. Per-account sums
  follow voter order, and ties are kept in position order. scikit-learn's own row
  normalisation also sums in an input-order-dependent entry order (its vocabulary indices
  are assigned by first appearance and then remapped). So bit-identical results across
  input orders are not reachable without changing how scikit-learn fits. The one visible
  effect: on an exact tie between two accounts, `candidate` can flip between input orders.
  The margin is then about 0, so the margin gate fails and `account` is `None` either way.
- **Cost of the tie rule** (measured on a synthetic 30,000-row partition, 40 accounts,
  this machine): build 0.35 s. A query with known n-grams takes 0.7 ms (0.6 ms with
  `exclude`). A query sharing no n-gram with any row takes 10.7 ms: every row is at
  distance 1, ties with the 15th, and goes through `_vote` with weight 0. `_vote` was
  kept as is, per the brief. If #25's backtest finds 10 ms too slow, a shortcut for
  "cutoff = 1" is the place to change it.

## Tests (`tests/test_knn.py`, 50 tests)

Iteration 3's 43 tests, minus the weak
`test_exclude_keeps_k_neighbours_when_the_partition_is_larger`, plus:

| Criterion | Test (`tests/test_knn.py`) |
|---|---|
| (i) case 3, FILIALE, margin 1 → 0.9430 | `test_exclude_comes_out_before_the_voters_are_chosen` (:413) — replaces the weak test |
| (i) case 4, absent row (and message privacy) | `test_exclude_that_matches_no_row_is_an_error` (:427) |
| (i) case 4, row of another partition | `test_exclude_from_another_partition_is_an_error` (:440) |
| extra: check before the empty-token / empty-partition results | `test_exclude_is_checked_before_any_result_is_returned` (:449) |
| extra: `exclude` with `mock.ANY` / list field | `test_an_exclude_with_a_tampered_field_is_refused` (:465) |
| (j) oldest first: MIETE, 0.3630, `{"margin"}` | `test_every_row_tied_with_the_kth_distance_votes` (:488) |
| (j) newest first, `random.Random(24)` shuffle | `test_the_vote_does_not_depend_on_the_order_of_the_rows` (:499) |
| (k) 0 / 0.2368 / 0.3589 | `test_ngrams_no_row_contains_move_the_query_away_from_history` (:520) |
| extra: all-unseen query at distance 1 | `test_a_query_history_never_contained_is_at_distance_one` (:536) |
| (l) | `test_index_rows_copies_provenance_from_the_corpus` (:549) |
| (m) 0.1056 / 0.2368, equal to `S` alone | `test_exclude_takes_its_row_out_of_the_query_idf` (:561) |

The test file follows the brief's three rules. Every name the patch adds is reached
through the module object inside test bodies. It contains no `sklearn`, no skip, and
neither of the two banned marker words (checked with a search).

## Evidence (red → green)

- **C4-verify, the gate's own script** (`engine/scripts/run-verify.sh` with
  `PDCA_BUNDLE`/`PDCA_WORKTREE` set):
  `PDCA-EVIDENCE: C4 PASS — red without the fix (49 of 55 failed), green with it`. The
  green leg ran 55 tests (`test_knn.py` + `test_skeleton.py`). The red leg had 0
  import/collection errors. The 6 that stay green are the 5 skeleton tests and
  `test_the_cascade_entry_point_is_still_the_stub`, which hold with or without the fix.
- **Against the iteration-3 classifier** (the rejected attempt, via
  `engine/nox.sh test-3.14 -- tests/test_knn.py`): 11 of 50 failed. These are every
  (i)-case-4, (j), (k), (l) and (m) test plus the two tampered-`exclude` tests. For
  example, (m) with `exclude` gave 0.10557, the value the brief predicts for iteration 3.
- **One-rule mutations** (each applied with `sed`, run through `engine/nox.sh test-3.14`,
  restored from `patch.diff`, and the worktree re-compared to `patch.diff` afterwards):

  | Mutation | Tests that fail |
  |---|---|
  | M1 `exclude` not taken out of the query idf | (m) only |
  | M2 voters cut to 15 in input order | (j) ×3 |
  | M3 `exclude` with no equal row silently ignored | (i)-case-4 ×3 |
  | M4 `index_rows` sets `"observed"` itself | (l) |
  | M5 unseen n-grams left out of the query norm | (k), all-unseen, (b), (m) |
  | M6 no `_check_row(exclude)` | tampered `exclude` ×2 (both raise `TypeError`, not `KnnError`) |

- **Commit readiness**: `engine/nox.sh gate` passes all seven sessions. That covers
  `ruff format --check` (38 files formatted), `ruff check`, `mypy` strict (37 files),
  pytest (312 passed, 1 skipped, 7 deselected; the skip is the pre-existing book test
  without `gnucash`), `typos` and `lint_docs`. Before the gate I ran
  `engine/nox.sh fmt -- --fix`, which reformatted one line in `classifier.py`. The target
  has no `.pre-commit-config.yaml`; its gate is `nox -s gate`. DCO sign-off is publish's
  job.

## Refuting my own test

- **(a) Genuine red? Yes.** With the production hunks reverted, 49 of 55 tests failed
  (C4-verify red leg, `AttributeError` inside test bodies, 0 collection errors). Against
  the iteration-3 code, which lacks only this round's rules, 11 failed. The mutation table
  shows each new rule is pinned by its own test.
- **(b) Production path? Yes.** The tests import `autobook.pipeline.classifier` and call
  `IndexRow`, `index_rows`, `KnnIndex.build` and `KnnIndex.query`, the code
  `patch.diff` changes. There is no stand-in and no mock of the index. The fixture
  history goes through the real `normaliser.load(tmp_path)` and `build_corpus(0)`.
- **(c) Fixture includes the fault? Yes.** The (k) and (m) queries carry n-grams the
  index never saw (`QXZV`, `WJKQ`). (j) holds 25 rows tied at distance 0, more than k,
  in the stale-first order a book export produces. (i)-case-4 passes an `exclude` that
  really is absent, or really is in the other partition. (l) really sets `"synthetic"`
  on a corpus row with `object.__setattr__`. None of them is curated out.

## Notes for the human

- **External dependencies**: `pypi` (declared in the brief). The nox sessions installed
  from PyPI without trouble, and the instance `.venv` already had scikit-learn 1.9.1
  (C4-verify's `sync_deps` stamp unchanged). No undeclared dependency came up.
- **Expected §6 item**: the advisory `T2-threat-model` check will flag
  `src/autobook/pipeline/classifier.py`. As decided at Plan, this patch does not edit
  `.oss-scanner/threat_model.md`. The PR description must name the follow-up issue (stale
  "Nothing is built yet" line at `.oss-scanner/threat_model.md:11`, and a sentence on how
  the kNN distance is measured).
- **PR description must state** (brief *Open questions*):
  - construction refuses bad provenance where proposal 0001 says "filters";
  - the neighbour and distance rules refine 0001's `NearestNeighbors(n_neighbors=15)`
    sketch;
  - the distance gate is `<=` where 0001 says "under cutoff";
  - `exclude` is leave-one-out for the query only;
  - a kNN index version is deferred to the version tuple;
  - the three planner decisions to confirm (leave-one-out idf, raise on no match, `<=`).
- **Target-repo quirk, outside this patch**: running the tests leaves an untracked
  `tests/fixtures/synthetic/__pycache__/` in the worktree. `.gitignore:55`
  (`!tests/fixtures/synthetic/**`) re-includes everything under that directory, bytecode
  caches too. It is not in `patch.diff`, but a publish that ran `git add -A` in this
  worktree would commit it. Worth a one-line `.gitignore` fix in a separate issue.
