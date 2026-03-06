# Phase 0A Harness Scripts

These scripts scaffold the risk-spike and contract-gate workflows for
`openspec/changes/archive/2026-02-26-mvp-foundation/design.md` **Checkpoint A**.

All scripts write machine-readable evidence under:

- `artifacts/phase0a/evidence/<run-id>/...`

## Scripts

- `measure_unix_socket_latency.py`  
  Measures Unix socket request/response round-trip latency.

- `measure_hotkey_path_latency.py`  
  Placeholder harness for end-to-end hotkey path latency
  (`Keyboard Maestro -> CLI -> socket -> visible panel`).

- `check_launch_identity_stability.py`  
  Runs launch-identity stability checks across clean install, restart,
  upgrade/reinstall, and relocation scenarios.

- `probe_workspace_convergence.py`  
  Verifies the observed active workspace converges to ground truth under
  rapid switching.

- `capture_mode_decision.py`  
  Captures the mode-decision freeze record and product-alignment
  acknowledgements (`A-1`, `A-3`).

- `record_manual_gate_result.py`  
  Records manual/visual gate results (for checks requiring GUI verification).

## Validation

Each script supports `--help`. Example:

```bash
python3 scripts/phase0a/measure_unix_socket_latency.py --help
```
