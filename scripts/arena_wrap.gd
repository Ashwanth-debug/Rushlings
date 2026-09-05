class_name ArenaWrap
extends Node2D

# Horizontal arena wrapping.
#
# The arena is a continuous horizontal loop: a body that leaves completely
# through one side re-enters from the opposite side at the same height, keeping
# its velocity, facing and movement state. Nothing is faded, reset or delayed.
#
# Only the X coordinate is ever touched, so an arena with any number of vertical
# layers reuses this unchanged - a body wrapping on the top layer stays on the
# top layer.
#
# Anything in the "wrappable" group is wrapped, so future Rushlings, bots and
# objects inherit the behaviour without needing to know the wrap exists.

const WRAPPABLE_GROUP := "wrappable"

@export var left_edge: float = 0.0
@export var right_edge: float = 1920.0

## How far past an edge a body's origin must travel before it counts as fully
## gone. Must exceed half the width of the widest wrappable body. It doubles as
## hysteresis: a body re-enters well inside the opposite edge, so it can never
## satisfy the opposite test and wrap straight back.
@export var exit_margin: float = 40.0

func _ready() -> void:
	# Wrap only after every other node has finished moving this physics frame.
	process_physics_priority = 100

func _physics_process(_delta: float) -> void:
	var width := right_edge - left_edge
	if width <= 0.0:
		return
	for body in get_tree().get_nodes_in_group(WRAPPABLE_GROUP):
		if body is Node2D:
			_wrap_body(body, width)

func _wrap_body(body: Node2D, width: float) -> void:
	var x := body.global_position.x
	if x > right_edge + exit_margin:
		body.global_position.x = x - width
	elif x < left_edge - exit_margin:
		body.global_position.x = x + width
