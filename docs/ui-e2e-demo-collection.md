# UI E2E Coverage

The project now uses Swift tests as the only supported E2E/demo validation workflow.

## Primary Commands

Run the full test suite:

```bash
swift test
```

Run the E2E-oriented integration subset:

```bash
scripts/run-e2e.sh
```

Run the video-backed E2E suite (quick path):

```bash
swift test --filter ZoomOutCanvasOverviewJourneyTests
```

Run the headed/video-backed recorder journey:

```bash
STICKYSPACES_RUN_SCREEN_RECORDING_TESTS=1 swift test --filter ZoomOutCanvasOverviewJourneyTests
```

## Architecture Boundary

- Canonical automation surface lives in app code (`StickySpacesAutomationAPI` in `StickySpacesApp`).
- `stickyspaces` CLI is a thin adapter over the canonical automation API.
- Recorder lifecycle sync supports typed events (`STICKYSPACES_AUTOMATION_EVENT ...`) with legacy marker fallback.

## Artifacts

When video-backed tests are enabled, integration videos are written under:

- `artifacts/ui-demos/integration-*/<scenario>/<scenario>.mov`
