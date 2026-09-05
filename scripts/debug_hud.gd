extends Label

@export var player_path: NodePath
var player: Node2D

func _ready() -> void:
	player = get_node(player_path)

func _process(_delta: float) -> void:
	if player == null:
		return
	var state := "climbing"
	if not player.is_climbing:
		state = "floor" if player.is_on_floor() else "air"
	text = "pos: (%.0f, %.0f)\nvel: (%.0f, %.0f)\nstate: %s\nin zone: %s\n[Space] jump   [R] reset" % [
		player.global_position.x, player.global_position.y,
		player.velocity.x, player.velocity.y,
		state, str(player.in_traversal_zone)
	]
