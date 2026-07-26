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
> **Current stage.** Autobook is *design-stage*: proposal 0001 exists, no
> implementation does. Several rows below are therefore honestly `[planned]` rather
> than filled with plausible-looking guesses — the first cycles run build order
> steps 0–2, and the fixture/repro machinery cannot be specified before there is
> code to reproduce against. Fill each row when the cycle that needs it arrives.

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
  machine, no milestones yet.
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
- **Reproduction runner(s) + commands:** `[planned]` — no implementation to
  reproduce against yet. Expect `pytest` selecting the bundle's named test.
- **Verification runner (test suite):** `./engine/nox.sh gate` (delegates to
  `nox -s gate` in the target tree). Wired as `C4-ci`, below.
- **Platform variants:** none. Linux-first by design (proposal 0001, *Platform
  support*); macOS is unverified and Windows is deferred as a stated restriction.
- **What counts as a successful repro:** `[planned]` — exit code from `pytest` once
  there is code. The red→green discriminator is deliberately unwired; see §4.

**Not reachable as a gate: `nox -s applier`.** It needs the system
`python3-gnucash` and, by Autobook's own rules, runs against a *restored copy* of a
book, never unattended. The driver must never be able to invoke a session that can
write to a book. `engine/nox.sh` documents this at the point of delegation.

## 4. Conformance ruleset (answers the validation-tooling matrix for this repo)
For each tier: the **written ruleset** it consumes, its **home**, and the
**single-sourced command** the driver and CI both run. A gate you can trace to a
written source is auditable; one you can't is folklore.

Gating policy (see `engine/README.md`): ship every tier **advisory**
(`gating = false`) except the per-fix C4 (red→green).

| Tier | Written ruleset | Home | Single-sourced command | Status |
|---|---|---|---|---|
| T1 structure | `ruff` config (`pyproject.toml [tool.ruff]`) | `../autobook` | `./engine/nox.sh gate` (fmt, lint) | [built — folded into C4-ci] |
| T2 shape | `mypy --strict`; the `gnucash` import ban (`flake8-tidy-imports.banned-api`) | `../autobook` | `./engine/nox.sh gate` (types, lint) | [built — folded into C4-ci] |
| T3 runtime | `pytest` suite | `../autobook` | `./engine/nox.sh gate` (test) | [built — folded into C4-ci] |
| T4 contribution | `AGENTS.md` (Publishing defaults); `dco` + `require-issue` workflows | host CI | host-side; `pdca-autobook contribcheck` for the bundle's own artifacts | [built — host-gated] |
| T5 judgment | reviewer contract below + `AGENTS.md` review rubric | Check reviewer + sign-off | (model) | [built — contract] |

**Why one gate row rather than five.** Autobook single-sources every deterministic
check in `noxfile.py`, and `nox -s gate` runs all of them. Splitting that back into
per-tier PDCA rows would re-declare gates PDCA does not own — exactly what
delegation exists to avoid. The tier column above records *which written ruleset
answers which tier*, which is the auditable part; the command is one.

**The per-fix C4 (`C4-verify`) is deliberately NOT wired.** It proves a patch's test
is red without the fix and green with it. Autobook has no implementation, so there
is no production change to revert to establish red, and every bundle would false-fail
C4. `engine/scripts/run-verify.sh` ships as the template's skeleton; wire it when
build order step 2 lands real code, and give it a dedicated `../autobook-verify`
worktree scoped by `$PDCA_LANE`, as wyrd-pdca does.

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
    idempotency via `num`) are not review-negotiable, and a change touching them
    needs a human even when every gate is green — their failure mode is a silently
    wrong ledger, not a red test.
  - **Any threshold or confidence-gate change.** These move on backtest evidence
    across the corpus, never on a single misclassification. A model cannot judge
    "is this evidence enough" from the diff.
  - **Anything altering what leaves the machine** — the redaction boundary, the
    model adapter, credential handling, or the content of a shareable rule pack.
  - **Adding or changing a scope exclusion** (securities, cross-currency splits),
    or reopening a row in proposal 0001's *Rejected alternatives* table.
  - **Any test fixture that could plausibly derive from real statement data.**

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
    there.
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
| Repro / verification runners | `engine/scripts/run-verify.sh` | (unwired) | [planned — needs code to verify] |
| Driver | `src/pdca_harness/` | `pdca-autobook run <id>` | [built — stub leaves] |
| Act tooling (L4) | `src/pdca_harness/act.py` | `pdca-autobook act index`, `pdca-autobook act log --date <d>` | [built] |
| Gates (single-sourced) | `pdca.toml` `[[gates.checks]]` | `pdca-autobook gates [<id>] [--working-tree]` | [built — C4-ci wired] |
| Reviewer role prompt | `agents/reviewer.md` (canonical body; inlined for codex) | (model leaf) | [built — contract; wire command mode] |
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

`ship_ci_workflow = false` at render time, because Autobook runs its own CI;
`ship_merge_guard = true`, because nothing host-side stops a model leaf from
marking a PR ready.

## 11. Per-repo P-/D-/C-/A- extensions
None today. Add repo-prefixed rules (e.g. `autobook-pdca-C7`) that *tighten
or add to* a generic rule — never weaken one — as running cycles surface them.

A likely first candidate, once code exists: a C-rule requiring that any bundle
touching classification reports **backtest numbers per method and per confidence
band** in `SUMMARY.md`, since "seems better" is not a verdict this project accepts.
