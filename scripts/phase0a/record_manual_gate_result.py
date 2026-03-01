#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from common import default_run_id, ensure_run_directory, now_iso, write_json


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Record manual Phase 0A gate observations (for GUI/visual checks) "
            "into machine-readable evidence files."
        )
    )
    parser.add_argument("--gate-id", required=True, help="Gate identifier (for example, phase0a.ns_panel_space_binding).")
    parser.add_argument(
        "--run-index",
        required=True,
        type=int,
        help="Consecutive run index (1-10).",
    )
    parser.add_argument(
        "--status",
        required=True,
        choices=("pass", "fail", "blocked"),
        help="Observation status for this run.",
    )
    parser.add_argument(
        "--notes",
        default="",
        help="Free-form notes, observations, or remediation hints.",
    )
    parser.add_argument(
        "--measurement-ms",
        type=float,
        help="Optional measured latency/duration in milliseconds.",
    )
    parser.add_argument(
        "--evidence-ref",
        action="append",
        default=[],
        help="Optional evidence path or URI (repeatable).",
    )
    parser.add_argument(
        "--checkpoint-reference",
        default="docs/stickyspaces-tech-spec.md#Checkpoint A",
        help="Spec reference associated with this observation.",
    )
    parser.add_argument(
        "--evidence-dir",
        default="artifacts/phase0a/evidence",
        help="Root evidence directory.",
    )
    parser.add_argument("--run-id", help="Explicit run ID (default: timestamp).")
    return parser.parse_args()


def append_jsonl(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, sort_keys=True) + "\n")


def main() -> int:
    args = parse_args()
    if args.run_index <= 0:
        raise SystemExit("--run-index must be > 0")

    run_id = args.run_id or default_run_id()
    run_dir = ensure_run_directory(args.evidence_dir, run_id)

    payload = {
        "record_type": "phase0a_manual_gate_observation",
        "captured_at": now_iso(),
        "run_id": run_id,
        "gate_id": args.gate_id,
        "run_index": args.run_index,
        "status": args.status,
        "checkpoint_reference": args.checkpoint_reference,
        "measurement_ms": args.measurement_ms,
        "notes": args.notes,
        "evidence_refs": args.evidence_ref,
    }

    gate_dir = run_dir / "manual-gates" / args.gate_id
    gate_file = gate_dir / f"run-{args.run_index:02d}.json"
    write_json(gate_file, payload)

    index_file = run_dir / "manual-gates" / "index.jsonl"
    append_jsonl(index_file, payload)

    print(f"Wrote evidence: {gate_file}")
    print(f"Updated index: {index_file}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
