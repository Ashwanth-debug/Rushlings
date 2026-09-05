extends Node2D

# Development-only harness for the Milestone 1 movement experiments.

@onready var _player: Node2D = $Player
var _spawn_position: Vector2

func _ready() -> void:
	_spawn_position = _player.global_position

func _process(_delta: float) -> void:
	# Debug affordance for playtesting only - NOT a Rushlings gameplay control.
	if Input.is_action_just_pressed("debug_reset"):
		_player.reset_to(_spawn_position)
