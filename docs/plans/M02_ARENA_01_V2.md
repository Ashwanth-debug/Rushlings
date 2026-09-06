# M2 — Arena 01 V2 ("The Gallery")

**Status: COMPLETE / ACCEPTED (2026-09-06).** Implemented, playtested across three sessions
(playground-only with the Relic hidden, objective-visible exploration, and a physical-gateway
chamber revision), and accepted by the Game Director as the M2 baseline. The geometry below is
the *implementation brief this was built from*; it does not reflect every hand-edit made during
playtesting or the connectivity fixes applied at close-out — those are recorded in
`docs/DECISIONS.md` (2026-09-06 entries, especially "M2 close-out") and verified in
`tools/arena_check.gd`, not re-authored back into this document. Treat the live scene
(`scenes/arena_01/arena_01.tscn`) plus the DECISIONS.md log as the source of truth for exact
current geometry; treat this file as the design reasoning behind it.

This document supersedes `docs/plans/M02_GREYBOX_ARENA.md` §§1–16 as the implementation brief
for Milestone 2. That document is retained for its **§17 Playtest 1 findings**, which are this
redesign's brief, and for its record of the V1 reasoning.

A future session should be able to build Arena 01 V2 from this file alone, without the
conversation that produced it.

---

## 0. Approval and amendments

Arena 01 V2 was approved as the new M2 direction by the Game Director on 2026-09-06, with
seven amendments. All seven are applied throughout this document; they are listed here so a
fresh session knows which parts of the design are settled decisions rather than proposals.

| # | Amendment | Where applied |
|---|---|---|
| **V2-A1** | **Keep `B_Under` for the first implementation**, explicitly as the **first deletion candidate** during human playtesting. Do not defend it if it feels fiddly, unnecessary, or harms readability. | §5, §10, §17, §20 |
| **V2-A2** | **Normal Relic access must not require precision momentum.** No objective entrance where walking versus running off the same edge determines success. Precision may exist later as *optional* skill shortcuts only. | **§9.2 — the vault's west entrance was redesigned and the bail-out gap removed**; enforced by new rule R8 (§15) |
| **V2-A3** | **Remove the ≥2× / ≥1.4× wrap advantage as a hard acceptance criterion.** Keep measuring and reporting wrap-route timing. The real criterion is **behavioural**: does the player intentionally choose wrapping for escape, chasing, flanking or repositioning? Human playtesting overrides the ratio. | §8.1, §15, §16 criterion 7, §17 Q9 |
| **V2-A4** | **Keep the current ladder spacing and climb duration** for the first V2 implementation. Do not redesign M2 around hypothetical Freeze balance. Record ladder vulnerability as an M4 power-balance consideration. | §7.2, §11, §20 R7 |
| **V2-A5** | **"The Gallery" is an internal working name only.** No further naming effort. | title, §18 |
| **V2-A6** | **Readability principle (new, explicit)** — the architecture may be sophisticated internally; the player's mental model must stay simple. | **§1.2**, §16 criterion 14 |
| **V2-A7** | **Preserve Playtest Session 1a exactly** — first V2 human test runs with the Relic placeholder **hidden**, controls only, one instruction. | **§17 Session 1a**, §16 criterion 12 |

---

## 1. Design thesis

### 1.1 The arena

**Arena 01 is a four-storey building with one continuous street, and it is cheap to fall but
expensive to climb.**

That single asymmetry is the design. Every platform drops to the floor in under a second.
Nothing climbs in under a second. Therefore:

- A chased player's escape is always **down and around**.
- A chaser's counter is always **predict where they land** — never "run faster".
- Height is a resource you spend, not a position you hold.

Remove the Relic entirely and what remains is a four-storey game of tag with **one wall that
severs the middle band**, forcing anyone who wants to cross it at height to go around the back
of the world through the seam. That is the playground test, and this arena is built to pass it
before it is built to deliver anyone to an objective.

The Relic sits at the top of that building **in a pit, not on a pedestal**. Reaching its band
is a climb. Entering the pit is a commitment. Leaving it is a different move from entering it.

**V1's error, recorded so it is not repeated:** V1 asked *"how does each player reach the Relic
differently?"* and answered it well — which is exactly why it produced a route diagram with four
entrances. V2 asks *"is this a good place for four people to be at once?"* and lets the Relic
inherit whatever that produces.

### 1.2 Readability principle (V2-A6) — binding

> **The arena architecture may be sophisticated internally, but the player's mental model must
> remain simple.**

A new player should perceive approximately:

- a floor
- lower platforms
- upper platforms
- a central protected area
- ladders
- a launcher
- wrapping

**They must not need to understand named route nodes or the route graph in order to play.**
Every node name in this document (`B_Under`, `C_Seam`, `A_W`…) is an implementation and
tooling label. None of it should be inferable, or need to be inferred, from playing.

This principle outranks route-graph sophistication, and it extends the existing decision
*"readability outranks route-graph complexity" (2026-09-06)*. Where they meet, the target
experience is **see → understand → choose → move**, never **study the level → understand the
graph → move**.

---

## 2. Schematic

1 char ≈ 40 px · 1920×1080 · y increases downward · **the left and right edges are the same place**

```
x:    0    240   480   720   960  1200  1440  1680  1920
      |     |     |     |     |     |     |     |     |

y200                    ▓▓▓
                      PIER TOP   (highest standing point in the arena)

y300              ████████▓▓▓            ██████████████
                    A_W  PIER                 A_E

y360                                  ▒▒▒
                                    VAULT_EAST (the two-way door)

y460                        ████████████
                        VAULT FLOOR + RELIC (x=1000)
                        ▲ pier's east face drops straight in

y560   ██████     ████████▓▓▓         ████████████   ░░  ██████
       B_SEAM      B_W    PIER          B_E         Lad  B_SEAM
      (wraps)   (dead-ends at the wall)              E   (wraps)
y580                          ██████
                            B_UNDER  (80px headroom, under the Relic)

y820  ██████ ▲ ░ █████████████████   ██████████    ████████████
      C_SEAM Pad│  C_W                  C_M          C_SEAM
      (wraps)  Lad                                    (wraps)
                W
y880                  ▄▄▄                 ▄▄▄
                    COVER W             COVER E

y960 ████████████████████████████████████████████████████████
                  FLOOR   (continuous, wraps, 1920 px of run)
```

**How to read it:** four bands, each covering a substantial part of the width, each broken in
2–3 deliberate places. The Crown (`y300`–`y460`) is **one continuous connected structure from
x=460 to x=1620 with zero horizontal gaps** — broken only by *height*: the pier step, the vault
pit, the threshold. That is the "visually connected architecture, strategically broken
traversal" the Playtest 1 brief asked for.

---

## 3. Geometry (Godot values)

Slab thickness 40 px unless stated. **Surface y = top of slab.** Positions are centres.
**Provisional — finalised by `tools/arena_check.gd` as implementation step 1 (§15).**

### Floor
| Node | Type | Position | Size | Note |
|---|---|---|---|---|
| `Floor` | StaticBody2D | (960, 1020) | 2120 × 120 | spans x −100…2020 — covers the seam strips without mirroring (R6) |
| `CoverW` | StaticBody2D | (690, 920) | 140 × 80 | x 620–760, an 80 px step-up block |
| `CoverE` | StaticBody2D | (1250, 920) | 140 × 80 | x 1180–1320, an 80 px step-up block |

### Band C — lower gallery (surface y = 820)
| Node | Position | Size | Span |
|---|---|---|---|
| `C_Seam` *(SeamMirror child)* | (1880, 840) | 600 × 40 | authored 1580–2180 → on-screen **1580–1920 and 0–260** |
| `C_W` | (650, 840) | 540 × 40 | x 380–920 |
| `C_M` | (1260, 840) | 360 × 40 | x 1080–1440 |

Gaps: **260–380** (120 px, the launch shaft) · **920–1080** (160) · **1440–1580** (140)
Coverage **78%**. Floor → Band C step-up = **140 px, comfortable, everywhere.**

### Band B — upper gallery (surface y = 560)
| Node | Position | Size | Span |
|---|---|---|---|
| `B_Seam` *(SeamMirror child)* | (1960, 580) | 360 × 40 | authored 1780–2140 → on-screen **1780–1920 and 0–220** |
| `B_W` | (600, 580) | 280 × 40 | x 460–740 |
| `Pier` | (780, 410) | 80 × 420 | x 740–820, **solid y 200–620** |
| `B_Under` | (1030, 600) | 140 × 40 | x 960–1100, **surface y = 580** |
| `B_E` | (1450, 580) | 340 × 40 | x 1280–1620 |

Gaps: **220–460** (240 px, *the arena's one tagged skill jump*) · the pier wall at 740–820 ·
**820–960** (140) · **1100–1280** (180) · **1620–1780** (160, the east ladder shaft)
Coverage **62.5%**. Band C → Band B = **260 px barrier** — ladders or the launcher only.

### Band A — the Crown, and the Vault
| Node | Position | Size | Span / note |
|---|---|---|---|
| `A_W` | (600, 320) | 280 × 40 | x 460–740, surface y = 300 |
| `Pier` | *(same node as above)* | | top surface **y = 200**; east face is the vault's west wall |
| `VaultFloor` | (1020, 480) | 400 × 40 | x 820–1220, **surface y = 460** |
| `VaultEast` | (1180, 400) | 80 × 100 | x 1140–1220, **top surface y = 360**, sits on `VaultFloor` |
| `A_E` | (1420, 320) | 400 × 40 | x 1220–1620, surface y = 300 |
| `RelicPlaceholder` | ColorRect (1000, 430) | 40 × 60 | x 980–1020, y 400–460. **No collision, no script, no state.** |

Band A voids: **x 0–460** and **x 1620–1920**. **Band A never crosses the seam** — 760 px of open
sky spans the seam at Crown height. You cannot wrap your way to the Relic.

### Traversal (all M1 scripts, unchanged)
| Node | Script | Position | Size | Function |
|---|---|---|---|---|
| `LadW` | `traversal_zone.gd` | (400, 515) | 60 × 610 | x 370–430, y 210→820. Band C → Crown, west. Mid-exit east onto `B_W`. |
| `LadE` | `traversal_zone.gd` | (1690, 515) | 80 × 610 | x 1650–1730, y 210→820. Band C → Crown, east. Mid-exit **left or right**. |
| `PadC` | `launch_pad.gd` | (310, 935) | 80 × 50 | x 270–350, on the **Floor**. `launch_direction = (0,-1)`. |

### Spawns (four territories)
| | Node | Position | Surface | Territory |
|---|---|---|---|---|
| P1 | `Spawn1` | (480, 532) | `B_W` | **top-left** |
| P2 | `Spawn2` | (1320, 532) | `B_E` | **top-right** |
| P3 | `Spawn3` | (500, 932) | Floor | **bottom-left** |
| P4 | `Spawn4` | (1440, 932) | Floor | **bottom-right** |

### Greybox palette
Retained from V1, plus two additions. This is a readability hierarchy, not decoration.

| Element | Colour | Why |
|---|---|---|
| Floor | `0.30` grey | as V1 |
| Platforms | `0.45` grey | as V1 |
| Seam-crossing (`C_Seam`, `B_Seam`) | `0.52` grey | as V1 — the wrap lane reads as its own thing |
| **`Pier`** | **`0.38` grey** | **new.** Darker and taller than any platform. Must read as *wall*, not *platform*, at a glance. |
| **`VaultFloor`, `VaultEast`** | **`0.58` grey** | **new.** Lighter than everything else. The chamber should read as a *room*. |
| Ladders | `(0.2, 0.6, 0.9, 0.4)` | as M1 |
| Launch pad | `(0.9, 0.7, 0.1)` | as M1 |
| Relic | `(0.85, 0.75, 0.25)` | as V1 |
| Player | red | as M1 |

---

## 4. Elevation ladder — why the numbers are these numbers

All derived from the accepted M1 constants: `max_speed 500`, `gravity 2200`,
`jump_strength 900` (**184 px rise, 409 px level reach, 0.818 s arc**),
`launch_strength 1500` (**511 px rise, apex 0.682 s**), `climb_speed 400`, body 36 × 56.

| From | To | Δ | Class |
|---|---|---|---|
| Floor 960 | Band C 820 | 140 px | **comfortable step** — the lower zone is one two-storey space |
| Band C 820 | Band B 560 | 260 | **barrier** |
| Band C 820 | `B_Under` 580 | 240 | **barrier** |
| Band B 560 | Band A 300 | 260 | **barrier** |
| `B_E` 560 | `VaultEast` 360 | 200 rise across a 60 px gap | **hard barrier** — mathematically unreachable |
| `B_Under` 580 | `VaultFloor` 460 | 120 rise, **80 px headroom** | **blocked by ceiling** — cannot jump (see rule R12) |
| `B_W` 560 | `Pier` top 200 | 360 | **barrier** — the wall that severs Band B |
| `A_W` 300 | `Pier` top 200 | 100 | comfortable step |
| `Pier` top 200 | `VaultFloor` 460 | 260 drop | **one-way in** (260 climb out = barrier) |
| `VaultFloor` 460 | `VaultEast` 360 | 100 | comfortable step, **no gap** |
| `VaultEast` 360 | `A_E` 300 | 60 | comfortable step, **no gap** |
| Floor 960 | `CoverW` / `CoverE` 880 | 80 | comfortable step |

**Nothing anywhere in the arena falls in the forbidden 151–199 px step band or the forbidden
301–420 px gap band.** That is machine-checked, not asserted (§15).

### 4.1 Comfort margins — the direct answer to `B1.5W`

V1's `B1.5W` was legal (45 px of margin) and felt bad in human hands. The cause was **not the
gap**. It was a **140 px landing platform** against a 36 px body with a ~36 px friction slide,
leaving roughly 50 px of usable standing room. V2's answer:

- Normal-route gaps are **≤ 180 px** against a 409 px reach — a **>2× margin**, versus V1's 240
  against 285.
- Normal-route landing platforms are **≥ 280 px wide**. The two narrowest platforms in the
  arena (`B_Under` and `CoverW`/`CoverE`, 140 px) are **not reached by a long jump** — both are
  reached by a short hop or a step-up.
- Exactly **one** jump in the arena exceeds 210 px: the **240 px `B_W` ↔ `B_Seam` crossing**,
  deliberately tagged as the arena's single named skill route, landing on a 360 px platform.
- A new checker rule (**R7**, §15) enforces minimum landing width *and* minimum landing window,
  so a `B1.5W`-class relationship fails at authoring time rather than in a playtest.

---

## 5. Major gameplay zones

Names in this table are **implementation labels**. Per §1.2 no player needs any of them.

| Zone | Where | Purpose |
|---|---|---|
| **The floor** | y 960, full 1920 px, wraps | The chase lane. 500 px/s unobstructed, two 80 px cover blocks. Everything falls here; nobody is ever stranded. This is the "proper floor" Playtest 1 asked for. |
| **Lower platforms** | Band C, y 820, 78% coverage | The floor's mezzanine. The 140 px step means floor + Band C read and play as **one two-storey lower zone ~250 px tall** — the interaction/chaos space. Three gaps keep it a chase surface rather than a corridor. |
| **Upper platforms** | Band B, y 560, 62.5% coverage | The contested middle. Home of both top territories. Severed by the pier, so it is a ring with one broken link. |
| **The wall** (`Pier`) | x 740–820, solid y 200–620 | The arena's one wall. Blocks Band B eastward. Its **top (y=200) is the highest standing point**, the only place you can see into the vault from outside it, and the west entrance to the vault. |
| **The Crown** | Band A, y 300 | The objective band. Two ways up. **Nobody spawns here.** |
| **The central protected area** | `VaultFloor` x 820–1220, y 460 | The Relic chamber. A pit with two doors of different kinds. |
| **`B_Under`** | y 580, x 960–1100 | A shelf with **80 px of headroom** directly under the Relic. You can walk it, you cannot jump in it, and you can see the Relic 120 px above you and not have it. Ambush pocket and the arena's "see it, can't reach it". **First deletion candidate (V2-A1).** |
| **The launch shaft** | x 260–380, floor → y 393 | The one full-height void in the arena, and the only place a vertical launch has a clear column. |
| **The seam** | x 0 / 1920 | Crossed solidly by the floor, by `C_Seam` (600 px) and by `B_Seam` (360 px). **Not crossed by Band A.** |

---

## 6. Four starting territories

**Starting territories, not rooms.** Every one has ≥3 immediate options and none is enclosed.

| | Territory | Spawn | Immediate options | Character |
|---|---|---|---|---|
| **P1** | top-left | `B_W` (480, 532) | ① 240 px skill jump west onto `B_Seam` ② drop 260 to `C_W` ③ run east and dead-end at the wall | **Boxed by the wall.** Must choose skill-west or drop-down. The most decision-forcing start. |
| **P2** | top-right | `B_E` (1320, 532) | ① east to `LadE`'s mid-station ② 160 px jump east onto `B_Seam` ③ west to `B_Under` ④ drop 260 to `C_M` | **The most connected start** — four exits and the most direct Crown access. Balanced by being the most predictable. |
| **P3** | bottom-left | Floor (500, 932) | ① west to `PadC` ② step up 140 onto `C_W` ③ run west through the seam ④ cover at `CoverW` | **Owns the launcher.** Fastest vertical escalation, but it lands you somewhere you must then choose. |
| **P4** | bottom-right | Floor (1440, 932) | ① step up 140 onto `C_M` ② east to `C_Seam` and `LadE`'s base ③ run east through the seam ④ cover at `CoverE` | **Owns the east ladder's base** and the widest seam-crossing platform. Slow but reliable. |

**Deliberately not mirrored.** P1's terrain (a wall to the east) and P2's terrain (four exits)
are genuinely different games; P3's launcher and P4's ladder are different tools. Fairness is
established by *measured route cost*, per the standing decision
*"route-cost measurement is diagnostic, not normative" (2026-09-06)*.

### 6.1 Spawn fairness reasoning

Hand-derived best-play time from each spawn to standing on the vault floor. **The checker
produces the authoritative numbers (§15).**

| | Best route | Est. |
|---|---|---|
| P1 | drop to `C_W` → west to `LadW` → climb 1.53 s → `A_W` → east 280 px → pier top → drop in | **≈3.2 s** |
| P2 | east to `LadE` mid-station → climb 0.88 s → `A_E` → west 400 px → `VaultEast` → step down | **≈3.2 s** |
| P3 | step up to `C_W` → west to `LadW` → climb 1.53 s → `A_W` → pier top → drop in | **≈3.2 s** |
| P4 | east to `C_Seam` → `LadE` → climb 1.53 s → `A_E` → west 400 px → step down | **≈3.2 s** |

Spread **≈2%**, comfortably inside the 15% diagnostic. Per the standing decision, if hitting
that number would ever cost a spawn its character, the checker **flags it and the arena is left
alone.**

What matters more than the clock: **no spawn reaches the vault without one gated vertical
transition and one horizontal commitment across open ground, and nobody starts on Band A.**

### 6.2 Six players — not designed, not foreclosed

The floor has 1920 px of continuous run; P5/P6 drop in at x≈900 and x≈1900 with no geometry
change. The binding constraint at six would be **Crown access**, which is why §7 flags the
reduction from three entrances to two as the thing to watch.

---

## 7. Connectivity

### 7.1 Horizontal — every band spans a substantial part of the width

| Band | Coverage | Longest continuous run | Deliberate breaks |
|---|---|---|---|
| **Floor** | 100% | **1920 px, wraps** | none (two 80 px steppable cover blocks) |
| **Band C** | 78% | **600 px** (`C_Seam`, crosses the seam) | 120 / 160 / 140 px gaps — all comfortable |
| **Band B** | 62.5% | 360 px (`B_Seam`) | **the wall (hard)**, plus 140 / 180 / 160 px gaps and one 240 px skill gap |
| **Band A** | 60% | **1160 px, x 460→1620, zero horizontal gaps** | none horizontally — broken only by *height* |

Band A is the direct answer to Playtest 1's *"more platforms connecting the left and right sides
specifically."* You can run from x=460 to x=1620 across the top of the arena without a single
jump — but doing so takes you over the wall and down into the vault, which is the point.

### 7.2 Vertical — two ways up to the Crown, and only two

| Route | Cost | Arrival property |
|---|---|---|
| **`LadW`** — Band C → Crown, west | **1.53 s** stationary climb (610 px) | Tops out on `A_W`, whose **only forward move is over the wall and one-way down into the vault.** Climbing it is a commitment. Mid-exit at Band B goes east onto `B_W` only. |
| **`LadE`** — Band C → Crown, east | **1.53 s** from Band C; **0.88 s** from the Band B mid-station | Tops out on `A_E`, which leads to the **two-way** east door. The safe, reversible, defensible side. Mid-station offers a **left-or-right** choice (`B_E` 30 px west, `B_Seam` 50 px east) — a decision point, not a corridor. |

**Two ways up to Band B:** the two ladders' mid-stations, and `PadC`.

**Downward is free everywhere.** Every surface can drop to the floor. No dead ends, no traps.

**The vault is the only connection between the Crown's west and east halves.** `A_W` and `A_E`
do not otherwise meet. That is what makes the pit the arena's crossroads rather than a cul-de-sac.

#### Recorded reduction: three approaches → two

V1's approved decision A1 specified *three structurally distinct approaches*. V2 delivers
**two Crown entrances and two vault doors**. This is a consequence of geometry, not neglect: a
**central** vault plus a **seam bridge at Band B** leaves only two full-height clear columns in
the frame, and every attempt to add a third either (a) put a launch arc into a platform's
underside — V1's exact failure — or (b) created a stepping ledge that also handed the top-right
spawn a ~1.8 s walk to the Relic.

**This is the single thing to watch in playtest.** If two entrances make the Crown feel like a
chokepoint rather than a contested space, the fix is to widen `B_Seam`'s east portion and add an
east stepping ledge, accepting the spawn rebalance that follows. It is not fixed pre-emptively.

### 7.3 The launcher — `PadC`

**Location:** on the **floor** at x=310, at the base of the launch shaft.
**Purpose:** *escape the bottom, dramatically, and choose your side at the top.*

Vertical only, per the standing decision *"vertical-only launch pads" (2026-09-06)*. Apex puts
the body top at **y ≈ 393** — just under the Crown, which the player can see and cannot reach.
From apex the player steers:

| Steer | Lands on | Landing window |
|---|---|---|
| **right** | `B_W` (x 492–740) | **248 px** |
| **left — across the seam** | `B_Seam` (x 1780–1920 ∪ 0–128) | **268 px** |

**What it deliberately is not:** it cannot reach Band A, it cannot reach the vault, and it is
not on anyone's required path. V1's launcher was *"the required precision solution to reach the
Relic"*; this one cannot be, by construction — its apex is 93 px below the Crown.

**Column clearance is structural:** x 260–380 is the one place where Band C, Band B and Band A
are *all* void. There is nothing to clip (R3).

---

## 8. Wrapping (V2-A3)

Wrapping is **connective tissue**, not the arena's organising principle. The whole arena is
deliberately *not* built around the seam. It earns its place in three concrete ways:

**1. The wall severs Band B, and the seam is the only way around it at height.**
`B_W` dead-ends east into a wall 360 px tall from its surface — unjumpable. To reach `B_E`
without losing height, the only route is west across the seam.

| Route | Cost |
|---|---|
| **Across the seam** — 240 skill jump → `B_Seam` → ~440 px run through the seam → 160 jump onto `B_E` | **≈1.85 s, height preserved** |
| Around the inside — drop 260 to `C_W`, run ~1200 px east, climb `LadE` 350 px to the mid-station | **≈3.6 s, height lost and regained** |

Roughly **1.95×**, and — more importantly — the inside route dumps you into the chase lane where
everyone can see and reach you.

**2. The launcher throws you across the seam.** Steering left off `PadC` is a deliberate,
rewarding, slightly hidden move that lands you on the seam bridge.

**3. `C_Seam` is the widest platform above the floor** (600 px) and it crosses the seam, so
escape, chase and flanking at lower-gallery height work naturally in both directions. The floor
wraps continuously beneath it.

**Band A deliberately does not cross the seam.** 760 px of open sky spans the seam at Crown
height. **You cannot wrap your way to the Relic.**

**Hard rule, retained from V1:** no hazard within 200 px of the seam, ever.

### 8.1 Success criterion for wrapping (V2-A3) — behavioural, not numerical

The ≥2× / ≥1.4× ratio is **removed as a hard acceptance criterion.** Route timing continues to
be **measured and reported** by `arena_check` (§15) as a diagnostic.

> **The success criterion is: during play, does the player intentionally choose wrapping for
> escape, chasing, flanking or repositioning?**

Human playtesting overrides the ratio in both directions — a good ratio with no observed use is
a failure; observed intentional use with a poor ratio is a success.

---

## 9. The Relic chamber (spatial placeholder only)

### 9.1 Shape

A **pit**, not a pedestal. Floor at y=460 spanning x 820–1220 (400 px), roofless, walled west by
the pier (a 260 px drop) and stepped east by `VaultEast`. The Relic marker sits at **x = 1000**,
40 px right of mathematical centre — it reads as the arena's focal point, is the highest-contrast
object on screen, and has 460 px of clear sky above it. Terrain asymmetry, not Relic offset, is
what breaks the arena's symmetry in V2.

**Placeholder only:** a 40 × 60 ColorRect. No collision, no script, no state, no behaviour, no
countdown, no unlock, no win condition. It exists to occupy space and be looked at.

### 9.2 Two doors, two different kinds — both forgiving (V2-A2)

| Door | How | Direction | Precision required |
|---|---|---|---|
| **The wall drop** (west) | `A_W` → step up 100 onto the pier top → walk east off its edge → **slide down the pier's east face and land on the vault floor** | **one-way in** (260 px climb out is a barrier) | **None.** |
| **The east door** | `A_E` → step down 60 onto `VaultEast` → step down 100 onto the vault floor | **two-way** | **None.** |

**How V2-A2 was satisfied — this is the material change from the proposal.**

The reviewed proposal had a 100 px shaft between the pier and the vault floor, so *walking* off
the pier dropped you to Band C while *running* off it landed you in the vault. That is exactly
the walk-versus-run failure the Director rejected. Two changes fix it:

1. **The vault floor now abuts the pier at x=820.** The pier's east face (solid from y=200 to
   y=620) is the vault's west wall. A player stepping off the pier top with **zero horizontal
   velocity** slides down that face and lands on the vault floor at x≈838. There is no gap to
   miss and no speed threshold. Arriving with speed simply lands you further east.
2. **The bail-out gap was removed** and `VaultEast` became a solid 100 px block sitting *on* the
   vault floor rather than a platform across a gap. Both directions of the east door are now pure
   step-ups and step-downs with **no gap at any point**.

**Consequence, recorded honestly:** the vault now has no third, downward exit. It is still not a
trap — the east door is always available and reachable by the player's own movement (rule R9) —
but a camper holding `A_E` at M4 could pressure the only two-way door. That is the same
**camping** concern already deferred to M3 by V1 §7, and it is a deliberate trade: **a forgiving
primary entrance outranks a third escape hatch.**

Optional precision shortcuts may be added later, per V2-A2, but not on any normal route.

### 9.3 Why it is not trivially reachable

Reaching the *pit* requires reaching the *Crown*, and the Crown has exactly two entrances, both
slow and both fully visible: two **1.53 s stationary ladder climbs** (0.88 s from a Band B
mid-station).

The pit **cannot be entered from Band B at all**:

- **West** — the pier is solid from y=200 to y=620. There is no way past it at Band B height.
- **Centre** — `B_Under` has 80 px of headroom under the vault floor. A player there can stand
  and walk but physically cannot jump (rule R12).
- **East** — `B_E` → `VaultEast` is a **200 px rise across a 60 px gap**: mathematically
  unreachable at any speed, not merely difficult.

Best-play spawn-to-Relic is ≈3.2 s, comparable to V1's 2.6 s fast route — but the structure
differs in kind: **four elevation transitions, three of them gated**, versus V1's three jumps and
a launch. The clock is not the protection; the gates are.

### 9.4 "See it, can't reach it"

`B_Under` sits 120 px below the Relic with 80 px of headroom. The Band C gap at 920–1080 is
directly beneath the vault. `PadC`'s apex tops out 93 px below the Crown. Three separate places
where the objective is visible and unreachable.

---

## 10. Future combat / interference map

**Nothing here is implemented in M2.** This section exists so that the geometry justifies itself
against the Push / Freeze / Teleport / Shield set planned for M4 — the arena is designed with
their interactions in mind, per §17.3 of the Playtest 1 brief.

### Duel zones — room for two players to confront and dodge

| Space | Width | Why |
|---|---|---|
| **The floor** | 1920 px, wraps | Unbounded horizontally. Two 80 px cover blocks break line of sight and give a dodge-behind. The only space where a fight can go on indefinitely. |
| `C_Seam` | 600 px, crosses the seam | Widest elevated platform. A duel here can **leave through the seam** — retreat is never cut off. |
| `C_W` | 540 px | Where players who drop off the Crown's west side land. |
| `A_E` | 400 px | The Crown's antechamber. Whoever holds it holds the east door. |
| `B_E` | 340 px | Top-right's home ground. |

### Interception points — where you can predict someone

| Point | Why |
|---|---|
| **`LadW` / `LadE` tops (y=210)** | A climber is stationary, fully visible for **1.53 s**, and can emerge in only one place. The strongest interception geometry in the arena. |
| **`LadE`'s mid-station** | The left-or-right choice is visible; guessing wrong costs the interceptor, not the climber. |
| **The east door (`VaultEast`, 80 px)** | The only two-way vault entrance. Everything funnels here. |
| **The pier top** | You see who is about to drop into the vault before they do. |
| **`PadC`'s apex** | A launched player's arc is a fixed public parabola — committed and steering-limited for ~0.9 s. |
| **The 240 px skill jump** (`B_W` ↔ `B_Seam`) | Long, slow, and the only height-preserving way past the wall. |

### Push / drop opportunities

| Spot | Cost of being pushed |
|---|---|
| **The pier top** (y=200) | Either into the vault (which *helps* your target) or west back onto `A_W`. Genuinely funny; low malice. |
| **`A_E`'s west edge** (x 1220) | Falls 200+ px past `B_E` to `B_Under` or the floor. Loses the whole Crown. |
| **`VaultEast`** | A push west drops the target into the pit; a push east puts them back on `A_E`. The most consequential 80 px in the arena. |
| **Band B's gaps** (140–180 px) | Short falls, cheap punishment — annoying, not devastating. |
| **`B_Seam`, mid-air over the seam** | The target reappears on the other side. Comedic, disorienting, harmless. |
| **Mid-climb on either ladder** | See §11 — recorded as an M4 balance consideration, deliberately **not** designed around (V2-A4). |

**No drop in M2 is fatal.** Every fall lands on a surface.

### Escape paths — a chased player always has ≥2 options

| From | Options |
|---|---|
| Crown / vault | east door → `A_E` → `LadE` down · the pier top → the pit · drop off `A_E`'s west edge |
| Band B | drop to Band C / floor (always) · the seam in either direction · `B_Under` (a place a chaser must commit to enter) |
| Band C | three gaps to jump · the seam via `C_Seam` · drop to the floor anywhere |
| Floor | 1920 px of continuous run in both directions, forever · `PadC` · step up onto Band C anywhere |

The one place with a single lateral exit is **`B_Under`** — 140 px, 80 px of headroom, too low to
jump in. That is intentional: the arena's one genuine risk pocket, directly under the Relic,
small enough to read as a hiding place rather than a trap. It is also the **first deletion
candidate (V2-A1)**.

### Likely crossfire areas — where different territories meet

1. **The Band C gap at 920–1080**, directly under the vault: P1/P3 arrive from `C_W`, P2/P4 from `C_M`. The busiest spot in the arena.
2. **The floor around x≈960**, between both cover blocks.
3. **`B_Seam` and its approaches**: P1 by skill jump from the west, P2 by a short jump from the east, P3 by launcher from below. Three territories converge on one 360 px platform.
4. **`A_E`**: the east ladder and the east door both feed it.
5. **`B_Under`**: whoever hides there is 120 px under whoever is taking the Relic.

### High ground that is not permanently dominant

The **pier top** (y=200) is the highest standing point and overlooks the vault. It is also a
**one-way perch**: every exit from it is downward, into the pit or back west onto `A_W`. You can
watch from it; you cannot rule from it. That is the intended shape of high ground in Rushlings.

---

## 11. Future positions — marked only, not implemented

### Power pickups (M4)

One per route identity, so choosing a route also chooses a power access pattern.

| Marker | Position | Why there |
|---|---|---|
| `PickupCandidate1` | Floor, (960, 932) | Maximum exposure, maximum detour. The greedy-but-stupid pickup. |
| `PickupCandidate2` | `B_Under`, (1030, 552) | Directly under the Relic. Makes the ambush pocket pay. |
| `PickupCandidate3` | `B_Seam`, (1850, 532) | Rewards committing to the seam. |
| `PickupCandidate4` | `C_M`, (1260, 792) | Bottom-right's natural first stop. |
| `PickupCandidate5` | Pier top, (780, 172) | High risk, total visibility, adjacent to the one-way vault entrance. |

### Hazards (M3/M4)

| Marker | Position | Why |
|---|---|---|
| `HazardCandidate1` | Floor strip x 920–1080 | Under the Band C central gap — makes falling from the middle cost something. |
| `HazardCandidate2` | Floor strip x 420–560 | Under the Band C west gap. |

**No hazard within 200 px of the seam. No hazard under a ladder base or the launch pad.**

### Ladder vulnerability — recorded for M4, not designed around (V2-A4)

A Freeze landing on a player mid-climb is a **1.53 s** sentence, the longest forced-immobility
window the arena can produce. This is recorded as an **M4 power-balance consideration**.

**Ladder spacing and climb duration are unchanged for the first V2 implementation.** M2 is not
redesigned around a hypothetical balance problem in an unimplemented power. If M4 shows this is
genuinely unfair, the candidate fixes are on the *power* side (cap Freeze duration, or make
climbing interruptible) before they are on the arena side.

### Portals — deliberately none

Unchanged from the standing decision *"no portals in Arena 01" (2026-09-06)*. Every candidate
portal function is already covered: lateral repositioning by wrapping, vertical-layer skipping by
`PadC`, unexpected arrival by crossing the seam. The only distinct remaining function is
bidirectional teleport between arbitrary points, and the **M4 Teleport power is planned to use
paired-portal logic** — arena portals now would blur that reading.

---

## 12. Disposition of Arena 01 V1

### Delete

All V1 geometry: `B1W`, `B1E`, `B15W`, `B2W`, `B2E`, `B3W`, `B3E`, `B3S`, the `Shrine` deck,
`PadH`, both V1 ladder placements, all four V1 spawn positions, all V1 pickup and hazard markers.
The "Seam Ring" name and the three-approaches framing go with them.

**Deleted rather than fixed, deliberately:**

- **`B1.5W`** — the platform Playtest 1 called unnecessarily difficult. Replaced by a rule (R7)
  that would have caught it at authoring time.
- **The `PadH` launch route and its geometry conflict.** Per the redesign brief the conflict is
  **not patched**; the element it belonged to no longer exists.

### Retain unchanged

| Asset | Note |
|---|---|
| `scripts/player.gd` and every M1 tuning value | **Hard constraint. Zero changes.** |
| `scripts/arena_wrap.gd` | Unchanged. |
| `scripts/traversal_zone.gd`, `scripts/launch_pad.gd` | Unchanged. |
| `scripts/seam_mirror.gd` | Unchanged — now serves **two** seam-crossing platforms (`C_Seam`, `B_Seam`) instead of one. `Floor` covers the seam strips by extent, as in V1. |
| `scripts/arena_01.gd` | Retained. The four-spawn debug cycle is still exactly the right tool. |
| `scripts/debug_hud.gd`, `scenes/player/player.tscn` | Unchanged. |
| Greybox palette | Reused, plus two additions (§3). |
| `scenes/movement_lab/` | Stays as the M1 regression harness. |

### Repurpose

- **`tools/arena_check.gd`** — the harness, geometry extraction, input simulation and reporting
  all survive. Only the rule thresholds, the edge list and the route phases are rewritten. This
  is exactly why it was made a permanent committed tool.
- **The R1–R6 rule set** — kept and tightened (§15).
- **Every V1 decision in `docs/DECISIONS.md`** remains valid: height-not-distance,
  diagnostic-not-normative, readability-over-complexity, no portals, vertical-only pads,
  unprompted first contact. **V2 changes the arena, not the principles.**

---

## 13. How V2 addresses each Playtest 1 finding

Against `docs/plans/M02_GREYBOX_ARENA.md` §17.

| §17.2 problem | V2's answer |
|---|---|
| **Arena feels too sparse** | Band coverage is now **100% / 78% / 62.5% / 60%** across four bands, with a 1160 px unbroken run across the Crown and a 1920 px unbroken floor. |
| **Too much empty / non-playable space** | Negative space is now *between* layers (~220 px per band, ~4 character heights) rather than *instead of* geometry. The two largest voids are deliberate and load-bearing: the launch shaft (the pad's only clear column) and the 760 px of sky spanning the seam at Crown height (which is what stops wrap-to-Relic). |
| **Reads as isolated floating platforms, not one arena** | The Crown is one continuous connected structure 1160 px wide with **zero** horizontal gaps. `C_Seam` runs 600 px continuous through the seam. Floor + Band C read and play as a single two-storey lower zone because the step between them is a comfortable 140 px. |
| **Too focused on route-to-Relic optimisation** | The design was derived from the playground test first. §10 (combat/interference) exists before the Relic has any behaviour at all. The Relic inherits the arena; it did not generate it. |
| **Relic feels too quickly / directly reachable** | Four elevation transitions, three gated. The pit **cannot be entered from Band B at all** — the wall seals it west, `B_Under` has 80 px of headroom, and `B_E` → `VaultEast` is a mathematically unreachable 200 px rise. Two Crown entrances, both 1.53 s stationary climbs. |
| **No space for four players to chase, fight, interfere** | §10: five duel zones ≥340 px, six named interception points, six push/drop spots, ≥2 escape options from every position, five crossfire areas. The floor alone is an unbounded 1920 px chase lane. |
| **Spawns don't communicate four territories** | §6 — explicit top-left / top-right / bottom-left / bottom-right on `B_W`, `B_E`, floor-west, floor-east, each with a different tool (a wall, four exits, the launcher, the ladder base) and ≥3 immediate options. Nobody spawns on the objective band. |
| **`B1.5W` reachable but slippery / difficult** | Deleted. Replaced by rule **R7** (minimum landing width and minimum landing window), sized against the 36 px body plus its ~36 px friction slide. |
| **Launch route geometry conflict** | Not patched — deleted with its route. The new pad sits in the one full-height void in the arena and **cannot reach the objective band by construction.** |

| §17.3 requirement | Where |
|---|---|
| Fun without the Relic | §1.1 thesis; tested directly by Playtest Session 1a (§17). |
| Designed for future power interaction | §10. |
| Four territories, TL / TR / BL / BR | §6. |
| Meaningful continuous lower floor | §5 — floor + Band C, 140 px apart, one zone. |
| Stronger horizontal connectivity on upper layers | §7.1 — Crown 1160 px unbroken. |
| Intentional gaps / choke points | The wall (hard), the east door (80 px), `B_Under` (80 px headroom), the 240 px skill jump, both ladder tops. |
| More structurally protected Relic chamber | §9 — a pit, unreachable from Band B, behind two slow Crown entrances. |
| Left-to-right platform chains, not only the ground or one upper ring | Crown 1160 px continuous; Band C 78%; Band B a ring with one severed link. |
| No portals · no powers · no M1 changes | §11, §18. |

---

## 14. Scene / node / script architecture

Unchanged in shape from V1 §9.1 — only the geometry inside it changes.

```
scenes/arena_01/arena_01.tscn
  Arena01 (Node2D)                    ← scripts/arena_01.gd            [REUSED]
    ArenaWrap (Node2D)                ← scripts/arena_wrap.gd          [REUSED unchanged]
    Camera2D                            position (960,540), static
    Geometry (Node2D)
      Floor, CoverW, CoverE
      C_W, C_M
      B_W, Pier, B_Under, B_E
      A_W, VaultFloor, VaultEast, A_E
      SeamMirror (Node2D)             ← scripts/seam_mirror.gd         [REUSED unchanged]
        C_Seam, B_Seam                  duplicated at ±1920 on _ready
    Traversal (Node2D)
      LadW, LadE                      ← scripts/traversal_zone.gd      [REUSED unchanged]
      PadC                            ← scripts/launch_pad.gd          [REUSED unchanged]
    Markers (Node2D)                    Marker2D only, zero behaviour
      Spawn1..Spawn4
      PickupCandidate1..5, HazardCandidate1..2
    RelicPlaceholder (ColorRect)        no collision, no script
    Player (instance)                 ← scenes/player/player.tscn      [REUSED unchanged]
    HUD (CanvasLayer) → DebugLabel    ← scripts/debug_hud.gd           [REUSED unchanged]
```

**No new scripts are required.** V2 reuses every script V1 produced.

`project.godot` → `run/main_scene = res://scenes/arena_01/arena_01.tscn`. The Movement Lab stays
intact and runnable as the M1 regression harness. `main.tscn` stays an empty placeholder; M3
decides its fate.

**Hard constraint, restated:** `player.gd`, `arena_wrap.gd`, `traversal_zone.gd`,
`launch_pad.gd` and every M1 tuning value are unchanged. **If the arena needs a movement change
to work, the arena is wrong, not the movement.**

---

## 15. Automated checks

`tools/arena_check.gd` remains a **permanent committed regression tool**. Its harness survives;
its rules change. Run headless: `godot --headless --script tools/arena_check.gd`

### Tightened rules

| Rule | V1 | V2 |
|---|---|---|
| **R1** step-up | ≤150 ok · 155–184 forbidden · ≥200 barrier · 151–154 and 185–199 merely warned | ≤150 ok · **151–199 forbidden** · ≥200 barrier — closes the "undefined band" V1 only warned about |
| **R2** level gap | ≤280 ok · 281–420 forbidden · >420 barrier | **rise-aware.** Compute the ballistic reach for the edge's actual rise, then: ≤210 px comfortable · **211–300 px skill (only on edges explicitly tagged `skill_route`)** · 301–420 forbidden · >420 or beyond ballistic reach = barrier |

### New rules

| Rule | Enforces | Why |
|---|---|---|
| **R7 — landing quality** | Every jump edge must land on a platform **≥280 px wide** (≥140 for a tagged skill route) **and** have a **landing window ≥120 px**, both computed from the ballistic arc for that edge's gap and rise. | The direct fix for `B1.5W`. "Mathematically reachable" is not sufficient — the body is 36 px wide and slides ~36 px on landing. |
| **R8 — forgiving objective access (V2-A2)** | Every entrance on a **normal** route to the Relic must succeed from a **standing start (zero horizontal velocity)**. Any entrance that requires horizontal speed must be explicitly tagged `skill_route` and must not be a normal objective entrance. | Encodes amendment V2-A2 so it cannot silently regress. Both vault doors must pass this at zero velocity. |
| **R9 — no trap volumes** | Every enclosed region (the vault, `B_Under`) must have **≥1 exit provable by simulation** using only the player's own movement. | The vault is the first genuinely enclosed space in a Rushlings arena. |
| **R12 — ceiling clearance** | Where a platform sits above a walkable surface, report the headroom. If headroom < **240 px** (184 px jump rise + 56 px body), any step-up above that surface is physically blocked and must **not** be classified as comfortable. | Without this, `B_Under` → `VaultFloor` would be reported as a comfortable 120 px step-up when it is in fact impossible. A false PASS is worse than a FAIL. |

### New diagnostics (report only — never pass/fail, never authorise geometry changes)

| # | Reports | Why |
|---|---|---|
| **R10 — band continuity** | Each band's horizontal coverage %, longest continuous run, and full gap list. | Turns *"does it feel like one arena?"* into a number readable before playing. Directly answers §17.2. |
| **R11 — territory report** | Pairwise spawn distances, each spawn's nearest vertical connector, and each spawn's count of immediate options. | Makes the four-territory claim falsifiable. |
| **Time-to-first-contact** | For each spawn pair, the minimum time until they can occupy a shared platform. | **The four-player-interaction metric this redesign is actually optimising.** V1 never measured it. |
| **Wrap-route timing (V2-A3)** | The seam route versus its best alternative for the `B_W` → `B_E` crossing, in seconds and as a ratio, **with no threshold attached**. | Amendment V2-A3: measured and reported, never a gate. Behaviour in playtest is the criterion. |

### Changed measurements

- **Route proofs** — replace V1's Approaches A/B/C with: both Crown entrances, both vault doors
  (each proven **from a standing start**, per R8), the 240 px skill jump, and the launcher's
  **left and right** landings.
- **Route-cost table** — retained (4 spawns → vault; spread reported, >15% **flagged not
  corrected**).
- **Wrap integrity** — extended from one seam platform to two (`C_Seam`, `B_Seam`) plus the
  floor, in both directions, at every band that crosses the seam.

---

## 16. Acceptance criteria

| # | Criterion | Verified by |
|---|---|---|
| 1 | Entire arena visible in one fixed 1920×1080 frame; camera never moves | Visual + scene inspection |
| 2 | The 36×56 player stays readable against all geometry | Playtest |
| 3 | All four spawns have a proven route to the vault floor | `arena_check` route proofs |
| 4 | Spawn-to-objective spread reported; **>15% flagged, not auto-corrected** | `arena_check` |
| 5 | **Both vault doors succeed from a standing start** (V2-A2) | `arena_check` R8 |
| 6 | **No dead ends** — every position can return to the floor; the vault has a provable exit | `arena_check` R9 |
| 7 | **Wrapping is intentionally chosen by the player** for escape, chasing, flanking or repositioning. Timing is reported but is **not** a threshold (V2-A3) | **Playtest observation** + `arena_check` diagnostic |
| 8 | **Zero R1–R2, R7–R9, R12 violations** — no impossible, ambiguous, or falsely-comfortable geometry | `arena_check` |
| 9 | **No changes to M1 movement scripts or tuning values** | `git diff` |
| 10 | Band continuity and territory diagnostics produced and reviewed | `arena_check` R10, R11 |
| 11 | Godot MCP run produces no errors introduced by M2 | MCP debug output |
| 12 | **The arena is enjoyable to move around with the Relic hidden** (§1.1 thesis) | **Playtest Session 1a** |
| 13 | Relic reads as the arena's objective on sight, without explanation | Playtest Session 1b Q2 |
| 14 | **Player's mental model stays simple** — floor / lower / upper / central protected area / ladders / launcher / wrapping, with no need for route-node names (V2-A6) | Playtest Session 1b Q3, Q6, Q7 |
| 15 | Routes feel meaningfully different | Playtest Session 2 |
| 16 | Relic not reachable by one trivial straight line | §9 + playtest |
| 17 | Director accepts navigation and route legibility | Playtest |

---

## 17. Human playtest procedure

### Session 1a — The playground test (V2-A7) — **first, and alone**

**Run the arena with the `RelicPlaceholder` hidden.** Tell the Director **only the controls**
and this exact instruction:

> **"Move around this arena for three minutes."**

**Say nothing** about routes, zones, the wall, the seam, the launcher, or any intended strategy.

Afterwards, ask:

1. What did you naturally discover?
2. **Was moving through the arena itself enjoyable?**
3. Were there places you wanted to go back to?
4. Where would you go to escape someone chasing you?
5. Where would you wait to ambush someone?
6. Did the bottom feel like a floor you would fight on?
7. Did any area feel like a corridor with nothing to decide?

**If the honest answer to Q2 is "not really", the redesign has failed and no amount of Relic
tuning fixes it.** That is why the question is asked before the objective is ever shown.

**Only after this session is complete and its answers are recorded** should the Relic placeholder
be made visible.

### Session 1b — Unprompted exploration with the Relic visible

Relic shown. Instruction: *"Explore the arena and try to reach the Relic."* Say nothing about
the wall, the seam, the ladders or the launcher's left turn. Then ask the seven V1 questions:

1. Which route did you discover first?
2. Did you understand where the Relic was?
3. Did the arena feel like one connected place?
4. Did you naturally discover wrapping as navigation?
5. Was anything visually reachable but physically unreachable?
6. Did you get stuck?
7. Which areas felt unnecessary or confusing?

Plus three V2 questions:

8. Did you work out that the wall blocks the middle, and what did you do about it?
9. **Did you ever choose to wrap on purpose — to escape, chase, flank or reposition?** *(This is acceptance criterion 7. V2-A3.)*
10. **Which platform would you delete?**

Q10 is deliberately blunt. Under the readability principle, a named platform is a **candidate for
deletion, not for defence**. `B_Under` is the standing first candidate (V2-A1) and **must not be
defended** if it feels fiddly, unnecessary, or harms readability.

### Session 2 — Deliberate route validation

Only after Sessions 1a and 1b. Walk both Crown entrances, both vault doors **from a standing
start**, the 240 px skill jump, and the launcher's left landing across the seam. Confirm each is
achievable by a human and not only by the checker.

### Session 3 — Four-player readability proxy (optional)

Three static coloured rectangles at the other three spawns: *"at a glance — who is where, and
where are they heading?"* Then a second reading with the proxies at mid-game positions (the pier
top, `B_Under`, `C_Seam`) to test the harder case. Zero code, zero physics, no scripts.

---

## 18. Explicitly out of scope for M2

Bots · powers · projectiles/shooting · **functional Relic** (no countdown, unlock, collection or
win state) · match timer / game loop · respawn · **implemented** hazards (positions marked only) ·
**implemented** pickups (positions marked only) · portals · mobile/touch controls · production UI
or HUD beyond the M1 debug label · art · animation · VFX · audio · networking/backend · more than
one player instance (static proxy rectangles for the readability test are not players) · **any
change to M1 movement scripts or tuning values** · six-player gameplay · angled launch pads ·
**further naming effort (V2-A5)**.

---

## 19. Implementation order for the next session

1. **Update `tools/arena_check.gd` first** — tighten R1/R2, add R7, R8, R9, R12, and the R10/R11
   diagnostics — **before** any geometry, so violations are caught at authoring time.
2. Rebuild `scenes/arena_01/arena_01.tscn` geometry per §3, running the static audit as it is
   built. Delete all V1 geometry rather than editing it.
3. Update spawn and candidate markers per §3 and §11.
4. Update the route proofs, cost table, wrap diagnostics and time-to-first-contact (§15).
5. MCP run; confirm no errors introduced.
6. **Stop. Hand to the Director for Playtest Session 1a with the Relic placeholder hidden (§17).**

Estimated: one session for the checker and geometry, one for tuning and the playtest.

---

## 20. Risks

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| R1 | **Two Crown entrances feel like a chokepoint** rather than a contested space (§7.2). | **High** | The single thing to watch in playtest. Named fix documented in §7.2; not applied pre-emptively. |
| R2 | **`B_Under` feels fiddly or unnecessary.** | **High** | V2-A1: first deletion candidate. Playtest Q10. **Do not defend it.** |
| R3 | **Seam-crossing collision holes** — a body between x=1920 and 1960 is off-screen and still needs floor. | **High** | `seam_mirror.gd` makes it structural for `C_Seam`/`B_Seam`; `Floor` covers the strips by extent. Verified by the wrap-integrity check. |
| R4 | **Ladder terminating under solid geometry** — M1 hit this exactly. | **High** | Rule R4 + checker. Both ladder columns must be verified clear from y=820 to y=210. |
| R5 | **The vault has only one two-way door**, so a camper can pressure it at M4. | Medium | Accepted trade for V2-A2. Same camping concern already deferred to M3. |
| R6 | **Arena still feels crowded or graph-like.** | Medium | §1.2 readability principle governs: simplify or delete geometry. Playtest Q3/Q7/Q10 is the trigger. |
| R7 | **Freeze on a ladder is a 1.53 s sentence.** | Medium | V2-A4: recorded as an **M4** power-balance consideration. Ladder spacing unchanged for V2. |
| R8 | **Off-screen moment at the seam × 4 players.** | Medium | Playtest Session 1b Q4/Q9 and Session 3. If it fails it is a *wrapping* decision to revisit, not an arena one. |
| R9 | **The 240 px skill jump feels bad** despite passing R7. | Low | It is the arena's only skill jump and has a documented safe alternative (drop and go around). Tune or delete in Phase E. |
| R10 | **Scope creep into M3** (Relic behaviour, timer, win state). | Low | Hard boundary in §18. |

---

## 21. What was deliberately not added

| Not added | Why |
|---|---|
| **Portals** | Standing decision, and the M4 Teleport power is planned to use paired-portal logic. |
| **A walkable roof over the vault** | Designed and cut twice now. It makes high ground dominant (drop straight in from above), consumes the HUD band, and needs a launcher strong enough to also break "entire arena visible". The pier top gives the overlook without giving the entrance. |
| **A third Crown entrance** | Every candidate either put a launch arc into a platform's underside (V1's exact failure) or handed the top-right spawn a ~1.8 s walk to the Relic. Recorded openly in §7.2 as the thing to watch rather than solved with geometry that does not work. |
| **A bail-out shaft out of the vault** | It reintroduced the walk-versus-run ambiguity on the east door. Removed to satisfy V2-A2. §9.2. |
| **A second launcher, or angled launchers** | One launcher with one clear purpose reads better than two with fuzzy ones. Angled pads remain a *movement* question, not an arena one. |
| **A ladder or lift into the vault from below** | It would collapse the four-transition climb into two and make the Relic a Band-B destination. |
| **Hazards, pits, spikes, moving platforms, one-way platforms, breakable geometry** | Positions marked, nothing implemented. M2 is a navigation milestone. |
| **Mirrored geometry for spawn fairness** | Fairness comes from measured route cost. P1 has a wall; P2 has four exits. They are not the same start and should not be. |
| **More than one height step per band** | Only `B_Under` (580) departs from its band line. Clean band lines are what let a player parse four storeys at a glance on a phone (§1.2). |
| **Any Relic behaviour** | No countdown, unlock, collection, win state or timer. M3. |
| **Any change to M1 movement or tuning** | Hard constraint. |
| **Filling the frame** | ~55% of the screen is still open air. Four players, future projectiles and a later art pass all need it. More connected does not mean more dense. |
