class_name MatchConfig
extends RefCounted

# Slot -> controller mapping as data, not code (docs/DECISIONS.md,
# 2026-09-06, "A player slot's controller is data: human-local, bot, or
# (reserved) network"). NETWORK exists only as a named enum value; nothing
# constructs a NetworkController.

enum ControllerKind { HUMAN_LOCAL, BOT, NETWORK }

class SlotConfig:
	var slot_id: int
	var controller_kind: ControllerKind
	var color: Color
	var label: String

	func _init(p_slot_id: int, p_controller_kind: ControllerKind, p_color: Color, p_label: String) -> void:
		slot_id = p_slot_id
		controller_kind = p_controller_kind
		color = p_color
		label = p_label

var slots: Array[SlotConfig] = []
var match_seed: int = 1
var curiosity_player_prob: float = 0.25
var player_collision_enabled: bool = false
var labels_visible: bool = true

func _init() -> void:
	# P1 red/orange (unchanged from M1/M2), P2 purple, P3 green, P4 blue -
	# four saturated hues against the greyscale greybox palette.
	slots = [
		SlotConfig.new(1, ControllerKind.HUMAN_LOCAL, Color(0.9, 0.2, 0.2), "P1"),
		SlotConfig.new(2, ControllerKind.BOT, Color(0.55, 0.25, 0.8), "P2"),
		SlotConfig.new(3, ControllerKind.BOT, Color(0.25, 0.7, 0.3), "P3"),
		SlotConfig.new(4, ControllerKind.BOT, Color(0.25, 0.45, 0.9), "P4"),
	]
