# Build notes — issue 24 / knn-index-abstention-gates (iteration 2)

Base: worktree at `0df021f` (folded #23 on `pdca-integration/main-r1726f2053868`).
Line numbers below are on that base for "base" claims and on the patched tree otherwise.

## Prerequisite check (brief: "stop if missing")

All present on the base: `normaliser.load` (`src/autobook/pipeline/normaliser.py:120`),
`Normaliser` (`:89`) with `version` (`:101`), `Normaliser.normalise` (`:105`),
`NormalisedMemo` (`:69`), and `IMPLEMENTED` in `tests/test_skeleton.py:22`, whose loop skips all
three stub assertions for listed modules (`tests/test_skeleton.py:52`). Nothing from #23 was
re-implemented.

## Starting point

This round starts from the iteration-1 patch (`iteration-v1/patch.diff`), applied unchanged, then
fixes the three findings in the carry-forward. Everything iteration 1 did that was not flagged is
kept as it was (its notes still hold for the design decisions: margin computed as
`(top - runner_up) / total`, empty index builds and abstains, blank tokens allowed, error
messages carry field names only, `half_life_days` validated, gate comparisons written so NaN
fails, `HALF_LIFE_DAYS = 548`).

## Carry-forward findings and what changed

### 1. C4-ci `types` session red: mypy parses numpy's stubs (fixed)

Reproduced with the gate's own `.nox/types` env: `numpy/__init__.pyi:737: error: Type statement
is only supported in Python 3.12 and greater`. `mypy -v` shows numpy is parsed right after
`_pytest/_io/saferepr.py`; the importer is pytest's `_pytest/python_api.py:21`
(`from numpy import ndarray` under `TYPE_CHECKING`, used by `approx`). So the reviewer's guess
was right. Before this patch numpy was not installed, so that import was silently missing.

Fix, `pyproject.toml:106-114` (new override, next to the `gnucash.*` peer at base
`pyproject.toml:97` and the `sklearn.*` one at `:101-104`):

```toml
module = ["numpy", "numpy.*"]
follow_imports = "skip"
follow_imports_for_stubs = true
```

`follow_imports = "skip"` alone did NOT work (tried it first: same error). mypy always follows
`.pyi` stubs unless `follow_imports_for_stubs = true` is also set; numpy's types are `.pyi`
files. With both, `mypy` prints `Success: no issues found in 37 source files`.

Ruled out: raising `python_version` (forbidden by the carry-forward; `requires-python` is 3.11);
pinning numpy below the release that uses `type` statements (an upper pin in a runtime
dependency only to please the type checker, and the brief says no upper pin on scikit-learn's
stack); a scipy override (scipy is not reached: the code does not import it, and sklearn is not
followed because it ships no `py.typed`).

Not run locally: the CI matrix's 3.11 interpreter. The gate here only has 3.14. On 3.11 pip
installs an older numpy; skipping it there is harmless either way.

### 2. Subclass could switch off `build`'s provenance re-check (fixed)

The iteration-1 code called `row._validate()` (a method looked up on the row's class), so a
subclass overriding `_validate` let a synthetic row in. Changes in
`src/autobook/pipeline/classifier.py`:

- The check is now a module function `_check_row(row)` (`:102`), called from
  `IndexRow.__post_init__` (`:99`) and from `build` (`:252`). A subclass cannot override a
  module function.
- `build` refuses any row whose type is not exactly `IndexRow` (`:250`). Reason: a subclass could
  also change how its fields read (a `provenance` property, say), so `isinstance` is not enough.
  The cost: a caller cannot pass an `IndexRow` subclass even with valid fields. Nothing in the
  brief or in #25's API needs that.
- `query` refuses an `exclude` that is not exactly `IndexRow` (`:287`). In `row == exclude`,
  Python runs a subclass's `__eq__` first, so a subclass `exclude` could drop a row it should not.

Rejected the reviewer's other one-liner, `IndexRow._validate(row)`: it closes the `_validate`
route but leaves the field-reading route open; the exact-type check closes both for one line.

Test: `tests/test_knn.py:178` `test_a_subclass_cannot_switch_off_the_build_check`. The subclass
overrides both `__post_init__` and `_validate` (the reviewer's exact route), is built with
`provenance="synthetic"` without `object.__setattr__`, and `build` must raise `KnnError`.

### 3. Misnamed test that passed on the red leg (fixed)

Split into two:

- `tests/test_knn.py:387` `test_the_result_holds_one_account_path_and_no_split_type_exists`:
  `KnnResult`'s fields are exactly the six in the brief, `account`'s type hint is
  `tuple[str, ...] | None` (one path), `__all__` is exactly the brief's API (no split type is
  exported), and an accepted result's `account` is a tuple of strings. Fails on the red leg.
- `tests/test_knn.py:416` `test_the_cascade_entry_point_is_still_the_stub`: the old stub check,
  now named for what it does. It passes on both legs on purpose (a regression guard).

### Docs

ch.5 §5.2 provenance bullet (`docs/design/architecture/05-building-block-view.md:371-374`) now
says `build` takes only `IndexRow` itself, not a subclass. ch.8 §8.3 change is unchanged from
iteration 1.

## Full change list (for citations)

- `src/autobook/pipeline/classifier.py`: replaces the base stub (base `:13` `__all__ =
  ["classify"]`, `:16-18` `classify` raising `NotImplementedError`; `classify` kept). New:
  `HALF_LIFE_DAYS` `:45`, `KnnError(ValueError)` `:57` (peer: `ContractError(ValueError)`,
  `src/autobook/contracts.py:110`), `IndexRow` `:87` (`sign: Sign`, `contracts.py:71`),
  `_check_row` `:102`, `KnnResult` `:124`, `index_rows` `:143` (reads `CorpusContract`
  `contracts.py:149` / `CorpusRow` `:120`), `KnnIndex` `:201`.
- `pyproject.toml`: base `:25-30` comment and `dependencies = []` now say why scikit-learn is
  there and declare `scikit-learn>=1.5` (`:25-31`); `sklearn.*` override `:101-104`; numpy
  override `:106-114`.
- `tests/test_skeleton.py:22`: `autobook.pipeline.classifier` added to `IMPLEMENTED`.
- `tests/test_knn.py`: 39 tests (34 functions, two parametrised), criteria (a)–(i) plus extras.
  Uses `build_corpus` (`tests/fixtures/synthetic/corpus_builder.py:69`), `NOVEL_MERCHANT`
  (`:43`), `GIROKONTO` (`:17`), `REVOLUT` (`:18`), `LEBENSMITTEL` (`:19`), `MIETE` (`:20`).
- Docs: ch.5 §5.2 kNN bullet, ch.8 §8.3 "filters" → "refuses (raises on)". Proposal 0001 untouched.

## Verification (project runners only)

- `./engine/nox.sh gate` (from autobook-pdca, `$PDCA_WORKTREE` set): fmt, lint, types,
  test-3.14 (`296 passed, 1 skipped, 7 deselected`), typos, docs — all `success`.
- `PDCA_BUNDLE=… ./engine/scripts/run-verify.sh`: `PDCA-EVIDENCE: C4 PASS — red without the fix
  (33 of 39 failed), green with it`. Green leg `ran 39, failed 0`; red leg `ran 39, failed 33,
  import/collection errors 0`. The 6 that pass on red: the 5 skeleton tests and
  `test_the_cascade_entry_point_is_still_the_stub`.
- After the verify run the worktree diff matched `patch.diff` byte for byte.

## Refute-your-own-test (forced answers)

- **(a) Genuine red?** Yes. The C4 script reverted every non-test hunk (classifier back to the
  stub): 33 of 39 failed with `AttributeError` inside test bodies, no collection errors. For the
  new subclass test I also ran it against the iteration-1 classifier (the code with the bypass):
  `FAILED test_a_subclass_cannot_switch_off_the_build_check — DID NOT RAISE KnnError`, the other
  33 passed. With this round's code it passes.
- **(b) Production path?** Yes. Tests call the real `classifier.index_rows`,
  `KnnIndex.build/query`, the real `normaliser.load` on `build_corpus(0)`, and real
  scikit-learn. No mock, no copy of the vote.
- **(c) Fixture includes the fault?** Yes. (b) queries the planted `NOVEL_MERCHANT` row from the
  corpus, kept out of the index only by date; (e) queries `REVOLUT`/`in`, which really has no
  rows; (d) smuggles synthetic rows in two ways (`object.__setattr__`, and a subclass that skips
  both checks) so `build`'s own check is what fires.

## Notes for the human

- While checking the subclass test against iteration 1, I kept a copy of the new classifier at
  `$PDCA_WORKTREE/.nox/classifier.v2.py` (gitignored, inside the worktree). It is not in the
  patch.
- `tests/fixtures/synthetic/__pycache__/` shows as untracked in the worktree (pytest output);
  it is not in the patch.
- Expect the advisory `T2-threat-model` row in §6 (`*classif*` path), per the brief. No
  threat-model edit made: the patch adds no input and no network use.
- PR description should state: provenance now raises where proposal 0001 says "filters"; `build`
  takes only `IndexRow` itself; kNN index version deferred to the version tuple; scikit-learn
  lower bound `>=1.5` is my pick (tested on 1.9.1 only); the numpy mypy override and why.
