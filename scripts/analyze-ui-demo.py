#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
from dataclasses import dataclass
from pathlib import Path


@dataclass
class VideoSummary:
    path: str
    scenario: str
    duration_seconds: float
    width: int
    height: int
    fps: float
    extracted_frames: list[str]
    notes: list[str]


def run_command(command: list[str]) -> str:
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    return result.stdout.strip()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract review frames and metadata from a UI demo video."
    )
    parser.add_argument("--video", required=True, help="Path to .mov demo video.")
    parser.add_argument(
        "--scenario",
        help="Scenario id (for example fr-7). If omitted, inferred from filename.",
    )
    parser.add_argument(
        "--output-root",
        default="artifacts/ui-demos/review",
        help="Root output folder for metadata/frames/report assets.",
    )
    parser.add_argument(
        "--frames",
        type=int,
        default=8,
        help="Number of evenly spaced frames to extract.",
    )
    return parser.parse_args()


def infer_scenario(video_path: Path) -> str:
    stem = video_path.stem
    parts = stem.split("-")
    if len(parts) >= 2 and parts[-2].startswith("fr"):
        return f"{parts[-2]}-{parts[-1]}"
    if parts and parts[-1].startswith("fr"):
        return parts[-1]
    return "unknown"


def probe_video(video_path: Path) -> tuple[float, int, int, float]:
    probe = run_command(
        [
            "ffprobe",
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=width,height,avg_frame_rate",
            "-show_entries",
            "format=duration",
            "-of",
            "json",
            str(video_path),
        ]
    )
    payload = json.loads(probe)
    stream = payload["streams"][0]
    width = int(stream["width"])
    height = int(stream["height"])
    duration_seconds = float(payload["format"]["duration"])
    frame_rate_raw = stream.get("avg_frame_rate", "0/1")
    numerator, denominator = frame_rate_raw.split("/")
    fps = float(numerator) / float(denominator) if float(denominator) != 0 else 0.0
    return duration_seconds, width, height, fps


def extract_frame(video_path: Path, output_file: Path, timestamp_seconds: float) -> None:
    output_file.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-hide_banner",
            "-loglevel",
            "error",
            "-ss",
            f"{timestamp_seconds:.3f}",
            "-i",
            str(video_path),
            "-frames:v",
            "1",
            str(output_file),
        ],
        check=True,
    )


def expected_observations(scenario: str) -> list[str]:
    map_: dict[str, list[str]] = {
        "fr-1": ["one sticky appears", "sticky remains visible"],
        "fr-2": ["workspace 1 sticky visible", "workspace switch visibility changes"],
        "fr-3": ["sticky text updates from before to after"],
        "fr-4": ["sticky changes position", "sticky changes size"],
        "fr-5": ["multiple stickies visible simultaneously"],
        "fr-6": ["one sticky disappears while others remain"],
        "fr-7": ["canvas overview window appears", "multiple workspace regions visible"],
        "fr-8": ["selection causes workspace navigation"],
        "fr-9": ["canvas region arrangement reflects moved positions"],
        "fr-10": ["active workspace highlighted in canvas overview"],
        "fr-11": ["workspace sticky hidden", "later confirmation state shown"],
    }
    return map_.get(scenario, ["verify scenario behavior manually"])


def analyze(video_path: Path, scenario: str, output_root: Path, frame_count: int) -> VideoSummary:
    duration_seconds, width, height, fps = probe_video(video_path)

    safe_name = video_path.stem
    frame_dir = output_root / safe_name / "frames"
    frame_dir.mkdir(parents=True, exist_ok=True)

    extracted_frames: list[str] = []
    if frame_count <= 0:
        frame_count = 1

    interval = duration_seconds / (frame_count + 1)
    for idx in range(frame_count):
        timestamp = max(0.0, interval * (idx + 1))
        frame_file = frame_dir / f"frame-{idx + 1:02d}.png"
        extract_frame(video_path, frame_file, timestamp)
        extracted_frames.append(str(frame_file))

    notes = expected_observations(scenario)
    return VideoSummary(
        path=str(video_path),
        scenario=scenario,
        duration_seconds=duration_seconds,
        width=width,
        height=height,
        fps=fps,
        extracted_frames=extracted_frames,
        notes=notes,
    )


def main() -> int:
    args = parse_args()
    video_path = Path(args.video)
    if not video_path.exists():
        raise SystemExit(f"Video does not exist: {video_path}")

    scenario = args.scenario or infer_scenario(video_path)
    output_root = Path(args.output_root)
    summary = analyze(video_path, scenario, output_root, args.frames)

    output_file = output_root / f"{video_path.stem}.json"
    output_file.parent.mkdir(parents=True, exist_ok=True)
    output_file.write_text(
        json.dumps(
            {
                "video": summary.path,
                "scenario": summary.scenario,
                "duration_seconds": round(summary.duration_seconds, 3),
                "resolution": {"width": summary.width, "height": summary.height},
                "fps": round(summary.fps, 3),
                "frames": summary.extracted_frames,
                "expected_observations": summary.notes,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    print(f"Wrote analysis: {output_file}")
    print(f"Extracted {len(summary.extracted_frames)} review frames")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
