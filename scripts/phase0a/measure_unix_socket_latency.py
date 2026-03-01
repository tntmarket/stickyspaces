#!/usr/bin/env python3
from __future__ import annotations

import argparse
import socket
import sys
import time
from pathlib import Path
from typing import Any

from common import default_run_id, ensure_run_directory, now_iso, percentile, write_json


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Measure Unix socket round-trip latency for "
            "StickySpaces Phase 0A (Checkpoint A)."
        )
    )
    parser.add_argument("--socket-path", required=True, help="Unix socket path to connect to.")
    parser.add_argument(
        "--request",
        default='{"type":"status"}',
        help="Raw request payload written to the socket.",
    )
    parser.add_argument(
        "--append-newline",
        action="store_true",
        help="Append a newline to --request before sending.",
    )
    parser.add_argument("--samples", type=int, default=30, help="Number of latency samples.")
    parser.add_argument(
        "--timeout-ms",
        type=int,
        default=500,
        help="Per-request socket timeout in milliseconds.",
    )
    parser.add_argument(
        "--threshold-ms",
        type=float,
        default=5.0,
        help="Gate threshold for p95 round-trip latency.",
    )
    parser.add_argument(
        "--max-response-bytes",
        type=int,
        default=65536,
        help="Maximum response bytes read before truncating.",
    )
    parser.add_argument(
        "--evidence-dir",
        default="artifacts/phase0a/evidence",
        help="Root evidence directory.",
    )
    parser.add_argument(
        "--run-id",
        help="Explicit run ID (default: timestamp).",
    )
    return parser.parse_args()


def read_response(client: socket.socket, max_response_bytes: int) -> bytes:
    response = bytearray()
    while len(response) < max_response_bytes:
        chunk = client.recv(min(4096, max_response_bytes - len(response)))
        if not chunk:
            break
        response.extend(chunk)
    return bytes(response)


def run_sample(
    socket_path: str,
    payload: str,
    timeout_ms: int,
    max_response_bytes: int,
) -> dict[str, Any]:
    started_at = now_iso()
    start = time.perf_counter()

    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(max(timeout_ms, 1) / 1000.0)
        client.connect(socket_path)
        client.sendall(payload.encode("utf-8"))
        client.shutdown(socket.SHUT_WR)
        response = read_response(client, max_response_bytes)

    elapsed_ms = (time.perf_counter() - start) * 1000.0
    return {
        "started_at": started_at,
        "finished_at": now_iso(),
        "elapsed_ms": round(elapsed_ms, 3),
        "response_bytes": len(response),
        "response_preview": response.decode("utf-8", errors="replace")[:200],
        "success": True,
    }


def main() -> int:
    args = parse_args()
    if args.samples <= 0:
        raise SystemExit("--samples must be > 0")
    if args.timeout_ms <= 0:
        raise SystemExit("--timeout-ms must be > 0")
    if args.max_response_bytes <= 0:
        raise SystemExit("--max-response-bytes must be > 0")

    payload = args.request + ("\n" if args.append_newline else "")
    run_id = args.run_id or default_run_id()
    run_dir = ensure_run_directory(args.evidence_dir, run_id)

    samples: list[dict[str, Any]] = []
    successful_latencies: list[float] = []

    for run_index in range(1, args.samples + 1):
        sample_record: dict[str, Any] = {"run_index": run_index}
        try:
            sample_result = run_sample(
                socket_path=args.socket_path,
                payload=payload,
                timeout_ms=args.timeout_ms,
                max_response_bytes=args.max_response_bytes,
            )
            sample_record.update(sample_result)
            successful_latencies.append(sample_result["elapsed_ms"])
        except Exception as exc:  # noqa: BLE001
            sample_record.update(
                {
                    "started_at": now_iso(),
                    "finished_at": now_iso(),
                    "success": False,
                    "error": str(exc),
                }
            )
        samples.append(sample_record)

    p95 = percentile(successful_latencies, 95.0)
    gate_passed = (
        len(successful_latencies) == args.samples
        and p95 is not None
        and p95 < args.threshold_ms
    )

    result = {
        "gate_id": "phase0a.unix_socket_round_trip",
        "spec_reference": "docs/stickyspaces-tech-spec.md#Checkpoint A",
        "captured_at": now_iso(),
        "run_id": run_id,
        "config": {
            "socket_path": args.socket_path,
            "samples": args.samples,
            "timeout_ms": args.timeout_ms,
            "threshold_ms": args.threshold_ms,
            "max_response_bytes": args.max_response_bytes,
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

    output_path = Path(run_dir) / "unix-socket-latency.json"
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
