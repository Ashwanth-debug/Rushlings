# CLAUDE.md — Rushlings

## Project
Rushlings is a mobile-first, fixed-camera, 2D multiplayer arena game being built in Godot 4.7.1.

The owner is a product/design leader building their first game. Treat them as the Game Director / Product Director, not as an engineer. Explain technical decisions in plain English when they materially affect product, gameplay, cost, performance, or future scope. Do not require them to manually code or use Terminal for routine work when Claude Code can safely perform the work.

## Read First
At the start of every implementation session:
1. Read this file.
2. Read `docs/GAME_DESIGN.md` — **especially §7A, §8A, §10 and §11**, which carry the approved M4
   match architecture. §7, §8 and part of §11 preserve older M3-era text and are explicitly marked
   as superseded; do not follow them for M4 work.
3. Read `docs/ROADMAP.md` — the M4 section is a **phase of seven stages**, not one milestone.
4. Read `docs/plans/M04_0_MATCH_SHAPE_DESIGN.md` — **the authority for the whole M4 phase.**
5. Read `docs/DECISIONS.md`, at minimum the 2026-09-12 M4-0 and M4-1 close-out entries at the end of
   the file.
6. Inspect the current Git status and relevant project files.
7. Identify the requested milestone and work only inside that milestone unless a prerequisite fix is required.

Those five documents together are sufficient to understand the current M4 architecture without any
prior conversation.

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

Milestone 1 — Movement Lab: COMPLETE / ACCEPTED (2026-09).
- Accepted movement language: horizontal movement, player-controlled jump, air steering, contextual ladder traversal, jump-off-ladder, environmental launch pads, horizontal screen wrapping.
- Movement lives in `scripts/player.gd`; wrapping in `scripts/arena_wrap.gd`; lab scene in `scenes/movement_lab/`.
- The Movement Lab is kept as a regression/tuning harness, not a shippable arena.
- Full record: `docs/plans/M01_MOVEMENT_LAB.md`.

Milestone 2 — Greybox Arena (Arena 01 V2, "The Gallery"): COMPLETE / ACCEPTED (2026-09-06).
- V1 ("The Seam Ring") was rejected via unprompted human playtesting; V2 was built, playtested across three sessions, and accepted.
- Live scene: `scenes/arena_01/arena_01.tscn`, now `main_scene`. Four starting territories, two Crown ladders, one launcher, a protected central Relic vault with two chokepoint-style approaches, a static closed-gate visual over the Relic (no logic yet), and accepted horizontal wrapping.
- `tools/arena_check.gd` is the permanent geometry/traversal regression tool — extend it, don't bypass it, for any future arena work.
- Full record: `docs/plans/M02_ARENA_01_V2.md` and the M2 entries in `docs/DECISIONS.md` (2026-09-06).
- The Movement Lab (`scenes/movement_lab/`) is retained as a separate regression harness.

Milestone 3-1 — Four-Player Foundation: COMPLETE / ACCEPTED (2026-09-09). Milestone 3-2 — Core Match Loop: COMPLETE / ACCEPTED (2026-09-12). **MILESTONE 3 — CORE GAME LOOP: COMPLETE.**
- Four player slots (P1 human, P2–P4 bots), a controller abstraction (`scripts/player_controller.gd`, `human_controller.gd`, `bot_controller.gd`), and a hand-authored nav graph + Dijkstra (`scripts/nav_graph.gd`, `nav_path.gd`, `edge_executor.gd`, `bot_brain.gd`) drive bot navigation with real M1 physics — no teleport cheating.
- `Floor→C_M` is the one dependable, RELIABLE bot road up from the ground (a purpose-built fixed-trigger recipe with a bounded reposition/build-runway safety behaviour); `Floor→C_W`/`Floor→C_Seam` are SKILL/human-only by design — see `docs/DECISIONS.md` (2026-09-08).
- `tools/m3_check.gd` (including NAV STRESS mode) is the permanent M3 navigation regression tool, alongside `tools/arena_check.gd`. Both must pass before any future navigation change — 4 known, deferred edge-sampling findings remain (checker-boundary artifacts predating M3-2 Step 4/5, unrelated to bot decision logic; see `docs/DECISIONS.md`, 2026-09-12) and are documented, not silently patched.
- Player↔player collision is OFF by default (dev toggle available); 1.0× is the accepted multiplayer tempo baseline.
- **The accepted M3-2 match loop:** `SETUP → UNLOCKING → OPEN → SEEK_RELIC → COLLECTION → RESULTS → REMATCH`. 10s is the accepted setup-duration baseline for the current no-powers game (15s/25s remain as debug options, not deleted; ~25s stays the M4 direction once powers exist). Bots switch `ROAM → SEEK_RELIC` at OPEN via `BotBrain.Goal` and converge on the Relic using accepted M3-1 navigation; `scripts/match_telemetry.gd` is permanent dev-only, print-based convergence/fairness telemetry.
- **Arena 01's roof/east-wall pre-positioning is ACCEPTED as an emergent strategy, not a defect** — a player who legally pre-positions on the vault header/roof before OPEN can fall directly onto the Relic. Not fixed in M3-2; recorded as an M4 counterplay hypothesis (Push/Freeze/projectiles/respawn) to be human-playtested, not assumed solved. See `docs/DECISIONS.md` (2026-09-12).
- Full record: `docs/plans/M03_CORE_GAME_LOOP.md` (§0.5–§0.8), `docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md` (§21 close-out), and the M3-1/M3-2 entries in `docs/DECISIONS.md` (2026-09-06 through 2026-09-12).
- **SUPERSEDED by M4-3 (2026-09-13, COMPLETE / ACCEPTED 2026-09-14 — see the Milestone 4 section
  below).** This bullet described the game through M4-2: `MatchDirector` state machine unchanged
  (`SETUP → UNLOCKING → OPEN → RESULTS`), but the Relic itself was still first-touch-wins. As of
  M4-3, `scripts/relic.gd` was rewritten: touching the Relic while OPEN makes the toucher the
  *carrier*, not the winner — winning now requires carrying it to a locked extraction
  (`scripts/extraction_anchor.gd`). This is a **live change to the normal match**, not a separate
  lab mode (Contact Lab/Arena Bites Lab remain separate dev-only toggles; M4-3's carry/extraction
  mechanics apply to ordinary play the instant the Relic opens). **Human playtesting has confirmed
  this** — see the M4-3 entry below and `docs/DECISIONS.md` (2026-09-14).

## Milestone 4 — Powers, Match Shape & Bot Intelligence
**M4-0 — Match Shape Design: COMPLETE / APPROVED (2026-09-12).**
**M4-1 — Contact: COMPLETE / ACCEPTED (2026-09-12).** Human validation confirmed: pickup/carry-one/
replacement, one-use consumption, Push (feels useful), Rocket, Freeze all working; all three hostile
powers remove exactly 1 health pip on a successful hit while keeping distinct identities (Push =
damage + displacement, Rocket = damage + range, Freeze = damage + temporary control); 3-pip health is
readable; defeat, power-spill and spill-collection work; unlimited respawn, authored dynamic respawn
selection and spawn protection (as a prototype) all work; 1.5s defeat→respawn feels correct. Current
accepted/prototype values: health 3 pips · Push/Rocket/Freeze each 1 pip on hit · Freeze duration
1.0s (tunable) · defeat duration 1.5s · spawn protection 0.8s · pickup respawn 6.0s · carry-one /
one-use · player↔player collision OFF. These are prototype baselines, not production balance.
**Damage-model amendment (2026-09-12):** the M4-0 assumption that Push and Freeze deal zero direct
damage is superseded for the current prototype — discovered and validated during M4-1. **Do not
generalize this into "all future powers must deal damage"**; it is a finding about this specific
power set. See `docs/DECISIONS.md` (2026-09-12, M4-1 close-out entries) for the full record,
regression results and STOP-by-STOP findings.
**M4-2 — The Arena Bites: COMPLETE / ACCEPTED (2026-09-13).** Escalating danger zones
(`scripts/danger_zone.gd`) with a mandatory SAFE → WARNING → ACTIVE cycle, deterministic staggered
phase offsets, and the reaction-window fix (a lethal hit's own effect finishes playing for
~0.4s before the target disappears) are all accepted. Full record: `docs/DECISIONS.md`
(2026-09-12/13). Permanent regression tool: `tools/m4_2_check.gd`.
**M4-3 — The Climax: COMPLETE / ACCEPTED (2026-09-14).** Relic carry, five locked extraction
anchors, drop-on-defeat, bot pursuit/interception, Mine, and a Relic-opening salience treatment
(camera shake + flash) are built, pass `tools/m4_3_check.gd` plus a 20-round soak, and were
confirmed by Game Director human playtest: carry-not-instant-win reads clearly, the activated
extraction is understandable and stays locked through ownership churn, a carrier can reach it and
win, a defeated carrier's dropped Relic can be continued toward the same extraction by another
player, health/powers/hazards keep working during the climax, the OPEN salience treatment is
noticeable, and Mine mechanically works. Full record: `docs/DECISIONS.md` (2026-09-13 implementation,
2026-09-14 acceptance). Committed. **`tools/m3_check.gd`'s objective-dependent tests (14–17) were
updated at close-out** to assert against the current carry/carrier contract instead of the
superseded M3-era first-touch-win one, preserving the same underlying tie-break/guard logic and
all M1/M2/M3 navigation coverage unchanged — see that file's own header comment and
`docs/DECISIONS.md` (2026-09-14) for the full before/after.
- **Authority: `docs/plans/M04_0_MATCH_SHAPE_DESIGN.md`.** M4 is a phase of seven stages, not one milestone: M4-0 design (done) · M4-1 Contact (done) · M4-2 The Arena Bites (done) · M4-3 The Climax (done) · M4-4 The Long Match (next) · GATE progression judgment · M4-5 Broader Power Set · M4-6 Economy (conditional).
- **The approved match:** `BUILD → ESCALATE → CLIMAX`. Grab the Relic, then carry it to an extraction that is selected **once per round** at first pickup (five authored region anchors, maximum region-distance from the first carrier, deterministic tie-break) and then **locked for the round** — it never recalculates on carrier defeat, Relic drop, ownership change or respawn.
- **Powers are one-use / carry-one.** M4-1's approved set is **Push + Rocket + Freeze**, all three
  now dealing 1 pip damage on a successful hit (damage-model amendment above) while keeping distinct
  identities via displacement/range/control. **Mine added and accepted at M4-3.**
  Shield/Teleport/Mobility → M4-5.
- **Health is three coarse pips** (`Healthy → Hurt → Critical → Defeated`), never a percentage bar; the visual treatment is character-integrated (body flash/tint), accepted at M4-1 STOP 3. **Health never prescribes behaviour** — no low-health retreat, for humans or bots.
- **Unlimited respawns with cost, not limited lives.** On defeat the carried power spills as a contestable pickup; a defeated carrier also drops the Relic.
- **"You feed them to the arena" is an aspiration, not a proven rule.** M4-2 (accepted) confirmed danger zones add useful environmental pressure; do not encode "the arena is the primary damage source" as settled beyond that.
- **Open by design, do not default:** all timings · timeout resolution (a hard-cap/sudden-death rule was proposed and explicitly withdrawn) · the value of environmental damage · whether stat progression is ever needed · whether the spawn protection window becomes permanent.
- **M4-1, M4-2 and M4-3 are implemented and accepted.** M4-3's own 20-round soak found a strong
  winner-distribution skew (P2 17/20) and zero organic Mine placements in the short Climax-only
  rounds — both preserved as diagnostics, **not acted on**; M4-4's longer match may materially change
  both. M4-4 (the long match/phase clock) is next.


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
- Extend the jump beyond its approved shape (no double jump, wall jump, charged/variable jump) without explicit approval.
- Turn Rushlings into a combat/shooter/MOBA. Health, defeat and Rocket exist as of M4-0, but the
  game stays a social interference racer: no basic attack, no aiming input, no ability toolbar, no
  general projectile/combat *model*, no damage numbers. Rocket is a single facing-direction power.
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
- Rushlings has a player-controlled jump (accepted 2026-09 after M1 playtesting; this replaced the earlier no-jump-button constraint). Grounded or from a ladder — no double jump, wall jump or charged jump without approval.
- Vertical traversal is also contextual: ladders, lifts, launch pads, portals, drop zones, etc. These are stronger than a jump and reach places a jump cannot.
- The arena wraps horizontally: leaving one side re-enters from the other at the same height (accepted at M1).
- Movement numbers are tuning data, not settled design. The movement *model* is what is settled.
- Projectile/shooting-style interaction is not a movement concern. It is evaluated through the M4 powers, never by turning a movement milestone into combat development. **As of M4-0 there is still no general projectile/combat model** — Rocket is a single facing-direction damage power with no aiming input.
- One power can be carried at a time. **As of M4-0 it is also one-use:** one carried active power →
  one use → empty → collect again. Scarcity, not a cooldown, throttles combat.
- Players collect a power by touching the pickup.
- **M4-1's approved power set is Push + Rocket + Freeze; M4-3 adds Mine** (accepted 2026-09-14 —
  `scripts/mine.gd`). Shield, Teleport and Mobility → M4-5. The old "Freeze, Push,
  Teleport, Shield" list is superseded as an *ordering*.
- **Damage-model amendment (M4-1, 2026-09-12): all three current hostile powers deal 1 pip on a
  successful hit** — Push = 1 + displacement, Rocket = 1 + range, Freeze = 1 + temporary control.
  This supersedes the M4-0 assumption that Push/Freeze deal zero direct damage; their strategic
  identity still comes from the non-damage effect, not from damage alone. Falling = 0 (fall damage
  would retune closed M1 movement). Every damage instance is exactly 1 pip. **Do not generalize this
  into "every future power must deal damage"** — it is a finding about this power set, reversible if
  a future power's design calls for pure control.
- **Health exists as of the M4 direction: three coarse states** — `Healthy → Hurt → Critical →
  Defeated`. **Never a percentage bar.** The visual treatment (character-integrated flash/tint) was
  accepted at M4-1 STOP 3.
- **Health never prescribes behaviour.** No "low health → retreat/hide" rule, for humans or bots. The
  only state that changes what a player can do is `Defeated` at zero. **Never add automatic
  low-health retreat to bots.**
- **Defeat and respawn are intended** — this supersedes the old "baseline mode has no elimination"
  guardrail. **Unlimited respawns with cost, never limited lives**: nobody sits watching a match. On
  defeat the carried power spills as a contestable world pickup; a defeated carrier also drops the
  Relic. Respawn placement stays minimal — the existing authored anchor furthest from the nearest
  living opponent. Do not build a spawn director.
- Ghost gameplay is reserved as a possible future mode.
- **The objective is: grab the Relic, then carry it to the activated extraction.** This is what the
  game implements as of M4-3 (`scripts/relic.gd`/`scripts/extraction_anchor.gd`), COMPLETE / ACCEPTED
  2026-09-14, superseding the old M3-era first-touch-wins behaviour.
- **The extraction is selected exactly once per round**, on the first Relic pickup, from five
  authored region anchors at maximum region-distance from the first carrier — then **locked for the
  round.** It must never recalculate on carrier defeat, Relic drop, ownership change or respawn.
- Relic is unavailable/locked at match start, then opens automatically after a setup period.
- No multi-seal unlocking system.
- No "hold Relic for 10 seconds" requirement — the carry to extraction replaces it.
- Maximum round target is around 2 minutes, but a round may end earlier. **What happens at the time
  limit is an OPEN question** — a hard-cap/sudden-death rule was proposed at M4-0 and explicitly
  withdrawn. Do not default to one; M4-4 resolves it with evidence.
- **"You don't kill your friends, you feed them to the arena" is a design aspiration, not a proven
  rule.** M4-2 (accepted) confirmed danger zones add useful environmental pressure; **do not encode
  "the arena is the primary damage source"** as fully settled beyond that finding.
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
**Milestone 3 — Core Game Loop: COMPLETE / ACCEPTED.**
**M4-0 — Match Shape Design: COMPLETE / APPROVED (2026-09-12).**
**M4-1 — Contact: COMPLETE / ACCEPTED (2026-09-12).** Full record in `docs/DECISIONS.md`.
**M4-2 — The Arena Bites: COMPLETE / ACCEPTED (2026-09-13).** Full record in `docs/DECISIONS.md`.
**M4-3 — The Climax: COMPLETE / ACCEPTED (2026-09-14).** Implemented and automated-tested
2026-09-13 (see `docs/DECISIONS.md`'s 2026-09-13 entry for the full implementation record and a
genuine production bug found and fixed along the way), then confirmed by Game Director human
playtest and closed out, committed, 2026-09-14 (see that date's `docs/DECISIONS.md` entry for the
close-out record, the `tools/m3_check.gd` checker-contract update, and the diagnostic findings
carried forward — a P2-heavy 17/20 winner distribution and zero organic Mine placements in the short
Climax-only soak — neither acted on).

**M4-4 — The Long Match is next.** `docs/plans/M04_0_MATCH_SHAPE_DESIGN.md` remains **the authority
for the M4 phase.** **M4 is a phase of seven stages, not one milestone:** M4-0 design (done) · M4-1
Contact (done) · M4-2 The Arena Bites (done) · M4-3 The Climax (done) · M4-4 The Long Match
(in progress — see below) · GATE progression judgment · M4-5 Broader Power Set · M4-6 Economy
(conditional).

**M4-4 status: implemented and automated-tested, uncommitted, NOT accepted.** A BUILD → ESCALATE →
CLIMAX phase clock, tier-gated power access/waves, hazard escalation, an unmissable CLIMAX
transition, a Mine-availability window, phase-aware (not strategy-aware) bots, a minimal phase/timer
HUD read and a Long Match Lab were built per the M4-4 session brief, pass `tools/m4_4_check.gd` plus
a 20-match soak, and are recorded in `docs/DECISIONS.md` (2026-09-14, "M4-4 The Long Match" entry).
That session's explicit boundary: it may implement mechanics/tests/bot-only simulation and fix
in-scope bugs, but may **not** declare M4-4 accepted, choose final match timing, rebalance
players/spawns, conclude progression is unnecessary, or start M4-5. **Requires Game Director human
playtest before acceptance — do not commit M4-4 code until then.**

**Do not close open questions by assumption.** These are deliberately unresolved and must be settled
by evidence, not by a future session picking a default: all phase timings and total match duration ·
**timeout resolution** (a hard-cap/sudden-death rule was proposed and explicitly withdrawn — M4-4's
own soak deliberately continues an over-time CLIMAX within a bounded test budget rather than
resolving it) · whether stat progression is needed at all (the GATE after M4-4) · pickup density and
respawn interval · whether the post-respawn protection window becomes permanent · whether the M4-4
phase timings/tiering/hazard-escalation choices hold up under real human play.

## Documentation Deliverables
Milestone plans, audits and reports are written into `docs/` — for milestone work, `docs/plans/` — as a Markdown file (the version a future session reads) and, when the Game Director wants a review copy, an accompanying Word `.docx`. Do not deliver plans as external links; the repository must stay self-sufficient. If both formats exist for one document, the Markdown is authoritative. Note `python-docx` is not installed globally on this machine — install it into the session scratchpad to generate a `.docx`.
