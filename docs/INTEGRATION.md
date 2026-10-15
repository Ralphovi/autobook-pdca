# Repository integration — Autobook PDCA

> What Autobook PDCA provides to plug into the generic PDCA cycle (see
> [quality-cycle.md](../PCDA/quality-cycle.md)). This is the project's answer to the
> "which / where / how" questions the generic model deliberately leaves open.
> It does **not** restate the cycle. Conflict rule: generic wins on cycle
> *shape*; this integration wins on *instantiation*.
>
> **Host repo:** Autobook, the Python project at the sibling checkout `../autobook`
> (`https://github.com/Ralphovi/autobook`). This PDCA project is **out-of-tree** — it
> wraps Autobook's `nox` gates and adds the Act beat; it never modifies Autobook's
> tree. Autobook's normative process lives in its `AGENTS.md`, its ADRs
> (`../autobook/docs/design/adr/`), and `CONTRIBUTING.md`; those are the sources
> cited below.
> Maintained by Act (append changes; don't silently rewrite).
>
> **Current stage.** Autobook is *design-stage*: proposal 0001 as amended by proposal
> 0002, and the architecture description (`../autobook/docs/design/architecture/`,
> ch.1–14), exist; no implementation does. The **execution order** is architecture
> ch.9, and the tracker follows it as GitHub milestones `01 · 0 + D0` … `13 · 9`, one
> issue per PDCA cycle. The first cycle is the package skeleton (Ralphovi/autobook#22).
> Several rows below are honestly `[planned]` rather than filled with
> plausible-looking guesses; fill each when the cycle that needs it arrives.
>
> **Naming.** The **book process** is the only process that links libgnucash: the
> **exporter** (read-only, from build step 2) and the **applier** (writes, from step
> 5). The nox session and pytest marker for its tests keep the name `applier`.

## 1. Tracker integration
- **System / URL:** GitHub Issues — https://github.com/Ralphovi/autobook/issues.
  Already gated host-side: Autobook's `require-issue` workflow rejects a PR with no
  linked real issue, so PDCA's "init from brief" maps onto an issue that already
  satisfies that rule.
- **Issue-ID format:** `#123` (GitHub integer; bare `#123` in commit/PR text).
- **Cross-link form (commit/PR → tracker):** `Fixes #nnnn` (GitHub auto-close) —
  `[tracker].issue_trailer = "Fixes #{id}"` in `pdca.toml`. A ticketless work item
  uses `pdca-autobook publish --no-issue` (omits the trailer; records the bundle
  `id_pending`).
- **Status → disposition mapping:** GitHub `open` → fixable at Plan; `closed` set on
  merge at Check. Labels (`bug`, `enhancement`) carry the rest; no custom state
  machine. **Milestones** follow architecture ch.9's execution order; the planner
  takes an issue's `Depends on:` line as its prerequisites.
- **Book-process and paperless tests run in Autobook's test environment.** When a
  bundle's tests use the `applier` or `live_paperless` marker, C4-verify starts the
  worktree's `testenv/` (GnuCash 5.14 bindings, PostgreSQL, paperless-ngx 3.3.0;
  synthetic data only, no outbound network; one compose project per lane,
  `autobook-pdca-l<lane>`) and runs them there for both legs, so those cycles get a
  real red→green. Without Docker or `testenv/` they do not run and the bundle is
  unverifiable. Stacks stay up between cycles for speed; `docker compose ls` lists
  them and `docker compose -p autobook-pdca-l<lane> down -v` removes one.
  **Real data never enters PDCA:** the backtest on the user's history, the D1/D2
  validation runs and anything that opens a real book stay human-run, outside the
  cycle (the `human-run` label marks the issues whose milestone closes on such a run).
- **Per-release field updated on a fix:** none. Autobook is pre-release and has no
  version field to maintain; the closed-by-PR link records the fix. Revisit at the
  first tagged release.
- **Comment voice / template:** `templates/tracker-comment.md.tpl`. No tracker
  scraper is needed — GitHub issues are read with `gh issue view <id>`.

## 2. Branch-target rules
- **Target checkout:** the sibling **`../autobook`** checkout — but a cycle's
  Do/Check never mutate it directly. With `[driver].worktree` on (the default) the
  driver runs Do/Check in a **per-cycle git worktree** off the target's base
  (`origin/main`), reset clean before each Do and exposed to the builder and gate
  commands as **`$PDCA_WORKTREE`**. `engine/nox.sh` runs `nox -s gate` in
  `$PDCA_WORKTREE` (falling back to `$AUTOBOOK_REPO`, then `../autobook`), so the
  gate tests the SAME tree the builder edited and the human's checkout is never
  touched.
- **Per-area branch map:** everything targets **`main`** directly. Autobook has no
  maintenance branches and no release line — don't invent one. If a multi-step
  milestone later needs stacking, add an integration branch here and record it, the
  way wyrd-pdca documents its M4 pattern.
- **Cross-version cherry-pick rules:** none. Single branch, no supported older line.
- **Master-vs-maintenance rule:** not applicable (`contribution_model = "own-repo"`;
  Autobook *is* the target, there is no fork and no upstream line).
- **Override convention:** a maintainer's explicit base-branch request on the PR
  wins; otherwise `main`.

## 3. Reproduction fixtures and runners
- **Canonical fixture path:** `../autobook/tests/` — and, for anything
  statement-shaped, **`../autobook/tests/fixtures/synthetic/`** specifically.
  Autobook's `.gitignore` blocks statement and book file types repo-wide and
  un-ignores only that path, so a fixture landing anywhere else is a mistake the
  repo will resist.
- **Fixtures are synthetic, always.** Never build a repro from a real statement,
  even normalised: bank memos carry counterparty names, IBANs, creditor IDs,
  employer names, and Art. 9 special-category data. A bundle whose repro needs real
  data is a bundle that needs a redesigned repro. This is a hard rule from
  Autobook's `AGENTS.md`, not a preference.
- **Reproduction runner(s) + commands:** `./engine/scripts/run-verify.sh` — `pytest`
  on the bundle's named test files with the worktree's `src/` on `PYTHONPATH` and
  `-m "not applier"`. Wired as `C4-verify`, below.
- **Verification runner (test suite):** `./engine/nox.sh gate` (delegates to
  `nox -s gate` in the target tree). Wired as `C4-ci`, below.
- **Platform variants:** none. Linux-first by design (proposal 0001, *Platform
  support*); macOS is unverified and Windows is deferred as a stated restriction.
- **What counts as a successful repro:** pytest's exit code **and** at least one test
  actually run, read from its JUnit report: red with the production hunks reverted,
  green with them applied. A leg in which no test ran is unverifiable, never a pass;
  see §4.

**Not reachable as a gate: `nox -s applier`.** It needs the system
`python3-gnucash` and, by Autobook's own rules, runs against a *restored copy* of a
book, never unattended. The driver must never be able to invoke a session that can
write to a book. `engine/nox.sh` documents this at the point of delegation.

## 4. Conformance ruleset (answers the validation-tooling matrix for this repo)
For each tier: the **written ruleset** it consumes, its **home**, and the
**single-sourced command** the driver and CI both run. A gate you can trace to a
written source is auditable; one you can't is folklore.

Gating policy (see `engine/README.md`): C4-ci (Autobook's own gate), C4-verify
(red→green) and T4-contribution gate; the T2 threat-model touch check is advisory.

| Tier | Written ruleset | Home | Single-sourced command | Status |
|---|---|---|---|---|
| T1 structure | `ruff` config (`pyproject.toml [tool.ruff]`) | `../autobook` | `./engine/nox.sh gate` (fmt, lint) | [built — folded into C4-ci] |
| T2 shape | `mypy --strict`; the `gnucash` import ban (`flake8-tidy-imports.banned-api`) | `../autobook` | `./engine/nox.sh gate` (types, lint) | [built — folded into C4-ci] |
| T2 threat model | `../autobook/.oss-scanner/threat_model.md` (Ralphovi/autobook#18) | this repo | `./engine/scripts/check-threat-model-touch.sh` | [built — advisory, `T2-threat-model`] |
| T3 runtime | `pytest` suite | `../autobook` | `./engine/nox.sh gate` (test) | [built — folded into C4-ci] |
| T4 contribution | `AGENTS.md` (Publishing defaults); `dco` + `require-issue` workflows | host CI | host-side; `./scripts/pdca contribcheck` for the bundle's own artifacts | [built — `T4-contribution`] |
| T5 judgment | reviewer contract below + `AGENTS.md` review rubric | Check reviewer + sign-off | (model) | [built — contract] |

**Why one gate row rather than five.** Autobook single-sources every deterministic
check in `noxfile.py`, and `nox -s gate` runs all of them. Splitting that back into
per-tier PDCA rows would re-declare gates PDCA does not own — exactly what
delegation exists to avoid. The tier column above records *which written ruleset
answers which tier*, which is the auditable part; the command is one.

**The per-fix C4 (`C4-verify`) is wired** (autobook-pdca#3, ported from nl-shell-pdca).
It proves a patch's test is red without the fix and green with it. It was first left
unwired because Autobook has no implementation, so most early bundles add new modules
and have nothing to revert to. This version handles that case: when the reverted test
can't even import, it reports **unverifiable** (§6, non-gating) instead of failing,
and the human decides at sign-off. It runs in the driver's per-cycle worktree
(`$PDCA_WORKTREE`), never in `../autobook`. Applier tests are deselected, so a bundle
whose only test is an applier test is unverifiable too: `nox -s applier` stays a
human-run step.

**Advisory reviewers.** Every bundle gets the `adversary` and the `security-review`
leaf (Check), and every brief gets the `plan-reviewer` (Plan), none gated by a
self-reported difficulty field. `security-review` grades the patch against
`../autobook/.oss-scanner/threat_model.md`.

- **Reviewer family (cross-vendor, ≠ builder):** codex — canonical role body
  `agents/reviewer.md`, inlined for a codex reviewer. `AGENTS.md` carries general
  codex **project context** (STOP discipline, boundaries), not the reviewer role.
- **Builder family:** claude — canonical role body `agents/builder.md`; the Claude
  wrapper `.claude/agents/builder.md` (with the ready-mark block enforced by the
  `.claude/hooks/builder_guard.py` PreToolUse hook).
- **Interactive family:** claude — Plan, Sign-off, Publish and Act run a seeded
  `claude --agent <name>` REPL.
- **Role prompts (vendor-neutral source):** each leaf's instructions live once in
  `agents/<name>.md`; Claude leaves also get `.claude/agents/<name>.md`.
- **Vendor profiles:** family-specific behaviour is data in `pdca_harness.families`,
  overridable via `pdca.toml [families.<name>]`.
- **Project-defined human-only items** (reviewer emits NEEDS-HUMAN by design):
  - **Anything that writes to a book, or changes how something is written.** The
    hard rules in Autobook's `AGENTS.md` (session mode, integer-cent money,
    reconciled flag, account creation, exact split sums, engine-API assertions,
    `session.save()` and read-back, proposal IDs in `num` only on created
    transactions, never `create` on a scheduled-transaction occurrence) are not
    review-negotiable, and a change touching them
    needs a human even when every gate is green — their failure mode is a silently
    wrong ledger, not a red test.
  - **Any threshold or confidence-gate change.** These move on backtest evidence
    across the corpus, never on a single misclassification. A model cannot judge
    "is this evidence enough" from the diff.
  - **Anything altering what leaves the machine** — the redaction boundary, the
    model adapter, credential handling, or the content of a shareable rule pack.
  - **Adding or changing a scope exclusion** (securities, cross-currency splits),
    or reopening a row in proposal 0001's *Rejected alternatives* table.
  - **Any test fixture that could plausibly derive from real statement data**, a real
    document, a correspondent name or a paperless export.
  - **Anything that writes to paperless** (stamp, tag, custom field), and any change to
    which paperless representation is read (original vs archive/content, version
    pinning) or to statement admission (balance check, checksum, overlap rule).
  - **Any change to bill-match conditions** (exact amount, date window, correspondent
    constraint, one-to-one rule, weak matches) or to a document-keyed rule's `auto`
    default or tier-2 qualification.
  - **Any change to approval or pre-marking** — what is pre-marked `a`, the LLM
    pre-marking rule, or anything that would apply a row not in a saved review file.

## 5. Upstream-isn't-ahead routine
- **What "upstream" is:** not applicable in the fork sense —
  `contribution_model = "own-repo"`; Autobook is the target and has no upstream.
- **Two genuine upstreams to check before building**, both from proposal 0001's
  *Parallel track*:
  - **GnuCash** (`https://github.com/Gnucash/gnucash`, Bugzilla at
    `https://bugs.gnucash.org/`) — before implementing anything that looks like a
    GnuCash feature, confirm GnuCash does not already ship it. The *defer to
    GnuCash* design principle makes this a standing check, not a courtesy: if
    GnuCash does it, the correct output is a handoff, not an implementation.
    Bugzilla has required a login even to *view* bugs since Sept 2025 and is no
    longer search-indexed; mailing list archives still are (`site:lists.gnucash.org`).
  - **The ofxstatement plugins** (`Ralphovi/ofxstatement-{consorsbank,revolut,scalable}`)
    — a parsing defect belongs there, not here. Normalisation belongs here, not
    there. Whether they parse PDF statements is open until the D0 spikes (#3).
  - **paperless-ngx 3.x** (`https://github.com/paperless-ngx/paperless-ngx`, REST API
    and permission model) — check the API and its docs before relying on a field or
    behaviour; duplicates are accepted by default, `/metadata/` follows the newest
    document version unless `?version=` is pinned, and document history records an
    actor (AI workflows as `System`).
- **Search routine + tokenization gotchas:** search GnuCash by *feature name*
  (assistant, matcher, scheduled transaction) rather than by symbol; the C++/Scheme
  split means a symbol search misses whole subsystems.
- **Merged-history check command:** `gh search issues --repo Ralphovi/autobook <terms>`
  and `git -C ../autobook log --oneline --grep=<term>`.

## 6. Brief and design-proposal templates
- **Brief template:** `templates/brief.md.tpl`
- **Design-proposal template:** `templates/design-proposal.md.tpl` — the Plan
  artifact for the exception (major architecture / data-model / UX change).
- **Required project-specific frontmatter/sections:** a brief whose change is
  architectural must land as a **proposal in Autobook's own
  `docs/design/proposals/draft/`**, in Autobook's format (`docs/design/templates/proposal.md`),
  not only as a PDCA design-proposal artifact. Autobook's design docs are its
  normative record; a PDCA artifact is a working file. A settled *decision* becomes
  an ADR there, and accepted docs of both classes are immutable — supersede, never
  rewrite.

## 7. Bundle and act-log paths
- **Bundle root + ID format:** `results/issue_<id>/`
- **Act log path:** `process/act-log.md`
- **Iterate archive:** a rejected attempt is preserved in `iteration-v<N>/` in the
  bundle (the brief is archived with it on iterate-to-Plan) — fixed by the harness

## 8. Committing and PR conventions
- **Commit-message format:** conventional-commit subject (`fix:`, `feat:`, `docs:`,
  `chore:`), imperative mood, body wrapped at 79. **Every commit carries a
  `Signed-off-by:` trailer** (`git commit -s`) plus the `Fixes #nnnn` tracker
  trailer. Sign-off is mandatory on docs-only commits too.
- **PR description format:** see `templates/pr-description.md.tpl` (Root cause / Fix
  / Verified against / Test), opening with a `**User impact:**` line.
- **Enforcement mechanism:** host-side PR CI — Autobook's `dco` workflow checks
  every commit's trailer and `require-issue` checks the linked issue. Both are
  authoritative; PDCA does not duplicate them. **The `dco` status check is the sole
  authority on sign-off** — do not report `Signed-off-by` findings from your own
  commit inspection, since the SHAs a review context exposes are often GitHub's
  synthesized merge-preview commits.

## 9. Repo-specific scripts and tooling
| Role | Path | Invocation | Status |
|---|---|---|---|
| Gate delegation wrapper | `engine/nox.sh` | `./engine/nox.sh gate` | [built] |
| Tracker scrape / handoff generator | none | `gh issue view <id>` | [not needed] |
| Conformance gate runners | `../autobook/noxfile.py` | `./engine/nox.sh gate` | [built — host-owned] |
| Repro / verification runners | `engine/scripts/run-verify.sh` (+ `lib/junit_count.py`) | `C4-verify` | [built] |
| Threat-model touch check | `engine/scripts/check-threat-model-touch.sh` | `T2-threat-model` | [built — advisory] |
| Target dependency install | `engine/scripts/install-target-deps.sh` | `[install].extra_bootstrap` (`make install`) | [built] |
| CLI resolver for gate rows | `scripts/pdca` | `./scripts/pdca contribcheck` | [built] |
| Driver | `src/pdca_harness/` | `pdca-autobook run <id>` | [built — live leaves] |
| Act tooling (L4) | `src/pdca_harness/act.py` | `pdca-autobook act index`, `pdca-autobook act log --date <d>` | [built] |
| Gates (single-sourced) | `pdca.toml` `[[gates.checks]]` | `pdca-autobook gates [<id>] [--working-tree]` | [built — C4-ci, C4-verify, T4, T2] |
| Reviewer role prompt | `agents/reviewer.md` (canonical body; inlined for codex) | (model leaf) | [built — command mode] |
| Security-review role prompt | `agents/security-review.md`; `.claude/agents/security-review.md` | (advisory leaf) | [built — always on] |
| Builder role prompt | `agents/builder.md`; `.claude/agents/builder.md` + `.claude/hooks/builder_guard.py` | (model leaf) | [built — ready-mark blocked] |

## 10. Maintainer and governance
- **Who reviews:** Eduard Ralph (sole maintainer).
- **Ready-mark gate:** the human, at sign-off. The driver opens a **draft** PR and
  never marks it ready or merges; `builder_guard.py` blocks `gh pr ready` /
  `gh pr merge` for the model leaves as a backstop.
- **External-contribution flow differences:** an outside PR follows Autobook's
  `CONTRIBUTING.md` (fork, linked issue, DCO) and does **not** enter the PDCA cycle.
  PDCA drives the maintainer's own work; it is not a review queue for contributors.
- **MAINTAINERS file:** none — single maintainer, recorded here.

### Composing with the host's CI / PR governance (issue #67)

PDCA **supplements** Autobook's PR governance; it does not replace it.

| Host gate (governance layer) | PDCA equivalent (supplement) | How they compose |
|---|---|---|
| `require-issue` on PRs | `[tracker].issue_trailer` (`Fixes #{id}`) in the publish commit/PR | The trailer satisfies the host's linked-issue rule. |
| `dco` workflow; ready-mark policy | builder/publisher STOP-discipline (`builder_guard.py` PreToolUse hook) | The hook is a *backstop*; the host workflow is the authority. |
| `ci` (`nox -s gate`) | `./engine/nox.sh gate` via `C4-ci` | Both run the *same* command — one definition, in `../autobook/noxfile.py`. |

`ship_ci_workflow = true` (autobook-pdca#3): `.github/workflows/check-gates.yml` runs
`pdca-autobook gates --working-tree` on this repo's PRs. Its only repo-scoped row is
C4-ci, which reports unverifiable there because CI has no Autobook checkout; Autobook's
own CI runs that gate on Autobook's PRs. `.github/workflows/require-linked-issue.yml`
holds this repo's PRs to the same linked-issue rule as Autobook's.
`ship_merge_guard = true`, because nothing host-side stops a model leaf from
marking a PR ready.

## 11. Per-repo P-/D-/C-/A- extensions
None today. Add repo-prefixed rules (e.g. `autobook-pdca-C7`) that *tighten
or add to* a generic rule — never weaken one — as running cycles surface them.

A likely first candidate, once code exists: a C-rule requiring that any bundle
touching classification reports **rolling-origin backtest numbers per method and per
confidence band, novel-memo stratum included**, and any bundle touching the bill
matcher reports **linkage numbers** (link rate, ambiguity rate), in `SUMMARY.md` —
"seems better" is not a verdict this project accepts.

## Answering an interactive leaf from another device

**Enabled here** on all five interactive leaves (planner, sign-off, publisher, Act,
splitter), as in nl-shell-pdca.

The four `interactive = true` leaves — planner, sign-off, publisher, Act — hand the terminal
to a human+model REPL and block there. That means the human has to be at the terminal the
flow runs in, for the whole batch: a `pdca-autobook flow` over several bundles can park on one
sign-off adjudication for hours because nobody is at that machine.

Claude Code's `--remote-control` flag removes the constraint. Add it to an interactive
leaf's `argv` in `pdca.toml` — anywhere but last: the driver appends the seed prompt as a
positional after the argv, and `--remote-control` takes an optional `[name]` value, so as
the final token it would swallow the whole seed as the RC session name (issue #396; the
claude-family spawn also inserts `--` before the seed as a backstop, but no flag with an
optional value should ever sit last). With the flag in place that leaf becomes answerable
from another enrolled device; nothing else changes — `signoff-decision`, the §6 ticks and
the C6 accept-guard all run the same code path, and only the human's location differs.

Enabling Remote Control in your own shell does **not** reach the leaves: each is a separate
`claude` subprocess whose argv comes from `pdca.toml`. That is the whole reason this needs
documenting.

The headless builder and reviewer must not carry the flag — it starts an *interactive*
session, and they have no human to reach.
