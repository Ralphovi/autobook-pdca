# Build notes — issue 24 / knn-index-abstention-gates (iteration 5)

Target: Ralphovi/autobook @ `main`, built on the folded base
`pdca-integration/main-r1726f2053868` (tip `0df021f`, holds #23). Worktree:
`$PDCA_WORKTREE` = `/home/eddie/autobook/autobook.pdca-wt`.

Line references: `base:` = the target branch at `0df021f`; `new:` = the patched tree.

## Starting point, and why not iteration 3

The brief's header says "Do starts from `iteration-v3/patch.diff`". That was written for
iteration 4. The carry-forward appended for this round names iteration 4 as the previous
attempt ("Full previous attempt preserved in `iteration-v4/`"), and every finding in it
cites iteration 4's lines (`classifier.py:267-268`, `tests/test_knn.py:561`, ch.5
`:366-367`). Those findings are two narrow gaps in an otherwise kept attempt: one missing
test case and one false docs sentence. So I applied `iteration-v4/patch.diff` to
`0df021f` (it applied cleanly) and changed only what the carry-forward asks for.
Rebuilding iteration 4 from iteration 3 would redo the same work for the same result.

I did not read `deferred-findings.json`: the carry-forward says its 11 findings need
human judgment and are not build work.

## Prerequisite check (#23 on the base)

All present and shaped as the brief says: `NormalisedMemo` (base:
`src/autobook/pipeline/normaliser.py:69`), `Normaliser` (`:89`), `Normaliser.version`
(attribute, `:101`), `Normaliser.normalise` (`:105`), `load` (`:120`); `IMPLEMENTED`
(base: `tests/test_skeleton.py:22`) and the exemption (`:52`). Nothing of #23 was
re-implemented.

## This round: the carry-forward, item by item

### 1. The shared-n-gram path of the leave-one-out rule had no test

Finding: the `df - 1` rule (new: `src/autobook/pipeline/classifier.py:258-268`) was pinned
only where `df` goes from 1 to 0, so a mutant that sets `df = 0` for every n-gram of the
excluded row survived the whole suite.

Fix: new test `test_exclude_lowers_the_df_of_ngrams_it_shares_with_other_rows`
(new: `tests/test_knn.py:581-600`), the case the carry-forward proposed. Rows
`[BEISPIELMARKT, BEISPIELMARKT, BEISPIEL GMBH]` (one partition, same date; the GMBH row
books to `MIETE`, so its distance reaches the margin), query `BEISPIELMARKT`:

- without `exclude`: `nearest_distance == 0.0`;
- with `exclude=` the first row: `nearest_distance ≈ 0.000877` (`rel=1e-2`),
  `margin ≈ 0.4924` (`abs=1e-3`), `candidate == LEBENSMITTEL`.

`KnnResult` does not report a per-row distance, so the GMBH distance (0.6602) is pinned
through the margin: both rows vote, both weigh `1 - distance` (same date), and
`(0.999123 - 0.339781) / (0.999123 + 0.339781) = 0.4924`. With the nearest distance held
to ±1%, the margin tolerance holds the GMBH distance to about ±0.0009.

**Values confirmed on scikit-learn 1.9.1** (instance `.venv`, numpy 2.5.4), three ways,
which all agree to the last digit:

| Source | to the other BEISPIELMARKT | to BEISPIEL GMBH |
|---|---|---|
| Independent reference: query idf from a real refit on the two remaining rows, row vectors from the fit with all three | 0.00087744 | 0.66021917 |
| Production code (`_Partition._distances`, and `KnnIndex.query` through the public API) | 0.00087744 | 0.66021917 |
| Hand formula: `BEISPIELMARKT` has 36 n-grams, 18 shared with `BEISPIEL GMBH` (df 3 → 2), 18 only in the two BEISPIELMARKT rows (df 2 → 1); query idf 1 and ln(3/2)+1, row idf 1 and ln(4/3)+1 | 0.0008774354725 | — |

The mutants, on the same rows (computed with the same script):

| Rule for the excluded row's n-grams | nearest | GMBH | margin | caught by the new test |
|---|---|---|---|---|
| correct: `n - 1`, `df - 1` | 0.000877 | 0.6602 | 0.4924 | — |
| `df = 0` (the carry-forward's mutant) | 0.007814 | 0.5856 | 0.4107 | yes (both) |
| `n - 1`, `df` unchanged | 0.000855 | 0.6600 | 0.4922 | yes, by the distance only |
| `n` unchanged, `df - 1` | 0.000051 | 0.6452 | 0.4762 | yes (both) |
| neither (iteration 3) | 0.000000 | 0.6405 | 0.4711 | yes (both) |

The "`df` unchanged" mutant comes within 2.2e-5 of the right distance, which is why the
distance tolerance is relative (±8.8e-6) rather than the `abs=1e-3` the other tests use.
That mutant was already caught by (m); the tight tolerance makes the new case catch it on
its own too.

### 2. ch.5 claimed an exact match passes `max_distance = 0`, which is false under `exclude`

Finding: `docs/design/architecture/05-building-block-view.md:366-367` (iteration 4) said
"so an exact token match passes even `max_distance = 0`" without limiting it to queries
without `exclude`; the `exclude` bullet said "exact on the query's side only" but did not
spell out the effect.

Fix, three places:

- ch.5 *Distance* (new: `05-building-block-view.md:363-368`): the claim is now limited to
  queries without `exclude`. I limited the sentence next to it the same way: "a query whose
  n-grams are all known gets the plain cosine distance" is also false under `exclude`, for
  the same reason. "With `exclude`, neither is guaranteed (see *`exclude`*)". I wrote
  "guaranteed" rather than "holds" because both can still happen under `exclude`. When
  every query n-gram has the same `df`, the remaining duplicate is at exactly 0, as in the
  FILIALE case of (i), where all 36 n-grams have `df = 16`.
- ch.5 *`exclude`* (new: `:396-403`): spells out the effect and why. One row fewer changes
  an n-gram's idf by an amount that depends on its `df`, so the query's weights stop being
  proportional to a remaining row with the same token. The bullet gives the worked
  example (0.000877, above the `1e-9` snap) and says a leave-one-out of a repeated merchant
  can fail `max_distance = 0`. This is the part #25 needs: its leave-one-out distances for
  repeated merchants sit slightly above 0.
- `KnnIndex.query` docstring (new: `classifier.py:377-380`): one sentence saying the
  same thing. The brief has #25 read that docstring for what `exclude` approximates.

I checked the rest of the patch for the same claim. `_IDENTICAL`'s comment (new:
`classifier.py:52-55`), `_clamp`'s docstring (`:277-284`) and
`test_every_exact_token_match_is_at_distance_zero` (`tests/test_knn.py:350`) are about
identical vectors or run without `exclude`, so they stay true. The *Gates* bullet's
"`<=` means 'exact matches only'" (`05-building-block-view.md:388-389`) is the brief's own
wording (brief *Semantics*) and is about distance values. I left it alone.

The only code change this round is the docstring. Behaviour is unchanged from iteration 4.

### 3. T2 threat model (sign-off / publish, not build work)

The carry-forward's first item asks sign-off to accept the planned threat-model follow-up
and publish to name its tracking issue. This patch does not touch
`.oss-scanner/threat_model.md` (brief *Scope*, out of scope). The PR description must name
the follow-up issue: the stale "Nothing is built yet" line at
`.oss-scanner/threat_model.md:11`, and a sentence on how the kNN distance is measured.
Expect `T2-threat-model` in SUMMARY §6 again.

## What the patch does against iteration 3 (unchanged from iteration 4; current lines)

1. **Distance counts unseen n-grams** (brief *Distance*). `_Partition._distances` (new:
   `classifier.py:242-274`) builds the query vector from the partition's own analyser
   (`build_analyzer()`, `:210`). Each distinct n-gram weighs
   `(1 + ln c) * (ln((1 + n) / (1 + df)) + 1)`, with `df = 0` outside the vocabulary. The
   L2 norm runs over every component (`:270`), and the distance is
   `1 - matrix @ query / norm`, then `_clamp` (`:274`). Document frequencies come from
   `(X > 0).sum(axis=0)` (`:213`). Hand checks from iteration 4 still hold: (k) 0.23677 /
   0.35894, (m) 0.10557 / 0.23677, the FILIALE row in (i) 0.58936.
   - One code path, with the idf computed from `(n, df)` for every n-gram. With `exclude`,
     `n` changes for every n-gram, so the fitted `idf_` could not be reused there anyway.
     Without `exclude` the formula is scikit-learn's own smooth idf, so all-known queries
     get iteration 3's distances up to float rounding.
   - Rejected: `transform()` with `norm=None` plus the unseen mass. It covers the
     no-`exclude` case but not the leave-one-out idf, which needs `n - 1` for every n-gram,
     so it would mean two code paths for one rule. `HashingVectorizer` and a refit per query
     are rejected by the brief. `NearestNeighbors` is gone (brief *Neighbours*).
2. **Every row tied with the k-th distance votes; `exclude` first** (brief *Neighbours*).
   `_Partition.voters` (new: `:219-240`) drops one equal row first (`:230`), returns no
   voters when none remain, takes the `min(k, m)`-th smallest remaining distance as the
   cutoff (`np.partition`, `:236`), lets every remaining row `<= cutoff` vote (`:237`), and
   sorts closest first with a stable sort.
3. **`exclude` leaves the row out of the query's idf** (brief *Leave-one-out*). `n - 1`
   (`:260`) and `df - 1` for each of the excluded row's n-grams (`:267-268`). The other
   rows' vectors stay as fitted.
4. **`exclude` that matches no row raises `KnnError`, before any result** (new: `:402-406`,
   the check at `:405`; `holds` at `:215-217`). The message names `exclude` and the
   reason, never the memo.
5. **`index_rows` copies `row.provenance`** (new: `:163-183`, the line at `:179`).
   `CorpusRow.provenance` is `Literal["observed"]` (base: `src/autobook/contracts.py:129`),
   which fits `IndexRow.provenance`, so mypy needs no cast.
6. **`_clamp` works on arrays** (new: `:277-284`), same rule as iteration 3.
7. **`query` runs `_check_row` on `exclude`** (new: `:388-393`, the call at `:393`), so an
   `exclude` carrying `unittest.mock.ANY` or a list field raises `KnnError`, not
   `TypeError` from the dict lookup.

### Hunks kept unchanged from iteration 3 (not re-derived)

- `docs/design/architecture/08-crosscutting-concepts.md` §8.3 (base: `:69-70` → new:
  `:69-70`): "filters" → "refuses (raises on)", keeping "there is no path by which a
  synthetic row can enter".
- `tests/test_skeleton.py:22`: `IMPLEMENTED` gains `"autobook.pipeline.classifier"`
  (base: `:22` holds only the normaliser).
- `pyproject.toml`: `dependencies = ["scikit-learn>=1.5"]` (base: `:30` → new: `:31`), the
  `sklearn.*` override (new: `:101-104`, peer of the `gnucash.*` override at base `:94-98`),
  and the numpy override's settings (new: `:114-116`). The comments were updated in
  iteration 4 and are unchanged here: the scikit-learn comment (new: `:25-30`) and the
  numpy comment (new: `:106-113`), which now says the classifier imports numpy
  (new: `classifier.py:29`).
- `classifier.py`: module docstring, `__all__`, `KnnError`/`_fail` (new: `:64`; peer
  `ContractError`, base `src/autobook/contracts.py:110`), `_text`/`_choice`/`_path`,
  `IndexRow` (`:107`), `_check_row` (`:122`), `KnnResult` (`:144`), `_threshold` (`:287`),
  `KnnIndex.__init__`/`build` (`:293`, `:311`), `_vote` (`:412`), `HALF_LIFE_DAYS = 548.0`
  (`:46`), the `<=`/`>=` gates (`:433`, `:435`), and `classify`, still the stub (new:
  `:447`; base: `src/autobook/pipeline/classifier.py:16-18`). The stub module it replaces
  is base `src/autobook/pipeline/classifier.py:1-18`.
- ch.5 §5.2 *Classifier* (base: `05-building-block-view.md:310`, kNN bullet `:335-341`):
  iteration 4's text, apart from the two edits under item 2 above. That includes
  "is under its cutoff" → "is within its cutoff" (new: `:339`), so the chapter matches its
  own `<=`.

Fixture names the tests use: `build_corpus`, `NOVEL_MERCHANT`, `GIROKONTO`, `REVOLUT`,
`LEBENSMITTEL`, `MIETE` (`tests/fixtures/synthetic/corpus_builder.py:69`, `:43`, `:17`,
`:18`, `:19`, `:20`; rows sorted oldest first at `:100`). `Sign` is
`src/autobook/contracts.py:71`, `CorpusContract` `:149`.

## Decisions for sign-off (carried over, still open)

- **numpy is imported directly but not declared.** `dependencies` lists only
  scikit-learn, as the brief's Scope (2) says. scikit-learn hard-requires numpy. Declaring
  it would be one line: `dependencies = ["numpy", "scikit-learn>=1.5"]` plus a clause in
  the comment.
- **Test imports.** The brief's example `import autobook.pipeline.classifier as
  classifier` fails the target's lint (ruff PLR0402, "Use `from autobook.pipeline import
  classifier` in lieu of alias"). The test uses `from autobook.pipeline import
  classifier, normaliser` (`tests/test_knn.py:23`), which is still a module import. The
  red leg again had 0 collection errors.
- **Order independence is up to float rounding**, as the brief accepts. On an exact tie
  between two accounts, `candidate` can flip between input orders. The margin is then
  about 0, so the margin gate fails and `account` is `None` either way.
- **Cost of the tie rule** (measured in iteration 4 on a synthetic 30,000-row partition):
  build 0.35 s, a query with known n-grams 0.7 ms, a query sharing no n-gram with any row
  10.7 ms, because every row ties at distance 1 and goes through `_vote`. If #25 finds that
  too slow, a shortcut for "cutoff = 1" is the place to change it.
- **New this round, for #25:** a leave-one-out of a repeated merchant is a little above
  distance 0 (item 2). How far: 0.000877 in the test case. I swept the extreme case: a
  token held by two rows, its n-grams split between `df = 2` and `df = n`, every split from
  1% to 99%, partitions of 3 to 30,000 rows. The largest distance was 0.0021 (at 7 rows),
  falling to 0.0002 at 30,000 rows. One row fewer moves an n-gram's idf by at most about
  14%. So such a leave-one-out still passes any `max_distance` above about 0.003, but
  `max_distance = 0` cannot be calibrated by leave-one-out. The docs say the second part.
  The sweep is a model of the formula, not a run of the index.

## Tests (`tests/test_knn.py`, 51 tests)

Iteration 4's 50 tests plus one. Mapping to the success criterion:

| Criterion | Test (`tests/test_knn.py`) |
|---|---|
| (a) | `test_known_merchant_with_card_noise_is_accepted` |
| (b) | `test_novel_merchant_abstains_on_distance` |
| (c) | `test_split_vote_abstains_on_margin_only` |
| (d) | `test_synthetic_provenance_is_refused_by_the_row_constructor`, `..._by_build` |
| (e) | `test_partition_with_no_rows_abstains_on_distance` |
| (f) | `test_build_refuses_two_normaliser_versions`, `test_query_refuses_another_normaliser_version` |
| (g) | `test_build_refuses_a_threshold_out_of_range` (4 cases) |
| (h) | `test_recent_habit_outvotes_an_older_majority` |
| (i) cases 1, 2 | `test_exclude_leaves_out_exactly_one_equal_row`, `test_exclude_of_the_only_row_leaves_nothing_near` |
| (i) case 3, FILIALE, 1 → 0.9430 | `test_exclude_comes_out_before_the_voters_are_chosen` (:413) |
| (i) case 4 | `test_exclude_that_matches_no_row_is_an_error`, `test_exclude_from_another_partition_is_an_error` |
| (j) | `test_every_row_tied_with_the_kth_distance_votes`, `test_the_vote_does_not_depend_on_the_order_of_the_rows` |
| (k) | `test_ngrams_no_row_contains_move_the_query_away_from_history` |
| (l) | `test_index_rows_copies_provenance_from_the_corpus` |
| (m) | `test_exclude_takes_its_row_out_of_the_query_idf` (:561) |
| **new: shared n-grams under `exclude`** | `test_exclude_lowers_the_df_of_ngrams_it_shares_with_other_rows` (:581) |

The rest are iteration 3's hardening tests (exact types, `str` subclass and `mock.ANY`
provenance, float snap, message privacy) and iteration 4's extras. The file follows the
brief's three rules: names the patch adds are reached through the module object inside
test bodies, there is no `sklearn` import, no skip, and neither banned marker word
(checked with a search). The new test's memos are invented (`BEISPIEL` is German for
"example").

## Evidence (red → green)

- **C4-verify, the gate's own script** (`engine/scripts/run-verify.sh` with
  `PDCA_BUNDLE`/`PDCA_WORKTREE` set):
  `PDCA-EVIDENCE: C4 PASS — red without the fix (50 of 56 failed), green with it`. The
  green leg ran 56 tests (`test_knn.py` + `test_skeleton.py`). The red leg had 0
  import/collection errors: `AttributeError` inside the test bodies. The 6 that stay green
  are the 5 skeleton tests and `test_the_cascade_entry_point_is_still_the_stub`, which hold
  with or without the fix. Afterwards the worktree matched `patch.diff` byte for byte.
- **Mutations this round** (each a `sed` on `classifier.py`, run with
  `engine/nox.sh test-3.14 -- tests/test_knn.py`, then restored from `patch.diff`; the tree
  was compared with `patch.diff` at the end and matched):

  | Mutation | Tests that fail |
  |---|---|
  | M7 `df = 0` for the excluded row's n-grams (`:268`) | the new test only (it passed the whole suite before) |
  | M8 `n - 1`, `df` unchanged | (m) and the new test |
  | M9 `n` unchanged, `df - 1` | (m) and the new test |
  | M1 neither (iteration 3's `exclude`) | (m) and the new test |

  Iteration 4's mutations M2–M6 (input-order cut, ignored `exclude`, `index_rows` literal,
  unseen n-grams out of the norm, no `_check_row(exclude)`) touch code this round did not
  change. I did not re-run them.
- **Commit readiness:** `engine/nox.sh fmt -- --fix` changed nothing (38 files).
  `engine/nox.sh gate` then passed all seven sessions: `ruff format --check`, `ruff check`,
  `mypy` strict (37 files), pytest (313 passed, 1 skipped, 7 deselected; the skip is the
  pre-existing book test without `gnucash`), `typos` (1.48.0 installed, the CI version, so
  it really ran) and `lint_docs`. The target has no `.pre-commit-config.yaml`; its gate is
  `nox -s gate`. DCO sign-off is publish's job.

## Refuting my own test

- **(a) Genuine red? Yes.** With the production hunks reverted, 50 of 56 failed (C4-verify
  red leg, 0 collection errors). The new test fails there too. More to the point, it goes
  red against the specific wrong rule it was added for. With only `df -= 1` changed to
  `df = 0`, it is the one test in the suite that fails (M7).
- **(b) Production path? Yes.** The new test builds a real `KnnIndex` from `IndexRow`s and
  calls `KnnIndex.query` with `exclude`, the code `patch.diff` ships. There is no stand-in.
  Its expected numbers come from an independent reference that refits scikit-learn on
  the remaining rows. That reference does not use the production code, and a hand formula
  gives the same number.
- **(c) Fixture includes the fault? Yes.** The fault is n-grams the excluded row shares
  with other rows. The fixture has exactly that: 18 of the query's 36 n-grams are in all
  three rows (df 3 → 2), and the other 18 in two (df 2 → 1). None of them goes from 1 to 0,
  which is the only path the earlier tests covered.

## Notes for the human

- **External dependencies:** `pypi` (declared in the brief). The nox sessions reused their
  environments and installed from PyPI without trouble. The instance `.venv` already had
  scikit-learn 1.9.1, so C4-verify's dependency sync did nothing. No undeclared dependency
  came up.
- **Expected §6 item:** `T2-threat-model` flags `src/autobook/pipeline/classifier.py`. As
  decided at Plan, no threat-model edit. The PR description must name the follow-up issue
  (see item 3 above).
- **The PR description must state** (brief *Open questions*): construction refuses bad
  provenance where proposal 0001 says "filters"; the neighbour and distance rules refine
  0001's `NearestNeighbors(n_neighbors=15)` sketch; the distance gate is `<=` where 0001
  says "under cutoff"; `exclude` is leave-one-out for the query only, and (new) a
  leave-one-out of a repeated merchant is therefore slightly above 0; a kNN index version is
  deferred to the version tuple; and the three planner decisions to confirm (leave-one-out
  idf, raise on no match, `<=`).
- **Target-repo quirk, outside this patch:** running the tests leaves an untracked
  `tests/fixtures/synthetic/__pycache__/` in the worktree, because `.gitignore:55`
  (`!tests/fixtures/synthetic/**`) re-includes bytecode caches under that directory. It is
  not in `patch.diff`, but a publish that ran `git add -A` in this worktree would commit it.
  This is worth a one-line `.gitignore` fix in a separate issue.
