extends SceneTree

# Long-duration NAV STRESS soak/diagnostic (Director report, 2026-09-08):
# "works well for ~120s, then some bots degrade" - P3 stuck oscillating
# in/near the Vault when NAV STRESS commanded it back to Floor (though the
# same physical exit worked instantly with NAV STRESS off), P2 similarly
# degraded, P4 stayed near Floor despite a Seam/Wrap destination. A second,
# related report: bots visibly trapped/bouncing in the narrow Floor pocket
# between CoverE and C_M.
#
# This is a diagnostic tool, not a pass/fail gate like m3_check.gd - it
# records lightweight state-transition events (not every physics tick) for
# a real 5-minute NAV_STRESS_TEST run, flags any bot that goes >3s without
# meaningful progress while it still has an unresolved destination, and
# separately drives one BotBrain through many repeated Floor<->VaultFloor
# cycles without resetting its internal state, to try to reproduce
# "cycle 1/2 work, a later cycle fails."
#
# Run headless:
#   godot --headless --path . --script tools/nav_soak_test.gd

const ARENA_SCENE_PATH := "res://scenes/arena_01/arena_01.tscn"
const SOAK_DURATION := 300.0   # 5 minutes
const STALL_THRESHOLD := 3.0   # seconds without progress while a destination is unresolved
const VAULT_CYCLE_COUNT := 20
const VAULT_CYCLE_TIMEOUT := 15.0

func _initialize() -> void:
	call_deferred("_run")

func physics_ticks_per_second() -> float:
	return float(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60))

func _load_rig() -> Dictionary:
	var arena: Node2D = (load(ARENA_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	return {"arena": arena, "geometry": arena.geometry, "graph": arena.nav_graph}

func _unload_rig(arena: Node2D) -> void:
	arena.queue_free()
	await process_frame

func _run() -> void:
	print("=== NAV STRESS soak / long-duration diagnostic ===")
	await _phase_a_soak()
	await _phase_b_vault_cycles()
	await _phase_c_covere_pocket_check()
	print("\n=== soak test complete ===")
	quit(0)

# --- Phase A: 5-minute real NAV_STRESS_TEST soak, all 3 bots -----------------

class BotTrace:
	var last_node: String = ""
	var last_region: String = ""
	var last_dest: String = ""
	var last_edge: String = ""
	var last_phase: String = ""
	var last_target: String = ""
	var last_progress_t: float = 0.0
	var last_pos: Vector2 = Vector2.ZERO
	var stall_dumped_this_episode: bool = false
	var edge_attempts: Dictionary = {}   # "from->to" -> {pass:int, fail:int}
	var covere_zone: bool = false
	var covere_entries: int = 0
	var covere_jump_ticks: int = 0
	var covere_total_ticks: int = 0

func _bot_label(p) -> String:
	return "slot %d" % p.slot_id

func _fmt_path(path: Array, path_index: int) -> String:
	if path.is_empty():
		return "(none)"
	var parts: Array[String] = []
	for i in range(path.size()):
		var e: Dictionary = path[i]
		var marker := ">>" if i == path_index else "  "
		parts.append("%s%s-[%s]->%s" % [marker, e.from, e.type, e.to])
	return " | ".join(parts)

func _dump_state(t: float, p, brain: BotBrain, reason: String) -> void:
	print("\n  !! STALL DUMP t=%.1fs %s reason=%s" % [t, _bot_label(p), reason])
	print("     debug_state=%s  state=%s  mode=%s" % [brain.debug_state(), brain.state, brain.mode])
	print("     current_node='%s'  target_node='%s'  pos=%s" % [brain.current_node, brain.target_node, str(p.global_position)])
	print("     stress_index=%d  stress_sequence=%s  current_stress_dest='%s'" % [brain.stress_index, str(brain.stress_sequence), brain.current_stress_destination()])
	print("     path=%s" % _fmt_path(brain.path, brain.path_index))
	if brain.executor != null:
		var ex: EdgeExecutor = brain.executor
		print("     executor: edge=%s->%s type=%s phase='%s' elapsed=%.2fs timeout=%.2fs valid=%s" % [ex.edge.from, ex.edge.to, ex.edge.type, ex.phase, ex.elapsed, ex.timeout, ex._valid])
	else:
		print("     executor: null")
	# Blacklist entries relevant to the bot's own next hop, if any.
	if not brain.path.is_empty() and brain.path_index < brain.path.size():
		var e: Dictionary = brain.path[brain.path_index]
		var key := "%s>%s" % [e.from, e.to]
		var unblock_at: float = brain.blocked_until.get(key, -INF)
		if unblock_at > -INF:
			print("     next-hop blacklist: %s blocked until game-clock %.2f (now %.2f)" % [key, unblock_at, brain._clock])
	print("     stall ladder: stage1=%d stage2=%d stage3=%d (counts so far)" % [brain.stage1_count, brain.stage2_count, brain.stage3_count])

func _phase_a_soak() -> void:
	print("\n--- Phase A: %.0fs real NAV_STRESS_TEST soak (all 3 bots) ---" % SOAK_DURATION)
	var rig := await _load_rig()
	var arena: Node2D = rig.arena
	var geometry: ArenaGeometry = rig.geometry
	arena.set_nav_mode(1)  # BotBrain.Mode.NAV_STRESS_TEST

	var covere_aabb: Dictionary = geometry.aabb("CoverE")
	var zone_left: float = covere_aabb.left - 40.0
	var zone_right: float = covere_aabb.right + 40.0

	var bot_indices: Array[int] = []
	var traces: Dictionary = {}
	for i in range(arena.brains.size()):
		if arena.brains[i] != null:
			bot_indices.append(i)
			var tr := BotTrace.new()
			tr.last_pos = arena.players[i].global_position
			traces[i] = tr

	var ticks := int(SOAK_DURATION * physics_ticks_per_second())
	var hz := physics_ticks_per_second()
	for t in range(ticks):
		await physics_frame
		var now: float = float(t) / hz
		for i in bot_indices:
			var p: CharacterBody2D = arena.players[i]
			var brain: BotBrain = arena.brains[i]
			var tr: BotTrace = traces[i]

			# --- meaningful-transition logging ---
			var node := brain.current_node
			var region := ArenaRegions.region_of(node)
			var dest := brain.current_stress_destination()
			var target := brain.target_node
			var phase := brain.executor.phase if brain.executor != null else ""
			var edge_label := ""
			if brain.executor != null:
				edge_label = "%s->%s" % [brain.executor.edge.from, brain.executor.edge.to]

			if node != tr.last_node:
				print("  t=%6.1f %s NODE %s -> %s (region %s)" % [now, _bot_label(p), tr.last_node, node, region])
				tr.last_node = node
			if dest != tr.last_dest:
				print("  t=%6.1f %s DEST -> '%s' (target_node='%s')" % [now, _bot_label(p), dest, target])
				tr.last_dest = dest
			if edge_label != tr.last_edge:
				if edge_label != "":
					print("  t=%6.1f %s EDGE START %s" % [now, _bot_label(p), edge_label])
				tr.last_edge = edge_label
			tr.last_phase = phase
			tr.last_pos = p.global_position

			# "Progress" deliberately does NOT mean raw position movement -
			# _intra_node_wander() produces continuous left/right motion by
			# design, which is exactly what the reported bug looks like from
			# outside ("moving left/right" while stuck). debug_state()
			# distinguishes "the brain believes it is actively pursuing
			# something" (EXECUTOR_ACTIVE / HAS_PATH_NO_EXECUTOR /
			# HAS_DESTINATION_NO_PATH / INVALID_LOCALIZATION) from AT_REST
			# (target_node == current_node - nothing left to do but wander),
			# which is the literal state the cap-exhaustion branch in
			# _decide_next() parks a bot in.
			var ds := brain.debug_state()
			if ds != "AT_REST":
				tr.last_progress_t = now
				tr.stall_dumped_this_episode = false

			# --- stall detection: unresolved NAV STRESS destination, no
			# real progress (per the debug_state() definition above) for
			# more than STALL_THRESHOLD seconds. ---
			if brain.mode == 1 and ds == "AT_REST" and (now - tr.last_progress_t) > STALL_THRESHOLD and not tr.stall_dumped_this_episode:
				tr.stall_dumped_this_episode = true
				_dump_state(now, p, brain, "AT_REST (target_node==current_node=='%s') for >%.0fs under NAV_STRESS_TEST" % [brain.current_node, STALL_THRESHOLD])

			# --- CoverE/C_M pocket zone tracking ---
			var in_zone: bool = p.is_on_floor() and p.global_position.x >= zone_left and p.global_position.x <= zone_right
			if in_zone:
				tr.covere_total_ticks += 1
			if in_zone and not tr.covere_zone:
				tr.covere_zone = true
				tr.covere_entries += 1
				print("  t=%6.1f %s enters CoverE/C_M pocket zone at x=%.1f (node='%s', target='%s')" % [now, _bot_label(p), p.global_position.x, node, target])
			elif not in_zone and tr.covere_zone:
				tr.covere_zone = false
			if in_zone and p.velocity.y < -1.0:
				tr.covere_jump_ticks += 1

	print("\n  -- Phase A summary --")
	for i in bot_indices:
		var p: CharacterBody2D = arena.players[i]
		var brain: BotBrain = arena.brains[i]
		var tr: BotTrace = traces[i]
		print("  %s: stress_arrivals=%d stress_index=%d/%d(cap) hard_recoveries=%d stall_stages(1/2/3)=%d/%d/%d covere_zone_entries=%d covere_zone_ticks=%d covere_jump_ticks=%d" % [
			_bot_label(p), brain.stress_arrivals, brain.stress_index, brain.stress_sequence.size() * 3,
			brain.hard_recovery_count, brain.stage1_count, brain.stage2_count, brain.stage3_count,
			tr.covere_entries, tr.covere_total_ticks, tr.covere_jump_ticks
		])
		print("       final debug_state=%s current_node='%s' target_node='%s' current_stress_dest='%s'" % [
			brain.debug_state(), brain.current_node, brain.target_node, brain.current_stress_destination()
		])

	await _unload_rig(arena)

# --- Phase B: repeated Floor<->VaultFloor cycles, one persistent BotBrain ---

func _phase_b_vault_cycles() -> void:
	print("\n--- Phase B: %d x Floor<->VaultFloor cycles, one persistent BotBrain ---" % VAULT_CYCLE_COUNT)
	var rig := await _load_rig()
	var arena: Node2D = rig.arena
	var geometry: ArenaGeometry = rig.geometry
	arena.set_nav_mode(1)  # NAV_STRESS_TEST, so debug label mechanics behave normally

	var brain: BotBrain = arena.brains[1]   # slot 2 (index 1) - arbitrary, one bot is enough
	var p: CharacterBody2D = arena.players[1]
	var hz := physics_ticks_per_second()

	var destinations := ["VaultFloor", "Floor"]
	var cycle_results: Array = []
	var t := 0.0
	var di := 0
	brain.target_node = destinations[0]

	for cycle in range(VAULT_CYCLE_COUNT * destinations.size()):
		var want: String = destinations[di]
		# Force the destination directly (bypassing _pick_stress_target's own
		# 3x-sequence cap entirely) so this test isolates whether ACCUMULATED
		# brain state (blacklists, visit counters, decision clock, RNG
		# advancement) - not the cap - degrades a later cycle. Re-asserted
		# EVERY tick the target has drifted, not just once at cycle start -
		# an edge failure mid-route clears target_node as a side effect
		# (edge_executor.gd's FAILED branch), and if left alone the bot's
		# own built-in stress_sequence picker takes over on the very next
		# decision tick (confirmed by an earlier version of this driver that
		# only set it once per cycle: contamination from the bot's own
		# sequence, not a real cycle failure, was the result).
		if brain.target_node != want and brain.current_node != want:
			brain.target_node = want
		var start_t := t
		var arrived := false
		var failed_reason := ""
		while t - start_t < VAULT_CYCLE_TIMEOUT:
			await physics_frame
			t += 1.0 / hz
			if brain.current_node == want and brain.target_node == "":
				arrived = true
				break
			if brain.target_node != want and brain.current_node != want:
				brain.target_node = want
			if brain.state == 1:  # RECOVER - a hard recovery mid-cycle is itself a failure signal
				failed_reason = "entered RECOVER (%s)" % brain.debug_state()
		if arrived:
			cycle_results.append({"n": cycle, "want": want, "ok": true, "t": t - start_t})
		else:
			if failed_reason == "":
				failed_reason = "timed out after %.1fs, debug_state=%s" % [VAULT_CYCLE_TIMEOUT, brain.debug_state()]
			cycle_results.append({"n": cycle, "want": want, "ok": false, "t": t - start_t, "reason": failed_reason})
			print("\n  !! Vault-cycle FAILURE at cycle %d (wanted '%s') - %s" % [cycle, want, failed_reason])
			_dump_state(t, p, brain, "vault-cycle failure")
			# Force it back on track for the remaining cycles rather than
			# aborting the whole run - we want to see if it recovers or
			# keeps failing the SAME way.
			brain.target_node = ""
			brain.path = []
			brain.executor = null
		di = (di + 1) % destinations.size()

	print("\n  -- Phase B summary --")
	var ok_count := 0
	for r in cycle_results:
		if r.ok:
			ok_count += 1
	print("  %d/%d cycle-legs succeeded" % [ok_count, cycle_results.size()])
	for r in cycle_results:
		if not r.ok:
			print("    FAIL cycle %d wanted '%s': %s" % [r.n, r.want, r.reason])

	await _unload_rig(arena)

# --- Phase C: does CoverE ever get offered/selected as an explicit target,
# and can a bot physically end up standing beside it while pursuing an
# UNRELATED target? -----------------------------------------------------

func _phase_c_covere_pocket_check() -> void:
	print("\n--- Phase C: CoverE/C_M pocket topology check ---")
	var rig := await _load_rig()
	var arena: Node2D = rig.arena
	var geometry: ArenaGeometry = rig.geometry
	var graph: NavGraph = rig.graph

	var covere_aabb: Dictionary = geometry.aabb("CoverE")
	var cm_aabb: Dictionary = geometry.aabb("C_M")
	print("  CoverE x=[%.0f,%.0f] top=%.0f   C_M x=[%.0f,%.0f] top=%.0f bottom=%.0f" % [
		covere_aabb.left, covere_aabb.right, covere_aabb.top, cm_aabb.left, cm_aabb.right, cm_aabb.top, cm_aabb.bottom
	])
	print("  CoverE entirely under C_M's footprint: %s" % str(covere_aabb.left >= cm_aabb.left and covere_aabb.right <= cm_aabb.right))

	# Is CoverE ever reachable from Floor via the RELIABLE subgraph (i.e.
	# could ordinary target-selection ever pick it)?
	var reach: Dictionary = graph.reliable_reachable_from("Floor")
	print("  CoverE reachable from Floor via RELIABLE-only routing: %s (should be false - it is skill-only)" % str(reach.has("CoverE")))

	# Does the fixed-trigger Floor->C_M recipe's own trigger window overlap
	# CoverE's x-range on either approach side?
	var trigger_far := 100.0
	var trigger_near := 60.0
	var west_window := Vector2(cm_aabb.left - trigger_far, cm_aabb.left - trigger_near)
	var east_window := Vector2(cm_aabb.right + trigger_near, cm_aabb.right + trigger_far)
	print("  Floor->C_M west trigger window x=[%.0f,%.0f]  east trigger window x=[%.0f,%.0f]" % [west_window.x, west_window.y, east_window.x, east_window.y])
	var west_overlaps: bool = west_window.y >= covere_aabb.left and west_window.x <= covere_aabb.right
	var east_overlaps: bool = east_window.y >= covere_aabb.left and east_window.x <= covere_aabb.right
	print("  West window overlaps CoverE: %s   East window overlaps CoverE: %s" % [str(west_overlaps), str(east_overlaps)])

	# Which RELIABLE edges FROM Floor require a straight-line walk across
	# CoverE's x-range to reach their own target/trigger point, given a
	# start on the opposite side of CoverE from that point?
	print("  RELIABLE edges out of Floor and their target x-range (a bot walking from the far side must cross CoverE if its own start and this range straddle CoverE):")
	for e in graph.outgoing("Floor"):
		if e.route_class != NavGraph.RouteClass.RELIABLE:
			continue
		var to_aabb: Dictionary = geometry.aabb(e.to)
		print("    Floor -[%s]-> %s   target x=[%.0f,%.0f]  cost=%.2f" % [e.type, e.to, to_aabb.left, to_aabb.right, e.cost])

	await _unload_rig(arena)
