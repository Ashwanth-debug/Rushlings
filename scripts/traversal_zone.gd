extends Area2D

@onready var _shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# Players moved to a dedicated layer 2 (post-A1/A2 playtest collision-
	# toggle fix, see player.gd) - this Area2D's default mask (layer 1 only)
	# would otherwise stop detecting them entirely.
	set_collision_mask_value(2, true)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

# Top edge of the climbable column in global coordinates. The player clamps its
# climb to this so it finishes level with the destination platform.
func get_top_y() -> float:
	var rect := _shape.shape as RectangleShape2D
	return _shape.global_position.y - rect.size.y * 0.5

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("enter_traversal_zone"):
		body.enter_traversal_zone(get_top_y())

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("exit_traversal_zone"):
		body.exit_traversal_zone()
