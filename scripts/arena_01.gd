extends Node2D

# Development-only harness for Arena 01 ("The Seam Ring"). Not a gameplay
# system - lets one human placeholder stand in for any of the four approved
# spawns during route testing, ahead of bots/multiplayer.

@onready var _player: Node2D = $Player
@onready var _spawns: Array[Marker2D] = [
	$Markers/Spawn1, $Markers/Spawn2, $Markers/Spawn3, $Markers/Spawn4
]

var _spawn_index: int = 0

func _ready() -> void:
	_player.reset_to(_spawns[_spawn_index].global_position)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug_reset"):
		_player.reset_to(_spawns[_spawn_index].global_position)
	if Input.is_action_just_pressed("debug_spawn_cycle"):
		_spawn_index = (_spawn_index + 1) % _spawns.size()
		_player.reset_to(_spawns[_spawn_index].global_position)
		print("Arena01: moved to spawn P%d %s" % [_spawn_index + 1, _spawns[_spawn_index].global_position])
