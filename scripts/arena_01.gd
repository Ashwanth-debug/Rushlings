extends Node2D

# M3-1 four-player foundation. Spawns the four PlayerSlots per MatchConfig,
# builds the shared ArenaGeometry + NavGraph once, and wires a BotBrain +
# BotController to every BOT slot. P1 keeps today's HumanController.
#
# Dev-only toggles for the M3-1 human playtest (docs/plans/M03_CORE_GAME_LOOP.md
# §10): P1-P4 labels on/off, player<->player collision on/off, and
# Engine.time_scale 1.0/1.25 for the tempo A/B. None of these are permanent
# product decisions - see docs/DECISIONS.md, 2026-09-06 entries on both.

const HumanControllerScript := preload("res://scripts/human_controller.gd")
const BotControllerScript := preload("res://scripts/bot_controller.gd")
const BotBrainScript := preload("res://scripts/bot_brain.gd")
const ArenaGeometryScript := preload("res://scripts/arena_geometry.gd")
const NavGraphScript := preload("res://scripts/nav_graph.gd")
const MatchConfigScript := preload("res://scripts/match_config.gd")
const TraversalRecorderScript := preload("res://scripts/traversal_recorder.gd")
const PickupFieldScript := preload("res://scripts/pickup_field.gd")

@onready var _slots_container: Node2D = $PlayerSlots
@onready var _markers: Node2D = $Markers
@onready var match_director: MatchDirector = $MatchDirector
@onready var relic: Area2D = $Relic
@onready var match_telemetry = $MatchTelemetry
@onready var power_system: PowerSystem = $PowerSystem
@onready var health_system: HealthSystem = $HealthSystem
@onready var _pickups_container: Node2D = $Pickups
@onready var _projectiles_container: Node2D = $Projectiles

var match_config
var geometry
var nav_graph
var players: Array = []
var brains: Array = []
var round_index: int = 0
var pickup_field
var contact_lab_active: bool = false

var labels_visible: bool = true
var collision_enabled: bool = false
var nav_mode: int = BotBrainScript.Mode.NORMAL_ROAM
var traversal_recorder

func _ready() -> void:
	match_config = MatchConfigScript.new()
	labels_visible = match_config.labels_visible
	collision_enabled = match_config.player_collision_enabled
	_spawn_slots()
	_build_navigation()
	_build_pickup_field()
	_wire_bots()
	power_system.configure(players, geometry, _projectiles_container, match_director)
	health_system.configure(players, geometry, _spawn_anchor_positions(), power_system, _pickups_container, pickup_field)
	health_system.player_respawned.connect(_on_player_respawned)
	set_label_visibility(labels_visible)
	set_player_collision(collision_enabled)
	# M3-2 Step 2: nav_graph's vault edges must match MatchDirector's state
	# from the very first frame (SETUP = sealed), not just on later
	# transitions - RelicGate handles the gate's own visuals/collision, this
	# is the bot-routing side of the same state.
	match_director.state_changed.connect(_on_match_state_changed)
	_on_match_state_changed(match_director.state)
	# Dev-only human-traversal recorder (Director request, 2026-09-07): P1
	# only, toggled with debug_record_traversal - see traversal_recorder.gd.
	traversal_recorder = TraversalRecorderScript.new(players[0], geometry)
	# M3-2 Step 5 (S14): dev-only, print-based convergence/fairness telemetry.
	# match_telemetry.arena is set here rather than passed to a constructor -
	# MatchTelemetry is a real scene node (its own _ready() already ran and
	# wired MatchDirector's state_changed signal) so it needs a back-reference
	# to the arena for players/geometry/nav_graph/brains, not a rebuild.
	match_telemetry.arena = self

func _spawn_slots() -> void:
	var spawns: Array = [
		_markers.get_node("Spawn1"), _markers.get_node("Spawn2"),
		_markers.get_node("Spawn3"), _markers.get_node("Spawn4"),
	]
	for i in range(match_config.slots.size()):
		var cfg = match_config.slots[i]
		var p: CharacterBody2D = _slots_container.get_node("Slot%d" % cfg.slot_id)
		p.configure(cfg.slot_id, cfg.color)
		p.reset_to(spawns[i].global_position)
		if cfg.controller_kind == MatchConfigScript.ControllerKind.HUMAN_LOCAL:
			p.controller = HumanControllerScript.new()
		players.append(p)
		brains.append(null)

func _build_navigation() -> void:
	var shape := players[0].get_node("CollisionShape2D").shape as RectangleShape2D
	var half_w: float = shape.size.x * 0.5
	var half_h: float = shape.size.y * 0.5
	geometry = ArenaGeometryScript.new(self, half_w, half_h)
	nav_graph = NavGraphScript.new(geometry)

## M4-1 STOP 1 - one PickupField built from whatever PowerPickup instances
## exist under $Pickups in the scene (see scenes/arena_01/arena_01.tscn),
## handed to every bot brain below. Built once per full reset, same lifetime
## as geometry/nav_graph - the pickups themselves persist across rounds
## (only their collected/respawning state changes), unlike bot brains.
func _build_pickup_field() -> void:
	pickup_field = PickupFieldScript.new()
	for pickup in _pickups_container.get_children():
		pickup_field.register(pickup)

## M4-1 STOP 4 - the same four authored Spawn markers _spawn_slots()/
## _full_reset() already use, read once as plain positions for
## HealthSystem's respawn-anchor selection (docs/plans/M04_0_MATCH_SHAPE_DESIGN.md
## S04.3: "reuse the four existing Spawn markers... never arbitrary
## coordinates").
func _spawn_anchor_positions() -> Array:
	return [
		_markers.get_node("Spawn1").global_position, _markers.get_node("Spawn2").global_position,
		_markers.get_node("Spawn3").global_position, _markers.get_node("Spawn4").global_position,
	]

## HealthSystem treats every body identically (CLAUDE.md M4-1 STOP 3+4 S8) -
## this is the one place that knows a respawned slot might be a bot, exactly
## mirroring _on_match_state_changed()'s SETUP branch calling
## brains[i].reset_goal(): a body teleported out from under a live BotBrain
## needs its stale path/executor cleared (see BotBrain.handle_respawn()), or
## nothing at all for P1's HumanController.
func _on_player_respawned(slot_id: int) -> void:
	var idx := slot_id - 1
	if brains[idx] != null:
		brains[idx].handle_respawn()

func _wire_bots() -> void:
	for i in range(match_config.slots.size()):
		var cfg = match_config.slots[i]
		if cfg.controller_kind != MatchConfigScript.ControllerKind.BOT:
			continue
		var other_bodies: Array = []
		for j in range(players.size()):
			if j != i:
				other_bodies.append(players[j])
		var brain = BotBrainScript.new(
			players[i], geometry, nav_graph, cfg.slot_id, _round_base_seed(),
			other_bodies, Callable(self, "_on_bot_hard_recovery"), match_config.curiosity_player_prob, relic.global_position.x
		)
		brain.set_pickup_field(pickup_field)
		brains[i] = brain
		players[i].controller = BotControllerScript.new(brain)

func _on_match_state_changed(new_state: int) -> void:
	nav_graph.set_gate_open(new_state == MatchDirector.State.OPEN)
	# M3-2 Step 3 (approved S12): freeze every controller on RESULTS, and
	# unfreeze on any transition back to SETUP - whether that transition
	# came from a full rematch (_full_reset(), which also hands bots brand
	# new, already-unfrozen controllers) or from a bare debug_setup_10/15/25
	# key press, which resets MatchDirector alone. Centralising this here
	# means neither of those call sites has to remember to unfreeze anyone.
	if new_state == MatchDirector.State.RESULTS:
		for p in players:
			p.controller.set_frozen(true)
	elif new_state == MatchDirector.State.SETUP:
		for p in players:
			p.controller.set_frozen(false)
		# M3-2 Step 4 (S08): a bare debug_setup_10/15/25 key press resets
		# MatchDirector alone, without rebuilding brains (a real rematch's
		# _full_reset() already hands every bot a brand-new brain, where
		# this is a no-op) - a bot must not carry SEEK_RELIC into a
		# freshly re-sealed vault just because the same brain instance
		# survived the reset.
		for i in range(brains.size()):
			if brains[i] != null:
				brains[i].reset_goal()
	elif new_state == MatchDirector.State.OPEN:
		# M3-2 Step 4 (S08): the single authoritative OPEN goal switch.
		# Each brain records the request and its own staggered reaction
		# delay - none of them cancel anything here, see
		# BotBrain.notify_open()/_check_goal_switch().
		for i in range(brains.size()):
			if brains[i] != null:
				brains[i].notify_open()

func _on_bot_hard_recovery(slot_id: int) -> void:
	var idx := slot_id - 1
	var spawn_name := "Spawn%d" % slot_id
	if _markers.has_node(spawn_name):
		players[idx].reset_to(_markers.get_node(spawn_name).global_position)

## Deterministic, non-colliding per-round bot seeds (docs/DECISIONS.md /
## M03_2_CORE_MATCH_LOOP_PLAN.md S13): match_seed + round_index*101 +
## slot_index. BotBrain._init() itself adds `+ slot_index` to whatever base
## seed it's given (see bot_brain.gd), so this returns everything BUT that
## last term - round_index=0 (the initial match) reduces to exactly
## match_config.match_seed, unchanged from pre-Step-3 behaviour.
func _round_base_seed() -> int:
	return match_config.match_seed + round_index * 101

## Rematch (docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md S13): rebuild the
## brains, reset the bodies - not a scene reload, not a giant mutable
## BotBrain.reset(). A fresh BotBrain is, by construction, fully reset (empty
## path, empty blacklist, stress_index 0, hard_recovery_count 0, ...) so
## there is nothing to enumerate. Reused for both the real rematch (R during
## RESULTS) and the debug_setup_10/15/25 keys, so pressing either always
## leaves bodies/brains/gate/relic/HUD in one consistent state - see
## docs/DECISIONS.md's "reset_to() traversal-zone ownership" note: reset_to()
## deliberately does NOT touch in_traversal_zone/climb_top_limit, and this
## function does not either.
func _full_reset(new_setup_duration: float = -1.0) -> void:
	round_index += 1
	var spawns: Array = [
		_markers.get_node("Spawn1"), _markers.get_node("Spawn2"),
		_markers.get_node("Spawn3"), _markers.get_node("Spawn4"),
	]
	for i in range(match_config.slots.size()):
		var cfg = match_config.slots[i]
		players[i].reset_to(spawns[i].global_position)
		if cfg.controller_kind == MatchConfigScript.ControllerKind.BOT:
			var other_bodies: Array = []
			for j in range(players.size()):
				if j != i:
					other_bodies.append(players[j])
			var brain = BotBrainScript.new(
				players[i], geometry, nav_graph, cfg.slot_id, _round_base_seed(),
				other_bodies, Callable(self, "_on_bot_hard_recovery"), match_config.curiosity_player_prob, relic.global_position.x
			)
			brain.set_mode(nav_mode)
			brain.set_pickup_field(pickup_field)
			brains[i] = brain
			players[i].controller = BotControllerScript.new(brain)
	power_system.reset()
	health_system.reset()
	match_director.reset_round(new_setup_duration)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug_reset"):
		# M3-2 Step 3: same physical key (R) doubles as the approved rematch
		# input while RESULTS is showing (matching the "[R] REMATCH" HUD
		# prompt) - RESULTS ignores it until match_director.rematch_ready(),
		# the approved ~1.2s minimum dwell. Outside RESULTS, unchanged M1/M2
		# behaviour: reset P1 to spawn.
		if match_director.state == MatchDirector.State.RESULTS:
			if match_director.rematch_ready():
				_full_reset()
				print("Arena01: rematch - round %d" % round_index)
		else:
			players[0].reset_to(_markers.get_node("Spawn1").global_position)
	if Input.is_action_just_pressed("debug_toggle_labels"):
		labels_visible = not labels_visible
		set_label_visibility(labels_visible)
	if Input.is_action_just_pressed("debug_toggle_collision"):
		collision_enabled = not collision_enabled
		set_player_collision(collision_enabled)
	if Input.is_action_just_pressed("debug_time_scale_1x"):
		Engine.time_scale = 1.0
		print("Arena01: time_scale = 1.0")
	if Input.is_action_just_pressed("debug_time_scale_125x"):
		Engine.time_scale = 1.25
		print("Arena01: time_scale = 1.25")
	if Input.is_action_just_pressed("debug_toggle_nav_mode"):
		set_nav_mode(BotBrainScript.Mode.NAV_STRESS_TEST if nav_mode == BotBrainScript.Mode.NORMAL_ROAM else BotBrainScript.Mode.NORMAL_ROAM)
	if Input.is_action_just_pressed("debug_record_traversal"):
		traversal_recorder.toggle()
	if Input.is_action_just_pressed("debug_restart_nav_stress"):
		restart_nav_stress()
	if Input.is_action_just_pressed("debug_toggle_gate") and match_director.state != MatchDirector.State.RESULTS:
		# M3-2 Step 2 (STOP 2 inspection): force straight to OPEN, or back to
		# a fresh SETUP - both go through MatchDirector.debug_force_*, so the
		# director (and everything driven off it: the gate, the HUD, the nav
		# graph) stays authoritative and cannot be left in a mixed state.
		# Excluded from RESULTS (Step 3): forcing OPEN from there would skip
		# the frozen->unfrozen transition, which only happens on SETUP -
		# press R (rematch) to leave RESULTS instead.
		if match_director.state == MatchDirector.State.OPEN:
			match_director.debug_force_setup()
			print("Arena01: MatchDirector forced to SETUP")
		else:
			match_director.debug_force_open()
			print("Arena01: MatchDirector forced to OPEN")
	if Input.is_action_just_pressed("debug_setup_10"):
		match_director.reset_round(10.0)
		print("Arena01: setup_duration = 10.0, round reset")
	if Input.is_action_just_pressed("debug_setup_15"):
		match_director.reset_round(15.0)
		print("Arena01: setup_duration = 15.0, round reset")
	if Input.is_action_just_pressed("debug_setup_25"):
		match_director.reset_round(25.0)
		print("Arena01: setup_duration = 25.0, round reset")
	if Input.is_action_just_pressed("debug_damage_p1"):
		# M4-1 STOP 3+4 debug key (CLAUDE.md S10): the real pipeline, not a
		# direct health mutation - goes through the exact same apply_damage()
		# a Rocket hit uses, so it exercises defeat/spill/respawn/protection
		# identically for deterministic testing.
		health_system.apply_damage(players[0])
		print("Arena01: debug damage applied to P1 (health=%d/%d)" % [players[0].health, players[0].max_health])
	if Input.is_action_just_pressed("debug_cycle_freeze_duration"):
		power_system.cycle_freeze_duration()
	if Input.is_action_just_pressed("debug_contact_lab"):
		contact_lab_active = not contact_lab_active
		power_system.reset()
		health_system.reset()
		if contact_lab_active:
			match_director.enter_contact_lab()
			print("Arena01: M4-1 Contact Lab ON - Relic sealed and match clock frozen, roam/pickups/powers indefinitely")
		else:
			match_director.exit_contact_lab()
			print("Arena01: M4-1 Contact Lab OFF - back to the accepted M3 match")
	if nav_mode == BotBrainScript.Mode.NAV_STRESS_TEST:
		_update_stress_labels()

func _physics_process(delta: float) -> void:
	traversal_recorder.tick(delta)

## Dev-only NORMAL_ROAM <-> NAV_STRESS_TEST toggle (Director feedback,
## iteration 4). Only affects bot slots - P1's HumanController has no
## concept of a mode.
func set_nav_mode(new_mode: int) -> void:
	nav_mode = new_mode
	for i in range(brains.size()):
		if brains[i] != null:
			brains[i].set_mode(nav_mode)
	if nav_mode == BotBrainScript.Mode.NORMAL_ROAM:
		for i in range(players.size()):
			if brains[i] != null:
				players[i].set_debug_suffix("")
	print("Arena01: nav mode = %s" % ("NAV_STRESS_TEST" if nav_mode == BotBrainScript.Mode.NAV_STRESS_TEST else "NORMAL_ROAM"))

## Dev-only (Director request, 2026-09-08): restart all three bots' NAV
## STRESS destination sequences from the beginning, without restarting the
## game or touching Engine.time_scale/collision/labels - the deliberate 3x
## sequence cap (see bot_brain.gd) means an unattended human observation
## session longer than one full cycle would otherwise read "(sequence
## complete)" as if navigation had failed. Smallest option of the two the
## Director offered - a key that restarts, not a mode that repeats forever
## by default - so a finished run still reads as finished until asked again.
func restart_nav_stress() -> void:
	for i in range(brains.size()):
		if brains[i] != null:
			brains[i].restart_stress_sequence()
	print("Arena01: NAV STRESS sequences restarted")

func _update_stress_labels() -> void:
	for i in range(players.size()):
		if brains[i] != null:
			players[i].set_debug_suffix(brains[i].current_stress_destination())

func set_label_visibility(v: bool) -> void:
	for p in players:
		p.set_label_visible(v)
	print("Arena01: P1-P4 labels %s" % ("ON" if v else "OFF"))

func set_player_collision(v: bool) -> void:
	for p in players:
		p.set_player_collision_enabled(v)
	print("Arena01: player<->player collision %s" % ("ON" if v else "OFF"))
