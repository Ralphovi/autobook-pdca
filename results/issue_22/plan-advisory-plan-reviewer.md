Bash was unavailable in this run (the sandbox failed with `apply-seccomp: … Permission denied`). This review used only Read, Grep and Glob against `$PDCA_TARGET`.

# Plan review — issue 22 / package-skeleton-contracts-fixtures

I tried to fault the root cause, the success criterion, the scope and the target, and found no fatal fault in any of them:

- **Root cause and criterion.** The C4-verify argument holds. `src/autobook/` holds only `__init__.py`. Criterion (a)–(c) can be checked with a red→green test, and the rule to import inside the test body is the correct fix for the collection-error trap.
- **Scope.** The scope matches the issue body, less two items that the brief accounts for:
  - The `live_paperless` marker is already on main (`pyproject.toml:109`, `noxfile.py:84`).
  - The XML book was dropped.
- **Target.** `@ main` with `Depends on: none` matches the issue ("**Depends on:** none").

The findings below are smaller faults that the planner can fix by revising the brief.

- NEEDS-HUMAN — **The maintainer decisions the brief relies on are not in the tracker record.** The brief says "Dropped by the maintainer at Plan" for the XML book, and "the maintainer approved these names at Plan" for `autobook.contracts` / `.pipeline` / `.book`. `notes.json` has only one comment, about the account separator. It says nothing about dropping the XML book or about package names. The issue body still lists "A tiny hand-written synthetic XML book … for book-process tests" in scope. If this is not confirmed, Check could flag the cycle as missing an in-scope item. Either confirm both decisions on the issue thread, or cite where they were recorded.

- NEEDS-HUMAN — **Where `*.pdf` goes in `.gitignore` is not specified, and the obvious place breaks the synthetic exception.** `.gitignore:53-54` ends with `!tests/fixtures/synthetic/` and `!tests/fixtures/synthetic/**`. In gitignore the last matching pattern wins. If `*.pdf` is appended at the end of the file, as scope item (4) suggests, it re-ignores every synthetic PDF fixture (#23–#26 and proposal 0002 will need document fixtures). The brief should say to add it to the "Never commit financial data" block (`.gitignore:26-43`), before the un-ignore lines.

- NEEDS-HUMAN — **`tests/test_skeleton.py` cannot find each module's entry point.** The brief says "Entry-point names and signatures are Do's choice". Rule 2 then forbids naming the modules and requires `pkgutil` discovery. Discovery alone does not tell the test which attribute to call, so the assertion "exposes its entry point, and the entry point raises `NotImplementedError`" is not defined. Fix one convention in the brief: a shared function name, or a module-level marker naming the entry point. Otherwise the test may check nothing per module, or Do will pick a convention that #23–#26 then have to discover. Signatures stay free, so calling the entry point with no arguments is also undefined. Either require no required parameters, or say to assert only that it is callable.

- NEEDS-HUMAN — **The `gnucash not in sys.modules` assertion depends on which host runs it.** The Falsifiability line runs C4-verify as "host pytest in `$PDCA_WORKTREE`" with `-m "not applier …"`. A `-m` filter deselects tests after collection, but every module is still imported. `tests/book/test_testenv_book.py:20` runs `pytest.importorskip("gnucash")` at module scope and is collected before `tests/test_*.py`. On a host with system `python3-gnucash` visible, `gnucash` is already in `sys.modules`, so the new skeleton test fails on both legs. The criterion's test file is `test_contracts.py`, so this does not block red→green. It can still make `test_skeleton.py` red after the patch on such a host. The existing `tests/test_smoke.py:28` has the same exposure, so this is inherited. The brief should either confirm the C4 host has no `gnucash` importable, or make the skeleton test check a fresh subprocess or a `sys.modules` diff instead.

- NEEDS-HUMAN — **One rejection rule in the corpus contract is still open.** `amount_cents` is "non-negative int", so zero passes parse. ch.5 §5.1 lists `sign` as a separate field, so a zero-amount row has an ambiguous direction. Either state that zero is allowed (and which `sign` it takes), or make it positive like `fraction`. As written, Do decides a contract rule that the brief says it fixes so Do does not re-decide it.

- NEEDS-HUMAN — **(Minor) The staging store's placement goes unremarked.** The brief places `staging` in `autobook/pipeline/`, giving the count of 12 pipeline modules. ch.5 §5.1 (`05-building-block-view.md:22`) lists the **Staging store** as its own top-level block, next to Pipeline, Book process and Launcher, not as a pipeline component. That is defensible, because only the pipeline touches it. But the brief also has Do replace the ch.5 `[OPEN]` naming note, so the docs update will make this placement official. Note it as a deliberate choice in "Alternatives considered", so the reviewer does not read it as a drift from ch.5.

> **pdca:** Bash was unavailable to this reviewer. The vendor sandbox could not start on this host, so every Bash call it made failed before running (`apply-seccomp: write /proc/self/setgroups (nested userns is capability-restricted; caller must provide CAP_SYS_ADMIN): Permission denied`) and it ran no commands; this review was delivered without Bash.

<!-- pdca:leaf-complete -->
