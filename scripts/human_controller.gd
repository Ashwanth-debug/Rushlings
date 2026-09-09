class_name HumanController
extends PlayerController

# Today's Input reads, verbatim - parameterised by an action-name prefix
# rather than hardcoded action strings, so a second local human (M9 couch
# multiplayer) only needs a different prefix and a second set of input
# actions, not a second code path. Default prefix "" resolves to today's
# unprefixed action names, so P1 behaves exactly as before M3-1.

var action_prefix: String

func _init(prefix: String = "") -> void:
	action_prefix = prefix

func _action(name: String) -> String:
	return action_prefix + name

func horizontal() -> float:
	return Input.get_axis(_action("move_left"), _action("move_right"))

func vertical() -> float:
	var intent := 0.0
	if Input.is_action_pressed(_action("vertical_intent_up")):
		intent -= 1.0
	if Input.is_action_pressed(_action("vertical_intent_down")):
		intent += 1.0
	return intent

func jump_pressed(in_traversal_zone: bool) -> bool:
	if Input.is_action_just_pressed(_action("jump")):
		return true
	# Up doubles as jump, but only away from a ladder - inside a traversal
	# zone it means climb up instead. Mirrors the original _get_jump_intent().
	return not in_traversal_zone and Input.is_action_just_pressed(_action("vertical_intent_up"))
