## Purpose

Specifies how sticky notes interact with the macOS desktop — chromeless appearance, drag-to-reposition, in-place text editing, edge/corner resize, hover-reveal dismiss, GUI-to-store coherence, and workspace binding. Links to parent capability `core` (references C-1, FR-3, FR-4, FR-6) and PRD stories 1, 2, 5.

## Requirements

### Requirement: FR-DI-1 Chromeless Appearance

The system SHALL render each sticky without any window title bar, traffic-light buttons, or decorative chrome, using a borderless style mask, so that orientation is a glance with zero visual noise and the sticky reads as a note rather than an application window.

#### Scenario: Sticky renders without window chrome

- **WHEN** a sticky is created and displayed on the desktop
- **THEN** the panel has no title bar, no traffic-light close/minimize/zoom buttons, and no window-frame decoration

### Requirement: FR-DI-2 Repositioning via Drag Strip

The system SHALL allow the user to reposition a sticky by dragging its top strip (~16pt zone), persisting the new position to the store on mouseUp, so that stickies do not obscure critical content and the drag affordance coexists with text editing without ambiguity.

#### Scenario: Drag strip moves the sticky

- **WHEN** the user presses and drags within the top 16pt drag strip
- **THEN** the sticky window follows the mouse movement and the new position is committed to the store on mouseUp

#### Scenario: Position is queryable after drag

- **WHEN** the user completes a drag-strip reposition
- **THEN** `stickyspaces get` returns the updated position coordinates

### Requirement: FR-DI-3 In-place Editing with Auto-Persist

The system SHALL allow the user to edit sticky text by clicking directly in the text area, with changes automatically persisted to the store via debounced callbacks, so that note updates require zero CLI round-trips and honor the zero-friction capture promise.

#### Scenario: Clicking text area enables editing

- **WHEN** the user clicks in the text area of a sticky
- **THEN** the text view becomes the first responder and accepts keyboard input

#### Scenario: Text changes are debounced and persisted

- **WHEN** the user types in the text area and pauses for 500ms
- **THEN** the current text is committed to the store via the delegate callback

#### Scenario: Pending text flushes on focus loss

- **WHEN** the user clicks away from the text area while edits are pending
- **THEN** the pending text is flushed to the store immediately without waiting for the debounce timer

### Requirement: FR-DI-4 Free Resize via Edge and Corner Drag

The system SHALL allow the user to resize a sticky by dragging its edges or corners, persisting the new size to the store, so that different workflows with varying text amounts are accommodated without wasting screen space or hiding content.

#### Scenario: Edge drag resizes the sticky

- **WHEN** the user drags a 5pt edge hot zone
- **THEN** the sticky resizes in that direction and the new size is committed to the store on mouseUp

#### Scenario: Corner drag resizes in two directions

- **WHEN** the user drags a corner hot zone
- **THEN** the sticky resizes in both directions simultaneously and the new size and position are committed to the store

### Requirement: FR-DI-5 Intentional Dismiss via Hover-Reveal Close Button

The system SHALL provide a close button that appears only on mouse hover, allowing the user to dismiss a sticky intentionally, so that completed tasks can be cleared without risking accidental context loss from irreversible dismissal.

#### Scenario: Dismiss button hidden by default

- **WHEN** the mouse is outside the sticky panel
- **THEN** the dismiss button has alphaValue 0 and is not visible

#### Scenario: Dismiss button appears on hover

- **WHEN** the mouse enters the sticky panel bounds
- **THEN** the dismiss button fades in to alphaValue 1.0 within ~150ms

#### Scenario: Clicking dismiss removes the sticky

- **WHEN** the user clicks the dismiss button
- **THEN** the sticky is removed from the panel registry, the store is updated, and `stickyspaces list` no longer includes that sticky

### Requirement: FR-DI-6 GUI-Store Coherence

The system SHALL reflect all GUI-initiated changes (text, position, size) in the StickyStore such that they are queryable via CLI read commands (`get`, `list`, `verify-sync`), so that the CLI/IPC API remains the programmatic source of truth and divergence between GUI and API is prevented.

#### Scenario: GUI text edit reflected in CLI

- **WHEN** the user edits text via the GUI and the debounce timer fires
- **THEN** `stickyspaces get` returns the updated text

#### Scenario: GUI reposition reflected in CLI

- **WHEN** the user repositions a sticky via drag
- **THEN** `stickyspaces get` returns the updated position

#### Scenario: verify-sync passes after GUI edits

- **WHEN** the user makes text, position, or size changes via the GUI
- **THEN** `stickyspaces verify-sync` reports all stickies as synced with no mismatches

### Requirement: FR-DI-7 Workspace Binding

The system SHALL ensure each sticky is visible only on the macOS Space where it was created, so that stickies answer "what am I doing HERE" rather than appearing generically on every Space, preserving the per-workspace orientation model.

#### Scenario: Sticky visible only on creator Space

- **WHEN** a sticky is created on Space A and the user switches to Space B
- **THEN** the sticky is not visible on Space B

#### Scenario: Sticky reappears on return to creator Space

- **WHEN** the user switches back to Space A
- **THEN** the sticky is visible again

### Requirement: NFR-DI-1 Position and Size Sync Latency

The system SHALL reflect position and size changes in the store within 100ms of mouseUp, so that `stickyspaces get` and `verify-sync` return current state for reliable E2E testing and automation.

#### Scenario: Position persisted within latency budget

- **WHEN** the user completes a drag-strip reposition (mouseUp)
- **THEN** the store contains the updated position within 100ms

#### Scenario: Size persisted within latency budget

- **WHEN** the user completes a resize operation (mouseUp)
- **THEN** the store contains the updated size within 100ms

### Requirement: NFR-DI-2 Text Sync Debounce

The system SHALL debounce GUI text changes and commit them to the store within 500ms of the last keystroke, so that per-keystroke store writes are avoided while ensuring CLI reads are never stale in practice.

#### Scenario: Text committed after 500ms debounce

- **WHEN** the user types in the text area and stops typing
- **THEN** the text is committed to the store within 500ms of the last keystroke

#### Scenario: Rapid keystrokes reset debounce timer

- **WHEN** the user types continuously
- **THEN** no store write occurs until 500ms after the final keystroke

### Requirement: C-DI-1 Non-Activating Interaction

The system SHALL ensure that dragging, resizing, dismissing, and text editing initiation do not activate the StickySpaces application or steal focus from the frontmost application, except when the user clicks into the text area to type (which inherently requires key window status), so that the sticky remains a passive orientation aid.

#### Scenario: Drag does not activate the app

- **WHEN** the user drags the sticky via the drag strip while another application is frontmost
- **THEN** the other application remains frontmost and StickySpaces does not become the active application

#### Scenario: Resize does not activate the app

- **WHEN** the user resizes the sticky via edge/corner drag while another application is frontmost
- **THEN** the other application remains frontmost

#### Scenario: Text click makes panel key but not app active

- **WHEN** the user clicks the text area to begin typing
- **THEN** the panel becomes key (to receive keystrokes) but StickySpaces does not become the frontmost application

### Requirement: C-DI-2 Dismiss Only via Hover-Reveal X

The system SHALL provide the hover-reveal X as the sole GUI dismiss mechanism — no keyboard shortcut, swipe gesture, or traffic-light button — so that accidental dismissal is prevented since it causes irreversible context loss in MVP.

#### Scenario: Escape key does not dismiss

- **WHEN** the user presses Escape while a sticky is focused
- **THEN** the sticky is not dismissed

#### Scenario: No traffic-light close button exists

- **WHEN** a sticky is displayed
- **THEN** no standard macOS close button is present in the window chrome

### Requirement: C-DI-3 Readability Baseline

The system SHALL meet parent spec NFR-6: minimum 14pt effective text size, high-contrast foreground/background, and no decorative chrome, so that re-orientation succeeds without squinting or parsing visual noise after context switches.

#### Scenario: Text meets minimum size

- **WHEN** a sticky is rendered with default settings
- **THEN** the text is displayed at a minimum of 14pt effective font size

#### Scenario: High contrast foreground and background

- **WHEN** a sticky is rendered
- **THEN** the text foreground and background colors provide high contrast sufficient for readability

### Requirement: C-DI-4 Minimum Size Enforcement

The system SHALL enforce a minimum sticky size of 120pt x 80pt during resize, so that stickies never become too small to read text or reach the dismiss button.

#### Scenario: Resize clamped at minimum width

- **WHEN** the user attempts to resize a sticky below 120pt width
- **THEN** the width is clamped to 120pt

#### Scenario: Resize clamped at minimum height

- **WHEN** the user attempts to resize a sticky below 80pt height
- **THEN** the height is clamped to 80pt

### Requirement: C-DI-5 Consistency with parent spec panel contract

The system SHALL configure panels as chromeless, non-activating, floating, and bound to a single workspace, consistent with the parent spec (C-1), so that stickies feel like notes rather than application windows.

#### Scenario: Panel is chromeless, non-activating, and floating

- **WHEN** a StickyPanel is created
- **THEN** it is borderless, floats above application windows, and does not activate the StickySpaces app

#### Scenario: Panel stays on its creator workspace

- **WHEN** a StickyPanel is created on a specific workspace
- **THEN** it is visible only on that workspace, not on all workspaces


