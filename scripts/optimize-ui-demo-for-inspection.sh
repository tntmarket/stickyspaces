#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

INPUT_VIDEO="${1:-}"
OUTPUT_VIDEO="${2:-}"

INSPECT_FPS="${INSPECT_FPS:-8}"
INSPECT_WIDTH="${INSPECT_WIDTH:-960}"
INSPECT_CRF="${INSPECT_CRF:-40}"
INSPECT_PRESET="${INSPECT_PRESET:-veryfast}"
INSPECT_ALL_I_FRAMES="${INSPECT_ALL_I_FRAMES:-1}"
INSPECT_GRAYSCALE="${INSPECT_GRAYSCALE:-0}"
INSPECT_DROP_REDUNDANT="${INSPECT_DROP_REDUNDANT:-1}"

if [[ -z "$INPUT_VIDEO" ]]; then
  echo "Usage: scripts/optimize-ui-demo-for-inspection.sh <input.mov> [output.mp4]"
  exit 1
fi

if [[ ! -f "$INPUT_VIDEO" ]]; then
  echo "Input video does not exist: $INPUT_VIDEO"
  exit 1
fi

if [[ -z "$OUTPUT_VIDEO" ]]; then
  base_name="$(basename "${INPUT_VIDEO%.*}")"
  OUTPUT_VIDEO="artifacts/ui-demos/review/inspection/${base_name}.inspect.mp4"
fi

mkdir -p "$(dirname "$OUTPUT_VIDEO")"

echo "Optimizing demo for inspection"
echo " input:   $INPUT_VIDEO"
echo " output:  $OUTPUT_VIDEO"
echo " fps:     $INSPECT_FPS"
echo " width:   $INSPECT_WIDTH"
echo " crf:     $INSPECT_CRF"
echo " preset:  $INSPECT_PRESET"
echo " all-i:   $INSPECT_ALL_I_FRAMES"
echo " gray:    $INSPECT_GRAYSCALE"
echo " dedupe:  $INSPECT_DROP_REDUNDANT"
echo

FILTERS=()
if [[ "$INSPECT_DROP_REDUNDANT" == "1" ]]; then
  FILTERS+=("mpdecimate=hi=64*10:lo=64*4:frac=0.12")
  FILTERS+=("setpts=N/(${INSPECT_FPS}*TB)")
fi
if [[ "$INSPECT_WIDTH" != "0" ]]; then
  FILTERS+=("scale=${INSPECT_WIDTH}:-2:flags=lanczos")
fi
if [[ "$INSPECT_GRAYSCALE" == "1" ]]; then
  FILTERS+=("format=gray")
fi

FILTER_GRAPH="$(IFS=,; echo "${FILTERS[*]}")"

KEYFRAME_ARGS=()
if [[ "$INSPECT_ALL_I_FRAMES" == "1" ]]; then
  KEYFRAME_ARGS=(-g 1 -keyint_min 1 -sc_threshold 0)
else
  KEYFRAME_ARGS=(-g "$((INSPECT_FPS * 2))" -keyint_min "$INSPECT_FPS" -sc_threshold 0)
fi

if [[ -n "$FILTER_GRAPH" ]]; then
  ffmpeg -y -hide_banner -loglevel error \
    -i "$INPUT_VIDEO" \
    -vf "$FILTER_GRAPH" \
    -r "$INSPECT_FPS" \
    -an \
    -c:v libx264 \
    -preset "$INSPECT_PRESET" \
    -crf "$INSPECT_CRF" \
    -pix_fmt yuv420p \
    -movflags +faststart \
    "${KEYFRAME_ARGS[@]}" \
    "$OUTPUT_VIDEO"
else
  ffmpeg -y -hide_banner -loglevel error \
    -i "$INPUT_VIDEO" \
    -r "$INSPECT_FPS" \
    -an \
    -c:v libx264 \
    -preset "$INSPECT_PRESET" \
    -crf "$INSPECT_CRF" \
    -pix_fmt yuv420p \
    -movflags +faststart \
    "${KEYFRAME_ARGS[@]}" \
    "$OUTPUT_VIDEO"
fi

echo "Saved inspection-optimized video: $OUTPUT_VIDEO"
