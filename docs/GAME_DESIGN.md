# Rushlings — Game Design Source of Truth

## 1. One-Sentence Pitch
A fast, simple mobile arena game where tiny Relic Hunters race through one fully visible 2D arena, grab powers to mess with friends, and become the first player to reach the Relic.

## 2. Product Promise
The experience should feel understandable in seconds:
**Move. Grab a power. Mess with your friends. Get the Relic first. Rematch.**

Rushlings should create social moments through prediction and interference rather than deep combat systems.

## 3. Audience / Positioning
Working direction:
- Broad casual-to-midcore mobile audience.
- Social/friends-first appeal.
- Easy enough to understand without gaming expertise.
- Skill and replayability should emerge from movement, routes, timing and power use.
- Avoid positioning that feels scary/dark, excessively childish, or like a hardcore MOBA/shooter.

## 4. Platform & Screen
- Mobile first.
- Android + iOS target.
- Landscape orientation.
- 1920×1080 logical design viewport currently configured.
- Fixed camera.
- Entire arena visible at all times.
- No minimap because the screen itself is the map.
- No scrolling level in baseline mode.

**Future platform direction (not current scope):** the long-term platform target extends beyond
mobile to Steam/desktop, alongside Android + iOS. A future desktop release also raises the
possibility of local/couch multiplayer with multiple physical controllers on one machine — a
different social configuration from phone-based play. Neither is implemented now; no controller
assignment, storefront APIs or desktop-specific input work is in scope until a dedicated platform
milestone. See the "Future / Parking Lot" section of `docs/ROADMAP.md`.

## 5. Camera / Arena Format
Chosen direction: straight-on 2D side view.

Why:
- Preserves the “everyone is visible” multiplayer essence.
- Easier to read on mobile than a large scrolling world.
- Lower character production complexity than top-down directional animation.
- Strong fit for compact one-screen arena design.

Rejected as baseline:
- Isometric/top-down presentation: felt too 3D and required more directional art/animation.
- Scrolling world: weakens the social value of seeing friends simultaneously.

## 6. Arena Philosophy
The arena is not merely decoration. It creates choices.

Desired characteristics:
- One fixed screen.
- Multiple horizontal/vertical routes.
- Players may see an opponent but cannot always reach them directly.
- Fast/risky routes and slower/safer routes.
- Power pickup routes can create detours.
- Portals can create shortcuts.
- Ladders/lifts/launch pads/drop zones provide contextual vertical traversal.
- Left and right edges connect, making the arena a continuous horizontal loop (accepted at M1).
- Enough negative space to read players and powers.
- Architecture should eventually accommodate experiments with six players, although launch scope is four.
- Arena geometry is designed first as a gameplay diagram; art is layered later.

Avoid:
- Huge decorative structures that consume play space.
- Straight unobstructed access to the objective.
- Excessive symmetry if it makes route choice predictable.
- Too many decorative glowing objects that look interactive.
- Dense foliage/details that hide characters.

**Not every arena needs identical objective-access topology (accepted 2026-09-12).** Arena 01's
roof/east-wall pre-positioning — a player who legally pre-positions on the vault header before the
Relic opens can fall directly onto it — was human-playtested and accepted as an emergent strategy
for *that* arena, not fixed away. Future arenas should deliberately explore different structural
problems rather than copying Arena 01's shape: more protected objective chambers, portals, moving
traversal, changing objective entrances, multiple approach structures, or access patterns where
camping is deliberately harder. Whether a camping-style position stays viable is also expected to
change once powers exist — see §25 and `docs/DECISIONS.md` (2026-09-12) — so this is not a
permanent verdict on Arena 01 either, only the current one.

## 7. Core Match

> **SUPERSEDED IN PART BY M4-0 (approved 2026-09-12).** The "Baseline Mode" described below is the
> **M3-era accepted match**, which remains the currently-implemented behaviour in
> `scenes/arena_01/arena_01.tscn`. The **approved M4 direction** replaces it with an escalating
> `BUILD → ESCALATE → CLIMAX` match ending in a carry-to-extraction objective — see §7A and
> `docs/plans/M04_0_MATCH_SHAPE_DESIGN.md`, which is the authority for the M4 phase. The M3-era
> text is preserved below rather than deleted, because it documents what the game currently does.

### M3-era Phase 1 — Power Up / Position
**Current M3 baseline (accepted 2026-09-12): 10 seconds**, for the present no-powers prototype —
15s/25s remain available as debug options, not deleted. **~25 seconds remains the M4 working
direction** once powers/pickups give this phase real content to fill; see `docs/DECISIONS.md`
(2026-09-12) for the full M3-2 close-out and the "Future match structure" hypothesis, which
imagines this phase eventually growing into a longer, escalating "build" period rather than a
short pre-race countdown.

At match start:
- Four players spawn at separated positions.
- Relic is visibly locked/unavailable.
- Power pickups are available/spawn.
- Players navigate, position themselves and interfere with others.
- Players can carry one power at a time.

### M3-era Phase 2 — Relic Rush
At the end of the setup period:
- Relic chamber opens automatically.
- No seals/switch puzzle is required in baseline mode.
- Players race toward the Relic.
- Powers are used to delay, displace or protect.
- First player to touch/grab the Relic wins immediately. **(M3-era. Superseded by §8A's carry-to-extraction objective for the M4 direction.)**

### Match Duration
- Target maximum around 2 minutes.
- A match can end earlier.
- Do not artificially stretch the round.
- Fast rematch is part of the desired loop.

## 7A. Core Match — APPROVED M4 DIRECTION (M4-0, 2026-09-12)

**Authority: `docs/plans/M04_0_MATCH_SHAPE_DESIGN.md`. Status: approved design, NOT implemented.**

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

Two escalation curves run together: **player capability** (by power access tier) and **arena
threat** (by hazard schedule).

**All phase timings are placeholders to be measured, not argued** — the same standard that resolved
M3-2's 10s setup. Working hypothesis only: BUILD ~0–40s, ESCALATE ~40–75s, Relic opens ~75s, total
~120s. **Do not encode these as production rules.**

**Timeout resolution is an OPEN QUESTION.** What happens when a match reaches its time limit is
deliberately undecided. Candidates recorded without selection: current carrier wins · overtime ·
extraction stays active while arena pressure escalates · another sudden-death structure · another
evidence-driven solution. **A hard-cap/sudden-death rule was proposed at M4-0 and explicitly
withdrawn.** Resolved at M4-4 with real pacing evidence.

## 8. Objective

### M3-era baseline objective — SUPERSEDED for the M4 direction
**Be the first player to grab the Relic.** First touch wins immediately. This is what the game
currently implements, and it remains the accepted M3 behaviour. It is **not** the intended final
objective — see §8A.

The Relic:
- Is central to the game but should not be trivially accessible.
- Begins protected/locked.
- Opens automatically after the setup phase.
- Does not require a 10-second hold in baseline mode.
- Does not require activating multiple seals in baseline mode.

## 8A. Objective — APPROVED M4 DIRECTION: carry to a locked extraction

**Grab the Relic → carry it to the activated extraction → survive the trip.**

Grabbing does not win. It makes you the visible carrier. A defeated carrier drops the Relic, which
re-enters contest.

**Why first-touch had to change.** An escalating match and an instant-win objective are
structurally incompatible: while the Relic is sealed nothing can be won or lost, so combat before
it opens has no stakes; and M3-2's telemetry measured median OPEN→win at **~0.00s**. The climax was
a coin flip resolved by pre-positioning. Giving the objective *duration* is what gives escalation
somewhere to land.

### The extraction rule — selected ONCE per round, then locked

Five authored extraction anchors, one per existing arena region (`scripts/arena_regions.gd`
already defines `floor`, `west`, `central`, `east`, `seam` as a wrap-aware loop). **Never arbitrary
world coordinates.**

On the **first** successful Relic pickup of a round:
1. Determine the first carrier's current region.
2. Select the anchor at **maximum region-distance** from it (`ArenaRegions.region_distance()`).
3. Break ties with deterministic per-round seeded RNG.
4. Activate and reveal that extraction to all players.
5. **Lock it for the remainder of the round.**

| First grab in | Extraction activates at |
|---|---|
| central (the vault) | west **or** seam |
| floor | east **or** seam |
| west | central **or** east |
| east | west **or** floor |
| seam | floor **or** central |

**It must NOT recalculate** on carrier defeat, Relic drop, another player taking the Relic,
repeated ownership changes, or respawn. A new selection happens only in the next round.

The design goal: **unpredictable before first pickup → clearly revealed → strategically stable for
the rest of the climax.** Once revealed, all players share one destination and can act on it — the
carrier picks a route, opponents intercept, players hold chokepoints or place traps along predicted
routes, others race ahead. A relocating extraction would destroy objective readability and make
prediction meaningless.

**Players are informed by the arena itself** — the anchor physically activates, plus a short global
flash and sound. Because the fixed camera shows the whole arena at all times, that *is* the
notification. No minimap, no HUD element.

**Effect on Arena 01 roof camping:** a vault grab is a central-region grab, so the extraction always
activates at maximum distance. The camper takes the Relic first, then faces the longest possible
carry from the most exposed platform at three health pips against three converging players. Camping
becomes an opening with a real cost. **Still requires human playtesting before being recorded as
solved.**

## 9. Controls & Movement Language
The final mobile controls must be extremely simple.

### Accepted Movement Language (M1, accepted 2026-09)
The movement vocabulary is settled. Later milestones build on it rather than revisiting it:
1. Horizontal movement with acceleration and deceleration.
2. Player-controlled jump — grounded or from a ladder.
3. Air steering, with momentum preserved in the air.
4. Contextual ladder traversal.
5. Jump off ladder.
6. Environmental launch pads, stronger than a jump.
7. Horizontal screen wrapping.

The *model* is settled; the numeric tuning inside it is not, and the mobile mapping is not.

Design intent:
- Movement primarily controlled with left thumb.
- One contextual/current power action on right side.
- Avoid permanent console-like D-pad + A/B/X/Y layout.
- Avoid a large persistent joystick if possible.
- Controls may appear contextually/fade when not used.

Prototype keyboard controls, deliberately context sensitive. These are prototype mappings, not final mobile controls:

Outside a ladder/traversal zone:
- A / Left Arrow: move left.
- D / Right Arrow: move right.
- W / Up Arrow: jump.
- Space: jump.

Inside/engaged with a ladder:
- A / Left Arrow, D / Right Arrow: move.
- W / Up Arrow: climb up.
- S / Down Arrow: climb down.
- Space: jump off the ladder.

Development only:
- R: reset player position. Not a game control.

### Vertical Traversal
The original design principle was no dedicated jump button, with all vertical movement supplied by the arena. **Milestone 1 playtesting rejected that principle** — horizontal movement plus contextual traversal alone felt too restrictive. See `docs/DECISIONS.md` (2026-09).

Current direction (accepted at M1 close, 2026-09):
- Rushlings has a normal player-controlled jump: grounded or from a ladder, no double jump, no wall jump, no charged jump.
- The player can jump off a ladder, so ladders never feel like traps. A held direction carries them away from it.
- Contextual arena traversal remains, and reaches places a plain jump cannot:
  - Ladder / climb zone.
  - Lift.
  - Launch pad.
  - Portal.
  - Drop-through zone.
  - Other arena-controlled traversal.

Jump is normal player movement. Launch pads and similar mechanisms are stronger environmental traversal. Both exist, and the arena still creates the interesting route choices.

Open question, intentionally unresolved until M5: how Run + Jump + Power map onto touch without turning the screen into a console controller. The keyboard mapping above is a prototype convenience, not a design commitment.

Movement speeds and strengths (climb speed, jump strength, etc.) are current tuning data rather than permanent design constants — see `docs/DECISIONS.md` (2026-09).

### Horizontal Wrapping
The arena's left and right edges connect. A player leaving completely through one edge re-enters from the other at the same height, keeping momentum, with no fade or respawn. Accepted after M1 iteration 2 playtesting — see `docs/DECISIONS.md` (2026-09).

## 10. Powers
Baseline set: four powers.

### Freeze
Purpose: temporarily stop/delay another player.
Desired behavior:
- Clear target/impact.
- Short duration; tune through playtesting.
- Should create opportunity, not long frustration.

### Push
Purpose: displace an opponent backward/away from route or objective.
Desired behavior:
- Immediate and readable.
- Strong social/comedic potential.
- Avoid uncontrollable long knockback.

### Teleport
Purpose: relocate another player and disrupt their route.
Working concept:
- Teleport power can affect another player.
- Destination should be predictable enough to understand.
- Paired portal logic is a candidate.
- Do not add complex destination selection initially.

### Shield
Purpose: protect against one power/interference event or a short period.
Desired behavior:
- Very obvious protective state.
- Should encourage timing, not permanent safety.

### Future Exploration — Arena-Reactive Powers (Hypothesis, Not Approved)
Not approved final behavior. This is a design direction to prototype and playtest at the powers
milestone (M4) — it does not authorize implementation now, and must not leak into M3.
**Status update (2026-09-12):** M4-1's Freeze is **player-targeted movement denial only** — the
environmental/surface variant is not in M4-1 scope. M4-2 approaches the same "arena matters"
question from the opposite direction, by making the arena a threat rather than a power target.
Revisit arena-targeting powers with M4-2 evidence.

**Broader principle:** the arena itself can become part of the power system. Rather than treating
powers only as player-vs-player attacks, they can be explored as temporary ways of manipulating
traversal, positioning and shared space — turning routes, platforms and traversal mechanisms into
targets, not just other players.

**Freeze as a concrete example:**
- **Direct Freeze** — the currently-described behavior above: freeze/slow another player directly.
- **Environmental Freeze** — freeze a floor or platform surface so players slide on it, or make a
  ladder slippery/temporarily difficult to climb. A player could use Freeze on arena geometry
  rather than (or in addition to) another player.

Both must be prototyped and playtested before either is treated as real Rushlings behavior — this
section records a hypothesis worth exploring, not a commitment. Any future gameplay telemetry work
(see "Future Direction — Human-Learned Bot Intelligence" below) should be capable of recording
environmental power usage if this direction is pursued, so learned bots could eventually imitate
how humans manipulate the arena, not just how they target other players.

### Power Rules
- Collect by touching pickup.
- No separate pickup button.
- Carry only one power at a time.
- Picking up another power replaces the current one unless playtesting later proves otherwise.
- No multi-ability toolbar.
- Powers are not tied to character identity/classes.

**Added at M4-0 (approved 2026-09-12) — one-use consumption.** The current hypothesis is:

> One carried active power → one use → empty → collect again.

Scarcity, not a cooldown, throttles combat frequency. This keeps pickups valuable for the entire
match, makes every use a decision, and pulls a player back into the arena to rearm after using
one. No inventory, no charges, no levels.

### Power taxonomy and tiers (M4-0, approved 2026-09-12)

A taxonomy for organising the design space. **Not an implementation list.**

| Category | Does | Examples | Damage? |
|---|---|---|---|
| **Control** | Denies or redirects movement | Push, Freeze, forced Teleport | No |
| **Damage** | Reduces health directly | Rocket / projectile, blast | Yes |
| **Denial** | Placed, persistent, rewards prediction | Mines, traps | Yes |
| **Defense** | Negates incoming harm | Shield, rotating shield | — |
| **Mobility** | Improves your own traversal | Self-teleport, dash, personal launch | No |
| **Summon** | Autonomous agent | Golem, pet, guardian | Yes |

**Summons are parked hardest of all** — a pet or golem needs its own navigation, i.e. a fifth AI on
top of a bot system that already cost two milestones. Not an M4 candidate at any stage.

**Tiers drive access escalation** — what exists to be found changes over the match, while the
carry-one rule never does:

| Tier | Available from | Spawns at | Examples |
|---|---|---|---|
| Tier 1 | BUILD | Common, easy routes | Push, Shield |
| Tier 2 | ESCALATE | Contested, hard-to-reach spots | Freeze, Mine, Mobility |
| Tier 3 | CLIMAX | Rare, most exposed positions | Rocket, heavy blast |

**Control powers deal no damage; damage powers do.** Preserving that split is a design goal. Push
is displacement-only — its lethality is contextual, via what the arena does to a displaced player.

**Loot spill.** On defeat, a player's carried active power spills into the arena as a world pickup.
That *is* the loot — no separate currency, counter or resource layer. A defeated carrier drops both
the Relic and their power, making the carrier the most rewarding target in the match.

## 11. Health, Defeat, Hazards / Respawn

> **REVISED AT M4-0 (approved 2026-09-12).** The previous rule — *"Baseline mode should not
> eliminate players"* — is **superseded**. Player defeat and respawn are now intended. The
> principle it protected is preserved and strengthened: **nobody sits watching a match**, which is
> exactly why respawns are unlimited rather than limited lives.

### M3-era rule (superseded, preserved for history)
Baseline mode should not eliminate players.
- Environmental hazard or strong failure causes short respawn.
- Exact respawn delay to be tuned.
- Nobody should sit watching a match for long.

### Health — approved M4 direction

Three coarse states plus defeat:

```
Healthy (3)  →  Hurt (2)  →  Critical (1)  →  Defeated (0)
```

**No percentage health bar.** Four bars on one fixed screen, over deliberately tiny characters,
contradicts §18 and the §19 readability hierarchy — and a percentage implies the many small damage
sources of a shooter.

**The binding requirement, and the only one:**

> Health state must be immediately readable at normal full-arena gameplay scale, without
> introducing a conventional percentage health bar.

**The visual treatment is deliberately NOT chosen.** Candidates recorded as hypotheses only — small
dots or pips, a ring or outline, a segmented indicator, character-integrated treatment (dimming,
cracking, flicker, silhouette), or something else. **M4-1 STOP 3 selects it through human
playtesting.**

**Damage:** every damage instance is exactly 1 pip. Arena hazard contact = 1. Rocket = 1. **Push =
0. Freeze = 0. Falling = 0** — fall damage would retune accepted M1 movement feel, and M1 is
closed. Impact damage (being slammed into geometry) is deferred, not rejected.

### Health does not prescribe behaviour — EXPLICIT RULE (2026-09-12)

**Health is information and vulnerability. It is not a behavioural state.** Any rule of the form
*"low health → retreat / hide / disengage"* is **explicitly rejected**.

At Critical health a player remains completely free to attack, chase, collect a power, contest the
Relic, take a risky route, hide, escape, or deliberately play aggressively.

- **Do not alter human movement, actions, inputs or power access based on health.** The only state
  that changes what a player can do is `Defeated` at zero.
- **Do not add automatic low-health retreat behaviour to bots.** No flee goal, no defensive mode,
  no health-keyed threat weighting. A bot must not become defensive simply because it has one pip.
- Health may be *read* by systems that display it, never by systems that decide what a player or
  bot is allowed or inclined to do.

If bot personalities are introduced later (§13, §24), different bots may legitimately make
different risk decisions — that is a future bot-intelligence question and **not an M4 rule**.

### Defeat and respawn — approved M4 direction

**Unlimited respawns with cost. Not limited lives.** Limited lives were considered and rejected: a
player eliminated at 60s of a 2-minute match watches for a minute, which violates the "nobody sits
watching" principle above, removes the losing player from their own comeback, and costs far more
code (elimination state, spectator handling, a last-player-standing end condition).

The cost of a defeat is already real: seconds out of play, your carried power spills, your position
is lost, and the Relic drops if you held it.

**Respawn placement — minimal, deliberately.** Reuse the existing authored spawn anchors; on
respawn pick the one **furthest from the nearest living opponent**. Never arbitrary coordinates.
**Do not build a sophisticated spawn director** — if four anchors prove insufficient, add anchors
and a real score *then*, with evidence.

**Post-respawn protection window (~0.75–1.0s): PROTOTYPE HYPOTHESIS ONLY.** Prototyped at M4-1, not
a shipped rule until playtesting says so.

### The arena as opponent — aspiration, not proven

> **You don't kill your friends. You feed them to the arena.**

Approved as a strong Rushlings design aspiration. **Not approved as a proven rule.** The arena is
*intended to become* a major source and amplifier of danger, while powers provide deliberate
player-driven interference — but M4-2 has not yet established that arena hazards are fun, and
**"the arena is the primary damage source" must not be encoded as settled.** M4-2 determines
through playtesting how important environmental damage should actually become. Health must not be
architected on the assumption that hazards have already succeeded.

**First experiment (M4-2): escalating danger zones**, with a **mandatory readable warning → active
→ safe cycle. No invisible damage.** Wind/blowers are the immediate fallback and follow-up
candidate. Roaming creatures and guardians are parked — they need their own navigation.

Ghost mechanic:
- Previously explored and liked conceptually.
- Not part of baseline mode.
- Reserved for a possible future “Haunted” mode where defeated players can interact differently.

## 12. Players
Launch prototype: four slots.

Early local development:
- One human.
- Three bots.

Future:
- Any combination of humans/bots.
- Bots can fill empty slots.
- Bot takeover on disconnect is a possible multiplayer feature.
- Six-player mode is an exploration, not a current commitment.

**Validated at M3-1 (2026-09):** four simultaneous characters make Arena 01 substantially more
alive and fun than solo exploration suggested — the strongest signal from the four-player
foundation milestone. 1.0× is the accepted tempo baseline for four-player play; a faster tempo
that read as exciting in solo debug playback read as merely fast-forwarded with four bodies
active, a reminder that movement-feel findings from single-player tuning don't automatically
transfer to the player count the game is actually built for.

## 13. Bots
Bots exist first to make the game testable by one person.

No LLM/ML required.

**Navigation principle, validated at M3-1 (2026-09):** a small reliable bot road network beats a
complete-but-unreliable traversal graph. Bots should route only through arena transitions proven
reliable for them; a human player may use additional traversal options a bot does not rely on for
ordinary navigation. This is not a limitation to design away — it's the accepted shape of the
RELIABLE/SKILL split, and it kept a real M3-1 bug (bots repeatedly failing at, and getting stuck
near, traversal a human could do easily) from ever reaching players.

Baseline bot reasoning:
- Understand current location.
- Understand routes/traversal.
- Seek useful power during setup.
- Seek Relic when available.
- Use power when contextually useful.
- Avoid obvious hazards.
- Recover from respawn.

**Explicit M4-0 constraint (2026-09-12): bots must NOT retreat because of low health.** There is no
low-health flee goal, no defensive mode, and no health-keyed threat weighting. A bot on one pip
plays exactly as it does on three. Health is information, not a behavioural state — see §11. If bot
personalities are built later, differing risk appetites become legitimate *then*, as a personality
question, never as an automatic health response.

Later difficulty/personality ideas:
- Easy: delayed reaction / suboptimal route.
- Normal: competent.
- Hard: better route/power timing.
- Greedy: prioritizes objective.
- Troublemaker: prioritizes interference.
Do not build these until core bot loop works.

A longer-term, distinct direction — bots that learn behavioral patterns from real human gameplay
rather than relying entirely on hand-authored logic — is recorded separately in §24, "Future
Direction — Human-Learned Bot Intelligence." That direction does not change the deterministic,
no-LLM/no-ML baseline above; it is future exploration, not current scope.

## 14. Characters — Rushlings / Tiny Relic Hunters
Primary direction: Tiny Relic Hunters.

Design characteristics:
- Tiny, readable 2D characters.
- Large head / small body.
- Two expressive eyes are important.
- Strong silhouette at actual gameplay scale.
- Hoods, horns, ears, helmets, scarves, goggles, feathers, backpacks can create variation.
- Charming/adventurous/mischievous, but not overly childish.
- Not realistic humans.
- Not one-eyed abstract symbols as primary player characters.
- Character identity is independent from powers.

Working character families/variation language:
- Hornkin Explorer.
- Cloaked Seeker.
- Long-Ear Scout.
- Feathered Wanderer.
- Masked Ranger.
- Goggle Engineer.
- Stone Helmet.
- Desert Nomad.
- Shroom Hunter.
- Rune Warden.
- Leaf Dancer.
- Star Gazer.

These are exploration labels, not final roster commitments.

## 15. Masks & Customization
Masks are a strong future cosmetic system.

Principles:
- Base Rushling remains relatable.
- Masks can cover/alter face but should generally preserve two readable eye openings/eyes.
- Cosmetic only; no gameplay advantage.
- Same animation rig should ideally support many masks.
- Outfit/color/trail/win-emote are future cosmetic possibilities.
- Do not build customization before the product-layer milestone.

Ancient Guardians / mask-spirit designs can also be used as:
- Masks.
- World guardians.
- Arena mechanisms.
- Boss/event concepts later.

## 16. Animation Direction — Later
Do not build production animation during greybox milestones.

Preferred future pipeline:
- 2D, not 3D.
- Reusable 2D rig / skeletal or modular animation where practical.
- Separated character pieces: head/body/arms/legs/eyes/hood/mask/accessory.
- Shared base rig across many Rushlings where possible.
- Small animation set:
  - Idle.
  - Run.
  - Cast.
  - Hit.
  - Respawn.
  - Victory.
  - Contextual climb/traversal only if required.
- Eyes/blinks/look direction add personality.
- Secondary motion for scarf/ears/cape/feathers where economical.

AI can accelerate asset creation and implementation, but deterministic in-engine animation is preferred over relying entirely on inconsistent AI-generated frame sequences.

## 17. VFX Direction — Later
Powers should rely heavily on Godot VFX rather than unique character animations.

Examples:
- Freeze: projectile/trail -> impact -> ice overlay -> shatter.
- Teleport: particles/distortion -> disappear -> reappear.
- Shield: translucent bubble/runes -> impact ripple.
- Push: wind arc/distortion/dust -> displacement.
- Pickup: concise flash/sound/icon feedback.
- Relic opening: strong but readable reveal.
- Respawn: simple materialization.
- Victory: concise celebratory effect.

Use particles, shaders, sprites, tweens and light camera feedback. Avoid effects that obscure player readability.

## 18. HUD / UI
HUD must be minimal and primarily top-aligned because thumbs occupy lower screen space.

Current principle:
- Timer at top is enough for early gameplay.
- Avoid permanent bottom player cards.
- Avoid ability toolbar.
- Avoid minimap.
- Avoid health bars. **Health exists as of the M4 direction (§11), but as three coarse states —
  `Healthy → Hurt → Critical` — never as a percentage bar.** The visual treatment is deliberately
  unchosen and is selected by M4-1 STOP 3; candidates include small dots/pips, a ring or outline, a
  segmented indicator, or character-integrated treatment. The binding requirement is only that
  health be immediately readable at normal full-arena scale without a conventional percentage bar.
- The activated extraction portal is communicated by the arena itself (the anchor lights/rises),
  not by a HUD element — the fixed camera already shows the whole arena.
- Avoid tutorial copy during normal matches.
- Current power should preferably be communicated near/through the player rather than a large inventory panel.
- Player identity should be visible through strong character color/silhouette and subtle P1/P2 markers during prototype/testing.

First-time onboarding can teach controls separately.

## 19. World / Art Direction
Current broader world:
- Ancient ruined civilization/temples in mountainous high-altitude environments.
- Bright sky, clouds, distant mountains, waterfalls and ruins.
- Adventure and mystery rather than horror.
- Temple/ruins are one arena/region, not the entire game identity.
- Multiple arenas can exist within the same broader world.

Potential arena regions:
- Mountain Temple / Ruins.
- Water Garden.
- Sun Observatory.
- Cloud Forge.
- Broken Palace.
- Floating Gardens.
Names are working concepts.

Readability hierarchy:
1. Players/gameplay.
2. Objective/powers.
3. Arena routes/mechanisms.
4. Environment beauty.

Avoid:
- Very dark/gothic baseline presentation.
- Heavy overgrown vines that camouflage characters.
- Toy-world styling that feels exclusively for children.
- Dense high-frequency detail everywhere.
- Visual effects/decorations with unclear gameplay meaning.

Flat visual-language exploration:
- A flatter, color-blocked, painterly/stylized treatment inspired by calm graphic games is a valid future art-direction experiment.
- It must be applied to the SAME fixed arena/camera/layout; do not change the game format when testing art styles.

## 20. Audio — Later
Eventually needed:
- Movement/footstep.
- Pickup.
- Freeze.
- Teleport.
- Push.
- Shield.
- Portal.
- Relic unlock/open.
- Relic grab/win.
- Respawn.
- UI feedback.
- Lobby/arena music and victory sting.

Temporary audio is acceptable during prototyping.

## 21. Multiplayer — Future, Not Current Prototype
Rushlings is intended to become online multiplayer, but networking is deliberately delayed until the local game is fun.

Desired future experience:
- Create private room.
- Share code/link.
- Friends join.
- Empty slots can be bots.
- Eventually public matchmaking if justified.

Architecture direction:
- Prefer server-authoritative live match state for fairness/synchronization.
- Do not use a normal database as the 60 FPS game simulation.
- Evaluate Nakama/custom server/other options only at Multiplayer Architecture milestone.
- Persistent account/cosmetic data can use a different backend from live match simulation.

## 22. Monetization — Future
Do not implement now.

Potential direction:
- Cosmetics/masks/skins.
- Rewarded ads where appropriate.
- Carefully placed interstitials between matches, never disrupting active gameplay.
- No pay-to-win powers.
- Sponsored/event content is possible much later.

Commercial validation should follow fun/retention validation.

## 23. Core Validation Metrics
Early prototype:
- Does movement feel good?
- Is arena navigation understandable?
- Does player immediately know where they are?
- Are routes strategically different?
- Does interfering with bots/friends create fun?
- Does the player want to rematch?

Later:
- Match completion.
- Rematch rate.
- Session length.
- Repeat sessions.
- Power usage.
- Route usage.
- Drop-off/onboarding.
- Multiplayer invite conversion.

The strongest early qualitative signal is: **“Again.”**

## 24. Future Direction — Human-Learned Bot Intelligence (Hypothesis, Not Approved)
Not current scope. Nothing here is implemented, and nothing here overrides §13's baseline: bots
remain deterministic/state-machine/utility/pathfinding logic, and **no LLM or ML is required** for
the shippable game. This section records a long-term direction worth investigating once the core
loop and powers are stable — real human gameplay, not hand-authored heuristics alone, as the
eventual source of bot believability.

The goal is explicitly **not** an omniscient or perfect AI. The goal is bots that behave like
believable Rushlings players: they should still make mistakes, react imperfectly, use different
routes, and remain beatable.

### Stage 1 — Gameplay telemetry
Once the core match loop and powers are stable, investigate recording privacy-conscious gameplay
events, such as:
- Spawn/player slot.
- Arena region.
- Route/traversal choices (wrap, drop, ladder, launcher, etc.).
- Jump, ladder, launcher and wrap usage.
- Power pickup and which power was selected.
- Power use, including player-vs-environment targeting (see the Arena-Reactive Powers hypothesis
  under §10).
- Nearby opponents/context (chase/escape situations).
- Relic state and Relic approach behavior.
- Match outcome.

Avoid collecting unnecessary personal information. This stage is data collection only — no
behavior changes as a result of it.

### Stage 2 — Statistical human imitation
Before any machine learning, investigate aggregated human behavior distributions — for example, at
a given decision point, humans wrap 45% of the time, drop 30%, use a ladder 20%, and choose
something else 5%. Bots could sample from actual observed human tendencies rather than arbitrary
hardcoded weights. The goal is human-like and varied behavior, not mathematically optimal behavior.

### Stage 3 — Player-style modeling
Explore whether real gameplay naturally reveals distinct player styles — for example, explorer,
hunter, runner, trickster, high-ground/control player, risk-taker. **These are hypotheses only, not
approved archetypes.** If real data supports them, future bots could mimic different real play
styles rather than a single generic bot personality.

### Stage 4 — Learned bot intelligence
Only after enough real gameplay data exists, evaluate behavior cloning/imitation learning, offline
learning from gameplay traces, and reinforcement learning where appropriate. Do not assume an LLM
is required — the appropriate technique depends on what the data actually supports. As above, the
goal remains believable, beatable Rushlings players, not a perfect opponent.

## 25. Escalating Match Structure & In-Match Power Progression

> **STATUS UPDATE (2026-09-12): PARTIALLY RESOLVED.** This section was recorded as an unapproved
> hypothesis at the M3 close-out. The dedicated design session it demanded has since happened and
> produced **`docs/plans/M04_0_MATCH_SHAPE_DESIGN.md`, approved 2026-09-12**, which is now the
> authority for the M4 phase.
>
> **Resolved by M4-0 and now approved** (see §7A, §8A, §10, §11): the escalating
> `BUILD → ESCALATE → CLIMAX` shape · the carry-to-locked-extraction objective · one-use/carry-one
> powers · the power category/tier taxonomy · access escalation instead of stat progression ·
> coarse 3-pip health · defeat with unlimited respawns · loot spill as the carried power only · the
> arena-as-opponent aspiration · the M4-1 power set (Push + Rocket + Freeze).
>
> **Still unresolved and deliberately open:** all phase timings · timeout resolution · the health
> visual treatment · how important environmental damage should become · whether stat progression is
> needed at all (the M4-4 GATE decides, from human evidence).
>
> **Explicitly rejected from this section's original wording:** "low-health players should have
> reason to retreat/hide" — health never prescribes behaviour (§11). A general shooting/projectile
> *model* is also not being built; Rocket is a single facing-direction damage power, not a combat
> system.
>
> The original text is preserved below unchanged, as the record of what was hypothesised.

**Recorded 2026-09-12, at the M3 close-out. Not current scope. Nothing here is implemented, and
nothing here changes M3's accepted match loop** — `SETUP → UNLOCKING → OPEN → SEEK_RELIC →
COLLECTION → RESULTS → REMATCH` remains the current prototype validating movement, arena
navigation, objective convergence, collection, winner and rematch. This section records a
longer-term direction to prototype and playtest once that loop is proven, not a rewrite of it.

### The core hypothesis

The intended Rushlings match may eventually be an **escalating experience** rather than the current
short countdown-then-Relic-race being the final game structure:

```
MATCH START
     ↓
EARLY GAME — BUILD        (explore / collect / weak interactions)
     ↓
MID GAME — ESCALATE       (stronger abilities / more encounters / positioning)
     ↓
LATE GAME — BATTLE / OBJECTIVE CLIMAX   (stronger attacks / interference / Relic contest)
     ↓
WINNER
```

Players would not begin a round at their strongest. During the match they would explore the arena,
collect powers/resources/pickups, increase their offensive/defensive capability, choose which
powers to pursue, encounter and interfere with other players, potentially avoid fights while
building strength, and position themselves for the later objective/battle. The match should
escalate over time rather than presenting the same intensity from the first second to the last.

### Approximate timing hypothesis — NOT approved

Working imagination: roughly a **2-minute total match**, with approximately the first half
weighted more heavily toward building capability and the second half toward combat/objective
intensity. **Do not encode exactly 60s of collection, 60s of combat, or 120s total as production
rules** — these are hypotheses to prototype and playtest, not settled timing.

### In-match power progression

Explore whether collected resources/powers can increase what a player is capable of *within the
same match*, rather than every player starting at maximum strength immediately. Illustrative
examples only, not an approved upgrade tree: stronger Push, stronger Freeze, a larger
projectile/bomb or blast radius, additional charges, a stronger Shield, upgraded movement/
traversal abilities, or other power evolutions. **The important principle: power should be
earned/buildable during the match, not universally available at full strength from t=0.**

### Different viable player strategies

The system should eventually allow different behaviours to be viable, as hypotheses rather than
fixed classes (do not create character classes now):
- **Aggressor** — fights/interferes early.
- **Builder** — avoids unnecessary fights and collects/upgrades.
- **Opportunist** — steals pickups or attacks weakened players.
- **Objective-focused player** — prepares specifically for the Relic opening/endgame.

### Combat can exist before the climax

The first half should **not** necessarily be a safe collection phase. Players may still attack,
Push, Freeze, disrupt, steal opportunities, and potentially eliminate/respawn one another early.
The overall power level and intensity should grow through the match — the early game is not
required to be combat-free, only lower-intensity than the climax.

### Strategic tension (a major future design space, not resolved here)

A player who spends more time collecting/upgrading may become stronger later, but risks losing
positional advantage, being attacked while collecting, missing contested resources, or being
poorly positioned when the objective changes. A player who fights constantly may gain immediate
control but potentially enter the late game less upgraded. This tradeoff is worth exploring
directly, not designing around in advance.

### Relationship to the Arena 01 roof strategy

The Arena 01 roof/east-wall pre-positioning strategy accepted at M3-2 close-out (§6, and
`docs/DECISIONS.md`, 2026-09-12) should be **revisited under this future combat system**, not
removed now. Future powers/projectiles/Push/Freeze may turn an advantageous camping position into
a contestable strategic location. This is a hypothesis that must be human-playtested, not assumed.

### Relationship to future arenas

Future arenas should explore different relationships between power/resource locations, high-value
hard-to-reach spaces, combat chokepoints, safe/risky collection routes, objective access, portals/
traversal, and high ground. Arena design and the power economy should eventually be designed
together, not arena-first-then-powers-bolted-on.

### M4 planning implication

Do **not** treat M4 as simply "implement Push, Freeze, Shield and shooting." Before M4
implementation, a fresh design/planning milestone must define: the match economy; what players
collect; how powers are acquired; inventory/carry rules; whether powers have levels; the upgrade/
progression model; power spawning/distribution and scarcity; death/respawn; what a kill
accomplishes; whether players drop resources on death; the shooting/projectile model; escalation
over match time; the relationship between combat and the Relic; when/how the Relic becomes
available under this structure; comeback mechanics if needed; and how bots should reason about
collecting vs. fighting vs. the objective. This planning must happen before power implementation —
see `docs/ROADMAP.md`'s M4 section and `docs/DECISIONS.md` (2026-09-12).
