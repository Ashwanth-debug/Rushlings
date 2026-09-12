class_name PowerType
extends RefCounted

# M4-1 STOP 1+2 - the approved power set (docs/plans/M04_0_MATCH_SHAPE_DESIGN.md
# S06/S12): Push (control/displacement, 0 damage), Rocket (direct ranged
# damage - damage itself is out of scope until STOP 3's health lands), Freeze
# (control/movement denial, 0 damage). A plain typed constant, not a class
# hierarchy - three fixed powers, no tiers/inventory/upgrade levels yet.

enum Type { NONE, PUSH, ROCKET, FREEZE }

const LABELS := {
	Type.NONE: "",
	Type.PUSH: "PSH",
	Type.ROCKET: "RKT",
	Type.FREEZE: "FRZ",
}

# Prototype greybox colours only - readability treatment, not production art.
# Chosen to stay distinguishable from the four player body colours
# (match_config.gd) and from each other at full-arena scale.
const COLORS := {
	Type.NONE: Color(0.5, 0.5, 0.5, 1.0),
	Type.PUSH: Color(0.95, 0.85, 0.15, 1.0),
	Type.ROCKET: Color(0.9, 0.25, 0.1, 1.0),
	Type.FREEZE: Color(0.3, 0.8, 0.95, 1.0),
}

static func label(type: int) -> String:
	return LABELS.get(type, "")

static func color(type: int) -> Color:
	return COLORS.get(type, COLORS[Type.NONE])
