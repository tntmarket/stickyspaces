## Purpose

CLI interface and daemon lifecycle for StickySpaces: defines the client-server transport that routes commands from short-lived CLI processes to a long-lived daemon, with lazy daemon startup, instance locking, signal-safe cleanup, and concurrent UI + IPC responsiveness.

- **Parent capability**: `core` (references core C-9, NFR-1, NFR-4)
- **Upstream PRD**: [StickySpaces PRD](../../changes/archive/2026-02-26-mvp-foundation/proposal.md)

## Requirements

### Requirement: CLI-FR-1 Commands take effect in persistent daemon

The system SHALL route any stickyspaces CLI command (e.g., `stickyspaces new --text "..."`) to a persistent daemon process so that the command takes effect in long-lived state — because today every invocation is ephemeral, making the CLI useless for actual work.

#### Scenario: User creates a sticky via CLI and it persists in the daemon
- **WHEN** a user runs `stickyspaces new --text "Project kickoff notes"`
- **THEN** the daemon receives the command, creates the sticky in its StickyStore, and returns a `.created` response with the sticky ID and workspace ID

#### Scenario: Sticky created via CLI is visible in subsequent list
- **WHEN** a user runs `stickyspaces new --text "Hello"` followed by `stickyspaces list`
- **THEN** the list output includes the text "Hello"

### Requirement: CLI-FR-2 Daemon starts automatically on first CLI invocation

The system SHALL start the daemon automatically on the first CLI invocation with no separate setup step — because requiring `stickyspaces serve` before `stickyspaces new` doubles the friction of a quick capture and breaks the Keyboard Maestro hotkey-to-action promise.

#### Scenario: First CLI command triggers daemon spawn
- **WHEN** a user runs `stickyspaces new --text "First note"` and no daemon is running
- **THEN** the CLI spawns the daemon in the background, waits for socket readiness, sends the command, and prints the result without the user needing to start the daemon manually

### Requirement: CLI-FR-3 Subsequent CLI invocations reuse running daemon

The system SHALL reuse the already-running daemon for subsequent CLI invocations — because creating a new in-memory universe per command means `list` can never show what `new` created.

#### Scenario: Second command reuses the same daemon
- **WHEN** a user runs `stickyspaces new --text "Note A"` (which starts the daemon) and then runs `stickyspaces new --text "Note B"`
- **THEN** both stickies exist in the same daemon's StickyStore, and `stickyspaces list` shows both

### Requirement: CLI-FR-4 Daemon creates real macOS floating windows

The system SHALL create real macOS floating windows (`NSPanel`) when stickies are created via the daemon — because the product promise is visible sticky notes on the desktop, not text printed to a terminal.

#### Scenario: Sticky creation produces a visible window
- **WHEN** the daemon processes a `new` command with text "Sprint planning"
- **THEN** an `NSPanel` floating window appears on the macOS desktop displaying the sticky content

### Requirement: CLI-FR-5 CLI prints actionable error on daemon start failure

The system SHALL print a clear, actionable error when the daemon cannot be started — because a silent failure after a hotkey press leaves the user confused about whether anything happened.

#### Scenario: Daemon launch timeout produces helpful error
- **WHEN** the CLI attempts to start the daemon but the socket does not become ready within the timeout period
- **THEN** the CLI prints an error message that includes the path to the daemon log file (`~/.config/stickyspaces/daemon.log`) so the user can diagnose the failure

### Requirement: CLI-FR-6 Daemon stays alive across CLI invocations

The system SHALL keep the daemon alive across CLI invocations until explicitly killed or the system shuts down — because stickies and their windows must persist for the duration of the work session (constraint C-3 in the parent spec).

#### Scenario: Daemon survives after CLI client disconnects
- **WHEN** a user runs `stickyspaces new --text "Persist me"` and the CLI process exits
- **THEN** the daemon process remains running and a subsequent `stickyspaces list` returns the previously created sticky

### Requirement: CLI-NFR-1 CLI round-trip completes under 200ms p95

The system SHALL complete a CLI command round-trip (client connect + send + receive + print) in under 200ms at the 95th percentile — because the Keyboard Maestro hotkey path adds ~50ms overhead, and the parent spec requires <100ms hotkey-to-visible-panel (core NFR-1), leaving ~50ms budget for socket overhead.

#### Scenario: Socket round-trip latency is within budget
- **WHEN** 100 sequential CLI commands are sent to a running daemon
- **THEN** at least 95 of them complete the full round-trip in under 200ms

#### Scenario: Concurrent commands are processed without hanging
- **WHEN** multiple CLI commands are issued in quick succession
- **THEN** each command receives a response within the round-trip budget

### Requirement: CLI-NFR-2 Daemon startup completes under 3 seconds

The system SHALL complete daemon startup (spawn + bind socket + ready for connections) in under 3 seconds — because this is the one-time cost on first use, and anything longer than a few seconds feels broken after pressing a hotkey.

#### Scenario: First-use daemon startup is fast
- **WHEN** the CLI spawns the daemon for the first time
- **THEN** the daemon binds the socket and accepts connections within 3 seconds of the spawn

### Requirement: CLI-C-2 At most one daemon process owns socket and store

The system MUST ensure at most one daemon process owns the socket and store at any time — because split-brain control planes make stickies appear lost or uncontrollable (parent spec core C-9).

#### Scenario: Second daemon attempt exits when lock is held
- **WHEN** a second `stickyspaces --daemon` process starts while the first daemon holds the instance lock
- **THEN** the second process prints "StickySpaces daemon is already running." to stderr and exits with code 1

### Requirement: CLI-C-3 Daemon cleans up socket and lock on termination

The system MUST clean up the socket file and lock on termination, including SIGINT and SIGTERM — because stale socket files prevent the next daemon from starting, requiring manual cleanup the user won't know how to do.

#### Scenario: SIGTERM causes socket file removal
- **WHEN** the daemon receives a SIGTERM signal
- **THEN** it unlinks the socket file at `~/.config/stickyspaces/sock` and the lock file before exiting

#### Scenario: SIGINT causes socket file removal
- **WHEN** the daemon receives a SIGINT signal (e.g., Ctrl+C)
- **THEN** it unlinks the socket file and lock file before exiting

### Requirement: CLI-FR-7 Panels remain responsive during IPC

The system SHALL keep sticky panels responsive to user interaction (drag, resize, type, dismiss) while the daemon is simultaneously serving IPC commands, because panels that appear but ignore input are worse than no panels — the user sees the note but cannot act on it.

#### Scenario: Panel drag while IPC command is in flight
- **WHEN** a user drags a sticky panel while a CLI command is being processed
- **THEN** the panel follows the cursor without freezing or dropping frames

#### Scenario: Panel dismiss while daemon is idle
- **WHEN** a user dismisses a sticky panel via its close button
- **THEN** the panel closes immediately without waiting for any IPC activity

### Requirement: CLI-NFR-3 Near-zero CPU usage when daemon is idle

The system SHALL consume near-zero CPU when idle (no user interaction, no IPC in flight), because the daemon is a long-running background process for the entire work session and gratuitous wake-ups drain laptop battery.

#### Scenario: Daemon idle for extended period
- **WHEN** the daemon has no pending IPC commands and no user interaction for 60 seconds
- **THEN** the process shows near-zero CPU usage with no periodic wake-ups

