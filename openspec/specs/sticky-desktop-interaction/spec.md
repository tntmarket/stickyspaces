## Purpose

Specifies how sticky notes interact with the macOS desktop — chromeless appearance, drag-to-reposition, in-place text editing, edge/corner resize, hover-reveal dismiss, GUI-to-store coherence, and workspace binding. Links to parent capability `core` (references D-3, D-6, C-1, FR-3, FR-4, FR-6) and PRD stories 1, 2, 5.

## Requirements

### Requirement: FR-DI-1 Chromeless Appearance

The system SHALL render each sticky without any window title bar, traffic-light buttons, or decorative chrome, using a borderless style mask, so that orientation is a glance with zero visual noise and the sticky reads as a note rather than an application window.

#### Scenario: Sticky renders without window chrome

- **WHEN** a sticky is created and displayed on the desktop
- **THEN** the panel has no title bar, no traffic-light close/minimize/zoom buttons, and no window-frame decoration

#### Scenario: Sticky uses borderless style mask

- **WHEN** the StickyPanel is initialized
- **THEN** its style mask is `[.borderless, .nonactivatingPanel]` with no `.titled`, `.closable`, or `.resizable` flags

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

### Requirement: C-DI-5 Consistency with Parent Spec

The system SHALL align its panel configuration with parent spec D-3 (default collectionBehavior for workspace binding) and D-6 (borderless, non-activating, floating), so that this spec implements within the architectural contract established by the parent spec.

#### Scenario: Panel uses default collectionBehavior

- **WHEN** a StickyPanel is created
- **THEN** its collectionBehavior is the default (empty) value, not `.canJoinAllSpaces`

#### Scenario: Panel uses borderless non-activating floating config

- **WHEN** a StickyPanel is created
- **THEN** it is configured as borderless, non-activating, and floating per parent spec D-6

### Requirement: D-DI-1 Single NSTrackingArea for Hover and Resize Cursor

The system SHALL install one NSTrackingArea with `.mouseEnteredAndExited`, `.mouseMoved`, `.activeAlways` on StickyContentView covering the full panel bounds, using mouseMoved to set resize cursors in edge/corner hot zones, mouseEntered to fade in the dismiss button, and mouseExited to fade it out. The `.activeAlways` flag SHALL be used so tracking works when the panel is not key.

#### Scenario: Resize cursor appears in edge hot zone

- **WHEN** the mouse moves over a 5pt edge/corner hot zone within the tracking area
- **THEN** the cursor changes to the appropriate resize cursor (horizontal, vertical, or diagonal)

#### Scenario: Cursor resets outside hot zones

- **WHEN** the mouse moves away from edge/corner hot zones but remains within the panel
- **THEN** the cursor resets to the default arrow

#### Scenario: Tracking works on non-key panel

- **WHEN** the panel is not key and the mouse enters the panel bounds
- **THEN** the dismiss button fade-in and cursor changes still fire because `.activeAlways` is set

### Requirement: D-DI-2 Custom Resize via Mouse Events

The system SHALL implement resize through custom mouse event handling in StickyContentView — detecting mouseDown within a 5pt edge/corner hot zone, capturing the initial frame and mouse position, tracking mouseDragged to compute the new frame, clamping to minimum size, and committing to the store on mouseUp — because borderless panels have no built-in resize handles.

#### Scenario: mouseDown in edge zone initiates resize

- **WHEN** the user presses the mouse within a 5pt inset from any edge or corner
- **THEN** the resize interaction begins, capturing the initial frame and mouse position

#### Scenario: mouseDragged updates the frame

- **WHEN** the user drags after initiating a resize
- **THEN** the panel frame updates continuously following the mouse delta, clamped to minimum size

#### Scenario: mouseUp commits the resize

- **WHEN** the user releases the mouse after resizing
- **THEN** the final size and position are committed to the store via the delegate

### Requirement: D-DI-3 DragStripView Reposition via mouseDown and mouseDragged

The system SHALL implement drag-strip repositioning by capturing the initial global mouse position and window origin on mouseDown, adjusting `window.setFrameOrigin()` by the delta on each mouseDragged, and committing position on mouseUp. The system SHALL NOT use `performDrag(with:)` because it triggers window-server behaviors incompatible with non-activating panels.

#### Scenario: Drag strip captures initial state on mouseDown

- **WHEN** the user presses the mouse within the drag strip
- **THEN** the initial global mouse position and window origin are captured

#### Scenario: Window follows mouse during drag

- **WHEN** the user drags after pressing in the drag strip
- **THEN** the window origin is adjusted by the mouse delta on each mouseDragged event

#### Scenario: Position committed on mouseUp

- **WHEN** the user releases the mouse after dragging
- **THEN** the final position is committed to the store via the delegate callback

### Requirement: D-DI-4 Text Change Debounce with Flush on Focus Loss

The system SHALL observe NSText.didChangeNotification on StickyTextView and reset a 500ms DispatchWorkItem timer on each notification. When the timer fires, the current text SHALL be committed via the delegate. If the text view resigns first responder (textDidEndEditing), any pending timer SHALL be cancelled and the current text SHALL be flushed immediately, so that no edits are lost when the user clicks away.

#### Scenario: Debounce timer resets on each keystroke

- **WHEN** the user types a character while a debounce timer is pending
- **THEN** the existing timer is cancelled and a new 500ms timer is started

#### Scenario: Timer fires and commits text

- **WHEN** the 500ms debounce timer fires
- **THEN** the current text content is committed to the store via the delegate

#### Scenario: Focus loss flushes pending text

- **WHEN** the text view resigns first responder while a debounce timer is pending
- **THEN** the pending timer is cancelled and the current text is flushed to the store immediately

### Requirement: D-DI-5 Immediate Text Focus on Creation

The system SHALL call `panel.makeKeyAndOrderFront(nil)` followed by `panel.makeFirstResponder(textView)` when a new sticky is created, so that typing starts immediately. When created with `--text`, the cursor SHALL be placed at the end of the pre-filled text. This satisfies parent spec FR-3.

#### Scenario: New sticky receives text focus immediately

- **WHEN** `AppKitPanelRegistry.show(sticky:)` creates a new panel
- **THEN** the text view is the first responder and the panel is key, allowing immediate typing

#### Scenario: Pre-filled text places cursor at end

- **WHEN** a sticky is created with `--text "some content"`
- **THEN** the cursor is positioned at the end of "some content" in the text view

### Requirement: D-DI-6 Default collectionBehavior for Workspace Binding

The system SHALL remove `.canJoinAllSpaces` and use the default (empty) collectionBehavior so that macOS automatically binds the panel to its creator Space. If validation fails with the borderless configuration, the system SHALL fall back to the ManualVisibility strategy — explicit orderFront/orderOut keyed by WorkspaceMonitor's current WorkspaceID. This satisfies parent spec D-3.

#### Scenario: Panel uses default collectionBehavior

- **WHEN** a StickyPanel is created
- **THEN** its collectionBehavior is empty (default), not `.canJoinAllSpaces`

#### Scenario: Fallback to ManualVisibility if default fails

- **WHEN** Phase 1 revalidation determines that default collectionBehavior does not correctly bind the borderless panel to its creator Space
- **THEN** the system falls back to ManualVisibility strategy using explicit orderFront/orderOut keyed by WorkspaceID
