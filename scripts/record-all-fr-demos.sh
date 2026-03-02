#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DURATION="${1:-auto}"
WORKSPACE_ID="${2:-1}"
OUTPUT_DIR="${3:-artifacts/ui-demos}"
DISPLAY_ID="${4:-1}"

SCENARIOS=(
  "create-sticky-current-workspace"
  "workspace-switch-shows-associated-stickies"
  "edit-sticky-text-in-place"
  "move-and-resize-sticky"
  "multiple-stickies-per-workspace"
  "dismiss-sticky"
  "zoom-out-canvas-overview"
  "navigate-by-sticky-selection"
  "arrange-workspace-regions"
  "highlight-active-workspace-in-overview"
  "remove-stickies-for-destroyed-workspace"
)

echo "Recording full UI demo collection..."
if [[ "$DURATION" == "auto" ]]; then
  echo " duration per demo: auto (scenario-aware)"
else
  echo " duration per demo: ${DURATION}s"
fi
echo " output directory:  ${OUTPUT_DIR}"
echo

for scenario in "${SCENARIOS[@]}"; do
  echo "=== Recording ${scenario} ==="
  scripts/record-ui-demo.sh "$scenario" "$DURATION" "$WORKSPACE_ID" "$OUTPUT_DIR" "$DISPLAY_ID"
  echo
done

echo "Done. UI demo collection available in: ${OUTPUT_DIR}"
