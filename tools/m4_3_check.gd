extends SceneTree

# M4-3 "The Climax" - focused automated checks for Relic carry
# (scripts/relic.gd), extraction selection/locking (scripts/extraction_system.gd,
# scripts/extraction_anchor.gd), Mine (scripts/mine.gd), and their
# interaction with the existing M4-1/M4-2 Contact + hazard systems. Run
# headless:
#   godot --headless --path . --script tools/m4_3_check.gd
#
# Same convention every earlier M4 checker already established: load the
# real arena_01.tscn, drive it directly, deterministic PASS/FAIL sections
# first, a diagnostic bot-only round soak last (report only, never gates
# PASS/FAIL, never auto-balanced from).
#
# Deliberately separate from arena_check/m3_check/m4_1_check/m4_2_check,
# which must all still pass unmodified and ungated by anything here - every
# M4-3 system is dormant/inert unless this tool (or a human via
# debug_climax_lab) explicitly exercises it.

const ARENA_SCENE_PATH := "res://scenes/arena_01/arena_01.tscn"
const PowerTypeScript := preload("res://scripts/power_type.gd")
const HealthSystemScript := preload("res://scripts/health_system.gd")

var arena: Node2D
var fails: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== M4-3 The Climax: Relic carry / extraction / Mine checks ===\n")
	arena = (load(ARENA_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(arena)
	await physics_frame
	await physics_frame

	await _test_relic_world_to_carrier()
	await _test_relic_never_two_carriers()
	await _test_relic_carrier_defeat_drops()
	await _test_relic_dropped_to_new_carrier()
	await _test_extraction_selection()
	await _test_extraction_locked_through_events()
	await _test_win_condition()
	await _test_defeat_relic_and_power_independent()
	await _test_mine()
	await _test_rematch_clean_state()
	await _diagnostic_climax_soak()

	arena.set_hazards_armed(false)
	root.remove_child(arena)
	arena.queue_free()

	print("\n=== SUMMARY ===")
	print("Failures: %d" % fails.size())
	for f in fails:
		print("  [%s] %s" % [f.category, f.detail])
	print("RESULT: %s" % ("PASS" if fails.is_empty() else "FAIL"))
	quit(1 if not fails.is_empty() else 0)

func _report(category: String, label: String, ok: bool, detail: String) -> void:
	var verdict := "PASS" if ok else "FAIL"
	print("[%s] %-52s %s   %s" % [category, label, verdict, detail])
	if not ok:
		fails.append({"category": category, "detail": "%s - %s" % [label, detail]})

func _settle(frames: int = 3) -> void:
	for _i in range(frames):
		await physics_frame

func physics_ticks_per_second() -> float:
	return float(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60))

## Same reasoning as tools/m4_2_check.gd's own helper: gravity=0 so a test
## body plants exactly where placed instead of drifting off a tight overlap
## rectangle before the next assertion. Deliberately does NOT touch
## is_carrying_relic directly - only scripts/relic.gd's own
## reset_to_pedestal()/drop_at() may clear that flag, or arena.relic's own
## carrier_slot_id would desync from reality (a stale "someone is carrying"
## lock that nothing could ever clear again). _force_fresh_open() at the
## start of each test section is what actually guarantees a clean Relic
## state, exactly like it already does for MatchDirector/extraction/goals.
func _reset_player_for_test(p: CharacterBody2D, pos: Vector2) -> void:
	p.reset_to(pos)
	p.velocity = Vector2.ZERO
	p.gravity = 0.0
	p.set_defeated(false)
	p.reset_health()
	p.set_spawn_protected(false)
	p.consume_power()
	arena.health_system._defeat_timers.erase(p)
	arena.health_system._protection_timers.erase(p)
	arena.health_system._reaction_timers.erase(p)
	arena.health_system._reaction_sources.erase(p)
	arena.power_system.clear_freeze(p)

const REAL_GRAVITY := 2200.0

func _restore_gravity() -> void:
	for p in arena.players:
		p.gravity = REAL_GRAVITY

func _clear_field(keep: Array) -> void:
	for p in arena.players:
		if not keep.has(p):
			_reset_player_for_test(p, Vector2(960, -2000))
			p.controller.set_frozen(true)

## Fresh round, straight to OPEN, no timers/UNLOCKING wait - same shape as
## a human pressing debug_toggle_gate (G) from SETUP, and what
## debug_climax_lab itself does. reset_round() cascades to relic.gd's own
## state_changed listener (reset_to_pedestal) and arena_01.gd's SETUP
## handler (extraction_system.reset(), bot reset_goal()) for free.
func _force_fresh_open() -> void:
	arena.match_director.reset_round()
	arena.match_director.debug_force_open()

## Deterministic tests must never race a live bot to a shared Relic/hazard/
## anchor - but reset_round()'s own SETUP transition unconditionally
## unfreezes EVERY controller (arena_01.gd's _on_match_state_changed(), the
## same "un-freeze on any transition back to SETUP" rule RESULTS relies on),
## undoing whatever _clear_field() froze before this call. Re-freeze
## immediately after for every deterministic test below; the diagnostic
## soak calls the bare _force_fresh_open() above and unfreezes bots
## deliberately, since it NEEDS live bot play.
func _force_fresh_open_frozen() -> void:
	_force_fresh_open()
	for p in arena.players:
		p.controller.set_frozen(true)

func _wait_for_defeated(target: CharacterBody2D, extra_budget_s: float = 1.0) -> void:
	var hz: float = physics_ticks_per_second()
	var max_frames := int((arena.health_system.reaction_duration + extra_budget_s) * hz)
	var frames := 0
	while target.is_dying and not target.is_defeated and frames < max_frames:
		await physics_frame
		frames += 1

# --- 1: Relic world -> carrier -----------------------------------------------

func _test_relic_world_to_carrier() -> void:
	print("\n--- Relic: world -> carrier on touch, only while OPEN ---")
	_clear_field([])
	_force_fresh_open_frozen()
	await _settle(2)
	_report("RELIC", "no carrier before any pickup", arena.relic.carrier_slot_id == -1, "carrier_slot_id=%d" % arena.relic.carrier_slot_id)
	_report("RELIC", "Relic is world-active (visible+monitoring) once OPEN", arena.relic.is_world_active(), "is_world_active=%s" % arena.relic.is_world_active())

	var p1: CharacterBody2D = arena.players[0]
	_reset_player_for_test(p1, arena.relic.global_position)
	await _settle(5)
	_report("RELIC", "touching the Relic makes the toucher the carrier", arena.relic.carrier_slot_id == 1, "carrier_slot_id=%d" % arena.relic.carrier_slot_id)
	_report("RELIC", "the carrier's own is_carrying_relic flag is set", p1.is_carrying_relic, "is_carrying_relic=%s" % p1.is_carrying_relic)
	_report("RELIC", "the world Relic hides once carried (never both world+carrier)", not arena.relic.visible and not arena.relic.is_world_active(), "visible=%s is_world_active=%s" % [arena.relic.visible, arena.relic.is_world_active()])
	_reset_player_for_test(p1, Vector2(960, -2000))

func _test_relic_never_two_carriers() -> void:
	print("\n--- Relic: simultaneous touch resolves to exactly one carrier ---")
	_clear_field([])
	_force_fresh_open_frozen()
	await _settle(2)
	var p1: CharacterBody2D = arena.players[0]
	var p2: CharacterBody2D = arena.players[1]
	_reset_player_for_test(p1, arena.relic.global_position + Vector2(-4, 0))
	_reset_player_for_test(p2, arena.relic.global_position + Vector2(4, 0))
	await _settle(5)
	var exactly_one: bool = p1.is_carrying_relic != p2.is_carrying_relic
	_report("RELIC", "a simultaneous double-touch still resolves to exactly one carrier", exactly_one, "P1.is_carrying_relic=%s P2.is_carrying_relic=%s carrier_slot_id=%d" % [p1.is_carrying_relic, p2.is_carrying_relic, arena.relic.carrier_slot_id])
	_reset_player_for_test(p1, Vector2(960, -2000))
	_reset_player_for_test(p2, Vector2(960, -2000))

# --- 2: carrier defeat drops the Relic --------------------------------------

func _test_relic_carrier_defeat_drops() -> void:
	print("\n--- Relic: a defeated carrier drops it at the defeat position, extraction unaffected ---")
	_clear_field([])
	_force_fresh_open_frozen()
	await _settle(2)
	var p1: CharacterBody2D = arena.players[0]
	_reset_player_for_test(p1, arena.relic.global_position)
	await _settle(5)
	_report("RELIC-DROP", "setup: P1 is carrier before defeat", p1.is_carrying_relic, "is_carrying_relic=%s" % p1.is_carrying_relic)

	# Pin down a real region/node so extraction has something to select.
	arena.extraction_system.on_relic_picked_up(1)
	var locked_region: String = arena.extraction_system.active_region
	var locked_node: String = arena.extraction_system.active_node

	arena.health_system.apply_damage(p1)
	arena.health_system.apply_damage(p1)
	arena.health_system.apply_damage(p1)
	await _wait_for_defeated(p1)
	await _settle(int(arena.health_system.defeat_duration * physics_ticks_per_second()) + 10)

	_report("RELIC-DROP", "defeated carrier no longer carries the Relic", not p1.is_carrying_relic, "is_carrying_relic=%s" % p1.is_carrying_relic)
	_report("RELIC-DROP", "Relic re-enters the world (visible+monitoring) after the drop", arena.relic.is_world_active(), "is_world_active=%s" % arena.relic.is_world_active())
	_report("RELIC-DROP", "no carrier once dropped", arena.relic.carrier_slot_id == -1, "carrier_slot_id=%d" % arena.relic.carrier_slot_id)
	_report("RELIC-DROP", "extraction selection is unchanged by the drop", arena.extraction_system.active_region == locked_region and arena.extraction_system.active_node == locked_node, "region=%s (was %s) node=%s (was %s)" % [arena.extraction_system.active_region, locked_region, arena.extraction_system.active_node, locked_node])
	_reset_player_for_test(p1, Vector2(960, -2000))

func _test_relic_dropped_to_new_carrier() -> void:
	print("\n--- Relic: a dropped Relic is collectible by a different player, extraction still unchanged ---")
	var locked_region: String = arena.extraction_system.active_region
	var locked_node: String = arena.extraction_system.active_node
	var drop_pos: Vector2 = arena.relic.global_position
	var p2: CharacterBody2D = arena.players[1]
	_reset_player_for_test(p2, drop_pos)
	await _settle(5)
	_report("RELIC-DROP", "a different player becomes the new carrier of the dropped Relic", p2.is_carrying_relic and arena.relic.carrier_slot_id == 2, "P2.is_carrying_relic=%s carrier_slot_id=%d" % [p2.is_carrying_relic, arena.relic.carrier_slot_id])
	_report("RELIC-DROP", "extraction selection still unchanged by the new pickup", arena.extraction_system.active_region == locked_region and arena.extraction_system.active_node == locked_node, "region=%s (was %s) node=%s (was %s)" % [arena.extraction_system.active_region, locked_region, arena.extraction_system.active_node, locked_node])
	_reset_player_for_test(p2, Vector2(960, -2000))

# --- 3: extraction selection -------------------------------------------------

func _test_extraction_selection() -> void:
	print("\n--- Extraction: locked exactly once, at maximum region-distance, valid/reachable ---")
	_clear_field([])
	_force_fresh_open_frozen()
	await _settle(2)
	_report("EXTRACTION", "no extraction selected before the first pickup", not arena.extraction_system.locked, "locked=%s" % arena.extraction_system.locked)
	for a in arena.extraction_system.anchors:
		_report("EXTRACTION", "%s starts dormant (inactive, hidden)" % a.name, not a.active and not a.visible, "active=%s visible=%s" % [a.active, a.visible])

	# Drive a real pickup at the vault pedestal (region "central").
	var p1: CharacterBody2D = arena.players[0]
	_reset_player_for_test(p1, arena.relic.global_position)
	await _settle(5)
	_report("EXTRACTION", "exactly one selection happens on the first pickup", arena.extraction_system.locked, "locked=%s" % arena.extraction_system.locked)
	var active_count := 0
	for a in arena.extraction_system.anchors:
		if a.active:
			active_count += 1
	_report("EXTRACTION", "exactly one anchor is active after selection", active_count == 1, "active_count=%d" % active_count)
	_report("EXTRACTION", "selection is a valid authored region", ArenaRegions.REGIONS.has(arena.extraction_system.active_region), "active_region='%s'" % arena.extraction_system.active_region)
	_report("EXTRACTION", "selected anchor's nav_node is a real graph node", arena.nav_graph.nodes.has(arena.extraction_system.active_node), "active_node='%s'" % arena.extraction_system.active_node)
	var reachable: Dictionary = arena.nav_graph.reliable_reachable_from("Floor")
	_report("EXTRACTION", "selected anchor's nav_node is RELIABLE-reachable from Floor (never a SKILL-only destination)", reachable.get(arena.extraction_system.active_node, false), "active_node='%s' reachable_from_Floor=%s" % [arena.extraction_system.active_node, reachable.get(arena.extraction_system.active_node, false)])
	# A vault (central) grab must select at MAXIMUM region-distance - per
	# docs/GAME_DESIGN.md S8A's table, that is west or seam (distance 2).
	var d: int = ArenaRegions.region_distance("central", arena.extraction_system.active_region)
	_report("EXTRACTION", "a central (vault) grab selects an anchor at maximum region-distance (2)", d == 2, "carrier_region=central chosen_region=%s distance=%d" % [arena.extraction_system.active_region, d])
	_reset_player_for_test(p1, Vector2(960, -2000))

	# Deterministic for the same round seed/state: same carrier region + same
	# seed -> same selection, run twice on a throwaway configuration.
	var seed_val: int = arena.extraction_system.round_seed
	arena.extraction_system.reset()
	arena.extraction_system.round_seed = seed_val
	arena.extraction_system._select_extraction("central")
	var first_pick: String = arena.extraction_system.active_region
	arena.extraction_system.reset()
	arena.extraction_system.round_seed = seed_val
	arena.extraction_system._select_extraction("central")
	var second_pick: String = arena.extraction_system.active_region
	_report("EXTRACTION", "selection is deterministic for the same round seed + carrier region", first_pick == second_pick, "first=%s second=%s (seed=%d)" % [first_pick, second_pick, seed_val])

func _test_extraction_locked_through_events() -> void:
	print("\n--- Extraction: locked through ownership churn, resets next round ---")
	_clear_field([])
	_force_fresh_open_frozen()
	await _settle(2)
	var p1: CharacterBody2D = arena.players[0]
	var p2: CharacterBody2D = arena.players[1]
	_reset_player_for_test(p1, arena.relic.global_position)
	await _settle(5)
	var locked_region: String = arena.extraction_system.active_region

	# Ownership churn: P1 defeated -> P2 grabs the drop -> P2 defeated.
	arena.health_system.apply_damage(p1)
	arena.health_system.apply_damage(p1)
	arena.health_system.apply_damage(p1)
	await _wait_for_defeated(p1)
	await _settle(int(arena.health_system.defeat_duration * physics_ticks_per_second()) + 10)
	_reset_player_for_test(p2, arena.relic.global_position)
	await _settle(5)
	_report("EXTRACTION", "extraction unchanged after P1 defeat + drop", arena.extraction_system.active_region == locked_region, "region=%s (was %s)" % [arena.extraction_system.active_region, locked_region])
	arena.health_system.apply_damage(p2)
	arena.health_system.apply_damage(p2)
	arena.health_system.apply_damage(p2)
	await _wait_for_defeated(p2)
	await _settle(int(arena.health_system.defeat_duration * physics_ticks_per_second()) + 10)
	_report("EXTRACTION", "extraction unchanged after a second ownership change + defeat", arena.extraction_system.active_region == locked_region, "region=%s (was %s)" % [arena.extraction_system.active_region, locked_region])
	_reset_player_for_test(p1, Vector2(960, -2000))
	_reset_player_for_test(p2, Vector2(960, -2000))

	# Resets next round.
	arena.match_director.reset_round()
	await _settle(2)
	_report("EXTRACTION", "resets to unlocked at the start of a new round", not arena.extraction_system.locked and arena.extraction_system.active_region == "", "locked=%s active_region='%s'" % [arena.extraction_system.locked, arena.extraction_system.active_region])

# --- 4: win condition ---------------------------------------------------------

func _test_win_condition() -> void:
	print("\n--- Win: only the carrier entering the LOCKED extraction wins ---")
	_clear_field([])
	_force_fresh_open_frozen()
	await _settle(2)
	var p1: CharacterBody2D = arena.players[0]
	var p2: CharacterBody2D = arena.players[1]
	_reset_player_for_test(p1, arena.relic.global_position)
	await _settle(5)
	var anchor = arena.extraction_system.active_anchor
	_report("WIN", "setup: an extraction anchor is active", anchor != null, "active_anchor=%s" % anchor)

	# Non-carrier entering the extraction cannot win.
	_reset_player_for_test(p2, anchor.global_position)
	await _settle(5)
	_report("WIN", "a non-carrier standing in the active extraction does not win", arena.match_director.state == MatchDirector.State.OPEN, "state=%d" % arena.match_director.state)
	_reset_player_for_test(p2, Vector2(960, -2000))

	# The carrier entering the extraction wins.
	p1.gravity = 0.0
	p1.global_position = anchor.global_position
	p1.velocity = Vector2.ZERO
	await _settle(5)
	_report("WIN", "the carrier entering the active extraction wins (RESULTS)", arena.match_director.state == MatchDirector.State.RESULTS, "state=%d" % arena.match_director.state)
	_report("WIN", "the correct slot is recorded as winner", arena.match_director.winner_slot_id == 1, "winner_slot_id=%d" % arena.match_director.winner_slot_id)
	arena.match_director.reset_round()
	await _settle(2)
	_reset_player_for_test(p1, Vector2(960, -2000))

# --- 5: defeat - Relic drop and power spill stay independent -----------------

func _test_defeat_relic_and_power_independent() -> void:
	print("\n--- Defeat: Relic drop and power spill are independent, both can happen from the same defeat ---")
	_clear_field([])
	_force_fresh_open_frozen()
	await _settle(2)
	var p1: CharacterBody2D = arena.players[0]
	_reset_player_for_test(p1, arena.relic.global_position)
	await _settle(5)
	p1.receive_power(PowerTypeScript.Type.PUSH)
	_report("DEFEAT-INDEPENDENT", "setup: carrying both the Relic and a power before defeat", p1.is_carrying_relic and p1.has_power(), "is_carrying_relic=%s has_power=%s" % [p1.is_carrying_relic, p1.has_power()])

	var pickups_before: int = arena._pickups_container.get_child_count()
	arena.health_system.apply_damage(p1)
	arena.health_system.apply_damage(p1)
	arena.health_system.apply_damage(p1)
	_report("DEFEAT-INDEPENDENT", "reaction window: still visible, still holding both the Relic and the power", p1.is_dying and p1.visible and p1.is_carrying_relic and p1.has_power(), "is_dying=%s visible=%s is_carrying_relic=%s has_power=%s" % [p1.is_dying, p1.visible, p1.is_carrying_relic, p1.has_power()])
	await _wait_for_defeated(p1)
	_report("DEFEAT-INDEPENDENT", "once resolved: Relic dropped AND power spilled as two separate world objects", not p1.is_carrying_relic and not p1.has_power(), "is_carrying_relic=%s has_power=%s" % [p1.is_carrying_relic, p1.has_power()])
	var pickups_after: int = arena._pickups_container.get_child_count()
	_report("DEFEAT-INDEPENDENT", "a new spilled power pickup was created (separate from the Relic)", pickups_after > pickups_before, "pickups_before=%d pickups_after=%d" % [pickups_before, pickups_after])
	_report("DEFEAT-INDEPENDENT", "the Relic itself is a separate world object, not merged with the spilled power", arena.relic.is_world_active(), "relic.is_world_active=%s" % arena.relic.is_world_active())

	await _settle(int(arena.health_system.defeat_duration * physics_ticks_per_second()) + 10)
	_report("DEFEAT-INDEPENDENT", "respawns clean: not defeated, not dying, full health, no Relic, no power", not p1.is_defeated and not p1.is_dying and p1.health == p1.max_health and not p1.is_carrying_relic and not p1.has_power(), "is_defeated=%s is_dying=%s health=%d is_carrying_relic=%s has_power=%s" % [p1.is_defeated, p1.is_dying, p1.health, p1.is_carrying_relic, p1.has_power()])
	_reset_player_for_test(p1, Vector2(960, -2000))

# --- 6: Mine -------------------------------------------------------------------

func _test_mine() -> void:
	print("\n--- Mine: place consumes once, owner-immunity window, another player triggers it, exactly 1 pip, clears ---")
	_clear_field([])
	var p1: CharacterBody2D = arena.players[0]
	var p2: CharacterBody2D = arena.players[1]
	_reset_player_for_test(p1, Vector2(500, 500))
	_reset_player_for_test(p2, Vector2(2000, -500))  # far away, out of the way

	var mines_before := _count_mines()
	p1.receive_power(PowerTypeScript.Type.MINE)
	var used: bool = arena.power_system.try_activate(p1)
	_report("MINE", "placing a Mine is always a valid activation", used, "used=%s" % used)
	_report("MINE", "placing consumes the carried Mine exactly once (empty after use)", not p1.has_power(), "carried_power=%d" % p1.carried_power)
	var mines_after := _count_mines()
	_report("MINE", "exactly one Mine object now exists in the world", mines_after == mines_before + 1, "mines_before=%d mines_after=%d" % [mines_before, mines_after])

	# Owner-immunity window: P1 stays on top of its own freshly-placed mine
	# and must not immediately trigger it.
	await _settle(4)
	_report("MINE", "owner does not immediately trigger their own newly-placed mine", p1.health == p1.max_health and _count_mines() == mines_before + 1, "P1.health=%d/%d mines=%d" % [p1.health, p1.max_health, _count_mines()])

	# Another player triggers it once the arm delay has elapsed.
	var mine: Node = _find_first_mine()
	var hz := physics_ticks_per_second()
	await _settle(int(mine.ARM_DELAY * hz) + 4)
	p2.reset_to(mine.global_position)
	p2.velocity = Vector2.ZERO
	p2.gravity = 0.0
	await _settle(5)
	_report("MINE", "a different player triggers the armed mine", p2.health == p2.max_health - 1, "P2.health=%d/%d" % [p2.health, p2.max_health])
	_report("MINE", "exactly 1 pip of damage, not more", p2.health == p2.max_health - 1, "P2.health=%d/%d" % [p2.health, p2.max_health])
	_report("MINE", "the mine clears itself once triggered", _count_mines() == mines_before, "mines_remaining=%d" % _count_mines())
	_reset_player_for_test(p1, Vector2(960, -2000))
	_reset_player_for_test(p2, Vector2(960, -2000))

	# Mine can be lethal, through the same defeat pipeline as every other
	# damage source.
	var p3: CharacterBody2D = arena.players[2]
	_reset_player_for_test(p3, Vector2(500, 500))
	arena.health_system.apply_damage(p3)
	arena.health_system.apply_damage(p3)
	_report("MINE-LETHAL", "setup: P3 at Critical (1 health) before the mine's killing hit", p3.health == 1, "health=%d" % p3.health)
	p3.receive_power(PowerTypeScript.Type.MINE)
	arena.power_system.try_activate(p3)
	var mine2: Node = _find_first_mine()
	await _settle(int(mine2.ARM_DELAY * hz) + 4)
	var p4: CharacterBody2D = arena.players[3]
	_reset_player_for_test(p4, mine2.global_position)
	await _settle(4)
	_report("MINE-LETHAL", "a mine's killing hit opens the reaction window (is_dying, not yet Defeated)", p4.is_dying and not p4.is_defeated and p4.health == 0, "is_dying=%s is_defeated=%s health=%d" % [p4.is_dying, p4.is_defeated, p4.health])
	await _wait_for_defeated(p4)
	_report("MINE-LETHAL", "a mine can cause Defeated through the same pipeline as every other power", p4.is_defeated and p4.health == 0, "is_defeated=%s health=%d" % [p4.is_defeated, p4.health])
	await _settle(int(arena.health_system.defeat_duration * hz) + 10)
	_report("MINE-LETHAL", "respawns cleanly", not p4.is_defeated and not p4.is_dying and p4.health == p4.max_health, "is_defeated=%s is_dying=%s health=%d" % [p4.is_defeated, p4.is_dying, p4.health])
	_reset_player_for_test(p3, Vector2(960, -2000))
	_reset_player_for_test(p4, Vector2(960, -2000))

func _count_mines() -> int:
	var n := 0
	for child in arena._projectiles_container.get_children():
		if child.has_method("setup") and child.has_signal("mine_triggered"):
			n += 1
	return n

func _find_first_mine() -> Node:
	for child in arena._projectiles_container.get_children():
		if child.has_method("setup") and child.has_signal("mine_triggered"):
			return child
	return null

# --- 7: rematch leaves no stale state ----------------------------------------

func _test_rematch_clean_state() -> void:
	print("\n--- Rematch: no stale carrier, extraction, dropped Relic, or Mine across rounds ---")
	for round_i in range(3):
		# _full_reset() (end of the previous iteration, or arena_01.gd's own
		# _ready() for round 0) hands every bot a brand-new, UNFROZEN
		# BotController - must re-clear/re-freeze every round, not just once
		# before the loop, or a live bot could reach the Relic during the
		# settle window below before this round's own assertions run.
		_clear_field([])
		_force_fresh_open_frozen()
		await _settle(2)
		_report("REMATCH", "round %d: no stale carrier at round start" % round_i, arena.relic.carrier_slot_id == -1 and not _any_player_carrying(), "carrier_slot_id=%d any_carrying=%s" % [arena.relic.carrier_slot_id, _any_player_carrying()])
		_report("REMATCH", "round %d: no stale extraction lock at round start" % round_i, not arena.extraction_system.locked, "locked=%s" % arena.extraction_system.locked)
		_report("REMATCH", "round %d: Relic is back at the pedestal position, uncarried" % round_i, arena.relic.global_position.distance_to(arena.relic._pedestal_position) < 1.0 and arena.relic.carrier_slot_id == -1, "position=%s pedestal=%s carrier_slot_id=%d" % [arena.relic.global_position, arena.relic._pedestal_position, arena.relic.carrier_slot_id])

		var p1: CharacterBody2D = arena.players[0]
		_reset_player_for_test(p1, arena.relic.global_position)
		await _settle(5)
		p1.receive_power(PowerTypeScript.Type.MINE)
		arena.power_system.try_activate(p1)
		_report("REMATCH", "round %d: a mine was placed this round" % round_i, _count_mines() >= 1, "mines=%d" % _count_mines())
		_reset_player_for_test(p1, Vector2(960, -2000))
		arena._full_reset()
		await _settle(3)
	_report("REMATCH", "no stale Mine survives a rematch (power_system.reset() clears the projectile container)", _count_mines() == 0, "mines_remaining=%d" % _count_mines())
	_report("REMATCH", "no stale dropped-Relic nav_node survives a rematch", arena.relic.nav_node == "VaultFloor", "nav_node='%s'" % arena.relic.nav_node)

func _any_player_carrying() -> bool:
	for p in arena.players:
		if p.is_carrying_relic:
			return true
	return false

# --- 8: diagnostic bot-only Climax soak (not gating PASS/FAIL) --------------

func _diagnostic_climax_soak() -> void:
	print("\n--- Diagnostic: 20-round bot-driven Climax soak (real Contact + hazard + carry/extraction/Mine systems, not asserted) ---")
	const ROUNDS := 20
	# 90s proved too tight in this tool's own development: a full round now
	# means grab AND carry across the whole arena (not just reach the
	# vault), under armed hazards - and the pre-existing Floor->C_M
	# fixed-trigger recipe (nav_graph.gd's own documented "known-limitations"
	# route, unrelated to anything M4-3 changed) degrades further when a bot
	# is also reacting to a nearby armed hazard mid-approach. 180s matches
	# tools/m4_2_check.gd's own hazard-soak duration precedent.
	const ROUND_TIMEOUT := 180.0
	# _clear_field() itself calls _reset_player_for_test() on every player
	# (keep=[]), which sets gravity=0.0 as part of its own deterministic-test
	# cleanup - _restore_gravity() MUST run AFTER _clear_field(), not before,
	# or _clear_field() immediately zeroes it right back out. Found during
	# this tool's own development: with gravity silently left at 0 for the
	# whole soak, bots never truly fall, and the Floor->C_M fixed-trigger
	# jump recipe (which assumes real gravity for its arc/timing) fails
	# every single attempt - not a navigation or hazard-interaction defect
	# at all, just this ordering bug.
	_clear_field([])
	_restore_gravity()
	for p in arena.players:
		p.controller.set_frozen(false)
	for i in range(arena.brains.size()):
		if arena.brains[i] != null:
			arena.brains[i].reset_goal()
	# An unfrozen P1 has no real human providing input in a headless run, so
	# its HumanController reads zero intent forever - but it is still a
	# real, physically-simulated CharacterBody2D. Left at _clear_field()'s
	# (960, -2000), it free-falls straight down (zero horizontal drift) onto
	# whatever happens to sit below that x - which is the Relic pedestal
	# chamber itself, letting an inert P1 silently hoard the Relic at the
	# vault forever and starve every round of a real winner (a bug found and
	# fixed during this tool's own development). tools/m4_2_check.gd's own
	# soak repositions to a random (x, y=500) instead, which is fine for a
	# ROAM-only soak but was found here to occasionally strand a body
	# somewhere awkward (mid-air over a gap, atop a narrow column) for a
	# soak that requires REAL SEEK_RELIC navigation to succeed - the
	# authored Spawn markers are the same safe, sensible starting points
	# _full_reset() itself already uses for every later round, so round 0
	# uses them too rather than inventing a separate convention.
	for i in range(arena.players.size()):
		arena.players[i].reset_to(arena._markers.get_node("Spawn%d" % (i + 1)).global_position)

	arena.set_hazards_armed(true)

	var results: Array = []
	var mine_placements := 0
	var mine_hits := 0
	var mine_defeats := 0
	var power_defeats := 0
	var hazard_defeats := 0
	var non_terminating := 0
	var hard_recoveries_start := 0
	for b in arena.brains:
		if b != null:
			hard_recoveries_start += b.hard_recovery_count

	var on_used := func(_slot_id, power_type):
		if power_type == PowerTypeScript.Type.MINE:
			mine_placements += 1
	var on_hit := func(_shooter, _target, power_type):
		if power_type == PowerTypeScript.Type.MINE:
			mine_hits += 1
	var on_defeated := func(_slot_id, power_type):
		if power_type == PowerTypeScript.Type.MINE:
			mine_defeats += 1
		elif power_type == HealthSystemScript.HAZARD_SOURCE:
			hazard_defeats += 1
		elif power_type != PowerTypeScript.Type.NONE:
			power_defeats += 1

	arena.power_system.power_used.connect(on_used)
	arena.power_system.power_hit.connect(on_hit)
	arena.health_system.player_defeated.connect(on_defeated)

	print("  running up to %d rounds (bot-only, real Climax systems)..." % ROUNDS)
	for round_i in range(ROUNDS):
		var first_carrier_slot := -1
		var carrier_changes := 0
		var relic_drops := 0
		var last_carrier := -1
		var open_t := 0.0
		var first_pickup_t := -1.0
		var win_t := -1.0

		var on_picked_up := func(slot_id):
			if first_carrier_slot < 0:
				first_carrier_slot = slot_id
			if last_carrier != slot_id:
				carrier_changes += 1
				last_carrier = slot_id
		var on_dropped := func(_slot_id):
			relic_drops += 1

		arena.relic.picked_up.connect(on_picked_up)
		arena.relic.dropped.connect(on_dropped)

		_force_fresh_open()
		await _settle(2)

		var t := 0.0
		var hz := physics_ticks_per_second()
		var terminated := false
		while t < ROUND_TIMEOUT:
			await physics_frame
			t += 1.0 / hz
			if first_pickup_t < 0.0 and arena.relic.carrier_slot_id >= 0:
				first_pickup_t = t
			if arena.match_director.state == MatchDirector.State.RESULTS:
				win_t = t
				terminated = true
				break

		arena.relic.picked_up.disconnect(on_picked_up)
		arena.relic.dropped.disconnect(on_dropped)

		if not terminated:
			non_terminating += 1
			print("  round %d: DID NOT TERMINATE within %.0fs" % [round_i, ROUND_TIMEOUT])
			results.append({
				"round": round_i, "winner": -1, "first_carrier": first_carrier_slot,
				"extraction_region": arena.extraction_system.active_region, "carrier_changes": carrier_changes,
				"drops": relic_drops, "open_to_pickup": first_pickup_t, "pickup_to_win": -1.0, "open_to_win": -1.0,
			})
		else:
			results.append({
				"round": round_i, "winner": arena.match_director.winner_slot_id, "first_carrier": first_carrier_slot,
				"extraction_region": arena.extraction_system.active_region, "carrier_changes": carrier_changes,
				"drops": relic_drops, "open_to_pickup": first_pickup_t,
				"pickup_to_win": (win_t - first_pickup_t) if first_pickup_t >= 0.0 else -1.0, "open_to_win": win_t,
			})

		# Wait for the approved minimum RESULTS dwell, then rematch - the
		# same real path a human pressing R takes, so climax_lab_active's
		# own auto-reopen (arena_01.gd) drives the next round exactly like
		# a real repeated Climax Lab session would.
		var dwell_budget := 0
		while not arena.match_director.rematch_ready() and dwell_budget < int(3.0 * hz):
			await physics_frame
			dwell_budget += 1
		arena._full_reset()
		await _settle(3)

	arena.power_system.power_used.disconnect(on_used)
	arena.power_system.power_hit.disconnect(on_hit)
	arena.health_system.player_defeated.disconnect(on_defeated)
	arena.set_hazards_armed(false)

	var hard_recoveries_end := 0
	for b in arena.brains:
		if b != null:
			hard_recoveries_end += b.hard_recovery_count

	print("\n  --- Climax soak report (%d rounds) ---" % ROUNDS)
	var winners := {}
	var first_carriers := {}
	var extraction_dist := {}
	var carry_durations: Array = []
	var open_to_pickup: Array = []
	var open_to_win: Array = []
	for r in results:
		if r.winner >= 0:
			winners[r.winner] = winners.get(r.winner, 0) + 1
		if r.first_carrier >= 0:
			first_carriers[r.first_carrier] = first_carriers.get(r.first_carrier, 0) + 1
		if r.extraction_region != "":
			extraction_dist[r.extraction_region] = extraction_dist.get(r.extraction_region, 0) + 1
		if r.pickup_to_win >= 0.0:
			carry_durations.append(r.pickup_to_win)
		if r.open_to_pickup >= 0.0:
			open_to_pickup.append(r.open_to_pickup)
		if r.open_to_win >= 0.0:
			open_to_win.append(r.open_to_win)
	print("  first carrier by slot: %s" % first_carriers)
	print("  extraction selected by region: %s" % extraction_dist)
	print("  winners by slot: %s" % winners)
	# %s with a single Array argument to the % operator spreads the array's
	# OWN elements across the format string's substitutions instead of
	# treating the array as one value - wrapping each in an outer [array]
	# is what actually forces "one %s, one argument" here.
	print("  carrier changes per round: %s" % [results.map(func(r): return r.carrier_changes)])
	print("  Relic drops per round: %s" % [results.map(func(r): return r.drops)])
	print("  carry duration (first pickup -> win), s: %s" % [carry_durations])
	print("  OPEN -> first pickup, s: %s" % [open_to_pickup])
	print("  OPEN -> win, s: %s" % [open_to_win])
	print("  mine placements: %d   mine hits: %d   mine-caused defeats: %d" % [mine_placements, mine_hits, mine_defeats])
	print("  power-caused defeats (non-mine): %d   hazard-caused defeats: %d" % [power_defeats, hazard_defeats])
	print("  non-terminating rounds: %d / %d" % [non_terminating, ROUNDS])
	print("  hard nav recoveries during soak: %d" % (hard_recoveries_end - hard_recoveries_start))
	print("  Diagnostic only - never balanced or auto-corrected from this report.")
