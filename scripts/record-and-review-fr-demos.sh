#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DURATION="${1:-auto}"
WORKSPACE_ID="${2:-1}"
OUTPUT_DIR="${3:-artifacts/ui-demos}"
DISPLAY_ID="${4:-1}"
FRAME_COUNT="${5:-8}"

echo "Step 1/3: Recording UI demos..."
scripts/record-all-fr-demos.sh "$DURATION" "$WORKSPACE_ID" "$OUTPUT_DIR" "$DISPLAY_ID"

echo
echo "Step 2/3: Analyzing recorded videos..."
mkdir -p "${OUTPUT_DIR}/review"
shopt -s nullglob
for video in "$OUTPUT_DIR"/*/*.mov; do
  case_review_dir="$(dirname "$video")/review"
  scripts/analyze-ui-demo.py --video "$video" --output-root "$case_review_dir" --frames "$FRAME_COUNT"
done
shopt -u nullglob

echo
echo "Step 3/3: Building review report..."
scripts/report-ui-demos.py --analysis-root "$OUTPUT_DIR" --output "${OUTPUT_DIR}/review/index.html"
echo "Review report: ${OUTPUT_DIR}/review/index.html"
