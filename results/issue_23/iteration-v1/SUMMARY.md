# Result — issue 23 / normaliser-profiles-version

## 1. Spec (from brief.md)              ← Check verifies against THIS
- Defect / goal: Turn a raw bank memo into a stable merchant token, in one place in the pipeline, driven by named per-source-account profiles (shipped in the package, overridable from a user directory), with a normaliser version that changes whenever anything that affects the output changes, carried on every normalised result.
- Success criterion: `tests/test_normaliser.py` passes with the patch applied and fails, with tests that RUN (not a collection error), with the production change reverted. It must assert: (a) with an empty user directory, for every row of `build_corpus(seed)` for seeds 0, 1 and 2 (`tests/fixtures/synthetic/corpus_builder.py`), the token equals that row's merchant name (`Merchant.token` of the merchant whose name starts the memo, or `NOVEL_MERCHANT`); (b) synthetic SEPA memos, normalised for a source account the user directory maps to the `sepa` profile, give the expected token, and none of `EREF+`, `MREF+`, `CRED+`, `SVWZ+`, `ABWA+` survives in any token; (c) a user-directory profile with the same name as a package profile replaces it (a memo the package profile reduces to one token gives a different, expected token), and with that user file absent the package profile applies again; (d) two loads of the same profiles give the same `version`, including identical profile and `accounts.toml` files written into two *different* user directories (two separate subdirectories of `tmp_path`), so no path enters the digest; changing one rule in a user profile, or one line of the account mapping, gives a different `version`; every result carries the normaliser's `version` and the unchanged `raw_memo`.
- Repo + branch target: Ralphovi/autobook @ main
- Scope (one logical fix) / out of scope: (1) the normaliser in `src/autobook/pipeline/normaliser.py`, with the API, profile format, override rule and version rule below; (2) two package profiles, `default` and `sepa`, as TOML files in `src/autobook/pipeline/profiles/`; (3) `tests/test_normaliser.py`; (4) `tests/test_skeleton.py` exempts the normaliser from the stub checks (below); (5) docs currency: ch.5 §5.2 *Normaliser* and ch.8 §8.8 record the profile format, the user directory, the mapping file, the override rule and the version rule. / out of scope: assembling the version tuple or the batch gate that compares it (no code for either exists yet; this slice only provides the value); any staging column write (`normaliser_version` in `proposals` arrives with staging, build step 3); bank profiles beyond `default` and `sepa` (Revolut, PayPal …); PayPal pass-through merchant parsing (correlator); any ofxstatement plugin; the kNN index (#24) and backtest (#25); new runtime dependencies (`tomllib` is in the standard library from Python 3.11, the minimum).

## 2. Disposition claimed               ← sign-off confirms or overrides
- Outcome: new-feature
- Confidence: medium
- Recommendation: (set by Do)

## 3. Correctness (Check — chain)
- C1 Spec: none — brief.md
- C2 Reproduction (red pre-fix): none — (no gate configured)
- C3 Change: none — patch.diff
- C4 Autobook gate: nox -s gate (fmt/lint/types/test/typos/docs): pass — nox > * docs: success
- C4 fix verified: bundle test red pre-fix, green post-fix (pytest): pass — C4 PASS — red without the fix (37 of 42 failed), green with it
- C5 Causal adequacy: none — reviewer + human sign-off

## 4. Conformance (Check — stack)
- T1 Structure: none — (no gate configured)
- T2 security-relevant change also updates the threat model: pass — no security-relevant path touched
- T3 Runtime: none — (no gate configured)
- T4 PR body has a user-impact opener + tracker id in both artifacts: deferred — pr-description.md not drafted yet — the substantive T4 audit of the contribution artifacts runs at publish
- T5 Judgment: none — reviewer + human sign-off
- T5 judgment: → see §5.

## 5. Advisory review (artifact-only, decorrelated)
Reviewer ran without build-notes.md. Summary:

Review issue #23: implement account-specific TOML memo-normalisation profiles, user overrides, and a deterministic version carried with every result.

| Item | Verdict | Basis |
|------|---------|-------|
| C1 Spec | PASS | The scope and success criteria are concrete and falsifiable, including corpus tokens, SEPA fields, overrides, and path-independent versioning; brief.md:12 and brief.md:21. |
| C2 Reproduction (red pre-fix) | PASS | Independently stashing production changes made all four direct probes execute and fail on the missing API; the frozen pytest leg also shows 37 failures without collection errors; reviewer-red.log:1 and gate-logs/C4-verify.log:985. |
| C3 Change | PASS | Changes stay within the planned normaliser, profiles, skeleton exemption, and architecture documentation; src/autobook/pipeline/normaliser.py:96, tests/test_skeleton.py:50, and docs/design/architecture/05-building-block-view.md:141. |
| C4 Verification (red→green) | PASS | Restoring production changes passed all four independent probes, including all 334 corpus rows; frozen evidence supports 42 bundle passes and 216 broader-suite passes, with the exclusions stated below; reviewer-green.log:1, gate-logs/C4-verify.log:12, and gate-logs/C4-ci.log:55. |
| C5 Causal adequacy | NEEDS-HUMAN [impl] | Fix unreadable-directory fallback and adjacent-tag parsing before relying on these profiles downstream: both produce incorrect tokens despite green tests; src/autobook/pipeline/normaliser.py:108 and src/autobook/pipeline/profiles/sepa.toml:7; reproduced in reviewer-edge-cases.log:3 and reviewer-edge-cases.log:6. |
| T1 Structure | PASS | Normalisation remains in one pipeline module, with package data and no new runtime dependency or book-process coupling; src/autobook/pipeline/normaliser.py:16, src/autobook/pipeline/normaliser.py:83, and pyproject.toml:30. |
| T2 Shape | PASS | The public result preserves the raw memo, configuration schemas are explicitly validated, and matching architecture docs accompany the API; the frozen threat-model scanner reports no security-relevant path touched, which is only its path-based verdict; src/autobook/pipeline/normaliser.py:52, src/autobook/pipeline/normaliser.py:156, and gate-logs/T2-threat-model.log:10. |
| T3 Runtime | FAIL | An existing but unreadable user directory is silently treated as absent, replacing the user's effective rules with package defaults instead of rejecting the configuration; src/autobook/pipeline/normaliser.py:105 and reviewer-edge-cases.log:1. |
| T4 Contribution | N/A | Contribution artifacts are absent by design at Check; the substantive contribution audit is deferred to the required publish gate; gate-logs/T4-contribution.log:10. |
| T5 Judgment | NEEDS-HUMAN | Confirm the prior-art disposition for affected paths across merged history and closed/rejected work before accepting a new API: brief.md:25 records the search, but the supplied target has one flattened base commit and no remote, so that history cannot be independently settled here. |
| Validation — fitness-to-purpose | NEEDS-HUMAN | Approve the TOML compatibility contract, full-version string for downstream consumers, and local user-regex trust model before #24/#25 depend on them; synthetic correctness checks do not decide these product commitments; brief.md:145, brief.md:217, and docs/design/architecture/05-building-block-view.md:147. |

Source citations above and below are relative to `$PDCA_TARGET`; evidence and brief citations are relative to the review directory. The target is readable and consistent with the patch: `git apply --reverse --check ../patch.diff` succeeds. No stale-target caveat applies. No production or test source was edited; the temporary production stash was popped and the original working-tree status restored.

**Reproduced implementation findings**

- **P2 — Reject unreadable configuration instead of silently dropping overrides.** At `src/autobook/pipeline/normaliser.py:108`, `Path.glob()` suppresses directory traversal errors. On the supplied Python 3.14.4 runtime, a directory containing `default.toml` with a rule removing `MARKT` yields `BEISPIEL` for `BEISPIEL MARKT` while readable. After setting directory permissions to `000`, direct directory enumeration raises `PermissionError`, but `load()` succeeds and returns `BEISPIEL MARKT`, with the same version as a genuinely absent directory. This violates the documented loud-error contract (`docs/design/architecture/05-building-block-view.md:143`) and silently discards user configuration. Use directory enumeration/stat handling that distinguishes an absent directory from unreadable configuration, translate access errors to `NormaliserError`, and add a regression test. Evidence: `reviewer-edge-cases.log:1`.
- **P2 — Recognise adjacent SEPA tags without requiring a word boundary.** At `src/autobook/pipeline/profiles/sepa.toml:7`, the next-tag lookahead requires `\b`, although the documented delimiter is the next SEPA tag, not whitespace (`docs/design/architecture/05-building-block-view.md:157`). `EREF+ABCSVWZ+BEISPIELMARKT` therefore becomes an empty token instead of `BEISPIELMARKT`; `SVWZ+BEISPIELMARKTEREF+ABC` retains `EREF+ABC`. The spaced control case passes. Existing cases at `tests/test_normaliser.py:65` separate tags with spaces and miss both failures. Correct tag delimiting and add adjacent-tag regression cases. Evidence: `reviewer-edge-cases.log:5`.

Reproduce both findings from the review directory with `PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=target/src:target python3 reviewer-edge-cases.py`. This uses actual filesystem permissions and the patched production module, without mocks or tool shims. It restores directory permissions in `finally`; all generated evidence stays inside the harness directory.

**Evidence and limits**

The independent red→green run used `reviewer-runtime.py`, four standard-library probes covering corpus tokens/raw-memo preservation, spaced SEPA tags, overrides, and version stability/change. All four failed inside their bodies against the stashed production tree and passed after restoration (`reviewer-red.log:1`, `reviewer-green.log:1`). These are additional direct probes, not a claim to have rerun pytest. I independently reran the documentation linter (`lint_docs: OK (2 ADR(s) checked)`), `typos` (exit 0), and `git diff --check` (exit 0).

The local interpreter has no pytest, nox, ruff, or mypy. I read the frozen gate evidence instead: `gate-logs/C4-ci.log:16` shows format success, line 23 lint success, line 30 type-check success, line 55 the 216 passing tests, and lines 59–64 spelling/docs success. The suite explicitly skips the unavailable GnuCash test module and deselects seven book/live tests; those are outside this pipeline-only scope. `gate-logs/C4-verify.log:12` and line 985 show 42 green tests versus 37 failed/5 passed on red, with zero setup or collection errors. The brief declares no external dependency (`brief.md:22`); the reviewer tool limitation does not turn that captured execution into an unmet runtime dependency.

The capability-probe/symptom-guard smell-test does not fire: configuration validation and the missing-directory policy are not guards around a capability assumed present. The actual directory-error handling defect is recorded above.

The prior-art investigation ran `git log --all --` over all affected paths and inspected remotes. It returned only `42fc10b pre-fix base 76baccee40f2a62d8da380ac46ddbcecf181e855`, with no remote configured. The brief records path-based history and an all-state PR search, including closed issue #5's split into #22–#26; those records cannot be independently corroborated from this flattened copy. No `INTEGRATION.md` is present in the supplied target, so no additional enumerated human-only items were available to assess.

<!-- pdca:leaf-complete -->

### Advisory — adversary

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

### Advisory — security-review

# Advisory security review — issue 23 / normaliser-profiles-version

**Attacker-reachable inputs this diff touches:** one — the raw memo (threat model, "Where untrusted input enters" #1: counterparty text). It is the `raw_memo` argument of `Normaliser.normalise` (`src/autobook/pipeline/normaliser.py:167-177` in the patch). The other new input, the profile and `accounts.toml` files under `$XDG_CONFIG_HOME/autobook/normaliser/`, is the user's own config, which the threat model lists as **trusted**. Package profiles ship with the code. Nothing calls the normaliser yet, so no memo reaches it in production today. This review checks the API that #24 and #25 will feed memos into.

**Verdict: no finding.** What I checked:

- **Hostile memo against the shipped patterns (crash, hang, ReDoS, the regex blow-up where a crafted input makes matching take far too long).** I timed all eight package patterns (`default.toml`, `sepa.toml`, run in the same order as `normalise`) on synthetic memos between 0.2 and 2.4 million characters: `EREF+` repeated, `EREF+` followed by one long tag-free run, a long digit run ending in a letter, `NR.` followed by many spaces, `NR. ` repeated, `1.1` repeated, `EREF+ SVWZ+` repeated, `EREF` with no `+`, and `ß` repeated. Every case finished in under 0.08 s and time grew linearly with length. The lazy SEPA rule `[\s\S]*?(?=…|\Z)` always matches from a tag, so matches never overlap and nothing backtracks twice. No crash: `raw_memo` is typed `str` in the contract (`src/autobook/contracts.py:123`, checked at `:132`), and `str.upper()`/`re.sub` cannot raise on any `str`.
- **Review-file row forging through the token.** `normalise` builds the token with `" ".join(text.split())` (`normaliser.py:174` in the patch), so newlines, tabs and other whitespace in a memo can never survive into a token. The test at `tests/test_normaliser.py` (`test_token_is_upper_cased_and_whitespace_collapsed`) covers a `\n` and a `\t`. The raw memo stays unchanged in `NormalisedMemo.raw_memo` by design. Escaping it is the review-file renderer's job, which this diff does not touch.
- **Making a novel merchant look familiar (abstention erosion).** The SEPA rule removes everything from a fake `EREF+`/`MREF+`/`CRED+`/`ABWA+` tag, typed inside the counterparty's own purpose text, up to the next tag or the end of the memo. That gives a counterparty no new power. They already control the whole memo text and could write a familiar merchant name directly. The rule only works on the memo, never on separate fields (payee, creditor ID). The worst case is a poor or empty token, which the threat model rates **Low** ("a poor normalised token that still falls through to review"). #24 treats an empty token as having no neighbour.
- **Privacy.** Nothing in the module logs anything. Error messages never include a memo. `normalise` puts only the *source account path* into its error (`_account_path`, `normaliser.py:292-302` in the patch), and `load` errors include local file paths. Both are the user's own data in a local exception, not sent to a backend or a pack. At most **Low** under the threat model, and not personal-data-to-log in any way that matters, since the account path is not counterparty data. Test memos are invented: the creditor ID uses the `ZZZ` synthetic form, and there are no IBAN-shaped strings (`tests/test_normaliser.py`, SEPA cases).
- **Version integrity (no silent mix of two normalisations).** `_version` hashes the sorted profile names, every rule in file order, and the sorted account mapping, prefixed by `NORMALISER_VERSION` (`normaliser.py:305-314` in the patch). No path or timestamp goes in. The tests pin "same files, different directory, same version", "one changed rule, mapping line or rule order, different version", and "every result carries the version".
- **User-supplied regex (the brief's open sign-off point).** A slow pattern in the user's own profile can only slow the user's own run. That is trusted config, and at worst "a misconfiguration the user made" (**Low**). It does not make any known gap worse, so I see no need for a threat-model change. Rule packs, which *are* untrusted, are not loaded through this path.
- **Money, book writes, idempotency, documents, model adapter.** Not touched: the diff has no amounts, no `gnucash` import, no staging write, no paperless access and no adapter call.

No NEEDS-HUMAN items.

<!-- pdca:leaf-complete -->

## 6. NEEDS-HUMAN — items the human must clear before sign-off
- [ ] C5 Causal adequacy — Fix unreadable-directory fallback and adjacent-tag parsing before relying on these profiles downstream: both produce incorrect tokens despite green tests; src/autobook/pipeline/normaliser.py:108 and src/autobook/pipeline/profiles/sepa.toml:7; reproduced in reviewer-edge-cases.log:3 and reviewer-edge-cases.log:6.
- [ ] T5 Judgment — Confirm the prior-art disposition for affected paths across merged history and closed/rejected work before accepting a new API: brief.md:25 records the search, but the supplied target has one flattened base commit and no remote, so that history cannot be independently settled here.
- [ ] Validation — fitness-to-purpose — Approve the TOML compatibility contract, full-version string for downstream consumers, and local user-regex trust model before #24/#25 depend on them; synthetic correctness checks do not decide these product commitments; brief.md:145, brief.md:217, and docs/design/architecture/05-building-block-view.md:147.
- [ ] `target/src/autobook/pipeline/profiles/sepa.toml:7` and `:11`: the `\b` in front of each tag in the lookahead (and in the `SVWZ+` rule) means a tag glued to the previous value is not seen as a tag. Then the `EREF+`/`MREF+`/`CRED+`/`ABWA+` value runs on to the end of the memo and the merchant is deleted. Concrete cases, run against the production loader with `Aktiva/Girokonto` mapped to `sepa`:
- [ ] `target/src/autobook/pipeline/normaliser.py:105-108`: a user directory that exists but cannot be read (mode `0300`) loads with no error. `Path.glob` swallows the `PermissionError` and returns nothing. The result is package profiles only, with the same version as package-only (`1-63b3ea5b316e` both ways), so the user's `accounts.toml` and overrides are dropped without a word. The brief says "unreadable … profile file … raises `NormaliserError`. Never a silent fallback." An unreadable *file* does raise correctly (`_read_toml`, `:149`). Fix: list the directory with `os.scandir`/`iterdir` inside a `try` that maps `OSError` to `NormaliserError`, and add a test with `chmod 0o300`.
- [ ] abstention erosion (rubric: "a change that makes a novel merchant look familiar"), `target/src/autobook/pipeline/profiles/sepa.toml:7`. The brief requires removing `CRED+` and `ABWA+` together with their values. This patch does that faithfully, but `CRED+` (the creditor ID) and `ABWA+` (the "on behalf of" party) are often the only thing that tells two merchants apart. Two cases:
- [ ] `target/src/autobook/pipeline/profiles/sepa.toml:3` relies on a comment ("keep the two files in step") to keep the copied `default` rules in `sepa` equal to `default.toml`. No test checks this. If someone edits `default.toml:23-26` and not `sepa.toml`, behaviour drifts with no test going red. The version still changes, so it is not hidden from the gate tuple, only from tests. Fix: one test that `sepa`'s rules end with exactly `default`'s rules.
- [ ] **Criterion (d) does not pin the path-independence the brief promises.** Design §Version says the digest "does not depend on file system order, modification times, or the directory's path". Criterion (d) only asks that "two loads of the same profiles give the same `version`". A test that loads the same `tmp_path` twice passes even if the user-dir path is hashed into the digest. If that happened, the version would change whenever `$XDG_CONFIG_HOME` moves, and every vector would look invalidated. Revise (d): identical content in two *different* directories must give the same `version`.
- [ ] **The issue names `NORMALISER_VERSION` as the recorded value; the brief records something else.** The issue scope says "`NORMALISER_VERSION`, recorded with every vector and in the version tuple" (notes.json body). In the brief, `NORMALISER_VERSION` is a code-only `Final[int]`, and the recorded value is `Normaliser.version: str` (`"<int>-<12 hex>"`). That fits ch.8 §8.8 ("Every configuration value that can change a classification is part of the version tuple", sources/08…md:146-148), and the maintainer settled it at Plan. But it is a rename of the issue's contract that #24/#25 are "briefed against". The brief should say outright that `Normaliser.version`, not the constant, goes into vectors, the tuple and the future `proposals.normaliser_version` column (sources/05…md:268), and the PR description should say so too. Otherwise #24 may record the int.
- [ ] **The brief claims to settle the open points but leaves the user-facing file formats to Do.** The header says the proposal fixes "profile file format … so Do does not re-decide it". Design §Profiles then says "Do picks the exact TOML layout of a rule", and §User directory says "Do picks the TOML layout" for `accounts.toml`. Both are new configuration surfaces that users will write by hand (ch.8 §8.8/§8.9), so after release they are a compatibility promise. The maintainer settled "named TOML profiles" but not these layouts (§Open questions). Either fix the two layouts in the brief, or drop the "fixes the profile file format" claim and leave the layout for sign-off to decide.
- [ ] **I could not verify the base commit or the dropped `Depends on`.** The issue declares "**Depends on:** #22" (notes.json). The brief says `Depends on: none` because #22 is merged (PR #49, `76bacce`). That reasoning is sound, but the target checkout has no `.git` here, there is no dependency-state.json, and Bash was unavailable. I could neither confirm `76bacce`/PR #49 nor re-run the "3 ran, 3 failed" red probe. The stub contents on the target do match the brief's description. Low risk; confirm at sign-off.

## 7. Proven / not proven
- Proven by which oracle: gates overall = pass (stub oracles).
- Unproven / needs manual run: anything flagged in §6.

## 8. Ready-to-ship attachments
- patch.diff
- tracker-comment.md     (ALWAYS, every tracker item)
- build-notes.md         (builder rationale — for the human, not the reviewer)

## 9. Check sign-off                     ← human completes Check here
- Disposition confirmed / overridden:
- Outcome: iterated-to-Do
- Iteration delta (if iterating): Auto-iterate (round 1): rebuilding for the implementation-level findings — C5 Causal adequacy — Fix unreadable-directory fallback and adjacent-tag parsing before relying on these profiles downstream: both produce incorrect tokens despite green tests; src/autobook/pipeline/normaliser.py:108 and src/autobook/pipeline/profiles/sepa.toml:7; reproduced in reviewer-edge-cases.log:3 and reviewer-edge-cases.log:6.; `target/src/autobook/pipeline/profiles/sepa.toml:7` and `:11`: the `\b` in front of each tag in the lookahead (and in the `SVWZ+` rule) means a tag glued to the previous value is not seen as a tag. Then the `EREF+`/`MREF+`/`CRED+`/`ABWA+` value runs on to the end of the memo and the merchant is deleted. Concrete cases, run against the production loader with `Aktiva/Girokonto` mapped to `sepa`:; `target/src/autobook/pipeline/normaliser.py:105-108`: a user directory that exists but cannot be read (mode `0300`) loads with no error. `Path.glob` swallows the `PermissionError` and returns nothing. The result is package profiles only, with the same version as package-only (`1-63b3ea5b316e` both ways), so the user's `accounts.toml` and overrides are dropped without a word. The brief says "unreadable … profile file … raises `NormaliserError`. Never a silent fallback." An unreadable *file* does raise correctly (`_read_toml`, `:149`). Fix: list the directory with `os.scandir`/`iterdir` inside a `try` that maps `OSError` to `NormaliserError`, and add a test with `chmod 0o300`.; `target/src/autobook/pipeline/profiles/sepa.toml:3` relies on a comment ("keep the two files in step") to keep the copied `default` rules in `sepa` equal to `default.toml`. No test checks this. If someone edits `default.toml:23-26` and not `sepa.toml`, behaviour drifts with no test going red. The version still changes, so it is not hidden from the gate tuple, only from tests. Fix: one test that `sepa`'s rules end with exactly `default`'s rules.. Deferred, not addressed here: 6 finding(s) that need human judgment, held in deferred-findings.json for the human at handover — not build work
- By / date: auto-iterate / 2026-10-15

## 10. Act candidates (hints for the next Act review)
- Plan advisory: 4 finding(s); brief revised: yes (plan-advisory-*.md)
- (empty is the common case)
