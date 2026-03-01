#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from common import default_run_id, ensure_run_directory, now_iso, write_json


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Capture Phase 0A mode-decision freeze metadata and product-alignment "
            "checkpoint acknowledgements."
        )
    )
    parser.add_argument(
        "--transition-mode-profile",
        required=True,
        choices=("continuousBridge+fallback", "discreteFallback-only"),
        help="Selected ZoomTransitionMode support profile for MVP.",
    )
    parser.add_argument(
        "--package-path-decision",
        required=True,
        help="Frozen packaging/launch identity decision for MVP.",
    )
    parser.add_argument(
        "--a1-decision",
        default="accepted: primary-display-only MVP interpretation",
        help="Acknowledgement statement for A-1.",
    )
    parser.add_argument(
        "--a3-decision",
        default="accepted: conservative deletion safety with confirmation",
        help="Acknowledgement statement for A-3.",
    )
    parser.add_argument(
        "--adr-path",
        required=True,
        help="Path to the ADR documenting these decisions.",
    )
    parser.add_argument(
        "--off-ramp",
        action="append",
        default=[],
        help="Optional override in the form '<contract>=<pivot>'.",
    )
    parser.add_argument(
        "--checkpoint-reference",
        default="docs/stickyspaces-tech-spec.md#Checkpoint A",
        help="Spec reference for this freeze record.",
    )
    parser.add_argument(
        "--evidence-dir",
        default="artifacts/phase0a/evidence",
        help="Root evidence directory.",
    )
    parser.add_argument("--run-id", help="Explicit run ID (default: timestamp).")
    parser.add_argument(
        "--output-file",
        help="Optional explicit output JSON path.",
    )
    return parser.parse_args()


def default_off_ramps() -> dict[str, str]:
    return {
        "D-3.space_binding_contract": "Switch to ManualVisibility strategy.",
        "D-5.transition_bridge_contract": (
            "Switch to discreteFallback-only and block FR-7/FR-8 release unless parity gates pass."
        ),
        "D-12.launch_identity_contract": "Switch packaging path and re-run launch identity gate matrix.",
    }


def parse_off_ramp_overrides(raw_values: list[str]) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for item in raw_values:
        if "=" not in item:
            raise SystemExit(f"Invalid --off-ramp value '{item}'. Expected <contract>=<pivot>.")
        key, value = item.split("=", 1)
        parsed[key.strip()] = value.strip()
    return parsed


def main() -> int:
    args = parse_args()
    adr_path = Path(args.adr_path)
    if not adr_path.exists():
        raise SystemExit(f"ADR path does not exist: {adr_path}")

    run_id = args.run_id or default_run_id()
    run_dir = ensure_run_directory(args.evidence_dir, run_id)
    output_path = Path(args.output_file) if args.output_file else (run_dir / "mode-decision-freeze.json")

    off_ramps = default_off_ramps()
    off_ramps.update(parse_off_ramp_overrides(args.off_ramp))

    payload = {
        "record_type": "phase0a_mode_decision_freeze",
        "captured_at": now_iso(),
        "run_id": run_id,
        "checkpoint_reference": args.checkpoint_reference,
        "transition_mode_profile": args.transition_mode_profile,
        "package_path_decision": args.package_path_decision,
        "product_alignment_decisions": {
            "A-1": args.a1_decision,
            "A-3": args.a3_decision,
        },
        "off_ramp_mapping": off_ramps,
        "adr_reference": str(adr_path),
    }

    write_json(output_path, payload)
    print(f"Wrote evidence: {output_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
