#!/usr/bin/env bash
# Delegate a PDCA gate to Autobook's single-sourced gate runner, `nox`.
#
# PDCA runs gate commands from THIS project's root (`pdca_harness.gates` uses
# `cwd=cfg.root`), but `nox` must run inside the Autobook checkout. This wrapper is
# the one place that knows where that checkout is: it `cd`s there and execs
# `nox -s "$@"`. It re-declares NO gates — Autobook's noxfile.py owns every gate
# definition; PDCA only orchestrates this runner
# (`[gates] runner = "./engine/nox.sh"`, subcmd = "gate").
#
# Where it runs, in priority order:
#   1. $PDCA_WORKTREE — the per-cycle git worktree the driver creates for Do/Check
#      when worktree isolation is on ([driver].worktree). The gate MUST test the
#      SAME tree the builder edited, so this wins.
#   2. $AUTOBOOK_REPO — explicit override for a bespoke setup.
#   3. ../autobook — the sibling primary checkout (isolation off, or a
#      --working-tree run).
# A cycle never mutates the human's checkout: with isolation on, (1) is a
# throwaway worktree; only an explicit isolation-off run touches ../autobook.
#
# NOTE ON THE APPLIER: `nox -s applier` is deliberately NOT reachable as a gate.
# It needs the system python3-gnucash and, by Autobook's own rules, is run
# against a restored copy of a book — never unattended, never by a driver. A gate
# that could write to a book is not a gate.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
autobook_repo="${PDCA_WORKTREE:-"${AUTOBOOK_REPO:-"$(cd "$here/../../autobook" 2>/dev/null && pwd || true)"}"}"

if [[ -z "$autobook_repo" || ! -f "$autobook_repo/noxfile.py" ]]; then
  echo "nox.sh: Autobook checkout not found (looked for a noxfile.py at '${autobook_repo:-<unset>}')." >&2
  echo "        Expected \$PDCA_WORKTREE (set by the driver), \$AUTOBOOK_REPO, or a sibling ../autobook." >&2
  exit 2
fi

if ! command -v nox >/dev/null 2>&1; then
  echo "nox.sh: \`nox\` is not on PATH. Install it with \`pipx install nox\`." >&2
  echo "        PDCA delegates every Autobook gate to it; there is no fallback." >&2
  exit 2
fi

cd "$autobook_repo"
exec nox -s "$@"
