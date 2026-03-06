## Purpose

Daemon event loop architecture ensuring NSApplication RunLoop and async IPC coexist without deadlock. The daemon must process AppKit UI events and Swift `@MainActor` continuations from IPC handlers simultaneously by using a synchronous `main()` entry point. Parent capability: `cli-interface` (references CLI-FR-4, CLI-NFR-1).

## Requirements

### Requirement: DEL-FR-1 IPC commands complete within round-trip budget

The system SHALL deliver responses for CLI commands that create or manipulate panels (e.g., `stickyspaces new`) within the parent spec's round-trip budget, because the current deadlock causes the CLI to hang indefinitely, making the product unusable.

#### Scenario: CLI create command receives daemon response

- **WHEN** a CLI create command is sent to a running daemon
- **THEN** the daemon responds within the round-trip budget (< 200ms) without hanging

#### Scenario: Concurrent IPC commands are processed

- **WHEN** multiple CLI commands are issued in quick succession
- **THEN** each command receives a response within the round-trip budget

### Requirement: DEL-FR-2 Panels respond to user interaction during IPC

The system SHALL keep sticky panels responsive to user interaction (drag, resize, type, dismiss) while the daemon is simultaneously serving IPC commands, because panels that appear but ignore input are worse than no panels — the user sees the note but cannot act on it.

#### Scenario: Panel drag while IPC command is in flight

- **WHEN** a user drags a sticky panel while a CLI command is being processed
- **THEN** the panel follows the cursor without freezing or dropping frames

#### Scenario: Panel dismiss while daemon is idle

- **WHEN** a user dismisses a sticky panel via its close button
- **THEN** the panel closes immediately without waiting for any IPC activity

### Requirement: DEL-NFR-1 Near-zero CPU usage when idle

The system SHALL consume near-zero CPU when idle (no user interaction, no IPC in flight), because the daemon is a long-running background process for the entire work session and gratuitous wake-ups drain laptop battery. The event loop MUST NOT use polling or periodic sleep-wake loops.

#### Scenario: Daemon idle for extended period

- **WHEN** the daemon has no pending IPC commands and no user interaction for 60 seconds
- **THEN** the process shows near-zero CPU usage with no periodic wake-ups


