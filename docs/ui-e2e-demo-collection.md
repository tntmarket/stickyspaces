# UI E2E Demo Collection

This project includes a visible AppKit-based demo runner that records one video per use-case scenario.

## Quick Start

Record one FR demo:

```bash
scripts/record-ui-demo.sh create-sticky-current-workspace auto
```

Record the full FR collection:

```bash
scripts/record-all-fr-demos.sh auto
```

Record + analyze + generate an HTML feedback report in one step:

```bash
scripts/record-and-review-fr-demos.sh auto
```

Videos are written to:

- `artifacts/ui-demos/<scenario-id>/<scenario-id>.mov`
- `artifacts/ui-demos/<scenario-id>/<scenario-id>.inspect.mp4`

Each rerun overwrites assets for that scenario path.

Analysis output is written to:

- `artifacts/ui-demos/<scenario-id>/review/`
- `artifacts/ui-demos/review/index.html`

## Scenario Map

- `create-sticky-current-workspace` — Create sticky on current workspace
- `workspace-switch-shows-associated-stickies` — Workspace switch visibility behavior
- `edit-sticky-text-in-place` — Edit sticky text in place
- `move-and-resize-sticky` — Move + resize sticky
- `multiple-stickies-per-workspace` — Multiple stickies per workspace
- `dismiss-sticky` — Dismiss a sticky
- `zoom-out-canvas-overview` — Zoom-out canvas overview
- `navigate-by-sticky-selection` — Navigate by sticky selection
- `arrange-workspace-regions` — Arrange workspace regions
- `highlight-active-workspace-in-overview` — Active workspace highlight in zoom-out
- `remove-stickies-for-destroyed-workspace` — Workspace-destroyed visibility removal + confirmation deletion

## Notes

- Recording uses macOS `screencapture -v`.
- First run may prompt for Screen Recording permissions.
- Frame extraction/reporting uses `ffmpeg`/`ffprobe`.
- Use the optional display argument if you need a non-main monitor:

```bash
scripts/record-ui-demo.sh create-sticky-current-workspace auto 1 artifacts/ui-demos 2
```

Quick analyze-only loop for existing videos:

```bash
for f in artifacts/ui-demos/*/*.mov; do
  scripts/analyze-ui-demo.py --video "$f"
done
scripts/report-ui-demos.py
```
