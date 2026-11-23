# Security review — issue 24 / knn-index-abstention-gates

Attacker-reachable inputs this diff touches: **counterparty memo text** (threat model "Where untrusted input enters" #1), which reaches `KnnIndex.query` as the normalised `token` and the TF-IDF (term frequency–inverse document frequency) vectoriser. Everything else (history rows from the user's own book, thresholds, `as_of`) is trusted input or caller code.

## Findings

- **Hardening, unrated (no reachable input found)** — `src/autobook/pipeline/classifier.py:187` (inside `_Partition.nearest`): the clamp `min(1.0, max(0.0, float(distance)))` turns a NaN distance into `0.0`. Python's `max(0.0, nan)` returns `0.0`, so a NaN would become "identical match", get full weight `(1 - 0)`, and pass the distance gate. The gate itself is written in NaN-safe form (`if not nearest <= self._max_distance`), but the clamp runs first and defeats that. I found no memo string that produces a NaN: scikit-learn's cosine distance normalises zero vectors and clips to `[0, 2]`, so an out-of-vocabulary token gives distance 1.0 and fails the gate (`max_distance < 1` is enforced). If a NaN ever did appear (a library change, a degenerate matrix), it would fall under the threat model's High item "a kNN proposal passes with either gate failed". Fix: map a non-finite distance to `1.0` before clamping (`d = float(distance); d = 1.0 if not math.isfinite(d) else min(1.0, max(0.0, d))`). Test: monkeypatch `_Partition.nearest`'s `kneighbors` to return `nan` and assert `"distance" in failed_gates`. Not tagged NEEDS-HUMAN because nothing reaches it today; the builder can take it or leave it.

## What I checked with no finding

- **Gate bypass from memo text.** An out-of-vocabulary, empty or whitespace-only query token gives either distance 1.0 (fails, since `max_distance < 1`) or no neighbours (`failed_gates={"distance"}`, `account=None`). A query only sees its own `(source_account, sign)` partition. When the weights sum to 0 the margin is 0, which always fails because `min_margin > 0`. NaN or infinite thresholds are refused at `build` (`not 0 <= nan < 1` is true, so it raises). `account` is set only when `failed` is empty. The test file covers the attacker-side cases: novel merchant, empty token, empty partition, split vote, cross-partition isolation.
- **Only one account.** `KnnResult` holds a single path tuple; there is no split type.
- **Synthetic rows reaching the index** (threat model Medium): refused in `IndexRow.__post_init__` and again in `build` via `row._validate()`, which catches rows built around the constructor. Non-`IndexRow` objects are refused. Both cases are tested.
- **Personal data in errors or logs.** `KnnError` messages carry field names and type names only. The provenance value is echoed, but it is not personal. There is no logging. `test_a_refused_row_message_does_not_carry_the_token` pins this. Nothing crosses a model adapter or the network.
- **Fixtures.** Test tokens are invented (`NEUBAU DROGERIE`-style) or come from the synthetic corpus builder. No real memos or IBANs.
- **Resource use.** Query cost grows linearly with token length (3–5 character n-grams, brute-force search over one partition). A long memo costs time in proportion to its size, which is acceptable.
- **No book, review-file, money or paperless surface** is touched. `classify()` is still the stub, so nothing pre-marks a row yet.
- **Dependency.** `scikit-learn>=1.5` is unpinned from PyPI. The brief asks for exactly this, and supply-chain pinning is not in the threat model's rubric, so I raise no finding.
- **Gate status (not a security finding).** C4-ci fails in `types`: mypy runs with `python_version = "3.11"` (`pyproject.toml:89`) and chokes on numpy's stub file (`numpy/__init__.pyi:737`, a `type` statement that needs 3.12+). This is a typing-config problem the new dependency brought in, not a security issue. Other reviewers own it. C4-verify shows a clean red (31 of 37 failed) and green (37 passed).

- NEEDS-HUMAN [human] — toolchain unavailable: scikit-learn is not installed in this sandbox, so I could not run the NaN or out-of-vocabulary probes myself. The out-of-vocabulary behaviour above comes from scikit-learn's documented cosine handling and the green C4-verify run (novel merchant abstains on distance). The NaN-clamp point is confirmed only for Python's `min`/`max` semantics (`min(1.0, max(0.0, nan)) == 0.0`).

<!-- pdca:leaf-complete -->
