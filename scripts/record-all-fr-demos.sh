#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DURATION="${1:-16}"
WORKSPACE_ID="${2:-1}"
OUTPUT_DIR="${3:-artifacts/ui-demos}"
DISPLAY_ID="${4:-1}"

SCENARIOS=(
  "fr-1"
  "fr-2"
  "fr-3"
  "fr-4"
  "fr-5"
  "fr-6"
  "fr-7"
  "fr-8"
  "fr-9"
  "fr-10"
  "fr-11"
)

echo "Recording full FR demo collection..."
echo " duration per demo: ${DURATION}s"
echo " output directory:  ${OUTPUT_DIR}"
echo

for scenario in "${SCENARIOS[@]}"; do
  echo "=== Recording ${scenario} ==="
  scripts/record-ui-demo.sh "$scenario" "$DURATION" "$WORKSPACE_ID" "$OUTPUT_DIR" "$DISPLAY_ID"
  echo
done

echo "Done. FR demo collection available in: ${OUTPUT_DIR}"
