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
            "Probe workspace convergence by comparing StickySpaces-observed active "
            "Space output with ground-truth yabai output after rapid switching."
        )
    )
    parser.add_argument(
        "--stimulus-cmd",
        required=True,
        help="Command that performs rapid workspace switching stimulus.",
    )
    parser.add_argument(
        "--observed-space-cmd",
        required=True,
        help="Command that prints app-observed active space identifier.",
    )
    parser.add_argument(
        "--truth-space-cmd",
        required=True,
        help="Command that prints ground-truth active space identifier.",
    )
    parser.add_argument(
        "--samples",
        type=int,
        default=10,
        help="Number of probe runs.",
    )
    parser.add_argument(
        "--threshold-ms",
        type=float,
        default=1000.0,
        help="Convergence threshold for p95 and per-sample pass checks.",
    )
    parser.add_argument(
        "--timeout-ms",
        type=int,
        default=1000,
        help="Maximum wait for a single run to converge.",
    )
    parser.add_argument(
        "--poll-interval-ms",
        type=int,
        default=50,
        help="Poll interval while checking observed vs truth values.",
    )
    parser.add_argument(
        "--command-timeout-ms",
        type=int,
        default=500,
        help="Timeout for each shell command execution.",
    )
    parser.add_argument(
        "--cooldown-ms",
        type=int,
        default=150,
        help="Cooldown between runs.",
    )
    parser.add_argument(
        "--evidence-dir",
        default="artifacts/phase0a/evidence",
        help="Root evidence directory.",
    )
    parser.add_argument("--run-id", help="Explicit run ID (default: timestamp).")
    return parser.parse_args()


def normalized_space_id(raw: str) -> str:
    first_line = raw.strip().splitlines()
    return first_line[0].strip() if first_line else ""


def run_sample(args: argparse.Namespace, run_index: int) -> dict[str, Any]:
    record: dict[str, Any] = {"run_index": run_index, "started_at": now_iso()}
    start = time.perf_counter()

    stimulus = run_shell(args.stimulus_cmd, args.command_timeout_ms)
    record["stimulus_result"] = {
        "exit_code": stimulus["exit_code"],
        "timed_out": stimulus["timed_out"],
        "stderr": stimulus["stderr"][:300],
    }
    if stimulus["timed_out"] or stimulus["exit_code"] != 0:
        record.update(
            {
                "finished_at": now_iso(),
                "success": False,
                "error": "stimulus command failed",
            }
        )
        return record

    deadline = start + (max(args.timeout_ms, 1) / 1000.0)
    attempts = 0
    mismatches: list[dict[str, str]] = []
    converged = False
    observed_value = ""
    truth_value = ""

    while time.perf_counter() < deadline:
        attempts += 1
        observed = run_shell(args.observed_space_cmd, args.command_timeout_ms)
        truth = run_shell(args.truth_space_cmd, args.command_timeout_ms)

        observed_value = normalized_space_id(observed["stdout"])
        truth_value = normalized_space_id(truth["stdout"])

        reads_ok = (
            not observed["timed_out"]
            and observed["exit_code"] == 0
            and not truth["timed_out"]
            and truth["exit_code"] == 0
            and observed_value
            and truth_value
        )
        if reads_ok and observed_value == truth_value:
            converged = True
            break

        if len(mismatches) < 5:
            mismatches.append(
                {
                    "observed_space": observed_value,
                    "truth_space": truth_value,
                }
            )

        time.sleep(max(args.poll_interval_ms, 1) / 1000.0)

    elapsed_ms = round((time.perf_counter() - start) * 1000.0, 3)
    success = converged and elapsed_ms <= args.threshold_ms
    record.update(
        {
            "finished_at": now_iso(),
            "attempts": attempts,
            "elapsed_ms": elapsed_ms,
            "observed_space": observed_value,
            "truth_space": truth_value,
            "mismatch_samples": mismatches,
            "success": success,
            "error": None if success else "did not converge within threshold",
        }
    )
    return record


def main() -> int:
    args = parse_args()
    if args.samples <= 0:
        raise SystemExit("--samples must be > 0")

    run_id = args.run_id or default_run_id()
    run_dir = ensure_run_directory(args.evidence_dir, run_id)

    samples: list[dict[str, Any]] = []
    successful_latencies: list[float] = []

    for run_index in range(1, args.samples + 1):
        sample = run_sample(args, run_index)
        if sample["success"]:
            successful_latencies.append(sample["elapsed_ms"])
        samples.append(sample)

        if args.cooldown_ms > 0:
            time.sleep(args.cooldown_ms / 1000.0)

    p95 = percentile(successful_latencies, 95.0)
    gate_passed = (
        len(successful_latencies) == args.samples
        and p95 is not None
        and p95 <= args.threshold_ms
    )

    result = {
        "gate_id": "phase0a.workspace_convergence",
        "spec_reference": "docs/stickyspaces-tech-spec.md#Checkpoint A",
        "captured_at": now_iso(),
        "run_id": run_id,
        "config": {
            "samples": args.samples,
            "threshold_ms": args.threshold_ms,
            "timeout_ms": args.timeout_ms,
            "poll_interval_ms": args.poll_interval_ms,
            "stimulus_cmd": args.stimulus_cmd,
            "observed_space_cmd": args.observed_space_cmd,
            "truth_space_cmd": args.truth_space_cmd,
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

    output_path = Path(run_dir) / "workspace-convergence.json"
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
