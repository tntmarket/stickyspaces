# StickySpaces Phase 0A Checkpoint A Execution Plan

This runbook implements Task `spacetree-6q5.1` and maps every
Checkpoint A gate from `docs/stickyspaces-tech-spec.md` to repeatable
commands and evidence locations.

## Scope

- This document covers **Phase 0A only**: risk spikes, contract gates, and decision freeze.
- This document does **not** implement product features from Phase 0B / Task 1+.
- Source of truth for gate definitions: `docs/stickyspaces-tech-spec.md` (Delivery Plan, Checkpoint A).

## Evidence Contract

- Evidence root: `artifacts/phase0a/evidence/<run-id>/`
- Canonical machine-readable run ledger:
  `artifacts/phase0a/evidence/<run-id>/gate-results.json`
- Template source:
  `templates/phase0a/checkpoint-a-gate-results.template.json`
- ADR reference:
  `docs/adr/0001-phase-0a-transition-mode-and-mvp-alignment.md`

## One-Time Setup Per Checkpoint Run

```bash
RUN_ID="$(date +%Y%m%d-%H%M%S)"
mkdir -p "artifacts/phase0a/evidence/$RUN_ID"
cp "templates/phase0a/checkpoint-a-gate-results.template.json" \
  "artifacts/phase0a/evidence/$RUN_ID/gate-results.json"
```

## Gate-to-Command Mapping

| Gate ID | Required gate (`docs/stickyspaces-tech-spec.md` Checkpoint A) | Repeatable command/script | Primary evidence location |
| --- | --- | --- | --- |
| A-G1 | NSPanel default `collectionBehavior` stays on creator Space across switches | Manual scenario + record result: `python3 scripts/phase0a/record_manual_gate_result.py --run-id "$RUN_ID" --gate-id phase0a.ns_panel_space_binding --run-index <1-10> --status <pass\|fail> --evidence-ref "artifacts/phase0a/evidence/$RUN_ID/screenshots/a-g1-run-<n>.png" --notes "<observation>"` | `artifacts/phase0a/evidence/$RUN_ID/manual-gates/phase0a.ns_panel_space_binding/` |
| A-G2 | `stickyspaces new` panel above app windows, below system UI, no app activation | Manual scenario + record result: `python3 scripts/phase0a/record_manual_gate_result.py --run-id "$RUN_ID" --gate-id phase0a.panel_z_order_non_activation --run-index <1-10> --status <pass\|fail> --evidence-ref "artifacts/phase0a/evidence/$RUN_ID/screenshots/a-g2-run-<n>.png" --notes "<frontmost-app check + z-order check>"` | `artifacts/phase0a/evidence/$RUN_ID/manual-gates/phase0a.panel_z_order_non_activation/` |
| A-G3 | `stickyspaces new` captures immediate keystrokes without activating StickySpaces | Manual scenario + record result: `python3 scripts/phase0a/record_manual_gate_result.py --run-id "$RUN_ID" --gate-id phase0a.immediate_keystroke_capture --run-index <1-10> --status <pass\|fail> --evidence-ref "artifacts/phase0a/evidence/$RUN_ID/screenshots/a-g3-run-<n>.png" --notes "<typed text + frontmost app unchanged>"` | `artifacts/phase0a/evidence/$RUN_ID/manual-gates/phase0a.immediate_keystroke_capture/` |
| A-G4 | Unix socket round-trip p95 <5ms | `python3 scripts/phase0a/measure_unix_socket_latency.py --run-id "$RUN_ID" --socket-path "$SOCKET_PATH" --request '{"type":"status"}' --append-newline --samples 30 --threshold-ms 5` | `artifacts/phase0a/evidence/$RUN_ID/unix-socket-latency.json` |
| A-G5 | End-to-end hotkey path p95 <100ms | `python3 scripts/phase0a/measure_hotkey_path_latency.py --run-id "$RUN_ID" --trigger-cmd "$HOTKEY_TRIGGER_CMD" --visible-probe-cmd "$VISIBLE_PROBE_CMD" --reset-cmd "$RESET_CMD" --samples 10 --threshold-ms 100 --timeout-ms 2000` | `artifacts/phase0a/evidence/$RUN_ID/hotkey-path-latency.json` |
| A-G6 | Bundled agent launch path works; launch identity stable | `python3 scripts/phase0a/check_launch_identity_stability.py --run-id "$RUN_ID" --identity-cmd "$IDENTITY_CMD" --clean-install-cmd "$CLEAN_INSTALL_CMD" --restart-cmd "$RESTART_CMD" --upgrade-reinstall-cmd "$UPGRADE_CMD" --relocation-cmd "$RELOCATION_CMD" --cycles 10` | `artifacts/phase0a/evidence/$RUN_ID/launch-identity-stability.json` |
| A-G7 | `.canJoinAllSpaces` canvas overlay works without z-order artifacts | Manual scenario + record result: `python3 scripts/phase0a/record_manual_gate_result.py --run-id "$RUN_ID" --gate-id phase0a.can_join_all_spaces_overlay --run-index <1-10> --status <pass\|fail> --evidence-ref "artifacts/phase0a/evidence/$RUN_ID/screenshots/a-g7-run-<n>.png" --notes "<artifact check>"` | `artifacts/phase0a/evidence/$RUN_ID/manual-gates/phase0a.can_join_all_spaces_overlay/` |
| A-G8 | `NSWorkspace` + yabai pipeline converges under rapid switching | `python3 scripts/phase0a/probe_workspace_convergence.py --run-id "$RUN_ID" --stimulus-cmd "$RAPID_SWITCH_CMD" --observed-space-cmd "$OBSERVED_SPACE_CMD" --truth-space-cmd "$TRUTH_SPACE_CMD" --samples 10 --threshold-ms 1000` | `artifacts/phase0a/evidence/$RUN_ID/workspace-convergence.json` |
| A-G9 | Mode decision freeze (transition profile + package path decision) | `python3 scripts/phase0a/capture_mode_decision.py --run-id "$RUN_ID" --transition-mode-profile "continuousBridge+fallback" --package-path-decision "Bundled agent app with stable bundle identifier + install path" --adr-path "docs/adr/0001-phase-0a-transition-mode-and-mvp-alignment.md"` | `artifacts/phase0a/evidence/$RUN_ID/mode-decision-freeze.json` |
| A-G10 | Product-alignment checkpoint acknowledges `A-1` and `A-3` | Included in ADR + freeze record command above; validate ADR content before closing gate | `docs/adr/0001-phase-0a-transition-mode-and-mvp-alignment.md` and `artifacts/phase0a/evidence/$RUN_ID/mode-decision-freeze.json` |

## Acceptance Roll-Up (50/50)

Record acceptance in `gate-results.json` using this mapping:

- Wrong-space rendering gate (10/10): A-G1 + A-G8
- Keystroke-routing gate (10/10): A-G2 + A-G3
- End-to-end hotkey latency gate (10/10): A-G5
- Transition continuity gate (10/10): A-G7 + A-G9
- Launch identity stability gate (10/10): A-G6
- Product-alignment checkpoint: A-G10 ADR evidence present

## Practical Notes

- GUI-observed checks (A-G1, A-G2, A-G3, A-G7) should save screenshots per run:

```bash
screencapture -x "artifacts/phase0a/evidence/$RUN_ID/screenshots/<gate>-run-<n>.png"
```

- Keep one `RUN_ID` per contiguous 10-run campaign.
- If any contract gate fails, apply the pre-decided off-ramp from
  `docs/adr/0001-phase-0a-transition-mode-and-mvp-alignment.md`
  before starting Phase 0B (`spacetree-6q5.2`).
