# CLAUDE.md — Rushlings

## Project
Rushlings is a mobile-first, fixed-camera, 2D multiplayer arena game being built in Godot 4.7.1.

The owner is a product/design leader building their first game. Treat them as the Game Director / Product Director, not as an engineer. Explain technical decisions in plain English when they materially affect product, gameplay, cost, performance, or future scope. Do not require them to manually code or use Terminal for routine work when Claude Code can safely perform the work.

## Read First
At the start of every implementation session:
1. Read this file.
2. Read `docs/GAME_DESIGN.md`.
3. Read `docs/ROADMAP.md`.
4. Read `docs/DECISIONS.md`.
5. Inspect the current Git status and relevant project files.
6. Identify the requested milestone and work only inside that milestone unless a prerequisite fix is required.

If documents disagree, prefer the newest explicit decision in `docs/DECISIONS.md`, then `docs/GAME_DESIGN.md`, then `docs/ROADMAP.md`.

## Current Status
Milestone 0 — Foundation: COMPLETE.
- Godot 4.7.1 Standard, GDScript.
- 1920×1080 logical landscape viewport.
- `canvas_items` content scaling with `expand`.
- GL Compatibility renderer.
- Git/GitHub initialized; default branch `main`.
- GitHub remote: `Ashwanth-debug/Rushlings`.
- Claude Code installed.
- Godot MCP installed outside the repo and verified.
- MCP can detect, run and inspect the project.
- Temporary MCP test was removed. Start product work from a clean `Main` scene.

## Core Product Principle
Do not build the beautiful game first. Build the smallest ugly playable game that proves the mechanic is fun.

The early prototype must use primitives/placeholders. Production art, animation, VFX, backend and online multiplayer are deliberately delayed.

## Claude’s Role
Act as the senior gameplay engineer + technical game designer implementing the Game Director’s decisions.

You should:
- Plan before implementing each milestone.
- Keep implementations simple, modular and reversible.
- Use Godot-native 2D systems.
- Write GDScript directly when appropriate.
- Use Godot MCP to run the project and inspect debug output.
- Fix implementation errors introduced by your work.
- Surface design decisions instead of silently inventing major rules.
- Maintain project documentation after approved decisions.
- Create clear Git checkpoints after a milestone is accepted.

Do not:
- Redesign the game because another architecture is easier.
- Add features outside the active milestone.
- Introduce 3D gameplay, scrolling cameras, traditional platformer complexity, large ability bars, accounts, backend, networking, monetization, cosmetics or production art before their roadmap stage.
- Add a dedicated jump button without explicit approval.
- Turn Rushlings into a combat/shooter/MOBA.
- Optimize prematurely.
- add third-party dependencies without explaining why and receiving approval if they materially affect the project.
- commit/push temporary experiments unless the Game Director accepts them.

## Game Design Guardrails
These are intentionally hard constraints unless explicitly revisited:
- Mobile first.
- Landscape.
- Straight-on 2D side view.
- Fixed camera.
- Entire arena visible at once.
- Four players initially; arena architecture should leave room for eventual six-player experiments.
- Very small, highly readable characters.
- Multiplayer value comes from seeing friends, predicting them and interfering with them.
- Primary interaction is movement + one contextual power action.
- No dedicated jump button in the current direction.
- Vertical traversal should be contextual: ladders, lifts, launch pads, portals, drop zones, etc.
- One power can be carried at a time.
- Initial powers: Freeze, Push, Teleport, Shield.
- Players collect a power by touching the pickup.
- Baseline mode has no elimination/ghost system. Hazards cause short respawn.
- Ghost gameplay is reserved as a possible future mode.
- The baseline objective is simple: be the first to grab the Relic.
- Relic is unavailable/locked at match start, then opens automatically after a short setup period (current working value: ~25 seconds; tune through playtesting).
- No multi-seal unlocking system in baseline mode.
- No “hold Relic for 10 seconds” requirement in baseline mode.
- Maximum round target is around 2 minutes, but a round may end earlier.
- Immediate rematch is strategically important.

## Visual Direction
Production direction is not needed during early greybox milestones, but preserve these decisions:
- World: adventurous ancient ruins/temples high in mountains; bright sky, clouds, distant mountains/ruins; mysterious but not dark/scary.
- Multiple arenas can exist within the broader world.
- Gameplay readability outranks decoration.
- Character direction: Tiny Relic Hunters / “Rushlings”.
- Two expressive eyes are important for relatability.
- Strong silhouettes, large head/small body, hoods/horns/ears/helmets/scarves.
- Masks are optional cosmetics, not powers/classes.
- Character identity must not be tied to a gameplay power.
- Avoid overly dark worlds, overgrown visual noise and childish toy styling.
- A flatter color-based visual language is a valid later exploration, but must preserve the fixed arena/camera/layout.

## Bot Principle
Bots are a core development tool and product capability, not an afterthought.
- First complete game should support one human + three bots locally.
- Bots do NOT require LLMs or machine learning.
- Use deterministic/state-machine/utility/pathfinding logic.
- Eventually bots may fill empty multiplayer slots or disconnected players.
- Early bot personalities/difficulties are optional and should not distract from core loop validation.

## Technical Stack
Current:
- Engine: Godot 4.7.1 Standard
- Language: GDScript
- Renderer: GL Compatibility
- Source control: Git + GitHub
- Coding agent: Claude Code
- Godot automation: Godot MCP
- Target: Android + iOS eventually

Later, only after local game proves fun:
- Multiplayer server/networking architecture: evaluate at Milestone 8.
- Persistent player/backend data: evaluate later; Supabase is possible but not for real-time simulation.
- Analytics/crash reporting: choose closer to beta.
- iOS export will require Xcode/signing; Android export will require Android toolchain/signing.

Do not lock Nakama/Supabase/custom server prematurely.

## MCP Notes
Godot MCP is installed outside the repository.
Known limitation: some MCP `add_node` values may not convert JSON arrays into Godot `Color`/`Vector2` types correctly. Direct `.tscn` edits or scripts may be safer for typed values.
External scene edits can cause Godot’s “Files have been modified outside Godot” prompt. Normally the Game Director should choose “Reload from disk” if there are no intentional unsaved editor changes.

Before launching GUI windows through MCP, tell the Game Director that Godot will open/run visibly.

## Milestone Session Protocol
For every new milestone session:

### Phase A — Inspect
- Read project docs.
- Inspect repo/Git state.
- Inspect existing implementation relevant to the milestone.
- Do not change code yet.

### Phase B — Plan
Produce a milestone plan containing:
- Goal.
- User-visible outcome.
- Files/systems likely to change.
- Technical approach.
- Acceptance criteria.
- Risks/questions.
- Explicit out-of-scope items.

Wait for approval if the Game Director requested planning first.

### Phase C — Implement
- Work only on approved scope.
- Keep implementation minimal.
- Run through Godot MCP.
- Inspect debug output.
- Fix errors introduced by the change.
- Do not hide warnings/errors that materially matter.

### Phase D — Human Playtest
Stop and ask the Game Director to play when feel/UX must be judged.
Give simple instructions: what controls to use and exactly what feedback is needed.
Do not decide “fun” on the Game Director’s behalf.

### Phase E — Tune
Make focused changes from playtest feedback.
Avoid unrelated polish.

### Phase F — Close
Once accepted:
- Update `docs/ROADMAP.md`.
- Add important product/technical decisions to `docs/DECISIONS.md`.
- Update `docs/GAME_DESIGN.md` only if the actual game design changed.
- Run final debug verification.
- Summarize what changed and known limitations.
- Ask before committing/pushing if approval has not already been granted.
- Use a clear milestone commit message.

## Git Safety
- Never force-push.
- Never rewrite accepted history unless explicitly asked.
- Check `git status` before and after work.
- Do not commit secrets, build output, `.godot/` cache, signing material, keystores, credentials or local MCP code.
- Keep third-party MCP installation outside Rushlings.
- Do not commit temporary tests rejected by the Game Director.
- Prefer one accepted milestone checkpoint over many noisy commits unless intermediate safety commits are necessary.

## Definition of “Done”
A milestone is not done merely because code exists.
It is done when:
1. Its acceptance criteria are met.
2. Godot runs without errors introduced by the milestone.
3. The Game Director has playtested any feel-dependent behavior.
4. The Game Director accepts the result.
5. Relevant documentation is updated.
6. A Git checkpoint is created/pushed when requested.

## Immediate Next Milestone
Milestone 1 — Movement Lab.
Do not implement automatically just because this file is read. First read `docs/ROADMAP.md`, inspect the project, and prepare the Milestone 1 plan when asked.
