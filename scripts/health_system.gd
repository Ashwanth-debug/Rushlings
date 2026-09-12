class_name HealthSystem
extends Node

# M4-1 STOP 3+4 - health/defeat/spill/respawn/spawn-protection orchestration.
# See docs/plans/M04_0_MATCH_SHAPE_DESIGN.md S04 and CLAUDE.md's M4-1 STOP
# 3+4 brief. Health/defeat/protection STATE lives on player.gd itself
# (health, is_defeated, spawn_protected), exactly like carried_power in
# power_system.gd - this system only decides WHEN a hit lands as real
# damage, WHEN a defeat->respawn cycle fires, and WHERE a spilled power or a
# respawn placement goes. It never special-cases a human vs. a bot body -
# both are the same player.gd instance, so "bots participate using exactly
# the same player systems as P1" (CLAUDE.md M4-1 S08) falls out for free.
#
# Owned by arena_01.gd as a scene-tree sibling of PowerSystem/MatchDirector,
# configured explicitly (configure()) the same way PowerSystem already is.

## power_type is the power that caused this defeat, PowerType.NONE if the
## damage had no power context (the debug damage key, or a direct
## apply_damage() call with no source given) - used only for the organic-
## play "defeats by final-hit power" diagnostic (CLAUDE.md M4-1 damage-model
## experiment S7), never to change any defeat/respawn behaviour.
signal player_defeated(slot_id: int, power_type: int)
signal player_respawned(slot_id: int)
## Diagnostic-only (CLAUDE.md M4-1 damage-model experiment S7's organic-play
## report needs a spill count) - never used to decide any behaviour.
signal power_spilled(slot_id: int, power_type: int)

const PowerTypeScript := preload("res://scripts/power_type.gd")
const PowerPickupScene := preload("res://scenes/power/power_pickup.tscn")

## Prototype tuning values, reported at STOP 3/4 handoff - not production
## constants. defeat_duration was 3.0s at STOP 3/4; the Game Director's
## STOP 3/4 acceptance playtest found that "noticeably too slow" (waiting a
## couple of seconds too long to get back into the game), so it is halved
## here to 1.5s as the new M4-1 prototype baseline - not a permanent value.
## Deliberately the only number this tuning pass touches: health, all three
## powers' damage, Freeze duration, spawn_protection_duration, respawn
## selection, spill and pickup timing are all unchanged (Game Director
## instruction: isolate the perceived waiting time first).
@export var defeat_duration: float = 1.5
@export var spawn_protection_duration: float = 0.8

var players: Array = []
var geometry = null
var spawn_anchors: Array = []  # Array[Vector2] - the four authored Spawn markers
var power_system: PowerSystem = null
var pickups_parent: Node = null
var pickup_field = null

# CharacterBody2D -> seconds remaining. Not per-slot-id, so a body that has
# since been fully replaced can never be operated on by a stale reference -
# is_instance_valid() guards every use, exactly like PowerSystem's own
# _frozen_timers.
var _defeat_timers: Dictionary = {}
var _protection_timers: Dictionary = {}

func configure(p_players: Array, p_geometry, p_spawn_anchors: Array, p_power_system: PowerSystem, p_pickups_parent: Node, p_pickup_field) -> void:
	players = p_players
	geometry = p_geometry
	spawn_anchors = p_spawn_anchors
	power_system = p_power_system
	pickups_parent = p_pickups_parent
	pickup_field = p_pickup_field
	if not power_system.power_hit.is_connected(_on_power_hit):
		power_system.power_hit.connect(_on_power_hit)

func _physics_process(delta: float) -> void:
	_update_defeat_timers(delta)
	_update_protection_timers(delta)

## M4-1 damage-model experiment (Game Director finding, post-STOP-3/4
## playtest): all three powers now deal damage on a successful hit, not just
## Rocket - PowerSystem's power_hit signal already carried the hit event
## (previously Rocket-only), so listening to it here is still the entire
## damage wire regardless of which power fired it, with zero changes needed
## inside power_pickup.gd or rocket_projectile.gd and no second damage
## implementation anywhere.
func _on_power_hit(_shooter_slot_id: int, target_slot_id: int, power_type: int) -> void:
	var target := _find_player(target_slot_id)
	if target != null:
		apply_damage(target, power_type)

func _find_player(slot_id: int) -> CharacterBody2D:
	for p in players:
		if is_instance_valid(p) and p.slot_id == slot_id:
			return p
	return null

## The one entry point for a damage event - also how tools/m4_1_check.gd and
## the debug damage key (arena_01.gd's debug_damage_p1) exercise the real
## pipeline directly. `source_power_type` is purely for the defeat-
## attribution diagnostic below and defaults to NONE for callers with no
## power context. Returns true if damage actually landed.
func apply_damage(target: CharacterBody2D, source_power_type: int = PowerTypeScript.Type.NONE) -> bool:
	if not target.take_damage():
		return false
	if target.health <= 0 and not target.is_defeated:
		_defeat(target, source_power_type)
	return true

func _defeat(target: CharacterBody2D, source_power_type: int = PowerTypeScript.Type.NONE) -> void:
	if target.has_power():
		_spill_power(target)
	power_system.clear_freeze(target)
	target.set_defeated(true)
	target.velocity = Vector2.ZERO
	_defeat_timers[target] = defeat_duration
	print("[HealthSystem] P%d DEFEATED by %s - respawn in %.1fs" % [target.slot_id, PowerTypeScript.label(source_power_type) if source_power_type != PowerTypeScript.Type.NONE else "(no power context)", defeat_duration])
	player_defeated.emit(target.slot_id, source_power_type)

## Reuses the same PowerPickup scene/entity the authored world pickups use
## (CLAUDE.md M4-1 STOP 4 S5: "the spilled object must use the same reusable
## pickup system where practical"), registered with the same PickupField so
## SEEK_PICKUP and opportunistic collection both see it exactly like an
## authored pickup - the only difference is respawns=false (power_pickup.gd),
## so it disappears for good once taken rather than respawning at a stale
## defeat position forever.
func _spill_power(target: CharacterBody2D) -> void:
	var spilled_type: int = target.carried_power
	var pickup := PowerPickupScene.instantiate()
	pickup.power_type = spilled_type
	pickup.respawns = false
	# Best-effort nav-graph node at the defeat position, so a bot can still
	# deliberately SEEK_PICKUP toward a spill it's reliably able to reach -
	# "" (not grounded, or no matching platform) just means it stays
	# opportunistic-only, exactly like any other pickup a bot happens to
	# cross rather than one it targeted.
	pickup.nav_node = geometry.canonical_platform(target) if target.is_on_floor() else ""
	pickups_parent.add_child(pickup)
	pickup.global_position = target.global_position
	pickup_field.register(pickup)
	target.consume_power()
	print("[HealthSystem] P%d power spilled: %s" % [target.slot_id, PowerTypeScript.label(spilled_type)])
	power_spilled.emit(target.slot_id, spilled_type)

func _update_defeat_timers(delta: float) -> void:
	var expired: Array = []
	for target in _defeat_timers.keys():
		if not is_instance_valid(target):
			expired.append(target)
			continue
		_defeat_timers[target] -= delta
		if _defeat_timers[target] <= 0.0:
			expired.append(target)
	for target in expired:
		_defeat_timers.erase(target)
		if is_instance_valid(target):
			_respawn(target)

## Minimal authored-anchor respawn (docs/plans/M04_0_MATCH_SHAPE_DESIGN.md
## S04.3): reuse the four existing Spawn markers, pick the one furthest from
## the nearest currently-active (not Defeated) opponent. Never arbitrary
## coordinates, never a weighted multi-factor spawn director.
func _respawn(target: CharacterBody2D) -> void:
	var anchor: Vector2 = _pick_respawn_anchor(target)
	target.reset_to(anchor)
	target.reset_health()
	target.set_defeated(false)
	target.consume_power()
	target.set_spawn_protected(true)
	_protection_timers[target] = spawn_protection_duration
	print("[HealthSystem] P%d respawned at %s (protected %.2fs)" % [target.slot_id, anchor, spawn_protection_duration])
	player_respawned.emit(target.slot_id)

func _pick_respawn_anchor(target: CharacterBody2D) -> Vector2:
	var best: Vector2 = spawn_anchors[0]
	var best_dist := -1.0
	for anchor in spawn_anchors:
		var nearest := INF
		for p in players:
			if p == target or not is_instance_valid(p) or p.is_defeated:
				continue
			var dx: float = geometry.shortest_diff(p.global_position.x, anchor.x)
			var dy: float = p.global_position.y - anchor.y
			nearest = min(nearest, Vector2(dx, dy).length())
		if nearest > best_dist:
			best_dist = nearest
			best = anchor
	return best

func _update_protection_timers(delta: float) -> void:
	var expired: Array = []
	for target in _protection_timers.keys():
		if not is_instance_valid(target):
			expired.append(target)
			continue
		_protection_timers[target] -= delta
		if _protection_timers[target] <= 0.0:
			expired.append(target)
	for target in expired:
		_protection_timers.erase(target)
		if is_instance_valid(target):
			target.set_spawn_protected(false)
			print("[HealthSystem] P%d spawn protection expired" % target.slot_id)

## Called on a full rematch and on Contact Lab enter/exit (arena_01.gd) -
## exactly the same "clean slate" reasoning as PowerSystem.reset(): a fresh
## round must not carry a stale Defeated/protected player into it.
func reset() -> void:
	for p in players:
		if is_instance_valid(p):
			p.set_defeated(false)
			p.reset_health()
			p.set_spawn_protected(false)
	_defeat_timers.clear()
	_protection_timers.clear()
