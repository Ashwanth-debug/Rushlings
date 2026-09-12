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
**Status: [x] COMPLETE — M3-1 (Four-player foundation) is COMPLETE / ACCEPTED (2026-09-09). M3-2
(Core match loop) is COMPLETE / ACCEPTED (2026-09-12). MILESTONE 3 — CORE GAME LOOP: COMPLETE.**
See `docs/plans/M03_CORE_GAME_LOOP.md` §0.5–§0.8, `docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md` §21,
and the 2026-09-06 through 2026-09-12 entries in `docs/DECISIONS.md` for the full implementation,
diagnostic, and playtest log.

**M3-2 implementation brief: `docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md`.** That document is the
authority for M3-2 and superseded Part Two (§11) of `M03_CORE_GAME_LOOP.md` wherever they differed.
**Accepted loop:** `SETUP → UNLOCKING → OPEN → SEEK_RELIC → COLLECTION → RESULTS → REMATCH`. Final
human playtest confirmed every stage reads clearly, bots visibly switch ROAM→SEEK_RELIC at OPEN
and converge using the accepted M3-1 navigation, and rematch reliably starts fresh rounds.

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

## M3-2 — COMPLETE / ACCEPTED (2026-09-12)

**Full plan and close-out: `docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md`** (§21 is the close-out).
Approved as the implementation direction with one revision to the gate treatment, then implemented
across Steps 1–5 and accepted after final human playtest. Decision entries: `docs/DECISIONS.md`,
2026-09-09 through 2026-09-12.

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

## M3-2 Closeout — DONE (2026-09-12)

- **Accepted** after final human playtest: the full `SETUP → UNLOCKING → OPEN → SEEK_RELIC →
  COLLECTION → RESULTS → REMATCH` loop reads clearly end to end, bots visibly switch to
  SEEK_RELIC at OPEN and converge, human and bots collect the same Relic, RESULTS freezes
  correctly, and repeated rematches work.
- **10s is the accepted setup-duration baseline** for the current no-powers game. 15s/25s debug
  options are preserved (not deleted); ~25s remains the M4 working direction once powers exist.
- **Arena 01's roof/east-wall pre-positioning is accepted as an emergent strategy**, not fixed in
  M3-2 — a player who pre-positions on the header/roof before OPEN can fall directly onto the
  Relic. Recorded as a hypothesis that future powers (Push, Freeze, projectiles) may provide
  natural counterplay, to be human-playtested at M4, not assumed solved. See `docs/DECISIONS.md`
  (2026-09-12) for the full decision and the future-arena-design principle it motivates.
  Not every future arena needs Arena 01's same objective-access topology.
- **20-round headless bot-only fairness sample recorded as diagnostic evidence, not acted on:** P2
  won 55% of rounds; OPEN→win was ~0s in nearly every round because roof/ceiling fallthrough
  materially affects results — door-usage telemetry under-counts roof-origin arrivals as a result.
  No spawn, geometry, cost, or bot-difficulty change was made. Telemetry timing resolution should
  be improved before fairness becomes a serious tuning task.
- **M3-1 is unchanged and not reopened**: M1 movement, accepted navigation, `Floor→C_M`, vault
  traversal, ladders, wrapping, the RELIABLE/SKILL policy, and the known deferred edge-sampling
  findings below all carry forward as-is.
- **Known, deferred checker findings, not fixed:** four `tools/m3_check.gd` edge-validation cases
  (`C_Seam→A_E_Bridge`, `A_W_Bridge→Pier`, `VaultFloor→VaultEast`, `VaultEast→A_E`) fail only at
  one extreme boundary sample position each, pre-dating the M3-2 Step 4/5 work and independent of
  it (raw `EdgeExecutor` mechanics, not bot decision logic). 20/20 real fairness rounds terminated
  cleanly with 0 hard recoveries, indicating this does not block real play. Recorded rather than
  patched, per the standing rule against silently changing M3-1 navigation/geometry.
- **`tools/arena_check.gd` remains a clean PASS**, unchanged from the M2/M3-1 baseline.

**MILESTONE 3 — CORE GAME LOOP: COMPLETE.** The dedicated match-economy design session this
close-out demanded has since happened: **M4-0 — Match Shape Design is COMPLETE / APPROVED
(2026-09-12)**, recorded in `docs/plans/M04_0_MATCH_SHAPE_DESIGN.md`. The next *implementation*
stage is **M4-1 — Contact**, planned and not started. See the M4 section above.

## Critical Decision Gate
If the game is not fun as shapes, do not proceed directly to art. Diagnose movement, arena and objective first.

---

# M4 — Powers, Match Shape & Bot Intelligence

**M4 is a PHASE, not a single milestone.** It has seven stages. Treating it as one milestone will
produce schedule surprise.

**M4-0 — Match Shape Design: [x] COMPLETE / APPROVED (2026-09-12).**
**M4-1 — Contact: [x] COMPLETE / ACCEPTED (2026-09-12).** Full record: `docs/DECISIONS.md`.
**M4-2 — The Arena Bites: [ ] NEXT, PLANNED / NOT STARTED.**

## Authority
**`docs/plans/M04_0_MATCH_SHAPE_DESIGN.md` is the authority for this phase** and supersedes any
older M4 text. Read it before planning or implementing any stage. It replaced the previous M4 scope
entirely — see "What changed" below.

## What changed, and why the old M4 was replaced

The previous M4 said: implement Push, then Freeze, then Teleport, then Shield, one at a time. That
ordering was sound; the defect was elsewhere. **There was no match for a power to live inside.**
M3-2's own telemetry measured median OPEN→win at **~0.00s** — ten seconds of sealed roaming
followed by a resolution too fast for any interference to change an outcome. Powers built into that
match would have been individually implemented and collectively unevaluable.

M4-0 therefore re-planned the match itself before any power is built, per the requirement recorded
in `docs/DECISIONS.md` (2026-09-12) and `docs/GAME_DESIGN.md` §25.

**Superseded M3-era assumptions** (preserved in `docs/GAME_DESIGN.md`, marked as superseded rather
than deleted): first-touch-wins as the *final* objective · "baseline mode should not eliminate
players" · M4 as simply Push → Freeze → Teleport → Shield.

## The approved match

```
BUILD       Relic sealed. Tier 1 powers on ordinary routes. Few or no hazards.
     ↓
ESCALATE    Tier 2 powers at contested hard-to-reach spots. Danger zones begin.
     ↓
CLIMAX      Relic opens. Tier 3 powers. First grab activates and LOCKS one
            extraction anchor. Carry it there while everyone hunts you.
     ↓
WINNER      Extraction reached.
```

Full detail in `docs/GAME_DESIGN.md` §7A, §8A, §10, §11.

## Stage sequence

| Stage | Status | The one question it answers | Contents |
|---|---|---|---|
| **M4-0** Match Shape Design | **[x] COMPLETE / APPROVED** | *What is a Rushlings match?* | The design document. No code. |
| **M4-1** Contact | **[x] COMPLETE / ACCEPTED (2026-09-12)** | **Does hurting each other feel good?** | Push + Rocket + Freeze · one-use, carry-one, pickup · 3-pip health · defeat → spill → respawn · minimal safe-respawn · protection-window prototype. **Damage-model amendment: all three powers now deal 1 pip on hit, not just Rocket** — see `docs/DECISIONS.md`. No Relic change, no hazards, no long match. |
| **M4-2** The Arena Bites | **[ ] NEXT** | **Does arena-as-opponent improve the game?** | Escalating danger zones with a mandatory warning → active → safe cycle. First real test of Push-is-displacement-only (now also Push-deals-1-pip, per the M4-1 amendment). Determines how important environmental damage should become. |
| **M4-3** The Climax | [ ] Not started | **Does carry-to-locked-extraction produce a great ending?** | Relic carry · five authored region anchors · selected once and locked for the round · drop-on-defeat · **Mine**. |
| **M4-4** The Long Match | [ ] Not started | **Does ~2 minutes hold attention?** | BUILD → ESCALATE → CLIMAX phase clock · Tier 1/2/3 access schedule · hazard escalation schedule · real timing measurement · **resolves the open timeout question**. |
| **GATE** Progression judgment | [ ] Not started | *Is access escalation enough?* | Decide from human evidence whether stat progression is needed at all. |
| **M4-5** Broader Power Set | [ ] Not started | *Do the categories stay distinct at scale?* | Shield, Teleport, Mobility. Conditional on M4-1 succeeding. |
| **M4-6** Economy | [ ] Not started | *Only if the GATE says yes* | Resources, levels, charges. Designed against evidence, never imagination. |

**Why hazards come before the climax:** Push has no lethal identity until something exists to push
people into. Testing the climax first would judge a version of combat that is not the intended
shipping version. The cost is that there is no complete playable game until M4-3.

## M4-1 — COMPLETE / ACCEPTED (2026-09-12)

**Status: ACCEPTED** by the Game Director after human playtesting confirmed every STOP point. Full
record: `docs/DECISIONS.md` (2026-09-12, M4-1 close-out entries). The scope, STOP points and
acceptance criteria below are preserved as written at approval — the M4-1 Closeout section after
them records what actually happened, including the damage-model amendment discovered during
playtesting.

### Risk Being Tested
Does player-to-player interference create the social/chaotic fun Rushlings needs, without becoming
confusing?

### Approved power set (as scoped; see Closeout below for the amendment)
| Power | Category | Damage | Skill it tests |
|---|---|---|---|
| **Push** | Control / displacement | **0** | Positional and environmental manipulation |
| **Rocket** | Direct ranged damage | 1 | Ranged pressure and firing lines |
| **Freeze** | Movement / control denial | **0** | Timing and denial |

**Mine is deferred to M4-3**, where the locked extraction creates predictable routes and makes
placement and prediction meaningful. **Shield is deferred to M4-5**, when enough threat density
exists to properly evaluate defense. Full reasoning: `docs/plans/M04_0_MATCH_SHAPE_DESIGN.md` §06.

### In scope
- Power pickup entity: touch to collect, carry one, replaces current.
- One-use consumption: use → empty → collect again.
- 3-pip health, with the visual treatment chosen at STOP 3, never before.
- Defeat → carried power spills as a world pickup → respawn at the anchor furthest from the nearest
  living opponent.
- Post-respawn protection window (~0.75–1.0s), flagged a prototype hypothesis.
- Bot goals at the existing `_decide_next()` seam: `SEEK_PICKUP`, `USE_POWER`, plus passive
  defeated/respawn handling. **No health-driven bot behaviour of any kind.**
- Extended roam phase so interference has room to occur.
- Test-harness knobs: pickup density, debug damage key.

### Explicitly out of scope for M4-1
Relic carry / extraction anchors (M4-3) · arena hazards (M4-2) · phase clock, tier gating, the
~2-minute match (M4-4) · Mine (M4-3) · Shield / Teleport / Mobility (M4-5) · inventory, XP,
currency, stat progression (M4-6 at the earliest, conditional) · impact and fall damage · timeout
resolution · **any low-health behaviour for humans or bots** · a weighted spawn director · carrier
speed modification · player↔player collision (stays OFF) · any change to M1 movement, M2 geometry
or M3 navigation.

### STOP points
M4-1 is one coherent milestone with internal human gates.

| STOP | Question |
|---|---|
| **1** Pickup + scarcity | Does touch-to-collect, carry-one, replacement and one-use consumption read correctly? |
| **2** Interference | Do Push, Rocket and Freeze work and feel meaningfully different? |
| **3** Health readability | Can Healthy / Hurt / Critical be understood at normal arena scale? **This STOP selects the visual treatment.** |
| **4** Defeat / spill / respawn | Does defeat have consequence without being frustrating? Is the spilled power understandable and contestable? Does respawn work? |
| **5** Human acceptance | Does player-to-player interference actually make Rushlings more fun? |

### Acceptance Criteria
- Each power has a unique purpose; control and damage identities stay distinct.
- No power requires a tutorial paragraph.
- One power at a time is clear; empty-after-use is legible.
- Health state is readable at full-arena scale without a percentage bar.
- Defeat has consequence without frustration; spilled power is contestable.
- Effects do not permanently lock a player out.
- Bots use powers without obviously self-sabotaging most of the time, and **never retreat because
  of low health**.
- `tools/arena_check.gd` and `tools/m3_check.gd` both still pass. The four known deferred
  `m3_check.gd` edge-sampling findings remain acknowledged, not silently patched.
- Remove or redesign any power that reduces fun.

## M4-1 Closeout — DONE (2026-09-12)

- **Accepted** by the Game Director after human playtesting confirmed all five STOP points: pickup/
  carry-one/replacement, one-use consumption, Push/Rocket/Freeze all working and feeling distinct,
  3-pip health readable at full-arena scale, defeat/spill/collection/respawn all working, and
  player-to-player interference judged to make Rushlings more fun.
- **Damage-model amendment, discovered during STOP 2/3/4 playtesting:** the M4-0 assumption that
  Push and Freeze deal zero direct damage is **superseded for the current prototype**. All three
  hostile powers (Push, Rocket, Freeze) now deal exactly 1 pip on a successful hit — routed through
  the same `HealthSystem.apply_damage()` path regardless of source — while keeping distinct
  strategic identities through their non-damage effect: Push = damage + displacement, Rocket =
  damage + range, Freeze = damage + temporary control. **Do not generalize this into "all future
  powers must deal damage"** — it is a finding about this specific power set, not a new rule. Full
  reasoning and organic-play evidence: `docs/DECISIONS.md` (2026-09-12).
- **Health visual treatment resolved at STOP 3**: character-integrated (three pips above the body,
  plus flash/tint feedback on a hit), not a percentage bar. Selected through playtesting as approved
  at M4-0 §04.1.
- **Accepted prototype tuning values** (not production balance): health 3 pips · Push/Rocket/Freeze
  each 1 pip on hit · Freeze duration 1.0s (tunable, `debug_cycle_freeze_duration`) · defeat duration
  1.5s (revised down from an initial 3.0s — the Game Director found 3.0s "noticeably too slow") ·
  spawn protection 0.8s · pickup respawn 6.0s (a test-harness knob, not a shipping value) · carry-one
  / one-use · player↔player collision OFF (unchanged).
- **Regression requirement met**: `tools/arena_check.gd` re-verified passing (exit 0) on the exact
  M4-1 tree, with `PowerSystem`/`HealthSystem` disabled during its run (a geometry/traversal-only
  checker cannot tolerate a bot legitimately Push/Freezing the checker's own test subject mid-route —
  player interference is real M4-1 behaviour, tested separately). `tools/m4_1_check.gd` (new,
  permanent M4-1 regression tool) passes all deterministic PASS/FAIL sections with 0 failures.
  `tools/m3_check.gd` re-run in full, twice: the four previously-acknowledged edge-sampling findings
  reproduce identically both times, unchanged. **A fifth finding was newly discovered by this
  close-out's own verification** — a rare NAV STRESS destination-reliability failure plus a related
  `_test_determinism()` WARN, both load/timing-sensitive and confirmed independent of M4-1/M4-2 (an
  isolated re-run of the failing test alone passed cleanly; danger zones are provably inert during
  this checker). Recorded as a fifth acknowledged finding, not silently patched — see
  `docs/DECISIONS.md` (2026-09-12) for the full evidence.
- **Known gap, not resolved, not blocking**: M4-1's own risk register flagged that organic defeats
  might be rare with no hazards yet. A 90s organic-play diagnostic (3 bots + idle P1, current pickup
  density) recorded only 1 organic defeat in that window even with all three powers now dealing
  damage — confirming the concern was real, and that M4-2's hazards are the next lever, not further
  M4-1 tuning.

## Open questions this phase must answer with evidence, not argument
- All phase timings and total match duration.
- **Timeout resolution** — what happens at the time limit. A hard-cap/sudden-death rule was
  proposed at M4-0 and **explicitly withdrawn**. Candidates recorded without selection: current
  carrier wins · overtime · extraction stays active while arena pressure escalates · another
  sudden-death structure · another evidence-driven solution. Resolved at M4-4.
- How important environmental damage should actually become (M4-2).
- Whether stat progression is needed at all (the GATE, after M4-4).
- Pickup density and respawn interval.
- Whether the post-respawn protection window becomes permanent.

## Known risks
1. **Readability is the binding constraint, not code** — four tiny characters, health states,
   carried-power indicators, three tiers of pickups, hazard zones, a carried Relic and an
   extraction beacon on one fixed screen. M4-1 alone (pips + one power indicator) read clearly;
   M4-2's hazard zones are the next readability test, not yet a proven risk realised.
2. **Bot cost is the largest hidden number** — hazard avoidance is the expensive addition.
   Navigation alone took two milestones and ~39K of `scripts/bot_brain.gd`.
3. **The stalemate case** — a carrier repeatedly defeated near extraction. No approved rule
   resolves it yet, because timeout resolution is open.
4. **Rocket cannot test aim** without an aiming input, which the control guardrail forbids and M5
   has not solved. It fires in facing direction and tests ranged pressure, not aim.
5. **Danger zones may read as arbitrary punishment** in greybox. Wind is the fallback.

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
- Arena-reactive powers (e.g. Freeze affecting floors/ladders, not just players). Recorded in
  `docs/GAME_DESIGN.md` near §10. Still not approved behaviour, and **not part of M4-1** — M4-1's
  Freeze is player-targeted movement denial only. The broader "arena as part of the power system"
  hypothesis is partly addressed from the other direction by M4-2's arena-as-opponent experiment,
  which makes the arena a threat rather than a power target. Revisit arena-*targeting* powers after
  M4-2 provides evidence.

These require separate validation and should not leak into early milestones.
