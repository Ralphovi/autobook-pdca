# Adversarial review — issue 24 / knn-index-abstention-gates (iteration 5)

**Verdict: I tried to refute the fix and could not.** No NEEDS-HUMAN findings. The fix holds against everything below; one small test gap is noted at the end.

## The evidence (red → green)

- Re-ran green myself: `tests/test_knn.py` gives 51 passed on the instance `.venv` (scikit-learn 1.9.1) with the patched `src/` on the path. This matches `gate-logs/C4-verify.log:12`.
- The red leg is real, not a collection error: `gate-logs/C4-verify.log:1410-1461` shows 50 of 56 failed, 0 import errors. Each failure is `AttributeError` on the stub module, as the brief's *Falsifiability* says. The red leg alone proves only "module missing". So I checked that this round's specific rules are pinned by running mutants (copies of `classifier.py` with one deliberate break each) against the suite. Every mutant that changes behaviour was caught:
  - `src/autobook/pipeline/classifier.py:267-268` (leave-one-out df): dropping `df -= 1` → 2 failed. Dropping `n -= 1` (`:260`) → 2 failed. Replacing it with `df = 0` (last round's surviving mutant) → 1 failed, caught by the new `tests/test_knn.py:581` case. So the carry-forward finding is closed.
  - `classifier.py:270-272` (unseen n-grams in the norm): counting only known n-grams → 4 failed. Unseen idf with the full `n` under `exclude` → 1 failed. Raw tf instead of `1 + ln c` → 1 failed.
  - `classifier.py:237` (tie voting): `<` instead of `<=` → 17 failed. Iteration 3's "first 15 in input order" cut → 3 failed.
  - `classifier.py:230` (exclude before voters): exclude not removed → 5 failed. Cutoff taken before removal → 1 failed.
  - `classifier.py:405` (no-match exclude raises): only checking for a missing partition → 3 failed. Dropping `_check_row(exclude)` (`:393`) → 2 failed.
  - Gates `:433`/`:435` flipped to strict → caught. Snap `_IDENTICAL` removed → caught. Tie-break by insertion order or by larger path → caught. Dropping the closest-first sort (`:239`) → caught.
- The tests call the production `classifier` module directly (`tests/test_knn.py:23`). They don't use a copy or mocks, and they don't import sklearn.

## The fix: inputs I tried to break it with

- **Weight floor / divide by zero** at `classifier.py:274`: under `exclude`, a gram the excluded row lacks has `df <= n-1 = n'`, so every weight stays ≥ 1. A non-blank token always yields at least one `char_wb` n-gram, so `squared > 0`. No NaN path found.
- **Edge partitions:** a single row excluded (`positions.size == 0` → empty result, `:231`); an all-blank partition (`_matrix is None`, `:226`); a blank `exclude` token (no n-grams, only `n` drops). All return the brief's empty result or a correct distance.
- **Order independence:** identical tokens get identical sparse rows, so they tie exactly at the cutoff. Only the float summation order in `_vote` (`:416-421`) depends on input order. That can flip `candidate` only when two accounts tie to within float noise, where margin ≈ 0 already fails the gate (`min_margin > 0`). The brief allows this ("up to float summation order").
- **Docs:** last round's false claim ("exact match passes `max_distance = 0`") is now limited to the no-`exclude` case (`docs/design/architecture/05-building-block-view.md:366-368`), and the `0.000877` effect is spelled out (`:397-403`). The `query` docstring says the same (`classifier.py:377-379`). The pyproject numpy comment is updated now that `classifier.py` imports numpy.

## Minor note (not a refutation, no rebuild needed)

- `classifier.py:417`: the `max(0, …)` age clamp has no test. A mutant that removes it passes all 51 tests. Concrete case: one row → A dated 1000 days *after* `as_of` against three rows → B dated on `as_of`, all with one token. With the clamp, B is accepted (margin 0.5). Without it, A becomes the candidate with weight 2^(1000/548) ≈ 3.5 per row. This is iteration-3 code kept unchanged, and it is correct. Only the test pin is missing. It matters for #25 if a leave-one-out `as_of` ever comes before later history rows. It is optional, and not worth its own review round under the rubric's "do not iterate chasing silence".

## Reviewer claims checked

- `check-gates.json` C4-verify "red without the fix (50 of 56 failed), green with it": warranted. It is backed by the log, the red failures run inside test bodies, and the mutants show the iteration-4/5 rules themselves are pinned, not just "module exists".
- T2 threat-model `unverifiable`: the brief settled this at Plan as a follow-up issue (*Scope*, out of scope). I don't count it as a finding against this diff.

Attempted to refute the leave-one-out idf, the unseen-n-gram distance, tie voting, exclude ordering and errors, the gate comparisons, and order independence. I could not.

<!-- pdca:leaf-complete -->
