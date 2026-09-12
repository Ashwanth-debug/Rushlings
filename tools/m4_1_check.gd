extends SceneTree

# M4-1 STOP 1+2+3+4 + the damage-model experiment - focused automated checks
# for the pickup/power-use/interference module, the health/defeat/spill/
# respawn/protection module, and the Push/Freeze-also-damage prototype
# (CLAUDE.md M4-1 S12 for STOP 1/2, the STOP 3+4 brief's own S11, and the
# damage-model experiment brief's own S6). Run headless:
#   godot --headless --script tools/m4_1_check.gd
#
# Loads the real arena_01.tscn (real geometry, real players, real
# PowerSystem/pickups) and drives it directly rather than building a
# synthetic rig - the same convention tools/door_arrival_check.gd already
# uses. Match Contact Lab (scripts/match_director.gd) is entered immediately
# so the Relic/gate loop cannot interfere with a run entirely about pickups
# and powers.
#
# This is deliberately separate from tools/arena_check.gd and
# tools/m3_check.gd, which must both still pass unmodified and ungated by
# anything here - see the M4-1 STOP 1/2 handoff report for those results.
#
# Deterministic PASS/FAIL sections (1-5) exercise PowerSystem/pickup/bot-hook
# APIs directly, exactly like tools/door_arrival_check.gd pokes at
# arena.match_director/arena.players directly. Section 6's emergent bot run
# is diagnostic only, the same PASS/FAIL-vs-diagnostic split arena_check.gd
# already uses for its own route-cost warnings - real bot play is
# non-deterministic by design (seeded RNG, curiosity, decorrelation) and
# must not gate the whole tool on one unlucky 20s sample.

const ARENA_SCENE_PATH := "res://scenes/arena_01/arena_01.tscn"
const PowerTypeScript := preload("res://scripts/power_type.gd")

var arena: Node2D
var fails: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== M4-1 STOP 1+2: pickup / power-use / interference checks ===\n")
	arena = (load(ARENA_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(arena)
	await physics_frame
	await physics_frame

	arena.match_director.enter_contact_lab()

	await _test_pickup_and_replacement()
	await _test_consumption()
	await _test_push()
	await _test_rocket()
	await _test_freeze()
	await _test_bot_mechanics()
	await _test_health()
	await _test_defeat()
	await _test_respawn()
	await _test_spawn_protection()
	await _test_repeated_cycles()
	await _test_defeat_by_each_power()
	await _test_mixed_combat_sequences()
	await _test_spawn_protection_power_paths()
	await _diagnostic_organic_combat()

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

func _clear_field(keep: Array) -> void:
	for p in arena.players:
		if not keep.has(p):
			p.reset_to(Vector2(-2000, -2000))
			# Sections 7+ run after _test_bot_mechanics()'s 30s emergent
			# bot-play diagnostic, in which bots can genuinely Rocket each
			# other and be defeated for real (HealthSystem is fully live in
			# this tool). Neutralise every bystander explicitly, not just
			# reposition it - an un-neutralised bystander could still be
			# mid-defeat and respawn onto a spawn anchor close enough to a
			# deterministic test's own bodies to become the accidental
			# nearest-player target for Push/Freeze.
			p.set_defeated(false)
			p.reset_health()
			p.set_spawn_protected(false)
			p.consume_power()
			arena.health_system._defeat_timers.erase(p)
			arena.health_system._protection_timers.erase(p)
			arena.power_system.clear_freeze(p)
			# Also fully pause the bystander for the rest of this
			# deterministic section - a still-roaming bot could otherwise
			# wander into range of a test body over a multi-second
			# defeat/respawn wait and become an accidental Push/Freeze
			# target. _reset_player_for_test()'s set_defeated(false) call
			# unfreezes any body that becomes an active participant again.
			p.controller.set_frozen(true)

# --- 1: pickup + replacement ------------------------------------------------

func _test_pickup_and_replacement() -> void:
	print("\n--- Pickup + replacement ---")
	var p1: CharacterBody2D = arena.players[0]
	var pickup_floor = arena.get_node("Pickups/Pickup_Floor")
	var pickup_cm = arena.get_node("Pickups/Pickup_CM")

	p1.consume_power()
	p1.reset_to(pickup_floor.global_position)
	await _settle(3)
	_report("PICKUP", "empty player touching a pickup receives its power", p1.carried_power == PowerTypeScript.Type.PUSH, "carried_power=%d (expected PUSH=%d)" % [p1.carried_power, PowerTypeScript.Type.PUSH])
	_report("PICKUP", "collected pickup stops offering itself", not pickup_floor.is_available(), "is_available()=%s" % pickup_floor.is_available())

	p1.reset_to(pickup_cm.global_position)
	await _settle(3)
	_report("PICKUP", "carrying A, touching B replaces A (not dropped, not stacked)", p1.carried_power == PowerTypeScript.Type.FREEZE, "carried_power=%d (expected FREEZE=%d)" % [p1.carried_power, PowerTypeScript.Type.FREEZE])
	p1.consume_power()

# --- 2: one-use consumption --------------------------------------------------

func _test_consumption() -> void:
	print("\n--- One-use consumption ---")
	var p1: CharacterBody2D = arena.players[0]
	var p2: CharacterBody2D = arena.players[1]
	_clear_field([p1, p2])
	p1.reset_to(Vector2(500, 500))
	p2.reset_to(Vector2(560, 500))
	await _settle(2)

	p1.receive_power(PowerTypeScript.Type.PUSH)
	var used: bool = arena.power_system.try_activate(p1)
	_report("CONSUME", "a valid use consumes the power exactly once", used and not p1.has_power(), "try_activate=%s has_power()=%s" % [used, p1.has_power()])

	var used_again: bool = arena.power_system.try_activate(p1)
	_report("CONSUME", "an empty slot cannot be re-activated", not used_again, "second try_activate() on an empty slot = %s" % used_again)

# --- 3: Push -----------------------------------------------------------------

func _test_push() -> void:
	print("\n--- Push ---")
	var p1: CharacterBody2D = arena.players[0]
	var p2: CharacterBody2D = arena.players[1]
	_clear_field([p1, p2])
	# _clear_field() only neutralises bystanders (P3/P4) - P1/P2 are the kept
	# participants here, but health must still start clean: PowerSystem is
	# fully live for this entire tool from frame one, so a bot could
	# organically land a real hit on P2 during an earlier section's brief
	# _settle() waits, which the damage-model experiment's new health
	# assertions below would otherwise misread as this test's own result.
	p1.reset_health()
	p2.reset_health()
	p1.reset_to(Vector2(500, 900))
	p2.reset_to(Vector2(560, 900))
	await _settle(3)
	p1.velocity = Vector2.ZERO
	p2.velocity = Vector2.ZERO

	p1.receive_power(PowerTypeScript.Type.PUSH)
	arena.power_system.try_activate(p1)
	await physics_frame
	_report("PUSH", "affects another player (real displacement)", p2.velocity.length() > 200.0, "P2 velocity after Push = %s" % p2.velocity)
	_report("PUSH", "does not affect the user", p1.velocity.length() < 100.0, "P1 velocity after using Push = %s" % p1.velocity)
	_report("PUSH", "does not alter permanent M1 movement tuning", p1.jump_strength == 900.0 and p1.max_speed == 500.0, "jump_strength=%.1f max_speed=%.1f" % [p1.jump_strength, p1.max_speed])
	# M4-1 damage-model experiment: a successful Push now also deals exactly
	# 1 pip, alongside (not instead of) the displacement above.
	_report("PUSH", "a successful hit deals exactly 1 pip damage", p2.health == p2.max_health - 1, "P2 health=%d/%d" % [p2.health, p2.max_health])
	_report("PUSH", "cannot damage the user (self-exclusion)", p1.health == p1.max_health, "P1 health=%d/%d after using Push" % [p1.health, p1.max_health])

	# Invalid case: nobody within range - must not consume, must not damage.
	_reset_player_for_test(p2, Vector2(500 + arena.power_system.interaction_radius + 400.0, 900))
	await _settle(2)
	p1.receive_power(PowerTypeScript.Type.PUSH)
	var used_invalid: bool = arena.power_system.try_activate(p1)
	_report("PUSH", "invalid activation (no target in range) is not consumed", not used_invalid and p1.has_power(), "try_activate=%s has_power()=%s" % [used_invalid, p1.has_power()])
	_report("PUSH", "invalid activation deals 0 damage", p2.health == p2.max_health, "P2 health=%d/%d" % [p2.health, p2.max_health])
	p1.consume_power()

# --- 4: Rocket ----------------------------------------------------------------

func _test_rocket() -> void:
	print("\n--- Rocket ---")
	var p1: CharacterBody2D = arena.players[0]
	var p2: CharacterBody2D = arena.players[1]
	_clear_field([p1, p2])
	p1.reset_health()
	p2.reset_health()
	p1.reset_to(Vector2(500, 900))
	p1.facing_dir = 1.0
	p2.reset_to(Vector2(700, 900))
	await _settle(2)

	var hits: Array = []
	var on_hit := func(shooter: int, target: int, power_type: int): hits.append([shooter, target, power_type])
	arena.power_system.power_hit.connect(on_hit)

	p1.receive_power(PowerTypeScript.Type.ROCKET)
	var used: bool = arena.power_system.try_activate(p1)
	_report("ROCKET", "always valid to fire (no aiming input, no target requirement)", used, "try_activate=%s" % used)
	_report("ROCKET", "consumed on FIRE, not on hit", not p1.has_power(), "has_power()=%s immediately after firing" % p1.has_power())

	var projectiles: Node = arena.get_node("Projectiles")
	_report("ROCKET", "spawns a real travelling projectile", projectiles.get_child_count() > 0, "Projectiles child count = %d" % projectiles.get_child_count())

	var frames := 0
	while hits.is_empty() and frames < 90:
		await physics_frame
		frames += 1
	_report("ROCKET", "hits another player it travels into", hits.size() >= 1, "hit events after %d frames = %d" % [frames, hits.size()])
	_report("ROCKET", "produces exactly one HIT event", hits.size() == 1, "hit events = %d" % hits.size())
	_report("ROCKET", "a hit deals exactly 1 pip damage", p2.health == p2.max_health - 1, "P2 health=%d/%d" % [p2.health, p2.max_health])
	arena.power_system.power_hit.disconnect(on_hit)

	# A miss (nothing in the flight path) must deal 0 damage to anyone -
	# firing is still the committed action and still consumes (already
	# proven above), independent of whether it connects.
	_reset_player_for_test(p2, Vector2(-2000, -2000))
	p1.reset_to(Vector2(500, 900))
	p1.facing_dir = 1.0
	await _settle(2)
	p1.receive_power(PowerTypeScript.Type.ROCKET)
	arena.power_system.try_activate(p1)
	await _settle(int(arena.power_system.rocket_lifetime * physics_ticks_per_second()) + 10)
	var all_full_health := true
	for p in arena.players:
		if p.health != p.max_health:
			all_full_health = false
	_report("ROCKET", "a miss deals 0 damage to any player", all_full_health, "all players' health after a rocket flew through empty space")

	# Owner exclusion: fire again with nobody else nearby - cannot self-hit.
	var self_hits: Array = []
	var on_self_hit := func(shooter: int, target: int, power_type: int): self_hits.append([shooter, target, power_type])
	arena.power_system.power_hit.connect(on_self_hit)
	p2.reset_to(Vector2(-2000, -2000))
	p1.reset_to(Vector2(500, 900))
	await _settle(2)
	p1.receive_power(PowerTypeScript.Type.ROCKET)
	arena.power_system.try_activate(p1)
	await _settle(3)
	_report("ROCKET", "cannot immediately hit its own owner", self_hits.is_empty(), "self-hit events = %d" % self_hits.size())
	arena.power_system.power_hit.disconnect(on_self_hit)

	# Bounded lifetime/range: with nothing to hit, it must still disappear.
	p1.receive_power(PowerTypeScript.Type.ROCKET)
	arena.power_system.try_activate(p1)
	var hz: float = physics_ticks_per_second()
	var max_frames := int(arena.power_system.rocket_lifetime * hz) + 60
	var life_frames := 0
	while projectiles.get_child_count() > 0 and life_frames < max_frames:
		await physics_frame
		life_frames += 1
	_report("ROCKET", "has a bounded lifetime/range - never passes indefinitely through the arena", projectiles.get_child_count() == 0, "still alive after %d/%d frames" % [life_frames, max_frames])

# --- 5: Freeze -----------------------------------------------------------------

func _test_freeze() -> void:
	print("\n--- Freeze ---")
	var p1: CharacterBody2D = arena.players[0]
	var p2: CharacterBody2D = arena.players[1]
	_clear_field([p1, p2])
	p1.reset_health()
	p2.reset_health()
	p1.reset_to(Vector2(500, 900))
	p2.reset_to(Vector2(560, 900))
	await _settle(2)

	var before_zone: bool = p2.in_traversal_zone
	var before_climb: bool = p2.is_climbing
	var freeze_duration: float = arena.power_system.freeze_duration

	p1.receive_power(PowerTypeScript.Type.FREEZE)
	var used: bool = arena.power_system.try_activate(p1)
	_report("FREEZE", "targets another player and locks their input", used and p2.controller.frozen, "try_activate=%s p2.controller.frozen=%s" % [used, p2.controller.frozen])
	_report("FREEZE", "a locked target reports zero movement/action intent", p2.controller.horizontal() == 0.0 and p2.controller.vertical() == 0.0 and not p2.controller.jump_pressed(false), "horizontal=%.2f vertical=%.2f" % [p2.controller.horizontal(), p2.controller.vertical()])
	# M4-1 damage-model experiment: a successful Freeze now also deals
	# exactly 1 pip - duration is unchanged (still freeze_duration, not
	# lengthened because it now damages).
	_report("FREEZE", "a successful hit deals exactly 1 pip damage", p2.health == p2.max_health - 1, "P2 health=%d/%d" % [p2.health, p2.max_health])

	var hz: float = physics_ticks_per_second()
	var max_frames := int((freeze_duration + 1.0) * hz)
	var frames := 0
	while p2.controller.frozen and frames < max_frames:
		await physics_frame
		frames += 1
	_report("FREEZE", "expires on its own and restores movement/action (target survived the hit)", not p2.controller.frozen and p2.health > 0, "still frozen after %.2fs (expected ~%.2fs), health=%d" % [frames / hz, freeze_duration, p2.health])
	_report("FREEZE", "traversal/ladder ownership is untouched by the freeze cycle", p2.in_traversal_zone == before_zone and p2.is_climbing == before_climb, "in_traversal_zone %s->%s, is_climbing %s->%s" % [before_zone, p2.in_traversal_zone, before_climb, p2.is_climbing])

	# Invalid case: nobody within range - must not consume, must not damage.
	# _clear_field() both moves P2 out of range and resets its health to a
	# clean baseline.
	_clear_field([p1])
	await _settle(2)
	p1.receive_power(PowerTypeScript.Type.FREEZE)
	var used_invalid: bool = arena.power_system.try_activate(p1)
	_report("FREEZE", "invalid activation (no target in range) is not consumed", not used_invalid and p1.has_power(), "try_activate=%s has_power()=%s" % [used_invalid, p1.has_power()])
	_report("FREEZE", "invalid activation deals 0 damage", p2.health == p2.max_health, "P2 health=%d/%d" % [p2.health, p2.max_health])
	p1.consume_power()

# --- 6: bots ---------------------------------------------------------------

func _test_bot_mechanics() -> void:
	print("\n--- Bots: SEEK_PICKUP / USE_POWER hooks, then a short emergent run ---")
	var brain: BotBrain = arena.brains[1]
	var body: CharacterBody2D = arena.players[1]
	body.consume_power()
	brain.current_node = "Floor"

	var offered := false
	for _i in range(50):
		if brain._pick_pickup_target() != "":
			offered = true
			break
	_report("BOT", "SEEK_PICKUP can select an available, reliably-reachable pickup node", offered, "a pickup target was offered within 50 tries")

	var other: CharacterBody2D = arena.players[2]
	other.reset_to(body.global_position + Vector2(50, 0))
	body.receive_power(PowerTypeScript.Type.PUSH)
	brain._use_power_clock = 0.0
	brain._update_use_power(0.1)
	_report("BOT", "USE_POWER raises intent when carrying a power with a target nearby", brain.consume_power_intent(), "consume_power_intent() after a positive _update_use_power() check")
	body.consume_power()

	# The deterministic tests above repeatedly teleport bodies (including bot
	# bodies, via _clear_field()) to force specific scenarios - a real reset
	# gives the diagnostic a clean, representative fresh-round starting point
	# instead of measuring recovery from test-induced teleportation.
	arena._full_reset()
	arena.match_director.enter_contact_lab()
	await _settle(5)

	print("  (diagnostic, does not gate PASS/FAIL) running 30s of real bot play from a fresh round...")
	# A Dictionary, not a plain int, because GDScript lambdas capture outer
	# local value-typed variables by value, not by reference - `uses += 1`
	# inside the lambda would silently mutate a copy.
	var use_counts: Dictionary = {PowerTypeScript.Type.PUSH: 0, PowerTypeScript.Type.ROCKET: 0, PowerTypeScript.Type.FREEZE: 0}
	var on_use := func(_slot: int, power_type: int): use_counts[power_type] = use_counts.get(power_type, 0) + 1
	arena.power_system.power_used.connect(on_use)
	var seen_power: Dictionary = {}
	var t := 0.0
	var hz: float = physics_ticks_per_second()
	while t < 30.0:
		await physics_frame
		t += 1.0 / hz
		for i in [1, 2, 3]:
			if arena.players[i].has_power() and not seen_power.get(i, false):
				seen_power[i] = true
	arena.power_system.power_used.disconnect(on_use)
	var total_uses: int = use_counts.values().reduce(func(a, b): return a + b, 0)
	print("  (diagnostic) bots that picked up a power at least once in 30s: %d/3, power_used events: %d (PUSH=%d ROCKET=%d FREEZE=%d)" % [seen_power.size(), total_uses, use_counts[PowerTypeScript.Type.PUSH], use_counts[PowerTypeScript.Type.ROCKET], use_counts[PowerTypeScript.Type.FREEZE]])
	for i in [1, 2, 3]:
		print("  (diagnostic) P%d stall stage3 (hard-stuck) count: %d" % [i + 1, arena.brains[i].stage3_count])

# --- Shared health/defeat/respawn helpers -----------------------------------

## A known-clean slate before each health/defeat/respawn test: full health,
## alive, unprotected, empty-handed, planted well clear of everyone else so
## Push/Freeze/pickup proximity from other bodies can't contaminate the
## measurement.
func _reset_player_for_test(p: CharacterBody2D, pos: Vector2) -> void:
	p.reset_to(pos)
	p.velocity = Vector2.ZERO
	p.set_defeated(false)
	p.reset_health()
	p.set_spawn_protected(false)
	p.consume_power()
	# Also drop any pending HealthSystem timer for this body - flipping the
	# flags directly (above) bypasses the timer dictionaries a real
	# respawn/expiry would clear together (scripts/health_system.gd's
	# _respawn()/_update_protection_timers()), so a timer from an earlier
	# test section could otherwise fire later and print a confusing
	# "protection expired" mid a later, unrelated test.
	arena.health_system._defeat_timers.erase(p)
	arena.health_system._protection_timers.erase(p)

## Drives the real pipeline (arena.health_system.apply_damage), not a direct
## health mutation - exactly what the debug damage key and a real Rocket hit
## both go through.
func _hit(p: CharacterBody2D) -> bool:
	return arena.health_system.apply_damage(p)

# --- 7: Health ---------------------------------------------------------------

func _test_health() -> void:
	print("\n--- Health ---")
	var p1: CharacterBody2D = arena.players[0]
	var p2: CharacterBody2D = arena.players[1]
	_clear_field([p1, p2])
	_reset_player_for_test(p1, Vector2(500, 500))
	_reset_player_for_test(p2, Vector2(1200, 500))

	_report("HEALTH", "starts at max_health (3)", p1.health == 3, "health=%d" % p1.health)

	_hit(p1)
	_report("HEALTH", "a valid hit removes exactly 1 pip (3 -> 2)", p1.health == 2, "health=%d" % p1.health)
	_hit(p1)
	_report("HEALTH", "next valid hit -> 1 (Critical)", p1.health == 1, "health=%d" % p1.health)
	_hit(p1)
	_report("HEALTH", "next valid hit -> 0 and Defeated", p1.health == 0 and p1.is_defeated, "health=%d is_defeated=%s" % [p1.health, p1.is_defeated])
	_reset_player_for_test(p1, Vector2(500, 500))

	# M4-1 damage-model experiment (Game Director finding after STOP 3/4
	# playtest): Push and Freeze now deal 1 pip on a SUCCESSFUL hit too, not
	# just Rocket - the exact same "found a valid target" condition that
	# already gated their consumption. Detailed per-power damage/invalid/
	# self/miss coverage lives in _test_push()/_test_rocket()/_test_freeze()
	# below; this just confirms the headline change at the health level.
	p1.reset_to(Vector2(500, 500))
	p2.reset_to(Vector2(560, 500))
	p1.receive_power(PowerTypeScript.Type.PUSH)
	arena.power_system.try_activate(p1)
	_report("HEALTH", "a successful Push deals exactly 1 pip", p2.health == p2.max_health - 1, "P2 health=%d/%d after being Pushed" % [p2.health, p2.max_health])

	_reset_player_for_test(p1, Vector2(500, 500))
	_reset_player_for_test(p2, Vector2(1200, 500))
	p1.reset_to(Vector2(500, 500))
	p2.reset_to(Vector2(560, 500))
	p1.receive_power(PowerTypeScript.Type.FREEZE)
	arena.power_system.try_activate(p1)
	_report("HEALTH", "a successful Freeze deals exactly 1 pip", p2.health == p2.max_health - 1, "P2 health=%d/%d after being Frozen" % [p2.health, p2.max_health])
	_reset_player_for_test(p1, Vector2(500, 500))
	_reset_player_for_test(p2, Vector2(1200, 500))

# --- 8: Defeat ---------------------------------------------------------------

func _test_defeat() -> void:
	print("\n--- Defeat ---")
	var p1: CharacterBody2D = arena.players[0]
	var p2: CharacterBody2D = arena.players[1]
	_clear_field([p1, p2])
	_reset_player_for_test(p1, Vector2(500, 500))
	_reset_player_for_test(p2, Vector2(1200, 500))

	p1.receive_power(PowerTypeScript.Type.ROCKET)
	for _i in range(3):
		_hit(p1)
	_report("DEFEAT", "reaching 0 health enters Defeated", p1.is_defeated, "is_defeated=%s health=%d" % [p1.is_defeated, p1.health])
	_report("DEFEAT", "an unused carried power spills, slot becomes empty", not p1.has_power(), "carried_power=%d" % p1.carried_power)

	var spilled: Node = _find_pickup_near(p1.global_position, PowerTypeScript.Type.ROCKET)
	_report("DEFEAT", "the exact carried power spills into the world", spilled != null, "a ROCKET pickup near the defeat position: %s" % (spilled != null))

	_report("DEFEAT", "no movement input while Defeated", p1.controller.horizontal() == 0.0 and p1.controller.vertical() == 0.0, "horizontal=%.2f vertical=%.2f" % [p1.controller.horizontal(), p1.controller.vertical()])
	_report("DEFEAT", "no jump while Defeated", not p1.controller.jump_pressed(false), "jump_pressed()=%s" % p1.controller.jump_pressed(false))
	_report("DEFEAT", "no power use while Defeated", not p1.controller.power_pressed(), "power_pressed()=%s" % p1.controller.power_pressed())
	_report("DEFEAT", "cannot collect a pickup while Defeated (off collision layer 2)", not p1.get_collision_layer_value(2), "collision layer 2 = %s" % p1.get_collision_layer_value(2))

	if spilled != null:
		p2.reset_to(spilled.global_position)
		await _settle(3)
		_report("DEFEAT", "another active player can collect the spilled power", p2.carried_power == PowerTypeScript.Type.ROCKET, "P2 carried_power=%d (expected ROCKET=%d)" % [p2.carried_power, PowerTypeScript.Type.ROCKET])

	# Clean slate for later tests - do not wait out the real defeat timer here.
	_reset_player_for_test(p1, Vector2(500, 500))
	_reset_player_for_test(p2, Vector2(1200, 500))

	# An empty-handed defeat must not spill anything.
	var pickups_before: int = arena.get_node("Pickups").get_child_count()
	for _i in range(3):
		_hit(p1)
	var pickups_after: int = arena.get_node("Pickups").get_child_count()
	_report("DEFEAT", "does not spill anything if the player was empty", p1.is_defeated and not p1.has_power() and pickups_after == pickups_before, "is_defeated=%s pickups %d -> %d" % [p1.is_defeated, pickups_before, pickups_after])

	_reset_player_for_test(p1, Vector2(500, 500))
	_reset_player_for_test(p2, Vector2(1200, 500))

func _find_pickup_near(pos: Vector2, power_type: int, radius: float = 80.0) -> Node:
	for pickup in arena.get_node("Pickups").get_children():
		if is_instance_valid(pickup) and pickup.is_available() and pickup.power_type == power_type and pickup.global_position.distance_to(pos) <= radius:
			return pickup
	return null

# --- 9: Respawn ---------------------------------------------------------------

func _test_respawn() -> void:
	print("\n--- Respawn ---")
	var p1: CharacterBody2D = arena.players[0]
	var bot_body: CharacterBody2D = arena.players[1]
	var bot_brain: BotBrain = arena.brains[1]
	_clear_field([p1, bot_body])
	_reset_player_for_test(p1, Vector2(500, 500))
	_reset_player_for_test(bot_body, Vector2(1200, 500))

	# Give the bot an in-flight nav goal, exactly the "mid-edge when defeated"
	# scenario handle_respawn() exists for.
	bot_brain.current_node = "Floor"
	bot_brain.target_node = "C_M"
	bot_brain.path = [{"from": "Floor", "to": "C_M", "type": "jump", "cost": 1.0}]
	bot_brain.path_index = 0

	for _i in range(3):
		_hit(p1)
		_hit(bot_body)
	_report("RESPAWN", "P1 (human) reaches Defeated", p1.is_defeated, "is_defeated=%s" % p1.is_defeated)
	_report("RESPAWN", "P2 (bot) reaches Defeated", bot_body.is_defeated, "is_defeated=%s" % bot_body.is_defeated)

	var hz: float = physics_ticks_per_second()
	var max_frames := int((arena.health_system.defeat_duration + 1.0) * hz)
	var frames := 0
	while (p1.is_defeated or bot_body.is_defeated) and frames < max_frames:
		await physics_frame
		frames += 1
	var respawn_elapsed: float = frames / hz

	# M4-1 tuning pass (Game Director feedback: 3.0s "feels noticeably too
	# slow"): defeat_duration is now 1.5s. Verify the respawn actually
	# happens at approximately the CURRENT exported value, not a
	# hard-coded 3.0s left over from the previous tuning pass.
	_report("RESPAWN", "respawn happens at approximately defeat_duration (%.2fs)" % arena.health_system.defeat_duration, abs(respawn_elapsed - arena.health_system.defeat_duration) < 0.2, "measured %.2fs, expected ~%.2fs" % [respawn_elapsed, arena.health_system.defeat_duration])

	# Every check below must read state from the INSTANT of respawn, before
	# waiting out spawn protection - a live, un-frozen bot resumes real ROAM
	# during that ~0.8s wait and will legitimately have picked a brand new
	# target/path by the time it ends, which is correct behaviour, not
	# staleness, and must not be misread as handle_respawn() having failed.
	_report("RESPAWN", "P1 returns to full health", p1.health == p1.max_health, "health=%d/%d" % [p1.health, p1.max_health])
	_report("RESPAWN", "P1's carried slot is empty", not p1.has_power(), "carried_power=%d" % p1.carried_power)
	_report("RESPAWN", "P1 lands on a valid authored spawn anchor", _is_at_spawn_anchor(p1.global_position), "position=%s" % p1.global_position)
	_report("RESPAWN", "P1 velocity is reset (no launch/fall carried over)", p1.velocity.length() < 100.0, "velocity=%s" % p1.velocity)
	_report("RESPAWN", "P1 traversal state is valid (not stuck owning a ladder)", not p1.in_traversal_zone and not p1.is_climbing, "in_traversal_zone=%s is_climbing=%s" % [p1.in_traversal_zone, p1.is_climbing])
	_report("RESPAWN", "P1 controller/active state resumed (not frozen)", not p1.controller.frozen, "controller.frozen=%s" % p1.controller.frozen)

	_report("RESPAWN", "P2 (bot) returns to full health and empty-handed", bot_body.health == bot_body.max_health and not bot_body.has_power(), "health=%d carried_power=%d" % [bot_body.health, bot_body.carried_power])
	_report("RESPAWN", "P2's stale pre-defeat path/executor was cleared (handle_respawn)", bot_brain.target_node == "" and bot_brain.path.is_empty() and bot_brain.executor == null, "target_node='%s' path.size()=%d executor=%s" % [bot_brain.target_node, bot_brain.path.size(), bot_brain.executor])
	_report("RESPAWN", "P2's bot controller resumes (not frozen)", not bot_body.controller.frozen, "controller.frozen=%s" % bot_body.controller.frozen)

	# Spawn protection must begin AT respawn, not be shortened/lengthened by
	# however long the defeat window itself was - measure the protection
	# window's own real duration in isolation from defeat_duration. Must run
	# AFTER the immediate-post-respawn checks above, not before (see note).
	var protection_frames := 0
	var protection_max_frames := int((arena.health_system.spawn_protection_duration + 1.0) * hz)
	while p1.spawn_protected and protection_frames < protection_max_frames:
		await physics_frame
		protection_frames += 1
	var protection_elapsed: float = protection_frames / hz
	_report("RESPAWN", "0.8s spawn protection begins from respawn, not from defeat", abs(protection_elapsed - arena.health_system.spawn_protection_duration) < 0.2, "protection measured %.2fs from the moment of respawn, expected ~%.2fs (independent of defeat_duration=%.2fs)" % [protection_elapsed, arena.health_system.spawn_protection_duration, arena.health_system.defeat_duration])

	_reset_player_for_test(p1, Vector2(500, 500))
	_reset_player_for_test(bot_body, Vector2(1200, 500))

func _is_at_spawn_anchor(pos: Vector2, tol: float = 4.0) -> bool:
	for anchor in arena._spawn_anchor_positions():
		if pos.distance_to(anchor) <= tol:
			return true
	return false

# --- 10: Spawn protection -----------------------------------------------------

func _test_spawn_protection() -> void:
	print("\n--- Spawn protection ---")
	var p1: CharacterBody2D = arena.players[0]
	var p2: CharacterBody2D = arena.players[1]
	_clear_field([p1, p2])
	_reset_player_for_test(p1, Vector2(500, 500))
	_reset_player_for_test(p2, Vector2(1200, 500))

	p1.set_spawn_protected(true)
	var absorbed: bool = _hit(p1)
	_report("PROTECTION", "incoming damage is ignored during protection", not absorbed and p1.health == p1.max_health, "apply_damage()=%s health=%d/%d" % [absorbed, p1.health, p1.max_health])
	_report("PROTECTION", "movement remains available during protection", not p1.controller.frozen, "controller.frozen=%s" % p1.controller.frozen)

	p1.set_spawn_protected(false)
	var landed: bool = _hit(p1)
	_report("PROTECTION", "damage resumes once protection expires", landed and p1.health == p1.max_health - 1, "apply_damage()=%s health=%d/%d" % [landed, p1.health, p1.max_health])

	_reset_player_for_test(p1, Vector2(500, 500))
	_reset_player_for_test(p2, Vector2(1200, 500))

# --- 11: Repeated defeat -> respawn cycles ------------------------------------

func _test_repeated_cycles() -> void:
	print("\n--- Repeated defeat -> respawn cycles (human + bot) ---")
	var p1: CharacterBody2D = arena.players[0]
	var bot_body: CharacterBody2D = arena.players[1]
	var bot_brain: BotBrain = arena.brains[1]
	_clear_field([p1, bot_body])
	_reset_player_for_test(p1, Vector2(500, 500))
	_reset_player_for_test(bot_body, Vector2(1200, 500))

	var hz: float = physics_ticks_per_second()
	var max_frames := int((arena.health_system.defeat_duration + arena.health_system.spawn_protection_duration + 1.5) * hz)

	for cycle in range(3):
		# Deliberately empty-handed going into each defeat - spill is already
		# covered by _test_defeat() above. Giving a power here would spill a
		# pickup at the defeat position every cycle, and a respawn anchor can
		# legitimately land close enough to it to recollect it for real
		# (spawn selection has no reason to know or care where a spill
		# landed) - a genuine game interaction, but one that would pollute
		# this test's own "no stale power" measurement with a real, fresh
		# pickup rather than anything actually stale.
		for _i in range(3):
			_hit(p1)
			_hit(bot_body)
		var frames := 0
		while (p1.is_defeated or bot_body.is_defeated or p1.spawn_protected or bot_body.spawn_protected) and frames < max_frames:
			await physics_frame
			frames += 1
		var clean: bool = (
			not p1.is_defeated and not bot_body.is_defeated
			and not p1.controller.frozen and not bot_body.controller.frozen
			and not p1.has_power() and not bot_body.has_power()
			and not p1.spawn_protected and not bot_body.spawn_protected
			and not p1.in_traversal_zone and not bot_body.in_traversal_zone
			and p1.health == p1.max_health and bot_body.health == bot_body.max_health
		)
		_report("CYCLE", "cycle %d/3 leaves no stale frozen/power/protection/traversal state" % (cycle + 1), clean, "P1: defeated=%s frozen=%s power=%d protected=%s | P2: defeated=%s frozen=%s power=%d protected=%s" % [p1.is_defeated, p1.controller.frozen, p1.carried_power, p1.spawn_protected, bot_body.is_defeated, bot_body.controller.frozen, bot_body.carried_power, bot_body.spawn_protected])
		p1.reset_to(Vector2(500, 500))
		bot_body.reset_to(Vector2(1200, 500))

	_reset_player_for_test(p1, Vector2(500, 500))
	_reset_player_for_test(bot_body, Vector2(1200, 500))

# --- 12: Defeat caused by each power (damage-model experiment) -------------

func _test_defeat_by_each_power() -> void:
	print("\n--- Defeat caused by each power (damage-model experiment) ---")
	await _defeat_via_power(PowerTypeScript.Type.PUSH, "PUSH")
	await _defeat_via_power(PowerTypeScript.Type.FREEZE, "FREEZE")
	await _defeat_via_power(PowerTypeScript.Type.ROCKET, "ROCKET")

## Brings target to 1 health via the raw pipeline, then lands the killing
## blow with `power_type` specifically - proving all three route through the
## same defeat/spill/respawn machinery (not three separate implementations),
## and checking the two interactions the Game Director explicitly flagged:
## a Freeze-caused defeat must not leave a stale PowerSystem freeze timer,
## and a Push-caused defeat must not leave a corrupted velocity/traversal
## state (scripts/health_system.gd's _defeat() already zeroes velocity and
## calls power_system.clear_freeze() unconditionally - this proves it holds
## for these two specific trigger powers, not just for Rocket).
func _defeat_via_power(power_type: int, label: String) -> void:
	var target: CharacterBody2D = arena.players[0]
	var attacker: CharacterBody2D = arena.players[1]
	_clear_field([target, attacker])
	_reset_player_for_test(target, Vector2(500, 900))
	_reset_player_for_test(attacker, Vector2(560, 900))
	_hit(target)
	_hit(target)
	_report("DEFEAT-BY-%s" % label, "target is at 1 health (Critical) before the killing blow", target.health == 1, "health=%d" % target.health)

	attacker.reset_to(Vector2(560, 900))
	attacker.facing_dir = -1.0
	attacker.receive_power(power_type)
	arena.power_system.try_activate(attacker)
	if power_type == PowerTypeScript.Type.ROCKET:
		var hit_frames := 0
		while not target.is_defeated and hit_frames < 90:
			await physics_frame
			hit_frames += 1

	_report("DEFEAT-BY-%s" % label, "%s can cause Defeated" % label, target.is_defeated, "is_defeated=%s health=%d" % [target.is_defeated, target.health])
	_report("DEFEAT-BY-%s" % label, "uses the same defeat pipeline (defeat timer armed)", arena.health_system._defeat_timers.has(target), "_defeat_timers.has(target)=%s" % arena.health_system._defeat_timers.has(target))

	if power_type == PowerTypeScript.Type.FREEZE:
		_report("FREEZE", "a Freeze-caused defeat does not leave a stale PowerSystem freeze timer", not arena.power_system._frozen_timers.has(target), "_frozen_timers.has(target)=%s" % arena.power_system._frozen_timers.has(target))
	if power_type == PowerTypeScript.Type.PUSH:
		_report("PUSH", "a Push-caused defeat zeroes velocity immediately (no corrupted movement state)", target.velocity == Vector2.ZERO, "velocity=%s" % target.velocity)

	# Let the full respawn cycle complete and verify cleanliness either way.
	var hz: float = physics_ticks_per_second()
	var max_frames := int((arena.health_system.defeat_duration + 1.0) * hz)
	var frames := 0
	while target.is_defeated and frames < max_frames:
		await physics_frame
		frames += 1
	_report("DEFEAT-BY-%s" % label, "respawns cleanly via the same pipeline", not target.is_defeated and target.health == target.max_health and not target.controller.frozen, "is_defeated=%s health=%d controller.frozen=%s" % [target.is_defeated, target.health, target.controller.frozen])
	if power_type == PowerTypeScript.Type.FREEZE:
		_report("FREEZE", "no stale Freeze lock survives into the respawned life", not target.controller.frozen, "controller.frozen=%s" % target.controller.frozen)
	if power_type == PowerTypeScript.Type.PUSH:
		_report("PUSH", "no corrupted velocity/traversal survives into the respawned life", target.velocity.length() < 100.0 and not target.in_traversal_zone and not target.is_climbing, "velocity=%s in_traversal_zone=%s is_climbing=%s" % [target.velocity, target.in_traversal_zone, target.is_climbing])

	_reset_player_for_test(target, Vector2(500, 900))
	_reset_player_for_test(attacker, Vector2(1200, 900))

# --- 13: Mixed combat sequences - order-independent health progression -----

func _test_mixed_combat_sequences() -> void:
	print("\n--- Repeated mixed combat (health progresses regardless of power order) ---")
	await _mixed_sequence([PowerTypeScript.Type.PUSH, PowerTypeScript.Type.FREEZE, PowerTypeScript.Type.ROCKET], "Push -> Freeze -> Rocket -> Defeated")
	await _mixed_sequence([PowerTypeScript.Type.ROCKET, PowerTypeScript.Type.PUSH, PowerTypeScript.Type.FREEZE], "Rocket -> Push -> Freeze -> Defeated")

func _mixed_sequence(order: Array, label: String) -> void:
	var target: CharacterBody2D = arena.players[0]
	var attacker: CharacterBody2D = arena.players[1]
	_clear_field([target, attacker])
	_reset_player_for_test(target, Vector2(500, 900))
	_reset_player_for_test(attacker, Vector2(560, 900))

	var expected_health: int = target.max_health
	for power_type in order:
		expected_health -= 1
		# Reposition before every step - Push displaces the target, and
		# nothing else needs to know or care where it landed to keep testing
		# order-independence, only that health keeps progressing correctly.
		target.reset_to(Vector2(500, 900))
		attacker.reset_to(Vector2(560, 900))
		attacker.facing_dir = -1.0
		attacker.receive_power(power_type)
		arena.power_system.try_activate(attacker)
		if power_type == PowerTypeScript.Type.ROCKET:
			var hit_frames := 0
			while target.health != expected_health and hit_frames < 90:
				await physics_frame
				hit_frames += 1
		_report("MIXED", "%s: health after %s = %d/%d" % [label, PowerTypeScript.label(power_type), expected_health, target.max_health], target.health == expected_health, "health=%d (expected %d)" % [target.health, expected_health])

	_report("MIXED", "%s: sequence ends in Defeated" % label, target.is_defeated, "is_defeated=%s health=%d" % [target.is_defeated, target.health])

	var hz: float = physics_ticks_per_second()
	var max_frames := int((arena.health_system.defeat_duration + 1.0) * hz)
	var frames := 0
	while target.is_defeated and frames < max_frames:
		await physics_frame
		frames += 1
	_reset_player_for_test(target, Vector2(500, 900))
	_reset_player_for_test(attacker, Vector2(1200, 900))

# --- 14: Spawn protection vs each power - inspect and report, don't assume -

func _test_spawn_protection_power_paths() -> void:
	print("\n--- Spawn protection vs Push/Rocket/Freeze (inspect current behaviour, don't assume) ---")
	var target: CharacterBody2D = arena.players[0]
	var attacker: CharacterBody2D = arena.players[1]
	_clear_field([target, attacker])

	_reset_player_for_test(target, Vector2(500, 900))
	_reset_player_for_test(attacker, Vector2(560, 900))
	target.set_spawn_protected(true)
	attacker.receive_power(PowerTypeScript.Type.PUSH)
	arena.power_system.try_activate(attacker)
	await physics_frame
	_report("PROTECTION", "Push: damage is ignored during protection", target.health == target.max_health, "health=%d/%d" % [target.health, target.max_health])
	print("  (report, not asserted) Push during spawn protection %s displace the target - velocity=%s" % ["DOES" if target.velocity.length() > 200.0 else "does NOT", target.velocity])

	_reset_player_for_test(target, Vector2(500, 900))
	_reset_player_for_test(attacker, Vector2(560, 900))
	target.set_spawn_protected(true)
	attacker.receive_power(PowerTypeScript.Type.FREEZE)
	arena.power_system.try_activate(attacker)
	_report("PROTECTION", "Freeze: damage is ignored during protection", target.health == target.max_health, "health=%d/%d" % [target.health, target.max_health])
	print("  (report, not asserted) Freeze during spawn protection: controller.frozen=%s (still immobilises - protection only ever gated take_damage(), never controller.set_frozen())" % target.controller.frozen)

	_reset_player_for_test(target, Vector2(500, 900))
	_reset_player_for_test(attacker, Vector2(560, 900))
	target.set_spawn_protected(true)
	attacker.facing_dir = -1.0
	attacker.receive_power(PowerTypeScript.Type.ROCKET)
	arena.power_system.try_activate(attacker)
	await _settle(10)
	_report("PROTECTION", "Rocket: damage is ignored during protection", target.health == target.max_health, "health=%d/%d" % [target.health, target.max_health])

	_reset_player_for_test(target, Vector2(500, 900))
	_reset_player_for_test(attacker, Vector2(1200, 900))

# --- 15: Organic-play diagnostic - does allowing all three to damage change
#         defeat frequency, without turning the arena into constant death? --
#         Diagnostic only, does not gate PASS/FAIL - see the section-6
#         comment at the top of this file for why real bot play cannot be a
#         deterministic assertion.

func _diagnostic_organic_combat() -> void:
	print("\n--- Organic-play diagnostic: damage-model experiment, full Contact Lab ---")
	arena._full_reset()
	arena.match_director.enter_contact_lab()
	await _settle(5)

	var uses: Dictionary = {PowerTypeScript.Type.PUSH: 0, PowerTypeScript.Type.ROCKET: 0, PowerTypeScript.Type.FREEZE: 0}
	var on_use := func(_slot: int, power_type: int): uses[power_type] = uses.get(power_type, 0) + 1
	arena.power_system.power_used.connect(on_use)

	var hits: Dictionary = {PowerTypeScript.Type.PUSH: 0, PowerTypeScript.Type.ROCKET: 0, PowerTypeScript.Type.FREEZE: 0}
	var on_hit := func(_shooter: int, _target: int, power_type: int): hits[power_type] = hits.get(power_type, 0) + 1
	arena.power_system.power_hit.connect(on_hit)

	var defeats := {"total": 0, "by_power": {PowerTypeScript.Type.PUSH: 0, PowerTypeScript.Type.ROCKET: 0, PowerTypeScript.Type.FREEZE: 0, PowerTypeScript.Type.NONE: 0}}
	var on_defeat := func(_slot: int, power_type: int):
		defeats["total"] = defeats["total"] + 1
		defeats["by_power"][power_type] = defeats["by_power"].get(power_type, 0) + 1
	arena.health_system.player_defeated.connect(on_defeat)

	var spills := {"count": 0}
	var on_spill := func(_slot: int, _power_type: int): spills["count"] = spills["count"] + 1
	arena.health_system.power_spilled.connect(on_spill)

	var respawns := {"count": 0}
	var on_respawn := func(_slot: int): respawns["count"] = respawns["count"] + 1
	arena.health_system.player_respawned.connect(on_respawn)

	const DIAGNOSTIC_DURATION := 90.0
	print("  running %.0fs of real Contact Lab bot play with the current pickup density..." % DIAGNOSTIC_DURATION)
	var t := 0.0
	var hz: float = physics_ticks_per_second()
	while t < DIAGNOSTIC_DURATION:
		await physics_frame
		t += 1.0 / hz

	arena.power_system.power_used.disconnect(on_use)
	arena.power_system.power_hit.disconnect(on_hit)
	arena.health_system.player_defeated.disconnect(on_defeat)
	arena.health_system.power_spilled.disconnect(on_spill)
	arena.health_system.player_respawned.disconnect(on_respawn)

	var pips_by_power: Dictionary = hits  # every successful hit is exactly 1 pip, by design
	print("  --- Organic-play damage-model diagnostic (%.0fs, current pickup density, 1 human idle + 3 bots) ---" % DIAGNOSTIC_DURATION)
	print("  uses:    PUSH=%d  ROCKET=%d  FREEZE=%d" % [uses[PowerTypeScript.Type.PUSH], uses[PowerTypeScript.Type.ROCKET], uses[PowerTypeScript.Type.FREEZE]])
	print("  hits:    PUSH=%d  ROCKET=%d  FREEZE=%d" % [hits[PowerTypeScript.Type.PUSH], hits[PowerTypeScript.Type.ROCKET], hits[PowerTypeScript.Type.FREEZE]])
	print("  pips:    PUSH=%d  ROCKET=%d  FREEZE=%d  (total=%d)" % [pips_by_power[PowerTypeScript.Type.PUSH], pips_by_power[PowerTypeScript.Type.ROCKET], pips_by_power[PowerTypeScript.Type.FREEZE], pips_by_power[PowerTypeScript.Type.PUSH] + pips_by_power[PowerTypeScript.Type.ROCKET] + pips_by_power[PowerTypeScript.Type.FREEZE]])
	print("  defeats: total=%d  (final hit: PUSH=%d ROCKET=%d FREEZE=%d NONE=%d)" % [defeats["total"], defeats["by_power"][PowerTypeScript.Type.PUSH], defeats["by_power"][PowerTypeScript.Type.ROCKET], defeats["by_power"][PowerTypeScript.Type.FREEZE], defeats["by_power"][PowerTypeScript.Type.NONE]])
	print("  spills:  %d" % spills["count"])
	print("  respawns: %d" % respawns["count"])
	print("  (compare against the STOP 3/4 handoff's Rocket-only-damage report: bots picked up a power at least once in 30s: 3/3, power_used events in that 30s window were PUSH=2 ROCKET=3 FREEZE=6 with 0 defeats observed)")
