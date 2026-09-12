extends SceneTree

# M3-2 Step 3 - spawn -> vault-door arrival measurement (diagnostic only).
# docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md S04 and S19 Step 3, item 9. Run
# headless:
#   godot --headless --script tools/door_arrival_check.gd
#
# Measures REAL engine game-time for each accepted spawn to reach a vault
# door, using the actual player movement, nav graph and edge-executor
# recipes - not a Dijkstra cost estimate. Target is "VaultFloor": both the
# west drop and the east VaultEast->VaultFloor step land there
# (ArenaGeometry.canonical_platform folds VaultFloor_Bridge into the same
# name - S10), so reaching it IS reaching a door by either route. The gate
# is forced OPEN for the whole measurement - this reports how long it takes
# to WALK there, independent of whether the seal currently allows entry,
# which is exactly the number S04's setup-duration reasoning needs.
#
# Diagnostic only. Does NOT change setup_duration - that stays whatever
# arena_01.tscn's MatchDirector.setup_duration currently is. This script
# only measures and reports; the Game Director chooses the number at STOP 3.

const ARENA_SCENE_PATH := "res://scenes/arena_01/arena_01.tscn"
const SAMPLES_PER_SPAWN := 3
const TIMEOUT_S := 20.0

# node: the graph node each spawn physically rests on. x: the spawn's real
# world x (Markers/SpawnN in arena_01.tscn). Per the accepted M3-1 territory
# design (docs/DECISIONS.md; M03_2_CORE_MATCH_LOOP_PLAN.md S04): P1 top-left/
# B_W, P2 top-right/B_E, P3 Floor west, P4 Floor east.
const SPAWNS := [
	{"slot": 1, "label": "P1 (B_W, top-left)", "node": "B_W", "x": 480.0},
	{"slot": 2, "label": "P2 (B_E, top-right)", "node": "B_E", "x": 1320.0},
	{"slot": 3, "label": "P3 (Floor, west)", "node": "Floor", "x": 500.0},
	{"slot": 4, "label": "P4 (Floor, east)", "node": "Floor", "x": 1440.0},
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== M3-2 Step 3: spawn -> vault-door (VaultFloor) arrival measurement ===")
	print("%d samples per spawn, %.0fs timeout, gate forced OPEN, real bot-driven movement\n" % [SAMPLES_PER_SPAWN, TIMEOUT_S])

	var arena: Node2D = (load(ARENA_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var geometry: ArenaGeometry = arena.geometry
	var graph: NavGraph = arena.nav_graph
	# debug_force_open() - not a direct nav_graph.set_gate_open(true) - is
	# required here: it is the one call that synchronously cascades through
	# the REAL state_changed signal to RelicGate, which is what actually
	# disables VaultSealW/VaultSealE's collision. Setting nav_graph.gate_open
	# alone only changes Dijkstra's PATHFINDING belief that the vault is
	# open - the physical seal stays solid, and a bot routed through it
	# collides with a wall its own path claims does not exist.
	arena.match_director.debug_force_open()
	# This measurement takes 60-90+ real seconds across all spawns/samples -
	# far longer than MatchDirector's own ~10s timer. Left running past this
	# point, the real Relic (still ticking) can genuinely be collected by
	# one of the OTHER, not-currently-under-test bots roaming with the real
	# graph - that latches RESULTS and freezes every controller, including
	# the one this script has temporarily attached to the spawn under test.
	# Freezing state right after the forced-open cascade keeps this a pure,
	# isolated movement measurement for the rest of the run.
	arena.get_node("MatchDirector").set_physics_process(false)
	arena.get_node("Relic").set_physics_process(false)
	graph.set_gate_open(true)  # redundant after debug_force_open(), kept explicit

	var hz := physics_ticks_per_second()
	var all_results: Dictionary = {}

	for spawn in SPAWNS:
		var body: CharacterBody2D = arena.players[spawn.slot - 1]
		var samples: Array = []
		for i in range(SAMPLES_PER_SPAWN):
			var brain := BotBrain.new(body, geometry, graph, spawn.slot, 999, [], func(_s): pass, 0.0)
			body.controller = BotController.new(brain)
			var result: Dictionary = await _drive_to_door(brain, body, geometry, spawn.node, spawn.x, TIMEOUT_S, hz)
			samples.append(result)
			var status: String = ("OK  %.2fs" % result.elapsed) if result.success else ("FAIL (ended on '%s')" % result.final_platform)
			print("  %s sample %d/%d: %s" % [spawn.label, i + 1, SAMPLES_PER_SPAWN, status])
		all_results[spawn.label] = samples

	root.remove_child(arena)
	arena.queue_free()

	print("\n--- Summary (successful samples only) ---")
	print("%-24s %8s %8s %8s  samples" % ["Spawn", "min", "max", "avg"])
	var slowest_avg := 0.0
	var slowest_label := ""
	var any_slowest := false
	for spawn in SPAWNS:
		var samples: Array = all_results[spawn.label]
		var ok: Array = samples.filter(func(r): return r.success)
		if ok.is_empty():
			print("%-24s  NO SUCCESSFUL SAMPLE (0/%d)" % [spawn.label, samples.size()])
			continue
		var times: Array = ok.map(func(r): return r.elapsed)
		var mn: float = times[0]
		var mx: float = times[0]
		var sum: float = 0.0
		for t in times:
			mn = min(mn, t)
			mx = max(mx, t)
			sum += t
		var avg: float = sum / times.size()
		print("%-24s %7.2fs %7.2fs %7.2fs  %d/%d ok" % [spawn.label, mn, mx, avg, ok.size(), samples.size()])
		if not any_slowest or avg > slowest_avg:
			slowest_avg = avg
			slowest_label = spawn.label
			any_slowest = true

	print("\n--- Setup-duration comparison (working rule: OPEN ~2-3s after the slowest spawn's plausible door arrival) ---")
	if any_slowest:
		print("Slowest spawn (by average): %s at %.2fs" % [slowest_label, slowest_avg])
		print("Suggested range per the working rule: %.1fs - %.1fs" % [slowest_avg + 2.0, slowest_avg + 3.0])
		for candidate in [10.0, 15.0, 25.0]:
			var slack: float = candidate - slowest_avg
			var verdict: String
			if slack < 0.0:
				verdict = "TOO SHORT - slowest spawn cannot reliably reach a door before OPEN"
			elif slack < 2.0:
				verdict = "tight - little to no jockeying time at the door"
			elif slack <= 3.0:
				verdict = "matches the working rule (2-3s slack)"
			else:
				verdict = "generous - %.1fs standing at the door with no powers yet" % slack
			print("  %.0fs: slack %.1fs - %s" % [candidate, slack, verdict])
	else:
		print("No spawn produced a successful sample - cannot recommend a duration from this run.")
	print("\nDIAGNOSTIC ONLY. setup_duration is unchanged by this script. The Game Director selects the value at STOP 3.")
	quit(0)

func physics_ticks_per_second() -> float:
	return float(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60))

# Same driving mechanism as tools/m3_check.gd's _drive_to_destination
# (NAV_STRESS_TEST with a one-entry sequence, the actual path-following
# machinery bots use) - duplicated here rather than shared, matching this
# project's existing convention of self-contained tools/*.gd scripts.
func _drive_to_door(brain: BotBrain, body: CharacterBody2D, geometry: ArenaGeometry, reset_node: String, start_x: float, timeout_s: float, hz: float) -> Dictionary:
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
	brain.stress_sequence = ["VaultFloor"]
	brain.stress_index = 0
	brain.decision_clock = 0.05
	brain._stall_timer = 0.0
	brain._stall_stage_done = 0
	brain._stall_check_pos = body.global_position

	var hard_recoveries_before: int = brain.hard_recovery_count
	for i in range(int(timeout_s * hz)):
		await physics_frame
		if brain.hard_recovery_count > hard_recoveries_before:
			return {"success": false, "elapsed": i / hz, "final_platform": "hard-recovery fired"}
		var plat := geometry.canonical_platform(body)
		if plat == "VaultFloor" and body.is_on_floor():
			return {"success": true, "elapsed": i / hz, "final_platform": plat}
	return {"success": false, "elapsed": timeout_s, "final_platform": geometry.canonical_platform(body)}
