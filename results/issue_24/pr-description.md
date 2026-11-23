## Summary
**User impact:** today Autobook cannot suggest an account for a bank line from the
user's own booking history at all; every line that no rule covers would have to go
to the language model or to the user. This adds that suggestion step, built so that
it stays quiet rather than guess: a merchant you have never booked, or a payee you
have booked two different ways, gets no suggestion, and the reason is reported.

This PR adds the nearest-neighbour index: it compares a memo with your past memos
for the same account and direction, and proposes one account only when the closest
match is close enough **and** the recent votes clearly agree.

Reported in [#24](https://github.com/Ralphovi/autobook/issues/24).

**Merge order:** this branch carries #23's normaliser commits. Merge #50 first, then
this PR; the diff shrinks to this change once #50 is in.

## What to look at
- The index and its two checks live in one module, the classifier. The cascade entry
  point there is still a stub; only the nearest-neighbour step is real.
- The tests read as a list of behaviours: a known shop with card noise is accepted;
  an unknown shop abstains on distance; a payee split evenly between two accounts
  abstains on the vote; a recent change of habit outweighs an older majority; extra
  unknown words in a memo push it away from history; synthetic rows are refused.
- To try it: `nox -s gate`, or just `pytest tests/test_knn.py`. scikit-learn is new
  as a runtime dependency, so the environment needs a reinstall.
- No thresholds are chosen here. They are required arguments with no default; the
  backtest (#25) supplies the evidence for them.

## Root cause
There was no history-based tier yet: `classifier.py` was a stub, and the design
(proposal 0001 §2, ch.5 §5.2) left open how neighbours are chosen, how distance is
measured, and how a leave-one-out query behaves. Earlier drafts of this change showed
two ways a naive version gives confident wrong answers: memo text the index never saw
was silently ignored (so "known shop + new words" scored as an exact match), and with
more than 15 identical memos, input order picked the voters, so the oldest bookings
outvoted a recent change.

## Fix
- `src/autobook/pipeline/classifier.py`: `KnnIndex.build` / `KnnIndex.query`,
  `IndexRow`, `KnnResult`, `index_rows`, `KnnError`, `HALF_LIFE_DAYS = 548.0`
  (about 18 months). One TF-IDF partition per `(source_account, sign)`, character
  3–5-grams.
  - **Distance** counts every n-gram of the query; one no row contains gets the idf
    of a term with document frequency 0. A query of only known n-grams gets the plain
    cosine distance.
  - **Voters**: every row at or within the 15th-smallest distance votes, weighted by
    `(1 - distance) * 0.5 ** (age / half_life)`. The result depends on the set of
    rows, not their order.
  - **Gates**: `nearest_distance <= max_distance` and `margin >= min_margin`; both are
    evaluated and every failure is listed.
  - **`exclude`** (for #25's leave-one-out): removes one equal row before voters are
    chosen and takes it out of the query's idf (`n - 1`, `df - 1`). The other rows'
    vectors are not refitted. An `exclude` the query's partition does not hold raises
    `KnnError`.
  - **Provenance**: only `observed` / `corrected` rows, checked in the `IndexRow`
    constructor and again in `build`; `index_rows` copies the corpus row's provenance.
    One normaliser version per index, checked in `build` and `query`.
- `pyproject.toml`: `scikit-learn>=1.5` in `dependencies`; mypy overrides for
  `sklearn.*` and numpy.
- `tests/test_skeleton.py`: the classifier joins `IMPLEMENTED`.
- Docs: ch.5 §5.2 describes the API, distance, voters, `exclude`, weights and gates;
  ch.8 §8.3 now says construction *refuses* a non-observed/corrected row.

### Differences from proposal 0001, on the record
These were settled with the maintainer during design and confirmed at review:
- Index construction **refuses** (raises on) bad provenance, where 0001 and the old
  ch.8 said it "filters". Silently dropping would hide a bug the design says cannot
  exist.
- The neighbour and distance rules refine 0001's `NearestNeighbors(n_neighbors=15)`
  sketch: all rows tied with the 15th distance vote, and unseen n-grams count.
- The distance gate is `<=`, where 0001 and ch.5 said "under cutoff". Distances are
  continuous apart from 0 and 1 and `max_distance < 1`, so the two differ only at
  `max_distance = 0`, where `<=` means "exact matches only" and `<` would mean
  "nothing ever passes". ch.5 now says "within its cutoff".
- `exclude` is leave-one-out **for the query only**. The remaining rows keep the idf
  fitted with the excluded row in. One effect for #25: a leave-one-out of a repeated
  merchant measures slightly above 0 to its own duplicate (0.000877 in the test
  case; at most about 0.002 in a sweep of partition sizes), so `max_distance = 0`
  cannot be calibrated by leave-one-out. Any cutoff above about 0.003 is unaffected.
- A kNN index version (listed in ch.8 §8.3's version tuple) is deferred until code
  assembles that tuple; the index is rebuilt in-process every run and never stored.

### Known limitation and follow-up
Repeating a known merchant name inside a memo dilutes the unknown part, because a
word's weight grows with `1 + ln(count)`. In a synthetic example, "NEUERLADEN
STROMANBIETER" plus "BEISPIELMARKT" written five times scores 0.241 against a history
of only "BEISPIELMARKT" and would pass a `max_distance` of 0.3. This was reviewed and
accepted for now, not fixed here. A follow-up issue (FOLLOW-UP-ISSUE) covers it
together with the threat model's stale "Nothing is built yet" line
(`.oss-scanner/threat_model.md:11`) and a sentence on how the kNN distance is
measured. This PR does not edit the threat model.

## Verification
- **Claim:** a known merchant with card noise is accepted; an unknown merchant
  abstains on distance; a split vote abstains on the vote only.
  **Checked:** `src/autobook/pipeline/classifier.py:428-436` (both gates evaluated,
  each failure listed). **Test:** `tests/test_knn.py:98`, `:114`, `:140`.
- **Claim:** text the index never saw moves the query away from history.
  **Checked:** `src/autobook/pipeline/classifier.py:242-274` (every query n-gram enters
  the norm; unknown ones at `df = 0`). **Test:** `tests/test_knn.py:520` — known name
  0.0, plus one unknown word 0.2368 (accepted at 0.3), plus two 0.3589 (abstains).
- **Claim:** all rows tied with the 15th distance vote, and row order does not matter.
  **Checked:** `src/autobook/pipeline/classifier.py:219-240`. **Test:**
  `tests/test_knn.py:488`, `:499` — 20 old rows vs 5 recent ones: recent account wins,
  margin 0.363, abstains on the vote, the same in oldest-first, newest-first and
  shuffled order.
- **Claim:** `exclude` is leave-one-out for the vote and the query's idf, and an
  `exclude` that matches nothing raises.
  **Checked:** `src/autobook/pipeline/classifier.py:255-268` (`n - 1`, `df - 1`),
  `:406` (the error, which names the field, never the memo). **Test:**
  `tests/test_knn.py:392-465`, `:561` (0.1056 → 0.2368 with `exclude`), `:581`
  (shared n-grams: 0.000877, margin 0.4924; the expected values come from an
  independent scikit-learn refit, and the test fails for the `df = 0`, `df` unchanged
  and `n` unchanged variants of the rule).
- **Claim:** no synthetic row can enter the index, by any path.
  **Checked:** `src/autobook/pipeline/classifier.py:107` (`IndexRow`), `:179`
  (`index_rows` copies provenance), the second check in `build`;
  `docs/design/architecture/08-crosscutting-concepts.md:69-70`. **Test:**
  `tests/test_knn.py:549` and the constructor/`build` provenance tests, including a row
  forced past the constructor with `object.__setattr__`.
- **Claim:** one normaliser version per index; thresholds validated
  (`0 <= max_distance < 1`, `0 < min_margin <= 1`). **Checked:**
  `src/autobook/pipeline/classifier.py:324-331`. **Test:** the version and threshold
  tests in `tests/test_knn.py`.
- **Red → green:** with the production change reverted, 50 of 56 tests in
  `tests/test_knn.py` + `tests/test_skeleton.py` fail (inside the test bodies, no
  collection errors); with it, all pass. The six that pass either way are the five
  skeleton tests and the check that `classify()` is still the stub.
- **Full gate:** `nox -s gate` passes (ruff format and check, mypy strict, pytest 313
  passed / 1 skipped for the book test without `gnucash`, typos, docs lint).

Fixes #24
