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
**Status: [x] COMPLETE / ACCEPTED (2026-09-06)**

Accepted by the Game Director after Arena 01 V2 playtests 1a, 1b, the physical-gateway chamber
iteration, and the closed-gate readability test. Full record: `docs/plans/M02_ARENA_01_V2.md`
(status updated to closed) and the M2 close-out entries in `docs/DECISIONS.md` (2026-09-06).

**Implementation brief: `docs/plans/M02_ARENA_01_V2.md`** (Arena 01 V2, internal working
name "The Gallery"). That document supersedes the scope and acceptance criteria below wherever they
differ.

**History:** Arena 01 V1 ("The Seam Ring") was built and playtested once. The first unprompted human
playtest found the architecture was solving the wrong problem — it optimised routes to the Relic
rather than making a place four players want to be in. V1 was **redesigned, not patched**. The V1
brief and its Playtest 1 findings are preserved in `docs/plans/M02_GREYBOX_ARENA.md` §17.

Arena 01 V2 is four horizontal bands — a continuous wrapping floor, a lower gallery, an upper
gallery severed by one wall, and a Crown band containing a sunken Relic vault — with four starting
territories (top-left, top-right, bottom-left, bottom-right), two ladder entrances to the Crown, one
floor-mounted launcher, and wrapping as connective tissue rather than as the organising idea.

Approved amendments that change the scope stated below:
- **No portal pair.** Decided against — see `docs/DECISIONS.md` (2026-09-06).
- **Route-cost measurement is diagnostic, not normative.** Human playtesting overrides route timing.
- **Readability outranks route-graph complexity**, extended by the V2 mental-model principle: the
  player must never need route-node names or the route graph in order to play.
- **First human test is unprompted exploration**, not a structured route walkthrough — and for V2
  the **first session runs with the Relic hidden** ("Move around this arena for three minutes").
- **The arena must be fun with the Relic removed.** This is the primary V2 design test.
- **Normal Relic access must not require precision momentum.**
- **Wrap-route timing is measured and reported, but is not an acceptance threshold.** The criterion
  is behavioural: does the player intentionally choose wrapping in play?

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
**Done twice.** V1 in `docs/plans/M02_GREYBOX_ARENA.md`; V2 — the current brief — in
`docs/plans/M02_ARENA_01_V2.md`. Retained below as the standing checklist for future arenas:
- Spawn points and starting territories.
- Route graph.
- Traversal points.
- ~~Portal pair.~~ Decided against for Arena 01.
- Future pickup candidate positions.
- Relic location.
- Hazard/respawn candidate areas.
- Fast/safe/power route rationale.
- **Playground value with the objective removed.** Added at V2 — an arena must be worth moving
  around in before it is worth racing across.
- **Future combat/interference map** — duel zones, interception points, push/drop opportunities,
  escape paths, crossfire areas. Added at V2.

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

## Closeout — DONE
- V1 rejected through unprompted human playtesting; V2 ("The Gallery") built, playtested across
  three sessions (playground-only, objective-visible, and the physical-gateway chamber revision),
  and accepted.
- Four starting territories (top-left, top-right, bottom-left, bottom-right), a substantial
  continuous lower interaction floor, and stronger horizontal connectivity across upper layers are
  all accepted, per `docs/DECISIONS.md`.
- A protected central Relic chamber with two chokepoint-style approaches (a physical west gateway,
  the narrow pre-existing east step) is accepted, plus a static closed-gate visual over the Relic
  confirmed by playtest to read as "found, but protected."
- Horizontal wrapping remains accepted, unchanged from M1, and was used intentionally by the
  Director during play (escape/flank/reposition), not just measured as a diagnostic.
- `tools/arena_check.gd` was extended throughout M2 (tightened R1/R2, new R3/R4/R5/R6/R7/R8/R9/R12,
  diagnostics R10/R11, gateway-specific checks) and stays the permanent regression tool for future
  arena work, including M3.
- Movement tempo (1.25× playback) and Freeze's possible environmental/surface mode are recorded
  hypotheses for later milestones, not implemented — M1 movement constants are unchanged.
- Known, deliberately deferred: `B_Under`'s jump-in rise sits right at the M1 jump ceiling
  (184px vs. a 184.1px max) — recorded, not simplified, since it's a confirmed high-value future
  pickup spot.

---

# M3 — Core Game Loop
**Status: [~] IN PROGRESS — M3-1 (Four-player foundation) is [x] COMPLETE / ACCEPTED
(2026-09-09). M3-2 (Core match loop) is [ ] PLAN APPROVED (2026-09-09) / IMPLEMENTATION NOT
STARTED.** See `docs/plans/M03_CORE_GAME_LOOP.md` §0.5–§0.7 and the 2026-09-06 through 2026-09-09
entries in `docs/DECISIONS.md` for the full implementation, diagnostic, and playtest log.

**⚠️ M3-2 implementation brief: `docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md`.** That document is the
authority for M3-2 and supersedes Part Two (§11) of `M03_CORE_GAME_LOOP.md` wherever they differ.
**No M3-2 gameplay code, scene, script, test or project setting exists yet.** A fresh session
starts at its Step 0 and stops at **STOP 1** for Director inspection of the gate.

**M3-1 close-out, for a session that hasn't read the whole log:** the vault exit, the traversal-
audit topology fixes (three missing mandatory edges, explicit drop departure sides), a genuinely
reliable `Floor→C_M` fixed-trigger bot route (with its own reposition/build-runway safety
behaviour), and the resulting `Floor→C_W`/`Floor→C_Seam` demotion to SKILL/HUMAN-ONLY together
resolved the Floor "one-way drain" problem that blocked earlier playtests. Final human playtest
(1.0×, collision OFF, NAV STRESS enabled) confirmed all three bots navigate reliably across every
region, vertical traversal works, and no persistent stuck/trap behaviour remains. Four
simultaneous players are confirmed substantially more alive and fun than solo M2 exploration.
1.0× is the accepted multiplayer tempo baseline (1.25× stays a recorded experiment only).

**Implementation brief: `docs/plans/M03_CORE_GAME_LOOP.md`.** That document supersedes the scope
and acceptance criteria below wherever they differ.

## ⛔ M3 is split into two halves with a hard approval gate between them

| | Half | Contains | Ends with |
|---|---|---|---|
| **M3-1** | **Four-player foundation** | Slot architecture · controller abstraction · colour identity + toggleable P1–P4 labels · nav graph · edge executors · Dijkstra · roaming bots with a small curiosity/encounter bias · deterministic bot variation · recovery · checker extensions | **HARD STOP → human playtest A1 (1.0×) / A2 (1.25× `time_scale`) / A3 (1.0×) → Director acceptance → commit** |
| **M3-2** | **Core match loop** | Match FSM · configurable setup timer · UNLOCKING bar-lift telegraph · physical vault sealing · gate CLOSED→OPEN · Relic collection · winner · results/rematch · bot goal switch | STOP 1 gate inspection → playtest B0/B1/B2/B3 → acceptance → commit |

**M3-1 is complete and accepted.** M3-2's plan is approved but **nothing in it is implemented**.
A fresh session works from `docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md`, whose §19 defines the
implementation order and five STOP points. **Step 1 builds the gate only** — the physical CLOSED
seal, the existing bars in CLOSED position, a debug-key-driven bars-lift prototype, and the minimal
anti-bypass collision. The `MatchDirector` loop, `SEEK_RELIC`, winner detection, results, rematch
and fairness logic **must not be built** — not partially, not as disabled stubs — until the Game
Director approves STOP 1 by visual inspection.

**Work item #0 comes before all M3 gameplay code:** give `tools/arena_check.gd` an acknowledged-
exception list for the accepted `B_Under` R7 finding and fix its Band A membership/coverage, so a
clean accepted baseline returns exit code 0 and the tool can gate M3 by exit code.

## Risk Being Tested
Is the simplest Rushlings loop fun even with ugly placeholder graphics?

M3-1 asks the prior question the roadmap never separated out: **does Rushlings become fun,
readable and appropriately chaotic when four players move simultaneously inside the same
fixed-screen arena?** The Relic loop is deliberately not the first thing tested.

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

## Added at plan approval (2026-09-06)
- **M3-1 acceptance is separate and comes first.** Four players readable and enjoyable in Arena 01
  with no objective; bots navigate via the same M1 movement with no teleport cheating; encounters
  actually happen; 1.0× vs 1.25× compared with `Engine.time_scale` only.
- **All four spawns report a proven route** in `arena_check.gd`'s route-cost table. The four
  `NO PROVEN ROUTE` warnings at the M2 baseline are a harness limitation the bot's `drop` executor
  fixes, and retiring them is a hard M3-1 criterion.
- **No M1 movement constants change during M3.** A 1.25× preference converts to real constants
  only in a separate tuning pass with a full checker re-run.
- **Setup duration is 10s for M3 only**, with a 10 vs 25 A/B at M3-2. It does not supersede the
  ~25s working direction for M4 when powers exist.

## M3-1 Closeout — DONE (2026-09-09)
- **Accepted** by the Game Director after the final human playtest: 1.0×, collision OFF, NAV
  STRESS enabled. All three bots navigated reliably and completed their full destination
  sequences, moved across every arena region, used ladders/wrap/launcher-adjacent traversal as
  appropriate, and showed no persistent stuck/jump-spam behaviour. Full record:
  `docs/DECISIONS.md`, 2026-09-06 through 2026-09-09 entries.
- Four-player foundation, controller abstraction, hand-authored nav graph + Dijkstra, deterministic
  bot variation, recovery/stall handling, and the RELIABLE/SKILL routing policy are all accepted
  as-is — no changes planned before M3-2.
- **The Floor "one-way drain" is resolved**: three missing mandatory topology edges were added,
  explicit drop departure sides fixed a direction-inference bug, and `Floor→C_M` became the sole
  RELIABLE Floor→Band C bot route via a purpose-built fixed-trigger recipe (with its own bounded
  reposition/build-runway safety behaviour) — `Floor→C_W`/`Floor→C_Seam` are SKILL/human-only.
  Confirmed by a 5-minute NAV STRESS soak, not just a single playtest window.
- **One pre-existing acceptance-criterion note, not reopened:** "all four spawns report a proven
  route" in `arena_check.gd`'s own route-cost table (added at plan approval, above) was never
  literally retired — that specific harness still reports 4 `NO PROVEN ROUTE` warnings, unchanged
  since the M2 baseline. This predates the Director's decision (recorded in
  `docs/plans/M03_CORE_GAME_LOOP.md` §0.5) that NAV STRESS — real `BotBrain`/`EdgeExecutor`
  destination testing over minutes, not this harness's own simplified two-approach simulation — is
  the actual authority on navigation health going forward. The Director's acceptance is based on
  that stronger evidence; the older warning is recorded here rather than silently dropped, and is
  not a blocker.
- **1.0× confirmed as the accepted multiplayer tempo baseline**; 1.25× remains a recorded
  development experiment only, not applied to any M1 constant.
- `tools/m3_check.gd` (including its NAV STRESS mode and the ad hoc 5-minute soak variant) is
  permanent development/regression tooling from here on, alongside `tools/arena_check.gd`.

## M3-2 — Plan approved 2026-09-09, implementation NOT started

**Full plan: `docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md`.** Approved as the implementation
direction with one revision to the gate treatment. Decision entries: `docs/DECISIONS.md`,
2026-09-09.

**Approved architecture:** SETUP → UNLOCKING → OPEN → RESULTS on one `delta`-driven
`MatchDirector` · `reset_round()` as a function, not a fifth state · plain M3-1 ROAM during SETUP ·
`VaultFloor` as the single Relic graph target · grounded bot re-path after OPEN with staggered
per-bot reaction delays · deterministic winner by physics-frame overlap → closest-to-centre →
slot ID · RESULTS freezes controllers/brains (never `paused`, never `time_scale`) · rematch
rebuilds `BotBrain` instances and resets existing bodies · fairness measured and reported before
any balancing · collision OFF and 1.0× tempo preserved · all accepted M3-1 navigation preserved.

**Gate revision (the one change to the plan as submitted):** the existing six vertical `RelicGate`
bars stay the **primary player-facing CLOSED language** — the Relic reads as caged — and they
**mechanically lift** during the final portion of UNLOCKING. The vault is *not* re-skinned around a
solid roof. Physical anti-bypass sealing is still mandatory (the chamber has a real 80px ceiling
hole), but it is minimised to two thin strips at the existing header's own y-range and thickness,
visually subordinate to it. The physical seal stays active for the whole bar lift.

**Setup duration is deliberately unresolved:** ship 10s configurable, offer 10/15/25 debug options,
and take a real engine door-arrival measurement before choosing the human-playtest default.
~25s remains the M4 working direction once powers give the phase content.

**Recorded, not acted on:** P2's spawn is ~2× closer to the Relic than any other on the bot road
network. Measurement finding only — no spawn moves, geometry changes, route re-costing or
slot-specific balancing are authorised.

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
- Steam/desktop platform release, alongside Android + iOS.
- Local/couch multiplayer on desktop with multiple physical controllers.
- Human-learned bot intelligence (gameplay telemetry → statistical imitation → player-style
  modeling → learned/trained bots). Full four-stage direction recorded in `docs/GAME_DESIGN.md`
  under "Future Direction — Human-Learned Bot Intelligence." Does not change the current
  hand-authored, deterministic bot baseline.
- Arena-reactive powers (e.g. Freeze affecting floors/ladders, not just players) and the
  broader "arena as part of the power system" hypothesis. Recorded in `docs/GAME_DESIGN.md`
  near §10 (Powers). Not approved behavior — to be prototyped and playtested at the powers
  milestone (M4), not implemented now.

These require separate validation and should not leak into early milestones.
