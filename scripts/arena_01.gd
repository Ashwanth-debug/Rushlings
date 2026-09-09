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

@onready var _slots_container: Node2D = $PlayerSlots
@onready var _markers: Node2D = $Markers

var match_config
var geometry
var nav_graph
var players: Array = []
var brains: Array = []

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
	_wire_bots()
	set_label_visibility(labels_visible)
	set_player_collision(collision_enabled)
	# Dev-only human-traversal recorder (Director request, 2026-09-07): P1
	# only, toggled with debug_record_traversal - see traversal_recorder.gd.
	traversal_recorder = TraversalRecorderScript.new(players[0], geometry)

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
			players[i], geometry, nav_graph, cfg.slot_id, match_config.match_seed,
			other_bodies, Callable(self, "_on_bot_hard_recovery"), match_config.curiosity_player_prob
		)
		brains[i] = brain
		players[i].controller = BotControllerScript.new(brain)

func _on_bot_hard_recovery(slot_id: int) -> void:
	var idx := slot_id - 1
	var spawn_name := "Spawn%d" % slot_id
	if _markers.has_node(spawn_name):
		players[idx].reset_to(_markers.get_node(spawn_name).global_position)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug_reset"):
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
