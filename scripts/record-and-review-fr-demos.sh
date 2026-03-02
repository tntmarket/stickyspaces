#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DURATION="${1:-auto}"
WORKSPACE_ID="${2:-1}"
OUTPUT_DIR="${3:-artifacts/ui-demos}"
DISPLAY_ID="${4:-1}"
FRAME_COUNT="${5:-8}"

echo "Step 1/3: Recording FR demos..."
scripts/record-all-fr-demos.sh "$DURATION" "$WORKSPACE_ID" "$OUTPUT_DIR" "$DISPLAY_ID"

echo
echo "Step 2/3: Analyzing recorded videos..."
ANALYSIS_DIR="${OUTPUT_DIR}/review"
mkdir -p "$ANALYSIS_DIR"

for video in "$OUTPUT_DIR"/*.mov; do
  scripts/analyze-ui-demo.py --video "$video" --output-root "$ANALYSIS_DIR" --frames "$FRAME_COUNT"
done

echo
echo "Step 3/3: Building review report..."
scripts/report-ui-demos.py --analysis-root "$ANALYSIS_DIR" --output "${ANALYSIS_DIR}/index.html"
echo "Review report: ${ANALYSIS_DIR}/index.html"
