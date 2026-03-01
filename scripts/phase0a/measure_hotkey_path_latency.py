#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path
from typing import Any

from common import (
    default_run_id,
    ensure_run_directory,
    now_iso,
    percentile,
    run_shell,
    write_json,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Measure end-to-end hotkey-path latency (placeholder harness) for "
            "StickySpaces Phase 0A Checkpoint A."
        )
    )
    parser.add_argument(
        "--trigger-cmd",
        required=True,
        help="Command that triggers sticky creation (for example, a KM macro trigger).",
    )
    parser.add_argument(
        "--visible-probe-cmd",
        required=True,
        help="Command that returns exit code 0 once the sticky is visible.",
    )
    parser.add_argument(
        "--reset-cmd",
        help="Optional command run after each sample to reset state.",
    )
    parser.add_argument("--samples", type=int, default=10, help="Number of samples to run.")
    parser.add_argument(
        "--threshold-ms",
        type=float,
        default=100.0,
        help="Target p95 threshold in milliseconds.",
    )
    parser.add_argument(
        "--timeout-ms",
        type=int,
        default=2000,
        help="Timeout for each sample while waiting for visibility.",
    )
    parser.add_argument(
        "--poll-interval-ms",
        type=int,
        default=20,
        help="Poll interval for --visible-probe-cmd.",
    )
    parser.add_argument(
        "--trigger-timeout-ms",
        type=int,
        default=3000,
        help="Timeout for --trigger-cmd and --reset-cmd.",
    )
    parser.add_argument(
        "--probe-timeout-ms",
        type=int,
        default=500,
        help="Timeout for each probe command execution.",
    )
    parser.add_argument(
        "--cooldown-ms",
        type=int,
        default=250,
        help="Cooldown after each sample.",
    )
    parser.add_argument(
        "--evidence-dir",
        default="artifacts/phase0a/evidence",
        help="Root evidence directory.",
    )
    parser.add_argument("--run-id", help="Explicit run ID (default: timestamp).")
    parser.add_argument(
        "--notes",
        help="Optional notes embedded in the output evidence.",
    )
    return parser.parse_args()


def run_sample(args: argparse.Namespace, run_index: int) -> dict[str, Any]:
    sample_record: dict[str, Any] = {
        "run_index": run_index,
        "started_at": now_iso(),
    }

    start = time.perf_counter()
    trigger = run_shell(args.trigger_cmd, args.trigger_timeout_ms)
    sample_record["trigger_result"] = {
        "exit_code": trigger["exit_code"],
        "timed_out": trigger["timed_out"],
        "stderr": trigger["stderr"][:300],
    }

    if trigger["timed_out"] or trigger["exit_code"] != 0:
        sample_record.update(
            {
                "finished_at": now_iso(),
                "success": False,
                "error": "trigger command failed",
            }
        )
        return sample_record

    deadline = start + (max(args.timeout_ms, 1) / 1000.0)
    attempts = 0
    last_probe: dict[str, Any] | None = None
    converged = False

    while time.perf_counter() < deadline:
        attempts += 1
        probe = run_shell(args.visible_probe_cmd, args.probe_timeout_ms)
        last_probe = {
            "exit_code": probe["exit_code"],
            "timed_out": probe["timed_out"],
            "stdout": probe["stdout"][:300],
            "stderr": probe["stderr"][:300],
        }
        if not probe["timed_out"] and probe["exit_code"] == 0:
            converged = True
            break
        time.sleep(max(args.poll_interval_ms, 1) / 1000.0)

    elapsed_ms = round((time.perf_counter() - start) * 1000.0, 3)
    sample_record.update(
        {
            "finished_at": now_iso(),
            "attempts": attempts,
            "elapsed_ms": elapsed_ms,
            "last_probe": last_probe,
            "success": converged,
            "within_threshold": converged and elapsed_ms < args.threshold_ms,
            "error": None if converged else "visibility probe timed out",
        }
    )
    return sample_record


def maybe_reset(args: argparse.Namespace) -> dict[str, Any] | None:
    if not args.reset_cmd:
        return None
    return run_shell(args.reset_cmd, args.trigger_timeout_ms)


def main() -> int:
    args = parse_args()
    if args.samples <= 0:
        raise SystemExit("--samples must be > 0")
    if args.timeout_ms <= 0:
        raise SystemExit("--timeout-ms must be > 0")

    run_id = args.run_id or default_run_id()
    run_dir = ensure_run_directory(args.evidence_dir, run_id)

    samples: list[dict[str, Any]] = []
    successful_latencies: list[float] = []

    for run_index in range(1, args.samples + 1):
        sample = run_sample(args, run_index)
        reset_result = maybe_reset(args)
        if reset_result is not None:
            sample["reset_result"] = {
                "exit_code": reset_result["exit_code"],
                "timed_out": reset_result["timed_out"],
                "stderr": reset_result["stderr"][:300],
            }

        if sample["success"]:
            successful_latencies.append(sample["elapsed_ms"])
        samples.append(sample)

        if args.cooldown_ms > 0:
            time.sleep(args.cooldown_ms / 1000.0)

    p95 = percentile(successful_latencies, 95.0)
    gate_passed = (
        len(successful_latencies) == args.samples
        and p95 is not None
        and p95 < args.threshold_ms
    )

    result = {
        "gate_id": "phase0a.hotkey_path_latency",
        "spec_reference": "docs/stickyspaces-tech-spec.md#Checkpoint A",
        "captured_at": now_iso(),
        "run_id": run_id,
        "config": {
            "samples": args.samples,
            "threshold_ms": args.threshold_ms,
            "timeout_ms": args.timeout_ms,
            "poll_interval_ms": args.poll_interval_ms,
            "trigger_cmd": args.trigger_cmd,
            "visible_probe_cmd": args.visible_probe_cmd,
            "reset_cmd": args.reset_cmd,
            "notes": args.notes,
        },
        "summary": {
            "successful_samples": len(successful_latencies),
            "failed_samples": args.samples - len(successful_latencies),
            "p95_ms": round(p95, 3) if p95 is not None else None,
            "threshold_ms": args.threshold_ms,
            "gate_passed": gate_passed,
        },
        "samples": samples,
    }

    output_path = Path(run_dir) / "hotkey-path-latency.json"
    write_json(output_path, result)
    print(f"Wrote evidence: {output_path}")
    print(
        "p95_ms="
        f"{result['summary']['p95_ms']} threshold_ms={args.threshold_ms} "
        f"gate_passed={gate_passed}"
    )
    return 0 if gate_passed else 1


if __name__ == "__main__":
    sys.exit(main())
