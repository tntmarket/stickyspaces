#!/usr/bin/env python3
from __future__ import annotations

import datetime as dt
import json
import math
import subprocess
from pathlib import Path
from typing import Any


def now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")


def default_run_id() -> str:
    return dt.datetime.now().strftime("%Y%m%d-%H%M%S")


def ensure_run_directory(evidence_root: str, run_id: str) -> Path:
    run_dir = Path(evidence_root).expanduser() / run_id
    run_dir.mkdir(parents=True, exist_ok=True)
    return run_dir


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def run_shell(command: str, timeout_ms: int) -> dict[str, Any]:
    timeout_s = max(timeout_ms, 1) / 1000.0
    try:
        completed = subprocess.run(
            command,
            shell=True,
            text=True,
            capture_output=True,
            timeout=timeout_s,
        )
    except subprocess.TimeoutExpired as exc:
        return {
            "command": command,
            "exit_code": None,
            "timed_out": True,
            "stdout": (exc.stdout or "").strip(),
            "stderr": (exc.stderr or "").strip(),
        }

    return {
        "command": command,
        "exit_code": completed.returncode,
        "timed_out": False,
        "stdout": completed.stdout.strip(),
        "stderr": completed.stderr.strip(),
    }


def percentile(values: list[float], rank: float) -> float | None:
    if not values:
        return None

    sorted_values = sorted(values)
    if len(sorted_values) == 1:
        return float(sorted_values[0])

    bounded_rank = min(max(rank, 0.0), 100.0)
    position = (len(sorted_values) - 1) * (bounded_rank / 100.0)
    lower_index = math.floor(position)
    upper_index = math.ceil(position)
    lower_value = float(sorted_values[lower_index])
    upper_value = float(sorted_values[upper_index])

    if lower_index == upper_index:
        return lower_value

    fraction = position - lower_index
    return lower_value + (upper_value - lower_value) * fraction
