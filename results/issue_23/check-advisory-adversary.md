# Adversarial review — issue 23 / normaliser-profiles-version

I could not refute the fix. I attacked the evidence, the version rule, the override and "must be used" rules, the SEPA rules and regex run time. Everything I tried behaved as the brief says. One edge case needs a human to decide whether it is in scope; the rest are notes.

## Evidence (red → green)

- Attempted: does the test go red for the right reason, on the production path? `gate-logs/C4-verify.log` shows the red leg with 83 of 88 failed and 0 collection errors. Every failure is `AttributeError: module 'autobook.pipeline.normaliser' has no attribute 'load'` (or the `__all__` mismatch) against the real stub module. The 5 tests that pass are the five in `tests/test_skeleton.py`. The tests import the production module (`tests/test_normaliser.py:24`) and reach every new name through it. Nothing mirrors or mocks the code under test. **Could not refute.**
- Attempted: would the green tests still pass if a key piece of behaviour were missing? I checked by reading the code and running probes, with pytest unavailable in this sandbox (I used the Python 3.14 interpreter directly on `$PDCA_TARGET/src`):
  - Without `re.IGNORECASE` (`src/autobook/pipeline/normaliser.py:263`), (e) `tests/test_normaliser.py:368` would fail, because `\bfiliale\b` cannot match the upper-cased memo.
  - Without the glued-tag lookahead (`src/autobook/pipeline/profiles/sepa.toml:21`), (b3) `tests/test_normaliser.py:234` would fail.
  - Without `extends` being resolved after overrides (`normaliser.py:133-134`), `tests/test_normaliser.py:278` would fail.
  - Without `unidata_version` in the digest (`normaliser.py:361`), `tests/test_normaliser.py:346` would fail.
  - Including a path in the digest would fail `tests/test_normaliser.py:316`.

  **Could not refute.**

## The fix

- Attempted: reproduce every example in the brief on the sepa-mapped account. All of them match exactly, including the glued `EREF+NOTPROVIDEDSVWZ+BEISPIELMARKT` → `BEISPIELMARKT` and the two card timestamps → `BEISPIELMARKT//MUENCHEN/DE`.
- Attempted: catastrophic backtracking (a regex taking far longer than the input size suggests) in `profiles/default.toml:15-50` and `profiles/sepa.toml:21,27`. I ran 200 kB hostile memos: tag-prefix runs with no `+`, 28k dropped tags, long punctuation runs ending in a letter, `1.`, `1:` and `2025-` runs, whitespace runs. Every one finished in under 0.05 s, so run time grows linearly with memo length. **Could not refute.**
- Attempted: find a way to change a token without changing `version`. The digest (`normaliser.py:350-372`) covers the resolved rule strings of every profile, the mapping, `NORMALISER_VERSION` and the Unicode version. The regex flags are fixed in code. Mapping an account to `default` explicitly changes the version even though no token changes, which is the global version working as designed. **Could not refute.**
- Attempted: get an unused user profile past `_check_used` (`normaliser.py:329-344`). I tried a chain `a → b → default` with only `a` mapped (accepted, correct) and an unused profile that extends a used one (rejected). An overridden package profile's old `extends` does not count as a use, because the check reads the merged set. **Could not refute.**
- NEEDS-HUMAN [human] — `src/autobook/pipeline/profiles/sepa.toml:21`: a SEPA tag that is split by a line break is not recognised, so the value of a dropped tag survives. Concrete case: `SVWZ+BEISPIELMARKT\nIBA\nN+DE00ZZZ000` on a sepa-mapped account gives `BEISPIELMARKT IBA N+DE00ZZZ000`, and the IBAN value is in the token. MT940 field 86 is wrapped into short sub-fields, so whether this happens depends on how the statement source joins the lines. That joining is upstream of this slice. The brief covers line breaks *between* tags (tested with the `one-tag-per-line` case, `tests/test_normaliser.py:183`) but says nothing about a break *inside* a tag. The rubric's privacy class ("a counterparty IBAN in shareable data") makes this worth a decision: either confirm that line joining guarantees whole tags, or record it as a known limit next to the "IBAN typed into `SVWZ+`" one in ch.5 §5.2. This is not a builder defect, because the patch does what the brief specifies.
- Note, no action proposed (brief-specified behaviour): because tags are matched with no word boundary in front, a word that ends in a tag name followed by `+` truncates the kept text. Concrete case: `SVWZ+ZAHLUNG ARABIC+ CAFE IBAN+DE00ZZZ` → `ZAHLUNG ARA`. Separately, the digit-run and punctuation-only rules (`profiles/default.toml:44,50`) erase merchant names made only of digits and punctuation. Concrete cases: `SVWZ+1&1 TELECOM` → `TELECOM`, and `1&1` alone → an empty token, which is the safe "no neighbour" result. Both follow the brief's rules as written and use realistic but uncommon inputs. I am recording them for the human's awareness, not as defects.

## The verdict

- `check-gates.json`, C4-ci row (`gate-logs/C4-ci.log`): the local gate ran only the `test-3.14` session. The docs this patch adds say CI runs Python 3.11 to 3.14. Python 3.11 to 3.13 are not on this host, so I could not run them. I read the code for 3.11 hazards and found none: global `(?s)` is at the start of the pattern, and `tomllib` and `importlib.resources.files(...).iterdir()` both exist in 3.11. The GitHub matrix (`.github/workflows/ci.yml:84`) will cover it. This is not a refutation.
- I found no claim in `check-gates.json` or the brief that the frozen gate output contradicts. The C4-verify evidence line ("83 of 88 failed") matches the log line for line.

<!-- pdca:leaf-complete -->
