class_name PowerSystem
extends Node

# M4-1 STOP 1+2 - the one place that turns "carrying a power + the power
# action pressed" into an actual effect. Deliberately the only new gameplay
# system this milestone adds beyond the pickup entity itself - Push, Rocket
# and Freeze are three branches here, not three separate managers, since all
# three share the same activation/consumption seam (docs/plans/
# M04_0_MATCH_SHAPE_DESIGN.md S08: "one carried active power -> one use ->
# empty -> collect again").
#
# Owned by arena_01.gd as a plain scene-tree sibling of MatchDirector/
# MatchTelemetry, configured explicitly (configure()) rather than wired
# through @onready cross-references, the same pattern arena_01.gd already
# uses for MatchTelemetry ("arena.match_telemetry.arena = self").
#
# Validity rule per power (CLAUDE.md M4-1 S05, reported at STOP 1/2 handoff):
#   Push / Freeze - INVALID (not consumed) if no other player is within
#     interaction_radius. Both are targeted control effects; with no aiming
#     input, "is anyone near enough to affect" is the only meaningful
#     validity condition, and firing them at nothing would be a silent,
#     misleading no-op if it still consumed the pickup.
#   Rocket - ALWAYS valid to fire. It is a travelling projectile with its
#     own lifetime/range, not a targeted lock - firing into empty space is
#     itself the thing being tested ("ranged pressure and positioning"), so
#     firing (not landing a hit) is what consumes it.
#
# M4-1 damage-model experiment (Game Director finding after STOP 3/4
# playtest, prototype only - NOT yet an approved M4-0 change): Rocket-only
# damage made reducing another player's 3 pips take too long, since Push and
# Freeze contributed nothing to the health/defeat loop despite being one-use
# and carry-one exactly like Rocket. All three now deal 1 pip on a
# SUCCESSFUL hit (the same condition that already gates consumption for
# Push/Freeze, and the same "did the projectile connect" condition Rocket
# already used) - see _try_push()/_try_freeze()/report_rocket_hit() below.
# Damage itself still routes through exactly one place: HealthSystem listens
# to power_hit below and calls HealthSystem.apply_damage() - nothing here
# ever touches health directly, so there is still only one damage
# implementation regardless of which power caused it.

signal power_used(slot_id: int, power_type: int)
## power_type identifies which power caused the hit, so HealthSystem can
## attribute a defeat to it for the organic-play diagnostic (CLAUDE.md M4-1
## damage-model experiment S7) without a second signal or a lookup table.
signal power_hit(shooter_slot_id: int, target_slot_id: int, power_type: int)

const PowerTypeScript := preload("res://scripts/power_type.gd")
const RocketScene := preload("res://scenes/power/rocket_projectile.tscn")
const MineScene := preload("res://scenes/power/mine.tscn")

## Prototype tuning values, reported at STOP 1/2 handoff - not production
## constants. Push reuses player.gd's own launch_strength (see _try_push),
## so it has no separate strength knob here.
@export var interaction_radius: float = 260.0
## Explicit prototype tuning value (Game Director feedback after STOP 1/2
## playtest: 2.0s "feels somewhat annoying/too long"). 1.0s is the next
## human-test value - NOT a redesign of Freeze, just a duration change.
## FREEZE_DURATION_OPTIONS below exists so 0.75/1.0/1.5/2.0 stay one
## keypress apart if a later session needs to compare them again - see
## cycle_freeze_duration() and arena_01.gd's debug_cycle_freeze_duration key.
@export var freeze_duration: float = 1.0
@export var rocket_speed: float = 1300.0
@export var rocket_lifetime: float = 2.0
@export var rocket_spawn_offset: float = 30.0

const FREEZE_DURATION_OPTIONS := [0.75, 1.0, 1.5, 2.0]
var _freeze_duration_index: int = 1  # matches the 1.0s default above

func cycle_freeze_duration() -> void:
	_freeze_duration_index = (_freeze_duration_index + 1) % FREEZE_DURATION_OPTIONS.size()
	freeze_duration = FREEZE_DURATION_OPTIONS[_freeze_duration_index]
	print("[PowerSystem] freeze_duration = %.2fs" % freeze_duration)

var players: Array = []
var geometry = null
var projectile_parent: Node = null
var match_director: MatchDirector = null

# target CharacterBody2D -> seconds remaining. Not per-slot-id, so a target
# that has been fully replaced (e.g. rematch rebuild) can never be operated
# on by a stale reference - is_instance_valid() guards every use.
var _frozen_timers: Dictionary = {}

func configure(p_players: Array, p_geometry, p_projectile_parent: Node, p_match_director: MatchDirector) -> void:
	players = p_players
	geometry = p_geometry
	projectile_parent = p_projectile_parent
	match_director = p_match_director

func _physics_process(delta: float) -> void:
	_update_freeze_timers(delta)
	for p in players:
		if not is_instance_valid(p):
			continue
		if p.controller.power_pressed() and p.has_power():
			try_activate(p)

## Public entry point - also how tools/m4_1_check.gd exercises activation
## directly, without needing to simulate raw Input in a headless run.
## Returns true if the power was actually used (and therefore consumed).
func try_activate(user: CharacterBody2D) -> bool:
	match user.carried_power:
		PowerTypeScript.Type.PUSH:
			return _try_push(user)
		PowerTypeScript.Type.ROCKET:
			return _fire_rocket(user)
		PowerTypeScript.Type.FREEZE:
			return _try_freeze(user)
		PowerTypeScript.Type.MINE:
			return _try_mine(user)
		_:
			return false

func _try_push(user: CharacterBody2D) -> bool:
	var target := _nearest_other_player(user, interaction_radius)
	if target == null:
		print("[PowerSystem] P%d PUSH: no target within %.0fpx - not consumed" % [user.slot_id, interaction_radius])
		return false
	var dx: float = geometry.shortest_diff(target.global_position.x, user.global_position.x)
	var away_x: float = 1.0 if dx >= 0.0 else -1.0
	# A small upward bias (not real height difference) so Push always reads
	# as a shove - "I moved that player" - rather than a flat horizontal
	# shuffle when both players happen to be at the same height. Reuses
	# player.gd's own receive_launch()/launch_strength exactly as the
	# launch pad does - no second movement model.
	var direction := Vector2(away_x, -0.35)
	target.receive_launch(direction)
	target.flash_push()
	user.consume_power()
	print("[PowerSystem] P%d used PUSH on P%d" % [user.slot_id, target.slot_id])
	power_used.emit(user.slot_id, PowerTypeScript.Type.PUSH)
	# Damage-model experiment: a successful Push (a valid target was found -
	# the exact same condition above that already gates consumption) now
	# also deals 1 pip, on top of the displacement it always dealt - no
	# additional stun/knockdown, no change to the displacement itself.
	power_hit.emit(user.slot_id, target.slot_id, PowerTypeScript.Type.PUSH)
	return true

func _try_freeze(user: CharacterBody2D) -> bool:
	var target := _nearest_other_player(user, interaction_radius)
	if target == null:
		print("[PowerSystem] P%d FREEZE: no target within %.0fpx - not consumed" % [user.slot_id, interaction_radius])
		return false
	target.controller.set_frozen(true)
	target.set_frozen_visual(true)
	_frozen_timers[target] = freeze_duration
	user.consume_power()
	print("[PowerSystem] P%d used FREEZE on P%d (%.2fs)" % [user.slot_id, target.slot_id, freeze_duration])
	power_used.emit(user.slot_id, PowerTypeScript.Type.FREEZE)
	# Damage-model experiment: 1 pip on a successful Freeze, same condition
	# as above. Duration is NOT changed because of this - still
	# freeze_duration (1.0s default), per the Director's explicit
	# instruction not to make Freeze longer just because it now damages.
	# If this hit defeats the target, HealthSystem.apply_damage() ->
	# _defeat() calls clear_freeze() (below) before this function returns,
	# so the _frozen_timers entry just set above never outlives the defeat.
	power_hit.emit(user.slot_id, target.slot_id, PowerTypeScript.Type.FREEZE)
	return true

func _fire_rocket(user: CharacterBody2D) -> bool:
	var dir: float = 1.0 if user.facing_dir >= 0.0 else -1.0
	var rocket := RocketScene.instantiate()
	rocket.speed = rocket_speed
	rocket.lifetime = rocket_lifetime
	projectile_parent.add_child(rocket)
	rocket.global_position = user.global_position + Vector2(dir * rocket_spawn_offset, -6.0)
	rocket.setup(dir, user.slot_id, self)
	user.consume_power()
	print("[PowerSystem] P%d fired ROCKET (dir=%.0f)" % [user.slot_id, dir])
	power_used.emit(user.slot_id, PowerTypeScript.Type.ROCKET)
	return true

## M4-3 - Mine (CLAUDE.md M4-3 S9). Always valid to place, exactly like
## Rocket is always valid to fire - placing IS the tested behaviour, not a
## targeted lock. Reuses `projectile_parent` (the existing $Projectiles
## container) rather than a new scene node - mines are transient world
## objects with the same "arena_01.gd owns the container, PowerSystem owns
## what lives in it" lifetime as rockets, and PowerSystem.reset()'s existing
## "clear every child of projectile_parent" loop therefore already clears
## any live mine on a rematch/lab toggle with zero extra code.
func _try_mine(user: CharacterBody2D) -> bool:
	var mine := MineScene.instantiate()
	projectile_parent.add_child(mine)
	mine.global_position = user.global_position
	mine.setup(user.slot_id)
	mine.mine_triggered.connect(_on_mine_triggered)
	user.consume_power()
	print("[PowerSystem] P%d placed MINE at %s" % [user.slot_id, user.global_position])
	power_used.emit(user.slot_id, PowerTypeScript.Type.MINE)
	return true

## Mirrors report_rocket_hit(): the hit event (print, signal, target flash)
## lives in exactly one place regardless of which of potentially several
## live mines caused it, and re-emits the SAME power_hit signal HealthSystem
## already listens to - Mine's damage never gets a second implementation.
func _on_mine_triggered(target_slot_id: int, owner_slot_id: int) -> void:
	var target := _find_player(target_slot_id)
	if target != null:
		target.flash_hit()
	print("[PowerSystem] MINE HIT: P%d triggered P%d's mine" % [target_slot_id, owner_slot_id])
	power_hit.emit(owner_slot_id, target_slot_id, PowerTypeScript.Type.MINE)

func _find_player(slot_id: int) -> CharacterBody2D:
	for p in players:
		if is_instance_valid(p) and p.slot_id == slot_id:
			return p
	return null

## Called by rocket_projectile.gd on a confirmed player hit. Kept here so the
## hit event (print, signal, visual) exists in exactly one place regardless
## of which of many simultaneous rockets caused it.
func report_rocket_hit(target: CharacterBody2D, shooter_slot_id: int) -> void:
	target.flash_hit()
	print("[PowerSystem] ROCKET HIT: P%d hit by P%d" % [target.slot_id, shooter_slot_id])
	power_hit.emit(shooter_slot_id, target.slot_id, PowerTypeScript.Type.ROCKET)

func _nearest_other_player(user: CharacterBody2D, radius: float) -> CharacterBody2D:
	var best: CharacterBody2D = null
	var best_dist := INF
	for p in players:
		if p == user or not is_instance_valid(p) or p.is_defeated:
			continue
		var dx: float = geometry.shortest_diff(p.global_position.x, user.global_position.x)
		var dy: float = p.global_position.y - user.global_position.y
		var dist := Vector2(dx, dy).length()
		if dist <= radius and dist < best_dist:
			best = p
			best_dist = dist
	return best

func _update_freeze_timers(delta: float) -> void:
	var expired: Array = []
	for target in _frozen_timers.keys():
		if not is_instance_valid(target):
			expired.append(target)
			continue
		_frozen_timers[target] -= delta
		if _frozen_timers[target] <= 0.0:
			expired.append(target)
	for target in expired:
		_frozen_timers.erase(target)
		if not is_instance_valid(target):
			continue
		# RESULTS freezes every controller for its own reason (M3-2 S12) -
		# a Freeze timer expiring mid-RESULTS must not undo that. Arena01's
		# own SETUP transition already unfreezes everyone, which correctly
		# clears this case too once the round actually moves on.
		if match_director == null or match_director.state != MatchDirector.State.RESULTS:
			target.controller.set_frozen(false)
			target.set_frozen_visual(false)
			print("[PowerSystem] FREEZE expired on P%d" % target.slot_id)

## M4-1 STOP 3+4 - health_system.gd calls this the instant a player is
## Defeated, so a Freeze that landed on them earlier can't later fire its own
## expiry (_update_freeze_timers above) and re-touch a body mid-respawn.
## Harmless even if called with no pending timer for `target`.
func clear_freeze(target: CharacterBody2D) -> void:
	_frozen_timers.erase(target)

## Called on a full rematch and on Contact Lab enter/exit (arena_01.gd) - a
## clean slate rather than carrying stale powers/freezes/in-flight rockets
## across a reset that already repositions every body.
func reset() -> void:
	for p in players:
		if is_instance_valid(p):
			p.consume_power()
	for target in _frozen_timers.keys():
		if is_instance_valid(target):
			target.controller.set_frozen(false)
			target.set_frozen_visual(false)
	_frozen_timers.clear()
	if projectile_parent != null:
		for child in projectile_parent.get_children():
			child.queue_free()
