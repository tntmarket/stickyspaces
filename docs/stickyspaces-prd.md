# Product Requirements Document: StickySpaces

**Version**: 1.0
**Date**: 2026-02-26
**Quality Score**: 90/100

---

## Executive Summary

StickySpaces is a native macOS application that places persistent, chrome-less floating sticky notes on each workspace, letting users declare and see their current intentions at a glance. It is designed for users with ADHD or limited working memory who frequently encounter valuable "side-quests" while working on a main task, but struggle to explore them without losing track of their original goal.

When a user lands on a workspace, the sticky immediately answers "What am I doing here?" — no reconstruction needed. When they need the big picture, a zoom-out animation shrinks the current sticky cluster into a canvas showing all workspaces and their stickies, with free-form arrangement. Post-MVP, users can draw lines between stickies to build a graph of task relationships.

The core promise: **explore freely, retreat safely, never lose your place.**

---

## Problem Statement

**Current Situation**: See [The Side-Quest Trilemma — Problem Brief](sidequest-trilemma-problem-brief.md) for the full problem statement, user profile, and success metrics.

**Proposed Solution**: Persistent floating sticky notes per workspace that provide instant orientation, combined with a zoom-out aggregate view that shows the big picture across all workspaces and enables spatial navigation between them.

**Business Impact**: Users sustain progress on more concurrent tasks without cognitive overload, because orientation is a glance (read the sticky) and navigation is spatial (click a sticky to jump to its workspace).

---

## Success Metrics

**Primary KPIs:**

- **Task capacity**: Sustaining progress on noticeably more concurrent tasks/side-quests than today's 2-3 workspace limit before cognitive overload
- **Focus depth**: Side-quest exploration feels "free" rather than anxious — no background hum of "don't forget the original task"
- **Context-switch quality**: Returning to a task feels like picking up exactly where you left off

**Validation**: Self-reported assessment after 2 weeks of daily use. The user will know if it's working.

---

## User Personas

### Primary: ADHD Developer

- **Role**: Software developer and knowledge worker on macOS
- **Goals**: Juggle multiple interrelated tasks and side-quests without losing track of any. Explore freely without anxiety about forgetting the original goal.
- **Pain Points**: Limited working memory exhausted by holding task relationships in their head. macOS Mission Control's flat workspace row provides no orientation or relationship context. Context-switching is cognitively expensive.
- **Technical Level**: Advanced — comfortable with developer tools, yabai, Keyboard Maestro, macOS power-user workflows.
- **Cognitive Profile**: Strong spatial memory — remembers things well when keyed by location or structure. Struggles with abstract, unanchored task lists.

---

## User Stories & Acceptance Criteria

### Story 1: Create a Sticky — "Here's What I'm Doing"

**As a** knowledge worker starting a task in a workspace
**I want to** create a floating sticky note declaring my intention
**So that** when I return to this workspace later, I instantly know what I was doing

**Acceptance Criteria:**

- A hotkey creates a new sticky note on the current workspace
- The sticky appears as a chrome-less (no title bar) floating panel
- The sticky stays above application windows but below system UI
- The sticky is editable — the user types their intention directly
- The sticky lives for the duration of the app session (no cross-restart persistence in MVP — see Risk Assessment for rationale)
- The sticky is bound to its workspace and only visible when that workspace is active
- Multiple stickies can exist on a single workspace

### Story 2: Orient — "What Am I Doing Here?"

**As a** knowledge worker who just switched to a workspace after a break or interruption
**I want to** immediately see my declared intentions
**So that** re-orienting is a glance, not an effortful reconstruction

**Acceptance Criteria:**

- When switching to a workspace, its stickies are already visible — no action required
- Stickies are readable at a glance: clear text, minimal visual noise
- Stickies don't obscure critical areas of the screen (user can reposition them)
- Sticky positions within a workspace are persistent — they stay where you put them

### Story 3: Zoom Out — "Show Me the Big Picture"

**As a** knowledge worker juggling several tasks across workspaces
**I want to** see all my stickies across all workspaces in one view
**So that** I can understand the full landscape of my work and navigate between tasks

**Acceptance Criteria:**

- A hotkey triggers the zoom-out from the current workspace
- The current workspace's stickies animate — shrinking in place — to reveal the aggregate canvas
- Each workspace appears as a bordered region containing its stickies, with stickies preserving their relative positions from the workspace view
- Workspace regions can be freely arranged on the canvas (drag to reposition)
- The workspace arrangement is persistent across zoom-out invocations
- The currently active workspace is visually highlighted

### Story 4: Navigate — "Take Me There"

**As a** knowledge worker viewing the zoomed-out canvas
**I want to** click a sticky to jump to its workspace
**So that** I never have to remember which numbered workspace holds which task

**Acceptance Criteria:**

- Clicking a sticky in the zoomed-out view navigates to its workspace
- The view animates — zooming into the clicked workspace's sticky cluster — and the workspace becomes active
- The transition feels like the inverse of the zoom-out: smooth, continuous, spatial

### Story 5: Dismiss — "I'm Done With This"

**As a** knowledge worker who finished a task
**I want to** close the sticky and have it disappear
**So that** completed work doesn't clutter my view

**Acceptance Criteria:**

- Closing a sticky (e.g., clicking a small dismiss control) deletes it immediately
- When a workspace is destroyed, all stickies in it are deleted
- Deleted stickies are gone — no archive, no history

---

## Functional Requirements

### Core Features

**Feature 1: Sticky Notes**

- Description: Session-scoped, chrome-less floating panels bound to a specific macOS workspace. Each sticky stores: text content, position (x, y within the workspace), dimensions, the workspace (yabai space ID) it belongs to, and creation timestamp.
- User flow: User presses hotkey → a new sticky appears at a default position → user types their intention → sticky auto-saves in memory. User can reposition by dragging. User can resize by dragging edges.
- Appearance: No window title bar. Minimal — a colored rectangle with text. Lightweight enough that having 3-5 per workspace doesn't feel cluttered.
- Data persistence (MVP): Stickies live in memory for the app session only. No cross-restart persistence — workspace identity (yabai space IDs) is unstable across reboots and workspace reorganization, making reliable reconciliation a non-trivial design problem (see Risk Assessment). Persistence is deferred to a future phase where it can be solved deliberately.
- Edge cases: If the user creates a sticky on a workspace that yabai doesn't recognize, the sticky is associated with the "current" workspace at creation time.

**Feature 2: Zoom-Out Aggregate View**

- Description: A full-screen canvas that shows all workspaces and their stickies in a spatial layout. Each workspace is a bordered region containing its stickies at their relative positions, scaled down.
- User flow: User presses zoom-out hotkey → current workspace's stickies animate (shrink and pull back) → full canvas appears with all workspace clusters → user can drag workspace regions to rearrange → user clicks a sticky or workspace to navigate → canvas animates (zooms into target) and switches workspace.
- Zoom-out animation: The stickies on the current workspace shrink in place, transitioning smoothly into their smaller representation on the canvas. Other workspace clusters fade in around them. The effect should feel like pulling back a camera.
- Zoom-in animation: Clicking a sticky reverses the animation — the canvas zooms into the target workspace cluster, stickies scale up to full size, and the target workspace becomes active.
- Canvas persistence (MVP): Workspace positions on the canvas are held in memory for the session. Disk persistence deferred alongside sticky persistence.
- Edge cases: If a workspace has no stickies, it still appears on the canvas as an empty bordered region (so the user knows it exists). If a new workspace is created, it appears at a default position on the canvas.

**Feature 3: Dismiss**

- Description: Stickies can be individually dismissed or bulk-dismissed when their workspace is destroyed.
- Closing a sticky: A small dismiss affordance (e.g., a subtle X that appears on hover) deletes the sticky.
- Workspace destruction: When yabai reports a space has been destroyed, all stickies associated with that space are deleted.

### Out of Scope (MVP)

- Drawing lines/connections between stickies (graph building) — Phase 3
- Merging workspaces
- Dragging stickies between workspaces from the overview
- Rich text or markdown in stickies
- Sticky color coding or tagging
- Search across stickies
- Archived sticky browser/history view
- Configurable hotkeys (UI for remapping)
- Templates or pre-filled stickies

---

## Technical Constraints

### Performance

- Sticky creation must be instantaneous (<100ms from hotkey to visible panel)
- Zoom-out animation must complete within 300-500ms — fast enough to feel responsive, slow enough to be legible
- Zoom-in (navigate) animation: same 300-500ms range
- Memory footprint should stay under 30MB for typical usage (5-10 workspaces, 1-5 stickies each)

### Security

- The app requires macOS Accessibility permissions (for global hotkey capture and yabai communication)
- No network access required — fully local, no telemetry
- MVP: all data in-memory only, nothing written to disk. Future persistence will use local JSON files in `~/.config/stickyspaces/` or Application Support

### Integration

- **yabai**: Primary integration for workspace management. Required for: detecting the current Space, switching Spaces on navigation, detecting Space creation/destruction, querying which Space a window belongs to. The app shells out to yabai CLI and parses JSON output. Must handle yabai being temporarily unavailable.
- **macOS Spaces**: yabai operates on native macOS Spaces. The app must stay in sync with actual Space state. On launch and on each zoom-out, the app reconciles its persisted sticky-workspace associations with yabai-reported spaces.
- **Keyboard Maestro (transitional)**: In MVP, global hotkeys can be wired via Keyboard Maestro calling the app's CLI interface. Commands: `stickyspaces new`, `stickyspaces zoom-out`. Post-MVP, the app registers its own global hotkeys natively.

### Technology Stack

- **Language**: Swift
- **UI Framework**: AppKit (NSPanel for chrome-less stickies, NSVisualEffectView for vibrancy if desired)
- **Animation**: Core Animation for zoom-out/zoom-in transitions
- **Global Hotkeys**: Initially via Keyboard Maestro → CLI; post-MVP via native CGEvent hotkey registration
- **yabai Communication**: Shell-out to yabai CLI, parsing JSON output
- **Data Persistence (MVP)**: In-memory only. Disk persistence (JSON via Codable) deferred pending workspace identity reconciliation design
- **Build**: Xcode / Swift Package Manager
- **Minimum macOS**: Ventura 13.0+

---

## MVP Scope & Phasing

### Phase 1: Per-Workspace Stickies (Milestone 1)

- Chrome-less floating sticky notes bound to workspaces
- Create, edit, reposition, resize stickies
- Session-scoped (in-memory only — no cross-restart persistence)
- Multiple stickies per workspace
- Close-to-dismiss behavior
- CLI interface for Keyboard Maestro integration (`stickyspaces new`)

**Milestone 1 Definition**: The minimum that delivers value — intention labels on workspaces within a session. This alone solves orientation ("What am I doing here?") by making every workspace self-documenting.

### Phase 2: Zoom-Out Aggregate View (Milestone 2)

- Full-screen canvas showing all workspace clusters
- Zoom-out animation from current workspace
- Zoom-in / click-to-navigate to any workspace
- Free-form workspace arrangement on canvas
- Session-scoped canvas layout (in-memory)
- CLI command: `stickyspaces zoom-out`

**Milestone 2 Definition**: Adds the big-picture view and spatial navigation. Together with Milestone 1, this covers orientation + navigation — the two core needs from the problem brief.

### Phase 3: Graph Connections

- Draw lines between stickies to visualize task relationships
- Lines visible in the zoomed-out canvas view
- Line persistence across restarts
- Delete/edit connections

### Phase 4: Cross-Workspace Operations

- Drag stickies between workspaces from the overview
- Merge workspaces (combine stickies and windows)
- Native global hotkey registration (replace Keyboard Maestro dependency)

### Future Considerations

- Cross-restart persistence with workspace reconciliation
- Sticky color coding and tagging
- Search across current and archived stickies
- Archived sticky browser / history timeline
- Rich text or markdown support in stickies
- Integration with task management tools (JIRA, Linear, Todoist)
- Workspace templates with pre-filled stickies

---

## Risk Assessment


| Risk                                                                              | Probability | Impact | Mitigation                                                                                               |
| --------------------------------------------------------------------------------- | ----------- | ------ | -------------------------------------------------------------------------------------------------------- |
| yabai API changes or breaks after macOS update                                    | Medium      | High   | Pin yabai version, abstract yabai calls behind an adapter layer, monitor yabai releases                  |
| Chrome-less NSPanel doesn't feel native or behaves unexpectedly across Spaces     | Medium      | High   | Prototype early with `NSPanel` + `.nonactivatingPanel` + borderless style; test across Space transitions |
| Zoom-out animation performance with many stickies (e.g., 30+)                     | Low         | Medium | Profile with Core Animation instruments; simplify rendering for large counts (reduce shadows, blur)      |
| Sticky-to-workspace association drifts (yabai space IDs change on reboot)         | High        | High   | MVP avoids this entirely by keeping stickies session-scoped. Cross-restart persistence deferred until a reliable reconciliation strategy is designed (candidates: user-driven reassignment on reload, content-based workspace matching via window titles, or stable workspace identifiers if yabai provides them) |
| Users expect drag-between-workspaces in MVP (natural affordance in zoom-out view) | Medium      | Low    | Clearly communicate phasing; make workspace borders non-interactive in MVP zoom-out                      |
| Accessibility permissions friction                                                | High        | Low    | Clear onboarding flow explaining why permissions are needed, with deep link to System Preferences        |


---

## Dependencies & Blockers

**Dependencies:**

- **yabai**: Must be installed and running with Spaces integration enabled. Required for workspace detection, switching, and lifecycle events.
- **macOS Accessibility permissions**: Required for global hotkey capture (post-MVP) and potentially for window querying.
- **Keyboard Maestro (MVP only)**: Used as the hotkey layer in MVP. Users must configure macros that call the `stickyspaces` CLI.

**Known Blockers:**

- None identified. yabai is already installed and functional in the user's environment.

---

## Appendix

### Glossary

- **Space**: A macOS virtual desktop (workspace), managed by Mission Control and programmable via yabai.
- **yabai**: A tiling window manager for macOS that provides CLI control over windows and spaces.
- **Sticky**: A persistent, chrome-less floating note bound to a specific workspace, declaring the user's intention or task context for that workspace.
- **Zoom-out**: The animated transition from a single workspace's sticky view to the full aggregate canvas showing all workspaces.
- **Canvas**: The aggregate view showing all workspaces and their stickies in a spatial, free-form layout.
- **Archive**: Removing a sticky from the active view while retaining its data on disk for potential future reference.
- **Reconciliation**: The process of syncing the app's persisted sticky-workspace associations with the actual state of macOS Spaces as reported by yabai.
- **Side-quest**: A tangential task discovered during work on a main task that feels valuable to explore but risks derailing the original focus.

### Related Documents

- [The Side-Quest Trilemma — Problem Brief](sidequest-trilemma-problem-brief.md)
- [SpaceTree PRD](spacetree-prd.md) — alternative solution using tree-structured workspace navigation

### References

- [yabai documentation](https://github.com/koekeishiya/yabai/wiki)
- [NSPanel documentation](https://developer.apple.com/documentation/appkit/nspanel)
- [Core Animation Programming Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreAnimation_guide/)
- macOS Mission Control & Spaces documentation

