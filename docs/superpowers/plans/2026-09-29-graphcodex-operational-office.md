# GraphCodex Operational Office Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the confirmed five-phase operational GraphCodex, including departmental 3D overview, productive 2D modes, safe agent creation, local persistence, and premium controls.

**Architecture:** Keep one SwiftUI/SceneKit macOS app and add focused domain, persistence, RPC, presentation, scene, and component files. JSON stores local metadata, and an injectable app-server transport makes behavior verifiable without creating or altering real Codex sessions.

**Tech Stack:** Swift 5.9, SwiftUI, SceneKit, AppKit, Foundation, XcodeGen, XCTest.

**Spec:** `docs/superpowers/specs/2026-09-29-graphcodex-operational-office-design.md`

## Global Constraints

- Platform: macOS 14.0 minimum.
- Keep one app target using SwiftUI and SceneKit.
- Use only app-server facts for Codex state.
- Never change a session's real `cwd` when changing its GraphCodex department.
- Never approve an action automatically; preserve configured Codex model, sandbox and approval policy.
- Do not create or fork a thread before the explicit **Iniciar Agent** action.
- Persist metadata in versioned local JSON and write atomically.
- Status includes text and symbol in every view.

---

### Task 1: Domain model and department grouping

**Files:**
- Create: `Sources/GraphCodex/Domain/Project.swift`
- Create: `Sources/GraphCodex/Domain/SessionOrganizer.swift`
- Create: `Tests/GraphCodexTests/SessionOrganizerTests.swift`
- Modify: `project.yml`

**Interfaces:** `Project`, `ProjectKind`, `SessionMetadata`, `SessionOrganizer.group(_:metadata:) -> [ProjectGroup]`.

- [ ] Add tests first for canonical folder grouping, same-name disambiguation, manual assignment override, and unchanged `cwd`.
- [ ] Run the focused XCTest target and confirm each fails for missing types/behavior.
- [ ] Add the XcodeGen unit test target and implement only model/organizer behavior.
- [ ] Run the focused tests and refactor pure grouping logic.

### Task 2: Versioned JSON persistence

**Files:**
- Create: `Sources/GraphCodex/Persistence/GraphCodexStore.swift`
- Create: `Tests/GraphCodexTests/GraphCodexStoreTests.swift`

**Interfaces:** `GraphCodexStore.load() -> GraphCodexSnapshot`, `save(_:) throws`, `GraphCodexSnapshot.schemaVersion`.

- [ ] Test default empty state, round-trip metadata, atomic save replacement, and unsupported-version preservation.
- [ ] Run tests and confirm failure.
- [ ] Implement injectable file URL and atomic JSON encoder/decoder.
- [ ] Run tests; refactor file IO behind the store boundary.

### Task 3: Codex app-server transport and lifecycle

**Files:**
- Create: `Sources/GraphCodex/Codex/AppServerTransport.swift`
- Create: `Sources/GraphCodex/Codex/AgentCreationService.swift`
- Modify: `Sources/GraphCodex/CodexAppServerClient.swift`
- Create: `Tests/GraphCodexTests/AgentCreationServiceTests.swift`
- Create: `Tests/GraphCodexTests/JSONRPCDispatcherTests.swift`

**Interfaces:** `CodexTransport.request(method:params:) async throws`, `AgentCreationService.start(_:approvedPrompt:)`, `ContextSource`, `AgentDraft`.

- [ ] Test cancel/no-call behavior, start and turn call order, full fork and summary start, startup failure recovery data, and no approval acceptance response.
- [ ] Run focused tests and confirm expected failures.
- [ ] Implement correlated RPC response handling, server-request preservation, explicit start transaction and protocol errors.
- [ ] Run tests; refactor transport and service without changing call behavior.

### Task 4: Shared app state and project sidebar

**Files:**
- Create: `Sources/GraphCodex/Presentation/OfficeViewModel.swift`
- Create: `Sources/GraphCodex/Features/Projects/ProjectSidebar.swift`
- Modify: `Sources/GraphCodex/CodexMonitor.swift`
- Modify: `Sources/GraphCodex/MainView.swift`
- Create: `Tests/GraphCodexTests/OfficeViewModelTests.swift`

**Interfaces:** `OfficeMode`, `CameraMode`, shared selected thread/project IDs, project/session selectors and department reassignment.

- [ ] Test mode/selection continuity, status KPIs, and persistent reassign behavior.
- [ ] Confirm red, implement state and sidebar, run focused tests, refactor view responsibilities.

### Task 5: Camera controller and modular scene builders

**Files:**
- Create: `Sources/GraphCodex/Scene/OfficeCameraController.swift`
- Create: `Sources/GraphCodex/Scene/OfficeSceneBuilder.swift`
- Create: `Sources/GraphCodex/Scene/DepartmentNodeBuilder.swift`
- Create: `Sources/GraphCodex/Scene/StationNodeBuilder.swift`
- Modify: `Sources/GraphCodex/Office3DView.swift`
- Create: `Tests/GraphCodexTests/CameraFramingTests.swift`

**Interfaces:** camera presets `overview`, `orbit`, `firstPerson`; framing clamps `7...42`; smooth `focus(on:)`; scene builder accepts projects and sessions.

- [ ] Test camera preset values, zoom bounds, and deterministic project framing.
- [ ] Confirm red, implement camera and builder extraction, run focused tests, refactor old view to delegate.
- [ ] Build and inspect the actual SceneKit scene at Overview and project focus.

### Task 6: Department islands and attention scene

**Files:**
- Modify: `Sources/GraphCodex/Scene/DepartmentNodeBuilder.swift`
- Modify: `Sources/GraphCodex/Scene/StationNodeBuilder.swift`
- Create: `Sources/GraphCodex/Scene/AttentionZoneBuilder.swift`
- Create: `Tests/GraphCodexTests/DepartmentLayoutTests.swift`

**Interfaces:** deterministic island position per project ID, visible project sign/accent, session stations, attention zone labels.

- [ ] Test stable island placement, department metrics and session state labels.
- [ ] Confirm red, implement room/stations/labels/attention zone, run tests, refactor scene composition.
- [ ] Inspect and fix first batched visual findings.

### Task 7: New Agent context composition and review flow

**Files:**
- Create: `Sources/GraphCodex/Agents/ContextTemplateService.swift`
- Create: `Sources/GraphCodex/Features/Agents/NewAgentFlow.swift`
- Create: `Sources/GraphCodex/Features/Agents/AgentReviewView.swift`
- Create: `Tests/GraphCodexTests/PromptCompositionTests.swift`

**Interfaces:** `AgentRole`, `AgentPriority`, `AgentTemplate`, `AgentDraft`, `PromptTemplateBuilder.build(draft:)`.

- [ ] Test role templates, included department instructions, only selected file paths, prompt edit preservation, and clone modes.
- [ ] Confirm red, implement flow and editable review, run focused tests, refactor stages.

### Task 8: Inspector, quick actions, and project management

**Files:**
- Create: `Sources/GraphCodex/Features/Sessions/SessionInspector.swift`
- Create: `Sources/GraphCodex/Features/Projects/ProjectEditor.swift`
- Modify: `Sources/GraphCodex/Presentation/OfficeViewModel.swift`
- Create: `Tests/GraphCodexTests/SessionActionsTests.swift`

**Interfaces:** open, copy ID, toggle priority/favorite, move project, duplicate context, archive.

- [ ] Test metadata actions, actual cwd immutability, and archive RPC method/confirmation.
- [ ] Confirm red, implement inspector/project editor and actions, run tests, refactor shared commands.

### Task 9: Dashboard, attention, List, Focus, and mini-map

**Files:**
- Create: `Sources/GraphCodex/Features/Dashboard/OfficeToolbar.swift`
- Create: `Sources/GraphCodex/Features/Dashboard/AttentionQueue.swift`
- Create: `Sources/GraphCodex/Features/Sessions/SessionListView.swift`
- Create: `Sources/GraphCodex/Features/Projects/ProjectFocusView.swift`
- Create: `Sources/GraphCodex/Features/Office/MiniMapView.swift`
- Modify: `Sources/GraphCodex/MainView.swift`
- Create: `Tests/GraphCodexTests/AttentionFilteringTests.swift`

**Interfaces:** shared `OfficeMode`, global search/filter, attention predicate and shared session-action bindings.

- [ ] Test attention predicate from app-server state and configured inactivity, global search, stable selection across modes.
- [ ] Confirm red, implement three modes/queue/minimap, run tests, refactor shared filters.

### Task 10: Premium motion, sound preference, and accessible controls

**Files:**
- Modify: `Sources/GraphCodex/Scene/OfficeCameraController.swift`
- Modify: `Sources/GraphCodex/Scene/StationNodeBuilder.swift`
- Modify: `Sources/GraphCodex/Features/Dashboard/OfficeToolbar.swift`
- Modify: `Sources/GraphCodex/MainView.swift`
- Create: `Tests/GraphCodexTests/AccessibilityPreferencesTests.swift`

**Interfaces:** `reduceMotion`, `soundEnabled` default false, semantic state labels and static equivalents.

- [ ] Test motion and sound defaults plus preference persistence.
- [ ] Confirm red, implement damped transitions/optional discreet sound and static states, run tests, refactor effect controls.

### Task 11: Documentation, integrated verification, and handoff

**Files:**
- Modify: `README.md` (preserve the user-owned changes; append/update only accurate shipped behavior)
- Modify: `docs/GraphCodex.md`
- Verify: `.github/workflows/*.yml` and `*.yaml`

- [ ] Build and run the macOS app; run all XCTest behaviors.
- [ ] Inspect the built app in the native UI in Overview/Orbit/First Person, Map/List/Focus, New Agent review, and error/empty states.
- [ ] Update docs from actual implementation; scan the full diff and preserve unrelated changes.
- [ ] If no GitHub Actions workflow exists, commit and push the reviewed task changes to the configured branch and remote. Do not stage unrelated README content without reviewing ownership.
