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
**Status — SUPERSEDED the same day by "Arena 01 V2 architecture: four bands, one wall, a sunken vault" below.** Kept as history, not deleted: this is the architecture that was built, played, and found to be solving the wrong problem, and the reasoning below is what the playtest actually falsified. The *principle* that route choice comes from **arrival property** rather than from parallel lanes survives into V2; the geometry does not.

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

**Extended (2026-09-06, Arena 01 V2):** first contact now begins one step earlier, with the **objective hidden**. See "An arena must be a good playground before it is a good racetrack" below.

---

## 2026-09-06 — An arena must be a good playground before it is a good racetrack
**Status: ACCEPTED.** This is the primary lesson of Arena 01 Playtest 1 and the reason Arena 01 was redesigned rather than patched.

**Decision:** Arena design starts from *"is this a good place for four players to be at once?"* and only then asks *"how does the objective sit inside it?"* The test is concrete:

> **If the Relic were temporarily removed, would four players still have an interesting playground?**

Arena 01 V2 must pass that test, and every future arena must too.

**Why:** Arena 01 V1 was designed around *"how does each player reach the Relic through different routes?"* It answered that question well — three genuinely distinct approaches, correct movement maths, a working seam ring — and produced an arena the Director described as isolated floating platforms with too much empty space, no proper floor, no four-player territories, and nowhere to chase, interfere or eventually use powers. **A correct answer to the wrong question.**

**How it is enforced, not merely stated:**
- The **first human playtest of a new arena runs with the objective placeholder hidden.** Controls only, one instruction — *"Move around this arena for three minutes."* No routes, zones or strategies explained. The question asked afterwards is whether moving through the arena was enjoyable *in itself*.
- Only after that session is recorded is the objective shown, for the separate navigation test.
- If the arena is not enjoyable to move around empty, no amount of objective tuning fixes it.

**Also decided:** arena geometry must be designed with **future power/projectile interaction** in mind even while powers are unimplemented — duel zones, interception points, push/drop opportunities, escape paths and crossfire areas are part of the arena design deliverable. Powers are not implemented earlier because of this; the *space for them* is reserved earlier.

**Applies to:** every arena, not just Arena 01.

---

## 2026-09-06 — The player's mental model must stay simple, however sophisticated the arena is
**Status: ACCEPTED.** Extends "Readability outranks route-graph complexity" above with an explicit, testable statement of what the player must perceive.

**Decision:** The arena architecture may be sophisticated internally, but the player's mental model must remain simple. A new player should perceive approximately:

- a floor
- lower platforms
- upper platforms
- a central protected area
- ladders
- a launcher
- wrapping

**They must not need to understand named route nodes or the route graph in order to play.**

**Why:** V1's route graph was legible *on paper* — bands, approaches, a ring closing through the seam — and every node had a justification. None of that reached the player. Node names like `B3S` or `B1.5W` are implementation and tooling labels; the moment an arena requires the player to hold that structure in their head, it has failed regardless of how good the structure is.

**Implication:** internal naming stays as precise as the checker needs. Nothing in the greybox may *depend* on that naming being perceivable. The target remains **see → understand → choose → move**.

---

## 2026-09-06 — Primary objective access must never require precision momentum
**Status: ACCEPTED** at Arena 01 V2 approval, and it changed the geometry.

**Decision:** No normal entrance to the objective may depend on precision execution. Specifically: **there must be no objective entrance where walking versus running off the same edge determines whether the player succeeds.** Every normal-route entrance must succeed from a standing start, with zero horizontal velocity.

**Precision traversal may exist** — but only as *optional* skill shortcuts, explicitly tagged as such, never on a primary route to the objective.

**What it changed in Arena 01 V2:** the proposed vault had a 100 px shaft between the wall and the chamber floor, so walking off the wall dropped the player a band lower while running off it landed them inside. Two changes fixed it: the vault floor was extended to abut the wall (so a player with zero velocity slides down its face straight into the chamber), and the downward bail-out gap was removed because it reintroduced the same ambiguity on the opposite door. The recorded cost — the vault now has one two-way door rather than a third escape hatch — was accepted deliberately: **a forgiving primary entrance outranks an extra exit.**

**How it is enforced:** new checker rule **R8** in `tools/arena_check.gd` — every entrance on a normal route to the objective must be proven from a standing start.

---

## 2026-09-06 — Wrapping's success criterion is behavioural, not a timing ratio
**Status: ACCEPTED**, superseding the numerical wrap requirement written for Arena 01 V1.

**Decision:** Wrap-route timing continues to be **measured and reported** by `tools/arena_check.gd` as a diagnostic. It is **not** an acceptance threshold. The criterion is:

> **During play, does the player intentionally choose wrapping for escape, chasing, flanking or repositioning?**

Human playtesting overrides the ratio **in both directions** — a good ratio with no observed use is a failure; observed intentional use with a poor ratio is a success.

**Supersedes:** V1 acceptance criterion 7, *"wrapping is used by ≥1 route whose alternative is ≥2× longer."*

**Why:** in a wrapped arena the world is a cylinder, so "around the other way" is never more than half the circumference. A large timing advantage can therefore only be manufactured by building the entire arena around the seam — which is exactly what V1 did, and exactly what the V2 brief said to stop doing. The number was measuring the architecture's obsession with the seam, not the player's use of it. This is the same principle as *"route-cost measurement is diagnostic, not normative"*, applied to wrapping.

**Retained unchanged:** no hazards within 200 px of the seam, ever.

---

## 2026-09-06 — Arena 01 V2 architecture: four bands, one wall, a sunken vault
**Decision:** Arena 01 V2 (internal working name "The Gallery") replaces V1's geometry entirely. Full brief: `docs/plans/M02_ARENA_01_V2.md`.

**The organising idea:** a four-storey building with one continuous street, where **it is cheap to fall and expensive to climb.** Every platform drops to the floor in under a second; nothing climbs in under a second. A chased player's escape is therefore always *down and around*, and a chaser's counter is always *predict where they land*. Height is a resource you spend, not a position you hold. That asymmetry is what makes the arena fun with the objective removed.

**Structure:** a continuous wrapping floor · a lower gallery 140 px above it (so the two read and play as one two-storey lower zone) · an upper gallery **severed by a single solid wall** · and a Crown band whose centre is a **sunken vault** holding the Relic. Four starting territories — top-left and top-right on the upper gallery, bottom-left and bottom-right on the floor. **Nobody spawns on the objective band.**

**Rejected from V1 and deleted rather than patched:** all V1 geometry, `B1.5W` (playtested as unnecessarily difficult), and the conflicting launch route.

**Recorded reduction:** V1's approved "three structurally distinct approaches" becomes **two Crown entrances and two vault doors** in V2. A central vault plus a Band-B seam bridge leaves only two full-height clear columns in the frame; every third-entrance candidate either fired a launch arc into a platform's underside (V1's exact failure) or handed one spawn a ~1.8 s walk to the Relic. **This is flagged as the single thing to watch in playtest**, with a named fix documented but deliberately not applied pre-emptively.

**The launcher's identity is now fixed:** *escape the bottom, dramatically, and choose your side at the top.* It sits on the floor, reaches only the upper gallery, and **cannot reach the objective band by construction** — its apex is 93 px below it. V1's launcher was the required precision solution to reach the Relic; this one cannot be.

**Retained from V1 without change:** every script (`player.gd`, `arena_wrap.gd`, `traversal_zone.gd`, `launch_pad.gd`, `seam_mirror.gd`, `arena_01.gd`, `debug_hud.gd`), the scene architecture, the greybox palette, and `tools/arena_check.gd`'s harness. **V2 changes the arena, not the systems.**

---

## 2026-09-06 — Ladder vulnerability to Freeze is an M4 question, not an M2 one
**Decision:** Arena 01 V2 keeps its ladder spacing and 1.53 s climb duration for the first implementation. M2 is **not** redesigned around a hypothetical balance problem in an unimplemented power.

**The concern, recorded so it is not rediscovered:** a Freeze landing on a player mid-climb is the longest forced-immobility window the arena can produce. Both ladders are also the arena's strongest interception geometry — a climber is stationary and fully visible for the whole climb — which is deliberate design, and only becomes a *balance* problem once powers exist.

**If M4 shows it is genuinely unfair,** the candidate fixes are on the **power** side first — cap Freeze duration, or make climbing interruptible — before any arena change.

**Why this is worth writing down:** it is the same failure mode as designing the arena around route timing. Reshaping proven geometry to pre-empt an unbuilt system's balance is guessing, and it costs the thing the geometry was actually built for.

---

## 2026-09-06 — Arena 01 V2 Playtest 1a: accepted, and hard-to-reach spots are pickup value, not a defect
**Status: ACCEPTED.** First unprompted human playtest with the Relic hidden (Session 1a, per V2-A7).

**Decision:** The V2 redesign works substantially better than V1. The Game Director explored all major sections unprompted, including both ladder columns and the upper areas, and confirmed the arena is worth exploring even with the objective hidden — the primary V2 design test (`docs/plans/M02_ARENA_01_V2.md` §1.1) passes.

**Also decided:** some locations are *intentionally* more difficult to reach (e.g. `B_Under`, the pier top, the Band C gap beneath the vault — the existing "see it, can't reach it" spots noted in `M02_ARENA_01_V2.md` §9.4 and §11). **Do not simplify these.** They are recorded as the arena's **highest-value future power-pickup candidates**, on the reasoning that travel effort should be repaid by a stronger pickup. This confirms and strengthens the pickup-candidate positions already marked in `M02_ARENA_01_V2.md` §11 — no new positions were added, but their difficulty is now a validated feature, not a candidate for deletion.

**Note:** the Director has since hand-edited some V2 structure positions/sizes directly in the editor ("moved the position of some of the structure to make it interesting") after this playtest. Per instruction, this geometry is not being re-validated or reverted this session.

---

## 2026-09-06 — M4 hypothesis (unimplemented): Freeze may have a direct mode and an environmental/surface mode
**Status: RECORDED FOR M4. Not approved, not implemented. Exploration only.**

**The idea:** Freeze could support two interaction types:
- **Direct Freeze** — used against another player, temporarily immobilizes/slows them (the originally planned behavior).
- **Environmental Freeze** — used on part of the *arena*: a floor/platform becomes temporarily icy (players lose traction/slide on contact), or a ladder becomes temporarily unclimbable/slippery (a climber slides back down).

**Why it's worth recording:** the design opportunity isn't the ice specifically — it's that a power could affect the **arena itself**, not just other players, making the arena part of the multiplayer interference rather than just a stage for it. That is a genuinely new axis for the power set and worth evaluating properly at M4.

**Explicitly not done now:** no ice physics, no surface-state system, no Freeze implementation, no power system of any kind in M2. This is a hypothesis for M4 playtesting, not a spec.

---

## 2026-09-06 — Playtest 1a "Push" clarification: no Push mechanic exists in the M2 build
**Decision:** Investigated after the Director described "experiencing Push" during Playtest 1a. `grep -rniE "push" scripts/ scenes/ project.godot` returns **zero matches** anywhere in the project. No power system of any kind is implemented — M2 is movement/arena only, per the approved roadmap.

**Conclusion:** what was experienced was ordinary collision/movement physics, not a Push power. The most likely candidates, given the arena's geometry: colliding with a solid corner (the pier's wall, or `CoverW`/`CoverE`) during `move_and_slide`, which can visibly deflect/stop a body in a way that can read as being "pushed"; or the launch pad's momentum on arrival. No code change made — there is nothing to change. This is recorded so the question is not re-asked, and so a real Push power (M4) is understood to start from zero, not from an accidental prototype.

---

## 2026-09-06 — Tempo observation: 1.25x debug playback felt good (tuning note, not a change)
**Decision:** Recorded only. The Director found the arena "particularly enjoyable" running Godot's debug playback at 1.25×. This is **not** applied — M1 movement constants (`max_speed`, `acceleration`, `friction`, `gravity`, `jump_strength`, `launch_strength`, `climb_speed`) are unchanged.

**Why recorded, not acted on:** this is a single-session impression on one specific arena, not a validated tuning direction. Scaling movement speed and scaling engine playback speed are not equivalent (playback speed also scales physics timestep and everything else in the world uniformly, including camera perception time), so this does not imply "increase `max_speed` by 25%." Revisit as a game-feel hypothesis in a future tuning pass, with its own dedicated test rather than folded into M2.

---

## 2026-09-06 — Relic chamber gateways: physical, not just colour — and why the east side isn't symmetric with the west

**Status: ACCEPTED**, implemented in Arena 01 V2 after Playtest 1b. Full context: the Director felt the vault didn't read as protected ("climb → jump/drop → reach Relic," no sense of entering somewhere) and asked for actual physical gateways — narrow openings between solid geometry — rather than a colour-only threshold marker, modelled on a reference showing a solid structure with two narrow doorway cutouts.

**West gateway (built as designed):** a new wall, `VaultGateW` (40×160, x 920–960, y 210–370), stands east of the Pier, leaving a 100px-wide fall corridor (Pier's east face at x=820 to `VaultGateW`'s west face at x=920) that a player drops through after stepping off the Pier-top walkway. Its underside (y=370) sits 90px above the vault floor (y=460) — well clear of the floor, so it narrows the *fall* without becoming a wall that divides the chamber once someone has landed.

**East gateway: the same design does not work, and was reverted after being built and caught by the checker.** The first implementation added an equivalent wall on top of `A_E`'s own walking surface, meant to leave only a "lane" near the step down to `VaultEast`. Simulation showed this wall doesn't create a passable gap — it's a full, unclimbable blocker (by design, since it must not be jump-overable) sitting on the *only* path along a straight one-directional corridor. Unlike the west's vertical shaft (open air, no surface to walk along), a wall on a walking surface in this move set (no duck/crouch) can only ever fully block or fully not-block the corridor behind it — there is no "narrow passable gap" available on a 1D walking lane. The wall was removed (`VaultGateE` node and its shape both deleted).

**What the east side has instead:** its existing geometry. `VaultEast` (80px wide, distinctly coloured at 0.58 grey vs. ordinary platforms' 0.45) was already the sole path in and out — "everything funnels here" per the original approved design — a narrower physical chokepoint than the west's new 100px gap. No new wall was needed or added; the asymmetry between a one-way vertical drop (west) and a two-way stepped descent (east) is a difference in *kind*, not something a matching wall could paper over.

**Also fixed in the same pass (connectivity, not gateway design):**
- `A_W_Bridge` (90×40, x 650–740) — restores the walkway from the Director's narrower `A_W` (530–650) to the Pier (740–820), which the narrowing had disconnected by a 90px gap.
- `A_E_Bridge` (184×40, x 1466–1650) — same fix on the east side: the Director's shortened `A_E` (now ending at x=1466 instead of 1620) had opened a 184px gap to `LadE`'s column (1650–1730), meaning the ladder's own restored height alone wasn't sufficient — restoring reach required both.
- `LadE`'s column height was restored to its original 610px (top y=210, base y=820 unchanged) — a prior hand-edit had shortened it to 411px (top y=409), which no longer reached `A_E`'s height at all and silently turned the east Crown route into a dead climb to `B_E`.
- `CoverW` was given its own collision shape (`CoverWShape`, 140×80) instead of sharing `CoverE`'s resized one (`CoverShape`, 140×37) — the shared resource meant resizing `CoverE`'s collision had also shrunk `CoverW`'s without moving its visual, leaving roughly 21px strips at the top and bottom of the drawn block that looked solid but weren't.

**New finding, not fixed:** with `B_Under` lowered (an accepted hand-edit), the rise from `C_W` to it is now 184px — within a hair of the M1 jump's absolute maximum (184.1px). `arena_check.gd`'s R7 rule flags this because `B_Under` is only 140px wide (below the 280px minimum for a non-skill landing), the same class of issue R7 was built to catch. Not fixed, because `B_Under` is one of the Director's confirmed "intentionally hard to reach, high pickup value" spots (see the Playtest 1a entry above) — a jump sitting right at the theoretical limit may be exactly the kind of difficulty that's wanted there. Recorded for a deliberate decision, not silently patched.

---

## 2026-09-06 — Relic closed-gate visual (M2 readability only)

**Status: ACCEPTED.** Final human playtest confirmed the static gate clearly communicates the Relic is CLOSED/unavailable.

**Decision:** Added a purely visual "closed vault" treatment around the Relic — no collision, no script, no state, matching `RelicPlaceholder`'s own simplicity. It reuses the Director's rotated `VaultGateW` beam (now a horizontal header at x 920–1080, y 336–376, directly above the Relic) as the lintel, and adds six thin vertical bars (`RelicGate/Bar1`–`Bar6`, 6px wide each, y 376–460) spaced across x 927–1073, framing the Relic (x 980–1020) with visible gaps between bars so it still reads as "something valuable, behind bars" rather than fully hidden.

**Also fixed:** `tools/arena_check.gd`'s geometry extraction (`_aabb_of`) didn't account for rotation at all, and crashed outright on a `CollisionShape2D` with no shape assigned. Both are now handled (rotated shapes get a proper rotated-corners bounding box; a shapeless collision node reports a zero-size point instead of crashing the checker). Tooling correctness, not a design change.

**Found, flagged, and resolved at M2 close-out:** further hand-edits since the gateway approval — `VaultFloor` narrowed and shifted, and `VaultGateW` lost its collision shape when rotated — broke the west door and briefly made the vault a true trap. See "M2 close-out" below for the fixes.

---

## 2026-09-06 — M2 close-out: final connectivity fixes on the Director's hand-edited geometry

**Status: ACCEPTED.** Milestone 2 — Arena 01 V2 is complete. This entry records the last three implementation-defect fixes made while auditing the Director's manual edits against the checker, immediately before accepting Arena 01 V2 as the M2 baseline. All three are narrow corrections tied to a specific defect (missing collision, a connectivity gap, or a trap) — none change the Director's intentional geometry (position, width, or the "taller wall" character of `VaultEast`) beyond what was needed to fix the defect.

**1. `VaultGateW` (the rotated header above the Relic) had no collision shape.** Rotating it in the editor had detached its `CollisionShape2D` from any shape resource (the resource itself was also dropped from the scene). This is squarely "missing collision caused accidentally by rotation/editing." Fixed by re-adding `VaultGateWShape` (40×160, unchanged from its original size) and a local position offset (66, −60) that places it exactly where the visual already was — no change to what's seen, the collision now simply matches it. Also serves as a solid header for the Relic gate, which reads as more "closed."

**2. `VaultFloor` had been narrowed from 820–1220 to 922–1220, opening a 102px gap between the Pier's east edge and the vault floor.** This made the west door's drop-in land on `C_W` (Band C) instead of the vault — "impossible traversal caused unintentionally." Fixed with `VaultFloor_Bridge`, a new 102×40 patch filling exactly that gap (x 820–922), rather than widening `VaultFloor` itself back to its old size — the Director's narrower vault floor is preserved unchanged; the gap it opened up next to the Pier is what's patched.

**3. `VaultEast` had grown from a short step (~100px tall) to a 288px-tall block (y 172–460), and its top was now high enough to obstruct the standing-start drop from `A_E` rather than catching it.** Investigated further: with the west door already one-way-in by design (see "protected by height" and "one-way in" decisions above) and this east block now un-jumpable in *either* direction (rise from `VaultFloor` to its top was 288px, the M1 jump's absolute max is 184.1px), **the vault had become a true trap with no way out at all.** That crosses from "the Director is exploring a taller wall" into "player becoming trapped" — one of the explicit defect categories, not a design question left open. Fixed by trimming `VaultEastShape` to 140px tall (top now at y=320, keeping its bottom anchored on the vault floor at y=460 exactly as authored) — a 140px rise is safely inside R1's comfortable band (≤150px) and clear of the 151–199px forbidden band an earlier attempt at this fix (160px) fell into. `VaultEast` is still visibly taller than its original ~100px form and reads as a proper wall; it's no longer tall enough to seal the chamber. The Director's position, width and colour for `VaultEast` are all unchanged.

**Verification:** `tools/arena_check.gd` re-run after all three fixes: R1–R12 all pass except the pre-existing, already-recorded `B_Under` finding (see above — not touched, by design). Both vault doors, both gateway entries and exits, both Crown-entrance routes, the skill jump, the launcher, and all six wrap-integrity checks pass. Godot MCP run: no errors.

**Not touched, and not a defect:** `B_Under`'s 184px rise from `C_W` sitting right at the M1 jump ceiling. Recorded earlier as a confirmed "intentionally hard to reach, high pickup value" spot, not re-litigated here.

---

## 2026-09-06 — Milestone 2 (Arena 01 V2) — COMPLETE / ACCEPTED

**Status: ACCEPTED.** Full milestone summary; see `docs/ROADMAP.md` and `docs/plans/M02_ARENA_01_V2.md` for the closed-out scope and brief.

**Major outcomes, for a session that hasn't read the whole log:**

- **V1 ("The Seam Ring") was rejected** by unprompted human playtesting — a route diagram optimized for reaching the Relic, not a place four players wanted to be. Preserved as history in `docs/plans/M02_GREYBOX_ARENA.md`, not deleted.
- **V2 ("The Gallery"), an interconnected arena, is accepted** — built around one asymmetry (cheap to fall, expensive to climb) rather than parallel routes to an objective.
- **A substantial, continuous lower interaction floor is accepted** — the floor plus Band C read and play as one two-storey chase/interference zone.
- **Stronger horizontal connectivity across upper layers is accepted** — the Crown runs 1160px unbroken; Band C and Band B both span most of the arena width.
- **Four starting territories are accepted**: top-left (`B_W`), top-right (`B_E`), bottom-left (Floor west), bottom-right (Floor east) — deliberately not mirrored; fairness comes from measured route cost, not symmetric geometry.
- **Vertical exploration was naturally discovered** — both ladders attracted the Director unprompted in Playtest 1a/1b, without being told they existed.
- **Difficult-to-reach areas are confirmed potential high-value future power-pickup locations** (`B_Under` chief among them) — explicitly not to be simplified; difficulty is the point, not a defect.
- **Horizontal wrapping remains accepted**, unchanged from M1, and used both as connective tissue and (per the Director's own playtest) as an intentional escape/flank/reposition tool.
- **A protected central Relic chamber is accepted**, with **approximately two controlled, chokepoint-style approaches** as the current direction — a genuine physical gateway on the west (a 100px walled fall-shaft beside the Pier) and the pre-existing narrow `VaultEast` step on the east, rather than a colour-only threshold or a maze.
- **A static closed-gate visual over the Relic is accepted** — bars plus a header, no collision, no script, no state — confirmed by human playtest to read immediately as "found, but currently protected/closed." The actual open/close *logic* (timer, state machine, collection) is explicitly M3's job, not M2's.
- **Tempo observation, recorded but not acted on:** 1.25× debug playback felt noticeably more energetic and fun than 1.0×, which felt merely acceptable. No M1 movement/physics values have been changed. Re-evaluate once multiple active players/bots exist — a single-player playback-speed impression isn't sufficient grounds to retune shared movement constants.
- **Freeze's possible dual mode (direct-on-player, and environmental/surface, e.g. an icy floor or ladder) remains an M4 hypothesis** — recorded, not approved, not implemented. No power system exists in the M2 build.
- **Push clarification stands:** no Push mechanic exists anywhere in the codebase (confirmed by full-text search); what read as "Push" during playtesting was ordinary collision physics.

**What M3 inherits:** a fixed, checker-verified arena (`tools/arena_check.gd` is the permanent regression tool — rules and route proofs updated throughout M2, not reset), four working spawn territories, a closed Relic placeholder with no logic behind it yet, and marked-but-unimplemented pickup/hazard candidate positions. M3 adds the Relic's actual open/collect/win logic, the match timer, and bots — not before.

---

## 2026-09-06 — M3 is split into M3-1 and M3-2 with a hard human-playtest approval gate

**Status: APPROVED PLAN. Nothing implemented.** Full brief: `docs/plans/M03_CORE_GAME_LOOP.md`.

**Decision:** Milestone 3 is delivered as two sequential halves:

- **M3-1 — Four-player foundation.** Slot architecture, controller abstraction, colour identity
  with toggleable P1–P4 labels, navigation graph, per-edge movement executors, Dijkstra, roaming
  bots with a small curiosity/encounter bias, deterministic bot variation, recovery, checker
  extensions. **No objective of any kind.**
- **HARD STOP.** Human playtest A1 (1.0×) → labels off → A2 (1.25× via `Engine.time_scale`) →
  A3 (back to 1.0×) → optional collision A/B → Director acceptance → its own commit.
- **M3-2 — Core match loop.** Match FSM, setup timer, UNLOCKING telegraph, vault sealing, gate
  CLOSED→OPEN, Relic collection, winner, results, rematch, bot goal switch.

**Binding on implementation sessions:** a fresh session builds **M3-1 only**. The functional
Relic, gate state machine, setup timer, winner detection, results and rematch must not be built —
not partially, not as disabled stubs — until M3-1 is played and accepted.

**Why split, and why not re-cut M3/M4 instead:** M3 as originally scoped is two milestones of
work, but the match loop must not slide into M4 either — M4 is powers, and powers layered on an
unvalidated loop is strictly worse. The correct cut is inside M3.

**Why navigation is in the first half:** the original session brief proposed "four-player
simulation" *before* "bot navigation". That ordering does not hold — four-player simulation
requires navigation, or it is four rectangles standing still.

---

## 2026-09-06 — A player slot's controller is data: human-local, bot, or (reserved) network

**Status: APPROVED for M3-1.**

**Decision:** `player.gd`'s three intent functions (`_get_horizontal_intent`,
`_get_vertical_intent`, `_get_jump_intent`) delegate to an assigned controller object.
`HumanController` reads input exactly as today but **parameterised by an action-name prefix /
device id rather than hardcoded action strings**. `BotController` produces the same three signals.
`NetworkController` is a reserved name in the enum and is **not written**. Slot→controller mapping
lives in a `MatchConfig` read at match start.

**Why now:** `docs/DECISIONS.md` (2026-09, "Mobile control mapping stays unresolved until M5")
already commits to replacing those three function bodies without touching movement physics — the
seam exists. Formalising it costs ~30 lines; skipping it means rewriting the bot/human coupling
at M5 and again at M9. **Nothing may assume P1 is permanently the only possible human.**

**Explicitly not built:** networking, device assignment, split input maps, a join flow, or a
second local human.

**Hard constraint retained:** zero changes to movement physics or M1 tuning values.

---

## 2026-09-06 — Player↔player physical collision starts OFF, as a development toggle only

**Status: APPROVED for M3-1. Deliberately NOT a permanent product decision.**

**Decision:** M3-1 begins with players on their own collision layer, masking world geometry only.
The toggle stays available for a brief A/B during the human playtest, run **after** the primary
tempo/readability tests so it cannot contaminate them.

**Why off first:** M2 already established that incidental collision physics *read as a Push power*
to the Director (see the Playtest 1a "Push" clarification above), so leaving bodies colliding
would contaminate M4's real Push. Bots wedging on each other is also the likeliest single source
of stuck states. It is one line to flip back.

---

## 2026-09-06 — Bots get one small social behaviour in M3-1: curiosity / encounter bias

**Status: APPROVED for M3-1.**

**Decision:** while roaming, a bot occasionally selects an interest **region currently occupied by
another player** instead of a purely environmental one. Working weighting: **~70–80%
environmental, ~20–30% player-occupied**, exported and configurable. The target is a *region*,
resolved to a nav-graph node once at selection time and **never re-targeted** if that player
moves. On arrival, normal roaming resumes immediately.

**This is explicitly NOT:** chasing · attacking · targeting the human · aggression · pursuit or
prediction · M4 combat AI.

**Why it exists:** without it, four independent roamers in a 1920px wrapping arena can plausibly
never meet, and M3-1's central questions — *do encounters actually happen?* and *does the Director
want to interfere with them?* — go untested. The bias must sample **other bots as well as the
human**; if it only ever selects the human's region it becomes the chasing behaviour this
decision excludes.

---

## 2026-09-06 — Vault camping is prevented by sealing the two approaches during setup, not by barring the Relic

**Status: APPROVED for M3-2.**

**The problem, found by audit:** the accepted `RelicGate` bars are six `ColorRect`s with **zero
collision**. Any player can walk into the alcove at t=0 and stand on the Relic for the whole setup
phase. With no powers in M3 to dislodge them, camping is a guaranteed win — that alone would
invalidate the M3-2 test. The M2 close-out entry above correctly describes the gate as a
readability treatment; it was never a barrier.

**Decision (Option A):** during SETUP and UNLOCKING, physically seal the two approved vault
approaches — a barrier plugging the **west fall shaft** (x 820–922, between the Pier's east face
and `VaultGateW`) and a barrier at the **east threshold** above `VaultEast` (x 1140–1220), tall
enough to be un-jumpable from `A_E` (≥200px rise against a 184.1px max). Both removed at OPEN.
**The accepted decorative bars are preserved unchanged** as the readability signal; they stay
cosmetic and the barriers do the work.

**Rejected, recorded so they are not retried:**
- **Giving the bars collision. This creates a trap.** The west door is one-way-in, so a player
  dropping through lands in the 820–927 pocket, walled by the Pier's un-jumpable 260px east face
  and now by solid bars — stuck until OPEN. That violates "nobody sits watching a match."
- **Doing nothing** (Relic simply uncollectible until OPEN) — degenerate; first to the alcove wins
  at t=open.
- **Repel volumes / soft push-out** — exactly the arbitrary invisible walls ruled out at planning.

**Trap check, required by the approval:** with Option A the camping positions become the **Pier
top** (west) and **`A_E`** (east) — both legitimate, fully visible, contestable, and neither a
trap (Pier top → `A_W_Bridge` → `A_W` → `LadW` down; `A_E` → `LadE` down). **R9 must be re-proved
by simulation in both gate states.**

**Second-order risk, named not solved:** with a sealed vault the rush may be decided in ~1s by who
is standing at a door. The doors are near-equidistant from the Relic (west landing ≈80–140px,
east step-down ≈120px), so the real contest becomes holding a door for 10s. Acceptable for M3; if
it still feels anticlimactic the fix belongs to M4's powers, not to more geometry.

**Arena geometry changes in M3 are limited to these two barriers.** Specifically not `B_Under`,
the Pier top, or the Band C gap under the vault — all confirmed high-value M4 pickup sites.

---

## 2026-09-06 — M3 setup is 10 seconds, and UNLOCKING is its final ~2 seconds

**Status: APPROVED for M3-2. Temporary M3 value.**

**Decision:** `0–8s SETUP/CLOSED · 8–10s UNLOCKING (still physically sealed) · at 10s OPEN.`
Exported and tunable. **UNLOCKING is the tail of the setup timer, not an additional wait.**

**Why 10 and not 25:** the checker times the Crown entrances at 1.97s (east) and 2.48s (west) from
Band C, so roughly 3–4.5s puts any player at a vault door. The ~25s working value exists to give
**power acquisition** room; in M3 there are no powers, so 25s is ~4s of travel followed by ~21s of
standing at a doorway. At 5s the phase has no identity. At 10s there is ~6s of jockeying — one
full cross-arena reposition (~2–3s) plus a counter, which is a real decision. Secondary benefit:
15–20s rounds let a session run many rematches, which is how the "Again." signal gets measured.

**This does not supersede the ~25s working direction for M4**, when powers give the phase content.
**M3-2 must A/B 10s vs 25s** so the number is measured rather than assumed.

**Why the telegraph:** it turns the rush into a race with a starting gun rather than a coin flip on
standing position, and it serves the requirement that the state change be extremely obvious.
Greybox only — a visible countdown plus a clear gate state change. No animation, no VFX.

---

## 2026-09-06 — The tempo A/B uses `Engine.time_scale`, never rescaled movement constants

**Status: APPROVED for the M3-1 playtest.** Resolves the "1.25× felt better" observation recorded
at M2 close-out.

**Decision:** compare 1.0× and 1.25× with `Engine.time_scale`. **No M1 movement constant may be
changed during or because of this test.** Playtest order is A1 (1.0×) → A2 (1.25×) → **A3 (back to
1.0×)**; the return leg is required, because one A/B cannot distinguish a real preference from
novelty and order effects are real.

**Why this specific method matters:** `time_scale` scales time uniformly, so every jump arc, gap
and landing window is **geometrically identical** and the entire M2 checker proof still holds — and
it reproduces exactly the thing the Director already judged at 1.25× debug playback. Rescaling
`max_speed` / `gravity` / `jump_strength` changes **every arc**, and would **invalidate the whole
M2 geometry proof**, requiring full re-verification and possibly re-authored platforms.

**Therefore:** if 1.25× wins, converting it into real constants is a **separate, dedicated tuning
pass with a full checker re-run** — never folded into M3.

**Implementation consequence:** all bot timers must be `delta`-based, never frame counts, so bots
are `time_scale`-safe.

---

## 2026-09-06 — `arena_check.gd` gets an acknowledged-exception list so its exit code means something

**Status: APPROVED. Work item #0 — before any M3 gameplay code.**

**Decision:** the checker gains a small, explicit, commented allowlist of accepted findings
(currently exactly one: the `C_W -> B_Under` R7 landing-width finding). An acknowledged finding is
still printed in full and clearly marked, but does not affect the exit code. Any unlisted failure
still fails. **A clean accepted baseline must return exit code 0.** Also fix `_band_report`'s
Band A member list, which omits `A_W_Bridge` and `A_E_Bridge` and therefore reports 38.8% coverage
instead of the real ~53%.

**Why:** the tool currently exits non-zero on the accepted M2 baseline because of that one
deliberately-unfixed finding, which makes it useless as an M3 regression gate — a new failure is
indistinguishable from the old one. `B_Under` itself is **not** to be fixed; it is a confirmed
"intentionally hard to reach, high pickup value" spot.

---

## 2026-09-06 — The route-cost table's four warnings are a harness gap the bots will close

**Status: RECORDED at M3 planning. Hard M3-1 acceptance criterion.**

**Finding:** at the M2 baseline all four spawns report `NO PROVEN ROUTE` in `arena_check.gd`'s
route-cost table. Per the tool's own comment this is a harness limitation, not an arena defect: it
departs a ledge at full running speed, and because deceleration is floor-only nothing slows the
fall's horizontal drift, so it overshoots narrow targets below.

**Why this matters for M3:** the manoeuvre the harness cannot perform — a controlled low-speed
edge departure, releasing input the instant the body clears the edge — is exactly the manoeuvre a
bot must perform dozens of times per match. The bot's `drop` executor *is* the fix.

**Decision:** once the per-edge executors exist, the checker drives **them** rather than
maintaining its own copies, so the two cannot drift. **Retiring all four warnings is a hard M3-1
acceptance criterion.**

**Related:** the executors' recipes are not invented — they are the checker's already-proven route
primitives (`_run_and_jump_near_edge`, `_drop_to_band_c`, the ladder-climb blocks, and
`_route_launcher`'s 12-tick steering delay), re-shaped from `await` coroutines into per-frame state.

---

## 2026-09-07 — Four players confirmed fun; 1.0× confirmed as the four-player baseline

**Status: RECORDED from human playtest. M3-1 finding.**

**Finding:** four simultaneous bodies in Arena 01 are substantially more alive and engaging than
the M2 single-player exploration sessions suggested — this is the strongest M3-1 signal so far and
validates continuing the milestone.

**Tempo A/B result:** using the approved `Engine.time_scale` method (see the 2026-09-06 tempo A/B
entry above), 1.25× was re-tested with all four players active. Where 1.25× felt exciting in solo
M2-era debug playback, with four active players it instead feels somewhat fast-forwarded rather
than exciting — there is more simultaneous information to read (three other bodies, not one), and
the faster clock compresses the time available to read it. **1.0× is the current preferred
four-player baseline.** This does not overturn the original tempo A/B method or invalidate a future
retest — it is a finding at the current player count and arena, not a permanent verdict on 1.25×.

**Why this matters:** it is a reminder that movement-feel findings from single-player tuning
sessions do not automatically transfer to the multiplayer condition Rushlings is actually built
for. Any future tempo/feel tuning should be (re-)validated at four-player count, not solo.

---

## 2026-09-07 — Player↔player collision OFF confirmed as the M3-1 baseline

**Status: CONFIRMED. M3-1 baseline.**

**Decision:** player↔player physical collision stays **OFF** for M3-1. Players still collide with
world geometry; they do not physically block or separate from each other. A dev toggle to switch
it on for comparison remains available in debug builds.

**Why:** tested directly against the ON state (physical separation on contact) via a dedicated
layer/mask comparison plus playtest. OFF reads as more readable and less frustrating at this stage
— four bodies jostling for the same narrow ladder/vault-approach geometry with collision ON adds
friction that isn't yet earned by a real objective (M3-2). This is the current baseline, not a
final ruling on collision for all future milestones — interference-via-contact may become relevant
again once powers (M4) or ghost mode are explored.

---

## 2026-09-07 — Bot navigation moves to RELIABLE-only routing; SKILL edges are excluded, not penalized

**Status: DECIDED. Supersedes the earlier "heavily-penalized-but-still-usable" fallback model.**

**Decision:** every traversal edge in the nav graph is classified **RELIABLE** or
**SKILL / HUMAN-OPTIONAL** (a third class, **INVALID**, marks edges that don't actually connect
their endpoints and are reported rather than hidden). Ordinary bot pathfinding — both NORMAL ROAM
and NAV STRESS — uses RELIABLE edges only; SKILL edges are excluded from the bot's route-cost graph
entirely (effectively infinite cost), not included at a high-but-finite penalty. A bot that cannot
reach its target using RELIABLE edges alone fails that pathfind and re-paths toward a new target,
rather than repeatedly attempting an edge it cannot reliably complete.

**Why:** an earlier version penalized SKILL edges heavily but still allowed the pathfinder to pick
them when nothing cheaper existed. In practice this meant bots kept selecting exactly the moves
already known to fail inconsistently (e.g. the pre-fix `VaultFloor → VaultEast` jump), producing
the stuck/retry loops seen in human playtest (P3 cycling near the vault, bots repeatedly clipping
`CoverW`). Reliable navigation — a bot that goes where it means to go, using moves it can actually
execute — is more valuable at this stage than theoretical access to every human-legal traversal.
Human players are unaffected: SKILL edges remain real, legal M1 movement for a human player: the
classification only constrains what the **bot AI** is expected to rely on for M3-1.

**Consequence:** if a target region is only reachable via SKILL edges from a bot's current
position, that is now visible in tooling as a real gap (see NAV STRESS below), not silently
papered over by a penalized-but-available fallback.

---

## 2026-09-07 — `CoverW` removed from Arena 01

**Status: DECIDED by the Game Director from human playtest evidence. Level-design change, not a
bug workaround.**

**Decision:** `CoverW` is permanently removed from Arena 01 — not hidden, not kept as a
stale/INVALID nav-graph node. `NavGraph`, `ArenaRegions`, `tools/arena_check.gd`, `tools/m3_check.gd`
and related code no longer reference it. Its counterpart `CoverE` is retained (currently
skill-tagged for bots).

**Why:** human playtest video showed multiple bots repeatedly converging on and visibly failing
around `CoverW`. Investigation (case-study requested by the Director, not a unilateral engineering
call) confirmed it was not required for any macro-region's connectivity and that removing it
disconnects nothing that RELIABLE routing depended on. Rather than keep tuning bot behavior around
a piece of geometry that was reliably confusing bots, the Director chose to remove it from the
arena.

**Not yet decided:** whether `CoverW` (or a different piece of cover geometry) is reintroduced
elsewhere in Arena 01 later. No replacement is planned as part of M3.

---

## 2026-09-07 — NAV STRESS (explicit destinations) is the preferred navigation validation method

**Status: DECIDED. Testing/tooling policy for M3-1 and future navigation work.**

**Decision:** `BotBrain`'s `NAV_STRESS_TEST` mode — an explicit, per-bot sequence of distinct
destinations spanning floor, west, east, upper/Crown, seam/wrap and central/vault-approach regions
— is the preferred way to validate that bot navigation is reliable, over judging `NORMAL_ROAM`
behavior by eye. Toggled in-game via the debug control (key `N`).

**Why:** `NORMAL_ROAM` is not expected to demonstrate final Rushlings bot intelligence, because
bots currently have no real gameplay objective — that arrives with M3-2 (Relic-seeking) and M4
(powers). Judging navigation quality from ROAM means judging "does this look like smart wandering,"
which is a weak, subjective signal. NAV STRESS instead asks a direct, measurable question — given
an explicit destination, does the bot reliably arrive — which is exactly what the RELIABLE-routing
change above needs verified. NAV STRESS results are the harness of record for vault-exit and other
navigation-reliability work going forward.

---

## 2026-09-07 — OPEN: `VaultFloor → VaultEast` exit is not yet reliable (M3-1 blocker)

**Status: OPEN / BLOCKED. Not resolved. No solution chosen. M3-1 cannot be accepted until this is
closed.**

**Background:** the Game Director rejected the original `VaultFloor → VaultEast` exit as too
unreliable for bot use and asked for the smallest local Arena 01 geometry adjustment that makes it
a comfortable, repeatable exit using accepted M1 movement — explicitly without changing M1
movement/tuning, without redesigning the vault, without making entry easier merely to solve exit,
and without adding any teleport-style recovery.

**Fixed so far:** the original failure mode — the jump clipping `VaultGateW` or `VaultEast`'s own
wall mid-ascent, which is what visibly trapped a bot inside the vault during human playtest — is
fixed and confirmed via direct executor testing. There is no more wall/gate collision on this edge.

**What's still broken:** a *different*, previously-masked problem is now the blocker. M1's jump is
a fixed ballistic arc with no in-air deceleration (friction is floor-only in the M1 movement
model). A takeoff speed fast enough to clear the wall in time keeps travelling at that same locked
horizontal speed for the entire flight, and overshoots `VaultEast`'s narrow landing width, landing
on `A_E` instead of `VaultEast`. In short: the timing that solves wall-clearance (an *ascending*
concern) and the timing that solves landing accuracy (a *descending* concern, much later in the
same fixed arc) pull in opposite directions, and M1's ballistic model gives no way to reconcile
them with a single takeoff speed.

**Why widening the platform hasn't worked:** every `VaultEast` widening/repositioning configuration
tried so far conflicts with `tools/arena_check.gd`'s own established static safety rules — notably
its R1 "columns overlap forbidden range" step-up check and R7 "landing platform width" check,
specifically around `VaultEast`'s proximity to `B_E`. The checker is treated as authoritative here:
a geometry change that makes the checker fail is not an acceptable fix, even if it happens to solve
the overshoot in isolated testing.

**Explicitly ruled out:** changing M1 movement/tuning to solve this local geometry problem.

**Not yet decided (for the Game Director next session):** whether to accept a visually larger
`VaultEast`, pursue a different local geometry change elsewhere in the chamber, or invest in a more
capable in-air "aim for landing" executor model (a materially larger change than local geometry
tuning, and out of scope for a quick fix). Until one of these is chosen and verified,
`VaultFloor → VaultEast` remains classified **SKILL**, not RELIABLE, and ordinary bot pathfinding
does not rely on it.

---

## 2026-09-07 — Two-tread vault staircase (VaultStepA/VaultStepB) implemented, tested, and REJECTED

**Status: REVERTED. Superseded by the 2026-09-08 entry below — do not redesign this geometry.**

**What happened:** approved as a Director decision, a two-tread staircase (`VaultStepA` then
`VaultStepB`, replacing the single flush-wall `VaultEast`) was fully implemented — scene geometry,
nav graph, `arena_regions.gd`, `bot_brain.gd` labels, and both checkers. Extensive empirical testing
(real `EdgeExecutor`/`BotController`, multiple starting positions and speeds) found it was **not
reliable**, for three separate, compounding reasons: `VaultGateW`'s ~28px of standing headroom means
any ascent beginning under its x-span (920–1080) head-bonks before clearing it; a tread low enough to
be a "small comfortable rise" also blocks ordinary walking underneath it; and M1's fixed
`jump_strength`/no-air-deceleration model makes a full-speed departure from `VaultFloor`'s necessary
width travel 290–390px+ before the descending height-crossing for any legal "comfortable" (≤150px)
rise — smaller rises travel *further*, not less.

**Why it was reverted:** the Game Director tested the **original** `VaultEast` geometry directly and
repeatedly entered/exited the vault successfully by hand. This proved the geometry itself was never
the defect — `BotController`/`EdgeExecutor` simply could not reproduce a traversal a human performs
easily. The staircase geometry was removed and `VaultEast` restored exactly. **Do not attempt another
geometry redesign of this chamber without new, explicit Director direction** — the fix belongs in bot
execution, not level design.

---

## 2026-09-08 — Vault exit solved via a human-traversal recorder + a local "vertical-clear jump" bot recipe

**Status: DECIDED. `VaultFloor → VaultEast → A_E` is now RELIABLE.**

**Decision:** rather than continue tuning bot jump physics by theory, a small dev-only instrument
(`scripts/traversal_recorder.gd`, toggled with the `debug_record_traversal` key, P1-only, no
persistence) was added to capture the Director's own successful manual traversal — position,
velocity, grounded state, intents, platform, and takeoff/landing events per physics tick.

**Finding:** across three independent full demonstrations, the Director's technique was completely
consistent for both hops (`VaultFloor→VaultEast` and `VaultEast→A_E`): run to the obstacle, **release
horizontal input before jumping**, jump with **zero horizontal hold** (a pure vertical impulse — the
body doesn't try to clear the wall in flight, it goes straight up beside it, sidestepping the
clearance problem instead of timing around it), hold zero horizontal through the whole ascent, and
only steer toward the target once the apex is reached (`vel.y` back near zero). This is the opposite
of `EdgeExecutor`'s existing `_advance_jump` model, which tries to avoid wall contact via an adaptive
speed cap and then preserves a *locked, nonzero* horizontal velocity for the whole flight.

**Implementation:** a new, edge-scoped recipe, `EdgeExecutor._advance_vertical_clear_jump`, gated by
an explicit `{"vertical_clear": true}` edge flag — used only for `VaultFloor→VaultEast` and
`VaultEast→A_E`. It does not touch `_advance_jump` or change behavior for any other edge in the game,
and no M1 movement constant (`max_speed`, `acceleration`, `gravity`, `jump_strength`, etc.) changed.

**Verification:** tested via a real `EdgeExecutor`+`BotController` from four starting positions
spanning `VaultFloor`'s realistic entry range; succeeded cleanly on both hops from every realistic
position (the one failure was an artificial start placed directly inside `VaultEast`'s own collision
volume — not a position the edge's own walk phase would ever produce). `arena_check.gd`'s East
gateway exit test (also updated to use the same recipe, since its previous generic "clear it in
flight" primitive was exactly the technique already known to be unreliable here) now passes.
`tools/arena_check.gd` returns a clean `RESULT: PASS`, zero failures.

**Why this matters beyond the vault:** the human technique — release horizontal, jump vertically,
steer only after the apex — may generalize to other awkward-approach obstacles if similar reliability
gaps surface elsewhere. Not applied speculatively; kept scoped to the two edges it was proven on.

---

## 2026-09-08 — Traversal audit (`Arena01_Traversal_Audit.docx`) diagnosed the real blocker: a topology/state problem, not a physics problem

**Status: ACCEPTED.** Full audit preserved at `docs/plans/Arena01_Traversal_Audit.docx`.

**Finding:** with the vault resolved, `tools/m3_check.gd` still reported bots pooling on Floor,
oscillating near `CoverW`-adjacent geometry, and four spawns with `NO PROVEN ROUTE`. The audit's
diagnosis: **the reliable navigation graph had no working way up from the ground**, and three real
arena transitions (`B_Seam→C_Seam`, `A_W→B_W`, `A_E_Bridge→B_Seam`) were missing entirely from
`nav_graph.gd`. This was a graph/topology and edge-executor defect, not an arena or M1 physics
defect — confirmed by re-simulating the live scene and cross-checking against a real headless run.

**Implemented, smallest-plan order (`docs/plans/M03_CORE_GAME_LOOP.md` §0.5 history; audit steps
01–03):**
- **Step 01 — explicit drop departure side.** `edge_executor.gd`'s `_advance_drop` was inferring
  which edge of the source platform to depart from by comparing the *target's* centre to the
  body's position — wrong whenever the target's centre falls inside the source platform's own
  extent (engine-confirmed: `B_W→C_W` stalled into the Pier's wall for the full timeout, every
  time). Every drop edge in `nav_graph.gd` now authors its own `"side"` ("left"/"right") as data;
  the executor reads it instead of inferring. A second, related bug found during multi-position
  regression (not center-only) testing: the drop "cleared the edge" check compared raw,
  non-wrap-aware coordinates — `B_Seam` is the first drop source whose extent straddles the wrap
  boundary, so a body that had just wrapped read as "already past the edge" on tick one. Fixed via
  `geometry.shortest_diff`, matching every other direction check in the file.
- **Step 02 — three mandatory topology edges.** `B_Seam→C_Seam`, `A_W→B_W` (both ordinary creep
  drops), and `A_E_Bridge→B_Seam` (a new **RUN_DROP** recipe — full-speed departure to clear a
  genuine 130px horizontal gap alongside the 260px fall, gated by an `edge.run_drop` flag, one
  branch in `_advance_drop`, no effect on any other edge). All three verified 5/5 across a spread
  of realistic start positions. With them, the RELIABLE subgraph became strongly connected except
  two audit-predicted, still-standing exceptions: `CoverE` (skill-only by design) and `B_Under`
  (physically 0.09px beyond the jump's rise ceiling, not reclassified this pass).
- **Step 03 — launcher evaluated for Floor→Band C, not promoted.** Multi-position/both-direction
  testing (both an isolated harness and the upgraded official one) showed the launcher only
  clears the bar from the east approach; a west (or wrap-equivalent) approach reliably clips
  `C_Seam`'s western overhang mid-launch (observed: rises ~44px of an intended ~511px). Real
  success rate ~60%, well under the reliability bar. **Launcher stays SKILL for normal bot
  routing**, unchanged — exactly the audit's own predicted risk, confirmed.

**Test suite upgraded to match** (`tools/m3_check.gd`): edge validation now samples ≥5 positions
across each source platform's walkable span and reports PASS only if *every* position succeeds
(a centre-only test is exactly how `Floor→C_W`/`Floor→C_M` previously read PASS while failing
constantly in play); a new node-level strong-connectivity + no-sink assertion (with a narrow named-
exception list) replaced the old region-level check, which only asked "is *some* node in each
region reachable from Floor" — precisely how `B_Seam`'s total orphan status went undetected before.

---

## 2026-09-08 — `Floor→C_M` fixed-trigger jump: the one dependable, central bot road up from the ground

**Status: ACCEPTED.**

**Decision:** with three Floor→Band C jump edges (`C_W`, `C_M`, `C_Seam`) all still failing in
real play (the audit's own diagnosis: the generic `_advance_jump` recipe computes an *adaptive*
safe-speed ceiling that *shrinks* as the body nears the wall — correct for a genuine gap, backwards
for an ascending target, where less distance means less time and therefore needs *more* speed, not
less), the Director directed a narrower fix: make `Floor→C_M` alone genuinely reliable, via a new,
edge-scoped **fixed-trigger** recipe (`_advance_fixed_trigger_jump`, gated by `edge.fixed_trigger`),
rather than touching the shared adaptive recipe every other jump edge still depends on.

**The recipe:** approach at full speed; jump only once the body is inside a *fixed* distance window
before the wall (`trigger_far`/`trigger_near`, edge metadata — 100/60px for this edge, matching the
audit's own modelled range) **and** at the required approach speed. Both the window and the
takeoff point are derived at runtime from the live target AABB, never a hardcoded coordinate — the
same edge tag generalises to any future fixed-trigger edge without a code change. Verified 5/5
across a spread of realistic Floor positions on both sides of `C_M`, then confirmed a second time
inside the official multi-position harness.

**Floor→C_W and Floor→C_Seam were deliberately left untouched and unfixed** in this same pass — see
the navigation-policy correction below for why that changed one week later.

---

## 2026-09-08 — Navigation-policy correction: `Floor→C_W`/`Floor→C_Seam` demoted to SKILL, not merely re-costed

**Status: ACCEPTED.**

**The problem, found by a 5-minute NAV STRESS soak test (the first time navigation health was
measured over minutes rather than seconds):** even with `Floor→C_M` proven reliable, bots kept
selecting the still-broken direct `Floor→C_W`/`Floor→C_Seam` edges far more often than the new
`C_M` gateway (255 attempts vs. 51 over one soak run) — because Dijkstra compares a *target's*
route cost, and the direct edge's flat cost (0.7) undercuts any real `C_M`-detour route (0.6+0.9=
1.5) no matter how `C_M` itself is priced. **Re-costing cannot fix this — only removing the direct
edges from RELIABLE-only routing does.** The same mechanism was also the root cause of a second
reported symptom: bots visibly trapped/bouncing in the Floor pocket between `CoverE` and `C_M`
(`CoverE` sits entirely inside `C_M`'s own footprint) — not because `CoverE` was ever a chosen
target (confirmed: it is correctly unreachable via RELIABLE-only routing), but as an incidental
side effect of repeatedly walking toward the still-selected, still-broken direct edges, which cross
straight through that pocket from most Floor positions. Measured dwell time: 66–72% of an entire
5-minute run, for two of three bots.

**Decision:** `Floor→C_W` and `Floor→C_Seam` are reclassified **SKILL / HUMAN-ONLY** — not merely
re-costed. Ordinary bot pathfinding never selects them; `Floor→C_M` is now the sole RELIABLE Floor→
Band C bot road, with the already-corrected topology carrying bots the rest of the way. Human
players are unaffected — both remain real, legal M1 traversal for a human, exactly as every other
skill-tagged edge in the graph already works.

**Bot navigation principle established by this finding, worth keeping:** **a small reliable bot
road network beats a complete-but-unreliable traversal graph.** Humans may have — and are expected
to have — traversal options bots do not normally rely on; that asymmetry is a feature of the
skill/reliable classification, not a gap to be closed by teaching bots every human move.

---

## 2026-09-08 — `Floor→C_M` reposition/build-runway fix, and the NAV STRESS debug-label cap bug

**Status: ACCEPTED. Both confirmed by a 5-minute soak test before and after.**

**Bug 1 — the debug label lied about "stuck."** `BotBrain.current_stress_destination()` (the label
a human reads during a NAV STRESS playtest) computed `stress_index % sequence.size()` unconditionally,
but the function that actually decides what to pursue, `_pick_stress_target()`, deliberately stops
once a bot's sequence completes 3 full loops ("a run long enough to prove the sequence works doesn't
need to repeat forever") — after which the real logic settles into `AT_REST`/wander, while the label
kept showing a plausible, entirely fictitious destination forever after. This exactly reproduced the
human report ("reached the Vault three times, destination shows Lower Floor, stays in the Vault") —
the bot was not stuck; it was *done*, and the label never said so. **Fixed:** the label now returns
`"(sequence complete)"` once the cap is reached, with a regression test (`m3_check.gd` Test 9)
asserting this at, below, and arbitrarily far past the cap. The underlying 3-loop cap itself is
unchanged — this was a display bug only.

**Development-only affordance added alongside it:** a **`B`** debug key
(`debug_restart_nav_stress`, `arena_01.gd::restart_nav_stress()`) resets all three bots'
`stress_index`/arrivals without restarting the game or touching any other state, so a human can
observe a completed run again rather than having "(sequence complete)" cap a playtest at ~100–120s.

**Bug 2 — the real cause of the remaining Floor trap, once `Floor→C_M` became the sole gateway.**
With no fallback edge left, `Floor→C_M`'s own rare failure mode became fully exposed: a bot that
begins or retries the edge already inside/too close to the 60–100px takeoff window with insufficient
approach speed previously **jumped anyway** ("the unsafe fallback"), clipped `C_M`'s underside
(concretely: walked straight into `CoverE`'s solid face, which sits entirely inside `C_M`'s own
footprint, and stalled there for the whole edge timeout), fell back to ~the same position, and
repeated indefinitely — confirmed live (Slot 4: 0 arrivals, ~83 stall events, permanently parked for
a full 90s run).

**Decision — reposition/build-runway, mirroring the human technique already recorded for this edge
family:** the unsafe fallback is removed. `_advance_fixed_trigger_jump` now enters a bounded
**REPOSITION** phase — walk away from the target until a real runway is re-established, then hand
back to the ordinary approach — whenever any of: (a) too close without approach speed, (b) held
intent producing no real motion for >0.25s (physically blocked, e.g. by `CoverE`), or (c) the body
has already crossed the target's near edge (a state unreachable via this recipe's own walk phase,
but reachable via residual velocity from elsewhere — multi-position testing found jumping from
*past* the edge gives asymmetric, much thinner clearance over `CoverE` than the same distance
measured on the correct side). The runway distance is derived entirely from the edge's own
`trigger_far`/`min_speed_frac` and the body's own `acceleration`/`max_speed`
(`d = v²/(2a)` + a fixed margin) — never a hardcoded coordinate. Bounded: max 2 reposition
attempts per edge execution, 3s max per attempt, a clear `FAILED` if no runway can be established.

**Verified:** the exact live bad-start range (`x≈1344.7–1358.4`, both sides mirrored) now
reliably backs off, rebuilds speed, and lands on `C_M` — no teleporting. Expanded multi-position
test (`m3_check.gd`): 12/12, covering far/medium/ideal-window/inside-window-zero-velocity/inside-
window-wrong-direction-velocity/immediately-adjacent on both approach sides. Post-fix 5-minute
soak: Slot 4 went from 0 arrivals/~83 stalls/never-leaves-Floor to **18/18 arrivals, 0 stalls, all
5 regions, all 4 bands** — and all seven NAV STRESS destination categories (West, East, Lower/Floor,
Upper Left, Upper Right, Seam/Wrap, Central/Vault Approach) passed for every bot. `CoverE` dwell
time is reduced but not eliminated (bots still legitimately transit near it) — no longer a trap,
which was the actual scope of the fix.

**Human traces informed both the vault exit recipe and this one** — recorded here as the second,
independent confirmation of the same pattern: `scripts/traversal_recorder.gd` (dev-only, P1-only,
no persistence) captures a real player's technique, which becomes the model for a bot recipe. This
is an early, small-scale validation of the direction recorded in `docs/GAME_DESIGN.md` §24
("Future Direction — Human-Learned Bot Intelligence") — **M3 remains deterministic, authored
behaviour, not ML or telemetry-trained bots**; what transferred here was a human *demonstrating a
technique to a developer*, who then hand-authored it as a recipe, not a system learning from
gameplay data.

---

## 2026-09-09 — Milestone 3-1 (Four-Player Foundation): COMPLETE / ACCEPTED

**Status: ACCEPTED.** Final human playtest, 1.0×, collision OFF, NAV STRESS enabled: P2/P3/P4 all
navigated successfully and completed their full navigation sequences, bots moved across different
arena regions, vertical traversal worked, Floor was no longer a practical trap, the `CoverE`/`C_M`
pocket no longer produced a blocking trap, Vault traversal remained functional, and no persistent
stuck/jump-spam behaviour was observed. **M3-2 has explicitly not been started.**

**Major outcomes, for a session that hasn't read the whole log:**

- **Four simultaneous players are substantially more alive and fun** than the M2 one-player
  exploration sessions suggested — the single most important M3-1 signal, confirmed and unchanged
  since it was first observed.
- **1.0× is the accepted current multiplayer tempo baseline.** 1.25× remains recorded as a
  development experiment only — it felt exciting in solo M2-era debug playback but "somewhat
  fast-forwarded" with four bodies simultaneously active. `Engine.time_scale` stays the only
  approved mechanism for any future retest; no M1 movement constant was ever touched.
- **Bot navigation principle:** a small reliable bot road network beats a complete-but-unreliable
  traversal graph. Humans may use traversal options bots do not; that's a feature of the
  RELIABLE/SKILL split, not a gap.
- **Human demonstrations informed two bot recipes** (the vault exit's vertical-clear technique, and
  `Floor→C_M`'s reposition/build-runway technique) — a small, real, deterministic-only precursor to
  the human-learned-bot-intelligence hypothesis in `docs/GAME_DESIGN.md` §24, not an instance of it.
- **The Floor "one-way drain" is fully diagnosed and resolved:** the original `Floor→C_W`/
  `Floor→C_M`/`Floor→C_Seam` jump edges were falsely classified reliable (passing a centre-only
  test while failing constantly in dynamic play); bots accumulated on Floor with no dependable way
  up. Fixed in two layers — corrected topology (the three missing mandatory edges) plus a genuinely
  reliable `Floor→C_M` fixed-trigger route with its own reposition/build-runway safety behaviour —
  and `Floor→C_W`/`Floor→C_Seam` demoted to SKILL so bots never fall back onto the broken direct
  routes. Confirmed resolved by a 5-minute NAV STRESS soak test, not merely a single playtest
  session.
- **`tools/m3_check.gd`'s NAV STRESS mode (and the ad hoc 5-minute soak variant) are permanent
  development/regression tooling, not gameplay** — the preferred way to validate navigation health
  going forward, over judging ROAM behaviour "by eye" or trusting a short playtest window alone.
- **Arena topology principle, worth keeping for any future arena or navigation work:** the nav
  graph must explicitly represent every legal transition type (walk, jump, drop, ladder, wrap,
  launcher/skill traversal where appropriate) as authored data. Bots should route through legal,
  authored transitions; local collision/retry behaviour (unstick jumps, stall recovery) exists to
  handle genuine physics uncertainty within a transition, not to compensate for a transition the
  graph never described in the first place.

**Explicitly deferred, not reopened at this closeout:** `B_Under`'s human-reachability/design
question (0.09px beyond the jump ceiling — a Director-reserved M4 pickup site, not reclassified);
the launcher remaining SKILL for normal bots; the other known human/skill-only traversal edges
(`A_W_Bridge→Pier`, the two Vault far-edge jumps, `C_Seam→A_E_Bridge`, `C_W→B_Under`,
`B_Seam↔B_W`); pre-existing non-load-bearing checker warnings (the cross-run determinism hash
divergence; the launcher's 0-completions-in-360s note, which reflects its SKILL status working as
designed, not a defect). None of these are arena, physics, or M3-1-scope problems — bot strategic
intelligence, powers, combat, Relic seeking, learned/human-imitation bot intelligence, networking,
and couch/controller multiplayer remain M3-2/M4/M9+ scope, untouched.
