class_name PlayerController
extends RefCounted

# Base for the three concepts a player slot's controller can be:
# human-local, bot, or (reserved, unwritten) network. player.gd's three
# intent functions delegate to whichever controller is assigned at spawn, so
# movement physics never knows or cares which one is driving it.
#
# update() runs once per physics frame, before player.gd reads horizontal(),
# vertical() and jump_pressed() for that same frame. HumanController's is a
# no-op (Input already reflects the frame's state); BotController's is where
# the bot actually decides what to do next.

func update(_delta: float) -> void:
	pass

func horizontal() -> float:
	return 0.0

func vertical() -> float:
	return 0.0

## in_traversal_zone is passed in because the human keyboard mapping
## overloads "Up" to mean jump outside a zone and climb inside one -
## player.gd owns that flag; the controller doesn't.
func jump_pressed(_in_traversal_zone: bool) -> bool:
	return false
