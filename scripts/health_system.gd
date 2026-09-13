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
## defeat_duration is the TOTAL downtime budget (lethal hit -> respawn),
## unchanged by the M4-2 reaction-window revision below - only how that
## budget is split changed. Deliberately the only numbers this tuning pass
## and the reaction-window revision touch: health, all three powers' damage,
## Freeze duration, spawn_protection_duration, respawn selection, spill and
## pickup timing are all unchanged.
@export var defeat_duration: float = 1.5
@export var spawn_protection_duration: float = 0.8

## M4-2 defeat-resolution window (Game Director playtest, 2026-09-13):
## instant hiding on a lethal hit meant a killing Push/Freeze/Rocket/hazard
## never got to visibly finish - the target vanished the same physics frame
## health reached 0. reaction_duration is the short beat (prototype value,
## chosen from the Director's own ~0.35-0.5s / "~0.4s visible reaction"
## example) where the body stays visible, on-layer and physically simulated
## before _finish_defeat() actually hides it. Comes OUT of defeat_duration's
## existing total, not on top of it: hidden phase = defeat_duration -
## reaction_duration, so total downtime stays ~1.5s exactly as already
## accepted, split as ~0.4s visible + ~1.1s hidden instead of 0s + 1.5s.
@export var reaction_duration: float = 0.4

## M4-2 sentinel source value for arena hazard damage - distinct from every
## real PowerType.Type value (all >= 0), so the defeat-attribution
## diagnostic can tell "the arena" apart from "a power" without adding a
## fake power to power_type.gd's taxonomy, which is specifically the power
## set. scripts/danger_zone.gd passes this to apply_damage(); nothing else
## needs to know it exists.
const HAZARD_SOURCE := -1

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
## CharacterBody2D -> seconds remaining in the M4-2 reaction window, and a
## parallel CharacterBody2D -> source power_type dictionary so _finish_defeat
## still gets the right attribution once the reaction elapses. Same
## not-per-slot-id, is_instance_valid()-guarded reasoning as the two above.
var _reaction_timers: Dictionary = {}
var _reaction_sources: Dictionary = {}

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
	_update_reaction_timers(delta)
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
	if target.health <= 0 and not target.is_dying and not target.is_defeated:
		_begin_defeat_reaction(target, source_power_type)
	return true

## M4-2 - the lethal hit's own effect (a Push's receive_launch(), a Freeze's
## set_frozen_visual()/timer, a Rocket's flash_hit()) has ALREADY happened by
## the time this runs - it's called from the same power_hit/apply_damage
## chain those effects fire from, synchronously, before this function
## returns. All this does is lock input (begin_dying(), the same
## controller.frozen primitive Defeated itself uses - a BotController skips
## brain.tick() entirely while frozen, so a dying bot cannot regain control)
## and start the short reaction timer - it deliberately does NOT touch
## velocity, visibility or collision layer 2, so whatever is already
## physically/visually in flight keeps playing out exactly as it would for a
## non-lethal hit, for reaction_duration seconds.
func _begin_defeat_reaction(target: CharacterBody2D, source_power_type: int = PowerTypeScript.Type.NONE) -> void:
	target.begin_dying()
	_reaction_timers[target] = reaction_duration
	_reaction_sources[target] = source_power_type
	print("[HealthSystem] P%d lethal hit - %.2fs reaction before defeat resolves" % [target.slot_id, reaction_duration])

func _update_reaction_timers(delta: float) -> void:
	var expired: Array = []
	for target in _reaction_timers.keys():
		if not is_instance_valid(target):
			expired.append(target)
			continue
		_reaction_timers[target] -= delta
		if _reaction_timers[target] <= 0.0:
			expired.append(target)
	for target in expired:
		var source_power_type: int = _reaction_sources.get(target, PowerTypeScript.Type.NONE)
		_reaction_timers.erase(target)
		_reaction_sources.erase(target)
		if is_instance_valid(target):
			_finish_defeat(target, source_power_type)

## The reaction window has elapsed - now actually resolve the defeat: spill
## (at the target's CURRENT position, e.g. wherever a killing Push carried
## them, not where they were originally hit - the more physically sensible
## reading of "the power drops where they finally went down"), clear any
## pending Freeze timer so it can never fire on a body that's about to be
## reset (also guarantees the frozen tint itself is cleared - see
## _respawn()'s explicit set_frozen_visual(false)), then hide/lock/zero
## exactly as the old single-step _defeat() used to do immediately. The
## hidden-phase timer is defeat_duration MINUS the reaction time already
## spent, so total lethal-hit-to-respawn downtime stays the same accepted
## ~1.5s regardless of reaction_duration's value.
func _finish_defeat(target: CharacterBody2D, source_power_type: int = PowerTypeScript.Type.NONE) -> void:
	if target.has_power():
		_spill_power(target)
	power_system.clear_freeze(target)
	target.end_dying()
	target.set_defeated(true)
	target.velocity = Vector2.ZERO
	var hidden_duration: float = max(0.0, defeat_duration - reaction_duration)
	_defeat_timers[target] = hidden_duration
	var source_label: String
	if source_power_type == HAZARD_SOURCE:
		source_label = "HAZARD"
	elif source_power_type != PowerTypeScript.Type.NONE:
		source_label = PowerTypeScript.label(source_power_type)
	else:
		source_label = "(no power context)"
	print("[HealthSystem] P%d DEFEATED by %s - %.2fs reaction + %.2fs hidden (~%.1fs total) - respawn in %.2fs" % [target.slot_id, source_label, reaction_duration, hidden_duration, defeat_duration, hidden_duration])
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
	# M4-2: a lethal Freeze's tint (player.gd's set_frozen_visual(true)) is
	# never cleared by PowerSystem's own timer expiry once
	# power_system.clear_freeze() has removed the pending entry
	# (_finish_defeat() does this deliberately, so a stale timer can never
	# fire on a body mid-reset) - explicit here so "no stale Freeze survives
	# respawn" holds for the VISUAL too, not just the timer/input-lock.
	# Must run BEFORE set_spawn_protected(): set_frozen_visual() assigns the
	# whole modulate (including alpha), which would otherwise clobber the
	# translucency set_spawn_protected(true) is about to apply.
	target.set_frozen_visual(false)
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
			p.end_dying()
			p.set_defeated(false)
			p.reset_health()
			p.set_spawn_protected(false)
			p.set_frozen_visual(false)
	_reaction_timers.clear()
	_reaction_sources.clear()
	_defeat_timers.clear()
	_protection_timers.clear()
