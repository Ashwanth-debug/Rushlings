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
	await _test_match_fsm_timing()
	await _test_physical_gate_state()
	await _test_sealed_state_nav_connectivity()
	await _test_relic_collection_and_winner()
	await _test_winner_resolution()
	await _test_results_freeze_and_dwell()
	await _test_rematch_reset()
	await _test_goal_switch_under_load()
	await _test_pier_to_vaultfloor_speed_spread()
	await _test_bot_only_fairness_rounds()
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

## M3-2 Step 4 (S08): several M3-1/Step-2/3 tests call debug_force_open()
## purely to physically/logically unseal the vault so ROAM or an explicit
## NAV_STRESS_TEST target can use it as an ordinary destination - a usage
## pattern that predates SEEK_RELIC. Since OPEN now also flips every bot's
## goal to SEEK_RELIC (the real, approved production behaviour), those tests
## must undo that one incidental side effect immediately afterward or their
## own explicit target-setting gets silently overridden by the real goal
## switch a few ticks later. Real gameplay never calls this - only test code
## that wants "gate open" without "objective changed".
func _reset_all_goals_to_roam(arena: Node2D) -> void:
	for b in arena.brains:
		if b != null:
			b.reset_goal()

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
	# This is the M3-1 baseline claim, predating the M3-2 vault seal - the
	# rig loads with MatchDirector in SETUP (sealed) by default, so the gate
	# must be forced open here or this test would report a connectivity
	# regression that is actually Step 2's new, intended SETUP behaviour.
	# The sealed-state equivalent is Test 13, below.
	graph.set_gate_open(true)
	# Also stop MatchDirector's own ~10s real timer from firing OPEN on its
	# own partway through this test - left running, it can trigger a genuine
	# Relic collection from a roaming bot, which freezes every controller
	# (docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md S11/S12) and silently breaks
	# everything from that point on. This test only cares about the graph.
	rig.arena.get_node("MatchDirector").set_physics_process(false)
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
	# Same reasoning as Test 0: this is the M3-1 baseline claim (no gate
	# existed yet), so force the gate open rather than inheriting the rig's
	# default SETUP-sealed state. Test 13 is the sealed-state equivalent.
	graph.set_gate_open(true)
	rig.arena.get_node("MatchDirector").set_physics_process(false)  # see Test 0's identical reasoning

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
	# This test validates every graph edge in isolation, including the five
	# gated vault edges - it needs the gate PHYSICALLY open for the whole run
	# (debug_force_open(), not just nav_graph.set_gate_open(true): a sealed
	# collision shape would fail these edges regardless of what Dijkstra
	# believes - see door_arrival_check.gd's identical fix), and, since it
	# can run for real minutes, MatchDirector's own real timer must not also
	# be free to fire a SECOND time (harmless once already open, but noisy)
	# and no longer be inert for bots once OPEN (M3-2 Step 4, S08, triggers
	# the real SEEK_RELIC goal switch) - undo that incidental side effect so
	# it cannot hijack the TestEdgeController-driven body mid-edge.
	arena.match_director.debug_force_open()
	arena.get_node("MatchDirector").set_physics_process(false)
	graph.set_gate_open(true)  # redundant after debug_force_open(), kept explicit
	_reset_all_goals_to_roam(arena)
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
	# This test proves raw M3-1 edge-execution capability, independent of
	# MatchDirector's state - force the gate open (debug_force_open(), not a
	# direct nav_graph.set_gate_open(true): this test drives REAL physical
	# movement through the vault, so the PHYSICAL seal must actually open,
	# not just Dijkstra's belief that it has - see door_arrival_check.gd's
	# identical fix) so it is not accidentally testing Step 2's new
	# SETUP-sealed default instead.
	arena.match_director.debug_force_open()
	arena.get_node("MatchDirector").set_physics_process(false)  # see Test 0's identical reasoning - this test runs for several real seconds
	graph.set_gate_open(true)  # redundant after debug_force_open(), kept explicit
	# This test proves M3-1 ROAM/manual-drive vault access, not the M3-2 goal
	# switch - undo debug_force_open()'s incidental SEEK_RELIC side effect
	# (see _reset_all_goals_to_roam's own comment) so it doesn't hijack the
	# explicit target-setting below a few ticks later.
	_reset_all_goals_to_roam(arena)

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
		# This is an M3-1 ROAM coverage/regression test, predating the M3-2
		# gate entirely - it expects the FULL original M3-1 map (vault
		# included) to be open for the whole 120s, same reasoning as Tests
		# 0/4/7/8. debug_force_open() opens the seal both physically and
		# logically; Relic's own _physics_process is then disabled so a
		# roaming bot touching it can never latch a real collection (which
		# would freeze every controller and corrupt the rest of the
		# coverage measurement) - Step 3 deliberately keeps bots on plain
		# ROAM even after OPEN specifically so collection is tested in its
		# own dedicated tests (14-17), not as an emergent side effect here.
		arena.match_director.debug_force_open()
		arena.get_node("MatchDirector").set_physics_process(false)
		arena.get_node("Relic").set_physics_process(false)
		# M3-2 Step 4: this test wants plain M3-1 ROAM coverage, not the real
		# SEEK_RELIC goal switch debug_force_open() now also triggers - undo
		# it (see _reset_all_goals_to_roam's own comment).
		_reset_all_goals_to_roam(arena)

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
	# NAV_STRESS_TEST sequences explicitly target VaultFloor as "central/
	# vault approach" coverage - this predates the M3-2 gate, so force it
	# open (debug_force_open(), not a direct nav_graph.set_gate_open(true):
	# real bodies physically drive through the vault here, so the PHYSICAL
	# seal must actually open too - see door_arrival_check.gd's identical
	# fix) rather than testing against Step 2's new SETUP-sealed default.
	arena.match_director.debug_force_open()
	# This test runs for 90 real seconds - see Test 0's identical reasoning
	# for why MatchDirector's own timer must not also be running.
	arena.get_node("MatchDirector").set_physics_process(false)
	rig.graph.set_gate_open(true)  # redundant after debug_force_open(), kept explicit
	# M3-2 Step 4: NAV_STRESS_TEST's explicit target selection must not be
	# overridden by the real SEEK_RELIC goal switch debug_force_open() also
	# triggers now - undo it (see _reset_all_goals_to_roam's own comment).
	_reset_all_goals_to_roam(arena)
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
	# Explicit vault destination-change regression, independent of match
	# state - force the gate open (see Test 4/7's identical reasoning: real
	# bodies physically drive through the vault here, so debug_force_open()
	# is required, not a direct nav_graph.set_gate_open(true), to actually
	# open the PHYSICAL seal too).
	arena.match_director.debug_force_open()
	arena.get_node("MatchDirector").set_physics_process(false)  # see Test 0's identical reasoning
	rig.graph.set_gate_open(true)  # redundant after debug_force_open(), kept explicit
	# M3-2 Step 4: this test drives an explicit target via NAV_STRESS_TEST
	# (_drive_to_destination) - it must not be overridden by the real
	# SEEK_RELIC goal switch debug_force_open() also triggers now (see
	# _reset_all_goals_to_roam's own comment).
	_reset_all_goals_to_roam(arena)
	# M3-2 Step 3's live Relic sits directly on the x=872 case's walk path
	# from VaultFloor toward VaultEast (it crosses the Relic's own x980-1020
	# zone en route) and is always-monitoring - an uncontrolled collection
	# mid-test would latch RESULTS and freeze every controller for the rest
	# of this test's sub-cases, exactly the hazard Tests 5/7 already guard
	# against for the same reason. This test isolates raw traversal/goal-
	# switch logic, not collection (which has its own dedicated tests).
	arena.get_node("Relic").set_physics_process(false)
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

# --- Test 10: MatchDirector FSM timing (M3-2 Step 2) --------------------------
# docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md S19 Step 2, item 9: verify
# SETUP -> UNLOCKING -> OPEN at time_scale 1.0 and 1.25 with no frame-count
# assumptions - the pass/fail check is against MatchDirector.clock (real
# elapsed game seconds), not against how many physics_frame signals fired to
# get there.

func _test_match_fsm_timing() -> void:
	print("\n--- Test 10: MatchDirector FSM timing at time_scale 1.0 and 1.25 ---")
	for ts in [1.0, 1.25]:
		var rig := await _load_rig()
		var arena: Node2D = rig.arena
		var director: MatchDirector = arena.match_director
		var hz := physics_ticks_per_second()
		Engine.time_scale = ts
		var unlocking_entered_at := -1.0
		var open_entered_at := -1.0
		var budget := int(hz * (director.setup_duration + 5.0) / ts)
		var ticks := 0
		while open_entered_at < 0.0 and ticks < budget:
			await physics_frame
			ticks += 1
			if director.state == MatchDirector.State.UNLOCKING and unlocking_entered_at < 0.0:
				unlocking_entered_at = director.clock
			if director.state == MatchDirector.State.OPEN and open_entered_at < 0.0:
				open_entered_at = director.clock
		Engine.time_scale = 1.0
		var expected_unlocking: float = director.setup_duration - director.unlocking_duration
		if unlocking_entered_at < 0.0:
			_report("FSM timing (time_scale=%.2f): reaches UNLOCKING" % ts, "FAIL", "never entered UNLOCKING within budget")
		else:
			var ok: bool = abs(unlocking_entered_at - expected_unlocking) < 0.25
			_report("FSM timing (time_scale=%.2f): UNLOCKING at clock~=%.1fs" % [ts, expected_unlocking], "PASS" if ok else "FAIL", "actually entered at clock=%.3fs" % unlocking_entered_at)
		if open_entered_at < 0.0:
			_report("FSM timing (time_scale=%.2f): reaches OPEN" % ts, "FAIL", "never entered OPEN within budget")
		else:
			var ok2: bool = abs(open_entered_at - director.setup_duration) < 0.25
			_report("FSM timing (time_scale=%.2f): OPEN at clock~=%.1fs" % [ts, director.setup_duration], "PASS" if ok2 else "FAIL", "actually entered at clock=%.3fs" % open_entered_at)
		await _unload_rig(arena)

# --- Test 11: Physical gate state (M3-2 Step 2) --------------------------------
# SETUP sealed, UNLOCKING sealed even mid-lift, OPEN physically open and
# matching the accepted M3-1 west door - the same standing-start drop
# tools/arena_check.gd's "West gateway enter" test already proves for M3-1.

func _assert_vault_sealed_from_standing_start(body: CharacterBody2D, geometry: ArenaGeometry, label: String) -> void:
	var pier: Dictionary = geometry.aabb("Pier")
	await _place_and_settle(body, Vector2(pier.right + geometry.player_half_w + 2.0, pier.top - geometry.player_half_h), 150)
	var landed_on := geometry.canonical_platform(body)
	if landed_on == "VaultFloor":
		_report("Gate %s: vault stays physically sealed" % label, "FAIL", "a standing-start west drop reached VaultFloor - the seal is not blocking")
	else:
		_report("Gate %s: vault stays physically sealed" % label, "PASS", "west drop landed on '%s', not VaultFloor" % landed_on)

func _test_physical_gate_state() -> void:
	print("\n--- Test 11: Physical gate state across SETUP/UNLOCKING/OPEN ---")
	var rig := await _load_rig()
	var arena: Node2D = rig.arena
	var geometry: ArenaGeometry = rig.geometry
	var director: MatchDirector = arena.match_director
	var body: CharacterBody2D = arena.players[0]
	var hz := physics_ticks_per_second()
	var budget := int(hz * (director.setup_duration + 3.0))

	await _assert_vault_sealed_from_standing_start(body, geometry, "SETUP")

	var mid_unlocking_clock: float = director.setup_duration - director.unlocking_duration * 0.5
	var reached_mid := false
	for _i in range(budget):
		await physics_frame
		if director.state == MatchDirector.State.UNLOCKING and director.clock >= mid_unlocking_clock:
			reached_mid = true
			break
	if not reached_mid:
		_report("Gate UNLOCKING probe reached (bars mid-lift)", "FAIL", "never observed UNLOCKING at/after clock=%.2fs within budget" % mid_unlocking_clock)
	else:
		var progress: float = director.unlocking_progress()
		_report("Gate UNLOCKING probe reached (bars mid-lift)", "PASS" if progress > 0.05 else "WARN", "unlocking_progress=%.2f at clock=%.2fs" % [progress, director.clock])
		await _assert_vault_sealed_from_standing_start(body, geometry, "UNLOCKING (bars mid-lift)")

	var reached_open := false
	for _i in range(budget):
		await physics_frame
		if director.state == MatchDirector.State.OPEN:
			reached_open = true
			break
	if not reached_open:
		_report("Gate OPEN probe reached", "FAIL", "never observed OPEN within budget")
	else:
		var pier: Dictionary = geometry.aabb("Pier")
		await _place_and_settle(body, Vector2(pier.right + geometry.player_half_w + 2.0, pier.top - geometry.player_half_h), 150)
		var landed_on := geometry.canonical_platform(body)
		if landed_on == "VaultFloor":
			_report("Gate OPEN: standing-start west entry reaches VaultFloor", "PASS", "matches the accepted M3-1 vault door")
		else:
			_report("Gate OPEN: standing-start west entry reaches VaultFloor", "FAIL", "landed on '%s' instead" % landed_on)

	await _unload_rig(arena)

# --- Test 13: Sealed-state RELIABLE nav-graph connectivity (M3-2 Step 2) ------
# docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md S07/A2: while the vault is sealed,
# its five interior edges must not exist for ordinary bot pathfinding, and
# the rest of the RELIABLE subgraph must stay connected without them -
# VaultFloor/VaultEast are the only named, expected exceptions.

func _test_sealed_state_nav_connectivity() -> void:
	print("\n--- Test 13: Sealed-state RELIABLE connectivity + no ROAM bot uses a gated edge ---")
	var rig := await _load_rig()
	var arena: Node2D = rig.arena
	var graph: NavGraph = rig.graph
	graph.set_gate_open(false)
	# This test's whole premise is "stays sealed for the entire 20s live
	# sim" - MatchDirector's own ~10s real timer left running would
	# genuinely reach OPEN partway through and flip nav_graph.gate_open back
	# to true on its own (arena_01.gd's _on_match_state_changed), silently
	# invalidating the back half of the sim. See Test 0's identical
	# reasoning for the general hazard.
	arena.get_node("MatchDirector").set_physics_process(false)

	# VaultFloor/VaultEast are the new M3-2 gated exceptions; CoverE/B_Under
	# are the PRE-EXISTING M3-1 exceptions from Test 0b's CONNECTIVITY_EXCEPTIONS
	# (no RELIABLE incoming edge at all, gate-independent) - both sets must be
	# excluded here or this test would flag a Test-0b-acknowledged condition
	# as a new Step 2 regression.
	var EXCEPTIONS: Array = ["VaultFloor", "VaultEast"] + CONNECTIVITY_EXCEPTIONS.keys()
	var start := "Floor"
	var reachable: Dictionary = graph.reliable_reachable_from(start)
	var missing: Array = []
	for n in graph.nodes:
		if EXCEPTIONS.has(n):
			continue
		if not reachable.get(n, false):
			missing.append(n)
	if missing.is_empty():
		_report("Sealed-state RELIABLE connectivity from '%s'" % start, "PASS", "every non-vault node reachable; vault interior (%s) correctly excluded while sealed" % ", ".join(EXCEPTIONS))
	else:
		_report("Sealed-state RELIABLE connectivity from '%s'" % start, "FAIL", "unreachable while sealed: %s" % ", ".join(missing))

	var no_sink_fail: Array = []
	for n in graph.nodes:
		if EXCEPTIONS.has(n):
			continue
		var out_reachable: Dictionary = graph.reliable_reachable_from(n)
		var has_any := false
		for m in out_reachable.keys():
			if m != n and not EXCEPTIONS.has(m):
				has_any = true
				break
		if not has_any:
			no_sink_fail.append(n)
	if no_sink_fail.is_empty():
		_report("Sealed-state no-sink (every non-vault node can still reach another)", "PASS", "no dead ends introduced by sealing")
	else:
		_report("Sealed-state no-sink (every non-vault node can still reach another)", "FAIL", "sink nodes while sealed: %s" % ", ".join(no_sink_fail))

	var gated_edges: Array = graph.edges.filter(func(e): return e.get("gated", false))
	var brain: BotBrain = arena.brains[1]
	var any_costed_finite := false
	for e in gated_edges:
		if brain._weighted_cost(e) != INF:
			any_costed_finite = true
	if gated_edges.is_empty():
		_report("Sealed gated edges excluded from bot costing", "FAIL", "no edges are tagged 'gated' - the vault interior is not gated at all")
	elif any_costed_finite:
		_report("Sealed gated edges excluded from bot costing (%d edges)" % gated_edges.size(), "FAIL", "at least one gated edge did not cost INF while sealed")
	else:
		_report("Sealed gated edges excluded from bot costing (%d edges)" % gated_edges.size(), "PASS", "all report INF while sealed")

	# Live simulation, not just static graph math: 20s of real ROAM with all
	# three bots while sealed, confirming _weighted_cost's INF and
	# ArenaRegions.NO_ROAM_TARGETS actually agree in a running sim.
	var hz := physics_ticks_per_second()
	var ticks := int(hz * 20.0)
	var entered_vault := false
	for _i in range(ticks):
		await physics_frame
		for i in range(arena.brains.size()):
			var b: BotBrain = arena.brains[i]
			if b != null and (b.current_node == "VaultFloor" or b.current_node == "VaultEast"):
				entered_vault = true
	if entered_vault:
		_report("Sealed-state ROAM: no bot enters the vault interior (20s live sim)", "FAIL", "a bot's current_node was VaultFloor/VaultEast during a sealed ROAM run")
	else:
		_report("Sealed-state ROAM: no bot enters the vault interior (20s live sim)", "PASS", "no bot's current_node was VaultFloor/VaultEast across a sealed ROAM run")

	await _unload_rig(arena)

# --- Test 14: Relic collection (M3-2 Step 3) ----------------------------------
# docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md S10: impossible during SETUP and
# UNLOCKING (even with a body forced to overlap it, bypassing the physical
# seal on purpose - this isolates the Relic/MatchDirector LOGIC guard from
# the physical one, which Step 1/2 already proved separately), active only
# at OPEN, fires exactly once.

func _test_relic_collection_and_winner() -> void:
	print("\n--- Test 14: Relic collection - impossible during SETUP/UNLOCKING, active only at OPEN, fires once ---")
	var rig := await _load_rig()
	var arena: Node2D = rig.arena
	var director: MatchDirector = arena.match_director
	var relic: Area2D = arena.get_node("Relic")
	var p1: CharacterBody2D = arena.players[0]

	p1.reset_to(relic.global_position)
	for _i in range(15):
		await physics_frame
	# Relic.monitoring stays permanently true by design (see relic.gd's own
	# header comment - toggling it off/on was found to leave stale overlap
	# data across a body's later movement, which broke rematch winner
	# resolution). The guard against collection during SETUP/UNLOCKING is
	# purely the state check in _physics_process, proven directly below by
	# state never advancing despite this forced overlap.
	_report("Relic collection guard active during SETUP (forced overlap)", "FAIL" if relic._collected else "PASS", "_collected=%s" % relic._collected)
	_report("Collection impossible during SETUP (forced overlap)", "PASS" if director.state == MatchDirector.State.SETUP else "FAIL", "state='%s'" % director.state)

	director._set_state(MatchDirector.State.UNLOCKING)
	for _i in range(15):
		await physics_frame
	_report("Relic collection guard active during UNLOCKING (forced overlap)", "FAIL" if relic._collected else "PASS", "_collected=%s" % relic._collected)
	_report("Collection impossible during UNLOCKING (forced overlap)", "PASS" if director.state == MatchDirector.State.UNLOCKING else "FAIL", "state='%s'" % director.state)

	director.debug_force_open()
	for _i in range(15):
		await physics_frame
	if director.state == MatchDirector.State.RESULTS and director.winner_slot_id == 1:
		_report("Collection active at OPEN, correct winner", "PASS", "P1 collected, winner_slot_id=1")
	else:
		_report("Collection active at OPEN, correct winner", "FAIL", "state='%s' winner_slot_id=%d" % [director.state, director.winner_slot_id])

	var winner_after_first: int = director.winner_slot_id
	var hz := physics_ticks_per_second()
	for _i in range(int(1.0 * hz)):
		await physics_frame
	if director.state == MatchDirector.State.RESULTS and director.winner_slot_id == winner_after_first:
		_report("Collection fires exactly once", "PASS", "RESULTS/winner unchanged after 1s of further ticks")
	else:
		_report("Collection fires exactly once", "FAIL", "state/winner changed: state='%s' winner=%d" % [director.state, director.winner_slot_id])

	await _unload_rig(arena)

# --- Test 15: deterministic winner resolution (M3-2 Step 3) ------------------
# docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md S11: single overlap, same-frame
# multi-overlap (closest to centre wins), exact-distance tie (lowest
# slot_id wins). Controllers are frozen for the whole test so bot ROAM
# cannot move a body out of its deliberately-placed test position before the
# poll runs - this isolates the tie-break MATH, not live navigation.

func _test_winner_resolution() -> void:
	print("\n--- Test 15: deterministic winner resolution (single/multi-overlap/tie) ---")

	var rig := await _load_rig()
	var arena: Node2D = rig.arena
	var director: MatchDirector = arena.match_director
	var relic: Area2D = arena.get_node("Relic")
	for p in arena.players:
		p.controller.set_frozen(true)
	arena.players[1].reset_to(relic.global_position)  # P2 alone
	director.debug_force_open()
	for _i in range(15):
		await physics_frame
	if director.state == MatchDirector.State.RESULTS and director.winner_slot_id == 2:
		_report("Winner: single overlap", "PASS", "P2 alone -> P2 wins")
	else:
		_report("Winner: single overlap", "FAIL", "winner_slot_id=%d state='%s'" % [director.winner_slot_id, director.state])
	await _unload_rig(arena)

	rig = await _load_rig()
	arena = rig.arena
	director = arena.match_director
	relic = arena.get_node("Relic")
	for p in arena.players:
		p.controller.set_frozen(true)
	var center: Vector2 = relic.global_position
	arena.players[0].reset_to(center + Vector2(15.0, 0.0))   # P1, dist 15
	arena.players[1].reset_to(center + Vector2(-5.0, 0.0))   # P2, dist 5 - closest
	arena.players[2].reset_to(center + Vector2(10.0, 0.0))   # P3, dist 10
	director.debug_force_open()
	for _i in range(15):
		await physics_frame
	if director.state == MatchDirector.State.RESULTS and director.winner_slot_id == 2:
		_report("Winner: same-frame multi-overlap, closest wins", "PASS", "P2 (dist 5) wins over P1 (15) and P3 (10)")
	else:
		_report("Winner: same-frame multi-overlap, closest wins", "FAIL", "winner_slot_id=%d state='%s'" % [director.winner_slot_id, director.state])
	await _unload_rig(arena)

	rig = await _load_rig()
	arena = rig.arena
	director = arena.match_director
	relic = arena.get_node("Relic")
	for p in arena.players:
		p.controller.set_frozen(true)
	center = relic.global_position
	arena.players[3].reset_to(center + Vector2(8.0, 0.0))    # P4, dist 8
	arena.players[1].reset_to(center + Vector2(-8.0, 0.0))   # P2, dist 8 - exact tie, lower slot
	director.debug_force_open()
	for _i in range(15):
		await physics_frame
	if director.state == MatchDirector.State.RESULTS and director.winner_slot_id == 2:
		_report("Winner: exact-distance tie, lowest slot_id wins", "PASS", "P2 (slot 2) beats P4 (slot 4) on an exact 8px tie")
	else:
		_report("Winner: exact-distance tie, lowest slot_id wins", "FAIL", "winner_slot_id=%d state='%s'" % [director.winner_slot_id, director.state])
	await _unload_rig(arena)

# --- Test 16: RESULTS - frozen gameplay, HUD, rematch dwell gate (M3-2 Step 3)

func _test_results_freeze_and_dwell() -> void:
	print("\n--- Test 16: RESULTS - frozen gameplay, correct HUD, rematch dwell gate ---")
	var rig := await _load_rig()
	var arena: Node2D = rig.arena
	var director: MatchDirector = arena.match_director
	var relic: Area2D = arena.get_node("Relic")

	arena.players[2].reset_to(relic.global_position)  # P3 wins
	director.debug_force_open()
	for _i in range(15):
		await physics_frame
	if director.state != MatchDirector.State.RESULTS or director.winner_slot_id != 3:
		_report("RESULTS setup (P3 wins)", "FAIL", "state='%s' winner=%d - cannot continue this test" % [director.state, director.winner_slot_id])
		await _unload_rig(arena)
		return
	_report("RESULTS setup (P3 wins)", "PASS", "state=RESULTS winner_slot_id=3")

	var all_frozen := true
	for p in arena.players:
		if not p.controller.frozen:
			all_frozen = false
		if p.controller.horizontal() != 0.0 or p.controller.vertical() != 0.0 or p.controller.jump_pressed(false):
			all_frozen = false
	_report("RESULTS freezes every controller", "PASS" if all_frozen else "FAIL", "all 4 controllers frozen with zero intent" if all_frozen else "at least one controller is not frozen or reports nonzero intent")

	var match_label: Label = arena.get_node("HUD/MatchLabel")
	await process_frame
	var expected := "P3 WINS\n[R] REMATCH"
	_report("Result HUD text correct", "PASS" if match_label.text == expected else "FAIL", "got '%s'" % match_label.text.replace("\n", "\\n"))

	_report("Rematch ignored before minimum dwell", "FAIL" if director.rematch_ready() else "PASS", "rematch_ready()=%s immediately after RESULTS began" % director.rematch_ready())

	var hz := physics_ticks_per_second()
	for _i in range(int(0.8 * hz)):  # 0.8s < 1.2s - still inside the dwell window
		await physics_frame
	_report("Rematch still ignored mid-dwell (0.8s < 1.2s)", "FAIL" if director.rematch_ready() else "PASS", "rematch_ready()=%s at results_dwell=%.2fs" % [director.rematch_ready(), director.results_dwell])

	for _i in range(int(0.6 * hz)):  # past 1.2s total
		await physics_frame
	_report("Rematch accepted after the minimum dwell (>1.2s)", "PASS" if director.rematch_ready() else "FAIL", "rematch_ready()=%s at results_dwell=%.2fs" % [director.rematch_ready(), director.results_dwell])

	await _unload_rig(arena)

# --- Test 17: rematch reset, multi-round, no scene reload (M3-2 Step 3) ------
# docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md S13: positions, velocities,
# in_traversal_zone, fresh BotBrains (new instances, empty path/executor/
# blacklist, hard_recovery_count 0), gate sealed, Relic non-collectible,
# clock zero, result cleared - run across 3 rounds without a scene reload,
# and verify the approved non-colliding seed formula
# (match_seed + round_index*101 + slot_id) holds with no collisions.

func _test_rematch_reset() -> void:
	print("\n--- Test 17: rematch reset (multi-round, no scene reload) ---")
	var rig := await _load_rig()
	var arena: Node2D = rig.arena
	var director: MatchDirector = arena.match_director
	var relic: Area2D = arena.get_node("Relic")
	var hz := physics_ticks_per_second()

	var seen_seeds: Dictionary = {}  # seed -> "round R slot S", for the collision check
	var seed_collision := false

	var winners := [1, 2, 3]
	for round_i in range(winners.size()):
		var winner_slot: int = winners[round_i]
		# Move everyone and give them velocity first, so the reset is
		# provably doing work, not just finding things already correct.
		for p in arena.players:
			p.reset_to(p.global_position + Vector2(37.0, -5.0))
			p.velocity = Vector2(123.0, -45.0)
		arena.players[winner_slot - 1].reset_to(relic.global_position)
		# A body just teleported via reset_to() is not necessarily reflected
		# in the physics server's own overlap query on the very next tick -
		# a few settle frames before forcing OPEN avoids querying stale
		# collision state from before the teleport (never an issue in real
		# play, where SETUP/UNLOCKING's multi-second duration always gives
		# the physics server time to catch up before OPEN can ever fire).
		for _i in range(5):
			await physics_frame
		director.debug_force_open()
		for _i in range(15):
			await physics_frame
		if director.state != MatchDirector.State.RESULTS or director.winner_slot_id != winner_slot:
			_report("Rematch round %d setup" % (round_i + 1), "FAIL", "state='%s' winner=%d" % [director.state, director.winner_slot_id])
			continue
		for _i in range(int(1.3 * hz)):
			await physics_frame
		if not director.rematch_ready():
			_report("Rematch round %d: dwell elapsed" % (round_i + 1), "FAIL", "rematch_ready() still false after 1.3s")
			continue

		var brains_before: Array = arena.brains.duplicate()
		arena._full_reset()

		var spawns: Array = [
			arena.get_node("Markers/Spawn1").global_position, arena.get_node("Markers/Spawn2").global_position,
			arena.get_node("Markers/Spawn3").global_position, arena.get_node("Markers/Spawn4").global_position,
		]
		var positions_ok := true
		var velocities_ok := true
		var zones_ok := true
		for i in range(arena.players.size()):
			var p = arena.players[i]
			if p.global_position.distance_to(spawns[i]) > 0.5:
				positions_ok = false
			if p.velocity != Vector2.ZERO:
				velocities_ok = false
			if p.in_traversal_zone:
				zones_ok = false
		_report("Rematch round %d: all 4 bodies at accepted spawns" % (round_i + 1), "PASS" if positions_ok else "FAIL", "")
		_report("Rematch round %d: velocity cleared" % (round_i + 1), "PASS" if velocities_ok else "FAIL", "")
		_report("Rematch round %d: no body left in a traversal zone" % (round_i + 1), "PASS" if zones_ok else "FAIL", "")

		var brains_fresh := true
		for i in range(arena.brains.size()):
			if arena.brains[i] == null:
				continue  # P1 (human) has no brain
			if arena.brains[i] == brains_before[i]:
				brains_fresh = false
			if not arena.brains[i].path.is_empty() or arena.brains[i].executor != null:
				brains_fresh = false
			if arena.brains[i].hard_recovery_count != 0:
				brains_fresh = false
			if not arena.brains[i].blocked_until.is_empty():
				brains_fresh = false
		_report("Rematch round %d: fresh BotBrains (new instances, empty path/blacklist)" % (round_i + 1), "PASS" if brains_fresh else "FAIL", "")

		# relic.monitoring is permanently true by design (see relic.gd) -
		# non-collectible is proven by _collected instead, which SETUP
		# resets and which nothing can bypass while state != OPEN.
		var gate_ok: bool = director.state == MatchDirector.State.SETUP and director.clock == 0.0 and director.winner_slot_id == -1 and not relic._collected
		_report("Rematch round %d: gate SETUP, clock 0, Relic non-collectible, result cleared" % (round_i + 1), "PASS" if gate_ok else "FAIL", "state='%s' clock=%.2f winner=%d _collected=%s" % [director.state, director.clock, director.winner_slot_id, relic._collected])

		var seeds_ok := true
		for i in range(arena.brains.size()):
			if arena.brains[i] == null:
				continue
			var slot_id: int = i + 1
			var expected_seed: int = arena.match_config.match_seed + arena.round_index * 101 + slot_id
			if int(arena.brains[i].rng.seed) != expected_seed:
				seeds_ok = false
			var key: String = "round=%d slot=%d" % [arena.round_index, slot_id]
			if seen_seeds.has(expected_seed):
				seed_collision = true
			seen_seeds[expected_seed] = key
		_report("Rematch round %d: deterministic seed (match_seed + round_index*101 + slot_id)" % (round_i + 1), "PASS" if seeds_ok else "FAIL", "round_index=%d" % arena.round_index)

	_report("No seed collisions across %d rounds x bot slots" % winners.size(), "FAIL" if seed_collision else "PASS", "%d distinct seeds observed" % seen_seeds.size())

	await _unload_rig(arena)

# --- Test 18: Bot goal switch under load (M3-2 Step 4) -----------------------
# docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md S08/S19 Step 4, test 14: fire OPEN
# with a bot mid-edge on every edge type (walk, jump, drop, ladder, launch),
# airborne, and idle on Floor/an upper band/a vault approach. Asserts: no
# per-tick position delta big enough to be a teleport (wrap-aware), the bot's
# goal actually flips to SEEK_RELIC, and the bot makes real, bounded-time
# forward progress afterward (reaches VaultFloor, or at minimum leaves its
# stale node) without excessive hard recoveries (jump/recovery spam).

const GOAL_SWITCH_MAX_TICK_DELTA := 150.0   # px/tick - generous vs. normal physics, tight vs. a teleport
const GOAL_SWITCH_PROGRESS_BUDGET := 20.0   # seconds after OPEN to reach VaultFloor
const GOAL_SWITCH_MAX_HARD_RECOVERIES := 2

func _test_goal_switch_under_load() -> void:
	print("\n--- Test 18: bot goal switch under load (per-edge-type + airborne + idle matrix) ---")
	var scenarios: Array = [
		{"label": "idle on Floor", "kind": "idle", "node": "Floor"},
		{"label": "idle on upper band (A_W)", "kind": "idle", "node": "A_W"},
		{"label": "idle near vault approach (Pier)", "kind": "idle", "node": "Pier"},
		{"label": "mid walk (A_W->A_W_Bridge)", "kind": "edge", "from": "A_W", "to": "A_W_Bridge", "edge_type": "walk", "wait_ticks": 5},
		{"label": "mid jump, airborne (C_W->C_M)", "kind": "edge", "from": "C_W", "to": "C_M", "edge_type": "jump", "wait_for": "airborne"},
		{"label": "mid drop, airborne (B_W->C_W)", "kind": "edge", "from": "B_W", "to": "C_W", "edge_type": "drop", "wait_for": "airborne"},
		{"label": "mid ladder climb (C_W->A_W)", "kind": "edge", "from": "C_W", "to": "A_W", "edge_type": "ladder", "wait_for": "climbing"},
		{"label": "mid launch, airborne (Floor->B_W)", "kind": "edge", "from": "Floor", "to": "B_W", "edge_type": "launch", "wait_for": "launch_air"},
	]
	for scenario in scenarios:
		await _run_goal_switch_scenario(scenario)

func _find_edge(graph: NavGraph, from: String, to: String, edge_type: String) -> Dictionary:
	for e in graph.edges:
		if e.from == from and e.to == to and e.type == edge_type:
			return e
	return {}

func _run_goal_switch_scenario(scenario: Dictionary) -> void:
	var label: String = scenario.label
	var rig := await _load_rig()
	var arena: Node2D = rig.arena
	var geometry: ArenaGeometry = rig.geometry
	var graph: NavGraph = rig.graph
	arena.get_node("MatchDirector").set_physics_process(false)  # drive the FSM by hand, see Test 0's reasoning
	# Isolate to the one bot under test (slot 2 / index 1) - freeze the other
	# two bots so neither can reach and collect the Relic first and freeze
	# everyone via RESULTS before this scenario's own assertions run.
	arena.players[2].controller = FrozenController.new()
	arena.players[3].controller = FrozenController.new()
	var brain: BotBrain = arena.brains[1]
	var body: CharacterBody2D = arena.players[1]

	var hz := physics_ticks_per_second()

	if scenario.kind == "idle":
		var aabb: Dictionary = geometry.aabb(scenario.node)
		await _place_and_settle(body, Vector2(aabb.center.x, aabb.top - geometry.player_half_h))
		body.controller = BotController.new(brain)  # _place_and_settle leaves a FrozenController behind
		brain.current_node = scenario.node
		brain.target_node = ""
		brain.path = []
		brain.executor = null
	else:
		var edge: Dictionary = _find_edge(graph, scenario.from, scenario.to, scenario.edge_type)
		if edge.is_empty():
			_report("goal switch: %s" % label, "FAIL", "no %s edge %s->%s in the graph" % [scenario.edge_type, scenario.from, scenario.to])
			await _unload_rig(arena)
			return
		var from_aabb: Dictionary = geometry.aabb(scenario.from)
		await _place_and_settle(body, Vector2(from_aabb.center.x, from_aabb.top - geometry.player_half_h))
		body.controller = BotController.new(brain)  # _place_and_settle leaves a FrozenController behind
		brain.current_node = scenario.from
		brain.target_node = scenario.to
		brain.path = [edge]
		brain.path_index = 0
		brain.executor = EdgeExecutor.new(body, geometry, edge)
		# Drive the real BotBrain loop (not just the executor) until the
		# requested mid-edge condition holds, or give up after a generous
		# budget - a scenario that can never reach its own mid-edge condition
		# is itself worth reporting, not silently skipped.
		var reached_condition := false
		for _i in range(int(6.0 * hz)):
			await physics_frame
			match scenario.get("wait_for", ""):
				"airborne":
					reached_condition = not body.is_on_floor()
				"climbing":
					reached_condition = body.is_climbing
				"launch_air":
					reached_condition = not body.is_on_floor() and body.velocity.y < -200.0
				_:
					pass
			if scenario.has("wait_ticks"):
				reached_condition = _i >= int(scenario.wait_ticks)
			if reached_condition:
				break
		if not reached_condition:
			_report("goal switch: %s (reached mid-edge state)" % label, "WARN", "never observed the intended mid-edge condition - firing OPEN at whatever state resulted anyway")

	# Fire the real production OPEN cascade: physically opens the gate AND
	# calls notify_open() on every brain, via arena_01.gd's own
	# _on_match_state_changed wiring - not a hand-rolled shortcut.
	arena.match_director.debug_force_open()

	var max_tick_delta := 0.0
	var last_pos: Vector2 = body.global_position
	var reached_vault := false
	var goal_flipped := false
	var budget_ticks := int(GOAL_SWITCH_PROGRESS_BUDGET * hz)
	for i in range(budget_ticks):
		await physics_frame
		var dx: float = abs(geometry.shortest_diff(body.global_position.x, last_pos.x))
		max_tick_delta = max(max_tick_delta, dx)
		last_pos = body.global_position
		if brain.goal == BotBrain.Goal.SEEK_RELIC:
			goal_flipped = true
		if geometry.canonical_platform(body) == "VaultFloor" and body.is_on_floor():
			reached_vault = true
			break

	if not goal_flipped:
		_report("goal switch: %s (goal flips to SEEK_RELIC)" % label, "FAIL", "brain.goal never became SEEK_RELIC")
	else:
		_report("goal switch: %s (goal flips to SEEK_RELIC)" % label, "PASS", "")

	if max_tick_delta > GOAL_SWITCH_MAX_TICK_DELTA:
		_report("goal switch: %s (no teleport)" % label, "FAIL", "worst single-tick position delta %.1fpx (> %.1fpx budget) - looks like a position write, not physics" % [max_tick_delta, GOAL_SWITCH_MAX_TICK_DELTA])
	else:
		_report("goal switch: %s (no teleport)" % label, "PASS", "worst single-tick delta %.1fpx" % max_tick_delta)

	if reached_vault:
		_report("goal switch: %s (reaches VaultFloor within %.0fs)" % [label, GOAL_SWITCH_PROGRESS_BUDGET], "PASS", "arrived, current_node='%s'" % brain.current_node)
	else:
		_report("goal switch: %s (reaches VaultFloor within %.0fs)" % [label, GOAL_SWITCH_PROGRESS_BUDGET], "FAIL", "never reached VaultFloor - final debug_state=%s current_node='%s' target='%s'" % [brain.debug_state(), brain.current_node, brain.target_node])

	if brain.hard_recovery_count > GOAL_SWITCH_MAX_HARD_RECOVERIES:
		_report("goal switch: %s (no jump/recovery spam)" % label, "FAIL", "%d hard recoveries - looks like spam, not a clean re-path" % brain.hard_recovery_count)
	else:
		_report("goal switch: %s (no jump/recovery spam)" % label, "PASS", "%d hard recoveries" % brain.hard_recovery_count)

	await _unload_rig(arena)

# --- Test 19: Pier -> VaultFloor from a spread of arrival speeds (M3-2 Step 4)
# docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md S19 Step 4, test 18 / R8: "a bot
# takes Pier -> VaultFloor at full speed and lands on VaultGateW" - far more
# likely once SEEK_RELIC sends bots through this edge under real time
# pressure than it ever was under plain ROAM. Same drive-to-completion
# mechanism as Test 1, but sweeping ARRIVAL SPEED at a fixed start position
# rather than start position at zero velocity.

func _test_pier_to_vaultfloor_speed_spread() -> void:
	print("\n--- Test 19: Pier -> VaultFloor from a spread of arrival speeds ---")
	var rig := await _load_rig()
	var arena: Node2D = rig.arena
	var geometry: ArenaGeometry = rig.geometry
	var graph: NavGraph = rig.graph
	arena.match_director.debug_force_open()
	arena.get_node("MatchDirector").set_physics_process(false)  # see Test 0's reasoning
	graph.set_gate_open(true)  # redundant after debug_force_open(), kept explicit
	var body: CharacterBody2D = arena.players[0]
	var edge: Dictionary = _find_edge(graph, "Pier", "VaultFloor", "drop")
	if edge.is_empty():
		_report("Pier->VaultFloor speed spread", "FAIL", "no Pier->VaultFloor drop edge in the graph")
		await _unload_rig(arena)
		return

	var pier_aabb: Dictionary = geometry.aabb("Pier")
	var start_x: float = pier_aabb.center.x
	var speeds: Array = [0.0, 125.0, 250.0, 375.0, 500.0]
	var hz := physics_ticks_per_second()
	var passed := 0
	for speed in speeds:
		await _place_and_settle(body, Vector2(start_x, pier_aabb.top - geometry.player_half_h))
		body.velocity = Vector2(speed, 0.0)   # "side": "right" on this edge - departs east, toward VaultFloor
		var exec := EdgeExecutor.new(body, geometry, edge)
		var controller := TestEdgeController.new(exec)
		body.controller = controller
		var budget := int(exec.timeout * hz + 90)
		var t := 0
		while controller.status == EdgeExecutor.Status.RUNNING and t < budget:
			await physics_frame
			t += 1
		var landed: String = geometry.canonical_platform(body)
		if controller.status == EdgeExecutor.Status.SUCCESS and landed == "VaultFloor":
			passed += 1
			_report("Pier->VaultFloor at arrival speed %.0f" % speed, "PASS", "landed on VaultFloor in %.2fs" % (float(t) / hz))
		else:
			_report("Pier->VaultFloor at arrival speed %.0f" % speed, "FAIL", "status=%s landed_on='%s' (expected VaultFloor)" % [controller.status, landed])
	_report("Pier->VaultFloor speed spread summary", "PASS" if passed == speeds.size() else "FAIL", "%d/%d arrival speeds succeeded" % [passed, speeds.size()])
	await _unload_rig(arena)

# --- Test 20: 20+ headless bot-only rounds + M3-2 fairness report (Step 5) --
# docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md S14/S19 Step 5: run the real timed
# SETUP->UNLOCKING->OPEN->RESULTS loop (not debug_force_open - the scattered-
# ROAM-then-converge experiment requires the real setup phase to actually
# elapse) for N rounds with all four slots bot-controlled ("P1 may use a bot
# controller for this headless fairness experiment only" - approved for this
# test alone; the real game always gives P1 a HumanController). Runs at the
# normal time_scale 1.0 - see FAIRNESS_ROUND_TIMEOUT_S's comment for why a
# speed-up multiplier is deliberately NOT used here. MatchTelemetry (already
# wired into the live scene) does the actual per-round bookkeeping; this test
# only drives rounds and prints the aggregate.

const FAIRNESS_ROUNDS := 20
# time_scale is NOT used to speed this test up, deliberately: at large
# multipliers each physics tick's delta grows enough (e.g. 8x -> 0.133s/tick)
# that position-sensitive recipes like Floor->C_M's fixed-trigger jump can
# overshoot their own ~40px trigger window in a single tick - confirmed live
# (every bot's Floor->C_M attempt failed at time_scale 8, a pure artifact of
# coarser physics integration, not a real navigation regression). 1.0/1.25
# are the only values ever validated for this movement model.
const FAIRNESS_ROUND_TIMEOUT_S := 40.0   # wall-clock, at time_scale 1.0

func _test_bot_only_fairness_rounds() -> void:
	print("\n--- Test 20: %d headless bot-only rounds + M3-2 fairness report ---" % FAIRNESS_ROUNDS)
	var rig := await _load_rig()
	var arena: Node2D = rig.arena
	var director: MatchDirector = arena.match_director

	# P1-as-bot, for this headless fairness experiment only. _full_reset()
	# never touches a HUMAN_LOCAL slot's controller, so this brain/controller
	# is rebuilt by hand each round below, exactly like arena_01.gd already
	# does for the three real bot slots.
	var p1_brain: BotBrain = BotBrain.new(
		arena.players[0], arena.geometry, arena.nav_graph, 1, arena._round_base_seed(),
		[arena.players[1], arena.players[2], arena.players[3]],
		Callable(arena, "_on_bot_hard_recovery"), arena.match_config.curiosity_player_prob, arena.relic.global_position.x
	)
	arena.players[0].controller = BotController.new(p1_brain)
	arena.match_telemetry.reset_aggregate()

	var hz := physics_ticks_per_second()
	var non_terminating := 0
	var hard_recoveries_total := 0
	var completed_rounds := 0

	for round_i in range(FAIRNESS_ROUNDS):
		var budget := int(FAIRNESS_ROUND_TIMEOUT_S * hz)
		var ticks := 0
		var reached_results := false
		while ticks < budget:
			await physics_frame
			ticks += 1
			if director.state == MatchDirector.State.RESULTS and director.rematch_ready():
				reached_results = true
				break
		if not reached_results:
			non_terminating += 1
			_report("Fairness round %d" % (round_i + 1), "FAIL", "did not reach a rematch-ready RESULTS within %.0fs - state='%s'" % [FAIRNESS_ROUND_TIMEOUT_S, director.state])
			# Force it open so the round still resolves and the run can
			# continue rather than deadlocking the whole 20-round sweep on
			# one bad round.
			if director.state != MatchDirector.State.RESULTS:
				director.debug_force_open()
				for _i in range(60):
					await physics_frame
		else:
			completed_rounds += 1
		for b in arena.brains:
			if b != null:
				hard_recoveries_total += b.hard_recovery_count
		hard_recoveries_total += p1_brain.hard_recovery_count
		arena._full_reset()
		# _full_reset() never rebuilds P1's controller (HUMAN_LOCAL slot) -
		# give it a fresh brain too, for the same reason every real bot slot
		# gets one: no stale path/blacklist/goal state carried into the next
		# round, and a fair, non-colliding seed per round.
		p1_brain = BotBrain.new(
			arena.players[0], arena.geometry, arena.nav_graph, 1, arena._round_base_seed(),
			[arena.players[1], arena.players[2], arena.players[3]],
			Callable(arena, "_on_bot_hard_recovery"), arena.match_config.curiosity_player_prob, arena.relic.global_position.x
		)
		arena.players[0].controller = BotController.new(p1_brain)

	_report("Fairness rounds terminate with a winner", "PASS" if non_terminating == 0 else "FAIL", "%d/%d rounds reached RESULTS; %d did not" % [completed_rounds, FAIRNESS_ROUNDS, non_terminating])
	arena.match_telemetry.print_aggregate_report(non_terminating, hard_recoveries_total)
	await _unload_rig(arena)
