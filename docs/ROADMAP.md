# Rushlings — Development Roadmap

## Roadmap Philosophy
This roadmap deliberately separates **proving fun** from **building production systems**.

Do not jump ahead because a later feature is exciting. Each milestone should answer a specific risk.

Status legend:
- [x] Complete
- [ ] Not started
- [~] In progress / partially validated

---

# M0 — Foundation
**Status: [x] COMPLETE**

## Goal
Create a safe AI-assisted Godot development environment.

## Completed
- Godot 4.7.1 Standard installed.
- Rushlings project created.
- 1920×1080 logical viewport.
- Landscape/mobile scaling configured.
- GL Compatibility renderer.
- Git initialized.
- GitHub remote configured and `main` pushed.
- Claude Code available.
- Godot MCP installed outside project.
- MCP verified against Godot 4.7.1.
- MCP can detect project, run project and retrieve debug output.
- Temporary blue-rectangle end-to-end test succeeded and was removed.

## Known MCP Constraint
MCP `add_node` may not correctly convert JSON arrays to typed Godot properties such as `Color`/`Vector2`; direct `.tscn` edits or GDScript may be used.

## Exit Criteria
Met.

---

# M1 — Movement Lab
**Status: [x] COMPLETE / ACCEPTED (2026-09)**

Accepted by the Game Director after three manual playtests. Full plan and outcome: `docs/plans/M01_MOVEMENT_LAB.md`.

## Risk Being Tested
Can Rushlings feel responsive and fun with extremely simple controls?

Originally this asked whether the game could work with **no dedicated jump button**. Playtesting answered that question: it could not. A player-controlled jump was added, and the milestone now also tests horizontal screen wrapping. See `docs/DECISIONS.md` (2026-09).

## Scope
- Greybox only.
- One human placeholder.
- One test scene/arena.
- Horizontal movement.
- Gravity/collision.
- Smooth acceleration/deceleration.
- Contextual vertical traversal experiments:
  - at least one launch pad,
  - at least one ladder/traversal zone or equivalent.
- Player-controlled jump (added after first playtest): grounded or from a ladder, no double jump.
- Jump off ladders (added after second playtest).
- Horizontal screen wrapping (added after first playtest, accepted after second).
- Keyboard controls first, with context-sensitive mapping (W/Up jumps outside a zone, climbs inside one).
- Small debug label only.

## Explicitly Out of Scope
- Bots.
- Relic.
- Powers.
- Portals unless required solely for traversal experiment.
- Touch controls.
- Production art.
- Animation/VFX/audio.
- Multiplayer/backend.

## Acceptance Criteria
- Player cannot fall through platforms unexpectedly.
- Left/right movement feels responsive.
- Reversing direction feels controllable.
- Stopping feels intentional.
- At least one contextual vertical traversal mechanic works.
- ~~Game Director can explain the traversal without needing a jump button.~~ Superseded 2026-09: playtesting showed a jump is needed. Replaced by: jump and contextual traversal each have a clear, distinct purpose.
- Jump works from the ground only, with no double jump.
- Horizontal wrapping feels continuous rather than like a respawn.
- No implementation errors in debug output.
- Game Director accepts the movement feel after tuning.

## Required Human Playtest Questions
- Too fast/slow?
- Too slippery/heavy?
- Does turning feel good?
- Does automatic traversal surprise or help?
- ~~Is a no-jump-button direction still desirable?~~ Answered 2026-09: no.
- Does jump feel right against the launch pad's stronger boost?
- Does horizontal wrapping read as continuous movement?

## Closeout — DONE
- Movement parameters documented as M1 baseline tuning data, not immutable production values.
- Vertical traversal decision recorded, including the reversal on jump.
- Milestone checkpoint committed and pushed.

## Accepted Movement Language
The vocabulary M1 established, which later milestones build on:
- Horizontal movement with acceleration and deceleration.
- Player-controlled jump (grounded or from a ladder).
- Air steering, with momentum preserved in the air.
- Contextual ladder traversal.
- Jump off ladder.
- Environmental launch pads (stronger than a jump, reaching places a jump cannot).
- Horizontal screen wrapping.

## M1 Baseline Tuning
Current accepted values. Tuning data, not immutable production values — expect these to move as arenas, powers, bots and mobile controls arrive.

| Parameter | Value |
|---|---|
| max_speed | 500 |
| acceleration | 3000 |
| friction | 3500 (floor only) |
| gravity | 2200 |
| jump_strength | 900 (~192px rise) |
| launch_strength | 1500 (~511px rise) |
| climb_speed | 400 |

## Deferred out of M1
- Projectile/shooting-style interaction. Evaluated at M4 through the powers, not by turning the movement milestone into combat development.
- Mobile mapping for Run + Jump + Power. Intentionally unresolved until M5.

---

# M2 — Greybox Arena
**Status: [~] PLAN APPROVED (2026-09-06) — NOT YET IMPLEMENTED**

Full implementation brief: `docs/plans/M02_GREYBOX_ARENA.md`. That document supersedes the scope and
acceptance criteria below wherever they differ. Arena 01 is "The Seam Ring": four walkable bands plus
an elevated Relic deck, with three structurally distinct approaches and a Band-3 ring that closes
only through the horizontal wrap seam.

Approved amendments that change the scope stated below:
- **No portal pair.** Decided against — see `docs/DECISIONS.md` (2026-09-06).
- **Route-cost measurement is diagnostic, not normative.** The fast route is allowed to be
  meaningfully faster; human playtesting overrides route timing.
- **Readability outranks route-graph complexity.** Simplify or remove geometry rather than preserve
  the planned graph.
- **First human test is unprompted exploration**, not a structured route walkthrough.

## Risk Being Tested
Can a fixed single-screen side-view arena provide enough navigation depth while keeping every player location understandable?

## Scope
- One greybox Arena 01.
- Fixed 1920×1080 view.
- Multiple route layers.
- Four spawn positions.
- Fast/risky vs slower/safer routes.
- Contextual vertical traversal based on M1.
- One paired portal shortcut if it improves route design.
- Relic chamber represented as a non-functional placeholder for spatial testing.
- No production art.

## Arena Design Deliverable
Before coding, Claude should create/document a simple arena map showing:
- Spawn points.
- Route graph.
- Traversal points.
- Portal pair.
- Future pickup candidate positions.
- Relic location.
- Hazard/respawn candidate areas.
- Fast/safe/power route rationale.

## Acceptance Criteria
- Entire arena fits one screen.
- Character remains readable at intended placeholder scale.
- All four spawn areas have viable routes.
- Relic cannot be reached via one trivial straight line.
- Player can move between major arena regions without confusion.
- Routes feel meaningfully different.
- There is enough breathing room for four players and plausible future six-player exploration.
- No scrolling camera.
- Game Director accepts navigation.

## Out of Scope
Bots, powers, win condition, production art, online multiplayer.

---

# M3 — Core Game Loop
**Status: [ ] NOT STARTED**

## Risk Being Tested
Is the simplest Rushlings loop fun even with ugly placeholder graphics?

## Scope
- Four player slots.
- P1 human.
- P2/P3/P4 basic bots.
- Relic locked at start.
- Setup phase around 25 seconds (configurable).
- Basic power pickup placeholders may exist only if required by final M3 plan; default is to keep M3 focused and introduce full power behavior in M4.
- Relic opens automatically.
- First player touching Relic wins.
- Winner state.
- Rematch/reset.
- Short respawn if arena hazards exist.
- Basic timer/debug state.

## Bot Minimum
- Navigate arena.
- Move toward relevant target.
- Seek Relic once open.
- Recover after respawn.
- Do not require sophisticated interference yet.

## Acceptance Criteria
- One person can play a complete round against three bots.
- Bots can reach the Relic through legal routes.
- Relic state transitions reliably.
- Winner is deterministic.
- Rematch works without restarting application.
- Round can complete in under ~2 minutes.
- Game Director voluntarily wants to replay enough to continue development.

## Critical Decision Gate
If the game is not fun as shapes, do not proceed directly to art. Diagnose movement, arena and objective first.

---

# M4 — Powers & Bot Intelligence
**Status: [ ] NOT STARTED**

## Risk Being Tested
Does interference create the social/chaotic fun Rushlings needs without becoming confusing?

## Scope
Implement one at a time:
1. Push.
2. Freeze.
3. Teleport.
4. Shield.

For every power:
- Pickup by touching.
- Carry one power.
- Clear placeholder visual state.
- One simple activation input.
- Clear hit/result.
- Bots can understand/use it at basic level.
- Tune before adding next power.

## Recommended Order Rationale
Push is simplest to understand and immediately tests “mess with your friends.”
Freeze tests timing.
Teleport tests route disruption.
Shield tests defense/counterplay.

## Acceptance Criteria
- Each power has a unique purpose.
- No power requires a tutorial paragraph.
- One power at a time is clear.
- Effects do not permanently lock a player out.
- Bots use powers without obviously self-sabotaging most of the time.
- Relic race remains primary objective; combat does not take over.
- Remove or redesign any power that reduces fun.

---

# M5 — Mobile Controls
**Status: [ ] NOT STARTED**

## Risk Being Tested
Can the game remain precise and understandable on a phone without console-like controls?

## Scope
- Touch movement on left-side interaction region.
- Explore invisible/floating control rather than permanent large joystick.
- Right-side single power action.
- Contextual vertical traversal.
- Safe-area/aspect-ratio handling.
- Android device test first if easiest; iOS later.
- Keep keyboard controls as debug fallback.

## Acceptance Criteria
- Player can locate/control themselves immediately.
- Controls do not obscure arena.
- Movement feels responsive on real device.
- Power use is reliable.
- No accidental power activation at unacceptable rate.
- Major phone aspect ratios preserve gameplay visibility.
- No need for A/B/X/Y-style UI.

---

# M6 — Visual Prototype
**Status: [ ] NOT STARTED**

## Risk Being Tested
Can the chosen art/character system remain readable and premium at actual mobile gameplay scale?

## Scope
Only after greybox game is fun:
- One production-quality Rushling.
- One Arena 01 visual pass.
- Minimal top HUD.
- Basic animation: idle/run/cast/hit/respawn/win as required.
- Basic VFX for currently accepted powers.
- Initial SFX.
- Relic open/win feedback.
- Preserve collision/gameplay geometry from greybox unless a design change is explicitly approved.

## Character Pipeline
- Start with one Tiny Relic Hunter, not the full roster.
- Prefer reusable modular 2D rig.
- Two expressive eyes.
- Strong silhouette.
- Test at real gameplay size.
- Masks remain future cosmetics.

## Art Direction
- Bright ancient mountain ruins.
- Blue sky/clouds/distant mountains.
- Controlled vegetation.
- Strong foreground/background separation.
- Gameplay clarity before decoration.
- A flat-color treatment can be tested as a style layer without changing arena structure.

## Acceptance Criteria
- Player remains instantly visible on a phone.
- VFX do not hide gameplay.
- Environment feels premium but not noisy.
- Animation system appears reusable.
- Performance remains healthy on target test device.

---

# M7 — Local Game Polish
**Status: [ ] NOT STARTED**

## Goal
Turn the local game into a small, coherent, repeatable product before networking.

## Scope
- Tune movement/round pacing.
- Refine respawn.
- Refine power balance.
- Onboarding/tutorial for first match.
- Minimal results/rematch flow.
- Audio polish.
- Game-feel feedback.
- Bot tuning.
- Local settings required for testing.
- Stability/performance pass.

## Acceptance Criteria
- New tester can understand goal and controls quickly.
- Complete match flow feels coherent.
- Rematch is fast.
- No major recurring gameplay bugs.
- Multiple external testers show “play again” behavior.
- Decision to invest in online multiplayer is explicitly made.

---

# M8 — Online Multiplayer Architecture
**Status: [ ] NOT STARTED**

## Risk Being Tested
What networking/server model best fits the proven game?

## This Milestone Is Primarily Architecture/Spike Work
Do not choose a backend based on old assumptions.

Evaluate:
- Godot networking options.
- Server-authoritative vs alternatives.
- Dedicated/headless Godot server viability.
- Nakama or other game backend where useful.
- Custom lightweight server where useful.
- Match state frequency/bandwidth.
- Latency tolerance for movement/powers.
- Anti-cheat needs.
- Hosting/deployment/cost.
- Room lifecycle.
- Bot ownership/authority.
- Disconnect/reconnect behavior.
- Persistent data boundary vs live simulation.

## Deliverable
Written architecture recommendation + small networking spike.

## Acceptance Criteria
- Two-device sync spike proves chosen direction.
- Clear authoritative ownership model.
- Cost/complexity understood.
- No production-scale build until architecture is approved.

---

# M9 — Private Multiplayer
**Status: [ ] NOT STARTED**

## Scope
- Create room.
- Room code/link.
- Join room.
- 2–4 humans.
- Bots fill empty slots.
- Ready/start flow.
- Live match sync.
- Win/rematch sync.
- Disconnect/reconnect.
- Bot takeover if approved.
- Basic latency/error UX.

## Acceptance Criteria
- Friends on separate devices/networks can complete repeated matches.
- No frequent desync.
- Empty slots do not block play.
- Disconnect does not destroy match unnecessarily.

---

# M10 — Product Layer
**Status: [ ] NOT STARTED**

## Scope Candidates
- Guest identity.
- Optional Apple/Google account linking.
- Character selection.
- Masks/cosmetics.
- Settings.
- Basic progression.
- Persistent unlocks.
- Analytics.
- Crash reporting.
- Match history only if useful.
- Accessibility options.

## Principle
Do not put registration friction before first play unless platform/technical constraints require it.

---

# M11 — Content Expansion
**Status: [ ] NOT STARTED**

## Scope
- Additional arena layouts.
- Additional visual regions/worlds.
- More Rushling silhouettes.
- Masks/cosmetics.
- Additional accepted power variations only if core remains simple.
- Seasonal/event content if justified.

## Possible Arena Regions
- Mountain Temple / Ruins.
- Water Garden.
- Sun Observatory.
- Cloud Forge.
- Broken Palace.
- Floating Gardens.

Each new arena must preserve:
- fixed camera,
- multiplayer readability,
- meaningful route choices,
- mobile clarity.

---

# M12 — Beta & Release
**Status: [ ] NOT STARTED**

## Scope
- Android export/signing.
- iOS export/Xcode/signing.
- Device matrix.
- Performance.
- Battery/thermal/network behavior.
- Analytics/crash monitoring.
- Closed beta.
- Balance.
- Store listing/assets.
- Privacy/terms as required.
- App Store / Google Play submission.
- Monetization only if validated and appropriate.

## Launch Gate
Do not launch because the feature list is complete.
Launch when:
- Core match is stable.
- Multiplayer is reliable enough.
- New players understand it.
- Retention/rematch signals justify release.
- Performance is acceptable on target devices.

---

# Future / Parking Lot
Not baseline commitments:
- Six-player mode.
- Haunted/ghost mode.
- 2v2 teams.
- Public matchmaking/ranked.
- Tournaments.
- Multiple objectives.
- Sponsored arenas/packs.
- Rewarded ads.
- Cosmetic store.
- Advanced bot personalities.
- Boss/Ancient Guardian events.
- Different objective modes.

These require separate validation and should not leak into early milestones.
