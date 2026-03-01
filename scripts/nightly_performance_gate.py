#!/usr/bin/env python3
"""Evaluate NFR-1/2/3 nightly metrics and emit release-blocking signal."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Evaluate nightly StickySpaces performance metrics. "
            "Exits non-zero when release should be blocked."
        )
    )
    parser.add_argument("--input", required=True, help="Path to metrics JSON file.")
    parser.add_argument("--output", required=True, help="Path to gate result JSON file.")
    return parser.parse_args()


def evaluate(metrics: dict[str, Any]) -> dict[str, Any]:
    nfr1 = int(metrics["nfr1_p95_ms"])
    nfr2 = int(metrics["nfr2_p95_ms"])
    nfr3 = int(metrics["nfr3_memory_mb"])

    failures: list[str] = []
    if nfr1 > 100:
        failures.append("NFR-1 hotkey-to-visible p95 exceeded 100ms")
    if nfr2 < 300 or nfr2 > 500:
        failures.append("NFR-2 zoom transition p95 outside 300-500ms")
    if nfr3 > 30:
        failures.append("NFR-3 memory exceeded 30MB")

    return {
        "release_blocking": len(failures) > 0,
        "failures": failures,
        "metrics": {
            "nfr1_p95_ms": nfr1,
            "nfr2_p95_ms": nfr2,
            "nfr3_memory_mb": nfr3,
        },
    }


def main() -> int:
    args = parse_args()
    input_path = Path(args.input)
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    metrics = json.loads(input_path.read_text())
    result = evaluate(metrics)
    output_path.write_text(json.dumps(result, indent=2) + "\n")

    return 1 if result["release_blocking"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
