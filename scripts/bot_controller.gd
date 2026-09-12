class_name BotController
extends PlayerController

var brain: BotBrain

func _init(p_brain: BotBrain) -> void:
	brain = p_brain

func update(delta: float) -> void:
	if frozen:
		return
	brain.tick(delta)

func horizontal() -> float:
	if frozen:
		return 0.0
	return brain.horizontal_intent

func vertical() -> float:
	if frozen:
		return 0.0
	return brain.vertical_intent

func jump_pressed(_in_traversal_zone: bool) -> bool:
	if frozen:
		return false
	return brain.consume_jump_intent()
