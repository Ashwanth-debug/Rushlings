# M3 — Core Game Loop

**Status: M3-1 COMPLETE / ACCEPTED (2026-09-09). M3-2 COMPLETE / ACCEPTED (2026-09-12). MILESTONE 3 — CORE GAME LOOP: COMPLETE.**
Approved by the Game Director in the M3 planning/audit session, with ten amendments (§0).
See **§0.5 M3-1 status and playtest log** for what has actually happened since approval —
this section supersedes the original plan's assumptions wherever a playtest or an
implementation finding has since overridden them, but the original plan text below is kept
intact as the historical record of what was approved and why. **§0.6 records the acceptance
close-out.** The hard approval gate at §10.5 held throughout: nothing in Part Two (§11 onward,
M3-2) was implemented before acceptance, and none of it is implemented by this close-out either.

---

## 0.5 M3-1 status and playtest log (2026-09-06 – 2026-09-08, historical)

**Status at the time this section was written: NOT accepted. Superseded by §0.6 below — M3-1 is
now ACCEPTED. Kept intact as the historical record of the diagnostic path that led there.**

Multiple human-playtest → automated-fix → re-playtest iterations have happened since the
plan below was approved. This section records what changed and what is still open, without
rewriting the original plan (§0–§10) — read both.

### Confirmed findings (durable — see docs/DECISIONS.md for the dated decision entries)

- **Four simultaneous players are fun.** Arena 01 feels substantially more alive with four
  active bodies than the M2 one-player exploration sessions suggested. This is the single
  most important M3-1 signal so far.
- **1.0× is the current preferred four-player baseline**, not 1.25×. The 1.25× tempo felt
  exciting in solo M2-era debug playback, but with four bodies simultaneously active it reads
  as somewhat fast-forwarded rather than exciting. `Engine.time_scale` stays the mechanism for
  any future A/B — no M1 movement constant has been touched.
- **Player↔player collision OFF remains the M3-1 baseline**, confirmed via dedicated
  layer/mask tests (both the "pass through, still collide with world" and "physically
  separate when ON" states) and via playtest. The dev toggle stays available.
- **Navigation philosophy changed**: reliable navigation now matters more than giving bots
  access to every theoretically possible human traversal. Ordinary bot pathfinding (both
  NORMAL ROAM and NAV STRESS) now uses a **RELIABLE vs SKILL/HUMAN-OPTIONAL** edge
  classification — SKILL edges are excluded from ordinary bot routing entirely, not kept as a
  penalized fallback (an earlier "heavy penalty, still usable" version was tried and
  explicitly rejected — it let bots keep selecting moves already known to fail
  inconsistently). A bot whose target requires a SKILL-only edge fails/re-paths rather than
  attempting it. Human players are unaffected — SKILL edges remain real, legal M1 traversal,
  just not ones the bot AI is expected to rely on for M3-1.
- **`CoverW` was removed from Arena 01.** Human playtesting showed multiple bots repeatedly
  converging on and visibly failing around it; automated analysis confirmed it was not
  required for arena connectivity and its removal disconnects no required macro-region. This
  is a level-design change, not a bug workaround — see docs/DECISIONS.md for the full record.
  `CoverE` (its counterpart) remains, currently skill-tagged for bots.
- **NAV STRESS (explicit destination testing) is now the preferred way to validate
  navigation capability**, over NORMAL ROAM. NORMAL ROAM is not expected to demonstrate final
  Rushlings bot intelligence — bots currently have no real gameplay objective (that is
  M3-2/M4's job), so ROAM only needs to look like competent wandering, not purposeful play.
  NAV STRESS gives each bot an explicit, distinct sequence of destinations (spanning floor,
  west, east, upper/Crown, seam/wrap, and central/vault-approach) and measures whether it
  reliably arrives, which is a much more direct signal of navigation-graph health than
  watching ROAM behavior and trying to judge whether it "looks smart."

### Vault exit reliability — RESOLVED (2026-09-08)

**Was the critical path to M3-1 acceptance; now closed.** Full account in docs/DECISIONS.md's
2026-09-07/08 entries. Summary of how it actually resolved (not the path originally expected):

- A two-tread staircase geometry redesign (`VaultStepA`/`VaultStepB`) was implemented and
  empirically tested, then **rejected and reverted** after the Game Director tested the
  *original* `VaultEast` geometry by hand and repeatedly entered/exited successfully. This
  proved the geometry was never the defect — bot execution was. **Do not redesign this
  chamber's geometry again** without new, explicit Director direction.
- A small dev-only human-traversal recorder (`scripts/traversal_recorder.gd`) captured the
  Director's actual technique across three consistent demonstrations: release horizontal
  before jumping, jump with zero horizontal hold (straight up beside the obstacle, not trying
  to clear it in flight), hold zero through the ascent, steer only after the apex.
- That recipe is now `EdgeExecutor._advance_vertical_clear_jump`, scoped to exactly the two
  affected edges (`VaultFloor→VaultEast`, `VaultEast→A_E`) via an explicit edge flag - it does
  not touch `_advance_jump` or any other edge's behavior, and no M1 movement constant changed.
- Both edges are now classified **RELIABLE**. `tools/arena_check.gd` returns a clean
  `RESULT: PASS`, zero failures, including the previously-failing East gateway exit test
  (updated to use the same recipe, since the old generic test primitive was exactly the
  technique already known to be unreliable here).

### What this means for the next session

Do not re-litigate the four-player/tempo/collision findings above — they are settled per
docs/DECISIONS.md. Do not start M3-2 without explicit Director acceptance of M3-1. With the
vault exit now resolved, re-run NAV STRESS and the full M3-1 acceptance checklist to confirm
nothing else is outstanding before asking the Director for final M3-1 acceptance.

---

## 0.6 M3-1 acceptance close-out (2026-09-09)

**M3-1 is ACCEPTED. Full record: `docs/DECISIONS.md`, 2026-09-06 through 2026-09-09 entries.**

The vault-exit resolution above (§0.5) was not the end of the story — a traversal audit
(`docs/plans/Arena01_Traversal_Audit.docx`) found the *real* remaining blocker was a navigation
topology/state problem, not a physics one: the reliable graph had no working way up from the
ground at all, and three real transitions were missing from `nav_graph.gd` entirely. Resolved in
order:

1. **Explicit drop departure side** — `_advance_drop` no longer infers which edge to depart from
   by comparing the target's centre to the body's position (wrong whenever the target's centre
   falls inside the source platform's own extent); every drop edge now authors `"side"` as data.
2. **Three missing mandatory edges** — `B_Seam→C_Seam`, `A_W→B_W`, `A_E_Bridge→B_Seam` (the last
   via a new RUN_DROP recipe). With these, the RELIABLE subgraph became strongly connected except
   the two audit-predicted exceptions (`CoverE`, `B_Under`).
3. **Launcher evaluated for Floor→Band C, not promoted** — multi-position, both-direction testing
   showed it only clears the bar from the east; stays SKILL.
4. **`Floor→C_M` fixed-trigger recipe** — a new, edge-scoped recipe made `Floor→C_M` the one
   dependable central bot road up from the ground (5/5 across a spread of positions).
5. **Navigation-policy correction** — a 5-minute NAV STRESS soak (the first time navigation health
   was measured over minutes, not seconds) found bots still preferred the still-broken direct
   `Floor→C_W`/`Floor→C_Seam` edges over the `C_M` detour purely on Dijkstra cost, and that this
   was *also* the root cause of bots trapped/bouncing in the `CoverE`/`C_M` Floor pocket.
   `Floor→C_W`/`Floor→C_Seam` demoted to SKILL/HUMAN-ONLY — cost tuning cannot fix a cost-ordering
   problem; only removing the edges from RELIABLE-only routing does.
6. **Reposition/build-runway fix** — with `Floor→C_M` as the sole gateway, its own rare failure
   mode (jump anyway when too close/too slow — "the unsafe fallback") became fully exposed
   (Slot 4: 0 arrivals, ~83 stall events, permanently parked). Removed and replaced with a bounded
   REPOSITION phase mirroring the human traversal-recorder technique: back off, rebuild a real
   runway, re-approach. Verified against the exact live bad-start position, expanded to a 12-case
   multi-position/multi-velocity matrix (12/12), and confirmed by a second 5-minute soak: Slot 4
   went from 0 arrivals to 18/18, 0 stalls, all destination categories passing for every bot.
7. **A debug-label bug was fixed alongside it** — `current_stress_destination()` now respects the
   intentional 3-loop NAV STRESS cap (`"(sequence complete)"` instead of a stale fake destination),
   which was the exact cause of the earlier-reported "stuck in the Vault" symptom (it was never
   stuck — the label lied). A **`B`** debug key now restarts all three stress sequences for
   extended human observation without restarting the game.

**Final human playtest (2026-09-09), 1.0×, collision OFF, NAV STRESS enabled:** P2/P3/P4 all
navigated successfully, completed their full navigation sequences, moved across every arena
region, vertical traversal worked, Floor was no longer a practical trap, the `CoverE`/`C_M` pocket
no longer produced a blocking trap, Vault traversal remained functional, and no persistent
stuck/jump-spam behaviour was observed. **Accepted.**

**Explicitly deferred, not reopened at this close-out:** `B_Under` human-reachability/design
question; launcher remains SKILL for normal bots; other known human/skill-only traversal edges
(`A_W_Bridge→Pier`, the two Vault far-edge jumps, `C_Seam→A_E_Bridge`, `C_W→B_Under`,
`B_Seam↔B_W`); pre-existing non-load-bearing checker warnings. Bot strategic intelligence, powers,
combat, Relic seeking, learned/human-imitation bot intelligence, networking, and couch/controller
multiplayer remain out of scope for M3-1 and are not addressed by this close-out.

**What the next session inherits:** an accepted four-player foundation with a fully reliable
Floor→Band C bot road, a strongly-connected RELIABLE nav graph, and two permanent regression
tools (`tools/arena_check.gd`, `tools/m3_check.gd` including its NAV STRESS mode). **M3-2 has not
been started.** ~~A fresh session implementing M3-2 should read Part Two (§11 onward) below, which
was approved at plan time and has not changed.~~ **Superseded 2026-09-09 — see §0.7.**

---

## 0.7 M3-2 plan approved (2026-09-09) — Part Two below is PARTLY SUPERSEDED

**M3-2's authority is now `docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md`, not Part Two below.**
Part Two is kept intact as the historical record of what was approved on 2026-09-06 and why.
Read the new plan first; consult Part Two only for the reasoning behind decisions the new plan
carries forward unchanged.

**Status: M3-2 PLAN APPROVED. NO M3-2 IMPLEMENTATION EXISTS** — no gameplay code, scene, script,
test or project setting. A fresh session begins at the new plan's **Step 0** and stops at
**STOP 1**.

**Where Part Two is superseded**, each recorded in full in `docs/DECISIONS.md` (2026-09-09):

| Part Two says | Superseded by | Why |
|---|---|---|
| §11.4 — east barrier at `x 1140–1220`, `VaultEast` top at `y 320` | New plan §05 — `VaultEast` is live at **x 1160–1240, y 360–460** | The Director hand-edited the chamber after Part Two was written; barriers authored from the old numbers land in the wrong place |
| §11.4 — seal "the two approaches" with free-standing barriers | New plan §05 — seal the **volume** via two thin roof strips at the header's own y-range | The chamber has an **80px hole in its ceiling** between `VaultGateW` (x1080) and `VaultEast` (x1160); barriers across the approaches leave it open |
| §11.3 — telegraph is "a visible countdown plus a clear gate state change" | New plan §05 — **the existing six bars mechanically lift** in the final portion of UNLOCKING | Director revision 2026-09-09 after inspecting the live gate: the bars already read as a locked cage and stay the primary visual language |
| §11.5 — "lowest slot index wins on a same-frame tie" | New plan §11 — physics-frame overlap poll → **closest to Relic centre** → slot ID | A pure slot rule makes P1 (the human) win every tie, in a milestone testing whether racing the bots is fair |
| §11.2 / M3-A8 — 10s, A/B'd against 25s | New plan §04 — 10s configurable, **10/15/25** debug options, default chosen from a real engine door-arrival measurement | Part Two's "3–4.5s puts any player at a door" starts *at Band C*; both floor spawns start below it, and there is now one reliable road up from the ground |
| §11.5 — bots switch `ROAM → SEEK_RELIC` after a reaction delay | New plan §08 — switch when the delay has elapsed **and the bot is grounded on a graph node** | `_update_localization()` only runs when `is_on_floor()`; cancelling mid-air leaves `current_node` stale and the bot re-plans from a platform it already left |

**Carried forward from Part Two unchanged:** the four-state FSM shape, UNLOCKING as the tail of the
setup timer (M3-A10), Option A camping-prevention *intent* (M3-A9) including "do not create traps",
preserving the accepted decorative bars, the "arena geometry changes are limited to the vault
seal" constraint, the named second-order risk that the rush may be decided by standing position,
and the full out-of-scope list.

**New in the M3-2 plan, with no Part Two equivalent:** gate-conditional nav edges (Part Two never
noticed that five reliable edges pass through the sealed volume, or that the vault is a 4.5×
Crown-level shortcut whose removal re-routes the arena); the grounded re-path mechanism; roof
camping approved as instrumented behaviour; and the convergence/fairness telemetry.

---

## 0.8 M3-2 acceptance close-out (2026-09-12)

**Status: ACCEPTED.** Full implementation and playtest record lives in
`docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md`'s own Step 7 close-out — this entry only marks that
Milestone 3 as a whole is now closed and points there rather than duplicating it.

**Accepted loop:** `SETUP → UNLOCKING → OPEN → SEEK_RELIC → COLLECTION → RESULTS → REMATCH`.
Final human playtest confirmed every stage reads clearly, bots visibly switch ROAM→SEEK_RELIC at
OPEN and physically converge using the accepted M3-1 navigation, human and bots can collect the
same Relic, RESULTS freezes correctly, and rematch reliably starts a fresh round across repeated
rounds.

**Setup duration:** 10s is the accepted M3-2 baseline for the current no-powers game. The 15s/25s
debug options are preserved, not deleted — ~25s remains the M4 working direction once powers give
the setup phase content.

**Arena 01 roof/east-wall pre-positioning is ACCEPTED as an emergent strategy, not a defect** — see
`docs/DECISIONS.md` (2026-09-12) for the full finding and the M4 counterplay hypothesis it is
recorded against.

**M3 — Core Game Loop is COMPLETE.** Next milestone per the existing roadmap: M4 — Powers & Bot
Intelligence, **not started**, and per the Game Director's own direction, M4 implementation must
be preceded by a dedicated match-economy design/planning session — see `docs/DECISIONS.md`'s
"Future match structure" entry (2026-09-12) and `docs/GAME_DESIGN.md`'s corresponding future-
direction section.

---

# ⛔ READ THIS BEFORE WRITING ANY CODE ⛔

**This banner is now historical.** Milestone 3 (both halves) is complete and accepted — see §0.8
above. Kept intact below as the record of the approval gate that was actually enforced.

**Milestone 3 is split into two sequential halves separated by a hard human-playtest
approval gate.**

| | Half | Contains | Ends with |
|---|---|---|---|
| **M3-1** | **Four-player foundation** | Slot architecture · controller abstraction · colour identity + labels · nav graph · edge executors · pathfinding · roaming bots with encounter bias · decorrelation · recovery · checker extensions | **HARD STOP → human playtest A1/A2/A3 → Director acceptance → commit** |
| **M3-2** | **Core match loop** | Match FSM · setup timer · UNLOCKING telegraph · gate CLOSED→OPEN · Relic collection · winner · results/rematch · vault sealing · bot goal switch | Playtest B1/B2/B3 → acceptance → commit |

**A fresh implementation session must implement M3-1 ONLY.**

**Nothing in §11 (M3-2) may be built — not partially, not "while we're in there", not as a
disabled stub — until the Game Director has personally played M3-1 and accepted it.**
Specifically forbidden during M3-1: a functional Relic, a gate state machine, a setup timer,
winner detection, a results screen, and rematch/reset-for-a-new-round logic.

If you are reading this file at the start of a session and you do not have an explicit,
written M3-1 acceptance from the Game Director, **you are building M3-1.**

---

## 0. Approval and amendments

Approved 2026-09-06 with ten amendments. All are applied throughout this document; they are
listed here so a fresh session knows which parts are settled decisions rather than proposals.

| # | Amendment | Where applied |
|---|---|---|
| **M3-A1** | **Split M3 into M3-1 and M3-2 with a hard playtest approval gate between them.** No functional Relic/loop systems during M3-1. | Banner above, §1, §10, §11 |
| **M3-A2** | **Work item #0 first**: acknowledged-exception handling for the accepted `B_Under` R7 finding, and fix Band A membership/coverage. A clean accepted baseline must return **exit code 0**. | §2, §9.1 |
| **M3-A3** | **Formalise the controller abstraction now** — a slot can be human-local, bot, or (reserved) network. No networking, no multi-controller assignment. | §5 |
| **M3-A4** | **Player↔player physical collision OFF** to start M3-1, kept as a **development toggle** for a brief A/B during the playtest. **Not a permanent product decision.** | §5.4, §10.4 |
| **M3-A5** | **Bot architecture approved** (nav graph · Dijkstra · per-edge executors · real M1 physics · no teleport cheating · deterministic variation · purposeful roaming), **plus one small social-awareness behaviour: curiosity / encounter bias.** ~70–80% environmental interest, ~20–30% player-occupied-region interest, configurable. **Not chasing, attacking, targeting the human, aggression, or M4 combat AI.** | §7, **§7.6** |
| **M3-A6** | **Player identity**: P1 red/orange, P2 purple, P3 green, P4 blue. **Subtle P1–P4 labels shown for the first playtest**, toggleable, so colour-only readability can be tested afterwards. | §5.3, §10.2 |
| **M3-A7** | **Playtest A1 (1.0×) → A2 (1.25× via `Engine.time_scale`) → A3 (back to 1.0×)**, then an optional collision OFF/ON A/B. **No M1 movement constants change during this test.** Hard STOP after. | §10 |
| **M3-A8** | **Setup duration 10s** as the temporary M3 value. Does **not** supersede the ~25s working direction for M4 with powers. M3-2 A/Bs 10 vs 25 later. | §11.2 |
| **M3-A9** | **Vault camping fix = Option A**: during SETUP, physically seal the two approved vault approaches. Preserve the accepted decorative CLOSED gate readability. **Do not create traps.** | §11.4 |
| **M3-A10** | **UNLOCKING is the final ~2 seconds of the 10-second setup, not an extra wait.** 0–8s SETUP/CLOSED · 8–10s UNLOCKING/still physically closed · 10s OPEN. Timing tunable. | §11.3 |

---

## 1. Goal and risk tested

M1 proved the movement. M2 proved Arena 01 as a one-player exploration space. M3 must answer:

> **Does Rushlings become fun, readable and appropriately chaotic when four players move
> simultaneously inside the same fixed-screen arena?**

The Relic loop matters, but it is deliberately **not** the first thing tested. M3-1 answers the
question above with the objective absent. M3-2 then adds the loop on top of an arena already
proven to hold four bodies.

**Why the split, and why not a different M3/M4 cut:** M3 as originally scoped is genuinely two
milestones of work. But the loop must not be deferred into M4 either — M4 is powers, and powers
layered on an unvalidated match loop is strictly worse. The correct cut is *inside* M3.

**A note on the originally proposed ordering:** the session brief proposed "M3A four-player
simulation" before "M3B bot navigation". That ordering does not hold — four-player simulation
*requires* navigation, otherwise it is four rectangles standing still. Navigation is a
prerequisite of the first deliverable, not a follow-up to it. M3-1 therefore contains both.

---

## 2. Work item #0 — checker prerequisite (M3-A2)

**Do this first, before any M3-1 gameplay code.**

`tools/arena_check.gd` currently exits **non-zero** on the accepted M2 baseline, because of the
single deliberately-unfixed finding:

```
[R7] Band C -> Band B barrier: C_W -> B_Under   FAIL
     landing platform 'B_Under' is 140px wide, needs >=280px for a normal route
```

That finding is correct and is **not** to be fixed — `B_Under` is a confirmed
"intentionally hard to reach, high pickup value" spot (`docs/DECISIONS.md`, 2026-09-06). But a
regression tool that already fails cannot detect a *new* regression by exit code, which makes it
useless as an M3 gate.

**Required changes:**

1. **Acknowledged-exception list.** A small, explicit, commented allowlist of accepted findings
   (currently exactly one: the `C_W -> B_Under` R7 landing width). An acknowledged finding is
   still **printed in full**, clearly marked as acknowledged, and counted separately. It does not
   contribute to the exit code. Any *unlisted* failure still fails.
   - The list must be keyed tightly enough that a *different* R7 failure on `B_Under` (say, a
     changed rise) does not get silently swallowed by the same entry.
2. **Fix Band A membership.** `_band_report`'s Band A member list omits `A_W_Bridge` and
   `A_E_Bridge`, so it reports 38.8% coverage with gaps `[90, 102]`. With the bridges included,
   real Crown coverage is ~53% with a continuous 728px run (x 922→1650) plus a 290px run
   (x 530→820). M3 reasons about crowding from these numbers, so they must be right.
3. **Exit code contract:** clean accepted baseline ⇒ **0**. Anything else ⇒ non-zero.

**Acceptance:** `godot --headless --path . --script tools/arena_check.gd; echo $?` prints `0`
with no gameplay code yet written.

---

## 3. Audit of the inherited M2 baseline

Recorded from the live scene and a headless checker run on 2026-09-06, **not** from
`M02_ARENA_01_V2.md` — the Director's hand-edits have moved geometry since that brief was
written. Treat the table below as the M3 starting truth.

### 3.1 Live geometry

| Node | Span x | Surface y | Note vs. the V2 brief |
|---|---|---|---|
| `Floor` | −100…2020 | 960 | as designed |
| `CoverW` | 620–760 | 880 | 80px step |
| `CoverE` | 1180–1320 | **923** | 37px step (hand-edited); visual matches collision |
| `C_W` | 380–920 | 820 | |
| `C_M` | 1080–1440 | 820 | |
| `C_Seam` | 1580–2180 (mirrored ±1920) | 820 | |
| `B_W` | 460–740 | 560 | |
| `Pier` | 740–820 | 200 (solid y 200–620) | the arena's one wall |
| **`B_Under`** | 960–1100 | **636** | lowered by hand — 184px rise from `C_W`, vs a 184.1px max |
| `B_E` | 1280–1620 | 560 | |
| `B_Seam` | 1780–2140 (mirrored ±1920) | 560 | |
| `A_W` | 530–650 | 300 | narrowed 280→120 by hand |
| `A_W_Bridge` | 650–740 | 300 | close-out connectivity fix |
| `VaultFloor_Bridge` | 820–922 | 460 | close-out connectivity fix |
| `VaultFloor` | 922–1220 | 460 | |
| `VaultEast` | 1140–1220 | 320 | trimmed to 140px tall at close-out |
| `A_E` | 1220–1466 | 300 | shortened by hand |
| `A_E_Bridge` | 1466–1650 | 300 | close-out connectivity fix |
| **`VaultGateW`** (header) | 920–1080 | **solid y 336–376** | real collision; 84px headroom over the Relic |
| `RelicPlaceholder` | 980–1020 | y 400–460 | ColorRect, no collision |
| **`RelicGate` Bar1–6** | 927–1073 | y 376–460 | **ColorRect only — zero collision** |
| `LadW` | 370–430 | y 210→820 | |
| `LadE` | 1650–1730 | y 210→820 | |
| `PadC` | 270–350 | on Floor | vertical only |

Two consequences that drive M3 decisions:

- **The Relic sits in a barred alcove under a solid beam with 84px of headroom.** A player can
  walk in but cannot jump inside it. Collection by touch is therefore a trivial `Area2D` overlap.
- **The "closed" gate is purely cosmetic.** Any player can walk to the Relic and stand on it from
  t=0. See §11.4.

### 3.2 Checker state at the M2 baseline

- **1 failure** — the acknowledged `B_Under` R7 finding (§2).
- **4 warnings** — all four spawns report `NO PROVEN ROUTE` in the route-cost table.
- Everything else passes: R1–R6, R8, R9, R12, both gateway routes, both Crown entrances
  (2.48s west, 1.97s east), the skill jump (0.87s), both launcher landings (0.98s), and all six
  wrap-integrity checks.

### 3.3 The most important finding in the audit

The four route-cost WARNs are **not** an arena defect. The tool's own comment identifies the
cause: the harness departs a ledge at full running speed, and because deceleration is
floor-only, nothing slows the fall's horizontal drift, so it overshoots narrow targets below.

**The manoeuvre the harness cannot perform — a controlled low-speed edge departure, releasing
input the instant the body clears the edge — is exactly the manoeuvre a bot must perform dozens
of times per match.** Building the bot's `drop` executor *is* the fix.

**Therefore: retiring all four route-cost WARNs is a hard M3-1 acceptance criterion** (§9.2).

### 3.4 The controller seam already exists

`scripts/player.gd` reads input in exactly three functions — `_get_horizontal_intent`,
`_get_vertical_intent`, `_get_jump_intent` — and `docs/DECISIONS.md` (2026-09, "Mobile control
mapping stays unresolved until M5") already commits to replacing those bodies without touching
movement physics. That is the human/bot/network abstraction, already designed. M3-1 formalises
it (§5) at near-zero cost.

---

## 4. M3's exact validation questions

**M3-1 — must be answered before any Relic work exists:**

1. At 36×56 px, can the Director instantly find *themselves* among four bodies?
2. Can they tell P2/P3/P4 apart at a glance, and read where each is heading?
3. Does Arena 01 feel too empty, correctly populated, or crowded with four bodies?
4. Do the three bots read as *alive* — or as robots on rails, or as broken?
5. Do encounters actually happen, or do four players orbit past each other all game?
6. Does the Director *want* to interfere with them? (the M4 appetite signal)
7. Does 1.25× remain readable with four bodies, or does the extra energy cost legibility?

**M3-2 — after the gate:**

8. Is the CLOSED→UNLOCKING→OPEN transition unmistakable without explanation?
9. Is the rush a contest, or decided by who happened to be standing nearest?
10. Is 10s the right setup length with no powers? Is 25s?
11. Does the Director press rematch voluntarily? (the "Again." signal)

---

# PART ONE — M3-1: FOUR-PLAYER FOUNDATION

---

## 5. Player-slot and controller architecture (M3-A3)

### 5.1 Slot model

```
PlayerSlot { slot_id: int, controller_kind: ControllerKind, color: Color, spawn: Marker2D }
ControllerKind { HUMAN_LOCAL, BOT, NETWORK }   # NETWORK is a reserved name only
```

Slot→controller mapping lives in a `MatchConfig`, read at match start, so "who is human" is
**data, not code**. M3-1 default: slot 1 `HUMAN_LOCAL`, slots 2–4 `BOT`.

**Nothing may assume P1 is permanently the only possible human.**

### 5.2 The controller abstraction

`scripts/player.gd` changes to delegate, and **nothing else changes in it**:

```gdscript
var controller: PlayerController          # assigned at spawn

func _get_horizontal_intent() -> float: return controller.horizontal()
func _get_vertical_intent()   -> float: return controller.vertical()
func _get_jump_intent()       -> bool:  return controller.jump_pressed()
```

- **`HumanController`** — today's `Input` reads, verbatim, but **parameterised by an action-name
  prefix / device id rather than hardcoded action strings.** That parameterisation is the entire
  couch-multiplayer preparation, and it is the only part worth doing now.
- **`BotController`** — produces the same three signals from the navigation layer (§7). It never
  writes `global_position`, never calls `reset_to` during normal play, and has no physics
  exemptions of any kind.
- **`NetworkController`** — a name in the enum. **Not written.**

**Explicitly not in scope:** networking, device assignment UI, split input maps, a join flow,
or a second local human.

**Cost of skipping this:** rewriting the bot/human coupling at M5 and again at M9. It is ~30
lines now.

### 5.3 Identity (M3-A6)

- Add `@export var body_color: Color` to `player.gd`, applied to the `ColorRect` in `_ready`.
- **P1 red/orange** (keep the current `0.9, 0.2, 0.2`) · **P2 purple** · **P3 green** ·
  **P4 blue**. The greybox palette is greyscale, so four saturated hues separate cleanly.
- **Subtle `P1`–`P4` labels above each placeholder, ON for the first playtest**, driven by a
  single toggle. After initial readability is established they are switched off to test whether
  **colour alone** is sufficient (§10.2). Labels are debug affordances, not HUD — small, low
  contrast, no background panels, no player cards.

### 5.4 Player↔player collision (M3-A4)

**M3-1 starts with player↔player physical collision OFF** — players on their own collision
layer, masking world geometry only.

Reasons on record: M2 established that incidental collision physics already **read as a Push
power** to the Director, so leaving bodies colliding would contaminate M4's real Push; and bots
wedging on each other is the single likeliest source of stuck states.

**Kept as a development toggle** for a brief A/B during the playtest (§10.4). **This is not a
permanent product decision** and must not be recorded as one.

---

## 6. Scene / script structure (M3-1 portion)

```
scenes/arena_01/arena_01.tscn
  Arena01                    ← scripts/arena_01.gd        [MODIFIED: spawns four slots]
    NavGraph                 ← scripts/nav_graph.gd       [NEW]
      N_* (Marker2D × ~30)
    PlayerSlots
      Slot1..Slot4           ← scenes/player/player.tscn instances
    ...existing M2 geometry, traversal, markers, RelicPlaceholder, RelicGate unchanged...
    HUD → DebugLabel         ← scripts/debug_hud.gd       [MODIFIED: follows slot 1]
```

**New scripts (M3-1):** `match_config.gd`, `player_controller.gd` (base), `human_controller.gd`,
`bot_controller.gd`, `bot_brain.gd`, `nav_graph.gd`, `nav_path.gd`, `edge_executor.gd`.

**Modified (M3-1):** `player.gd` (three intent functions delegate; `body_color`; `slot_id` —
**zero physics changes**), `arena_01.gd`, `debug_hud.gd` (its `player_path = ../../Player` breaks
the moment the node is renamed).

**Unchanged, hard constraint:** `arena_wrap.gd`, `traversal_zone.gd`, `launch_pad.gd`,
`seam_mirror.gd`, and **every M1 tuning value**. `main.tscn` stays an empty placeholder;
`arena_01.tscn` stays `main_scene`.

**Arena geometry: zero changes in M3-1.** (M3-2 adds only the two vault door barriers, §11.4.)

---

## 7. Bot navigation architecture (M3-A5)

**Approved: a hand-authored, checker-validated navigation graph + Dijkstra + per-edge executors
+ a small FSM.**

Rejected, with reasons recorded so they are not re-litigated:

- **Godot `NavigationServer2D` / navmesh.** Models walkable surfaces and agents crossing them. It
  does not model jumps, ladders, launch pads, or a horizontally wrapping world. Every interesting
  edge in Arena 01 would still have to be a hand-authored `NavigationLink2D` — the same work,
  plus a runtime that contributes nothing.
- **Pure utility scoring with no graph.** Utility answers *which* target. It cannot answer *how
  to cross a 260px barrier*. The graph is still required underneath.
- **Steering / potential fields.** In an arena whose entire design is "cheap to fall, expensive
  to climb", a bot walking toward the target's bearing walks off ledges into the wrong band
  continuously.

### 7.1 Graph representation

Authored **in-scene** under a `NavGraph` node: one `Marker2D` per node, edges as an exported
typed array on `nav_graph.gd`. In-scene rather than as a separate resource, because the Director
hand-edits geometry in the editor and the graph must visibly track it.

Approximately **30 nodes / ~60 edges** — comfortably hand-authorable:

| Band | Nodes (~) |
|---|---|
| Floor | west · `PadC` · mid-west · `CoverW` · centre · `CoverE` · east · seam — **8** |
| Band C | `LadW` base · `C_W` mid · `C_W` east · `C_M` west · `C_M` east · `LadE` base · `C_Seam` wrap pair — **8** |
| Band B | `B_W` west edge · `B_W` mid · `B_Under` · `B_E` · `LadE` mid-station · `B_Seam` pair — **7** |
| Crown | `A_W` · `A_W_Bridge` · Pier top · vault west pocket · **Relic** · `VaultEast` · `A_E` · `A_E_Bridge` · `LadE` top — **9** |

Edge record: `{ from, to, type, recipe, cost_seconds }`. **Costs are measured by the checker,
never guessed.**

Edge types: `walk` · `step_up` · `jump_gap` · `drop` · `ladder_up` · `ladder_down` ·
`ladder_exit_mid` · `launch`. `wrap` is a **flag on walk edges** that cross the seam, not a
separate type.

### 7.2 Pathfinding

**Hand-rolled Dijkstra** over ~30 nodes — free at this size, and it sidesteps a real footgun:
A*'s Euclidean heuristic is wrong in a wrapping world unless every distance uses wrap-aware
shortest-difference logic (`_shortest_diff` already exists in `arena_check.gd` and should be
shared). Recompute on target change, on arrival, or on edge failure — **never per frame.**

### 7.3 Edge execution — using jump/ladders/launcher/wrap without cheating

Every edge type has a small executor emitting **only** the three intent signals. No teleports, no
position writes, no physics exemptions. Bots run the identical `player.gd` code path as the human.

| Type | Recipe |
|---|---|
| `walk` | hold direction (wrap-aware shortest); done within tolerance of target x |
| `step_up` | hold direction; jump within N px of the ledge |
| `jump_gap` | walk to the edge's stored takeoff x, confirm speed ≥ required, jump, hold direction through the arc |
| `drop` | walk to the departure edge, **release input the instant the origin clears `half_w + 4`**, fall, re-acquire on landing |
| `ladder_up` / `ladder_down` | walk into the zone, release horizontal, hold vertical until target y, release, step off in the exit direction |
| `ladder_exit_mid` | as above, but release at the mid-station y and step off left or right |
| `launch` | walk onto the pad, wait for airborne, **wait ~12 ticks**, then hold the steer direction |
| `wrap` (flag) | ordinary walk. Wrapping is transparent — `arena_wrap.gd` handles it, and bots inherit it free because `player.gd::_ready` already joins the `wrappable` group |

**These recipes are not invented.** They are `arena_check.gd`'s already-proven route primitives:
`_run_and_jump_near_edge`, `_drop_to_band_c` (including its "release the moment the edge clears"
reasoning), the ladder-climb blocks, and `_route_launcher`'s 12-tick steering delay.

**Honest caveat:** the checker's versions are `await` coroutines; the bot needs per-frame state.
This is a re-shape, not copy-paste. But the *recipes* are validated.

**Then invert the dependency:** once the executors exist, the checker should drive **them**
instead of maintaining its own copies. That is how the two stop drifting, and how the four
route-cost WARNs get retired (§3.3, §9.2).

### 7.4 Decision model

A minimal FSM, with utility only where it naturally belongs — target *selection*:

- **`ROAM`** — pick an interest target (§7.5, §7.6); on arrival, pick the next.
  **In M3-1 this is the entire bot.**
- **`RECOVER`** — off-graph or stuck (§8).
- *(M3-2 adds `SEEK_RELIC`. M4 adds `SEEK_PICKUP` / `CHASE` / `AVOID` / `USE_POWER` at the same
  target-selection seam.)*

**Do not build a general utility system for two states.**

### 7.5 Deterministic variation between bots

Five knobs, all seeded from `match_seed + slot_index`, all testable, **none a personality**:

1. **Decision interval + phase offset** — e.g. 0.45 / 0.55 / 0.65 s with offsets 0 / 0.15 / 0.30 s.
   Breaks lockstep immediately.
2. **Reaction delay on state change** — e.g. 0.15 / 0.30 / 0.45 s.
3. **Per-bot edge-type cost weights** — e.g. one bot ×0.85 on `ladder_*`, another ×0.85 on
   `drop`/`wrap`, one neutral. Same graph, genuinely different routes, **zero new behaviour code**.
4. **Level-change willingness** — a per-bot additive penalty on `ladder_up` / `launch`, so some
   bots live low and others climb readily.
5. **Distinct interest-point lists** during `ROAM`, drawn from a per-bot seeded RNG.

**Explicitly not built in M3:** aggression, difficulty tiers, personalities, interference.

**Purposeful roaming is a requirement, not a nicety.** With no objective, roaming quality *is*
the bot. Interest points must be spread across all four bands, prefer least-recently-visited, and
the bot must **commit** to a target rather than dithering. See risk #1 (§12).

### 7.6 Curiosity / encounter bias (M3-A5) — the one social behaviour

Bots occasionally choose an interest region **currently occupied by another player**.

- Working weighting: **~70–80% environmental/arena interest, ~20–30% player-occupied-region
  interest.** Exported and configurable; do not over-engineer it.
- The target is a **region**, not a player. It is resolved to a nav-graph node at selection time
  and **not re-targeted** if the other player moves.
- On arrival, **normal roaming resumes immediately.**

**What this is NOT:** chasing · attacking · targeting the human specifically · aggression ·
M4 combat AI · any form of pursuit or prediction.

**Why it exists:** to raise natural path-crossing frequency so M3-1 can meaningfully answer
question 5 (*do encounters actually happen?*) and question 6 (*does the Director want to interfere
with them?*). Without it, four independent roamers in a 1920px wrapping arena can plausibly never
meet, and the milestone's central question goes untested.

**Bias the sampling toward other bots as well as the human** — if the bias only ever selects the
human's region, it becomes the chasing behaviour this amendment explicitly excludes.

---

## 8. Recovery — minimum M3 implementation

**M3 does not need a hazard respawn system, and hazards must not be invented to justify one.**
There are no hazards; the checker proves no trap volumes (R9) and every fall lands on a surface.

**Normal bot recovery is not a respawn.** On edge failure: mark that edge temporarily blocked,
re-localise to the nearest graph node via "which platform am I standing on", re-path. Falling
into an unexpected band is **normal in this arena by design**, not a failure.

**One shared `respawn(slot, position)` path**, with exactly three callers:

1. Match reset / rematch — all slots to spawns. *(M3-2 only.)*
2. **Bot hard recovery — last resort only**, after N consecutive edge failures or T seconds
   unable to localise. **Logged loudly.** If this fires during a playtest it is a bug signal, not
   normal operation.
3. The existing debug `R` key.

Building it as one function now means M4's hazards inherit respawn for free.

**Known landmine, do not "tidy" it:** `player.gd::reset_to()` deliberately does **not** clear
`in_traversal_zone` / `climb_top_limit`, because those are owned by the traversal zone's
enter/exit signals which re-evaluate overlaps after the move. This was a real bug caught by the
M1 harness and it will resurface at M3 if someone clears them here.

---

## 9. M3-1 automated tests

### 9.1 Prerequisite

Work item #0 (§2) complete: clean accepted baseline returns **exit code 0**.

### 9.2 Tests

| # | Test | Why |
|---|---|---|
| 1 | **Nav-graph edge validation** — every edge executed by a real `BotController` in the real arena, must succeed inside its budget | Highest-value test in the milestone. **Retires the four route-cost WARNs** (§3.3) |
| 2 | **Determinism** — same seed ⇒ identical position hash after N ticks | Catches unseeded RNG and frame-rate dependence |
| 3 | **Decorrelation** — over 60s with 3 bots, pairwise "same platform" fraction and position correlation stay below a threshold | Makes "bots don't move as one group" falsifiable rather than a vibe |
| 4 | **Coverage** — over 60s, bots collectively visit ≥X% of graph nodes and **all four bands** | Catches a parked or orbiting bot |
| 5 | **Encounter rate** — over 60s, count player-proximity events; assert it is non-zero and within a sane band | Makes the §7.6 curiosity bias measurable rather than assumed |
| 6 | **Stuck** — zero hard recoveries across 3×60s runs at different seeds | §8 |
| 7 | **Regression** — R1–R12, all route proofs and all six wrap-integrity checks still pass **with four bodies present** | Four bodies must not perturb the M2 proof |

**Hard M3-1 acceptance criterion:** the route-cost table reports a proven route for all four
spawns. No remaining `NO PROVEN ROUTE` warnings.

---

## 10. M3-1 human playtest (M3-A7)

**No M1 movement constants may be changed during or because of this test.**

### 10.1 Session A1 — 1.0×, ~4 minutes

Instruction, and nothing more: *"Play with these three. There's no goal yet."*
P1–P4 labels **ON**. Then ask questions 1–6 from §4.

### 10.2 Label-off readability check

Same session, labels **OFF**. Re-ask questions 1 and 2 only: can you still find yourself, and
still tell the others apart, **on colour alone**?

### 10.3 Session A2 — 1.25× via `Engine.time_scale`, then A3 — back to 1.0×

Same duration, same questions, plus: *more fun, or just more chaotic?* and *could you still read
where everyone was?*

**A3 (a short return to 1.0×) is required, not optional** — one A/B cannot distinguish a real
preference from novelty, and order effects are real.

**Technical point that must not be skipped.** Use `Engine.time_scale`, **not** rescaled movement
constants:

- `time_scale` scales time uniformly. Every jump arc, gap and landing window is **geometrically
  identical**, so the entire M2 checker proof still holds, and it reproduces exactly the thing
  the Director already judged at 1.25× debug playback.
- Rescaling `max_speed` / `gravity` / `jump_strength` changes **every arc**, and would
  **invalidate the whole M2 geometry proof** — requiring full re-verification and possibly
  re-authored platforms.

**Therefore:** A/B with `time_scale` only. If 1.25× wins, converting it into real constants is a
**separate, dedicated tuning pass with a full checker re-run**, never folded into M3.

**Bots must be `time_scale`-safe** — all timers `delta`-based, never frame counts.

### 10.4 Optional Session A4 — collision OFF vs ON (M3-A4)

Run **after** the primary tempo/readability tests, so it cannot contaminate them. Toggle only;
no permanent decision is recorded from this session.

### 10.5 ⛔ HARD STOP

**Nothing in Part Two is implemented until the Game Director has played A1–A3 and accepted
M3-1.** If four players in Arena 01 is not fun, the match loop will not rescue it — and it is far
cheaper to learn that from an empty arena.

Commit M3-1 as its own checkpoint on acceptance.

---

# PART TWO — M3-2: CORE MATCH LOOP

> **⛔ PARTLY SUPERSEDED 2026-09-09. The authority for M3-2 is
> `docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md`** — see §0.7 above for the table of exactly which
> statements below no longer hold. This section is preserved as the historical record of the
> 2026-09-06 approval; **do not implement from it directly.**
>
> **Original note, kept:** LOCKED. Do not implement any of Part Two until M3-1 is accepted (§10.5).
> This section is recorded now so the plan is complete, **not** so it can be started early.

---

## 11. M3-2 design

### 11.1 Match state machine

A `MatchDirector` node owning one FSM, **`delta`-driven** (never frame counts — must survive
`Engine.time_scale`):

```
SETUP (0–8s)  →  UNLOCKING (8–10s)  →  OPEN  →  WON  →  RESET  →  SETUP
```

### 11.2 Setup duration (M3-A8)

**10 seconds**, exported and configurable.

Reasoning from measured facts: the checker times the Crown entrances at **1.97s** (east) and
**2.48s** (west) from Band C; from spawn, roughly 3–4.5s puts any player at a vault door.

The ~25s working value exists to give **power acquisition** room. In M3 there are no powers, so
the phase contains only positioning. At 25s that is ~4s of travel followed by ~21s of standing
at a doorway — dead air that would make the Director judge the phase rather than the loop. At 5s
the phase has no identity at all. At 10s there is ~6s of jockeying: one full cross-arena
reposition (~2–3s) plus a counter — a real decision.

Secondary benefit: 10s setup + ~5s rush ≈ 15–20s rounds, so a session runs many rounds and the
"Again." signal actually gets measured.

**This does not supersede the ~25s working direction for M4**, when powers give the phase
content. **M3-2 must A/B 10s vs 25s** (Session B2) so the number is measured, not assumed.

### 11.3 UNLOCKING telegraph (M3-A10)

**The final ~2 seconds of the 10-second setup are the telegraph — not an additional wait.**

| Window | State | Vault |
|---|---|---|
| 0–8s | SETUP / CLOSED | physically sealed |
| 8–10s | **UNLOCKING** | **still physically sealed** |
| at 10s | OPEN | barriers removed, Relic collectible |

Exact timing tunable. The telegraph turns the rush into a race with a starting gun rather than a
coin flip on standing position, and it directly serves the requirement that the state change be
**extremely obvious**. Greybox only: a visible countdown plus a clear state change on the gate.
No animation, no VFX.

### 11.4 Vault sealing / camping fix (M3-A9)

**The problem, stated precisely:** the `RelicGate` bars are six `ColorRect`s with **zero
collision**. Any player can walk into the alcove at t=0 and stand on the Relic for the entire
setup phase. With no powers in M3 to dislodge them, camping is a guaranteed win — **that alone
would invalidate the M3-2 test.**

**Approved fix — Option A: seal the two approved vault approaches during SETUP/UNLOCKING.**

- A solid barrier plugs the **west fall shaft** (x 820–922, between the Pier's east face and
  `VaultGateW`).
- A second barrier blocks the **east threshold** above `VaultEast` (x 1140–1220), tall enough to
  be un-jumpable from `A_E` (surface y=300, so ≥200px rise required against a 184.1px max).
- Both are removed at OPEN.
- **The accepted decorative CLOSED gate (the bars) is preserved** as the readability signal the
  Director already validated by playtest. The bars stay cosmetic; the barriers do the work.

**Rejected alternatives, recorded so they are not retried:**

| | Approach | Why rejected |
|---|---|---|
| B | Give the existing bars collision | **Creates a trap.** The west door is one-way-in, so a player dropping through lands in the 820–927 pocket, walled by the Pier's un-jumpable 260px east face and now by solid bars — stuck until OPEN. Violates "nobody sits watching a match" |
| C | Do nothing; Relic simply not collectible until OPEN | Degenerate — first to the alcove wins at t=open |
| D | Repel volumes / soft push-out | Exactly the "arbitrary invisible walls" the Director ruled out |

**Trap check against live geometry (M3-A9: "do not create traps").** With Option A, camping
positions become the **Pier top** (west) and **`A_E`** (east). Both are legitimate, fully visible
and contestable, and neither is a trap: the Pier top walks back to `A_W_Bridge` → `A_W` → `LadW`
down; `A_E` descends via `LadE`. **R9 must be re-proved by simulation in *both* gate states.**

**Second-order risk, named now:** with a sealed vault the rush may be decided in ~1s by who is
standing at a door. The doors are near-equidistant from the Relic (west landing ≈80–140px away,
east step-down ≈120px), so the real contest becomes *holding a door for 10s*, which is
acceptable for M3. The UNLOCKING telegraph (§11.3) mitigates the coin-flip reading. If it still
feels anticlimactic, the fix belongs to M4's powers, not to more geometry.

### 11.5 Relic, winner, results, rematch

- **OPEN** — barriers removed, bar `ColorRect`s hidden, Relic `Area2D` monitoring enabled, one
  instant colour change on the vault floor.
- **Bots** switch `ROAM → SEEK_RELIC` after their **own per-bot reaction delay**
  (0.15/0.30/0.45s), so the pivot is not synchronised.
- **WON** — first body overlapping the Relic wins. **Tie-break must be explicit: lowest slot
  index wins on a same-frame tie.** Collection fires exactly once behind a guard flag, and the
  FSM latches.
- **RESET** — positions, velocities, `is_climbing`, `climb_suppressed`, traversal flags, gate
  state, timer, bot FSM + path caches, and RNG **re-seeded from `match_seed + round_index`**.
- **HUD** — timer during SETUP/UNLOCKING; `P2 WINS` on WON; a rematch key/button. Nothing else.
  No player cards, no progression, no XP.

### 11.6 M3-2 scene additions

```
    MatchDirector            ← scripts/match_director.gd  [NEW]
    RelicGate                ← scripts/relic_gate.gd      [NEW] bars + the two door barriers
    Relic (Area2D)           ← scripts/relic.gd           [NEW]
    HUD → MatchHUD           ← scripts/match_hud.gd       [NEW]
```

**Arena geometry changes in M3-2: only the two door barriers.** Nothing else — and specifically
**not** `B_Under`, the Pier top, or the Band C gap under the vault, which stay hard on purpose as
M4 pickup sites (`docs/DECISIONS.md`, 2026-09-06).

### 11.7 M3-2 automated tests

| # | Test |
|---|---|
| 8 | FSM transitions and timer accuracy at `time_scale` 1.0 **and** 1.25 |
| 9 | Barrier collision present in SETUP and UNLOCKING, absent in OPEN; **R9 no-trap proven in both states** |
| 10 | **Nobody can reach the Relic during CLOSED** — all four bots plus a scripted human try, for the full setup duration |
| 11 | Collection fires exactly once; same-frame tie resolves deterministically to the lowest slot index |
| 12 | Rematch resets every field listed in §11.5 |
| 13 | **20 headless bot-only matches all terminate with a winner in under 2 minutes** |

### 11.8 M3-2 human playtest

- **B1** — full match, 10s setup, 3 rounds + rematch. Questions 8–9.
- **B2** — same at 25s setup. Direct comparison (question 10).
- **B3** — unprompted: does the Director hit rematch on their own? (question 11).

---

## 12. Risks

| # | Risk | Sev | Mitigation |
|---|---|---|---|
| 1 | **Bots looking dumb dominates the M3-1 verdict** — the Director judges the bots, not the four-player question | **High** | Purposeful `ROAM` (§7.5) and the curiosity bias (§7.6); frame the session explicitly as "no goal yet"; ask question 3 (arena) separately from question 4 (bots) |
| 2 | **Nav graph silently drifts from hand-edited geometry** | **High** | Every edge simulation-validated by the checker (test 1); graph authored in-scene so drift is visible |
| 3 | **Bots reach the Relic too reliably** and win every round before the human *(M3-2)* | **High** | Per-bot cost weights + reaction delays; a minimal `bot_skill` scalar only if needed. Real difficulty tuning is M4/M7 |
| 4 | **Curiosity bias drifts into chasing** | Medium | Region target resolved once at selection, never re-targeted; bias must sample other bots too, not only the human (§7.6) |
| 5 | **Sealed-vault rush decided by standing position** *(M3-2)* | Medium | UNLOCKING telegraph; near-equidistant doors; accept for M3 and let M4's powers create the contest |
| 6 | Four bodies make the arena feel crowded / readability fails at 36×56 | Medium | This **is** the M3-1 test. The answer is colour + labels, **never** an arena resize |
| 7 | Non-determinism from `_process` decisions or unseeded RNG | Medium | All bot decisions in `_physics_process`; all timers `delta`-based; one seeded RNG per slot; test 2 |
| 8 | **`B_Under`'s 184px rise sits at the 184.1px physical ceiling** — bots will fail it intermittently | Low | Tag that edge `skill_route`; bots may fail it and re-path. **Do not simplify it** — confirmed high-value M4 pickup spot |
| 9 | Scope creep into M3-2 during M3-1, or into M4 | Low | The banner at the top of this file, the §10.5 hard stop, and §13 |

---

## 13. Explicitly out of scope for M3

Powers (Push / Freeze / Teleport / Shield) · projectiles · implemented power pickups ·
implemented hazards · ghost/elimination mode · bot personalities or difficulty tiers ·
chasing / interference / aggression behaviours · touch or mobile controls · local
multi-controller input and device assignment · networking or backend · production art,
animation, VFX, audio · six players · menus beyond the results/rematch strip ·
progression / profile / XP · **any change to M1 movement scripts or tuning constants** ·
**any arena geometry change beyond M3-2's two vault door barriers** (specifically **not**
`B_Under`, the Pier top, or the Band C gap under the vault) · `main.tscn` productionisation ·
angled launch pads · portals.

**And, during M3-1 specifically:** the functional Relic, the gate state machine, the setup timer,
winner detection, results, and rematch (§10.5).

---

## 14. Implementation order for the next session

1. **Work item #0** — checker acknowledged-exception list + Band A membership fix. Confirm
   exit code 0 on the clean baseline. *(§2)*
2. Controller abstraction + `MatchConfig` + four slots + colours + toggleable labels +
   collision-off layer setup. *(§5, §6)*
3. `NavGraph` authoring in-scene. *(§7.1)*
4. Edge executors + Dijkstra. *(§7.2, §7.3)*
5. Checker: nav-graph edge validation; then **invert** — the checker drives the executors, and
   the four route-cost WARNs are retired. *(§7.3, §9.2)*
6. `bot_brain.gd`: `ROAM` + `RECOVER`, deterministic variation, curiosity bias. *(§7.4–§7.6)*
7. Remaining M3-1 tests. *(§9.2)*
8. Godot MCP run; confirm no errors introduced.
9. **STOP.** Hand to the Director for playtest A1 / label-off / A2 / A3, then optional A4. *(§10)*

Estimated: one session for #1–#5, one for #6–#8, then the playtest.

**Do not begin Part Two.**
