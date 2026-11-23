# Build notes — issue 24 / knn-index-abstention-gates (iteration 3)

Base: worktree at `0df021f` (folded #23). Line numbers are on the patched tree unless marked
"base".

## Prerequisite check (brief: "stop if missing")

Unchanged from iterations 1–2 and still true on the base: `normaliser.load`
(`src/autobook/pipeline/normaliser.py:120`), `Normaliser` (`:89`) with `version` (`:101`),
`Normaliser.normalise` (`:105`), `NormalisedMemo` (`:69`), and `IMPLEMENTED` in
`tests/test_skeleton.py:22` (loop exemption at `:52`). Nothing from #23 was re-implemented.

## Starting point

This round starts from the iteration-2 patch (`iteration-v2/patch.diff`), applied unchanged, and
fixes the two code findings in the iteration-2 carry-forward. Everything not flagged is kept as
it was; the design decisions in `iteration-v2/build-notes.md` and `iteration-v1/build-notes.md`
still hold (margin = `(top - runner_up) / total`, `HALF_LIFE_DAYS = 548`, the numpy mypy
override, `build` takes only `IndexRow` itself, and so on).

## Carry-forward findings and what changed

### 1. A provenance with its own `__eq__` passed the check (fixed)

Cause: `_check_row` tested `row.provenance not in _PROVENANCE`. Tuple membership falls back to
the other object's `__eq__`, so `unittest.mock.ANY` or a `str` subclass whose `__eq__` always
returns `True` passed, while the value could still read `"synthetic"`.

Change, `src/autobook/pipeline/classifier.py`:

- Every field check now compares the exact type, not `isinstance`: `_text` (`:80`) requires
  `type(value) is str`; `_path` (`:95`) requires `type(value) is tuple` and every part
  `type(part) is str`. A comment block above them (`:72-75`) says why.
- New `_choice` (`:88`) checks `type(value) is str` **before** the membership test. It is used for
  `sign` (`:128`) and `provenance` (`:132`) in `_check_row`, which both the constructor and
  `build` run.
- `query` now runs the same checks on its own inputs: `token` (`:307`), `sign` (`:309`) and
  `normaliser_version` (`:310`). Without the last one, a `str` subclass whose `__ne__` returns
  `False` would get past the "one version per index" check at `:317`.

Why every field and not only `provenance`: the reviewer said to do the same for `sign`, `token`
and `normaliser_version` if the ch.5 claim ("cannot be overridden") is to hold. Account path
parts are dict keys for partitions and votes, so a part with its own `__eq__`/`__hash__` could
merge partitions or votes; exact `str` closes that too. Cost: 6 changed lines in the checks plus
the 7-line `_choice`; no caller in the tree passes a `str` subclass (`index_rows` copies plain
strings from `CorpusRow`).

Ruled out: normalising the field with `str(value)` before checking. That would make the check
pass on a converted copy while the row still holds the odd object, which is what the index then
reads.

Docs: the ch.5 provenance bullet (`docs/design/architecture/05-building-block-view.md:373-378`)
now says the checks require exact `str` and `tuple` field types, so neither a subclass nor a
field with its own `__eq__` can pass.

Tests (`tests/test_knn.py`):

- `_Chameleon` (`:197`): a `str` subclass equal to everything.
- `test_a_provenance_with_its_own_equality_is_refused` (`:214`), run for `_Chameleon("synthetic")`
  and `unittest.mock.ANY`: the constructor raises, and a valid row with the field swapped in via
  `object.__setattr__` is refused by `build`. These are the reviewer's two concrete cases.
- `test_other_fields_with_their_own_equality_are_refused` (`:224`): `sign`, an account path part,
  `normaliser_version` on the row, and `normaliser_version` on `query`.

### 2. An exact token match did not always get distance 0 (fixed)

Cause: the clamp only removed negative values. scikit-learn computes cosine distance as
`1 - dot(a, b)`, so identical vectors can come back a few ulps above 0. Probe on the fixture
(script kept at `$PDCA_WORKTREE/.nox/probe/selfdist.py`, gitignored, not in the patch): with
the full `build_corpus(0)` index, `MUSTER HAUSVERWALTUNG` matched itself at `1.78e-15`; with
the pre-novel-row index the test builds, `MUSTERBAECKEREI` matched itself at `3.33e-16`. With
`max_distance=0.0` (allowed by validation) those exact matches failed the distance gate.

Change: new `_clamp` (`classifier.py:211`) used by `_Partition.nearest`. A distance below
`_IDENTICAL = 1e-9` (`:53`) becomes exactly `0.0`; anything else is capped at `1.0`.

Why `1e-9`: rounding error on a dot product of two unit vectors is about `1e-16` per non-zero
term, so even thousands of shared n-grams stay below `1e-12`. Two different tokens with
different vectors are nowhere near `1e-9` apart. Two different tokens whose vectors are truly
identical (e.g. `X` and `X X`, which have the same normalised n-gram profile) were already at
mathematical distance 0, so reading them as 0 is correct, not a widened gate. This is not a
threshold change (rubric "Abstention erosion"): `max_distance` is untouched and nothing that was
far is now near.

Side effect, a small fix: the old clamp `min(1.0, max(0.0, nan))` turned a NaN distance into
`0.0`, which would pass any distance gate. `_clamp` turns NaN into `1.0` (`nan < 1e-9` is false,
`min(1.0, nan)` returns `1.0`), which fails it. Not reachable with finite TF-IDF vectors as far
as I know; I did not add a test for it because I could not produce a NaN from scikit-learn
without mocking it.

Ruled out: special-casing "neighbour token == query token → 0". It covers identical strings but
not identical vectors from different strings, and it needs the token comparison inside the
neighbour loop. The tolerance covers both in one place.

Docs: ch.5 *Vote* bullet (`05-building-block-view.md:353-355`) records the `1e-9` snap and why.

Test: `test_every_exact_token_match_is_at_distance_zero` (`tests/test_knn.py:349`). It builds the
fixture index (rows before the novel row) with `max_distance=0.0`, queries every distinct
`(token, source_account, sign)` in it with its own token, and requires the distance gate to pass.
It asserts on the gate, not on `nearest_distance == 0.0`, because the brief forbids `==` on
floats. This replaces the luck the reviewer pointed at in `test_boundary_thresholds_are_accepted`
(kept as is: it is now backed by the snap).

### 3. T2 threat model (not build work)

The carry-forward lists "decide whether executable classification enforcement requires a
threat-model update". The brief says that is a sign-off call and Do does not edit
`.oss-scanner/threat_model.md`. Not touched. For the human: the patch still adds no new input,
no network use and no new trust boundary; the model already states the invariant these checks
enforce.

## Full change list (for citations)

- `src/autobook/pipeline/classifier.py`: replaces the base stub (base `:13` `__all__ =
  ["classify"]`, `:16-18` `classify` raising `NotImplementedError`; `classify` kept, now listed in
  `__all__`). New: `HALF_LIFE_DAYS`, `_K`, `_IDENTICAL` (`:53`), `KnnError(ValueError)` (peer:
  `ContractError(ValueError)`, `src/autobook/contracts.py:110`), `_text` `:80`, `_choice` `:88`,
  `_path` `:95`, `IndexRow` (`sign: Sign`, `contracts.py:71`), `_check_row` `:120`, `KnnResult`,
  `index_rows` (reads `CorpusContract` `contracts.py:149` / `CorpusRow` `:120`), `_Partition`,
  `_clamp` `:211`, `KnnIndex` with `build` and `query`.
- `pyproject.toml`: unchanged from iteration 2 (base `:25-30` "Deliberately empty" comment and
  `dependencies = []` → `scikit-learn>=1.5` with a comment saying why; `sklearn.*` override next
  to the `gnucash.*` peer at base `:97`; numpy `follow_imports = "skip"` +
  `follow_imports_for_stubs = true`).
- `tests/test_skeleton.py:22`: `autobook.pipeline.classifier` added to `IMPLEMENTED`.
- `tests/test_knn.py`: 38 tests (31 functions, three of them parametrised; the verify run's 43
  adds the 5 skeleton tests). Criteria (a)–(i) plus the
  extras. Uses `build_corpus` (`tests/fixtures/synthetic/corpus_builder.py:69`), `NOVEL_MERCHANT`
  (`:43`), `GIROKONTO` (`:17`), `REVOLUT` (`:18`), `LEBENSMITTEL` (`:19`), `MIETE` (`:20`).
- Docs: ch.5 §5.2 kNN bullet (iteration 2 text plus the two edits above); ch.8 §8.3 "filters" →
  "refuses (raises on)", unchanged. Proposal 0001 not edited.

## Verification (project runners only)

- `./engine/nox.sh fmt -- --fix`: `38 files left unchanged`, `All checks passed!`.
- `./engine/nox.sh gate` (`$PDCA_WORKTREE` set): fmt, lint, types, test-3.14
  (`300 passed, 1 skipped, 7 deselected`), typos, docs — all `success`.
- `PDCA_BUNDLE=… ./engine/scripts/run-verify.sh`: `PDCA-EVIDENCE: C4 PASS — red without the fix
  (37 of 43 failed), green with it`. Red leg: `ran 43, failed 37, import/collection errors 0`.
  The 6 that pass on red: the 5 skeleton tests and `test_the_cascade_entry_point_is_still_the_stub`
  (a regression guard, by design).
- After the verify run, `git diff` of the worktree (test file added with `git add -N`) matched
  `patch.diff` byte for byte (`cmp` → same).

## Refute-your-own-test (forced answers)

- **(a) Genuine red?** Yes, at two levels. Against the base stub (the C4 red leg): 37 of 43 fail
  with `AttributeError` inside test bodies, no collection errors. Against the iteration-2
  classifier (the code the reviewer flagged; I put it back in the worktree with
  `git apply --include=src/autobook/pipeline/classifier.py iteration-v2/patch.diff` and ran
  `./engine/nox.sh test-3.14 -- tests/test_knn.py`): exactly the 4 new tests fail —
  both `test_a_provenance_with_its_own_equality_is_refused` cases (no `KnnError` raised),
  `test_other_fields_with_their_own_equality_are_refused`, and
  `test_every_exact_token_match_is_at_distance_zero`
  (`MUSTERBAECKEREI … nearest_distance=3.3306690738754696e-16, failed_gates={'distance'}`);
  the other 34 pass. With this round's classifier all 43 pass.
- **(b) Production path?** Yes. The tests call the real `IndexRow`, `KnnIndex.build`/`query`,
  `index_rows` and `normaliser.load` on `build_corpus(0)`, with real scikit-learn doing the
  distances. No mock of the classifier or of scikit-learn; `unittest.mock.ANY` is used only as
  the hostile field value the reviewer named.
- **(c) Fixture includes the fault?** Yes. The distance test runs on the real fixture partition
  where scikit-learn really returns a nonzero self-distance (shown above), not on a hand-picked
  token that happens to come out at 0. The equality tests use the reviewer's two exact hostile
  values, and smuggle them past the constructor so `build`'s own check is what fires.

## Notes for the human

- Working files kept inside the worktree, gitignored, not in the patch:
  `.nox/probe/selfdist.py` (the self-distance probe), `.nox/probe/classifier.v3.py` (a copy of
  this round's classifier, used while running the tests against iteration 2), and an empty temp
  dir under `.nox/probe/`. `tests/fixtures/synthetic/__pycache__/` is pytest output.
- The self-distance that goes nonzero depends on the BLAS and numpy build (here
  `MUSTERBAECKEREI` in the test's index). On another machine a different token, or none, may hit
  it, so the distance test could pass on the old code there. It cannot fail on the new code: the
  snap makes every exact match 0 regardless.
- Expect the advisory `T2-threat-model` row in §6 (`*classif*` path), per the brief.
- PR description should state: provenance now raises where proposal 0001 says "filters"; `build`
  takes only `IndexRow` itself and fields must be exact `str`/`tuple`; distances under `1e-9`
  read as 0; kNN index version deferred to the version tuple; scikit-learn lower bound `>=1.5`
  is my pick (tested on 1.9.1 only); the numpy mypy override and why.
