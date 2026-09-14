# M4-3 — The Climax: implementation record

**Status: COMPLETE / ACCEPTED (2026-09-14).** Built by an autonomous Claude Code session on
2026-09-13, working from the M4-3 session brief (`CLAUDE.md`'s "Milestone Session Protocol" plus the
M4-3-specific instructions handed to that session directly — the brief itself is not duplicated
here; this document records what was actually built, tested, and found). That session was authorized
to implement, automated-test and headless-soak M4-3, but explicitly not to declare it accepted,
permanently tune extraction fairness, redesign Arena 01, start M4-4, or introduce additional powers.
**A subsequent session confirmed Game Director human playtest acceptance and closed M4-3 out
2026-09-14** — see `docs/DECISIONS.md` (2026-09-14) for the acceptance record, the `tools/m3_check.gd`
checker-contract update, and the M4-4 handoff. Everything below is the original implementation
record as written 2026-09-13 and is preserved unchanged.

**Authority for the design this implements:** `docs/plans/M04_0_MATCH_SHAPE_DESIGN.md` §05.7/§06/§09
and `docs/GAME_DESIGN.md` §8A. Full narrative close-out: `docs/DECISIONS.md` (2026-09-13, "M4-3 The
Climax" entry) — that entry is the canonical record; this document is the implementation reference
a future session should read before touching M4-3 code.

---

## 1. Relic carry architecture

**One physical Relic node, three states, never two at once.**

`scripts/relic.gd` (rewritten from the M3-2 first-touch-wins version) is a single `Area2D` that is
either:
- **At the pedestal**, dim, inert (`carrier_slot_id == -1`, `SETUP`/before-OPEN) or bright and
  collectible (`OPEN`, nobody has grabbed it yet this round);
- **Carried** — hidden (`visible = false`), `carrier_slot_id` set to the carrier's slot; the actual
  "who has it" flag lives on `player.gd` (`is_carrying_relic`, `receive_relic()`, `drop_relic()`),
  exactly mirroring how `carried_power` already works; or
- **Dropped** — repositioned to the defeated carrier's position, visible and collectible again,
  `carrier_slot_id == -1`.

No second Relic instance is ever created, and the node is never reparented onto a carrier. Touch
detection is a poll (`_physics_process`, not `body_entered`) — see §7 below for why, and for the
staleness bug this session found and fixed.

`nav_node` (a plain string field on `relic.gd`) tracks which nav-graph node the Relic is currently
associated with — `"VaultFloor"` at the pedestal, or the defeated carrier's `canonical_platform()` on
a drop — so `BotBrain` can target a dropped Relic through the existing RELIABLE-only routing policy
without any new spatial-query code (the same convention `health_system.gd`'s `_spill_power()` already
uses for a spilled power).

## 2. Extraction anchors and selection algorithm

**Five authored anchors**, one per `ArenaRegions.REGIONS` region, each a
`scenes/extraction/extraction_anchor.tscn` instance under `$ExtractionAnchors` in
`arena_01.tscn`:

| Region | Nav node | Position | Why this node |
|---|---|---|---|
| `floor` | `Floor` | (1700, 932) | The floor's own huge, always-RELIABLE platform; placed east of `Hazard_Floor`'s footprint (x 1040–1260) and clear of every spawn/pickup. |
| `west` | `Pier` | (780, 150) | RELIABLE via `A_W`→`A_W_Bridge`→`Pier`; not the Relic chamber, not a hazard footprint. |
| `central` | `C_M` | (1150, 792) | RELIABLE via `Floor`→`C_M` (the sole fixed-trigger route); deliberately NOT `C_W`, which hosts `Hazard_CW`. |
| `east` | `A_E_Bridge` | (1558, 272) | RELIABLE via `A_E`↔`A_E_Bridge`/`B_E` ladders; deliberately NOT `A_E`, which hosts `Hazard_AE`. |
| `seam` | `C_Seam` | (1880, 792) | A RELIABLE hub node (`C_M↔C_Seam`, both `LadE` ladders, `B_Seam→C_Seam`); not `B_Seam`, which has no reliable outgoing edge. |

Every anchor's `nav_node` was checked against `NavGraph.reliable_reachable_from()` before being
chosen — confirmed automatically by `tools/m4_3_check.gd`'s own reachability assertion, not just by
inspection.

**Selection** (`scripts/extraction_system.gd`): on the Relic's first pickup of a round
(`relic.picked_up` → `arena_01.gd`'s `_on_relic_picked_up()` → `extraction_system.on_relic_picked_up()`):
1. Look up the carrier's canonical region via `geometry.canonical_platform()` + `ArenaRegions.region_of()`.
2. Score every region by `ArenaRegions.region_distance()`; keep only the maximum-distance
   candidate(s).
3. If more than one candidate ties (always true for this 5-region loop — every region has exactly
   two maximally-distant neighbours), break the tie with a `RandomNumberGenerator` seeded from
   `round_seed` (set once per round by `arena_01.gd`, the same `_round_base_seed() + <offset>`
   convention `BotBrain` already uses — never runtime randomness).
4. Activate the winning anchor (`extraction_anchor.activate()`: becomes visible, monitoring the
   carrier), lock `ExtractionSystem.locked = true`.

Locked selection is **never** recomputed — not on carrier defeat, Relic drop, a new carrier, or
respawn — only `reset()` (wired to `MatchDirector`'s `SETUP` transition, alongside `relic.gd`'s own
reset) clears it, once per round.

## 3. Carrier/drop behaviour

On defeat (`health_system.gd`'s `_finish_defeat()`), if the target `is_carrying_relic`, a **second,
independent branch** (not merged with the power-spill branch immediately above it) calls
`relic.drop_at(target, target.global_position, canonical_platform_or_empty)`. Both a spilled power
and a dropped Relic can result from the same defeat, as two separate world objects — verified
automatically (`tools/m4_3_check.gd`'s `_test_defeat_relic_and_power_independent`).

The reaction window (M4-2's 0.4s visible-lethal-hit beat) applies identically: the Relic is not
dropped until `_finish_defeat()` actually runs, so a killing blow's own effect (a Push's
displacement, a Freeze's tint, a mine's flash) finishes playing before the carrier disappears and
the Relic reappears at their final position.

## 4. Extraction → winner

`scripts/extraction_anchor.gd` polls (again, not `body_entered`) for the CURRENT carrier
(`"is_carrying_relic" in body and body.is_carrying_relic`) overlapping the active anchor, and calls
`MatchDirector.collect(body.slot_id)` directly — the exact same entry point the old first-touch
`relic.gd` used to call. `MatchDirector`'s own state machine is **completely unchanged**
(`SETUP → UNLOCKING → OPEN → RESULTS`); OPEN now covers the whole grab→carry→extraction climax
instead of just the old instant race. A non-carrier standing in the active extraction cannot win —
the check is built into the win condition itself, not bolted on separately.

## 5. Mine

`scripts/mine.gd` + `scenes/power/mine.tscn`, `power_type.gd`'s new `Type.MINE`. Carried/placed/
consumed exactly like Push/Rocket/Freeze (`power_system.gd`'s `_try_mine()`): always a valid
activation (mirrors Rocket's "firing is the tested behaviour" reasoning — there is no target-range
gate), always consumes on placement. A flat `ARM_DELAY = 0.6s` (not per-owner tracking) keeps the
owner from instantly retriggering their own newly-placed mine; after that window, any player
including the owner can trigger it. Damage routes through the identical `power_hit` signal →
`HealthSystem.apply_damage()` pipeline every other power uses (`_on_mine_triggered()` mirrors
`report_rocket_hit()`) — there is still exactly one damage implementation in the codebase.

One authored world Mine pickup was added at `B_E` (position 1450, 532); no tier gating (that's
M4-4), no inventory, no multiple stored mines.

## 6. Bot pursuit / interception

`scripts/bot_brain.gd`'s `Goal` enum gained `SEEK_EXTRACTION` alongside the existing `ROAM`/
`SEEK_RELIC`. The pre-existing OPEN-triggered staggered goal-switch mechanism
(`notify_open()`/`_check_goal_switch()`'s reaction-delay + grounded-cap pattern) was **generalised,
not duplicated**, into `_request_goal()`/`_pending_goal`, now driving three events instead of one:

- `notify_open()` — unchanged, `Goal.SEEK_RELIC`.
- `notify_relic_carried()` — fired for **every** bot (including the one that just became carrier)
  the instant the Relic is picked up by anyone. All bots switch to `Goal.SEEK_EXTRACTION`, targeting
  the SAME locked node (`extraction_target_node`, set by `arena_01.gd` once `ExtractionSystem`
  locks). This is deliberately the smallest implementation that produces visible pursuit: a carrier
  walking there fulfils the win condition; a non-carrier arriving there is the smallest useful
  interception behaviour the brief asked for ("extraction approach"), and the pre-existing
  `USE_POWER` opponent-in-range check (unchanged) naturally fires when the carrier and an
  interceptor end up near each other — no combat planner was built.
- `notify_relic_dropped()` — every bot reverts to `Goal.SEEK_RELIC`, now chasing the Relic's live
  world position (see §1) rather than the fixed pedestal.

`SEEK_RELIC` itself was generalised: `_final_approach_relic()`/`_pick_target_for_mode()` now read
the Relic's CURRENT `nav_node`/position via a live `relic_ref` (set by `arena_01.gd`'s
`set_relic_ref()`, a setter, matching `set_pickup_field()`'s own "never a constructor param"
convention) instead of the fixed pedestal x captured at `BotBrain` construction — with the old fixed
value preserved as a fallback for any pre-M4-3 test rig that never calls the setter
(`tools/m3_check.gd`, `tools/nav_soak_test.gd`, `tools/door_arrival_check.gd` are all unaffected by
this change).

No Mine-specific bot AI was added — bots place Mine through the identical, unmodified `USE_POWER`
range check every other power already uses. No health-based reasoning, no combat planner.

## 7. A production bug found and fixed by this session's own testing

The first `relic.gd`/`extraction_anchor.gd` drafts toggled `Area2D.monitoring` on/off (hidden+not-
monitoring while carried/dormant, shown+monitoring while world-active/selected). Automated testing
reproduced, on this new code, **the identical bug class the ORIGINAL M3-2 `relic.gd` already
discovered and documented as the reason its OWN `monitoring` stays permanently true**: Godot does
not reliably clear an `Area2D`'s internal overlap cache when `monitoring` is toggled off then back
on, so a body that was near the Relic/an anchor before monitoring was disabled can be reported as
still "overlapping" many physics frames later, even after genuinely moving away. Observed here as a
just-respawned player — teleported far from the drop point — being credited with re-picking-up the
Relic the instant its own SETUP→OPEN cycle re-enabled monitoring at the pedestal.

**Fixed** by reverting to the original M3-2 pattern in both `relic.gd` and `extraction_anchor.gd`:
`monitoring = true`, set once in `_ready()`, never toggled again; a plain state flag
(`carrier_slot_id` / `active`) gates all real behaviour instead. As defence in depth, the same
geometric AABB-vs-AABB re-check the M4-2 close-out already added to `power_pickup.gd`/`launch_pad.gd`
for the related "body teleported earlier in the same physics frame" staleness class was also applied
to `relic.gd`, `extraction_anchor.gd`, and `mine.gd`. See `docs/DECISIONS.md` for the full incident
record — recorded there and here so a future session does not rediscover this a third time.

## 8. Relic-opening salience treatment

`arena_01.gd`'s `_on_match_state_changed()` OPEN branch now also calls `_trigger_open_salience()`: a
brief camera shake (`Camera2D.offset`, 0.3s, 10px magnitude, decaying via `sin`/`cos` noise) plus a
short flash pulse on a new `HUD/OpenPulse` full-screen `ColorRect` (alpha 0 → 0.35 → 0 over ~0.4s).
Both are mild by construction (a 10px shake is far below anything that would impair control) and
fully reversible; production audio/VFX remain explicitly out of scope. This is one candidate
treatment for the cross-milestone finding recorded 2026-09-12/13 — not yet human-playtested, and the
extraction-anchor REVEAL itself (a separate moment from Relic OPEN) still relies only on the
anchor's own visual change, not a second flash (see `docs/GAME_DESIGN.md` §8A's own note on this
gap).

## 9. Climax Lab

New debug key `debug_climax_lab` (physical `X`). Unlike Contact Lab/Arena Bites Lab, it does **not**
freeze `MatchDirector`'s clock — `OPEN` has no timer exit regardless (`collect()` is the only way
out), so Climax Lab simply arms hazards and force-opens the Relic via the existing
`debug_force_open()`. It self-sustains: every return to `SETUP` (a real win→rematch, or a stray
`debug_setup_10/15/25`) immediately re-forces `OPEN` again while the lab is active
(`_on_match_state_changed()`'s `SETUP` branch), so a human tester can iterate on carry/extraction/
Mine repeatedly without waiting on the future M4-4 phase-clock architecture. Mutually exclusive with
Contact Lab/Arena Bites Lab (entering one exits the other), matching the existing convention those
two already use against each other. The pre-existing `debug_toggle_gate` (G) key still works inside
the lab for a manual force-open/force-setup toggle.

## 10. Deterministic test results

`tools/m4_3_check.gd` (new, permanent M4-3 regression tool) — **all ten deterministic sections PASS,
0 failures**, on the final tree:

1. Relic world → carrier (touch while OPEN becomes carrier; a simultaneous double-touch still
   resolves to exactly one carrier).
2. Carrier defeat drops the Relic, independent of any power spill; extraction unaffected.
3. A dropped Relic is collectible by a different player; extraction still unchanged.
4. Extraction selection: unselected before first pickup; exactly one anchor active after; a valid,
   RELIABLE-reachable region/node; a central (vault) grab selects at maximum region-distance (2);
   deterministic for the same round seed + carrier region.
5. Extraction stays locked through ownership churn (two defeats, two carrier changes); resets to
   unselected at the next round.
6. Win: a non-carrier in the active extraction cannot win; the carrier can; the correct slot is
   recorded.
7. Defeat independence: Relic drop and power spill both happen from one defeat, as two separate
   world objects; the reaction window stays visible; respawn is clean (no stale Relic/power).
8. Mine: places, consumes exactly once, an owner-immunity window holds, a different player triggers
   it, exactly 1 pip, the mine object clears itself, and a mine can be lethal through the same
   defeat pipeline as every other power.
9. Rematch: three simulated rounds show no stale carrier, extraction lock, dropped-Relic position,
   or leftover Mine.

**Full exact-tree regression** (re-verified on this session's final tree, since M4-3 touches shared
files — `health_system.gd`, `power_system.gd`, `power_type.gd`, `player.gd`, `bot_brain.gd`):
`tools/arena_check.gd` PASS · `tools/m4_1_check.gd` PASS · `tools/m4_2_check.gd` PASS ·
`tools/m4_3_check.gd` PASS (all ten deterministic sections plus the 20-round soak).

**`tools/m3_check.gd` does NOT pass cleanly against the combined M4-2+M4-3 tree, and this is an
expected consequence of M4-3's design, not a regression.** Its own `_test_winner_resolution()`
directly tests the OLD M3-2 first-touch-instant-win Relic behaviour, which M4-3 deliberately
replaces (touching the Relic now makes the toucher a carrier, not a winner). That test can never
complete against the new `relic.gd`, and `MatchDirector` is left in a state the checker's own later
tests do not expect — cascading into 43 additional failures (every "goal switch"/"Fairness"/
"Rematch" test that needs a fresh OPEN or RESULTS transition), confirmed to be this single root
cause and not a real defect (the underlying bot goal-switch mechanism is unchanged and verified
correct by `tools/m4_3_check.gd`'s own 20-round soak, which reached RESULTS cleanly every round).
Re-running `tools/m3_check.gd` against the exact tree actually **committed** for M4-2 (M4-3 set
aside) reproduces the clean baseline: exactly the four historically-acknowledged edge-sampling
findings, nothing else — confirming the M4-2 commit itself is not the cause. `m3_check.gd` is an
M1–M3-era regression tool never updated for M4 objective logic; deciding whether/how to update its
Winner-dependent tests for the new carry-to-extraction objective is a call for a future *accepted*
M4-3+ session, not something to patch before Game Director review. See `docs/DECISIONS.md`
(2026-09-13, M4-3 entry) for the full evidence trail, including a second, narrower and separately-
confirmed test-harness-only artifact in `tools/m4_1_check.gd` when run against the combined tree.

## 11. 20-round diagnostic soak

Bot-only (P2–P4; P1 present but inert, matching the "idle P1" convention every earlier M4 soak
already established), hazards armed, real Climax systems, driven through the actual RESULTS→rematch
loop each round (not a flat timer). A test-harness bug was found and fixed during this soak's own
development: the soak initially left P1 exactly where a generic field-clear helper positioned it
(960, −2000), and a HumanController with no real human providing input in a headless run free-falls
straight down with zero horizontal drift — landing squarely on the Relic pedestal chamber and
silently hoarding the Relic every round. Fixed by repositioning every body onto ordinary ground
before the soak begins, the same convention `tools/m4_2_check.gd`'s own soak already used.

Reported (diagnostic only, never balanced or auto-corrected from): first carrier by slot, extraction
anchor/region distribution, carrier changes per round, Relic drops per round, carry duration (first
pickup → win), OPEN → first pickup, OPEN → win, winners by slot, Mine placements/hits/defeats,
power-caused vs. hazard-caused defeats, non-terminating rounds, hard nav recoveries. See this
session's own terminal output / `docs/DECISIONS.md` entry for the actual figures from this run — re-run
`tools/m4_3_check.gd` for current numbers rather than treating any pasted table as durable.

## 12. Suggested Game Director playtest protocol

1. Launch the project normally (the accepted M3/M4 match is unchanged in shape — `SETUP → UNLOCKING
   → OPEN`; only the OPEN-state objective changed).
2. Play a full round as P1. When the Relic opens, grab it — you should become the visible carrier
   (the new gold `RelicIndicator` above your character), not an instant winner.
3. Notice which extraction anchor lit up (one of five authored locations) and try to carry the Relic
   there while P2–P4 (bots) pursue you.
4. Get defeated while carrying it (deliberately, to test the drop) — confirm the Relic drops at your
   defeat position, stays collectible, and the extraction anchor does NOT move.
5. Try the `X` key (Climax Lab) for rapid repeated rounds without waiting through SETUP each time.
6. Try picking up a Mine (`B_E` platform) and placing it — confirm you don't immediately trigger your
   own mine, and that it's a real threat to whoever crosses it next.
7. Report on: is "become carrier, not winner" clear? Is the extraction anchor's activation readable
   at full-arena scale? Does the OPEN camera-shake/flash read as "something changed," or is it too
   subtle/too strong? Does chasing a fleeing carrier feel meaningfully different from the old
   first-touch race? Does Mine feel like "I predicted your route"?

## 13. Explicitly out of scope, not built

M4-4's BUILD/ESCALATE/CLIMAX phase clock, tier gating, the ~2-minute match timing, and timeout
resolution · Shield/Teleport/Mobility · any economy/XP/currency/upgrade system · limited lives ·
production VFX/audio · a second arena · sophisticated combat AI. None of these were touched.
