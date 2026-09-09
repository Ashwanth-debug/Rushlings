class_name BotController
extends PlayerController

var brain: BotBrain

func _init(p_brain: BotBrain) -> void:
	brain = p_brain

func update(delta: float) -> void:
	brain.tick(delta)

func horizontal() -> float:
	return brain.horizontal_intent

func vertical() -> float:
	return brain.vertical_intent

func jump_pressed(_in_traversal_zone: bool) -> bool:
	return brain.consume_jump_intent()
