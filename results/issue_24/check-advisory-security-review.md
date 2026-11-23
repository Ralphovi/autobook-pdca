# Security review — issue 24 (kNN index and abstention gates)

Attacker-reachable inputs this diff touches: **statement memo text** (threat model "Where untrusted input enters" item 1, written by any counterparty), which reaches `KnnIndex.query` as the normalised `token` and, through booking history, the `IndexRow.token` of indexed rows. Nothing else the threat model calls untrusted is touched: no model output, rule pack, review file, paperless data, money or book write.

## Findings

- NEEDS-HUMAN [human] — **Medium (rubric class *Abstention erosion*; the threat model counts "a gate that lets a low-confidence proposal through as confident" as in scope)** — `src/autobook/pipeline/classifier.py:264-269`. Repeating a known word drowns out a merchant the index has never seen. The query weight is `(1 + ln count) * idf` per n-gram, so a word written N times weighs about `1 + ln N` times as much, while each new n-gram keeps weight about 1 times its idf. The normaliser does not collapse repeated words (`normaliser.py:114` only joins on whitespace). So a memo that repeats a known merchant name before a new merchant can pass the distance gate and get pre-marked `a`. Who causes it: a counterparty, who controls the remittance text, or by accident a bank format that repeats a prefix such as a card-processor name. Reproducer, run against the patched module with synthetic data: an index of 5 rows `BEISPIELMARKT` → `Ausgaben:Lebensmittel` (`Girokonto`/`out`, `max_distance=0.3`, `min_margin=0.5`):
  - `BEISPIELMARKT NEUFIRMA XQZV` gives distance 0.6347 and abstains;
  - with the word written 2× the distance is 0.4466, and 4× gives 0.3165;
  - with `BEISPIELMARKT` written 20× and then `NEUFIRMA XQZV`, the distance is **0.1569 and the row is accepted** as Lebensmittel.

  This is not a regression: iteration 3 dropped unseen n-grams completely and gave 0 for all of these, so the patch is strictly better. It is also no worse than a counterparty simply writing `BEISPIELMARKT` as its memo. But the stated invariant is that "the distance gate measures the whole query", and the result above shows the new-merchant part can still be diluted. The fix is a design choice the brief fixed (keep `sublinear_tf`, or count each query n-gram once, or dedupe repeated words in the normaliser), and it affects what #25 calibrates. So a human should decide whether to change it now or track it. I tagged it [human] for that reason. Suggested pin if changed: the 20× case above must abstain on `distance`.

## Checked, no finding

- **Provenance** (`classifier.py` `_check_row`, `KnnIndex.build`, `index_rows`): synthetic rows are refused at the constructor, at `build` (exact `type(row) is IndexRow` plus a re-check), and when passed as `exclude`. `index_rows` copies `row.provenance`. A `str` subclass or a `mock.ANY` provenance is refused by the exact-type checks.
- **Gates cannot be loosened by input**: thresholds are checked to be finite and in range (NaN fails `0 <= x < 1`). Both gates are always evaluated, and `account` is set only when no gate failed. If every query n-gram is new, the distance is 1. A blank token or an empty partition abstains on `distance`.
- **`exclude`**: a row the query's partition does not hold raises `KnnError` before any result is returned. The divide-by-zero case (a dropped n-gram missing from the vocabulary) cannot happen, because the excluded row is in the partition and the default vectoriser keeps every n-gram.
- **Privacy**: `KnnError` messages name the field and type, or show the fixed sign/provenance value. They never include the token or an account path. Test fixtures are invented (`tests/test_knn.py:3`). Nothing new is logged or sent to a model.
- **Crash and resource use**: query cost grows linearly with token length and partition size (brute force over one partition). Ties at the k-th distance can let a whole partition vote, which is still linear. I found no memo text that crashes the code.
- **Order dependence**: voters are chosen by distance only, and equal rows are interchangeable, so the result does not depend on input order beyond float rounding.
- **T2 (threat-model touch)**: the brief explicitly scopes the threat-model edit out to a follow-up issue. This diff adds no new input and moves no trust boundary, so that decision stands. The finding above may be worth a line in that follow-up.
- Gates: C4-ci and C4-verify both pass (red leg 50 of 56 failed, green with the fix).

<!-- pdca:leaf-complete -->
