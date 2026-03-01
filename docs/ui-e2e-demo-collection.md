# UI E2E Demo Collection

This project includes a visible AppKit-based demo runner that can record one video per functional requirement (FR-1 through FR-11).

## Quick Start

Record one FR demo:

```bash
scripts/record-ui-demo.sh fr-1 16
```

Record the full FR collection:

```bash
scripts/record-all-fr-demos.sh 16
```

Record + analyze + generate an HTML feedback report in one step:

```bash
scripts/record-and-review-fr-demos.sh 16
```

Videos are written to:

- `artifacts/ui-demos/`

Analysis output is written to:

- `artifacts/ui-demos/review/`
- `artifacts/ui-demos/review/index.html`

## Scenario Map

- `fr-1` — Create sticky on current workspace
- `fr-2` — Workspace switch visibility behavior
- `fr-3` — Edit sticky text in place
- `fr-4` — Move + resize sticky
- `fr-5` — Multiple stickies per workspace
- `fr-6` — Dismiss a sticky
- `fr-7` — Zoom-out canvas overview
- `fr-8` — Navigate by sticky selection
- `fr-9` — Arrange workspace regions
- `fr-10` — Active workspace highlight in zoom-out
- `fr-11` — Workspace-destroyed visibility removal + confirmation deletion

## Notes

- Recording uses macOS `screencapture -v`.
- First run may prompt for Screen Recording permissions.
- Frame extraction/reporting uses `ffmpeg`/`ffprobe`.
- Use the optional display argument if you need a non-main monitor:

```bash
scripts/record-ui-demo.sh fr-1 16 1 artifacts/ui-demos 2
```

Quick analyze-only loop for existing videos:

```bash
for f in artifacts/ui-demos/*.mov; do
  scripts/analyze-ui-demo.py --video "$f"
done
scripts/report-ui-demos.py
```
