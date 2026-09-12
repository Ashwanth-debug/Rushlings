extends Node

# M3-2 Step 5 - development-only convergence + fairness telemetry. See
# docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md S14.
#
# Print-based only. No persistence, no files, no database. Reports every
# round; never balances, re-costs or moves anything on its own - that
# decision belongs to the Game Director (S14's closing line).
#
# arena_01.gd sets `arena` after building geometry/nav_graph/brains (this
# node's own _ready() already ran and wired MatchDirector.state_changed by
# then) - everything here reads that back-reference rather than owning a
# duplicate copy of arena state.

@onready var _director: MatchDirector = get_parent().get_node("MatchDirector")
@onready var _relic: Area2D = get_parent().get_node("Relic")

var arena  # Node2D (arena_01.gd) - untyped to avoid a script-preload cycle

var _open_started_at: float = -1.0
var _open_snapshots: Dictionary = {}   # slot_id -> Dictionary (see _snapshot_open)
var _arrival_times: Dictionary = {}    # slot_id -> OPEN-relative seconds of first VaultFloor arrival
var _arrival_doors: Dictionary = {}    # slot_id -> "west"/"east"/"unknown"

## Per-round summaries, accumulated across as many rounds as the caller
## chooses to run (a real play session, or the headless fairness test) -
## nothing here assumes a fixed N. reset_aggregate() clears it for a fresh
## report window.
var round_reports: Array = []

# Roof/header probe (§06): a body standing on the seal strips or the
# permanent VaultGateW header rests with its feet at this y, somewhere
# across the sealed volume's full x-span - matches R9's re-proof origin.
const ROOF_Y := 336.0
const ROOF_X_MIN := 820.0
const ROOF_X_MAX := 1160.0
const ROOF_Y_TOL := 6.0

func _ready() -> void:
	_director.state_changed.connect(_on_state_changed)

func _on_state_changed(new_state: int) -> void:
	if new_state == MatchDirector.State.OPEN:
		_snapshot_open()
	elif new_state == MatchDirector.State.RESULTS:
		_report_round()

func _physics_process(_delta: float) -> void:
	if arena == null or _director.state != MatchDirector.State.OPEN:
		return
	for p in arena.players:
		if _arrival_times.has(p.slot_id):
			continue
		if arena.geometry.canonical_platform(p) != "VaultFloor":
			continue
		var elapsed: float = _director.clock - _open_started_at
		_arrival_times[p.slot_id] = elapsed
		_arrival_doors[p.slot_id] = _door_for_slot(p.slot_id, p)
		print("[MatchTelemetry] slot %d reached VaultFloor at OPEN+%.2fs via %s door" % [p.slot_id, elapsed, _arrival_doors[p.slot_id]])

## "Door used - inferred from the last edge taken for a bot, from entry x for
## the human (<960 = west)" (S14).
func _door_for_slot(slot_id: int, body: CharacterBody2D) -> String:
	var idx := slot_id - 1
	if idx >= 0 and idx < arena.brains.size() and arena.brains[idx] != null:
		var d: String = arena.brains[idx].last_relic_door
		return d if d != "" else "unknown"
	return "west" if body.global_position.x < 960.0 else "east"

func _standing_on_seal(body: CharacterBody2D) -> bool:
	if not body.is_on_floor():
		return false
	var feet_y: float = body.global_position.y + arena.geometry.player_half_h
	if abs(feet_y - ROOF_Y) > ROOF_Y_TOL:
		return false
	return body.global_position.x >= ROOF_X_MIN and body.global_position.x <= ROOF_X_MAX

## Dijkstra route cost to VaultFloor under NEUTRAL weights (no per-bot
## edge_type_weight/level_change_penalty/blacklist penalty) - comparable
## across slots, unlike each bot's own _weighted_cost (S14: "unlike each
## bot's own weighted cost"). Still excludes SKILL/INVALID and (if closed)
## gated edges, matching what ordinary bot routing can actually use.
func _neutral_cost_to_vault(node: String) -> float:
	if node == "":
		return INF
	if node == "VaultFloor":
		return 0.0
	var neutral_cost := func(e: Dictionary) -> float:
		if e.get("route_class", NavGraph.RouteClass.RELIABLE) != NavGraph.RouteClass.RELIABLE:
			return INF
		if e.get("gated", false) and not arena.nav_graph.gate_open:
			return INF
		return float(e.cost)
	var path: Array = NavPath.shortest_path(arena.nav_graph, node, "VaultFloor", neutral_cost)
	if path.is_empty():
		return INF
	var total := 0.0
	for e in path:
		total += float(e.cost)
	return total

func _snapshot_open() -> void:
	_open_started_at = _director.clock
	_open_snapshots.clear()
	_arrival_times.clear()
	_arrival_doors.clear()
	if arena == null:
		return
	print("[MatchTelemetry] === OPEN snapshot (clock=%.2fs) ===" % _open_started_at)
	for p in arena.players:
		var node: String = arena.geometry.canonical_platform(p)
		var region: String = ArenaRegions.region_of(node) if node != "" else ""
		var cost: float = _neutral_cost_to_vault(node)
		var wrap_dist: float = abs(arena.geometry.shortest_diff(_relic.global_position.x, p.global_position.x))
		var on_seal: bool = _standing_on_seal(p)
		_open_snapshots[p.slot_id] = {
			"node": node if node != "" else "air", "pos": p.global_position,
			"region": region, "cost": cost, "wrap_dist": wrap_dist, "on_seal": on_seal,
		}
		print("[MatchTelemetry]   slot %d: node=%s region=%s neutral_cost=%s wrap_dist=%.0f on_seal=%s" % [
			p.slot_id, _open_snapshots[p.slot_id].node, region,
			("inf" if cost == INF else "%.2f" % cost), wrap_dist, on_seal
		])

func _report_round() -> void:
	if arena == null:
		return
	var winner_slot: int = _director.winner_slot_id
	var elapsed: float = _director.clock - _open_started_at
	var lowest_cost_slot := -1
	var lowest_cost := INF
	for slot in _open_snapshots:
		var c: float = _open_snapshots[slot].cost
		if c < lowest_cost:
			lowest_cost = c
			lowest_cost_slot = slot
	var winner_snapshot: Dictionary = _open_snapshots.get(winner_slot, {})
	var winner_had_lowest_cost: bool = winner_slot == lowest_cost_slot
	var winner_on_seal: bool = winner_snapshot.get("on_seal", false)
	var winner_door: String = _arrival_doors.get(winner_slot, "unknown")
	var arrival_order: Array = _arrival_times.keys()
	arrival_order.sort_custom(func(a, b): return _arrival_times[a] < _arrival_times[b])
	var report := {
		"winner": winner_slot, "open_to_win": elapsed, "door": winner_door,
		"winner_lowest_cost": winner_had_lowest_cost, "winner_on_seal": winner_on_seal,
		"arrival_order": arrival_order.duplicate(),
		"arrival_times": _arrival_times.duplicate(), "arrival_doors": _arrival_doors.duplicate(),
		"snapshots": _open_snapshots.duplicate(true),
	}
	round_reports.append(report)
	print("[MatchTelemetry] ROUND RESULT: winner=P%d open->win=%.2fs door=%s nearest_at_open=%s winner_on_seal=%s arrival_order=%s" % [
		winner_slot, elapsed, winner_door, winner_had_lowest_cost, winner_on_seal,
		str(arrival_order.map(func(s): return "P%d" % s))
	])

func reset_aggregate() -> void:
	round_reports = []

## Prints the §14 aggregate table over every round recorded since the last
## reset_aggregate(). Flags are diagnostic only - printed for the Game
## Director's attention, never acted on automatically.
func print_aggregate_report(non_terminating: int = 0, hard_recoveries: int = 0) -> void:
	var n := round_reports.size()
	print("\n=== M3-2 Fairness Report (%d round%s) ===" % [n, "" if n == 1 else "s"])
	if n == 0:
		print("No rounds recorded.")
		return

	var wins_by_slot: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0}
	var door_counts: Dictionary = {"west": 0, "east": 0, "unknown": 0}
	var nearest_wins := 0
	var seal_wins := 0
	var open_to_win: Array = []
	var first_arrivals: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0}

	for r in round_reports:
		wins_by_slot[r.winner] = wins_by_slot.get(r.winner, 0) + 1
		if r.winner_lowest_cost:
			nearest_wins += 1
		if r.winner_on_seal:
			seal_wins += 1
		open_to_win.append(r.open_to_win)
		for slot in r.arrival_doors:
			var d: String = r.arrival_doors[slot]
			door_counts[d] = door_counts.get(d, 0) + 1
		if not r.arrival_order.is_empty():
			var first: int = r.arrival_order[0]
			first_arrivals[first] = first_arrivals.get(first, 0) + 1

	open_to_win.sort()
	var median: float = open_to_win[open_to_win.size() / 2] if open_to_win.size() % 2 == 1 else (open_to_win[open_to_win.size() / 2 - 1] + open_to_win[open_to_win.size() / 2]) * 0.5
	var mn: float = open_to_win[0]
	var mx: float = open_to_win[open_to_win.size() - 1]

	print("Wins by slot:")
	var top_win_frac := 0.0
	for slot in [1, 2, 3, 4]:
		var frac: float = float(wins_by_slot[slot]) / float(n)
		top_win_frac = max(top_win_frac, frac)
		print("  P%d: %d/%d (%.1f%%)" % [slot, wins_by_slot[slot], n, frac * 100.0])

	var door_total: int = door_counts["west"] + door_counts["east"] + door_counts["unknown"]
	var top_door_frac := 0.0
	print("Door usage (all arrivals, not just winners):")
	for d in ["west", "east", "unknown"]:
		var frac: float = float(door_counts[d]) / float(max(door_total, 1))
		if d != "unknown":
			top_door_frac = max(top_door_frac, frac)
		print("  %s: %d/%d (%.1f%%)" % [d, door_counts[d], door_total, frac * 100.0])

	var nearest_frac: float = float(nearest_wins) / float(n)
	var seal_frac: float = float(seal_wins) / float(n)
	print("Nearest-at-OPEN win rate: %d/%d (%.1f%%)" % [nearest_wins, n, nearest_frac * 100.0])
	print("Roof/seal-camp win rate: %d/%d (%.1f%%)" % [seal_wins, n, seal_frac * 100.0])
	print("OPEN->win: median=%.2fs min=%.2fs max=%.2fs" % [median, mn, mx])
	print("First-arrival-at-VaultFloor pattern (who converges first):")
	for slot in [1, 2, 3, 4]:
		print("  P%d first: %d/%d rounds" % [slot, first_arrivals[slot], n])
	print("Non-terminating rounds: %d" % non_terminating)
	print("Hard recoveries across all rounds: %d" % hard_recoveries)

	print("\n-- Diagnostic flags (report only, never auto-corrected) --")
	_flag("slot dominance (>50% wins by one slot)", top_win_frac > 0.5, "%.1f%%" % (top_win_frac * 100.0))
	_flag("door monoculture (>90% one door)", top_door_frac > 0.9, "%.1f%%" % (top_door_frac * 100.0))
	_flag("decided-at-OPEN (nearest-at-OPEN wins >80%)", nearest_frac > 0.8, "%.1f%%" % (nearest_frac * 100.0))
	_flag("anticlimax (median OPEN->win <1.5s)", median < 1.5, "%.2fs" % median)
	_flag("convergence failure (median OPEN->win >12s)", median > 12.0, "%.2fs" % median)
	_flag("non-terminating rounds present", non_terminating > 0, "%d" % non_terminating)
	print("=== end fairness report ===\n")

func _flag(label: String, triggered: bool, detail: String) -> void:
	print("  [%s] %s (%s)" % ["FLAG" if triggered else "ok  ", label, detail])
