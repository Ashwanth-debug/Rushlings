# M3-2 — Core Match Loop

**Status: COMPLETE / ACCEPTED (2026-09-12) by the Game Director.** Final human playtest passed —
see §21 for the full close-out. Kept below exactly as approved and implemented, as the historical
planning record.

Approved as the implementation direction, with **one revision** to the CLOSED / UNLOCKING / OPEN
gate treatment (§05). This document is the authority for M3-2 and **supersedes Part Two (§11) of
`docs/plans/M03_CORE_GAME_LOOP.md` wherever the two differ** — see §00 for exactly where and why.
The original Part Two text is deliberately preserved there as history.

**Companion file:** `docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.docx` — the same content as a Word
document for review. If the two ever disagree, **this markdown file wins**; it is the one a fresh
Claude session reads.

> ### ✅ Implemented and accepted — see §21.
> All five STOP points were reached and approved. The accepted loop is
> `SETUP → UNLOCKING → OPEN → SEEK_RELIC → COLLECTION → RESULTS → REMATCH`.

---

## 00. What changed since the M3-2 section was approved, and why

The M3-2 section of `M03_CORE_GAME_LOOP.md` was written on 2026-09-06 — before the traversal
audit, before the vault-exit work, before `Floor→C_M`, and before the Director's later hand-edits
to the chamber. Five of its statements are now wrong or incomplete. **Recorded rather than
silently corrected**, so a future session understands why the plan moved.

### A1 — The vault door coordinates in §11.4 are stale

§11.4 specifies an east barrier at `x 1140–1220`, above a `VaultEast` whose top sits at `y 320`.
Live scene: `VaultEast` is **x 1160–1240, y 360–460** — moved 20px east and trimmed to 100px tall,
not the 140px the M2 close-out entry records. The rise `VaultFloor→VaultEast` is now **100px**, not
140; `VaultEast→A_E` is **60px**. A barrier authored from the approved numbers would land in the
wrong place.

### A2 — The vault is a load-bearing bot shortcut, so sealing it re-routes the whole arena

The reliable path `Pier → VaultFloor → VaultEast → A_E` costs **1.5**. The next-cheapest
west-Crown-to-east-Crown route is **6.8** — down a ladder, across three Band C platforms, up the
other ladder. The vault is a **4.5× shortcut** and Dijkstra takes it constantly.

§11.4 treats sealing as a local change at the chamber. It is not: during SETUP the arena loses its
only Crown-level east–west crossing, and every bot route through the middle of the map changes.
**The RELIABLE subgraph's strong-connectivity and no-sink test must be re-run in the sealed
state**, with `VaultFloor` and `VaultEast` as named, expected exceptions.

### A3 — Sealing the two approaches is not enough; the chamber has an open ceiling

Between `VaultGateW`'s east edge (x 1080) and `VaultEast`'s west face (x 1160) there is an **80px
hole in the vault's roof**. Two free-standing barriers "across the approaches" leave it open, and a
body that reaches the roof of the header — a legal jump west from `VaultEast`, a 24px rise over an
80px gap — drops straight through it onto the Relic. **The seal must close the volume, not the
walking routes.**

### A4 — There is no re-path mechanism at all

`BotBrain._tick_roam` only reaches `_decide_next()` when `executor == null` **and**
`path.is_empty()`. Once a path is committed the bot runs it to completion or to failure; nothing
can interrupt it. Invisible in M3-1, because ROAM never changes its mind. In M3-2 the OPEN event
changes every bot's destination mid-route. The traversal audit
(`docs/plans/Arena01_Traversal_Audit.docx`) names this directly: *"worth fixing now, cheaply."*
See §08 — including a mid-air hazard the audit does not mention.

### A5 — The 10-second reasoning measured the wrong leg of the journey

The approved reasoning — *"roughly 3–4.5s puts any player at a vault door"* — comes from the
checker's Crown-entrance timings, which start **at Band C**. Both floor spawns start 140px below
Band C, and since the navigation-policy correction there is exactly one reliable bot road up from
the ground (`Floor→C_M`), reached by walking to a fixed 60–100px takeoff window. Adding that leg
back puts a floor spawn at a vault door at roughly **8–9.5s**, not 3–4.5s. See §04.

### A6 — Gate visual language (Director revision, 2026-09-09)

The Director inspected the live gate in Godot and **rejected the plan's proposed solid-roof visual
treatment as the dominant reading of CLOSED.** The existing six vertical bars already communicate
"Relic behind bars / locked" and stay the primary player-facing gate; they now **mechanically lift**
during UNLOCKING. Physical anti-bypass collision is still required (A3 is unchanged) but is
subordinated visually to the existing header architecture. Full treatment: §05.

---

## 01. The exact questions M3-2 must answer

Q8–Q11 are from the approved plan (`M03_CORE_GAME_LOOP.md` §4). Q12–Q15 are added because the
audit and the M3-1 implementation raise them and nothing else will.

| # | Question | Answered by |
|---|---|---|
| **Q8** | Is `CLOSED → UNLOCKING → OPEN` unmistakable without explanation? | STOP 1 inspection, then playtest B0 |
| **Q9** | Is the rush a contest, or decided by who happened to be standing nearest? | Telemetry "nearest-at-OPEN wins" rate + B1b |
| **Q10** | Is 10s the right setup length with no powers? Is 25s? | Headless door-arrival measurement, then B2 A/B |
| **Q11** | Does the Game Director press rematch voluntarily? | Playtest B3, unprompted |
| **Q12** | Do bots *visibly* change behaviour at OPEN — is the goal switch legible to a spectator? | Playtest B1a (stand still and watch) |
| **Q13** | Does any spawn or either door dominate outcomes? | 20+ headless bot-only rounds |
| **Q14** | Does the setup phase earn its existence at all, with no powers in the game? | Control round: Relic OPEN from t=0 |
| **Q15** | Does the sealed vault stay a place, or become two doorways people queue at? | B1 observation + door-dwell telemetry |

Q14 is the uncomfortable one and it is cheap to run: one round where the Relic is collectible
immediately. If that round is *more* fun than the 10s round, the setup phase is currently carrying
nothing and its real justification is M4's powers — a finding worth having before tuning a number
that may not matter yet.

---

## 02. The five challenges, and the approved answers

| Challenge | Answer |
|---|---|
| **Is 10 seconds appropriate?** | Unresolved on purpose. **Do not change it on an estimate.** Ship 10s configurable, provide 10/15/25 debug options, and measure real door-arrival times in-engine before selecting the human-playtest default. |
| **ROAM or light positioning during SETUP?** | **Option A — plain M3-1 ROAM.** Approved. Option B is premature and would contaminate the milestone's own experiment (§09). |
| **Seal both approaches?** | **Yes — and the ceiling**, which the approved plan missed (A3). But the seal is physical anti-bypass support only; the *visual* gate is the existing bars (§05). |
| **Is a single Relic graph target sufficient?** | **Yes — `VaultFloor`**, plus a final walk to the Relic's x. Nothing new in the graph (§10). |
| **Smallest robust rematch?** | **Rebuild the `BotBrain` instances, reset the existing bodies, do not reload the scene** (§13). |

---

## 03. Match state architecture

```
   SETUP  ──timer──▶  UNLOCKING  ──timer──▶  OPEN  ──collected──▶  RESULTS
  (sealed)             (sealed)            (unsealed)             (frozen)
      ▲                                                               │
      └───────────────────── reset_round() ───────────────────────────┘
                          a function, not a state
```

Four states on a single `MatchDirector` node:

```gdscript
enum State { SETUP, UNLOCKING, OPEN, RESULTS }
```

- One `float` clock accumulated in `_physics_process(delta)` — **never `_process`, never frame
  counts**, so the whole loop survives `Engine.time_scale` exactly as the bots already do.
- One signal, `state_changed(new_state)`. The gate, the HUD, the Relic and every bot brain
  subscribe. Nothing polls `director.state` from elsewhere.
- UNLOCKING is the **tail of the setup timer**, never an additional wait (M3-A10, unchanged).
- The only non-timer transition in the machine is the Relic collection event.

### Does SPAWN / RESET need to be a state?

**No.** A state earns its place when something observes it for longer than a frame and it needs its
own exit condition. Reset does neither: it is a single synchronous function that runs and hands
straight back to SETUP. Making it a state adds a transition, a guard, and a place for the FSM to
get stuck — for zero observable behaviour.

One qualification: **RESULTS holds for a short minimum dwell (~1.2s)** before it accepts the
rematch input, so a key held at the moment of victory cannot skip the result just earned. That is a
timer inside RESULTS, not a fifth state.

### Note for the tester, so it does not read as a bug

Because the timer is `delta`-driven, a 10s setup elapses in **8 wall-clock seconds at
`time_scale` 1.25**. That is correct — time is scaled uniformly, which is the entire reason the
tempo A/B uses `time_scale`.

---

## 04. Timing — unresolved by decision, resolved by measurement

**Approved: do not change the setup duration based on the estimates below.** Ship the initial
configurable **10s**, provide debug options **10 / 15 / 25**, and take a real engine door-arrival
measurement before selecting the default for human playtesting.

### Why the approved 10s reasoning needs re-measuring (A5)

The reasoning on record is: *"the checker times the Crown entrances at 1.97s (east) and 2.48s
(west) **from Band C**, so roughly 3–4.5s puts any player at a vault door."* Two things have
changed since:

- **Nobody starts on Band C.** Two of the four spawns are on the Floor, 140px below it.
- **There is now exactly one reliable bot road up from the ground** — `Floor→C_M`, entered through
  a fixed 60–100px takeoff window that a bot must walk to and, on a bad approach, back away from
  and re-approach.

### Reconstructed spawn → door times

Derived from live geometry and the M1 constants (`max_speed 500 · acceleration 3000 ·
climb_speed 400`). **Not measured in-engine.** To be replaced by the Step 3 measurement.

| Slot | Spawn | Route cost to Relic | Shortest door | Est. time to door |
|---|---|---|---|---|
| **P2** bot | `B_E` — top right | 2.2 | East | ~3.0s |
| **P1** human | `B_W` — top left | 4.5 | West | ~6.5s |
| **P4** bot | `Floor` east | 4.7 | East | ~8.0s |
| **P3** bot | `Floor` west | 4.7 | East | ~9.5s |

Dijkstra over RELIABLE edges only, neutral per-bot weights, target `VaultFloor`, OPEN state. Units
are the graph's own cost seconds.

### Two findings, not one

**The spread is 2×.** P2's spawn is roughly twice as close to the Relic as anyone else's on the bot
road network.

> **Approved: this is a measurement finding only.** Do not move spawns, alter geometry, change
> route costs, or introduce slot-specific balancing. It is reported, per the standing decision that
> route-cost measurement is diagnostic and never normative.

**The cost model cannot see it all.** Edge costs are per-edge constants; walking 580px along the
Floor to reach the `Floor→C_M` takeoff window costs the pathfinder nothing. P3 and P4 tie on graph
cost and differ by roughly 1.2s of real walking. Any fairness instrumentation built on graph cost
alone will under-report the real imbalance, so it must record **wall-clock arrival time as the
primary number**, with graph cost as the secondary.

### The rule to validate

**Hypothesis, to be confirmed against measured data:** OPEN should occur roughly **2–3 seconds
after the slowest spawn can plausibly reach a door**. On the estimates above that is 12–13s, which
is why 15 is in the debug set. The measurement decides; the Director selects the number.

**Unchanged:** ~25s remains the M4 working direction once powers give the setup phase content.

---

## 05. The gate — CLOSED / UNLOCKING / OPEN

> **REVISED 2026-09-09 by Director decision.** The earlier proposal made a continuous solid roof
> the dominant visual reading of CLOSED. That is rejected. **The existing six vertical bars remain
> the primary player-facing gate**, and they now mechanically lift. The physical seal still exists
> — A3's bypass problem is real and unchanged — but it is minimised and visually subordinated to
> the existing header architecture.

### The player's mental model

> ✅ *"The barred Relic gate is locked."*
> ❌ *"A giant roof block is preventing me from entering."*

### The chamber as it actually is (live geometry)

| Element | x span | y span | Role |
|---|---|---|---|
| `Pier` | 740 – 820 | 200 – 620 | West wall of the chamber, solid past the floor |
| `VaultFloor_Bridge` | 820 – 922 | 460 – 500 | West landing, canonicalises to `VaultFloor` |
| `VaultFloor` | 922 – 1220 | 460 – 500 | Chamber floor — the Relic sits on it |
| `VaultGateW` | 920 – 1080 | 336 – 376 | **Permanent** rotated header — half a roof |
| `VaultEast` | 1160 – 1240 | 360 – 460 | East wall and east step |
| `RelicPlaceholder` | 980 – 1020 | 400 – 460 | Objective, 84px of headroom under the header |
| `RelicGate` Bar1–6 | 927 – 1073 | 376 – 460 | **The visual gate.** Six 6px bars, 22px gaps |
| `VaultSealW` | 820 – 922 | 336 – 376 | **NEW** — anti-bypass roof strip, removed at OPEN |
| `VaultSealE` | 1080 – 1160 | 336 – 376 | **NEW** — anti-bypass roof strip, removed at OPEN |

### Why the bars read as a cage

The six bars sit at x 927, 955, 983, 1011, 1039, 1067 (6px wide each), leaving **22px gaps**
against a **36px-wide** player body. Even read purely visually, nothing player-shaped fits between
them — which is exactly why the treatment already communicates "locked" and why the Director's
instinct to preserve it is right. Bars 3 and 4 stand directly in front of the Relic (980–1020).

### CLOSED

- The six bars remain **down**, spanning y 376–460, framing the Relic. Unchanged from the accepted
  M2 treatment.
- The Relic is dimmed (`modulate ≈ 0.45`).
- **Physical access is genuinely impossible** — enforced by the two seal strips below, not by the
  bars.

### The physical seal — minimal, and smaller than first proposed

The Director's revision made the seal **54% smaller** than the plan's original version. Both pieces
now sit at **exactly the header's own y-range (336–376)** and at its thickness, so they read as the
existing lintel completing itself rather than as new architecture:

```
  ROOF LINE AT y336-376, WEST TO EAST

    x820 ─────────── x922 ─────────── x1080 ─────────── x1160
      │  VaultSealW    │  VaultGateW    │  VaultSealE    │
      │  [NEW 102x40]  │  (permanent)   │  [NEW 80x40]   │
      └── closes the ──┴── already ─────┴── closes the ──┘
          west shaft       there            80px hole  (A3)

  west wall  :  Pier east face          x820,  y200-620    (existing)
  east wall  :  VaultEast west face     x1160, y360-460    (existing)
  floor      :  VaultFloor(_Bridge)     x820-1220, y460    (existing)

  => while sealed, the chamber interior x820-1160 / y376-460 is a closed box.
```

**Why a thin strip is sufficient**, where the earlier version used a 124px-tall plug: the space
below the west strip (x 820–922, y 376–460) is reachable *only* from inside the chamber — the Pier's
solid face walls it to the west, `VaultFloor_Bridge` floors it, and the strip caps it. There is no
outside route into it, so it does not need filling. Total new visible area: **7,280 px²**, versus
15,848 px² for the rejected version.

**Nobody can be sealed in:** the seal is applied during `reset_round()` with all four bodies at
spawns, and is never applied mid-round.

### UNLOCKING — the bars lift

- The six existing bars **retract upward into the header**, the classic portcullis motion: their
  top edge stays fixed at y376 while their bottom edge travels **y460 → y376** (84px of travel).
  Implemented by animating each bar `ColorRect`'s `offset_bottom`; the bars appear to withdraw into
  the lintel above them, which is exactly where a portcullis goes. No new geometry, no bar moving
  through solid architecture, no clipping.
- **The lift happens in the final portion of UNLOCKING**, not slowly across the whole setup phase.
  Working values against a 10s setup: UNLOCKING spans t=8.0–10.0; bars hold for ~0.8s while the
  colour cue runs, then lift over **t ≈ 8.8 → 10.0**. All `delta`-driven and therefore
  `time_scale`-safe; both numbers exported.
- **The physical seal stays fully active for the entire lift.** A player must not be able to enter
  because the animation has started. This is automatic — the bars have no collision and the seal
  strips are untouched until OPEN — but it is stated explicitly because it is a hard requirement,
  and test 12 must probe the chamber *while the bars are mid-lift*, not only while they are down.
- Supporting cue: bars and seal strips share one `modulate`, slate → amber during UNLOCKING.
- No production animation, VFX, particles, audio or polish.

### OPEN — one authoritative transition

At the single `state_changed(OPEN)` emission, in one frame:

```
1  bars     → fully retracted, entrance visually clear
2  seals    → VaultSealW / VaultSealE collision disabled, visibility off
3  relic    → Area2D monitoring on, modulate to full brightness
4  navgraph → the five gate-conditional edges become usable
5  vault    → one instant floor colour change
6  bots     → each brain notified; each acts after its own reaction delay
7  hud      → "OPEN"
```

**An honest note for the implementer:** the bars never gate anything physically — they are the
*visual* language, and the seal strips are the *physical* gate. Step 1's job is to make those two
agree so precisely that a player never perceives the difference.

### One thing to judge at STOP 1

The seal strips must be hidden at OPEN, not merely made non-solid — leaving a visible strip that is
no longer collidable would be a lie the player can walk through. The consequence is that the header
appears to shorten at OPEN. Colour-matching the strips to the header makes CLOSED read as one clean
lintel; it also makes that shortening the subtlest possible change. **Whether that reads as
intentional or as a glitch is a judgement call for the Director's inspection**, and it is on the
STOP 1 list. If it reads badly, the fallback is to give the strips their own subordinate shade so
their removal is legible as a gate opening rather than as architecture changing size.

---

## 06. Roof camping — approved for M3-2 testing

If a player can legally stand on the seal or header area during SETUP, and the OPEN transition
drops that player toward or into the chamber, **that is allowed for the M3-2 prototype**.

- **Do not pre-emptively prevent it.**
- **Instrument it:** whether each player was standing on a seal piece at OPEN, and whether that
  player subsequently won.
- Treat roof-camping dominance as **evidence to review later**, not as an automatic geometry
  correction.

**Trap check (M3-A9 requires it):** the roof is not a trap. A body standing on it (x 820–1160,
y336) exits east — a 24px step down onto `VaultEast`, then a 60px step up onto `A_E` — or jumps
136px west back onto the Pier top. Both are inside the comfortable band and clear of R1's forbidden
155–184px range. **R9 must be re-proved by simulation in both gate states**, with the roof added as
a probe origin.

---

## 07. Gate-conditional nav-graph edges

Five edges pass through the sealed volume and must be unusable while it is sealed, or bots will
walk into a wall and burn the full edge timeout before blacklisting it:

| Edge | Type | Reason |
|---|---|---|
| `Pier → VaultFloor` | drop | Blocked by `VaultSealW` |
| `A_E → VaultEast` | drop | Destination is inside the sealed volume's east wall |
| `VaultEast → VaultFloor` | drop | Inside the sealed volume |
| `VaultFloor → VaultEast` | jump | Inside the sealed volume |
| `VaultEast → A_E` | jump | Exit from inside the sealed volume |

Smallest implementation: an `edge.gated = true` flag authored in `nav_graph.gd`, plus one condition
in `BotBrain._weighted_cost` — the same place `route_class != RELIABLE` already returns `INF`. No
new pathfinding code, no second graph.

**Consequence, from A2:** while sealed, the arena has no Crown-level east–west crossing, so bot
routing across the middle changes completely between SETUP and OPEN. This is a bonus for legibility
— the goal switch will look like a real change of mind — and a hazard for connectivity, which is
why the sealed state gets its own strong-connectivity test (test 13).

---

## 08. Bot goal switch and re-path

The single most important piece of engineering in M3-2, and the one the traversal audit already
flagged (A4).

### The cancellation pattern already exists

`BotBrain.set_mode()` is exactly this operation, written and proven for the
NORMAL_ROAM ↔ NAV_STRESS toggle:

```gdscript
target_node = ""
path = []
path_index = 0
executor = null
decision_clock = min(decision_clock, 0.1)
```

`set_goal(Goal.SEEK_RELIC)` is the same five lines plus a state assignment. That is the whole
cancellation mechanism — no new machinery.

### The hazard the audit does not mention: cancelling in mid-air

`_update_localization()` returns immediately unless `body.is_on_floor()`. Cancel a path while a bot
is airborne and `current_node` is **stale** — the platform it left, not where it is. Dijkstra then
plans from a node the bot is not on, the first executor starts from wrong assumptions, and the bot
spends its whole rush recovering. With four bodies and a 2-second window, this would look exactly
like *"the bots are broken at OPEN."*

### Approved: cancel on ground, not on event

OPEN sets a `goal_dirty` flag. The brain performs the cancellation on the first tick where **both**
hold:

1. its own per-bot reaction delay (0.15 / 0.30 / 0.45s) has elapsed, **and**
2. `body.is_on_floor()` with a valid graph node underneath it.

Cap the wait at ~1.2s; if the bot is still not grounded by then, cancel anyway and let the existing
RECOVER path do its job — that is precisely what it is for.

This buys three properties at once: the pivot is **staggered** rather than synchronised (as §11.5
requires), the bot always re-localises **from real physical footing**, and mid-air states are never
a special case anywhere in the code.

### Full sequence, per bot

1. OPEN fires → `goal = SEEK_RELIC`, `goal_dirty = true`. Nothing else happens yet.
2. Reaction delay elapses and the bot is grounded on a graph node → active executor dropped, path
   cleared, target cleared.
3. `_update_localization()` sets `current_node` from the platform actually underfoot.
4. `_decide_next()` — under SEEK_RELIC, target selection is not the roaming picker; it is the
   constant `"VaultFloor"`.
5. Dijkstra over RELIABLE, now-ungated edges. If it returns empty — which should be impossible, but
   the code must not assume so — fall back to a route toward the nearest of `Pier` / `A_E` and
   retry next tick.
6. Executors run as normal. On arrival at `VaultFloor`, the final approach (§10) takes over.
7. **Edge blacklists persist through the switch.** An edge that failed during SETUP is still on its
   8s cooldown at OPEN. Leave it — clearing it would re-offer a route the bot has just proven it
   cannot take, at the worst possible moment.

**No teleporting, no position writes, no physics exemptions.** The cancellation only clears brain
state. A bot mid-jump keeps its velocity and lands where physics puts it.

---

## 09. Bot behaviour during SETUP — Option A, approved

**Plain M3-1 ROAM. No pre-positioning.** `ArenaRegions.NO_ROAM_TARGETS` already excludes
`VaultFloor` and `VaultEast` from roaming targets — written for M3-1, correct for M3-2 for the same
reason. Zero new code.

Option B (lightweight positioning) is rejected for M3-2 because it costs the milestone its own
experiment:

1. **It destroys what M3-2 exists to observe.** The headline is four scattered players suddenly
   converging on one objective. If they have already converged during SETUP, there is no
   convergence to watch and Q9 becomes unanswerable.
2. **It makes the goal switch invisible.** Q12 asks whether a spectator can see the bots change
   behaviour at OPEN. If SETUP behaviour already points at the vault, before and after look the
   same.
3. **It collapses the fairness data.** Every round would start from roughly the same configuration,
   so the spawn-advantage measurement loses its variance.

There is also a design argument: "useful positioning" presupposes something to position *for*. With
no powers, no pickups and no interference, the only useful position is "near a door" — and three
bots standing at two doors for eight seconds is worse to watch, and worse to play against, than
three bots exploring an arena already accepted as fun to move around in.

**Recorded as an M4 question**, where it has real content: a bot that fetches a power during setup
and positions with it is a bot doing something, and `_pick_interest_target` is the seam it belongs
in. If B1 shows the bots looking aimless *because* they have no objective, that is a finding about
setup length (Q10/Q14), not a request for positioning AI.

---

## 10. Relic targeting, approach and collection

### The graph target

**One node: `VaultFloor`.** The Relic rests on that surface (x 980–1020 on a platform spanning
922–1220, top y460), and `ArenaGeometry.canonical_platform` already folds the western
`VaultFloor_Bridge` patch into the same name — so both doors deliver a bot onto the same node.
No new nodes, no new edges, no "relic node."

### The two legal approaches, unchanged

| Door | Bot route in | Lands at | Walk to Relic |
|---|---|---|---|
| **West** | `A_W_Bridge → Pier → VaultFloor` | x ≈ 820–922 | ~140px |
| **East** | `A_E → VaultEast → VaultFloor` | x ≈ 1160–1200 | ~180px |

Both are proven RELIABLE edges from M3-1. **The bot uses precisely the routes a human uses**;
nothing about SEEK_RELIC gives it a move a human does not have.

### Final approach — the one new behaviour

On arriving at `VaultFloor` the bot must not fall into `_intra_node_wander()`, which picks a random
x on the platform. It needs a small arrival mode: walk toward the Relic's centre x using
`geometry.shortest_diff` (wrap-aware, like everything else), hold until overlap. The Relic's 84px
alcove is too low to jump inside, so this is a pure walk — no jump, no special case.

### Watch for — door monoculture

Dijkstra picks a door on cost alone, and the per-bot cost weights are small. All three bots may take
the same door most rounds, making convergence read as a queue rather than a pincer. **Do not
pre-emptively fix this.** Measure door usage (§14) first; if one door carries >90% of arrivals, the
cheapest fix is a per-bot additive preference on the two door edges, using the deterministic
per-slot weighting that already exists.

### Collection mechanism

- An `Area2D` matching the Relic rect (x 980–1020, y 400–460), added as a sibling of
  `RelicPlaceholder` — **not** under `Geometry`, so `ArenaGeometry` never sees it as a platform.
- **Its collision mask must include layer 2.** Players live on layer 2 *only* since the M3-1
  collision fix; an `Area2D` left on the default layer-1 mask will silently never detect anybody.
  `traversal_zone.gd` and `launch_pad.gd` both carry this exact workaround and comment.
- `monitoring = false` until OPEN, so an overlap during CLOSED cannot be latched by any means.

---

## 11. Deterministic winner resolution

First valid body to touch the OPEN Relic wins. The engineering question is what happens when two
bodies satisfy that in the same physics frame — which, with player↔player collision OFF, is not a
rare edge case: two bodies can occupy the same space.

**Approved: poll, do not listen.** Do **not** resolve the winner from `body_entered` — signal
emission order across multiple simultaneous overlaps is an engine detail, not a rule you can state.
Instead, once per physics frame while state is OPEN, call `get_overlapping_bodies()`, collect every
player body, and resolve:

1. **One candidate** → that player wins.
2. **Several** → the one whose `global_position.x` is closest to the Relic's centre (x=1000).
   Physically meaningful: whoever is furthest into the alcove.
3. **Exact tie on distance** → lowest `slot_id`.

Then set a `_collected` guard, latch the FSM into RESULTS, and stop polling. **Collection fires
exactly once, by construction.**

**This supersedes §11.5's "lowest slot index wins on a same-frame tie."** With four players and
collision OFF, a same-frame tie is a real possibility rather than a formality, and a pure slot rule
makes **P1 — the human — win every tie** in a milestone whose central question is whether racing the
bots is fair. Distance-first keeps determinism, removes the systematic bias, and degrades to the
slot rule when it genuinely cannot decide.

All three branches are testable in one frame by placing two bodies inside the Relic volume and
stepping the physics once.

---

## 12. RESULTS

`P2 WINS` in the HUD, in that slot's colour, plus one line: `[R] rematch`. Nothing else. **No XP,
no progression, no profile, no leaderboard, no stats panel.**

### How gameplay freezes

| Approach | Verdict | Why |
|---|---|---|
| Freeze **input** — controllers return zero, brains stop ticking | **Approved** | Deterministic, headless-friendly, does not fight `time_scale`; bodies settle under gravity and the winner is visibly standing on the Relic |
| `get_tree().paused = true` | No | Requires `process_mode` surgery on the director and HUD to keep them alive; more moving parts than the problem needs |
| `Engine.time_scale = 0` | **Never** | `time_scale` is the approved tempo A/B mechanism. Overloading it as a pause makes the two impossible to reason about together |

Practically: a `frozen` flag on `MatchDirector` that `BotController.update()` and `HumanController`
both consult. One condition in two files.

---

## 13. Rematch — rebuild the brains, reset the bodies

| Approach | Cost | Risk |
|---|---|---|
| Scene reload — `reload_current_scene()` | Two lines | Deferred and asynchronous, so headless tests cannot step it deterministically; discards every dev toggle (labels, collision, nav mode, `time_scale`) mid-session; rebuilds `ArenaGeometry` and `NavGraph` for no reason |
| In-place reset with a `BotBrain.reset()` | ~40 lines | Must enumerate 20+ mutable fields. The first field added after it is written will be forgotten, and the symptom — a bot behaving oddly only in round 3 — is expensive to find |
| **Rebuild the brains, reset the bodies** | **~15 lines** | **Approved.** Nothing to enumerate: a fresh `BotBrain` is by construction fully reset |

```
reset_round():
  round_index += 1
  for each slot:
      body.reset_to(spawn)      # clears velocity, is_climbing, climb_suppressed
      body.controller = BotController(BotBrain(..., seed_for(round_index, slot)))
  gate.seal()                   # seal strips back on, bars back DOWN (offset_bottom = 460)
  relic.monitoring = false ; relic.modulate = dim
  director.state = SETUP ; director.clock = 0.0
  hud.clear_result()
  frozen = false
```

Preserved across rematch, deliberately: slot identity, colours, spawn assignments, and every dev
toggle.

### Two traps in this function

**Seed collision.** Brains seed from `match_seed + slot_index`. Naively adding `round_index` makes
round 1 / slot 2 identical to round 2 / slot 1 — the bots would swap personalities between rounds.
Use a non-colliding combination, e.g. `match_seed + round_index * 101 + slot_index`.

**The `reset_to` landmine.** `player.gd::reset_to()` deliberately does **not** clear
`in_traversal_zone` / `climb_top_limit` — those are owned by the traversal zone's enter/exit
signals, and clearing them here was a real M1 bug. **Do not "tidy" it.** Instead assert in the
rematch test that no body ends a reset with `in_traversal_zone == true`, since the spawns sit
outside both ladder columns and the exit signal should have fired.

**Bar reset:** `gate.seal()` must snap the bars back to their CLOSED position instantly, not
animate them back down. A rematch is a new round, not a closing sequence.

---

## 14. Convergence and fairness instrumentation

Development-only, print-based, no persistence, no files written. **Report imbalance; never
auto-correct it.**

### Captured at OPEN, per slot

- Canonical node (or `air`), world position, region and band.
- Dijkstra route cost to `VaultFloor` under **neutral** weights — comparable across slots, unlike
  each bot's own weighted cost.
- Wrap-aware horizontal distance to the Relic, so the cost model's blind spot (§04) is visible
  rather than hidden.
- **Whether the body is standing on a seal piece** — the roof-camp measurement (§06).

### Captured at the win

- Winner slot; elapsed OPEN → collection.
- Per-slot first arrival on `VaultFloor`, giving arrival **order** and gaps, not just the winner.
- Door used — inferred from the last edge taken for a bot, from entry x for the human (<960 = west).
- Full node sequence per bot, so a bad route is diagnosable from the log alone.
- **Was the winner the player with the lowest route cost at OPEN?** One boolean. Aggregated, it is
  the single most useful number in the milestone.
- **Was the winner standing on a seal at OPEN?** (§06.)

### Aggregate report, printed after N rounds

| Signal | Measure | Flag when |
|---|---|---|
| Spawn dominance | Wins by slot over ≥20 bot-only rounds | any slot > 50% |
| Route monoculture | Door usage split | one door > 90% |
| Decided-at-OPEN | "nearest at OPEN wins" rate | > 80% |
| Roof-camp dominance | Seal-camper win rate | review, no threshold |
| Bot always wins | Human win rate across B1/B2/B3 | < 15% |
| Human always wins | Same | > 85% |
| Relic opens too fast | Slowest spawn's door arrival vs T | arrival > T |
| Relic opens too slow | Median slack at a door before OPEN | > 4s |
| Anticlimax | Median OPEN → win | < 1.5s |
| Convergence failure | Same | > 12s |

Every one of these is a **flag for the Director's attention**, not a trigger for a change.
Measurement reports; it does not design. **Geometry does not move in M3-2 beyond the two seal
strips** — and specifically not `B_Under`, the Pier top, or the Band C gap under the vault, which
stay hard on purpose as M4 pickup sites.

---

## 15. Scene and script structure

```
scenes/arena_01/arena_01.tscn
  Arena01                    scripts/arena_01.gd        [MOD  wire director, reset path]
    Geometry/
      VaultSealW             StaticBody2D               [NEW  x820-922   y336-376]
      VaultSealE             StaticBody2D               [NEW  x1080-1160 y336-376]
      ...all other geometry unchanged...
    MatchDirector            scripts/match_director.gd  [NEW  FSM + timer + reset]
    RelicGate                scripts/relic_gate.gd      [NEW  owns bars, bar lift, both seals]
    Relic (Area2D)           scripts/relic.gd           [NEW  overlap poll + tie-break]
    MatchTelemetry           scripts/match_telemetry.gd [NEW  dev-only, print-based]
    HUD/
      DebugLabel             scripts/debug_hud.gd       [unchanged - keep it separate]
      MatchLabel             scripts/match_hud.gd       [NEW  timer / state / result]

scripts/bot_brain.gd    [MOD  Goal enum, set_goal(), grounded re-path, relic approach]
scripts/nav_graph.gd    [MOD  "gated" flag on the five vault edges]
scripts/match_config.gd [MOD  setup_duration, round_index, seed_for()]
tools/m3_check.gd       [MOD  tests 10-18]
tools/arena_check.gd    [MOD  run R1-R12 in both gate states]
```

- **Do not repurpose `DebugLabel`** for match state. It is the M1/M2 movement debug readout and
  stays as it is; the match HUD is a separate label so either can be switched off alone.
- **`RelicGate` owns every gate visual state** — the bars, their lift animation, both seal strips,
  and the Relic's dimming — so "what does CLOSED look like" lives in exactly one file.
- **Unchanged, hard constraint:** `player.gd` movement physics and every M1 tuning value,
  `arena_wrap.gd`, `traversal_zone.gd`, `launch_pad.gd`, `seam_mirror.gd`, `edge_executor.gd`
  recipes, and the RELIABLE/SKILL classification of every existing edge.

---

## 16. Automated tests

Numbered from 10 to avoid colliding with `m3_check.gd`'s existing tests 0–9, **all of which must
keep passing.**

| # | Test | Catches |
|---|---|---|
| 10 | FSM transitions and timer accuracy at `time_scale` 1.0 **and** 1.25 | Frame-count timers; a loop that breaks under the approved tempo mechanism |
| 11 | Seal collision present in SETUP and UNLOCKING — **including while the bars are mid-lift** — absent in OPEN; `arena_check` R1–R12 clean in both states; R9 no-trap proven in both, with the roof as a probe origin | A seal that reads closed but is not; a seal that creates a trap; an animation that opens access early |
| 12 | **Nobody reaches the Relic during CLOSED or UNLOCKING.** Three bots plus a scripted adversary controller that beelines the west door, the east door, the header top and the roof, for the full setup duration and through the whole bar lift | The bypass class of bug — the one that invalidates the whole milestone |
| 13 | Strong connectivity + no-sink over RELIABLE edges **in the sealed state**, with `VaultFloor`/`VaultEast` as named expected exceptions | A2 — the arena losing its Crown-level crossing during SETUP |
| 14 | **Goal switch under load.** Fire OPEN with each bot mid-edge on each edge type (walk, jump, drop, ladder, launch) and airborne; assert executor abandoned, re-localised on a real node within 1.5s, path produced, arrival within budget, and **no position delta exceeding `max_speed × delta`** on any tick | Stale localisation, mid-air re-path, and any accidental teleport |
| 15 | Collection fires exactly once; same-frame two-body tie resolves by distance then slot, both branches exercised | Double winners; a tie rule that is really signal-emission order |
| 16 | Rematch resets everything: positions at spawns, zero velocity, no `in_traversal_zone`, bars back down, seals back on, fresh brains (empty path, empty blacklist, `stress_index` 0), timer zero, HUD cleared — and round 2 with a given seed reproduces the same position hash as an independently started round 2 | The field someone forgot; seed collisions between rounds |
| 17 | **20 headless bot-only matches** all terminate with a winner under 2 minutes, printing the §14 aggregate | Non-termination; and it is how the fairness report gets produced |
| 18 | `Pier → VaultFloor` from a spread of arrival speeds | The audit's note that a full-speed Pier departure lands on `VaultGateW`, not in the vault — far more likely once bots take this edge under time pressure |

---

## 17. Human playtest plan

Ordering principle: **each session should be able to fail without contaminating the next.**

| Session | Setup | Instruction | Answers |
|---|---|---|---|
| **B0** — state readability | Full loop, but bots still ROAM — no SEEK_RELIC yet. Relic collectible. | *"Move around. Tell me what the vault is doing."* Nothing about timers or states. | Q8 in isolation. If the sequence is not legible with nothing else moving, it will not be legible with three bots converging. |
| **B1a** — bot convergence | Everything on. Labels ON. | *"Stand still. Do not play. Watch the other three."* | Q12. The clean spectator read on whether the goal switch is visible. |
| **B1b** — the race | Same, 3 rounds. | *"Beat them to it."* | Q9, Q15. Is trying to win fun, or is it decided before you move? |
| **B2** — setup length | A/B: 10s → 15s → 25s → back to the winner of the first two. | Same instruction each time; no explanation of what changed. | Q10. The return leg is required for the same reason it was in the tempo A/B — one comparison cannot separate a preference from novelty. |
| **B2c** — control round | Relic OPEN from t=0. One round. | *"Same thing, one more round."* | Q14. Does the setup phase earn its place at all with no powers? |
| **B3** — the "Again." signal | Best configuration from B2. Unprompted. | Nothing. Hand it over and stop talking. | Q11. Counted, not asked: how many rematches before stopping unprompted. |

**One question to ask after B1b, before anything else:** *"Describe the rules of this game in one
sentence, as if to someone who has not seen it."* The product promise is that this is
understandable in seconds; that sentence is the only direct test of it in the whole milestone.

**Collision stays OFF for every session above.** An A/B with collision ON may follow acceptance,
never inside it — body-blocking at a door would function as an interference mechanic and pre-empt
M4's Push, the exact contamination the M2 "Push clarification" already recorded once. **Tempo stays
1.0×** throughout; no M1 constant is touched by this milestone.

---

## 18. Risks

| # | Risk | Sev | Mitigation |
|---|---|---|---|
| R1 | The rush is decided in ~1s by who stands at a door, and the round reads as a coin flip | High | Measured as the "decided-at-OPEN" rate before it is ever played. If confirmed, the fix belongs to M4's powers, not to more geometry |
| R2 | Mid-air re-path at OPEN produces three visibly confused bots at the milestone's most important moment | High | Cancel-on-ground (§08) + test 14's per-edge-type matrix |
| R3 | The seal changes bot routing arena-wide and something silently loses connectivity during SETUP | High | Test 13 — sealed-state strong connectivity, with named exceptions |
| R4 | A bypass into the sealed chamber that nobody thought of | High | Test 12 probes the roof and header top, not only the two doors, and probes *during* the bar lift. The volume, not the routes, is what is sealed |
| R5 | The bar lift reads as the gate opening while access is still sealed, and a player blames the game | Medium | The lift is deliberately late (final ~1.2s) and short. STOP 1 and B0 both judge it directly |
| R6 | Bots beat the human every round (P2 starts twice as close) | Medium | Report first. Levers, in order: setup length, per-bot reaction delay, a `bot_skill` scalar. Real difficulty tuning is M4/M7 |
| R7 | Roof-camping becomes the dominant strategy | Medium | Approved for testing (§06) — measured per round, reviewed later, not pre-emptively corrected |
| R8 | A bot takes `Pier → VaultFloor` at full speed and lands on `VaultGateW` | Medium | Test 18. Self-correcting in the OPEN state, but it must be proven, not assumed |
| R9 | 10s is wrong and the first playtest measures the timer instead of the loop | Medium | Headless door-arrival measurement before B0 (§04) |
| R10 | Scope creep into M4 — "the rush needs a power to be interesting" | Low | That conclusion is a legitimate M3-2 *finding* and the correct handoff to M4. It is not a licence to build one here |

---

## 19. Implementation order and STOP points

### Step 0 · Confirm the inherited baseline

Run `tools/arena_check.gd` and `tools/m3_check.gd` headless. Both must be at their accepted M3-1
state before a line of M3-2 is written — **the engine was not run during the planning session, so
this is unverified.** If either has regressed, **stop and report.**

### Step 1 · The gate, and nothing else  ⟵ REVISED per Director direction

Build **only**:

- the physical CLOSED seal (`VaultSealW`, `VaultSealE`);
- the existing six bars in their CLOSED position;
- a simple bars-lifting prototype, driven by a **debug key**, not by the match FSM;
- the minimal anti-bypass collision;
- Relic dim / bright visual states, if useful for this isolated test.

Do **not** build: the `MatchDirector` loop, `SEEK_RELIC`, winner detection, results, rematch, or
fairness logic — not partially, not as disabled stubs.

Validation before handing over: re-run `arena_check` in both gate states, and attempt the bypass
manually from both doors, the header top and the roof.

> ### ⛔ STOP 1 — Director visual inspection
> The Director inspects and answers:
> 1. Does CLOSED immediately read as **locked**?
> 2. Do the existing bars still feel like the **primary gate**?
> 3. Does lifting the bars clearly communicate **opening**?
> 4. Is the anti-bypass seal **visually unobtrusive**?
> 5. Does OPEN feel **substantially different** from CLOSED?
> 6. Can the player **physically bypass** CLOSED through either approach, the roof, or the header?
>
> **No later M3-2 implementation begins until STOP 1 is approved.**

### Step 2 · MatchDirector, timer, HUD, UNLOCKING, OPEN

Bots still ROAM; the Relic is not yet collectible. Tests 10, 11, 13.

> **STOP 2 — playtest B0.** State readability in isolation, with nothing else moving.

### Step 3 · Relic, collection, winner, RESULTS, rematch

Bots still ROAM, so the human wins every round — which is exactly what makes tests 15, 16 and 12
clean to run. Then run the **headless door-arrival measurement** and propose a setup duration.

> **STOP 3 — the timing number.** Measured per-spawn door-arrival times and a recommendation are
> reported. **The Director chooses the number.** It remains a temporary M3 value, and does not
> supersede the ~25s M4 direction.

### Step 4 · Bot goal switch

Gated edges, `SEEK_RELIC`, cancel-on-ground re-path, final approach. Tests 14, 18, then the full
existing suite 0–9 again.

### Step 5 · Telemetry and the fairness report

Test 17 — 20+ headless bot-only rounds, aggregate printed.

> **STOP 4 — imbalance report, before any tuning.** The fairness table and any flags it raised are
> reported. **Nothing is balanced, re-costed or moved without the Director's decision.**

### Step 6 · Human playtests B0 → B3

> **STOP 5 — acceptance.** Director acceptance, or a specific list of changes. Nothing is committed
> before this.

### Step 7 · Close out

Update `ROADMAP.md`, add M3-2 entries to `DECISIONS.md`, update `GAME_DESIGN.md` only if the design
actually changed, write the close-out into this file and `M03_CORE_GAME_LOOP.md`, and commit as one
milestone checkpoint on approval.

---

## 20. Explicitly out of scope for M3-2

Push · Freeze · Teleport · Shield · projectiles · power pickups · environmental Freeze · combat ·
damage · elimination · ghost mode · hazards and hazard respawn · bot personalities or difficulty
tiers · chasing, interference or aggression behaviours · production art, animation, VFX, audio ·
networking or backend · touch or mobile controls · couch multiplayer or device assignment ·
learned/imitation bots · six players · menus beyond the result strip · progression, XP, profile,
leaderboard · **any change to M1 movement scripts or tuning constants** · **any arena geometry
change beyond the two seal strips**.

### M3-1 is preserved, not reopened

Unchanged by this plan: the reliable road network · `Floor→C_M` and its reposition/build-runway
behaviour · the vault vertical-clear recipe · every topology edge · both ladders · wrapping · the
recovery ladder · the controller abstraction · collision OFF as the baseline · 1.0× tempo · the
RELIABLE/SKILL classification.

M3-2 will make bots use the vault far more heavily than roaming ever did, and that may expose a
navigation weakness that has never been under this kind of load. **If that happens it is identified
and reported as its own separate finding** — an M3-1 regression with its own evidence — and not
folded silently into M3-2's scope.

---

## 21. Close-out (2026-09-12) — ACCEPTED

All seven implementation steps (§19) were completed and all five STOP points were reached and
approved by the Game Director. **The accepted loop:**

```
SETUP → UNLOCKING → OPEN → SEEK_RELIC → COLLECTION → RESULTS → REMATCH
```

### What shipped, by step

- **Steps 1–3** (gate, MatchDirector/timer/HUD, Relic/winner/RESULTS/rematch) — built and STOP
  1/2/3-approved in an earlier session.
- **Step 4 — bot goal switch.** `BotBrain.Goal` (`ROAM`/`SEEK_RELIC`), orthogonal to `State`/`Mode`.
  `notify_open()` records the request; each brain's own `_check_goal_switch()` cancels its current
  executor/path/target on the first ROAM tick where its staggered reaction delay (0.15/0.30/0.45s)
  has elapsed **and** it is grounded on a valid graph node, capped at 1.2s (cancel anyway past the
  cap and let the stall ladder/RECOVER handle it — no special-casing for mid-transit states, per
  §08). `_pick_target_for_mode()` returns the constant `"VaultFloor"` whenever `goal == SEEK_RELIC`,
  overriding ROAM/NAV_STRESS_TEST target selection. `_final_approach_relic()` replaces intra-node
  wander with a wrap-aware walk to the Relic's real x once at `VaultFloor`. No teleporting, no
  position writes — verified by a per-tick displacement check across walk/jump/drop/ladder/launch/
  airborne/idle scenarios (test 18, all 8 scenarios passed).
- **Step 5 — telemetry and fairness report.** `scripts/match_telemetry.gd`, a dev-only print-based
  node wired into the live scene: per-slot snapshot at OPEN (node, region, neutral route cost,
  wrap-aware distance to Relic, seal-standing flag) and per-round results (winner, OPEN→win, door,
  arrival order, nearest-at-OPEN flag, roof-camp flag). `tools/m3_check.gd` test 20 runs 20 headless
  bot-only rounds (P1 bot-controlled for this experiment only) and prints the §14 aggregate table.

### Setup duration — ACCEPTED

**10 seconds is the accepted M3-2 baseline** for the current no-powers game. The 15s/25s debug
options (`debug_setup_15`/`debug_setup_25`) are preserved, not deleted. ~25s remains the M4 working
direction once powers give the setup phase real content — this is unchanged from §04.

### Arena 01 roof/east-wall pre-positioning — ACCEPTED as emergent strategy, not a defect

Human playtesting confirmed players/bots can legally pre-position on the Relic roof/header/east-
wall area before OPEN (P3 observed waiting on the roof, P4 around the east wall); when the seal
opens, a correctly positioned player can fall directly toward the Relic for a very fast collection.
**This is not fixed in M3-2** — it is recorded as an accepted emergent Arena 01 strategy. Full
decision, including the M4 counterplay hypothesis (Push/Freeze/projectiles/respawn as future
natural counters) and the future-arena design principle this motivates, is in `docs/DECISIONS.md`
(2026-09-12). Do not claim powers have "solved" it until playtested — if roof positioning remains
dominant after counterplay exists, Arena 01 is revisited then, not before.

### Fairness telemetry — preserved as diagnostic evidence, not acted on

20-round headless bot-only sample: P2 55% wins (flagged, not corrected), median/min/max OPEN→win
all 0.00s, nearest-at-OPEN win rate 0%, 0 non-terminating rounds, 0 hard recoveries. **Important
caveat, recorded rather than quietly presented at face value:** tracing the raw run showed the
near-universal 0.00s figure is largely explained by bots falling through the vault's now-open
ceiling from roof/header pre-positioning, not by racing through a door — and the telemetry's
single OPEN-instant position snapshot under-counts this (a body mid-fall through the ceiling reads
as `node=air, on_seal=false`, not as a roof-camp win), so the reported 10% roof-camp rate is a
floor, not the true rate. **No spawn, geometry, route cost, or bot-difficulty change was made from
this sample.** Improve the telemetry's timing resolution before treating fairness as a serious
tuning task.

### Regressions found and fixed during Step 4/5 validation (harness-only, not gameplay)

Several pre-existing M3-1/Step-1–3 tests used `debug_force_open()` purely to unseal the vault for
their own purposes; since OPEN now has real behavioural meaning for bots, this incidentally
hijacked their explicit targets. Fixed by resetting the affected brains back to ROAM immediately
after forcing the gate (tests 1, 4, 5, 7, 8) and, for test 8 specifically, disabling the always-
monitoring Relic's `_physics_process` during that test (it isolates raw traversal, not collection,
and one of its own test bodies walks directly across the Relic's collection zone en route to a
different target) — the same pattern tests 5/7 already used for the same reason. None of these
touched gameplay code; all are test-isolation fixes.

### Checker status at acceptance

- `tools/arena_check.gd`: **PASS**, 0 failures, unchanged from the accepted M2/M3-1 baseline (2
  acknowledged exceptions, both pre-existing and named in the tool itself).
- `tools/m3_check.gd` (tests 0–20): **4 known, deferred failures**, all the same checker-sampling
  artifact — `C_Seam→A_E_Bridge`, `A_W_Bridge→Pier`, `VaultFloor→VaultEast`, `VaultEast→A_E`, each
  failing only at one extreme boundary sample position (out of five) with an implausibly fast
  ~0.07s "steer" phase suggesting the body starts embedded in/against the wall at that exact
  sample point. Present before any M3-2 Step 4/5 code was written, unchanged across every run
  performed, and independent of the goal-switch code path (raw `EdgeExecutor` mechanics, no
  `BotBrain` involvement) — not fixed, per the standing "do not silently patch M3-1
  geometry/navigation" rule. Real gameplay evidence (20/20 clean fairness-round terminations, 0
  hard recoveries) indicates this checker-sampling artifact does not block real play. **Recorded as
  a deferred finding, not cleared to force an artificial green result.**

### M3 — Core Game Loop: COMPLETE

Both halves accepted. Next milestone per the existing roadmap: **M4 — Powers & Bot Intelligence**,
not started. Per the Game Director's own direction (see `docs/DECISIONS.md`'s "Future match
structure" entry, 2026-09-12, and `docs/GAME_DESIGN.md`'s corresponding future-direction section),
M4 implementation must be preceded by a dedicated match-economy design/planning milestone — M4 is
not simply "implement Push, Freeze, Shield and shooting."
