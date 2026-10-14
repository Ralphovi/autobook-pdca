#!/usr/bin/env bash
# Advisory T2 check: a patch that touches Autobook's security-relevant code or contracts
# should also update .oss-scanner/threat_model.md (the threat model's own rule, and the
# rubric the security-review leaf rates against). Not gating: a change can be security-
# relevant by path without changing the threat model. When the rule isn't met, report
# PDCA-UNVERIFIABLE (exit 77) so it lands in SUMMARY §6 for the human to judge.
set -euo pipefail

BUNDLE="${PDCA_BUNDLE:?run from the driver — \$PDCA_BUNDLE must be set}"
PATCH="$BUNDLE/patch.diff"
[ -s "$PATCH" ] || { echo "PDCA-EVIDENCE: no patch.diff, nothing to check"; exit 0; }

mapfile -t CHANGED < <(git apply --numstat "$PATCH" | awk -F'\t' '{print $3}')

SECURITY=() TOUCHED_TM=0
for p in "${CHANGED[@]}"; do
  case "$p" in
    .oss-scanner/threat_model.md) TOUCHED_TM=1 ;;
    src/autobook/*appl*|src/autobook/*session*|src/autobook/*money*|src/autobook/*review*| \
    src/autobook/*redact*|src/autobook/*adapter*|src/autobook/*backend*|src/autobook/*llm*| \
    src/autobook/*knn*|src/autobook/*threshold*|src/autobook/*classif*|src/autobook/*correlat*| \
    src/autobook/*dedup*|src/autobook/*fitid*|src/autobook/*ingest*|src/autobook/*pack*| \
    src/autobook/*launch*|src/autobook/*log*|src/autobook/*secret*|src/autobook/*credential*| \
    src/autobook/*paperless*|AGENTS.md|SECURITY.md|docs/design/architecture/14-threat-model.md)
      SECURITY+=("$p") ;;
  esac
done

if [ "${#SECURITY[@]}" -eq 0 ]; then
  echo "PDCA-EVIDENCE: no security-relevant path touched"
  exit 0
fi
if [ "$TOUCHED_TM" -eq 1 ]; then
  echo "PDCA-EVIDENCE: security-relevant paths touched and the threat model updated: ${SECURITY[*]}"
  exit 0
fi
echo "PDCA-UNVERIFIABLE: security-relevant paths changed without a threat-model update: ${SECURITY[*]} — decide at sign-off whether .oss-scanner/threat_model.md needs a change (new input, moved trust boundary, changed must-hold property)"
exit 77
