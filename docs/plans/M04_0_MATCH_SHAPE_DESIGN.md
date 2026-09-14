# M4-0 — Match Shape Design

**Status: M4-0 COMPLETE / APPROVED (2026-09-12), with Game Director amendments applied.**
**M4-1: COMPLETE / ACCEPTED (2026-09-12).** **M4-2: COMPLETE / ACCEPTED (2026-09-13).**
**M4-3: COMPLETE / ACCEPTED (2026-09-14)** — Relic carry, five locked extraction anchors,
drop-on-defeat, Mine and bot pursuit were built and automated-tested 2026-09-13, then confirmed by
Game Director human playtest 2026-09-14. Full close-out records: `docs/DECISIONS.md`. M4-4 — The
Long Match is next. This document's text below is preserved as written at M4-0 approval, per this project's
standing rule against deleting superseded text — it is the historical record of what was approved
*before* M4-1/M4-2/M4-3 were built and played.
**Post-M4-1 amendment (2026-09-12), read this before trusting §04.2/§05.6 below at face value:**
M4-1 human playtesting found that Rocket as the *only* damage source among three equally scarce
powers made reducing health too slow. **Push and Freeze now also deal 1 pip of damage on a
successful hit**, in addition to Rocket — superseding the "Push = 0, Freeze = 0" rule stated in
§04.2 and §05.6 below. Their category and non-damage identity (displacement / temporary control) are
unchanged; this is a finding about this specific power set, not a reopening of the Control/Damage
taxonomy, and does not mean every future Control power must deal damage. Full reasoning and
organic-play evidence: `docs/DECISIONS.md` (2026-09-12, "Damage-model amendment").
Written 2026-09-12, immediately after `MILESTONE 3 — CORE GAME LOOP` was accepted at commit
`de0d410`. No game code, scene, or tool was modified in producing it.

This document is the deliverable of the dedicated match-economy design session that
`docs/GAME_DESIGN.md` §25, `docs/ROADMAP.md`'s M4 section and `docs/DECISIONS.md` (2026-09-12) all
require **before** any power implementation begins. It is the authority for the M4 phase and
supersedes the M4 section of `docs/ROADMAP.md` wherever the two differ.

**It does not authorise implementation.** M4-1 is scoped here but explicitly not begun. No
gameplay code, scene, tool or project setting has been created or modified for M4.

**Amendment note.** This document was approved after review on 2026-09-12 subject to seven
amendments, all applied here: the M4-1 power set was confirmed (§06, §12); the "arena is the
primary damage source" claim was softened to an aspiration pending M4-2 evidence (§02); the
hard-cap/sudden-death resolution was withdrawn from the approved rules and reopened (§05.9); the
health visual treatment was un-specified pending STOP 3 (§04.1); an explicit rule was added that
health never prescribes player or bot behaviour (§04.4); and the extraction, respawn, phase and
STOP structures were confirmed unchanged.

---

## 00. What this document decides, and what it deliberately leaves open

**Decided by the Game Director across two review rounds (2026-09-12):**

1. Coarse 3-pip health — `Healthy → Hurt → Critical → Defeated`. No percentage bars.
2. Unlimited respawns with cost. Not limited lives.
3. Minimal authored-anchor respawn selection, plus a post-respawn protection window as a
   *prototype hypothesis only*.
4. Five authored region-relative extraction anchors, maximum-region-distance selection,
   **locked once per round** at first Relic pickup.
5. The carrier keeps their active power; on defeat the Relic drops and the unused power spills.
6. No carrier speed modification. M1 movement is preserved exactly.
7. Escalating danger zones as the first arena-as-opponent experiment, with a mandatory readable
   warning → active → safe cycle.
8. M4-1 stays one milestone with internal STOP points.
9. **M4-1's power set: Push + Rocket + Freeze** (§06). Mine → M4-3, Shield → M4-5.
10. **Health never prescribes player or bot behaviour** (§04.4). No low-health retreat, for humans
    or bots.
11. **"You don't kill your friends, you feed them to the arena" is a design aspiration, not a
    proven rule** (§02). M4-2 determines how important environmental damage actually becomes.
12. Preserved unchanged: one-use / carry-one, player↔player collision OFF, no inventory, no XP,
    no currency, no stat progression.

**Deliberately left open, to be resolved by measurement rather than argument** — the same standard
that resolved M3-2's setup duration:

- All phase timings. BUILD/ESCALATE/CLIMAX boundaries and the total match duration are
  placeholders.
- **Timeout resolution** — what happens if a match reaches its time limit (§05.9). Explicitly
  reopened at review; no candidate selected.
- **The health visual treatment** (§04.1). Determined by M4-1 STOP 3, not before.
- **How important environmental damage should become** (§02). Determined by M4-2 playtesting.
- Pickup density and respawn interval.
- Whether the post-respawn protection window becomes permanent.
- Whether access escalation alone satisfies "improve capabilities during the match", or whether a
  progression layer is needed (the M4-4 → M4-5 GATE, §07).
- Whether danger zones or wind is the better arena-threat primitive.

---

## 01. Why M4 was re-planned rather than executed as written

The M4 section of `docs/ROADMAP.md` says: implement Push, then Freeze, then Teleport, then Shield,
one at a time, tuning each. That ordering is sound. The defect is elsewhere.

**There is no match for a power to live inside.**

M3-2's own 20-round telemetry is the evidence: median OPEN→win was **~0.00s**. The accepted match
is ten seconds of sealed roaming followed by a resolution so fast that nothing can occur within it.
Push implemented into that match is not badly built — it is *unevaluable*, because no window exists
in which one player's interference can change another player's outcome.

So M4-as-written would have produced four powers that were individually implemented and
collectively impossible to judge. `docs/GAME_DESIGN.md` §25 correctly senses this. This document is
the response.

---

## 02. The load-bearing principle

The Game Director's expanded direction introduces player health alongside one-use consumed powers.
Those two systems pull against each other, and the resolution determines the shape of everything
else.

**The tension.** A health pool assumes repeated hits accumulating over time. One-use consumed
powers assume each hit is scarce and precious. Combined naively:

- **Fine-grained health (a 100% bar):** each hit costs a whole power pickup, so killing anyone
  takes many pickups and defeats essentially never happen. Health becomes decoration, and
  a wounded state is never reached often enough to be part of play.
- **Coarse health with powers as the only damage source:** you have built a health system to
  express "you can take one more hit" — a two-hit knockdown wearing a costume.

Two escape routes were rejected:

- A weak always-available basic attack to supply chip damage — adds a second input, moves Rushlings
  toward a shooter, contradicts `CLAUDE.md`'s "movement + one contextual power action".
- Reusable powers on cooldown — abandons the one-use hypothesis the Director asked to preserve.

**The accepted resolution:**

> **Health is coarse. Powers deal damage deliberately and sparingly. The arena is intended to
> become a major source and amplifier of danger.**

Stated as a design aspiration:

> ### You don't kill your friends. You feed them to the arena.

Push deals zero direct damage. It displaces — off a route, away from an extraction, and
potentially into whatever the arena is doing at that moment. Dedicated offensive powers deal
direct damage but are scarce and tiered.

**This is an aspiration, not a proven rule (Director amendment, 2026-09-12).** M4-2 has not yet
established that arena hazards are fun, and it must NOT be assumed that environmental damage has
already earned the role of the game's primary damage source. **M4-2 determines through human
playtesting how important environmental damage should actually become.**

| Direction | How the aspiration addresses it | Proven? |
|---|---|---|
| Push vs damage | Push is displacement-only; its lethality is contextual and arena-mediated. Control and damage keep distinct identities. | **Decided** |
| Arena as opponent | The arena is intended to become a major source and amplifier of danger, while powers provide deliberate player-driven interference. | **M4-2 experiment** |
| Health has meaning | Damage should arrive often enough for a health pool to be a real resource, without an unscarce basic attack. | **M4-1/M4-2 evidence** |
| One-use powers survive | Powers stay precious because they are not intended to be the damage treadmill. | **Decided** |

It is also unmistakably Rushlings rather than a shooter. "Mess with your friends" becomes literal:
the weapon is, in part, the level.

**Health must not be architected on the assumption that hazards have already succeeded.** Coarse
3-pip health (§04.1) is deliberately robust to the outcome: it works whether environmental damage
turns out to be major or minor. If M4-2 finds that danger zones are not fun, the response is
re-planned at M4-2 with that evidence — by adjusting power tier density, the damage mix, or the
arena primitive (wind remains the immediate fallback candidate) — **not** by assuming this
aspiration held.

---

## 03. What this supersedes

### From the first draft proposal of this session (never documented, recorded here for the log)

| Previously proposed | Status |
|---|---|
| Single fixed seam extraction point | **Superseded** — five dynamic region-relative anchors |
| "Own-territory extraction" as a variant | **Dropped entirely** |
| "Extraction concentrates the climax in one place" | **Superseded** — the climax is deliberately distributed and unpredictable before first pickup |
| Soft-knockdown-only combat model | **Superseded** by health / defeat / respawn |
| "No elimination" recommendation | **Fully superseded** |
| Push always knocks down | **Superseded** — Push is displacement-only, no damage, no knockdown state |
| Shield absorbs one knockdown | **Revised** — absorbs one damage instance, and deferred to M4-5 |
| M4-1 = Push only | **Superseded** — insufficient to test health/defeat |
| Recompute extraction on carrier change | **Superseded by Director decision** — locked once per round (§05.7) |
| M4-1 power set = Push + Damage + Shield | **Superseded** — Push + Rocket + Freeze (§06) |

### From existing project documentation

`docs/ROADMAP.md`'s M4 scope and acceptance criteria are superseded by §07 and §08 of this
document. Four accepted guardrails now require formal revision — see §11. **Those revisions are
proposed here, not applied.**

---

## 04. Player state model

### 04.1 Health

Three coarse states plus defeat:

```
Healthy  (3)  →  Hurt  (2)  →  Critical  (1)  →  Defeated  (0)
```

**Why coarse and not a percentage.** Four health bars on one fixed screen, over characters
deliberately designed to be tiny, contradicts `docs/GAME_DESIGN.md` §18 ("avoid health bars") and
the §19 readability hierarchy. A percentage also implies many small damage sources, which is the
shooter shape `CLAUDE.md` rules out. Three states are readable at a glance across the whole arena,
which is the entire point of the fixed camera.

**Readability requirement — the visual treatment is deliberately NOT specified (Director
amendment, 2026-09-12).** The actual, binding requirement is:

> Health state must be immediately readable at normal full-arena gameplay scale, without
> introducing a conventional percentage health bar.

Everyone should be able to see who is wounded from across the arena — that is what makes hunting a
weakened player a *social* act rather than a private number. **How** that is achieved is open.
Candidate treatments, recorded as examples and hypotheses only, none selected:

- small dots or pips near the character
- a ring or outline treatment
- a segmented indicator
- character-integrated treatment (dimming, cracking, flicker, silhouette change)
- another solution found during prototyping

**M4-1 STOP 3 determines the visual treatment through human playtesting.** Do not lock it before
then.

### 04.2 Damage sources

**SUPERSEDED at M4-1 (2026-09-12) for Push and Freeze — see the status banner at the top of this
document and `docs/DECISIONS.md`'s "Damage-model amendment".** The table below is preserved as
originally approved.

| Source | Damage (as originally approved) |
|---|---|
| Arena hazard contact | 1 |
| Offensive power hit (Rocket) | 1 |
| Push | ~~0~~ → **1** (M4-1 amendment) |
| Freeze | ~~0~~ → **1** (M4-1 amendment) |
| Falling | **0** (unchanged) |

**Every damage instance is exactly 1 pip.** A universal rule beats special cases for readability.

**Falling deals no damage, deliberately.** Adding fall damage would retune accepted M1 movement
feel, and M1 is closed (`docs/DECISIONS.md`, 2026-09).

**Impact damage (being slammed into geometry) is deferred, not rejected.** It would make Push
directly lethal, but requires a velocity threshold that never misfires during ordinary movement —
and getting that wrong makes M1 movement feel punishing. Hazard-delivery already gives Push its
lethal identity. Revisit only if Push reads as too weak after M4-2's hazards exist.

### 04.3 Defeat and respawn

**Unlimited respawns with cost. Not limited lives.** The comparison that decided it:

| | Limited lives (~3) | Unlimited respawn with cost |
|---|---|---|
| Dead-player experience | A player eliminated at 60s watches for a minute — **violates `docs/GAME_DESIGN.md` §11** ("nobody should sit watching a match for long") | Back in play within seconds |
| Snowballing | Severe — the losing player is removed from their own comeback | Self-limiting |
| Code cost | Elimination state, spectator handling, "last player standing" end condition, plus interaction with the Relic objective | Reset position, clear power, resume |
| Reversibility | Hard to remove once players expect it | Trivial to add lives later |

The cost of a defeat is already substantial: a few seconds out of play, your carried power spills,
your position is lost, and the Relic drops if you held it. That is real without removing anyone
from the room.

**Respawn location — minimal authored-anchor selection.** Reuse the four existing `Spawn1–4`
markers in `scenes/arena_01/arena_01.tscn`. On respawn, select the anchor **furthest from the
nearest living opponent**.

This is deliberately the smallest version. A full anchor-scoring framework would be solving a
problem that has not yet been observed, and the project's standing precedent is that measurement
precedes balancing (`docs/DECISIONS.md`: route-cost and fairness measurement are "diagnostic, not
normative"). If playtesting shows four anchors are insufficient, add anchors and a real score
**then**, with evidence. Never arbitrary world coordinates.

**Post-respawn protection window — PROTOTYPE HYPOTHESIS, NOT PERMANENT.** A ~0.75–1.0s window
during which a respawned player cannot take damage, prototyped in M4-1. It must not be treated as
a shipped rule without playtest evidence. Recorded so a future session does not mistake it for an
accepted mechanic.

**No sophisticated spawn director.** The minimal rule above is the whole design. Do not plan,
scope or build a weighted multi-factor spawn selection system.

### 04.4 Health does not prescribe behaviour — EXPLICIT RULE

**Health is information and vulnerability. It is not a behavioural state.**

Any rule or assumption of the form *"low health → retreat / hide / disengage"* is **explicitly
rejected** (Director amendment, 2026-09-12).

At Critical health a player remains completely free to attack, chase another player, collect a
power, contest the Relic, take a risky route, hide, escape, or deliberately play aggressively.
Being on one pip is a *situation the player reads and responds to as they choose*, not a mode the
game puts them in.

**Binding consequences for implementation:**

- **Do not alter human movement, available actions, inputs or power access based on health.** The
  only state that changes what a player can do is `Defeated` at zero.
- **Do not add automatic low-health retreat behaviour to bots.** A bot must not become defensive
  simply because it has one pip remaining. There is no low-health flee goal, no defensive mode, no
  threat-avoidance weighting keyed to health.
- Health may be *read* by systems that display it. It must not be read by systems that decide what
  a player or bot is allowed or inclined to do.

**Future scope, explicitly not M4:** if bot personalities or strategies are introduced later,
different bots may legitimately make different risk decisions — including cautious ones. That is a
future bot-intelligence question (`docs/GAME_DESIGN.md` §13, §24) and **is not an M4-0 or M4-1
rule**. Nothing in M4 may pre-empt it.

---

## 05. The match model

### 05.1 Powers — one-use, carry-one

**Preserved as the current hypothesis:**

> One carried active power → one use → empty → collect again.

The properties this buys, at no cost:

- Pickups stay valuable for the **entire** match, so collection routes matter during the climax
  too — not only early.
- Every use is a decision. *Do I spend my Rocket on P3 now, or save it for whoever takes the
  Relic?* That is precisely the fight-or-build tension `docs/GAME_DESIGN.md` §25 asks for, with no
  economy attached.
- Combat frequency is throttled by **scarcity**, not by an explicit cooldown rule, so it never
  reads as a combat game with a rate limit.
- Using a power disarms you and pulls you back into the arena to rearm — away from the objective.

### 05.2 Power taxonomy

Functional categories, for organising the design space. **This is a taxonomy, not an
implementation list.**

| Category | Does | Examples | Deals damage? |
|---|---|---|---|
| **Control** | Denies or redirects movement | Push, Freeze, forced Teleport | No |
| **Damage** | Reduces health directly | Rocket / projectile, blast | Yes |
| **Denial** | Placed, persistent, rewards prediction | Mines, traps | Yes |
| **Defense** | Negates incoming harm | Shield, rotating shield | — |
| **Mobility** | Improves your own traversal | Self-teleport, dash, personal launch | No |
| **Summon** | Autonomous agent | Golem, pet, guardian | Yes |

**Summons are parked hardest of all.** A golem or pet needs its own navigation — a fifth AI on top
of a bot system that already cost two milestones and left four deferred navigation findings
(`docs/DECISIONS.md`, 2026-09-12). Not an M4 candidate at any stage.

### 05.3 Power tiers — how access escalation works

| Tier | Available from | Where it spawns | Examples |
|---|---|---|---|
| **Tier 1** | BUILD | Common, easy routes | Push, Shield |
| **Tier 2** | ESCALATE | Contested, hard-to-reach spots | Freeze, Mine, Mobility |
| **Tier 3** | CLIMAX | Rare, most exposed positions | Rocket, heavy blast |

Tier gating is a spawn table keyed to match time. Small code, no persistent player state, and it
delivers "players begin relatively weak" and "contest valuable locations" without an inventory or
upgrade tree.

The Tier 2/3 spawn locations should be the spots `docs/DECISIONS.md` (2026-09-06) already
identified as *"intentionally hard to reach, high pickup value"* — `B_Under`, `Pier`, the upper
bands, the vault header.

### 05.4 Loot spill — no separate resource layer

> On defeat, a player's carried active power spills into the arena as a world pickup. **That is the
> loot.**

Why this is sufficient, and why a currency should not be added:

- With one-use powers, a spilled power is genuinely valuable. Defeating someone carrying a Tier-3
  Rocket and taking it is a legible, dramatic prize.
- It reuses the pickup entity that must exist anyway. Zero new systems.
- A separate currency would need a per-player counter, a HUD readout, a spend mechanism, and bot
  valuation logic — all four are precisely what the Director ruled out introducing automatically.

**A defeated carrier drops both the Relic and their power**, making the carrier the most rewarding
target in the match. That is the correct incentive shape for a climax.

### 05.5 Arena as opponent

**First experiment: escalating danger zones.** Authored `Area2D` zones activating in waves as the
match escalates.

The constraint that decided this: **the hazard must be something Push can deliver a player into.**
Otherwise arena-as-opponent is texture rather than opponent, and the Push-identity decision goes
untested.

| Candidate | Verdict |
|---|---|
| **Escalating danger zones** | **Approved for M4-2.** Cheap, escalates trivially, creates late-match area denial that reshapes routes, damages, and is exactly what Push delivers you into. |
| Blowers / wind | **Immediate follow-up candidate.** Best exploits M1 air-steering and modulates routes continuously — but non-damaging, so it tests arena-as-*texture*, not arena-as-*opponent*. |
| Moving hazards | Cheap, but mostly a timing obstacle; weak power interaction. |
| Slippery / environmental Freeze | Really a *power* effect, not an arena threat. Belongs in the taxonomy above. |
| Roaming creatures / guardians | Expensive — needs its own navigation. Parked. |

**Mandatory: a readable warning → active → safe cycle. No invisible damage.** A zone must
telegraph before it becomes lethal, be unmistakably lethal while active, and be unmistakably safe
afterwards. This is a hard requirement, not polish — an unsignalled hazard reads as a bug and
poisons the experiment.

**Known risk:** damaging zones in a greybox may read as arbitrary punishment rather than as an
opponent. If that is how it plays, wind is the fallback, and the finding itself is valuable.

### 05.6 Push vs damage — distinct identities

**Direct damage row SUPERSEDED at M4-1 (2026-09-12)** — Push now deals 1 pip too (see the status
banner at the top of this document). The rest of the table, and the design goal it states, are
unchanged: Push's identity is still its displacement effect, not its damage.

| | Push | Rocket |
|---|---|---|
| Category | Control | Damage |
| Direct damage | ~~0~~ → **1** (M4-1 amendment) | 1 |
| Effect | Displacement impulse | Health reduction |
| Lethality | Contextual — via hazard delivery, now also direct | Direct |
| Skill | Positional / environmental manipulation | Ranged pressure and firing lines |

Preserving this split is a design goal, not an accident. Control powers move and deny; damage
powers hurt. A control power that also chips health would collapse the distinction and push the
game toward a brawler.

### 05.7 The Relic and the extraction portal

**Winning requires: grab the Relic → carry it to the activated extraction → survive the trip.**

The carrier is loud and unmistakable. A defeated carrier drops the Relic, which falls under gravity
and re-enters contest after a brief re-grab lockout.

#### Extraction anchors

**Five authored anchors — one per existing arena region.** `scripts/arena_regions.gd` already
defines exactly five regions (`floor`, `west`, `central`, `east`, `seam`) arranged as a wrap-aware
loop in `REGION_ORDER`, and already ships `region_distance()` returning circular distance over that
loop. Extraction anchors map one-to-one onto them. **Never arbitrary world coordinates.**

#### Selection rule — ONCE PER ROUND

When the Relic is picked up **for the first time in a round**:

1. Determine the first carrier's current region.
2. Select the authored anchor at **maximum region-distance** from that region.
3. Resolve ties with deterministic per-round seeded RNG.
4. Activate and reveal that extraction portal to all players.
5. **Lock it for the remainder of the round.**

Working the actual `REGION_ORDER` loop (`west, floor, central, east, seam`), every region yields
exactly **two** maximally-distant candidates:

| First grab happens in | Extraction activates at |
|---|---|
| **central** (the vault) | west **or** seam |
| floor | east **or** seam |
| west | central **or** east |
| east | west **or** floor |
| seam | floor **or** central |

#### The extraction MUST NOT move after selection

It does not recalculate on: carrier defeat · Relic drop · another player picking up the Relic ·
Relic ownership changing repeatedly · player respawn.

Worked example, as specified by the Game Director:

```
P1 picks up Relic       → West extraction activates
P1 defeated, Relic drops → West extraction remains
P3 picks up Relic        → West extraction remains
P3 defeated, P4 picks up → West extraction remains
```

Selection happens again only when a new round begins and that round's Relic is picked up for the
first time.

**Why locked, not dynamic.** The design goal is *unpredictable before first pickup → clearly
revealed → strategically stable for the rest of the climax.* Once revealed, all players share one
destination and can make real strategic decisions around it: the carrier chooses a route, opponents
intercept, players defend chokepoints, traps are placed along predicted routes, players race ahead.
A relocating extraction would destroy objective readability and make prediction meaningless — and
prediction is the thing Rushlings is built on (`docs/GAME_DESIGN.md` §2).

#### What this satisfies

- **Not campable before pickup** — the anchor is a function of where the grab happens, which nobody
  knows in advance.
- **Minimum distance guaranteed by construction** — always two region-hops. No separate distance
  rule needed.
- **Accounts for carrier position** — yes, and in the direction that forces travel.
- **Fair** — computed relative to the carrier, so no player has a structurally shorter carry. P2's
  recorded spawn-proximity advantage (`docs/DECISIONS.md`, 2026-09-09) no longer compounds.
- **Learnable rather than lucky** — a skilled player knows a vault grab means west-or-seam and can
  start moving on a 50/50 read before the beacon resolves. Arena knowledge is rewarded.

#### Informing players

The anchor structure physically activates — rises, lights, opens — plus a short global flash and
sound. **Because the fixed camera shows the entire arena at all times, that is the notification.**
No minimap, no HUD element. A direct payoff from the §4 guardrail.

#### Roof camping, revisited

A vault grab is a *central*-region grab, which guarantees the extraction activates at maximum
distance. The roof camper now takes the Relic first and immediately faces the longest possible
carry, from the most exposed platform in the arena, at three pips, against three converging
players.

Camping becomes a legitimate opening with a real cost — a **structural** answer to the question
`docs/DECISIONS.md` (2026-09-12) left open, rather than the hoped-for combat counterplay. **It
still requires human playtesting before being recorded as solved**, to the same standard every
prior milestone was held to.

### 05.8 Match shape

```
BUILD       Relic sealed. Tier 1 powers on ordinary routes. Few or no hazards.
            Explore, collect, skirmish. Defeat costs tempo and your power.
     ↓
ESCALATE    Tier 2 powers spawn at contested hard-to-reach spots.
            Danger zones begin activating. The vault begins telegraphing.
     ↓
CLIMAX      Relic opens. Tier 3 powers appear. Hazards at maximum.
            First grab → an extraction anchor activates far away and LOCKS →
            cross the arena at three pips while everyone hunts you.
     ↓
WINNER      Extraction reached.  (Timeout resolution is OPEN — see §05.9.)
```

Two escalation curves run together: **player capability** (by access tier) and **arena threat** (by
hazard schedule).

**All timings are placeholders to be measured, not argued** — exactly as M3-2's 10s setup was
resolved by engine measurement rather than debate. Working hypothesis only: BUILD ~0–40s,
ESCALATE ~40–75s, Relic opens ~75s, total match duration ~120s. **Do not encode these as
production rules**, and note that what *happens* at the time limit is a separate open question
(§05.9).

### 05.9 Timeout resolution — OPEN, NOT DECIDED

**The approved core objective:**

> Relic pickup → extraction activates once → extraction locks for the round → carrier attempts
> extraction → carrier defeat drops the Relic → another player can continue toward the **same**
> extraction.

**Extraction reached → that player wins.** That is the only approved end condition.

**What happens when a match reaches its time limit is deliberately unresolved (Director
amendment, 2026-09-12).** The previously proposed rule — *hard cap with a carrier → the holder
wins; hard cap with no carrier → sudden death by first touch* — is **WITHDRAWN and NOT APPROVED**.
It must not be implemented, and must not be treated as a default by a future session.

The ~2-minute duration remains a hypothesis. Timeout resolution is a separate open question.
Candidate experiments, **recorded without selecting one**:

- the current carrier wins
- overtime
- the extraction remains active while arena pressure escalates
- some other sudden-death structure
- another evidence-driven solution not yet identified

**Do not design or implement the answer now.** This is resolved by evidence at M4-4, when real
match pacing is measured for the first time.

---

## 06. The M4-1 power set — the decision and its reasoning

Two candidate sets were compared.

**Candidate A: Push + Damage + Shield** — categories Control / Damage / Defense.
**Candidate B: Push + Rocket + Mine** — skills positional / aim / prediction.

### Shield is deferred to M4-5

In M4-1, Shield is either:

- **Passive** (auto-absorbs the next hit) — which tests nothing about the contextual action verb,
  or
- **Manually timed** — which, against scarce one-use ranged attacks, is nearly impossible to time
  and yields almost no signal.

Shield is counterplay to a threat density that does not exist until M4-2's hazards and M4-5's wider
power set. Candidate A is rejected.

### Mine is promoted to M4-3, not included in M4-1

Mines are one of the highest-fit mechanics in the whole taxonomy — but M4-1 is the one context
where they cannot work.

> Mines reward predicting **where someone must go.** In M4-1 there is no Relic carry, no locked
> extraction, and no objective — nobody is going anywhere predictable.

The locked-extraction decision in §05.7 is what creates predictable routes, and it arrives in
**M4-3**. Testing mines in M4-1 risks a false negative on an excellent mechanic. Mine is also the
most expensive candidate on both constraints identified as binding (§09):

- **Bot cost is high** — bots need dynamic path avoidance injected into `_weighted_cost()` in
  `scripts/bot_brain.gd`, or three of four players walk into mines repeatedly and mines read as
  overpowered.
- **Readability cost is high** — a placed mine is a small static shape among other small static
  shapes (pickups) at greybox scale.

### Comparison

| | Impl cost | Bot cost | Readability cost | Distinct feel | Testable in M4-1? |
|---|---|---|---|---|---|
| **Push** | Low — reuses `receive_launch()` in `scripts/player.gd` | Low | Low | "I moved you" | Yes |
| **Rocket** | Medium | Medium | Medium | "I hit you" | Yes |
| **Freeze** | **Low** — reuses defeat's input-lock and health's state channel | Low | Low | "I stopped you" | Yes |
| Mine | Medium-high | **High** | **High** | "I predicted you" | **No** |
| Shield | Low | Low | Medium | "I survived you" | Weakly |

### DECISION — M4-1 ships Push + Rocket + Freeze

Three distinct feels, the cheapest possible third power, and full coverage of M4-1's actual
question.

**Freeze is unusually cheap here because it shares infrastructure M4-1 must build anyway:** the
input-lock that defeat requires, and the character-state readability channel that 3-pip health
requires. It also sets up M4-2 directly — freezing a player beside an activating danger zone is the
§02 pillar in miniature.

**Mine → M4-3. Shield → M4-5.**

### Two caveats on Rocket, recorded so they are not rediscovered later

1. **Rocket cannot test aim skill in M4-1.** True aim needs an aiming input, which the "movement +
   one contextual power action" guardrail forbids and M5 has not solved. Rocket must fire in facing
   direction. It tests *ranged pressure*, *positioning to create a firing line*, and the
   roof-camper counterplay hypothesis — **not aim**. That limitation is itself a useful early
   finding for M5.
2. **M4-1 has no hazards, so powers are the only damage source.** At 1 damage per hit and 3 pips, a
   defeat costs three separate pickups across four competing players — defeats may be too rare to
   validate the spill/respawn chain organically. Mitigations, both explicitly test-harness
   measures: treat **pickup density as an M4-1 tuning knob** (not a shipping value), and add a
   **debug damage key** to exercise the defeat → spill → respawn chain mechanically. Organic defeat
   frequency then becomes a *measured finding* of M4-1, in the same spirit as M3-2's setup-duration
   measurement.

---

## 07. Revised milestone sequence

**M4 is a phase, not a milestone.** `docs/ROADMAP.md` should say so, or it will keep reading as
nearly-done.

| | Stage | The one question it answers | Contents |
|---|---|---|---|
| **M4-0** | **Match Shape Design** | *What is a Rushlings match?* | This document. No code. |
| **M4-1** | **Contact** | **Does hurting each other feel good?** | Push + Rocket + Freeze · one-use, carry-one, pickup · 3-pip health · defeat → spill → respawn · minimal safe-respawn · protection-window prototype. No Relic change, no hazards, no long match. |
| **M4-2** | **The Arena Bites** | **Does arena-as-opponent improve the game?** | Escalating danger zones with warning → active → safe cycle. First real test of Push-is-displacement-only. |
| **M4-3** | **The Climax** | **Does carry-to-locked-extraction produce a great ending?** | Relic carry · five region anchors · once-per-round locked selection · drop-on-defeat · **Mine**. |
| **M4-4** | **The Long Match** | **Does ~2 minutes hold attention?** | Phase clock · Tier 1/2/3 access schedule · hazard escalation schedule · real timing measurement. No new powers. |
| **GATE** | **Progression judgment** | *Is access escalation enough?* | Play M4-4. Decide whether stat progression is needed. Deferred Director decision. |
| **M4-5** | **Broader Power Set** | *Do the categories stay distinct at scale?* | Shield, Teleport, Mobility. Conditional on M4-1 succeeding. |
| **M4-6** | **Economy** | *Only if the GATE says yes* | Resources, levels, charges. Designed against evidence, never imagination. |

### Why hazards come before the climax

Push has no lethal identity until something exists to push people into. Testing the climax before
hazards would mean judging a version of combat that is not the intended shipping version, risking a
false negative on Push.

**The cost of this ordering:** there is no complete playable game until M4-3 rather than M4-2. That
is a real trade-off and the Game Director may overrule it.

### Why M4-1 bundles three validation targets

Interference feel, health/defeat/respawn, and pickup scarcity are **not separable experiments** —
you cannot test health without damage, damage without powers, or scarcity without one-use. They run
as one milestone with internal STOP points, the way M3-2 used five (`docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md` §19).

---

## 08. M4-1 scope and STOP points

**Not authorised to begin.** Scoped here so the next session has an unambiguous starting point.

### In scope

- Power pickup entity: touch to collect, carry one, replaces current.
- Three powers: **Push** (displacement, 0 damage), **Rocket** (facing-direction projectile, 1
  damage), **Freeze** (input-lock for a short duration, 0 damage).
- One-use consumption: use → empty → collect again.
- 3-pip health with character-integrated readability.
- Defeat → power spills as a world pickup → respawn at the furthest-from-nearest-opponent anchor.
- Post-respawn protection window (~0.75–1.0s), flagged as a prototype hypothesis.
- Bot goals at the existing `_decide_next()` seam: `SEEK_PICKUP`, `USE_POWER` (simple trigger:
  opponent in range and roughly in front), plus passive defeated/respawn handling. **No
  health-driven behaviour of any kind** — see §04.4.
- Extended roam phase so interference has room to occur.
- Test-harness knobs: pickup density, debug damage key.

### Out of scope for M4-1 — explicitly

- Relic carry, extraction anchors, the locked-extraction rule (**M4-3**).
- Arena hazards or danger zones (**M4-2**).
- Phase clock, tier gating, the ~2-minute match (**M4-4**).
- Mine (**M4-3**), Shield / Teleport / Mobility (**M4-5**).
- Inventory, XP, currency, stat progression, upgrade levels (**M4-6 at the earliest, conditional**).
- Impact damage, fall damage.
- Timeout resolution (§05.9) — open, and not to be defaulted.
- Any low-health behaviour for humans or bots (§04.4).
- A weighted or multi-factor spawn director.
- Carrier speed modification.
- Player↔player collision — stays **OFF**.
- Any change to M1 movement, M2 geometry, or M3 navigation.

### STOP points, in order

| STOP | Validates | Gate |
|---|---|---|
| **1** | Pickup and scarcity | One power carried, collected by touch, replacement reads clearly, empty-after-use is legible. |
| **2** | Interference | Push, Rocket and Freeze each land, read clearly, and feel distinct from each other. |
| **3** | Health readability | Can Healthy / Hurt / Critical be understood at normal full-arena scale, without a percentage bar? **This STOP selects the visual treatment** (§04.1) — it is not chosen in advance. |
| **4** | Defeat, spill and respawn | Does defeat have consequence without being frustrating? Is the spilled power understandable and contestable? Does respawn placement avoid camping? Is the protection window worth keeping? |
| **5** | Final acceptance | Human playtest. Does player-to-player interference actually make Rushlings more fun? |

### Regression requirements

`tools/arena_check.gd` and `tools/m3_check.gd` must both still pass before M4-1 is accepted, per
the standing rule. The four known, deferred `m3_check.gd` edge-sampling findings
(`docs/DECISIONS.md`, 2026-09-12) remain acknowledged, not silently patched.

---

## 09. Known risks

1. **Readability is now the binding constraint, not code.** One fixed screen must carry four tiny
   characters, their health states, carried-power indicators, pickups at three tiers, active
   hazard zones, a carried Relic, and an extraction beacon. `docs/GAME_DESIGN.md` §19's hierarchy
   will be under real pressure. Expect at least one milestone spent on readability alone, and plan
   for it rather than discovering it.
2. **Bot cost is the largest hidden number.** Bots will eventually need: seek pickup, use power,
   chase carrier, carry to extraction, and handle defeat and respawn — plus **hazard avoidance**,
   the one genuinely expensive addition. Navigation alone took two milestones and ~39K of
   `scripts/bot_brain.gd`. Build hazard-avoidance crudely on purpose, and say so, rather than
   letting it become a second `bot_brain.gd`. **Low-health retreat is NOT on this list and must not
   be added** — see §04.4.
3. **The stalemate case.** With unlimited respawns and a droppable Relic, a carrier can be defeated
   near extraction repeatedly and nobody ever extracts. **There is currently no approved rule that
   resolves this**, because timeout resolution is open (§05.9) — that is a known, accepted gap to
   be closed with M4-4 evidence. Levers held in reserve if it proves common: a brief grace period
   on pickup, or a carrier speed change — **named here, deliberately not designed**.
4. **Rocket's aim limitation may under-sell ranged combat** until M5 resolves mobile controls.
5. **Danger zones may read as arbitrary punishment** in greybox. Wind is the fallback.
6. **M4 is now six stages.** Treating it as one milestone will produce schedule surprise.

---

## 10. What is preserved unchanged

- M1 movement language and tuning — closed, not reopened.
- M2 Arena 01 geometry — no changes proposed by this document.
- M3 navigation: the nav graph, `Floor→C_M`, the RELIABLE/SKILL policy, vault traversal, ladders,
  wrapping.
- Player↔player collision **OFF**. Push remains the only thing that can move another body, so every
  interference event is deliberate and readable — which fits "predict them and interfere with them"
  better than incidental jostling.
- One human + three bots as the development configuration.
- Four player slots; six remains an exploration.
- No inventory, XP, currency, or stat progression.

---

## 11. Documentation edits — APPLIED 2026-09-12

The expanded direction contradicts several accepted guardrails. Unless they are formally revised,
a future session would read them and reject this plan as out of scope. **These edits were applied
on 2026-09-12 at M4-0 approval.** History is preserved throughout — superseded M3-era assumptions
are marked as superseded rather than deleted.

| Document | Section | Revision applied |
|---|---|---|
| `docs/GAME_DESIGN.md` | §7 / new §7A | §7 banner-marked as M3-era and superseded in part; §7A added carrying the approved `BUILD → ESCALATE → CLIMAX` match and the open timeout question. |
| `docs/GAME_DESIGN.md` | §8 / new §8A | §8's first-touch objective marked M3-era; §8A added with the carry-to-extraction objective, the five region anchors, the once-per-round locked-extraction rule and its region table. |
| `docs/GAME_DESIGN.md` | §10 Power Rules | One-use consumption made explicit; category and tier taxonomy added; loot-spill rule added; carry-one/replace retained. |
| `docs/GAME_DESIGN.md` | §11 → "Health, Defeat, Hazards / Respawn" | Old "should not eliminate players" preserved as a labelled superseded block; coarse 3-pip health, the unchosen visual treatment, the no-prescribed-behaviour rule, unlimited respawns, minimal respawn placement and the arena-as-aspiration all added. |
| `docs/GAME_DESIGN.md` | §13 Bots | Explicit constraint added: bots must never retreat because of low health. |
| `docs/GAME_DESIGN.md` | §18 HUD / UI | "Avoid health bars" retained and qualified — three coarse states, never a percentage bar, treatment chosen at STOP 3; extraction communicated by the arena, not a HUD element. |
| `docs/GAME_DESIGN.md` | §25 | Status banner added: partially resolved, listing what M4-0 approved, what stays open, and what was explicitly rejected. Original text preserved. |
| `CLAUDE.md` | Read First · Current Status · new Milestone 4 section · Guardrails · Immediate Next Milestone | Read-First path extended to five documents; M4 status block added; guardrails rewritten for one-use powers, health, defeat/respawn, the locked extraction, the aspiration wording and the open timeout question. |
| `docs/ROADMAP.md` | M4 | Replaced wholesale with the seven-stage phase, the M4-1 scope and STOP points, open questions and known risks. M3 close-out pointer and parking-lot entry updated. |
| `docs/DECISIONS.md` | ten new 2026-09-12 entries | M4-0 approval · the M4-1 power set and why Shield/Mine were deferred · the aspiration correction · health-never-prescribes-behaviour · 3-pip health · unlimited respawns · the locked extraction · the withdrawn timeout rule · one-use powers and tiers · known risks. |

---

## 12. Decision log — 2026-09-12

| # | Decision | Status |
|---|---|---|
| 1 | Coarse 3-pip health, character-integrated readability, no percentage bars | **APPROVED** |
| 2 | Unlimited respawns with cost; limited lives rejected for a ~2-minute match | **APPROVED** |
| 3 | Minimal authored-anchor respawn using existing spawns, furthest-from-nearest-opponent | **APPROVED** |
| 4 | ~0.75–1.0s post-respawn protection window | **PROTOTYPE HYPOTHESIS ONLY** |
| 5 | Five region-relative extraction anchors, max-region-distance selection | **APPROVED** |
| 6 | Extraction locked once per round at first pickup; never relocates | **APPROVED — Director revision** |
| 7 | Carrier keeps their power; on defeat the Relic drops and the power spills | **APPROVED** |
| 8 | No carrier speed modification; M1 movement preserved exactly | **APPROVED** |
| 9 | Escalating danger zones as the first arena experiment, warning → active → safe mandatory | **APPROVED** |
| 10 | Wind/blowers as the immediate follow-up candidate | **RECORDED** |
| 11 | M4-1 as one milestone with internal STOP points | **APPROVED** |
| 12 | M4-1 power set = Push (control/displacement) + Rocket (direct ranged damage) + Freeze (movement/control denial) | **APPROVED** |
| 13 | Mine deferred to M4-3 (where the locked extraction creates predictable routes); Shield deferred to M4-5 (when enough threat density exists to evaluate defense) | **APPROVED** |
| 14 | Loot spill = the carried active power only; no separate resource layer | **APPROVED** |
| 15 | Push deals 0 damage; Rocket deals direct damage; Freeze deals 0 damage | **APPROVED** |
| 15a | "You don't kill your friends. You feed them to the arena." as a design aspiration | **APPROVED as aspiration** |
| 15b | The arena as the game's *primary* damage source | **NOT APPROVED — M4-2 must prove it (§02)** |
| 15c | Hard-cap / sudden-death timeout resolution | **WITHDRAWN — open question (§05.9)** |
| 15d | Health never prescribes player or bot behaviour; no low-health retreat | **APPROVED (§04.4)** |
| 15e | Health visual treatment | **OPEN — determined by M4-1 STOP 3 (§04.1)** |
| 16 | Impact damage and fall damage deferred | **RECORDED** |
| 17 | One-use / carry-one, collision OFF, no inventory / XP / currency / stat progression | **PRESERVED** |

---

**END — M4-0 MATCH SHAPE DESIGN. COMPLETE / APPROVED 2026-09-12.**
**M4-1: COMPLETE / ACCEPTED. M4-2: COMPLETE / ACCEPTED. M4-3: COMPLETE / ACCEPTED (2026-09-14) — see
`docs/DECISIONS.md` (2026-09-13/14) for the full record. M4-4 — The Long Match is next.**
