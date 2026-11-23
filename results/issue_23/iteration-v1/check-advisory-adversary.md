# Adversarial review — issue 23 / normaliser-profiles-version

**Bottom line:** I could not break the red→green proof or the brief's criteria (a)–(d). I did find two concrete cases where the fix gives wrong results, and one design question for a human.

**Evidence.** `pytest` is not installed in this sandbox, so I judged red→green from the frozen `gate-logs/C4-verify.log`. It shows green at 42/42 and red at 37/42. On the red leg every failure is `AttributeError: … has no attribute 'load'`, which is the RAN-and-FAILED state the brief planned for. The 5 tests that pass on red are the `tests/test_skeleton.py` tests. The tests call the real `autobook.pipeline.normaliser` and the shipped TOML profiles; nothing is mocked or re-implemented in the test. I also ran the production code directly with plain Python. Criterion (a) holds for corpus seeds 0–49, not just 0–2: 0 mismatches. On the red leg, any test that calls `load` goes red, so red only proves the API is missing. The tests prove the behaviour on the green leg. That is how a new feature works, so it is not a refutation.

## Findings

- NEEDS-HUMAN [impl] — `target/src/autobook/pipeline/profiles/sepa.toml:7` and `:11`: the `\b` in front of each tag in the lookahead (and in the `SVWZ+` rule) means a tag glued to the previous value is not seen as a tag. Then the `EREF+`/`MREF+`/`CRED+`/`ABWA+` value runs on to the end of the memo and the merchant is deleted. Concrete cases, run against the production loader with `Aktiva/Girokonto` mapped to `sepa`:
  - `"EREF+NOTPROVIDEDSVWZ+BEISPIELMARKT"` gives `''`.
  - `"EREF+123 MREF+456SVWZ+BEISPIELMARKT"` gives `''`.
  - The expected token in both is `BEISPIELMARKT`.
  
  Glued tags are a real shape. MT940 `:86:` subfields (the free-text lines of a German bank statement) are 27-character lines that some exporters join without a space. The brief says "up to the next SEPA tag", not "up to the next tag that follows a word break". Fix: drop `\b` from the lookahead (the tags are four capitals plus `+`, so false hits are unlikely), and add a test with a glued memo.
- NEEDS-HUMAN [impl] — `target/src/autobook/pipeline/normaliser.py:105-108`: a user directory that exists but cannot be read (mode `0300`) loads with no error. `Path.glob` swallows the `PermissionError` and returns nothing. The result is package profiles only, with the same version as package-only (`1-63b3ea5b316e` both ways), so the user's `accounts.toml` and overrides are dropped without a word. The brief says "unreadable … profile file … raises `NormaliserError`. Never a silent fallback." An unreadable *file* does raise correctly (`_read_toml`, `:149`). Fix: list the directory with `os.scandir`/`iterdir` inside a `try` that maps `OSError` to `NormaliserError`, and add a test with `chmod 0o300`.
- NEEDS-HUMAN [human] — abstention erosion (rubric: "a change that makes a novel merchant look familiar"), `target/src/autobook/pipeline/profiles/sepa.toml:7`. The brief requires removing `CRED+` and `ABWA+` together with their values. This patch does that faithfully, but `CRED+` (the creditor ID) and `ABWA+` (the "on behalf of" party) are often the only thing that tells two merchants apart. Two cases:
  - Two direct debits from different creditors, `…CRED+DE98ZZZ01111111111 SVWZ+MITGLIEDSBEITRAG 01.2025` and `…CRED+DE98ZZZ02222222222 SVWZ+MITGLIEDSBEITRAG 01.2025`, both give `MITGLIEDSBEITRAG .`.
  - `SVWZ+ZAHLUNG 1234 ABWA+BEISPIELMARKT GMBH` and `SVWZ+ZAHLUNG 9876 ABWA+MUSTERBAECKEREI` both give `ZAHLUNG`.
  
  So the kNN index (#24) would see a never-seen merchant as a familiar one. This is the brief's design, not a build slip. A human should decide whether `sepa` should keep the creditor ID or the `ABWA` name as part of the token. If not, record the reason and a tracking issue.
- NEEDS-HUMAN [impl] — `target/src/autobook/pipeline/profiles/sepa.toml:3` relies on a comment ("keep the two files in step") to keep the copied `default` rules in `sepa` equal to `default.toml`. No test checks this. If someone edits `default.toml:23-26` and not `sepa.toml`, behaviour drifts with no test going red. The version still changes, so it is not hidden from the gate tuple, only from tests. Fix: one test that `sepa`'s rules end with exactly `default`'s rules.
- Note, not a blocker: `target/src/autobook/pipeline/normaliser.py:175` accepts a pattern that matches the empty string. A user `default.toml` with `pattern = ''` turns `Beispiel` into `B E I S P I E L` with no error. The brief only requires rejecting patterns that don't compile, so this is within scope as written. It is the same "a typo silently becomes a rule" risk the brief guards against, though.

## Claims in check-gates.json / brief

- `C4-verify` "red without the fix (37 of 42 failed), green with it": confirmed from the log. The claim is accurate, but it only covers the API being present. The two behaviour defects above pass the green leg because no test feeds a glued SEPA memo or an unreadable directory.
- T2 "no security-relevant path touched": correct by path, as the brief predicted. I found nothing new on the user-supplied regex beyond the brief's own "local, self-inflicted" note.

I tried and failed to break: the version (it stays the same from two different directories, and changes with rule order, one rule, or one mapping line); the override and restore behaviour; the account-path checks (a list is accepted, an empty part is rejected); a user directory that is really a file (rejected); a bad-TOML file (rejected with the file name); and the skeleton exemption (it skips only the three stub-shape assertions and leaves every other check in place).
<!-- pdca:leaf-complete -->
