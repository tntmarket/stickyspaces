#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DURATION="${1:-20}"
SCENARIO="${2:-create-sticky-current-workspace}"
WORKSPACE_ID="${3:-1}"

echo "Launching visible UI E2E demo..."
echo "duration=${DURATION}s scenario=${SCENARIO} workspace=${WORKSPACE_ID}"
echo
echo "Expected behavior:"
echo "  - Scenario actions run on visible sticky windows."
echo "  - Remaining windows are dismissed at the end."
echo

swift run stickyspaces-ui-e2e \
  --duration "$DURATION" \
  --scenario "$SCENARIO" \
  --workspace "$WORKSPACE_ID"
