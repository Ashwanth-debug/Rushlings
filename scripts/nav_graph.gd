class_name NavGraph
extends RefCounted

# Hand-authored Arena 01 navigation graph. Nodes are the arena's real named
# platforms (read live from ArenaGeometry, not duplicated as separate
# Marker2D positions) - so the graph can never drift from hand-edited
# geometry the way a separately-authored marker set could. Edges are the
# arena's real traversal moves: jump (covers both R1 step-ups and R2 gaps -
# same "run to the edge and jump" recipe either way), drop, ladder and
# launch, each executed for real by edge_executor.gd, never invented.
#
# Costs are engineering estimates for route *comparison*, not measured
# constants - see the automated nav-graph edge validation test, which
# measures every edge's real elapsed time with a real BotController and is
# the actual authority on whether an edge works at all.

var geometry: ArenaGeometry
var nodes: Array[String] = []
var edges: Array[Dictionary] = []
var _adjacency: Dictionary = {}   # node name -> Array[Dictionary] (outgoing edges)

func _init(p_geometry: ArenaGeometry) -> void:
	geometry = p_geometry
	# CoverW removed from Arena 01 (Director decision, human-playtest-driven
	# M3 level-design adjustment - see docs/DECISIONS.md): not a stale/missing
	# reference to defend against, it simply no longer exists. No CoverW node
	# or edge should appear anywhere below.
	nodes = [
		"Floor", "CoverE",
		"C_W", "C_M", "C_Seam",
		"B_W", "Pier", "B_Under", "B_E", "B_Seam",
		"A_W", "A_W_Bridge", "VaultFloor", "VaultEast", "A_E", "A_E_Bridge",
	]
	_build_edges()
	_validate_against_geometry()
	for n in nodes:
		_adjacency[n] = []
	for e in edges:
		_adjacency[e.from].append(e)

const RouteClass = {
	RELIABLE = "reliable",
	SKILL = "skill",
	INVALID = "invalid",
}

# History: a runtime crash was originally traced to CoverW being deleted
# from the scene while NavGraph's hand-authored node/edge list still
# referenced it - geometry.aabb() quietly returns {} for a name with no live
# geometry rather than erroring, so nothing upstream noticed until
# edge_executor.gd indexed a field on that {} (also hardened directly there,
# see its _validate_geometry). CoverW's own references have since been
# removed entirely (Director decision - it is deleted arena geometry now,
# not a stale reference to defend against), but the general defence stays:
# any edge whose from/to platform, ladder or pad has no live geometry right
# now is marked INVALID here, once, at load time - never entering
# pathfinding (see bot_brain.gd's cost function) rather than crashing or
# silently misrouting later. A scene
# edit (deleting, renaming, or hiding a StaticBody2D so it never registers
# with ArenaGeometry) is exactly the kind of stale-metadata scenario this
# guards against - it does not require every edit to also update this file.
var invalid_edges: Array[Dictionary] = []

func _validate_against_geometry() -> void:
	invalid_edges = []
	for e in edges:
		var reason := ""
		match e.type:
			"jump", "drop", "walk":
				if not geometry.has(e.from):
					reason = "'%s' has no live geometry" % e.from
				elif not geometry.has(e.to):
					reason = "'%s' has no live geometry" % e.to
			"ladder":
				if not geometry.ladders.has(e.get("ladder", "")):
					reason = "ladder '%s' has no live geometry" % e.get("ladder", "")
			"launch":
				if not geometry.pads.has(e.get("pad", "")):
					reason = "pad '%s' has no live geometry" % e.get("pad", "")
		if reason != "":
			e.route_class = RouteClass.INVALID
			e.invalid_reason = reason
			invalid_edges.append(e)
			push_warning("NavGraph: %s->%s marked INVALID - %s" % [e.from, e.to, reason])

func _edge(from: String, to: String, type: String, cost: float, extra: Dictionary = {}) -> Dictionary:
	var e := {"from": from, "to": to, "type": type, "cost": cost, "skill": false, "timeout": 5.0, "route_class": RouteClass.RELIABLE}
	e.merge(extra, true)
	# The `skill` flag already existed for by-design skill routes (B_Under,
	# the B_Seam<->B_W hop) - keep it in sync with route_class rather than
	# tracking two separate booleans for the same idea.
	if e.skill:
		e.route_class = RouteClass.SKILL
	return e

func _build_edges() -> void:
	var lad_w: Dictionary = geometry.ladders.get("LadW", {})
	var lad_e: Dictionary = geometry.ladders.get("LadE", {})
	var b_e: Dictionary = geometry.aabb("B_E")

	# Nav-graph audit (Director feedback, iteration 4: classify edges as
	# reliable_bot_route / skill / invalid rather than requiring bots to use
	# every theoretically reachable human traversal). Every edge below
	# tagged {"skill": true} for a reason OTHER than "by-design advanced
	# route" (that reason is recorded on each one) was measured via
	# tools/m3_check.gd's edge-validation test to fail or be meaningfully
	# unreliable under the current jump/drop physics - CoverE because the
	# Band C platform directly overhead (C_M) blocks the ascent regardless
	# of takeoff tuning, and the two Band B drops because of a still-
	# unexplained platform-specific embedding/rest-position issue on
	# departure. They remain in the graph with real costs (so pathfinding
	# and recovery can still use them as a last resort, and the automated
	# nav stress test can still exercise them explicitly) but ordinary bot
	# ROAM/stress-test routing excludes route_class == "skill" by default -
	# see NavPath's cost_fn usage in bot_brain.gd.
	#
	# Traversal audit fix (Arena01_Traversal_Audit.docx, smallest
	# implementation plan, step 01): every drop edge below now authors its
	# own departure side ("left" = depart from `from`'s west edge, "right" =
	# east edge) as data, rather than letting edge_executor.gd infer it from
	# the target's centre. Inference is only actually wrong when the
	# target's centre falls inside the source platform's own extent
	# (B_W->C_W, A_W->B_W below) - for every other edge, "side" is set to
	# exactly the direction the old centre-comparison already produced, so
	# this is a pure authoring change with zero behaviour change on them
	# (confirmed by the full drop-edge regression re-run in Test 1).
	edges = [
		# CoverW removed from Arena 01 (Director decision, human-playtest-
		# driven M3 level-design adjustment) - no edge references it.
		# Floor <-> CoverE - sits directly under a Band C platform (C_M)
		# whose underside the ascent can't reliably clear.
		_edge("Floor", "CoverE", "jump", 0.6, {"skill": true}),
		_edge("CoverE", "Floor", "drop", 0.5, {"side": "left"}),

		# Floor <-> Band C
		# Floor -> Band C jump reliability under real concurrent load was an
		# open problem - see the M3-1 report's known-limitations section and
		# docs/plans/Arena01_Traversal_Audit.docx. Floor->C_M is the one
		# dependable, central bot road up from the ground, via the
		# fixed-trigger recipe below (see edge_executor.gd's
		# _advance_fixed_trigger_jump).
		#
		# Director directive (2026-09-08, navigation-policy correction): now
		# that Floor->C_M is proven 5/5, Floor->C_W and Floor->C_Seam are
		# demoted to SKILL - not merely re-costed. A 5-minute soak test found
		# bots still selected them ~5x more often than C_M despite C_M's
		# lower base cost, because a bot's TARGET is C_W/C_Seam/wherever, and
		# Dijkstra compares the direct edge's cost against a real C_M detour
		# (0.6 + 0.9 = 1.5) - the direct edge's flat 0.7 undercuts that no
		# matter how C_M itself is priced, so cost tuning alone cannot fix
		# this; only removing them from Dijkstra's RELIABLE-only search
		# (route_class == SKILL -> INF in bot_brain.gd's _weighted_cost) does.
		# Walking toward either direct target from most Floor positions also
		# crosses straight through the CoverE/C_M pocket (CoverE sits
		# entirely inside C_M's own footprint) - the soak test measured 66-
		# 72% of two bots' entire 5-minute runtime spent dwelling in that
		# pocket while repeatedly failing this exact edge, which is the
		# CoverE-trapping bug this demotion is also meant to close. Skill
		# edges remain real, legal M1 traversal for a human player -
		# 'HUMAN_ONLY' in the Director's own words for this classification -
		# this affects bot path planning only.
		_edge("Floor", "C_W", "jump", 0.7, {"skill": true}),
		_edge("C_W", "Floor", "drop", 0.6, {"side": "right"}),
		# trigger_far/trigger_near follow the audit's own modelled range
		# (60-100px), engine-confirmed 5/5 across a spread of realistic Floor
		# starting positions on both sides of C_M - see the m3_check.gd
		# report.
		# timeout raised from the 5.0s default: the reposition/build-runway
		# phase (edge_executor.gd) can legitimately add a few real seconds
		# on a bad start before the normal approach even begins - the
		# recipe's OWN bounded reposition-attempt/reposition-duration caps
		# are what actually prevent an infinite loop, not this timeout.
		_edge("Floor", "C_M", "jump", 0.6, {"fixed_trigger": true, "trigger_far": 100.0, "trigger_near": 60.0, "timeout": 8.0}),
		_edge("C_M", "Floor", "drop", 0.6, {"side": "left"}),
		_edge("Floor", "C_Seam", "jump", 0.7, {"skill": true}),
		_edge("C_Seam", "Floor", "drop", 0.6, {"side": "left"}),

		# Launcher: Floor -> Band B directly, both landings. Kept skill-tagged
		# per the Game Director (M3-1: launcher may remain human/skill-only
		# as long as it does not affect required global bot connectivity -
		# it does not, see the connectivity report) - not re-evaluated for
		# ordinary bot reliability this pass, even though removing CoverW
		# cleared the one obstacle previously known to sit in its approach.
		_edge("Floor", "B_W", "launch", 1.0, {"pad": "PadC", "steer_dir": 1, "skill": true}),
		_edge("Floor", "B_Seam", "launch", 1.0, {"pad": "PadC", "steer_dir": -1, "skill": true}),

		# Band C internal gaps. C_W <-> C_Seam has no direct edge - the gap is
		# too wide to clear in one jump (it is two chained gaps, C_W->C_M and
		# C_M->C_Seam); Dijkstra already routes through C_M for free.
		_edge("C_W", "C_M", "jump", 0.9),
		_edge("C_M", "C_W", "jump", 0.9),
		_edge("C_M", "C_Seam", "jump", 0.9),
		_edge("C_Seam", "C_M", "jump", 0.9),

		# The B_Under skill route - narrow landing, confirmed high-value
		# pickup spot per docs/DECISIONS.md. Tagged so bots may fail and
		# re-path rather than treating it as a normal edge. B_Under has no
		# edge onward to B_E - the checker's own R2 static audit classifies
		# that gap as a barrier (180px gap exceeds the ~48px ballistic reach
		# at that rise), so it is a dead end reachable only from C_W.
		_edge("C_W", "B_Under", "jump", 1.1, {"skill": true}),
		_edge("B_Under", "C_W", "drop", 0.6, {"side": "left"}),

		# Band B internal
		_edge("B_Seam", "B_W", "jump", 1.1, {"skill": true}),
		_edge("B_W", "B_Seam", "jump", 1.1, {"skill": true}),

		# Band B -> Band C: cheap to fall, per Arena 01's core asymmetry.
		# Both platforms have their departure edge chosen ONCE per attempt
		# now (see edge_executor.gd's _advance_drop) after a confirmed
		# regression where recomputing the direction every tick oscillated
		# forever near the target's centre instead of ever departing -
		# these are B_W/B_E's ONLY non-skill exit, so keeping them reliable
		# (not skill) matters even though a residual, position-dependent
		# collision (a nearby platform, not the departure itself) can still
		# occasionally block a specific approach - see the M3-1 report.
		#
		# Traversal audit (step 01, engine-confirmed): B_W's east side is a
		# WALL, not an edge - the Pier's solid face spans y200-620, flush
		# with B_W's own y560 surface. C_W's centre (650) sits inside B_W's
		# own extent (460-740), so the old target-centre inference picked
		# "east" from most starting positions on B_W, walking the body
		# straight into the Pier's face where it stalled for the full 2.85s
		# timeout every time. The only real departure is B_W's west edge.
		_edge("B_W", "C_W", "drop", 0.6, {"side": "left"}),
		_edge("B_E", "C_M", "drop", 0.6, {"side": "left"}),

		# LadW: Band C <-> Crown west
		_edge("C_W", "A_W", "ladder", 2.5, {"ladder": "LadW", "climb_dir": -1, "exit_dir": 1, "target_y": lad_w.get("top", 210.0)}),
		_edge("A_W", "C_W", "ladder", 2.2, {"ladder": "LadW", "climb_dir": 1, "exit_dir": 1, "target_y": lad_w.get("bottom", 820.0)}),

		# LadE: Band C <-> Band B mid-station <-> Crown east. The top exit
		# lands on A_E_Bridge, not A_E directly - A_E_Bridge is the platform
		# immediately touching the ladder's own column, and holding exit_dir
		# all the way to a landing (deceleration is floor-only, so an exit
		# walk that starts accelerating the instant it leaves the zone can
		# reach a fair clip before landing) overshoots clean past A_E onto
		# A_E_Bridge anyway. The already-proven A_E_Bridge<->A_E walk edge
		# finishes the trip for free.
		_edge("C_Seam", "A_E_Bridge", "ladder", 2.0, {"ladder": "LadE", "climb_dir": -1, "exit_dir": -1, "target_y": lad_e.get("top", 210.0)}),
		_edge("A_E", "C_Seam", "ladder", 1.8, {"ladder": "LadE", "climb_dir": 1, "exit_dir": 1, "target_y": lad_e.get("bottom", 820.0)}),
		# The mid-station stop is well above B_E's own surface, not flush
		# with it - exiting flush would have the body's feet still inside
		# B_E's solid mass (its origin, not its feet, is what climbing
		# clamps), colliding with its east face instead of settling onto
		# its top. The real ladder-to-destination pairs (e.g. LadE top to
		# A_E_Bridge) all have 80-100px of exactly this clearance by design
		# (R4) - matching it here lets exit+gravity settle onto B_E cleanly.
		_edge("C_Seam", "B_E", "ladder", 1.2, {"ladder": "LadE", "climb_dir": -1, "exit_dir": -1, "target_y": b_e.get("top", 560.0) - 90.0}),
		_edge("B_E", "A_E_Bridge", "ladder", 1.0, {"ladder": "LadE", "climb_dir": -1, "exit_dir": -1, "target_y": lad_e.get("top", 210.0)}),
		_edge("A_E", "B_E", "ladder", 0.9, {"ladder": "LadE", "climb_dir": 1, "exit_dir": -1, "target_y": b_e.get("top", 560.0) - 90.0}),

		# Crown. A_W<->A_W_Bridge and A_E<->A_E_Bridge are the same walking
		# height with touching/overlapping x-ranges and no wall between them -
		# a plain walk, not a jump (a jump's fixed flight time would carry a
		# full-speed takeoff clean over these 90px connectors and into
		# whatever is next). A_W_Bridge->Pier is a genuine jump (100px rise);
		# Pier->A_W_Bridge is the reverse direction, i.e. a drop, not a jump.
		_edge("A_W", "A_W_Bridge", "walk", 0.4),
		_edge("A_W_Bridge", "A_W", "walk", 0.4),
		_edge("A_W_Bridge", "Pier", "jump", 0.5),
		_edge("Pier", "A_W_Bridge", "drop", 0.4, {"side": "left"}),
		_edge("Pier", "VaultFloor", "drop", 0.5, {"side": "right"}),
		# Director decision (2026-09-07): a two-tread staircase replacement
		# (VaultStepA/VaultStepB) was implemented and tested, then REJECTED
		# and reverted after human playtest evidence: the Director can
		# repeatedly enter/exit the vault successfully using this ORIGINAL
		# VaultEast geometry. The problem was reclassified as a bot-execution
		# gap, not a level-design defect - do not redesign this geometry
		# again without new Director direction.
		# 2026-09-08: a dev-only traversal recorder captured the Director's
		# actual technique across two full demonstrations, consistently:
		# walk to the wall, release horizontal, jump with ZERO horizontal
		# hold (straight up beside the wall - no attempt to avoid contact),
		# hold zero horizontal to the apex, THEN steer onto the target. This
		# is edge_executor.gd's _advance_vertical_clear_jump, gated by the
		# "vertical_clear" flag below - a local recipe for these two edges
		# only, not a change to the shared jump-trigger logic other edges
		# use. See docs/DECISIONS.md and the M3-1 report for the full
		# comparison against the bot's previous (unreliable) attempt.
		# 2026-09-08: the vertical_clear recipe above was tested from three
		# realistic starting positions (near VaultFloor/VaultFloor_Bridge,
		# matching where a bot actually lands after entering via Pier) and
		# succeeded cleanly on both hops every time - promoted to reliable.
		_edge("VaultFloor", "VaultEast", "jump", 0.5, {"vertical_clear": true}),
		_edge("VaultEast", "VaultFloor", "drop", 0.4, {"side": "left"}),
		_edge("VaultEast", "A_E", "jump", 0.5, {"vertical_clear": true}),
		_edge("A_E", "VaultEast", "drop", 0.4, {"side": "left"}),
		_edge("A_E", "A_E_Bridge", "walk", 0.4),
		_edge("A_E_Bridge", "A_E", "walk", 0.4),

		# Traversal audit (Arena01_Traversal_Audit.docx, smallest
		# implementation plan, step 02): the three mandatory missing
		# transitions. Without them the RELIABLE subgraph is not strongly
		# connected - B_Seam has no reliable edge in or out at all, and
		# B_W/A_E_Bridge's only reliable ways into their neighbouring bands
		# are missing. Verified by exhaustive search in the audit: no set of
		# one or two edges suffices, and this set of three is the minimal
		# working set. Kept edge-scoped: no other drop behaviour changes.
		#
		# B_Seam sits entirely above C_Seam - a plain creep drop, west edge
		# (matches the audit's engine-modelled 6/6 result).
		_edge("B_Seam", "C_Seam", "drop", 0.6, {"side": "left"}),
		# A_W sits above B_W's west portion - B_W's only reliable way in.
		# Same shape as the B_W->C_W fix above: the target's centre falls
		# inside the source's own extent, so the side must be authored, not
		# inferred. Creep drop, west edge (audit: 6/6).
		_edge("A_W", "B_W", "drop", 0.6, {"side": "left"}),
		# A_E_Bridge -> B_Seam needs the new RUN_DROP recipe: it is both a
		# 260px fall AND a genuine 130px horizontal gap (A_E_Bridge's east
		# edge at x=1650, B_Seam's west edge at x=1780) - the ordinary creep
		# recipe only drifts ~39px and falls two bands short onto C_Seam
		# instead. A full-speed departure drifts ~243px and lands mid-B_Seam
		# (audit: 6/6 at every speed tested).
		_edge("A_E_Bridge", "B_Seam", "drop", 0.8, {"side": "right", "run_drop": true}),
	]

func outgoing(node: String) -> Array:
	return _adjacency.get(node, [])

func edge_counts() -> Dictionary:
	var counts := {RouteClass.RELIABLE: 0, RouteClass.SKILL: 0, RouteClass.INVALID: 0}
	for e in edges:
		counts[e.route_class] = counts.get(e.route_class, 0) + 1
	return counts

## BFS over RELIABLE edges only - the actual connectivity ordinary bot
## pathfinding has, not the graph's theoretical full connectivity. Used both
## to report which regions/nodes a policy of "reliable edges only" leaves
## disconnected, and to keep ROAM/stress-test target selection from ever
## choosing a node nothing can reliably reach.
func reliable_reachable_from(start: String) -> Dictionary:
	var visited := {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var u: String = queue.pop_front()
		for e in outgoing(u):
			if e.route_class != RouteClass.RELIABLE:
				continue
			if not visited.has(e.to):
				visited[e.to] = true
				queue.append(e.to)
	return visited
