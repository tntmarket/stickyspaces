## Purpose

Zoom-out "Map Overview" canvas that shows all workspaces and their stickies as a spatial landscape, enabling users to see the big picture, preserve spatial memory, and maintain orientation across workspaces. Refines and details `core` requirements FR-7 through FR-10 and NFR-2 for the overview entry, rendering, and arrangement experience (PRD Story 3). Keeps existing ZO-* prefixed requirement IDs.

## Requirements

### Requirement: ZO-FR-1 Open Map Overview from current workspace

The system SHALL allow a knowledge worker to open Map Overview from the current workspace with a single hotkey or command, so they can access the big picture at the moment they need it.

#### Scenario: Hotkey triggers overview

- **WHEN** user presses the zoom-out hotkey from any workspace
- **THEN** the Map Overview canvas is displayed showing all supported workspaces

#### Scenario: CLI triggers overview

- **WHEN** user runs the zoom-out CLI command
- **THEN** the Map Overview canvas is displayed with structured snapshot output

### Requirement: ZO-FR-2 Spatial continuity during zoom-out transition

The system SHALL animate current-workspace stickies shrinking in place into overview context, so spatial continuity preserves confidence during context expansion and the user never loses track of where they were.

#### Scenario: First frame matches pre-zoom state

- **WHEN** the zoom-out transition begins
- **THEN** the first frame is visually identical to the pre-zoom desktop state on a stable region of interest (changed-pixel ratio <=0.1%, max per-channel delta <=2)

#### Scenario: Hero anchor continuity during animation

- **WHEN** the zoom-out animation plays from first frame to final frame
- **THEN** the current workspace's content shrinks in place without discontinuity or jump

### Requirement: ZO-FR-3 Workspace regions as screenshot thumbnails

The system SHALL render each supported workspace as a distinct bordered region using a scaled screenshot thumbnail of that workspace's real desktop appearance (windows, wallpaper, and sticky placement), so users can recognize workspace intent without mental remapping.

#### Scenario: Workspace regions show real desktop appearance

- **WHEN** the Map Overview is displayed
- **THEN** each workspace region contains a scaled screenshot thumbnail reflecting the actual desktop composition at zoom-out time

#### Scenario: Regions are non-overlapping

- **WHEN** the Map Overview is displayed with multiple workspaces
- **THEN** all workspace regions are rendered as non-overlapping bordered areas

### Requirement: ZO-FR-4 Empty workspaces shown as empty regions

The system SHALL display empty workspaces as empty bordered regions in the overview, so the overview reflects full workspace topology and not only workspaces with stickies.

#### Scenario: Empty workspace appears on canvas

- **WHEN** a workspace has no stickies or windows
- **THEN** it still appears as an empty bordered region on the Map Overview canvas

#### Scenario: Region count matches workspace count

- **WHEN** the Map Overview is displayed
- **THEN** the number of regions equals the number of supported workspaces, including empty ones

### Requirement: ZO-FR-5 Drag workspace regions to rearrange canvas

The system SHALL allow a knowledge worker to drag workspace regions to arbitrary positions in the overview, so they can encode task relationships spatially by grouping related work together.

#### Scenario: Drag moves region to new position

- **WHEN** user drags a workspace region to a new position via the overlay or the move-region command
- **THEN** the region appears at the new position and the position is reflected in subsequent canvas-layout reads

### Requirement: ZO-FR-6 Stable region arrangement across invocations

The system SHALL preserve region arrangement across repeated zoom-out invocations within the same session, so spatial memory compounds instead of resetting.

#### Scenario: Arrangement persists across repeated zoom-outs

- **WHEN** user moves a region and then closes and reopens the Map Overview
- **THEN** the moved region retains its custom position for at least 20 repeated invocations

#### Scenario: Repeated snapshots are deterministic

- **WHEN** nothing has changed between two zoom-out invocations (same workspaces, stickies, layout)
- **THEN** the resulting snapshots are equivalent

### Requirement: ZO-FR-7 Active workspace highlight in overview

The system SHALL visually highlight the currently active workspace in the Map Overview, so users can quickly answer "where am I now?" before deciding what to do next.

#### Scenario: Active workspace is uniquely highlighted

- **WHEN** the Map Overview is displayed
- **THEN** exactly one workspace region is visually highlighted as the active workspace

#### Scenario: Highlight follows current workspace

- **WHEN** the active workspace changes between zoom-out invocations
- **THEN** the highlight moves to the newly active workspace

### Requirement: ZO-NFR-1 Zoom-out transition within 300-500ms

The system SHALL complete the zoom-out transition within 300 to 500ms at p95, because it needs to feel responsive without moving so fast that users lose track of what they are seeing.

#### Scenario: Transition duration within budget

- **WHEN** 30 zoom-out transitions are measured end-to-end
- **THEN** p95 duration is within 300-500ms

### Requirement: ZO-NFR-2 Deterministic overview layout

The system SHALL produce identical overview output when nothing has changed (same workspaces, same stickies, same layout), because consistency allows the user to reuse their spatial memory (method of loci). Cards SHALL NOT jump around or reorder unexpectedly.

#### Scenario: Stable input produces stable output

- **WHEN** zoom-out snapshots are taken 10 times without any mutations
- **THEN** all snapshots are equivalent with identical region positions, highlights, and thumbnail metadata

### Requirement: ZO-NFR-3 Read-only canvas for persistent state

The system SHALL NOT edit sticky content or placement, switch workspaces, or create or destroy workspaces when bringing up the Map Overview, because the overview is a read-only observation surface. Transient presentation-layer effects needed for animation are permitted.

#### Scenario: Overview does not mutate sticky state

- **WHEN** the Map Overview is opened and closed
- **THEN** sticky text, position, size, and workspace binding are unchanged

#### Scenario: Overview does not switch workspaces

- **WHEN** the Map Overview is opened
- **THEN** the active workspace remains the same as before the overview was triggered

#### Scenario: Presentation mutations are transient

- **WHEN** the Map Overview animation creates transient visual effects
- **THEN** no persistent user-visible state (stickies, topology, final settled window state) is altered

### Requirement: ZO-NFR-4 Automation-friendly zoom-out API

The system SHALL provide a typed automation surface for zoom-out that enables fast AI iteration loops: an AI agent can run the behavior, inspect structured results, make a change, and re-run without manual UI steps.

#### Scenario: CLI returns structured snapshot

- **WHEN** an automation agent runs the zoom-out CLI command
- **THEN** a structured, typed snapshot response is returned that can be parsed programmatically

#### Scenario: IPC returns snapshot over socket

- **WHEN** an automation agent sends a zoom-out request over IPC
- **THEN** a typed CanvasSnapshot response is returned

### Requirement: ZO-C-1 Primary-display-only workspace enumeration

The system MUST limit overview workspace enumeration to the primary display only, because multi-display topology introduces ambiguity that is intentionally deferred to post-MVP.

#### Scenario: Only primary display workspaces appear

- **WHEN** the Map Overview is displayed on a multi-display system
- **THEN** only workspaces from the primary display are shown as regions

### Requirement: ZO-C-2 Session-scoped region arrangement

The system MUST scope workspace-region arrangement to the current session in memory, because cross-restart reconciliation is a separate risk area deferred from MVP.

#### Scenario: Arrangement clears on restart

- **WHEN** the app is restarted
- **THEN** all custom region positions are cleared and the default layout is used

### Requirement: ZO-C-3 Graceful degradation on capability loss

The system MUST fail gracefully with structured status and warnings when required yabai capabilities are unavailable during zoom-out preparation, because silent or crashing failure breaks user trust.

#### Scenario: Unsupported mode returned on capability loss

- **WHEN** zoom-out is triggered but required yabai capabilities are unavailable
- **THEN** the system returns a structured unsupported-mode error with warnings instead of crashing

#### Scenario: Structured warnings surfaced over IPC

- **WHEN** zoom-out is triggered with degraded capabilities over IPC
- **THEN** the response includes structured mode warnings describing which capabilities are unavailable

### Requirement: ZO-C-4 No Story 4 dependency

The system MUST deliver Story 3 (Map Overview) independently of Story 4 (click-to-navigate), because overview value must stand on its own without requiring navigation semantics.

#### Scenario: Overview works without navigation

- **WHEN** the Map Overview is opened
- **THEN** all overview features (rendering, arrangement, highlight) function correctly without any Story 4 click-to-navigate behavior being implemented


