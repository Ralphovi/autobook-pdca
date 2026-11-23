## Review rubric & protocol

Authors self-review against this before requesting review; reviewers judge
against it. The repo's written conventions are the arbiter, not reviewer taste.
When a defect class recurs, it graduates to a gate and drops out of review scope.

### Recurring defect classes (MUST check when the diff touches the surface)

- *Money*: any float in a monetary path; a float reaching the `GncNumeric(float)`
  constructor; a rules-file amount written as `value: 12.50` instead of integer
  `cents:`; rounding that does not preserve the exact-sum property; a currency
  assumed rather than read from the source account's commodity, or a commodity
  whose fraction is not checked to be 100.
- *Book writes*: a row written that was not marked `a` in the saved review file;
  a mutation outside `BeginEdit`/`CommitEdit`; a batch ended without
  `session.save()`; a row reported applied without a read-back; a session not
  ended in `finally`; a write path that could run while the GUI holds the lock
  (`ERR_BACKEND_LOCKED`); a launcher path that can exit before `exec gnucash`.
- *Idempotency*: a path that can create a transaction twice after a crash between
  "committed to book" and "marked applied"; `num` or a FITID/`online_id` stamp
  written to a matched transaction; a `num` that does not match the proposal-ID
  pattern treated as Autobook's; an undo that deletes without checking both the
  staging GUID with disposition `create` and the `num`.
- *Double-booking*: a transfer booked from both statements, or a second side
  classified instead of matched or queued as "pending transfer"; a PayPal row
  classified as an expense rather than matched to its funding transaction (in
  `account` mode); a `create` on a scheduled-transaction occurrence; a
  `match_existing` search on the target account, or filtered to unreconciled
  transactions.
- *Documents*: a statement line, amount or balance taken from OCR text, the
  archive version or metadata; a statement partly admitted; a document link that
  changes an amount, date or account, creates a split, or overwrites an existing
  link; a decision read from the paperless stamp; document content or a
  correspondent name in staging, a log or a model request; a downloaded original
  or review file outside `$XDG_RUNTIME_DIR`, readable by others, or left behind
  after a failure; a document-keyed rule acting without a confirmed
  correspondent association.
- *Out-of-scope rows*: silently queued instead of dispositioned `out_of_scope`,
  or counted in coverage and drift metrics — either one degrades the drift
  detector until it stops catching real drift.
- *Abstention erosion*: a change that makes a novel merchant look familiar; a
  threshold widened without backtest evidence; a synthetic row reaching the
  index; an LLM row pre-marked before shadow mode has measured `method=llm`; an
  ambiguity-flagged row pre-marked by a tier below the flag; a rule `priority`
  that reorders tiers.
- *Failure granularity*: a per-row problem that halts the batch, or a batch-level
  problem (coverage drop, LLM-fallback spike, parse errors) that still writes; a
  failed post-apply assertion that is not flagged and undoable.
- *Backend assumptions*: SQL used where an XML book must work; a file-copy backup
  assumed where the backend is a server; a `CommitEdit` assumed durable on an
  XML book.
- *Privacy*: a raw memo crossing the adapter boundary; a remote backend
  receiving a token outside the rule packs and allowlist, or an account name; a
  counterparty IBAN in shareable data; a credential in config; a transaction in
  a test fixture drawn from a real statement.

### Reviewer protocol

- **DCO**: the `dco` status check is the sole authority. Do not report
  `Signed-off-by` findings from your own commit inspection — the SHAs a review
  context exposes are often GitHub's synthesized merge-preview commits, and this
  finding class is reliably a false positive.
- **Deferrals are settled**: a finding answered with "Deferred — tracked in #N"
  (or an in-code `# deferred: #N` marker) is resolved for review purposes. Raise
  the tracking issue instead if the deferral itself seems wrong.
- **Out of scope**: a real finding outside the PR's stated scope gets a
  decline-with-issue-reference, not an in-PR fix.
- **Definition of done**: the gate green plus **one** deep, multi-pass review
  whose findings are each fixed or rejected with a recorded reason. Do not
  iterate review rounds chasing silence.
