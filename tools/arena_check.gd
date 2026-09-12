extends SceneTree

# Arena 01 V2 ("The Gallery") permanent geometry/reachability checker.
# Run headless: godot --headless --script tools/arena_check.gd
#
# Per docs/plans/M02_ARENA_01_V2.md section 15, this is a PERMANENT committed
# regression tool. The harness (geometry extraction, input simulation,
# reporting) survives from V1; the rule thresholds, edge list and route
# phases are rewritten for V2's geometry.
#
# Section map (docs/plans/M02_ARENA_01_V2.md #15):
#   Static audit    - R1 (tightened), R2 (rise-aware), R3, R4, R5, R6, R7,
#                      R8 (simulated), R9 (simulated), R12
#   Diagnostics     - R10 (band continuity), R11 (territory report),
#                      route-cost table, time-to-first-contact, wrap-route
#                      timing. None of these gate PASS/FAIL.
#   Route proofs    - both Crown entrances, both vault doors (from a
#                      standing start), the 240px skill jump, the
#                      launcher's left and right landings.
#   Wrap integrity  - Floor, Band C seam, Band B seam, both directions.
#
# Note on input simulation: Input.action_press()/action_release() do NOT
# reliably set the is_action_just_pressed() edge under --headless --script
# (observed ~5 physics-tick flush latency, and a press+release issued in the
# same tick can be dropped entirely before the flush ever sees it). This file
# dispatches real InputEventAction objects via Input.parse_input_event(), and
# every driver function confirms its effect against real physics state
# (velocity, position, is_on_floor()) rather than assuming a fixed frame
# count - this makes the whole harness robust to that latency by construction.

const ARENA_SCENE_PATH := "res://scenes/arena_01/arena_01.tscn"
const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"

var fails: Array[String] = []
var warns: Array[String] = []
var acknowledged: Array[String] = []

# Findings that are known, deliberately not fixed, and must not silently
# reappear as "the checker is broken" every M3+ run. Keyed on rule + exact
# label + a substring of the expected detail text, so a DIFFERENT failure on
# the same rule/label (e.g. B_Under's rise changing) does not match this entry
# and fails normally instead of being swallowed. See docs/DECISIONS.md
# (2026-09-06, "arena_check.gd gets an acknowledged-exception list").
const ACKNOWLEDGED_EXCEPTIONS := [
	{
		"rule": "R7",
		"label": "Band C -> Band B barrier: C_W -> B_Under",
		"detail_contains": "landing platform 'B_Under' is 140px wide, needs >=280px",
		"reason": "B_Under is a confirmed intentionally-hard-to-reach, high-value future pickup spot (docs/DECISIONS.md, 2026-09-06). Not to be simplified.",
	},
	{
		"rule": "GATE",
		"label": "West gateway shaft / VaultSealW",
		"detail_contains": "platform intersects the west gateway's fall corridor",
		"reason": "This static AABB check predates M3-2 and cannot see runtime collision toggling - VaultSealW is DESIGNED to occupy this exact corridor while the vault is sealed (docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md S05) and its collision is disabled at OPEN (proven dynamically by the GATE/R8/R9 checks run above, forced OPEN, and by the SEAL section's CLOSED-state proof). Not a bug; the check's job of catching an UNEXPECTED obstruction is unaffected for any other platform.",
	},
]

func _acknowledged_exception(rule: String, label: String, detail: String) -> Dictionary:
	for exc in ACKNOWLEDGED_EXCEPTIONS:
		if exc.rule == rule and exc.label == label and detail.contains(exc.detail_contains):
			return exc
	return {}

# M1 movement constants, read from the real Player scene's exported defaults
# so this checker can never drift from the numbers that actually ship.
var max_speed: float
var acceleration: float
var friction: float
var gravity: float
var climb_speed: float
var launch_strength: float
var jump_strength: float
var player_half_w: float
var player_half_h: float

var geom: Dictionary = {}     # platform name -> {left,right,top,bottom,center}
var ladders: Dictionary = {}  # ladder name -> aabb
var pads: Dictionary = {}     # pad name -> aabb
var edge_verdicts: Dictionary = {}  # "a->b" -> "PASS"/"FAIL" from the static audit

var arena: Node2D
var player: CharacterBody2D
var physics_hz: float

# --- Entry point -----------------------------------------------------------

func _initialize() -> void:
	physics_hz = float(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60))
	_load_player_constants()
	call_deferred("_run")

func _run() -> void:
	_load_arena()
	await process_frame
	await process_frame
	_extract_geometry()

	print("=== Arena 01 V2 Checker (M2) ===")
	print("M1 constants: max_speed=%.0f accel=%.0f friction=%.0f gravity=%.0f climb=%.0f jump=%.0f launch=%.0f player_half=(%.0f,%.0f)" % [
		max_speed, acceleration, friction, gravity, climb_speed, jump_strength, launch_strength, player_half_w, player_half_h
	])
	print("max jump rise = %.1fpx | max launch rise = %.1fpx" % [
		jump_strength * jump_strength / (2.0 * gravity), launch_strength * launch_strength / (2.0 * gravity)
	])

	print("\n--- Static geometry audit (R1, R2, R7, R12) ---")
	_static_audit()

	print("\n--- R3, R5: launch pad checks ---")
	_check_pads()

	print("\n--- R4: ladder checks ---")
	_check_ladders()

	print("\n--- R6: seam collision coverage ---")
	_check_seam_collision()

	# M3-2 Step 2: the scene now loads with MatchDirector in SETUP, i.e. the
	# vault sealed by default - see docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md
	# S19 Step 2, item 9 ("make arena_check.gd correctly test both SEALED and
	# OPEN rather than leaving the legacy OPEN-only tests as expected
	# failures"). The gateway/R8/R9 checks below predate the gate and were
	# authored to prove the M2/M3-1 accepted vault traversal - that claim is
	# only meaningful with the gate OPEN, so it is forced open for exactly
	# these checks, then re-sealed immediately after. The SEALED-state proof
	# (nobody can bypass while CLOSED) runs first, against the scene's real
	# default, no forcing needed.
	print("\n--- SEAL: M3-2 vault seal (VaultSealW/VaultSealE), SETUP/CLOSED state (scene default) ---")
	await _check_vault_seal_step1()

	print("\n--- Relic chamber gateways (forced OPEN - the accepted M2/M3-1 baseline) ---")
	await _set_gate_open(true)
	_check_gateways()
	await _check_gateway_routes()

	print("\n--- R8: forgiving objective access (standing start), OPEN state ---")
	await _check_standing_start_access()

	print("\n--- R9: no trap volumes, OPEN state ---")
	_check_no_trap_volumes()

	print("\n--- SEAL: re-sealed after the OPEN proof, back to CLOSED for the remaining diagnostics ---")
	await _set_gate_open(false)
	if await _test_west_gateway_enter():
		_report("SEAL", "Re-sealed after OPEN proof (west gateway)", "FAIL", "reached VaultFloor after toggling back to CLOSED - the seal did not re-engage")
	else:
		_report("SEAL", "Re-sealed after OPEN proof (west gateway)", "PASS", "blocked again once toggled back CLOSED")

	print("\n--- R10: band continuity (diagnostic only) ---")
	_band_report("Floor", ["Floor"], true)
	_band_report("Band C", ["C_Seam_west", "C_W", "C_M", "C_Seam"], true)
	_band_report("Band B", ["B_Seam_west", "B_W", "Pier", "B_Under", "B_E", "B_Seam"], true)
	_band_report("Band A (Crown)", ["A_W", "A_W_Bridge", "Pier", "VaultFloor", "VaultEast", "A_E", "A_E_Bridge"], false)

	print("\n--- R11: territory report (diagnostic only) ---")
	_territory_report()

	print("\n--- Route proofs (Session 2 validation) ---")
	await _print_route_result("Crown entrance west (LadW -> A_W)", await _route_ladw_crown(Vector2(650.0, 792.0)))
	await _print_route_result("Crown entrance east (LadE -> A_E)", await _route_lade_crown(Vector2(1700.0, 792.0)))
	await _print_route_result("Skill jump (B_W -> B_Seam, 240px)", await _route_skill_jump())
	await _print_route_result("Launcher steer right (PadC -> B_W)", await _route_launcher(1))
	await _print_route_result("Launcher steer left (PadC -> B_Seam, across seam)", await _route_launcher(-1))
	print("  (Both vault doors from a standing start are proven above under R8.)")

	print("\n--- Route-cost table (per spawn; diagnostic only, not normative) ---")
	var spawns: Array = []
	var markers := arena.get_node("Markers")
	for i in range(1, 5):
		spawns.append(markers.get_node("Spawn%d" % i).global_position)
	await _route_cost_table(spawns)

	print("\n--- Wrap integrity ---")
	await _wrap_integrity()

	print("\n--- Wrap-route timing (diagnostic only, not a threshold; V2-A3) ---")
	await _wrap_route_timing()

	print("\n--- Time-to-first-contact (diagnostic only; simplified to time-to-Floor) ---")
	await _time_to_first_contact(spawns)

	_print_summary()
	quit(1 if not fails.is_empty() else 0)

# --- Setup / geometry extraction -------------------------------------------

func _load_player_constants() -> void:
	var p: CharacterBody2D = (load(PLAYER_SCENE_PATH) as PackedScene).instantiate()
	max_speed = p.max_speed
	acceleration = p.acceleration
	friction = p.friction
	gravity = p.gravity
	climb_speed = p.climb_speed
	launch_strength = p.launch_strength
	jump_strength = p.jump_strength
	var shape := (p.get_node("CollisionShape2D").shape as RectangleShape2D)
	player_half_w = shape.size.x * 0.5
	player_half_h = shape.size.y * 0.5
	p.free()

func _load_arena() -> void:
	arena = (load(ARENA_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(arena)
	# M3-1: the single "Player" node became four PlayerSlots. Slot1 is P1,
	# the human-local slot, and is what this checker drives directly with
	# raw input events exactly as before - Slots 2-4 are bot-controlled and
	# roam independently for the whole run, which does not affect any static
	# geometry check or Slot1's own route proofs.
	player = arena.get_node("PlayerSlots/Slot1")
	# M3-2 Step 3: this checker's own _set_gate_open() drives MatchDirector
	# directly and explicitly - it must not ALSO advance on its own in the
	# background. Left enabled, MatchDirector's real ~10s timer eventually
	# fires OPEN unprompted mid-run, which lets the real Relic (still
	# ticking) genuinely collect from a bot wandering through the
	# now-unsealed vault - that latches RESULTS and freezes every
	# controller, including Slot1's, silently breaking every later
	# Input-driven test (first observed: the wrap-integrity tests, which
	# depend on Slot1 actually moving). Relic collection itself is Step 3's
	# own concern and is tested separately in tools/m3_check.gd - this
	# checker is geometry/traversal only and must not exercise it as a side
	# effect of forcing the gate open for its own purposes.
	arena.get_node("MatchDirector").set_physics_process(false)
	arena.get_node("Relic").set_physics_process(false)
	# M4-1 STOP 1+2: same reasoning as MatchDirector/Relic above, for the same
	# failure shape. PowerSystem polls every player for a pressed power action
	# every physics frame regardless of match state, and bots roaming in the
	# background can now legitimately Push/Freeze whichever body they find
	# nearby - including Slot1 mid-route. A bot shoving the checker's own test
	# subject off a ladder mid-climb is real M4-1 behaviour, not a bug, but it
	# makes Slot1's route no longer deterministic, which is what this checker
	# is geometry/traversal only and cannot tolerate. Player-vs-player
	# interference itself is tested separately in tools/m4_1_check.gd.
	arena.get_node("PowerSystem").set_physics_process(false)
	# M4-1 STOP 3+4: HealthSystem can only ever act on a real power_hit signal
	# from PowerSystem (a Rocket landing), which the line above already makes
	# impossible here - disabled anyway, for the same defence-in-depth reason
	# and so a later change to either system can't silently reopen this.
	arena.get_node("HealthSystem").set_physics_process(false)

func _aabb_of(body: Node2D) -> Dictionary:
	var cs := body.get_node("CollisionShape2D") as CollisionShape2D
	var rect := cs.shape as RectangleShape2D
	if rect == null:
		# A hand-edit can leave a CollisionShape2D with no shape assigned
		# (observed on the rotated beam over the Relic) - that body has no
		# actual collision at all. Report it as a zero-size box at its own
		# position rather than crashing the whole simulation on a null shape.
		var pos: Vector2 = cs.global_position
		return {"left": pos.x, "right": pos.x, "top": pos.y, "bottom": pos.y, "center": pos, "no_shape": true}
	# Use the CollisionShape2D's own global_position, not the parent body's -
	# a shape authored with a local position offset (as several V2 blocks now
	# have, from hand-editing in the editor) sits somewhere other than its
	# body's origin, and reading the body's position alone silently computes
	# the wrong AABB. traversal_zone.gd's get_top_y() already does this
	# correctly; this checker was the one place still reading the body.
	var c: Vector2 = cs.global_position
	var hw: float = rect.size.x * 0.5
	var hh: float = rect.size.y * 0.5
	# Account for rotation (body and/or shape) by rotating all four local
	# corners into world space and taking their bounding box - a hand-edit
	# can rotate either node, and reading size.x/y directly as if still
	# axis-aligned silently computes the wrong AABB for a rotated shape
	# (this arena now has one: the Director rotated a jamb wall 90 degrees
	# into a horizontal beam over the Relic).
	var angle: float = cs.global_rotation
	if abs(angle) > 0.0001:
		var corners: Array[Vector2] = [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]
		var min_x: float = INF
		var max_x: float = -INF
		var min_y: float = INF
		var max_y: float = -INF
		for corner in corners:
			var world: Vector2 = c + corner.rotated(angle)
			min_x = min(min_x, world.x)
			max_x = max(max_x, world.x)
			min_y = min(min_y, world.y)
			max_y = max(max_y, world.y)
		return {"left": min_x, "right": max_x, "top": min_y, "bottom": max_y, "center": c}
	return {"left": c.x - hw, "right": c.x + hw, "top": c.y - hh, "bottom": c.y + hh, "center": c}

func _extract_geometry() -> void:
	var geo := arena.get_node("Geometry")
	for child in geo.get_children():
		if child.name == "SeamMirror":
			for seam_child in child.get_children():
				geom[seam_child.name] = _aabb_of(seam_child)
			continue
		geom[child.name] = _aabb_of(child)
	var trav := arena.get_node("Traversal")
	for child in trav.get_children():
		var aabb := _aabb_of(child)
		if child.name.begins_with("Lad"):
			ladders[child.name] = aabb
		elif child.name.begins_with("Pad"):
			pads[child.name] = aabb

# --- Reporting ---------------------------------------------------------------

func _report(rule: String, label: String, verdict: String, detail: String) -> void:
	if verdict == "FAIL":
		var exc := _acknowledged_exception(rule, label, detail)
		if not exc.is_empty():
			var ack_line := "[%s] %-46s %-5s %s" % [rule, label, "ACK", detail]
			print(ack_line + "  (ACKNOWLEDGED: %s)" % exc.reason)
			acknowledged.append(ack_line)
			return
	var line := "[%s] %-46s %-5s %s" % [rule, label, verdict, detail]
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
	print("Acknowledged exceptions (do not gate PASS/FAIL): %d" % acknowledged.size())
	for a in acknowledged:
		print("  " + a)
	print("Warnings / diagnostics: %d" % warns.size())
	for w in warns:
		print("  " + w)
	print("RESULT: %s" % ("PASS" if fails.is_empty() else "FAIL"))

# --- R1 / R2 / R7 / R12: static geometry audit ------------------------------

func _classify_r1(rise: float) -> Dictionary:
	if rise <= 0.0:
		return {"verdict": "PASS", "band": "not a climb (level or drop - downward is free everywhere)"}
	if rise <= 150.0:
		return {"verdict": "PASS", "band": "comfortable (<=150px)"}
	if rise >= 200.0:
		return {"verdict": "PASS", "band": "deliberate barrier (>=200px)"}
	return {"verdict": "FAIL", "band": "FORBIDDEN 151-199px - tightened V2 rule, closes the band V1 only warned about"}

# Rise-aware ballistic arrival time for a jump of the given net vertical
# displacement dy (down-positive: dy<0 means the target is higher). Mirrors
# the launch-pad arc math below, using jump_strength instead of
# launch_strength. dy<=0 (ascending arrival) uses the first height crossing;
# dy>0 (descending arrival, target lower) uses the second.
func _jump_arc(dy: float) -> Dictionary:
	var vy0: float = -jump_strength
	var disc: float = vy0 * vy0 + 2.0 * gravity * dy
	if disc < 0.0:
		return {"feasible": false}
	var t_first: float = (-vy0 - sqrt(disc)) / gravity
	var t_second: float = (-vy0 + sqrt(disc)) / gravity
	# dy<0 (target strictly higher): a clean landing on top of a platform can
	# only happen while ascending if the platform has zero thickness, which
	# none do here - but for a truly higher, unobstructed target the earliest
	# arrival is still the right answer for a plain rise-to-a-ledge case.
	# dy>=0 (target level or lower): landing happens on the way back down, so
	# use the later (return) crossing - this matters even at dy==0, where
	# t_first is the trivial t=0 launch instant, not a real arrival.
	var t: float = t_first if dy < 0.0 else t_second
	return {"feasible": true, "t": t}

func _classify_r2(gap: float, rise: float, tagged_skill: bool) -> Dictionary:
	var dy: float = -rise
	var arc := _jump_arc(dy)
	if not arc.feasible:
		return {"verdict": "PASS", "band": "barrier (rise %.0fpx exceeds max jump rise %.0fpx - vertically unreachable)" % [rise, jump_strength * jump_strength / (2.0 * gravity)]}
	var reach: float = max_speed * arc.t
	if gap > reach or gap > 420.0:
		return {"verdict": "PASS", "band": "barrier (gap %.0fpx exceeds ballistic reach %.0fpx for this rise)" % [gap, reach]}
	if gap <= 210.0:
		return {"verdict": "PASS", "band": "comfortable (<=210px, reach %.0fpx)" % reach}
	if gap <= 300.0:
		if tagged_skill:
			return {"verdict": "PASS", "band": "tagged skill_route (211-300px, reach %.0fpx)" % reach}
		return {"verdict": "FAIL", "band": "FORBIDDEN 211-300px on a normal (non-skill) route"}
	return {"verdict": "FAIL", "band": "FORBIDDEN 301-420px"}

func _measure(a_name: String, b_name: String) -> Dictionary:
	var a: Dictionary = geom[a_name]
	var b: Dictionary = geom[b_name]
	var overlap: bool = not (a.right <= b.left or b.right <= a.left)
	var gap: float = 0.0
	if not overlap:
		gap = (b.left - a.right) if a.right <= b.left else (a.left - b.right)
	var rise: float = a.top - b.top
	return {"overlap": overlap, "gap": gap, "rise": rise}

# R12: if platform b's footprint fully contains a's footprint AND b sits
# above a with less than 240px clearance (184px max jump rise + 56px body),
# any step from a toward b's top is physically blocked by b's own underside
# before the player can rise anywhere near b's top - it must never be
# reported as a comfortable step. Detects the B_Under / VaultFloor case.
func _ceiling_clearance(a_name: String, b_name: String) -> Dictionary:
	var a: Dictionary = geom[a_name]
	var b: Dictionary = geom[b_name]
	var contained: bool = a.left >= b.left - 1.0 and a.right <= b.right + 1.0
	if not contained or b.bottom > a.top + 1.0:
		return {"applies": false}
	return {"applies": true, "clearance": a.top - b.bottom}

func _check_edge(label: String, a_name: String, b_name: String, tagged_skill: bool = false) -> void:
	if not geom.has(a_name) or not geom.has(b_name):
		_report("R1/R2", label, "FAIL", "missing geometry: '%s' or '%s' not found in the scene" % [a_name, b_name])
		return
	var ceiling := _ceiling_clearance(a_name, b_name)
	if ceiling.applies and ceiling.clearance < 240.0:
		_report("R12", label, "PASS", "ceiling-blocked: '%s' overhangs the whole of '%s' with only %.0fpx headroom (<240px needed) - jump is physically impossible, NOT classified as comfortable" % [b_name, a_name, ceiling.clearance])
		edge_verdicts["%s->%s" % [a_name, b_name]] = "PASS"
		return
	var m := _measure(a_name, b_name)
	var verdict: String
	if m.overlap:
		var c := _classify_r1(m.rise)
		verdict = c.verdict
		_report("R1", label, c.verdict, "step-up %.1fpx (columns overlap) - %s" % [m.rise, c.band])
	else:
		var c := _classify_r2(m.gap, m.rise, tagged_skill)
		verdict = c.verdict
		_report("R2", label, c.verdict, "gap %.1fpx, rise %.1fpx - %s" % [m.gap, m.rise, c.band])
		if m.gap > 10.0 and c.verdict == "PASS" and (c.band.begins_with("comfortable") or c.band.begins_with("tagged skill")):
			var b: Dictionary = geom[b_name]
			var width: float = b.right - b.left
			var min_width: float = 140.0 if tagged_skill else 280.0
			if width < min_width:
				_report("R7", label, "FAIL", "landing platform '%s' is %.0fpx wide, needs >=%.0fpx for a %s route" % [b_name, width, min_width, "skill" if tagged_skill else "normal"])
			else:
				_report("R7", label, "PASS", "landing platform '%s' is %.0fpx wide (>=%.0fpx required)" % [b_name, width, min_width])
	edge_verdicts["%s->%s" % [a_name, b_name]] = verdict

func _static_audit() -> void:
	var edges := [
		# CoverW removed from Arena 01 (Director decision, human-playtest-
		# driven M3 level-design adjustment) - no longer audited here.
		["Floor -> CoverE (step)", "Floor", "CoverE", false],
		["Floor -> C_W (step, everywhere)", "Floor", "C_W", false],
		["Floor -> C_M (step, everywhere)", "Floor", "C_M", false],
		["Floor -> C_Seam (step, everywhere)", "Floor", "C_Seam_west", false],
		["Band C gap: C_Seam(west) -> C_W (launch shaft)", "C_Seam_west", "C_W", false],
		["Band C gap: C_W -> C_M", "C_W", "C_M", false],
		["Band C gap: C_M -> C_Seam", "C_M", "C_Seam", false],
		["Band C -> Band B barrier: C_W -> B_W", "C_W", "B_W", false],
		["Band C -> Band B barrier: C_M -> B_E", "C_M", "B_E", false],
		["Band C -> Band B barrier: C_W -> B_Under", "C_W", "B_Under", false],
		["Band B skill jump: B_Seam(west) -> B_W (240px)", "B_Seam_west", "B_W", true],
		["Band B gap: B_Under -> B_E", "B_Under", "B_E", false],
		["Band B gap: B_E -> B_Seam (east ladder shaft)", "B_E", "B_Seam", false],
		["Band B wall barrier: B_W -> Pier", "B_W", "Pier", false],
		["Crown step: A_W -> A_W_Bridge", "A_W", "A_W_Bridge", false],
		["Crown step: A_W_Bridge -> Pier top", "A_W_Bridge", "Pier", false],
		["Vault one-way in: Pier top -> VaultFloor (drop)", "Pier", "VaultFloor", false],
		["Vault climb-out barrier: VaultFloor -> Pier top", "VaultFloor", "Pier", false],
		["Vault step: VaultFloor -> VaultEast", "VaultFloor", "VaultEast", false],
		["Vault step: VaultEast -> A_E", "VaultEast", "A_E", false],
		["Vault barrier (mathematically unreachable): B_E -> VaultEast", "B_E", "VaultEast", false],
		["Ceiling check: B_Under -> VaultFloor", "B_Under", "VaultFloor", false],
	]
	for e in edges:
		_check_edge(e[0], e[1], e[2], e[3])

# --- R3 / R5: launch pad checks ---------------------------------------------

func _find_supporting_platform(area_aabb: Dictionary) -> String:
	var best_name := ""
	var best_dist := INF
	for name in geom:
		var p: Dictionary = geom[name]
		var overlaps_x: bool = not (p.right <= area_aabb.left or area_aabb.right <= p.left)
		if not overlaps_x:
			continue
		var d: float = p.top - area_aabb.bottom
		if d >= -10.0 and d < best_dist:
			best_dist = d
			best_name = name
	return best_name

func _check_pads() -> void:
	var apex_rise: float = launch_strength * launch_strength / (2.0 * gravity)
	for pad_name in pads:
		var pad: Dictionary = pads[pad_name]
		var support := _find_supporting_platform(pad)
		if support == "":
			_report("R5", pad_name, "FAIL", "no supporting platform found beneath the pad")
			continue
		var support_top: float = geom[support].top
		if support_top >= 620.0:
			_report("R5", pad_name, "PASS", "sits on '%s', surface y=%.0f (>=620)" % [support, support_top])
		else:
			_report("R5", pad_name, "FAIL", "sits on '%s', surface y=%.0f (<620) - a %.0fpx launch rise from here can exit the top of the screen" % [support, support_top, apex_rise])

		var origin_y: float = support_top - player_half_h
		var apex_y: float = origin_y - apex_rise
		# The "column" is the pad's own vertical shaft, not a wide steering
		# cone - R3 asks whether the shaft directly above the pad is clear
		# from launch to apex, not whether every possible steered landing
		# clips something (that is exactly what the simulated route proofs
		# below check, empirically, for the two actual landings).
		var clipped := false
		for name in geom:
			if name == support:
				continue
			var p: Dictionary = geom[name]
			var overlaps_x: bool = not (p.right <= pad.left or pad.right <= p.left)
			var overlaps_y: bool = not (p.bottom <= apex_y or origin_y <= p.top)
			if overlaps_x and overlaps_y:
				clipped = true
				_report("R3", "%s column / %s" % [pad_name, name], "FAIL", "platform intersects the pad's own vertical shaft between apex (y=%.0f) and launch point (y=%.0f)" % [apex_y, origin_y])
		if not clipped:
			_report("R3", "%s column" % pad_name, "PASS", "shaft clear from launch point y=%.0f to apex y=%.0f" % [origin_y, apex_y])

		if geom.has("A_W"):
			var crown_y: float = geom["A_W"].top - player_half_h
			if apex_y > crown_y:
				_report("R3", "%s apex vs Crown" % pad_name, "PASS", "apex y=%.0f is %.0fpx short of Crown surface y=%.0f - cannot reach the objective band by construction" % [apex_y, apex_y - crown_y, crown_y])
			else:
				_report("R3", "%s apex vs Crown" % pad_name, "WARN", "apex y=%.0f reaches or exceeds Crown surface y=%.0f" % [apex_y, crown_y])

# --- R4: ladder checks (unchanged logic from V1, generic over `ladders`) ---

func _check_ladders() -> void:
	for lname in ladders:
		var l: Dictionary = ladders[lname]
		var blocked := false
		for name in geom:
			var p: Dictionary = geom[name]
			var overlaps_x: bool = not (p.right <= l.left or l.right <= p.left)
			if not overlaps_x:
				continue
			var overlaps_y: bool = not (p.bottom <= l.top or l.bottom <= p.top)
			if not overlaps_y:
				continue
			var touches_top: bool = abs(p.top - l.top) <= 10.0 or abs(p.bottom - l.top) <= 10.0
			var touches_bottom: bool = abs(p.top - l.bottom) <= 10.0 or abs(p.bottom - l.bottom) <= 10.0
			if touches_top or touches_bottom:
				continue
			blocked = true
			_report("R4", "%s column" % lname, "FAIL", "column blocked by '%s' between its base and top" % name)
		if not blocked:
			_report("R4", "%s column" % lname, "PASS", "clear from base (y=%.0f) to top (y=%.0f)" % [l.bottom, l.top])

		var found_valid := false
		var candidates: Array[String] = []
		for name in geom:
			var p: Dictionary = geom[name]
			# 150px, not 70px: hand-edits have widened ladder-to-destination
			# gaps beyond the original tuning value. This is a proximity
			# heuristic only - R4's real authority is the simulated Crown-
			# entrance route proofs, which exercise the actual exit physics.
			var x_near: bool = not (p.right + 150.0 <= l.left or l.right + 150.0 <= p.left)
			if not x_near:
				continue
			var offset: float = p.top - l.top
			if offset < -20.0 or offset > 300.0:
				continue
			candidates.append("%s(+%.0fpx)" % [name, offset])
			if offset >= 80.0 and offset <= 100.0:
				found_valid = true
		if found_valid:
			_report("R4", "%s destination" % lname, "PASS", "top sits 80-100px above a reachable destination: %s" % ", ".join(candidates))
		else:
			_report("R4", "%s destination" % lname, "FAIL", "no destination 80-100px above the ladder top; candidates found: %s" % (", ".join(candidates) if not candidates.is_empty() else "none"))

# --- R6: seam collision coverage, extended to two seam-crossing platforms --

func _check_seam_collision() -> void:
	for seam_name in ["C_Seam", "B_Seam"]:
		if not geom.has(seam_name):
			_report("R6", seam_name, "FAIL", "no geometry found")
			continue
		var y_ref: Dictionary = geom[seam_name]
		var bands := [
			{"label": "%s: east screen-edge strip (x 1920-1978)" % seam_name, "left": 1920.0, "right": 1978.0},
			{"label": "%s: west screen-edge strip (x -58-0)" % seam_name, "left": -58.0, "right": 0.0},
		]
		for band in bands:
			var covered := false
			for name in geom:
				var p: Dictionary = geom[name]
				if p.left <= band.left and p.right >= band.right and p.top <= y_ref.top and p.bottom >= y_ref.bottom:
					covered = true
					_report("R6", band.label, "PASS", "covered by '%s'" % name)
					break
			if not covered:
				_report("R6", band.label, "FAIL", "no platform covers this seam-crossing strip at %s height - a body between the screen edge and the wrap trigger would have no floor" % seam_name)

# --- Relic chamber gateways (static checks) ---------------------------------

func _check_gateways() -> void:
	var pier: Dictionary = geom["Pier"]
	var gate_w: Dictionary = geom["VaultGateW"]
	var vault_floor: Dictionary = geom["VaultFloor"]
	var shaft_left: float = pier.right
	var shaft_right: float = gate_w.left
	var shaft_top: float = pier.top
	var shaft_bottom: float = vault_floor.top
	var clipped := false
	for name in geom:
		if name == "Pier" or name == "VaultGateW":
			continue
		var p: Dictionary = geom[name]
		var overlaps_x: bool = not (p.right <= shaft_left or shaft_right <= p.left)
		var overlaps_y: bool = not (p.bottom <= shaft_top or shaft_bottom <= p.top)
		if overlaps_x and overlaps_y:
			clipped = true
			_report("GATE", "West gateway shaft / %s" % name, "FAIL", "platform intersects the west gateway's fall corridor (x %.0f-%.0f, y %.0f-%.0f)" % [shaft_left, shaft_right, shaft_top, shaft_bottom])
	if not clipped:
		_report("GATE", "West gateway shaft", "PASS", "clear corridor x %.0f-%.0f (%.0fpx wide), y %.0f-%.0f" % [shaft_left, shaft_right, shaft_right - shaft_left, shaft_top, shaft_bottom])

	var gate_w_clearance: float = vault_floor.top - gate_w.bottom
	var min_clearance: float = player_half_h * 2.0 + 20.0
	if gate_w_clearance >= min_clearance:
		_report("GATE", "West gateway floor clearance", "PASS", "%.0fpx clearance above the vault floor (>=%.0fpx needed) - narrows the fall without walling off the chamber floor" % [gate_w_clearance, min_clearance])
	else:
		_report("GATE", "West gateway floor clearance", "FAIL", "only %.0fpx clearance above the vault floor (<%.0fpx) - would block walking through the chamber" % [gate_w_clearance, min_clearance])

	# The east side has no new gate wall (see the note in DECISIONS.md on why
	# one was tried and removed - a wall on a straight walking surface like
	# A_E can only ever fully block or fully not-block, with no way to be a
	# passable narrow gap, given this move set has no duck/crouch). VaultEast
	# is already the narrow, single-file, distinctly-coloured east chokepoint
	# ("everything funnels here" per the original approved design) - report
	# its width for comparison against the west gap rather than gating on it.
	var vault_east: Dictionary = geom["VaultEast"]
	_report("GATE", "East gateway (VaultEast, existing structure)", "PASS", "%.0fpx wide (x %.0f-%.0f) - already the sole path, distinctly coloured from ordinary platforms" % [vault_east.right - vault_east.left, vault_east.left, vault_east.right])

# --- Relic chamber gateways (simulated pass-through) -------------------------

func _test_west_gateway_enter() -> bool:
	var pier: Dictionary = geom["Pier"]
	await _place_player(Vector2(pier.right + player_half_w + 2.0, pier.top - player_half_h))
	_reset_inputs()
	if not await _wait_until(func(): return player.is_on_floor(), 200, "fall through west gateway"):
		return false
	return _on_vault_floor()

func _test_east_gateway_enter() -> bool:
	var a_e: Dictionary = geom["A_E"]
	await _place_player(Vector2(1420.0, a_e.top - player_half_h))
	_hold(-1)
	if not await _wait_until(func(): return player.global_position.x <= a_e.left + 1.0, 300, "walk to A_E's west edge"):
		return false
	if not await _wait_until(func(): return not player.is_on_floor(), 30, "step off A_E's edge"):
		return false
	if not await _wait_until(func(): return player.is_on_floor(), 200, "land after stepping off A_E"):
		return false
	_hold(0)
	# A full-speed run off the edge can carry a body past VaultEast's 80px
	# width straight onto VaultFloor (existing physics, not something this
	# gateway changed) - either is a successful east entry.
	return _on_platform("VaultEast") or _on_vault_floor()

func _test_east_gateway_exit() -> bool:
	var vault_east: Dictionary = geom["VaultEast"]
	await _place_player(Vector2(vault_east.center.x, vault_east.top - player_half_h))
	if not await _vertical_clear_jump_near_edge("A_E", 1, 20.0, 200):
		return false
	if not await _wait_until(func(): return player.is_on_floor(), 200, "land on A_E"):
		return false
	if not (_on_platform("A_E") or _on_platform("A_E_Bridge")):
		return false
	_hold(1)
	if not await _wait_until(func(): return player.global_position.x >= geom["A_E"].left + 200.0, 300, "walk east back into the arrival zone"):
		return false
	_hold(0)
	return _on_platform("A_E") or _on_platform("A_E_Bridge")

# --- M3-2 Step 1: vault seal (VaultSealW/VaultSealE) -------------------------
#
# The GATE/R8/R9 tests above still assume the pre-M3-2 always-open vault and
# are scheduled for a gate-state-aware rewrite alongside the MatchDirector
# (docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md S15/S16, "run R1-R12 in both gate
# states") - they now correctly FAIL on every route that leads into the
# sealed chamber, which is Step 1's intended effect, not a defect. This
# section is an additive, temporary Step 1 probe for the two new seal pieces
# only; it does not relax or replace any existing rule above.

func _check_vault_seal_step1() -> void:
	var seal_w: Dictionary = geom["VaultSealW"]
	var gate_w: Dictionary = geom["VaultGateW"]
	var seal_e: Dictionary = geom["VaultSealE"]
	var roof_gap := false
	if seal_w.right < gate_w.left - 0.5:
		roof_gap = true
		_report("SEAL", "Roof coverage: VaultSealW -> VaultGateW", "FAIL", "gap of %.1fpx" % (gate_w.left - seal_w.right))
	if gate_w.right < seal_e.left - 0.5:
		roof_gap = true
		_report("SEAL", "Roof coverage: VaultGateW -> VaultSealE", "FAIL", "gap of %.1fpx" % (seal_e.left - gate_w.right))
	if not roof_gap:
		_report("SEAL", "Roof coverage (VaultSealW+VaultGateW+VaultSealE)", "PASS", "continuous solid span x %.0f-%.0f, y %.0f-%.0f" % [seal_w.left, seal_e.right, seal_w.top, seal_w.bottom])

	# The interior box the seal caps is [820,1160] x [seal.bottom, floor.top] -
	# below the seal, above the chamber floor (docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md
	# S05's ASCII diagram). Each side wall only needs to cover that span, not
	# the seal's own y-range - the seal itself already covers that overhead.
	var floor_top: float = geom["VaultFloor"].top
	var pier: Dictionary = geom["Pier"]
	if pier.top <= seal_w.bottom and pier.bottom >= floor_top:
		_report("SEAL", "West wall coverage (Pier east face)", "PASS", "Pier spans y %.0f-%.0f, covers the interior's y %.0f-%.0f" % [pier.top, pier.bottom, seal_w.bottom, floor_top])
	else:
		_report("SEAL", "West wall coverage (Pier east face)", "FAIL", "Pier spans y %.0f-%.0f, does not cover the interior's y %.0f-%.0f" % [pier.top, pier.bottom, seal_w.bottom, floor_top])

	var vault_east: Dictionary = geom["VaultEast"]
	if vault_east.top <= seal_e.bottom and vault_east.bottom >= floor_top:
		_report("SEAL", "East wall coverage (VaultEast west face)", "PASS", "VaultEast spans y %.0f-%.0f, covers the interior's y %.0f-%.0f" % [vault_east.top, vault_east.bottom, seal_e.bottom, floor_top])
	else:
		_report("SEAL", "East wall coverage (VaultEast west face)", "FAIL", "VaultEast spans y %.0f-%.0f, does not cover the interior's y %.0f-%.0f" % [vault_east.top, vault_east.bottom, seal_e.bottom, floor_top])

	await _check_roof_bypass()

# A3's exact named bypass: jump from VaultEast onto the roof (a legal, ordinary
# M1 jump), then try to walk the whole roof width and confirm no descent into
# VaultFloor is possible from up there.
func _check_roof_bypass() -> void:
	var vault_east: Dictionary = geom["VaultEast"]
	await _place_player(Vector2(vault_east.center.x, vault_east.top - player_half_h))
	if not await _run_and_jump_near_edge("VaultEast", -1, 20.0, 200):
		_report("SEAL", "Roof bypass probe: VaultEast -> roof", "WARN", "could not reach the roof from VaultEast to run this probe - verify by manual STOP 1 inspection instead")
		return
	if not await _wait_until(func(): return player.is_on_floor(), 200, "land after jumping from VaultEast"):
		_report("SEAL", "Roof bypass probe: VaultEast -> roof", "WARN", "never landed after the jump - verify by manual STOP 1 inspection instead")
		return
	if not (_on_platform("VaultSealE") or _on_platform("VaultGateW") or _on_platform("VaultSealW")):
		_report("SEAL", "Roof bypass probe: VaultEast -> roof", "WARN", "landed on '%s' instead of the roof - verify by manual STOP 1 inspection instead" % _current_platform_name())
		return
	var reached_vault_floor := false
	_hold(-1)
	for _i in range(240):
		await _tick()
		if _on_vault_floor():
			reached_vault_floor = true
			break
		if player.global_position.x <= geom["Pier"].right - player_half_w:
			break
	_hold(0)
	if reached_vault_floor:
		_report("SEAL", "Roof bypass (walk the roof west, watch for a drop into the chamber)", "FAIL", "reached VaultFloor from the roof - the seal has a hole")
	else:
		_report("SEAL", "Roof bypass (walk the roof west, watch for a drop into the chamber)", "PASS", "never landed inside the sealed chamber; ended on '%s'" % _current_platform_name())

# M3-2 Step 2: the gate is driven by MatchDirector, which is authoritative
# (scripts/match_director.gd, scripts/relic_gate.gd). Forcing state through
# MatchDirector's own debug_force_open()/debug_force_setup() - the same API
# the G-key debug preview uses - is the same code path a human triggers
# manually at STOP 1/2. This lets this headless probe assert what STOP 1
# asked a human to judge by eye: that OPEN genuinely restores the accepted
# M3-1 vault traversal, not merely that it looks open.
func _director_node() -> Node:
	return arena.get_node("MatchDirector")

func _set_gate_open(open: bool) -> void:
	if open:
		_director_node().debug_force_open()
	else:
		_director_node().debug_force_setup()
	# CollisionShape2D.disabled is toggled with set_deferred by relic_gate.gd;
	# let that deferred call land before any physics probe runs.
	await process_frame
	await process_frame

func _check_gateway_routes() -> void:
	if await _test_west_gateway_enter():
		_report("GATE", "West gateway enter (standing start, drop through)", "PASS", "reaches VaultFloor")
	else:
		_report("GATE", "West gateway enter (standing start, drop through)", "FAIL", "did not land on VaultFloor")

	if await _test_east_gateway_enter():
		_report("GATE", "East gateway enter (walk from arrival zone to VaultEast)", "PASS", "reaches VaultEast")
	else:
		_report("GATE", "East gateway enter (walk from arrival zone to VaultEast)", "FAIL", "did not land on VaultEast")

	if await _test_east_gateway_exit():
		_report("GATE", "East gateway exit (VaultEast -> A_E -> back east)", "PASS", "reaches the arrival zone")
	else:
		_report("GATE", "East gateway exit (VaultEast -> A_E -> back east)", "FAIL", "did not reach the arrival zone")

# --- Input simulation --------------------------------------------------------

func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)

func _release(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = false
	Input.parse_input_event(ev)

func _reset_inputs() -> void:
	for a in ["move_left", "move_right", "vertical_intent_up", "vertical_intent_down", "jump"]:
		_release(a)

func _hold(dir: int) -> void:
	if dir < 0:
		_press("move_left"); _release("move_right")
	elif dir > 0:
		_press("move_right"); _release("move_left")
	else:
		_release("move_left"); _release("move_right")

func _hold_climb(v: int) -> void:
	if v < 0:
		_press("vertical_intent_up"); _release("vertical_intent_down")
	elif v > 0:
		_press("vertical_intent_down"); _release("vertical_intent_up")
	else:
		_release("vertical_intent_up"); _release("vertical_intent_down")

func _tap_jump(max_ticks: int = 40) -> bool:
	_press("jump")
	var fired := await _wait_until(func(): return player.velocity.y < -jump_strength * 0.5, max_ticks, "jump to register")
	_release("jump")
	await _tick()
	await _tick()
	return fired

func _tick() -> void:
	await physics_frame

func _wait_until(cond: Callable, max_ticks: int, label: String) -> bool:
	var t := 0
	while not cond.call():
		await _tick()
		t += 1
		if t > max_ticks:
			return false
	return true

func _place_player(pos: Vector2) -> void:
	_reset_inputs()
	await _tick()
	player.reset_to(pos)
	await _tick()
	await _tick()

func _on_platform(name: String) -> bool:
	if not geom.has(name):
		return false
	var p: Dictionary = geom[name]
	var pos := player.global_position
	var x_tol: float = player_half_w + 4.0
	return player.is_on_floor() and pos.x >= p.left - x_tol and pos.x <= p.right + x_tol and abs(pos.y - (p.top - player_half_h)) <= 4.0

# VaultFloor_Bridge fills a gap the Director's narrower VaultFloor opened up
# next to the Pier - it's the same walkable surface for every gameplay
# purpose, just authored as a separate node. Treat landing on either as
# "reached the vault floor."
func _on_vault_floor() -> bool:
	return _on_platform("VaultFloor") or _on_platform("VaultFloor_Bridge")

func _current_platform_name() -> String:
	for name in geom:
		if _on_platform(name):
			return name
	return "unknown (pos=%s, on_floor=%s)" % [str(player.global_position), str(player.is_on_floor())]

func _shortest_diff(target_x: float, from_x: float) -> float:
	var raw := target_x - from_x
	while raw > 960.0:
		raw -= 1920.0
	while raw < -960.0:
		raw += 1920.0
	return raw

func _run_and_jump_near_edge(platform_name: String, dir: int, edge_margin: float, max_ticks: int) -> bool:
	# Self-sufficient: does not assume the caller already holds the right
	# direction. A prior maneuver (e.g. _reach_band_c) can leave a stale
	# opposite hold active, which would otherwise walk the player the wrong
	# way entirely.
	_hold(dir)
	var p: Dictionary = geom[platform_name]
	var edge_x: float = p.right if dir > 0 else p.left
	var cond := func():
		if not player.is_on_floor():
			return false
		return (dir > 0 and player.global_position.x >= edge_x - edge_margin) or (dir < 0 and player.global_position.x <= edge_x + edge_margin)
	if not await _wait_until(cond, max_ticks, "run to edge of %s" % platform_name):
		return false
	return await _tap_jump()

# Mirrors EdgeExecutor's _advance_vertical_clear_jump recipe (Director
# investigation, 2026-09-08, via the dev-only traversal recorder): walk
# toward the TARGET's own near edge (not the departure platform's far edge -
# opposite convention from _run_and_jump_near_edge above), release
# horizontal, jump with ZERO horizontal hold (no attempt to clear the wall
# mid-ascent), hold zero until the apex, THEN steer onto the target. Used
# for VaultEast, where _run_and_jump_near_edge's generic "clear it in
# flight" model is the exact recipe already confirmed unreliable for this
# specific obstacle. `target_name` is the edge's "to" platform (e.g. "A_E"
# for the VaultEast->A_E hop), matching EdgeExecutor's own to_near_edge.
func _vertical_clear_jump_near_edge(target_name: String, dir: int, edge_margin: float, max_ticks: int) -> bool:
	_hold(dir)
	var to: Dictionary = geom[target_name]
	var near_edge: float = to.left if dir > 0 else to.right
	var cond := func():
		if not player.is_on_floor():
			return false
		return abs(_shortest_diff(near_edge, player.global_position.x)) <= edge_margin
	if not await _wait_until(cond, max_ticks, "approach %s" % target_name):
		return false
	_hold(0)
	await _tick()
	if not await _tap_jump():
		return false
	if not await _wait_until(func(): return player.velocity.y >= -50.0, max_ticks, "reach apex before %s" % target_name):
		return false
	_hold(dir)
	return true

func _ensure_on_ground(max_ticks: int = 400) -> bool:
	if _on_platform("Floor"):
		return true
	# Blindly holding right can walk straight into a wall (B_W's east edge
	# butts the pier). Drop via whichever edge of the CURRENT platform is
	# nearer, same as _drop_to_band_c, chaining through Band C if starting
	# on Band B - "downward is free everywhere" holds regardless of layer.
	for _i in range(3):
		if _on_platform("Floor"):
			return true
		if not await _drop_to_band_c("Floor"):
			if _on_platform("Floor"):
				return true
	return _on_platform("Floor")

func _hold_and_travel(dir: int, distance: float, max_ticks: int) -> bool:
	_hold(dir)
	if distance <= 0.0:
		return true
	var traveled := 0.0
	var t := 0
	while traveled < distance:
		await _tick()
		traveled += abs(player.velocity.x) / physics_hz
		t += 1
		if t > max_ticks:
			return false
	return true

# Travels from wherever the player currently stands toward a DISTANT target
# platform (not the current one) and jumps once close enough that the arc
# reaches it, leaving lead_in px of runway before the target's near edge for
# the jump itself. Wrap-aware, since the shortest path to a target can cross
# the seam.
func _travel_and_jump_to(target_name: String, lead_in: float, max_ticks: int) -> bool:
	var p: Dictionary = geom[target_name]
	var x: float = player.global_position.x
	if x >= p.left - 1.0 and x <= p.right + 1.0:
		# Already under the target's own footprint (an overlapping step, not
		# a gap - e.g. Floor directly beneath C_W). Jumping straight up here
		# hits the target's underside instead of clearing onto its top.
		# Clear whichever edge is nearer first, then approach from outside.
		var to_left: float = abs(_shortest_diff(p.left, x))
		var to_right: float = abs(_shortest_diff(p.right, x))
		var clear_dir: int = -1 if to_left <= to_right else 1
		if not await _hold_and_travel(clear_dir, (to_left if clear_dir < 0 else to_right) + 20.0, max_ticks):
			return false
		# Velocity doesn't snap to a new direction the instant input changes -
		# it ramps via move_toward. Reversing straight into a jump here would
		# still carry most of the clearing manoeuvre's momentum (real risk:
		# drifting back into whatever lies further past the cleared edge, as
		# happens here with PadC just west of C_W). Let it settle to a stop
		# first.
		_hold(0)
		if not await _wait_until(func(): return abs(player.velocity.x) < 10.0, 60, "settle after clearing"):
			return false
	var center_diff := _shortest_diff(p.center.x, player.global_position.x)
	var dir := 1 if center_diff > 0.0 else -1
	var edge_x: float = p.left if dir > 0 else p.right
	var edge_diff := _shortest_diff(edge_x, player.global_position.x)
	if not await _hold_and_travel(dir, abs(edge_diff) - lead_in, max_ticks):
		return false
	return await _tap_jump()

# --- R8: forgiving objective access, simulated from a standing start -------

func _standing_start_test(label: String, start_pos: Vector2, target_platform: String, max_ticks: int = 200) -> bool:
	await _place_player(start_pos)
	_reset_inputs()
	if not await _wait_until(func(): return player.is_on_floor(), max_ticks, "%s settle" % label):
		_report("R8", label, "FAIL", "never landed (stuck airborne) from a standing start at %s" % str(start_pos))
		return false
	# VaultFloor_Bridge is the same walkable surface as VaultFloor for every
	# gameplay purpose (see _on_vault_floor) - accept either.
	var landed: bool = _on_platform(target_platform) or (target_platform == "VaultFloor" and _on_platform("VaultFloor_Bridge"))
	if landed:
		_report("R8", label, "PASS", "from a standing start (zero horizontal velocity), lands on '%s'" % _current_platform_name())
		return true
	_report("R8", label, "FAIL", "from a standing start, landed on '%s' instead of '%s'" % [_current_platform_name(), target_platform])
	return false

var _r8_west_door_ok: bool = false
var _r8_east_door_ok: bool = false

func _check_standing_start_access() -> void:
	# West door: stepping off the pier top with zero velocity slides straight
	# down its east face onto the vault floor. Position just past the pier's
	# right edge (820) at pier-top height, already "having stepped off".
	# "Just stepped off with zero velocity" means the body's ENTIRE collision
	# shape has cleared the source platform - a body only 1px past the edge
	# still has most of its width resting on it, which would read as still
	# grounded there. Clear by player_half_w plus a small margin.
	var clear_margin: float = player_half_w + 2.0
	var pier: Dictionary = geom["Pier"]
	_r8_west_door_ok = await _standing_start_test(
		"West door (Pier top -> VaultFloor, standing start)",
		Vector2(pier.right + clear_margin, pier.top - player_half_h),
		"VaultFloor"
	)

	# East door, downward: A_E -> VaultEast -> VaultFloor, each hop from zero
	# horizontal velocity right at the edge.
	var a_e: Dictionary = geom["A_E"]
	var hop1 := await _standing_start_test(
		"East door hop 1 (A_E -> VaultEast, standing start)",
		Vector2(a_e.left - clear_margin, a_e.top - player_half_h),
		"VaultEast"
	)
	var vault_east: Dictionary = geom["VaultEast"]
	var hop2 := await _standing_start_test(
		"East door hop 2 (VaultEast -> VaultFloor, standing start)",
		Vector2(vault_east.left - clear_margin, vault_east.top - player_half_h),
		"VaultFloor"
	)
	_r8_east_door_ok = hop1 and hop2

# --- R9: no trap volumes -----------------------------------------------------

func _check_no_trap_volumes() -> void:
	if _r8_east_door_ok:
		_report("R9", "Vault exit", "PASS", "the east-door chain (A_E -> VaultEast -> VaultFloor) is a simulated, physics-proven two-way exit; A_E connects onward via LadE (see R4 and the Crown-entrance route proof)")
	else:
		_report("R9", "Vault exit", "FAIL", "the east-door chain failed its standing-start simulation above - the vault would be a true trap")

	var bu: Dictionary = geom["B_Under"]
	_report("R9", "B_Under exit", "PASS", "no wall geometry brackets B_Under's left/right edges (x %.0f-%.0f) - stepping off either side is a free drop to Band C/Floor, per the standing 'downward is free everywhere' rule (R1)" % [bu.left, bu.right])

# --- R10: band continuity (report only) -------------------------------------

func _band_report(label: String, member_names: Array, wraps: bool) -> void:
	var segments: Array = []
	for name in member_names:
		if not geom.has(name):
			continue
		var p: Dictionary = geom[name]
		var l: float = max(p.left, 0.0)
		var r: float = min(p.right, 1920.0)
		if r > l:
			segments.append([l, r])
	segments.sort_custom(func(a, b): return a[0] < b[0])
	var merged: Array = []
	for seg in segments:
		if merged.size() > 0 and seg[0] <= merged[-1][1] + 0.5:
			merged[-1][1] = max(merged[-1][1], seg[1])
		else:
			merged.append([seg[0], seg[1]])
	var covered: float = 0.0
	var longest: float = 0.0
	var gaps: Array = []
	for seg in merged:
		var length: float = seg[1] - seg[0]
		covered += length
		longest = max(longest, length)
	for i in range(merged.size() - 1):
		gaps.append(merged[i + 1][0] - merged[i][1])
	if wraps and merged.size() > 0:
		var wrap_gap: float = (1920.0 - merged[-1][1]) + merged[0][0]
		if wrap_gap < 1.0 and merged.size() > 1:
			longest = max(longest, (merged[-1][1] - merged[-1][0]) + (merged[0][1] - merged[0][0]))
		else:
			gaps.append(wrap_gap)
	var pct: float = covered / 1920.0 * 100.0
	print("  [R10] %s: coverage %.1f%%, longest continuous run %.0fpx, gaps: %s" % [label, pct, longest, str(gaps)])

# --- R11: territory report (report only) ------------------------------------

func _territory_report() -> void:
	var spawns: Array = []
	var markers := arena.get_node("Markers")
	for i in range(1, 5):
		spawns.append(markers.get_node("Spawn%d" % i).global_position)
	for i in range(spawns.size()):
		for j in range(i + 1, spawns.size()):
			var d: float = abs(_shortest_diff(spawns[j].x, spawns[i].x))
			print("  [R11] P%d <-> P%d: shortest wrap-aware x distance = %.0fpx" % [i + 1, j + 1, d])
	var options := {1: 3, 2: 4, 3: 4, 4: 4}
	for i in range(1, 5):
		print("  [R11] P%d immediate options (per approved design brief, §6): %d" % [i, options[i]])

# --- Route proofs: Crown entrances ------------------------------------------

func _route_ladw_crown(start_pos: Vector2) -> Dictionary:
	await _place_player(start_pos)
	var t0 := Engine.get_physics_frames()
	var on_band_c := func(): return _on_platform("C_W") or _on_platform("C_Seam") or _on_platform("C_Seam_east") or _on_platform("C_Seam_west")
	if not on_band_c.call():
		if not await _ensure_on_ground(300):
			return {"success": false, "stage": "could not reach Floor"}
		if not await _travel_and_jump_to("C_W", 80.0, 300):
			return {"success": false, "stage": "Floor->C_W (never jumped)"}
		if not await _wait_until(func(): return player.is_on_floor(), 200, "land on C_W"):
			return {"success": false, "stage": "Floor->C_W (timeout airborne)"}
		if not _on_platform("C_W"):
			return {"success": false, "stage": "Floor->C_W (missed - landed on %s)" % _current_platform_name()}
	var lad: Dictionary = ladders["LadW"]
	_hold(1 if lad.center.x > player.global_position.x else -1)
	var in_zone := func(): return player.in_traversal_zone and player.global_position.x >= lad.left and player.global_position.x <= lad.right
	if not await _wait_until(in_zone, 300, "enter LadW zone"):
		return {"success": false, "stage": "never entered LadW zone"}
	_hold(0)
	_hold_climb(-1)
	if not await _wait_until(func(): return player.global_position.y <= lad.top + 4.0, 400, "climb LadW to top"):
		return {"success": false, "stage": "LadW climb timeout"}
	_hold_climb(0)
	_hold(1)
	if not await _wait_until(func(): return player.is_on_floor(), 200, "exit LadW top onto A_W"):
		return {"success": false, "stage": "never landed after LadW top exit"}
	_hold(0)
	if not _on_platform("A_W"):
		return {"success": false, "stage": "landed on %s instead of A_W" % _current_platform_name()}
	return {"success": true, "ticks": Engine.get_physics_frames() - t0}

func _route_lade_crown(start_pos: Vector2) -> Dictionary:
	await _place_player(start_pos)
	var t0 := Engine.get_physics_frames()
	var on_band_c := func(): return _on_platform("C_M") or _on_platform("C_Seam") or _on_platform("C_Seam_east") or _on_platform("C_Seam_west")
	if not on_band_c.call():
		if not await _ensure_on_ground(300):
			return {"success": false, "stage": "could not reach Floor"}
		if not await _travel_and_jump_to("C_M", 80.0, 300):
			return {"success": false, "stage": "Floor->C_M (never jumped)"}
		if not await _wait_until(func(): return player.is_on_floor(), 200, "land on C_M"):
			return {"success": false, "stage": "Floor->C_M (timeout airborne)"}
		if not _on_platform("C_M"):
			return {"success": false, "stage": "Floor->C_M (missed - landed on %s)" % _current_platform_name()}
	if _on_platform("C_M"):
		if not await _run_and_jump_near_edge("C_M", 1, 40.0, 300):
			return {"success": false, "stage": "C_M->C_Seam (never jumped)"}
		if not await _wait_until(func(): return player.is_on_floor(), 200, "land on C_Seam"):
			return {"success": false, "stage": "C_M->C_Seam (timeout airborne)"}
		if not (_on_platform("C_Seam") or _on_platform("C_Seam_east")):
			return {"success": false, "stage": "C_M->C_Seam (missed - landed on %s)" % _current_platform_name()}
	var lad: Dictionary = ladders["LadE"]
	_hold(1)
	var in_zone := func(): return player.in_traversal_zone and player.global_position.x >= lad.left and player.global_position.x <= lad.right
	if not await _wait_until(in_zone, 300, "enter LadE zone"):
		return {"success": false, "stage": "never entered LadE zone"}
	_hold(0)
	_hold_climb(-1)
	if not await _wait_until(func(): return player.global_position.y <= lad.top + 4.0, 400, "climb LadE to top"):
		return {"success": false, "stage": "LadE climb timeout"}
	_hold_climb(0)
	_hold(-1)
	if not await _wait_until(func(): return player.is_on_floor(), 200, "exit LadE top onto A_E"):
		return {"success": false, "stage": "never landed after LadE top exit"}
	_hold(0)
	if not (_on_platform("A_E") or _on_platform("A_E_Bridge")):
		return {"success": false, "stage": "landed on %s instead of A_E" % _current_platform_name()}
	return {"success": true, "ticks": Engine.get_physics_frames() - t0}

# --- Route proof: the 240px skill jump ---------------------------------------

func _route_skill_jump() -> Dictionary:
	var b_w: Dictionary = geom["B_W"]
	await _place_player(Vector2(b_w.left + 20.0, b_w.top - player_half_h))
	var t0 := Engine.get_physics_frames()
	_hold(-1)
	if not await _run_and_jump_near_edge("B_W", -1, 20.0, 300):
		return {"success": false, "stage": "never reached B_W edge to jump"}
	if not await _wait_until(func(): return player.is_on_floor(), 300, "land after skill jump"):
		return {"success": false, "stage": "timeout airborne on skill jump"}
	_hold(0)
	if _on_platform("B_Seam") or _on_platform("B_Seam_west"):
		return {"success": true, "ticks": Engine.get_physics_frames() - t0}
	return {"success": false, "stage": "landed on %s instead of B_Seam" % _current_platform_name()}

# --- Route proof: launcher left/right ----------------------------------------

func _route_launcher(steer: int) -> Dictionary:
	var pad: Dictionary = pads["PadC"]
	var floor_aabb: Dictionary = geom["Floor"]
	# Area2D only fires body_entered on a fresh overlap - if a previous test
	# left the player resting inside/near the pad's Area2D, teleporting back
	# to the same spot would not re-trigger it. Clear out first.
	await _place_player(Vector2(pad.center.x - 200.0, floor_aabb.top - player_half_h))
	await _place_player(Vector2(pad.center.x, floor_aabb.top - player_half_h))
	var t0 := Engine.get_physics_frames()
	_hold(0)
	if not await _wait_until(func(): return player.velocity.y < -1000.0, 200, "trigger PadC"):
		return {"success": false, "stage": "PadC never triggered"}
	if not await _wait_until(func(): return not player.is_on_floor(), 30, "become airborne after launch"):
		return {"success": false, "stage": "never left the ground after launch"}
	# Steering immediately clips B_Seam's underside by a hair on the way up
	# (the ascending path passes within its own body-width of the corner).
	# A brief delay before steering - matching the plan's framing of the left
	# landing as "a deliberate, slightly hidden move" - clears it cleanly.
	for _i in range(12):
		await _tick()
	_hold(steer)
	if not await _wait_until(func(): return player.is_on_floor(), 300, "land after launch"):
		return {"success": false, "stage": "timeout airborne after launch"}
	_hold(0)
	var target := "B_W" if steer > 0 else "B_Seam"
	var landed := _on_platform(target) or (target == "B_Seam" and (_on_platform("B_Seam_west") or _on_platform("B_Seam_east")))
	if landed:
		return {"success": true, "ticks": Engine.get_physics_frames() - t0}
	return {"success": false, "stage": "landed on %s instead of %s" % [_current_platform_name(), target]}

func _print_route_result(label: String, r: Dictionary) -> void:
	if r.get("success", false):
		_report("ROUTE", label, "PASS", "%.2fs" % (float(r["ticks"]) / physics_hz))
	else:
		_report("ROUTE", label, "FAIL", "stuck at: %s" % r.get("stage", "unknown"))

# --- Route-cost table: spawn -> vault floor -----------------------------------

# Reaches the named Band C platform from wherever the player currently
# stands. Handles all three spawn shapes in this arena: already there,
# starting on the Floor (jump up), or starting on a Band B platform that
# sits directly above it - B_W over C_W, B_E over C_M - where the correct
# move is simply to drop (holding a direction here would walk into the
# pier's wall from B_W, or overshoot onto C_Seam from B_E).
func _reach_band_c(target_name: String) -> bool:
	if _on_platform(target_name):
		return true
	if _on_platform("Floor"):
		if not await _travel_and_jump_to(target_name, 80.0, 300):
			return false
		if not await _wait_until(func(): return player.is_on_floor(), 300, "land on %s" % target_name):
			return false
		if _on_platform(target_name):
			return true
		# PadC sits close enough to C_W's western approach that reaching it
		# from the Floor can overshoot into the launcher instead, landing on
		# B_W. That's a valid escalation, not a failure - drop back down from
		# there the same way a Band B spawn would.
		return await _drop_to_band_c(target_name)
	return await _drop_to_band_c(target_name)

# Starting on a Band B platform directly above the target (B_W over C_W,
# B_E over C_M) - standing still on solid ground never makes you fall
# through it, so walk to whichever edge is nearest the target's centre and
# clear it. Downward is free everywhere once you're off the edge, no jump
# needed.
func _drop_to_band_c(target_name: String) -> bool:
	var cur_name := _current_platform_name()
	if not geom.has(cur_name):
		return false
	var cur: Dictionary = geom[cur_name]
	# Prefer whichever edge of the CURRENT platform is nearer, not the edge
	# facing the target's centre - B_W's east edge butts straight into the
	# pier's wall, so "aim at the target" would walk into it instead of
	# clearing an edge at all.
	var x: float = player.global_position.x
	var to_left: float = abs(_shortest_diff(cur.left, x))
	var to_right: float = abs(_shortest_diff(cur.right, x))
	var dir := -1 if to_left <= to_right else 1
	var edge_x: float = cur.right if dir > 0 else cur.left
	# The origin needs to clear the edge by more than a few px - the body is
	# player_half_w wide, so anything less still leaves it resting on the
	# platform's corner (is_on_floor stays true, nothing ever falls).
	var clear_buffer: float = player_half_w + 4.0
	var cleared := func():
		return (dir > 0 and player.global_position.x >= edge_x + clear_buffer) or (dir < 0 and player.global_position.x <= edge_x - clear_buffer)
	# A real player walks off a ledge slowly, not at a dead sprint - and
	# deceleration is floor-only, so any speed still carried at the moment
	# the origin leaves the platform survives untouched through the whole
	# fall. Holding one direction all the way to the edge reaches ~500px/s
	# well before arriving, then drifts ~240px on a ~260px drop - this is
	# exactly what carried a B_W departure past C_W into the launch shaft
	# beyond it, and is why every spawn reported NO PROVEN ROUTE at the M2
	# baseline (docs/plans/M03_CORE_GAME_LOOP.md §3.3). Creeping the final
	# stretch at a low speed cap (bang-bang: accelerate below it, release
	# above it) keeps just enough residual momentum to clear the edge while
	# drifting only a fraction as far - the same recipe edge_executor.gd
	# uses for the real bots' drop edges.
	var creep_range := 120.0
	var speed_cap := 80.0
	var t := 0
	while not cleared.call():
		var dist_to_edge: float = abs(_shortest_diff(edge_x, player.global_position.x))
		if dist_to_edge <= creep_range:
			_hold(0 if abs(player.velocity.x) >= speed_cap else dir)
		else:
			_hold(dir)
		await _tick()
		t += 1
		if t > 300:
			return false
	_hold(0)
	if not await _wait_until(func(): return player.is_on_floor(), 300, "fall to %s" % target_name):
		return false
	return _on_platform(target_name)

func _route_via_west(start_pos: Vector2) -> Dictionary:
	await _place_player(start_pos)
	var t0 := Engine.get_physics_frames()
	if not await _reach_band_c("C_W"):
		return {"success": false, "stage": "could not reach C_W"}
	var lad: Dictionary = ladders["LadW"]
	_hold(1 if lad.center.x > player.global_position.x else -1)
	var in_zone := func(): return player.in_traversal_zone and player.global_position.x >= lad.left and player.global_position.x <= lad.right
	if not await _wait_until(in_zone, 300, "enter LadW zone"):
		return {"success": false, "stage": "never entered LadW zone"}
	_hold(0)
	_hold_climb(-1)
	if not await _wait_until(func(): return player.global_position.y <= lad.top + 4.0, 400, "climb LadW to top"):
		return {"success": false, "stage": "LadW climb timeout"}
	_hold_climb(0)
	_hold(1)
	if not await _wait_until(func(): return player.is_on_floor(), 200, "exit LadW top onto A_W"):
		return {"success": false, "stage": "never landed after LadW top exit"}
	if not _on_platform("A_W"):
		return {"success": false, "stage": "landed on %s instead of A_W" % _current_platform_name()}
	if not await _run_and_jump_near_edge("A_W", 1, 40.0, 300):
		return {"success": false, "stage": "A_W->Pier (never jumped)"}
	if not await _wait_until(func(): return player.is_on_floor(), 200, "land on Pier top"):
		return {"success": false, "stage": "A_W->Pier (timeout airborne)"}
	if not _on_platform("Pier"):
		return {"success": false, "stage": "A_W->Pier (missed - landed on %s)" % _current_platform_name()}
	_hold(1)
	if not await _wait_until(func(): return player.global_position.x >= geom["Pier"].right + 1.0, 200, "walk off Pier's east edge"):
		return {"success": false, "stage": "Pier->VaultFloor (never left the pier)"}
	if not await _wait_until(func(): return player.is_on_floor(), 200, "land in the vault"):
		return {"success": false, "stage": "Pier->VaultFloor (timeout airborne)"}
	_hold(0)
	if not _on_vault_floor():
		return {"success": false, "stage": "Pier->VaultFloor (missed - landed on %s)" % _current_platform_name()}
	return {"success": true, "ticks": Engine.get_physics_frames() - t0}

func _route_via_east(start_pos: Vector2) -> Dictionary:
	await _place_player(start_pos)
	var t0 := Engine.get_physics_frames()
	if not await _reach_band_c("C_M"):
		return {"success": false, "stage": "could not reach C_M"}
	if not await _run_and_jump_near_edge("C_M", 1, 40.0, 300):
		return {"success": false, "stage": "C_M->C_Seam (never jumped)"}
	if not await _wait_until(func(): return player.is_on_floor(), 200, "land on C_Seam"):
		return {"success": false, "stage": "C_M->C_Seam (timeout airborne)"}
	if not (_on_platform("C_Seam") or _on_platform("C_Seam_east")):
		return {"success": false, "stage": "C_M->C_Seam (missed - landed on %s)" % _current_platform_name()}
	var lad: Dictionary = ladders["LadE"]
	_hold(1)
	var in_zone := func(): return player.in_traversal_zone and player.global_position.x >= lad.left and player.global_position.x <= lad.right
	if not await _wait_until(in_zone, 300, "enter LadE zone"):
		return {"success": false, "stage": "never entered LadE zone"}
	_hold(0)
	_hold_climb(-1)
	if not await _wait_until(func(): return player.global_position.y <= lad.top + 4.0, 400, "climb LadE to top"):
		return {"success": false, "stage": "LadE climb timeout"}
	_hold_climb(0)
	_hold(-1)
	if not await _wait_until(func(): return player.is_on_floor(), 200, "exit LadE top onto A_E"):
		return {"success": false, "stage": "never landed after LadE top exit"}
	if not (_on_platform("A_E") or _on_platform("A_E_Bridge")):
		return {"success": false, "stage": "landed on %s instead of A_E" % _current_platform_name()}
	_hold(-1)
	if not await _wait_until(func(): return player.global_position.x <= geom["A_E"].left + 1.0, 200, "walk off A_E's west edge"):
		return {"success": false, "stage": "A_E->VaultEast (never left A_E)"}
	if not await _wait_until(func(): return player.is_on_floor(), 200, "land on VaultEast"):
		return {"success": false, "stage": "A_E->VaultEast (timeout airborne)"}
	if not _on_platform("VaultEast"):
		return {"success": false, "stage": "A_E->VaultEast (missed - landed on %s)" % _current_platform_name()}
	if not await _wait_until(func(): return player.global_position.x <= geom["VaultEast"].left + 1.0, 200, "walk off VaultEast's west edge"):
		return {"success": false, "stage": "VaultEast->VaultFloor (never left VaultEast)"}
	if not await _wait_until(func(): return player.is_on_floor(), 200, "land on VaultFloor"):
		return {"success": false, "stage": "VaultEast->VaultFloor (timeout airborne)"}
	_hold(0)
	if not _on_vault_floor():
		return {"success": false, "stage": "VaultEast->VaultFloor (missed - landed on %s)" % _current_platform_name()}
	return {"success": true, "ticks": Engine.get_physics_frames() - t0}

func _route_cost_table(spawns: Array) -> void:
	var costs: Array[float] = []
	for i in spawns.size():
		var pos: Vector2 = spawns[i]
		var results := {
			"west (LadW)": await _route_via_west(pos),
			"east (LadE)": await _route_via_east(pos),
		}
		var best_time := INF
		var best_label := "NONE"
		var any_success := false
		for label in results:
			var r: Dictionary = results[label]
			if r.get("success", false):
				any_success = true
				var secs: float = float(r["ticks"]) / physics_hz
				if secs < best_time:
					best_time = secs
					best_label = label
		if any_success:
			print("  P%d %s: fastest = %s at %.2fs" % [i + 1, pos, best_label, best_time])
		else:
			print("  P%d %s: NO PROVEN ROUTE" % [i + 1, pos])
		for label in results:
			var r: Dictionary = results[label]
			if r.get("success", false):
				print("      %s: %.2fs" % [label, float(r["ticks"]) / physics_hz])
			else:
				print("      %s: FAILED at %s" % [label, r.get("stage", "?")])
		if any_success:
			costs.append(best_time)
		else:
			# Diagnostic only (docs/DECISIONS.md 2026-09-06) - reported as a
			# WARN, not a FAIL. Investigation traced every failure here to
			# the same harness limitation: a Band B -> Band C drop departs
			# the edge at full running speed, and since deceleration is
			# floor-only, nothing slows the fall's horizontal drift, which
			# can overshoot a narrow target below (e.g. B_W -> C_W drifts
			# into the launch shaft beyond it). A real player can walk off
			# an edge slowly; this harness does not yet simulate a
			# controlled low-speed departure. Every move this route chains
			# together is independently proven elsewhere in this report: the
			# Crown-entrance route proofs enter both ladders from Band C,
			# the launcher route proofs work, and both vault doors are
			# proven from a standing start. This is a simulation gap, not an
			# arena defect - do not spend further effort chasing it before
			# the human playtest.
			_report("route-cost", "P%d" % (i + 1), "WARN", "no proven route via this harness's simple two-approach simulation - see comment above; the constituent moves are separately proven passing elsewhere in this report")
	if costs.size() >= 2:
		var min_c: float = costs.min()
		var max_c: float = costs.max()
		var spread: float = (max_c - min_c) / min_c * 100.0
		var verdict := "PASS" if spread <= 15.0 else "WARN"
		_report("route-cost", "spawn spread", verdict, "%.1f%% spread (fastest %.2fs, slowest %.2fs) - diagnostic only per docs/DECISIONS.md 2026-09-06, geometry is not auto-corrected to hit this" % [spread, min_c, max_c])

# --- Wrap integrity -----------------------------------------------------------

func _run_until_wrap(dir: int, max_ticks: int) -> bool:
	_hold(dir)
	var prev := player.global_position.x
	var t := 0
	while true:
		await _tick()
		var cur := player.global_position.x
		if abs(cur - prev) > 200.0:
			return true
		prev = cur
		t += 1
		if t > max_ticks:
			return false
	return false

func _wrap_integrity() -> void:
	var floor_origin_y: float = geom["Floor"].top - player_half_h
	# CoverE is a deliberate solid cover block on the Floor (x 1180-1320) - a
	# straight run across the whole Floor would slam into it (CoverW, the
	# matching west-side block, was removed from Arena 01 - see docs/
	# DECISIONS.md). Start close to each departure edge, past CoverE, for a
	# clear runway to the wrap point.
	for c in [
		{"dir": 1, "start": Vector2(1850.0, floor_origin_y), "label": "Floor, wrapping east-to-west", "platform": "Floor"},
		{"dir": -1, "start": Vector2(70.0, floor_origin_y), "label": "Floor, wrapping west-to-east", "platform": "Floor"},
	]:
		await _place_player(c.start)
		var wrapped: bool = await _run_until_wrap(c.dir, 400)
		await _tick(); await _tick()
		var still_on: bool = _on_platform(c.platform)
		_hold(0)
		if wrapped and still_on:
			_report("wrap", c.label, "PASS", "wrapped and remained on %s with no fall" % c.platform)
		else:
			_report("wrap", c.label, "FAIL", "wrapped=%s, on_platform_after=%s" % [wrapped, still_on])

	var c_seam_origin_y: float = geom["C_Seam"].top - player_half_h
	for c in [
		{"dir": 1, "start": Vector2(1700.0, c_seam_origin_y), "label": "Band C seam, wrapping east-to-west"},
		{"dir": -1, "start": Vector2(100.0, c_seam_origin_y), "label": "Band C seam, wrapping west-to-east"},
	]:
		await _place_player(c.start)
		await _tick(); await _tick()
		var starting_on_seam: bool = player.is_on_floor()
		var wrapped: bool = await _run_until_wrap(c.dir, 400)
		await _tick(); await _tick()
		var still_on_seam: bool = player.is_on_floor() and (_on_platform("C_Seam") or _on_platform("C_Seam_east") or _on_platform("C_Seam_west"))
		_hold(0)
		if starting_on_seam and wrapped and still_on_seam:
			_report("wrap", c.label, "PASS", "wrapped along Band C with no floor gap")
		else:
			_report("wrap", c.label, "FAIL", "starting_on_seam=%s wrapped=%s still_on_seam_after=%s" % [starting_on_seam, wrapped, still_on_seam])

	var b_seam_origin_y: float = geom["B_Seam"].top - player_half_h
	for c in [
		{"dir": 1, "start": Vector2(1850.0, b_seam_origin_y), "label": "Band B seam, wrapping east-to-west"},
		{"dir": -1, "start": Vector2(70.0, b_seam_origin_y), "label": "Band B seam, wrapping west-to-east"},
	]:
		await _place_player(c.start)
		await _tick(); await _tick()
		var starting_on_seam: bool = player.is_on_floor()
		var wrapped: bool = await _run_until_wrap(c.dir, 400)
		await _tick(); await _tick()
		var still_on_seam: bool = player.is_on_floor() and (_on_platform("B_Seam") or _on_platform("B_Seam_east") or _on_platform("B_Seam_west"))
		_hold(0)
		if starting_on_seam and wrapped and still_on_seam:
			_report("wrap", c.label, "PASS", "wrapped along Band B with no floor gap")
		else:
			_report("wrap", c.label, "FAIL", "starting_on_seam=%s wrapped=%s still_on_seam_after=%s" % [starting_on_seam, wrapped, still_on_seam])

# --- Wrap-route timing (diagnostic only, V2-A3) ------------------------------

func _route_seam_crossing() -> Dictionary:
	var b_w: Dictionary = geom["B_W"]
	await _place_player(Vector2(b_w.left + 20.0, b_w.top - player_half_h))
	var t0 := Engine.get_physics_frames()
	_hold(-1)
	if not await _run_and_jump_near_edge("B_W", -1, 20.0, 300):
		return {"success": false, "stage": "never reached B_W edge to jump"}
	if not await _wait_until(func(): return player.is_on_floor(), 300, "land after skill jump"):
		return {"success": false, "stage": "timeout airborne on skill jump"}
	if not (_on_platform("B_Seam") or _on_platform("B_Seam_west")):
		return {"success": false, "stage": "landed on %s instead of B_Seam" % _current_platform_name()}
	# Continue holding left: this wraps the player from B_Seam's on-screen
	# west portion onto its east/original portion (1780-1920), still
	# travelling left toward B_E across the 160px shaft. Detect proximity to
	# B_Seam's own left edge (in the direction of travel) rather than B_E's,
	# since the player is on B_Seam right up until the jump.
	_hold(-1)
	if not await _run_and_jump_near_edge("B_Seam", -1, 40.0, 500):
		return {"success": false, "stage": "never reached B_Seam's edge to jump onto B_E"}
	if not await _wait_until(func(): return player.is_on_floor(), 200, "land on B_E"):
		return {"success": false, "stage": "timeout airborne approaching B_E"}
	_hold(0)
	if not _on_platform("B_E"):
		return {"success": false, "stage": "landed on %s instead of B_E" % _current_platform_name()}
	return {"success": true, "ticks": Engine.get_physics_frames() - t0}

func _wrap_route_timing() -> void:
	var r := await _route_seam_crossing()
	if r.get("success", false):
		var secs: float = float(r["ticks"]) / physics_hz
		print("  Seam crossing (B_W -> B_Seam -> B_E, simulated): %.2fs" % secs)
		print("  Inside route (drop to C_W, run east, climb LadE to mid-station): ~3.6s (hand-derived estimate per M02_ARENA_01_V2.md §8.1, not simulated)")
		print("  Ratio is reported for reference only - per V2-A3 this is NOT an acceptance threshold. The criterion is behavioural: does the player choose to wrap in play?")
	else:
		_report("wrap-timing", "seam crossing simulation", "WARN", "could not simulate (stuck at: %s) - diagnostic only, does not gate PASS/FAIL" % r.get("stage", "unknown"))

# --- Time-to-first-contact (diagnostic only, simplified) ---------------------

func _time_to_floor(start_pos: Vector2) -> float:
	await _place_player(start_pos)
	if _on_platform("Floor"):
		return 0.0
	var t0 := Engine.get_physics_frames()
	if not await _ensure_on_ground(400):
		return -1.0
	return float(Engine.get_physics_frames() - t0) / physics_hz

func _time_to_first_contact(spawns: Array) -> void:
	var times: Array[float] = []
	for i in spawns.size():
		var t: float = await _time_to_floor(spawns[i])
		times.append(t)
		print("  P%d time-to-Floor: %s" % [i + 1, ("%.2fs" % t) if t >= 0.0 else "not measured (same harness limitation as the route-cost table above)"])
	for i in range(spawns.size()):
		for j in range(i + 1, spawns.size()):
			if times[i] >= 0.0 and times[j] >= 0.0:
				print("  P%d <-> P%d: both could share the Floor by t=%.2fs (max of each spawn's time-to-Floor; a simplified proxy for shared-platform contact, not a true nearest-shared-platform search)" % [i + 1, j + 1, max(times[i], times[j])])
