# StickySpaces hardening gates (Task 7)

This document lists deterministic gates that run in-repo for hardening.

## Test suites

- `swift test` includes `Task 7 hardening gates` coverage for:
  - prerequisite diagnostics in headless context
  - rapid-switch reliability, per-space sync checks, and renumbering stress
  - topology health-flap fault injection
  - IPC protocol skew and second-launch lock behavior
  - yabai timeout chaos gate (degrade without deadlock)
  - restart lifecycle state reset and local-only guardrail
  - default sticky readability contract
  - nightly performance release-blocking signal logic

## Nightly performance gate scaffold

Use `scripts/nightly_performance_gate.py` to evaluate NFR budgets and emit a release signal.

### Input JSON schema

```json
{
  "nfr1_p95_ms": 95,
  "nfr2_p95_ms": 420,
  "nfr3_memory_mb": 24
}
```

### Command

```bash
python3 scripts/nightly_performance_gate.py \
  --input artifacts/nightly/metrics.json \
  --output artifacts/nightly/gate-result.json
```

Exit code semantics:

- `0`: all NFR gates pass (candidate may proceed)
- `1`: at least one NFR gate failed (release-blocking)

## Continuous gate guidance

- Hardening gate should be run at least three consecutive times with zero flakes before release promotion.
- Nightly gate outputs (`gate-result.json`) should be consumed by CI release-candidate promotion logic.
