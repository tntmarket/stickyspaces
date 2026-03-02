#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SCENARIO_INPUT="${1:-create-sticky-current-workspace}"
DURATION_INPUT="${2:-auto}"
WORKSPACE_ID="${3:-1}"
OUTPUT_DIR="${4:-artifacts/ui-demos}"
DISPLAY_ID="${5:-1}"
TAIL_AFTER_ACTIONS_SECONDS="${TAIL_AFTER_ACTIONS_SECONDS:-0.5}"
STOP_ON_ACTIONS_COMPLETE="${STOP_ON_ACTIONS_COMPLETE:-1}"
WAIT_FOR_ACTIONS_START="${WAIT_FOR_ACTIONS_START:-1}"
ACTION_START_TIMEOUT_SECONDS="${ACTION_START_TIMEOUT_SECONDS:-12}"
POST_TRIM_AFTER_COMPLETE="${POST_TRIM_AFTER_COMPLETE:-1}"
POST_TRIM_SAFETY_SECONDS="${POST_TRIM_SAFETY_SECONDS:-0.2}"
KEEP_RUNNER_LOG="${KEEP_RUNNER_LOG:-0}"
GENERATE_INSPECTION_COPY="${GENERATE_INSPECTION_COPY:-1}"

canonical_scenario_name() {
  case "$1" in
    fr-1) echo "create-sticky-current-workspace" ;;
    fr-2) echo "workspace-switch-shows-associated-stickies" ;;
    fr-3) echo "edit-sticky-text-in-place" ;;
    fr-4) echo "move-and-resize-sticky" ;;
    fr-5) echo "multiple-stickies-per-workspace" ;;
    fr-6) echo "dismiss-sticky" ;;
    fr-7) echo "zoom-out-canvas-overview" ;;
    fr-8) echo "navigate-by-sticky-selection" ;;
    fr-9) echo "arrange-workspace-regions" ;;
    fr-10) echo "highlight-active-workspace-in-overview" ;;
    fr-11) echo "remove-stickies-for-destroyed-workspace" ;;
    *) echo "$1" ;;
  esac
}

SCENARIO="$(canonical_scenario_name "$SCENARIO_INPUT")"

recommended_duration_for_scenario() {
  case "$1" in
    zoom-out-canvas-overview|arrange-workspace-regions|highlight-active-workspace-in-overview)
      echo "8"
      ;;
    remove-stickies-for-destroyed-workspace)
      echo "9"
      ;;
    *)
      echo "7"
      ;;
  esac
}

if [[ "$DURATION_INPUT" == "auto" ]]; then
  DURATION="$(recommended_duration_for_scenario "$SCENARIO")"
  DURATION_LABEL="${DURATION}s (auto)"
else
  DURATION="$DURATION_INPUT"
  DURATION_LABEL="${DURATION}s"
fi

if ! [[ "$DURATION" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "Invalid duration: ${DURATION_INPUT}. Use a positive number of seconds or 'auto'."
  exit 1
fi

CASE_OUTPUT_DIR="${OUTPUT_DIR}/${SCENARIO}"
INSPECTION_OUTPUT_DIR="${INSPECTION_OUTPUT_DIR:-${CASE_OUTPUT_DIR}}"
OUTPUT_FILE="${CASE_OUTPUT_DIR}/${SCENARIO}.mov"
INSPECTION_FILE="${INSPECTION_OUTPUT_DIR}/${SCENARIO}.inspect.mp4"

rm -rf "$CASE_OUTPUT_DIR"
mkdir -p "$CASE_OUTPUT_DIR"
if [[ "$INSPECTION_OUTPUT_DIR" != "$CASE_OUTPUT_DIR" ]]; then
  mkdir -p "$INSPECTION_OUTPUT_DIR"
fi

echo "Recording UI demo"
echo " scenario: $SCENARIO"
echo " duration: ${DURATION_LABEL}"
echo " display:  ${DISPLAY_ID}"
echo " output:   ${OUTPUT_FILE}"
echo " wait-for-actions-start: ${WAIT_FOR_ACTIONS_START} (timeout ${ACTION_START_TIMEOUT_SECONDS}s)"
echo " stop-on-actions-complete: ${STOP_ON_ACTIONS_COMPLETE} (tail ${TAIL_AFTER_ACTIONS_SECONDS}s)"
echo " post-trim-after-complete: ${POST_TRIM_AFTER_COMPLETE} (safety ${POST_TRIM_SAFETY_SECONDS}s)"
echo " capture-backend: ${CAPTURE_BACKEND:-auto}"
echo " generate-inspection-copy: ${GENERATE_INSPECTION_COPY}"
echo

RUNNER_LOG="$(mktemp -t stickyspaces-ui-e2e-record.XXXXXX.log)"
DIAGNOSTICS_FILE="${CASE_OUTPUT_DIR}/${SCENARIO}.diagnostics.json"
set +e
swift run stickyspaces-ui-recorder \
  --duration "$DURATION" \
  --scenario "$SCENARIO" \
  --workspace "$WORKSPACE_ID" \
  --display "$DISPLAY_ID" \
  --output "$OUTPUT_FILE" \
  --runner-log "$RUNNER_LOG" \
  --diagnostics "$DIAGNOSTICS_FILE" \
  --tail-after-actions-seconds "$TAIL_AFTER_ACTIONS_SECONDS" \
  --stop-on-actions-complete "$STOP_ON_ACTIONS_COMPLETE" \
  --wait-for-actions-start "$WAIT_FOR_ACTIONS_START" \
  --action-start-timeout-seconds "$ACTION_START_TIMEOUT_SECONDS" \
  --post-trim-after-complete "$POST_TRIM_AFTER_COMPLETE" \
  --post-trim-safety-seconds "$POST_TRIM_SAFETY_SECONDS"
RECORDER_EXIT=$?
set -e

if [[ "$KEEP_RUNNER_LOG" == "1" ]]; then
  echo "Retaining runner log: $RUNNER_LOG"
else
  rm -f "$RUNNER_LOG"
fi

if [[ "$RECORDER_EXIT" -ne 0 ]]; then
  echo "Video capture failed (exit=${RECORDER_EXIT})."
  exit "$RECORDER_EXIT"
fi

if [[ ! -f "$OUTPUT_FILE" ]]; then
  echo "Video capture failed (exit=${RECORDER_EXIT})."
  echo "No output file produced: $OUTPUT_FILE"
  exit 1
fi

echo "Saved demo video: $OUTPUT_FILE"

if [[ "$GENERATE_INSPECTION_COPY" == "1" ]]; then
  scripts/optimize-ui-demo-for-inspection.sh "$OUTPUT_FILE" "$INSPECTION_FILE"
  echo "Saved inspection copy: $INSPECTION_FILE"
fi
