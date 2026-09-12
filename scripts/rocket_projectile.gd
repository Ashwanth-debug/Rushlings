extends Area2D

# M4-1 STOP 2 - Rocket's projectile. Fires in a straight line at a fixed
# height in the shooter's facing direction (docs/plans/M04_0_MATCH_SHAPE_DESIGN.md
# S06 caveat 1: "Rocket cannot test aim in M4-1... it fires in facing
# direction" - there is no aiming input to give it a trajectory). Not
# affected by gravity - a straight ranged-pressure shot, not a lobbed one.
#
# Polling, not signals, for the same reason relic.gd polls rather than
# listens: exactly one outcome (world hit, player hit, or lifetime expiry)
# must win, and only one queue_free() may ever fire for a given rocket.
#
# STOP 2 scope: damage does not exist yet (health is STOP 3). A player hit
# only reports a HIT event through PowerSystem.report_rocket_hit() - no
# health is reduced here or anywhere else this session.

const ArenaWrapScript := preload("res://scripts/arena_wrap.gd")

@export var speed: float = 1300.0
@export var lifetime: float = 2.0

var _direction: float = 1.0
var _owner_slot_id: int = -1
var _power_system = null

## direction: +1/-1, the shooter's facing_dir at the moment of firing.
## owner_slot_id: excluded from hit detection so a rocket can never register
## an immediate self-hit regardless of spawn offset.
## power_system: PowerSystem, told about a confirmed player hit so the hit
## event (print + signal + target flash) lives in one place rather than
## being duplicated per-projectile.
func setup(direction: float, owner_slot_id: int, power_system) -> void:
	_direction = direction
	_owner_slot_id = owner_slot_id
	_power_system = power_system

func _ready() -> void:
	add_to_group(ArenaWrapScript.WRAPPABLE_GROUP)
	# No layer of its own is read by anything else, so nothing needs to
	# detect a rocket as a body - only what a rocket itself detects matters.
	collision_layer = 0
	set_collision_mask_value(1, true)  # world geometry
	set_collision_mask_value(2, true)  # players
	monitoring = true

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	global_position.x += _direction * speed * delta
	for body in get_overlapping_bodies():
		if body is CharacterBody2D and "slot_id" in body:
			if body.slot_id == _owner_slot_id:
				continue
			if _power_system != null:
				_power_system.report_rocket_hit(body, _owner_slot_id)
			queue_free()
			return
		else:
			# Any other physics body is world geometry - a Rocket has a
			# clear lifetime/range and must not pass indefinitely through it.
			queue_free()
			return
