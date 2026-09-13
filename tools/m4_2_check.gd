extends SceneTree

# M4-2 "The Arena Bites" - focused automated checks for the danger-zone
# module (scripts/danger_zone.gd) and its interaction with the M4-1 Contact
# systems, per the M4-2 session brief's Section 8. Run headless:
#   godot --headless --script tools/m4_2_check.gd
#
# Loads the real arena_01.tscn (real geometry, real players, the three
# authored DangerZone instances under $Hazards) and drives it directly,
# the same convention tools/m4_1_check.gd already uses. Contact Lab is
# entered immediately so the Relic/gate loop cannot interfere.
#
# This is deliberately separate from tools/arena_check.gd, tools/m3_check.gd
# and tools/m4_1_check.gd, which must all still pass unmodified and ungated
# by anything here - danger zones are dormant (armed=false) unless this tool
# (or a human via debug_arena_bites_lab) explicitly arms them, so none of
# the three earlier checkers are affected by this file's existence at all.
#
# Deterministic PASS/FAIL sections (1-6) exercise DangerZone/HealthSystem/
# PowerSystem APIs directly. Section 7's emergent bot soak is diagnostic
# only, the same PASS/FAIL-vs-diagnostic split every earlier checker in this
# project already uses for real, non-deterministic bot play.

const ARENA_SCENE_PATH := "res://scenes/arena_01/arena_01.tscn"
const PowerTypeScript := preload("res://scripts/power_type.gd")
const HealthSystemScript := preload("res://scripts/health_system.gd")
const DangerZoneScene := preload("res://scenes/hazard/danger_zone.tscn")

var arena: Node2D
var fails: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== M4-2 Arena Bites: danger-zone checks ===\n")
	arena = (load(ARENA_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(arena)
	await physics_frame
	await physics_frame

	arena.match_director.enter_contact_lab()

	await _test_dormant_by_default()
	await _test_state_cycle()
	await _test_damage_rule()
	await _test_repeated_activation()
	await _test_protection_and_defeated()
	await _test_push_and_freeze_interaction()
	await _test_rocket_unaffected()
	await _test_defeat_via_hazard()
	await _test_geometry_unaffected()
	await _test_phase_offsets()
	await _test_phase_offset_damage_semantics()
	await _test_authored_placement_sanity()
	await _diagnostic_arena_bites_soak()

	arena.set_hazards_armed(false)
	root.remove_child(arena)
	arena.queue_free()

	print("\n=== SUMMARY ===")
	print("Failures: %d" % fails.size())
	for f in fails:
		print("  [%s] %s" % [f.category, f.detail])
	print("RESULT: %s" % ("PASS" if fails.is_empty() else "FAIL"))
	quit(1 if not fails.is_empty() else 0)

func _report(category: String, label: String, ok: bool, detail: String) -> void:
	var verdict := "PASS" if ok else "FAIL"
	print("[%s] %-52s %s   %s" % [category, label, verdict, detail])
	if not ok:
		fails.append({"category": category, "detail": "%s - %s" % [label, detail]})

func _settle(frames: int = 3) -> void:
	for _i in range(frames):
		await physics_frame

func physics_ticks_per_second() -> float:
	return float(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60))

## Same reasoning as tools/m4_1_check.gd's own _reset_player_for_test(),
## plus gravity=0: every deterministic test here plants bodies off in open
## space (no floor under them), unlike m4_1_check.gd's short Push/Freeze/
## Rocket checks where a little vertical drift never mattered - a danger
## zone's overlap is a tight rectangle, and free-falling for even a few
## tenths of a second is enough to fall clean out of one. Restored to the
## real M1 baseline for every player before the diagnostic soak (below),
## which needs real gravity for bot navigation.
func _reset_player_for_test(p: CharacterBody2D, pos: Vector2) -> void:
	p.reset_to(pos)
	p.velocity = Vector2.ZERO
	p.gravity = 0.0
	p.set_defeated(false)
	p.reset_health()
	p.set_spawn_protected(false)
	p.consume_power()
	arena.health_system._defeat_timers.erase(p)
	arena.health_system._protection_timers.erase(p)
	arena.power_system.clear_freeze(p)

const REAL_GRAVITY := 2200.0

func _restore_gravity() -> void:
	for p in arena.players:
		p.gravity = REAL_GRAVITY

func _clear_field(keep: Array) -> void:
	for p in arena.players:
		if not keep.has(p):
			p.reset_to(Vector2(960, -2000))
			p.set_defeated(false)
			p.reset_health()
			p.set_spawn_protected(false)
			p.consume_power()
			arena.health_system._defeat_timers.erase(p)
			arena.health_system._protection_timers.erase(p)
			arena.power_system.clear_freeze(p)
			p.controller.set_frozen(true)

## A throwaway DangerZone with fast, test-friendly (not production) timings,
## so the deterministic sections below don't have to wait out the ~5.7s
## authored default cycle dozens of times. Real code path, real scene,
## real HealthSystem - only the exported timing knobs differ, exactly the
## same "test-harness knob" convention already used elsewhere (e.g.
## power_pickup.gd's respawn_delay).
func _fresh_zone(warning: float = 0.1, active: float = 0.15, safe: float = 0.1) -> Node:
	var zone = DangerZoneScene.instantiate()
	zone.zone_size = Vector2(200, 200)
	zone.warning_duration = warning
	zone.active_duration = active
	zone.safe_duration = safe
	arena.add_child(zone)
	# x=960 (mid-arena, in-range) and y=-3000 (far above all real geometry):
	# a test zone must sit at an X the arena's own horizontal wrap
	# (scripts/arena_wrap.gd) will not silently relocate. player.gd is in
	# the "wrappable" group and DangerZone is not, so an out-of-range X like
	# -3000 wraps the PLAYER back into [0,1920] on the very next physics
	# frame while the zone stays put - a real bug this test harness hit and
	# is why the fresh cycle/damage tests below place bodies here, not in
	# open negative space.
	zone.global_position = Vector2(960, -3000)
	zone.configure(arena.health_system)
	return zone

func _free_zone(zone: Node) -> void:
	zone.arm(false)
	zone.queue_free()

# --- 0: dormant by default ---------------------------------------------------

func _test_dormant_by_default() -> void:
	print("\n--- Dormant by default (must not contaminate arena_check/m3_check/m4_1_check) ---")
	var zone = arena.get_node("Hazards/Hazard_Floor")
	_report("DORMANT", "an unarmed zone stays in SAFE and does not advance its clock", zone.armed == false and zone.state == zone.State.SAFE, "armed=%s state=%d" % [zone.armed, zone.state])
	var p1: CharacterBody2D = arena.players[0]
	_reset_player_for_test(p1, zone.global_position)
	await _settle(10)
	_report("DORMANT", "standing in an unarmed zone takes no damage", p1.health == p1.max_health, "health=%d/%d" % [p1.health, p1.max_health])
	_reset_player_for_test(p1, Vector2(960, -2000))

# --- 1: state cycle -----------------------------------------------------------

func _test_state_cycle() -> void:
	print("\n--- State cycle: SAFE -> WARNING -> ACTIVE -> SAFE, deterministic timings ---")
	var zone = _fresh_zone(0.1, 0.15, 0.1)
	var hz := physics_ticks_per_second()
	zone.arm(true)
	_report("CYCLE", "starts armed in SAFE", zone.state == zone.State.SAFE, "state=%d" % zone.state)

	await _settle(int(0.1 * hz) + 2)
	_report("CYCLE", "SAFE -> WARNING after safe_duration", zone.state == zone.State.WARNING, "state=%d" % zone.state)

	await _settle(int(0.1 * hz) + 2)
	_report("CYCLE", "WARNING -> ACTIVE after warning_duration", zone.state == zone.State.ACTIVE, "state=%d" % zone.state)

	await _settle(int(0.15 * hz) + 2)
	_report("CYCLE", "ACTIVE -> SAFE after active_duration (return to SAFE is obvious)", zone.state == zone.State.SAFE, "state=%d" % zone.state)

	await _settle(int(0.1 * hz) + 2)
	_report("CYCLE", "cycle repeats: SAFE -> WARNING a second time", zone.state == zone.State.WARNING, "state=%d" % zone.state)
	_free_zone(zone)

# --- 2: damage rule -----------------------------------------------------------

func _test_damage_rule() -> void:
	print("\n--- Damage rule: SAFE/WARNING deal nothing, ACTIVE deals exactly the approved 1 pip ---")
	var zone = _fresh_zone(0.2, 0.3, 0.2)
	var hz := physics_ticks_per_second()
	var p1: CharacterBody2D = arena.players[0]
	_reset_player_for_test(p1, zone.global_position)
	zone.arm(true)

	_report("DAMAGE", "SAFE: no damage", p1.health == p1.max_health, "health=%d/%d state=%d" % [p1.health, p1.max_health, zone.state])
	await _settle(int(0.2 * hz) + 2)
	_report("DAMAGE", "WARNING: no damage (telegraph only)", p1.health == p1.max_health and zone.state == zone.State.WARNING, "health=%d/%d state=%d" % [p1.health, p1.max_health, zone.state])

	await _settle(int(0.3 * hz) + 2)  # spans WARNING->ACTIVE and most of ACTIVE
	_report("DAMAGE", "ACTIVE: exactly 1 pip removed, not more", p1.health == p1.max_health - 1, "health=%d/%d" % [p1.health, p1.max_health])

	await _settle(int(0.2 * hz) + 4)  # rest of ACTIVE + all of the next SAFE
	_report("DAMAGE", "no frame-by-frame drain: still exactly 1 pip lost after the full ACTIVE window elapsed", p1.health == p1.max_health - 1, "health=%d/%d" % [p1.health, p1.max_health])
	_reset_player_for_test(p1, Vector2(960, -2000))
	_free_zone(zone)

# --- 3: repeated activation ---------------------------------------------------

func _test_repeated_activation() -> void:
	print("\n--- Repeated activation: a later ACTIVE cycle can hit the same player again ---")
	var zone = _fresh_zone(0.1, 0.15, 0.1)
	var hz := physics_ticks_per_second()
	var p1: CharacterBody2D = arena.players[0]
	_reset_player_for_test(p1, zone.global_position)
	zone.arm(true)

	# Ride out one full SAFE->WARNING->ACTIVE->SAFE cycle plus enough of the
	# next WARNING to be sure the first ACTIVE window has fully closed.
	await _settle(int((0.1 + 0.1 + 0.15 + 0.02) * hz) + 4)
	var after_first: int = p1.health
	_report("CYCLE-DAMAGE", "first ACTIVE cycle deals its 1 pip", after_first == p1.max_health - 1, "health=%d/%d" % [after_first, p1.max_health])

	# Ride through the second WARNING and into the second ACTIVE.
	await _settle(int((0.1 + 0.1) * hz) + 4)
	_report("CYCLE-DAMAGE", "player may be damaged again on a later ACTIVE cycle", p1.health == p1.max_health - 2, "health=%d/%d (expected %d after two activations)" % [p1.health, p1.max_health, p1.max_health - 2])
	_reset_player_for_test(p1, Vector2(960, -2000))
	_free_zone(zone)

# --- 4: spawn protection and Defeated are honoured, through the existing pipeline ---

func _test_protection_and_defeated() -> void:
	print("\n--- Spawn protection blocks hazard damage; Defeated players are ignored ---")
	var zone = _fresh_zone(0.1, 0.2, 0.1)
	var hz := physics_ticks_per_second()

	var p1: CharacterBody2D = arena.players[0]
	_reset_player_for_test(p1, zone.global_position)
	p1.set_spawn_protected(true)
	zone.arm(true)
	await _settle(int((0.1 + 0.1 + 0.2) * hz) + 4)
	_report("PROTECTION", "spawn protection blocks hazard damage through the existing pipeline", p1.health == p1.max_health, "health=%d/%d" % [p1.health, p1.max_health])
	_reset_player_for_test(p1, Vector2(960, -2000))
	zone.arm(false)

	# Defeated: a defeated body is off collision layer 2 entirely (player.gd's
	# set_defeated()), so the zone's own layer-2-only mask should never even
	# see it - the same "not there" mechanism every other M4-1 system reuses.
	var p2: CharacterBody2D = arena.players[1]
	_reset_player_for_test(p2, zone.global_position)
	p2.set_defeated(true)
	zone.arm(true)
	await _settle(int((0.1 + 0.1 + 0.2) * hz) + 4)
	_report("DEFEATED", "a Defeated player is ignored by the hazard (no crash, no damage-while-defeated)", p2.health == p2.max_health, "health=%d/%d is_defeated=%s" % [p2.health, p2.max_health, p2.is_defeated])
	_reset_player_for_test(p2, Vector2(960, -2000))
	_free_zone(zone)

# --- 5: Push/Freeze interaction with an active hazard, and Rocket's own regression ---

func _test_push_and_freeze_interaction() -> void:
	print("\n--- Push into an ACTIVE hazard; Freeze near a hazard remains vulnerable ---")
	var zone = _fresh_zone(0.05, 0.6, 0.05)  # long ACTIVE so a Push landing mid-window is reliably inside it
	var hz := physics_ticks_per_second()
	var p1: CharacterBody2D = arena.players[0]
	var p2: CharacterBody2D = arena.players[1]
	_clear_field([p1, p2])
	_reset_player_for_test(p1, zone.global_position + Vector2(-60, 0))
	_reset_player_for_test(p2, zone.global_position)
	zone.arm(true)
	await _settle(int((0.05 + 0.05) * hz) + 2)  # into ACTIVE
	_report("PUSH+HAZARD", "hazard is ACTIVE for this scenario", zone.state == zone.State.ACTIVE, "state=%d" % zone.state)

	# P1 pushes P2 further into the (already ACTIVE) zone. Per CLAUDE.md M4-2
	# S4: "do not secretly suppress one just because two damage sources occur
	# close together" - both a successful Push (1 pip, scripts/power_system.gd)
	# and the hazard's own bounded hit (1 pip) are allowed to land.
	p1.receive_power(PowerTypeScript.Type.PUSH)
	var used: bool = arena.power_system.try_activate(p1)
	await _settle(int(0.3 * hz))
	print("  (report, not asserted) Push into an ACTIVE hazard: push_used=%s P2 health=%d/%d (max %d pip from Push + up to 1 pip from the hazard this activation, %d if both land)" % [used, p2.health, p2.max_health, p2.max_health - 1, p2.max_health - 2])
	_report("PUSH+HAZARD", "combining Push with an ACTIVE hazard does not silently suppress either damage source (health dropped by at least 1)", p2.health <= p2.max_health - 1, "health=%d/%d" % [p2.health, p2.max_health])
	_reset_player_for_test(p1, Vector2(960, -2000))
	_reset_player_for_test(p2, Vector2(960, -2000))
	_free_zone(zone)

	# Freeze: a frozen player must remain a valid hazard target - no special-
	# case immunity, per CLAUDE.md M4-2 S4 ("Do not create special-case
	# immunity for Freeze").
	var zone2 = _fresh_zone(0.05, 0.3, 0.05)
	var p3: CharacterBody2D = arena.players[2]
	_reset_player_for_test(p3, zone2.global_position)
	arena.power_system.clear_freeze(p3)
	p3.controller.set_frozen(true)
	p3.set_frozen_visual(true)
	zone2.arm(true)
	await _settle(int((0.05 + 0.05 + 0.15) * hz) + 4)
	_report("FREEZE+HAZARD", "a frozen player caught by an activation still takes hazard damage (no special-case immunity)", p3.health == p3.max_health - 1, "health=%d/%d controller.frozen=%s" % [p3.health, p3.max_health, p3.controller.frozen])
	p3.controller.set_frozen(false)
	p3.set_frozen_visual(false)
	_reset_player_for_test(p3, Vector2(960, -2000))
	_free_zone(zone2)

func _test_rocket_unaffected() -> void:
	print("\n--- Rocket remains unchanged by the hazard system ---")
	var p1: CharacterBody2D = arena.players[0]
	var p2: CharacterBody2D = arena.players[1]
	_clear_field([p1, p2])
	_reset_player_for_test(p1, Vector2(500, 500))
	_reset_player_for_test(p2, Vector2(560, 500))
	p1.receive_power(PowerTypeScript.Type.ROCKET)
	arena.power_system.try_activate(p1)
	await _settle(20)
	_report("ROCKET", "Rocket still deals exactly 1 pip, unaffected by the hazard module existing", p2.health == p2.max_health - 1, "health=%d/%d" % [p2.health, p2.max_health])
	_reset_player_for_test(p1, Vector2(960, -2000))
	_reset_player_for_test(p2, Vector2(960, -2000))

# --- 6: defeat/spill/respawn when a hazard provides the final pip ------------

func _test_defeat_via_hazard() -> void:
	print("\n--- Defeat/spill/respawn still work when a hazard provides the final pip, through the same M4-2 reaction-window pipeline ---")
	var zone = _fresh_zone(0.05, 0.2, 0.05)
	var hz := physics_ticks_per_second()
	var p1: CharacterBody2D = arena.players[0]
	_reset_player_for_test(p1, zone.global_position)
	p1.receive_power(PowerTypeScript.Type.PUSH)
	arena.health_system.apply_damage(p1)
	arena.health_system.apply_damage(p1)
	_report("DEFEAT-BY-HAZARD", "target is at 1 health (Critical) before the hazard's killing blow", p1.health == 1, "health=%d" % p1.health)
	zone.arm(true)

	# Wait only until the hazard's lethal hit actually lands (is_dying flips
	# the instant health reaches 0) - this is the same reaction-window
	# architecture every power's lethal hit already uses (Game Director
	# playtest 2026-09-13: "a hazard-caused defeat should not create a
	# completely different defeat pipeline").
	await _settle(int((0.05 + 0.05 + 0.2) * hz) + 4)
	_report("DEFEAT-BY-HAZARD", "the lethal hazard hit opens the reaction window (is_dying, not yet Defeated)", p1.is_dying and not p1.is_defeated and p1.health == 0, "is_dying=%s is_defeated=%s health=%d" % [p1.is_dying, p1.is_defeated, p1.health])
	_report("DEFEAT-BY-HAZARD", "target remains visible during the reaction window", p1.visible, "visible=%s" % p1.visible)
	_report("DEFEAT-BY-HAZARD", "the carried power is still held during the reaction window (spill happens at _finish_defeat)", p1.has_power(), "carried_power=%d" % p1.carried_power)

	await _wait_for_defeated(p1)
	_report("DEFEAT-BY-HAZARD", "a hazard hit can cause Defeated once the reaction window elapses", p1.is_defeated and p1.health == 0, "is_defeated=%s health=%d" % [p1.is_defeated, p1.health])
	_report("DEFEAT-BY-HAZARD", "target disappears only after the reaction window elapses", not p1.visible, "visible=%s" % p1.visible)
	_report("DEFEAT-BY-HAZARD", "the carried power spilled (loot spill unchanged for a hazard-caused defeat)", not p1.has_power(), "carried_power=%d" % p1.carried_power)

	await _settle(int(arena.health_system.defeat_duration * hz) + 10)
	_report("DEFEAT-BY-HAZARD", "respawns cleanly via the same pipeline", not p1.is_defeated and not p1.is_dying and p1.health == p1.max_health, "is_defeated=%s is_dying=%s health=%d" % [p1.is_defeated, p1.is_dying, p1.health])
	_report("DEFEAT-BY-HAZARD", "spawn protection follows respawn exactly as it does for a power-caused defeat", p1.spawn_protected, "spawn_protected=%s" % p1.spawn_protected)
	_reset_player_for_test(p1, Vector2(960, -2000))
	_free_zone(zone)

## M4-2 - a helper local to this file mirroring tools/m4_1_check.gd's own
## _wait_for_defeated(): waits through the reaction window specifically,
## rather than a fixed frame count, so this test tracks the real exported
## reaction_duration value.
func _wait_for_defeated(target: CharacterBody2D, extra_budget_s: float = 1.0) -> void:
	var hz: float = physics_ticks_per_second()
	var max_frames := int((arena.health_system.reaction_duration + extra_budget_s) * hz)
	var frames := 0
	while target.is_dying and not target.is_defeated and frames < max_frames:
		await physics_frame
		frames += 1

# --- 7: hazard Areas do not alter collision/traversal geometry ---------------

func _test_geometry_unaffected() -> void:
	print("\n--- Hazard Areas do not alter collision/traversal geometry ---")
	for zone in arena.hazard_zones:
		_report("GEOMETRY", "%s has no collision_layer (Area2D only, never a physical obstacle)" % zone.name, zone.collision_layer == 0, "collision_layer=%d" % zone.collision_layer)
	_report("GEOMETRY", "exactly 3 authored hazard locations, per the M4-2 brief's 'do not cover the whole arena'", arena.hazard_zones.size() == 3, "count=%d" % arena.hazard_zones.size())

# --- 9: phase offsets are deterministic (Game Director playtest, 2026-09-12:
# three zones on identical timings read as one global timer) --------------

func _test_phase_offsets() -> void:
	print("\n--- Phase offsets: deterministic seeding, independent of real arm() time ---")

	var z0 = _fresh_zone(0.2, 0.3, 0.5)
	z0.phase_offset = 0.0
	z0.arm(true)
	_report("PHASE", "phase_offset=0.0 starts in SAFE, same as no offset at all", z0.state == z0.State.SAFE, "state=%d" % z0.state)
	_free_zone(z0)

	var z1 = _fresh_zone(0.2, 0.3, 0.5)
	z1.phase_offset = 0.5  # == safe_duration exactly
	z1.arm(true)
	_report("PHASE", "phase_offset == safe_duration seeds straight into WARNING", z1.state == z1.State.WARNING, "state=%d _clock=%.3f" % [z1.state, z1._clock])
	_free_zone(z1)

	var z2 = _fresh_zone(0.2, 0.3, 0.5)
	z2.phase_offset = 0.5 + 0.2 + 0.1  # safe + warning + 0.1s into active
	z2.arm(true)
	_report("PHASE", "an offset landing inside the active window seeds straight into ACTIVE", z2.state == z2.State.ACTIVE, "state=%d _clock=%.3f" % [z2.state, z2._clock])
	_free_zone(z2)

	var total := 0.5 + 0.2 + 0.3
	var z3 = _fresh_zone(0.2, 0.3, 0.5)
	z3.phase_offset = total + 0.05  # one full cycle plus a hair into the next SAFE
	z3.arm(true)
	_report("PHASE", "an offset longer than one full cycle wraps (fmod), landing back in SAFE", z3.state == z3.State.SAFE, "state=%d _clock=%.3f (cycle total=%.2f)" % [z3.state, z3._clock, total])
	_free_zone(z3)

	# The actual point of this feature: two zones, identical phase_offset and
	# timings, armed at different real moments (different amounts of prior
	# _settle()) must still land in the same state after the same tick count -
	# proving this is a deterministic seed, never real-clock-dependent
	# randomness. za and zb are measured after the SAME number of physics
	# ticks-since-arm() each (sequentially, not concurrently - _settle()
	# advances every armed zone in the tree, so overlapping their lifetimes
	# would give them different tick counts since their own arm() calls and
	# invalidate the comparison).
	var za = _fresh_zone(0.1, 0.15, 0.1)
	za.phase_offset = 0.12
	za.arm(true)
	await _settle(7)
	var za_state: int = za.state
	_free_zone(za)

	var zb = _fresh_zone(0.1, 0.15, 0.1)
	zb.phase_offset = 0.12
	zb.arm(true)
	await _settle(7)
	var zb_state: int = zb.state
	_report("PHASE", "identical phase_offset + timings reach the same state after the same tick count, regardless of when arm() was actually called", za_state == zb_state, "za_state=%d zb_state=%d" % [za_state, zb_state])
	_free_zone(zb)

# --- 10: phase offsets do not alter damage semantics ----------------------

func _test_phase_offset_damage_semantics() -> void:
	print("\n--- Phase offsets do not alter damage semantics (still exactly 1 pip per activation) ---")
	var hz := physics_ticks_per_second()

	var zone := _fresh_zone(0.1, 0.3, 0.1)
	zone.phase_offset = 0.1 + 0.05  # seed 0.05s into WARNING
	var p1: CharacterBody2D = arena.players[0]
	_reset_player_for_test(p1, zone.global_position)
	zone.arm(true)
	_report("PHASE-DAMAGE", "seeded mid-WARNING deals no damage yet", p1.health == p1.max_health and zone.state == zone.State.WARNING, "health=%d/%d state=%d" % [p1.health, p1.max_health, zone.state])
	await _settle(int(0.4 * hz) + 4)  # cross into and mostly through ACTIVE
	_report("PHASE-DAMAGE", "a WARNING-seeded zone still deals exactly 1 pip once ACTIVE arrives", p1.health == p1.max_health - 1, "health=%d/%d" % [p1.health, p1.max_health])
	_reset_player_for_test(p1, Vector2(960, -2000))
	_free_zone(zone)

	# Seeded directly INTO an active window at arm() time - must still cost
	# exactly 1 pip for that activation, never damage-on-arm plus
	# damage-on-the-next-tick.
	var zone2 := _fresh_zone(0.1, 0.4, 0.1)
	zone2.phase_offset = 0.1 + 0.1 + 0.05  # 0.05s already into ACTIVE
	var p2: CharacterBody2D = arena.players[1]
	_reset_player_for_test(p2, zone2.global_position)
	zone2.arm(true)
	await _settle(int(0.4 * hz) + 4)
	_report("PHASE-DAMAGE", "a zone seeded directly into ACTIVE still deals exactly 1 pip for that activation", p2.health == p2.max_health - 1, "health=%d/%d" % [p2.health, p2.max_health])
	_reset_player_for_test(p2, Vector2(960, -2000))
	_free_zone(zone2)

# --- 11: revised authored placement sanity (Game Director playtest,
# 2026-09-12: vertical distribution was too concentrated toward the lower
# arena) -------------------------------------------------------------------

func _test_authored_placement_sanity() -> void:
	print("\n--- Authored placement: outside every spawn, upper zone geometry-neutral and outside the vault ---")
	var spawn_positions: Array = []
	for marker_name in ["Spawn1", "Spawn2", "Spawn3", "Spawn4"]:
		spawn_positions.append(arena.get_node("Markers/%s" % marker_name).global_position)
	for zone in arena.hazard_zones:
		var half: Vector2 = zone.zone_size * 0.5
		var rect := Rect2(zone.global_position - half, zone.zone_size)
		for i in range(spawn_positions.size()):
			var sp: Vector2 = spawn_positions[i]
			_report("PLACEMENT", "%s does not overlap Spawn%d (no spawn is made immediately hazardous)" % [zone.name, i + 1], not rect.has_point(sp), "zone_rect=%s spawn=%s" % [rect, sp])
	var upper = arena.get_node("Hazards/Hazard_AE")
	_report("PLACEMENT", "Hazard_AE has no collision_layer (Area2D only, geometry/traversal-neutral)", upper.collision_layer == 0, "collision_layer=%d" % upper.collision_layer)
	# VaultSealW/VaultSealE (the vault's own upper boundary) sit at y=356,
	# top edge y=336 - Hazard_AE at y=272 sits on the A_E Crown platform
	# above and outside that, never inside the Relic chamber itself.
	_report("PLACEMENT", "Hazard_AE sits on the A_E Crown platform, above and outside the vault interior", upper.global_position.y < 336.0, "y=%.1f (vault interior begins at y>=336)" % upper.global_position.y)

# --- 8: diagnostic Arena Bites Lab soak (not gating PASS/FAIL) ---------------

func _diagnostic_arena_bites_soak() -> void:
	print("\n--- Diagnostic: Arena Bites Lab soak (bot-only, real Contact + hazard systems, not asserted) ---")
	const SOAK_DURATION := 180.0
	_restore_gravity()
	_clear_field([])
	for p in arena.players:
		p.controller.set_frozen(false)
	for i in range(arena.brains.size()):
		if arena.brains[i] != null:
			arena.brains[i].reset_goal()
	for p in arena.players:
		p.reset_to(Vector2(randf_range(400, 1600), 500))

	# Keyed by PowerType.label()'s own abbreviations (PSH/RKT/FRZ), not the
	# category names - keeps every dict below written from the same source
	# of truth the signals themselves already carry, with no separate
	# label-mapping step to fall out of sync.
	var uses := {"PSH": 0, "RKT": 0, "FRZ": 0}
	var hits := {"PSH": 0, "RKT": 0, "FRZ": 0}
	var pips := {"PSH": 0, "RKT": 0, "FRZ": 0, "HAZARD": 0}
	var defeats_by_source := {"PSH": 0, "RKT": 0, "FRZ": 0, "HAZARD": 0, "NONE": 0}
	# A Dictionary, not plain ints - GDScript lambdas below capture local
	# variables by value, so a plain `var spills := 0` mutated via `spills +=
	# 1` inside a lambda only ever updates the lambda's own captured copy,
	# never this outer scope. A Dictionary (or Array) is a reference type,
	# so `counters["spills"] += 1` correctly mutates the one shared object
	# every lambda below and the final report both see.
	var counters := {"spills": 0, "respawns": 0, "push_hazard_combo": 0, "freeze_hazard_combo": 0}
	var activations := {}
	for zone in arena.hazard_zones:
		activations[zone.name] = 0
	var occupants_seen := {}
	for zone in arena.hazard_zones:
		occupants_seen[zone.name] = {}
	var hard_recoveries_start := 0
	for b in arena.brains:
		if b != null:
			hard_recoveries_start += b.hard_recovery_count

	arena.set_hazards_armed(true)
	var last_active := {}
	for zone in arena.hazard_zones:
		last_active[zone.name] = false

	var on_used := func(slot_id, power_type):
		var label: String = PowerTypeScript.label(power_type)
		if uses.has(label):
			uses[label] += 1
	var on_hit := func(shooter_slot_id, target_slot_id, power_type):
		var label: String = PowerTypeScript.label(power_type)
		if hits.has(label):
			hits[label] += 1
		pips[label] = pips.get(label, 0) + 1
		# Player-interference-during-an-active-hazard combo counters, per
		# CLAUDE.md M4-2 S9 - approximate by "was any zone ACTIVE with the
		# target inside it at the moment the power landed".
		var target = null
		for p in arena.players:
			if p.slot_id == target_slot_id:
				target = p
		if target != null:
			for zone in arena.hazard_zones:
				if zone.state == zone.State.ACTIVE and zone.get_overlapping_bodies().has(target):
					if label == "PSH":
						counters["push_hazard_combo"] += 1
					elif label == "FRZ":
						counters["freeze_hazard_combo"] += 1
	var on_defeated := func(slot_id, power_type):
		var label: String
		if power_type == HealthSystemScript.HAZARD_SOURCE:
			label = "HAZARD"
		elif power_type == PowerTypeScript.Type.NONE:
			label = "NONE"
		else:
			label = PowerTypeScript.label(power_type)
		defeats_by_source[label] = defeats_by_source.get(label, 0) + 1
	var on_spilled := func(_slot_id, _power_type):
		counters["spills"] += 1
	var on_respawned := func(_slot_id):
		counters["respawns"] += 1
	var on_hazard_hit := func(_target_slot_id):
		pips["HAZARD"] += 1

	arena.power_system.power_used.connect(on_used)
	arena.power_system.power_hit.connect(on_hit)
	arena.health_system.player_defeated.connect(on_defeated)
	arena.health_system.power_spilled.connect(on_spilled)
	arena.health_system.player_respawned.connect(on_respawned)
	for zone in arena.hazard_zones:
		zone.hazard_hit.connect(on_hazard_hit)

	print("  running %.0fs of real Arena Bites Lab bot play (3 bots + 1 idle P1, armed hazards)..." % SOAK_DURATION)
	var ticks := int(SOAK_DURATION * physics_ticks_per_second())
	for t in range(ticks):
		await physics_frame
		for zone in arena.hazard_zones:
			var now_active: bool = zone.state == zone.State.ACTIVE
			if now_active and not last_active[zone.name]:
				activations[zone.name] += 1
			last_active[zone.name] = now_active
			if now_active:
				for body in zone.get_overlapping_bodies():
					if body is CharacterBody2D and "slot_id" in body:
						occupants_seen[zone.name][body.slot_id] = occupants_seen[zone.name].get(body.slot_id, 0) + 1

	arena.power_system.power_used.disconnect(on_used)
	arena.power_system.power_hit.disconnect(on_hit)
	arena.health_system.player_defeated.disconnect(on_defeated)
	arena.health_system.power_spilled.disconnect(on_spilled)
	arena.health_system.player_respawned.disconnect(on_respawned)
	for zone in arena.hazard_zones:
		zone.hazard_hit.disconnect(on_hazard_hit)
	arena.set_hazards_armed(false)

	var hard_recoveries_end := 0
	for b in arena.brains:
		if b != null:
			hard_recoveries_end += b.hard_recovery_count

	var total_pips := 0
	for k in pips:
		total_pips += pips[k]

	print("  --- Arena Bites Lab soak report (%.0fs) ---" % SOAK_DURATION)
	print("  hazard activations: %s" % activations)
	for zone_name in occupants_seen:
		print("  %s occupancy (physics-tick samples while ACTIVE, by slot): %s" % [zone_name, occupants_seen[zone_name]])
	print("  power uses:    %s" % uses)
	print("  power hits:    %s" % hits)
	print("  damage pips:   %s  (total=%d)" % [pips, total_pips])
	print("  defeats by final source: %s" % defeats_by_source)
	print("  spills: %d   respawns: %d" % [counters["spills"], counters["respawns"]])
	print("  Push->active-hazard combo occurrences: %d" % counters["push_hazard_combo"])
	print("  Freeze->active-hazard combo occurrences: %d" % counters["freeze_hazard_combo"])
	print("  hard nav recoveries during soak: %d" % (hard_recoveries_end - hard_recoveries_start))
	for zone_name in occupants_seen:
		for slot_id in occupants_seen[zone_name]:
			# "Repeatedly farming/dying to one zone" flag, per CLAUDE.md M4-2
			# S7/S9 - report only, never auto-corrected or used to add bot
			# hazard-avoidance.
			if occupants_seen[zone_name][slot_id] > int(SOAK_DURATION * physics_ticks_per_second() * 0.15):
				print("  [FLAG, report only] slot %d spent a large share of the soak inside %s while it was ACTIVE - candidate for a bot repeatedly farming/dying to one zone" % [slot_id, zone_name])
