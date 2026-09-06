# M2 — Greybox Arena (Arena 01 V1, "The Seam Ring")

> ## ⚠️ SUPERSEDED (2026-09-06)
>
> **The implementation brief for Milestone 2 is now `docs/plans/M02_ARENA_01_V2.md`
> (Arena 01 V2, internal working name "The Gallery").**
>
> Arena 01 V1 was built, played once, and the Playtest 1 findings in **§17 below** showed the
> architecture was solving the wrong problem. V1 was redesigned rather than patched.
>
> **What this document is still for:**
> - **§17 — Playtest 1 findings.** These are the evidence that produced V2 and are its brief.
> - The V1 design reasoning, kept so it is not re-litigated. The *principles* in §2 and §8
>   survive into V2; the geometry in §3, §4, §6, §7 and §9 does not.
>
> **Do not build from §§1–16 of this document.** The V1 geometry is deleted in V2 — see
> `docs/plans/M02_ARENA_01_V2.md` §12 for the full delete / retain / repurpose disposition.

---

**Status: V1 — SUPERSEDED. Built, playtested once, redesigned.**
Originally approved by the Game Director with amendments, recorded in §0.2 and applied throughout.

This document was the implementation brief for Milestone 2. A future session should be able to
build Arena 01 V1 from this file alone — but should not, because V2 replaces it.

---

## 0. Approvals and amendments

### 0.1 Approved as proposed

| # | Decision |
|---|---|
| A1 | **Three structurally distinct approaches**, not five parallel routes: fast/skill launch, safe/legible ladder, positional/flanking seam-wrap. |
| A2 | **Cut the fifth/top catwalk.** Four walkable bands (ground, B1, B2, B3) plus the Relic destination deck. |
| A3 | `tools/arena_check.gd` is a **permanent committed regression tool**, not a temporary probe. This reverses M1's throwaway-harness practice. |
| A4 | **No portals in Arena 01.** |
| A5 | **Vertical-only launch pads.** M1 launch/movement physics is not changed to support angled pads. |
| A6 | The Relic **may sit slightly right of mathematical centre**, but must still read as visually central and immediately recognisable as the arena's objective. |

### 0.2 Amendments (these override the original proposal)

**M1 — Route-cost calculations are diagnostic, not the game designer.**
Automated timing and reachability measurement exists to detect *unfair spawns, impossible geometry
and accidental dominant shortcuts*. It does **not** normalise routes to equal travel time.

- The fast route is **allowed** to be meaningfully faster, because it carries more execution and
  interception risk.
- Human playtesting **overrides** mathematically elegant route timing.
- The ≤15% spawn-to-objective spread is an **initial fairness diagnostic only**. If satisfying it
  would damage route identity, **flag it and leave the arena alone** — do not distort geometry to
  hit the number.

**M2 — Readability outranks route-graph complexity.**
The graph below is deliberately sophisticated for a first arena. If the implemented greybox feels
visually crowded or hard to parse at 1920×1080, **simplify or remove geometry** rather than
preserving every planned platform.

The target is:

> see → understand → choose → move

not:

> study the level → understand the graph → move

**M3 — The first human test is unprompted exploration.** See §11. Do not walk the Director through
structured test rounds on first contact.

---

## 1. The gameplay question M2 must answer

The roadmap asks: *"Can a fixed single-screen side-view arena provide enough navigation depth while
keeping every player location understandable?"*

Sharpened so a playtest can falsify it:

> **Primary:** Using only the M1 movement language, does one fixed screen produce route choices a
> player can *see, predict and act on* — or does it collapse into one obvious best path?
>
> **Secondary:** Does horizontal wrapping read as a *strategic space* ("the seam is a place I can
> use") rather than an edge rule ("I didn't fall off")?

M2 fails if there is one dominant route, or if the seam feels like a technicality.

---

## 2. Design rationale that shaped the arena

Three premises were challenged during planning. Two changed the design. Recorded so they are not
re-litigated.

### 2.1 "Central Relic chamber" is not meaningful in a wrapped arena

The left and right edges connect, making the arena a cylinder of circumference 1920. Every player is
at most **960 px** from any x-coordinate, in *both* directions. Horizontal centrality confers zero
protection — x=960 is topologically identical to x=0.

**Therefore the Relic is protected by height and structure, never by horizontal distance.** It is an
elevated deck with no ladder to it, reached only by three distinct manoeuvres. Per A6 it stays close
enough to centre to read as the arena's focal point.

### 2.2 Five parallel routes would read as one route with five skins

"Vertical" and "launch" are *traversal verbs*, not destinations. Five lanes converging on a 260 px
deck reads as noise, not choice. What creates the see → predict → intercept loop is **arrival
property**: does the opponent come at me from below, from the side, or from the far side of the seam?

Hence A1: three approaches with genuinely different arrival properties, plus **wrapping as
connective tissue** — the cheapest way to change *which* approach you attack from, rather than a
fourth approach of its own.

### 2.3 A fifth top-tier layer costs more than it returns

A catwalk at y≈140 was designed and cut. Its access ladder had to top out at y≈60, consuming the HUD
band; the drop onto the Relic had to be ≥200 px to stay one-way; and its payoff was a single one-way
approach costing a 1.15 s climb. Too much arena for one door. Hence A2.

---

## 3. Arena 01 — "The Seam Ring"

### 3.1 Schematic (1 char ≈ 40 px, 1920×1080, y increases downward)

```
     |     |     |     |     |     |     |     |
x:   0    240   480   720   960  1200  1440  1680  1920

y380                        ████████
                            ▲ SHRINE (Relic placeholder)

y450 █████     ████████             ████████╫╫███████
     B3S(w)      B3W                  B3E   Lad  B3S(e)
                                             E

y650         ║ ███████▲███       ███████    ║
             ║   B2W  Pad  B2W     B2E      ║
             ║       H                      ║
y750         ║            █████             ║
            Lad            B1.5W           Lad
             W                              E
y845        █████████                █████████
               B1W                      B1E

y1000 ████████████████████████████████████████████████
                        GROUND  (continuous, wraps)
```

**The left and right edges of this diagram are the same place.** `B3S(w)` and `B3S(e)` are one
platform seen from both sides of the seam.

### 3.2 Route graph

```
                        ┌──────── SHRINE ────────┐
             jump 250   │      (Relic deck)      │  jump 60
             rise 70    │                        │  rise 70
                 ┌──────┘                        └──────┐
                 │                                      │
               B3W ◄─── jump 250, ACROSS THE SEAM ───► B3S ◄─ jump 100 ─► B3E
                 ▲                                      ▲                  ▲
                 │ LadW (485px, 1.21s)                  └── LadE (485px, 1.21s) ──┘
                 │                                            (exit left OR right)
               B1W ─── jump 240/+95 ──► B1.5W ─ jump 20/+100 ─► B2W ──PadH──► SHRINE
                 ▲                                              │  (launch, one-way)
                 │ jump +155                          jump 280  │
                 │                                    (level)   ▼
              GROUND ◄──── continuous, wraps ────► B1E ──►     B2E
                                                     ▲          │
                                                     └── drop ◄─┘
```

**Every platform can drop to the ground. The ground is continuous and wraps. No player can ever be
stranded.**

### 3.3 Why each element exists

Nothing here is placed for visual balance.

| Element | Why it exists |
|---|---|
| **Ground** (open, continuous) | The *repositioning lane*: fast horizontally (500 px/s, unobstructed), useless vertically. Deliberately empty — it is the arena's negative space and its safety net. |
| **B1W / B1E** | The **only** 155 px step-up from the ground. They gate everything above and give the ground sprint a destination in each direction. Two of them, far apart. |
| **B1.5W** (small, 140 px) | Exists *solely* to make the fast route a chain of jumps. Without it, B1W→B2W is a 195 px barrier and the fast route would need a ladder — i.e. would not be fast. This is the arena's skill-expression element. |
| **B2W** | Carries PadH; west half of the mid lane. |
| **B2E** | The **overshoot catch** for a mis-steered launch, and mid-height transit. Deliberately has *no* route upward (B2E→B3E is a 200 px barrier), so it is a place you pass through, never a position you hold. |
| **B3W / B3E** | The Relic's two neighbours on the ring, with deliberately different gap profiles (250 px west vs 60 px east) so the two side approaches do not feel identical. |
| **B3S** (seam corridor) | The **only** Band-3 element crossing the seam. It is what makes the top a ring, and what makes wrapping structural rather than cosmetic. |
| **Shrine deck** | Elevated, no ladder, three approaches, no straight line. Positioned by *height*, not by x (§2.1). |
| **PadH** | The fast route's payoff and the only ladder-free entrance to the upper ring. Its arc is fixed and public — that is its price. |
| **LadW / LadE** | The two slow, safe, fully legible ring entrances. 1.21 s each — long enough that committing is a *visible decision*. LadE tops out in a gap offering a left-or-right exit, making it a decision point rather than a corridor. |
| **Both ladder columns** | Double as **drop shafts** — running off B3W's left edge or B3E's right edge falls 395 px straight down to Band 1. One element, two functions. |

### 3.4 Deliberate empty space

Roughly 55–60% of the frame is open air: the whole ground band, the region under the Relic between
y 420–640, and the west third below Band 3. A 36×56 player is ~5% of screen height; each band is
~200 px ≈ 3.5 character heights of headroom.

Under amendment M2, this is a floor, not a ceiling — if it still feels crowded in play, remove
platforms.

---

## 4. The three approaches

### Approach A — Launch line (fast / skill / risky)
`GROUND → B1W → jump 240 → B1.5W → jump 20/+100 → B2W → PadH → Relic deck`
**≈ 2.6 s** from B1W. Three consecutive jumps then a launch. **Three failure points**, each dropping
you to the ground.

The launch arc is a fixed public parabola from a known pad — at M4 this is where a Freeze or Push is
devastating. Holding "right" for the entire flight overshoots the deck by ~26 px and drops you to
B2E. **You must release steering mid-flight.** That is the skill.

### Approach B — East ladder (safe / slower / legible)
`GROUND → B1E → LadE (1.21 s) → B3E → jump 60/+70 → Relic deck`
**≈ 3.4 s.** No failure risk at all. Its cost is 1.21 s of *stationary, fully visible commitment* —
anyone watching knows exactly where you will emerge, and can be waiting.

### Approach C — Seam ring (positional / flanking)
`GROUND → B1E → LadE → exit RIGHT onto B3S → run across the seam → jump 250 → B3W → jump 250/+70 → Relic deck`
**≈ 3.9 s.** You arrive from the *opposite side* of the Relic from where you were last seen.

### Intended cost premium

Fast is ~25% faster than B and ~33% faster than C. **Per amendment M1, this asymmetry is intended
and must not be normalised away.** The fast route buys its speed with execution risk and, from M4,
with interception risk.

---

## 5. How wrapping becomes strategic

Wrapping only matters if **the shortest path between two places crosses the seam.** The design puts
one there:

> **The Band-3 ring closes *only* through the seam.**
> B3W (410–670) — 190 gap — SHRINE — 60 gap — B3E (1240–1540) — 100 gap — **B3S (1640 → wraps → 160)** — 250 gap — back to B3W.

There is **no** Band-3 connection between B3W's left edge and B3S's east end other than through the
seam. A player on B3E who wants to reach B3W has two options:

| Route | Cost |
|---|---|
| Run east, **cross the seam**, run to B3W | ~430 px + 250 gap ≈ **1.4 s** |
| Drop 395 px to B1E, run the ground west ~1000 px, climb LadW | ≈ **3.5 s** |

**2.5× advantage to the wrap route.** That is what "strategically useful" means concretely.

### Wrapping does not trivialise the Relic

The seam corridor's exits are B3W (250 px jump, then a *further* 250/+70 jump to the deck) and B3E
(100 px jump, then 60/+70). Neither is a direct entry. **Crossing the seam repositions you; it does
not deliver you.** The ring's three entrances (LadW, LadE, PadH) are all below Band 3, so no amount
of wrapping skips the climb.

### The prediction loop this creates

A player on the Relic deck watches an opponent run off the right edge of the screen at Band 3. They
know, with certainty, that the opponent reappears on the left in ~0.4 s and will approach from B3W.
They can hold that side, or bail east. **See → predict → choose → intercept.**

### Hard rule

**No hazards within 200 px of the seam, ever.** If crossing the seam is punished, players stop doing
it and the ring dies.

---

## 6. Spawns and the fairness model

**Fairness model:** rotationally distributed spawns with **asymmetric terrain**. Fairness is
established by *measured route cost*, not by mirroring geometry. This resolves the tension between
"spawns must be fair" and "avoid excessive symmetry."

| Spawn | Position | Band | Character of the start |
|---|---|---|---|
| **P1** | (150, 972) | Ground, west of seam | Nearest LadW; can also sprint left through the seam. |
| **P2** | (760, 972) | Ground, mid-west | Directly under B2W; the natural fast-route start. |
| **P3** | (1450, 817) | B1E | Only elevated spawn; sits on LadE, controls the ring's east chokepoint. |
| **P4** | (1900, 972) | Ground, at the seam | No adjacent climb — must commit left or right. The spawn that "owns" the wrap. |

These x-positions are **provisional**. `arena_check` §9.3 produces the real numbers.

**Per amendment M1:** the ≤15% spread is an initial diagnostic. If hitting it would flatten the
distinct character of a spawn, **flag the deviation in the check output and leave the arena alone.**
Human playtesting decides.

**Rejected:** spawning anyone on B2E — it can jump the 280 px Band-2 gap straight to PadH, making
that spawn ~2.5 s to the Relic and privileged.

**Six-player breathing room (not designed, only not foreclosed):** the ground has ~1900 px of
continuous run, so spawns 5 and 6 drop in at x≈1050 and x≈1700 with no geometry change. The binding
constraint at six would be the **three ring entrances**, not floor space — a reason to keep three
entrances rather than two.

---

## 7. Relic chamber (spatial placeholder only)

- **Deck:** x 920 → 1180, surface y = 380, 260×40.
- **Relic marker:** a 40×60 ColorRect at (1050, 330). **No collision, no script, no state, no
  behaviour.** It exists to occupy space and be looked at.
- **Placement per A6:** 90 px right of mathematical centre — enough to break false symmetry, not
  enough to stop reading as the focal point. It is the highest object in the arena and the only
  gold-coloured one. **If it does not read as the objective on sight in playtest, move it back
  toward centre or enlarge the deck** — recognisability outranks the anti-symmetry preference.
- **Approach structure:** three (§4). No approach is a straight line; each requires either a launch,
  a 1.21 s climb, or a seam crossing.
- **"See it, can't reach it":** the Band-2 lane runs directly *beneath* the deck (280 px gap at
  x 860–1140, 290 px of headroom). Players jumping that gap look straight up at the Relic. B1.5W
  sits under it too, 370 px below.

**Flagged for M3, not solved in M2:** the deck is reachable from three sides and easy to defend once
occupied. With a 25 s locked-Relic phase, camping is a real strategy. That is an M3 game-loop
problem.

---

## 8. Movement feasibility — derived rule set

This section exists to prevent the M1 failure where geometry was visually plausible but physically
impossible. All values derive from the accepted M1 constants (`max_speed 500`, `gravity 2200`,
`jump_strength 900`, `launch_strength 1500`, `climb_speed 400`, body 36×56).

### 8.1 Derived envelope

| Quantity | Value |
|---|---|
| Jump rise | 900² / (2·2200) = **184 px** (apex 0.409 s, full arc 0.818 s) |
| Level-gap reach at full speed | **409 px** centre-to-centre; usable landing gap **≈350 px** |
| Launch rise | 1500² / (2·2200) = **511 px** (apex 0.682 s → **341 px** of steering on the way up) |
| Climb rate | 400 px/s |

### 8.2 Design rules (all machine-checkable)

| # | Rule | Reason |
|---|---|---|
| **R1** | Step-up ≤ **150 px** (comfortable) **or ≥ 200 px** (deliberate barrier). **155–184 px is forbidden.** | That band looks jumpable and intermittently fails — exactly how "visually plausible, physically impossible" happens. |
| **R2** | Level gap ≤ **280 px** (comfortable). **281–420 px forbidden.** > 420 px = deliberate barrier. | Same reasoning on the horizontal axis. |
| **R3** | A launch pad's vertical column must be **clear of solid geometry to its apex**, and its arc must not clip the *underside or edge* of any platform inside the reachable cone. | M1's exact bug: the pad fired into the platform it was meant to reach. |
| **R4** | A ladder column must be **clear of solid geometry from base to top**, and its top must sit **80–100 px above** the destination surface, with the destination edge within ~70 px. | M1's other bug (ladder under a platform). The overshoot is required: it buys ~0.24 s of fall time ≈ 118 px of lateral step-over. A top level with the surface leaves only ~52 px and the climber falls back down. |
| **R5** | Launch pads only on surfaces with **y ≥ 620**. | A 511 px rise from any higher surface exits the top of the screen, violating "entire arena visible." Consequence: launchers live in the lower two-thirds, giving them a clean identity — *the launcher is how you escape the bottom.* |
| **R6** | Any seam-crossing platform needs collision covering **x ∈ [1920, 1978]** and **[−58, 0]**. | New bug class from wrapping × multi-layer geometry. `arena_wrap.gd` wraps only after the origin passes `right_edge + exit_margin` (1960). Between 1920 and 1960 the body is off-screen and **still needs floor.** |

### 8.3 Verified critical relationships

Arithmetic done during planning; to be re-proven by `arena_check` before any playtest.

| Relationship | Numbers | Margin |
|---|---|---|
| Ground → B1 step-up | 155 px rise | R1 comfortable |
| B1W → B1.5W | 240 px gap, +95 rise | 285 px available → **45 px margin** |
| B1.5W → B2W | 20 px gap, +100 rise | 276 px available → wide |
| B2W ↔ B2E | 280 px level | at R2 limit |
| B1 → B2 | 195 px | R1 barrier (intended) |
| B2E → B3E | 200 px | R1 barrier (intended) |
| B3E → Shrine | 60 px gap, +70 rise | 322 px available → wide |
| B3W → Shrine | 250 px gap, +70 rise | 322 px available → **72 px margin** |
| B3S → B3W (seam) | 250 px level | ok |
| B3E → B3S | 100 px level | ok |
| LadW / LadE | 485 px climb = **1.21 s** | ok |
| **PadH → Shrine** | see §8.4 | **90 px lateral clearance** |

### 8.4 PadH clearance derivation

The tightest relationship in the arena, and the reason the pad moved twice during planning.

Pad at x=720 on B2W (y=650, origin 622). Shrine deck occupies y 380–420, x 920–1180.

- Player's body clears the deck's top plane (origin < 352, rise 270) at **t = 0.213 s**.
- Player first laterally overlaps the deck (x+18 > 920, travel 182 px at 500 px/s) at **t = 0.364 s**.
- → Clears the deck's edge by **0.15 s ≈ 90 px** before it could strike the underside.

Landing window: the player is above deck level from t=0.213 to t=1.150 (0.937 s → 468 px of
steering). Valid landing origins are 938–1162, i.e. +218 to +442 px. Holding right for the whole
flight gives +468 → **overshoots by 26 px and drops to B2E.** Deliberate.

### 8.5 Known movement quirk — vertical pads only (A5)

`receive_launch()` does `velocity.x += dir.x * launch_strength` with no clamp, but air steering does
`move_toward(velocity.x, intent * max_speed, ...)`. So after an *angled* launch, **holding the
direction of travel decelerates you** toward 500, while releasing input preserves ~1060. That is
backwards and would make an angled pad feel broken.

Arena 01 uses one vertical pad. **This is recorded as a known movement characteristic, not an M2
defect.** If angled pads are ever wanted, that is a movement change requiring its own approval — not
something M2 patches for arena convenience.

### 8.6 Interaction to verify in playtest (probably a feature)

LadE's column spans the 100 px B3E↔B3S gap. A player jumping that gap *while holding up* will latch
onto the ladder mid-air. That reads like grabbing a ladder in flight, which is good — but it is
emergent, not designed, so it gets played before it is blessed.

---

## 9. Proposed geometry (Godot values)

Provisional — finalised by `arena_check` as implementation step 1. Platform thickness 40 px.

| Node | Type | Position (centre) | Size |
|---|---|---|---|
| `Ground` | StaticBody2D | (960, 1040) | 2120 × 80 |
| `B1W` | StaticBody2D | (470, 865) | 340 × 40 |
| `B1E` | StaticBody2D | (1480, 865) | 360 × 40 |
| `B15W` | StaticBody2D | (950, 770) | 140 × 40 |
| `B2W` | StaticBody2D | (640, 670) | 440 × 40 |
| `B2E` | StaticBody2D | (1270, 670) | 260 × 40 |
| `B3W` | StaticBody2D | (540, 470) | 260 × 40 |
| `B3E` | StaticBody2D | (1390, 470) | 300 × 40 |
| `B3S` | StaticBody2D (seam-mirrored) | (1860, 470) + mirror at (−60, 470) | 440 × 40 |
| `Shrine` | StaticBody2D | (1050, 400) | 260 × 40 |
| `RelicPlaceholder` | ColorRect only | (1050, 330) | 40 × 60, **no collision** |
| `PadH` | Area2D (`launch_pad.gd`) | (720, 620) | 140 × 50, `launch_direction = (0,-1)` |
| `LadW` | Area2D (`traversal_zone.gd`) | (360, 602.5) | 80 × 485 |
| `LadE` | Area2D (`traversal_zone.gd`) | (1590, 602.5) | 80 × 485 |
| `Spawn1..4` | Marker2D | (150,972) (760,972) (1450,817) (1900,972) | — |

**Greybox palette** — readability hierarchy, not decoration:

| Element | Colour |
|---|---|
| Ground | `0.30` grey |
| Platforms | `0.45` grey |
| Seam corridor (B3S) | `0.52` grey — visually distinct; it is the wrap lane |
| Ladders | `(0.2, 0.6, 0.9, 0.4)` — as M1 |
| Launch pad | `(0.9, 0.7, 0.1)` — as M1 |
| Relic | `(0.85, 0.75, 0.25)` |
| Player | red — as M1 |

### 9.1 Scene / node / script architecture

```
scenes/arena_01/arena_01.tscn
  Arena01 (Node2D)                    ← scripts/arena_01.gd            [new, small]
    ArenaWrap (Node2D)                ← scripts/arena_wrap.gd          [REUSED unchanged]
    Camera2D                            position (960,540), static
    Geometry (Node2D)
      Ground, B1W, B1E, B15W, B2W, B2E, B3W, B3E, Shrine
      SeamMirror (Node2D)             ← scripts/seam_mirror.gd         [new, ~25 lines]
        B3S                             duplicated at ±1920 on _ready
    Traversal (Node2D)
      LadW, LadE                      ← scripts/traversal_zone.gd      [REUSED unchanged]
      PadH                            ← scripts/launch_pad.gd          [REUSED unchanged]
    Markers (Node2D)                    Marker2D only, zero behaviour
      Spawn1..Spawn4
      PickupCandidate1..4, HazardCandidate1..2
    RelicPlaceholder (ColorRect)
    Player (instance)                 ← scenes/player/player.tscn      [REUSED unchanged]
    HUD (CanvasLayer) → DebugLabel    ← scripts/debug_hud.gd           [REUSED unchanged]
```

**New code is two files.**

- `scripts/seam_mirror.gd` (~25 lines): duplicates each child at ±`arena_width` so seam-crossing
  geometry has collision on both sides. Exists to make R6 impossible to get wrong by hand.
- `scripts/arena_01.gd` (~30 lines): spawn placement + `debug_reset` (adapted from
  `movement_lab.gd`) + a `debug_spawn_cycle` key that teleports the single player between the four
  spawns for route testing.

**Unchanged, and this is a hard constraint:** `player.gd`, `arena_wrap.gd`, `traversal_zone.gd`,
`launch_pad.gd`, and every M1 tuning value. **If the arena needs a movement change to work, the
arena is wrong, not the movement.**

`project.godot` → `run/main_scene = res://scenes/arena_01/arena_01.tscn`. The Movement Lab stays
intact and runnable as the regression harness. `main.tscn` stays an empty placeholder; M3 decides
its fate.

---

## 10. Automated traversal / reachability checks

Per A3, `tools/arena_check.gd` is a **permanent committed regression tool.** M1's harness was
throwaway and still earned its place three times; M2's geometry has more simultaneous constraints,
and M3/M4/M6 are likely to silently regress it. Built first, not last.

Run headless: `godot --headless --script tools/arena_check.gd`

| # | Check | What it does |
|---|---|---|
| **10.1** | **Static geometry audit** | Pure maths against the M1 constants, no simulation. Fails on any R1–R6 violation. Reports **every** gap and step-up **with its margin**, so a tight-but-legal relationship (45 px on B1W→B1.5W, 90 px on PadH) is visible rather than discovered in a playtest. |
| **10.2** | **Simulated route proofs** | Drives the *real* player through scripted input, asserting arrival on the Shrine deck for Approach A, B and C (both directions), plus every edge in the §3.2 graph. |
| **10.3** | **Route-cost table** | From each of the four spawns, the cheapest proven time to the deck. **Diagnostic per amendment M1** — it reports the spread and flags >15%, it does not authorise geometry changes on its own. |
| **10.4** | **Wrap integrity** | A body runs the full ring in both directions at ground level and Band 3, asserting it never falls unintentionally and returns to its origin. This is the test that catches a missing seam mirror. |

---

## 11. Human playtest procedure

**Per amendment M3, first contact is unprompted exploration. Do not explain the routes beforehand.**

### Session 1 — Unprompted exploration (first, and alone)

When technically ready, tell the Director **only the controls** and:

> "Explore the arena and try to reach the Relic deck."

Say nothing about the fast, safe or wrap routes. Say nothing about the seam. Let them play for
several minutes.

Then ask exactly these:

1. Which route did you discover first?
2. Did you understand where the Relic was?
3. Did the arena feel like one connected place?
4. Did you naturally discover wrapping as navigation?
5. Was anything visually reachable but physically unreachable?
6. Did you get stuck?
7. Which areas felt unnecessary or confusing?

Question 5 is the M1 failure mode. Question 7 feeds amendment M2 — **an area called unnecessary is a
candidate for deletion, not defence.**

### Session 2 — Deliberate route validation (only after Session 1)

Once the unprompted test is complete and its feedback is recorded, deliberately validate the three
planned approaches and seam behaviour: walk each route, confirm it is achievable by a human and not
only by the checker, and test the seam crossing in both directions from Band 3 and from the ground.

### Session 3 — Four-player readability proxy (optional)

Three static coloured rectangles placed at plausible opponent positions. "At a glance: who is where,
and where are they heading?" Zero code, no physics, no scripts. This is the closest approximation to
four-player legibility available before bots exist.

---

## 12. Acceptance criteria

| # | Criterion | Verified by |
|---|---|---|
| 1 | Entire arena visible in one fixed 1920×1080 frame; camera never moves | Visual + scene inspection |
| 2 | The 36×56 player stays readable against all geometry | Playtest |
| 3 | All four spawns have a proven route to the deck | `arena_check` 10.2 |
| 4 | Spawn-to-objective spread reported; **>15% flagged, not auto-corrected** (amendment M1) | `arena_check` 10.3 |
| 5 | **≥3 structurally distinct approaches** to the deck, each proven end-to-end | `arena_check` 10.2 |
| 6 | **No dead ends** — every position can return to the ground | `arena_check` 10.2 |
| 7 | Wrapping is used by ≥1 route whose alternative is **≥2× longer** | `arena_check` 10.3 |
| 8 | **Zero** R1–R6 violations — no impossible *or ambiguous* geometry | `arena_check` 10.1 |
| 9 | **No changes to M1 movement scripts or tuning values** | `git diff` |
| 10 | Godot MCP run produces no errors introduced by M2 | MCP debug output |
| 11 | Relic reads as the arena's objective on sight, without explanation (A6) | Playtest Q2 |
| 12 | Arena is understandable without studying it — see → understand → choose → move (amendment M2) | Playtest Q3, Q6, Q7 |
| 13 | Routes feel meaningfully different (roadmap) | Playtest Session 2 |
| 14 | Relic not reachable by one trivial straight line (roadmap) | §4 + playtest |
| 15 | Director accepts navigation and route legibility | Playtest |

---

## 13. Risks

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| R1 | **Seam-crossing collision holes** — new bug class from wrapping × multi-layer geometry. A body between x=1920 and 1960 is off-screen and still needs floor. | **High** | `seam_mirror.gd` makes it structural, not manual. `arena_check` 10.1 (R6) + 10.4. |
| R2 | **Ladder terminating under solid geometry** — M1 hit this exactly. | **High** | Rule R4 + `arena_check`. Both ladder columns verified clear to y=360. |
| R3 | **Launch arc clipping the Relic deck's underside.** Two earlier pad placements failed this, one by 1 px. | **High** | Rule R3 + `arena_check`. Current placement clears by 90 px (§8.4). |
| R4 | **Arena feels crowded / graph-like rather than legible.** | **High** | Amendment M2 governs: simplify or delete geometry. Playtest Q3/Q7 is the trigger. |
| R5 | **Angled launch pads fight air steering.** | Medium | A5: vertical pads only. Recorded as a movement characteristic (§8.5), not fixed here. |
| R6 | **Arena reads as a platformer level**, not a Rushlings arena. | Medium | Ground kept open; Relic high and visible from everywhere; playtest Q3. |
| R7 | **Relic deck camping** once the Relic is functional. | Medium | Named now, solved at M3. Not an M2 problem. |
| R8 | **Off-screen moment at the seam × 4 players.** M1 accepted a brief off-screen frame with one player; with four, "where did they go?" may be genuinely confusing. | Medium | Playtest Q4 and Session 3. If it fails, it is a *wrapping* decision to revisit, not an arena one. |
| R9 | Tight margins (45 px on B1W→B1.5W, 72 px on B3W→Shrine) pass the checker but feel bad. | Low | `arena_check` reports margins explicitly; tune in Phase E. |
| R10 | **Scope creep into M3** (relic behaviour, timer, win state). | Low | Hard boundary in §14. |

---

## 14. Explicitly out of scope for M2

Bots · powers · projectiles/shooting · **functional Relic** (no countdown, unlock, collection or win
state) · match timer / game loop · respawn · **implemented** hazards (positions marked only) ·
**implemented** pickups (positions marked only) · portals · mobile/touch controls · production UI or
HUD beyond the M1 debug label · art · animation · VFX · audio · networking/backend · more than one
player instance (static proxy rectangles for the readability test are not players) · **any change to
M1 movement scripts or tuning values** · six-player gameplay · angled launch pads.

---

## 15. Future positions — marked only, not implemented

### Power pickups (M4)

Principle: one per route identity, so choosing a route is also choosing a power access pattern.

| Marker | Position | Why there |
|---|---|---|
| PU-A | Ground, x≈960 | Maximum detour from the goal, maximum exposure. The "greedy but stupid" pickup. |
| PU-B | B2E, x≈1270 | The overshoot catch — a failed launch is consoled with a power. |
| PU-C | B3S, x≈1880 | Rewards committing to the seam route. |
| PU-D | B1.5W, x≈950 | On the fast route's hardest link — offsets its risk so the fast route is not purely a gamble. |

### Hazards (M3/M4)

| Marker | Position | Why there |
|---|---|---|
| HZ-1 | Ground strip x 660–880 | Under the B1W→B1.5W gap — the fast route's hardest jump costs a respawn, not just a fall. |
| HZ-2 | Ground strip x 900–1120 | Under the Relic deck — falling off the deck costs a respawn, not a free retry. |

**No hazard within 200 px of the seam** (§5).

### Portals — deliberately none (A4)

A portal's candidate functions are already covered:

| Function | Already provided by |
|---|---|
| Instant lateral repositioning | Horizontal wrapping (the seam ring) |
| Skip vertical layers | PadH |
| Arrive somewhere unexpected | Crossing the seam at Band 3 |

The only distinct function left is bidirectional teleport between two arbitrary non-adjacent points
— and the **Teleport power at M4 is planned to use paired-portal logic.** Shipping arena portals now
would blur the reading of that power: a player seeing a portal effect could not tell whether it is
arena furniture or someone's power. If M2 playtesting shows a genuinely missing connection type, add
it then, with evidence.

---

## 16. Implementation order for the next session

1. `tools/arena_check.gd` static audit (§10.1) — **before** any geometry, so violations are caught
   at authoring time.
2. `scripts/seam_mirror.gd`.
3. `scenes/arena_01/arena_01.tscn` geometry per §9, running the static audit as it is built.
4. `scripts/arena_01.gd` + spawn markers.
5. `arena_check` simulated route proofs, cost table and wrap integrity (§10.2–10.4).
6. Switch `run/main_scene`; MCP run; confirm no errors.
7. **Stop. Hand to the Director for unprompted exploration (§11 Session 1).**

Estimated: one session for the checker and geometry, one for tuning and the playtest.

---

## 17. M2 Playtest 1 — Findings (2026-09-06)

**Status: recorded as playtest evidence only. Not yet acted on.** The Director completed the first
unprompted-exploration session (§11 Session 1) against the built Arena 01 greybox. The result is a
**larger design issue**, not a set of local geometry bugs. Per the Director's explicit instruction,
this section is a record of findings only — no redesign, patching, or further implementation follows
from it in this session. The next M2 session should treat this as its starting brief.

### 17.1 Validated

The M1 movement language and the core presentation format hold up inside a real arena, not just the
Movement Lab:

- Fixed-camera arena direction works.
- Current player scale works.
- M1 movement works inside a larger arena.
- Jump works.
- Ladders work.
- Horizontal wrapping works.
- Multiple vertical levels are understandable.

### 17.2 Problems

- Arena feels too sparse.
- Too much empty/non-playable space.
- Geometry reads as isolated floating platforms rather than one connected arena.
- Level design is too focused on route-to-Relic optimization.
- The Relic currently feels too quickly/directly reachable.
- The arena does not yet create enough space for four players to chase, fight/interfere, and use
  powers.
- Spawn layout does not communicate four distinct player territories.
- B1.5W is technically reachable but feels unnecessarily difficult/slippery in human play.
- The fast/launch route has a genuine geometry conflict (recorded during implementation, §7 of the
  M2 session record / DECISIONS.md pending) and should not be patched independently of this larger
  redesign.

### 17.3 New design requirement

**Arena 01 should remain fun and strategically interesting even if the Relic is temporarily
removed.** The arena needs to support four simultaneous players interacting with each other, not
merely four players independently finding routes to an objective.

Future arena design must consider likely power/projectile interactions even though powers are not
implemented in M2.

Four starting territories should approximately occupy:

- top-left
- top-right
- bottom-left
- bottom-right

This does not require perfectly symmetric geometry.

The arena should include:

- A meaningful continuous, or largely continuous, lower floor or lower interaction zone.
- Stronger horizontal connectivity across upper layers.
- Intentional gaps/choke points.
- A more structurally protected Relic chamber.
- More platforms connecting the left and right sides of the screen specifically — players should be
  able to run from one side of the screen to the other across a chain of platforms like this, not
  only via the ground or a single upper ring.

**Explicitly out of scope for the next session too:**

- Portals — not yet.
- Powers — not yet implemented.
- M1 movement — not to be modified.

### 17.4 Disposition

Recorded as evidence per the Director's instruction. No geometry, scripts, or scenes were changed as
a result of this playtest. The existing Arena 01 greybox (as implemented and checked in §§9–10) is
left in place, launch-route conflict and all, pending a full redesign session that treats §17.3 as
its brief.

**Resolved (2026-09-06):** that redesign session produced **Arena 01 V2**, approved by the Game
Director with seven amendments. §17.3 was its brief and every finding above is answered in
`docs/plans/M02_ARENA_01_V2.md` §13. The V1 geometry, including `B1.5W` and the conflicting launch
route, is **deleted rather than patched** in V2.
