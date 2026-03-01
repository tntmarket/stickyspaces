#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SCENARIO="${1:-fr-1}"
DURATION="${2:-16}"
WORKSPACE_ID="${3:-1}"
OUTPUT_DIR="${4:-artifacts/ui-demos}"
DISPLAY_ID="${5:-1}"

mkdir -p "$OUTPUT_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUTPUT_FILE="${OUTPUT_DIR}/${STAMP}-${SCENARIO}.mov"

echo "Recording UI demo"
echo " scenario: $SCENARIO"
echo " duration: ${DURATION}s"
echo " display:  ${DISPLAY_ID}"
echo " output:   ${OUTPUT_FILE}"
echo

swift run stickyspaces-ui-e2e \
  --duration "$DURATION" \
  --scenario "$SCENARIO" \
  --workspace "$WORKSPACE_ID" &
RUNNER_PID=$!

# Allow windows to appear before recording starts.
sleep 1

set +e
screencapture -x -D"$DISPLAY_ID" -k -V"$DURATION" -v "$OUTPUT_FILE"
CAPTURE_EXIT=$?
set -e

wait "$RUNNER_PID" || true

if [[ "$CAPTURE_EXIT" -ne 0 ]]; then
  echo "Video capture failed (exit=${CAPTURE_EXIT})."
  echo "Tip: grant Screen Recording permission to your terminal/IDE"
  echo "in System Settings -> Privacy & Security -> Screen Recording."
  exit "$CAPTURE_EXIT"
fi

echo "Saved demo video: $OUTPUT_FILE"
