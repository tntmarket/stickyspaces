## Purpose

Core specification for StickySpaces, a native macOS app that places persistent, chromeless sticky notes on each workspace so users can recover intent at a glance. Upstream: PRD at `../../changes/archive/2026-02-26-mvp-foundation/proposal.md`, problem brief at `../../changes/archive/2026-02-26-mvp-foundation/problem-brief.md`. Covers cross-cutting functional, non-functional, constraint, architectural, and scope requirements for the StickySpaces MVP.

## Requirements

### Requirement: FR-1 Create sticky on current workspace

The system SHALL allow a knowledge worker to create a floating sticky note on the current workspace via a hotkey, because returning to a workspace should require zero effort to re-orient, eliminating the "what was I doing?" reconstruction tax.

#### Scenario: Hotkey creates sticky on active workspace

- **WHEN** user presses the create-sticky hotkey
- **THEN** a new sticky note appears on the current workspace with text cursor ready

#### Scenario: CLI creates sticky on active workspace

- **WHEN** user runs `stickyspaces new --text "Fix login bug"`
- **THEN** a sticky with that text is created and bound to the currently active workspace

#### Scenario: Creation during workspace transition returns retriable error

- **WHEN** user creates a sticky while a workspace switch is in progress
- **THEN** the system returns a retriable error rather than binding to the wrong workspace

### Requirement: FR-2 Auto-show stickies on workspace switch

The system SHALL display the correct stickies immediately when the user switches to a workspace, with no action required, because orientation should be a glance, not a deliberate act of recall.

#### Scenario: Switching workspace shows its stickies

- **WHEN** user switches to a workspace that has stickies
- **THEN** those stickies are visible immediately without any user action

#### Scenario: Switching workspace hides other stickies

- **WHEN** user switches away from a workspace with stickies
- **THEN** those stickies are no longer visible

### Requirement: FR-3 Edit sticky text in-place

The system SHALL allow a knowledge worker to edit sticky text directly in-place, with the cursor ready immediately after creation, because intentions evolve as work progresses, and stickies must reflect current state to remain useful.

#### Scenario: New sticky is immediately editable

- **WHEN** a new sticky is created
- **THEN** the text cursor is active inside the sticky and keystrokes are captured without activating the StickySpaces app

#### Scenario: Edit command updates sticky text

- **WHEN** user runs `stickyspaces edit <id> --text "Updated"`
- **THEN** the sticky text is updated to "Updated"

### Requirement: FR-4 Reposition and resize stickies

The system SHALL allow a knowledge worker to reposition and resize stickies by dragging, because different workflows need different screen layouts, and stickies must not obscure critical content.

#### Scenario: Drag to reposition sticky

- **WHEN** user drags a sticky to a new position
- **THEN** the sticky position is persisted in the store and reflected in queries

#### Scenario: Drag to resize sticky

- **WHEN** user drags a sticky edge to resize it
- **THEN** the sticky size is persisted in the store and reflected in queries

### Requirement: FR-5 Multiple stickies per workspace

The system SHALL allow a knowledge worker to have multiple stickies per workspace, because a single workspace may involve multiple sub-tasks or coordination notes.

#### Scenario: Create multiple stickies on same workspace

- **WHEN** user creates three stickies on the same workspace
- **THEN** all three stickies are visible and listed in queries for that workspace

### Requirement: FR-6 Dismiss a sticky

The system SHALL allow a knowledge worker to dismiss a sticky, because completed tasks clutter the view and erode the glanceability that makes stickies useful.

#### Scenario: Dismiss removes sticky permanently

- **WHEN** user dismisses a sticky via the hover-reveal dismiss control or CLI
- **THEN** the sticky is removed from the store and no longer appears on the workspace

### Requirement: FR-7 Zoom-out canvas showing all workspaces

The system SHALL allow a knowledge worker to zoom out to see all supported workspaces and their stickies in one spatial canvas (MVP scope: primary display Spaces only), because understanding the full landscape of work reduces "what else was I doing?" anxiety and enables better prioritization.

#### Scenario: Zoom-out shows all workspaces

- **WHEN** user triggers zoom-out
- **THEN** a spatial canvas is displayed showing all supported workspaces, including empty ones, with their stickies

#### Scenario: Empty workspaces appear on canvas

- **WHEN** a workspace has no stickies
- **THEN** it still appears as an empty region on the zoom-out canvas

### Requirement: FR-8 Navigate via sticky click in canvas

The system SHALL allow a knowledge worker to navigate to any workspace by clicking its sticky in the zoom-out canvas, because spatial navigation is lower cognitive load than recalling workspace numbers.

#### Scenario: Clicking sticky in canvas navigates to its workspace

- **WHEN** user clicks a sticky on the zoom-out canvas
- **THEN** the system zooms in and switches to that sticky's workspace

### Requirement: FR-9 Freely arrange workspace regions on canvas

The system SHALL allow a knowledge worker to freely arrange workspace regions on the zoom-out canvas, because spatial arrangement lets users encode task relationships by grouping related work together, leveraging their strong spatial memory.

#### Scenario: Drag workspace region to new position

- **WHEN** user drags a workspace region on the canvas
- **THEN** the new position persists across subsequent zoom-out invocations

### Requirement: FR-10 Active workspace highlight in canvas

The system SHALL allow a knowledge worker to see which workspace is currently active in the zoom-out canvas, because knowing "where I am now" is the anchor for deciding "where to go next."

#### Scenario: Active workspace is highlighted

- **WHEN** the zoom-out canvas is displayed
- **THEN** the currently active workspace region is visually highlighted

### Requirement: FR-11 Clean up stickies on workspace destruction

The system SHALL remove stickies from user-visible surfaces immediately when a workspace is destroyed, and hard-delete only after conservative topology confirmation, because orphaned stickies are confusing, but false-positive hard deletion would cause irreversible context loss.

#### Scenario: Destroyed workspace stickies disappear from UI

- **WHEN** a workspace is destroyed
- **THEN** its stickies are hidden from user-visible surfaces and queries immediately

#### Scenario: Hard deletion requires confirmation

- **WHEN** a workspace disappears from one topology snapshot
- **THEN** stickies are quarantined but not hard-deleted until confirmed absent across multiple snapshots

#### Scenario: Reappearing workspace restores stickies

- **WHEN** a workspace reappears during the quarantine window
- **THEN** its stickies are automatically restored to user-visible surfaces

### Requirement: NFR-1 Sticky creation latency under 100ms

The system SHALL complete sticky creation in less than 100ms from hotkey press to visible panel, because any perceptible delay breaks the "zero-friction capture" promise and discourages use at the critical moment of intention-setting.

#### Scenario: Creation latency within budget

- **WHEN** 30 create operations are measured end-to-end (hotkey to visible panel)
- **THEN** p95 latency is under 100ms

### Requirement: NFR-2 Zoom animation duration 300-500ms with no flicker

The system SHALL complete zoom-out and zoom-in animations within 300 to 500ms with no blank interval exceeding 100ms, because the animation must be fast enough to feel responsive, slow enough to maintain spatial continuity, and free of visible flicker.

#### Scenario: Zoom transition duration within budget

- **WHEN** 30 zoom-out/zoom-in round-trips are measured
- **THEN** p95 duration is within 300-500ms

#### Scenario: No blank flicker during transition

- **WHEN** a zoom-out or zoom-in transition plays
- **THEN** there is no blank or empty interval exceeding 100ms between frames

### Requirement: NFR-3 Memory footprint under 30MB

The system SHALL keep memory footprint under 30MB for typical usage of 5-10 workspaces with 1-5 stickies each, because this is a background utility that must never compete with the user's actual work apps for system resources.

#### Scenario: Typical session memory usage

- **WHEN** the app is running with 10 workspaces and 5 stickies each
- **THEN** resident memory footprint is under 30MB

### Requirement: NFR-4 New CLI command addable in under 1 hour

The system SHALL enable a developer to add a new CLI command within 1 hour, because the CLI is the primary integration surface for Keyboard Maestro, automation, and testing, and the command set will grow across phases.

#### Scenario: Adding a new CLI command

- **WHEN** a developer needs to add a new CLI command
- **THEN** the transport and routing layers require no changes — only the command definition and its handler need to be added

### Requirement: NFR-5 Fully CLI-operable project with no GUI tool dependency

The system SHALL have its project structure, build system, and test infrastructure fully operable through text file manipulation and CLI commands, with no dependency on GUI tools, because the primary development workflow is AI-agent-driven.

#### Scenario: Build and test via CLI

- **WHEN** a developer runs `swift build` and `swift test`
- **THEN** the project builds and tests execute without requiring Xcode GUI interaction

### Requirement: NFR-6 Readable-at-a-glance default styling

The system SHALL use default sticky styling with minimum 14pt effective text size, high-contrast foreground/background, and no decorative chrome, because re-orientation fails if users must squint or parse visual noise after every context switch.

#### Scenario: Default sticky readability

- **WHEN** a sticky is created with default styling
- **THEN** text size is at least 14pt, contrast ratio meets accessibility thresholds, and no decorative chrome is present

### Requirement: NFR-7 Versioned IPC compatibility

The system SHALL enforce explicit and versioned app/CLI IPC compatibility, with the server supporting protocol version N and N-1, because automation environments commonly drift binaries, and silent wire incompatibility causes fragile behavior.

#### Scenario: Compatible client connects successfully

- **WHEN** a client with protocol version N or N-1 connects
- **THEN** the handshake succeeds and commands are processed

#### Scenario: Incompatible client is rejected with guidance

- **WHEN** a client with an unsupported protocol version connects
- **THEN** the server responds with a structured `protocolMismatch` including actionable upgrade guidance

### Requirement: C-1 Chromeless floating panels bound to single Space

The system MUST render floating panels as chromeless (no title bar), above application windows, and bound to a single macOS Space, because orientation requires stickies to be visible at a glance without obscuring system UI, and workspace-binding makes a sticky an answer to "what am I doing HERE."

#### Scenario: Panel is chromeless and floating

- **WHEN** a sticky panel is displayed
- **THEN** it has no title bar, floats above application windows, and appears below system UI

#### Scenario: Panel stays on its creator Space

- **WHEN** a sticky is created on workspace 3
- **THEN** it is only visible on workspace 3 and not on other workspaces

### Requirement: C-2 Graceful handling of yabai unavailability

The system MUST handle yabai being temporarily unavailable without crashing, because yabai restarts after macOS updates, and loss of yabai must not destroy in-session stickies.

#### Scenario: Yabai goes down during session

- **WHEN** yabai becomes unavailable while the app is running
- **THEN** the app does not crash, existing stickies are preserved, and a structured error is surfaced for commands requiring yabai

### Requirement: C-3 Session-scoped in-memory data only

The system MUST scope MVP data to the session (in-memory only, no disk persistence), because yabai space IDs are unstable across reboots, making cross-restart reconciliation unreliable without dedicated design effort.

#### Scenario: App restart clears all state

- **WHEN** the app is restarted
- **THEN** all stickies and canvas layout are cleared

### Requirement: C-4 macOS Ventura 13.0+ minimum support

The system MUST support macOS Ventura 13.0 or later, because this is the minimum version supporting the required NSPanel behaviors and yabai compatibility.

#### Scenario: App runs on macOS 13.0+

- **WHEN** the app is launched on macOS 13.0 or later
- **THEN** all features function correctly

### Requirement: C-5 Single-display MVP with explicit multi-display mode

The system MUST assume a single-display configuration for MVP; on multi-display setups the app MUST enter Single-Display Mode bound to the primary display and return structured unsupported-mode errors for non-primary-display contexts, because multi-display Space management introduces orthogonal complexity.

#### Scenario: Multi-display detected at startup

- **WHEN** the app starts with multiple displays connected
- **THEN** it enters Single-Display Mode, binds to the primary display, and sets a warning state

#### Scenario: Command from non-primary display context

- **WHEN** a command targets a workspace on a non-primary display
- **THEN** the system returns a structured `.unsupportedMode` error instead of a generic error

### Requirement: C-6 Fully local with no network calls or telemetry

The system MUST remain fully local with no outbound network calls and no telemetry, because this is a personal productivity utility handling sensitive in-progress work context.

#### Scenario: No outbound network during operation

- **WHEN** the app is running and performing all core workflows
- **THEN** zero outbound network connections are made

### Requirement: C-7 Actionable failure for missing prerequisites

The system MUST fail gracefully with actionable remediation steps when system prerequisites (Accessibility permission, Keyboard Maestro wiring, or yabai availability) are missing, because onboarding friction is expected and silent failure would feel like data loss.

#### Scenario: Missing Accessibility permission

- **WHEN** the app launches without Accessibility permission granted
- **THEN** it provides an actionable error message explaining how to enable it

#### Scenario: Yabai not installed or not running

- **WHEN** the app launches and yabai is not available
- **THEN** it provides an actionable error message with remediation steps

### Requirement: C-8 Scoped degradation when yabai capabilities are unavailable

The system MUST probe yabai capabilities on startup and degrade per-capability rather than treating yabai as all-or-nothing, because partial unavailability should only affect commands that need the missing capability while the rest keep working.

#### Scenario: Partial capability loss degrades specific commands

- **WHEN** workspace navigation is unavailable but workspace detection is available
- **THEN** navigation commands fail with structured errors while capture and orientation commands remain functional

#### Scenario: Status reports capability state

- **WHEN** user runs `stickyspaces status`
- **THEN** response includes which capabilities are available and any active warnings

### Requirement: C-9 Single-instance authority over socket and store

The system MUST enforce single-instance authority over the Unix socket and in-memory store; second launch attempts MUST fail safely with actionable output, because split-brain control planes can make stickies appear lost or uncontrollable.

#### Scenario: Second instance attempt is blocked

- **WHEN** a second instance of StickySpaces is launched
- **THEN** it exits with an actionable message including the PID of the running instance, without modifying socket state

### Requirement: NFR-8 Workspace switch responsiveness

The system SHALL update visible stickies within 150ms at p95 after a workspace switch, and converge workspace topology within 1s at p95, because orientation must feel instant and the system must self-correct even when OS notifications are delayed or missed.

#### Scenario: Stickies update within 150ms of workspace switch

- **WHEN** the user switches workspaces
- **THEN** the correct stickies are visible within 150ms at p95

#### Scenario: Rapid switching converges to correct state

- **WHEN** 100 rapid workspace switches occur
- **THEN** the final state converges to correct sticky visibility within 1s

### Requirement: C-10 Background agent with no Dock icon

The system MUST run as a background agent app with no Dock icon, a stable bundle identifier, and a fixed install path, because stickies are a background utility that should not compete for Dock space or confuse macOS permission prompts with changing identities.

#### Scenario: App does not appear in Dock

- **WHEN** the app is running
- **THEN** it does not appear in the macOS Dock

### Requirement: A-1 Display scope limited to primary display for MVP

The system MUST limit "all workspaces" scope to all Spaces on the primary display only for MVP, because multi-display Space management introduces per-display space sets, ambiguous "current workspace" semantics, and cross-display coordinate transforms that are orthogonal to the core product hypothesis.

#### Scenario: Only primary display spaces are tracked

- **WHEN** the app queries for all workspaces
- **THEN** only Spaces on the primary display are included in results

#### Scenario: Non-primary display spaces are excluded

- **WHEN** a Space exists on a secondary display
- **THEN** it does not appear in workspace listings, canvas, or sticky bindings

### Requirement: A-2 Navigation limited to sticky-click for MVP

The system MUST limit canvas navigation to sticky-click only for MVP, with region-click navigation explicitly out of scope, because sticky-click is the required FR-8 interaction and region-click is deferred to post-MVP polish.

#### Scenario: Sticky click navigates

- **WHEN** user clicks a sticky in the zoom-out canvas
- **THEN** the system navigates to that sticky's workspace

#### Scenario: Region click does not navigate

- **WHEN** user clicks an empty area of a workspace region in the canvas
- **THEN** no navigation occurs

### Requirement: A-3 Conservative workspace deletion safety for MVP

The system MUST implement conservative confirmation before hard-deleting stickies on workspace destruction, because transient topology inconsistencies could cause irreversible false-positive deletes.

#### Scenario: Deletion requires multi-snapshot confirmation

- **WHEN** a workspace disappears from topology
- **THEN** stickies are not hard-deleted until absence is confirmed across multiple successful snapshots separated by at least 2s with passing health checks

