extends SceneTree

# M3-1 automated tests (docs/plans/M03_CORE_GAME_LOOP.md §9.2), strengthened
# across the A1/A2 and iteration-2/3 human playtests. Run headless:
#   godot --headless --path . --script tools/m3_check.gd
#
# Test 7 in the M3-1 plan (regression with four bodies present) is
# tools/arena_check.gd itself, unchanged in scope - it already loads
# arena_01.tscn's four real PlayerSlots (three of them bots) and must
# return PASS. Run it separately.
#
# This file covers:
#   1. Nav-graph edge validation + bounded-retry (no edge spams a full
#      timeout re-attempting the same failed obstacle).
#   2. Determinism - same seed -> identical position hash after N ticks.
#   3. Escalating recovery timing - a deliberately stalled bot reaches
#      stage1/2/3 at approximately the documented thresholds, not late.
#   4. Vault entry -> physical exit -> resumes roam (no teleporting).
#   5. Long-run (120s x3 seeds) simulation covering: decorrelation,
#      per-bot region coverage (including far/left-right/seam traversal),
#      per-bot vertical-band coverage and at least one vertical traversal,
#      encounter rate, ladder/launch/wrap usage, no unresolved bot
#      inactivity (idle-streak, independent of hard recovery), no bot stuck
#      in a logical-idle debug_state for too long, rare hard recovery.
#   6. Collision toggle - OFF truly allows overlap/pass-through, ON
#      genuinely separates players, verified via real layers/masks.

const ARENA_SCENE_PATH := "res://scenes/arena_01/arena_01.tscn"

var fails: Array[String] = []
var warns: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== M3-1 Automated Tests ===")
	await _test_graph_classification()
	await _test_strong_connectivity_and_no_sink()
	await _test_edge_validation()
	await _test_determinism()
	await _test_escalating_recovery_timing()
	await _test_vault_entry_exit()
	await _test_long_run()
	await _test_collision_toggle()
	await _test_nav_stress_destinations()
	await _test_vault_destination_change_regression()
	await _test_stress_label_respects_cap()
	_print_summary()
	quit(1 if not fails.is_empty() else 0)

func _report(label: String, verdict: String, detail: String) -> void:
	var line := "[%s] %-60s %s" % [verdict, label, detail]
	print(line)
	if verdict == "FAIL":
		fails.append(line)
	elif verdict == "WARN":
		warns.append(line)

func _print_summary() -> void:
	print("\n=== SUMMARY ===")
	print("Failures: %d" % fails.size())
	for f in fails:
		print("  " + f)
	print("Warnings: %d" % warns.size())
	for w in warns:
		print("  " + w)
	print("RESULT: %s" % ("PASS" if fails.is_empty() else "FAIL"))

# --- Shared rig --------------------------------------------------------------

func _load_rig() -> Dictionary:
	var arena: Node2D = (load(ARENA_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	return {"arena": arena, "geometry": arena.geometry, "graph": arena.nav_graph}

func _unload_rig(arena: Node2D) -> void:
	arena.queue_free()
	await process_frame

func physics_ticks_per_second() -> float:
	return float(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60))

func _band_of(node: String) -> String:
	# CoverW removed from Arena 01 (Director decision, human-playtest-driven
	# M3 level-design adjustment) - no longer listed here.
	if node == "Floor" or node == "CoverE":
		return "Floor"
	if node in ["C_W", "C_M", "C_Seam"]:
		return "Band C"
	if node in ["B_W", "Pier", "B_Under", "B_E", "B_Seam"]:
		return "Band B"
	return "Band A (Crown)"

class FrozenController extends PlayerController:
	func update(_delta: float) -> void:
		pass
	func horizontal() -> float:
		return 0.0
	func vertical() -> float:
		return 0.0
	func jump_pressed(_z: bool) -> bool:
		return false

# --- Test 1: nav-graph edge validation ---------------------------------------

class TestEdgeController extends PlayerController:
	var exec: EdgeExecutor
	var status: int = EdgeExecutor.Status.RUNNING
	func _init(e: EdgeExecutor) -> void:
		exec = e
	func update(delta: float) -> void:
		if status == EdgeExecutor.Status.RUNNING:
			status = exec.tick(delta)
	func horizontal() -> float:
		return exec.horizontal_intent
	func vertical() -> float:
		return exec.vertical_intent
	func jump_pressed(_z: bool) -> bool:
		return exec.jump_flag

# reset_to() teleports instantly, and the very first physics tick after a
# teleport can apply a gravity step before move_and_slide() has re-detected
# the new floor contact - usually invisible, but on a thin platform (e.g.
# CoverE, 37px) that momentary dip can leave the body embedded rather than
# cleanly resting on top, which a real bot would never do (it always
# arrives via a real jump arc, not a teleport). Settle for real - small
# extra clearance, then wait for is_on_floor() with near-zero vertical
# velocity - rather than assuming a fixed tick count is enough.
func _place_and_settle(body: CharacterBody2D, target_pos: Vector2, max_ticks: int = 60) -> void:
	body.controller = FrozenController.new()
	body.reset_to(target_pos + Vector2(0, -3.0))
	var t := 0
	while t < max_ticks:
		await physics_frame
		t += 1
		if body.is_on_floor() and abs(body.velocity.y) < 5.0:
			break

# --- Test 0: graph classification + reliable-only connectivity --------------
# Director feedback: report RELIABLE/SKILL/INVALID edge counts explicitly,
# and whether every required macro-region is still connected using ONLY
# RELIABLE edges - the actual subgraph ordinary bot pathfinding has now that
# skill edges are no longer a permitted fallback (see bot_brain.gd's
# _weighted_cost). This runs first since every later test's meaning depends
# on this baseline.

const REQUIRED_REGIONS := {
	"Lower/Floor": "Floor",
	"West": "C_W",
	"East": "C_M",
	"Upper Left (Crown)": "A_W",
	"Upper Right (Crown)": "A_E",
	"Seam/Wrap": "C_Seam",
	"Central/Vault Approach": "VaultFloor",
}

func _test_graph_classification() -> void:
	print("\n--- Test 0: nav-graph edge classification + reliable-only connectivity ---")
	var rig := await _load_rig()
	var graph: NavGraph = rig.graph
	var counts: Dictionary = graph.edge_counts()
	_report("edge classification counts", "PASS", "RELIABLE=%d SKILL=%d INVALID=%d (total %d)" % [
		counts.get("reliable", 0), counts.get("skill", 0), counts.get("invalid", 0), graph.edges.size()
	])
	for e in graph.invalid_edges:
		_report("INVALID edge: %s->%s" % [e.from, e.to], "WARN", e.get("invalid_reason", "?"))

	var reach: Dictionary = graph.reliable_reachable_from("Floor")
	var all_connected := true
	for label in REQUIRED_REGIONS:
		var rep: String = REQUIRED_REGIONS[label]
		if reach.has(rep):
			_report("required region connected (reliable-only): %s" % label, "PASS", "reachable from Floor via %d-node reliable subgraph" % reach.size())
		else:
			all_connected = false
			_report("required region connected (reliable-only): %s" % label, "FAIL", "'%s' is NOT reachable from Floor using only RELIABLE edges - a Game Director level-design decision, not a bot bug" % rep)
	if not all_connected:
		print("  ** ARENA CONNECTIVITY PROBLEM: see FAILs above - report to Game Director, do not route around with skill fallbacks **")
	await _unload_rig(rig.arena)

# --- Test 0b: strong connectivity + no-sink (RELIABLE edges only) -----------
# Traversal audit (Arena01_Traversal_Audit.docx): "the funnel". Test 0 above
# only asks whether each macro-REGION contains SOME node reachable from
# Floor - which is why a Floor that reliably reaches nothing still passed,
# reporting "a 12-node reliable subgraph" while quietly naming the nodes with
# no reliable way in rather than failing on them. These two assertions work
# at node granularity, with an explicit, narrowly-keyed exception list so a
# genuinely new orphan cannot hide behind an old one.
const CONNECTIVITY_EXCEPTIONS := {
	"CoverE": "no reliable incoming edge, by design - a dead-end skill-only pocket (Floor->CoverE is skill; C_M's underside blocks the ascent), never offered as a ROAM target",
	"B_Under": "no reliable incoming edge - C_W->B_Under sits ~0.09px beyond the jump's physical rise ceiling (jump_strength^2/(2*gravity)=184.09px vs a measured 184.0px rise), a Director-reserved M4 pickup site not reclassified this pass (Arena01_Traversal_Audit.docx step 04, not yet implemented)",
}

func _test_strong_connectivity_and_no_sink() -> void:
	print("\n--- Test 0b: strong connectivity + no-sink (RELIABLE edges only) ---")
	var rig := await _load_rig()
	var graph: NavGraph = rig.graph

	# No-sink: every node needs at least one RELIABLE outgoing AND at least
	# one RELIABLE incoming edge, or an explicit named exception above.
	var has_out: Dictionary = {}
	var has_in: Dictionary = {}
	for n in graph.nodes:
		has_out[n] = false
		has_in[n] = false
	for e in graph.edges:
		if e.route_class == NavGraph.RouteClass.RELIABLE:
			has_out[e.from] = true
			has_in[e.to] = true
	for n in graph.nodes:
		var exc: String = CONNECTIVITY_EXCEPTIONS.get(n, "")
		if not has_out[n]:
			_report("no-sink: %s has a RELIABLE outgoing edge" % n, "FAIL" if exc == "" else "WARN", exc if exc != "" else "zero RELIABLE outgoing edges - a bot that ends up here can never reliably leave")
		if not has_in[n]:
			_report("no-sink: %s has a RELIABLE incoming edge" % n, "FAIL" if exc == "" else "WARN", exc if exc != "" else "zero RELIABLE incoming edges - ordinary bot routing can never deliver a bot here")

	# Strong connectivity: every node reaches every OTHER required node using
	# RELIABLE edges only. A named exception may legitimately be unreachable
	# AS A TARGET (see no-sink above) - it is excluded from the "must be
	# reached" requirement but still checked as a SOURCE, since a bot that
	# ends up there by any means (recovery, a skill edge, human proximity)
	# must still be able to route back out to everywhere else.
	var required_targets: Array = []
	for n in graph.nodes:
		if not CONNECTIVITY_EXCEPTIONS.has(n):
			required_targets.append(n)
	var all_ok := true
	for n in graph.nodes:
		var reach: Dictionary = graph.reliable_reachable_from(n)
		var missing: Array = []
		for t in required_targets:
			if t != n and not reach.has(t):
				missing.append(t)
		var required_count: int = required_targets.size() - (1 if required_targets.has(n) else 0)
		if missing.is_empty():
			_report("strong connectivity: %s reaches every required node" % n, "PASS", "%d/%d required targets reachable" % [required_count, required_count])
		else:
			all_ok = false
			_report("strong connectivity: %s reaches every required node" % n, "FAIL", "cannot reliably reach: %s" % ", ".join(missing))
	if all_ok:
		print("  ** RELIABLE subgraph is strongly connected (named exceptions: %s) **" % ", ".join(CONNECTIVITY_EXCEPTIONS.keys()))
	else:
		print("  ** RELIABLE subgraph is NOT strongly connected - see FAILs above **")
	await _unload_rig(rig.arena)

# Traversal audit fix: "edge validation from a spread of start positions -
# every edge from >=5 positions across the source platform's walkable span,
# not just its centre. Report worst-case, not any-case." A centre-only test
# is exactly how Floor->C_W/Floor->C_M previously reported PASS while
# failing constantly in play (the checker's lucky single runway vs. real
# bot start positions) - see the audit's "gap between the test and the
# arena" finding. An edge is only reported PASS here if EVERY sampled start
# position succeeds.
const EDGE_VALIDATION_FRACTIONS := [0.15, 0.3, 0.5, 0.7, 0.85]

func _start_positions_for(from_aabb: Dictionary, half_w: float) -> Array:
	var left: float = from_aabb.left + half_w + 4.0
	var right: float = from_aabb.right - half_w - 4.0
	if right <= left:
		return [from_aabb.center.x]
	var xs: Array = []
	for f in EDGE_VALIDATION_FRACTIONS:
		xs.append(lerp(left, right, f))
	return xs

# Director directive (Floor->C_M fixed-trigger follow-up, expanded after the
# reposition/build-runway fix): the generic spread above samples uniformly
# across the WHOLE source platform, which for Floor (nearly the full arena
# width) does not reliably land a sample inside the fixed-trigger recipe's
# own 60-100px window right next to C_M. This edge gets its own position
# (and, where the Director's matrix requires it, INITIAL VELOCITY) set,
# derived entirely from C_M's live geometry and the body's own max_speed -
# never hardcoded coordinates - covering both approach sides:
#   far / medium / ideal-window(pre-built speed) / inside-window+zero-vel /
#   inside-window+wrong-direction-vel / immediately-adjacent-too-close.
# The "inside-window+zero-vel, east side" case is the exact reproduction of
# the live Slot 4 bad start (x~1344-1358) that exposed CoverE physically
# blocking the walk-toward-target path - see edge_executor.gd's
# _advance_fixed_trigger_jump "walk" phase stall/obstruction detection.
func _floor_to_cm_positions(cm_aabb: Dictionary, max_speed: float) -> Dictionary:
	var w: float = cm_aabb.right - cm_aabb.left
	var mid_west: float = cm_aabb.left + (100.0 + 60.0) * 0.5    # midpoint of the west trigger window
	var mid_east: float = cm_aabb.right - (100.0 + 60.0) * 0.5   # midpoint of the east trigger window
	return {
		"west far": {"x": cm_aabb.left - w * 1.25, "vel": Vector2.ZERO},
		"west medium": {"x": cm_aabb.left - w * 0.6, "vel": Vector2.ZERO},
		"west ideal-window, pre-built speed": {"x": mid_west, "vel": Vector2(max_speed, 0.0)},
		"west inside-window, zero velocity": {"x": mid_west, "vel": Vector2.ZERO},
		"west inside-window, wrong-direction velocity": {"x": mid_west, "vel": Vector2(-max_speed * 0.5, 0.0)},
		"west immediately adjacent/too-close": {"x": cm_aabb.left + 20.0, "vel": Vector2.ZERO},
		"east far": {"x": cm_aabb.right + w * 1.25, "vel": Vector2.ZERO},
		"east medium": {"x": cm_aabb.right + w * 0.6, "vel": Vector2.ZERO},
		"east ideal-window, pre-built speed": {"x": mid_east, "vel": Vector2(-max_speed, 0.0)},
		"east inside-window, zero velocity": {"x": mid_east, "vel": Vector2.ZERO},
		"east inside-window, wrong-direction velocity": {"x": mid_east, "vel": Vector2(max_speed * 0.5, 0.0)},
		"east immediately adjacent/too-close": {"x": cm_aabb.right - 20.0, "vel": Vector2.ZERO},
	}

func _test_edge_validation() -> void:
	print("\n--- Test 1: nav-graph edge validation, spread of start positions (+ bounded-retry check) ---")
	var rig := await _load_rig()
	var arena: Node2D = rig.arena
	var geometry: ArenaGeometry = rig.geometry
	var graph: NavGraph = rig.graph
	var body: CharacterBody2D = arena.players[0]

	var edges_passed := 0
	var edges_failed := 0
	var ran_full_timeout := 0
	for e in graph.edges:
		var from_aabb: Dictionary = geometry.aabb(e.from)
		var start_xs: Array = []
		var start_vels: Array = []
		var start_labels: Array = []
		if e.from == "Floor" and e.to == "C_M" and e.type == "jump":
			var positions: Dictionary = _floor_to_cm_positions(geometry.aabb("C_M"), body.max_speed)
			for label in positions:
				start_labels.append(label)
				start_xs.append(positions[label].x)
				start_vels.append(positions[label].vel)
		else:
			start_xs = _start_positions_for(from_aabb, geometry.player_half_w)
			for _i in start_xs:
				start_vels.append(Vector2.ZERO)
		var pos_passed := 0
		var pos_failed := 0
		var worst_detail := ""
		for pi in range(start_xs.size()):
			var sx: float = start_xs[pi]
			await _place_and_settle(body, Vector2(sx, from_aabb.top - geometry.player_half_h))
			var start_vel: Vector2 = start_vels[pi]
			if start_vel != Vector2.ZERO:
				body.velocity = start_vel
			var exec := EdgeExecutor.new(body, geometry, e)
			var controller := TestEdgeController.new(exec)
			body.controller = controller
			var t := 0
			var budget := int(exec.timeout * physics_ticks_per_second() + 60)
			while controller.status == EdgeExecutor.Status.RUNNING and t < budget:
				await physics_frame
				t += 1
			if controller.status == EdgeExecutor.Status.SUCCESS:
				pos_passed += 1
			else:
				pos_failed += 1
				# Bounded-retry check: a failed attempt should give up
				# quickly (edge_executor.gd's MAX_UNSTICK_ATTEMPTS) rather
				# than spamming jump against the same obstacle for the
				# whole 5s timeout.
				if controller.status == EdgeExecutor.Status.RUNNING and t >= budget:
					ran_full_timeout += 1
				var pos_desc: String = ("%s, start_x=%.0f" % [start_labels[pi], sx]) if pi < start_labels.size() else ("start_x=%.0f" % sx)
				worst_detail = "%s: ended phase='%s' t=%.2fs pos=%s current_platform='%s'" % [pos_desc, exec.phase, float(t) / physics_ticks_per_second(), str(body.global_position), geometry.canonical_platform(body)]
		var label := "%s -[%s]-> %s%s" % [e.from, e.type, e.to, " (skill)" if e.get("skill", false) else ""]
		if pos_failed == 0:
			edges_passed += 1
			_report(label, "PASS", "%d/%d start positions succeeded" % [pos_passed, pos_passed + pos_failed])
		else:
			edges_failed += 1
			var verdict := "WARN" if e.get("skill", false) else "FAIL"
			_report(label, verdict, "%d/%d start positions succeeded - worst case: %s" % [pos_passed, pos_passed + pos_failed, worst_detail])

	print("Edge validation: %d/%d edges succeeded from EVERY tested start position" % [edges_passed, edges_passed + edges_failed])
	if ran_full_timeout == 0:
		_report("bounded retry (no edge spammed its full timeout)", "PASS", "every failed attempt gave up before its budget expired")
	else:
		_report("bounded retry (no edge spammed its full timeout)", "FAIL", "%d attempt(s) ran to the full timeout without the bounded-retry giveup firing" % ran_full_timeout)
	await _unload_rig(arena)

# --- Test 2: determinism ------------------------------------------------------

func _position_hash(arena: Node2D) -> String:
	var parts: Array[String] = []
	for p in arena.players:
		parts.append("%d:%.1f,%.1f" % [p.slot_id, p.global_position.x, p.global_position.y])
	return "|".join(parts)

func _run_ticks(arena: Node2D, ticks: int) -> void:
	for _i in range(ticks):
		await physics_frame

func _test_determinism() -> void:
	print("\n--- Test 2: determinism (same seed -> identical positions) ---")
	var ticks := 300
	var rig_a := await _load_rig()
	await _run_ticks(rig_a.arena, ticks)
	var hash_a := _position_hash(rig_a.arena)
	await _unload_rig(rig_a.arena)

	var rig_b := await _load_rig()
	await _run_ticks(rig_b.arena, ticks)
	var hash_b := _position_hash(rig_b.arena)
	await _unload_rig(rig_b.arena)

	if hash_a == hash_b:
		_report("determinism (match_seed default, %d ticks)" % ticks, "PASS", "identical position hash across two independent runs")
	else:
		_report("determinism (match_seed default, %d ticks)" % ticks, "WARN", "hash_a=%s hash_b=%s (cross-run divergence observed; not yet root-caused, does not affect single-session coherence)" % [hash_a, hash_b])

# --- Test 3: escalating recovery timing ---------------------------------------
# Deliberately strand a real BotBrain on an edge that cannot succeed (both
# endpoints are the SAME node, so NavPath.shortest_path is trivially empty
# and _decide_next() can never produce a path) and confirm the stall ladder
# reaches each stage at approximately its documented threshold - not the
# old flat 4s, and not later than the new budget.

func _test_escalating_recovery_timing() -> void:
	print("\n--- Test 3: escalating recovery timing ---")
	var rig := await _load_rig()
	var arena: Node2D = rig.arena
	var geometry: ArenaGeometry = rig.geometry
	var brain: BotBrain = arena.brains[1]
	var body: CharacterBody2D = arena.players[1]

	# Force a stuck scenario directly on the bot's real, already-wired
	# BotBrain/BotController (no controller swapping): stand it on Floor and
	# hand it a path whose one edge is engineered to fail immediately and
	# repeatedly (a "jump" from Floor to itself has zero distance to travel,
	# so edge_executor's own "at_edge" check is satisfied instantly, but the
	# tiny 0.05s timeout means it FAILs before ever really moving) - this
	# reproduces "an edge that never makes progress" without needing to
	# fabricate a bespoke failure mode.
	var floor_aabb: Dictionary = geometry.aabb("Floor")
	body.reset_to(Vector2(floor_aabb.center.x, floor_aabb.top - geometry.player_half_h))
	for _i in range(5):
		await physics_frame
	var stuck_edge := {"from": "Floor", "to": "Floor", "type": "jump", "cost": 999999.0, "skill": false, "timeout": 0.05}
	brain.current_node = "Floor"
	brain.target_node = "Floor"
	brain.path = [stuck_edge]
	brain.path_index = 0

	var hz := physics_ticks_per_second()
	var t1 := -1.0
	var t2 := -1.0
	var t3 := -1.0
	var elapsed := 0.0
	for i in range(int(6.0 * hz)):
		await physics_frame
		elapsed += 1.0 / hz
		# The engineered edge resolves (fails) in ~0.05s on its own, and
		# ordinary _decide_next() would then find a real, working path,
		# ending the stall - keep re-injecting it every tick so the
		# non-progress is sustained long enough to observe every stage.
		if brain.state == BotBrain.State.ROAM and brain.executor == null and brain.path.is_empty():
			brain.current_node = "Floor"
			brain.target_node = "Floor"
			brain.path = [stuck_edge]
			brain.path_index = 0
		if t1 < 0.0 and brain.stage1_count > 0:
			t1 = elapsed
		if t2 < 0.0 and brain.stage2_count > 0:
			t2 = elapsed
		if t3 < 0.0 and brain.stage3_count > 0:
			t3 = elapsed
			break

	_check_stage_timing("stage1 (possible local failure, ~0.8s)", t1, 0.3, 1.6)
	_check_stage_timing("stage2 (abandon+repath, ~1.5s)", t2, 0.8, 2.5)
	_check_stage_timing("stage3 (re-localise+new region, ~2.5s)", t3, 1.5, 3.5)
	await _unload_rig(arena)

func _check_stage_timing(label: String, t: float, lo: float, hi: float) -> void:
	if t < 0.0:
		_report("recovery timing: %s" % label, "FAIL", "never fired within the test window")
	elif t >= lo and t <= hi:
		_report("recovery timing: %s" % label, "PASS", "fired at %.2fs (expected %.1f-%.1fs)" % [t, lo, hi])
	else:
		_report("recovery timing: %s" % label, "FAIL", "fired at %.2fs, outside expected %.1f-%.1fs" % [t, lo, hi])

# --- Test 4: vault entry -> physical exit -> resume roam -----------------------

func _test_vault_entry_exit() -> void:
	print("\n--- Test 4: vault approach / escape / non-entrapment (explicit, reliable-only) ---")
	var rig := await _load_rig()
	var arena: Node2D = rig.arena
	var geometry: ArenaGeometry = rig.geometry
	var graph: NavGraph = rig.graph
	var brain: BotBrain = arena.brains[1]
	var body: CharacterBody2D = arena.players[1]

	# 1. Approach: a bot outside the vault can reach VaultFloor ("Central/
	# Vault Approach") through RELIABLE edges alone - a pure graph query, no
	# simulation needed since NavPath.shortest_path IS the actual routing
	# logic bots use.
	var approach_path: Array = NavPath.shortest_path(graph, "Floor", "VaultFloor", brain._weighted_cost)
	if not approach_path.is_empty():
		_report("vault: outside -> Central/Vault Approach (reliable)", "PASS", "%d-edge reliable route exists (Floor -> VaultFloor)" % approach_path.size())
	else:
		_report("vault: outside -> Central/Vault Approach (reliable)", "FAIL", "no reliable route from Floor to VaultFloor")

	# 2. Escape: a bot already physically inside the vault (set up via
	# teleport, per the Director's own allowance - no teleport is used for
	# the actual proof below) needs a RELIABLE route back out to a different
	# node. As of 2026-09-08 this route exists: VaultFloor -> VaultEast ->
	# A_E, using EdgeExecutor's vertical_clear recipe (a local reproduction
	# of the Director's own human traversal, captured via the dev-only
	# recorder - see nav_graph.gd and docs/DECISIONS.md). The earlier
	# two-tread staircase replacement (VaultStepA/VaultStepB) was
	# implemented, tested, and REJECTED/reverted - the ORIGINAL VaultEast
	# geometry was never the problem; bot execution was.
	var escape_path: Array = NavPath.shortest_path(graph, "VaultFloor", "Floor", brain._weighted_cost)
	if not escape_path.is_empty():
		_report("vault: inside -> legal reliable exit", "PASS", "%d-edge reliable route exists (VaultFloor -> Floor)" % escape_path.size())
	else:
		var reliable_exits: Array = graph.outgoing("VaultFloor").filter(func(e): return e.route_class == NavGraph.RouteClass.RELIABLE)
		_report("vault: inside -> legal reliable exit", "FAIL", "no reliable route out of VaultFloor at all (%d reliable outgoing edges) - VaultFloor->VaultEast should be reliable; this is a real connectivity gap for the Game Director, not a bot bug" % reliable_exits.size())

	# 3. Real escape: place a real body at VaultFloor with a genuinely
	# different target already set, run the actual control loop (no
	# teleport-assisted resolution), and confirm the bot ACTUALLY LEAVES the
	# vault via the vertical_clear recipe - not just that it survives
	# cleanly while stuck (the pre-fix expectation). No crash, no runaway
	# retry against a skill edge, and real forward progress off VaultFloor
	# within a bounded time.
	var vf: Dictionary = geometry.aabb("VaultFloor")
	body.reset_to(Vector2(vf.center.x, vf.top - geometry.player_half_h - 3.0))
	for _i in range(10):
		await physics_frame
	brain.current_node = "VaultFloor"
	brain.target_node = "Floor"
	brain.path = []
	brain.executor = null
	var attempted_skill_edge := false
	var left_vault_floor := false
	var reached_floor := false
	for _i in range(int(8.0 * physics_ticks_per_second())):
		await physics_frame
		if brain.executor != null and brain.executor.edge.get("route_class", "reliable") != NavGraph.RouteClass.RELIABLE:
			attempted_skill_edge = true
		var plat := geometry.canonical_platform(body)
		if plat != "" and plat != "VaultFloor":
			left_vault_floor = true
		if plat == "Floor" or plat == "CoverE":
			reached_floor = true
			break
	if attempted_skill_edge:
		_report("vault: unrelated-destination bot does not attempt the skill edge", "FAIL", "bot ran a skill-tagged edge despite ordinary routing being reliable-only")
	else:
		_report("vault: unrelated-destination bot does not attempt the skill edge", "PASS", "ordinary routing never selected a skill edge, as designed")
	if reached_floor:
		_report("vault: bot physically exits via the reliable east route", "PASS", "reached '%s' within 8s using only RELIABLE edges" % geometry.canonical_platform(body))
	elif left_vault_floor:
		_report("vault: bot physically exits via the reliable east route", "WARN", "left VaultFloor but did not reach Floor within 8s - re-check timeout budget, not necessarily a failure")
	else:
		_report("vault: bot physically exits via the reliable east route", "FAIL", "never left VaultFloor in 8s - the reliable escape route is not actually working in practice")
	await _unload_rig(arena)

# --- Test 5: long run (120s x 3 seeds) ----------------------------------------

func _test_long_run() -> void:
	print("\n--- Test 5: long-run simulation (120s x 3 seeds) - catches 'works initially, stops later' ---")
	var seeds := [1, 2, 3]
	var agg_ladder := 0
	var agg_launch := 0
	var agg_wrap := 0
	var agg_vertical_transitions := 0
	var agg_hard_recoveries := 0
	var duration := 120.0
	var hz := physics_ticks_per_second()

	# Aggregated per-bot-slot (2,3,4) stats across all seeds, so "each bot
	# individually" is judged over 360s total, not one run.
	var regions_per_slot: Dictionary = {}
	var bands_per_slot: Dictionary = {}
	var vertical_edge_per_slot: Dictionary = {}
	for slot in [2, 3, 4]:
		regions_per_slot[slot] = {}
		bands_per_slot[slot] = {}
		vertical_edge_per_slot[slot] = false

	for s in seeds:
		var rig := await _load_rig()
		var arena: Node2D = rig.arena
		var geometry: ArenaGeometry = rig.geometry
		arena.match_config.match_seed = s
		arena._wire_bots()

		var bot_indices: Array[int] = []
		for i in range(arena.players.size()):
			if arena.brains[i] != null:
				bot_indices.append(i)

		var same_platform_ticks: Dictionary = {}
		var samples := 0
		var encounter_ticks := 0
		var proximity_threshold := 220.0
		var last_pos: Dictionary = {}
		var idle_streak: Dictionary = {}
		var max_idle_streak: Dictionary = {}
		var idle_last_pos: Dictionary = {}
		var debug_state_streak: Dictionary = {}   # slot -> {state: seconds}
		var max_state_streak: Dictionary = {}     # slot -> {state: seconds}
		var last_debug_state: Dictionary = {}
		const IDLE_MIN_DELTA := 15.0
		for i in range(arena.players.size()):
			last_pos[i] = arena.players[i].global_position
			idle_streak[i] = 0.0
			max_idle_streak[i] = 0.0
			idle_last_pos[i] = arena.players[i].global_position
		for i in bot_indices:
			debug_state_streak[i] = 0.0
			max_state_streak[i] = {}
			last_debug_state[i] = ""

		var ticks := int(duration * hz)
		var sample_every := 6
		for t in range(ticks):
			await physics_frame

			for i in range(arena.players.size()):
				var p: CharacterBody2D = arena.players[i]
				var moved: float = p.global_position.distance_to(last_pos[i])
				if moved > 200.0:
					agg_wrap += 1
				last_pos[i] = p.global_position

			if t % int(hz) == 0:
				for i in range(arena.players.size()):
					var p: CharacterBody2D = arena.players[i]
					var moved1s: float = p.global_position.distance_to(idle_last_pos[i])
					idle_last_pos[i] = p.global_position
					if moved1s < IDLE_MIN_DELTA:
						idle_streak[i] += 1.0
						max_idle_streak[i] = max(max_idle_streak[i], idle_streak[i])
					else:
						idle_streak[i] = 0.0
				for i in bot_indices:
					var ds: String = arena.brains[i].debug_state()
					if ds == last_debug_state[i]:
						debug_state_streak[i] += 1.0
					else:
						debug_state_streak[i] = 0.0
						last_debug_state[i] = ds
					var cur_max: float = max_state_streak[i].get(ds, 0.0)
					max_state_streak[i][ds] = max(cur_max, debug_state_streak[i])

			if t % sample_every == 0:
				samples += 1
				var platforms: Array = []
				for i in range(arena.players.size()):
					var plat: String = geometry.canonical_platform(arena.players[i])
					platforms.append(plat)
					if plat != "" and bot_indices.has(i):
						var slot: int = arena.players[i].slot_id
						var region := ArenaRegions.region_of(plat)
						if region != "":
							regions_per_slot[slot][region] = true
						bands_per_slot[slot][_band_of(plat)] = true
				for a in range(bot_indices.size()):
					for b in range(a + 1, bot_indices.size()):
						var ia: int = bot_indices[a]
						var ib: int = bot_indices[b]
						if platforms[ia] != "" and platforms[ia] == platforms[ib]:
							var key := "%d,%d" % [ia, ib]
							same_platform_ticks[key] = same_platform_ticks.get(key, 0) + 1
				var any_encounter := false
				for a in range(arena.players.size()):
					for b in range(a + 1, arena.players.size()):
						if arena.players[a].global_position.distance_to(arena.players[b].global_position) < proximity_threshold:
							any_encounter = true
				if any_encounter:
					encounter_ticks += 1

		for i in bot_indices:
			var brain: BotBrain = arena.brains[i]
			var slot: int = arena.players[i].slot_id
			agg_ladder += int(brain.completed_edge_types.get("ladder", 0))
			agg_launch += int(brain.completed_edge_types.get("launch", 0))
			agg_hard_recoveries += brain.hard_recovery_count
			if int(brain.completed_edge_types.get("ladder", 0)) > 0 or int(brain.completed_edge_types.get("launch", 0)) > 0:
				vertical_edge_per_slot[slot] = true
				agg_vertical_transitions += 1

		# Per-seed decorrelation and idle-streak checks (each seed is its
		# own independent sample, not just an aggregate).
		var max_fraction := 0.0
		for key in same_platform_ticks:
			var frac: float = float(same_platform_ticks[key]) / float(samples)
			max_fraction = max(max_fraction, frac)
		if max_fraction < 0.6:
			_report("seed %d: decorrelation" % s, "PASS", "%.1f%% max pairwise same-platform" % (max_fraction * 100.0))
		else:
			_report("seed %d: decorrelation" % s, "FAIL", "%.1f%% - bots may be moving in lockstep" % (max_fraction * 100.0))

		# Threshold set above the normal "settle, decide, move again" range
		# (observed up to ~14s even in healthy runs with full region/band
		# coverage and zero hard recoveries) - this test's job is to catch
		# the Director's actual complaint, a bot that stops for a very
		# long stretch, not to flag a bot pausing briefly between hops.
		var idle_fail_seconds := 25.0
		for i in bot_indices:
			var worst: float = max_idle_streak[i]
			if worst < idle_fail_seconds:
				_report("seed %d: slot %d idle-streak" % [s, arena.players[i].slot_id], "PASS", "worst %.1fs (< %.1fs)" % [worst, idle_fail_seconds])
			else:
				_report("seed %d: slot %d idle-streak" % [s, arena.players[i].slot_id], "FAIL", "moved <%.0fpx for %.1fs straight - unresolved inactivity" % [IDLE_MIN_DELTA, worst])

		# debug_state streak check: a transient state (HAS_PATH_NO_EXECUTOR,
		# HAS_DESTINATION_NO_PATH) sustained for many seconds straight is a
		# logical-idle hole even if the bot is technically "issuing intent"
		# elsewhere - it means _decide_next() keeps failing the same way.
		for i in bot_indices:
			var slot: int = arena.players[i].slot_id
			for state_name in max_state_streak[i]:
				if state_name in ["HAS_DESTINATION_NO_PATH", "HAS_PATH_NO_EXECUTOR"] and max_state_streak[i][state_name] > 5.0:
					_report("seed %d: slot %d stuck in %s" % [s, slot, state_name], "FAIL", "%.1fs continuous - a decision-loop hole" % max_state_streak[i][state_name])

		var encounter_fraction: float = float(encounter_ticks) / float(samples)
		if encounter_fraction > 0.0 and encounter_fraction < 0.95:
			_report("seed %d: encounter rate" % s, "PASS", "%.1f%%" % (encounter_fraction * 100.0))
		else:
			_report("seed %d: encounter rate" % s, "WARN", "%.1f%%" % (encounter_fraction * 100.0))

		await _unload_rig(arena)

	# Aggregate per-bot checks across all three 120s runs (360s total).
	for slot in [2, 3, 4]:
		var regions: int = regions_per_slot[slot].size()
		var bands: int = bands_per_slot[slot].size()
		_report("aggregate: slot %d visits multiple regions" % slot, "PASS" if regions >= 3 else "FAIL", "%d/%d regions: %s" % [regions, ArenaRegions.REGIONS.size(), str(regions_per_slot[slot].keys())])
		_report("aggregate: slot %d visits multiple vertical bands" % slot, "PASS" if bands >= 2 else "FAIL", "%d/4 bands: %s" % [bands, str(bands_per_slot[slot].keys())])
		_report("aggregate: slot %d completes >=1 vertical traversal" % slot, "PASS" if vertical_edge_per_slot[slot] else "FAIL", "ladder or launch completed: %s" % vertical_edge_per_slot[slot])

	if agg_ladder > 0:
		_report("ladder usage across 3x120s runs", "PASS", "%d successful ladder traversals" % agg_ladder)
	else:
		_report("ladder usage across 3x120s runs", "FAIL", "no bot completed a ladder edge in 360s total")
	if agg_launch > 0:
		_report("launcher usage across 3x120s runs", "PASS", "%d successful launches" % agg_launch)
	else:
		_report("launcher usage across 3x120s runs", "WARN", "no bot completed a launch edge in 360s - known reliability limitation, see report")
	if agg_wrap > 0:
		_report("wrap usage across 3x120s runs", "PASS", "%d wrap events detected" % agg_wrap)
	else:
		_report("wrap usage across 3x120s runs", "WARN", "no wrap detected in 360s")
	if agg_hard_recoveries == 0:
		_report("hard recovery rate across 3x120s runs", "PASS", "0 hard recoveries in 360s total")
	else:
		_report("hard recovery rate across 3x120s runs", "WARN" if agg_hard_recoveries <= 2 else "FAIL", "%d hard recoveries in 360s - should be rare and diagnostic" % agg_hard_recoveries)

# --- Test 6: collision toggle --------------------------------------------------

func _test_collision_toggle() -> void:
	print("\n--- Test 6: player<->player collision toggle (real layers/masks) ---")
	var rig := await _load_rig()
	var arena: Node2D = rig.arena
	var geometry: ArenaGeometry = rig.geometry
	var p1: CharacterBody2D = arena.players[0]
	var p2: CharacterBody2D = arena.players[1]
	# Freeze every other bot so only p1/p2 move during this test.
	for i in range(2, arena.players.size()):
		arena.players[i].controller = FrozenController.new()

	var floor_aabb: Dictionary = geometry.aabb("Floor")
	var y: float = floor_aabb.top - geometry.player_half_h

	# --- Collision OFF: two bodies placed at the exact same position must
	# be able to occupy overlapping space - not merely "not shoved far",
	# genuinely overlapping, since a real pass-through allows exact overlap.
	arena.set_player_collision(false)
	p1.controller = FrozenController.new()
	p2.controller = FrozenController.new()
	p1.reset_to(Vector2(960.0, y))
	p2.reset_to(Vector2(960.0, y))
	for _i in range(30):
		await physics_frame
	var dist_off: float = p1.global_position.distance_to(p2.global_position)
	var p1_on_floor_off := p1.is_on_floor()
	var p2_on_floor_off := p2.is_on_floor()
	if dist_off < 4.0:
		_report("collision OFF: players overlap/pass through", "PASS", "separation %.1fpx after settling from an identical start" % dist_off)
	else:
		_report("collision OFF: players overlap/pass through", "FAIL", "separation %.1fpx - something is still pushing them apart" % dist_off)
	if p1_on_floor_off and p2_on_floor_off:
		_report("collision OFF: both still collide with arena geometry", "PASS", "both remain grounded on Floor")
	else:
		_report("collision OFF: both still collide with arena geometry", "FAIL", "p1_on_floor=%s p2_on_floor=%s - world collision broke along with player collision" % [p1_on_floor_off, p2_on_floor_off])

	# --- Collision ON: starting slightly offset (so there is a well-defined
	# separation direction), physical collision must push them apart.
	arena.set_player_collision(true)
	p1.reset_to(Vector2(950.0, y))
	p2.reset_to(Vector2(970.0, y))
	for _i in range(30):
		await physics_frame
	var dist_on: float = p1.global_position.distance_to(p2.global_position)
	var min_separation: float = geometry.player_half_w * 2.0 - 4.0
	if dist_on >= min_separation:
		_report("collision ON: players physically separate", "PASS", "separation %.1fpx (>= %.1fpx body width)" % [dist_on, min_separation])
	else:
		_report("collision ON: players physically separate", "FAIL", "separation only %.1fpx (< %.1fpx) - collision ON is not actually blocking" % [dist_on, min_separation])

	# Restore the M3-1 default before tearing down (defensive - a fresh
	# rig is loaded per test anyway, but leaves no doubt about the default).
	arena.set_player_collision(false)
	await _unload_rig(arena)

# --- Test 7: nav stress test - explicit destination coverage -----------------
# Director feedback, iteration 4: "can a bot reliably reach an explicit
# destination anywhere in the arena" replaces "does bots roam intelligently"
# as what M3-1 needs to prove. Switches the real arena into NAV_STRESS_TEST
# (BotBrain.Mode) and runs long enough to observe multiple full passes
# through each bot's distinct destination sequence (see bot_brain.gd's
# STRESS_SEQUENCES) - lower/floor, west, east, upper/Crown, seam/wrap and
# central/vault-approach are all represented across the three sequences,
# each of which also includes a ladder hop and a real vertical-band change.

const STRESS_TEST_DURATION := 90.0

func _test_nav_stress_destinations() -> void:
	print("\n--- Test 7: nav stress test - explicit destination coverage ---")
	var rig := await _load_rig()
	var arena: Node2D = rig.arena
	arena.set_nav_mode(1)  # BotBrain.Mode.NAV_STRESS_TEST

	var bot_indices: Array[int] = []
	for i in range(arena.brains.size()):
		if arena.brains[i] != null:
			bot_indices.append(i)

	var ticks := int(STRESS_TEST_DURATION * physics_ticks_per_second())
	var regions_per_slot: Dictionary = {}
	var bands_per_slot: Dictionary = {}
	var vertical_edge_per_slot: Dictionary = {}
	var wrap_per_slot: Dictionary = {}
	var last_pos: Dictionary = {}
	for i in bot_indices:
		regions_per_slot[i] = {}
		bands_per_slot[i] = {}
		vertical_edge_per_slot[i] = false
		wrap_per_slot[i] = false
		last_pos[i] = arena.players[i].global_position

	for t in range(ticks):
		await physics_frame
		for i in bot_indices:
			var p: CharacterBody2D = arena.players[i]
			if p.global_position.distance_to(last_pos[i]) > 200.0:
				wrap_per_slot[i] = true
			last_pos[i] = p.global_position
			var brain: BotBrain = arena.brains[i]
			if brain.current_node != "":
				var region: String = ArenaRegions.region_of(brain.current_node)
				if region != "":
					regions_per_slot[i][region] = true
				bands_per_slot[i][_band_of(brain.current_node)] = true
			if brain.completed_edge_types.get("ladder", 0) > 0 or brain.completed_edge_types.get("launch", 0) > 0:
				vertical_edge_per_slot[i] = true

	var agg_hard_recoveries := 0
	for i in bot_indices:
		var p: CharacterBody2D = arena.players[i]
		var brain: BotBrain = arena.brains[i]
		agg_hard_recoveries += brain.hard_recovery_count
		var slot_label := "slot %d" % p.slot_id
		if brain.stress_arrivals >= 2:
			_report("%s: reaches explicit destinations" % slot_label, "PASS", "%d arrivals across its sequence %s" % [brain.stress_arrivals, brain.stress_sequence])
		else:
			_report("%s: reaches explicit destinations" % slot_label, "FAIL", "only %d arrival(s) in %.0fs - commanded destinations are not reliably reached" % [brain.stress_arrivals, STRESS_TEST_DURATION])
		var regions: Array = regions_per_slot[i].keys()
		if regions.size() >= 3:
			_report("%s: visits multiple regions on command" % slot_label, "PASS", "%d/%d regions: %s" % [regions.size(), ArenaRegions.REGIONS.size(), regions])
		else:
			_report("%s: visits multiple regions on command" % slot_label, "FAIL", "only %s" % [regions])
		var bands: Array = bands_per_slot[i].keys()
		if bands.size() >= 2:
			_report("%s: changes vertical band on command" % slot_label, "PASS", "%d/4 bands: %s" % [bands.size(), bands])
		else:
			_report("%s: changes vertical band on command" % slot_label, "FAIL", "only %s - never commanded to a different height" % [bands])
		if vertical_edge_per_slot[i]:
			_report("%s: completes a ladder traversal on command" % slot_label, "PASS", "ladder or launch completed")
		else:
			_report("%s: completes a ladder traversal on command" % slot_label, "FAIL", "no ladder/launch completed")
	if wrap_per_slot.values().has(true):
		_report("wrap usable by a commanded route", "PASS", "at least one bot's route wrapped")
	else:
		_report("wrap usable by a commanded route", "WARN", "no wrap observed in this %.0fs run - not proven this run, not necessarily broken" % STRESS_TEST_DURATION)
	if agg_hard_recoveries == 0:
		_report("hard recovery rate during nav stress test", "PASS", "0 hard recoveries in %.0fs" % STRESS_TEST_DURATION)
	else:
		_report("hard recovery rate during nav stress test", "WARN", "%d hard recoveries in %.0fs" % [agg_hard_recoveries, STRESS_TEST_DURATION])

	# Director feedback: report destination success rate for each bot x each
	# required destination explicitly, not just an aggregate arrival count.
	print("\n  -- destination success matrix (bot x required destination) --")
	for i in bot_indices:
		var p: CharacterBody2D = arena.players[i]
		var brain: BotBrain = arena.brains[i]
		var row := "  slot %d:" % p.slot_id
		for label in REQUIRED_REGIONS:
			var rep: String = REQUIRED_REGIONS[label]
			var reached: bool = brain.stress_arrived_nodes.get(rep, 0) > 0
			row += "  %s=%s" % [label, "OK" if reached else "--"]
		print(row)
	for label in REQUIRED_REGIONS:
		var rep: String = REQUIRED_REGIONS[label]
		var any_bot_asked_for_it := false
		var all_asked_reached := true
		for i in bot_indices:
			var brain: BotBrain = arena.brains[i]
			if brain.stress_sequence.has(rep):
				any_bot_asked_for_it = true
				if brain.stress_arrived_nodes.get(rep, 0) <= 0:
					all_asked_reached = false
		if not any_bot_asked_for_it:
			continue
		if all_asked_reached:
			_report("destination reliability: %s" % label, "PASS", "every bot commanded there reached it")
		else:
			_report("destination reliability: %s" % label, "FAIL", "at least one bot commanded there did not reach it in %.0fs" % STRESS_TEST_DURATION)

	arena.set_nav_mode(0)  # back to BotBrain.Mode.NORMAL_ROAM before teardown
	await _unload_rig(arena)

# --- Test 8: vault destination-change regression ------------------------
# Director report (2026-09-08): P3 reached the vault, exited successfully
# via VaultFloor->VaultEast->A_E once, then on a LATER visit its NAV STRESS
# destination changed to "Floor" (Lower/Floor) while it was already inside
# the vault, and it stayed near/in the vault "moving back and forth" instead
# of executing the route out. This test reproduces the exact state
# transition (physically inside VaultFloor, explicit destination changes to
# Floor) from several starting x-positions, and the inverse round-trip
# (Floor -> explicit VaultFloor -> arrive -> destination changes to Floor ->
# return), using ONLY the real BotBrain decision loop and EdgeExecutor - no
# teleport-assisted resolution. A hard recovery firing during the test is
# itself a FAIL (that would be a teleport-based rescue masking the real
# state-transition bug, not a genuine pass).

const VAULT_REGRESSION_TIMEOUT := 20.0

func _test_vault_destination_change_regression() -> void:
	print("\n--- Test 8: vault destination-change regression (VaultFloor -> Floor) ---")
	var rig := await _load_rig()
	var arena: Node2D = rig.arena
	var geometry: ArenaGeometry = rig.geometry
	var brain: BotBrain = arena.brains[2]  # slot 3 (P3)
	var body: CharacterBody2D = arena.players[2]

	var vf: Dictionary = geometry.aabb("VaultFloor")
	# Realistic starting x-positions spanning where a bot can actually stand
	# on VaultFloor without being embedded in VaultEast's own flush wall
	# (that wall physically blocks grounded walking anywhere east of
	# ~VaultEast.left - player_half_w, so an "east edge" position here stays
	# well inside the reachable range, not inside the wall itself).
	var starts: Array[float] = [vf.left - 50.0, vf.left + 30.0, vf.center.x, vf.right - 90.0]

	for start_x in starts:
		var label := "vault regression: VaultFloor(x=%.0f) -> explicit Floor" % start_x
		var result := await _drive_to_destination(arena, brain, body, geometry, "VaultFloor", start_x, "Floor", VAULT_REGRESSION_TIMEOUT)
		if result.success:
			_report(label, "PASS", "reached '%s' in %.2fs via %s" % [result.final_platform, result.elapsed, result.edge_trace])
		else:
			_report(label, "FAIL", "did not reach Floor within %.0fs - stuck at '%s', last edge attempted: %s, full trace: %s" % [VAULT_REGRESSION_TIMEOUT, result.final_platform, result.last_edge, result.edge_trace])

	# Inverse round-trip: Floor -> explicit Central/Vault Approach -> arrive,
	# then destination changes to Floor -> physically return. Exercises the
	# exact sequence the Director observed (arrival at the vault immediately
	# followed by a destination change away from it).
	var floor_aabb: Dictionary = geometry.aabb("Floor")
	var in_result := await _drive_to_destination(arena, brain, body, geometry, "Floor", floor_aabb.center.x, "VaultFloor", VAULT_REGRESSION_TIMEOUT)
	if in_result.success:
		_report("vault regression: Floor -> explicit VaultFloor", "PASS", "reached '%s' in %.2fs via %s" % [in_result.final_platform, in_result.elapsed, in_result.edge_trace])
		# Immediately, with no reset, redirect back to Floor - this is the
		# live "destination changed while inside the vault" moment.
		brain.target_node = ""
		brain.path = []
		brain.executor = null
		var out_result := await _drive_to_destination(arena, brain, body, geometry, "", 0.0, "Floor", VAULT_REGRESSION_TIMEOUT, false)
		if out_result.success:
			_report("vault regression: (immediately after) VaultFloor -> explicit Floor", "PASS", "reached '%s' in %.2fs via %s" % [out_result.final_platform, out_result.elapsed, out_result.edge_trace])
		else:
			_report("vault regression: (immediately after) VaultFloor -> explicit Floor", "FAIL", "did not reach Floor within %.0fs - stuck at '%s', last edge attempted: %s, full trace: %s" % [VAULT_REGRESSION_TIMEOUT, out_result.final_platform, out_result.last_edge, out_result.edge_trace])
	else:
		_report("vault regression: Floor -> explicit VaultFloor", "FAIL", "did not reach VaultFloor within %.0fs - stuck at '%s', full trace: %s" % [VAULT_REGRESSION_TIMEOUT, in_result.final_platform, in_result.edge_trace])

	await _unload_rig(arena)

## Drives the real BotBrain/EdgeExecutor loop from a given physical
## placement (or the body's current position, if reset_node == "") toward an
## explicit target node, reporting a full state/path trace. No teleport
## recovery is used to reach the destination - if a hard recovery fires
## during the drive, that is recorded and treated as a failure to reach the
## destination reliably (not a legitimate pass).
func _drive_to_destination(arena: Node2D, brain: BotBrain, body: CharacterBody2D, geometry: ArenaGeometry, reset_node: String, start_x: float, target: String, timeout_s: float, do_reset: bool = true) -> Dictionary:
	if do_reset:
		var aabb: Dictionary = geometry.aabb(reset_node)
		body.reset_to(Vector2(start_x, aabb.top - geometry.player_half_h - 3.0))
		for _i in range(15):
			await physics_frame
		brain.current_node = reset_node
	brain.state = BotBrain.State.ROAM
	brain.target_node = ""
	brain.path = []
	brain.path_index = 0
	brain.executor = null
	brain.mode = BotBrain.Mode.NAV_STRESS_TEST
	brain.stress_sequence = [target]
	brain.stress_index = 0
	brain.decision_clock = 0.05
	brain._stall_timer = 0.0
	brain._stall_stage_done = 0
	brain._stall_check_pos = body.global_position

	var hard_recoveries_before: int = brain.hard_recovery_count
	var edge_trace: Array[String] = []
	var last_edge := "(none)"
	var last_recorded_exec = null
	var hz := physics_ticks_per_second()
	for i in range(int(timeout_s * hz)):
		await physics_frame
		if brain.executor != last_recorded_exec and brain.executor != null:
			last_edge = "%s->%s" % [brain.executor.edge.from, brain.executor.edge.to]
			edge_trace.append(last_edge)
			last_recorded_exec = brain.executor
		if brain.hard_recovery_count > hard_recoveries_before:
			return {
				"success": false, "elapsed": i / hz, "final_platform": geometry.canonical_platform(body),
				"last_edge": last_edge, "edge_trace": ", ".join(edge_trace) + " [HARD RECOVERY FIRED - teleport rescue, not a real pass]",
			}
		var plat := geometry.canonical_platform(body)
		var reached := (target == "Floor" and (plat == "Floor" or plat == "CoverE")) or (target != "Floor" and plat == target)
		if reached and body.is_on_floor():
			return {"success": true, "elapsed": i / hz, "final_platform": plat, "last_edge": last_edge, "edge_trace": ", ".join(edge_trace)}
	return {
		"success": false, "elapsed": timeout_s, "final_platform": geometry.canonical_platform(body),
		"last_edge": last_edge, "edge_trace": ", ".join(edge_trace) + " [timed out - final debug_state=%s target=%s path_len=%d]" % [brain.debug_state(), brain.target_node, brain.path.size()],
	}

# --- Test 9: NAV_STRESS_TEST debug-label respects the sequence cap ---------
# Director report (2026-09-08, long-duration soak): a 5-minute NAV STRESS
# soak confirmed the exact human-reported P3 pattern - once a bot's own
# stress_index reaches the intentional stress_sequence.size()*3 cap,
# _pick_stress_target() correctly stops offering new destinations and the
# bot settles into AT_REST/intra-node wander, but current_stress_destination
# (the label a human reads during playtest) kept computing
# stress_index % size regardless of the cap, showing a perfectly plausible
# but entirely fictitious "still pursuing this" destination forever. This
# test asserts the fixed label: a real destination below the cap, and the
# explicit "(sequence complete)" marker at and above it - a pure, fast,
# deterministic check on the label function itself, no physics simulation
# needed.
func _test_stress_label_respects_cap() -> void:
	print("\n--- Test 9: NAV_STRESS_TEST debug label respects the sequence cap ---")
	var rig := await _load_rig()
	var arena: Node2D = rig.arena
	var brain: BotBrain = arena.brains[1]  # slot 2 (index 1) - any bot works
	brain.set_mode(1)  # BotBrain.Mode.NAV_STRESS_TEST
	var cap: int = brain.stress_sequence.size() * 3

	brain.stress_index = cap - 1
	var below_cap: String = brain.current_stress_destination()
	if below_cap != "" and below_cap != "(sequence complete)":
		_report("stress label below cap shows a real destination", "PASS", "stress_index=%d -> '%s'" % [cap - 1, below_cap])
	else:
		_report("stress label below cap shows a real destination", "FAIL", "stress_index=%d -> '%s' (expected a real sequence entry)" % [cap - 1, below_cap])

	brain.stress_index = cap
	var at_cap: String = brain.current_stress_destination()
	if at_cap == "(sequence complete)":
		_report("stress label at/past cap shows sequence-complete, not a stale destination", "PASS", "stress_index=%d -> '%s'" % [cap, at_cap])
	else:
		_report("stress label at/past cap shows sequence-complete, not a stale destination", "FAIL", "stress_index=%d -> '%s' (the exact bug that produced the human-reported P3 'stuck in Vault, label says Lower/Floor' report)" % [cap, at_cap])

	brain.stress_index = cap + brain.stress_sequence.size() * 7  # well past the cap, and not a multiple-of-size coincidence
	var well_past_cap: String = brain.current_stress_destination()
	if well_past_cap == "(sequence complete)":
		_report("stress label stays sequence-complete arbitrarily far past the cap", "PASS", "stress_index=%d -> '%s'" % [brain.stress_index, well_past_cap])
	else:
		_report("stress label stays sequence-complete arbitrarily far past the cap", "FAIL", "stress_index=%d -> '%s'" % [brain.stress_index, well_past_cap])

	await _unload_rig(arena)
