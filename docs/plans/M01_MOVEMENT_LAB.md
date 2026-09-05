# M1 — Movement Lab

**Status: COMPLETE / ACCEPTED (2026-09)**
Accepted by the Game Director after three manual playtests.

---

## Goal and Risk Tested
Prove that Rushlings can feel responsive and fun with extremely simple controls, using greybox primitives only.

The original risk was stated as: *can the game work with no dedicated jump button, with all vertical movement supplied by the arena?*

**Playtesting answered that question with "no."** That reversal is the most important outcome of this milestone and is preserved in full below.

---

## What Was Built

A single greybox lab scene, run as the project's temporary main scene.

| File | Role |
|---|---|
| `scenes/movement_lab/movement_lab.tscn` | The lab: ground, two platforms, launch pad, ladder zone, static camera, debug HUD |
| `scenes/player/player.tscn` | Placeholder player body (`CharacterBody2D` + rectangle) |
| `scripts/player.gd` | Movement model and all tuning parameters |
| `scripts/arena_wrap.gd` | Horizontal wrapping component |
| `scripts/traversal_zone.gd` | Ladder/climb zone |
| `scripts/launch_pad.gd` | Environmental launch pad |
| `scripts/movement_lab.gd` | Lab harness, debug reset key |
| `scripts/debug_hud.gd` | Small debug readout |
| `project.godot` | Input map, run target |

The camera is static and frames the whole 1920×1080 lab. No scrolling, consistent with the fixed-camera guardrail.

---

## Accepted Movement Language

1. **Horizontal movement** with acceleration and deceleration.
2. **Player-controlled jump** — grounded or from a ladder. No double jump, no wall jump, no charged/variable jump.
3. **Air steering** — horizontal momentum is preserved in the air; deceleration applies on the floor only, so a player commits to an arc and steers it.
4. **Contextual ladder traversal** — latched: vertical intent engages the climb, it stays engaged inside the zone, zero input holds position, and the climb is clamped so it ends level with the destination platform.
5. **Jump off ladder** — detaches and jumps, carrying any held direction away from the ladder. Cannot re-attach to the same ladder while the climb input stays held; releasing and pressing again is a deliberate re-engage.
6. **Environmental launch pads** — automatic on contact, no input. Deliberately much stronger than a jump, reaching places a jump cannot.
7. **Horizontal screen wrapping** — leaving one edge completely re-enters from the other at the same height with momentum intact. No fade, respawn, delay or animation.

---

## M1 Baseline Tuning

**These are baseline tuning values, not immutable production values.** Climb speed alone moved 260 → 320 → 400 across playtests. Expect all of these to move again as arenas, powers, bots and mobile controls arrive. What is settled is the model, not the numbers.

| Parameter | Value | Note |
|---|---|---|
| `max_speed` | 500 | |
| `acceleration` | 3000 | |
| `friction` | 3500 | Floor only |
| `gravity` | 2200 | |
| `jump_strength` | 900 | ~192px rise |
| `launch_strength` | 1500 | ~511px rise |
| `climb_speed` | 400 | Raised twice on playtest feedback |

All exported on the player, with no scene overrides, so `scripts/player.gd` is the single tuning source.

---

## Prototype Controls

Deliberately context sensitive. Prototype keyboard mappings only.

| | Outside a ladder | Inside/engaged with a ladder |
|---|---|---|
| A / Left, D / Right | Move | Move |
| W / Up | Jump | Climb up |
| S / Down | — | Climb down |
| Space | Jump | Jump off ladder |
| R | Reset player (development only, not a game control) | |

---

## Design History — The Jump Reversal

**Preserved deliberately, so this is not re-litigated later.**

The original design intent was explicitly **no dedicated jump button**. Vertical movement was to come entirely from the arena — ladders, lifts, launch pads, portals, drop zones. The reasoning was sound: keep mobile controls minimal, avoid a console controller overlaid on a phone.

M1 was built specifically to test that premise, and the premise failed. In manual playtesting, horizontal movement plus contextual traversal alone felt **too restrictive** for the game Rushlings is trying to be. A jump was added in playtest iteration 2, and jumping off ladders in iteration 3.

The original constraint asked for exactly this validation. The validation rejected it. The old decision is preserved as superseded in `docs/DECISIONS.md` rather than deleted, because the reasoning behind it still constrains what comes next — particularly the mobile control mapping.

---

## Verification

Automated regression harness driving synthetic input through the lab, run at closeout: **15/15 checks passed**, covering horizontal movement, deceleration, jump, absence of double jump, air steering, ladder traversal, climb speed, jump-off-ladder, ladder route completion, launch pad route completion, both wrap directions, wrap preserving height and momentum, and debug reset.

Godot MCP run at closeout: **no errors**.

The harness itself was temporary and deliberately not committed. It earned its place three times, catching defects that would otherwise have reached playtest:
- Both traversal mechanics were originally geometric dead ends — the launch pad fired into the underside of the platform it was meant to reach, and the ladder ran beneath a solid platform.
- A compile failure that silently left the player script unloaded, caused by referencing a global class name that only exists in the editor's cache.
- `reset_to()` desyncing the traversal-zone flag from reality when a body is moved within a zone it is already inside — latent until M3's respawns.

---

## Known Limitations, Intentionally Deferred

- **Mobile control mapping is unresolved.** Jump adds a third input to what was planned as movement plus one power action. Deferred to M5 by decision, not oversight.
- **Placeholder visuals only.** Coloured rectangles; no art, animation, VFX or audio.
- **The lab is not an arena.** Its layout exists to exercise mechanics, not to provide good routes. Real arena design is M2.
- **No bots, Relic, powers, hazards, respawn or networking.** All out of M1 scope by design.
- **No projectile or shooting interaction.** Evaluated at M4 through the powers, never by turning a movement milestone into combat development.
- **No coyote time, jump buffering or variable jump height.** Not needed so far; revisit only if play demands it.
- **Wrapping shows a brief off-screen moment** at the wrap point (the body is fully out before it re-enters). Considered and accepted; the alternative was splitting the body across both edges.
- `main.tscn` **remains an empty placeholder.** The lab is the current run target; M2 will introduce the real arena scene.

---

## Kept for Reuse

The Movement Lab stays in the project as a regression and tuning harness. It is not a shippable arena and should not be treated as one.
