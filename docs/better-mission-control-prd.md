# Product Requirements Document: Better Mission Control

**Version**: 1.0
**Date**: 2026-02-20
**Quality Score**: 91/100

---

## Executive Summary

Better Mission Control is a native macOS application that replaces the flat, one-dimensional workspace row of Mission Control with a spatial, tree-structured task navigator. It is designed for users with ADHD or limited working memory who frequently encounter valuable "side-quests" while working on a main task, but struggle to explore them without losing track of their original goal.

The app externalizes the mental "call stack" of tasks and sub-tasks into a persistent visual tree, displayed as a HUD overlay. Users can fork sub-tasks (spawning child workspaces), freely explore side-quests without cognitive overhead, and navigate back to parent tasks at any time. All workspace management is powered by yabai's programmatic macOS Spaces integration.

The core promise: **explore freely, retreat safely, never lose your place.**

---

## Problem Statement

**Current Situation**: Users with ADHD face a painful trilemma when they spot a valuable side-quest during focused work:

1. **Explore and lose track** — They dive into the side-quest, enter a hyperfocus trance, and hours later realize they forgot the original goal entirely.
2. **Explore while anchoring** — They try to hold the original goal in working memory while exploring. This is overwhelming — most mental effort goes to "refreshing memory" rather than making progress, resulting in circular thinking.
3. **Refuse and suffer** — They force themselves to stay on the main task under sub-optimal conditions, feeling frustrated that an enabling improvement (e.g., a useful refactor) must be deferred due to scope creep risk.

macOS Mission Control partially helps by mapping one task per workspace, but its 1D row of tiny thumbnails makes it impossible to see task relationships at a glance, understand how deep you are in a side-quest chain, or quickly orient yourself in context.

**Proposed Solution**: A tree-structured workspace navigator with a HUD overlay that lets users fork sub-tasks as child workspaces, navigate the tree spatially, and always see where they are relative to their main goal — all without holding any of this structure in working memory.

**Business Impact**: Unlocks a fourth option — explore side-quests safely — that eliminates the trilemma. Users can sustain progress on more tasks simultaneously, focus more deeply on any single task, and context-switch seamlessly without dropping responsibilities or losing information.

---

## Success Metrics

**Primary KPIs:**

- **Task capacity**: How many concurrent tasks/side-quests can the user sustain progress on without feeling overwhelmed? Target: noticeably more than the current 2-3 workspace limit before cognitive overload.
- **Focus depth**: How deeply can the user focus on any particular task without working memory being taxed by unrelated details? Target: side-quest exploration feels "free" rather than anxious.
- **Context-switch quality**: How seamlessly can the user switch between tasks without dropping prior responsibility or losing critical information? Target: returning to a parent task feels like picking up exactly where you left off.

**Validation**: Self-reported assessment after 2 weeks of daily use. These are qualitative metrics appropriate for a personal productivity tool — the user will know if it's working.

---

## User Personas

### Primary: ADHD Knowledge Worker

- **Role**: Software developer / knowledge worker who juggles multiple interrelated tasks
- **Goals**: Explore side-quests without losing the main thread; see the big picture of all active work at a glance; context-switch without cognitive penalty
- **Pain Points**: Limited working memory makes mental task-tracking exhausting; current tools (Mission Control) are too flat/linear to represent task relationships; refusing side-quests feels wasteful, pursuing them feels risky
- **Technical Level**: Advanced — comfortable with CLI tools (yabai, Keyboard Maestro), macOS power user
- **Key Trait**: Strong spatial memory — remembers things well when they are keyed by spatial location; tree/graph diagrams are an effective memory aid

---

## User Stories & Acceptance Criteria

### Story 1: Fork a Sub-Task

**As a** knowledge worker in the middle of a task
**I want to** fork a sub-task from my current workspace via a hotkey
**So that** I can explore a side-quest in a clean workspace that's visually linked to my parent task

**Acceptance Criteria:**

- A hardcoded global hotkey triggers the fork action from any application
- A prompt appears asking for the name of the new sub-task
- A new macOS Space is created via yabai
- The new space appears as a child node of the current workspace in the task tree
- The user is automatically switched to the new (empty) workspace
- The parent workspace's windows remain untouched

### Story 2: Navigate the Task Tree via HUD

**As a** knowledge worker with multiple active tasks
**I want to** see and navigate my task tree through a HUD overlay
**So that** I can orient myself spatially and switch to any task without remembering its workspace number

**Acceptance Criteria:**

- A hardcoded global hotkey summons the HUD overlay
- The HUD displays the full task tree with node names and window titles per workspace
- Arrow keys navigate the tree: Up = parent, Down = first child, Left/Right = siblings
- The currently-focused workspace is visually highlighted
- Pressing Enter switches to the selected workspace and dismisses the HUD
- Pressing Escape dismisses the HUD without switching
- The HUD also appears automatically on any workspace navigation

### Story 3: Orient — "What Am I Doing Here?"

**As a** knowledge worker who just switched context
**I want to** quickly see the name and contents of my current workspace
**So that** I can re-orient myself without holding the task tree in my head

**Acceptance Criteria:**

- The HUD hotkey shows the tree with the current node highlighted and its name visible
- Each node displays the workspace name (from fork prompt) and titles of windows in that space
- The user can see ancestor nodes (the path back to the root task) for full context

### Story 4: Archive a Completed Side-Quest

**As a** knowledge worker who finished a side-quest
**I want to** close out a sub-task and have it disappear from the tree
**So that** my tree stays clean and only shows active work

**Acceptance Criteria:**

- When all windows in a workspace are closed, the node is archived and removed from the tree
- The user is navigated to the parent workspace when a child is archived
- Archived nodes do not appear in the HUD
- The tree structure adjusts (children of the archived node, if any, are re-parented or also archived)

---

## Functional Requirements

### Core Features

**Feature 1: Task Tree Data Model**

- Description: A persistent tree structure where each node represents a macOS Space (workspace). Each node stores: a name (from fork prompt), the yabai space ID, a parent reference, and an ordered list of children.
- Data persistence: The tree is saved to disk (e.g., JSON file) so it survives app restarts.
- Root node: The tree has a virtual root, with top-level workspaces as its children. Users can have multiple independent task trees (multiple root-level tasks).
- Edge cases: If yabai reports a space that isn't in the tree (e.g., user manually created a space), it appears as an unparented root node.

**Feature 2: Fork Sub-Task**

- User flow: User presses fork hotkey → text input prompt appears (minimal, floating, centered) → user types sub-task name → presses Enter → new space created via `yabai -m space --create` → space is focused via `yabai -m space --focus` → tree is updated with new child node → tree saved to disk.
- Error handling: If space creation fails (e.g., macOS space limit), show an error notification. If the user presses Escape at the prompt, cancel the fork.

**Feature 3: HUD Overlay — Tree Navigator**

- Description: A semi-transparent overlay that renders the task tree spatially. Nodes are laid out as a top-down tree (root at top, children below). The current workspace is highlighted.
- Navigation: Arrow keys move a selection cursor through the tree. Enter switches to the selected workspace. Escape dismisses.
- Node display: Each node shows the workspace name and a list of window titles currently in that space (queried from yabai in real-time when HUD is summoned).
- Appearance: Native macOS vibrancy/blur (NSVisualEffectView), dark theme, compact node cards. Should feel like a refined version of Mission Control's overlay.
- Summoning: Appears on hardcoded hotkey press, and optionally on every workspace switch (configurable later).

**Feature 4: Workspace Switching**

- When the user selects a workspace in the HUD: execute `yabai -m space --focus <space_id>` to switch, then dismiss the HUD.
- The HUD should update the highlight to reflect the new current workspace before dismissing (brief visual confirmation).

**Feature 5: Auto-Archive**

- When yabai reports that a space has been destroyed (or has zero windows), the corresponding tree node is archived.
- Archived nodes are removed from the active tree and stored separately (for potential future "history" view).
- If an archived node had children, those children are re-parented to the archived node's parent.

### Out of Scope (MVP)

- Window suspend/restore with layout memory
- Workspace preview thumbnails in HUD
- Window transfer on fork (moving windows to new workspace)
- Many-to-many window/workspace relationships ("pinned" or "floating" windows)
- Configurable hotkeys (UI for remapping)
- Intention/notes labels per workspace (beyond the name)
- History/visualization of archived tasks
- Drag-and-drop tree reorganization

---

## Technical Constraints

### Performance

- HUD must appear within 200ms of hotkey press — this is a "glance" tool, not a modal dialog
- Tree navigation (arrow key response) must be instantaneous (<50ms)
- Workspace switching should feel as fast as native Mission Control (yabai is the bottleneck here, not the app)
- Memory footprint should stay under 50MB for typical usage (10-20 active workspaces)

### Security

- The app requires macOS Accessibility permissions (for global hotkey capture and yabai communication)
- No network access required — fully local, no telemetry
- Tree data stored as a local JSON file in `~/.config/better-mission-control/` or Application Support

### Integration

- **yabai**: Primary integration. The app shells out to `/opt/homebrew/bin/yabai` for all workspace operations: creating spaces, focusing spaces, querying spaces/windows. The app must handle yabai being temporarily unavailable (e.g., after a restart).
- **macOS Spaces**: yabai operates on native macOS Spaces. The app's tree model must stay in sync with the actual macOS Spaces state. On launch, the app should reconcile its persisted tree with the current yabai-reported spaces.
- **Keyboard Maestro (transitional)**: In MVP, global hotkeys can be wired via Keyboard Maestro calling the app's CLI interface. The app exposes commands like `bmc fork`, `bmc navigate`, `bmc show-hud` that Keyboard Maestro macros can invoke. Post-MVP, the app registers its own global hotkeys natively.

### Technology Stack

- **Language**: Swift
- **UI Framework**: AppKit (for native macOS HUD, NSPanel, NSVisualEffectView)
- **Global Hotkeys**: Initially triggered externally via Keyboard Maestro → CLI; post-MVP via native Carbon/CGEvent hotkey registration
- **yabai Communication**: Shell-out to yabai CLI, parsing JSON output (`yabai -m query --spaces`, `yabai -m query --windows`)
- **Data Persistence**: JSON file on disk via Codable
- **Build**: Xcode / Swift Package Manager
- **Minimum macOS**: Ventura 13.0+ (for current NSVisualEffectView APIs and yabai compatibility)

---

## MVP Scope & Phasing

### Phase 1: MVP

- Task tree data model with JSON persistence
- Fork Sub-Task: CLI command (`bmc fork "task name"`) that creates a space, updates the tree, and switches to it
- HUD overlay: CLI command (`bmc hud`) that shows the tree, supports arrow key navigation + Enter/Escape
- Auto-archive: nodes removed when their space is destroyed
- CLI interface for Keyboard Maestro integration
- Reconciliation on launch (sync tree with yabai's actual spaces)

**MVP Definition**: The minimum that delivers value is the ability to fork a sub-task and navigate back to the parent via a spatial tree HUD. This alone breaks the ADHD trilemma by externalizing the task call-stack.

### Phase 2: Self-Contained Hotkeys + Polish

- Native global hotkey registration (replace Keyboard Maestro dependency)
- Configuration UI for hotkey remapping
- Intention/notes field per workspace node
- HUD appears automatically on workspace switch
- Visual polish: animations, transitions, node styling

### Phase 3: Window Management

- Workspace preview thumbnails in HUD nodes
- Window suspend/restore with layout memory (positions, sizes)
- Window transfer on fork (select which windows to bring to the new workspace)
- Cross-cutting / "pinned" windows that appear in multiple workspaces

### Phase 4: History & Intelligence

- Archived task visualization (timeline or collapsed tree branches)
- Search across current and archived tasks
- Task duration tracking
- Suggested archive (detect idle workspaces)

### Future Considerations

- Integration with task management tools (JIRA, Linear, Todoist)
- Sync across machines
- Template workspaces (pre-configured window layouts for common task types)

---

## Risk Assessment


| Risk                                                                              | Probability | Impact | Mitigation                                                                                          |
| --------------------------------------------------------------------------------- | ----------- | ------ | --------------------------------------------------------------------------------------------------- |
| yabai API changes or breaks after macOS update                                    | Medium      | High   | Pin yabai version, abstract yabai calls behind an adapter layer, monitor yabai releases             |
| macOS limits on number of Spaces (historically ~16)                               | Medium      | Medium | Document the limit, implement archive aggressively, warn user when approaching limit                |
| HUD overlay conflicts with other overlays or full-screen apps                     | Medium      | Medium | Use NSPanel with appropriate window level, test with common full-screen apps                        |
| Tree state drifts from actual yabai state (user manually creates/destroys spaces) | High        | Medium | Reconciliation on every HUD summon: query yabai, diff against tree, surface orphan spaces           |
| Global hotkey conflicts with other apps                                           | Low         | Low    | Use uncommon key combinations in MVP; configurable hotkeys in Phase 2                               |
| Accessibility permissions friction (user must grant manually)                     | High        | Low    | Clear onboarding flow explaining why permissions are needed, with a deep link to System Preferences |


---

## Dependencies & Blockers

**Dependencies:**

- **yabai**: Must be installed and running with Spaces integration enabled. The app does not function without yabai.
- **macOS Accessibility permissions**: Required for global hotkey capture (post-MVP) and potentially for window querying.
- **Keyboard Maestro (MVP only)**: Used as the hotkey layer in MVP. Users must configure macros that call the `bmc` CLI.

**Known Blockers:**

- None identified. yabai is already installed and functional in the user's environment.

---

## Appendix

### Glossary

- **Space**: A macOS virtual desktop (workspace), managed by Mission Control and programmable via yabai.
- **yabai**: A tiling window manager for macOS that provides CLI control over windows and spaces.
- **HUD**: Heads-Up Display — a semi-transparent overlay that appears on top of the current workspace.
- **Fork**: Creating a new child workspace (sub-task) branching from the current workspace in the task tree.
- **Archive**: Removing a completed task's node from the active tree while retaining its data for potential future reference.
- **Side-quest**: A tangential task discovered during work on a main task that feels valuable to explore but risks derailing the original focus.
- **Reconciliation**: The process of syncing the app's persisted tree model with the actual state of macOS Spaces as reported by yabai.

### References

- [yabai documentation](https://github.com/koekeishiya/yabai/wiki)
- User's current Keyboard Maestro configuration (yabai hotkey macros)
- macOS Mission Control & Spaces documentation

