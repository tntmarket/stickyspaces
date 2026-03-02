#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SCENARIO="${1:-fr-1}"
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
INSPECTION_OUTPUT_DIR="${INSPECTION_OUTPUT_DIR:-${OUTPUT_DIR}/review/inspection}"

epoch_ms() {
  python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
}

recommended_duration_for_scenario() {
  case "$1" in
    fr-7|fr-9|fr-10)
      echo "8"
      ;;
    fr-11)
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

mkdir -p "$OUTPUT_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUTPUT_FILE="${OUTPUT_DIR}/${STAMP}-${SCENARIO}.mov"

echo "Recording UI demo"
echo " scenario: $SCENARIO"
echo " duration: ${DURATION_LABEL}"
echo " display:  ${DISPLAY_ID}"
echo " output:   ${OUTPUT_FILE}"
echo " wait-for-actions-start: ${WAIT_FOR_ACTIONS_START} (timeout ${ACTION_START_TIMEOUT_SECONDS}s)"
echo " stop-on-actions-complete: ${STOP_ON_ACTIONS_COMPLETE} (tail ${TAIL_AFTER_ACTIONS_SECONDS}s)"
echo " post-trim-after-complete: ${POST_TRIM_AFTER_COMPLETE} (safety ${POST_TRIM_SAFETY_SECONDS}s)"
echo " generate-inspection-copy: ${GENERATE_INSPECTION_COPY}"
echo

RUNNER_LOG="$(mktemp -t stickyspaces-ui-e2e-record.XXXXXX.log)"

swift run stickyspaces-ui-e2e \
  --duration "$DURATION" \
  --scenario "$SCENARIO" \
  --workspace "$WORKSPACE_ID" \
  > >(tee "$RUNNER_LOG") 2>&1 &
RUNNER_PID=$!

ACTION_START_SEEN=0
if [[ "$WAIT_FOR_ACTIONS_START" == "1" ]]; then
  attempt_limit=$((ACTION_START_TIMEOUT_SECONDS * 10))
  for ((attempt=0; attempt<attempt_limit; attempt++)); do
    if grep -q "SCENARIO_ACTIONS_START" "$RUNNER_LOG"; then
      ACTION_START_SEEN=1
      break
    fi
    if ! kill -0 "$RUNNER_PID" 2>/dev/null; then
      break
    fi
    sleep 0.1
  done
  if [[ "$ACTION_START_SEEN" -eq 0 ]] && grep -q "SCENARIO_ACTIONS_START" "$RUNNER_LOG"; then
    ACTION_START_SEEN=1
  fi
else
  # Legacy fallback: allow windows to appear before recording starts.
  sleep 1
fi

if [[ "$WAIT_FOR_ACTIONS_START" == "1" && "$ACTION_START_SEEN" -eq 1 ]]; then
  echo "Detected scenario start marker; starting capture at first meaningful action."
elif [[ "$WAIT_FOR_ACTIONS_START" == "1" ]]; then
  echo "No start marker detected before timeout; starting capture with fallback timing."
fi

set +e
CAPTURE_START_EPOCH_MS="$(epoch_ms)"
screencapture -x -D"$DISPLAY_ID" -k -V"$DURATION" -v "$OUTPUT_FILE" &
CAPTURE_PID=$!
set -e

EARLY_STOPPED=0
ACTION_COMPLETE_SEEN=0
ACTION_COMPLETE_EPOCH_MS=""
RUNNER_DONE=0
if [[ "$STOP_ON_ACTIONS_COMPLETE" == "1" ]]; then
  while kill -0 "$CAPTURE_PID" 2>/dev/null; do
    if grep -q "SCENARIO_ACTIONS_COMPLETE" "$RUNNER_LOG"; then
      ACTION_COMPLETE_SEEN=1
      ACTION_COMPLETE_EPOCH_MS="$(epoch_ms)"
      sleep "$TAIL_AFTER_ACTIONS_SECONDS"
      if kill -0 "$CAPTURE_PID" 2>/dev/null; then
        kill -INT "$CAPTURE_PID" 2>/dev/null || true
        EARLY_STOPPED=1
      fi
      break
    fi
    if ! kill -0 "$RUNNER_PID" 2>/dev/null; then
      if [[ "$RUNNER_DONE" -eq 1 ]]; then
        break
      fi
      RUNNER_DONE=1
    fi
    sleep 0.1
  done
fi

set +e
wait "$CAPTURE_PID"
CAPTURE_EXIT=$?
wait "$RUNNER_PID"
RUNNER_EXIT=$?
set -e

if [[ "$KEEP_RUNNER_LOG" == "1" ]]; then
  echo "Retaining runner log: $RUNNER_LOG"
else
  rm -f "$RUNNER_LOG"
fi

if [[ "$RUNNER_EXIT" -ne 0 ]]; then
  echo "UI runner failed (exit=${RUNNER_EXIT})."
  exit "$RUNNER_EXIT"
fi

if [[ "$CAPTURE_EXIT" -ne 0 ]]; then
  if [[ "$EARLY_STOPPED" -eq 1 && -f "$OUTPUT_FILE" ]]; then
    echo "Capture stopped early after scenario completion (exit=${CAPTURE_EXIT})."
  else
    echo "Video capture failed (exit=${CAPTURE_EXIT})."
    echo "Tip: grant Screen Recording permission to your terminal/IDE"
    echo "in System Settings -> Privacy & Security -> Screen Recording."
    exit "$CAPTURE_EXIT"
  fi
fi

if [[ "$ACTION_COMPLETE_SEEN" -eq 1 ]]; then
  echo "Detected scenario completion marker; trimmed trailing idle time."
elif [[ "$STOP_ON_ACTIONS_COMPLETE" == "1" ]]; then
  echo "No completion marker detected before timeout; used max duration fallback."
fi

if [[ ! -f "$OUTPUT_FILE" ]]; then
  echo "Video capture failed (exit=${CAPTURE_EXIT})."
  echo "No output file produced: $OUTPUT_FILE"
  exit 1
fi

if [[ "$POST_TRIM_AFTER_COMPLETE" == "1" && "$ACTION_COMPLETE_SEEN" -eq 1 && -n "$ACTION_COMPLETE_EPOCH_MS" ]]; then
  TARGET_DURATION_SECONDS="$(
    python3 - <<PY
start_ms = int("${CAPTURE_START_EPOCH_MS}")
end_ms = int("${ACTION_COMPLETE_EPOCH_MS}")
tail = float("${TAIL_AFTER_ACTIONS_SECONDS}")
safety = float("${POST_TRIM_SAFETY_SECONDS}")
duration = max(0.5, ((end_ms - start_ms) / 1000.0) + tail + safety)
print(f"{duration:.3f}")
PY
  )"
  ACTUAL_DURATION_SECONDS="$(
    ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUTPUT_FILE"
  )"
  SHOULD_TRIM="$(
    python3 - <<PY
actual = float("${ACTUAL_DURATION_SECONDS}")
target = float("${TARGET_DURATION_SECONDS}")
print(1 if actual > target + 0.15 else 0)
PY
  )"
  if [[ "$SHOULD_TRIM" == "1" ]]; then
    TRIMMED_OUTPUT_FILE="${OUTPUT_FILE%.mov}.trim.mov"
    ffmpeg -y -hide_banner -loglevel error \
      -i "$OUTPUT_FILE" \
      -t "$TARGET_DURATION_SECONDS" \
      -an \
      -c:v libx264 \
      -preset veryfast \
      -crf 20 \
      -pix_fmt yuv420p \
      -movflags +faststart \
      "$TRIMMED_OUTPUT_FILE"
    mv "$TRIMMED_OUTPUT_FILE" "$OUTPUT_FILE"
    UPDATED_DURATION_SECONDS="$(
      ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUTPUT_FILE"
    )"
    echo "Post-trimmed original video from ${ACTUAL_DURATION_SECONDS}s to ${UPDATED_DURATION_SECONDS}s (target ${TARGET_DURATION_SECONDS}s)."
  fi
fi

echo "Saved demo video: $OUTPUT_FILE"

if [[ "$GENERATE_INSPECTION_COPY" == "1" ]]; then
  mkdir -p "$INSPECTION_OUTPUT_DIR"
  INSPECTION_FILE="${INSPECTION_OUTPUT_DIR}/${STAMP}-${SCENARIO}.inspect.mp4"
  scripts/optimize-ui-demo-for-inspection.sh "$OUTPUT_FILE" "$INSPECTION_FILE"
  echo "Saved inspection copy: $INSPECTION_FILE"
fi
