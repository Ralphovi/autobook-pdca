Bash was unavailable in this run (sandbox failed to start: `apply-seccomp: ... Permission denied`); review done with Read/Grep/Glob only.

# Plan review — issue 24 / knn-index-abstention-gates (iteration 4 brief)

What I tried to fault, and what held up:
- **Root cause / problem statement:** it matches the issue (`notes.json`: "Distance gate and vote-margin gate … Provenance: only `observed`/`corrected` rows enter the index"). All three "Done when" items map to criteria (b), (c) and (d).
- **Cited code:** every `path:line` checks out on the target:
  - `contracts.py:110` `ContractError` and `:129` `provenance: Literal["observed"]`
  - `corpus_builder.py:100` sort, oldest first; the fixture books only `out` rows to `REVOLUT` (`:36`)
  - `normaliser.py:69/:89/:101/:120`
  - `test_skeleton.py:22/:52`
  - `pyproject.toml:25-30` `dependencies = []` and `:94-98` the `gnucash.*` override
  - `classifier.py` is the stub, so the red leg behaves as described.
- **Pinned numbers:** I recomputed the brief's numbers by hand from the stated rules, and they are consistent:
  - (k): 36 known n-grams at idf 1 plus 9 or 18 unseen n-grams at idf `ln 2 + 1` give distances 0.2367 and 0.359.
  - (j): margin ≈0.362; the rejected "newest-first cut" alternative gives ≈0.565.
  - (i), third case: the FILIALE row's distance ≈0.589 gives margin ≈0.943.

  (j) and (k) really pin this round's change.
- **Dependencies:** `dependency-state.json` shows #23 `exists: true, state: COMPLETE`.

The findings left are below.

- NEEDS-HUMAN — **`exclude` is not leave-one-out, and the brief does not say so.**
  - *What the brief says:* *Neighbours* step 2 removes the excluded row only from the vote. The vectoriser, the vocabulary and the idf (including `n` in the unseen-term idf `ln((1+n)/1)+1`) are still fitted with that row in.
  - *Why it matters:* a memo whose n-grams occur only in the excluded row gets idf `ln((1+n)/2)+1` for them, not the unseen idf `ln(1+n)+1`. That makes its unseen mass smaller, so its leave-one-out distance comes out systematically lower than if that row had never been in history.
  - *Who it affects:* #25 runs its leave-one-out through `exclude` and calibrates `max_distance` on those distances. So the distance gate gets calibrated on numbers that differ from production for exactly the novel-merchant case it exists to catch.
  - *Contradiction:* this cuts against the brief's own invariant "The result is a function of the set of rows". `query(..., exclude=R)` on set S is not `query` on S∖{R}.
  - *Ask:* either decide it (for example, compute document frequency excluding R for the query's n-grams) or state it as an accepted bias that #25 must know about. None of the (i) cases can tell the two behaviours apart.
- NEEDS-HUMAN — **`exclude` with no equal row is unspecified.** Step 2 says "remove one row equal to it" but does not say what happens when no row in the partition equals `exclude`. It could be ignored silently, raise `KnnError`, or come from a different partition. #25's API is "fixed" against this signature, and a silent no-op would make a leave-one-out bug look like a perfect score. Decide it and pin it with a test in (i).
- NEEDS-HUMAN — **The maintainer decisions behind this round are not in the tracker record.**
  - *Where:* the brief's justification for the iteration-4 design rests on rulings attributed to the maintainer. Examples: *Alternatives* "Rejected at Plan (maintainer, iteration 4)" (twice); *Open questions* "Settled with the maintainer (eduralph) at Plan … These are not on the issue thread".
  - *Thread state:* `notes.json` has `"comments":[]`.
  - *Rulings involved:* the tie-group vote rule, the unseen-n-gram idf, "no threat-model edit, follow-up issue instead", and "no split".
  - *Why it matters:* nothing a reviewer has can verify them. The first and last of these also go against the design docs' text: proposal 0001 `:316` `NearestNeighbors(n_neighbors=15, …)`, and `:344` "Index construction filters on provenance" (the brief changes this to *refuses*).
  - *Ask:* sign-off should confirm these rulings directly, or the planner should get them recorded on #24 before Do.
- NEEDS-HUMAN — **The repo/branch target disagrees with the base the bundle actually builds on.**
  - *Conflict:* the brief says `Repo + branch target: Ralphovi/autobook @ main`. Its *Falsifiability* section says it builds on the folded base `pdca-integration/main-r1726f2053868` (tip `0df021f`), which carries #23 from **draft** PR #50.
  - *Evidence:* the target tree I was given has `normaliser.py` and `IMPLEMENTED = {"autobook.pipeline.normaliser"}` (`tests/test_skeleton.py:22`), so it is that folded base, not `main`.
  - *Risk:* a draft PR opened against `main` before #50 merges will show #23's diff, or fail CI on missing `normaliser`.
  - *Ask:* the brief should say which branch the PR targets and that it waits for #50, or that it stacks on #50.
- NEEDS-HUMAN — **The distance gate is inclusive, but the design text says strict.** The brief sets the gate to `nearest_distance <= max_distance` and allows `max_distance=0`. ch.5 (`sources/05-building-block-view.md:165`) says "distance is **under** its cutoff", and proposal 0001 `:331` says "under cutoff". This boundary is exactly what #25 calibrates. Either pick `<` or list `<=` among the differences the PR description must state (*Open questions* currently omits it).
- NEEDS-HUMAN — **Minor scope bookkeeping.** *Scope* (1) lists four changes to the iteration-3 code: distance, neighbour choice/`exclude`, `index_rows` provenance, and `HALF_LIFE_DAYS = 548.0`. *Difficulty* claims "This round's delta is local to `_Partition`, `KnnIndex.query` … and `index_rows`" and leaves out the half-life constant. Pinning it moves every recency number, including (h). Small, but say whether 548.0 is a change from iteration 3 or not, so the Check reviewer knows which hunk to expect.

Not faulted, after trying:
- **The success criterion:** red→green on `tests/test_knn.py`, with concrete asserted values.
- **Scope:** no hidden drive-by. The threat-model and proposal edits are explicitly out of scope.
- **The #22/#23 prerequisites.**

> **pdca:** Bash was unavailable to this reviewer. The vendor sandbox could not start on this host, so every Bash call it made failed before running (`apply-seccomp: write /proc/self/setgroups (nested userns is capability-restricted; caller must provide CAP_SYS_ADMIN): Permission denied`) and it ran no commands; this review was delivered without Bash.

<!-- pdca:leaf-complete -->
