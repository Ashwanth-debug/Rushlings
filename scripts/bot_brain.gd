class_name BotBrain
extends RefCounted

# ROAM + RECOVER only, per docs/plans/M03_CORE_GAME_LOOP.md §7.4 - "do not
# build a general utility system for two states." M3-2 added SEEK_RELIC at
# the same target-selection seam. M4-1 STOP 1+2 adds SEEK_PICKUP (an
# opportunistic detour inside plain ROAM curiosity, not a new Goal or State -
# see _pick_pickup_target()/_pickup_x_here()) and USE_POWER (a periodic
# range check independent of ROAM/RECOVER - see _update_use_power()). Both
# are deliberately minimal: no health-aware reasoning, no combat planner, no
# personalities (docs/GAME_DESIGN.md §11/§13).

enum State { ROAM, RECOVER }

# M3-2 Step 4 (docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md S08): the match
# objective, orthogonal to State/Mode above - ROAM is M3-1's roaming
# behaviour, SEEK_RELIC is the OPEN-triggered rush. A goal switch never
# invents a third State; it reuses ROAM's entire executor/path/recovery
# machinery unchanged, only _decide_next()'s target selection differs -
# exactly the same shape as the NORMAL_ROAM/NAV_STRESS_TEST Mode split above.
enum Goal { ROAM, SEEK_RELIC }

# Nav stress-test mode (Director feedback, iteration 4): "can a bot reliably
# reach an explicit destination anywhere in the arena" replaces "does bots
# roam intelligently" as the thing M3-1 validation actually needs to prove.
# NAV_STRESS_TEST reuses ROAM's entire executor-driving/recovery/stall-ladder
# machinery unchanged - only _decide_next()'s target selection differs
# (an explicit per-bot sequence instead of curiosity/region picking). A
# separate Mode rather than a new State, since nothing about running an edge
# or recovering from a stall changes between them.
enum Mode { NORMAL_ROAM, NAV_STRESS_TEST }

# Each bot gets a different sequence (Director: "so they do not move
# together") spanning the representative destinations required: lower/floor,
# west, east, upper/Crown, seam/wrap, central/vault-approach - each sequence
# also includes at least one ladder hop, one real vertical-band change, and
# at least one hop long enough that the shortest route naturally wraps
# (ArenaGeometry.shortest_diff, already wrap-aware since M1, picks that
# automatically when it truly is shorter - see the wrap-usage aggregate in
# tools/m3_check.gd's long-run test for confirmation these sequences do).
# VaultEast/VaultFloor stand in for "central/vault approach" - never the
# Relic itself, which does not exist yet.
# VaultFloor is placed LAST in the two sequences that visit it, not
# mid-sequence (Director report: VaultFloor currently has zero RELIABLE
# outgoing edges - see nav_graph.gd - so a bot sent there and then asked for
# a different destination cannot comply and simply remains near it for the
# rest of the run; that is itself the confirmed finding, but a mid-sequence
# visit was also silently costing every LATER destination in that bot's
# sequence. Ending on it means the other five real destinations are still
# proven first, and _test_vault_entry_exit in tools/m3_check.gd is now the
# dedicated, explicit proof of the enter/escape/non-entrapment requirement
# rather than something incidental to the general sequence loop).
const STRESS_SEQUENCES: Array = [
	["Floor", "A_W", "A_E", "C_Seam", "VaultFloor"],
	["C_W", "A_W", "C_Seam", "B_E", "Floor", "A_E"],
	["C_M", "C_Seam", "A_W", "B_E", "Floor", "VaultFloor"],
]

# Human-readable labels for the NAV_STRESS_TEST debug display (Director:
# "show each bot's current destination region as a small debug label").
const STRESS_DEST_LABELS: Dictionary = {
	"Floor": "Lower/Floor", "CoverE": "Lower/Floor",
	"C_W": "West", "C_M": "Central", "C_Seam": "Seam/Wrap",
	"B_W": "West (Band B)", "Pier": "West (Band B)", "B_Under": "Central (Band B)",
	"B_E": "East (Band B)", "B_Seam": "Seam/Wrap (Band B)",
	"A_W": "Upper Left (Crown)", "A_W_Bridge": "Upper Left (Crown)",
	"VaultFloor": "Central/Vault Approach", "VaultEast": "Central/Vault Approach",
	"A_E": "Upper Right (Crown)", "A_E_Bridge": "Upper Right (Crown)",
}

const EDGE_BLOCK_COOLDOWN := 8.0
# Bug fix after A1/A2 playtest: a soft +20 penalty was still cheaper than
# many legitimate alternate routes, so a bot could re-select the very edge
# that just failed, producing exactly the "jump -> fail -> jump -> fail"
# loop the Director flagged. This is a near-blacklist for the cooldown
# window - not absolute, so a genuinely edge-less bot (nothing else
# reachable) can still use it as a last resort rather than being stranded.
const EDGE_BLOCK_PENALTY := 500.0

# Escalating recovery ladder (Director feedback, iteration 3: the old flat
# 4s "no progress" watchdog was too slow and too coarse - a human should
# never watch a bot repeatedly jump against the same obstacle for several
# seconds). One continuous stall timer, staged actions at each threshold:
#   ~0.8s  - possible local failure: one lightweight correction (a jump
#            nudge, in case the executor's own logic hasn't tried one).
#   ~1.5s  - abandon the current edge/path, blacklist it, force a fresh pick.
#   ~2.5s  - enter RECOVER: re-localise for real, and force the NEXT pick to
#            be a different macro-region rather than retrying nearby.
# RECOVER's own timeout below is 1.5s, so worst case stage3 (2.5s) + that
# 1.5s = 4.0s total before hard recovery - matching the requested "~4s max".
const STALL_STAGE1_TIME := 0.8
const STALL_STAGE2_TIME := 1.5
const STALL_STAGE3_TIME := 2.5
const STALL_MIN_DELTA := 20.0
const HARD_RECOVERY_TIMEOUT := 1.5

# Five deterministic knobs, all seeded from match_seed + slot_index, none a
# personality (§7.5). Indexed by slot so P2/P3/P4 each land on a different
# row without any of them being "the hard bot."
const DECISION_INTERVALS := [0.45, 0.55, 0.65]
const PHASE_OFFSETS := [0.0, 0.15, 0.30]
const REACTION_DELAYS := [0.15, 0.30, 0.45]
const LEVEL_CHANGE_PENALTIES := [0.0, 0.4, 0.8]

var body: CharacterBody2D
var geometry: ArenaGeometry
var graph: NavGraph
var slot_index: int
var other_bodies: Array
var hard_recovery_callback: Callable
var curiosity_player_prob: float
## The Relic's real world x, read once at construction (arena_01.gd passes
## the live Relic Area2D's global_position.x - see S10's "final approach").
## Defaulted to the Relic's authored centre (980-1020) so a rig with no live
## Relic node (none of the pre-Step-5 tests construct one directly) still
## gets a sane value.
var relic_x: float = 1000.0

## M4-1 STOP 1 - set via set_pickup_field() (a setter, not a constructor
## param - see pickup_field.gd's own header for why), never in _init().
## Stays null for every existing test rig that never calls the setter
## (tools/m3_check.gd, tools/nav_soak_test.gd, tools/door_arrival_check.gd),
## which is exactly what gates every pickup-seeking branch below off for them.
var pickup_field = null

var rng := RandomNumberGenerator.new()
var pickup_rng := RandomNumberGenerator.new()
var state: State = State.ROAM
var mode: Mode = Mode.NORMAL_ROAM
var goal: Goal = Goal.ROAM
var goal_dirty: bool = false
var _goal_dirty_since: float = 0.0
## Dev/telemetry only (S14): when this bot first arrived at VaultFloor while
## pursuing SEEK_RELIC, in brain-clock seconds; -1 until then. Reset by
## reset_goal()/a fresh BotBrain instance, never by the goal switch itself.
var seek_relic_arrived_at: float = -1.0
## Dev/telemetry only (S14 "door used ... inferred from the last edge taken
## for a bot"): "west" (arrived via Pier) or "east" (via VaultEast), "" if
## this bot has never completed an edge landing on VaultFloor.
var last_relic_door: String = ""
var current_node: String = ""
var target_node: String = ""
var path: Array = []
var path_index: int = 0
var executor: EdgeExecutor = null

var stress_sequence: Array = []
var stress_index: int = 0
var stress_arrivals: int = 0
var stress_arrived_nodes: Dictionary = {}   # node name -> arrival count, for a bot x destination report

var decision_clock: float
var decision_interval: float
var reaction_delay: float
var level_change_penalty: float
var edge_type_weight: Dictionary = {}

var interest_nodes: Array = []
var last_visited: Dictionary = {}
var visit_counter: int = 0
var last_region_visited: Dictionary = {}
var region_visit_counter: int = 0
var wander_target_x: float = NAN
var _force_new_region: bool = false

var recover_timer: float = 0.0
var blocked_until: Dictionary = {}   # "from>to" -> game-time seconds it unblocks
var _clock: float = 0.0
var hard_recovery_count: int = 0
var completed_edge_types: Dictionary = {}   # edge type -> completion count

# Stall ladder state.
var _stall_timer: float = 0.0
var _stall_stage_done: int = 0
var _stall_check_pos: Vector2
var stage1_count: int = 0
var stage2_count: int = 0
var stage3_count: int = 0

# Landed on real, solid geometry that isn't a nav-graph node (Problem 2's
# "localized to an invalid/ambiguous graph node" - e.g. VaultGateW, the
# rotated beam over the Relic, reachable only by a bad jump landing). Never
# adopted as current_node - Dijkstra can't path from it - instead nudged off
# deterministically until back on real footing. No teleporting.
var _invalid_platform: String = ""

var horizontal_intent: float = 0.0
var vertical_intent: float = 0.0
var _pending_jump: bool = false

func _init(p_body: CharacterBody2D, p_geometry: ArenaGeometry, p_graph: NavGraph, p_slot_index: int, match_seed: int, p_other_bodies: Array, p_hard_recovery_callback: Callable, p_curiosity_player_prob: float = 0.25, p_relic_x: float = 1000.0) -> void:
	body = p_body
	geometry = p_geometry
	graph = p_graph
	slot_index = p_slot_index
	other_bodies = p_other_bodies
	hard_recovery_callback = p_hard_recovery_callback
	curiosity_player_prob = p_curiosity_player_prob
	relic_x = p_relic_x

	rng.seed = match_seed + slot_index
	# M4-1 STOP 1: a separate stream, not `rng`, for SEEK_PICKUP's own roll
	# (_pick_pickup_target()) - every pre-existing ROAM/NAV_STRESS decision
	# (region pick, node pick, curiosity-follow) is drawn from `rng` in a
	# fixed order that tools/m3_check.gd's determinism and long-run tests
	# depend on. Consuming even one extra `rng.randf()` per decision cycle
	# shifts every later draw in that sequence, which was confirmed to
	# occasionally route a bot into an already-known-flaky SKILL-edge
	# neighbourhood near the vault seal (the same geometry the 4 acknowledged
	# m3_check.gd findings already document) purely from the changed RNG
	# sequence, not from anything SEEK_PICKUP itself targets. A second,
	# independently-seeded generator keeps SEEK_PICKUP's own randomness from
	# perturbing any pre-existing, already-tuned bot decision at all.
	pickup_rng.seed = match_seed + slot_index + 97
	var row: int = slot_index % DECISION_INTERVALS.size()
	decision_interval = DECISION_INTERVALS[row]
	reaction_delay = REACTION_DELAYS[row]
	level_change_penalty = LEVEL_CHANGE_PENALTIES[row]
	decision_clock = PHASE_OFFSETS[row]
	match row:
		0:
			edge_type_weight = {"ladder": 0.85}
		1:
			edge_type_weight = {"drop": 0.85}
		_:
			edge_type_weight = {}

	interest_nodes = graph.nodes.duplicate()
	_shuffle(interest_nodes)
	_stall_check_pos = body.global_position
	stress_sequence = STRESS_SEQUENCES[slot_index % STRESS_SEQUENCES.size()]

## Dev-only toggle between NORMAL_ROAM and NAV_STRESS_TEST (Director
## feedback, iteration 4). Switching abandons whatever the bot was doing -
## a live path/executor picked under the old mode's target-selection rules
## has no meaning under the new one.
func set_mode(new_mode: Mode) -> void:
	if new_mode == mode:
		return
	mode = new_mode
	target_node = ""
	path = []
	path_index = 0
	executor = null
	stress_index = 0
	decision_clock = min(decision_clock, 0.1)

## Dev-only: restart this bot's NAV_STRESS_TEST sequence from its beginning,
## without touching mode, position or any other brain state (Director
## request, 2026-09-08: observing bots for 5+ minutes needs a way to run the
## deliberately-bounded 3x sequence cap again, rather than reading "sequence
## complete" as a navigation failure). Deliberately the same reset shape as
## set_mode()'s own target/path/executor clear, minus the mode switch, so a
## restart mid-edge behaves like arriving fresh rather than like an
## interrupted, half-finished attempt.
func restart_stress_sequence() -> void:
	target_node = ""
	path = []
	path_index = 0
	executor = null
	stress_index = 0
	stress_arrivals = 0
	stress_arrived_nodes = {}
	decision_clock = min(decision_clock, 0.1)

## The node the bot is currently trying to reach under NAV_STRESS_TEST, for
## the human-playtest debug label - "" outside that mode or before the first
## destination is picked.
##
## Long-duration soak diagnostic (Director report, 2026-09-08): this used to
## compute stress_index % size unconditionally, with no cap check - but
## _pick_stress_target() (the function that actually decides what the bot
## pursues) gives up permanently once stress_index >= stress_sequence.size()*3
## (intentional - "a run long enough to prove the sequence works doesn't need
## to repeat forever"), at which point the REAL logic reverts to
## _decide_next()'s target_node = current_node branch and the bot silently
## parks in AT_REST/_intra_node_wander() forever. The label never reflected
## that: it kept computing stress_index % size and displaying whatever
## sequence entry that landed on, showing a perfectly plausible-looking
## destination that nothing was actually pursuing - exactly what a human
## watching the debug label during an extended playtest would read as "the
## bot is refusing to go to X" rather than "the bot decided it was done."
## Root cause confirmed by a 5-minute soak test: slot 3's own 5-entry
## sequence hit the cap at stress_index=15 with target_node==current_node==
## 'VaultFloor', while this function still reported 'Lower/Floor' (index
## 15 % 5 = 0) - the exact "reached the Vault, destination shows Lower Floor,
## but stays in the Vault" pattern reported from human play.
func current_stress_destination() -> String:
	if mode != Mode.NAV_STRESS_TEST or stress_sequence.is_empty():
		return ""
	if stress_index >= stress_sequence.size() * 3:
		return "(sequence complete)"
	var dest: String = stress_sequence[stress_index % stress_sequence.size()]
	return STRESS_DEST_LABELS.get(dest, dest)

## The OPEN-triggered goal switch (S08). Does NOT cancel anything itself -
## it only records that a switch is wanted and when it was requested.
## _check_goal_switch(), run every ROAM tick, performs the actual
## cancellation once this bot's own reaction delay has elapsed AND it is
## grounded on a valid node (capped at GOAL_SWITCH_GROUND_CAP). Idempotent:
## a second call while already SEEK_RELIC (e.g. a stray extra signal) is a
## no-op, never re-arming goal_dirty or resetting the staggered timer.
func notify_open() -> void:
	if goal == Goal.SEEK_RELIC:
		return
	goal = Goal.SEEK_RELIC
	goal_dirty = true
	_goal_dirty_since = _clock

## Reverts to plain ROAM (arena_01.gd calls this on every transition back to
## SETUP - a real rematch already gets a brand-new BotBrain where this is a
## no-op, but the debug_setup_10/15/25 keys reset MatchDirector alone without
## rebuilding brains, and a bot must not carry SEEK_RELIC into a freshly
## re-sealed vault). Same cancellation shape as set_mode()/notify_open().
func reset_goal() -> void:
	if goal == Goal.ROAM and not goal_dirty:
		return
	goal = Goal.ROAM
	goal_dirty = false
	target_node = ""
	path = []
	path_index = 0
	executor = null
	seek_relic_arrived_at = -1.0
	last_relic_door = ""
	decision_clock = min(decision_clock, 0.1)

## Approved cancel-on-ground re-path (S08): fires on the first ROAM tick
## where BOTH this bot's own reaction_delay has elapsed AND it is grounded on
## a real graph node - re-localising from actual physical footing, never a
## stale mid-air current_node. Capped at GOAL_SWITCH_GROUND_CAP: if still not
## grounded by then, cancel anyway and let the stall ladder/RECOVER handle
## whatever physical state that leaves the body in - no special-casing for
## mid-transit states, exactly as approved. Edge blacklists (blocked_until)
## are deliberately untouched - S08's "leave it" instruction.
const GOAL_SWITCH_GROUND_CAP := 1.2

func _check_goal_switch() -> void:
	if not goal_dirty:
		return
	var elapsed: float = _clock - _goal_dirty_since
	if elapsed < reaction_delay:
		return
	var grounded_valid: bool = body.is_on_floor() and _invalid_platform == "" and current_node != "" and graph.nodes.has(current_node)
	if grounded_valid or elapsed >= GOAL_SWITCH_GROUND_CAP:
		goal_dirty = false
		executor = null
		path = []
		path_index = 0
		target_node = ""
		decision_clock = min(decision_clock, 0.1)
		print("[BotBrain] slot %d: goal switch -> SEEK_RELIC (reacted at %.2fs, grounded=%s, node='%s')" % [slot_index, elapsed, grounded_valid, current_node])

func consume_jump_intent() -> bool:
	var j := _pending_jump
	_pending_jump = false
	return j

## M4-1 STOP 1 - the only way anything outside this file learns about the
## pickup field. Deliberately a setter, not a constructor param - see
## pickup_field's own declaration above.
func set_pickup_field(field) -> void:
	pickup_field = field

## M4-1 STOP 2 - USE_POWER (CLAUDE.md M4-1 S10): "if carrying a power and
## another player is within a simple valid range/forward condition, [it] may
## be used." Deliberately no health-aware or tactical reasoning of any kind
## (docs/GAME_DESIGN.md S11/S13's explicit no-low-health-behaviour rule
## applies to every bot decision, not just this one) - just "is anyone
## close enough to matter." PowerSystem's own per-power validity rule
## (scripts/power_system.gd) is the real gate on whether anything happens;
## this only decides whether the bot bothers to try.
const USE_POWER_CHECK_INTERVAL := 0.5
const USE_POWER_RANGE := 300.0

var _pending_power_use: bool = false
var _use_power_clock: float = 0.0

func consume_power_intent() -> bool:
	var p := _pending_power_use
	_pending_power_use = false
	return p

func _update_use_power(delta: float) -> void:
	_use_power_clock -= delta
	if _use_power_clock > 0.0:
		return
	_use_power_clock = USE_POWER_CHECK_INTERVAL
	if not body.has_method("has_power") or not body.has_power():
		return
	if _find_use_power_target() != null:
		_pending_power_use = true

func _find_use_power_target() -> CharacterBody2D:
	for other in other_bodies:
		if other == null or not is_instance_valid(other):
			continue
		# M4-1 STOP 3+4: a Defeated body is meant to be "not there" for the
		# rest of the arena (see player.gd's set_defeated()) - not targeting
		# one isn't tactical/health-aware reasoning, it's just not wasting an
		# attempt on someone who is invisible and cannot be affected.
		if "is_defeated" in other and other.is_defeated:
			continue
		var dx: float = geometry.shortest_diff(other.global_position.x, body.global_position.x)
		var dy: float = other.global_position.y - body.global_position.y
		if Vector2(dx, dy).length() <= USE_POWER_RANGE:
			return other
	return null

## M4-1 STOP 3+4 - called by arena_01.gd right after a bot's body is
## reset_to()'d onto a fresh respawn anchor (scripts/health_system.gd). Same
## shape as reset_goal()'s own path/executor/target clearing: an EdgeExecutor
## built against the pre-respawn position is meaningless after a teleport,
## exactly the "stale navigation" class of bug reset_goal() already exists to
## prevent for the OPEN goal-switch case. current_node self-corrects within
## one tick via _update_localization() and needs no help here; goal is left
## alone deliberately - a bot mid-SEEK_RELIC when defeated should still want
## the Relic after respawning.
func handle_respawn() -> void:
	target_node = ""
	path = []
	path_index = 0
	executor = null
	_invalid_platform = ""
	decision_clock = min(decision_clock, 0.1)

func tick(delta: float) -> void:
	_clock += delta
	horizontal_intent = 0.0
	vertical_intent = 0.0
	match state:
		State.ROAM:
			_tick_roam(delta)
		State.RECOVER:
			_tick_recover(delta)
	_update_stall_ladder(delta)
	_update_use_power(delta)

# --- Diagnostics (Director feedback: instrument bot state so automated
# tests can identify exactly which logical-idle hole, if any, a bot is in) --

func debug_state() -> String:
	if state == State.RECOVER:
		return "RECOVER"
	if _invalid_platform != "":
		return "INVALID_LOCALIZATION"
	if executor != null:
		return "EXECUTOR_ACTIVE"
	if not path.is_empty():
		return "HAS_PATH_NO_EXECUTOR"
	if target_node == "":
		return "NO_DESTINATION"
	if target_node == current_node:
		return "AT_REST"
	return "HAS_DESTINATION_NO_PATH"

# --- ROAM ---------------------------------------------------------------

func _tick_roam(delta: float) -> void:
	_update_localization()
	# Checked before the _invalid_platform early-return, deliberately: the
	# GOAL_SWITCH_GROUND_CAP must keep counting down even if this exact bot
	# happens to be sitting on unrecognised geometry when OPEN fires, or a
	# rare-but-possible combination of the two bugs could wedge goal_dirty
	# open indefinitely.
	_check_goal_switch()
	if _invalid_platform != "":
		# Deterministic nudge off unrecognised geometry - never teleport.
		# Direction is fixed per bot (not re-randomised each tick) so it
		# commits to one way off rather than vibrating in place.
		horizontal_intent = 1.0 if (slot_index % 2 == 0) else -1.0
		return

	if executor != null:
		_drive_executor(delta)
		return
	if not path.is_empty():
		executor = EdgeExecutor.new(body, geometry, path[path_index])
		_drive_executor(delta)
		return

	decision_clock -= delta
	if decision_clock <= 0.0:
		decision_clock = decision_interval
		_decide_next()
		if not path.is_empty():
			return
	# S10 final approach: VaultFloor is too low a chamber to jump inside, and
	# _intra_node_wander()'s random x would have the bot drift away from the
	# Relic instead of collecting it - a pure walk toward the Relic's actual
	# (wrap-aware) x, holding once close enough for the Relic's own Area2D
	# overlap to do the rest.
	var pickup_here := _pickup_x_here()
	if goal == Goal.SEEK_RELIC and current_node == "VaultFloor":
		_final_approach_relic()
	elif not is_nan(pickup_here):
		_final_approach_x(pickup_here)
	else:
		_intra_node_wander()

# Only accepts a landing as current_node if it is a real nav-graph node -
# the root cause found for a bot silently going idle (Problem 2): landing on
# real, solid, but non-graph geometry (VaultGateW) previously got adopted as
# current_node just because it was non-empty, after which EVERY pathfind
# failed silently forever (Dijkstra has no route from an unknown node), and
# nothing ever corrected current_node back because the bot never left that
# platform on its own initiative.
func _update_localization() -> void:
	if not body.is_on_floor():
		return
	var p := geometry.canonical_platform(body)
	if p == "":
		return
	if not graph.nodes.has(p):
		if p != _invalid_platform:
			_invalid_platform = p
			print("[BotBrain] slot %d: landed on '%s' - not a nav-graph node, nudging off it" % [slot_index, p])
		return
	if _invalid_platform != "":
		print("[BotBrain] slot %d: back on '%s', resuming normal roam" % [slot_index, p])
	_invalid_platform = ""
	if p != current_node:
		current_node = p
		_mark_visited(p)

func _drive_executor(delta: float) -> void:
	var status := executor.tick(delta)
	horizontal_intent = executor.horizontal_intent
	vertical_intent = executor.vertical_intent
	if executor.jump_flag:
		_pending_jump = true
	match status:
		EdgeExecutor.Status.SUCCESS:
			var done_edge: Dictionary = path[path_index]
			completed_edge_types[done_edge.type] = completed_edge_types.get(done_edge.type, 0) + 1
			current_node = path[path_index].to
			_mark_visited(current_node)
			# S14 telemetry: which door this bot's most recent VaultFloor
			# arrival used - inferred from the edge that just landed it there,
			# per the plan's own instruction ("last edge taken for a bot").
			if current_node == "VaultFloor":
				if done_edge.from == "Pier":
					last_relic_door = "west"
				elif done_edge.from == "VaultEast":
					last_relic_door = "east"
			path_index += 1
			executor = null
			if path_index >= path.size():
				path = []
				if current_node == target_node:
					target_node = ""
					if goal == Goal.SEEK_RELIC and current_node == "VaultFloor" and seek_relic_arrived_at < 0.0:
						seek_relic_arrived_at = _clock
					if mode == Mode.NAV_STRESS_TEST:
						stress_arrivals += 1
						stress_arrived_nodes[current_node] = stress_arrived_nodes.get(current_node, 0) + 1
						print("[BotBrain] slot %d: nav stress test reached '%s' (%d/%d in sequence)" % [slot_index, current_node, (stress_index % stress_sequence.size()) + 1, stress_sequence.size()])
						stress_index += 1
						decision_clock = min(decision_clock, 0.1)
		EdgeExecutor.Status.FAILED:
			var failed_edge: Dictionary = path[path_index]
			_block_edge(failed_edge.from, failed_edge.to)
			print("[BotBrain] slot %d: edge %s->%s FAILED" % [slot_index, failed_edge.from, failed_edge.to])
			path = []
			executor = null
			target_node = ""
			# One-attempt rule (Director feedback, iteration 4): a failed
			# traversal should read as the bot "changing its mind" and
			# immediately setting off somewhere else, not sitting idle until
			# the next scheduled decision tick (up to decision_interval away)
			# before reacting.
			decision_clock = min(decision_clock, 0.1)

func _block_edge(from: String, to: String) -> void:
	blocked_until["%s>%s" % [from, to]] = _clock + EDGE_BLOCK_COOLDOWN

func _has_active_goal() -> bool:
	return executor != null or not path.is_empty() or (target_node != "" and target_node != current_node)

# The escalating stall ladder. Runs every tick regardless of what ROAM is
# doing internally - it is a continuous measure of "time since any real
# positional progress while trying to get somewhere", not tied to any one
# executor or edge, so it also catches chains of short failures (each one
# individually bounded and fast, per edge_executor.gd, but never actually
# advancing the bot) rather than only a single long stall.
func _update_stall_ladder(delta: float) -> void:
	if state != State.ROAM or _invalid_platform != "":
		_stall_timer = 0.0
		_stall_stage_done = 0
		_stall_check_pos = body.global_position
		return
	var moved := body.global_position.distance_to(_stall_check_pos)
	if moved >= STALL_MIN_DELTA:
		_stall_timer = 0.0
		_stall_stage_done = 0
		_stall_check_pos = body.global_position
		return
	if not _has_active_goal():
		# Resting at a chosen wander spot with nothing further to do is not
		# a stall - but don't reset the ladder either, in case this is just
		# the brief gap between abandoning one goal and the next decision
		# cycle picking another mid-episode.
		return
	_stall_timer += delta
	if _stall_timer >= STALL_STAGE1_TIME and _stall_stage_done < 1:
		_stall_stage_done = 1
		_stage1_light_correction()
	if _stall_timer >= STALL_STAGE2_TIME and _stall_stage_done < 2:
		_stall_stage_done = 2
		_stage2_abandon_and_repath()
	if _stall_timer >= STALL_STAGE3_TIME and _stall_stage_done < 3:
		_stall_stage_done = 3
		_stage3_relocalize_new_region()

func _stage1_light_correction() -> void:
	stage1_count += 1
	print("[BotBrain] slot %d: stall stage1 (%.2fs, possible local failure) - lightweight correction" % [slot_index, _stall_timer])
	# The correction is deliberately passive: edge_executor.gd already owns
	# a bounded unstick-jump retry for exactly this situation, and forcing
	# an EXTRA jump from here caused a real bug - a jump is a large, fast
	# motion, so it satisfied the stall ladder's own "moved" progress check
	# without the underlying problem being resolved at all, silently
	# resetting stage2/stage3 from ever being reached. The only active
	# correction here is nudging the decision clock so a fresh pick is
	# tried slightly sooner than the normal cadence, without touching
	# physics.
	decision_clock = min(decision_clock, 0.1)

func _stage2_abandon_and_repath() -> void:
	stage2_count += 1
	var label := "(no active edge)"
	if not path.is_empty() and path_index < path.size():
		var e: Dictionary = path[path_index]
		label = "%s->%s" % [e.from, e.to]
		_block_edge(e.from, e.to)
	print("[BotBrain] slot %d: stall stage2 (%.2fs) abandon+repath on %s" % [slot_index, _stall_timer, label])
	path = []
	executor = null
	target_node = ""

func _stage3_relocalize_new_region() -> void:
	stage3_count += 1
	print("[BotBrain] slot %d: stall stage3 (%.2fs) re-localise + force a different region" % [slot_index, _stall_timer])
	_force_new_region = true
	_enter_recover("stall ladder stage 3 (%.2fs without progress)" % _stall_timer)

func _decide_next() -> void:
	if target_node == "" or target_node == current_node:
		var picked := _pick_target_for_mode()
		if picked == current_node or picked == "":
			# Confirmed regression: in NAV_STRESS_TEST, a sequence entry that
			# happens to already equal the bot's current node (its own spawn
			# node as sequence[0] was the case that surfaced this) fell
			# through to "nothing to do, wander" without ever advancing
			# stress_index - since only a real completed edge or a failed-
			# path skip used to move the index forward, the bot re-offered
			# the same trivially-already-satisfied destination forever and
			# never got credit for it or moved on to the next one.
			if goal == Goal.ROAM and mode == Mode.NAV_STRESS_TEST and picked == current_node and picked != "":
				stress_arrivals += 1
				stress_arrived_nodes[current_node] = stress_arrived_nodes.get(current_node, 0) + 1
				print("[BotBrain] slot %d: nav stress test already at '%s' (%d/%d in sequence)" % [slot_index, current_node, (stress_index % stress_sequence.size()) + 1, stress_sequence.size()])
				stress_index += 1
				decision_clock = min(decision_clock, 0.1)
			# S14 telemetry: the bot was already standing on VaultFloor the
			# instant SEEK_RELIC was set (e.g. OPEN fired while it happened to
			# be there) - record the arrival exactly like a completed-edge
			# arrival does in _drive_executor, so this case is not silently
			# missing from the fairness data.
			if goal == Goal.SEEK_RELIC and picked == "VaultFloor" and picked == current_node and seek_relic_arrived_at < 0.0:
				seek_relic_arrived_at = _clock
			target_node = current_node
			if not (goal == Goal.SEEK_RELIC and current_node == "VaultFloor"):
				wander_target_x = _random_wander_x(current_node)
			return
		target_node = picked
	var new_path: Array = NavPath.shortest_path(graph, current_node, target_node, _weighted_cost)
	if new_path.is_empty():
		if goal == Goal.SEEK_RELIC and target_node == "VaultFloor":
			_seek_relic_fallback_path()
			return
		if mode == Mode.NAV_STRESS_TEST:
			# No reliable route to this destination from here right now
			# (e.g. it was reached via a skill edge that just failed and is
			# on cooldown) - skip it rather than stalling on an
			# unreachable target for the rest of the run.
			print("[BotBrain] slot %d: nav stress test - no path to '%s', skipping" % [slot_index, target_node])
			stress_index += 1
		target_node = ""
	else:
		path = new_path
		path_index = 0

## Which target-selection policy is active - goal (the real match objective)
## always wins over mode (a dev-only ROAM/NAV_STRESS_TEST toggle): SEEK_RELIC
## means the match is racing to the Relic regardless of what debug mode
## happens to be set.
func _pick_target_for_mode() -> String:
	if goal == Goal.SEEK_RELIC:
		return "VaultFloor"
	return _pick_stress_target() if mode == Mode.NAV_STRESS_TEST else _pick_interest_target()

## Approved S08 fallback: "if [Dijkstra] returns empty - which should be
## impossible, but the code must not assume so - fall back to a route toward
## the nearest of Pier / A_E and retry next tick." Once at either door, the
## next _decide_next() cycle asks for VaultFloor again, now one gated hop
## away instead of a whole-arena route - a bot cannot get permanently stuck
## on this path just because the direct route momentarily failed.
func _seek_relic_fallback_path() -> void:
	var pier_path: Array = NavPath.shortest_path(graph, current_node, "Pier", _weighted_cost)
	var ae_path: Array = NavPath.shortest_path(graph, current_node, "A_E", _weighted_cost)
	var use_pier: bool = not pier_path.is_empty() and (ae_path.is_empty() or pier_path.size() <= ae_path.size())
	if use_pier:
		path = pier_path
		path_index = 0
		target_node = "Pier"
	elif not ae_path.is_empty():
		path = ae_path
		path_index = 0
		target_node = "A_E"
	else:
		target_node = ""

const RELIC_ARRIVAL_TOL := 8.0

## S10 final approach, the one new behaviour SEEK_RELIC adds beyond reusing
## ROAM's machinery: a pure wrap-aware walk toward the Relic's real x, no
## jump (the 84px alcove is too low), holding once close enough that the
## Relic's own Area2D overlap resolves the actual collection.
func _final_approach_relic() -> void:
	_final_approach_x(relic_x)

## M4-1 STOP 1 - generalised for pickups: the exact same "walk to this real
## x and hold, let the target's own Area2D resolve collection" shape
## _final_approach_relic() already used, since a pickup floating above a
## small platform has the identical "random intra-node wander would drift
## past it" problem the Relic does.
func _final_approach_x(target_x: float) -> void:
	var diff: float = geometry.shortest_diff(target_x, body.global_position.x)
	if abs(diff) < RELIC_ARRIVAL_TOL:
		horizontal_intent = 0.0
	else:
		horizontal_intent = 1.0 if diff > 0.0 else -1.0

## The available pickup's real x if this bot is empty-handed and one exists
## on the node it is currently standing on, else NAN. Deliberately opportunistic
## rather than tied to a specific "I chose this pickup as my goal" flag - a
## bot that arrives at a pickup's platform for any reason (curiosity,
## SEEK_PICKUP, recovery) collects it if it can use it, exactly like a human
## walking past one would.
func _pickup_x_here() -> float:
	if pickup_field == null or current_node == "":
		return NAN
	if not body.has_method("has_power") or body.has_power():
		return NAN
	return pickup_field.x_for_node(current_node)

## The next node in this bot's explicit destination sequence, or "" once the
## whole sequence has looped back around past its own length once - a run
## long enough to prove the sequence works doesn't need to repeat forever.
func _pick_stress_target() -> String:
	if stress_sequence.is_empty() or stress_index >= stress_sequence.size() * 3:
		return ""
	return stress_sequence[stress_index % stress_sequence.size()]

func _weighted_cost(edge: Dictionary) -> float:
	# Nav-graph audit (Director feedback, iteration 5 - explicit policy
	# change): ordinary bot pathfinding - both ROAM and the nav stress test -
	# uses RELIABLE edges ONLY. An earlier version heavily penalised but
	# still permitted SKILL edges as a last-resort fallback; the Director
	# explicitly rejected that ("do not retain an unreliable edge merely as
	# a high-cost fallback... that policy is currently allowing bots to
	# select movements we already know they cannot execute consistently").
	# INF excludes SKILL and INVALID from Dijkstra entirely - if that
	# disconnects a region, NavPath.shortest_path returns [] and _decide_next
	# reports it rather than quietly routing through something known-bad.
	if edge.get("route_class", NavGraph.RouteClass.RELIABLE) != NavGraph.RouteClass.RELIABLE:
		return INF
	# M3-2 Step 2 (S07): while the vault is sealed, its five interior edges
	# are excluded from Dijkstra exactly like a SKILL/INVALID edge - INF, not
	# merely penalised, so a ROAM bot never attempts to walk into physically
	# blocked collision. graph.gate_open flips true again at OPEN.
	if edge.get("gated", false) and not graph.gate_open:
		return INF
	var w: float = edge_type_weight.get(edge.type, 1.0)
	var extra: float = level_change_penalty if (edge.type == "ladder" or edge.type == "launch") else 0.0
	# An edge that just failed is heavily penalised, not permanently removed -
	# a real transient failure (another body briefly in the way, a mistimed
	# launch) should not permanently blacklist a legitimate route, but
	# Dijkstra should always prefer any viable alternative while the
	# cooldown holds (see EDGE_BLOCK_PENALTY).
	var key := "%s>%s" % [edge.from, edge.to]
	if _clock < blocked_until.get(key, -INF):
		extra += EDGE_BLOCK_PENALTY
	return float(edge.cost) * w + extra

# --- Region-then-node target selection -----------------------------------
# A macro-region layer sits above node selection - pick a region first,
# then a node within it. No arena geometry changes; ArenaRegions groups the
# existing graph nodes. The Relic/vault is never offered as a destination
# (Problem 3) - see ArenaRegions.roamable_nodes_in.

## M4-1 STOP 1 - SEEK_PICKUP (CLAUDE.md M4-1 S10): "if empty and an
## accessible pickup exists, occasionally choose a pickup as a goal."
## PICKUP_SEEK_PROB is deliberately well under 1.0 and this is only ever
## consulted from plain ROAM curiosity (never from SEEK_RELIC's target
## selection, which always returns "VaultFloor" before this function is
## reached) - a bot still spends most of its ROAM cycles on ordinary
## curiosity/environmental picks, exactly the "preserve enough roaming"
## requirement.
const PICKUP_SEEK_PROB := 0.35

func _pick_pickup_target() -> String:
	if pickup_field == null or body.has_method("has_power") and body.has_power():
		return ""
	if pickup_rng.randf() >= PICKUP_SEEK_PROB:
		return ""
	var reachable: Dictionary = graph.reliable_reachable_from(current_node) if current_node != "" else {}
	var candidates: Array = []
	for n in pickup_field.available_nodes():
		if n != current_node and reachable.get(n, false):
			candidates.append(n)
	if candidates.is_empty():
		return ""
	return candidates[pickup_rng.randi_range(0, candidates.size() - 1)]

func _pick_interest_target() -> String:
	var pickup_target := _pick_pickup_target()
	if pickup_target != "":
		return pickup_target
	if not other_bodies.is_empty() and rng.randf() < curiosity_player_prob:
		var idx := rng.randi_range(0, other_bodies.size() - 1)
		var other: CharacterBody2D = other_bodies[idx]
		if is_instance_valid(other) and other.is_on_floor():
			var occ := geometry.canonical_platform(other)
			var occ_region := ArenaRegions.region_of(occ)
			if occ_region != "":
				return _pick_node_in_region(occ_region)
	return _pick_environmental_target()

func _pick_environmental_target() -> String:
	return _pick_node_in_region(_pick_region())

func _pick_region() -> String:
	var candidates := ArenaRegions.REGIONS.duplicate()
	var current_region := ArenaRegions.region_of(current_node)
	if current_node != "":
		var reachable: Dictionary = graph.reliable_reachable_from(current_node)
		var has_reachable_node := func(r: String) -> bool:
			for n in ArenaRegions.roamable_nodes_in(r):
				if reachable.get(n, false):
					return true
			return false
		var reachable_regions: Array = candidates.filter(has_reachable_node)
		if not reachable_regions.is_empty():
			candidates = reachable_regions
	if _force_new_region:
		# Stage3 of the stall ladder: whatever was "nearby" wasn't working -
		# deliberately break out rather than drifting back to a neighbour.
		_force_new_region = false
		var others: Array = candidates.filter(func(r): return r != current_region)
		if not others.is_empty():
			candidates = others
	else:
		# Arena-scale traversal (Problem 4): prefer a destination at least
		# ~2 region-hops away where practical, so roaming reads as crossing
		# the arena (left -> centre -> right, floor -> upper) rather than
		# shuffling between neighbours. Falls back to all regions if none
		# qualify (e.g. current_node not yet known).
		var far: Array = candidates.filter(func(r): return ArenaRegions.region_distance(current_region, r) >= 2)
		if not far.is_empty():
			candidates = far
	candidates.sort_custom(func(a, b): return last_region_visited.get(a, -1) < last_region_visited.get(b, -1))
	# Pool 3, not 1 - with only five regions total, always taking the single
	# least-recently-visited one made independent bots draw the same region
	# at the same time (most visibly right at match start), hurting
	# decorrelation. Still deterministic per bot via the seeded rng.
	var pool_size: int = min(3, candidates.size())
	return candidates[rng.randi_range(0, pool_size - 1)]

func _pick_node_in_region(region: String) -> String:
	var nodes_here := ArenaRegions.roamable_nodes_in(region)
	# Only offer nodes reachable through the RELIABLE subgraph from here
	# (Director report, iteration 5: CoverW kept getting re-picked as a ROAM
	# target - it is a "floor" region member per ArenaRegions, and node
	# selection never checked reachability at all, so it kept looking like
	# the "due" least-recently-visited choice forever, since a bot can never
	# actually visit it to update that timestamp). Excluding unreachable
	# nodes here, not just letting Dijkstra fail after the fact, stops a bot
	# from repeatedly "choosing" a destination it already cannot reach.
	var reachable: Dictionary = graph.reliable_reachable_from(current_node) if current_node != "" else {}
	nodes_here = nodes_here.filter(func(n): return reachable.get(n, false))
	if nodes_here.is_empty():
		# Nothing in this region is reliably reachable from here right now -
		# stay put rather than falling back to a pick Dijkstra would only
		# reject anyway.
		return current_node
	# Exclude the node the bot is already standing on where possible - this
	# was picking itself back fairly often with only 2-3 nodes per region,
	# which _decide_next() then treats as "nothing to do, wander in place"
	# for a full decision cycle. Multiplied over consecutive cycles this
	# produced multi-second stretches that looked like the bot had stopped
	# exploring, even though the overall session still covered every region
	# and band - a real one, just intermittently too passive between hops.
	var away: Array = nodes_here.filter(func(n): return n != current_node)
	if not away.is_empty():
		nodes_here = away
	if nodes_here.is_empty():
		return current_node
	nodes_here.sort_custom(func(a, b): return last_visited.get(a, -1) < last_visited.get(b, -1))
	var pool_size: int = min(2, nodes_here.size())
	return nodes_here[rng.randi_range(0, pool_size - 1)]

func _intra_node_wander() -> void:
	if is_nan(wander_target_x):
		wander_target_x = _random_wander_x(current_node)
	var diff := geometry.shortest_diff(wander_target_x, body.global_position.x)
	if abs(diff) < 24.0:
		horizontal_intent = 0.0
	else:
		horizontal_intent = 1.0 if diff > 0.0 else -1.0

func _random_wander_x(node: String) -> float:
	var aabb := geometry.aabb(node)
	if aabb.is_empty():
		return body.global_position.x
	var margin: float = geometry.player_half_w + 10.0
	var left: float = aabb.left + margin
	var right: float = aabb.right - margin
	if node == "Floor":
		# CoverE is a solid 37px block sitting directly on the Floor,
		# splitting it into two walkable segments at ground level even
		# though it is one nav-graph node (CoverW, the matching west-side
		# block, was removed from Arena 01 - see docs/DECISIONS.md). Without
		# this, a wander target on the far side of CoverE would have the bot
		# walk into it forever - Dijkstra never routes through the Floor->
		# CoverE->Floor hop for a same-node wander target.
		var bounds := _floor_segment_bounds(body.global_position.x, margin)
		left = bounds.x
		right = bounds.y
	if right <= left:
		return float(aabb.center.x)
	return rng.randf_range(left, right)

func _floor_segment_bounds(x: float, margin: float) -> Vector2:
	var floor_aabb := geometry.aabb("Floor")
	var left: float = floor_aabb.left + margin
	var right: float = floor_aabb.right - margin
	var obstacles: Array = []
	if geometry.has("CoverE"):
		obstacles.append(geometry.aabb("CoverE"))
	for o in obstacles:
		if x >= o.left and x <= o.right:
			return Vector2(o.left + margin, o.right - margin)
	for o in obstacles:
		if o.left > x and o.left < right:
			right = min(right, o.left - margin)
		if o.right < x and o.right > left:
			left = max(left, o.right + margin)
	return Vector2(left, right)

func _mark_visited(node: String) -> void:
	visit_counter += 1
	last_visited[node] = visit_counter
	var region := ArenaRegions.region_of(node)
	if region != "":
		region_visit_counter += 1
		last_region_visited[region] = region_visit_counter

func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

# --- RECOVER --------------------------------------------------------------
# Not a hazard respawn - there are no hazards in M3. This is "which platform
# am I actually standing on" re-localisation, entered from stall ladder
# stage3. HARD_RECOVERY_TIMEOUT is intentionally short (1.5s) - RECOVER only
# needs to confirm the bot is on solid, recognised ground, which normally
# resolves within a tick or two since falling always lands somewhere (R9).

func _enter_recover(reason: String) -> void:
	state = State.RECOVER
	recover_timer = 0.0
	print("[BotBrain] slot %d -> RECOVER: %s" % [slot_index, reason])

func _tick_recover(delta: float) -> void:
	recover_timer += delta
	if body.is_on_floor():
		var p := geometry.canonical_platform(body)
		if p != "" and graph.nodes.has(p):
			current_node = p
			_mark_visited(p)
			_resume_roam()
			return
	if recover_timer > HARD_RECOVERY_TIMEOUT:
		_hard_recovery()

func _resume_roam() -> void:
	state = State.ROAM
	path = []
	path_index = 0
	executor = null
	target_node = ""
	_stall_timer = 0.0
	_stall_stage_done = 0
	_stall_check_pos = body.global_position

func _hard_recovery() -> void:
	hard_recovery_count += 1
	print("[BotBrain] slot %d HARD RECOVERY #%d - could not re-localise within %.1fs (bug signal, not normal operation)" % [slot_index, hard_recovery_count, HARD_RECOVERY_TIMEOUT])
	if hard_recovery_callback.is_valid():
		hard_recovery_callback.call(slot_index)
	recover_timer = 0.0
	_resume_roam()
