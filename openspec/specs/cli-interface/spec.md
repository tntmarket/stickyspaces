## Purpose

CLI interface and daemon lifecycle for StickySpaces: defines the client-server IPC transport layer that routes commands from short-lived CLI processes to a long-lived daemon over a Unix socket, with lazy daemon startup, instance locking, and signal-safe cleanup.

- **Parent capability**: `core` (references core D-1, C-9, NFR-1, NFR-4)
- **Upstream PRD**: [StickySpaces PRD](docs/stickyspaces-prd.md)

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

### Requirement: CLI-NFR-2 Daemon startup completes under 3 seconds

The system SHALL complete daemon startup (spawn + bind socket + ready for connections) in under 3 seconds — because this is the one-time cost on first use, and anything longer than a few seconds feels broken after pressing a hotkey.

#### Scenario: First-use daemon startup is fast
- **WHEN** the CLI spawns the daemon for the first time
- **THEN** the daemon binds the socket and accepts connections within 3 seconds of the spawn

### Requirement: CLI-NFR-3 New CLI command requires at most two file changes

The system SHALL ensure that adding a new CLI command requires changes in at most two files (arg-to-`IPCRequest` translation + response formatting) — because the parent spec (core NFR-4) promises new commands in under 1 hour, and the transport layer must not add friction to that.

#### Scenario: Adding a hypothetical new command touches minimal files
- **WHEN** a developer adds a new CLI command (e.g., `stickyspaces archive`)
- **THEN** the only files that need changes are the arg-to-IPCRequest translation and the response formatter — no transport layer changes are required

### Requirement: CLI-NFR-4 Existing in-process test path remains unchanged

The system SHALL preserve the existing `StickySpacesCLICommandRunner.run(args:app:)` test path without modification — because 10 CLI integration tests and 7 IPC integration tests depend on it, and breaking them would be a regression with no product value.

#### Scenario: Existing test suites pass after transport layer is added
- **WHEN** the socket transport layer is implemented
- **THEN** all existing `CLIWorkflowTests` and `IPCWorkflowTests` continue to pass without any changes to test code or the `StickySpacesCLICommandRunner` interface

### Requirement: CLI-C-1 IPC transport uses Unix domain socket at well-known path

The system MUST use a Unix domain socket at `~/.config/stickyspaces/sock` for IPC transport — because the parent spec (core D-1) already defines this path, and `IPCServer`, `IPCWireCodec`, `IPCRequest`/`IPCResponse` are all built around newline-delimited JSON over this socket.

#### Scenario: Server binds to the canonical socket path
- **WHEN** the daemon starts
- **THEN** it creates and binds a Unix domain socket at `~/.config/stickyspaces/sock`

#### Scenario: Client connects to the canonical socket path
- **WHEN** the CLI client needs to communicate with the daemon
- **THEN** it connects to `~/.config/stickyspaces/sock`

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

### Requirement: CLI-C-4 Daemon flag is internal not user-facing

The system MUST treat the `--daemon` flag as an internal mechanism, not a user-facing command — because exposing process management to users adds cognitive load that contradicts the "zero-friction capture" design goal.

#### Scenario: Help output does not advertise daemon flag
- **WHEN** a user runs `stickyspaces --help`
- **THEN** the `--daemon` flag is not listed in the help output

#### Scenario: Daemon flag is used only by DaemonLauncher
- **WHEN** the CLI needs to start a daemon
- **THEN** `DaemonLauncher` spawns `stickyspaces --daemon` internally, and the user never invokes it directly

### Requirement: CLI-D-1 Lazy daemon start rather than explicit serve command

The system MUST start the daemon lazily on first CLI use rather than requiring an explicit `serve` command — because this eliminates a manual setup step and preserves the Keyboard Maestro hotkey contract (press hotkey, sticky appears, no prerequisites). Satisfies CLI-FR-2.

#### Scenario: CLI probes socket and spawns daemon if absent
- **WHEN** a CLI invocation attempts to connect and no daemon socket exists
- **THEN** the CLI spawns `stickyspaces --daemon` as a detached background process and polls the socket at 50ms intervals until ready (up to 3 seconds)

#### Scenario: CLI skips spawn when daemon is already running
- **WHEN** a CLI invocation attempts to connect and the daemon socket is already connectable
- **THEN** the CLI proceeds directly to send the command without spawning a new daemon

### Requirement: CLI-D-2 Daemon is background instance of same binary

The system MUST run the daemon as a background instance of the same `stickyspaces` binary (via a `--daemon` flag) rather than a separate daemon binary — because reusing the same executable simplifies the build and means `DaemonLauncher` can resolve the executable path from `ProcessInfo`. Satisfies CLI-FR-2 and CLI-NFR-3.

#### Scenario: DaemonLauncher resolves executable path from ProcessInfo
- **WHEN** the CLI needs to spawn the daemon
- **THEN** it resolves the current executable path via `ProcessInfo.processInfo.arguments[0]` and spawns it with the `--daemon` flag appended

### Requirement: CLI-D-3 UnixSocketServer is thin transport adapter over IPCServer

The system MUST implement `UnixSocketServer` as a thin transport adapter that delegates all command handling to the existing `IPCServer.handleLine()` — because all command routing is already implemented in `IPCServer`, and this means adding a new command requires zero changes to the transport layer. Satisfies CLI-NFR-3.

#### Scenario: Socket server delegates lines to IPCServer
- **WHEN** the `UnixSocketServer` reads a newline-delimited JSON line from a client connection
- **THEN** it passes the line to `IPCServer.handleLine()` and writes the response back to the client

#### Scenario: New command requires no transport changes
- **WHEN** a new command is added to `IPCServer`
- **THEN** `UnixSocketServer` routes it automatically without any modifications to the socket layer

### Requirement: CLI-D-4 File-based instance lock prevents double daemon

The system MUST use a POSIX `flock()` file lock on `~/.config/stickyspaces/instance.lock` to prevent multiple daemon instances — because `flock()` is automatically released on process exit (including crashes and SIGKILL), so a stale lock file cannot permanently block daemon startup. Combined with stale-socket cleanup in `DaemonLauncher`, this handles all daemon lifecycle edge cases. Satisfies CLI-C-2 and CLI-C-3.

#### Scenario: Stale socket without lock is cleaned up
- **WHEN** a CLI invocation finds a socket file on disk but no `flock()` is held on the instance lock
- **THEN** `DaemonLauncher` unlinks the stale socket and spawns a fresh daemon

#### Scenario: Lock held prevents second daemon
- **WHEN** a second process attempts to acquire `flock()` on `instance.lock` while the first daemon holds it
- **THEN** the second process fails to acquire the lock and exits with an "already running" message

### Requirement: CLI-D-5 Preserve in-process DemoApp test path

The system MUST keep the `StickySpacesCLICommandRunner.run(args:app:)` in-process test path unchanged alongside the new `CLIClientRunner` socket-based path — because tests that exercise command semantics continue to use the fast in-process path, and only transport-level tests use actual sockets. Satisfies CLI-NFR-4.

#### Scenario: In-process tests remain functional
- **WHEN** the socket transport layer is added
- **THEN** `StickySpacesCLICommandRunner.run(args:app:)` continues to work identically, and all 10 CLI integration tests and 7 IPC integration tests pass without modification

#### Scenario: Two parallel execution paths coexist
- **WHEN** the system is fully implemented
- **THEN** `CLIClientRunner` handles real CLI usage via sockets, while `StickySpacesCLICommandRunner` handles in-process test execution — both paths coexist without interference
