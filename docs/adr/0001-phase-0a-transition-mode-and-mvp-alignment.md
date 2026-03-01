# ADR 0001: Phase 0A Transition Mode and MVP Alignment Freeze

- Status: Accepted (Phase 0A freeze)
- Date: 2026-03-01
- Task: `spacetree-6q5.1`
- Spec reference: `docs/stickyspaces-tech-spec.md` (Checkpoint A)

## Context

Checkpoint A requires a pre-implementation decision freeze for:

1. Zoom transition mode profile (`continuousBridge+fallback` or `discreteFallback-only`)
2. Packaging/launch identity direction
3. Product-alignment acknowledgements for `A-1` and `A-3`

This ADR records those decisions and the contract off-ramps required before
moving to Phase 0B.

## Decisions

### D1. Transition mode profile

Selected profile: **`continuousBridge+fallback`**.

- `continuousBridge` is the preferred runtime mode for motion quality.
- `discreteFallback` remains implemented and testable as a safety mode.
- Forced-mode parity checks remain mandatory per Checkpoint A and Task 6 tests.

### D2. Packaging and launch identity

Selected packaging path: **bundled agent app** with:

- stable bundle identifier,
- stable install/launch path,
- no Dock icon behavior in release mode.

`swift run` remains dev-only and is explicitly not a release identity target.

### D3. Product-alignment checkpoint decisions

`A-1` and `A-3` are accepted for MVP:

- **A-1 (Display scope interpretation):** MVP supports primary-display Spaces only (single-display mode contract).
- **A-3 (Workspace deletion safety):** MVP uses conservative confirmation before irreversible deletion to reduce false-positive data loss risk.

## Rationale

- The dual-mode transition profile keeps the higher-quality path while preserving
  an explicit fallback contract.
- Freezing launch identity early reduces late-stage TCC/packaging churn.
- `A-1` and `A-3` preserve MVP feasibility while protecting trust-sensitive data
  handling around workspace lifecycle events.

## Off-Ramp Mapping (Contract Failure -> Pivot)

| Contract | Failure signal | Off-ramp pivot |
| --- | --- | --- |
| D-3 Space-binding (`NSPanel` default behavior) | Wrong-space rendering gate fails | Switch to `ManualVisibility` strategy before Phase 0B proceeds |
| D-5 Transition bridge continuity | Bridge mode violates continuity gates | Use `discreteFallback-only` profile |
| D-5 Fallback parity | `discreteFallback` also fails parity gates | Block FR-7/FR-8 scope; explicit scope re-approval required |
| D-12 Launch identity stability | Clean install/restart/upgrade/relocation instability | Switch packaging path and re-run identity gate matrix |

## Checkpoint A Evidence Linkage

- Execution plan: `docs/checkpoints/stickyspaces-phase-0a-checkpoint-a-execution-plan.md`
- Gate template: `templates/phase0a/checkpoint-a-gate-results.template.json`
- Mode freeze record output:
  `artifacts/phase0a/evidence/<run-id>/mode-decision-freeze.json`

## Consequences

- Phase 0B (`spacetree-6q5.2`) remains blocked until all Checkpoint A gates pass
  and this ADR-backed freeze remains valid.
- Any gate failure invokes the mapped off-ramp immediately, not ad hoc
  implementation changes.
