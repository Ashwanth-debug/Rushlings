class_name ArenaRegions
extends RefCounted

# A small, fixed set of macro-regions grouping the nav graph's existing
# platform nodes - added after the A1/A2 playtest because node-level least-
# recently-visited selection alone produced roaming that didn't read as
# purposeful (Problem 4: "bots currently look too much like they are moving
# for no reason"). This is a selection layer only - no arena geometry
# changes, no new nodes, no new edges. A bot picks a REGION first (biased
# toward regions meaningfully separated from its own, or occasionally one
# another player currently occupies), then a node within it, then paths
# there exactly as before.
#
# Five regions, matching the shapes the Game Director asked for: a lower
# floor region, a west vertical column, a central band, an east vertical
# column, and the seam/wrap platforms.

const REGION_OF := {
	# CoverW removed from Arena 01 (Director decision, human-playtest-driven
	# M3 level-design adjustment) - no longer listed anywhere here.
	"Floor": "floor", "CoverE": "floor",
	"B_W": "west", "Pier": "west", "A_W": "west", "A_W_Bridge": "west",
	"C_W": "central", "C_M": "central", "B_Under": "central",
	"VaultFloor": "central", "VaultEast": "central",
	"B_E": "east", "A_E": "east", "A_E_Bridge": "east",
	"C_Seam": "seam", "B_Seam": "seam",
}

const REGIONS: Array[String] = ["floor", "west", "central", "east", "seam"]

# Rough spatial ordering of the regions, arranged as a loop matching the
# arena's actual cylindrical topology - "seam" (the wrap point) sits next to
# "west" on one side and "east" on the other, exactly like the real arena.
# Used to prefer destinations meaningfully separated from the current one
# (Problem 4: "encourage arena-scale traversal") rather than just avoiding
# exact repeats.
const REGION_ORDER: Array[String] = ["west", "floor", "central", "east", "seam"]

# During M3-1 ROAM the Relic/vault chamber is not a destination a bot has any
# reason to visit - there is no Relic objective yet (that is M3-2's
# SEEK_RELIC). These nodes stay in the graph (with real physical edges) so
# pathfinding and recovery still work if a bot ends up there by accident;
# they are just never offered as an intentional target.
const NO_ROAM_TARGETS: Array[String] = ["VaultFloor", "VaultEast"]

static func region_of(node: String) -> String:
	return REGION_OF.get(node, "")

static func nodes_in(region: String) -> Array:
	var result: Array = []
	for n in REGION_OF:
		if REGION_OF[n] == region:
			result.append(n)
	return result

## Nodes in `region` that are legitimate ROAM destinations - excludes the
## vault (see NO_ROAM_TARGETS). Still returns vault nodes if they are the
## ONLY nodes in the region (never true today, since "central" always has
## C_W/C_M/B_Under too) so a region is never made unreachable as a target.
static func roamable_nodes_in(region: String) -> Array:
	var all_nodes := nodes_in(region)
	var result: Array = []
	for n in all_nodes:
		if not NO_ROAM_TARGETS.has(n):
			result.append(n)
	return result if not result.is_empty() else all_nodes

## Circular distance between two regions along REGION_ORDER's loop - 0 for
## the same region, up to floor(REGIONS.size()/2) for the "furthest" pair.
static func region_distance(a: String, b: String) -> int:
	var ia := REGION_ORDER.find(a)
	var ib := REGION_ORDER.find(b)
	if ia < 0 or ib < 0:
		return 0
	var d: int = abs(ia - ib)
	return min(d, REGION_ORDER.size() - d)
