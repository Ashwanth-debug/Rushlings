extends Area2D

# M4-3 - Mine, the fourth power (CLAUDE.md M4-3 S9, docs/plans/
# M04_0_MATCH_SHAPE_DESIGN.md S06 taxonomy: Denial/prediction). Placed by
# power_system.gd's _try_mine() at the owner's current position, consumed
# on placement exactly like Push/Rocket/Freeze - carry-one/one-use, no
# inventory, no multiple stored mines (CLAUDE.md: "Do not build
# inventories or multiple stored mines").
#
# Stays in the world until triggered by a later valid overlap. ARM_DELAY is
# a short general arming window (not a per-owner exclusion) so a mine does
# not instantly detonate under the owner's own feet from residual overlap
# the instant it's placed ("Do not let owner immediately trigger their own
# newly-placed mine") - after it elapses, ANY valid player including the
# owner can trigger it, the smallest rule that satisfies the requirement
# without inventing owner-tracking state that out-lives placement.
#
# Poll, not body_entered - same reasoning as every other hit-detection
# entity in this codebase (relic.gd, extraction_anchor.gd,
# rocket_projectile.gd): exactly one trigger may ever fire, and
# get_overlapping_bodies() gives that for free without enter/exit
# bookkeeping.
#
# Damage routes through the SAME single power_hit -> HealthSystem.apply_damage()
# pipeline every other power uses - this script never touches health
# itself. power_system.gd listens to mine_triggered and re-emits power_hit,
# exactly like report_rocket_hit() already does for Rocket, so there is
# still exactly one damage implementation in the codebase regardless of
# source.

signal mine_triggered(target_slot_id: int, owner_slot_id: int)

const MINE_SIZE := Vector2(36.0, 30.0)
const ARM_DELAY := 0.6
const COLOR := Color(0.55, 0.15, 0.05, 1.0)

var owner_slot_id: int = -1
var _armed_clock: float = 0.0
var _triggered: bool = false

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: ColorRect = $ColorRect

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(2, true)  # players layer only, per player.gd
	monitoring = true
	var shape := RectangleShape2D.new()
	shape.size = MINE_SIZE
	_shape.shape = shape
	_visual.color = COLOR

func setup(p_owner_slot_id: int) -> void:
	owner_slot_id = p_owner_slot_id

func _physics_process(delta: float) -> void:
	if _triggered:
		return
	_armed_clock += delta
	if _armed_clock < ARM_DELAY:
		return
	for body in get_overlapping_bodies():
		if not (body is CharacterBody2D) or not ("slot_id" in body):
			continue
		if "is_defeated" in body and body.is_defeated:
			continue
		if "is_dying" in body and body.is_dying:
			continue
		if not _actually_overlaps(body):
			continue
		_trigger(body)
		return

## Same staleness guard as relic.gd/extraction_anchor.gd - a body teleported
## earlier in the SAME physics frame (a respawn's reset_to()) can still show
## up in get_overlapping_bodies() at its OLD position. See relic.gd's own
## _actually_overlaps() for the full reasoning.
func _actually_overlaps(body: CharacterBody2D) -> bool:
	var rect_shape := _shape.shape as RectangleShape2D
	if rect_shape == null:
		return true
	var local_pos: Vector2 = _shape.global_transform.affine_inverse() * body.global_position
	var half: Vector2 = rect_shape.size * 0.5 + _body_half_extents(body)
	return abs(local_pos.x) <= half.x and abs(local_pos.y) <= half.y

func _body_half_extents(body: Node2D) -> Vector2:
	if not body.has_node("CollisionShape2D"):
		return Vector2.ZERO
	var body_shape := (body.get_node("CollisionShape2D") as CollisionShape2D).shape
	if body_shape is RectangleShape2D:
		return (body_shape as RectangleShape2D).size * 0.5
	return Vector2.ZERO

func _trigger(body: CharacterBody2D) -> void:
	_triggered = true
	visible = false
	monitoring = false
	mine_triggered.emit(body.slot_id, owner_slot_id)
	queue_free()
