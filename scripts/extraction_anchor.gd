extends Area2D

# M4-3 - one authored extraction destination (CLAUDE.md M4-3 S2/S8). Five
# instances of this same script live under $ExtractionAnchors in
# scenes/arena_01/arena_01.tscn, one per docs/GAME_DESIGN.md S8A region
# (`floor`/`west`/`central`/`east`/`seam`) - selection/locking is
# scripts/extraction_system.gd's job entirely; this script only knows how
# to reveal ITSELF and, once revealed, detect the carrier entering it.
#
# Dormant by construction, the same convention scripts/danger_zone.gd
# already established for an authored-but-conditional world object: hidden
# and behaviourally inert (the `active` flag below gates everything) until
# activate() is called, so an unselected anchor is inert and every earlier
# checker (arena_check/m3_check/m4_1_check/m4_2_check, none of which ever
# call activate()) is unaffected by this script's existence.
#
# `monitoring` stays permanently TRUE, deliberately never toggled - the
# same reasoning scripts/relic.gd documents at length: toggling
# Area2D.monitoring off then back on does not reliably clear Godot's
# internal overlap tracking, so an anchor re-activated in a LATER round
# (the same instance, deactivated then activated again) could otherwise
# resurface a stale overlap from whoever was near it the last time it was
# active. `active` (a plain state flag) is what actually gates the win
# check below.
#
# Poll, not body_entered/signals - matching relic.gd's own "poll, do not
# listen" reasoning, plus the same geometric re-check relic.gd applies for
# a body teleported earlier in the SAME physics frame (a respawn, or a
# dying body's reaction-window resolution). Only the CURRENT CARRIER can
# win (CLAUDE.md M4-3 S8: "Only the current carrier can trigger
# extraction") - there is never a multi-candidate tie to resolve here,
# since there is only ever one carrier at a time.

## Which docs/GAME_DESIGN.md S8A region this anchor represents - authored
## per scene instance, read by ExtractionSystem's selection algorithm.
@export var region: String = ""
## The nav-graph node (scripts/nav_graph.gd) this anchor physically sits on -
## authored once per instance, handed to every BotBrain once this anchor is
## selected (CLAUDE.md M4-3 S10), the same "authored nav_node" convention
## scenes/power/power_pickup.tscn's own instances already use.
@export var nav_node: String = ""

const DORMANT_COLOR := Color(0.3, 0.3, 0.35, 0.35)
const ACTIVE_COLOR := Color(0.95, 0.85, 0.25, 0.85)

var active: bool = false
var _director: MatchDirector = null

@onready var _visual: ColorRect = $ColorRect
@onready var _shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	set_collision_mask_value(2, true)
	monitoring = true
	visible = false
	if has_node("ColorRect"):
		_visual.color = DORMANT_COLOR

## arena_01.gd calls this once, exactly like every other configure() seam in
## this codebase (PowerSystem/HealthSystem/DangerZone).
func configure(p_director: MatchDirector) -> void:
	_director = p_director

func activate() -> void:
	active = true
	visible = true
	if has_node("ColorRect"):
		_visual.color = ACTIVE_COLOR
	print("[ExtractionAnchor] '%s' (region=%s, node=%s) ACTIVATED" % [name, region, nav_node])

func deactivate() -> void:
	active = false
	visible = false
	if has_node("ColorRect"):
		_visual.color = DORMANT_COLOR

func _physics_process(_delta: float) -> void:
	if not active or _director == null or _director.state != MatchDirector.State.OPEN:
		return
	for body in get_overlapping_bodies():
		if not (body is CharacterBody2D) or not ("slot_id" in body):
			continue
		if not ("is_carrying_relic" in body) or not body.is_carrying_relic:
			continue
		if not _actually_overlaps(body):
			continue
		_director.collect(body.slot_id)
		return

## See relic.gd's own _actually_overlaps() for the full reasoning - the
## identical AABB-vs-AABB re-check against a possibly-stale overlap list.
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
