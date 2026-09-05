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
- Enough negative space to read players and powers.
- Architecture should eventually accommodate experiments with six players, although launch scope is four.
- Arena geometry is designed first as a gameplay diagram; art is layered later.

Avoid:
- Huge decorative structures that consume play space.
- Straight unobstructed access to the objective.
- Excessive symmetry if it makes route choice predictable.
- Too many decorative glowing objects that look interactive.
- Dense foliage/details that hide characters.

## 7. Core Match — Baseline Mode

### Phase 1 — Power Up / Position
Working duration: ~25 seconds, subject to playtesting.

At match start:
- Four players spawn at separated positions.
- Relic is visibly locked/unavailable.
- Power pickups are available/spawn.
- Players navigate, position themselves and interfere with others.
- Players can carry one power at a time.

### Phase 2 — Relic Rush
At the end of the setup period:
- Relic chamber opens automatically.
- No seals/switch puzzle is required in baseline mode.
- Players race toward the Relic.
- Powers are used to delay, displace or protect.
- First player to touch/grab the Relic wins immediately.

### Match Duration
- Target maximum around 2 minutes.
- A match can end earlier.
- Do not artificially stretch the round.
- Fast rematch is part of the desired loop.

## 8. Objective
Baseline objective:
**Be the first player to grab the Relic.**

The Relic:
- Is central to the game but should not be trivially accessible.
- Begins protected/locked.
- Opens automatically after the setup phase.
- Does not require a 10-second hold in baseline mode.
- Does not require activating multiple seals in baseline mode.

Future modes may change the objective, but do not complicate baseline mode.

## 9. Controls — Working Direction
The final mobile controls must be extremely simple.

Design intent:
- Movement primarily controlled with left thumb.
- One contextual/current power action on right side.
- Avoid permanent console-like D-pad + A/B/X/Y layout.
- Avoid a large persistent joystick if possible.
- Controls may appear contextually/fade when not used.

Prototype controls may use keyboard before mobile touch:
- A / Left Arrow: move left.
- D / Right Arrow: move right.

### Vertical Traversal
Current design principle: no dedicated jump button.
Explore contextual systems:
- Ladder / climb zone.
- Lift.
- Launch pad.
- Portal.
- Drop-through zone.
- Other arena-controlled traversal.

Milestone 1 must validate whether no-jump-button traversal actually feels good. This decision may be revisited through playtesting.

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

### Power Rules
- Collect by touching pickup.
- No separate pickup button.
- Carry only one power at a time.
- Picking up another power replaces the current one unless playtesting later proves otherwise.
- No multi-ability toolbar.
- Powers are not tied to character identity/classes.

## 11. Hazards / Respawn
Baseline mode should not eliminate players.
- Environmental hazard or strong failure causes short respawn.
- Exact respawn delay to be tuned.
- Nobody should sit watching a match for long.

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

## 13. Bots
Bots exist first to make the game testable by one person.

No LLM/ML required.

Baseline bot reasoning:
- Understand current location.
- Understand routes/traversal.
- Seek useful power during setup.
- Seek Relic when available.
- Use power when contextually useful.
- Avoid obvious hazards.
- Recover from respawn.

Later difficulty/personality ideas:
- Easy: delayed reaction / suboptimal route.
- Normal: competent.
- Hard: better route/power timing.
- Greedy: prioritizes objective.
- Troublemaker: prioritizes interference.
Do not build these until core bot loop works.

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
- Avoid health bars unless future mechanics prove they are needed.
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
