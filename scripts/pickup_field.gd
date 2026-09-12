class_name PickupField
extends RefCounted

# M4-1 STOP 1 - the smallest possible bridge between the world's PowerPickup
# entities and BotBrain's existing target-selection seam. Deliberately not a
# node in the scene tree and not a signal bus - just a live query surface
# arena_01.gd builds once (scripts/arena_01.gd's _build_pickup_field()) and
# hands to every BotBrain via BotBrain.set_pickup_field() (a setter, not a
# constructor param, so this never touches BotBrain's existing constructor
# signature - see tools/m3_check.gd and tools/nav_soak_test.gd, which
# construct BotBrain directly and must keep working unmodified).

var pickups: Array = []

func register(pickup) -> void:
	pickups.append(pickup)

## Nav-graph node names currently holding a collectable (not mid-respawn)
## pickup - BotBrain's ROAM curiosity picker samples this directly, per
## docs/plans/M04_0_MATCH_SHAPE_DESIGN.md S08's "SEEK_PICKUP: if empty and an
## accessible pickup exists, occasionally choose a pickup as a goal."
func available_nodes() -> Array:
	var result: Array = []
	for p in pickups:
		if is_instance_valid(p) and p.is_available():
			result.append(p.nav_node)
	return result

## The real world x of the available pickup authored at `node`, or NAN if
## none - lets a bot that has already arrived at a pickup's platform walk
## straight to it instead of wandering randomly across it, the same way
## BotBrain's own _final_approach_relic() closes the last few pixels onto the
## Relic (see bot_brain.gd's generalised _final_approach_x()).
func x_for_node(node: String) -> float:
	for p in pickups:
		if is_instance_valid(p) and p.nav_node == node and p.is_available():
			return p.global_position.x
	return NAN
