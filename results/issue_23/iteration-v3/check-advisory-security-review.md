# Security review — issue 23 (normaliser profiles and version)

**Attacker-reachable inputs this diff touches:** statement memo text (threat model "Where untrusted input enters" #1, written by any counterparty), which now flows into `Normaliser.normalise`. The profile files and `accounts.toml` in `$XDG_CONFIG_HOME/autobook/normaliser/` are the user's own config, which the threat model lists as trusted.

## Findings

No finding. Here is what I checked:

- **Hostile memo to regex (crash or hang).** Memo text only meets the shipped patterns in `src/autobook/pipeline/profiles/default.toml` and `sepa.toml` (applied at `src/autobook/pipeline/normaliser.py:87`). The one with an open-ended scan is the SEPA tag rule (`sepa.toml:10`). Its lazy `[\s\S]*?` always ends at the next tag or `\Z`, so it never fails and backtracks. I ran the patched code on synthetic memos of about 200 kB each: `"EREF+" + "A"*200000`, `"EREF+X"*40000`, a 200 000-digit run followed by a letter, `("NR." + " "*1000)*200`, `"1.1."*50000` and `"CRED"*50000`. Each took 0.01–0.03 s under both profiles, so time grows linearly with memo length. No exception is reachable from memo content. `normalise` only raises on a bad `source_account`, and that comes from the book or config, not from a counterparty.
- **Raw memo unchanged and kept apart.** `NormalisedMemo.raw_memo` (`normaliser.py:56`) keeps the input as given, and only `token` is derived from it. Nothing in the diff logs, prints or sends either one. No model adapter, staging write or review-file output is touched.
- **Personal data in the token.** A token is the memo minus the boilerplate, so it can still hold a personal name or an alphanumeric IBAN. `\b\d+\b` does not strip `DE..`-style IBANs. This is by design: AGENTS.md says "Redaction happens at the model-adapter boundary", and the threat model rates token quality as "lower priority (a bad token falls through to review)". This diff does not widen that gap.
- **Memo shaped to look like a familiar merchant.** A counterparty controls the SEPA `SVWZ+` purpose text, and the `sepa` profile keeps that text. A sender can therefore make a token read like a known merchant. This is the known gap "a model or kNN can propose the wrong account". Creditor-ID rules come first in the cascade, and this diff changes no gate or threshold.
- **User config (trusted).** A user pattern that is slow on some input could hang a run. That needs a misconfiguration by the user, which the threat model rates Low, so I am not raising it. Unknown keys, bad regexes, unknown profiles and duplicate mappings all raise `NormaliserError` instead of silently falling back (`normaliser.py:114`, `:197`, `:223`). An unreadable user directory raises instead of being skipped.
- **Version stability.** The version is a digest of the patterns and mapping that are in effect, with no paths or timestamps in it. A changed profile therefore changes the version tuple, and old vectors are not silently reused with new tokens.
- **Test fixtures.** The SEPA test memos use made-up merchants (`BEISPIELMARKT`), the standard sample creditor ID `DE98ZZZ09999999999` and placeholder references. No real memo, IBAN or name appears.
- **Gates.** The T2 gate reported "no security-relevant path touched". I agree: the normaliser is not a trust boundary, so the threat model does not need an edit.

## Note (hardening, not a finding)

- `src/autobook/pipeline/normaliser.py:53-56`: `NormalisedMemo` is a dataclass with the default `repr`, so `repr(result)` contains the full raw memo (checked: `NormalisedMemo(raw_memo='SECRET MEMO', ...)`). No code path logs it today, so this is not a finding. Once a later step logs proposals or writes crash reports, though, a `%r` or a traceback that shows local variables would leak the raw memo. Leaking it to a log is rated High in the threat model. One cheap fix the builder could adopt here or in the step that adds logging is `raw_memo: str = dataclasses.field(repr=False)`.

<!-- pdca:leaf-complete -->
