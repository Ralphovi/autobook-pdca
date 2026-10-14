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
  # CI (.github/workflows/check-gates.yml) checks out only this repo, so there is no
  # Autobook tree to gate. Say so instead of failing: Autobook's own CI runs this gate on
  # every Autobook PR. Locally a missing checkout is a setup error and stays one.
  if [[ -n "${CI:-}" ]]; then
    echo "PDCA-UNVERIFIABLE: no Autobook checkout in CI — nox -s $* runs in Autobook's own CI"
    exit 77
  fi
  echo "nox.sh: Autobook checkout not found (looked for a noxfile.py at '${autobook_repo:-<unset>}')." >&2
  echo "        Expected \$PDCA_WORKTREE (set by the driver), \$AUTOBOOK_REPO, or a sibling ../autobook." >&2
  exit 2
fi

# nox on PATH wins; otherwise the instance venv's (make install puts it there through
# [install].extra_bootstrap = engine/scripts/install-target-deps.sh).
nox_bin="$(command -v nox || true)"
if [[ -z "$nox_bin" && -x "$here/../.venv/bin/nox" ]]; then
  nox_bin="$here/../.venv/bin/nox"
fi
if [[ -z "$nox_bin" ]]; then
  echo "nox.sh: \`nox\` is not on PATH and not in .venv. Run \`make install\`." >&2
  echo "        PDCA delegates every Autobook gate to it; there is no fallback." >&2
  exit 2
fi

cd "$autobook_repo"
exec "$nox_bin" -s "$@"
