extends Area2D

@export var launch_direction: Vector2 = Vector2(0, -1)

func _ready() -> void:
	# Players moved to a dedicated layer 2 (post-A1/A2 playtest collision-
	# toggle fix, see player.gd) - this Area2D's default mask (layer 1 only)
	# would otherwise stop detecting them entirely.
	set_collision_mask_value(2, true)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("receive_launch"):
		body.receive_launch(launch_direction)
