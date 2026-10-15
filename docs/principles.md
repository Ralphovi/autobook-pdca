# Planning Principles — solution-design discipline for briefs

> **Status:** living document. **Owner:** Eduard Ralph.
> **Counterpart:** [`fork-discipline.md`](fork-discipline.md) — the **Check**-closing /
> contribution discipline; this file governs **Plan**-time solution design. The two are
> a deliberate pair, one per PDCA beat (doc map below).
> **Why this exists.** A brief that names a *solution mechanism* (a probe, a guard, a
> helper) instead of the *property the fix must restore* seats the fix shape before Do
> reasons about it — and no downstream gate can recover the right shape from a wrong
> success criterion. This document gives Plan the rules and a sourced invariant
> catalogue so it states the right success property before Do ever runs. It was born
> from a real cycle where a symptom-guard shipped where cause-removal was the correct,
> comparably small fix — caught only at human review, one rework round-trip too late.
>
> **Two layers.** This reference layer is the *library*: document a principle here
> freely (near-zero cost). The *active layer* — the brief-template `Invariant to
> restore` field, the planner's minimalism qualifier, and the Plan-exit gate — is the
> small set the brief actually asks about, on the matching defect category (§6). The
> reference layer holds knowledge; the active layer is the few questions worth
> interrupting planning to ask every relevant time. Graduate a principle from reference
> to active only on evidence it is being missed (§8).

**Doc map — the generic-doctrine pair and its instance answers:**

| Doc | PDCA beat | Layer |
|---|---|---|
| [`principles.md`](principles.md) (this file) | **Plan** — solution-design discipline | generic doctrine (templated) |
| [`fork-discipline.md`](fork-discipline.md) | **Check** — closing / contribution discipline | generic doctrine (templated) |
| [`INTEGRATION.md`](INTEGRATION.md) | all — the concrete per-project answers | instance |

---

## 1. Process principle — minimalism is scoped to behavioural bug fixes

- **1.1** In bug-fixing, the target is the smallest reviewable, low-risk delta against
  code you do not own.
- **1.2** The maxim does **not** apply when a fix touches *structure* — what runs at
  load/import, object lifetime, where work happens. There the target is the smallest
  change that **restores the invariant** (§5), not the smallest diff. A named invariant
  takes precedence over diff size.
- **1.3** New-feature work is not governed by minimalism at all.

> Why: when "minimal" is the only *named* currency in the room, it wins by default —
> even on a structural fix where it is out of scope per 1.2. Name the invariant so it
> has something to lose to.

## 2. Process principle — a cost used to reject an alternative must be checkable

- **2.1** Rejecting an alternative on cost requires a **verifiable basis** — a diff
  sketch or a concrete line count someone can check — never an adjective ("heavier",
  "larger", "touches every reader").
- **2.2** A precise estimate of the *wrong* comparison is still wrong. If a named
  invariant is in play, cost-vs-minimalism is not the deciding axis (1.2 governs).
  Estimation is the **backstop**, not the decision.

> Why: an unquantified "heavier" is exactly how a cheaper, better fix gets discarded.
> Make the cost claim checkable and the false ones fall away.

## 3. Process principle — a brief states the invariant, not a solution

- **3.1** Scope names the **defect to remove**. It must **not** name a probe, guard, or
  helper (a capability check, a `hasattr`, a `try/except import`). Naming a mechanism
  seats the fix shape before Do reasons about it.
- **3.2** The invariant is **quantified over the defect category**, not the repro file.
  **Self-test:** *could Do satisfy this by guarding a single module?* If yes, it is the
  narrow symptom-sentence — widen it until a one-module patch visibly fails it.
- **3.3** Mechanism is left to Do; Do prefers removing the cause over guarding the
  symptom.

> The self-test is the load-bearing rule: a success criterion narrow enough to be met
> by guarding one module is narrow enough to let the wrong fix pass. Widen it until only
> the real requirement satisfies it.

## 4. Sourcing principle — invariants come from named, citable sources

- **4.1** Domain invariants live in the catalogue (§5), each with a source and a
  provenance tier.
- **4.2** When Plan classifies a brief into a defect category (§6 mapping), it pulls the
  matching invariant **and its citation** into the brief's `Invariant to restore` field.
- **4.3** A sourced invariant can override "minimal" in a Do/Check argument; an
  unsourced intuition cannot. This is the content Principles 1–3 operate on — without
  it, "state the invariant" (3) just produces a plausible-sounding guess, which lands
  back on the narrow sentence.

---

## 5. The invariant catalogue (sourced) — **project-provided**

> **Scaffold — the template ships the structure; your project fills the content.** Each
> entry is one invariant: a one-line property the fix must make true, a **citable
> source**, and a **provenance tier**. A planner reading this must be able to see *which
> family* an invariant draws its authority from, so keep the tiers separate. Mark an
> entry `[ACTIVE]` when it also appears in the §6 mapping. Tag each citation
> authoritative / corroborating / illustrative per §7.

The target repo is **Autobook** (`../autobook`). Its two written rule sources are
[`AGENTS.md`](../../autobook/AGENTS.md) (§*Hard rules for anything touching a book*,
§*Classification rules*, §*Privacy rules*, §*Documents*, §*Review interface rules*) and
the design: proposal `docs/design/proposals/draft/0001-gnucash-auto-booking-pipeline.md`
as amended by `0002-document-driven-booking-via-paperless.md` (0002 governs the rows in
its *Changes to proposal 0001* table), described in `docs/design/architecture/`. Entries
below cite those by section; `[ACTIVE]` marks the ones that also appear in §6.

### Tier A — language / platform canon

Rules that hold for any Python code, with a standards-level source. Tier A supplies the
*prohibition* only; the exact type Autobook actually uses is Tier B.

- **A1 `[ACTIVE]` — A monetary value must never be held in binary floating point.**
  IEEE-754 binary64 cannot represent most decimal fractions exactly, so arithmetic on it
  is not value-preserving and errors accumulate silently rather than raising.
  *Source:* Python Tutorial, *Floating Point Arithmetic: Issues and Limitations*
  (`docs.python.org/3/tutorial/floatingpoint.html`) — **authoritative**; `decimal` module
  rationale (`docs.python.org/3/library/decimal.html`) — **authoritative**.
- **A2 `[ACTIVE]` — A resource acquired for a run is released in a `finally`,
  unconditionally.**
  `finally` is the only construct that runs on every exit path including an unhandled
  exception; any other placement leaks the resource on the path that matters.
  *Source:* Python Language Reference, *The `try` statement*
  (`docs.python.org/3/reference/compound_stmts.html#the-try-statement`) —
  **authoritative**.

### Tier B — framework / library canon

**Version pinned: GnuCash 5.x / `python3-gnucash` (the system `dist-packages` build).**
Where a citation names a libgnucash symbol, the symbol and its header are the checkable
artifact; pin a doc URL against the version you target before a brief leans on it.

- **B1 `[ACTIVE]` — Monetary amounts are `GncNumeric` rationals constructed from integer
  cents.** The Python bindings expose no `from_double`; the hazard is the
  `GncNumeric(float)` constructor, which converts a double silently (`GncNumeric(0.5)`
  becomes 1/2). It must not be reached for money in any code path, including tests and
  fixtures. This is A1's positive form: the engine's exact
  rational type is the representation, not `float` and not a bare `Decimal`.
  *Source:* libgnucash `gnc-numeric.h` (GnuCash 5.x) — **authoritative**; design proposal
  §*Write path* — **corroborating**.
- **B2 `[ACTIVE]` — Every engine-object mutation is bracketed by `BeginEdit` /
  `CommitEdit`.** An unbracketed mutation is not an error; it is an unpropagated edit.
  *Source:* libgnucash engine edit brackets (`qof_instance_begin_edit` /
  `_commit_edit`, GnuCash 5.x) — **authoritative**; design proposal §*Write path* —
  **corroborating**.
- **B3 `[ACTIVE]` — Sessions open `SESSION_NORMAL_OPEN` for writes and
  `SESSION_READ_ONLY` for dry-run/inspection; never `SESSION_BREAK_LOCK`.** One session
  per run, ended in a `finally` (A2). Breaking the lock is how a book is corrupted by
  writing under a live GUI session.
  *Version note:* `SessionOpenMode` (`qofsession.h`, GnuCash 5.x) **replaces** the
  deprecated `ignore_lock` / `is_new` / `force_new` booleans — pre-5.x examples show the
  old form and must not be copied.
  *Source:* libgnucash `qofsession.h` `SessionOpenMode` — **authoritative**; design
  proposal §*Write path* — **corroborating**.
- **B4 — Assertions and queries against a book go through the engine API, never SQL.**
  The backend abstraction (`xml://`, `sqlite3://`, `mysql://`, `postgres://`) leaks in
  exactly one direction: read-only SQL does not exist for XML-backend users. Applies to
  the idempotency check, the Imbalance assertion, balance checks, and lock inspection
  alike.
  *Source:* design proposal §*Backend abstraction* — **corroborating** (records the
  upstream behaviour); AGENTS.md §*Hard rules* — **authoritative** as the project rule.
- **B5 `[ACTIVE]` — Desktop GnuCash holds the book lock for its entire session and has no
  reload-from-DB.** Anything written while it is open is invisible to it, so the applier
  runs only when GnuCash is closed — sequenced by the launcher, not scheduled.
  *Source:* design proposal §*Locking* — **corroborating**.

### Tier C — internal project invariants

Autobook's own written rules. No external canon is claimed for any of them; the backing
is the rule itself, and for C1 a lint rule.

- **C1 `[GATED]` — Nothing under the pipeline imports `gnucash`** — not in a function
  body, not behind a `try`, not lazily. Only the **book process** (exporter, read-only
  from build step 2; applier, from step 5) may. *Rationale:* it is what keeps the pipeline
  testable with no GnuCash installed, sidesteps the `dist-packages` venv problem, and
  keeps a Windows port a component swap. *Mechanically enforced* by ruff
  `flake8-tidy-imports.banned-api` in `pyproject.toml`, so it is deliberately **not** in
  §6 — see the note there. *Source:* AGENTS.md §*The pipeline/book-process boundary is
  load-bearing*.
- **C2 `[ACTIVE]` — Every row is written at most once, and only what was written is
  undone.** The proposal ID (`AB-` + a ULID) goes in `num` **only on transactions
  Autobook creates**; existing IDs are queried before each batch and dropped. A matched
  transaction gets no `num` and no stamp; staging records its GUID. A row counts as
  applied only after `session.save()` and a read-back. Undo deletes only by GUID **and**
  matching ID. *Rationale:* there is no distributed transaction between book and
  staging store, so a crash between "committed to book" and "marked applied" leaves
  unknown state; this is what makes the applier re-runnable and any batch reversible. On
  an XML book nothing persists until `save()`, and `num` is a field users type into.
  *Source:* AGENTS.md §*Hard rules*; proposal 0001 §*Idempotency*, §*Write path*.
- **C3 `[ACTIVE]` — One economic event is booked once.** A transfer visible in two
  statements is emitted from one canonical side only — also when the second side arrives
  in a later batch (`transfers_pending`); a row on a scheduled-transaction occurrence is
  never `create`d: it matches the instance (searched in the row's **source** account) or
  queues until GnuCash's Since Last Run creates it. *Rationale:* an applier
  that only ever creates double-books every mortgage payment and every inter-account
  transfer; balances then drift with no error raised. *Source:* AGENTS.md §*Hard rules*;
  proposal 0001 §*Correlation pass*, §*Splits and match-to-existing*.
- **C4 `[ACTIVE]` — A threshold moves on backtest evidence across the corpus, never to
  fix one miss.** Both abstention gates — nearest-neighbour distance and vote margin —
  must pass; failing either falls through and does not lower a threshold. Thresholds are
  calibrated with a **rolling-origin** backtest on the **novel-memo** stratum, never
  leave-one-out. *Rationale:* a
  unanimous vote among distant neighbours is a sparse region, not confidence; widening to
  capture one annoying transaction degrades precision everywhere and silently.
  *Source:* AGENTS.md §*Classification rules*; design proposal §*2. kNN*.
- **C5 — Computed splits sum exactly to the transaction total.** A specification that
  does not sum fails the row loudly; the difference is never dumped into Imbalance.
  *Source:* AGENTS.md §*Hard rules*; design proposal §*1. Rules*.
- **C6 — Splits are rules-tier only.** kNN and the LLM may only ever return a single
  destination account, and the corpus stays two-split-only. *Rationale:* multi-split
  transactions are ambiguous labels, and a model guessing split ratios inside a ledger is
  the confident wrongness the abstention design exists to prevent.
  *Source:* AGENTS.md §*Classification rules*; design proposal §*1. Rules*.
- **C7 — Never create accounts, and never create scheduled transactions
  programmatically.** *Rationale:* a chart of accounts encodes how someone thinks about
  their money and may map to tax categories an accountant specified; an auto-created
  account carries type, parent, placeholder flag and commodity, and an expense account
  typed as an asset does not error — it misreports forever. A wrong SX frequency or
  formula generates phantom transactions indefinitely and, for loans, creates a second
  source of truth. Guide to GnuCash's own assistants, verify the result, don't create.
  *Source:* AGENTS.md §*Hard rules*; design proposal §*Design principle: defer to
  GnuCash*, §*Amortising loans belong in Scheduled Transactions*.
- **C8 — Never set the reconciled flag from code.** *Rationale:* reconciliation is the
  independent human check on everything this tool does; removing it to make a number look
  right defeats the tool's only external audit. *Source:* AGENTS.md §*Hard rules*.
- **C9 — A refusal never blocks opening GnuCash.** Notify loudly, then open the app
  anyway; proposals stay pending. *Rationale:* books are not hostage to a classifier that
  lost confidence in itself. *Source:* AGENTS.md §*Hard rules*; design proposal
  §*Scenario 2 — production*.
- **C10 — `out_of_scope` rows are excluded from the review queue and from coverage and
  drift metrics.** *Rationale:* left in the queue they are permanent phantom work; left
  in the metrics they hold coverage permanently low, so the drift detector either
  misfires constantly or gets its threshold lowered until it stops catching real drift.
  *Source:* design proposal §*Handling out-of-scope rows*.
- **C11 — Corpus provenance is structural.** Every row is `observed` or `corrected`;
  index construction filters on provenance and synthetic rows cannot enter.
  *Rationale:* a synthetic neighbour makes a novel merchant look familiar, which destroys
  abstention, and it invalidates the backtest by measuring agreement with a model's
  guesses rather than with real decisions. *Source:* AGENTS.md §*Classification rules*;
  design proposal §*2. kNN*, §*Open questions*.
- **C12 — Normalisation lives in the pipeline, never in an ofxstatement plugin, and the
  normaliser version is part of the gate tuple.** *Rationale:* it is the component tuned
  most, so it must be changeable and re-backtestable in one place; and changing it changes
  what every vector means, so a plugin update can otherwise invalidate the index with no
  classifier code changing. *Source:* AGENTS.md §*Classification rules*; design proposal
  §*Normalisation*, §*Scenario 2 — production*.
- **C13 — Redaction happens at the model-adapter boundary, and transactions are never
  collected or committed.** The adapter sends normalised merchant token, amount and sign
  — never the raw memo or document content. The backend is local by default; a remote
  backend receives only tokens on a pack or the user allowlist (otherwise the LLM
  abstains) and accounts as numeric indices, never names. Shared artifacts
  carry patterns and categories only; counterparty IBANs are local-only, credentials live
  in the Secret Service. *Rationale:* normalised memos routinely still carry counterparty
  names, IBANs, creditor IDs, employer names, and Art. 9 special-category data. Merchant
  tokens are business names; that is the line. *Source:* AGENTS.md §*Privacy rules*;
  proposal 0001 §*Community contribution*, §*Model backend*.
- **C14 — The review file is parsed by ID, never by position, and the parser fails
  loudly.** An unknown ID is an error, not a guess; an unknown status char, unparseable
  account or amount mismatch aborts the whole batch with a line number and applies
  nothing, with accounts validated against the live CoA at parse time. *Rationale:*
  reordering or sorting must not misalign rows, and a typo must stop the run rather than
  create an Imbalance row. *Source:* AGENTS.md §*Review interface rules*; design proposal
  §*Review interface*.

- **C15 — Approval is the saved review file.** Nothing reaches the book that was not
  marked `a` in a review file the user saved, with the account, amount and date shown
  there. Only gate-passing rows are pre-marked; LLM rows never, until shadow mode has
  measured their precision. Unattended runs are deferred beyond v1. *Source:* AGENTS.md
  §*Review interface rules*, §*Classification rules*; proposal 0001 §*Review interface*.
- **C16 — A statement is the reference.** Lines and amounts come from the original file,
  parsed by its plugin — never from OCR text, an archive version or paperless metadata;
  admission is all-or-nothing per statement. *Source:* AGENTS.md §*Documents*; proposal
  0002 §2–3.
- **C17 — Documents feed rules only, and only when the link is confirmed.** kNN and the
  LLM never see document features; a bill feeds a rule only with a confirmed correspondent
  association (otherwise it is a weak hint in the review file). Rule precedence is the one
  table in proposal 0002 §5.1. *Source:* AGENTS.md §*Documents*, §*Classification rules*;
  proposal 0002 §4–5.
- **C18 — A link changes nothing else.** A document link changes no amount, date or
  account and creates no split; an existing GnuCash document link is never overwritten;
  the paperless stamp is never read back to decide anything. *Source:* AGENTS.md
  §*Documents*; proposal 0002 §5.3, §6.
- **C19 — Document content stays out of staging, logs and models.** Staging, logs and
  the model adapter hold document IDs, checksums, amounts and dates only — never content
  or correspondent names; downloaded originals and the review file live under
  `$XDG_RUNTIME_DIR`, mode 0600, removed in `finally`. *Source:* AGENTS.md §*Documents*,
  §*Privacy rules*; proposal 0002 §7.

## 6. Category → invariant mapping (the active layer) — **project-provided**

> **Scaffold.** When Plan classifies a brief into one of these categories, it MUST pull
> the invariant **and its citation** into the brief's `Invariant to restore` field
> (Principle 4.2). Fill this with the categories that have a **real shipped failure**
> behind them (§8) — keep it short; enforcement is rationed, not exhaustive.

**Deviation from §8, stated deliberately.** Autobook has shipped nothing and run no
cycles, so on a literal reading of §8 this table would be empty until a cycle shows a
miss. The five rows below are seeded anyway, on the rationale AGENTS.md gives for its own
hard rules: *"Every rule below that looks pedantic is there because the failure it
prevents is invisible."* Each row's violation produces a **wrong ledger rather than an
error** — so "wait for evidence of a miss" would mean waiting for a corrupted book, and
the evidence bar §8 protects against checklist growth is the wrong instrument here.
Nothing else is seeded; the rest of §5 stays reference-layer and graduates on evidence.

| Defect category | Invariant Plan must state | Cite |
|---|---|---|
| **Monetary representation** — any code path carrying an amount, including tests and fixtures | Amounts are exact: `GncNumeric(cents, 100)` from integer cents. No `float` (the `GncNumeric(float)` constructor converts silently), integer `cents` in rule files, no rounding that breaks the exact-sum property, the currency read from the account's commodity rather than assumed. | A1, B1 |
| **Book write / session lifecycle** — any mutation of a book | Every mutation is bracketed by `BeginEdit`/`CommitEdit`; one session per run, `SESSION_NORMAL_OPEN` for writes and never `SESSION_BREAK_LOCK`, `session.save()` then the assertions then `session.end()` in a `finally`, and a read-back before a row counts as applied; the applier never runs while the GUI holds the lock. | A2, B2, B3, B5, C2 |
| **Idempotency / double-booking** — apply paths, correlation, `match_existing` | One economic event is booked once — including transfers across batches and scheduled-transaction occurrences — and a batch is re-runnable after any crash and reversible by GUID plus proposal ID. | C2, C3 |
| **Document linking / matching** — any code path that admits a statement, pairs a bill with a row, or writes a document link | The statement is the reference; a link is used only when confirmed and unambiguous, changes nothing else, never overwrites, and carries no document content anywhere. | C16, C17, C18, C19 |
| **Classifier accuracy complaint** — "it mis-booked X" | Thresholds move on backtest evidence across the corpus, not on the reported transaction; both abstention gates must pass, and falling through is the correct outcome, not a failure to fix. | C4 |

**Why C1 is not here.** The pipeline/book-process import boundary is already a mechanical gate
(ruff `banned-api`). Per AGENTS.md's own rubric — *"when a defect class recurs, it
graduates to a gate and drops out of review scope"* — a gated class does not also need
Plan to restate it. Adding it would be the checklist growth §8 warns about.

The last row is the one that earns its place on §3 grounds rather than corruption: a
brief reading *"fix the misclassification of X"* invites Do to widen a threshold, which is
precisely the symptom-guard-instead-of-cause fork this document exists to prevent, and it
is the single most likely brief Autobook will receive once the backtest harness lands.

Everything not in this table stays reference-layer (§5); promote a category here only on
evidence (§8).

---

## 7. Provenance honesty rules (keep the catalogue citable)

- **Cite for what the source says, not an inflated ruling.** If a source documents a
  hazard while adding a feature, it does not necessarily *forbid* the thing — cite the
  standing rule for the prohibition and the newer source as corroboration.
- **Check a standard's status and target version.** Draft/Rejected ranks below
  Final/Accepted; a rule accepted for a runtime version you do not yet ship is
  corroborating, not yet enforceable. Note status and version beside each citation.
- **Authoritative vs illustrative.** Official specs and vendor docs are authoritative;
  blog posts and war-stories are illustrative — tag them so, and cite the rule from the
  page that actually *states* it, not a tutorial that only demonstrates it.
- **Pin the version you target; note where a newer major differs.**
- **Internal invariants don't borrow external authority** — state the rationale.

## 8. Evidence basis & promotion rule

Promote a principle from reference to active (or to a hard gate) only on evidence — the
same bar the act-log applies to process deltas:

- **Active / template-asked:** the symptom-vs-cause fork **recurs** in a category (a
  real failure plus repeated decision-points across cycles). One war-story is enough to
  document a principle in §5; a recurring miss is what graduates it to §6.
- **Hard gate:** reserve for a category with a **real shipped failure**. Everything else
  stays reference until a cycle shows it was missed.

Resist a growing checklist. The discipline that keeps minimalism valuable is the same
one that keeps this set small: knowledge is documented freely (§5); enforcement is
rationed (§6).
