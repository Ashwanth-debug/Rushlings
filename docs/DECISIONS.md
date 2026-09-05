# Rushlings — Decision Log

This file records decisions that should survive across Claude Code sessions. Add new entries when a product/technical choice materially changes implementation or prevents future re-litigation.

---

## 2026-08 — Build Rushlings, but validate it as an ugly local game first
**Decision:** Keep the Rushlings multiplayer vision, but drastically simplify the development path.

**Why:** A friend challenged the scope and suggested starting with something much simpler, similar in development complexity to a casual puzzle game. The useful insight was scope risk, not necessarily that Rushlings is the wrong product.

**Implication:** Prove the core loop with primitives, one human + bots and no networking/art before investing in production systems.

---

## 2026-08 — Godot 4.7.1 Standard + GDScript
**Decision:** Use Godot 4.7.1 Standard, not the .NET/C# build.

**Why:** Rushlings is a 2D game and GDScript is simpler, well-integrated with Godot and suitable for AI-assisted implementation.

---

## 2026-08 — AI-assisted workflow
**Decision:** Claude Code is the primary coding agent, connected to Godot through MCP. GitHub is the safety/checkpoint layer.

**Why:** The Game Director does not want to manually code/rig/build VFX or routinely use Terminal.

**Operating model:** Game Director directs/playtests; Claude plans/implements/tests/maintains docs.

---

## 2026-08 — Fixed straight-on 2D arena
**Decision:** Baseline gameplay uses a straight-on 2D side-view fixed camera.

**Rejected:** Isometric/top-down and scrolling-map baseline.

**Why:** The fixed side view preserves the core multiplayer value: everyone can see where friends are and what they are doing. It also reduces directional character-animation complexity and avoids a 3D/MOBA feel.

---

## 2026-08 — Entire arena remains visible
**Decision:** No camera scrolling in baseline mode.

**Why:** Seeing all players simultaneously is part of the product proposition, not merely a technical constraint.

---

## 2026-08 — Landscape mobile
**Decision:** Mobile-first landscape game.

**Why:** Better horizontal arena space and multiplayer visibility. Bottom screen space should remain clear for thumbs.

---

## 2026-08 — Minimal controls
**Decision:** Design toward movement + one power action.

**Current constraint:** No dedicated jump button.

**Why:** Game should be immediately approachable on mobile and not feel like a console controller overlaid on a phone.

**Validation needed:** M1 must prove contextual vertical traversal is fun enough. This may be revisited based on playtesting.

**Status — partially superseded (2026-09):** The "no dedicated jump button" constraint was superseded after Milestone 1 playtesting; see "2026-09 — Rushlings has a player-controlled jump". It is preserved here as history rather than deleted, because the validation it called for is exactly what produced the change. The rest of this decision — minimal controls, movement plus one power action, no console-style button layout — still stands.

---

## 2026-08 — Simplify match to two phases
**Decision:** Baseline match has only:
1. Power-up/position phase.
2. Relic race phase.

**Rejected:** Multi-seal unlocking, four-stage objectives, and hold-the-Relic-for-10-seconds baseline.

**Why:** Those systems demanded too much explanation. The game should be understood in seconds.

---

## 2026-08 — Relic opens automatically
**Decision:** Relic is protected/locked initially and opens automatically after a short setup period (~25 seconds working value).

**Why:** Keeps early movement/power positioning meaningful without asking users to understand a seal puzzle.

---

## 2026-08 — First to touch Relic wins
**Decision:** Baseline victory occurs immediately when the first player reaches/grabs the open Relic.

**Rejected:** Mandatory 10-second possession/hold.

**Why:** Simpler mental model. Can revisit if playtesting reveals anticlimactic endings.

---

## 2026-08 — One power at a time
**Decision:** Player can carry one power. Touching a pickup collects it.

**Why:** Avoid inventory/ability-bar complexity and keep mobile HUD minimal.

---

## 2026-08 — Initial power set
**Decision:** Prototype the following powers:
- Push.
- Freeze.
- Teleport.
- Shield.

**Why:** They emphasize interfering with friends rather than conventional combat.

**Note:** Add/tune one at a time; remove any that are not fun.

---

## 2026-08 — No baseline elimination / ghost mode
**Decision:** Baseline mode does not eliminate players. Use short respawn.

**Previous exploration:** Defeated players becoming ghosts that manipulate the arena was considered fun.

**Why removed from baseline:** It introduces another rule/state before the simple game is proven.

**Parking lot:** Haunted/Ghost mode later.

---

## 2026-08 — Bots are first-class
**Decision:** First complete game should be playable as one human + three bots.

**Why:** Enables solo development/testing, reduces cold-start problems for future multiplayer and may later fill empty/disconnected slots.

**Technical:** Use normal game AI, not LLMs.

---

## 2026-08 — Tiny Relic Hunters as player character direction
**Decision:** Player characters are Tiny Relic Hunters (“Rushlings”).

**Character requirements:**
- Two expressive eyes.
- Strong small-scale silhouette.
- Large head/small body.
- Adventurous/mischievous.
- Hoods/horns/ears/helmets/scarves etc.
- Not tied to power classes.

**Rejected:** One-eyed/symbol-like main characters and generic mythical creatures as primary direction.

---

## 2026-08 — Masks are cosmetics
**Decision:** Ancient mask-spirit language becomes optional collectible/equippable masks rather than the only player-character form.

**Why:** Preserves emotional connection while creating scalable cosmetic identity.

---

## 2026-08 — Bright ancient mountain ruins world
**Decision:** Broad visual world is ancient ruined temples/civilization high in mountains, with bright sky/clouds/distant ruins.

**Why:** Earlier bright ruin concepts had better character readability and broader adventurous tone.

**Rejected as baseline themes:**
- Dense enchanted forest: characters became hard to find.
- Dark machine/forgotten kingdom: too dark/heavy/scary.
- Giant toy world: too child-oriented.

**Note:** These ideas can inform future arenas without replacing the broad world.

---

## 2026-08 — Multiple arenas within one world
**Decision:** “Temple” is an arena/region, not the entire game identity.

**Potential regions:** Mountain Temple, Water Garden, Sun Observatory, Cloud Forge, Broken Palace, Floating Gardens.

---

## 2026-08 — Art style can vary without changing gameplay structure
**Decision:** Future flat-color/painterly/pixel/high-definition style explorations must preserve the same fixed camera, arena layout and gameplay structure when being compared.

**Why:** Previous visual experiments accidentally changed the game format, making art-style comparisons invalid.

---

## 2026-08 — 2D production, not 3D
**Decision:** Do not require 3D character production for the current direction.

**Future production preference:** reusable modular 2D rig + in-engine VFX/procedural animation.

**Why:** Lower production complexity and better fit for tiny side-view characters.

---

## 2026-08 — Multiplayer networking is delayed
**Decision:** Do not implement server/backend/networking until local game is fun and polished enough to justify it.

**Why:** Networking is one of the largest technical risks and should not be solved before core fun.

**Future preference:** evaluate server-authoritative architecture at M8; do not prematurely lock Nakama/Supabase/custom solution.

---

## 2026-08 — Working name: Rushlings
**Decision:** Use “Rushlings” as the working product/project name.

**Why:** Stronger potential as an ownable character/IP name than generic Relic/Ruin descriptive names.

**Caveat:** Formal trademark/store/domain clearance must be repeated before brand investment/release.

---

## 2026-09 — Rushlings has a player-controlled jump (supersedes the no-jump constraint)
**Status: ACCEPTED** after Milestone 1 iteration 2 playtesting. Jump, launch pad and wrapping were all played together and the movement model was accepted.

**Decision:** Rushlings includes a normal player-controlled jump. Prototype binding: Space, or W/Up when not engaged with a traversal zone.

**Supersedes:** the “No dedicated jump button” constraint in “2026-08 — Minimal controls”. That entry is kept as history, not deleted.

**Why:** This came from actually playing the game, not from argument. The Milestone 1 Movement Lab was built specifically to test whether horizontal movement plus contextual arena traversal was enough. It was not — it felt too restrictive for the game we are trying to create. The original constraint asked for exactly this validation, and the validation rejected it.

**Shape of the jump:**
- Grounded only, or from a ladder. No double jump, no wall jump.
- No variable/charged jump.
- Horizontal momentum is preserved through the jump; existing air steering applies.
- Tunable `jump_strength`, deliberately separate from and much weaker than `launch_strength`.

**Jump off ladders — ACCEPTED (2026-09, iteration 2):** while climbing, jump detaches the player from the ladder and performs a normal jump. A horizontal direction held at that moment carries them away from the ladder. The player cannot re-attach to the same ladder during that jump while the climb input stays held; releasing and pressing it again is treated as a deliberate re-engage. This keeps ladders from feeling like traps.

**Retained:** launch pads and ladders/contextual traversal both stay. Jump is normal player movement; launch pads are stronger environmental traversal that reaches places a jump cannot. Contextual traversal is no longer the *only* way to move vertically, but it is still how the arena creates route choices.

**Open question:** how jump maps to the minimal mobile control scheme (movement + one power action) at M5. Adding a third touch input must not turn the phone screen into a console controller. Not yet decided.

---

## 2026-09 — Horizontal screen wrapping (validated direction, under active testing)
**Decision:** The arena's left and right edges are not walls. A player that leaves completely through one edge re-enters from the opposite edge at the same height, keeping vertical position, direction and horizontal momentum. No fade, respawn, loading state, reset animation or spawn delay.

**Status: ACCEPTED** after Milestone 1 iteration 2 playtesting. The current behaviour — wrap once the body has left the edge completely, preserving height and momentum — was played and accepted as-is.

**Why:** It turns the fixed single-screen arena into a continuous horizontal loop. That suits the “everyone is visible at once” format, adds route and escape options, and costs no extra buttons and no camera scrolling.

**Intent:** This is part of Rushlings' arena-navigation language, not a debug convenience.

**Implementation notes:**
- Only the X coordinate is modified, so arenas with multiple vertical layers reuse the behaviour unchanged — a body wrapping on an upper layer stays on that layer.
- Anything in the `wrappable` group wraps, so future Rushlings, bots and objects inherit it without knowing the wrap exists.
- An `exit_margin` provides hysteresis, so a body that has just wrapped cannot immediately wrap back.

**Resolved (2026-09, iteration 2):** wrapping triggers on full exit. The alternative — wrapping when the body's centre crosses the edge, showing it split across both edges — was considered and is not needed. Full exit felt continuous in play.

---

## 2026-09 — Movement values are tuning data, not design constants
**Decision:** The numeric movement values produced by M1 — `climb_speed`, `jump_strength`, `max_speed`, `acceleration`, `friction`, `gravity`, `launch_strength` — are recorded as current tuning data, not as permanent game-design constants. They stay exported and easy to change, and are expected to move again as arenas, powers, bots and mobile controls arrive.

**Why this is worth writing down:** climb speed alone moved 260 → 320 → 400 across two playtests. Treating any of these as settled design would invite pointless re-litigation later. What is settled is the *model* — floor-only friction, preserved air momentum, grounded jump, latched climbing, full-exit wrapping — not the numbers inside it.

**Current M1 values:** max_speed 500, acceleration 3000, friction 3500, gravity 2200, jump_strength 900, launch_strength 1500, climb_speed 400.

---

## 2026-09 — Mobile control mapping stays unresolved until M5
**Decision:** How Run + Jump + Power map onto touch is deliberately left open until the Mobile Controls milestone.

**Why:** M1 deliberately used keyboard, and the prototype mapping (including W/Up doubling as jump outside a ladder and climb inside one) is a keyboard convenience, not a design commitment. Jump adds a third input to what was planned as movement + one power action, and resolving that on paper before testing real thumbs would be guessing.

**Constraint that still holds:** the result must not become a console-style D-pad plus button cluster on a phone. See "2026-08 — Minimal controls".

**Implementation note:** movement physics reads intent through three functions (`_get_horizontal_intent`, `_get_vertical_intent`, `_get_jump_intent`). M5 replaces those bodies with touch/gesture input without touching movement physics.

---

## 2026-09 — M1 accepted: the Rushlings movement language
**Status: ACCEPTED.** Milestone 1 — Movement Lab is complete, accepted by the Game Director after three manual playtests.

**Decision:** Rushlings' movement vocabulary is settled as:
1. Horizontal movement with acceleration and deceleration.
2. Player-controlled jump — grounded or from a ladder, no double jump, no wall jump, no charged jump.
3. Air steering, with horizontal momentum preserved in the air (deceleration applies on the floor only).
4. Contextual ladder traversal — latched, holds position with no input, ends level with the destination.
5. Jump off ladder, carrying any held direction away from it.
6. Environmental launch pads — automatic on contact, stronger than a jump, reaching places a jump cannot.
7. Horizontal screen wrapping — leave one edge completely, re-enter the other at the same height with momentum intact.

**How this was reached:** three playtests, each of which changed the design. The first rejected the original no-jump-button premise. The second added jumping off ladders and raised climb speed. The third accepted the result. None of this came from theory; every change came from playing it.

**What is settled versus what is not:** the *model* above is settled. The numeric values inside it are not — see "2026-09 — Movement values are tuning data, not design constants". The mobile mapping is not — see "2026-09 — Mobile control mapping stays unresolved until M5".

**Kept for reuse:** the Movement Lab scene stays in the project as a regression and tuning harness, not as a shippable arena.

---

## 2026-09-06 — In a wrapped arena, the objective is protected by height, never by horizontal distance
**Decision:** The Relic is protected by vertical structure and approach design. Horizontal position is never used as protection.

**Why:** The arena's left and right edges connect, which makes it a cylinder of circumference 1920. Every player is at most 960 px from any x-coordinate, in *both* directions, so x=960 is topologically identical to x=0. "Put the Relic in the centre so it is far from everyone" is not a real statement about a wrapped arena — horizontal centrality confers zero protection.

**Implication:** Arena 01's Relic is an elevated deck with no ladder to it, reachable only by a launch, a long climb, or a seam crossing. It sits 90 px right of mathematical centre — enough to break false symmetry, not enough to stop reading as the arena's focal point.

**Constraint that survives this:** the Relic must still read instantly as the objective. If the offset ever costs recognisability, recognisability wins and it moves back toward centre.

**Applies to:** every future arena, not just Arena 01.

---

## 2026-09-06 — Arena 01 architecture: three approaches, wrapping as connective tissue
**Decision:** Arena 01 ("The Seam Ring") offers **three structurally distinct approaches** to the Relic — a fast/skill launch route, a safe/legible ladder route, and a positional/flanking seam-wrap route — plus four walkable bands and the Relic destination deck.

**Rejected:** five parallel routes (fast / safe / vertical / launch / wrap). "Vertical" and "launch" are traversal *verbs*, not destinations. Five lanes converging on one 260 px deck reads as noise, not choice. What creates real route choice is **arrival property** — from below, from the side, or from the far side of the seam.

**Rejected:** a fifth top-tier catwalk layer. Its access ladder had to top out at y≈60 (consuming the HUD band), its drop onto the Relic had to be ≥200 px to stay one-way, and its payoff was a single one-way approach costing a 1.15 s climb. Too much arena for one door.

**How wrapping earns its place:** the Band-3 ring **closes only through the seam**. Crossing it is ~2.5× faster than going around the inside. Crossing the seam *repositions* you; it does not deliver you to the Relic — every approach still requires one of the three ring entrances below Band 3.

**Hard rule:** no hazards within 200 px of the seam, ever. If crossing the seam is punished, players stop doing it and the ring dies.

**Full design:** `docs/plans/M02_GREYBOX_ARENA.md`.

---

## 2026-09-06 — Route-cost measurement is diagnostic, not normative
**Decision:** Automated route timing and reachability measurement exists to detect unfair spawns, impossible geometry and accidental dominant shortcuts. It does **not** normalise routes to equal travel time.

**Specifically:**
- The fast route is *allowed* to be meaningfully faster, because it carries more execution and interception risk.
- The ≤15% spawn-to-objective spread is an initial fairness **diagnostic**. If satisfying it would damage route identity, the checker **flags** the deviation and the arena is left alone.
- **Human playtesting overrides mathematically elegant route timing.**

**Why this is worth writing down:** a measurement tool that can also authorise geometry changes will quietly flatten an arena into four equivalent lanes. The numbers report; they do not design.

---

## 2026-09-06 — Readability outranks route-graph complexity
**Decision:** When an arena's implemented greybox feels visually crowded or hard to parse at 1920×1080, **simplify or remove geometry** rather than preserving the planned route graph.

**The target experience:** see → understand → choose → move.
**Not:** study the level → understand the graph → move.

**Why:** Arena 01's graph is deliberately sophisticated for a first arena. Sophistication on paper is cheap; legibility on a phone at gameplay scale is the actual product constraint. A platform a playtester calls unnecessary is a candidate for deletion, not defence.

---

## 2026-09-06 — Arena geometry is proven by a permanent committed checker
**Decision:** `tools/arena_check.gd` is a permanent, committed regression tool. This reverses M1's practice of deliberately not committing its harness.

**Why:** M1's throwaway harness still earned its place three times, twice by catching geometry that was visually plausible but physically impossible. M2's geometry has more simultaneous constraints, and M3/M4/M6 are likely to regress it silently.

**What it enforces** — derived from the M1 movement constants, and binding on every future arena:
- **R1** Step-up ≤150 px (comfortable) or ≥200 px (deliberate barrier). **155–184 px is forbidden** — that band looks jumpable and intermittently fails.
- **R2** Level gap ≤280 px comfortable; **281–420 px forbidden**; >420 px is a deliberate barrier.
- **R3** A launch pad's column must be clear to its apex, and its arc must not clip any platform's underside or edge inside the reachable cone.
- **R4** A ladder column must be clear from base to top, and its top must sit **80–100 px above** the destination surface. A top level with the surface leaves only ~52 px of step-over and the climber falls back down.
- **R5** Launch pads only on surfaces at **y ≥ 620** — a 511 px rise from anything higher exits the top of the screen and breaks "entire arena visible."
- **R6** Any seam-crossing platform needs collision covering x ∈ [1920, 1978] and [−58, 0]. Wrapping triggers only after the origin passes 1960, so a body between 1920 and 1960 is off-screen and **still needs floor**.

**Principle:** if an arena needs a movement change to work, the arena is wrong, not the movement.

---

## 2026-09-06 — Vertical-only launch pads; angled pads are a movement question, not an arena one
**Decision:** Arena 01 uses vertical launch pads only. M1 launch/movement physics is not changed to support angled pads.

**Why:** `receive_launch()` adds `dir.x * launch_strength` to horizontal velocity with no clamp, while air steering uses `move_toward(velocity.x, intent * max_speed, ...)`. After an angled launch, **holding the direction of travel decelerates you** toward 500 while releasing input preserves ~1060 — backwards, and it would make an angled pad feel broken.

**Status:** recorded as a known movement characteristic, not an M2 defect. If angled pads are ever wanted, that is a movement change requiring its own approval.

---

## 2026-09-06 — No portals in Arena 01
**Decision:** Arena 01 ships without portals.

**Why:** every candidate portal function is already covered — instant lateral repositioning by horizontal wrapping, skipping vertical layers by the launch pad, and unexpected arrival by crossing the seam at Band 3. The only genuinely distinct function left is bidirectional teleport between two arbitrary non-adjacent points, and **the Teleport power at M4 is planned to use paired-portal logic**. Arena portals now would blur the reading of that power: a player seeing a portal effect could not tell whether it was arena furniture or someone's power.

**Revisit condition:** if M2 playtesting shows a genuinely missing connection type, add one then, with evidence.

---

## 2026-09-06 — First contact with a new arena is unprompted exploration
**Decision:** The first human test of a new arena is unstructured. The Game Director is told the controls and one instruction — *"Explore the arena and try to reach the Relic deck"* — and nothing about the intended routes, the seam, or the layout. Structured route validation happens only afterwards.

**Questions asked after that first session:** which route was discovered first; was the Relic's location understood; did the arena feel like one connected place; was wrapping discovered naturally as navigation; was anything visually reachable but physically unreachable; did they get stuck; which areas felt unnecessary or confusing.

**Why:** an arena's real deliverable is whether it teaches itself. Walking the tester through the intended routes first destroys the only chance to measure that, and would make "the routes are discoverable" unfalsifiable. The question about visually-reachable-but-not is the M1 failure mode; the question about unnecessary areas feeds the readability-over-complexity rule above.
