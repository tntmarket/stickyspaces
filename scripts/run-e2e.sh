#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ "${1:-}" == "--all" ]]; then
  echo "Running full Swift test suite..."
  swift test
  exit 0
fi

echo "Running E2E-oriented integration suites..."
echo "(headless/in-memory; for visible windows use scripts/run-ui-e2e.sh)"
echo " - CLITests"
swift test --filter CLITests

echo " - IPCRoutingTests"
swift test --filter IPCRoutingTests

echo " - CanvasLayoutTests"
swift test --filter CanvasLayoutTests

echo " - WorkspaceLifecycleTests"
swift test --filter WorkspaceLifecycleTests

echo " - ZoomTransitionTests"
swift test --filter ZoomTransitionTests

echo "E2E-oriented test run complete."
