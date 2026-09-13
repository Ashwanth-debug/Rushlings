extends Area2D

@export var launch_direction: Vector2 = Vector2(0, -1)

func _ready() -> void:
	# Players moved to a dedicated layer 2 (post-A1/A2 playtest collision-
	# toggle fix, see player.gd) - this Area2D's default mask (layer 1 only)
	# would otherwise stop detecting them entirely.
	set_collision_mask_value(2, true)
	body_entered.connect(_on_body_entered)

@onready var _shape: CollisionShape2D = $CollisionShape2D

## M4-2 finding (Game Director playtest, 2026-09-13): a fast-moving body can
## produce a body_entered signal that is still queued/deferred by the time it
## is actually processed, after the body has already left this Area2D
## entirely - observed for a lethal Push carrying its target through this
## pad's zone during the new defeat-resolution reaction window, where the
## stale signal fired only after the target had already respawned somewhere
## else, silently overwriting its fresh velocity.
##
## get_overlapping_bodies() is NOT a fix for this - that list is maintained
## by the exact same deferred signal system, so it can be just as stale as
## the signal itself. Re-checking the body's CURRENT global_position against
## this pad's own shape directly, in local space, is a plain geometry test
## with no dependency on the physics server's own bookkeeping.
##
## The check must be against the pad's half-extents PLUS the body's own
## half-extents (an AABB-vs-AABB test, not a point-vs-AABB test) - an
## earlier version of this fix compared the body's bare origin point against
## the pad's rectangle, which wrongly rejected a real, non-stale entry
## whenever the body's edge (not its centre) was what actually touched the
## pad first, shrinking the pad's effective trigger area by the body's own
## half-size on every side (confirmed by tools/m3_check.gd's sealed-state
## ROAM regression - a bot that should have launched normally instead
## fell into a completely different, unintended path).
func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("receive_launch"):
		return
	var rect_shape := _shape.shape as RectangleShape2D
	if rect_shape != null:
		var local_pos: Vector2 = (_shape.global_transform.affine_inverse() * body.global_position)
		var half: Vector2 = rect_shape.size * 0.5 + _body_half_extents(body)
		if abs(local_pos.x) > half.x or abs(local_pos.y) > half.y:
			return
	body.receive_launch(launch_direction)

## Best-effort half-extents of the OTHER body's own rectangular collision
## shape, so the re-check above approximates a real shape-vs-shape overlap
## instead of a point-vs-shape one. Zero (no expansion) if the body has no
## such shape - strictly more conservative than skipping the check
## entirely, never less.
func _body_half_extents(body: Node2D) -> Vector2:
	if not body.has_node("CollisionShape2D"):
		return Vector2.ZERO
	var body_shape := (body.get_node("CollisionShape2D") as CollisionShape2D).shape
	if body_shape is RectangleShape2D:
		return (body_shape as RectangleShape2D).size * 0.5
	return Vector2.ZERO
