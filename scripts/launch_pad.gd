extends Area2D

@export var launch_direction: Vector2 = Vector2(0, -1)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("receive_launch"):
		body.receive_launch(launch_direction)
