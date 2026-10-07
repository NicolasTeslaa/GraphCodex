# GraphCodex Operational Office Design

## Objective

Evolve GraphCodex from a 3D session viewer into a local macOS operating environment for Codex agent teams. The 3D office is the primary overview and wayfinding surface. List and Focus modes make operational actions equally reachable in 2D.

## Confirmed product rules

- Keep one macOS app in SwiftUI + SceneKit and evolve the current implementation incrementally.
- The default screen is Map in a high, distant, tilted Overview camera.
- A canonical working-folder path creates an automatic department. Its visible name is its last path component; when names collide, show the parent component too.
- A user can assign a thread to a different department. Persist this per-thread override without changing the thread's actual `cwd`.
- Departments/projects can exist without a work folder and store description/instructions, accent color, icon, kind, and tags.
- Every new agent chooses its own working folder, regardless of department.
- Persist project metadata, thread assignments, agent metadata, office layout, and preferences in versioned local JSON files.
- Every state has text and an icon in addition to color.
- Single click selects a station and opens its inspector. Enter or double-click opens the Codex conversation.
- Departments arrange as islands with a sign, accent, stations, overview metrics, and an attention zone. Selecting a department moves the camera smoothly to it.
- Camera modes are Overview, Orbit, and First Person. A compact department/attention sidebar, global KPIs/search/filters, Map/List/Focus modes, and a shared selection/action model are available.
- The New Agent flow selects or creates a department; collects name, goal, role, priority, tags, and an exclusive work folder; then selects a context source. The final review shows editable full prompt and folder. Only **Iniciar Agent** creates/forks a thread and starts a turn. Cancel before that action has no side effect.
- Context sources: blank, templates, department instructions plus user-selected files from the agent folder, or another agent cloned as full history or summary. File paths are included in the initial prompt for Codex to read.
- Thread creation and turns use the configured Codex model, permissions, and sandbox. GraphCodex never auto-approves; approval decisions stay in Codex.
- Session inspector/actions: project, textual status, last activity, last prompt summary, attention reason, open, copy thread ID, prioritize/favorite, move department, duplicate context, archive.
- Attention includes user/approval wait, error, or configured inactivity threshold. Only app-server facts are shown; last prompt is a summary, not an invented task breakdown.
- Focus shows one department, its agents, and blockers. List and Map share selection/actions.
- Later maturity items include a mini-map, richer layout/favorites, project-specific decoration, refined lighting and avatars, smooth motion, and optional discreet sound.
- API failures are recoverable. Approval continues through Codex.

## Architecture

Retain one app target and divide the existing monoliths into small Swift files by responsibility:

- **Domain**: `Project`, `CodexSession`, thread metadata, context templates, prompt composition, grouping/classification.
- **Persistence**: versioned `GraphCodexStore` JSON schema. Writes are atomic. Invalid or newer schema data reports an actionable recovery message and does not overwrite the unreadable file.
- **Codex integration**: one serialized JSON-RPC client that preserves notifications and server-initiated requests while waiting for matching response IDs. It supports read methods, `thread/start`, `thread/fork`, `turn/start`, `thread/archive`, and explicit JSON-RPC responses to host requests. Approval requests are not answered with acceptance by GraphCodex.
- **Presentation**: shared view state for Map/List/Focus and selection; project sidebar; session inspector; New Agent review flow.
- **Scene**: separate scene builders for departments, stations, attention, props, and a camera controller. SceneKit receives projects and sessions, not persistence or RPC objects.

## New-agent transaction and safety

1. Editing and canceling the form performs no Codex calls and writes no agent record.
2. On explicit start, create a thread (`thread/start`) or fork one (`thread/fork`) with the selected `cwd` and source-history option; use defaults for model/permissions unless the installed protocol requires omission-safe fields.
3. Start the first turn using the reviewed prompt (`turn/start`). Persist the resulting `threadId` metadata and department assignment only after the RPC returns a thread ID. If turn start fails after thread creation, retain the thread metadata, mark its startup error, and offer retry/open/archive; do not create a second thread silently.
4. Keep the protocol's configured approval policy and user reviewer. GraphCodex never replies with an accept decision. The UI must surface any server-originated request and route the user to Codex for the approval workflow; if the installed app-server cannot transfer that pending request to Codex, do not simulate an approval UI or silently accept/deny it. Report the compatibility limitation and preserve the thread for opening in Codex.
5. Archiving is explicit and uses the app-server method; it never deletes rollout files.

## Five delivery phases

### Phase 1 — Structural foundation

Create focused domain/persistence/Codex/camera boundaries; auto-group departments by canonical `cwd`; persist per-thread department overrides and project metadata; add the compact project sidebar; make Overview the initial camera with zoom bounds and camera modes.

### Phase 2 — Readable departmental office

Render project islands, signs, accents, metric panels, attention areas, recognizable departments and more informative stations. Smoothly focus a selected project/station. Preserve readable station selection and inspector without disrupting scene navigation.

### Phase 3 — Operational agent creation and quick actions

Provide project/session forms, reviewable prompt composition, selectable templates/files, clone-full-history/clone-summary, explicit start/cancel, Codex app-server mutations, inspector quick actions, persisted metadata, and recoverable error handling.

### Phase 4 — Productivity at scale

Provide dashboard KPIs, global search/filter, shared Map/List/Focus state, attention queue, priority/favorites, moving assignments, duplicate context, archiving, configured inactivity attention, a mini-map, and shared actions from each mode.

### Phase 5 — Premium polish

Refine project-dependent scene styling, avatars, lighting, short damped camera transitions, motion-reduction behavior, an opt-in low-volume sound preference, and accessible reduced-motion/static alternatives. Scene controls remain functional without animation or sound.

## Visual decisions

- Retain the Midnight Violet palette in `DESIGN.md`.
- Use the code-first workflow selected by the user; build in the native app and inspect the actual SceneKit scene.
- Accent colors distinguish departments while semantic status colors remain consistent.

## Error and privacy behavior

- Keep all app metadata local in versioned JSON. Never alter Codex conversation rollouts directly.
- JSON-RPC IDs are correlated; notifications do not get dropped while another request is in flight.
- Server/client requests must receive protocol-valid responses; approval request methods are never accepted automatically.
- Show the operation and recovery action on errors. Retain local metadata if refresh fails.
- Do not claim tasks, intent, blockers, or completion beyond app-server facts and explicitly user-supplied metadata.

## Acceptance examples

- Two threads whose `cwd`s are `/Users/a/GraphCodex` and `/Users/b/GraphCodex` produce distinct automatic groups named `a/GraphCodex` and `b/GraphCodex`; moving one to Verval persists through reload and leaves `cwd` unchanged.
- A project with no working folder remains selectable and can receive an agent whose selected `cwd` is a different path.
- Canceling the New Agent review causes zero `thread/start`, `thread/fork`, and `turn/start` calls.
- Starting a blank agent calls `thread/start` with selected `cwd`, then `turn/start` with the exact approved prompt.
- Cloning full history calls `thread/fork` and starts the first turn on the fork. Summary cloning calls `thread/start` with the chosen summary as initial context.
- Selected file paths and department instructions appear in the editable prompt; GraphCodex does not upload or rewrite those files.
- A server-initiated approval request can never trigger an acceptance reply from GraphCodex.
- Map, List, and Focus preserve a single selected thread and offer equivalent session actions.
- The default overview displays every department without requiring camera movement, and reduced-motion preference disables continuous effects.
