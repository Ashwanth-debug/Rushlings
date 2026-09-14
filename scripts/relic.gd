extends Area2D

# M4-3 - the Relic is now a carried object, not an instant win (CLAUDE.md
# M4-3 S1: "touch Relic -> become carrier. No winner yet."). This script's
# job shrank to exactly that: detect a valid touch while the Relic is
# sitting in the world (at the chamber pedestal, or wherever a previous
# carrier was defeated) and hand carry state to the toucher. Winning is now
# entirely scripts/extraction_anchor.gd's job - this script never calls
# MatchDirector.collect().
#
# Exactly one world Relic OR one carrier, never both/neither except a
# same-frame transition (CLAUDE.md S1) - achieved by toggling this SINGLE
# node's own visible state and carrier_slot_id rather than creating a
# second instance or reparenting onto the carrier. "Who has it" lives on
# player.gd (is_carrying_relic), exactly like carried_power; this node only
# knows whether IT is currently the active world object, and if so, where.
#
# `monitoring` stays permanently TRUE, deliberately never toggled -
# identical reasoning to the original M3-2 relic.gd's own documented
# finding, preserved here rather than rediscovered the hard way twice:
# toggling Area2D.monitoring off then back on does not reliably clear
# Godot's internal overlap tracking, so a body that was near the Relic
# before monitoring was disabled can still be reported as "overlapping"
# many frames after monitoring is re-enabled, even though it has long since
# moved away. carrier_slot_id (a plain state flag, not the physics engine)
# is what actually gates pickup processing below.
#
# Poll, not body_entered - the same reasoning the old M3-2 winner-detection
# version already established: simultaneous overlaps are an engine ordering
# detail, not something to build a race around. Resolved identically here:
# closest to centre, then lowest slot_id. A second guard, found via this
# milestone's own testing: get_overlapping_bodies() can ALSO be one physics
# step behind a body teleported earlier in the SAME frame (a respawn's
# reset_to(), or a dying body's reaction-window resolution) - the same
# staleness class docs/DECISIONS.md (2026-09-13) already found and fixed
# for power_pickup.gd/launch_pad.gd via a geometric re-check, applied here
# too rather than trusting the overlap list alone.

signal picked_up(slot_id: int)
signal dropped(slot_id: int)

@onready var _director: MatchDirector = get_parent().get_node("MatchDirector")
@onready var _placeholder: ColorRect = get_parent().get_node("RelicPlaceholder")
@onready var _shape: CollisionShape2D = $CollisionShape2D

const RELIC_DIM := Color(0.45, 0.45, 0.45, 1)
const RELIC_BRIGHT := Color(1, 1, 1, 1)

## "" while at the pedestal (the world Relic is BotBrain's existing
## "VaultFloor" SEEK_RELIC target, unchanged) - set to a real nav-graph node
## by drop_at() below, the same best-effort-canonical-platform convention
## scripts/health_system.gd's own _spill_power() already uses for a spilled
## power, so BotBrain can target a dropped Relic through the existing
## RELIABLE-only routing policy without any new spatial-query code.
var nav_node: String = "VaultFloor"

var carrier_slot_id: int = -1
var _world_active: bool = false
var _pedestal_position: Vector2

func _ready() -> void:
	set_collision_mask_value(2, true)
	monitoring = true
	_pedestal_position = global_position
	_director.state_changed.connect(_on_state_changed)
	if _director.state == MatchDirector.State.OPEN:
		_show_world(true)
	else:
		reset_to_pedestal()

func _on_state_changed(new_state: int) -> void:
	match new_state:
		MatchDirector.State.SETUP:
			reset_to_pedestal()
		MatchDirector.State.OPEN:
			if carrier_slot_id < 0:
				_show_world(true)

func is_world_active() -> bool:
	return carrier_slot_id < 0 and _world_active

## Rematch/SETUP reset (CLAUDE.md M4-3 S8: "Relic back to chamber/pedestal").
## Also the ONE place a still-carrying winner's own is_carrying_relic flag
## is cleared - a round can end with the carrier mid-carry (they just won by
## reaching extraction, not by dropping), so nothing else in the M3-2
## RESULTS->SETUP transition would otherwise clear it.
func reset_to_pedestal() -> void:
	if carrier_slot_id >= 0:
		var carrier := _find_player(carrier_slot_id)
		if carrier != null:
			carrier.drop_relic()
	carrier_slot_id = -1
	nav_node = "VaultFloor"
	_move_relic_to(_pedestal_position)
	_hide_world()
	visible = true
	_placeholder.visible = true
	_placeholder.modulate = RELIC_DIM

## scripts/health_system.gd calls this from _finish_defeat() when a
## Defeated player was carrying the Relic (CLAUDE.md M4-3 S6: "Relic drops
## at a valid nearby world position associated with the defeat location...
## extraction remains active and unchanged"). Guarded by carrier_slot_id
## matching `target`, the same is_instance_valid()-adjacent defensiveness
## every other per-body system in this codebase uses, so a stale/duplicate
## call can never double-drop.
func drop_at(target: CharacterBody2D, pos: Vector2, dropper_nav_node: String) -> void:
	if carrier_slot_id != target.slot_id:
		return
	var dropped_slot_id := carrier_slot_id
	carrier_slot_id = -1
	target.drop_relic()
	nav_node = dropper_nav_node if dropper_nav_node != "" else "VaultFloor"
	_move_relic_to(pos)
	_show_world(true)
	print("[Relic] P%d defeated - Relic dropped at %s (nav_node='%s')" % [dropped_slot_id, pos, nav_node])
	dropped.emit(dropped_slot_id)

## Visibility/placeholder ONLY - monitoring is never touched here, see the
## header. `_world_active` is the plain state flag is_world_active() reads.
func _show_world(bright: bool) -> void:
	_world_active = true
	visible = true
	_placeholder.visible = true
	_placeholder.modulate = RELIC_BRIGHT if bright else RELIC_DIM

func _hide_world() -> void:
	_world_active = false
	visible = false
	_placeholder.visible = false

## RelicPlaceholder is a Control (ColorRect) positioned via its own offsets,
## not a Node2D - `.position` on a Control IS its top-left offset once size
## is resolved, so recentring it on an arbitrary world point is just
## `target - half_size`, the same arithmetic its original authored offsets
## already encode (980,400 = 1000-20, 430-30, for the Relic's own 40x60
## pedestal rect).
func _move_relic_to(pos: Vector2) -> void:
	global_position = pos
	var half: Vector2 = _placeholder.size * 0.5
	_placeholder.position = pos - half

func _physics_process(_delta: float) -> void:
	if carrier_slot_id >= 0 or not _world_active:
		return
	if _director.state != MatchDirector.State.OPEN:
		return
	var winner: CharacterBody2D = null
	var winner_dist := INF
	for body in get_overlapping_bodies():
		if not (body is CharacterBody2D) or not ("slot_id" in body):
			continue
		if "is_defeated" in body and body.is_defeated:
			continue
		if "is_dying" in body and body.is_dying:
			continue
		if not _actually_overlaps(body):
			continue
		var d: float = abs(body.global_position.x - global_position.x)
		if winner == null or d < winner_dist - 0.001 or (abs(d - winner_dist) <= 0.001 and body.slot_id < winner.slot_id):
			winner = body
			winner_dist = d
	if winner == null:
		return
	_become_carrier(winner)

## get_overlapping_bodies() can report a body at a position it no longer
## occupies (see the header) - re-verify the body's CURRENT global_position
## against this Area2D's own rectangle (expanded by the body's own
## half-extents, an AABB-vs-AABB test) before trusting the overlap. Same
## pattern as power_pickup.gd's/launch_pad.gd's own fix for the identical
## staleness class.
func _actually_overlaps(body: CharacterBody2D) -> bool:
	var rect_shape := _shape.shape as RectangleShape2D
	if rect_shape == null:
		return true
	var local_pos: Vector2 = _shape.global_transform.affine_inverse() * body.global_position
	var half: Vector2 = rect_shape.size * 0.5 + _body_half_extents(body)
	return abs(local_pos.x) <= half.x and abs(local_pos.y) <= half.y

func _body_half_extents(body: Node2D) -> Vector2:
	if not body.has_node("CollisionShape2D"):
		return Vector2.ZERO
	var body_shape := (body.get_node("CollisionShape2D") as CollisionShape2D).shape
	if body_shape is RectangleShape2D:
		return (body_shape as RectangleShape2D).size * 0.5
	return Vector2.ZERO

func _become_carrier(body: CharacterBody2D) -> void:
	carrier_slot_id = body.slot_id
	body.receive_relic()
	_hide_world()
	print("[Relic] P%d picked up the Relic" % body.slot_id)
	picked_up.emit(body.slot_id)

func _find_player(slot_id: int) -> CharacterBody2D:
	var arena := get_parent()
	if arena == null or not ("players" in arena):
		return null
	for p in arena.players:
		if is_instance_valid(p) and p.slot_id == slot_id:
			return p
	return null
