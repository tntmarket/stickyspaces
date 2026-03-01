#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from html import escape
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate an HTML review report from analyzed UI demo videos."
    )
    parser.add_argument(
        "--analysis-root",
        default="artifacts/ui-demos/review",
        help="Folder containing *.json outputs from analyze-ui-demo.py",
    )
    parser.add_argument(
        "--output",
        default="artifacts/ui-demos/review/index.html",
        help="Output HTML report path.",
    )
    return parser.parse_args()


def render_section(entry: dict, report_dir: Path) -> str:
    scenario = escape(entry["scenario"])
    video = Path(entry["video"])
    rel_video = escape(str(video.relative_to(report_dir.parent)))
    duration = entry.get("duration_seconds", 0)
    res = entry.get("resolution", {})
    width = res.get("width", "?")
    height = res.get("height", "?")
    fps = entry.get("fps", "?")

    notes = "".join(f"<li>{escape(item)}</li>" for item in entry.get("expected_observations", []))
    frames_html = []
    for frame_path in entry.get("frames", []):
        frame = Path(frame_path)
        rel_frame = escape(str(frame.relative_to(report_dir)))
        frames_html.append(
            f'<a href="{rel_frame}"><img src="{rel_frame}" alt="{scenario} frame" '
            'style="width:220px;border:1px solid #444;border-radius:6px"/></a>'
        )

    return f"""
<section style="margin:24px 0;padding:16px;border:1px solid #333;border-radius:10px;background:#101215">
  <h2 style="margin-top:0">{scenario}</h2>
  <p><strong>Video:</strong> <a href="../{rel_video}">{video.name}</a></p>
  <p><strong>Duration:</strong> {duration}s | <strong>Resolution:</strong> {width}x{height} | <strong>FPS:</strong> {fps}</p>
  <p><strong>Expected observations:</strong></p>
  <ul>{notes}</ul>
  <div style="display:flex;flex-wrap:wrap;gap:10px">{''.join(frames_html)}</div>
</section>
"""


def main() -> int:
    args = parse_args()
    analysis_root = Path(args.analysis_root)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    entries = []
    for json_file in sorted(analysis_root.glob("*.json")):
        with json_file.open("r", encoding="utf-8") as handle:
            entries.append(json.load(handle))

    sections = [render_section(entry, output.parent) for entry in entries]
    html = f"""<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <title>StickySpaces UI Demo Review</title>
</head>
<body style="font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Helvetica,Arial,sans-serif;background:#0b0d10;color:#e5e7eb;max-width:1200px;margin:0 auto;padding:24px">
  <h1>StickySpaces UI Demo Review</h1>
  <p>Generated from analyzed FR demo videos.</p>
  {''.join(sections) if sections else '<p>No analyzed demos found.</p>'}
</body>
</html>
"""
    output.write_text(html, encoding="utf-8")
    print(f"Wrote report: {output}")
    print(f"Included demos: {len(entries)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
