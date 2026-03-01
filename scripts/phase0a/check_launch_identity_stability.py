#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any

from common import default_run_id, ensure_run_directory, now_iso, run_shell, write_json

CORE_SCENARIOS = (
    "clean_install",
    "restart",
    "upgrade_reinstall",
    "relocation",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Run launch identity stability checks for Phase 0A "
            "(clean install, restart, upgrade/reinstall, relocation)."
        )
    )
    parser.add_argument(
        "--identity-cmd",
        required=True,
        help=(
            "Command that outputs launch identity information. "
            "Use a stable JSON payload when possible."
        ),
    )
    parser.add_argument("--clean-install-cmd", help="Setup command for clean install scenario.")
    parser.add_argument("--restart-cmd", help="Setup command for restart scenario.")
    parser.add_argument(
        "--upgrade-reinstall-cmd",
        help="Setup command for upgrade/reinstall scenario.",
    )
    parser.add_argument("--relocation-cmd", help="Setup command for relocation scenario.")
    parser.add_argument(
        "--allow-partial-scenarios",
        action="store_true",
        help="Allow running a subset of the four core scenarios.",
    )
    parser.add_argument(
        "--cycles",
        type=int,
        default=10,
        help="Number of complete scenario cycles.",
    )
    parser.add_argument(
        "--scenario-timeout-ms",
        type=int,
        default=20000,
        help="Timeout for each scenario setup command.",
    )
    parser.add_argument(
        "--identity-timeout-ms",
        type=int,
        default=3000,
        help="Timeout for identity capture command.",
    )
    parser.add_argument(
        "--evidence-dir",
        default="artifacts/phase0a/evidence",
        help="Root evidence directory.",
    )
    parser.add_argument("--run-id", help="Explicit run ID (default: timestamp).")
    return parser.parse_args()


def parse_identity(stdout: str) -> dict[str, Any]:
    text = stdout.strip()
    if not text:
        return {"raw": ""}

    try:
        payload = json.loads(text)
        if isinstance(payload, dict):
            return payload
    except json.JSONDecodeError:
        pass

    return {"raw": text}


def identity_fingerprint(identity: dict[str, Any]) -> str:
    normalized = json.dumps(identity, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def scenario_commands(args: argparse.Namespace) -> dict[str, str]:
    return {
        "clean_install": args.clean_install_cmd or "",
        "restart": args.restart_cmd or "",
        "upgrade_reinstall": args.upgrade_reinstall_cmd or "",
        "relocation": args.relocation_cmd or "",
    }


def main() -> int:
    args = parse_args()
    if args.cycles <= 0:
        raise SystemExit("--cycles must be > 0")

    scenario_cmds = scenario_commands(args)
    missing = [name for name, cmd in scenario_cmds.items() if not cmd]
    if missing and not args.allow_partial_scenarios:
        raise SystemExit(
            "Missing required core scenario commands. "
            "Provide all four or pass --allow-partial-scenarios. "
            f"Missing: {', '.join(missing)}"
        )

    active_scenarios = [(name, cmd) for name, cmd in scenario_cmds.items() if cmd]
    if not active_scenarios:
        raise SystemExit("No scenario commands provided.")

    run_id = args.run_id or default_run_id()
    run_dir = ensure_run_directory(args.evidence_dir, run_id)
    baseline_fingerprints: dict[str, str] = {}
    cycle_results: list[dict[str, Any]] = []

    for cycle_index in range(1, args.cycles + 1):
        cycle_record: dict[str, Any] = {
            "cycle_index": cycle_index,
            "started_at": now_iso(),
            "scenarios": [],
            "cycle_passed": True,
        }

        for scenario_name, setup_cmd in active_scenarios:
            setup_result = run_shell(setup_cmd, args.scenario_timeout_ms)
            identity_cmd_result = run_shell(args.identity_cmd, args.identity_timeout_ms)
            identity_payload = parse_identity(identity_cmd_result["stdout"])
            fingerprint = identity_fingerprint(identity_payload)

            if scenario_name not in baseline_fingerprints:
                baseline_fingerprints[scenario_name] = fingerprint

            stable = baseline_fingerprints[scenario_name] == fingerprint
            scenario_passed = (
                not setup_result["timed_out"]
                and setup_result["exit_code"] == 0
                and not identity_cmd_result["timed_out"]
                and identity_cmd_result["exit_code"] == 0
                and stable
            )

            scenario_record = {
                "scenario": scenario_name,
                "setup_result": {
                    "exit_code": setup_result["exit_code"],
                    "timed_out": setup_result["timed_out"],
                    "stderr": setup_result["stderr"][:300],
                },
                "identity_result": {
                    "exit_code": identity_cmd_result["exit_code"],
                    "timed_out": identity_cmd_result["timed_out"],
                    "stderr": identity_cmd_result["stderr"][:300],
                    "identity_payload": identity_payload,
                    "fingerprint": fingerprint,
                    "matches_baseline": stable,
                },
                "passed": scenario_passed,
            }
            cycle_record["scenarios"].append(scenario_record)
            cycle_record["cycle_passed"] = cycle_record["cycle_passed"] and scenario_passed

        cycle_record["finished_at"] = now_iso()
        cycle_results.append(cycle_record)

    passed_cycles = sum(1 for cycle in cycle_results if cycle["cycle_passed"])
    gate_passed = passed_cycles == args.cycles

    result = {
        "gate_id": "phase0a.launch_identity_stability",
        "spec_reference": "docs/stickyspaces-tech-spec.md#Checkpoint A",
        "captured_at": now_iso(),
        "run_id": run_id,
        "config": {
            "cycles": args.cycles,
            "identity_cmd": args.identity_cmd,
            "scenario_commands": scenario_cmds,
            "allow_partial_scenarios": args.allow_partial_scenarios,
            "scenario_timeout_ms": args.scenario_timeout_ms,
            "identity_timeout_ms": args.identity_timeout_ms,
        },
        "summary": {
            "passed_cycles": passed_cycles,
            "required_cycles": args.cycles,
            "gate_passed": gate_passed,
            "missing_core_scenarios": missing,
        },
        "baseline_fingerprints": baseline_fingerprints,
        "cycles": cycle_results,
    }

    output_path = Path(run_dir) / "launch-identity-stability.json"
    write_json(output_path, result)
    print(f"Wrote evidence: {output_path}")
    print(f"passed_cycles={passed_cycles}/{args.cycles} gate_passed={gate_passed}")
    return 0 if gate_passed else 1


if __name__ == "__main__":
    sys.exit(main())
